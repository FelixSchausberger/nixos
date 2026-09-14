import { POLL_MS, STOPWATCH_ENABLED, TITLE_ENABLED, TITLE_MAX, log } from "./config"
import { formatStopwatch, iconFor, stripIcons, truncateTitle } from "./format"
import { derivePhase, shouldCheckFocus, transitionSession, type SessionState } from "./state"
import { isFocused, renameTab, renameTabIfNamed, resolvePane } from "./zellij"

type Selection = {
  rootID: string
  title?: string
  state: SessionState
}

// Hand-rolled definition object. Upstream imports `Plugin.define` from
// @opencode-ai/plugin/tui; a Nix store plugin path has no node_modules, so this
// fork avoids that dependency. The runtime only requires a default export with
// an id and a setup function.
export default {
  id: "opencode.zellij-indicator",
  async setup(context) {
    const paneIdRaw = process.env.ZELLIJ_PANE_ID
    const paneId = paneIdRaw ? Number.parseInt(paneIdRaw, 10) : NaN
    if (!process.env.ZELLIJ_SESSION_NAME || Number.isNaN(paneId)) {
      log(`not inside Zellij (ZELLIJ_SESSION_NAME=${process.env.ZELLIJ_SESSION_NAME}, ZELLIJ_PANE_ID=${paneIdRaw}) - disabled`)
      return
    }

    const initialPane = await resolvePane(paneId)
    if (!initialPane) {
      log(`could not resolve Zellij pane ${paneId} - disabled`)
      return
    }

    log(`init: pane=${paneId} session=${process.env.ZELLIJ_SESSION_NAME}`)
    let tabId = initialPane.tabId
    let baseName = stripIcons(initialPane.tabName)
    let lastName = initialPane.tabName
    let activeSession: string | undefined
    let disposed = false
    let pollTimer: ReturnType<typeof setInterval> | undefined
    let stopwatchTimer: ReturnType<typeof setTimeout> | undefined
    let stopwatchRoot: string | undefined
    let stopwatchStartedAt: number | undefined
    const sessions = new Map<string, SessionState>()
    const syncRetry = new Set<string>()
    const rootHints = new Map<string, string>()
    const executionStarts = new Map<string, number>()
    const pendingAttention = new Map<string, { phase: "permission" | "done"; title?: string }>()
    const pendingRestores = new Map<number, { expected: string; base: string }>()
    let activeRoot: string | undefined
    let activeFamily = new Set<string>()
    let work: Promise<void> = Promise.resolve()
    let refreshRequested = false
    let forceSyncRequested = false
    let refreshScheduled = false
    let refresh: (forceSync?: boolean) => Promise<void>

    const requestRefresh = (forceSync = false) => {
      refreshRequested = true
      forceSyncRequested ||= forceSync
      if (refreshScheduled || disposed) return
      refreshScheduled = true
      work = work
        .then(async () => {
          while (refreshRequested && !disposed) {
            refreshRequested = false
            const force = forceSyncRequested
            forceSyncRequested = false
            await refresh(force)
          }
        })
        .catch((error) => log(`update failed: ${error instanceof Error ? error.message : String(error)}`))
        .finally(() => {
          refreshScheduled = false
          if (refreshRequested && !disposed) requestRefresh()
        })
    }

    const familyIDs = (rootID: string) => {
      const family = context.data.session.family(rootID)
      return family.length > 0 ? family : [rootID]
    }

    const syncSession = async (sessionID: string) => {
      let rootID = sessionID
      const ancestors = new Set<string>()
      while (!ancestors.has(rootID)) {
        ancestors.add(rootID)
        await context.data.session.sync(rootID)
        const parentID = context.data.session.get(rootID)?.parentID
        if (!parentID) break
        rootID = parentID
      }

      let complete = true
      const queue = [rootID]
      const visited = new Set<string>()
      while (queue.length > 0) {
        const parentID = queue.shift()!
        if (visited.has(parentID)) continue
        visited.add(parentID)
        let cursor: string | undefined
        const cursors = new Set<string>()
        do {
          const page = await context.client.session.list({ parentID, order: "desc", limit: 100, cursor }).catch((error) => {
            complete = false
            log(`could not list children of ${parentID}: ${error instanceof Error ? error.message : String(error)}`)
            return undefined
          })
          if (!page) break
          for (const child of page.data) {
            await context.data.session.sync(child.id).catch((error) => {
              complete = false
              log(`could not sync ${child.id}: ${error instanceof Error ? error.message : String(error)}`)
            })
            queue.push(child.id)
          }
          cursor = page.cursor.next ?? undefined
          if (cursor && cursors.has(cursor)) {
            complete = false
            log(`session list for ${parentID} returned a repeated cursor`)
            break
          }
          if (cursor) cursors.add(cursor)
        } while (cursor)
      }

      const family = familyIDs(rootID)
      const results = await Promise.allSettled(
        family.flatMap((familyID) => [
          context.data.session.pending.sync(familyID),
          context.data.session.permission.sync(familyID),
          context.data.session.form.sync(familyID, context.data.session.get(familyID)?.location),
        ]),
      )
      complete &&= results.every((result) => result.status === "fulfilled")
      if (complete) {
        syncRetry.delete(rootID)
        for (const familyID of family) rootHints.delete(familyID)
      } else syncRetry.add(rootID)
      return { rootID, complete }
    }

    const selectedRoot = () => {
      const route = context.ui.router.current()
      if (route.type !== "session" || route.sessionID === "dummy") return undefined
      return { sessionID: route.sessionID, rootID: rootHints.get(route.sessionID) ?? context.data.session.root(route.sessionID) }
    }

    const eventRoot = (sessionID: string) => rootHints.get(sessionID) ?? context.data.session.root(sessionID)

    const selectedEventRoot = (sessionID: string) => {
      const selected = selectedRoot()
      if (!selected) return undefined
      if (eventRoot(sessionID) === selected.rootID) return selected.rootID
      if (activeRoot === selected.rootID && activeFamily.has(sessionID)) return selected.rootID
      return undefined
    }

    const refreshSelected = (sessionID: string, forceSync = false) => {
      if (selectedEventRoot(sessionID)) requestRefresh(forceSync)
    }

    const stopEvents = context.data.listen(({ details }) => {
      switch (details.type) {
        case "server.connected":
          requestRefresh(true)
          return
        case "session.created":
        case "session.forked": {
          const selected = selectedRoot()
          if (!selected) return
          const parentRoot = details.data.parentID ? eventRoot(details.data.parentID) : details.data.sessionID
          if (details.data.sessionID !== selected.sessionID && parentRoot !== selected.rootID) return
          rootHints.set(details.data.sessionID, parentRoot)
          requestRefresh(true)
          return
        }
        case "session.execution.started": {
          const rootID = selectedEventRoot(details.data.sessionID)
          if (!rootID) return
          if (!executionStarts.has(rootID)) executionStarts.set(rootID, details.created)
          requestRefresh()
          return
        }
        case "session.execution.succeeded":
        case "session.execution.failed":
        case "session.execution.interrupted":
        case "session.inbox.enqueued":
        case "session.inbox.delivered":
        case "session.inbox.cancelled":
        case "session.inbox.delivery.changed":
        case "session.renamed":
          refreshSelected(details.data.sessionID)
          return
        case "session.deleted": {
          const selected = Boolean(selectedEventRoot(details.data.sessionID))
          rootHints.delete(details.data.sessionID)
          if (selected) requestRefresh(true)
          return
        }
        case "permission.asked":
        case "permission.replied":
        case "form.replied":
        case "form.cancelled":
          refreshSelected(details.data.sessionID)
          return
        case "form.created":
          refreshSelected(details.data.form.sessionID)
          return
      }
    })

    const phaseFor = (rootID: string) =>
      derivePhase(
        familyIDs(rootID).map((sessionID) => ({
          running: context.data.session.status(sessionID) === "running",
          pending: context.data.session.pending.list(sessionID).length > 0,
          permissions: context.data.session.permission.list(sessionID)?.length ?? 0,
          forms: context.data.session.form.list(sessionID, context.data.session.get(sessionID)?.location)?.length ?? 0,
        })),
      )

    const labelFor = (selection: Selection | undefined) => {
      if (!selection) return baseName
      const stopwatch = formatStopwatch(selection.state.runStartedAt, selection.state.phase)
      const icon = iconFor(selection.state.phase, selection.state.seen)
      const suffix = stopwatch ? `${icon} (⏱ ${stopwatch})` : icon
      // Compact by default: the tab name is the status icon only, so Zellij
      // renders just its index + icon (matching the V1 fork). Set
      // OPENCODE_ZELLIJ_TITLE_MAX > 0 to show the session title instead,
      // truncated to that many characters to protect the status bar.
      if (!TITLE_ENABLED) return suffix
      const label = truncateTitle(selection.title?.trim() || baseName.trim(), TITLE_MAX)
      if (!label) return suffix
      return `${label} ${suffix}`
    }

    const restorePendingTabs = async () => {
      for (const [restoreTabID, restore] of pendingRestores) {
        const result = await renameTabIfNamed(restoreTabID, restore.expected, restore.base)
        if (result !== "failed") pendingRestores.delete(restoreTabID)
      }
    }

    const render = async (selection: Selection | undefined, routeSessionID?: string) => {
      let name = labelFor(selection)
      const pane = await resolvePane(paneId)
      if (!pane) return
      if (pane.tabId !== tabId) {
        if (lastName !== baseName) pendingRestores.set(tabId, { expected: lastName, base: baseName })
        tabId = pane.tabId
        baseName = stripIcons(pane.tabName)
        lastName = pane.tabName
        name = labelFor(selection)
      }
      await restorePendingTabs()
      if (name === pane.tabName) {
        lastName = name
        return
      }

      const route = context.ui.router.current()
      if (routeSessionID ? route.type !== "session" || route.sessionID !== routeSessionID : route.type === "session") return

      log(`rename tab ${tabId} -> ${JSON.stringify(name)}`)
      if (await renameTab(tabId, name)) lastName = name
    }

    const clearStopwatch = () => {
      if (stopwatchTimer) clearTimeout(stopwatchTimer)
      stopwatchTimer = undefined
      stopwatchRoot = undefined
      stopwatchStartedAt = undefined
    }

    const scheduleStopwatch = (selection: Selection | undefined) => {
      const startedAt = selection?.state.runStartedAt
      if (!STOPWATCH_ENABLED || !selection || selection.state.phase !== "running" || !startedAt) {
        clearStopwatch()
        return
      }
      if (stopwatchTimer && stopwatchRoot === selection.rootID && stopwatchStartedAt === startedAt) return
      clearStopwatch()
      stopwatchRoot = selection.rootID
      stopwatchStartedAt = startedAt
      const elapsed = Date.now() - startedAt
      stopwatchTimer = setTimeout(() => {
        stopwatchTimer = undefined
        requestRefresh()
      }, 60_000 - (elapsed % 60_000))
      stopwatchTimer.unref?.()
    }

    refresh = async (forceSync = false) => {
      const route = context.ui.router.current()
      if (route.type !== "session" || route.sessionID === "dummy") {
        activeSession = undefined
        activeRoot = undefined
        activeFamily.clear()
        clearStopwatch()
        await render(undefined)
        return
      }

      const routeSessionID = route.sessionID
      const selectionChanged = routeSessionID !== activeSession
      activeSession = routeSessionID
      let rootID = context.data.session.root(routeSessionID)
      let syncComplete = true
      if (selectionChanged || forceSync || syncRetry.has(rootID)) {
        try {
          const result = await syncSession(routeSessionID)
          rootID = result.rootID
          syncComplete = result.complete
        } catch (error) {
          activeSession = undefined
          activeRoot = undefined
          activeFamily.clear()
          throw error
        }
      }
      if (disposed) return

      const currentRoute = context.ui.router.current()
      if (currentRoute.type !== "session" || currentRoute.sessionID !== routeSessionID || context.data.session.root(currentRoute.sessionID) !== rootID) return
      if (!syncComplete) {
        if (selectionChanged) await render(undefined, routeSessionID)
        return
      }
      activeRoot = rootID
      activeFamily = new Set(familyIDs(rootID))
      const info = context.data.session.get(rootID)
      if (!info) {
        activeSession = undefined
        clearStopwatch()
        await render(undefined, routeSessionID)
        return
      }

      const phase = phaseFor(rootID)
      let previous = sessions.get(rootID)
      const executionStartedAt = executionStarts.get(rootID)
      if (executionStartedAt !== undefined && phase !== "permission") {
        executionStarts.delete(rootID)
        if (previous?.phase !== "running") previous = transitionSession(previous, "running", false, executionStartedAt)
      }
      const attentionPhase = previous && previous.phase !== phase && (phase === "permission" || phase === "done") ? phase : undefined
      if (phase === "running") pendingAttention.delete(rootID)
      else if (attentionPhase) pendingAttention.set(rootID, { phase: attentionPhase, title: info.title })
      const focused = shouldCheckFocus(previous, phase) ? await isFocused(paneId) : undefined
      const latestRoute = context.ui.router.current()
      if (latestRoute.type !== "session" || latestRoute.sessionID !== routeSessionID || context.data.session.root(latestRoute.sessionID) !== rootID) return
      let state = transitionSession(previous, phase, focused === true, Date.now())
      sessions.set(rootID, state)
      const selection = { rootID, title: info.title, state }
      scheduleStopwatch(selection)
      await render(selection, routeSessionID)
      const attention = pendingAttention.get(rootID)
      if (attention) {
        const finalFocus = await isFocused(paneId)
        const finalRoute = context.ui.router.current()
        if (finalRoute.type !== "session" || finalRoute.sessionID !== routeSessionID) return
        if (finalFocus !== undefined) {
          pendingAttention.delete(rootID)
          if (finalFocus && state.phase === "done" && !state.seen) {
            state = transitionSession(state, "done", true, Date.now())
            sessions.set(rootID, state)
            await render({ rootID, title: info.title, state }, routeSessionID)
          } else if (!finalFocus) {
            void context.attention.notify({
              title: attention.title,
              message: attention.phase === "permission" ? "OpenCode needs input" : "OpenCode session done",
              notification: false,
              sound: { name: attention.phase === "permission" ? "permission" : "done", when: "always" },
            })
          }
        }
      }
    }

    await refresh(true).catch((error) => log(`initial update failed: ${error instanceof Error ? error.message : String(error)}`))
    pollTimer = setInterval(() => requestRefresh(), POLL_MS)
    pollTimer.unref?.()

    return async () => {
      disposed = true
      stopEvents()
      if (pollTimer) clearInterval(pollTimer)
      clearStopwatch()
      await work

      if (lastName !== baseName) pendingRestores.set(tabId, { expected: lastName, base: baseName })
      await restorePendingTabs()
    }
  },
}
