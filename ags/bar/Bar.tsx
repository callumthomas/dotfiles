import Astal from "gi://Astal?version=4.0";
import { Gdk } from "ags/gtk4";
import Workspaces from "../widgets/workspaces";
import WindowTitle from "../widgets/window-title";
import { NetworkButton } from "../widgets/network";
import { BatteryButton } from "../widgets/battery";
import { BluetoothButton } from "../widgets/bluetooth";
import { AudioButton } from "../widgets/audio";
import { SystemStatsButton } from "../widgets/system-stats";
import Media from "../widgets/media";
import { NotificationsButton } from "../widgets/notifications";
import { ClockButton } from "../widgets/clock";
import { PowerButton } from "../widgets/power";

export default function Bar(gdkmonitor: Gdk.Monitor) {
  return (
    <window
      name={`bar-${gdkmonitor.get_connector()}`}
      gdkmonitor={gdkmonitor}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.OVERLAY}
      cssClasses={["bar"]}
      visible={true}
    >
      <centerbox cssClasses={["bar-inner"]}>
        <box $type="start" cssClasses={["modules-left"]}>
          <Workspaces />
        </box>
        <box $type="center" cssClasses={["modules-center"]}>
          <WindowTitle />
        </box>
        <box $type="end" cssClasses={["modules-right"]} spacing={2}>
          <Media />
          <NetworkButton />
          <BluetoothButton />
          <AudioButton />
          <BatteryButton />
          <SystemStatsButton />
          <NotificationsButton />
          <ClockButton />
          <PowerButton />
        </box>
      </centerbox>
    </window>
  );
}
