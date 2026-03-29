import { createExternal } from "gnim"
import { execAsync } from "ags/process"

const rewriteRules: [RegExp, string][] = [
  [/^(.*) - Mozilla Firefox$/, "🌎 $1"],
  [/^(.*) — Mozilla Firefox$/, "🌎 $1"],
  [/^(.*) - Delio - Slack$/, "💬 $1"],
  [/^\s*$/, "  ...  "],
]

function rewriteTitle(title: string): string {
  for (const [pattern, replacement] of rewriteRules) {
    if (pattern.test(title)) {
      return title.replace(pattern, replacement)
    }
  }
  return title
}

function truncate(str: string, max: number): string {
  return str.length > max ? str.slice(0, max - 1) + "…" : str
}

function fetchTitle(): Promise<string> {
  return execAsync("hyprctl activewindow -j")
    .then((out) => {
      const win = JSON.parse(out) as { title?: string }
      return win.title ?? ""
    })
    .catch(() => "")
}

const windowTitle = createExternal<string>("", (set) => {
  let cancelled = false

  async function refresh() {
    const title = await fetchTitle()
    if (!cancelled) set(truncate(rewriteTitle(title), 50))
  }

  const timer = setInterval(refresh, 500)
  refresh()

  return () => {
    cancelled = true
    clearInterval(timer)
  }
})

export default function WindowTitle() {
  return (
    <box cssClasses={["window-title"]}>
      <label label={windowTitle} />
    </box>
  )
}
