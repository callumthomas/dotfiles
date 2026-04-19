import GioUnix from "gi://GioUnix?version=2.0"
import GLib from "gi://GLib?version=2.0"
import type { AppEntry } from "./AppIndex"

export function launchApp(entry: AppEntry): void {
  const info = GioUnix.DesktopAppInfo.new_from_filename(entry.desktopFilePath)
  if (!info) {
    console.warn(`launchApp: could not load ${entry.desktopFilePath}`)
    return
  }
  try {
    info.launch([], null)
  } catch (e) {
    console.warn(`launchApp: launch failed for ${entry.name}:`, e)
  }
}

export function openFile(path: string): void {
  // GLib.shell_quote wraps in single quotes and escapes embedded single quotes.
  const quoted = GLib.shell_quote(path)
  try {
    GLib.spawn_command_line_async(`xdg-open ${quoted}`)
  } catch (e) {
    console.warn(`openFile: failed for ${path}:`, e)
  }
}

export function runCommand(cmd: string): void {
  try {
    // Use sh -c so the user's shell-style input (pipes, &&, env vars) works.
    GLib.spawn_async(
      null,
      ["/bin/sh", "-c", cmd],
      null,
      GLib.SpawnFlags.SEARCH_PATH,
      null,
    )
  } catch (e) {
    console.warn(`runCommand: failed for "${cmd}":`, e)
  }
}
