import { execAsync } from "ags/process"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import { togglePopup, closePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"

const actions = [
  { label: "🔒  Lock", cmd: "hyprlock" },
  { label: "😴  Suspend", cmd: "systemctl suspend-then-hibernate" },
  { label: "🔄  Reboot", cmd: "systemctl reboot" },
  { label: "🚪  Log Out", cmd: "hyprctl dispatch exit" },
  { label: "⏻  Shutdown", cmd: "systemctl poweroff", danger: true },
]

export function PowerButton({ monitor }: { monitor: string }) {
  return (
    <button
      cssClasses={["module-button", "module-last"]}
      onClicked={() => togglePopup(`power-popup-${monitor}`)}
    >
      <label label="⏻" />
    </button>
  )
}

export function PowerPopup(gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name={`power-popup-${gdkmonitor.get_connector()}`} gdkmonitor={gdkmonitor}>
      <box orientation={Gtk.Orientation.VERTICAL}>
        {actions.map((action) => (
          <button
            cssClasses={
              action.danger
                ? ["power-item", "danger"]
                : ["power-item"]
            }
            onClicked={() => {
              closePopup()
              execAsync(["bash", "-c", action.cmd]).catch(console.error)
            }}
          >
            <label label={action.label} />
          </button>
        ))}
      </box>
    </PopupWindow>
  )
}
