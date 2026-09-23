# Shared ntfy publish helper for alert scripts: publish on the primary topic
# and retry on an optional fallback topic when the primary publish fails. The
# local ntfy server shares this host's storage, so a full pool takes the
# primary channel down exactly when alerts matter most; a fallback topic on
# another server still delivers. Always returns success: callers run under
# `set -e`, so a dead notification channel must degrade to a journal line,
# not abort the remaining checks (no caller inspects the return value).
{
  pkgs,
  lib,
}: {
  primary,
  fallback ? "",
}: ''
  NTFY_URL=${lib.escapeShellArg primary}
  NTFY_FALLBACK=${lib.escapeShellArg fallback}
  ntfy_send() {
    local title="$1" prio="$2" tags="$3" body="$4"
    # -f fails on HTTP >= 400 (a broken ntfy still answering 5xx is a failed
    # publish, not a success, as observed 2026-09-15 on m920q when its own
    # sqlite died under a full pool).
    if ${pkgs.curl}/bin/curl -sf -o /dev/null \
      -H "Title: $title" -H "Priority: $prio" -H "Tags: $tags" \
      -d "$body" "$NTFY_URL"; then
      return 0
    fi
    echo "ERROR: ntfy publish failed for '$title'" >&2
    if [ -n "$NTFY_FALLBACK" ]; then
      ${pkgs.curl}/bin/curl -sf -o /dev/null \
        -H "Title: $title" -H "Priority: $prio" -H "Tags: $tags" \
        -d "primary channel down: $body" "$NTFY_FALLBACK" \
        || echo "ERROR: fallback ntfy publish failed for '$title'" >&2
    fi
    return 0
  }
''
