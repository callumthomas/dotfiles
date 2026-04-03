import { createBinding, createComputed, For } from "gnim"
import { Gdk } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { execAsync } from "ags/process"
import { togglePopup, closePopup } from "../bar/PopupManager"
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

export function NotificationsButton({ monitor }: { monitor: string }) {
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
      onClicked={() => togglePopup(`notifications-popup-${monitor}`)}
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

function focusAppWindow(notif: AstalNotifd.Notification) {
  // Invoke default action for in-app navigation (e.g. opens specific Slack conversation)
  const defaultAction = notif.actions.find((a) => a.id === "default")
  if (defaultAction) {
    notif.invoke("default")
  }

  // Look up the window address and focus by address — this forces workspace switching
  const query = notif.desktopEntry || notif.appName
  if (query) {
    execAsync(["bash", "-c",
      `hyprctl clients -j | jq -r '.[] | select(.class | test("${query}"; "i")) | .address' | head -1`
    ]).then((addr) => {
      const trimmed = addr.trim()
      if (trimmed) {
        execAsync(["hyprctl", "dispatch", "focuswindow", `address:${trimmed}`])
          .catch(console.error)
      }
    }).catch(console.error)
  }
}

function NotificationItem({ notif }: { notif: AstalNotifd.Notification }) {
  const time = notif.time

  return (
    <button
      cssClasses={["notif-item"]}
      onClicked={() => {
        focusAppWindow(notif)
        notif.dismiss()
        closePopup()
      }}
    >
      <box>
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
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
    </button>
  )
}

export function NotificationsPopup(gdkmonitor: Gdk.Monitor) {
  const notifs = createBinding(notifd, "notifications")
  const dnd = createBinding(notifd, "dontDisturb")
  const hasNotifs = notifs.as((ns) => ns.length > 0)

  return (
    <PopupWindow name={`notifications-popup-${gdkmonitor.get_connector()}`} gdkmonitor={gdkmonitor}>
      <box orientation={Gtk.Orientation.VERTICAL} cssClasses={["notifications-popup"]}>
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
        <Gtk.ScrolledWindow
          vexpand
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
          cssClasses={["notif-scroll"]}
          visible={hasNotifs}
        >
          <box
            orientation={Gtk.Orientation.VERTICAL}
            cssClasses={["notif-list"]}
          >
            <For
              each={notifs.as((ns) => [...ns].sort((a, b) => b.time - a.time))}
              id={(n) => n.id}
            >
              {(notif) => <NotificationItem notif={notif} />}
            </For>
          </box>
        </Gtk.ScrolledWindow>

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
