import app from "ags/gtk4/app";
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

app.start({
  css: style,
  main() {
    for (const monitor of app.get_monitors()) {
      Bar(monitor);
      ClockPopup(monitor);
      PowerPopup(monitor);
      AudioPopup(monitor);
      NetworkPopup(monitor);
      BluetoothPopup(monitor);
      BatteryPopup(monitor);
      SystemStatsPopup(monitor);
      NotificationsPopup(monitor);
    }
  },
});
