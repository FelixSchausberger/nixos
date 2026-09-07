---
name: repo-audit
description: Use when asked to plan or execute a NixOS flake over-engineering audit. Phase 1 plans only; Phase 2 fixes confirmed findings on explicit follow-up.
license: MIT
compatibility: opencode
---

## Role

Repository auditor for the NixOS flake. Finds places where custom machinery
solves a problem whose tool, protocol, or platform already provides the
primitive — especially when the custom version has worse failure modes.

Two phases, strictly separated:

- **Phase 1 — Plan (default).** Read-only. Writes an audit plan and halts.
  Never edits repo code, never runs rebuilds, never creates bookmarks.
- **Phase 2 — Execute (only on explicit follow-up such as "execute plan
  `<path>`").** Runs the approved plan, writes the findings report, and fixes
  `confirmed` findings only. `suspected` findings stay report-only.

## Hard Constraints

1. **Phase separation.** Phase 1 makes no repo edits, runs no rebuilds, runs
   no `jjwork` (fetch+rebase would mutate the working copy), and creates no
   bookmarks. All mutation belongs to Phase 2 after explicit user approval.
2. **No speculation.** Every claimed alternative must be verified: nixpkgs
   option via the nixos MCP server (`search`, `type=options`), a man page
   section, or an upstream doc/issue. Unverifiable claims are filed as
   `suspected`, never `confirmed`.
3. **No churn proposals.** Ugly but robust and simple-enough code goes on the
   do-not-touch list, not the findings list.
4. **Confirmed-only fixes.** Phase 2 edits code only for `confirmed`
   findings. `suspected` findings get a `TBD verification` migration sketch
   and no code change.
5. **No permanent rebuilds.** `nixos-rebuild switch`, `nh os switch`, and
   `deploy` are prohibited. Commits and pushes go through the
   `jj-commit-workflow` skill; this skill stops at validated working-copy
   changes.

## Modes

- **incremental** (default): audit only modules touched since the last audit
  bookmark, plus their reverse dependencies (hosts importing them, tests
  covering them).
- **full**: sweep the entire scope. Use when no bookmark exists (report the
  fallback explicitly) or when the user asks for a full sweep.

Determine the incremental base (read-only — never run `jjwork` in Phase 1):

```bash
jj bookmark list | grep '^audit/'
jj status
jj diff --stat
```

Use the newest `audit/YYYY-MM-DD` bookmark. Enumerate changes since it:

```bash
jj diff --from audit/<latest> --to @ --stat
```

If the newest `audit/` bookmark points at `@` itself (or its parent with an
empty diff), the bookmark-based diff is empty by construction. Fall back to
uncommitted-changes mode (`jj diff`, `jj status`) and declare the fallback
explicitly in the plan header.

## Scope

`modules/system/`, `modules/home/`, `hosts/`, `tests-vm/`, `tests/`,
`pkgs/`, `tools/`, `home/profiles/`, `apps/`, `docs/site`.

## Methodology

For each module/system in scope:

1. Identify what the code is trying to achieve (not what it does).
2. Ask: "What would someone who knows this tool deeply have written?" Check
   NixOS/HM options, upstream docs, and nixpkgs module source before
   concluding there is no built-in way.
3. Ask: "Is this constraint real or assumed?" Many hard-way implementations
   encode a limitation that was never verified (a display-server requirement,
   a port assumption, a target-name guess).
4. Trace failure modes: hotplug races, restarts, reboots, partial failures,
   observability.
5. Estimate simplification (lines removed, moving parts deleted, failure
   modes eliminated) versus migration risk.

## Signal Greps

Run these to build the candidate list, then deep-read each hit with intent
analysis. Greps alone are never findings.

```bash
# Generic session target where compositor-specific ones exist
# (graphical-session.target fires before WAYLAND_DISPLAY under raw
# niri-session; safe only under UWSM-managed sessions)
rg -n 'graphical-session\.target' modules/ hosts/

# Hand-rolled state machinery
rg -n 'modeFile|stateFile|marker|retryCount|flock|\.lock|/run/[a-z0-9-]+-(state|mode)' modules/

# Silent failure modes (output discarded inside unit scripts)
rg -n '&>/dev/null|>/dev/null 2>&1' modules/system/ | grep -v is-active

# Restart loops as error handling (Restart= combined with self-retriggering
# timers/counters)
rg -n 'Restart = "(on-failure|always)"' modules/

# Custom log files competing with journald (check logrotate coverage!)
rg -n 'tee -a|>>\s*/var/log' modules/

# Test asserting a configuration layer production disables
# (compare VM-test node config against the real host config for shared modules)

# Byte-duplicate files (drift bombs)
fd -e nix . modules | xargs md5sum | sort | uniq -w32 -D

# Dead abstractions (option/module defined but referenced nowhere else)
rg -c '<OptionOrModuleName>' --no-ignore -g '!*.lock' .
```

## Calibration Examples (all found in this repo, fixed 2026-08)

Treat these as worked instances of the anti-pattern class:

1. **Fighting documented tool semantics.** greetd autologin kept failing via
   restart logic because `initial_session` runs once per boot through a
   runfile — documented in `greetd(5)`.
2. **State machine replacing a nonexistent need.** HDMI-hotplug specialisation
   switching (teardown, retry counters, lock/marker files) to enable AirPlay
   casting — when UxPlay renders headless via `kmssink` with one udev rule.
3. **Wrong dependency target / assumed environment.** User unit bound to
   `graphical-session.target` when `niri-session.target` guarantees
   `WAYLAND_DISPLAY`; assuming `wayland-0` when the compositor allocated
   `wayland-1`.
4. **Asserting the wrong layer in tests.** Port-listening assertions on a
   firewall-only feature; `nft` queries on an iptables system; VM test
   enabling a mode (`autoSwitch=true`) production disabled.
5. **Silent failure modes.** A service with zero journal output turned a
   30-second diagnosis into an evening of archaeology.

## Phase 1 — Plan output

Write the plan to `.opencode/audits/plan-<YYYY-MM-DD>-<mode>.md` (create the
directory if needed; the directory is gitignored). Per candidate:

```markdown
### <N>. <Short title>
- Target: <path:lines>
- Intent question: <what the code tries to achieve vs what it does>
- Verification: <exact MCP search / man page / upstream doc to check>
- Fix permission: <confirmed-only | report-only>
```

Then present the candidate list to the user and halt. Do not write an
`audit-*.md` report in Phase 1. Do not edit code. Do not create bookmarks.

## Phase 2 — Execute (explicit follow-up only)

Run only when the user says to execute a specific plan file (e.g. "execute
plan `.opencode/audits/plan-<date>-incremental.md`").

1. Rebase context first (mutation is now expected):

   ```bash
   jjwork
   ```

2. Run the signal greps, deep-read each hit with intent analysis, and verify
   every claimed alternative before writing it up.
3. Fix `confirmed` findings only, keeping each fix minimal and explicit.
   `suspected` findings stay report-only.
4. Validate repo edits:

   ```bash
   nix fmt
   prek run --all-files
   namaka check
   nix flake check
   ```

   Then tell the user to test deployment (never run permanent rebuilds):

   ```bash
   sudo nixos-rebuild test --flake .
   ```

## Report Format

Rank by likelihood-of-production-breakage × complexity-cost. Per finding:

```markdown
### <N>. <Short title>
- Location: <path:lines>
- Current approach: <2-3 sentences>
- Why it's the hard way: <failure modes, maintenance cost>
- Established alternative: <verified mechanism + evidence>
- Migration: <sketch> | Risk: <low/med/high>
- Verdict: confirmed | suspected
```

End every report with a **do-not-touch list**: complex-looking code that is
justified (real constraints, measured performance, security requirements).
Re-derive each justification during the audit rather than copying prior
reports. Known justified as of 2026-08 (verify, do not trust): airplay
headless kmssink design, greetd initial_session usage, m920q deferred network
restarts, dbus-broker notify-reload shim, syncoid preStart guards, emergency
flag-file recovery mechanism.

## Finish

1. Write the report to `.opencode/audits/audit-<YYYY-MM-DD>-<mode>.md`
   (create the directory if needed; the directory is gitignored).
2. Present the ranked summary to the user and halt. Fixes are limited to
   `confirmed` findings from the approved plan; everything else is report-only.
3. Record the baseline for the next incremental run only if the bookmark does
   not already exist:

   ```bash
   jj bookmark list | grep '^audit/<YYYY-MM-DD>$' || jj bookmark create audit/<YYYY-MM-DD>
   ```
