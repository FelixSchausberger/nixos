# CLAUDE.md

This file provides guidance to Claude Code when working with tools in this
repository.

## Unix Philosophy

Tools in this directory follow the Unix philosophy:

### Core Principles

**Make each program do one thing well.**

To do a new job, build afresh rather than complicate old programs by adding new
features. Each tool should have a single, well-defined purpose. When new
functionality is needed, create a new tool instead of expanding an existing one
beyond its core responsibility.

**Expect the output of every program to become the input to another, as yet
unknown, program.**

Design tools to work together through composition. Output should be clean and
parseable, ready to be consumed by other tools in a pipeline. Don't clutter
output with extraneous information. Avoid stringently columnar or binary input
formats. Don't insist on interactive input.

**Write modular, simple, transparent, small, robust programs.**

Favor simplicity over complexity. Code should be easy to understand, maintain,
and reason about. Each component should be small enough to understand fully.
Programs should handle errors gracefully and fail explicitly rather than
silently.

**Avoid unnecessary output.**

Only output what is essential. Verbose output should be opt-in through flags
like `-v` or `--verbose`. By default, successful operations should be quiet.
Errors should be clear and actionable, written to stderr.

## Implementation Guidelines

When developing tools in this repository:

- Prefer text streams over complex data structures for inter-tool communication
- Accept input from stdin and write to stdout when appropriate
- Use exit codes: 0 for success, non-zero for failure
- Write errors and diagnostics to stderr
- Make tools composable through pipes and redirection
- Keep dependencies minimal
- Document expected input/output formats
- Provide clear error messages
- Follow the principle of least surprise

## Examples

Good:

```bash
# Tool produces clean output suitable for piping
tool list-configs | grep desktop | tool validate
```

Poor:

```bash
# Tool produces formatted output with headers and colors
# that break when piped
tool list-configs  # prints "=== Configurations ===" header
```

## Tools in This Directory

Each subdirectory contains a specific tool following these principles:

- `scripts`: Utility scripts for system operations
- `templates`: Project and configuration templates

See individual tool documentation for specific usage.
