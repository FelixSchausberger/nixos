// Inert V2 TUI entrypoint. An unisolated V2 resolves ./tui when this
// directory is named as a plugin; a missing entry aborts its whole plugin
// generation, so provide the documented {id, setup} shape with a no-op.
// Nothing registers, and V1 is unaffected: it loads main (src/index.ts).
export default {
  id: "opencode.zellij-indicator",
  setup() {},
}
