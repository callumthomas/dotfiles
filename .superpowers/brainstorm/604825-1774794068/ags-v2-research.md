# AGS v2/v3 (Astal) Research - Wayland Bar on Hyprland

## 1. Project Setup

### Installation (Arch Linux)

```sh
yay -S aylurs-gtk-shell-git
# Dependencies:
sudo pacman -Syu npm meson ninja go gobject-introspection \
    gtk3 gtk-layer-shell gtk4 gtk4-layer-shell
```

Astal libraries are installed separately (or via nix flake). Key packages:
- `astal-io`, `astal3`, `astal4` (core)
- `astal-hyprland`, `astal-wireplumber`, `astal-network`, `astal-bluetooth`,
  `astal-battery`, `astal-mpris`, `astal-notifd`, `astal-tray`, `astal-powerprofiles`

### Initialize a Project

```sh
ags init -d ~/.config/ags        # creates GTK4 template by default
ags types -u -d ~/.config/ags    # generates TypeScript type definitions
```

### File Structure (Production Pattern)

```
~/.config/ags/
  app.tsx              # entry point (ags run uses this by default)
  env.d.ts             # module declarations (*.scss, *.css, *.blp)
  tsconfig.json        # TypeScript configuration
  style.scss           # global styles (SCSS supported natively)
  widgets/
    bar/
      index.tsx        # Bar window component
      Workspaces.tsx   # workspace indicator
      Clients.tsx      # active window icons
      Clock.tsx        # clock widget
    popups/
      backdrop.tsx     # click-away backdrop
      audio/
      network/
      bluetooth/
      notifications/
  lib/
    popup-manager.ts   # toggle/close popup logic
    constants.ts       # shared configuration
```

### tsconfig.json

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "strict": true,
    "module": "ES2022",
    "target": "ES2020",
    "lib": ["ES2023"],
    "moduleResolution": "Bundler",
    "jsx": "react-jsx",
    "jsxImportSource": "ags/gtk4"
  }
}
```

### env.d.ts

```typescript
declare const SRC: string

declare module "inline:*" {
  const content: string
  export default content
}

declare module "*.scss" {
  const content: string
  export default content
}

declare module "*.css" {
  const content: string
  export default content
}
```

### Running

```sh
ags run                           # runs ~/.config/ags/app.tsx
ags run ./mybar.tsx               # runs single file
ags toggle window-name            # toggle a named window
ags request my-command            # send request to running instance
```

---

## 2. JSX/TSX Syntax for GTK4 Widgets

AGS uses **Gnim** - a library that brings JSX to GJS (GNOME JavaScript). The syntax
is React-like but renders to GTK4 widgets.

### Entry Point Pattern

```typescript
import app from "ags/gtk4/app"
import style from "./style.scss"

app.start({
  css: style,
  requestHandler(request: string, res: (response: any) => void) {
    if (request === "toggle-launcher") {
      // handle custom commands
      res("ok")
    } else {
      res("unknown command")
    }
  },
  main() {
    // Instantiate all windows here. Return them as an array.
    return [
      <Bar />,
      <PopupBackdrop />,
      <AudioPopup />,
    ]
  },
})
```

### JSX Widget Basics

```typescript
// Functional components (lowercase = GTK widget, Uppercase = custom component)
function MyButton() {
  return (
    <button onClicked={(self) => console.log(self, "clicked")}>
      <label label="Click me!" />
    </button>
  )
}

// Nesting
function MyBar() {
  return (
    <window visible>
      <box>
        Click The button
        <MyButton />
      </box>
    </window>
  )
}

// Props
type Props = {
  myprop: string
  children?: JSX.Element | Array<JSX.Element>
}
function MyWidget({ myprop, children }: Props) {
  return <box>{children}</box>
}
```

### GTK4 Widgets Available as JSX Elements

All lowercase JSX tags map to GTK4 widgets:
- `<window>` -> Astal.Window (layer-shell window)
- `<box>` -> Gtk.Box
- `<label>` -> Gtk.Label
- `<button>` -> Gtk.Button
- `<image>` -> Gtk.Image
- `<centerbox>` -> Gtk.CenterBox
- `<scale>` -> Gtk.Scale (slider)
- `<entry>` -> Gtk.Entry (text input)
- `<scrollable>` -> Gtk.ScrolledWindow

### CenterBox Pattern (common for bars)

```typescript
<centerbox cssClasses={["centerbox"]}>
  <box $type="start" halign={Gtk.Align.START}>
    {/* left side widgets */}
  </box>
  <box $type="center">
    {/* center widgets */}
  </box>
  <box $type="end" halign={Gtk.Align.END}>
    {/* right side widgets */}
  </box>
</centerbox>
```

### Conditional & List Rendering

```typescript
// Conditional
<box>{condition ? <True /> : <False />}</box>
<box>{condition && <Widget />}</box>

// Static list
<box>
  {items.map((item) => <label label={item} />)}
</box>
```

### Event Controllers (GTK4 pattern)

```typescript
import Gtk from "gi://Gtk"
import Gdk from "gi://Gdk"

<box>
  <Gtk.GestureClick
    propagationPhase={Gtk.PropagationPhase.CAPTURE}
    button={Gdk.BUTTON_PRIMARY}
    onPressed={() => print("clicked")}
  />
</box>
```

---

## 3. Layer-Shell Windows

Astal.Window extends GtkWindow with wlr-layer-shell support.

### Window Properties

| Property      | Type                  | Description |
|---------------|-----------------------|-------------|
| `anchor`      | Astal.WindowAnchor    | Edges to anchor to (bitfield: TOP, BOTTOM, LEFT, RIGHT) |
| `exclusivity` | Astal.Exclusivity     | NORMAL (0), EXCLUSIVE (1), IGNORE (2) |
| `layer`       | Astal.Layer           | BACKGROUND (0), BOTTOM (1), TOP (2), OVERLAY (3) |
| `keymode`     | Astal.Keymode         | NONE (0), EXCLUSIVE (1), ON_DEMAND (2) |
| `monitor`     | int                   | Monitor index (CAUTION: may differ from compositor) |
| `gdkmonitor`  | Gdk.Monitor           | GdkMonitor object (preferred for multi-monitor) |
| `namespace`   | string                | Layer-shell namespace for compositor rules |
| `margin-*`    | int                   | Top/bottom/left/right margins |
| `visible`     | boolean               | Show/hide the window |
| `name`        | string                | Window name (for CLI toggle) |
| `application` | Gtk.Application       | Required for CLI toggle support |

### Bar Window (anchored to top, exclusive zone)

```typescript
import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"

function Bar({ monitor }: { monitor: Gdk.Monitor }) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible
      namespace={`ags-bar-${monitor.connector}`}
      name={`bar-${monitor.connector}`}
      cssClasses={["Bar"]}
      gdkmonitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox>
        {/* bar content */}
      </centerbox>
    </window>
  )
}
```

### Popup Window (overlay, no exclusive zone)

```typescript
function AudioPopup() {
  const { TOP, RIGHT } = Astal.WindowAnchor

  return (
    <window
      visible={false}
      namespace="ags-audio-popup"
      name="audio-popup"
      cssClasses={["AudioPopup"]}
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.ON_DEMAND}
      application={app}
    >
      {/* popup content */}
    </window>
  )
}
```

### Click-Away Backdrop

```typescript
function PopupBackdrop() {
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  const win = (
    <window
      visible={false}
      namespace="popup-backdrop"
      name="popup-backdrop"
      cssClasses={["PopupBackdrop"]}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.ON_DEMAND}
      application={app}
    >
      <box hexpand vexpand />
    </window>
  ) as Astal.Window

  const clickController = new Gtk.GestureClick()
  clickController.connect("released", () => closeAllPopups())
  win.add_controller(clickController)

  return win
}
```

---

## 4. Astal Libraries API Reference

### 4.1 astal-hyprland

```typescript
import AstalHyprland from "gi://AstalHyprland"
const hypr = AstalHyprland.get_default()
```

**Hyprland class properties:**
- `monitors` - list of Monitor objects
- `workspaces` - list of Workspace objects
- `clients` - list of Client objects (windows)
- `focused-workspace` - currently active workspace
- `focused-monitor` - currently active monitor
- `focused-client` - currently active client
- `cursor-position` - mouse coordinates

**Hyprland class methods:**
- `get_monitors()`, `get_workspaces()`, `get_clients()`
- `get_monitor(id)`, `get_workspace(id)`, `get_client(address)`
- `get_monitor_by_name(name)`, `get_workspace_by_name(name)`
- `get_focused_workspace()`, `get_focused_monitor()`, `get_focused_client()`
- `dispatch(action, args)` - execute Hyprland dispatcher
- `message(cmd)` / `message_async(cmd)` - send IPC command

**Hyprland signals:**
- `event` - generic event
- `workspace-added`, `workspace-removed`
- `client-added`, `client-removed`
- `monitor-added`, `monitor-removed`
- `client-moved`, `floating`, `urgent`, `minimize`
- `submap`, `keyboard-layout`, `config-reloaded`

**Workspace class:**
- Properties: `id`, `name`, `monitor`, `clients`, `has-fullscreen`, `last-client`
- Methods: `focus()`, `move_to(monitor)`
- Signals: `removed`

**Client class:**
- Properties: `address`, `title`, `class`, `initial-class`, `initial-title`,
  `workspace`, `monitor`, `x`, `y`, `width`, `height`, `floating`, `fullscreen`,
  `pinned`, `mapped`, `hidden`, `xwayland`, `pid`, `focus-history-id`
- Methods: `kill()`, `focus()`, `move_to(workspace)`, `toggle_floating()`
- Signals: `removed`, `moved-to`

**Monitor class:**
- Properties: `id`, `name`, `description`, `make`, `model`, `serial`,
  `width`, `height`, `refresh-rate`, `x`, `y`, `scale`, `transform`,
  `active-workspace`, `special-workspace`, `focused`, `dpms-status`
- Methods: `focus()`
- Signals: `removed`

**Workspaces Widget Example:**

```typescript
import { createBinding, For } from "ags"
import AstalHyprland from "gi://AstalHyprland"

function Workspaces({ monitorName }: { monitorName: string }) {
  const hypr = AstalHyprland.get_default()
  const workspaces = createBinding(hypr, "workspaces")
  const focused = createBinding(hypr, "focusedWorkspace")

  const filtered = workspaces((wss: any[]) =>
    wss
      .filter((ws) => ws.monitor?.name === monitorName)
      .sort((a, b) => a.id - b.id)
  )

  return (
    <box cssClasses={["workspaces"]}>
      <For each={filtered}>
        {(ws: any) => (
          <button
            cssClasses={focused((fw: any) =>
              fw?.id === ws.id ? ["active"] : ws.get_clients().length > 0 ? ["occupied"] : []
            )}
            onClicked={() => hypr.dispatch("workspace", String(ws.id))}
          >
            <label label={String(ws.id)} />
          </button>
        )}
      </For>
    </box>
  )
}
```

### 4.2 astal-wireplumber

```typescript
import AstalWp from "gi://AstalWp"
const wp = AstalWp.get_default()
const audio = wp.audio
```

**Audio class properties:**
- `default-speaker` (AstalWp.Endpoint)
- `default-microphone` (AstalWp.Endpoint)
- `speakers` (list of Endpoint)
- `microphones` (list of Endpoint)
- `streams` (list of Stream)
- `recorders` (list of Stream)

**Audio signals:**
- `speaker-added`, `speaker-removed`
- `microphone-added`, `microphone-removed`
- `stream-added`, `stream-removed`
- `recorder-added`, `recorder-removed`

**Endpoint (Node) class:**
- Properties: `volume` (double 0-1), `mute` (boolean), `description` (string),
  `icon` (string), `volume-icon` (string), `name`, `id`, `state`, `media-class`,
  `channels` (list), `lock-channels` (boolean)
- Methods: `set_volume(v)`, `set_mute(b)`, `get_volume()`, `get_mute()`
- Device-specific: `is-default` (boolean), `device`, `routes`
- Methods: `set_is_default(true)` to make default device

**Volume Control Example:**

```typescript
const speaker = AstalWp.get_default()!.audio.default_speaker
// Read volume
print(speaker.volume)  // 0.0 - 1.0
// Set volume
speaker.set_volume(0.5)
// Toggle mute
speaker.mute = !speaker.mute
// Bind reactively
const vol = createBinding(speaker, "volume")
const icon = createBinding(speaker, "volume-icon")
```

**IMPORTANT:** AstalWp initializes asynchronously. Lists are initially empty.
It emits the `ready` signal once initial data has been loaded.

### 4.3 astal-network

```typescript
import AstalNetwork from "gi://AstalNetwork"
const network = AstalNetwork.get_default()
```

**Network class properties:**
- `wifi` (Wifi object)
- `wired` (Wired object)
- `primary` (AstalNetwork.Primary enum: WIFI, WIRED, UNKNOWN)
- `connectivity`
- `state`

**Wifi class properties:**
- `ssid`, `strength`, `frequency`, `bandwidth`
- `enabled`, `scanning`, `is-hotspot`
- `icon-name`, `state`, `internet`
- `access-points`, `active-access-point`, `active-connection`
- Methods: `scan()`, `set_enabled(bool)`

**Wifi signals:**
- `access-point-added`, `access-point-removed`, `state-changed`

**Network Icon Example:**

```typescript
const nw = AstalNetwork.get_default()
// Determine which icon to show based on primary connection
if (nw.primary === AstalNetwork.Primary.WIFI) {
  return nw.wifi.icon_name
} else if (nw.primary === AstalNetwork.Primary.WIRED) {
  return nw.wired.icon_name
} else {
  return "network-idle-symbolic"
}
```

### 4.4 astal-bluetooth

```typescript
import AstalBluetooth from "gi://AstalBluetooth"
const bluetooth = AstalBluetooth.get_default()
```

**Bluetooth class:**
- `get_devices()` - list all known devices
- `is-connected` - whether any device is connected

**Device properties:**
- `name`, `address`, `connected`, `paired`, `icon`

### 4.5 astal-battery

```typescript
import AstalBattery from "gi://AstalBattery"
const battery = AstalBattery.get_default()
```

**Device class properties:**
- `percentage` (double 0-1, **not 0-100**)
- `state` (enum: charging, discharging, full, etc.)
- `charging` (boolean - true if charging or fully charged)
- `icon-name` (string)
- `time-to-full` (uint64, seconds)
- `time-to-empty` (uint64, seconds)
- `is-present` (boolean)
- `is-battery` (boolean)
- `energy`, `energy-full`, `energy-rate`, `voltage`, `temperature`
- `device-type`, `capacity`, `technology`, `warning-level`

**Battery Widget Example:**

```typescript
import { createBinding } from "ags"
import AstalBattery from "gi://AstalBattery"

function BatteryWidget() {
  const bat = AstalBattery.get_default()
  const percentage = createBinding(bat, "percentage")
  const icon = createBinding(bat, "icon-name")
  const visible = createBinding(bat, "is-present")

  return (
    <box visible={visible} cssClasses={["battery"]}>
      <image iconName={icon} />
      <label label={percentage((p) => `${Math.round(p * 100)}%`)} />
    </box>
  )
}
```

### 4.6 astal-mpris

```typescript
import AstalMpris from "gi://AstalMpris"
const player = AstalMpris.Player.new("spotify")
```

**Player class properties:**
- `available` (boolean), `identity` (string), `entry` (string)
- `title`, `artist`, `album`, `album-artist`, `composer`, `lyrics`
- `art-url`, `cover-art` (cached local path)
- `length` (seconds), `position` (seconds)
- `playback-status` (Playing/Paused/Stopped)
- `volume` (0-1), `rate`
- `can-play`, `can-pause`, `can-go-next`, `can-go-previous`, `can-seek`, `can-control`
- `loop-status`, `shuffle-status`

**Player methods:**
- `play()`, `pause()`, `play_pause()`, `stop()`
- `next()`, `previous()`
- `set_position(seconds)`, `set_volume(0-1)`
- `loop()` (cycle: none -> track -> playlist -> none)
- `shuffle()` (toggle)
- `raise()`, `quit()`

### 4.7 astal-notifd

```typescript
import AstalNotifd from "gi://AstalNotifd"
const notifd = AstalNotifd.get_default()
```

**Notifd class:**
- Properties: `notifications` (list), `ignore-timeout`, `dont-disturb`, `default-timeout`
- Methods: `get_notification(id)`, `get_notifications()`
- Signals: `notified` (emitted with id), `resolved` (emitted with id)

**Notification class:**
- Properties: `id`, `app-name`, `app-icon`, `summary`, `body`, `actions` (list),
  `urgency` (LOW/NORMAL/CRITICAL), `image`, `time` (unix timestamp),
  `expire-timeout`, `category`, `desktop-entry`, `transient`, `resident`
- Methods: `dismiss()`, `expire()`, `invoke(action_id)`
- Signals: `resolved`, `invoked`

**Notification Handling Example:**

```typescript
notifd.connect("notified", (_, id) => {
  const n = notifd.get_notification(id)
  print(n.summary, n.body)
  // n.urgency === AstalNotifd.Urgency.CRITICAL
  // n.actions is a list of Action objects
  // n.dismiss() to dismiss, n.invoke(actionId) to invoke action
})
```

### 4.8 astal-tray

```typescript
import AstalTray from "gi://AstalTray"
const tray = AstalTray.get_default()
```

- `get_items()` - list tray items
- Signals: `item-added(id)`, `item-removed(id)`
- `get_item(id)` returns TrayItem with: `title`, `gicon`, `menu_model`, `action_group`

**System Tray Example:**

```typescript
const tray = AstalTray.get_default()
const trayItems = new Map<string, Gtk.MenuButton>()

tray.connect("item-added", (_, id) => {
  const item = tray.get_item(id)
  const popover = Gtk.PopoverMenu.new_from_model(item.menu_model)
  const icon = new Gtk.Image()
  const button = new Gtk.MenuButton({ popover, child: icon })

  item.bind_property("gicon", icon, "gicon", GObject.BindingFlags.SYNC_CREATE)
  popover.insert_action_group("dbusmenu", item.action_group)
  item.connect("notify::action-group", () => {
    popover.insert_action_group("dbusmenu", item.action_group)
  })

  trayItems.set(id, button)
  trayBox.append(button)
})

tray.connect("item-removed", (_, id) => {
  const button = trayItems.get(id)
  if (button) {
    trayBox.remove(button)
    button.run_dispose()
    trayItems.delete(id)
  }
})
```

---

## 5. Reactive State & Bindings

### createState (local component state)

```typescript
import { createState, createComputed } from "ags"

function Counter() {
  const [count, setCount] = createState(0)

  function increment() {
    setCount((v) => v + 1)
  }

  const label = createComputed(() => count().toString())

  return (
    <box>
      <label label={label} />
      <button onClicked={increment}>Click to increment</button>
    </box>
  )
}
```

- `createState(initial)` returns `[Accessor<T>, (v: T | (prev: T) => T) => void]`
- `accessor()` reads value and tracks dependency in reactive scopes
- `accessor.peek()` reads without tracking

### createBinding (bind to GObject properties)

```typescript
import { createBinding } from "ags"

// Bind to a GObject property - returns an Accessor
const percentage = createBinding(battery, "percentage")

// Use in JSX - transforms the value
<label label={percentage((p) => `${Math.round(p * 100)}%`)} />

// Use with cssClasses
<button cssClasses={focused((fw) => fw?.id === ws.id ? ["active"] : [])} />
```

### createPoll (polling external commands/functions)

```typescript
import { createPoll } from "ags/time"

// Poll a shell command every 1000ms
const date = createPoll("", 1000, `date "+%H:%M"`)

// Poll a function every 1000ms
const time = createPoll("--:--", 1000, () => {
  const now = GLib.DateTime.new_now_local()
  return now ? now.format("%I:%M %p") || "--:--" : "--:--"
})

<label label={time} />
```

### createComputed (derived state)

```typescript
import { createComputed } from "ags"

const label = createComputed(() => count().toString())
// Automatically re-evaluates when count() changes
```

### For / With Components (dynamic reactive rendering)

```typescript
import { For, With, Accessor } from "ags"

// For - renders a list reactively
<For each={listAccessor}>
  {(item, index: Accessor<number>) => (
    <label label={index((i) => `${i}. ${item}`)} />
  )}
</For>

// With - renders a single value reactively
<With value={valueAccessor}>
  {(value) => value && <label label={value.member} />}
</With>
```

### GObject Property Binding (low-level)

```typescript
import GObject from "gi://GObject"
const SYNC = GObject.BindingFlags.SYNC_CREATE

// Bind GObject property to another GObject property
battery.bind_property("icon-name", widget, "icon-name", SYNC)
battery.bind_property("is-present", widget, "visible", SYNC)

// With transform
object.bind_property_full("property", target, "target-prop", SYNC,
  (_, value) => {
    // transform forward
    return [true, transformedValue]
  },
  null
)
```

### GObject Signal Connection

```typescript
const id = object.connect("notify::property-name", () => {
  // property changed
})
// Cleanup
object.disconnect(id)
// Or on destroy:
widget.connect("destroy", () => object.disconnect(id))
```

---

## 6. GTK4 CSS Theming

### Loading CSS

```typescript
// Method 1: Import SCSS (AGS handles compilation)
import style from "./style.scss"
app.start({ css: style, ... })

// Method 2: Manual CssProvider
import Gtk from "gi://Gtk"
import Gdk from "gi://Gdk"

const provider = new Gtk.CssProvider()
provider.load_from_resource("/style.css")  // or load_from_string(cssString)
Gtk.StyleContext.add_provider_for_display(
  Gdk.Display.get_default()!,
  provider,
  Gtk.STYLE_PROVIDER_PRIORITY_USER,
)
```

### CSS Classes on Widgets

```typescript
// Use cssClasses prop (array of strings)
<window cssClasses={["Bar"]}>
<button cssClasses={["active", "workspace-button"]}>
<label cssClasses={focused((fw) => fw?.id === id ? ["active"] : [])} />

// Programmatic
widget.add_css_class("my-class")
widget.remove_css_class("my-class")
```

### GTK4 CSS Subset

GTK4 CSS supports a **subset** of web CSS. Key supported features:

```scss
// Layout
margin, padding, min-width, min-height, min-height

// Colors & backgrounds
color, background, background-color, opacity
background: linear-gradient(...)

// Borders
border, border-radius, border-color, border-width

// Typography
font-family, font-size, font-weight

// Box shadow
box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);

// Transitions & animations
transition: background 150ms ease;
animation: wiggle 2s linear infinite;
@keyframes wiggle { ... }

// Transforms (in animations)
transform: rotateZ(-15deg);
```

### SCSS Theming Pattern

```scss
$bg-dark: #0d0d0d;
$bg-surface: #121218;
$bg-elevated: #1a1a2e;
$text-primary: #e0e0e0;
$accent: #9d4edd;
$border-subtle: rgba(255, 255, 255, 0.06);

window.Bar {
  background: transparent;
  color: $text-primary;
  font-family: "JetBrains Mono Nerd Font", monospace;
  font-size: 13px;

  .centerbox {
    background: $bg-dark;
    border-bottom: 2px solid $accent;
    min-height: 36px;
    padding: 0 12px;
  }

  .workspaces button {
    min-width: 28px;
    min-height: 26px;
    border-radius: 6px;
    background: transparent;

    &.active {
      background: linear-gradient(135deg, $accent, darken($accent, 10%));
      color: #ffffff;
    }

    &.occupied {
      color: $accent;
      background: rgba($accent, 0.1);
    }
  }
}

// Popup styling
@mixin popup-content {
  background: rgba(18, 18, 24, 0.98);
  border: 1px solid $border-subtle;
  border-radius: 12px;
  padding: 16px;
  margin: 8px;  // margin from screen edge
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
}

window.AudioPopup { @include popup-content; }
```

**Important CSS limitations in GTK4:**
- No flexbox/grid layout (use Gtk.Box with orientation)
- No `display`, `position`, `z-index`
- `min-height: 0; min-width: 0;` needed to shrink buttons below default size
- Use `hexpand`/`vexpand` props on widgets instead of CSS flex

---

## 7. Window Toggle (Show/Hide)

### Method 1: Via app.get_window() (programmatic)

```typescript
import app from "ags/gtk4/app"

function togglePopup(name: string): void {
  const popup = app.get_window(name)
  if (!popup) return
  popup.visible = !popup.visible
}

// Close all popups
function closeAllPopups(): void {
  const POPUP_NAMES = ["audio-popup", "wifi-popup", "bluetooth-popup"]
  POPUP_NAMES.forEach(name => {
    const popup = app.get_window(name)
    if (popup?.visible) popup.visible = false
  })
  const backdrop = app.get_window("popup-backdrop")
  if (backdrop) backdrop.visible = false
}
```

**Requirement:** Windows must have `name` prop and `application={app}` for this to work.

### Method 2: Via CLI

```sh
ags toggle window-name     # toggles visibility
```

### Method 3: Via requestHandler

```typescript
// In app.start():
requestHandler(request: string, res: (response: any) => void) {
  if (request === "toggle-launcher") {
    toggleLauncher()
    res("ok")
  }
}

// From shell:
// ags request toggle-launcher
```

### Method 4: Via Hyprland keybind

```
# hyprland.conf
bind = SUPER, B, exec, ags toggle bar
bind = SUPER, A, exec, ags request toggle-launcher
```

---

## 8. Multi-Monitor Support

### Pattern: Create bar per GdkMonitor

```typescript
import app from "ags/gtk4/app"
import Gdk from "gi://Gdk?version=4.0"

app.start({
  main() {
    const monitors = app.get_monitors()
    return [
      ...monitors.map((monitor: Gdk.Monitor) => <Bar monitor={monitor} />),
      // popup windows (shared across monitors)
      <PopupBackdrop />,
      <AudioPopup />,
    ]
  },
})
```

### Bar component receives GdkMonitor

```typescript
function Bar({ monitor }: { monitor: Gdk.Monitor }) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
  const monitorName = monitor.connector || "unknown"

  return (
    <window
      visible
      gdkmonitor={monitor}       // <-- use gdkmonitor, not monitor (int)
      namespace={`ags-bar-${monitorName}`}
      name={`bar-${monitorName}`}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox>
        <Workspaces monitorName={monitorName} />
      </centerbox>
    </window>
  )
}
```

### Filter workspaces per monitor

```typescript
function Workspaces({ monitorName }: { monitorName: string }) {
  const hypr = AstalHyprland.get_default()
  const workspaces = createBinding(hypr, "workspaces")
  const focused = createBinding(hypr, "focusedWorkspace")

  const filtered = workspaces((wss: any[]) =>
    wss
      .filter((ws) => ws.monitor?.name === monitorName)
      .sort((a, b) => a.id - b.id)
  )

  return (
    <box cssClasses={["workspaces"]}>
      <For each={filtered}>
        {(ws: any) => (
          <button
            cssClasses={focused((fw: any) =>
              fw?.id === ws.id ? ["active"] : []
            )}
            onClicked={() => hypr.dispatch("workspace", String(ws.id))}
          >
            <label label={String(ws.id)} />
          </button>
        )}
      </For>
    </box>
  )
}
```

### GdkMonitor vs Hyprland Monitor Mapping

**Known issue:** GDK monitor IDs may not match Hyprland monitor IDs. Solutions:
1. **Use `monitor.connector`** (e.g., "DP-1", "HDMI-A-1") to match by name
2. **Use `gdkmonitor` prop** on window instead of integer `monitor` prop
3. Match Hyprland monitors by name: `hypr.get_monitor_by_name("DP-1")`

### Handle monitor hotplug

Listen for `monitor-added` / `monitor-removed` signals on the Hyprland object,
or use `app.get_monitors()` on startup. GTK also emits signals when displays change.
