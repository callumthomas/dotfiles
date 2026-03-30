import { createBinding, createComputed, For } from "gnim"
import { createPoll } from "ags/time"
import { execAsync } from "ags/process"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import AstalNetwork from "gi://AstalNetwork?version=0.1"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"

const network = AstalNetwork.get_default()

// ── bandwidth polling (/sys/class/net) ────────────────────────────────────────

interface BwState {
  rxBytes: number
  txBytes: number
  rxRate: string
  txRate: string
}

function fmtRate(bytesPerSec: number): string {
  if (bytesPerSec < 1024) return `${bytesPerSec.toFixed(0)} B/s`
  if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(1)} KB/s`
  return `${(bytesPerSec / 1024 / 1024).toFixed(1)} MB/s`
}

function getNetIface(): string {
  const primary = network.primary
  if (primary === AstalNetwork.Primary.WIFI && network.wifi) {
    try {
      return (network.wifi.device as any)?.get_iface?.() ?? "wlan0"
    } catch {
      return "wlan0"
    }
  }
  if (primary === AstalNetwork.Primary.WIRED && network.wired) {
    try {
      return (network.wired.device as any)?.get_iface?.() ?? "eth0"
    } catch {
      return "eth0"
    }
  }
  return "wlan0"
}

const bandwidth = createPoll<BwState>(
  { rxBytes: 0, txBytes: 0, rxRate: "—", txRate: "—" },
  2000,
  async (prev) => {
    try {
      const iface = getNetIface()
      const rxPath = `/sys/class/net/${iface}/statistics/rx_bytes`
      const txPath = `/sys/class/net/${iface}/statistics/tx_bytes`

      const [rxStr, txStr] = await Promise.all([
        execAsync(`cat ${rxPath}`),
        execAsync(`cat ${txPath}`),
      ])

      const rx = parseInt(rxStr.trim(), 10)
      const tx = parseInt(txStr.trim(), 10)

      const rxRate = prev.rxBytes > 0 ? fmtRate((rx - prev.rxBytes) / 2) : "—"
      const txRate = prev.txBytes > 0 ? fmtRate((tx - prev.txBytes) / 2) : "—"

      return { rxBytes: rx, txBytes: tx, rxRate, txRate }
    } catch {
      return { ...prev, rxRate: "—", txRate: "—" }
    }
  }
)

// ── bar button ────────────────────────────────────────────────────────────────

function wifiIcon(strength: number): string {
  if (strength >= 75) return "󰤨"
  if (strength >= 50) return "󰤥"
  if (strength >= 25) return "󰤢"
  return "󰤟"
}

export function NetworkButton() {
  const wifi = network.wifi
  const primary = createBinding(network, "primary")

  // If NM reports wifi, use that; if wifi object exists (iwd), use signal strength
  const icon = wifi
    ? createBinding(wifi, "strength").as((s) =>
        s > 0 ? wifiIcon(s) : primary() === AstalNetwork.Primary.WIRED ? "" : "󰤭"
      )
    : primary.as((p) =>
        p === AstalNetwork.Primary.WIRED ? "" : "󰤭"
      )

  const cssClass = wifi
    ? createBinding(wifi, "strength").as((s) =>
        s > 0
          ? ["module-button", "net-wifi"]
          : ["module-button", "net-disconnected"]
      )
    : primary.as((p) =>
        p === AstalNetwork.Primary.WIRED
          ? ["module-button", "net-wired"]
          : ["module-button", "net-disconnected"]
      )

  return (
    <button
      cssClasses={cssClass}
      onClicked={() => togglePopup("network-popup")}
    >
      <label label={icon} />
    </button>
  )
}

// ── popup sections ────────────────────────────────────────────────────────────

function WifiSection() {
  const wifi = network.wifi
  if (!wifi) return <box />

  const ssid = createBinding(wifi, "ssid")
  const strength = createBinding(wifi, "strength")
  const aps = createBinding(wifi, "accessPoints")

  const sortedAps = aps.as((list) =>
    [...list].sort((a, b) => b.strength - a.strength).slice(0, 10)
  )

  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["net-section"]}>
      <label label="Wi-Fi" cssClasses={["section-header"]} xalign={0} />

      {/* Current connection info */}
      <box cssClasses={["net-info-row"]}>
        <label label="" cssClasses={["net-icon"]} />
        <label label={ssid.as((s) => s || "Not connected")} xalign={0} hexpand />
        <label label={strength.as((s) => `${s}%`)} cssClasses={["net-strength"]} />
      </box>

      {/* Bandwidth */}
      <box cssClasses={["net-bw-row"]}>
        <label
          label={bandwidth.as((b) => `↓ ${b.rxRate}  ↑ ${b.txRate}`)}
          cssClasses={["net-bandwidth"]}
          xalign={0}
        />
      </box>

      {/* Access point list */}
      <label label="Available networks" cssClasses={["net-sub-header"]} xalign={0} />
      <For each={sortedAps} id={(ap) => ap.bssid}>
        {(ap) => {
          const apSsid = createBinding(ap, "ssid")
          const apStrength = createBinding(ap, "strength")
          const isActive = createComputed(() => ap.ssid === wifi.ssid)

          return (
            <button
              cssClasses={isActive.as((a) =>
                a ? ["net-ap", "active"] : ["net-ap"]
              )}
              onClicked={() => ap.activate().catch(console.error)}
            >
              <box>
                <label label={apSsid.as((s) => s || "(hidden)")} xalign={0} hexpand />
                <label label={apStrength.as((s) => `${s}%`)} cssClasses={["net-strength"]} />
                <label label="" cssClasses={["net-lock"]} visible={createBinding(ap, "requiresPassword")} />
              </box>
            </button>
          )
        }}
      </For>
    </box>
  )
}

function WiredSection() {
  const wired = network.wired
  if (!wired) return <box />

  const speed = createBinding(wired, "speed")

  return (
    <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["net-section"]}>
      <label label="Ethernet" cssClasses={["section-header"]} xalign={0} />
      <box cssClasses={["net-info-row"]}>
        <label label="" cssClasses={["net-icon"]} />
        <label label="Connected" xalign={0} hexpand />
        <label label={speed.as((s) => `${s} Mb/s`)} cssClasses={["net-speed"]} />
      </box>
      <box cssClasses={["net-bw-row"]}>
        <label
          label={bandwidth.as((b) => `↓ ${b.rxRate}  ↑ ${b.txRate}`)}
          cssClasses={["net-bandwidth"]}
          xalign={0}
        />
      </box>
    </box>
  )
}

export function NetworkPopup(gdkmonitor: Gdk.Monitor) {
  const hasWifi = network.wifi !== null
  const hasWired = network.wired !== null

  return (
    <PopupWindow name="network-popup" gdkmonitor={gdkmonitor}>
      <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["network-popup"]}>
        {hasWifi && <WifiSection />}
        {hasWifi && hasWired && <box cssClasses={["popup-divider"]} />}
        {hasWired && <WiredSection />}
        {!hasWifi && !hasWired && (
          <box cssClasses={["net-section"]}>
            <label label="Not connected" cssClasses={["net-disconnected-label"]} />
          </box>
        )}
      </box>
    </PopupWindow>
  )
}
