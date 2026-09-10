---
name: jj-commit-workflow
description: Use when asked to commit, describe, push, or open a PR for changes in any jj-managed repo. Validates with repo-appropriate checks, then commits and pushes with jj (jjwork, jj describe, jjpush).
license: MIT
---

## Role

Jujutsu workflow assistant for validating and committing changes in any
jj-managed repository. Handles the full path from rebase to PR creation.
Validation steps are detected per repo — never assume a specific stack.

## Scope

Run the entire workflow in the current jj workspace — the repository that
contains the working directory where the skill was invoked. Never switch to
a different repository mid-workflow. If the cwd is a subdirectory, resolve
the workspace root with `jj root` and run root-relative commands (nix fmt,
prek, just, namaka, cargo) from there.

## Workflow Steps

Always execute these steps in order. Stop and report if any step fails.

### 1. Rebase onto main

```bash
jjwork
```

Skip if the repo has no remote configured (bare `git remote -v` check) —
report that jjwork was skipped.

If `jjwork` reports conflicts, run `jj resolve --list` and report them to the
user. Do not proceed past conflicts.

If `jjwork` refuses because the working copy has undescribed changes, give the
working copy a provisional conventional description (`jj describe -m
"wip: <summary>"`), then re-run `jjwork`. The split in step 4 replaces the
provisional message. Never bypass the guard with `JJWORK_ALLOW_WIP=1`.

### 2. Assess current state

```bash
jj status
jj diff --stat
```

Review the changed files. If the change set looks wrong (unintended files,
missing expected changes), report to the user before proceeding.

### 3. Validate (repo-adaptive detection)

Detect what exists and run those checks in this order. Skip what is absent
and say so in the final report. Fix any issues, then re-run until clean.

| Present | Run |
| --- | --- |
| `flake.nix` | `nix fmt` (if a formatter is configured), then `nix flake check` |
| `.pre-commit-config.yaml` | `prek run --all-files` (or `pre-commit run -a` if prek is missing) |
| `namaka.toml` | `namaka check` — on intentional snapshot changes, `namaka review` and accept |
| `justfile` | existing `just fmt` / `just build` / `just test` targets (`just --list` to discover) |
| `Cargo.toml` | `cargo build --release` and `cargo test` |
| none of the above | compile/smoke-test the change directly if applicable, else report validation skipped |

### 4. Split into logical commits

Review the diff and group the changed paths by concern. Each concern a
reviewer could evaluate on its own gets its own commit — features, fixes,
docs, refactors, and formatting/lockfile churn are separate commits. Only a
genuinely atomic change (a single concern with no separable parts) stays as
one commit.

Keep coupled changes together: a config change plus the code that consumes it,
or a rename plus its call-site updates, must not be split into commits that
would individually fail validation.

Split the working copy bottom-up with `jj split`. The selected paths go into
the parent commit; everything else stays in `@`, so the first split ends up
lowest in the stack and the final remainder is the top commit:

```bash
jj split <paths-of-first-concern> -m "<message>"
jj split <paths-of-next-concern> -m "<message>"
jj describe -m "<message-for-remainder>"
```

Generate a conventional message per commit. Follow the format:

```text
type(scope): description

- bullet points for notable changes
```

Types: feat, fix, chore, refactor, docs, test, perf.

### 5. Push and create PR

```bash
jjpush
```

Skip if the repo has no remote. `jjpush` pushes the bookmark and creates a
GitHub PR with the auto-merge label. If no PR should be created (e.g. push
to main), use `jj git push` instead.

## Git → jj Reference

| Git | jj |
| --- | --- |
| `git status` | `jj status` |
| `git diff` | `jj diff` |
| `git log --graph` | `jj log --graph` |
| `git add . && git commit` | `jj describe` (auto-tracks) |
| `git commit --amend` | `jj describe` (replaces) |
| `git reset HEAD~1` | `jj abandon` |
| `git checkout -- file` | `jj restore file` |
| `git checkout -b feat/x` | `jj bookmark create feat/x` |
| `git stash` / `git stash pop` | `jj shelve` / `jj unshelve` |
| `git merge main` | `jj rebase -d main` |
| `git push` | `jj git push` |
