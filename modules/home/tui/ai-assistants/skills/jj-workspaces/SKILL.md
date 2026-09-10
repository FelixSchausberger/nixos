---
name: jj-workspaces
description: Use when running parallel AI agents on the same repository, or when asked to isolate work in a jj workspace instead of the shared working copy. Covers workspace creation, agent handoff, and cleanup.
license: MIT
compatibility: opencode
---

## Role

Parallel-work isolation for jj repositories. jj workspaces are jj's equivalent
of git worktrees: sibling directories with their own `@` (working-copy commit)
sharing one revision graph. Use them whenever two agents might touch the same
repo concurrently — sessions sharing one working copy interleave edits and
produce conflicted bookmarks (observed failure mode).

## When to Use

Activate this skill when:

- The user asks for parallel/isolated work on this repo
- A second agent session is active on the same repository
- A task would collide with in-progress undescribed work

Do not activate for small sequential tasks — workspace overhead exceeds the
benefit for single quick changes.

## Workflow

0. Check for active claims before starting. The jj graph itself is the
   claim table — every workspace's `@` commit, its description, and its
   timestamp identify who owns which workspace and on what task:

   ```bash
   jj log -r 'working_copies()' --no-graph
   ```

   An undescribed or unfinished `@` in another workspace means: do not touch
   that workspace. Report the conflict to the user and halt (same policy as
   the `jjwork` undescribed-WIP guard). No liveness signal is needed — an
   abandoned workspace is as much a hazard as an active one. Optionally, an
   opencode server call (`GET /session`, `GET /session/status` on a reachable
   server) can enrich this with busy/idle session titles; it is decorative and
   may not exist in opencode 2.

1. Create the workspace as a **sibling directory** (never a subdirectory —
   child dirs get tracked by jj):

   ```bash
   jj workspace add ../nixos-ws-<task> --name <task>
   ```

2. Hand the agent the **absolute path** and a **change ID**. Agents lose track
   of relative cwd during work. In the target workspace:

   ```bash
   cd /absolute/path/to/nixos-ws-<task>
   jj edit <change-id>   # or jj new -m "describe the task first"
   ```

3. Describe before editing. The change description **is** the claim:
   creating the workspace and giving its `@` a description registers
   ownership atomically in the graph, with no external registry to prune or
   repair. A workspace with no description is by definition unclaimed and a
   hazard to other sessions. The `jjwork` guard refuses to rebase an
   undescribed non-empty working copy — in any workspace. Describe first,
   then implement.

4. Integration runs from the workspace itself: `jjwork` (rebases that
   workspace's `@` onto `main@origin`), then `jjpush`. The comin-autopush
   timer only watches the primary checkout (`/per/etc/nixos`) — secondary
   workspaces are never auto-pushed; the agent must push its own work.

5. Cleanup after the PR merges:

   ```bash
   jj workspace forget <task>   # unregisters; commits are preserved
   rm -rf ../nixos-ws-<task>    # forget does NOT delete the directory
   ```

## Naming Convention

Use one task string in three places so `working_copies()` output is
self-explanatory across sessions:

- workspace name: `nixos-ws-<task>`
- change description prefix: `"<task>: ..."`
- optionally, the opencode session title

A reader can then map any workspace `@` to its session without a registry.

## Rules

- Always use absolute paths in agent instructions.
- One agent per workspace; never share a working copy between agents.
- Tasks touching the same files do not parallelize — redesign the boundary
  instead.
- Lock files and shared config (flake.lock, secrets): one owner only, resolve
  at integration.

## Useful Revsets

| Expression          | Meaning                                  |
| ------------------- | ---------------------------------------- |
| `working_copies()`  | All workspaces' `@` commits              |
| `<task>@`           | A specific workspace's working copy      |
| `@`                 | The current workspace's working copy     |

## Troubleshooting

- "Stale working copy" after another workspace rebased shared history: run
  `jj workspace update-stale`. This is normal, not an error.
- `jj workspace list` shows every workspace and its `@`.
- `jj workspace forget` never deletes work — commits stay in the repo.
