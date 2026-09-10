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
  TITLE_MAX,
  type Phase,
} from "./config"

// Strip any trailing status icon(s) so we recover the clean base tab name.
export function stripIcons(s: string): string {
  let out = s.trimEnd()
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

export function iconFor(phase: Phase, seen: boolean): string {
  if (phase === "running") return ICON_RUNNING
  if (phase === "permission") return ICON_PERMISSION
  return seen ? ICON_SEEN : ICON_UNSEEN
}

// Returns compact stopwatch string once >= 1 min, or undefined if not yet / not
// applicable (feature disabled, not running, or no start time).
export function formatStopwatch(runStartedAt: number | undefined, phase: Phase): string | undefined {
  if (!STOPWATCH_ENABLED || !runStartedAt || phase !== "running") return undefined
  const mins = Math.floor((Date.now() - runStartedAt) / 60_000)
  if (mins < 1) return undefined
  if (mins < 60) return `${mins}`
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return m === 0 ? `${h}h` : `${h}h${m}`
}

// --- Adaptive tab-name budget ------------------------------------------------
// The zjstatus bar is a single row shared by mode (left), tabs (center) and
// hints/quota/clock (right). If the rendered line is wider than the pane,
// zellij wraps it and the left/center vanish, so we shrink each tab title to
// fit instead. These constants describe the fixed, non-tab segments of the
// zellij.nix zjstatus layout; keep them in sync when that layout changes.
const MODE_WIDTH = 12 // widest mode label, e.g. "ENTERSEARCH "
const HINTS_WIDTH = 40 // matches zjstatus-hints max_length in zellij.nix
const QUOTA_WIDTH = 30 // "Go 5h 100% · wk 100% · mo 100%"
const CLOCK_WIDTH = 6 // "17:22"
const PER_TAB_FIXED = 4 // "{index} " + trailing space + separator "|"
const ICON_WIDTH = 2 // status emoji render width
const STOPWATCH_WIDTH = 8 // " (⏱ 12)"

// Fallback caps by tab count, used when zellij momentarily reports a zero bar
// width (it sometimes drops the column count on tab creation).
function countCap(tabCount: number): number {
  if (tabCount <= 2) return 20
  if (tabCount === 3) return 16
  if (tabCount === 4) return 12
  if (tabCount === 5) return 8
  return 0
}

// Maximum title length for the current tab count and bar width. Combines a
// count-based cap with a width budget; 0 means drop the title entirely (the
// tab then shows only "{index} {icon}"). A non-positive ceiling disables titles.
export function adaptiveTitleMax(
  tabCount: number,
  barWidth: number,
  ceiling: number = TITLE_MAX,
): number {
  if (ceiling <= 0) return 0
  const byCount = countCap(tabCount)
  if (tabCount <= 0 || barWidth <= 0) return Math.min(ceiling, byCount)
  const reserved = MODE_WIDTH + HINTS_WIDTH + QUOTA_WIDTH + CLOCK_WIDTH + tabCount * PER_TAB_FIXED
  const perTab = Math.floor((barWidth - reserved) / tabCount)
  const byWidth = perTab - (ICON_WIDTH + STOPWATCH_WIDTH)
  return Math.max(0, Math.min(ceiling, byCount, byWidth))
}

// Truncate a title to `cap` characters. A cap of 0 drops the title entirely so
// the tab name becomes just the status icon.
export function fitTitle(t: string, cap: number): string {
  if (cap <= 0) return ""
  return t.length > cap ? `${t.slice(0, cap).trimEnd()}…` : t
}
