import { createBinding, createComputed, createState, For } from "gnim"
import { createPoll } from "ags/time"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"
import ToggleRow from "../components/ToggleRow"

const bt = AstalBluetooth.get_default()

// ── bar button ────────────────────────────────────────────────────────────────

interface BtIconState {
  isPowered: boolean
  isConnected: boolean
}

const btIconState = createPoll<BtIconState>(
  { isPowered: bt.isPowered, isConnected: bt.isConnected },
  3000,
  () => ({ isPowered: bt.isPowered, isConnected: bt.isConnected })
)

export function BluetoothButton({ monitor }: { monitor: string }) {
  const icon = btIconState.as((s) =>
    !s.isPowered ? "󰂲" : s.isConnected ? "󰂱" : "󰂯"
  )

  const cssClass = btIconState.as((s) =>
    s.isConnected ? ["module-button", "bt-connected"] : ["module-button"]
  )

  return (
    <button
      cssClasses={cssClass}
      onClicked={() => togglePopup(`bluetooth-popup-${monitor}`)}
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

  const batteryLabel = battery.as((b) => b >= 0 ? ` ${Math.round(b * 100)}%` : "")

  return (
    <box cssClasses={connected.as((c) => c ? ["bt-device", "connected"] : ["bt-device"])}>
      <label label={name} xalign={0} hexpand />
      <label label={batteryLabel} cssClasses={["bt-battery"]} />
      <button
        cssClasses={["bt-action"]}
        sensitive={connecting.as((c) => !c)}
        onClicked={() => {
          if (device.connected) {
            device.disconnect_device((_: any, res: any) => {
              try { device.disconnect_device_finish(res) } catch (e) { console.error(e) }
            })
          } else {
            device.trusted = true
            device.connect_device((_: any, res: any) => {
              try { device.connect_device_finish(res) } catch (e) { console.error(e) }
            })
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
    <box orientation={Gtk.Orientation.VERTICAL} visible={hasConnected}>
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
    <box orientation={Gtk.Orientation.VERTICAL} visible={hasPaired}>
      <label label="Paired" cssClasses={["section-header"]} xalign={0} />
      <For each={paired} id={(d) => d.address}>
        {(device) => <DeviceRow device={device} />}
      </For>
    </box>
  )
}

function pairDevice(device: AstalBluetooth.Device): Promise<void> {
  const proxy = Gio.DBusProxy.new_for_bus_sync(
    Gio.BusType.SYSTEM, Gio.DBusProxyFlags.NONE, null,
    "org.bluez", `/org/bluez/hci0/dev_${device.address.replaceAll(":", "_")}`,
    "org.bluez.Device1", null,
  )
  return new Promise((resolve, reject) => {
    proxy.call("Pair", null, Gio.DBusCallFlags.NONE, 60000, null,
      (_proxy: any, res: any) => {
        try { proxy.call_finish(res); resolve() }
        catch (e) { reject(e) }
      })
  })
}

function DiscoveredDeviceRow({ device }: { device: AstalBluetooth.Device }) {
  const name = createBinding(device, "alias").as((a) => a || device.name || "Unknown")
  const [status, setStatus] = createState<"idle" | "busy" | "error">("idle")

  return (
    <box cssClasses={["bt-device"]}>
      <label label={name} xalign={0} hexpand />
      <button
        cssClasses={status.as((s) =>
          s === "error" ? ["bt-action", "bt-error"] : ["bt-action"]
        )}
        sensitive={status.as((s) => s !== "busy")}
        onClicked={() => {
          if (status.peek() === "error") { setStatus("idle"); return }
          setStatus("busy")
          pairDevice(device)
            .then(() => {
              device.trusted = true
              return new Promise<void>((resolve, reject) => {
                device.connect_device((_: any, res: any) => {
                  try { device.connect_device_finish(res); resolve() }
                  catch (e) { reject(e) }
                })
              })
            })
            .then(() => setStatus("idle"))
            .catch(() => setStatus("error"))
        }}
      >
        <label label={status.as((s) =>
          s === "busy" ? "…" : s === "error" ? "Failed" : "Pair"
        )} />
      </button>
    </box>
  )
}

function AvailableDevices() {
  const adapter = bt.adapter
  if (!adapter) return <box />

  const devices = createBinding(bt, "devices")
  const discovering = createBinding(adapter, "discovering")

  const discovered = devices.as((ds) =>
    ds.filter((d) => !d.paired && d.name)
  )
  const hasDiscovered = discovered.as((ds) => ds.length > 0)

  return (
    <box orientation={Gtk.Orientation.VERTICAL}>
      <box cssClasses={["bt-scan-row"]}>
        <label label="Available" cssClasses={["section-header"]} xalign={0} hexpand />
        <button
          cssClasses={["bt-action"]}
          onClicked={() => {
            if (adapter.discovering) {
              adapter.stop_discovery()
            } else {
              adapter.start_discovery()
            }
          }}
        >
          <label label={discovering.as((d) => d ? "Stop" : "Scan")} />
        </button>
      </box>
      <box orientation={Gtk.Orientation.VERTICAL} visible={hasDiscovered}>
        <For each={discovered} id={(d) => d.address}>
          {(device) => <DiscoveredDeviceRow device={device} />}
        </For>
      </box>
      <label
        label="Scanning…"
        cssClasses={["bt-scanning"]}
        xalign={0}
        visible={createComputed(() => discovering() && !hasDiscovered())}
      />
    </box>
  )
}

export function BluetoothPopup(gdkmonitor: Gdk.Monitor) {
  const isPowered = createBinding(bt, "isPowered")

  return (
    <PopupWindow name={`bluetooth-popup-${gdkmonitor.get_connector()}`} gdkmonitor={gdkmonitor}>
      <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["bluetooth-popup"]}>
        <ToggleRow
          label="Bluetooth"
          active={isPowered}
          onToggled={() => bt.toggle()}
        />
        <box
          orientation={Gtk.Orientation.VERTICAL}
          visible={isPowered}
          cssClasses={["bt-devices"]}
        >
          <ConnectedDevices />
          <PairedDevices />
          <box cssClasses={["popup-divider"]} />
          <AvailableDevices />
        </box>
      </box>
    </PopupWindow>
  )
}
