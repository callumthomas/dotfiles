import GLib from "gi://GLib?version=2.0"

// Exclude patterns shared by the initial fd scan and the inotifywait regex.
// Add project-specific folders here (e.g. "target" for Rust, "vendor" for PHP composer).
// These match path SEGMENTS (not globs); if the segment appears anywhere in a path,
// the path is excluded.
export const FILE_EXCLUDES = [
  ".git",
  "node_modules",
  "vendor",
  "target",
  ".venv",
  "venv",
  "__pycache__",
  "dist",
  "build",
  ".next",
  ".cache",
  ".Trash",
] as const

// Fuzzy-match result limits per mode.
export const LIMITS = {
  apps: 30,
  files: 50,
  history: 20,
} as const

// Application .desktop search roots (missing ones are skipped silently).
export const APP_DIRS = [
  "/usr/share/applications",
  "/usr/local/share/applications",
  `${GLib.get_home_dir()}/.local/share/applications`,
  "/var/lib/flatpak/exports/share/applications",
  `${GLib.get_home_dir()}/.local/share/flatpak/exports/share/applications`,
]
