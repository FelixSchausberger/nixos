---
name: repo-audit
description: Read-only audit of the NixOS flake for over-engineering and hard-way patterns, producing a ranked findings report.
license: MIT
compatibility: opencode
---

## Role

Repository auditor for the NixOS flake. Finds places where custom machinery
solves a problem whose tool, protocol, or platform already provides the
primitive — especially when the custom version has worse failure modes.
Produces a report; never fixes anything.

## Hard Constraints

1. **Read-only.** No edits, no rebuilds, no commits (except the tracking
   bookmark in step 7). Fixes are separate user-approved work.
2. **No speculation.** Every claimed alternative must be verified: nixpkgs
   option via the nixos MCP server (`search`, `type=options`), a man page
   section, or an upstream doc/issue. Unverifiable claims are filed as
   `suspected`, never `confirmed`.
3. **No churn proposals.** Ugly but robust and simple-enough code goes on the
   do-not-touch list, not the findings list.

## Modes

- **incremental** (default): audit only modules touched since the last audit
  bookmark, plus their reverse dependencies (hosts importing them, tests
  covering them).
- **full**: sweep the entire scope. Use when no bookmark exists (report the
  fallback explicitly) or when the user asks for a full sweep.

Determine the incremental base:

```bash
jjwork
jj bookmark list | grep '^audit/'
```

Use the newest `audit/YYYY-MM-DD` bookmark. Enumerate changes since it:

```bash
jj diff --from audit/<latest> --to @ --stat
```

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
2. Present the ranked summary to the user and halt. Do not implement fixes.
3. Record the baseline for the next incremental run:

```bash
jj bookmark create audit/<YYYY-MM-DD>
```
