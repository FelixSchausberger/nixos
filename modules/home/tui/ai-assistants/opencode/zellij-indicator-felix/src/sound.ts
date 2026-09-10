// ---------------------------------------------------------------------------
// Sound notification when a background tab needs you while you're NOT looking
// at it — either a turn finishes (🔔 "done, unseen") or it blocks on a
// permission/question prompt (❓). On by default.
//   OPENCODE_ZELLIJ_SOUND=0           disable
//   OPENCODE_ZELLIJ_SOUND_CMD="..."   run this command instead of the built-in
//                                     player (e.g. "pw-play ~/alert.wav")
// When SOUND_CMD is unset we play the bundled WAV via the first audio player we
// find. If no player exists we silently do nothing — audio is never guaranteed.
// On by default; set OPENCODE_ZELLIJ_SOUND=0 to disable.
// ---------------------------------------------------------------------------

import { fileURLToPath } from "node:url"
import { log } from "./config"
import type { Shell } from "./zellij"

const SOUND_ENABLED = process.env.OPENCODE_ZELLIJ_SOUND !== "0"
const SOUND_CMD = (() => {
  const v = process.env.OPENCODE_ZELLIJ_SOUND_CMD
  return v && v.length > 0 ? v : undefined
})()
const BUNDLED_SOUND = fileURLToPath(new URL("../sounds/complete.wav", import.meta.url))
// Ordered by preference; the first one present on the system wins. aplay/paplay
// handle WAV; ffplay is the catch-all. macOS uses afplay.
const SOUND_PLAYERS: Array<[string, string[]]> =
  process.platform === "darwin"
    ? [["afplay", [BUNDLED_SOUND]]]
    : [
        ["paplay", [BUNDLED_SOUND]],
        ["pw-play", [BUNDLED_SOUND]],
        ["aplay", ["-q", BUNDLED_SOUND]],
        ["ffplay", ["-nodisp", "-autoexit", "-loglevel", "quiet", BUNDLED_SOUND]],
      ]

let lastPlayedAt = 0

// Fire-and-forget notification sound. Fully swallows errors and never blocks
// the event loop, so a missing player or audio glitch can never break the
// plugin. A short time-guard stops accidental duplicate plays.
export async function playSound($: Shell) {
  if (!SOUND_ENABLED) return
  const now = Date.now()
  if (now - lastPlayedAt < 2000) return
  lastPlayedAt = now
  try {
    if (SOUND_CMD) {
      log(`sound via SOUND_CMD: ${SOUND_CMD}`)
      await $`sh -c ${SOUND_CMD}`.quiet().nothrow()
      return
    }
    for (const [cmd, args] of SOUND_PLAYERS) {
      try {
        const res = await $`${cmd} ${args}`.quiet().nothrow()
        if (res.exitCode === 0) {
          log(`sound via ${cmd}`)
          return
        }
      } catch {
        // try the next player
      }
    }
    log("sound: no working audio player found")
  } catch (e) {
    log(`sound failed: ${e instanceof Error ? e.message : "unknown"}`)
  }
}
