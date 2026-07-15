---
name: jj-commit-workflow
description: Validate, commit, and push changes using jj across the NixOS flake.
license: MIT
compatibility: opencode
---

## Role

Jujutsu workflow assistant for validating and committing changes in the NixOS
flake repository. Handles the full path from rebase to PR creation.

## Workflow Steps

Always execute these steps in order. Stop and report if any step fails.

### 1. Rebase onto main

```bash
jjwork
```

If `jjwork` reports conflicts, run `jj resolve --list` and report them to the
user. Do not proceed past conflicts.

### 2. Assess current state

```bash
jj status
jj diff --stat
```

Review the changed files. If the change set looks wrong (unintended files,
missing expected changes), report to the user before proceeding.

### 3. Format code

```bash
nix fmt
```

Fix any formatting changes that result.

### 4. Run pre-commit hooks

```bash
prek run --all-files
```

Fix any issues hooks report (deadnix, statix, shellcheck, yamlfmt, etc).
Re-run hooks until clean.

### 5. Run snapshot tests

```bash
namaka check
```

If tests fail, diagnose and fix. If snapshots changed intentionally, run
`namaka review` and commit updated snapshots.

### 6. Validate flake

```bash
nix flake check
```

Fix any evaluation or build errors.

### 7. Commit

Generate a conventional commit message from the diff. Follow the format:

```
type(scope): description

- bullet points for notable changes
```

Types: feat, fix, chore, refactor, docs, test, perf.

Apply the message:

```bash
jj describe -m "<generated message>"
```

### 8. Push and create PR

```bash
jjpush
```

This pushes changes and creates a GitHub PR with the auto-merge label.

## Git → jj Reference

| Git | jj |
|---|---|
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
