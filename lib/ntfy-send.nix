# Shared ntfy publish helper for alert scripts: publish each message to the
# primary channel and, only when that publish fails, to the secondary
# channel. One channel per message in normal operation - a phone subscribed
# to both topics must not have to mute one of them - with the secondary as a
# safety net rather than a second copy: the local ntfy shares this host's
# storage, so a full pool takes it down exactly when disk alerts matter most
# (2026-09-15 on m920q: sqlite died under a full pool and answered 5xx).
# Failover covers a failed publish only, never a failed delivery - a publish
# that succeeds says nothing about delivery (2026-09-27: publishes landed for
# hours while the peer's subscriber was gone), which no publish-side logic
# can cover. Each channel is a literal URL or a file holding it (typically a
# sops secret, because the topic name is password-equivalent). Always returns
# success: callers run under `set -e`, so a dead notification channel must
# degrade to a journal line, not abort the remaining checks (no caller
# inspects the return value).
{
  pkgs,
  lib,
}: {
  # Primary channel: a literal URL, or a file holding it (primaryFile).
  primary ? "",
  primaryFile ? "",
  # Secondary channel, published to only when the primary publish fails:
  # a literal URL, or a file holding it (secondaryFile).
  secondary ? "",
  secondaryFile ? "",
}: ''
  NTFY_PRIMARY=${lib.escapeShellArg primary}
  NTFY_PRIMARY_FILE=${lib.escapeShellArg primaryFile}
  NTFY_SECONDARY=${lib.escapeShellArg secondary}
  NTFY_SECONDARY_FILE=${lib.escapeShellArg secondaryFile}

  # Resolves a channel to its URL: a readable, non-empty file wins over the
  # literal, so a rotated secret takes effect without a redeploy. Echoes
  # nothing when the channel is unconfigured, which the caller reads as
  # "no such channel" rather than a failed publish. A configured file that
  # yields no URL is not the same thing: it means the out-of-band channel is
  # gone while the alert still leaves, so say so instead of downgrading
  # quietly.
  ntfy_resolve() {
    if [ -n "$2" ] && [ -r "$2" ]; then
      file_url=$(${pkgs.coreutils}/bin/cat "$2" 2>/dev/null || true)
      if [ -n "$file_url" ]; then
        printf '%s' "$file_url"
        return 0
      fi
    fi
    if [ -n "$2" ]; then
      echo "ERROR: ntfy URL file $2 did not yield a URL" >&2
    fi
    printf '%s' "$1"
  }

  # $1 = destination URL, then title, priority, tags, body. -f fails on HTTP
  # >= 400: a broken ntfy still answering 5xx is a failed publish, not a
  # success (observed 2026-09-15 on m920q when its own sqlite died under a
  # full pool).
  ntfy_publish() {
    ${pkgs.curl}/bin/curl -sf -o /dev/null \
      -H "Title: $2" -H "Priority: $3" -H "Tags: $4" \
      -d "$5" "$1"
  }

  ntfy_send() {
    local title="$1" prio="$2" tags="$3" body="$4" primary secondary
    primary=$(ntfy_resolve "$NTFY_PRIMARY" "$NTFY_PRIMARY_FILE")
    # Resolve the safety net on every send, not just after a failure: a
    # failover path is exercised only on the worst day, so a secret that has
    # rotted must surface in the journal while alerts still deliver.
    secondary=$(ntfy_resolve "$NTFY_SECONDARY" "$NTFY_SECONDARY_FILE")
    if [ -n "$primary" ]; then
      if ntfy_publish "$primary" "$title" "$prio" "$tags" "$body"; then
        return 0
      fi
      echo "ERROR: ntfy primary publish failed for '$title'" >&2
    fi
    if [ -n "$secondary" ]; then
      ntfy_publish "$secondary" "$title" "$prio" "$tags" "$body" \
        || echo "ERROR: ntfy secondary publish failed for '$title'" >&2
    fi
    return 0
  }
''
