// A seat opens under a filler name because waiting for a title would put
// seconds between the keypress and the OpenCode TUI. This plugin closes the
// loop: once OpenCode names the session, it runs `rookery title`, which renames
// the jj workspace, rewrites the change description and renames the herdr tab
// in one guarded step. The claim logic lives in rookery so a human or an agent
// can run the same command by hand; this file only watches for the title.
import { log, POLL_MS } from "./config"
import { runCommand } from "./process"

type Route = { type: string; sessionID?: string }
type SessionInfo = { title?: string; parentID?: string }

type Context = {
  ui: { router: { current(): Route } }
  data: {
    session: {
      root(sessionID: string): string
      get(sessionID: string): SessionInfo | undefined
      sync(sessionID: string): Promise<unknown>
    }
  }
}

// rookery names an unnamed seat `t-<HHMMSS>` with an optional collision suffix.
// A title that still looks like one means OpenCode has not named the session
// yet, so claiming it would replace a filler with a filler.
const FILLER = /^t-\d{4,6}(-\d)?$/

export default {
  id: "rookery.seat",
  async setup(context: Context) {
    // Seats are herdr tabs, and the tab name is what makes the filler
    // visible. Outside a pane there is nothing to rename automatically, and
    // `rookery title` stays a manual command.
    if (!process.env.HERDR_TAB_ID) {
      log("not inside a herdr pane - disabled")
      return
    }

    let claimed = false
    let attempts = 0
    let disposed = false

    let timer: ReturnType<typeof setInterval> | undefined

    const finish = (reason: string) => {
      claimed = true
      if (timer) clearInterval(timer)
      log(reason)
    }

    const tick = async () => {
      if (disposed || claimed) return
      const route = context.ui.router.current()
      if (route.type !== "session" || !route.sessionID) return
      // A fork keeps the root session's title, so read the title from there.
      const rootID = context.data.session.root(route.sessionID)
      let info = context.data.session.get(rootID)
      if (!info) {
        await context.data.session.sync(rootID).catch(() => undefined)
        info = context.data.session.get(rootID)
        if (!info) return
      }
      const title = info.title?.trim()
      if (!title || FILLER.test(title)) return

      attempts += 1
      const result = await runCommand("rookery", ["title", title])
      if (result.exitCode === 0) {
        finish(`claimed the seat as ${JSON.stringify(title)}`)
        return
      }
      // A non-zero exit means the workspace was already described (the agent
      // or the user got there first) or this is not a Rookery workspace at all.
      // Retrying cannot fix either, so stop after a short grace period.
      if (attempts >= 3) finish(`stopped after ${attempts} failed claims`)
    }

    // A seat can sit idle for hours before its first message, so the watch
    // lasts as long as the TUI: the lookup is in-memory and the interval is
    // the same order as the zellij indicator's. A stale client API or a
    // refused spawn must never surface as an unhandled rejection inside the
    // TUI; the seat simply keeps its filler.
    const run = () => {
      void tick().catch((error) => {
        log(`tick failed: ${error instanceof Error ? error.message : String(error)}`)
      })
    }

    timer = setInterval(run, POLL_MS)
    timer.unref?.()
    run()

    return async () => {
      disposed = true
      if (timer) clearInterval(timer)
    }
  },
}
