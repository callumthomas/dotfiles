import Astal from "gi://Astal?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { Gdk } from "ags/gtk4";
import { closePopup } from "../bar/PopupManager";

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
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={false}
      cssClasses={["popup-window"]}
      $={(self) => {
        // Escape key dismisses popup
        const keyController = new Gtk.EventControllerKey();
        keyController.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) {
            closePopup();
          }
        });
        self.add_controller(keyController);

        // Click anywhere on the window background dismisses popup
        const clickController = new Gtk.GestureClick();
        clickController.connect("pressed", () => {
          closePopup();
        });
        self.add_controller(clickController);
      }}
    >
      <box vertical>
        <box cssClasses={["popup-panel"]}>
          {children}
        </box>
      </box>
    </window>
  );
}
