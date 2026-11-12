# GrapheneOS provisioning for the Pixel 10a, built from lib/phone.nix. A
# desktop-side (m920q) helper: `pair` wires up wireless adb, `apply` pushes the
# manifest settings and the F-Droid lane for the owner, the private space or the
# Google user and prints the interactive-lane checklists, `links` renders the
# Obtainium bulk import, `check` audits the result against the manifest, and
# `widgets` stages the Termux desktop-power shortcuts. Android-side state
# (sign-ins, patcher runs) has no machine interface, so those steps print as a
# checklist instead of lying about being runnable.
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
}: let
  manifest = (import ../../lib/phone.nix) {};
  manifestJson = writeText "phone-manifest.json" (builtins.toJSON manifest);
  hostLib = import ../../lib/hosts.nix;
  m920qAddress = hostLib.m920q.tailnetIp;
in
  writeShellScriptBin "pixel-provision" ''
            PATH=${lib.makeBinPath [android-tools coreutils gnugrep gnused fdroidcl jq]}
            ADB=''${ADB:-${android-tools}/bin/adb}
            MANIFEST=${manifestJson}
            # The privacy lane lives outside the repository by design:
            # user-managed file, never committed; missing file is a no-op.
            # It targets the private space, the profile that hides its apps.
            PRIVATE=''${HOME}/.config/pixel-provision/private-apps.json
            PROFILE=owner

            set_profile() {
              PROFILE="''${1:-owner}"
              case "$PROFILE" in
                owner|private|google) ;;
                *) echo "unknown profile: $PROFILE (use owner, private or google)" >&2; exit 1 ;;
              esac
            }

            lanes_path() {
              case "$PROFILE" in
                owner) echo ".lanes" ;;
                private) echo ".privateSpace.lanes" ;;
                google) echo ".googleAccount.lanes" ;;
              esac
            }

            lane() {
              if [ "$1" = obtainium ]; then
                jq -r "$(lanes_path).obtainium[].id" "$MANIFEST"
              else
                jq -r "$(lanes_path).$1[]" "$MANIFEST"
              fi
            }
            private_lane() {
              if [ "$PROFILE" = private ] && [ -f "$PRIVATE" ]; then
                jq -r '.aurora[] // empty' "$PRIVATE"
              fi
            }

            ensure_device() {
              if state=$("$ADB" get-state 2>&1); then
                return 0
              fi
              case "$state" in
                *"more than one"*)
                  echo "multiple adb devices; export ANDROID_SERIAL=<serial> (see '$ADB devices')" >&2
                  exit 1
                  ;;
              esac
              echo "no adb device connected - run 'pixel-provision pair ...' first" >&2
              exit 1
            }

            target_user() {
              case "$PROFILE" in
                owner) echo 0 ;;
                private)
                  u=$("$ADB" shell cmd user list -v | sed -n 's/.*id=\([0-9]\+\).*type=profile\.PRIVATE.*parentId=0.*/\1/p' | head -n1)
                  if [ -z "$u" ]; then
                    echo "no private space under the main user" >&2
                    exit 1
                  fi
                  echo "$u"
                  ;;
                google)
                  # Full secondary user, not a profile: resolve it by type so a
                  # renumbered user id still works.
                  u=$("$ADB" shell cmd user list -v | sed -n 's/.*id=\([0-9]\+\).*type=full\.SECONDARY.*/\1/p' | head -n1)
                  if [ -z "$u" ]; then
                    echo "no secondary full user (Google user) on the device" >&2
                    exit 1
                  fi
                  echo "$u"
                  ;;
              esac
            }

            obtainium_bulk_link() {
              payload=$(jq -c "[$(lanes_path).obtainium[] | {id, url, author, name}]" "$MANIFEST")
              encoded=$(printf %s "$payload" | jq -sRr @uri)
              echo "obtainium://apps/$encoded"
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
                set_profile "''${2:-owner}"
                u=$(target_user)
                echo "== profile: $PROFILE (user $u)"
                echo "== system settings"
                while IFS=$'\t' read -r key value; do
                  "$ADB" shell settings --user "$u" put global "$key" "$value"
                done < <(jq -r '.settings.global[] | @tsv' "$MANIFEST")
                while IFS=$'\t' read -r key value; do
                  # always_on_vpn_* rows: the shared settings keep Tailscale
                  # always-on without lockdown for every profile.
                  "$ADB" shell settings --user "$u" put secure "$key" "$value" || true
                done < <(jq -r '.settings.secure[] | @tsv' "$MANIFEST")
                if [ "$PROFILE" != google ]; then
                  echo "== F-Droid lane"
                  for id in $(lane fdroid); do
                    fdroidcl install -user "$u" "$id" || echo "FAILED: $id (fall back to the F-Droid app)" >&2
                  done
                  echo
                  echo "== Obtainium lane (interactive)"
                  echo "Bulk import link (imports all ids at once):"
                  obtainium_bulk_link
                  echo
                fi
                echo "== Aurora lane (install manually in an anonymous session)"
                lane aurora
                if [ "$PROFILE" = private ]; then
                  echo
                  echo "== private lane (out-of-repo file merged at runtime)"
                  private_lane
                fi
                echo
                echo "== manual checklist"
                jq -r "$(lanes_path).manual[] | \"- \(.)\"" "$MANIFEST"
                if [ "$PROFILE" != google ]; then
                  echo
                  echo "== dropped by decision (reference, do not install)"
                  jq -r '.dropped[]' "$MANIFEST"
                fi
                echo
                echo "re-run 'pixel-provision check $PROFILE' after the manual lanes."
                exit 0
                ;;
              links)
                set_profile "''${2:-owner}"
                if [ "$PROFILE" = google ]; then
                  echo "no obtainium lane for the google profile" >&2
                  exit 1
                fi
                echo "Per-app (bulk below is authoritative for ids):"
                jq -r "$(lanes_path).obtainium[] | \"obtainium://add?url=\(.url)\"" "$MANIFEST"
                echo
                echo "Bulk (one link, imports all with ids):"
                obtainium_bulk_link
                exit 0
                ;;
              widgets)
                # The termux widget lane: ~/.shortcuts scripts that ssh into
                # m920q for desktop-power. adb cannot write com.termux's
                # app-private home, so the bundle lands in Download and the
                # printed finisher does the move inside Termux. Tailscale SSH
                # authenticates the phone by tailnet identity, so the scripts
                # carry no key material.
                ensure_device
                stage=$(mktemp -d)
                for act in on off; do
                  {
                    printf '#!/data/data/com.termux/files/usr/bin/sh\n'
                    printf 'exec ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=30 -o StrictHostKeyChecking=accept-new schausberger@%s desktop-power %s\n' "${m920qAddress}" "$act"
                  } > "$stage/power-$act"
                  chmod +x "$stage/power-$act"
                done
                "$ADB" shell mkdir -p /sdcard/Download/termux-widget-lane
                "$ADB" push "$stage"/power-* /sdcard/Download/termux-widget-lane/ >/dev/null
                rm -rf "$stage"
                cat <<FINISH
    Finish inside the Termux app (NOT nix-on-droid):
      pkg install -y openssh
      mkdir -p ~/.shortcuts
      mv /sdcard/Download/termux-widget-lane/power-* ~/.shortcuts/
      chmod +x ~/.shortcuts/power-*
      ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new schausberger@${m920qAddress} desktop-power status
      rm -rf /sdcard/Download/termux-widget-lane
    Then long-press a home screen and add the Termux:Widget shortcuts widget.
    No SSH key is involved: Tailscale SSH authenticates the phone by tailnet
    identity. An older bundle installed ~/.ssh/phone-widget-key and a Host
    m920q block; both can be deleted from Termux.
    FINISH
                exit 0
                ;;
              check)
                ensure_device
                set_profile "''${2:-owner}"
                u=$(target_user)
                f=$(mktemp)
                trap 'rm -f "$f"' EXIT
                "$ADB" shell pm list packages -3 --user "$u" | sed 's/^package://' > "$f"
                if [ "$PROFILE" = owner ]; then
                  google=$(grep -c '^com\.google\.' "$f" || true)
                  echo "com.google.* installed: $google (expect 0 on GrapheneOS)"
                  grep '^com\.google\.' "$f" || true
                  echo "-- fdroid lane coverage:"
                  ids=$(lane fdroid)
                elif [ "$PROFILE" = google ]; then
                  echo "-- aurora lane coverage:"
                  ids=$(lane aurora)
                else
                  echo "-- sandboxed Google Play:"
                  for id in com.google.android.gms com.android.vending com.google.android.projection.gearhead; do
                    if grep -q "^$id$" "$f"; then
                      echo "ok   $id"
                    else
                      echo "MISS $id"
                    fi
                  done
                  echo "-- private lane coverage:"
                  ids="$(lane fdroid) $(lane aurora) $(lane obtainium)"
                fi
                for id in $ids; do
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
          pixel-provision apply [owner|private|google]
              settings + lane + interactive checklists (default: owner)
          pixel-provision links [owner|private]
              obtainium deep links (bulk + per app, default: owner)
          pixel-provision check [owner|private|google]
              Google-free owner audit or per-profile lane coverage
          pixel-provision widgets  stage the termux power-on/power-off shortcuts
                                   via Download (Tailscale SSH, no key)
        env: ADB=<path>, ANDROID_SERIAL=<serial>
    USAGE
                exit 1
                ;;
            esac
  ''
