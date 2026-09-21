# AGENTS.md

Repository guidance for AI agents. Cross-project behavior (jjwork-first,
rebuild prevention, rm shim, gh CLI preference) is defined globally in
`~/.config/opencode/AGENTS.md`; this file adds only what is specific to this
repository.

## Repository

Personal NixOS and Home Manager configuration built on flakes and flake-parts.
The deployed fleet is `desktop`, `m920q`, and `hp-probook-wsl`. Additional
configs (`surface`, `hp-probook-vmware`) are opt-in under
`flake.legacyConfigurations`, and `hosts/portable` builds the recovery ISO.

Key paths: `modules/system/` and `modules/home/` (modules), `hosts/` (host
configs), `home/profiles/` (Home Manager profiles), `pkgs/` (custom packages),
`tests/` (namaka snapshots) and `tests-vm/` (VM tests), `tools/` (utilities).

## Documentation Policy

Every fact has one authoritative source: project usage in `README.md`, AI
guidance in `AGENTS.md`, operational procedures in the GitHub Wiki, and code
behavior in inline comments.

Do not create new Markdown files beyond these exceptions:

- `README.md` — project entry point and quick reference
- `AGENTS.md` — AI guidance
- `hosts/installer/README.md` and `hosts/installer/ssh_keys/README.md` —
  installation procedure

Tool-owned Markdown is out of scope of this policy: skill files
(`SKILL.md`), Claude Code commands/agents, `tools/templates/` documentation,
and `docs/site/` content. Long-form material does not belong in the repo as
new Markdown files: architectural decisions stay as inline comments;
procedures live in the GitHub Wiki.

Architectural decisions, design rationale, and "why" choices belong as inline
comments at the site they describe, never in separate overview files.

Comments describe the current state, not relative changes: "uses foo for
authentication", never "changed from bar to foo". Explain why, not what.
Documentation, comments, and committed artifacts contain no emojis.

## Workflow

The global rules cover `jjwork` and workspace isolation. Repository specifics:

- Work in an `ocws` workspace by default (`ocws <task>`). Editing the primary
  checkout directly is only for user-directed sessions, and only after
  `ocws ls` shows no other active claim. If another session's unpushed commit
  sits at `@`, halt and report: jj snapshots the working copy into `@`, so
  parallel edits merge silently into someone else's described commit.
- Agents run as the owning user and never need `sudo`: deploys happen through
  comin (origin `main`, `switch`) or `jjtest` (testing bookmark,
  `switch-to-configuration test`); rebuild validation commands stay with the
  user.
- Close-out check: before wrapping up a session, re-run any task list the
  session started with and verify every item was addressed - committed,
  pushed, or explicitly deferred with a note. Sessions have repeatedly left
  half-staged work reported as done; this check is the remedy.
- `jjpush` only pushes changes descended from `main`. If it refuses, run
  `jjwork` first.
- One long-lived branch: `main`. Every other branch is ephemeral and
  auto-created by `jjpush` from the commit description; never push a named
  branch by hand.
- One concern per change and per PR. Squash-merge collapses a PR to one commit,
  so split with `jj split`, fold follow-up fixes with `jj absorb`, and turn
  accidentally-stacked changes into siblings with `jj parallelize`.
- Rebase only with jj. `git rebase`, `git commit --amend`, and `gh stack`
  rebase/sync verbs run a second rebase engine and cause divergent change-ids.
- Deploy WIP with `jjtest`, not a background timer: it points the per-host
  `testing-<hostname>` bookmark at a change for the comin local remote to apply
  with `switch-to-configuration test`. `jjpush` lands changes on `main`.

## Validation

Run before pushing:

```bash
nix fmt                # alejandra, prettier, treefmt
prek run --all-files   # commit hooks (deadnix, statix, ripsecrets, ...)
namaka check           # snapshot tests
nix flake check        # evaluate all configurations
```

`just` wraps common flows (`just niri-validate`, `just fmt`, `just test`,
`just validate`); the recipes require `nix develop`.

When a change needs a rebuild, test with
`sudo nixos-rebuild test --flake .` and ask the user to apply it permanently.

## Skills

Load the matching skill instead of guessing: `nix-expert` (flake, derivations,
modules, packaging), `nix-testing` (namaka and VM tests), `jj-commit-workflow`
(commit, describe, push), `jj-workspaces` (parallel-agent isolation). Defined
in this repository: `repo-audit` (flake audit, `.opencode/skills/`) and
`vitals-triage` (systemd/vitals issues).

## AI Assistant Configuration

Configuration lives in `modules/home/tui/ai-assistants/opencode/`: `shared.nix`
holds the values both harnesses need (model, permissions, formatters, skills,
behavior context, agent text), `default.nix` renders the V1 config, and `v2.nix`
renders the opt-in OpenCode 2 beta config (`ai-assistants.opencodeV2.enable`)
into `~/.config/opencode-v2/opencode/`. V2 is isolated because it loads the V1
plugin list by union and V1-only plugins have no V2 entrypoint; its credentials
are database-backed, so `opencode2 auth login <provider>` is needed once.
