import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import { createState } from "gnim"

const HIST_PATH = `${GLib.get_home_dir()}/.local/share/fish/fish_history`

const [commands, setCommands] = createState<string[]>([])

function parseHistory(text: string): string[] {
  // Fish history is YAML-ish: entries are "- cmd: <command>\n  when: <ts>".
  // Fish encodes embedded backslashes and newlines inside cmd as "\\" and "\n".
  const out: string[] = []
  const seen = new Set<string>()
  const lines = text.split("\n")
  // Walk backwards to dedup keeping the most recent occurrence.
  for (let i = lines.length - 1; i >= 0; i--) {
    const m = lines[i].match(/^- cmd: (.*)$/)
    if (!m) continue
    const raw = m[1]
    const unescaped = raw.replace(/\\n/g, "\n").replace(/\\\\/g, "\\")
    if (seen.has(unescaped)) continue
    seen.add(unescaped)
    out.push(unescaped)
  }
  return out
}

function reload() {
  try {
    const [ok, contents] = GLib.file_get_contents(HIST_PATH)
    if (!ok) {
      setCommands([])
      return
    }
    const text = new TextDecoder().decode(contents)
    setCommands(parseHistory(text))
  } catch (e) {
    console.warn("HistoryIndex: reload failed:", e)
    setCommands([])
  }
}

export function initHistoryIndex() {
  reload()
  try {
    const file = Gio.File.new_for_path(HIST_PATH)
    const monitor = file.monitor_file(Gio.FileMonitorFlags.NONE, null)
    // Debounce: fish writes incrementally; coalesce rapid changes.
    let pending: number | null = null
    monitor.connect("changed", () => {
      if (pending !== null) return
      pending = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 300, () => {
        pending = null
        reload()
        return false
      })
    })
  } catch (e) {
    console.warn("HistoryIndex: monitor failed:", e)
  }
}

export { commands as historyCommands }
