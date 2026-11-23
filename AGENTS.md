# AGENTS.md

Repository guidance for AI agents. Cross-project behavior (jjwork-first,
rebuild prevention, rm shim, gh CLI preference) is defined globally in
`~/.config/opencode/AGENTS.md`; this file adds only what is specific to this
repository.

## GitHub purge in flight (support ticket #4956676)

History was rewritten 2026-11-05 with `git filter-repo
--sensitive-data-removal` and force-pushed; GitHub Support is purging the
archived pull refs and cached views (ticket
`help.github.com/ticket/personal/0/4956676`). While the ticket is open:

- No history rewrites or force-pushes of `main`. Normal append pushes stay
  subject to the usual user authorization for deployed changes, and every
  push must pass `prek run --all-files`; the `forbid-corporate-strings`
  blocklist applies permanently, ticket or not.
- A checkout is clean only when `git cat-file -e
  8d1acde80274c8981f9d567a1ec32b32dabc5f00` fails. The jj journal pins every
  pre-rewrite commit through `refs/jj/keep`, and comin's bare clone holds them
  in frozen packs, so `git reflog expire --expire=now --all && git gc
  --prune=now` cleans neither: re-clone `/per/etc/nixos` and
  `/var/lib/comin/repository`. The same source trees survive in the Nix store
  as inputs of old generations until `nix-collect-garbage -d`.
- Work git/SSH configuration lives in a private flake that depends on this
  repository and extends its host configurations; this repository never gains
  an input, URL or path pointing at it. The public tree carries only the two
  inert include lines (`~/.config/git/private.conf`,
  `~/.ssh/config.d/private.conf`).
- The blocklist is `tools/scripts/forbid-corporate-strings.sh`. It scans the
  tree (including `flake.lock`) and commit descriptions, and `jjpush` runs it
  as a blocking gate; `prek run --all-files` and CI run the same script.
- Full incident context (restricted file, user-owned, never echoed into tool
  output): `~/.local/share/ocws/incident-notes.md`.
- Remove this section only after the user reports the ticket closed.

## Repository

Personal NixOS and Home Manager configuration built on flakes and flake-parts.
The deployed fleet is `desktop`, `m920q`, and `hp-probook-wsl`; `surface` is a
full `nixosConfigurations` member built by CI. The opt-in shelf config is
`hp-probook-vmware` under `flake.legacyConfigurations`, and `hosts/portable`
builds the recovery ISO.

Key paths: `modules/system/` and `modules/home/` (modules), `hosts/` (host
configs), `home/profiles/` (Home Manager profiles), `pkgs/` (custom packages),
`apps/` (flake apps), `tests/` (namaka snapshots), `tests-vm/` (VM tests), and
`tools/` (utilities).

`Rookery` (the jj workspace manager) is consumed from the `rookery` flake input
and configured in `modules/home/tui/jujutsu.nix`. Its classifier test lives in
the project; this repo pins the consumer shapes in the
`rookery-consumer-contract` check (`flake-parts/dev.nix`).

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

- Work in a `rookery` workspace by default (`rookery <task>`). Editing the primary
  checkout directly is only for user-directed sessions, and only after
  `rookery ls` shows no other active claim. If another session's unpushed commit
  sits at `@`, halt and report: jj snapshots the working copy into `@`, so
  parallel edits merge silently into someone else's described commit. The V2
  config denies primary-checkout edits (absolute paths), though
  location-relative paths bypass that gate and a workspace cwd resolves them
  outside the primary - `rookery` remains the real boundary.
- Agents run as the owning user and never need `sudo`: deploys happen through
  comin (origin `main`, `switch`) or `jjtest` (testing bookmark,
  `switch-to-configuration test`); rebuild validation commands stay with the
  user.
- Keep the claim honest: `rookery ls` marks a workspace `live` when a process is
  rooted in its directory and `session` when an unarchived opencode session
  under it was updated within `ROOKERY_GC_SESSION_AGE` (default 7 days), so gc
  keeps a paused conversation after its TUI exits. An older session whose cwd
  is elsewhere still holds it silently, so check the session database
  (`~/.local/share/opencode/opencode.db`, `session_v2.directory`) before
  settling in. Two sessions in one directory cost a foreign plan file in a push
  and a re-claimed `@`; when foreign files appear, move to a fresh workspace and
  report them instead of committing them. A seat opened unnamed carries a filler
  `t-<HHMMSS>` description until `rookery title` claims it from the session title.
- A herdr workspace is the seat and a herdr tab a view inside it; neither owns
  the work. Opening a tab creates nothing, and closing one - even a workspace's
  last tab - never releases the jj claim or an open PR.
- Lead/worker orchestration: a lead resolves its seat with `rookery seat --json`,
  creates one worker per task with `rookery herdr --workspace <id> --json
  --no-focus --wait <task>`, prompts it with `herdr agent prompt <pane>
  --wait`, and reads the report file it names. Each worker owns its jj
  workspace; the lead never edits it and never answers a `blocked` agent. The
  protocol, report format and cleanup live in the `herdr-lead` skill.
- Scratch plans and audits under `.opencode/` stay ignored and never enter a
  commit; the global diff rule is what proves the change carries one concern.
  Park a session waiting on the outside world with
  `rookery wait <task> [reason...]` and release it with `rookery go <task>`: gc keeps
  parked workspaces whatever their commit state, and waits older than
  `ROOKERY_WAIT_STALE_DAYS` (default 14) resurface in gc output and the prompt
  badge.
- `jj workspace add` run from a stale workspace can leave the new working copy at
  jj's root commit; after creating a workspace, check `@-` is `main@origin` and
  run `jj new main@origin` when it is the root.
- herdr's git-worktree workspaces are deliberately unused: this repository
  isolates agents with jj workspaces, and a second git-based checkout would
  fight the jj op log.
- Close-out check: before wrapping up a session, re-run any task list the
  session started with and verify every item was addressed - committed,
  pushed, or explicitly deferred with a note. Sessions have repeatedly left
  half-staged work reported as done; this check is the remedy. After the PR
  merges, release the workspace with `rookery done <task>` (it refuses while
  unmerged work remains or a session is still rooted there). `rookery ls`
  classifies every workspace; `rookery gc` reclaims the empty/merged ones idle
  past the age gate, skipping any with a live process or a recent opencode
  session, and runs on `rookery <task>` and daily from a systemd user timer.
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
nix eval --json .#packages.x86_64-linux --apply 'ps: builtins.mapAttrs (_: v: v.drvPath) ps' >/dev/null
                       # instantiate all package drvs (flake check is WHNF-only; CI runs this)
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

Configuration lives in `modules/home/tui/ai-assistants/`:
`behaviors.nix` owns the global behavior definitions, `opencode/shared.nix`
assembles them with the model, permissions, formatters and skills,
`opencode/default.nix` holds the shell integration (`oc`, the GitHub token
export, sops secrets), and `opencode/opencode.nix` renders the config into the
canonical `~/.config/opencode/`. Project skills live in `.opencode/skills/`;
the rest are deployed globally from `ai-assistants/skills/`. Credentials are
database-backed, so `opencode auth login <provider>` is needed once.

Launch OpenCode through the launcher only: it is exposed as both `opencode` and
`opencode2`. `nix shell` or an absolute store path skips it and loses the
graveyard wiring; agent tool calls are covered separately by the `shell`
wrapper the config sets, because opencode builds the tool PATH from the login
shell rather than from its own environment.
