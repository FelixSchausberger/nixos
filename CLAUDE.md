# CLAUDE.md

This file configures Claude Code for this repository. The shared, canonical
repository guidance lives in [AGENTS.md](AGENTS.md) and is imported below, so
there is exactly one place to update.

@AGENTS.md

## Claude Code Notes

- The active AI assistant is OpenCode. The Claude Code Home Manager module
  (`modules/home/tui/ai-assistants/claude-code/`) is currently disabled; this
  file exists so a switch back to Claude Code keeps working without
  re-deriving repository conventions.
- MCP servers, hooks, and the status line are declared under
  `modules/home/tui/ai-assistants/`. Project-scoped MCP configuration is
  generated into `.mcp.json`/`.lsp.json` at the repository root and is
  gitignored.
- The `documentation-policy.sh` hook restricts Markdown paths. If the
  `claude-code` module is re-enabled, extend its allowlist with `AGENTS.md`.
