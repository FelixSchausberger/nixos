// ---------------------------------------------------------------------------
// Thin wrappers around the `zellij` CLI.
// ---------------------------------------------------------------------------

import { log } from "./config"
import { runCommand } from "./process"

type Pane = {
  id: number
  is_plugin: boolean
  tab_id: number
  tab_name?: string
}

async function listPanes(): Promise<Pane[] | undefined> {
  try {
    const result = await runCommand("zellij", ["action", "list-panes", "--json", "--all"])
    if (result.exitCode !== 0) return undefined
    return JSON.parse(result.stdout) as Pane[]
  } catch (error) {
    log(`list-panes failed: ${error instanceof Error ? error.message : "unknown"}`)
    return undefined
  }
}

export async function renameTab(id: number, name: string): Promise<boolean> {
  const result = await runCommand("zellij", ["action", "rename-tab-by-id", String(id), name])
  if (result.exitCode !== 0) log(`rename-tab-by-id failed with exit code ${result.exitCode}`)
  return result.exitCode === 0
}

export async function renameTabIfNamed(id: number, expected: string, name: string): Promise<"renamed" | "changed" | "failed"> {
  const panes = await listPanes()
  if (!panes) return "failed"
  const tab = panes.find((pane) => pane.tab_id === id)
  if (!tab || String(tab.tab_name ?? "") !== expected) return "changed"
  return (await renameTab(id, name)) ? "renamed" : "failed"
}

// Locate our own pane among all panes and return its tab id + raw tab name.
// Returns undefined if we can't find it (or the CLI call fails).
export async function resolvePane(paneId: number): Promise<{ tabId: number; tabName: string } | undefined> {
  const panes = await listPanes()
  if (!panes) return undefined
  const mine = panes.find((pane) => !pane.is_plugin && pane.id === paneId)
  if (!mine) {
    log(`could not find own pane (id=${paneId}) among ${panes.length} panes`)
    return undefined
  }
  return { tabId: mine.tab_id, tabName: String(mine.tab_name ?? "") }
}

// Whether the client is currently focused on our pane's tab.
export async function isFocused(paneId: number): Promise<boolean | undefined> {
  try {
    const result = await runCommand("zellij", ["action", "list-clients"])
    if (result.exitCode !== 0) return undefined
    return new RegExp(`\\bterminal_${paneId}\\b`).test(result.stdout)
  } catch {
    return undefined
  }
}
