import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import { Gdk } from "ags/gtk4"
import { createState, createComputed, For, type Accessor } from "gnim"
import { currentPopup, closePopup } from "../bar/PopupManager"
import { appEntries, initAppIndex } from "./AppIndex"
import GLib from "gi://GLib?version=2.0" // used for timeout_add debounce
import { filePaths, initFileIndex } from "./FileIndex"
import { historyCommands, initHistoryIndex } from "./HistoryIndex"
import { fzfMatch, match, matchStrings } from "./FuzzyMatcher"
import { launchApp, openFile, runCommand } from "./launch"
import { LIMITS } from "./config"
import type { AppEntry } from "./AppIndex"

initAppIndex()
initFileIndex()
initHistoryIndex()

type Row =
  | { kind: "app"; entry: AppEntry }
  | { kind: "file"; path: string }
  | { kind: "run"; cmd: string; fromHistory: boolean }

const [query, setQuery] = createState("")
const [selectedIndex, setSelectedIndex] = createState(0)

// File mode runs fzf as a subprocess, which is async. Results arrive out-of-band
// and are stored in this state; rows reads it on file queries.
const [fileResults, setFileResults] = createState<string[]>([])
let fileQueryToken = 0

query.subscribe(() => {
  const q = query.get()
  if (!q.startsWith("/")) {
    // Drop stale file results when leaving file mode so they don't flash
    // on the next file-mode entry.
    if (fileResults.get().length) setFileResults([])
    return
  }
  const token = ++fileQueryToken
  const inner = q.slice(1)
  const files = filePaths.get()
  fzfMatch(inner, files, LIMITS.files).then((paths) => {
    if (token === fileQueryToken) setFileResults(paths)
  })
})

function computeRows(
  q: string,
  apps: AppEntry[],
  fileRes: string[],
  history: string[],
): Row[] {
  if (q.startsWith("!")) {
    const inner = q.slice(1).trim()
    const rows: Row[] = []
    if (inner.length > 0) {
      rows.push({ kind: "run", cmd: inner, fromHistory: false })
    }
    const hits = matchStrings(inner, history, LIMITS.history)
    for (const h of hits) {
      if (h === inner) continue // already at top
      rows.push({ kind: "run", cmd: h, fromHistory: true })
    }
    return rows
  }
  if (q.startsWith("/")) {
    return fileRes.map((path) => ({ kind: "file", path }))
  }
  const hits = match(q, apps, (a) => a.searchHaystack, LIMITS.apps)
  return hits.map((h) => ({ kind: "app", entry: h.item }))
}

function launchRow(row: Row) {
  if (row.kind === "app") launchApp(row.entry)
  else if (row.kind === "file") openFile(row.path)
  else if (row.kind === "run") runCommand(row.cmd)
  setQuery("")
  setSelectedIndex(0)
  closePopup()
}

export default function Launcher(gdkmonitor: Gdk.Monitor) {
  const stateName = `launcher-${gdkmonitor.get_connector()}`

  // rows recomputes on query, appEntries, or fileResults changes. In file mode
  // fileResults is populated asynchronously by the query.subscribe above.
  const rows = createComputed(() => computeRows(query(), appEntries(), fileResults(), historyCommands()))

  let entryRef: Gtk.Entry | null = null

  return (
    <window
      name={stateName}
      gdkmonitor={gdkmonitor}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.LEFT
      }
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.OVERLAY}
      keymode={Astal.Keymode.EXCLUSIVE}
      visible={currentPopup.as((p) => p === stateName)}
      cssClasses={["launcher-window"]}
      $={(self: Astal.Window) => {
        self.connect("notify::visible", () => {
          if (self.visible) {
            setQuery("")
            setSelectedIndex(0)
            if (entryRef) {
              entryRef.set_text("")
              entryRef.grab_focus()
            }
          }
        })
      }}
    >
      <box
        hexpand
        vexpand
        $={(self: Gtk.Box) => {
          const gesture = new Gtk.GestureClick()
          gesture.connect("released", () => closePopup())
          self.add_controller(gesture)
        }}
      >
        <box hexpand />
        <box valign={Gtk.Align.START} hexpand={false}>
          <box
            cssClasses={["launcher-panel"]}
            orientation={Gtk.Orientation.VERTICAL}
            $={(self: Gtk.Box) => {
              const swallow = new Gtk.GestureClick()
              swallow.connect("pressed", (g) => g.set_state(Gtk.EventSequenceState.CLAIMED))
              self.add_controller(swallow)
            }}
          >
            <entry
              cssClasses={["launcher-entry"]}
              placeholderText="Type to search… / for files, ! for commands"
              onActivate={() => {
                const r = rows.get()[selectedIndex.get()]
                if (r) launchRow(r)
              }}
              $={(self: Gtk.Entry) => {
                entryRef = self
                // Debounce query updates so fast typing doesn't flood
                // the reactive chain with intermediate searches.
                let debounceId: number | null = null
                self.connect("changed", () => {
                  if (debounceId !== null) GLib.source_remove(debounceId)
                  debounceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60, () => {
                    debounceId = null
                    setQuery(self.get_text())
                    setSelectedIndex(0)
                    return false
                  })
                })
                const key = new Gtk.EventControllerKey()
                key.connect("key-pressed", (_c, keyval, _code, state) => {
                  const ctrl = (state & Gdk.ModifierType.CONTROL_MASK) !== 0
                  if (keyval === Gdk.KEY_Escape) { closePopup(); return true }
                  if (keyval === Gdk.KEY_Up || (ctrl && keyval === Gdk.KEY_k)) {
                    const n = rows.get().length
                    if (n > 0) setSelectedIndex((i) => (i - 1 + n) % n)
                    return true
                  }
                  if (keyval === Gdk.KEY_Down || (ctrl && keyval === Gdk.KEY_j)) {
                    const n = rows.get().length
                    if (n > 0) setSelectedIndex((i) => (i + 1) % n)
                    return true
                  }
                  if (ctrl && keyval === Gdk.KEY_u) { self.set_text(""); return true }
                  return false
                })
                self.add_controller(key)
              }}
            />
            <Gtk.ScrolledWindow
              cssClasses={["launcher-scroll"]}
              hscrollbarPolicy={Gtk.PolicyType.NEVER}
              vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            >
              <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["launcher-list"]}>
                <For each={rows} id={(row: Row) => {
                  if (row.kind === "app") return `app:${row.entry.desktopFilePath}`
                  if (row.kind === "file") return `file:${row.path}`
                  if (row.kind === "run") return `run:${row.fromHistory ? "h" : "t"}:${row.cmd}`
                  return `unknown:${JSON.stringify(row)}`
                }}>
                  {(row: Row, index: Accessor<number>) => (
                    <box
                      cssClasses={createComputed(() =>
                        selectedIndex() === index() ? ["launcher-row", "selected"] : ["launcher-row"],
                      )}
                    >
                      {renderRow(row)}
                    </box>
                  )}
                </For>
              </box>
            </Gtk.ScrolledWindow>
          </box>
        </box>
        <box hexpand />
      </box>
    </window>
  )
}

function renderRow(row: Row): JSX.Element {
  if (row.kind === "app") {
    const { name, comment, icon } = row.entry
    return (
      <box cssClasses={["launcher-row-inner"]}>
        {icon ? (
          <image iconName={icon} pixelSize={24} cssClasses={["launcher-row-icon"]} />
        ) : (
          <box cssClasses={["launcher-row-icon"]} />
        )}
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
          <label label={name} halign={Gtk.Align.START} cssClasses={["launcher-row-title"]} />
          {comment ? (
            <label
              label={comment}
              halign={Gtk.Align.START}
              cssClasses={["launcher-row-subtitle"]}
              ellipsize={3 /* PANGO_ELLIPSIZE_END */}
            />
          ) : null}
        </box>
      </box>
    )
  }
  if (row.kind === "file") {
    const p = row.path
    const basename = p.split("/").pop() ?? p
    const parent = p.slice(0, p.length - basename.length - 1) || "/"
    return (
      <box cssClasses={["launcher-row-inner"]}>
        <box cssClasses={["launcher-row-icon"]}>
          <label label="" />
        </box>
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
          <label label={basename} halign={Gtk.Align.START} cssClasses={["launcher-row-title"]} />
          <label
            label={parent}
            halign={Gtk.Align.START}
            cssClasses={["launcher-row-subtitle"]}
            ellipsize={3}
          />
        </box>
      </box>
    )
  }
  if (row.kind === "run") {
    return (
      <box cssClasses={["launcher-row-inner"]}>
        <label label={row.fromHistory ? "↺" : "▶"} cssClasses={["launcher-row-icon"]} />
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
          <label label={row.cmd} halign={Gtk.Align.START} cssClasses={["launcher-row-title"]} />
          <label
            label={row.fromHistory ? "history" : "Run typed command"}
            halign={Gtk.Align.START}
            cssClasses={["launcher-row-subtitle"]}
          />
        </box>
      </box>
    )
  }
  return <box />
}
