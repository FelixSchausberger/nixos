---
name: jj-workspaces
description: Use when running parallel AI agents on the same repository, or when asked to isolate work in a jj workspace instead of the shared working copy. Covers workspace creation, agent handoff, and cleanup.
license: MIT
compatibility: opencode
---

## Role

Parallel-work isolation for jj repositories. jj workspaces are jj's equivalent
of git worktrees: separate directories with their own `@` (working-copy commit)
sharing one revision graph. Use them whenever two agents might touch the same
repo concurrently — sessions sharing one working copy interleave edits and
produce conflicted bookmarks (observed failure mode).

The primary checkout (`/per/etc/nixos`) is reserved for the user and the comin
reconciler. Agents should work in a workspace.

## Herdr model

The fleet runs agents inside herdr, whose three layers do not map onto the
claim:

- herdr workspace — the UI container for a repository (the fleet runs one);
  it is not one per agent.
- herdr tab — a layout inside a workspace; use tabs for views (agent, logs,
  server, review).
- herdr pane — one real terminal.

The fleet runs one herdr workspace per repository and one tab per agent. The
isolation unit is the jj workspace the tab's agent runs in: tabs in one herdr
workspace each have their own jj workspace when they are created through
`rookery`.

A lead creates each worker with `rookery herdr --workspace <id>`; the worker gets
its own jj workspace and a tab in the lead's herdr workspace. The lead prompts
it, reads the report file, closes only the tabs it created, and releases the
workspace with `rookery done`. The `herdr-lead` skill owns the delegation protocol;
`herdr worktree` and fan remain unused.

The claim lives in jj, not in herdr. `rookery <task>` creates the jj workspace,
writes the change description, and starts opencode rooted at the workspace.
Opening a tab on its own creates nothing: the tab is where the command runs,
not what owns the work. Closing a tab — even a workspace's last tab, which
closes the herdr workspace — never releases the jj claim or an open PR.
`rookery tab` is the zellij variant and does not apply inside herdr, whose panes
carry no zellij session. With `terminal.new_cwd = follow`, a new tab inherits
the focused pane's directory, so a tab can start inside another agent's
worktree; start agents through `rookery`, not a bare tab.

## When to Use

Activate this skill when:

- The user asks for parallel/isolated work on this repo
- A second agent session is active on the same repository
- A task would collide with in-progress undescribed work

Do not activate for small sequential tasks — workspace overhead exceeds the
benefit for single quick changes.

## Workflow

1. Check for active claims before starting. The jj graph itself is the claim
   table — every workspace's `@` commit, its description, and its timestamp
   identify who owns which workspace and on what task:

   ```bash
   rookery ls
   # or: jj log -r 'working_copies()' --no-graph
   ```

   An undescribed or unfinished `@` in another workspace means: do not touch
   that workspace. Report the conflict to the user and halt (same policy as the
   `jjwork` undescribed-WIP guard). No liveness signal is needed — an abandoned
   workspace is as much a hazard as an active one.

2. Create the workspace, claim it, and start opencode rooted there in one step:

   ```bash
   rookery <task>            # opencode in the current pane, named up front
   rookery herdr             # new agent seat in a new herdr tab, filler name
   rookery herdr <task>      # same, with a task name you already know
   rookery tab <task>        # opencode in a new zellij tab (not inside herdr)
   ```

   Inside herdr, `prefix+shift+a` runs `rookery herdr` with no task, bound
   detached: the tab appears with a filler task (`t-<HHMMSS>`), the workspace is
   created without the gc pass and fetch that would delay it, and opencode
   starts. Once OpenCode names the session, the seat plugin runs
   `rookery title "<title>"`, which sets the change description, renames the
   workspace and renames the herdr tab — once, and only while the description is
   still the placeholder `jj workspace add` wrote. Run `rookery title` by hand if
   the plugin is off; it is a no-op on an already-claimed workspace. Re-running
   `rookery herdr <task>` for an existing task reopens the seat only when no process
   is live in that workspace.

   The base directory is chosen in this order: `$ROOKERY_BASE`, the parent of the
   current workspace (the sibling-directory convention) when writable, then
   `$XDG_DATA_HOME/ocws` (default `~/.local/share/ocws`, created on demand), then
   `/tmp/opencode`. On this host `/per/etc` is root-owned, so the default base is
   `~/.local/share/ocws` — persistent and user-owned; a workspace lives at
   `<base>/nixos-ws-<task>`. Set `ROOKERY_BASE` to a persistent path for long-lived
   work. jj commits are stored in the shared repo regardless of where the
   working directory lives, so even the `/tmp/opencode` fallback never loses a
   revision.

   By hand (when `rookery` is unavailable):

   ```bash
   jj workspace add /abs/path/nixos-ws-<task> --name <task> \
     -r 'main@origin' -m "<task>: started from main@origin"
   cd /abs/path/nixos-ws-<task>
   ```

3. The change description **is** the claim. `rookery` writes it at creation. If you
   created the workspace by hand, describe before editing:

   ```bash
   jj describe -m "<task>: ..."
   ```

   Creating the workspace and describing its `@` registers ownership atomically
   in the graph, with no external registry to prune or repair. A workspace with
   no description is by definition unclaimed and a hazard to other sessions. The
   `jjwork` guard refuses to rebase an undescribed non-empty working copy — in
   any workspace.

4. Integration runs from the workspace itself: `jjwork` (rebase that
   workspace's `@` onto `main@origin`), then `jjpush`. Nothing pushes background
   work: the primary checkout and secondary workspaces are pushed only by an
   explicit `jjpush` (or `jjtest` for a test deploy).

5. Cleanup after the PR merges:

   ```bash
   rookery ls            # classify every workspace; empty/merged are reclaimable
   rookery done <task>   # fetch, refuse if unmerged or live, then forget + rip
   ```

   `rookery ls` is a read-only status board. Each workspace is classified `empty`
   (nothing outside `main@origin`), `merged` (its content is already absorbed
   into `main@origin`), `unpushed` (content no remote bookmark tracks),
   `in-flight` (content with an open PR), `conflict`, or `waiting` (parked with
   `rookery wait`). The summary's `stale` count is separate: workspaces that gc
   could reclaim now if not for the age gate. Absorption is checked
   per revision, so a squash-merged PR counts as finished even though its draft
   commit is not an ancestor of `main@origin`; unsnapshotted edits in a foreign
   workspace are invisible by design (rookery never snapshots a workspace it does
   not own). The `HOLD` column shows `live` (a process rooted in the workspace),
   `session` (an unarchived opencode session under it updated within
   `ROOKERY_GC_SESSION_AGE`, default 604800s), or `-` (idle).

   `done` refuses while unmerged work remains or a process is still rooted in
   the workspace (`--force` overrides both), so it doubles as a close-out
   check. `rookery gc` reclaims `empty`/`merged` workspaces, skipping any with a
   live process, any held by a recent session, and any touched within the age
   gate: an empty unclaimed workspace after `ROOKERY_GC_EMPTY_AGE` (default
   21600s), one that held work after `ROOKERY_GC_AGE` (default 86400s). It runs
   on `rookery <task>` and daily from a systemd user timer. `rookery rm
   [--force] <task>` removes without the fetch/check; `--force` discards
   unmerged work and live sessions.

   By hand: `jj workspace forget <task>` then `rip <dir>`. `forget` never
   deletes work — commits stay in the repo.

6. Park a session that must idle on an outside blocker (an upstream fix, a
   device shipment) instead of keeping its pane alive as the only preservation:

   ```bash
   rookery wait <task> [reason...]   # mark parked; gc then keeps it whatever
                                  # its commit state
   rookery go <task>                 # release; gc reclassifies on the next pass
   ```

   The wait marker (`<base>/<task>.wait`, reason + timestamp) lives outside
   the working copy, so no snapshot can absorb it into a claim commit, and
   every removal path (`done`, `rm`, `gc`) clears it with the workspace. A
   parked workspace resurfaces when the wait passes `ROOKERY_WAIT_STALE_DAYS`
   (default 14): gc nudges to resume or release, the prompt badge shows a
   reminder count, and `rookery ls --board` lists it under PARKED.

## Naming Convention

Use one task string in three places so `working_copies()` output is
self-explanatory across sessions:

- workspace name: `<task>` (directory `nixos-ws-<task>`)
- change description prefix: `"<task>: ..."`
- optionally, the opencode session title

A reader can then map any workspace `@` to its session without a registry.

## Concurrency Hazards

- `jj-tidy` (run by `jjwork` in the primary checkout) must exclude
  `working_copies()` from its abandonment candidates. A freshly created
  workspace `@` is childless and empty, so without the exclusion it is "fully
  absorbed" into `main@origin` and gets abandoned and reset under a parallel
  agent's feet. The exclusion lives in
  `pkgs/jj-tools/jj-tidy.nix`; do not remove it.
- comin only reconciles the primary checkout. Never rely on it to push a
  secondary workspace's change.
- One writer per clone: do not run interactive jj mutations in the primary
  checkout concurrently from another session.

## Rules

- Always use absolute paths in agent instructions.
- One agent per workspace; never share a working copy between agents.
- Tasks touching the same files do not parallelize — redesign the boundary
  instead.
- Lock files and shared config (flake.lock, secrets): one owner only, resolve
  at integration.

## Useful Revsets

| Expression         | Meaning                              |
| ------------------ | ------------------------------------ |
| `working_copies()` | All workspaces' `@` commits          |
| `<task>@`          | A specific workspace's working copy  |
| `@`                | The current workspace's working copy |

## Troubleshooting

- "Stale working copy" after another workspace rebased shared history: run
  `jj workspace update-stale`. This is normal, not an error.
- Secondary workspaces in a colocated repo have no `.git`. `prek` still works
  there through the devShell wrapper, which supplies a throwaway repository and
  index. Git-based tooling that bypasses `GIT_DIR` may still fail; run those
  from the primary checkout. CI runs the full hook set on the PR.
- `jj workspace list` shows every workspace and its `@`.
- `jj workspace forget` never deletes work — commits stay in the repo.
- A parked workspace (`rookery wait <task>`) is kept by `rookery gc` whatever its
  commit state until `rookery go <task>` clears the marker; waits older than
  `ROOKERY_WAIT_STALE_DAYS` (default 14) surface as gc nudges and a prompt-badge
  reminder.

## Zellij fallback

`rookery tab` is the zellij variant, used only when herdr is not the surface. The
0.46 attention inbox tracks panes in the zellij server it runs in; agents in
herdr never appear there. Zellij reads keybinds, `env` and `attention` at
server start, so a server that predates a config change keeps the old map.
Verify in a fresh session, never by restarting a session with live panes:

```bash
# raw protocol probe: the blocked pane becomes the next attention target
printf '\e]7501;state=blocked:kind=permission:app=test:msg=QXBwcm92ZT8=\e\\'
```

The opencode client plugin writes the same sequences to `/dev/tty`;
`OPENCODE_OSC7501_DEBUG=1` traces it under `[osc7501]`.
