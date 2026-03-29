import { createBinding, createComputed } from "gnim"
import AstalHyprland from "gi://AstalHyprland?version=0.1"

const hypr = AstalHyprland.get_default()!

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

// Reactive focused client title — null-safe since there may be no focused client
const windowTitle = createBinding(hypr, "focusedClient").as((client) => {
  const raw = client?.title ?? ""
  return truncate(rewriteTitle(raw), 50)
})

export default function WindowTitle() {
  return (
    <box cssClasses={["window-title"]}>
      <label label={windowTitle} />
    </box>
  )
}
