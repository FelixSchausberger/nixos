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
// Event names follow the V2 event stream used by the Herdr integration
// (opencode/herdr-agent-state.js). Child (subagent) sessions are skipped so one
// turn does not fan out into several pushes.
import { readFileSync } from "node:fs"
import { Plugin } from "@opencode/plugin"

const DEFAULTS = {
  url: "http://127.0.0.1:2586",
  topic: "opencode",
  cooldownMs: 10000,
}

// Event type -> notification shape. Priority is ntfy's 1..5 scale.
const EVENTS = {
  "permission.asked": {kind: "approval", title: "OpenCode needs approval", priority: "4", tag: "warning"},
  "question.asked": {kind: "question", title: "OpenCode has a question", priority: "4", tag: "question"},
  "session.error": {kind: "error", title: "OpenCode error", priority: "4", tag: "rotating_light"},
  "session.idle": {kind: "done", title: "OpenCode finished", priority: "3", tag: "white_check_mark"},
}

export default Plugin.define({
  id: "ntfy-mobile",
  async setup(ctx) {
    const opt = {...DEFAULTS, ...(ctx.options ?? {})}
    const topicUrl = `${String(opt.url).replace(/\/+$/, "")}/${opt.topic}`
    const controller = new AbortController()
    const recent = new Map()

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
      const key = `${sessionID}:${spec.kind}`
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

        const properties = event?.properties ?? {}
        const sessionID =
          typeof properties.sessionID === "string" ? properties.sessionID : properties.info?.id
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

    return () => controller.abort()
  },
})
