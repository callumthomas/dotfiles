import { createExternal } from "gnim"
import AstalMpris from "gi://AstalMpris?version=0.1"

const mpris = AstalMpris.get_default()

function truncate(s: string, max: number): string {
  return s.length > max ? s.slice(0, max - 1) + "…" : s
}

// ── reactive media state ─────────────────────────────────────────────────────

interface MediaState {
  title: string
  playing: boolean
  visible: boolean
}

let currentPlayer: AstalMpris.Player | null = null

const media = createExternal<MediaState>(
  { title: "", playing: false, visible: false },
  (set) => {
    let propIds: number[] = []
    const statusIds = new Map<AstalMpris.Player, number>()

    function snapshot(p: AstalMpris.Player | null): MediaState {
      if (!p) return { title: "", playing: false, visible: false }
      const t = p.title || p.identity || ""
      const a = p.artist ? ` – ${p.artist}` : ""
      return {
        title: truncate(t + a, 50),
        playing: p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING,
        visible: true,
      }
    }

    function watchProps(p: AstalMpris.Player | null) {
      if (currentPlayer) {
        for (const id of propIds) currentPlayer.disconnect(id)
      }
      propIds = []
      currentPlayer = p
      if (p) {
        const update = () => set(snapshot(p))
        propIds.push(p.connect("notify::title", update))
        propIds.push(p.connect("notify::artist", update))
      }
    }

    function pickBest() {
      const players = mpris.players
      if (!players.length) {
        watchProps(null)
        set(snapshot(null))
        return
      }
      const best =
        players.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PLAYING) ||
        players.find((p) => p.playbackStatus === AstalMpris.PlaybackStatus.PAUSED) ||
        players[0]

      if (best !== currentPlayer) watchProps(best)
      set(snapshot(best))
    }

    function watchStatus(p: AstalMpris.Player) {
      if (!statusIds.has(p)) {
        statusIds.set(p, p.connect("notify::playback-status", pickBest))
      }
    }
    function unwatchStatus(p: AstalMpris.Player) {
      const id = statusIds.get(p)
      if (id !== undefined) { p.disconnect(id); statusIds.delete(p) }
    }

    const listId = mpris.connect("notify::players", () => {
      for (const p of statusIds.keys()) {
        if (!mpris.players.includes(p)) unwatchStatus(p)
      }
      for (const p of mpris.players) watchStatus(p)
      pickBest()
    })

    for (const p of mpris.players) watchStatus(p)
    pickBest()

    return () => {
      mpris.disconnect(listId)
      for (const [p, id] of statusIds) p.disconnect(id)
      if (currentPlayer) {
        for (const id of propIds) currentPlayer.disconnect(id)
      }
    }
  },
)

// ── widget ───────────────────────────────────────────────────────────────────

export default function Media() {
  return (
    <button
      cssClasses={["module-button"]}
      visible={media.as((m) => m.visible)}
      onClicked={() => currentPlayer?.play_pause()}
    >
      <box spacing={6}>
        <label
          label={media.as((m) => m.playing ? "⏸" : "▶")}
          cssClasses={media.as((m) => m.playing ? ["media-playing-icon"] : [])}
        />
        <label
          label={media.as((m) => m.title)}
          cssClasses={["media-title"]}
          ellipsize={3}
          maxWidthChars={30}
        />
      </box>
    </button>
  )
}
