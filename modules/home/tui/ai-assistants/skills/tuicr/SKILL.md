---
name: tuicr
description: Use when reviewing a diff, commit range, or forge PR in the tuicr terminal TUI, or when the user has left review comments there for you to act on. Covers opening the review pane and reading or adding comments through the tuicr review CLI.
license: MIT
---

## Role

tuicr is the fleet's terminal code-review TUI. The human reviews and comments
in the pane; the agent reads those comments through `tuicr review` and acts on
them. tuicr speaks git, jj and mercurial natively, and `:submit` pushes a real
inline review to GitHub through `gh`, so it fits the jj + `gh pr` workflow used
in this repository.

The TUI is the human's surface. Do not start or drive it unless the user asked
you to.

## When to Use

Activate when:

- The user wants to review a patch, a commit range, or a pull request
  interactively.
- The user says their tuicr comments are ready and asks you to address them.
- You are explicitly waiting on a review the user is doing in tuicr.

Do not activate when the user asks for raw `git diff`/`jj diff` output, or names
a different review tool.

## Open The Review Pane

The pane belongs to the user, so tell them how to open it rather than opening
one yourself:

- Under herdr: `prefix+shift+c` opens `tuicr` in a popup bound by
  `modules/home/tui/tuicr/default.nix`.
- Anywhere else (a bare shell, a Zellij pane): run `tuicr` in the repository
  root.

Bare `tuicr` opens its target selector, which is where the worktree, commit
range, forge PR and saved-session scopes are chosen. Do not pass `-w` or
`-r <revset>` on the user's behalf; let them pick the scope.

## Read The User's Comments

There is no push from tuicr to the agent; read on demand.

1. Find the session. Pass the repository root, not a subdirectory, and pass
   `--all` before concluding nothing is open:

   ```bash
   tuicr review list --repo /path/to/repo
   ```

2. Read the comments for the session slug reported by the listing:

   ```bash
   tuicr review comments --repo /path/to/repo --session <slug>
   ```

   The output is JSON. Each comment carries `id`, `path`, `start_line`,
   `end_line`, `side`, `comment_type`, `author`, `lifecycle_state` and
   `content`.

3. Treat `comment_type` as the priority: `issue` is a blocking problem,
   `suggestion` is worth implementing or explaining, `note` is an
   acknowledgement, `praise` needs nothing.

If several sessions are active, or the slug is unclear, ask which one instead of
guessing; adding to the wrong session exits 0 and looks successful.

While the user is still reviewing, re-running the same command and comparing
`id`s is how new comments appear. Read immediately when the user says the review
is done, and stop polling once it is.

An empty result is not automatically an unfinished review: compare
`reviewed_count` against `file_count` from `tuicr review list`. Equal means the
user reviewed everything and flagged nothing, which is a complete review.

## Add Comments As The Agent

Only when the user asks you to review and approves writing the comments:

```bash
tuicr review add --repo /path/to/repo --session <slug> \
  --target-file src/main.rs --line 42 --side new \
  --type issue --username "<agent>" "Handle the empty case here."
```

Always pass `--username` so agent comments are distinguishable from the user's,
and prefer `--type issue`. Use `--side old` for removed lines and `--side new`
for added or unchanged lines. Re-read `tuicr review comments` afterwards and
check the line exists on the side you gave: a line outside the diff stores and
exits 0 but never renders.

## Cautions

- Never run `tuicr update`. Nix owns the binary
  (`modules/home/tui/tuicr/default.nix`, nixpkgs `tuicr`); the command targets a
  package manager's install and would fight the Home Manager profile.
- The theme is the bundled `catppuccin-mocha`, and `editor` is unset so tuicr
  inherits `$EDITOR` (`nvedit`). Do not reintroduce a literal `nvim` editor
  setting.
- In this repository, review the change in the jj workspace that holds it.
  tuicr detects jj without a `.git` directory, so a secondary workspace is a
  valid review target.
