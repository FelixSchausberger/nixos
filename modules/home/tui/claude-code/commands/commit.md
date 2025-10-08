---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
description: Create a git commit with proper message
---

## Context

- Current git status: !`git status`
- Current git diff: !`git diff HEAD`
- Recent commits: !`git log --oneline -5`

## Task

Based on the changes above, create a single atomic git commit with a descriptive message.

## Commit message convention

- `feat:` - New feature
- `fix:` - Bug fix
- `chore:` - Maintenance
- `docs:` - Documentation
- `refactor:` - Code restructuring
- `test:` - Test changes
- `ci:` - CI/CD changes

