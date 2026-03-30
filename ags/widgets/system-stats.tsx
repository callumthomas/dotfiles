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

    const psOut = await execAsync("ps aux --sort=-%mem --no-headers")
    const top = psOut.split("\n").slice(0, 3)
      .map((row) => {
        const cols = row.trim().split(/\s+/)
        return { pid: cols[1] ?? "", cmd: cols[10] ?? "?", pct: cols[3] ?? "0" }
      })
      .filter((r) => r.pid)

    return { usedMb: used, totalMb: total, pct, top }
  } catch {
    return prev
  }
})

// ── Temperature ───────────────────────────────────────────────────────────────

interface TempEntry { name: string; temp: number }

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
            if (subKey.endsWith("_input") && typeof val === "number") {
              results.push({ name: `${chipName}: ${featureName}`, temp: Math.round(val) })
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

// ── bar buttons ───────────────────────────────────────────────────────────────

export function CpuButton() {
  return (
    <button
      cssClasses={cpuStat.as((c) => ["module-button", levelCss(c.usage, CPU_THRESHOLDS)])}
      onClicked={() => togglePopup("system-stats-popup")}
    >
      <box>
        <label label=" " />
        <label label={cpuStat.as((c) => `${c.usage}%`)} />
      </box>
    </button>
  )
}

export function MemButton() {
  return (
    <button
      cssClasses={memStat.as((m) => ["module-button", levelCss(m.pct, MEM_THRESHOLDS)])}
      onClicked={() => togglePopup("system-stats-popup")}
    >
      <box>
        <label label=" " />
        <label label={memStat.as((m) => `${m.pct}%`)} />
      </box>
    </button>
  )
}

export function TempButton() {
  const maxTemp = tempStat.as((ts) => ts[0]?.temp ?? 0)
  return (
    <button
      cssClasses={maxTemp.as((t) => ["module-button", levelCss(t, TMP_THRESHOLDS)])}
      onClicked={() => togglePopup("system-stats-popup")}
    >
      <box>
        <label label=" " />
        <label label={maxTemp.as((t) => `${t}°`)} />
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

function TopProcesses({ procs }: { procs: Accessor<ProcEntry[]> }) {
  return (
    <For each={procs} id={(p) => p.pid}>
      {(p) => (
        <box cssClasses={["stat-proc-row"]}>
          <label label={p.cmd.split("/").pop()!.slice(0, 24)} xalign={0} hexpand />
          <label label={`${p.pct}%`} cssClasses={["stat-proc-pct"]} />
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
          label={memStat.as((m) => `${m.usedMb}/${m.totalMb} MB`)}
          cssClasses={memStat.as((m) => ["stat-value", levelCss(m.pct, MEM_THRESHOLDS)])}
        />
      </box>
      <UsageBar pct={memStat.as((m) => m.pct)} thresholds={MEM_THRESHOLDS} />
      <box orientation={Gtk.Orientation.VERTICAL}>
        <TopProcesses procs={memStat.as((m) => m.top)} />
      </box>
    </box>
  )
}

function TempPanel() {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["stat-panel"]}>
      <label label="Temperatures" cssClasses={["section-header"]} xalign={0} />
      <box cssClasses={["stat-temp-grid"]}>
        <For each={tempStat} id={(e) => e.name}>
          {(e) => (
            <box cssClasses={["stat-temp-cell"]}>
              <label
                label={e.name.split(":").pop()!.trim().slice(0, 20)}
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
    <PopupWindow name="system-stats-popup" gdkmonitor={gdkmonitor}>
      <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["system-stats-popup"]}>
        <CpuPanel />
        <box cssClasses={["popup-divider"]} />
        <MemPanel />
        <box cssClasses={["popup-divider"]} />
        <TempPanel />
      </box>
    </PopupWindow>
  )
}
