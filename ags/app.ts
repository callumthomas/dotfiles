import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import style from "./style.scss";
import Bar from "./bar/Bar";
import { ClockPopup } from "./widgets/clock";
import { PowerPopup } from "./widgets/power";
import { AudioPopup } from "./widgets/audio";
import { NetworkPopup } from "./widgets/network";
import { BluetoothPopup } from "./widgets/bluetooth";
import { BatteryPopup } from "./widgets/battery";
import { SystemStatsPopup } from "./widgets/system-stats";
import { NotificationsPopup } from "./widgets/notifications";
import { togglePopup, closePopup } from "./bar/PopupManager";

app.start({
  css: style,
  requestHandler(argv, res) {
    const args = argv.join(" ").split(" ");
    if (args[0] === "toggle" && args[1]) {
      togglePopup(args[1]);
      res("ok");
    } else if (args[0] === "close") {
      closePopup();
      res("ok");
    } else {
      res(`unknown: ${JSON.stringify(argv)}`);
    }
  },
  main() {
    for (const monitor of app.get_monitors()) {
      Bar(monitor);

      // Create popups and ensure they're registered with the app
      const popups = [
        ClockPopup(monitor),
        PowerPopup(monitor),
        AudioPopup(monitor),
        NetworkPopup(monitor),
        BluetoothPopup(monitor),
        BatteryPopup(monitor),
        SystemStatsPopup(monitor),
        NotificationsPopup(monitor),
      ];

      for (const win of popups) {
        if (win instanceof Gtk.Window && !win.application) {
          app.add_window(win);
        }
      }
    }
  },
});
