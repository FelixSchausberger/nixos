// ntfy-mobile — server-side push for the phone-facing OpenCode V2 server.
//
// Runs inside the OpenCode server process and mirrors each session's attention
// events to the self-hosted ntfy instance, so the phone receives a push with
// the PWA closed. The V2 API exposes no per-client origin, so "mobile only" is
// scoped by *server* instead: this plugin is enabled only on the host whose
// server the phone can reach (Tailscale Serve), while the desktop, WSL and
// nvim clients attach to their own loopback servers and never publish. See
// modules/system/homelab/opencode-web.nix.
//
// Event names follow the V2 event stream, the same stream the herdr
// agent-state integration consumes. Child (subagent) sessions are skipped so
// one turn does not fan out into several pushes.
//
// Scoping is per *server*, and cannot be per *client*: nothing in the V2 API,
// the event payload, or the session tables records which client a turn came
// from, so a phone-originated turn cannot be told apart from one run on the
// desktop against the same server. `finished` therefore exists as the blunt
// instrument - turn off the `done` push when its noise outweighs its value -
// and the needs-attention kinds stay on, since those are what a push is for.
import { readFileSync } from "node:fs"

// Plugin.define from @opencode/plugin is an identity helper, and a
// path-referenced plugin has no node_modules to resolve that bare import from,
// so the object is exported directly with the same { id, setup } shape.

const DEFAULTS = {
  url: "http://127.0.0.1:2586",
  topic: "opencode",
  cooldownMs: 10000,
  debounceMs: 15000,
  finished: true,
}

// Event type -> notification shape. Priority is ntfy's 1..5 scale.
// `session.idle` is deprecated but still emitted; `session.execution.succeeded`
// is the signal the V2 client itself treats as "turn complete", so both map to
// the same `done` kind and the per-session cooldown collapses the duplicate.
const EVENTS = {
  "permission.asked": {kind: "approval", title: "OpenCode needs approval", priority: "4", tag: "warning"},
  "question.asked": {kind: "question", title: "OpenCode has a question", priority: "4", tag: "question"},
  "session.error": {kind: "error", title: "OpenCode error", priority: "4", tag: "rotating_light"},
  "session.idle": {kind: "done", title: "OpenCode finished", priority: "3", tag: "white_check_mark"},
  "session.execution.succeeded": {kind: "done", title: "OpenCode finished", priority: "3", tag: "white_check_mark"},
}

export default {
  id: "ntfy-mobile",
  async setup(ctx) {
    const opt = {...DEFAULTS, ...(ctx.options ?? {})}
    const topicUrl = `${String(opt.url).replace(/\/+$/, "")}/${opt.topic}`
    const controller = new AbortController()
    const recent = new Map()
    const timers = new Map()

    const token = () => {
      if (!opt.tokenFile) return undefined
      try {
        return readFileSync(opt.tokenFile, "utf8").trim() || undefined
      } catch (error) {
        console.error(`ntfy-mobile: cannot read tokenFile ${opt.tokenFile}: ${error}`)
        return undefined
      }
    }

    const publish = async (sessionID, spec, body) => {
      if (spec.kind === "done" && !opt.finished) return
      const key = `${sessionID}:${spec.kind}`

      // A turn emits the `done` signal once per completed step, plus the
      // deprecated session.idle, spread across the whole turn. The cooldown
      // below is leading-edge, so it only collapses signals arriving inside its
      // window and a multi-minute turn produced one push per step. `done`
      // therefore takes the trailing edge instead: restart the timer and
      // publish once the turn has been quiet.
      if (spec.kind === "done") {
        clearTimeout(timers.get(key))
        timers.set(
          key,
          setTimeout(() => {
            timers.delete(key)
            void send(sessionID, spec, body, key)
          }, Number(opt.debounceMs)),
        )
        return
      }

      await send(sessionID, spec, body, key)
    }

    const send = async (sessionID, spec, body, key) => {
      const now = Date.now()
      if ((recent.get(key) ?? 0) + Number(opt.cooldownMs) > now) return
      recent.set(key, now)

      const headers = {Title: spec.title, Tags: spec.tag, Priority: spec.priority}
      if (opt.clickBase) headers.Click = opt.clickBase
      const bearer = token()
      if (bearer) headers.Authorization = `Bearer ${bearer}`

      try {
        await fetch(topicUrl, {
          method: "POST",
          headers,
          body,
          signal: AbortSignal.timeout(5000),
        })
      } catch (error) {
        console.error(`ntfy-mobile: publish failed: ${error}`)
      }
    }

    void (async () => {
      for await (const event of ctx.event.subscribe({signal: controller.signal})) {
        const spec = EVENTS[event?.type]
        if (!spec) continue

        // V2 events carry their fields under `data` (see the schema's
        // Event.ephemeral: { id, type, data, ... }); the V1 `properties`
        // shape is kept as a fallback so one export can serve both entry
        // points. Reading only `properties` yields {} under V2 and silently
        // drops every event, which is why the phone received nothing.
        const payload = event?.data ?? event?.properties ?? {}
        const sessionID =
          typeof payload.sessionID === "string" ? payload.sessionID : payload.info?.id
        if (!sessionID) continue

        try {
          const info = await ctx.session.get({sessionID})
          if (info?.parentID) continue
          await publish(sessionID, spec, info?.title || sessionID)
        } catch (error) {
          console.error(`ntfy-mobile: handler failed: ${error}`)
        }
      }
    })()

    return () => {
      controller.abort()
      for (const timer of timers.values()) clearTimeout(timer)
      timers.clear()
    }
  },
}
