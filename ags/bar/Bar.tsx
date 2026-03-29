import Astal from "gi://Astal?version=4.0";
import { Gdk } from "ags/gtk4";
import Workspaces from "../widgets/workspaces";
import WindowTitle from "../widgets/window-title";
import { ClockButton } from "../widgets/clock";

export default function Bar(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name={`bar-${gdkmonitor.get_connector()}`}
      gdkmonitor={gdkmonitor}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      cssClasses={["bar"]}
    >
      <centerbox cssClasses={["bar-inner"]}>
        <box $type="start" cssClasses={["modules-left"]}>
          <Workspaces />
        </box>
        <box $type="center" cssClasses={["modules-center"]}>
          <WindowTitle />
        </box>
        <box $type="end" cssClasses={["modules-right"]}>
          <ClockButton />
        </box>
      </centerbox>
    </window>
  );
}
