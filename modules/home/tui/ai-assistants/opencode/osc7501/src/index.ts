// OpenCode -> OSC 7501 (Program Status Protocol) bridge.
//
// The terminal client owns the pane's tty, so the plugin writes the protocol
// sequence to /dev/tty instead of a multiplexer socket. Zellij 0.46's
// attention inbox, TUIOS, Rex and libghostty-vt consumers read the same
// protocol, which keeps the status layer independent of the terminal that
// displays it. Only the client loads this plugin (it is listed in cli.json,
// never in the config's server-side plugin list): a server role has no tty.
//
// The state derivation mirrors the fleet's Zellij indicator, which has the
// same three phases: a permission or question wins over a running turn, a
// running turn wins over rest, and a turn that ends is reported as done. The
// protocol's own lifetime rules then keep done visible until the next report.

import fs from "node:fs"

const POLL_MS = 1500
const DEBUG = process.env.OPENCODE_OSC7501_DEBUG === "1"
const log = (msg: string) => {
  if (DEBUG) console.error(`[osc7501] ${msg}`)
}

type Phase = "running" | "permission" | "done"

type Member = {
  running: boolean
  pending: boolean
  permissions: number
  forms: number
}

type Route = { type: string; sessionID?: string }

type SessionInfo = {
  parentID?: string
  location?: unknown
}

type Context = {
  ui: { router: { current(): Route } }
  client: {
    session: {
      list(input: {
        parentID: string
        order: "desc"
        limit: number
        cursor?: string
      }): Promise<{ data: { id: string }[]; cursor: { next?: string } }>
    }
  }
  data: {
    session: {
      root(id: string): string
      get(id: string): SessionInfo | undefined
      family(id: string): string[]
      status(id: string): string
      sync(id: string): Promise<unknown>
      pending: { sync(id: string): Promise<unknown>; list(id: string): unknown[] }
      permission: { sync(id: string): Promise<unknown>; list(id: string): unknown[] | undefined }
      form: {
        sync(id: string, location: unknown): Promise<unknown>
        list(id: string, location: unknown): unknown[] | undefined
      }
    }
    listen(callback: (event: { details: { type: string; data: any } }) => void): () => void
  }
}

const familyIDs = (context: Context, rootID: string) => {
  const family = context.data.session.family(rootID)
  return family.length > 0 ? family : [rootID]
}

const phaseOf = (members: Member[]): Phase => {
  if (members.some((member) => member.permissions > 0 || member.forms > 0)) return "permission"
  if (members.some((member) => member.running || member.pending)) return "running"
  return "done"
}

const kindOf = (members: Member[]) =>
  members.some((member) => member.permissions > 0) ? "permission" : "question"

export default {
  id: "ocws.osc7501",
  async setup(context: Context) {
    // Windows has no /dev/tty; the protocol has nothing to attach to there.
    if (process.platform === "win32") {
      log("disabled on Windows")
      return
    }

    let tty: number
    try {
      tty = fs.openSync("/dev/tty", "w")
    } catch (error) {
      log(`cannot open /dev/tty: ${error instanceof Error ? error.message : String(error)}`)
      return
    }

    let disposed = false
    let last = ""
    let activeSession: string | undefined
    // Per root session, so switching away mid-turn and back still reports a
    // completion the pane's terminal record no longer has (the record is
    // cleared when the pane shows another session).
    const phases = new Map<string, Phase>()
    const syncRetry = new Set<string>()

    const report = (state: string, kind?: string, message?: string) => {
      if (disposed) return
      let body = `state=${state}:app=opencode`
      if (kind) body += `:kind=${kind}`
      if (message) body += `:msg=${Buffer.from(message, "utf8").toString("base64")}`
      if (body === last) return
      try {
        fs.writeSync(tty, `\x1b]7501;${body}\x1b\\`)
        last = body
      } catch (error) {
        log(`write failed: ${error instanceof Error ? error.message : String(error)}`)
        try {
          fs.closeSync(tty)
        } catch {}
        disposed = true
      }
    }

    const clear = () => report("clear")

    const syncSession = async (routeSessionID: string) => {
      let rootID = routeSessionID
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
          const page = await context.client.session
            .list({ parentID, order: "desc", limit: 100, cursor })
            .catch((error) => {
              complete = false
              log(
                `cannot list children of ${parentID}: ${error instanceof Error ? error.message : String(error)}`,
              )
              return undefined
            })
          if (!page) break
          for (const child of page.data) {
            await context.data.session.sync(child.id).catch((error) => {
              complete = false
              log(`cannot sync ${child.id}: ${error instanceof Error ? error.message : String(error)}`)
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

      const family = familyIDs(context, rootID)
      const results = await Promise.allSettled(
        family.flatMap((familyID) => [
          context.data.session.pending.sync(familyID),
          context.data.session.permission.sync(familyID),
          context.data.session.form.sync(familyID, context.data.session.get(familyID)?.location),
        ]),
      )
      complete &&= results.every((result) => result.status === "fulfilled")
      if (complete) syncRetry.delete(rootID)
      else syncRetry.add(rootID)
      return { rootID, complete }
    }

    const membersOf = (rootID: string): Member[] =>
      familyIDs(context, rootID).map((sessionID) => ({
        running: context.data.session.status(sessionID) === "running",
        pending: context.data.session.pending.list(sessionID).length > 0,
        permissions: context.data.session.permission.list(sessionID)?.length ?? 0,
        forms: context.data.session.form.list(sessionID, context.data.session.get(sessionID)?.location)?.length ?? 0,
      }))

    const refresh = async (force = false) => {
      const route = context.ui.router.current()
      if (route.type !== "session" || !route.sessionID || route.sessionID === "dummy") {
        activeSession = undefined
        clear()
        return
      }

      const routeSessionID = route.sessionID
      const selectionChanged = routeSessionID !== activeSession
      activeSession = routeSessionID
      if (selectionChanged) {
        // The record belongs to the pane, not the session: drop the previous
        // session's state before the first report for the new one.
        clear()
      }
      let rootID = context.data.session.root(routeSessionID)
      if (selectionChanged || force || syncRetry.has(rootID)) {
        try {
          const result = await syncSession(routeSessionID)
          rootID = result.rootID
          if (!result.complete) return
        } catch (error) {
          log(`sync failed: ${error instanceof Error ? error.message : String(error)}`)
          syncRetry.add(rootID)
          return
        }
      }
      if (disposed) return

      const current = context.ui.router.current()
      if (
        current.type !== "session" ||
        current.sessionID !== routeSessionID ||
        context.data.session.root(current.sessionID) !== rootID
      ) {
        return
      }

      const members = membersOf(rootID)
      const phase = phaseOf(members)
      const previous = phases.get(rootID)
      if (phase === "permission") {
        const kind = kindOf(members)
        report("blocked", kind, kind === "permission" ? "approve a tool call" : "answer a question")
        phases.set(rootID, phase)
        return
      }
      if (phase === "running") {
        report("working")
        phases.set(rootID, phase)
        return
      }

      // A turn ended since the last report, or the TUI just settled on a
      // session at rest: done versus idle are different facts for the inbox.
      if (previous === "running" || previous === "permission" || (selectionChanged && previous === "done")) {
        report("done", undefined, "turn complete")
      } else if (previous === undefined) {
        report("idle")
      }
      phases.set(rootID, phase)
    }

    // Serialize refreshes: events can arrive while a sync is in flight, and a
    // late report must never describe a session the TUI left.
    let work: Promise<void> = Promise.resolve()
    let requested = false
    let forced = false
    let scheduled = false

    const schedule = (force = false) => {
      requested = true
      forced ||= force
      if (scheduled || disposed) return
      scheduled = true
      work = work
        .then(async () => {
          while (requested && !disposed) {
            requested = false
            const next = forced
            forced = false
            await refresh(next)
          }
        })
        .catch((error) => log(`refresh failed: ${error instanceof Error ? error.message : String(error)}`))
        .finally(() => {
          scheduled = false
          if (requested && !disposed) schedule()
        })
    }

    const stop = context.data.listen(({ details }) => {
      switch (details.type) {
        case "server.connected":
        case "session.created":
        case "session.forked":
          schedule(true)
          return
        case "session.deleted":
          if (typeof details.data?.sessionID === "string") phases.delete(details.data.sessionID)
          schedule(true)
          return
        case "session.execution.started":
        case "session.execution.succeeded":
        case "session.execution.failed":
        case "session.execution.interrupted":
        case "session.inbox.enqueued":
        case "session.inbox.delivered":
        case "session.inbox.cancelled":
        case "session.inbox.delivery.changed":
        case "session.renamed":
        case "permission.asked":
        case "permission.replied":
        case "form.created":
        case "form.replied":
        case "form.cancelled":
          schedule()
          return
      }
    })

    const poll = setInterval(() => schedule(syncRetry.size > 0), POLL_MS)
    poll.unref?.()

    schedule(true)

    return async () => {
      if (disposed) return
      stop()
      clearInterval(poll)
      // Clear before flipping the guard: report() refuses to write once the
      // plugin is disposed, and a stale working/blocked record would otherwise
      // outlive the TUI until the terminal drops it.
      clear()
      disposed = true
      try {
        fs.closeSync(tty)
      } catch {}
      await work
    }
  },
}
