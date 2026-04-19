import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import { createBinding, createComputed, For, type Accessor } from "gnim"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"

// ── thresholds ────────────────────────────────────────────────────────────────

const CPU_THRESHOLDS = [45, 60, 75, 90]
const MEM_THRESHOLDS = [45, 60, 75, 90]
const TMP_THRESHOLDS = [50, 60, 70, 85]
const FAN_THRESHOLDS = [3000, 4000, 5000, 6000]

function levelCss(val: number, thresholds: number[]): string {
  if (val >= thresholds[3]) return "stat-warning"
  if (val >= thresholds[2]) return "stat-high"
  if (val >= thresholds[1]) return "stat-moderate"
  return "stat-normal"
}

// ── CPU ───────────────────────────────────────────────────────────────────────

interface ProcEntry { pid: string; cmd: string; pct: string }

interface CpuSample {
  idle: number
  total: number
  usage: number
  top: ProcEntry[]
}

const EMPTY_CPU: CpuSample = { idle: 0, total: 0, usage: 0, top: [] }

const cpuStat = createPoll<CpuSample>(EMPTY_CPU, 2000, async (prev) => {
  try {
    const statOut = await execAsync("cat /proc/stat")
    const line = statOut.split("\n")[0]
    const parts = line.split(/\s+/).slice(1).map(Number)
    const idle = parts[3] + (parts[4] ?? 0)
    const total = parts.reduce((a, b) => a + b, 0)
    const dIdle = idle - prev.idle
    const dTotal = total - prev.total
    const usage = dTotal > 0 ? Math.round(100 * (1 - dIdle / dTotal)) : 0

    const psOut = await execAsync("ps aux --sort=-%cpu --no-headers")
    const top = psOut.split("\n").slice(0, 3)
      .map((row) => {
        const cols = row.trim().split(/\s+/)
        return { pid: cols[1] ?? "", cmd: cols[10] ?? "?", pct: cols[2] ?? "0" }
      })
      .filter((r) => r.pid)

    return { idle, total, usage, top }
  } catch {
    return prev
  }
})

// ── Memory ────────────────────────────────────────────────────────────────────

interface MemSample {
  usedMb: number
  totalMb: number
  pct: number
  top: ProcEntry[]
}

const EMPTY_MEM: MemSample = { usedMb: 0, totalMb: 0, pct: 0, top: [] }

const memStat = createPoll<MemSample>(EMPTY_MEM, 2000, async (prev) => {
  try {
    const freeOut = await execAsync("free -m")
    const line = freeOut.split("\n")[1]
    const parts = line.trim().split(/\s+/)
    const total = parseInt(parts[1], 10)
    const used = parseInt(parts[2], 10)
    const pct = total > 0 ? Math.round((used / total) * 100) : 0

    const psOut = await execAsync("ps -eo pid,rss,comm --sort=-rss --no-headers")
    const top = psOut.split("\n").slice(0, 3)
      .map((row) => {
        const cols = row.trim().split(/\s+/)
        const rssKb = parseInt(cols[1] ?? "0", 10)
        return { pid: cols[0] ?? "", cmd: cols[2] ?? "?", pct: String(Math.round(rssKb / 1024)) }
      })
      .filter((r) => r.pid)

    return { usedMb: used, totalMb: total, pct, top }
  } catch {
    return prev
  }
})

// ── Temperature ───────────────────────────────────────────────────────────────

interface TempEntry { name: string; temp: number }

const KNOWN_FEATURE_NAMES: Record<string, string> = {
  "Tctl": "CPU Package",
  "edge": "GPU Edge",
  "Composite": "NVMe",
  "Sensor 1": "NVMe Die",
}

function friendlyTempName(chipName: string, featureName: string): string {
  if (KNOWN_FEATURE_NAMES[featureName]) return KNOWN_FEATURE_NAMES[featureName]
  if (chipName.startsWith("mt79") || chipName.startsWith("iwl")) return "WiFi"
  if (chipName.startsWith("acpitz")) return "ACPI"
  if (chipName.startsWith("thinkpad") && /^temp\d+$/.test(featureName))
    return `Zone ${featureName.slice(4)}`
  return featureName
}

const EMPTY_TEMPS: TempEntry[] = []

const tempStat = createPoll<TempEntry[]>(EMPTY_TEMPS, 5000, async () => {
  try {
    const out = await execAsync("sensors -j")
    const json = JSON.parse(out)
    const results: TempEntry[] = []

    for (const [chipName, chip] of Object.entries(json as Record<string, any>)) {
      for (const [featureName, feature] of Object.entries(chip as Record<string, any>)) {
        if (typeof feature === "object" && feature !== null) {
          for (const [subKey, val] of Object.entries(feature as Record<string, any>)) {
            if (/^temp\d+_input$/.test(subKey) && typeof val === "number") {
              results.push({ name: friendlyTempName(chipName, featureName), temp: Math.round(val) })
            }
          }
        }
      }
    }

    return results.filter((e) => e.temp > 0).sort((a, b) => b.temp - a.temp).slice(0, 8)
  } catch {
    return EMPTY_TEMPS
  }
})

// ── Fan ──────────────────────────────────────────────────────────────────────

interface FanSample {
  rpm: number
  pct: number
  level: string
}

const EMPTY_FAN: FanSample = { rpm: 0, pct: 0, level: "auto" }

const fanStat = createPoll<FanSample>(EMPTY_FAN, 5000, async () => {
  try {
    const [sensorsOut, fanOut] = await Promise.all([
      execAsync("sensors -j"),
      execAsync("cat /proc/acpi/ibm/fan"),
    ])

    const json = JSON.parse(sensorsOut)
    const thinkpad = json["thinkpad-isa-0000"]
    const rpm = thinkpad?.fan1?.fan1_input ?? 0
    const pwm = thinkpad?.pwm1?.pwm1 ?? 0
    const pct = Math.round((pwm / 255) * 100)

    const levelMatch = fanOut.match(/^level:\s+(.+)$/m)
    const level = levelMatch?.[1]?.trim() ?? "unknown"

    return { rpm: Math.round(rpm), pct, level }
  } catch {
    return EMPTY_FAN
  }
})

// ── bar buttons ───────────────────────────────────────────────────────────────

export function SystemStatsButton({ monitor }: { monitor: string }) {
  const maxTemp = tempStat.as((ts) => ts[0]?.temp ?? 0)
  return (
    <button
      cssClasses={["module-button", "sys-stats-group"]}
      onClicked={() => togglePopup(`system-stats-popup-${monitor}`)}
    >
      <box spacing={18}>
        <label
          label={"\uF2C8"}
          cssClasses={maxTemp.as((t) => [levelCss(t, TMP_THRESHOLDS)])}
        />
        <label
          label={"\u{F0210}"}
          cssClasses={fanStat.as((f) => [levelCss(f.rpm, FAN_THRESHOLDS)])}
        />
        <label
          label={"\uEFC5"}
          cssClasses={memStat.as((m) => [levelCss(m.pct, MEM_THRESHOLDS)])}
        />
        <label
          label={"\uF2DB"}
          cssClasses={cpuStat.as((c) => [levelCss(c.usage, CPU_THRESHOLDS)])}
        />
      </box>
    </button>
  )
}

// ── popup: usage bar (via levelbar intrinsic) ─────────────────────────────────

function UsageBar({ pct, thresholds }: { pct: Accessor<number>, thresholds: number[] }) {
  return (
    <levelbar
      minValue={0}
      maxValue={100}
      value={pct}
      cssClasses={pct.as((p) => ["stat-levelbar", levelCss(p, thresholds)])}
    />
  )
}

// ── proc rows ─────────────────────────────────────────────────────────────────

function formatMb(mb: number): string {
  return mb >= 1024 ? `${(mb / 1024).toFixed(1)} GB` : `${mb} MB`
}

function TopProcesses({ procs, unit }: { procs: Accessor<ProcEntry[]>, unit?: "mem" }) {
  return (
    <For each={procs} id={(p) => p.pid}>
      {(p) => (
        <box cssClasses={["stat-proc-row"]}>
          <label label={p.cmd.split("/").pop()!.slice(0, 24)} xalign={0} hexpand />
          <label
            label={unit === "mem" ? formatMb(parseInt(p.pct, 10)) : `${p.pct}%`}
            cssClasses={["stat-proc-pct"]}
          />
        </box>
      )}
    </For>
  )
}

// ── popup panels ─────────────────────────────────────────────────────────────

function CpuPanel() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["stat-panel"]}>
      <box>
        <label label="CPU" cssClasses={["section-header"]} hexpand xalign={0} />
        <label
          label={cpuStat.as((c) => `${c.usage}%`)}
          cssClasses={cpuStat.as((c) => ["stat-value", levelCss(c.usage, CPU_THRESHOLDS)])}
        />
      </box>
      <UsageBar pct={cpuStat.as((c) => c.usage)} thresholds={CPU_THRESHOLDS} />
      <box orientation={Gtk.Orientation.VERTICAL}>
        <TopProcesses procs={cpuStat.as((c) => c.top)} />
      </box>
    </box>
  )
}

function MemPanel() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["stat-panel"]}>
      <box>
        <label label="Memory" cssClasses={["section-header"]} hexpand xalign={0} />
        <label
          label={memStat.as((m) => `${formatMb(m.usedMb)} / ${formatMb(m.totalMb)}`)}
          cssClasses={memStat.as((m) => ["stat-value", levelCss(m.pct, MEM_THRESHOLDS)])}
        />
      </box>
      <UsageBar pct={memStat.as((m) => m.pct)} thresholds={MEM_THRESHOLDS} />
      <box orientation={Gtk.Orientation.VERTICAL}>
        <TopProcesses procs={memStat.as((m) => m.top)} unit="mem" />
      </box>
    </box>
  )
}

function FanPanel() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["stat-panel"]}>
      <box>
        <label label="Fan" cssClasses={["section-header"]} hexpand xalign={0} />
        <label
          label={fanStat.as((f) => `${f.rpm} RPM`)}
          cssClasses={fanStat.as((f) => ["stat-value", levelCss(f.rpm, FAN_THRESHOLDS)])}
        />
      </box>
      <box cssClasses={["stat-fan-detail"]}>
        <label label="Level" xalign={0} hexpand cssClasses={["stat-temp-name"]} />
        <label label={fanStat.as((f) => f.level)} cssClasses={["stat-temp-val"]} />
      </box>
      <box cssClasses={["stat-fan-control"]} spacing={8}>
        <slider
          hexpand
          value={fanStat.as((f) => {
            const n = parseInt(f.level)
            return isNaN(n) ? 4 : n
          })}
          min={0}
          max={7}
          step={1}
          drawValue={false}
          onChangeValue={(_self, _scroll, val) => {
            execAsync(`sudo /usr/local/bin/fan-set ${Math.round(val)}`)
            return false
          }}
        />
        <button
          label="Auto"
          cssClasses={fanStat.as((f) => [
            "stat-fan-auto-btn",
            f.level === "auto" ? "active" : "",
          ])}
          onClicked={() => {
            const current = fanStat.get()
            if (current.level === "auto") {
              const level = Math.min(7, Math.max(0, Math.round(current.pct / 100 * 7)))
              execAsync(`sudo /usr/local/bin/fan-set ${level}`)
            } else {
              execAsync("sudo /usr/local/bin/fan-set auto")
            }
          }}
        />
      </box>
    </box>
  )
}

function TempPanel() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["stat-panel"]}>
      <label label="Temperatures" cssClasses={["section-header"]} xalign={0} />
      <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["stat-temp-grid"]}>
        <For each={tempStat} id={(e) => e.name}>
          {(e) => (
            <box cssClasses={["stat-temp-cell"]}>
              <label
                label={e.name.slice(0, 20)}
                xalign={0}
                hexpand
                cssClasses={["stat-temp-name"]}
              />
              <label
                label={`${e.temp}°`}
                cssClasses={["stat-temp-val", levelCss(e.temp, TMP_THRESHOLDS)]}
              />
            </box>
          )}
        </For>
      </box>
    </box>
  )
}

export function SystemStatsPopup(gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name={`system-stats-popup-${gdkmonitor.get_connector()}`} gdkmonitor={gdkmonitor}>
      <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["system-stats-popup"]}>
        <CpuPanel />
        <box cssClasses={["popup-divider"]} />
        <MemPanel />
        <box cssClasses={["popup-divider"]} />
        <TempPanel />
        <box cssClasses={["popup-divider"]} />
        <FanPanel />
      </box>
    </PopupWindow>
  )
}
