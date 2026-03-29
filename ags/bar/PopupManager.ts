import { App } from "ags/gtk4";

let currentPopup: string | null = null;

export function openPopup(name: string) {
  if (currentPopup && currentPopup !== name) {
    closePopup();
  }
  const win = App.get_window(name);
  if (win) {
    win.visible = true;
    currentPopup = name;
  }
}

export function closePopup() {
  if (currentPopup) {
    const win = App.get_window(currentPopup);
    if (win) {
      win.visible = false;
    }
    currentPopup = null;
  }
}

export function togglePopup(name: string) {
  if (currentPopup === name) {
    closePopup();
  } else {
    openPopup(name);
  }
}
