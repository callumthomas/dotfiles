import { createBinding } from "gnim"
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

// Deep binding: fires both when focused client changes AND when its title changes
const windowTitle = createBinding(hypr, "focusedClient", "title").as((title) =>
  truncate(rewriteTitle(title ?? ""), 50)
)

export default function WindowTitle() {
  return (
    <box cssClasses={["window-title"]}>
      <label label={windowTitle} />
    </box>
  )
}
