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
  const monitor = gdkmonitor.get_connector()!;
  return (
    <window
      name={`bar-${monitor}`}
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
          <Media />
        </box>
        <box $type="center" cssClasses={["modules-center"]}>
          <WindowTitle />
        </box>
        <box $type="end" cssClasses={["modules-right"]} spacing={2}>
          <NetworkButton monitor={monitor} />
          <BluetoothButton monitor={monitor} />
          <AudioButton monitor={monitor} />
          <BatteryButton monitor={monitor} />
          <SystemStatsButton monitor={monitor} />
          <NotificationsButton monitor={monitor} />
          <ClockButton monitor={monitor} />
          <PowerButton monitor={monitor} />
        </box>
      </centerbox>
    </window>
  );
}
