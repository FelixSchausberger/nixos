// ---------------------------------------------------------------------------
// Environment-derived configuration + shared logging.
//
// Everything here is read once at module load from env vars, has no runtime
// state, and depends on nothing else in the plugin.
// ---------------------------------------------------------------------------

export type Phase = "running" | "permission" | "done"

const env = (key: string, def: string) => {
  const v = process.env[key]
  return v && v.length > 0 ? v : def
}

// The four icons. Defaults: hourglass = busy, question = needs you, bell =
// finished and wants your eyes, tick = you've since reviewed it. Override any of
// them with env vars for other glyphs.
export const ICON_RUNNING = env("OPENCODE_ZELLIJ_ICON_RUNNING", "⏳")
export const ICON_PERMISSION = env("OPENCODE_ZELLIJ_ICON_PERMISSION", "❓")
export const ICON_UNSEEN = env("OPENCODE_ZELLIJ_ICON_ATTENTION", "🔔")
export const ICON_SEEN = env("OPENCODE_ZELLIJ_ICON_SEEN", "✅")
export const ALL_ICONS = [
  ICON_RUNNING,
  ICON_PERMISSION,
  ICON_UNSEEN,
  ICON_SEEN,
].filter((i) => i.length)

export const STOPWATCH_ENABLED = process.env.OPENCODE_ZELLIJ_STOPWATCH !== "0"

// Compact tabs by default (status icon only), matching the V1 fork. Set
// OPENCODE_ZELLIJ_TITLE_MAX > 0 to render the session title instead, truncated
// to that many characters so long auto-generated titles cannot overflow
// zjstatus (which has no per-name truncation).
const titleParsed = Number.parseInt(env("OPENCODE_ZELLIJ_TITLE_MAX", "0"), 10)
export const TITLE_MAX = Number.isFinite(titleParsed) && titleParsed > 0 ? titleParsed : 0
export const TITLE_ENABLED = TITLE_MAX > 0

const DEFAULT_POLL_MS = 1500
const pollParsed = Number.parseInt(env("OPENCODE_ZELLIJ_POLL_MS", String(DEFAULT_POLL_MS)), 10)
export const POLL_MS = Number.isFinite(pollParsed) && pollParsed >= 100 ? pollParsed : DEFAULT_POLL_MS

// Debug logging (set OPENCODE_ZELLIJ_DEBUG=1). Goes to opencode's server log,
// not the TUI. Invaluable for diagnosing "why isn't my tab renaming?".
const DEBUG = process.env.OPENCODE_ZELLIJ_DEBUG === "1"
export const log = (msg: string) => {
  if (DEBUG) console.error(`[zellij-indicator] ${msg}`)
}
