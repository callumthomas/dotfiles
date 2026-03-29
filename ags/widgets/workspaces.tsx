import { createBinding, createComputed, For } from "gnim"
import AstalHyprland from "gi://AstalHyprland?version=0.1"

const hypr = AstalHyprland.get_default()!

// Reactive list of workspaces sorted by id (positive ids only)
const workspaces = createBinding(hypr, "workspaces").as((ws) =>
  ws.filter((w) => w.id > 0).sort((a, b) => a.id - b.id)
)

// Reactive focused workspace id
const focusedId = createBinding(hypr, "focusedWorkspace").as((ws) => ws?.id ?? -1)

export default function Workspaces() {
  return (
    <box cssClasses={["workspaces"]}>
      <For each={workspaces} id={(ws) => ws.id}>
        {(ws) => {
          const isActive = createComputed(() => focusedId() === ws.id)
          return (
            <button
              cssClasses={isActive.as((active) =>
                active ? ["workspace-button", "active"] : ["workspace-button"]
              )}
              onClicked={() =>
                hypr.dispatch("workspace", String(ws.id))
              }
            >
              <label label={String(ws.id)} />
            </button>
          )
        }}
      </For>
    </box>
  )
}
