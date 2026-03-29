import app from "ags/gtk4/app";
import style from "./style.scss";
import Bar from "./bar/Bar";
import { ClockPopup } from "./widgets/clock";
import { PowerPopup } from "./widgets/power";

app.start({
  css: style,
  main() {
    for (const monitor of app.get_monitors()) {
      Bar(monitor);
      ClockPopup(monitor);
      PowerPopup(monitor);
    }
  },
});
