// Environment-derived configuration + logging. Read once at module load, no
// runtime state, and nothing here depends on the rest of the plugin.

const env = (key: string, def: string) => {
  const v = process.env[key]
  return v && v.length > 0 ? v : def
}

const pollParsed = Number.parseInt(env("OCWS_SEAT_POLL_MS", "2000"), 10)
export const POLL_MS = Number.isFinite(pollParsed) && pollParsed >= 250 ? pollParsed : 2000

// Debug logging goes to OpenCode's server log, not the TUI: the answer to
// "why did my tab not rename?" is usually a non-zero `ocws title` exit.
const DEBUG = process.env.OCWS_SEAT_DEBUG === "1"
export const log = (msg: string) => {
  if (DEBUG) console.error(`[ocws-seat] ${msg}`)
}
