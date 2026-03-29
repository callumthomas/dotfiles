import { createExternal, For } from "gnim"
import { execAsync } from "ags/process"

interface HyprWorkspace {
  id: number
  name: string
}

function fetchWorkspaces(): Promise<HyprWorkspace[]> {
  return execAsync("hyprctl workspaces -j")
    .then((out) => JSON.parse(out) as HyprWorkspace[])
    .catch(() => [])
}

function fetchActiveId(): Promise<number> {
  return execAsync("hyprctl activeworkspace -j")
    .then((out) => (JSON.parse(out) as { id: number }).id)
    .catch(() => -1)
}

const workspaces = createExternal<HyprWorkspace[]>([], (set) => {
  let cancelled = false

  async function refresh() {
    const ws = await fetchWorkspaces()
    if (!cancelled) set(ws.filter((w) => w.id > 0).sort((a, b) => a.id - b.id))
  }

  const timer = setInterval(refresh, 500)
  refresh()

  return () => {
    cancelled = true
    clearInterval(timer)
  }
})

const activeId = createExternal<number>(-1, (set) => {
  let cancelled = false

  async function refresh() {
    const id = await fetchActiveId()
    if (!cancelled) set(id)
  }

  const timer = setInterval(refresh, 500)
  refresh()

  return () => {
    cancelled = true
    clearInterval(timer)
  }
})

export default function Workspaces() {
  return (
    <box cssClasses={["workspaces"]}>
      <For each={workspaces} id={(ws) => ws.id}>
        {(ws) => (
          <button
            cssClasses={activeId.as((id) =>
              id === ws.id
                ? ["workspace-button", "active"]
                : ["workspace-button"]
            )}
            onClicked={() =>
              execAsync(`hyprctl dispatch workspace ${ws.id}`).catch(
                console.error
              )
            }
          >
            <label label={String(ws.id)} />
          </button>
        )}
      </For>
    </box>
  )
}
