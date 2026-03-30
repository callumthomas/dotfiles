# AGS v2 Bar — Design Spec

Replaces Waybar with an AGS v2 (Astal) bar for Hyprland. Same transparent dark aesthetic, evolved with GTK4 polish. Modules open functional dropdown panels with real controls.

## Tech Stack

- **AGS v2** with Astal libraries
- **TypeScript + JSX** targeting GTK4
- **Hyprland layer-shell** for bar and popup windows
- Runs on Arch Linux, Hyprland compositor

## Architecture

**Widget-per-module** — each module is a self-contained `.tsx` file exporting a bar button and its dropdown panel. A shared popup manager coordinates open/close state.

```
ags/
├── app.ts                  # Entry point, window definitions
├── bar/
│   ├── Bar.tsx             # Bar layout (left/center/right)
│   └── PopupManager.ts    # Singleton: tracks open popup, handles dismiss
├── widgets/
│   ├── workspaces.tsx
│   ├── window-title.tsx
│   ├── audio.tsx
│   ├── network.tsx
│   ├── bluetooth.tsx
│   ├── battery.tsx
│   ├── system-stats.tsx
│   ├── clock.tsx
│   ├── media.tsx
│   ├── notifications.tsx
│   └── power.tsx
├── components/
│   ├── Slider.tsx          # Reusable volume/brightness slider
│   ├── ToggleRow.tsx       # Label + toggle switch row
│   └── DeviceList.tsx      # Reusable device list (BT/audio)
└── styles/
    └── style.css           # GTK4 CSS
```

## Bar Layout

Single GTK4 layer-shell window anchored to top of each monitor.

- **Left:** Workspaces
- **Center:** Window title
- **Right:** Network, Battery, Bluetooth, Audio, System Stats, Media (inline), Notifications, Clock, Power Menu

Multi-monitor: bar spawns on each monitor. Popups open on the monitor where the click happened. Workspaces show all workspaces across monitors.

Toggle with `SUPER+SHIFT+W` — calls `ags toggle bar-<monitor>` (replaces current `killall waybar || waybar` bind).

## Popup Manager

- Only one popup open at a time — opening another closes the current
- Click outside or Escape to dismiss
- Each popup is its own layer-shell window (not a bar child), positioned below its trigger button
- Slide-down + fade-in animation on open

## Modules

### Workspaces

Hyprland workspace buttons with click-to-activate. Icon-based display showing all workspaces across monitors (matching current `all-outputs: true` behavior).

**Binding:** Astal Hyprland service — reactive workspace state.

### Window Title

Active window name in center with rewrite rules:
- `(.*) - Mozilla Firefox` → `🌎 $1`
- `(.*) — Mozilla Firefox` → `🌎 $1`
- `(.*) - Delio - Slack` → `💬 $1`
- Empty → `...`

Max length: 50 characters.

**Binding:** Astal Hyprland service — active window title.

### Audio

**Bar icon:** Speaker with volume-level icons, muted state in red. Scroll to adjust volume.

**Dropdown panel:**
- Output volume slider with percentage
- Output device list (click to switch) — shows active device highlighted
- Input device section
- Per-app volume sliders (shows running audio streams)

**Binding:** Astal WirePlumber service — reactive volume, mute, sink/source switching. Per-app volume via PulseAudio stream API.

### Network

**Bar icon:** WiFi/ethernet/disconnected status icon with color coding (cyan for WiFi, green for ethernet, red for disconnected).

**Dropdown panel:**
- Current connection info (SSID, IP, link speed)
- Upload/download bandwidth cards
- Available WiFi networks list with signal strength, click to connect

**Binding:** Astal Network service for connection state and signal. Bandwidth via polling `/sys/class/net` stats. Available networks from NetworkManager via `nmcli`.

### Battery + TLP

**Bar icon:** Battery level with tiered icons and color coding. Charging indicator.

**Dropdown panel:**
- Charge percentage with progress bar, time remaining
- TLP profile indicator — shows whether AC (performance) or battery (powersave) is active
- Details grid: CPU governor, CPU boost on/off, platform profile, power draw (from `/sys/class/power_supply`)
- Charge thresholds display (75% start / 80% stop from TLP config)
- "Full Charge" button — temporarily sets thresholds to 100/100 for travel prep

**Binding:** Astal Battery service for charge/state. TLP info via `tlp-stat -b` and `tlp-stat -p` (polled, ~10s interval). Charge threshold toggle writes to `/sys/class/power_supply/BAT0/charge_control_*` (needs polkit rule).

### Bluetooth

**Bar icon:** Grey when idle, blue when connected.

**Dropdown panel:**
- Power toggle (on/off)
- Connected devices list with battery levels, disconnect button per device
- Paired (not connected) devices below, click to connect

**Binding:** Astal Bluetooth service — device list, connect/disconnect, power toggle. Battery levels from BlueZ D-Bus properties.

### System Stats

**Bar icons:** Three separate icons in the bar (CPU, memory, temperature) with color-coded thresholds matching current scheme:
- Normal: `#00FF7F`
- Moderate: `#FFFF00`
- High: `#FFA500`
- Warning: `#FF9F0A`
- Critical: `#FF4040`

Thresholds: CPU (45/60/75/90), Memory (45/60/75/90), Temp (50/60/70/85).

**Dropdown panel (unified, opens from any of the three icons):**
- CPU section: usage bar, top 3 processes by CPU
- Memory section: usage bar with used/total, top 3 processes by RSS
- Temperature section: grid of sensor readings (CPU package, GPU edge, NVMe) with color coding

**Binding:** CPU from `/proc/stat`, memory from `/proc/meminfo`, temps from `/sys/class/hwmon` — all via reactive polling (~2s interval). Top processes from `/proc/[pid]/stat` and `/proc/[pid]/status`. Replaces the three shell scripts (`cpu_details.sh`, `memory_details.sh`, `temperature_details.sh`).

### Clock

**Bar display:** Time in `HH:MM` format, Europe/London timezone.

**Dropdown panel:**
- Large time display with full date
- Month calendar with color scheme matching current Waybar config:
  - Months: `#ffead3`
  - Days: `#ecc6d9`
  - Weeks: `#99ffdd`
  - Weekdays: `#ffcc66`
  - Today: `#ff6699`

**Binding:** GLib timeout for time updates. Calendar via GTK4 calendar widget or custom grid.

### Media Player

**Inline bar widget (no dropdown):** Previous/play-pause/next controls with scrolling track title. Hidden when nothing is playing.

**Binding:** Astal MPRIS service — reactive now-playing state and playback controls via playerctl/MPRIS D-Bus.

### Notification Center

**Bar icon:** Bell icon with unread count badge.

**Dropdown panel:**
- Header with "Clear all" and DND toggle
- Notification history list — app name, summary, relative timestamp
- Each notification is dismissible

Replaces dunst — AGS acts as the notification daemon via the freedesktop notifications spec.

**Binding:** Astal Notifd service. Handles both popup toasts (appearing briefly on screen) and persistent history in the dropdown. DND toggle suppresses popups but still logs to history.

### Power Menu

**Bar icon:** Power symbol.

**Dropdown panel (compact list):**
- Lock → `hyprlock`
- Suspend → `systemctl suspend-then-hibernate` (matching current lid close behavior)
- Reboot → `systemctl reboot`
- Log Out → `hyprctl dispatch exit`
- Shutdown → `systemctl poweroff`

## Styling

GTK4 CSS replacing current Waybar `style.css`. Key properties:

- Transparent bar background (`rgba(0, 0, 0, 0)`)
- Module groups with `rgba(15, 27, 53, 0.7)` background, rounded corners (10px)
- Popup panels: `rgba(15, 27, 53, 0.95)` background, 10px border radius
- Drop shadows on module groups and popups
- Font: Liberation Mono / CaskaydiaCove Nerd Font / Font Awesome
- Margins: 5px top, 10px sides (matching current bar)
- Module hover states with `rgba(70, 75, 90, 0.9)`

## Hyprland Integration

Changes to `hypr/hyprland.conf`:
- Replace `exec-once = waybar` with `exec-once = ags run`
- Replace `exec-once = dunst` with nothing (AGS handles notifications)
- Update `SUPER+SHIFT+W` bind to toggle AGS bar
- Keep all other binds unchanged

## Dependencies

- `ags` (v2) — the shell framework
- `astal` libraries: hyprland, wireplumber, network, bluetooth, battery, mpris, notifd
- System: `tlp`, `networkmanager`, `bluez`, `wireplumber`
- Fonts: Liberation Mono, CaskaydiaCove Nerd Font, Font Awesome 6 (already installed)

## What Gets Removed

- `waybar/` directory (config.jsonc, modules.json, style.css, scripts/)
- `dunst` from autostart (AGS replaces it)
- The three polling shell scripts are replaced by native `/proc` and `hwmon` reads
