import { type Accessor } from "gnim"

interface ToggleRowProps {
  label: string
  active: boolean | Accessor<boolean>
  onToggled: (active: boolean) => void
}

export default function ToggleRow({ label, active, onToggled }: ToggleRowProps) {
  return (
    <box cssClasses={["toggle-row"]}>
      <label label={label} hexpand xalign={0} />
      <switch
        active={active}
        onNotifyActive={(self) => {
          onToggled(self.active)
        }}
      />
    </box>
  )
}
