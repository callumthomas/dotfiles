import Astal from "gi://Astal?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { Gdk } from "ags/gtk4";
import { currentPopup, closePopup } from "../bar/PopupManager";

interface PopupWindowProps {
  name: string;
  gdkmonitor: Gdk.Monitor;
  children?: JSX.Element;
}

export default function PopupWindow({ name, gdkmonitor, children }: PopupWindowProps) {
  return (
    <window
      name={name}
      gdkmonitor={gdkmonitor}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.LEFT
      }
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={currentPopup.as((p) => p === name)}
      cssClasses={["popup-window"]}
      $={(self: Astal.Window) => {
        const key = new Gtk.EventControllerKey();
        key.connect("key-pressed", () => {
          closePopup();
          return true;
        });
        self.add_controller(key);
      }}
    >
      <box
        hexpand
        vexpand
        $={(self: Gtk.Box) => {
          const gesture = new Gtk.GestureClick();
          gesture.connect("released", () => closePopup());
          self.add_controller(gesture);
        }}
      >
        <box hexpand />
        <box
          valign={Gtk.Align.START}
          hexpand={false}
          $={(self: Gtk.Box) => {
            const gesture = new Gtk.GestureClick();
            self.add_controller(gesture);
          }}
        >
          <box
            cssClasses={["popup-panel"]}
            orientation={Gtk.Orientation.VERTICAL}
          >
            {children}
          </box>
        </box>
      </box>
    </window>
  );
}
