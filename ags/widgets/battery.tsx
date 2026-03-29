import { createBinding, createComputed } from "gnim"
import { Gdk } from "ags/gtk4"
import AstalBattery from "gi://AstalBattery?version=0.1"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"
import ToggleRow from "../components/ToggleRow"
import { tlpState, setFullCharge } from "../lib/tlp"

const bat = AstalBattery.get_default()!

// ── helpers ───────────────────────────────────────────────────────────────────

function battIcon(pct: number, charging: boolean): string {
  if (charging) {
    if (pct >= 90) return "󰂅"
    if (pct >= 80) return "󰂄"
    if (pct >= 70) return "󰂃"
    if (pct >= 60) return "󰂂"
    if (pct >= 50) return "󰂁"
    if (pct >= 40) return "󰂀"
    if (pct >= 30) return "󰁿"
    if (pct >= 20) return "󰁾"
    return "󰁽"
  }
  if (pct >= 90) return "󰁹"
  if (pct >= 80) return "󰂂"
  if (pct >= 70) return "󰂁"
  if (pct >= 60) return "󰂀"
  if (pct >= 50) return "󰁿"
  if (pct >= 40) return "󰁾"
  if (pct >= 30) return "󰁽"
  if (pct >= 20) return "󰁼"
  if (pct >= 10) return "󰁻"
  return "󰁺"
}

function battCssClass(pct: number): string {
  if (pct > 60) return "bat-good"
  if (pct > 30) return "bat-medium"
  if (pct > 15) return "bat-low"
  return "bat-critical"
}

function fmtSeconds(secs: number): string {
  if (secs <= 0) return "—"
  const h = Math.floor(secs / 3600)
  const m = Math.floor((secs % 3600) / 60)
  if (h > 0) return `${h}h ${m}m`
  return `${m}m`
}

// ── bar button ────────────────────────────────────────────────────────────────

export function BatteryButton() {
  const pct = createBinding(bat, "percentage").as((p) => Math.round(p * 100))
  const charging = createBinding(bat, "charging")

  const icon = createComputed(() => battIcon(pct(), charging()))
  const cssClass = createComputed(() => [
    "module-button",
    battCssClass(pct()),
  ])

  return (
    <button
      cssClasses={cssClass}
      onClicked={() => togglePopup("battery-popup")}
    >
      <box>
        <label label={icon} cssClasses={["bat-icon"]} />
        <label label={pct.as((p) => `${p}%`)} cssClasses={["bat-pct"]} />
      </box>
    </button>
  )
}

// ── popup ─────────────────────────────────────────────────────────────────────

function BatteryInfo() {
  const pct = createBinding(bat, "percentage").as((p) => Math.round(p * 100))
  const charging = createBinding(bat, "charging")
  const state = createBinding(bat, "state")
  const timeToEmpty = createBinding(bat, "timeToEmpty")
  const timeToFull = createBinding(bat, "timeToFull")
  const energyRate = createBinding(bat, "energyRate")

  const timeLabel = createComputed(() => {
    if (charging()) return `Full in ${fmtSeconds(timeToFull())}`
    return `${fmtSeconds(timeToEmpty())} remaining`
  })

  const stateLabel = state.as((s) => {
    switch (s) {
      case AstalBattery.State.CHARGING: return "Charging"
      case AstalBattery.State.DISCHARGING: return "Discharging"
      case AstalBattery.State.FULLY_CHARGED: return "Full"
      default: return "Unknown"
    }
  })

  return (
    <box vertical cssClasses={["bat-info"]}>
      <box cssClasses={["bat-header-row"]}>
        <label
          label={createComputed(() => battIcon(pct(), charging()))}
          cssClasses={["bat-big-icon"]}
        />
        <box vertical>
          <label label={pct.as((p) => `${p}%`)} cssClasses={["bat-big-pct"]} xalign={0} />
          <label label={stateLabel} cssClasses={["bat-state"]} xalign={0} />
        </box>
      </box>
      <label label={timeLabel} cssClasses={["bat-time"]} xalign={0} />
      <label
        label={energyRate.as((r) => `${r.toFixed(1)} W`)}
        cssClasses={["bat-power"]}
        xalign={0}
      />
    </box>
  )
}

function TlpInfo() {
  const tlp = tlpState

  const modeLabel = tlp.as((t) =>
    t.mode === "AC" ? "AC (Performance)" : t.mode === "BAT" ? "Battery (Save)" : t.mode
  )

  const isFullCharge = tlp.as((t) => t.chargeStop >= 95)

  return (
    <box vertical cssClasses={["bat-tlp"]}>
      <label label="Power Profile" cssClasses={["section-header"]} xalign={0} />

      {/* TLP mode */}
      <box cssClasses={["bat-detail-row"]}>
        <label label="Mode" xalign={0} hexpand />
        <label label={modeLabel} cssClasses={["bat-detail-val"]} />
      </box>

      {/* CPU governor */}
      <box cssClasses={["bat-detail-row"]}>
        <label label="Governor" xalign={0} hexpand />
        <label label={tlp.as((t) => t.governor)} cssClasses={["bat-detail-val"]} />
      </box>

      {/* CPU boost */}
      <box cssClasses={["bat-detail-row"]}>
        <label label="CPU Boost" xalign={0} hexpand />
        <label label={tlp.as((t) => t.boost ? "on" : "off")} cssClasses={["bat-detail-val"]} />
      </box>

      {/* Platform profile */}
      <box cssClasses={["bat-detail-row"]}>
        <label label="Platform" xalign={0} hexpand />
        <label label={tlp.as((t) => t.platform)} cssClasses={["bat-detail-val"]} />
      </box>

      <box cssClasses={["popup-divider"]} />

      {/* Charge thresholds */}
      <label label="Charge Thresholds" cssClasses={["section-header"]} xalign={0} />
      <box cssClasses={["bat-detail-row"]}>
        <label label="Start / Stop" xalign={0} hexpand />
        <label
          label={tlp.as((t) => `${t.chargeStart}% / ${t.chargeStop}%`)}
          cssClasses={["bat-detail-val"]}
        />
      </box>

      <ToggleRow
        label="Full Charge (100%)"
        active={isFullCharge}
        onToggled={(active) => setFullCharge(active).catch(console.error)}
      />
    </box>
  )
}

export function BatteryPopup(gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name="battery-popup" gdkmonitor={gdkmonitor}>
      <box vertical cssClasses={["battery-popup"]}>
        <BatteryInfo />
        <box cssClasses={["popup-divider"]} />
        <TlpInfo />
      </box>
    </PopupWindow>
  )
}
