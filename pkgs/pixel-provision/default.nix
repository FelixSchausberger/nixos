# GrapheneOS provisioning for the Pixel 10a, built from lib/phone.nix. A
# desktop-side (m920q) helper: `pair` wires up wireless adb, `apply` pushes the
# manifest settings and the F-Droid lane and prints the interactive-lane
# checklists, `links` renders the Obtainium bulk import, `check` audits the
# result against the manifest. Android-side state (sign-ins, patcher runs) has
# no machine interface, so those steps print as a checklist instead of lying
# about being runnable.
{
  writeText,
  writeShellScriptBin,
  lib,
  android-tools,
  coreutils,
  # sed and grep: the `check` audit greps the package list on-device.
  gnugrep,
  gnused,
  fdroidcl,
  jq,
  openssh,
}: let
  manifest = (import ../../lib/phone.nix) {};
  manifestJson = writeText "phone-manifest.json" (builtins.toJSON manifest);
  m920qAddress = "100.105.37.12";
in
  writeShellScriptBin "pixel-provision" ''
            PATH=${lib.makeBinPath [android-tools coreutils gnugrep gnused fdroidcl jq openssh]}
            ADB=${android-tools}/bin/adb
            MANIFEST=${manifestJson}
            # The privacy lane lives outside the repository by design:
            # user-managed file, never committed; missing file is a no-op.
            PRIVATE=''${HOME}/.config/pixel-provision/private-apps.json

            lane() { jq -r ".$1[]" "$MANIFEST"; }
            private_lane() {
              if [ -f "$PRIVATE" ]; then
                jq -r '.aurora[] // empty' "$PRIVATE"
              fi
            }

            ensure_device() {
              if ! "$ADB" get-state >/dev/null 2>&1; then
                echo "no adb device connected - run 'pixel-provision pair ...' first" >&2
                exit 1
              fi
            }

            obtainium_bulk_link() {
              payload=$(jq -c '[.lanes.obtainium[] | {id, url, author, name}]' "$MANIFEST")
              encoded=$(printf %s "$payload" | jq -sRr @uri)
              echo "obtainium://apps/$encoded"
            }

            nextdns_resolution() {
              # Precedence: NEXTDNS env, the manifest value, then a prompt - an empty
              # result means the specifier stays untouched and the phone keeps its
              # resolver until the user names one.
              v="''${NEXTDNS:-}"
              if [ -z "$v" ]; then
                v=$(jq -r '.nextDnsHostname // ""' "$MANIFEST")
              fi
              if [ -z "$v" ]; then
                printf 'NextDNS private DNS hostname (empty to skip): ' >&2
                read -r v >&2 || true
              fi
              echo "$v"
            }

            case ''${1:-help} in
              pair)
                # Wireless debugging pairing, exactly the flow the 9a used over the
                # tailnet: pairing port and code come from the pairing dialog, the
                # main port from the Wireless debugging screen.
                pairTarget=''${2:?usage: pixel-provision pair <pair-ip:port> <code> [main-ip:port]}
                code=''${3:?}
                "$ADB" pair "$pairTarget" "$code" || exit 1
                if [ "''${4:-}" != "" ]; then
                  "$ADB" connect "''$4"
                fi
                exit 0
                ;;
              apply)
                ensure_device
                nextdns=$(nextdns_resolution)
                echo "== system settings"
                while IFS=$'\t' read -r key value; do
                  "$ADB" shell settings put global "$key" "$value"
                done < <(jq -r '.settings.global[] | @tsv' "$MANIFEST")
                while IFS=$'\t' read -r key value; do
                  # always_on_vpn_* rows: bench-verified on the first 10a run; a
                  # re-run converges if the keys differ.
                  "$ADB" shell settings put secure "$key" "$value" || true
                done < <(jq -r '.settings.secure[] | @tsv' "$MANIFEST")
                if [ -n "$nextdns" ]; then
                  "$ADB" shell settings put global private_dns_specifier "$nextdns"
                else
                  echo "no NextDNS hostname given - private DNS specifier untouched" >&2
                fi
                echo "== F-Droid lane"
                for id in $(lane lanes.fdroid); do
                  fdroidcl install "$id" || echo "FAILED: $id (fall back to the F-Droid app)" >&2
                done
                echo
                echo "== Obtainium lane (interactive)"
                echo "Bulk import link (imports all ids at once):"
                obtainium_bulk_link
                echo
                echo "== Aurora lane (install manually in an anonymous session)"
                lane lanes.aurora
                echo
                echo "== private lane (out-of-repo file merged at runtime)"
                private_lane
                echo
                echo "== manual checklist"
                jq -r '.lanes.manual[] | "- \(.)"' "$MANIFEST"
                echo
                echo "== dropped by decision (reference, do not install)"
                jq -r '.dropped[]' "$MANIFEST"
                echo
                echo "re-run 'pixel-provision check' after the manual lanes."
                exit 0
                ;;
              links)
                echo "Per-app (bulk below is authoritative for ids):"
                jq -r '.lanes.obtainium[] | "obtainium://add?url=\(.url)"' "$MANIFEST"
                echo
                echo "Bulk (one link, imports all with ids):"
                obtainium_bulk_link
                exit 0
                ;;
              widgets)
                # The termux widget lane: ~/.shortcuts scripts that ssh into m920q
                # for desktop-power. adb cannot write com.termux's app-private
                # home, so the bundle lands in Download and the printed finisher
                # does the privileged move inside Termux.
                ensure_device
                key=''${HOME}/.config/pixel-provision/phone-widget-key
                if [ ! -f "$key" ]; then
                  ssh-keygen -t ed25519 -N "" -C m920q-termux-widget -f "$key" >/dev/null
                  echo "generated $key - add its public half to lib/ssh-keys.nix" >&2
                fi
                stage=$(mktemp -d)
                mkdir "$stage/.ssh"
                cp "$key" "$stage/.ssh/phone-widget-key"
                cp ''${key}.pub "$stage/.ssh/phone-widget-key.pub"
                printf '%s\n' \
                  "Host m920q" \
                  "  HostName ${m920qAddress}" \
                  "  User schausberger" \
                  "  IdentityFile ~/.ssh/phone-widget-key" \
                  "  StrictHostKeyChecking accept-new" > "$stage/.ssh/config"
                for act in on off status; do
                  {
                    printf '#!/data/data/com.termux/files/usr/bin/sh\n'
                    printf 'exec ssh -F ~/.ssh/config m920q desktop-power %s\n' "$act"
                  } > "$stage/power-$act"
                  chmod +x "$stage/power-$act"
                done
                "$ADB" shell mkdir -p /sdcard/Download/termux-widget-lane
                "$ADB" push "$stage/.ssh/" /sdcard/Download/termux-widget-lane/.ssh >/dev/null
                "$ADB" push "$stage"/power-* /sdcard/Download/termux-widget-lane/ >/dev/null
                rm -rf "$stage"
                cat <<'FINISH'
    Finish inside the Termux app (NOT nix-on-droid):
      pkg install -y openssh
      mkdir -p ~/.shortcuts ~/.ssh
      mv /sdcard/Download/termux-widget-lane/.ssh/* ~/.ssh/
      mv /sdcard/Download/termux-widget-lane/power-* ~/.shortcuts/
      chmod 700 ~/.ssh && chmod 600 ~/.ssh/phone-widget-key
      chmod +x ~/.shortcuts/power-*
      ssh m920q desktop-power status
      rm -rf /sdcard/Download/termux-widget-lane
    Then long-press a home screen and add the Termux:Widget shortcuts widget.
    The key's public half is committed in lib/ssh-keys.nix; until that lands,
    ~/.ssh/authorized_keys on the target host is the interim path.
    FINISH
                exit 0
                ;;
              check)
                ensure_device
                f=$(mktemp)
                trap 'rm -f "$f"' EXIT
                "$ADB" shell pm list packages -3 | sed 's/^package://' > "$f"
                google=$(grep -c '^com\.google\.' "$f" || true)
                echo "com.google.* installed: $google (expect 0 on GrapheneOS)"
                grep '^com\.google\.' "$f" || true
                echo "-- fdroid lane coverage:"
                for id in $(lane lanes.fdroid); do
                  if grep -q "^$id$" "$f"; then
                    echo "ok   $id"
                  else
                    echo "MISS $id"
                  fi
                done
                exit 0
                ;;
              help|*)
                cat <<'USAGE'
        usage:
          pixel-provision pair <pair-ip:port> <code> [main-ip:port]
              pair wireless debugging (code from the pairing dialog) and
              connect the main port from the wireless debugging screen.
          pixel-provision apply    settings + fdroid lane + interactive checklists
          pixel-provision links    obtainium deep links (bulk + per app)
          pixel-provision check    Google-free and lane-coverage audit
          pixel-provision widgets  stage the termux power-widget bundle (key,
                                   ssh config, ~/.shortcuts scripts via Download)
        env: NEXTDNS=<hostname>, ADB=<path>
    USAGE
                exit 1
                ;;
            esac
  ''
