import app from "ags/gtk4/app";
import { Gdk } from "ags/gtk4";
import Gtk from "gi://Gtk?version=4.0";
import AstalHyprland from "gi://AstalHyprland?version=0.1";
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

const hypr = AstalHyprland.get_default()!;

const POPUP_PREFIXES = [
  "clock-popup",
  "power-popup",
  "audio-popup",
  "network-popup",
  "bluetooth-popup",
  "battery-popup",
  "system-stats-popup",
  "notifications-popup",
];

const activeMonitors = new Set<string>();

function findGdkMonitor(connector: string): Gdk.Monitor | null {
  return app.get_monitors().find((m) => m.get_connector() === connector) ?? null;
}

function setupMonitor(connector: string) {
  if (activeMonitors.has(connector)) return;

  const gdkMonitor = findGdkMonitor(connector);
  if (!gdkMonitor) return;

  activeMonitors.add(connector);
  Bar(gdkMonitor);

  const popups = [
    ClockPopup(gdkMonitor),
    PowerPopup(gdkMonitor),
    AudioPopup(gdkMonitor),
    NetworkPopup(gdkMonitor),
    BluetoothPopup(gdkMonitor),
    BatteryPopup(gdkMonitor),
    SystemStatsPopup(gdkMonitor),
    NotificationsPopup(gdkMonitor),
  ];

  for (const win of popups) {
    if (win instanceof Gtk.Window && !win.application) {
      app.add_window(win);
    }
  }
}

function teardownMonitor(connector: string) {
  if (!activeMonitors.has(connector)) return;

  activeMonitors.delete(connector);

  const windowNames = [
    `bar-${connector}`,
    ...POPUP_PREFIXES.map((p) => `${p}-${connector}`),
  ];

  for (const name of windowNames) {
    const win = app.get_window(name);
    if (win) {
      win.visible = false;
      app.remove_window(win);
      win.close();
    }
  }
}

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
      setupMonitor(monitor.get_connector()!);
    }

    hypr.connect("monitor-added", (_, hyprMonitor) => {
      setupMonitor(hyprMonitor.name);
    });

    hypr.connect("monitor-removed", (_, id) => {
      // Find which connector was removed by diffing against active set
      const hyprConnectors = new Set(hypr.get_monitors().map((m) => m.name));
      for (const connector of [...activeMonitors]) {
        if (!hyprConnectors.has(connector)) {
          teardownMonitor(connector);
        }
      }
    });
  },
});
