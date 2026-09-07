---
name: token-debug
description: Use ONLY when investigating high token usage, cache anomalies, context bloat, or subagent cost in opencode sessions. On-demand TokenScope debugging, not quota display.
license: MIT
compatibility: opencode
---

## Role

Token usage debugger for opencode sessions. Uses the TokenScope plugin
(`@ramtinj95/opencode-tokenscope`) for per-session forensics. Never used for
remote quota display; that is the opencode-quota plugin's job (OpenCode Go
subscription via the official usage API).

## When to Use

Activate this skill when the conversation involves:

- Unexpectedly large session cost or context growth
- Suspected cache misuse (low hit rate, high fresh input)
- Oversized tool outputs or skill/subagent bloat
- Comparing `/tokens_weekly` trend against a single heavy session

Do not activate for routine quota checks. Those use `/quota_status` and
`/tokens_*` from `@slkiser/opencode-quota`.

## Workflow

1. Prefer trend first: `/tokens_weekly` or `/tokens_session` for scope.
2. Drill down only on request or clear anomaly: run `/tokenscope`.
3. Call the `tokenscope` tool directly without delegating to other agents.
   Leave `sessionID` unset unless analyzing a different session.
4. Read the exact unique report path returned and quote it verbatim.

## How to Read the Report

Three number classes, never mixed:

- Recorded provider-step telemetry: fresh input, cache read/write, output,
  reasoning, completed steps, OpenCode-recorded cost. Strongest source.
- Local content inventory: tokenizer estimates over retained text and
  replayable tool output. Identifies contributors, not billable usage.
- Explanatory estimates: public API-rate cost, cache savings, tool schemas,
  skill/subagent catalogs. Labeled estimates only.

## Thresholds and Signals

- Cache hit rate drop or effective input rate spike: check repeated file reads,
  uncached prefixes, compaction boundaries.
- Top contributors dominated by one tool: cap output, paginate, or exclude.
- Subagent totals exceeding main session: reduce fan-out, narrow scope.
- Skill catalog or tool-schema sections large: disable unused skills.

## Caveats

- Invoking step excluded: `step-finish` persists after the tool returns.
- Compaction and reverts make retained content differ from lifetime usage.
- Zero recorded cost on `*-free` models is expected; use the separately
  labeled API-rate estimate, never as an invoice.
- Approximate tokenizer warning means reinstall or remap the model.
- Reports are local-only in owner-only tmpdir; no upload.
