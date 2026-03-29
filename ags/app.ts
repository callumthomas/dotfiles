import { App } from "ags/gtk4";
import style from "./style.scss";
import Bar from "./bar/Bar";

App.start({
  css: style,
  main() {
    for (const monitor of App.get_monitors()) {
      Bar(monitor);
    }
  },
});
