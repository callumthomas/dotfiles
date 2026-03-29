import { createPoll } from "ags/time"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import GLib from "gi://GLib?version=2.0"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"

const londonTz = GLib.TimeZone["new"]("Europe/London")

const time = createPoll("", 1000, () =>
  GLib.DateTime.new_now(londonTz)!.format("%H:%M")!
)

const date = createPoll("", 60000, () =>
  GLib.DateTime.new_now(londonTz)!.format("%A, %e %B %Y")!
)

export function ClockButton() {
  return (
    <button
      cssClasses={["module-button"]}
      onClicked={() => togglePopup("clock-popup")}
    >
      <label label={time} />
    </button>
  )
}

export function ClockPopup(gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name="clock-popup" gdkmonitor={gdkmonitor}>
      <box vertical>
        <label label={time} />
        <label label={date} cssClasses={["text-secondary"]} />
        <box cssClasses={["popup-divider"]} />
        {new Gtk.Calendar()}
      </box>
    </PopupWindow>
  )
}
