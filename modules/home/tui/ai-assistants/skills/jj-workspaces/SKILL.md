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
   ocws ls
   # or: jj log -r 'working_copies()' --no-graph
   ```

   An undescribed or unfinished `@` in another workspace means: do not touch
   that workspace. Report the conflict to the user and halt (same policy as the
   `jjwork` undescribed-WIP guard). No liveness signal is needed — an abandoned
   workspace is as much a hazard as an active one.

2. Create the workspace, claim it, and start opencode rooted there in one step:

   ```bash
   ocws <task>            # opencode in the current pane
   ocws tab <task>        # opencode in a new zellij tab
   ```

   The base directory is chosen in this order: `$OCWS_BASE`, the parent of the
   current workspace (the sibling-directory convention) when writable, then
   `$XDG_DATA_HOME/ocws` (default `~/.local/share/ocws`, created on demand), then
   `/tmp/opencode`. On this host `/per/etc` is root-owned, so the default base is
   `~/.local/share/ocws` — persistent and user-owned; a workspace lives at
   `<base>/nixos-ws-<task>`. Set `OCWS_BASE` to a persistent path for long-lived
   work. jj commits are stored in the shared repo regardless of where the
   working directory lives, so even the `/tmp/opencode` fallback never loses a
   revision.

   By hand (when `ocws` is unavailable):

   ```bash
   jj workspace add /abs/path/nixos-ws-<task> --name <task> \
     -r 'main@origin' -m "<task>: started from main@origin"
   cd /abs/path/nixos-ws-<task>
   ```

3. The change description **is** the claim. `ocws` writes it at creation. If you
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
   ocws rm <task>   # jj workspace forget + send the directory to the rip graveyard
   ```

   By hand: `jj workspace forget <task>` then `rip <dir>`. `forget` never
   deletes work — commits stay in the repo.

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
  `modules/home/shells/fish/functions/jj.nix`; do not remove it.
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
