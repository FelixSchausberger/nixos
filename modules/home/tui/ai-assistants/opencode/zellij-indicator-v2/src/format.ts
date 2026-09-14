// ---------------------------------------------------------------------------
// Pure presentation helpers: turning state into the strings we render on the
// tab. No runtime state, no side effects, no `$`.
// ---------------------------------------------------------------------------

import {
  ALL_ICONS,
  ICON_PERMISSION,
  ICON_RUNNING,
  ICON_SEEN,
  ICON_UNSEEN,
  STOPWATCH_ENABLED,
  type Phase,
} from "./config"

// Strip any trailing status icon(s) so we recover the clean base tab name.
export function stripIcons(s: string): string {
  let out = s.trimEnd()
  const withoutStopwatch = out.replace(/\s+\(⏱ [^)]+\)$/, "").trimEnd()
  if (ALL_ICONS.some((icon) => withoutStopwatch.endsWith(icon))) out = withoutStopwatch
  let changed = true
  while (changed) {
    changed = false
    for (const ic of ALL_ICONS) {
      if (out.endsWith(ic)) {
        out = out.slice(0, -ic.length).trimEnd()
        changed = true
      }
    }
  }
  return out
}

// Clamp a session title to a fixed character budget, appending an ellipsis
// when it had to be shortened. zjstatus does not truncate tab names, so this
// is the only guard against a long auto-generated title overflowing the bar.
export function truncateTitle(s: string, max: number): string {
  if (max <= 0 || s.length <= max) return s
  return s.slice(0, Math.max(1, max - 1)).trimEnd() + "…"
}

export function iconFor(phase: Phase, seen: boolean): string {
  if (phase === "running") return ICON_RUNNING
  if (phase === "permission") return ICON_PERMISSION
  return seen ? ICON_SEEN : ICON_UNSEEN
}

// Returns compact stopwatch string once >= 1 min, or undefined if not yet / not
// applicable (feature disabled, not running, or no start time).
export function formatStopwatch(runStartedAt: number | undefined, phase: Phase, now = Date.now()): string | undefined {
  if (!STOPWATCH_ENABLED || !runStartedAt || phase !== "running") return undefined
  const mins = Math.floor((now - runStartedAt) / 60_000)
  if (mins < 1) return undefined
  if (mins < 60) return `${mins}`
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return m === 0 ? `${h}h` : `${h}h${m}`
}
