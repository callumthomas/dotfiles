import { createState } from "gnim"

const [currentPopup, setCurrentPopup] = createState<string | null>(null)

export { currentPopup }

export function closePopup() {
  setCurrentPopup(null)
}

export function togglePopup(name: string) {
  setCurrentPopup((prev: string | null) => prev === name ? null : name)
}
