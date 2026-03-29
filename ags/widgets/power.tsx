import { execAsync } from "ags/process"
import { Gdk } from "ags/gtk4"
import { togglePopup, closePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"

const actions = [
  { label: "🔒  Lock", cmd: "hyprlock" },
  { label: "😴  Suspend", cmd: "systemctl suspend-then-hibernate" },
  { label: "🔄  Reboot", cmd: "systemctl reboot" },
  { label: "🚪  Log Out", cmd: "hyprctl dispatch exit" },
  { label: "⏻  Shutdown", cmd: "systemctl poweroff", danger: true },
]

export function PowerButton() {
  return (
    <button
      cssClasses={["module-button"]}
      onClicked={() => togglePopup("power-popup")}
    >
      <label label="⏻" />
    </button>
  )
}

export function PowerPopup(gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name="power-popup" gdkmonitor={gdkmonitor}>
      <box vertical>
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
