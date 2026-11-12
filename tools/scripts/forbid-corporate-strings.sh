#!/usr/bin/env bash
# Employer identifiers are never public-tree material: the work git/SSH
# configuration lived in this repository for a year before the security scrub,
# and the GitHub history purge is still open. This script is the single source
# of the blocklist; the prek hook and jjpush both call it, so an entry can only
# be added or dropped in one place.
#
# The pattern segments are split into character classes so this file never
# spells the identifiers it forbids. Hits are reported as file names only - a
# matched line must never reach a terminal scrollback or a CI log.
#
# Usage:
#   forbid-corporate-strings.sh              scan the tracked tree
#   forbid-corporate-strings.sh --message F  scan a commit message file
set -euo pipefail

readonly pattern='freq[u]entis|b[i]tbucket|p[d]ts|sch[a]usbergerf|f[v]cs|f[a]ax10'

# sops ciphertext cannot spell an identifier, and the encrypted file is the one
# path whose content is deliberately unreadable.
readonly skip=(--glob '!secrets/**')

report() {
  local label="$1"
  shift
  local hits
  hits="$(rg -i -l "${skip[@]}" -e "$pattern" "$@" 2>/dev/null || true)"
  if [[ -n "$hits" ]]; then
    printf 'forbid-corporate-strings: %s\n' "$label" >&2
    printf '%s\n' "$hits" | sed 's/^/  /' >&2
    return 1
  fi
}

if [[ ${1:-} == --message ]]; then
  if [[ -z ${2:-} ]]; then
    echo "usage: $0 --message <file>" >&2
    exit 2
  fi
  report "blocked identifier in the commit message" -- "$2"
  exit
fi

report "blocked identifier in the tree" -- .
