# Bless-driven cleanup of proven-unbootable generations.
#
# systemd-boot boot counting skips entries whose tries hit +0-3, but the
# generations stay in the system profile — and the next bootloader install
# recreates their entries with fresh tries, re-arming the trap. This service
# runs once per successful boot: exhausted entries map (via their init=
# store path) to profile generation numbers; proven-bad, non-current
# generations are deleted once at least minGoodGenerations good ones exist
# (good = blessed suffixless entry on the ESP, or the running generation).
# Exhausted entry files are always removed immediately so they can never be
# selected again, and sibling entries of a deleted generation are removed
# with it. Everything is reported to the journal and (best-effort) ntfy;
# the unit always exits 0 so a helper failure can never fail a boot.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.bootFallback;
in {
  options.modules.system.bootFallback = {
    enable = lib.mkEnableOption "bless-driven cleanup of proven-unbootable generations";
    ntfyUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:2586/homelab-alerts";
      description = "ntfy URL receiving boot-fallback alerts (best-effort; cleanup never depends on it).";
    };
    minGoodGenerations = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Delete bad generations only when at least this many good ones exist.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.boot-fallback-cleanup = {
      description = "Delete generations whose boot entries exhausted boot-count tries";
      wantedBy = ["multi-user.target"];
      after = ["multi-user.target"];
      serviceConfig.Type = "oneshot";
      # NixOS prepends `set -e` to `script` wrappers, so every pipeline with
      # an expected non-zero status (empty grep, entry without init=) must
      # be guarded with `|| true` or an `if` condition. Otherwise the common
      # case (no exhausted entries) fails the unit despite the `exit 0`s.
      script = ''
        set -uo pipefail
        PROFILE=/nix/var/nix/profiles/system
        NTFY_URL=${lib.escapeShellArg cfg.ntfyUrl}
        MIN_GOOD=${toString cfg.minGoodGenerations}
        NIX_ENV=${pkgs.nix}/bin/nix-env
        CURL=${pkgs.curl}/bin/curl
        TAG=boot-fallback-cleanup

        notify() { # notify <title> <priority> <message>
          $CURL -fsS --max-time 10 \
            -H "Title: $1" -H "Priority: $2" -H "Tags: warning,cd" \
            -d "$3" "$NTFY_URL" >/dev/null 2>&1 \
            || echo "$TAG: ntfy unavailable, alert logged locally only" >&2
        }

        shopt -s nullglob
        current_toplevel=$(readlink -f /run/current-system)
        profile_toplevel=$(readlink -f "$PROFILE")

        # Print the profile generation number owning a toplevel store path.
        gen_of_toplevel() {
          local want=$1 link n
          for link in "$PROFILE"-*-link; do
            [ -e "$link" ] || continue
            if [ "$(readlink -f "$link")" = "$want" ]; then
              n="''${link#$PROFILE-}"
              echo "''${n%-link}"
              return 0
            fi
          done
          return 1
        }

        # init= store path of an entry file (empty when none, e.g. rescue entries).
        entry_init() {
          grep -oE 'init=/nix/store/[A-Za-z0-9._-]+-nixos-system-[^ [:space:]"]*' "$1" 2>/dev/null | head -1 || true
        }

        # Good generations: blessed (suffixless) entries plus the running one
        # (which is good by construction even if its entry file was GC'd).
        good_gens=""
        for entry in /boot/loader/entries/nixos-*.conf; do
          case "$entry" in *+*-*.conf) continue ;; esac
          init=$(entry_init "$entry" || true)
          [ -n "$init" ] || continue
          g=$(gen_of_toplevel "$(dirname "''${init#init=}")") || continue
          good_gens="$good_gens $g"
        done
        if g=$(gen_of_toplevel "$current_toplevel"); then
          good_gens="$good_gens $g"
        fi
        good_count=$(echo "$good_gens" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -nu | wc -l || true)
        good_count=$(echo "$good_count" | tr -d '[:space:]')
        [ -n "$good_count" ] || good_count=0

        # Bad generations: exhausted (+0-3) entries mapping to a profile gen.
        bad_gens=""
        for entry in /boot/loader/entries/nixos-*+0-3.conf; do
          init=$(entry_init "$entry" || true)
          if [ -z "$init" ]; then
            echo "$TAG: skip $(basename "$entry") (no init= path; likely specialisation)"
            continue
          fi
          top=$(dirname "''${init#init=}")
          if [ "$top" = "$current_toplevel" ] || [ "$top" = "$profile_toplevel" ]; then
            echo "$TAG: skip $(basename "$entry") (current generation, never delete)"
            continue
          fi
          if g=$(gen_of_toplevel "$top"); then
            bad_gens="$bad_gens $g"
          else
            echo "$TAG: skip $(basename "$entry") (toplevel not a profile generation)"
          fi
        done
        bad_gens=$(echo "$bad_gens" | tr ' ' '\n' | grep -E '^[0-9]+$' | sort -nu | tr '\n' ' ' || true)

        if [ -z "''${bad_gens// }" ]; then
          echo "$TAG: no exhausted entries ($good_count good generations)"
          exit 0
        fi

        if [ "$good_count" -lt "$MIN_GOOD" ]; then
          msg="Keeping proven-unbootable generation(s):$bad_gens (only $good_count good, need $MIN_GOOD); remove entry files only, delete manually once stable"
          echo "$TAG: $msg"
          # Still remove the exhausted files: unselectable now, and they would
          # otherwise be attempted again before the next install.
          for entry in /boot/loader/entries/nixos-*+0-3.conf; do rm -f "$entry"; done
          notify "Boot fallback cleanup deferred" "high" "$msg"
          exit 0
        fi

        failed=""
        ok_gens=""
        for g in $bad_gens; do
          if $NIX_ENV -p "$PROFILE" --delete-generations "$g" >/dev/null 2>&1; then
            ok_gens="$ok_gens $g"
          else
            failed="$failed $g"
          fi
        done

        # Remove every ESP entry (base + specialisations) of deleted gens so no
        # sibling entry can be selected later. Emergency/rescue extraEntries
        # carry no "Generation N" version line and are never matched.
        for g in $ok_gens; do
          { grep -lE "Generation $g NixOS" /boot/loader/entries/nixos-*.conf 2>/dev/null || true; } | while read -r f; do
            rm -f "$f" && echo "$TAG: removed $(basename "$f")"
          done
        done

        if [ -n "''${failed// }" ]; then
          msg="nix-env --delete-generations failed for:$failed; entry files removed, delete manually"
          echo "$TAG: $msg" >&2
          notify "Boot fallback cleanup needs attention" "high" "$msg"
        else
          msg="Deleted proven-unbootable generation(s):$ok_gens ($good_count good remain)"
          echo "$TAG: $msg"
          notify "Boot fallback cleanup" "default" "$msg"
        fi
        exit 0
      '';
    };
  };
}
