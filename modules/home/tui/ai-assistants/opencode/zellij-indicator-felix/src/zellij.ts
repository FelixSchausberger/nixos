// ---------------------------------------------------------------------------
// Thin wrappers around the `zellij` CLI. Each takes the Bun shell (`$`) that
// opencode hands the plugin, so this module holds no state of its own.
// ---------------------------------------------------------------------------

import type { Plugin } from "@opencode-ai/plugin"
import { log } from "./config"

// The Bun shell type, derived from the plugin input so we don't depend on a
// deep/private import path from the SDK.
export type Shell = Parameters<Plugin>[0]["$"]

export function renameTab($: Shell, id: number, name: string) {
  return $`zellij action rename-tab-by-id ${id} ${name}`.quiet().nothrow()
}

// Fields we read from `zellij action list-panes --json --all`.
interface PaneInfo {
  id: number
  is_plugin: boolean
  tab_id: number
  tab_position?: number
  tab_name?: string
  title?: string
  pane_columns?: number
  plugin_url?: string
}

export interface PaneMetrics {
  tabId: number
  tabName: string
  // Number of open tabs; drives the count-based slice of the title budget.
  tabCount: number
  // Width of the status bar in our tab (the zjstatus plugin pane). This is the
  // true bar width even when our tab is split, unlike our own pane's width.
  barWidth: number
}

// Locate our own pane among all panes and return its tab id, raw tab name, the
// open-tab count and the status-bar width. Returns undefined if we can't find
// it (or the CLI call fails).
export async function resolvePane($: Shell, paneId: number): Promise<PaneMetrics | undefined> {
  try {
    const out = await $`zellij action list-panes --json --all`.quiet().nothrow().text()
    const panes = JSON.parse(out) as PaneInfo[]
    const mine = panes.find((p) => !p.is_plugin && p.id === paneId)
    if (!mine) {
      log(`could not find own pane (id=${paneId}) among ${panes.length} panes`)
      return undefined
    }
    const tabCount = new Set(panes.map((p) => p.tab_position)).size || 1
    // zellij reports the bar pane either by alias ("zjstatus") or by full wasm
    // path ("file:.../zjstatus.wasm"); the hints plugin is "zjstatus-hints", so
    // match the exact bar, not anything containing "zjstatus".
    const isStatusBar = (v?: string) => v === "zjstatus" || (v?.endsWith("/zjstatus.wasm") ?? false)
    const barPane = panes.find(
      (p) => p.is_plugin && p.tab_id === mine.tab_id && (isStatusBar(p.plugin_url) || isStatusBar(p.title)),
    )
    return {
      tabId: mine.tab_id,
      tabName: String(mine.tab_name ?? ""),
      tabCount,
      barWidth: Number(barPane?.pane_columns ?? 0),
    }
  } catch (e) {
    log(`list-panes failed: ${e instanceof Error ? e.message : "unknown"}`)
    return undefined
  }
}

// Whether the client is currently focused on our pane's tab.
export async function isFocused($: Shell, paneId: number): Promise<boolean> {
  try {
    const out = await $`zellij action list-clients`.quiet().nothrow().text()
    return new RegExp(`\\bterminal_${paneId}\\b`).test(out)
  } catch {
    return false
  }
}
