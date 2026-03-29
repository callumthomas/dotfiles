import { createBinding, createComputed, createExternal } from "gnim"
import AstalMpris from "gi://AstalMpris?version=0.1"

const mpris = AstalMpris.get_default()

// Reactive list accessor
const playerList = createBinding(mpris, "players")

// Reactive best-player: subscribes to list changes AND each player's
// playback-status so we swap to the active player automatically.
const bestPlayer = createExternal<AstalMpris.Player | null>(null, (set) => {
  function update() {
    const players = mpris.players
    if (!players.length) { set(null); return }
    const playing = players.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING)
    if (playing) { set(playing); return }
    const paused = players.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PAUSED)
    if (paused) { set(paused); return }
    set(players[0])
  }

  const statusIds = new Map<AstalMpris.Player, number>()

  function watch(p: AstalMpris.Player) {
    if (!statusIds.has(p)) {
      statusIds.set(p, p.connect("notify::playback-status", update))
    }
  }
  function unwatch(p: AstalMpris.Player) {
    const id = statusIds.get(p)
    if (id !== undefined) { p.disconnect(id); statusIds.delete(p) }
  }

  const listId = mpris.connect("notify::players", () => {
    // Unwatch players that left
    for (const p of statusIds.keys()) {
      if (!mpris.players.includes(p)) unwatch(p)
    }
    // Watch new players
    for (const p of mpris.players) watch(p)
    update()
  })

  for (const p of mpris.players) watch(p)
  update()

  return () => {
    mpris.disconnect(listId)
    for (const [p, id] of statusIds) p.disconnect(id)
    statusIds.clear()
  }
})

// ── helpers ───────────────────────────────────────────────────────────────────

function truncate(s: string, max: number): string {
  return s.length > max ? s.slice(0, max - 1) + "…" : s
}

function playPauseIcon(status: AstalMpris.PlaybackStatus): string {
  return status === AstalMpris.PlaybackStatus.PLAYING ? "⏸" : "▶"
}

// ── widget ────────────────────────────────────────────────────────────────────
//
// For reactive title / status / can-X we create per-player bindings when the
// best player changes, falling back to empty values when there is none.

function PlayerControls({ player }: { player: AstalMpris.Player }) {
  const title = createComputed(() => {
    const t = player.title || player.identity || ""
    const a = player.artist ? ` – ${player.artist}` : ""
    return truncate(t + a, 50)
  })
  // We need a reactive title — bind the player's title property
  const reactiveTitle = createBinding(player, "title").as((t) => {
    const a = player.artist ? ` – ${player.artist}` : ""
    return truncate((t || player.identity || "") + a, 50)
  })
  const status = createBinding(player, "playbackStatus")
  const canPrev = createBinding(player, "canGoPrevious")
  const canNext = createBinding(player, "canGoNext")
  const canCtrl = createBinding(player, "canControl")

  return (
    <>
      <button
        cssClasses={["media-btn"]}
        sensitive={canPrev}
        onClicked={() => player.previous()}
      >
        <label label="⏮" />
      </button>

      <button
        cssClasses={["media-btn", "media-play"]}
        sensitive={canCtrl}
        onClicked={() => player.play_pause()}
      >
        <label label={status.as(playPauseIcon)} />
      </button>

      <button
        cssClasses={["media-btn"]}
        sensitive={canNext}
        onClicked={() => player.next()}
      >
        <label label="⏭" />
      </button>

      <label
        label={reactiveTitle}
        cssClasses={["media-title"]}
        ellipsize={3}
        maxWidthChars={30}
      />
    </>
  )
}

export default function Media() {
  const hasPlayer = bestPlayer.as((p) => p !== null)

  return (
    <box cssClasses={["media-bar"]} visible={hasPlayer}>
      {bestPlayer.as((player) => {
        if (!player) return <box />
        return <PlayerControls player={player} />
      })}
    </box>
  )
}
