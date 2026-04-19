import GLib from "gi://GLib?version=2.0"
import Gio from "gi://Gio?version=2.0"
import { createState } from "gnim"
import { APP_DIRS } from "./config"

export interface AppEntry {
  name: string
  exec: string
  icon: string | null
  comment: string | null
  keywords: string[]
  desktopFilePath: string
  searchHaystack: string
}

function parseDesktopFile(path: string): AppEntry | null {
  const kf = new GLib.KeyFile()
  try {
    if (!kf.load_from_file(path, GLib.KeyFileFlags.NONE)) return null
  } catch {
    return null
  }
  const section = "Desktop Entry"
  try {
    if (kf.get_string(section, "Type") !== "Application") return null
  } catch {
    return null
  }
  const getBool = (k: string) => {
    try { return kf.get_boolean(section, k) } catch { return false }
  }
  if (getBool("NoDisplay") || getBool("Hidden")) return null

  const getStr = (k: string): string | null => {
    try { return kf.get_locale_string(section, k, null) } catch { return null }
  }
  const getStrList = (k: string): string[] => {
    try { return kf.get_locale_string_list(section, k, null) } catch { return [] }
  }

  const name = getStr("Name")
  const exec = getStr("Exec")
  if (!name || !exec) return null

  const icon = getStr("Icon")
  const comment = getStr("Comment")
  const keywords = getStrList("Keywords")
  const haystack = [name, keywords.join(" "), comment ?? ""].join(" ")

  return { name, exec, icon, comment, keywords, desktopFilePath: path, searchHaystack: haystack }
}

function scanDir(dir: string): AppEntry[] {
  const file = Gio.File.new_for_path(dir)
  if (!file.query_exists(null)) return []
  const entries: AppEntry[] = []
  let enumerator: Gio.FileEnumerator
  try {
    enumerator = file.enumerate_children(
      "standard::name,standard::type",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
  } catch {
    return []
  }
  while (true) {
    const info = enumerator.next_file(null)
    if (!info) break
    const name = info.get_name()
    if (!name.endsWith(".desktop")) continue
    const entry = parseDesktopFile(`${dir}/${name}`)
    if (entry) entries.push(entry)
  }
  enumerator.close(null)
  return entries
}

// Per-dir map so we can re-scan one directory without touching others.
const perDir = new Map<string, AppEntry[]>()
const [entries, setEntries] = createState<AppEntry[]>([])

function rebuildFlat() {
  const flat: AppEntry[] = []
  for (const list of perDir.values()) flat.push(...list)
  // Dedup by desktop file name (later dirs override earlier per XDG spec).
  const byBasename = new Map<string, AppEntry>()
  for (const e of flat) {
    const base = e.desktopFilePath.split("/").pop()!
    byBasename.set(base, e)
  }
  setEntries(Array.from(byBasename.values()))
}

export function initAppIndex() {
  for (const dir of APP_DIRS) {
    perDir.set(dir, scanDir(dir))
    const file = Gio.File.new_for_path(dir)
    if (!file.query_exists(null)) continue
    try {
      const monitor = file.monitor_directory(Gio.FileMonitorFlags.NONE, null)
      monitor.connect("changed", () => {
        perDir.set(dir, scanDir(dir))
        rebuildFlat()
      })
    } catch (e) {
      console.warn(`AppIndex: failed to monitor ${dir}:`, e)
    }
  }
  rebuildFlat()
}

export { entries as appEntries }
