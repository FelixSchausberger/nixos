#!/usr/bin/env bash
set -euo pipefail

LIBNOTIFY="@LIBNOTIFY@"
CLAUDE_NOTIFIER="@CLAUDE_NOTIFY@"

TITLE="Notification"
BODY=""

parse_args() {
  local -a args=("$@")
  local -a positional=()
  local i=0

  while ((i < ${#args[@]})); do
    local arg="${args[i]}"
    case "$arg" in
      --)
        positional+=("${args[@]:i+1}")
        break
        ;;
      --*=*)
        ;;
      --*)
        ((i++))
        ;;
      -*)
        if [[ "${#arg}" -eq 2 ]] && ((i + 1 < ${#args[@]})) && [[ "${args[i+1]}" != -* ]]; then
          ((i++))
        fi
        ;;
      *)
        positional+=("${args[@]:i}")
        break
        ;;
    esac
    ((i++))
  done

  if ((${#positional[@]} > 0)); then
    TITLE="${positional[0]}"
    if ((${#positional[@]} > 1)); then
      local rest=("${positional[@]:1}")
      BODY="${rest[*]}"
    else
      BODY=""
    fi
  fi
}

parse_args "$@"

if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  if "$LIBNOTIFY" "$@" >/dev/null 2>&1; then
    exit 0
  fi
fi

if [[ -n "${WSL_DISTRO_NAME:-}" && -f "$CLAUDE_NOTIFIER" ]]; then
  powershell=$(command -v powershell.exe 2>/dev/null || true)
  if [[ -n "$powershell" ]]; then
    path_win="$CLAUDE_NOTIFIER"
    if command -v wslpath >/dev/null 2>&1; then
      path_win=$(wslpath -w "$CLAUDE_NOTIFIER" 2>/dev/null || printf '%s' "$CLAUDE_NOTIFIER")
    fi
    "$powershell" -ExecutionPolicy Bypass -WindowStyle Hidden \
      -File "$path_win" \
      -Title "$TITLE" \
      -Message "$BODY" \
      >/dev/null 2>&1 || true
    exit 0
  fi
fi

>&2 printf 'Notification: %s' "$TITLE"
if [[ -n "$BODY" ]]; then
  >&2 printf ' - %s' "$BODY"
fi
>&2 printf '\n'
