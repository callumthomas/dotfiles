import { createBinding, createComputed, For } from "gnim"
import { Gdk } from "ags/gtk4"
import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { togglePopup } from "../bar/PopupManager"
import PopupWindow from "../components/PopupWindow"
import ToggleRow from "../components/ToggleRow"

const notifd = AstalNotifd.get_default()

// ── helpers ───────────────────────────────────────────────────────────────────

function relativeTime(unixSec: number): string {
  const diffSec = Math.floor(Date.now() / 1000 - unixSec)
  if (diffSec < 60) return "just now"
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`
  return `${Math.floor(diffSec / 86400)}d ago`
}

// ── bar button ────────────────────────────────────────────────────────────────

export function NotificationsButton() {
  const notifs = createBinding(notifd, "notifications")
  const count = notifs.as((ns) => ns.length)
  const dnd = createBinding(notifd, "dontDisturb")

  const icon = createComputed(() => {
    if (dnd()) return "󰂛"
    return count() > 0 ? "󰂞" : "󰂜"
  })

  const cssClass = createComputed(() => {
    const classes = ["module-button"]
    if (dnd()) classes.push("notif-dnd")
    else if (count() > 0) classes.push("notif-active")
    return classes
  })

  return (
    <button
      cssClasses={cssClass}
      onClicked={() => togglePopup("notifications-popup")}
    >
      <box>
        <label label={icon} />
        <label
          label={count.as((c) => c > 0 ? String(c) : "")}
          cssClasses={["notif-count"]}
          visible={count.as((c) => c > 0)}
        />
      </box>
    </button>
  )
}

// ── popup ─────────────────────────────────────────────────────────────────────

function NotificationItem({ notif }: { notif: AstalNotifd.Notification }) {
  const time = notif.time

  return (
    <box cssClasses={["notif-item"]}>
      <box vertical hexpand>
        {/* Header row */}
        <box cssClasses={["notif-header"]}>
          <label
            label={notif.appName || "Unknown"}
            cssClasses={["notif-app-name"]}
            xalign={0}
            hexpand
          />
          <label
            label={relativeTime(time)}
            cssClasses={["notif-time"]}
          />
        </box>

        {/* Summary */}
        <label
          label={notif.summary}
          cssClasses={["notif-summary"]}
          xalign={0}
          wrap
          wrapMode={2}
        />

        {/* Body (if non-empty) */}
        <label
          label={notif.body}
          cssClasses={["notif-body"]}
          xalign={0}
          visible={notif.body.length > 0}
          wrap
          wrapMode={2}
          maxWidthChars={40}
        />
      </box>

      {/* Dismiss button */}
      <button
        cssClasses={["notif-dismiss"]}
        onClicked={() => notif.dismiss()}
        valign={1} // START
      >
        <label label="✕" />
      </button>
    </box>
  )
}

export function NotificationsPopup(gdkmonitor: Gdk.Monitor) {
  const notifs = createBinding(notifd, "notifications")
  const dnd = createBinding(notifd, "dontDisturb")
  const hasNotifs = notifs.as((ns) => ns.length > 0)

  return (
    <PopupWindow name="notifications-popup" gdkmonitor={gdkmonitor}>
      <box vertical cssClasses={["notifications-popup"]}>
        {/* Header row */}
        <box cssClasses={["notif-popup-header"]}>
          <label label="Notifications" cssClasses={["notif-title"]} hexpand xalign={0} />
          <button
            cssClasses={["notif-clear-btn"]}
            visible={hasNotifs}
            onClicked={() => {
              for (const n of notifd.notifications) {
                n.dismiss()
              }
            }}
          >
            <label label="Clear all" />
          </button>
        </box>

        {/* DND toggle */}
        <ToggleRow
          label="Do Not Disturb"
          active={dnd}
          onToggled={(active) => {
            notifd.dontDisturb = active
          }}
        />

        <box cssClasses={["popup-divider"]} />

        {/* Notification list */}
        <box
          vertical
          cssClasses={["notif-list"]}
          visible={hasNotifs}
        >
          <For
            each={notifs.as((ns) => [...ns].reverse())}
            id={(n) => n.id}
          >
            {(notif) => <NotificationItem notif={notif} />}
          </For>
        </box>

        {/* Empty state */}
        <box
          cssClasses={["notif-empty"]}
          visible={notifs.as((ns) => ns.length === 0)}
        >
          <label label="No notifications" cssClasses={["notif-empty-label"]} />
        </box>
      </box>
    </PopupWindow>
  )
}
