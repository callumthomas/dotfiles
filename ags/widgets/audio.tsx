import { createBinding, createComputed, For } from "gnim"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import AstalWp from "gi://AstalWp?version=0.1"
import { togglePopup, closePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"
import Slider from "../components/Slider"

const wp = AstalWp.get_default()!
const audio = wp.audio

// ── helpers ──────────────────────────────────────────────────────────────────

function volIcon(vol: number, mute: boolean): string {
  if (mute || vol === 0) return "󰝟"
  if (vol < 0.33) return "󰕿"
  if (vol < 0.66) return "󰖀"
  return "󰕾"
}

function pct(vol: number): string {
  return `${Math.round(vol * 100)}%`
}

// ── bar button ────────────────────────────────────────────────────────────────

export function AudioButton() {
  const speaker = createBinding(audio, "defaultSpeaker")
  const icon = createComputed(() => {
    const sp = speaker()
    if (!sp) return "󰝟"
    return volIcon(sp.volume, sp.mute)
  })

  return (
    <button
      cssClasses={["module-button"]}
      onClicked={() => togglePopup("audio-popup")}
      $={(self: Gtk.Button) => {
        const scrollCtrl = new Gtk.EventControllerScroll()
        scrollCtrl.flags = Gtk.EventControllerScrollFlags.VERTICAL
        scrollCtrl.connect("scroll", (_ctrl, _dx, dy) => {
          const sp = audio.defaultSpeaker
          if (!sp) return false
          sp.volume = Math.max(0, Math.min(1.5, sp.volume - dy * 0.05))
          return true
        })
        self.add_controller(scrollCtrl)
      }}
    >
      <label label={icon} />
    </button>
  )
}

// ── popup ─────────────────────────────────────────────────────────────────────

function SpeakerSection() {
  const speaker = createBinding(audio, "defaultSpeaker")
  const speakers = createBinding(audio, "speakers")

  const volLabel = createComputed(() => {
    const sp = speaker()
    return sp ? pct(sp.volume) : "—"
  })

  const sliderVal = createComputed(() => speaker()?.volume ?? 0)

  return (
    <box vertical cssClasses={["audio-section"]}>
      <label label="Output" cssClasses={["section-header"]} xalign={0} />

      {/* Volume row */}
      <box cssClasses={["audio-volume-row"]}>
        <label
          label={createComputed(() => {
            const sp = speaker()
            return sp ? volIcon(sp.volume, sp.mute) : "󰝟"
          })}
          cssClasses={["audio-icon"]}
        />
        <Slider
          value={sliderVal}
          min={0}
          max={1.5}
          onChange={(v) => {
            const sp = audio.defaultSpeaker
            if (sp) sp.volume = v
          }}
        />
        <label label={volLabel} cssClasses={["audio-pct"]} widthChars={4} />
      </box>

      {/* Device list */}
      <For each={speakers} id={(ep) => ep.id}>
        {(ep) => {
          const isDefault = createBinding(ep, "isDefault")
          return (
            <button
              cssClasses={isDefault.as((d) =>
                d ? ["audio-device", "active"] : ["audio-device"]
              )}
              onClicked={() => {
                ep.isDefault = true
                closePopup()
              }}
            >
              <label label={createBinding(ep, "description").as((d) => d ?? ep.name)} xalign={0} />
            </button>
          )
        }}
      </For>
    </box>
  )
}

function MicSection() {
  const mic = createBinding(audio, "defaultMicrophone")
  const mics = createBinding(audio, "microphones")

  const sliderVal = createComputed(() => mic()?.volume ?? 0)

  return (
    <box vertical cssClasses={["audio-section"]}>
      <label label="Input" cssClasses={["section-header"]} xalign={0} />

      <box cssClasses={["audio-volume-row"]}>
        <label
          label={createComputed(() => {
            const m = mic()
            return m ? (m.mute ? "󰍭" : "󰍬") : "󰍭"
          })}
          cssClasses={["audio-icon"]}
        />
        <Slider
          value={sliderVal}
          min={0}
          max={1}
          onChange={(v) => {
            const m = audio.defaultMicrophone
            if (m) m.volume = v
          }}
        />
        <label
          label={createComputed(() => mic() ? pct(mic()!.volume) : "—")}
          cssClasses={["audio-pct"]}
          widthChars={4}
        />
      </box>

      <For each={mics} id={(ep) => ep.id}>
        {(ep) => {
          const isDefault = createBinding(ep, "isDefault")
          return (
            <button
              cssClasses={isDefault.as((d) =>
                d ? ["audio-device", "active"] : ["audio-device"]
              )}
              onClicked={() => {
                ep.isDefault = true
                closePopup()
              }}
            >
              <label label={createBinding(ep, "description").as((d) => d ?? ep.name)} xalign={0} />
            </button>
          )
        }}
      </For>
    </box>
  )
}

function AppStreamsSection() {
  const streams = createBinding(audio, "streams")
  const hasStreams = streams.as((s) => s.length > 0)

  return (
    <box
      vertical
      cssClasses={["audio-section"]}
      visible={hasStreams}
    >
      <label label="Apps" cssClasses={["section-header"]} xalign={0} />
      <For each={streams} id={(s) => s.id}>
        {(stream) => {
          const sliderVal = createBinding(stream, "volume")
          return (
            <box cssClasses={["audio-volume-row"]}>
              <label
                label={createBinding(stream, "name").as((n) => n.slice(0, 20))}
                cssClasses={["audio-app-name"]}
                xalign={0}
                widthChars={20}
              />
              <Slider
                value={sliderVal}
                min={0}
                max={1.5}
                onChange={(v) => {
                  stream.volume = v
                }}
              />
              <label
                label={sliderVal.as(pct)}
                cssClasses={["audio-pct"]}
                widthChars={4}
              />
            </box>
          )
        }}
      </For>
    </box>
  )
}

export function AudioPopup(gdkmonitor: Gdk.Monitor) {
  return (
    <PopupWindow name="audio-popup" gdkmonitor={gdkmonitor}>
      <box vertical cssClasses={["audio-popup"]}>
        <SpeakerSection />
        <box cssClasses={["popup-divider"]} />
        <MicSection />
        <box cssClasses={["popup-divider"]} />
        <AppStreamsSection />
      </box>
    </PopupWindow>
  )
}
