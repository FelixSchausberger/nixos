{
  pkgs,
  hosts,
}: let
  hostListSpace = builtins.concatStringsSep ", " hosts;
in {
  type = "app";
  program = "${pkgs.writeShellApplication {
    name = "new-host-keys";
    # yq-go (mikefarah) preserves comments when rewriting .sops.yaml; the
    # plain `yq` package is the jq wrapper and drops them.
    runtimeInputs = with pkgs; [
      bitwarden-cli
      coreutils
      gnugrep
      gnused
      openssh
      sops
      ssh-to-age
      yq-go
    ];
    # SC2029 (info) fires on the deliberate client-side expansions inside the
    # SSH command strings.
    checkPhase = ''
      runHook preCheck
      "${pkgs.shellcheck}/bin/shellcheck" -S warning "$target"
      runHook postCheck
    '';
    text = ''
      if [[ $# -lt 2 ]]; then
          echo "Usage: nix run .#new-host-keys generate HOSTNAME" >&2
          echo "       nix run .#new-host-keys backup HOSTNAME [user@]TARGET_IP" >&2
          echo "" >&2
          echo "generate  Keygen a host key, register the sops recipient in" >&2
          echo "          .sops.yaml, rekey secrets.yaml, and store the private" >&2
          echo "          key as Bitwarden vault item 'host/<name>'." >&2
          echo "backup    Fetch the live host key over SSH from an installed" >&2
          echo "          host, then the same registration and vault storage." >&2
          echo "" >&2
          echo "Available hosts: ${hostListSpace}" >&2
          exit 1
      fi

      MODE="$1"
      HOSTNAME="$2"
      TARGET_HOST="''${3:-}"

      case "$MODE" in
          generate | backup) ;;
          *)
              echo "Error: unknown mode '$MODE' (expected: generate, backup)" >&2
              exit 1
              ;;
      esac

      # Literal membership check (no case-pattern expansion of user input)
      all_hosts=(${builtins.concatStringsSep " " hosts})
      host_ok=""
      for h in "''${all_hosts[@]}"; do
          if [[ "$h" == "$HOSTNAME" ]]; then
              host_ok=1
          fi
      done
      if [[ -z "$host_ok" ]]; then
          echo "Error: unknown host '$HOSTNAME'" >&2
          echo "Valid options: ${hostListSpace}" >&2
          exit 1
      fi

      if [[ ! -f ~/.ssh/id_ed25519 ]]; then
          echo "Error: SSH key not found at ~/.ssh/id_ed25519 (needed to rekey)" >&2
          exit 1
      fi

      if bw status | grep -q unauthenticated; then
          echo "Error: Bitwarden CLI is not logged in." >&2
          echo "Run once: nix shell nixpkgs#bitwarden-cli -c bw login" >&2
          exit 1
      fi

      WORKDIR=$(mktemp -d)
      cleanup() {
          local f
          # Shred instead of rm: the rm shim buries files in the rip
          # graveyard, which must never hold key material.
          for f in "$WORKDIR/key" "$WORKDIR/key.pub" "$WORKDIR/item.json"; do
              if [[ -f "$f" ]]; then
                  shred -u "$f"
              fi
          done
          rmdir "$WORKDIR"
      }
      trap cleanup EXIT

      BW_SESSION=""
      unlock_vault() {
          if ! BW_SESSION=$(bw unlock --raw) || [[ -z "$BW_SESSION" ]]; then
              echo "Error: Bitwarden vault unlock failed." >&2
              echo "Run once: nix shell nixpkgs#bitwarden-cli -c bw login" >&2
              exit 1
          fi
      }

      # $1 item name, $2 private key, $3 public key, $4 fingerprint
      store_item() {
          ITEM="$1" PRIV="$2" PUB="$3" FP="$4" yq -o=json -n \
              '{type: "sshkey", name: strenv(ITEM), privateKey: strenv(PRIV), publicKey: strenv(PUB), fingerprint: strenv(FP)}' \
              > "$WORKDIR/item.json"
          if ! bw create item --session "$BW_SESSION" --file "$WORKDIR/item.json" > /dev/null; then
              echo "Error: failed to store 'host/$HOSTNAME' in the Bitwarden vault." >&2
              echo "The repository was not modified; fix vault access and rerun." >&2
              exit 1
          fi
          echo "Vault item 'host/$HOSTNAME' stored."
      }

      # Append the age recipient to .sops.yaml if either list lacks it. The
      # keys entry gets the derivation comment that the anchor style of the
      # hand-written entries carries.
      # $1 age recipient, $2 host label
      register_recipient() {
          if ! grep -q "^  - $1" .sops.yaml; then
              RECIP="$1" yq -i '.keys += [strenv(RECIP)]' .sops.yaml
              sed -i "s|^  - $1\$|  - $1 # ssh-to-age -i /per/etc/ssh/ssh_host_ed25519_key.pub (host-$2)|" .sops.yaml
              echo "Recipient for $2 added to .sops.yaml keys."
          fi
          if ! grep -q "^          - $1" .sops.yaml; then
              RECIP="$1" yq -i '.creation_rules[0].key_groups[0].age += [strenv(RECIP)]' .sops.yaml
              echo "Recipient for $2 added to the creation rule."
          fi
      }

      rekey() {
          echo "Re-encrypting secrets/secrets.yaml for all recipients..."
          SOPS_AGE_KEY=$(ssh-to-age -private-key -i ~/.ssh/id_ed25519) sops updatekeys --yes secrets/secrets.yaml
      }

      # An existing vault item is authoritative: its key must be the one in
      # .sops.yaml, or a rerun would mix two generations of host keys.
      # $1 item JSON, $2 live recipient ("" when no live key is at hand)
      reconcile_existing_item() {
          local item_pub item_recip
          if ! item_pub=$(printf '%s' "$1" | yq -r '.sshKey.publicKey // .publicKey // ""') || [[ -z "$item_pub" || "$item_pub" == "null" ]]; then
              echo "Error: cannot read a public key from vault item 'host/$HOSTNAME'." >&2
              echo "Delete the stale item and rerun." >&2
              exit 1
          fi
          if ! item_recip=$(printf '%s\n' "$item_pub" | ssh-to-age); then
              echo "Error: vault item public key is not a valid SSH key." >&2
              exit 1
          fi
          if [[ -n "$2" && "$item_recip" != "$2" ]]; then
              echo "Error: vault item 'host/$HOSTNAME' holds a different key than the" >&2
              echo "live host (rotation in progress?). Re-back up the host or delete" >&2
              echo "the stale vault item, then rerun." >&2
              exit 1
          fi
          if grep -q "^  - $item_recip" .sops.yaml && grep -q "^          - $item_recip" .sops.yaml; then
              echo "host/$HOSTNAME is already stored and registered; nothing to do."
              exit 0
          fi
          echo "Error: vault item 'host/$HOSTNAME' exists but its key is not the" >&2
          echo "registered .sops.yaml recipient. Delete the stale vault item and" >&2
          echo "rerun so a single key generation ends up in both places." >&2
          exit 1
      }

      case "$MODE" in
      generate)
          unlock_vault
          # bw's exit code on a missing item is unreliable, so a result only
          # counts when it is an actual JSON object.
          if existing=$(bw get item --session "$BW_SESSION" "host/$HOSTNAME" 2> /dev/null) && [[ "$existing" == \{* ]]; then
              reconcile_existing_item "$existing" ""
          fi

          ssh-keygen -t ed25519 -N "" -C "host-$HOSTNAME" -f "$WORKDIR/key"
          PUB=$(< "$WORKDIR/key.pub")
          PRIV=$(< "$WORKDIR/key")
          RECIP=$(printf '%s\n' "$PUB" | ssh-to-age)
          read -r _bits FINGERPRINT _ <<< "$(ssh-keygen -lf "$WORKDIR/key.pub")"

          store_item "host/$HOSTNAME" "$PRIV" "$PUB" "$FINGERPRINT"
          register_recipient "$RECIP" "$HOSTNAME"
          rekey
          ;;
      backup)
          if [[ -z "$TARGET_HOST" ]]; then
              echo "Error: backup mode needs [user@]TARGET_IP as third argument" >&2
              exit 1
          fi
          if [[ "$TARGET_HOST" != *@* ]]; then
              TARGET_HOST="schausberger@$TARGET_HOST"
          fi

          if ! keydata=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$TARGET_HOST" "sudo -n cat /per/etc/ssh/ssh_host_ed25519_key.pub; echo __SPLIT__; sudo -n cat /per/etc/ssh/ssh_host_ed25519_key"); then
              echo "Error: could not read the host key from $TARGET_HOST" >&2
              exit 1
          fi
          HOST_PUB=''${keydata%%__SPLIT__*}
          HOST_PRIV=''${keydata#*__SPLIT__}
          if [[ "$HOST_PUB" != ssh-ed25519* || "$HOST_PRIV" != *"PRIVATE KEY"* ]]; then
              echo "Error: incomplete host key material read from $TARGET_HOST" >&2
              exit 1
          fi

          printf '%s\n' "$HOST_PRIV" > "$WORKDIR/key"
          chmod 600 "$WORKDIR/key"
          if ! derived=$(ssh-keygen -y -f "$WORKDIR/key" 2> /dev/null); then
              echo "Error: host private key from $TARGET_HOST does not parse" >&2
              exit 1
          fi
          read -r pub_alg pub_body _ <<< "$HOST_PUB"
          read -r der_alg der_body _ <<< "$derived"
          if [[ "$pub_alg $pub_body" != "$der_alg $der_body" ]]; then
              echo "Error: public and private host keys on $TARGET_HOST do not match" >&2
              exit 1
          fi
          RECIP=$(printf '%s\n' "$HOST_PUB" | ssh-to-age)
          read -r _bits FINGERPRINT _ <<< "$(ssh-keygen -lf <(printf '%s\n' "$HOST_PUB"))"

          unlock_vault
          if existing=$(bw get item --session "$BW_SESSION" "host/$HOSTNAME" 2> /dev/null) && [[ "$existing" == \{* ]]; then
              reconcile_existing_item "$existing" "$RECIP"
              echo "Vault item already matches the live host key."
          else
              store_item "host/$HOSTNAME" "$HOST_PRIV" "$HOST_PUB" "$FINGERPRINT"
          fi
          register_recipient "$RECIP" "$HOSTNAME"
          rekey
          ;;
      esac

      echo ""
      echo "host/$HOSTNAME is registered:"
      echo "  .sops.yaml   recipient added"
      echo "  secrets.yaml rekeyed to all recipients"
      echo "  Bitwarden    item 'host/$HOSTNAME' holds the private key"
      echo "Commit both files and merge to main before installing."
    '';
    meta.description = "Register a host's sops recipient and store its key in Bitwarden";
  }}/bin/new-host-keys";
}
