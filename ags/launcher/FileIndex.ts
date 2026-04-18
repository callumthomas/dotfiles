import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"
import { createState } from "gnim"
import { FILE_EXCLUDES } from "./config"

const HOME = GLib.get_home_dir()

const [paths, setPaths] = createState<string[]>([])
let internal: string[] = []
let ready = false
const [isReady, setIsReady] = createState(false)

function notify() {
  setPaths(internal.slice())
}

function makeFdArgs(): string[] {
  const excludeArgs: string[] = []
  for (const ex of FILE_EXCLUDES) {
    excludeArgs.push("--exclude", ex)
  }
  return [
    "fd",
    "--type", "f",
    "--type", "d",
    "--hidden",
    "--absolute-path",
    ...excludeArgs,
    ".",
    HOME,
  ]
}

function makeInotifyArgs(): string[] {
  const alt = FILE_EXCLUDES.map((s) => s.replace(/\./g, "\\.")).join("|")
  const excludeRegex = `(^|/)(${alt})(/|$)`
  return [
    "inotifywait",
    "-rm",
    "-e", "create,delete,move",
    "--exclude", excludeRegex,
    HOME,
  ]
}

function streamLines(
  stdin: Gio.InputStream,
  onLine: (line: string) => void,
  onEnd: () => void,
) {
  const stream = new Gio.DataInputStream({ base_stream: stdin })
  const read = () => {
    stream.read_line_async(GLib.PRIORITY_DEFAULT, null, (src, res) => {
      try {
        const [bytes] = src!.read_line_finish(res)
        if (bytes === null) {
          onEnd()
          return
        }
        onLine(new TextDecoder().decode(bytes))
        read()
      } catch (e) {
        console.warn("FileIndex: read_line failed:", e)
        onEnd()
      }
    })
  }
  read()
}

function startInitialScan() {
  const proc = Gio.Subprocess.new(
    makeFdArgs(),
    Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
  )
  streamLines(
    proc.get_stdout_pipe()!,
    (line) => {
      if (line) internal.push(line)
    },
    () => {
      notify()
      ready = true
      setIsReady(true)
    },
  )
  // Periodic flush during long scans so UI isn't totally empty.
  let flushTimer: number | null = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 250, () => {
    if (ready) {
      if (flushTimer !== null) GLib.source_remove(flushTimer)
      return false
    }
    notify()
    return true
  })
}

function handleInotifyLine(line: string) {
  // Format: "<dir> <EVENTS> <filename>"
  const parts = line.split(" ")
  if (parts.length < 3) return
  const dir = parts[0]
  const events = parts[1]
  const name = parts.slice(2).join(" ")
  const full = dir.endsWith("/") ? `${dir}${name}` : `${dir}/${name}`
  if (events.includes("CREATE") || events.includes("MOVED_TO")) {
    internal.push(full)
    notify()
  } else if (events.includes("DELETE") || events.includes("MOVED_FROM")) {
    const idx = internal.indexOf(full)
    if (idx >= 0) {
      internal.splice(idx, 1)
      notify()
    }
  }
}

function startInotifyWatcher() {
  let proc: Gio.Subprocess
  try {
    proc = Gio.Subprocess.new(
      makeInotifyArgs(),
      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
    )
  } catch (e) {
    console.warn("FileIndex: failed to spawn inotifywait:", e)
    return
  }
  streamLines(
    proc.get_stdout_pipe()!,
    handleInotifyLine,
    () => {
      console.warn("FileIndex: inotifywait exited; file index is now static")
    },
  )
  streamLines(
    proc.get_stderr_pipe()!,
    (line) => {
      if (line) console.warn(`inotifywait: ${line}`)
    },
    () => {},
  )
}

export function initFileIndex() {
  startInitialScan()
  startInotifyWatcher()
}

export { paths as filePaths, isReady as fileIndexReady }
