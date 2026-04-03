import { type Accessor } from "gnim"

interface SliderProps {
  value: number | Accessor<number>
  onChange: (value: number) => void
  min?: number
  max?: number
  step?: number
}

/**
 * Wraps Astal.Slider (which extends Gtk.Scale).
 * Available as the `<slider>` intrinsic element in gnim gtk4 JSX.
 */
export default function Slider({ value, onChange, min = 0, max = 1, step = 0.01 }: SliderProps) {
  return (
    <slider
      value={value}
      min={min}
      max={max}
      step={step}
      drawValue={false}
      hexpand
      onChangeValue={(_self, _scroll, newVal) => {
        onChange(newVal)
        return false
      }}
    />
  )
}
