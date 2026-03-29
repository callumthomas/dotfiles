import { createBinding, createComputed, For } from "gnim"
import { Gdk } from "ags/gtk4"
import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"
import ToggleRow from "../components/ToggleRow"

const bt = AstalBluetooth.get_default()

// ── bar button ────────────────────────────────────────────────────────────────

export function BluetoothButton() {
  const isPowered = createBinding(bt, "isPowered")
  const isConnected = createBinding(bt, "isConnected")

  const icon = createComputed(() =>
    !isPowered() ? "󰂲" : isConnected() ? "󰂱" : "󰂯"
  )

  const cssClass = createComputed(() =>
    isConnected()
      ? ["module-button", "bt-connected"]
      : ["module-button"]
  )

  return (
    <button
      cssClasses={cssClass}
      onClicked={() => togglePopup("bluetooth-popup")}
    >
      <label label={icon} />
    </button>
  )
}

// ── popup ─────────────────────────────────────────────────────────────────────

function DeviceRow({ device }: { device: AstalBluetooth.Device }) {
  const connected = createBinding(device, "connected")
  const connecting = createBinding(device, "connecting")
  const name = createBinding(device, "alias").as((a) => a || device.name || "Unknown")
  const battery = createBinding(device, "batteryPercentage")

  const batteryLabel = battery.as((b) => b >= 0 ? ` ${Math.round(b)}%` : "")

  return (
    <box cssClasses={connected.as((c) => c ? ["bt-device", "connected"] : ["bt-device"])}>
      <label label={name} xalign={0} hexpand />
      <label label={batteryLabel} cssClasses={["bt-battery"]} />
      <button
        cssClasses={["bt-action"]}
        sensitive={connecting.as((c) => !c)}
        onClicked={() => {
          if (device.connected) {
            device.disconnect_device().catch(console.error)
          } else {
            device.connect_device().catch(console.error)
          }
        }}
      >
        <label
          label={createComputed(() =>
            connecting() ? "…" : connected() ? "Disconnect" : "Connect"
          )}
        />
      </button>
    </box>
  )
}

function ConnectedDevices() {
  const devices = createBinding(bt, "devices")
  const connected = devices.as((ds) => ds.filter((d) => d.connected))
  const hasConnected = connected.as((ds) => ds.length > 0)

  return (
    <box vertical visible={hasConnected}>
      <label label="Connected" cssClasses={["section-header"]} xalign={0} />
      <For each={connected} id={(d) => d.address}>
        {(device) => <DeviceRow device={device} />}
      </For>
    </box>
  )
}

function PairedDevices() {
  const devices = createBinding(bt, "devices")
  const paired = devices.as((ds) => ds.filter((d) => d.paired && !d.connected))
  const hasPaired = paired.as((ds) => ds.length > 0)

  return (
    <box vertical visible={hasPaired}>
      <label label="Paired" cssClasses={["section-header"]} xalign={0} />
      <For each={paired} id={(d) => d.address}>
        {(device) => <DeviceRow device={device} />}
      </For>
    </box>
  )
}

export function BluetoothPopup(gdkmonitor: Gdk.Monitor) {
  const isPowered = createBinding(bt, "isPowered")

  return (
    <PopupWindow name="bluetooth-popup" gdkmonitor={gdkmonitor}>
      <box vertical cssClasses={["bluetooth-popup"]}>
        <ToggleRow
          label="Bluetooth"
          active={isPowered}
          onToggled={() => bt.toggle()}
        />
        <box
          vertical
          visible={isPowered}
          cssClasses={["bt-devices"]}
        >
          <ConnectedDevices />
          <PairedDevices />
        </box>
      </box>
    </PopupWindow>
  )
}
