// Explicit file path: fuzzysort ships only "main" in package.json and no ESM build,
// which esbuild's neutral platform (AGS's bundler) won't resolve by default.
import fuzzysort from "fuzzysort/fuzzysort.js"
import Gio from "gi://Gio?version=2.0"
import GLib from "gi://GLib?version=2.0"

export interface FuzzyHit<T> {
  item: T
  score: number
}

/**
 * In-process fuzzy match for small corpora (apps, history). For large file
 * lists use `fzfMatch` — fuzzysort's JS implementation can't keep up with
 * 100k+ items per keystroke.
 */
export function match<T>(
  query: string,
  items: readonly T[],
  keyFn: (item: T) => string,
  limit: number,
): FuzzyHit<T>[] {
  if (!query) {
    return items.slice(0, limit).map((item) => ({ item, score: 0 }))
  }
  const prepared = items.map((item) => ({ item, target: keyFn(item) }))
  const results = fuzzysort.go(query, prepared, { key: "target", limit })
  return results.map((r) => ({ item: r.obj.item, score: r.score }))
}

export function matchStrings(
  query: string,
  items: readonly string[],
  limit: number,
): string[] {
  if (!query) return items.slice(0, limit)
  const results = fuzzysort.go(query, items, { limit })
  return results.map((r) => r.target)
}

/**
 * Fuzzy match via fzf subprocess. Pipes `items` to fzf's stdin and reads
 * the filter output. For large corpora (e.g. 100k+ file paths) this is
 * ~10x faster than anything we can run in-process from GJS.
 */
export function fzfMatch(
  query: string,
  items: readonly string[],
  limit: number,
): Promise<string[]> {
  if (!query) return Promise.resolve(items.slice(0, limit))
  return new Promise((resolve) => {
    let proc: Gio.Subprocess
    try {
      proc = Gio.Subprocess.new(
        ["fzf", "--filter", query],
        Gio.SubprocessFlags.STDIN_PIPE | Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE,
      )
    } catch (e) {
      console.warn("fzfMatch: spawn failed:", e)
      resolve([])
      return
    }
    const input = GLib.Bytes.new(new TextEncoder().encode(items.join("\n")))
    proc.communicate_async(input, null, (src, res) => {
      try {
        const [, stdout] = src!.communicate_finish(res)
        if (!stdout) {
          resolve([])
          return
        }
        const text = new TextDecoder().decode(stdout.toArray())
        const lines: string[] = []
        let start = 0
        for (let i = 0; i < text.length && lines.length < limit; i++) {
          if (text.charCodeAt(i) === 10 /* \n */) {
            if (i > start) lines.push(text.slice(start, i))
            start = i + 1
          }
        }
        // Trailing line without newline (unlikely but handle it).
        if (start < text.length && lines.length < limit) {
          lines.push(text.slice(start))
        }
        resolve(lines)
      } catch (e) {
        console.warn("fzfMatch: read failed:", e)
        resolve([])
      }
    })
  })
}
