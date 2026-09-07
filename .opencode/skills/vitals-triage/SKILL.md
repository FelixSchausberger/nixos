---
name: vitals-triage
description: Use when vitals reports issues, the health score drops, or systemd units fail. Investigates vitals findings and fixes root causes in NixOS config or vitals itself.
license: MIT
compatibility: opencode
---

## Role

Triage agent for `vitals` health-check findings. Collects active issues,
root-causes each one, and fixes the declarative source: `/per/etc/nixos`
for system misconfigurations, `/per/repos/vitals` for aggregation or
false-positive bugs. Reports transients without editing anything.

## Modes

- **Full triage** (default): auto-run collection, sort all issues by burden,
  fix in order, report the rest.
- **Single issue**: user names a title, unit, or issue id; skip everything
  else and focus on that match.

## Workflow Steps

Always execute in order. Stop and report if a step fails.

### 1. Rebase context

Each repo you touch starts with a rebase (per project VCS policy):

```bash
jjwork
```

Run it in `/per/etc/nixos` first. Run it in `/per/repos/vitals` only if
you end up editing vitals. If `jjwork` reports conflicts, run
`jj resolve --list` and report to the user. Do not proceed past conflicts.

### 2. Collect (auto-run, never trust pasted tables alone)

```bash
vitals issues
vitals status --format json
vitals status --detail
vitals history
```

The human `issues` table truncates hints to one line. The JSON from
`vitals status --format json` is authoritative: `issues[{id,title,
severity,count,impact,unit,hints}]`, `resources` with per-dimension
penalties and `top_consumers`, `breakdown{errors,warnings,info}`,
baseline sample counts. Sort work order by `abs(impact)` descending,
then `Error` before `Warning` before `Info`.

In single-issue mode, filter this list to the requested title/unit/id
and confirm the match with the user before editing.

### 3. Classify and investigate

Identify the issue class first, then run its runbook. Check system state
before reading config: state tells you whether the config is even loaded.

| Class | Signature | Runbook |
| --- | --- | --- |
| Failed unit | `Failed Unit: <name>` | `systemctl status <name>` (add `--user` for `user@` units); `journalctl -u <name> --since -2h`; `systemctl is-failed <name>` to confirm still failing |
| Journal events | `Journal Events — <unit>` | `journalctl -u <unit> --since -2h -p <pri>`; check the hint timestamps for shutdown markers (`Shutting down`, `Reached target System Shutdown`) within ~120s; query `/logs?unit=<unit>` if daemon API is reachable |
| OOM kill | `OOM kill: <comm>` | `dmesg --level emerg,alert,crit,err` plus `journalctl -k --since -24h`; search output for OOM terms; correlate with `RAM growth` on the same host |
| Restart storm | `Restart storm: <unit>` | `systemctl status <unit>`; `journalctl -u <unit> --since -1h` filtered for start-limit terms; look for crash-loop ExecStart |
| Slow boot | `Slow boot: <unit>` | `systemd-analyze blame` (top 20 lines); confirm threshold (>30s) still applies |
| RAM growth | `RAM growth: <unit>` | `systemctl status <unit>`; compare RSS over time; check for known leaks vs legitimate caches |
| Resource burden | `CPU/MEM/DISK/LOAD` row | Use JSON `resources.top_consumers`; `systemd-cgtop --batch -n1` (top lines) and `df -h`; do not chase a burden below 0.05 |
| Unknown-key warning | `Unknown key 'X' in section [Service]` | `man systemd.exec` / `man systemd.service` to verify the key name; this class is almost always a real typo (e.g. `IPFreebind` should be `FreeBind`) |

Suppressed by design (visible in `/logs`, never scored): one-time boot
noise, shutdown transients near a marker, dbus-broker self-denials.
Do not "fix" these in the NixOS repo. If they score anyway, the bug is
in vitals aggregation, not the system.

### 4. Map unit to declarative source

```bash
rg -n '<unit-name>' modules/ hosts/ home/profiles/
```

Record the owning file as `path:lines`. Common anchors in this repo:
comin-autopush lives in `modules/system/comin.nix`; AdGuard Home in
`modules/system/homelab/adguardhome.nix`; syncoid commands in
`hosts/m920q/default.nix`. For user units (`user@1000.service` noise),
resolve the inner unit first (`journalctl --user -u <inner>`).

### 5. Decide fix location

- **System misconfig** (wrong systemd key, failed syncoid timer, broken
  unit): edit `/per/etc/nixos`. Keep the change minimal and explicit.
- **Vitals bug** (false positive, bad grouping, missing suppression
  pattern): edit `/per/repos/vitals` (`daemon/src/agg/mod.rs` patterns,
  `daemon/src/probes.rs` thresholds). Add or update a regression test
  next to the changed logic.
- **Transient** (clean-reboot fallout, one-shot exit-code, unit already
  green): no edit. State the evidence and close the issue.

Verify systemd key names against man pages or the nixos MCP server
(`search`, `type=options`) before concluding. Unverifiable claims are
reported as suspected, never confirmed.

### 6. Validate

NixOS repo edits:

```bash
nix fmt
prek run --all-files
namaka check
nix flake check
```

Vitals repo edits: `cargo test`, `cargo clippy`, `nix build` per that
repo's dev shell aliases.

Then tell the user to test deployment (never run permanent rebuilds):

```bash
sudo nixos-rebuild test --flake .
```

`nixos-rebuild switch`, `nh os switch`, and `deploy` are prohibited.
Commits and pushes go through the `jj-commit-workflow` skill
(`jj describe`, `jjpush` with auto-merge); this skill stops at validated
working-copy changes.

## Report Format

One section per issue, in burden order:

```markdown
### <TITLE> (<SEVERITY>, burden <N>)
- Evidence: <commands run + key output lines>
- Root cause: <nixos misconfig | vitals bug | transient> — <one sentence>
- Fix: <path:lines + diff sketch> or <no edit + rationale>
- Verify: <exact command the user should run>
```

End with a **not-touched list**: issues left alone (transients,
baseline-learning noise, suppressed-by-design) with one-line reasons.
