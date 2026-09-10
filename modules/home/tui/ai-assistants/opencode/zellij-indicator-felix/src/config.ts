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

// Truncate session titles added in this fork: auto-generated titles are whole
// sentences and overflow the zjstatus tab bar. Applied where the title enters
// the plugin so every consumer (label, log, rename bookkeeping) sees the same
// short name. Set OPENCODE_ZELLIJ_TITLE_MAX=0 to disable.
export const TITLE_MAX = (() => {
  const n = Number.parseInt(env("OPENCODE_ZELLIJ_TITLE_MAX", "24"), 10)
  return Number.isFinite(n) && n > 0 ? n : 0
})()

export const truncateTitle = (t: string): string =>
  TITLE_MAX > 0 && title_needs_truncation(TITLE_MAX, t) ? `${t.slice(0, TITLE_MAX).trimEnd()}…` : t

const title_needs_truncation = (max: number, t: string) => t.length > max

const DEFAULT_POLL_MS = 1500
const pollParsed = Number.parseInt(env("OPENCODE_ZELLIJ_POLL_MS", String(DEFAULT_POLL_MS)), 10)
export const POLL_MS = Number.isFinite(pollParsed) ? pollParsed : DEFAULT_POLL_MS

// Tools that block waiting for the user (opencode's interactive question / the
// plan-mode "switch to build agent?" prompt). While one of these runs, the
// session is really waiting on you, so show the permission icon rather than the
// running one.
export const ASK_TOOLS = new Set(["question", "plan_exit"])

// Debug logging (set OPENCODE_ZELLIJ_DEBUG=1). Goes to opencode's server log,
// not the TUI. Invaluable for diagnosing "why isn't my tab renaming?".
const DEBUG = process.env.OPENCODE_ZELLIJ_DEBUG === "1"
export const log = (msg: string) => {
  if (DEBUG) console.error(`[zellij-indicator] ${msg}`)
}
