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

// Locate our own pane among all panes and return its tab id + raw tab name.
// Returns undefined if we can't find it (or the CLI call fails).
export async function resolvePane(
  $: Shell,
  paneId: number,
): Promise<{ tabId: number; tabName: string } | undefined> {
  try {
    const out = await $`zellij action list-panes --json --all`.quiet().nothrow().text()
    const panes = JSON.parse(out) as Array<{
      id: number
      is_plugin: boolean
      tab_id: number
      tab_name?: string
    }>
    const mine = panes.find((p) => !p.is_plugin && p.id === paneId)
    if (!mine) {
      log(`could not find own pane (id=${paneId}) among ${panes.length} panes`)
      return undefined
    }
    return { tabId: mine.tab_id, tabName: String(mine.tab_name ?? "") }
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
