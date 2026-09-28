# Shared ntfy publish helper for alert scripts: publish every message to
# every configured channel. The local ntfy server shares this host's
# storage, so a full pool takes it down exactly when alerts matter most;
# and a publish that succeeds says nothing about delivery (2026-09-27:
# publishes landed for hours while the peer's subscriber was gone), which
# a failure-triggered fallback can never cover. The secondary URL lives in
# a file (typically a sops secret) because the topic name is
# password-equivalent. Always returns success: callers run under
# `set -e`, so a dead notification channel must degrade to a journal line,
# not abort the remaining checks (no caller inspects the return value).
{
  pkgs,
  lib,
}: {
  primary,
  # Path to a file containing the secondary ntfy URL; empty disables it.
  secondaryFile ? "",
}: ''
  NTFY_URL=${lib.escapeShellArg primary}
  NTFY_SECONDARY_FILE=${lib.escapeShellArg secondaryFile}
  ntfy_send() {
    local title="$1" prio="$2" tags="$3" body="$4"
    # -f fails on HTTP >= 400 (a broken ntfy still answering 5xx is a failed
    # publish, not a success, as observed 2026-09-15 on m920q when its own
    # sqlite died under a full pool).
    ${pkgs.curl}/bin/curl -sf -o /dev/null \
      -H "Title: $title" -H "Priority: $prio" -H "Tags: $tags" \
      -d "$body" "$NTFY_URL" \
      || echo "ERROR: ntfy primary publish failed for '$title'" >&2
    if [ -n "$NTFY_SECONDARY_FILE" ] && [ -r "$NTFY_SECONDARY_FILE" ]; then
      secondary_url=$(${pkgs.coreutils}/bin/cat "$NTFY_SECONDARY_FILE" 2>/dev/null || true)
      if [ -n "$secondary_url" ]; then
        ${pkgs.curl}/bin/curl -sf -o /dev/null \
          -H "Title: $title" -H "Priority: $prio" -H "Tags: $tags" \
          -d "$body" "$secondary_url" \
          || echo "ERROR: ntfy secondary publish failed for '$title'" >&2
      fi
    fi
    return 0
  }
''
