#!/usr/bin/env bash
# Validate the sops-stored user SSH key (private/id_ed25519).
#
# System sops-install-secrets plants this value over ~/.ssh/id_ed25519 on
# every host, so a value that does not parse takes down user sops-nix and
# ssh authentication fleet wide (a newline-stripped PEM shipped once
# already). The stored value must parse as an SSH private key and match
# the live public key, so a key rotation that skips the secret fails here.
#
# Exit codes:
#   0 - value parses and matches, or no decryption material available
#       (CI runners, fresh machines: the ENC-prefix hook still applies)
#   1 - live key unusable, stored value empty, unparseable, or mismatched
#
# Usage: tools/scripts/check-sops-user-key.sh [secrets-file]

set -euo pipefail
# ssh-keygen refuses key files that are group/world accessible, so every
# temp file this script creates must be owner-only from birth.
umask 077

secrets_file="${1:-secrets/secrets.yaml}"
pub_file="${HOME}/.ssh/id_ed25519.pub"
live_key="${HOME}/.ssh/id_ed25519"

if [[ -z "${SOPS_AGE_KEY:-}" && -z "${SOPS_AGE_KEY_CMD:-}" ]]; then
	if [[ ! -f "$live_key" ]]; then
		echo "skip: no live user key and no SOPS_AGE_KEY(_CMD); cannot decrypt"
		exit 0
	fi
	# Derive the decryptor from the live key so the check runs outside
	# direnv too (nix develop, just recipes); a live key that ssh-to-age
	# rejects is itself the failure mode this hook exists for.
	if ! command -v ssh-to-age >/dev/null 2>&1; then
		echo "ERROR: $live_key exists but ssh-to-age is not on PATH" >&2
		exit 1
	fi
	if ! age_key=$(ssh-to-age -private-key -i "$live_key" 2>/dev/null); then
		echo "ERROR: live key $live_key does not parse as an SSH private key" >&2
		exit 1
	fi
	export SOPS_AGE_KEY="$age_key"
fi

if ! command -v sops >/dev/null 2>&1; then
	echo "ERROR: decryption material is set but sops is not on PATH" >&2
	exit 1
fi

tmp_dir=$(mktemp -d)
value="$tmp_dir/key"
cleanup() {
	shred -u "$value" 2>/dev/null || rm -f "$value"
	rm -rf "$tmp_dir"
}
trap cleanup EXIT

if ! sops -d --extract '["private"]["id_ed25519"]' "$secrets_file" \
	>"$value" 2>"$tmp_dir/decrypt.err"; then
	echo "ERROR: cannot decrypt private/id_ed25519 from $secrets_file:" >&2
	cat "$tmp_dir/decrypt.err" >&2
	exit 1
fi

if [[ ! -s "$value" ]]; then
	echo "ERROR: private/id_ed25519 in $secrets_file is empty" >&2
	exit 1
fi

if ! ssh-keygen -y -f "$value" >"$tmp_dir/derived.pub" 2>"$tmp_dir/keygen.err"; then
	echo "ERROR: private/id_ed25519 in $secrets_file is not a parseable SSH private key" >&2
	cat "$tmp_dir/keygen.err" >&2
	echo "Fix: re-encrypt $live_key as private/id_ed25519 with sops" >&2
	exit 1
fi

if [[ -f "$pub_file" ]]; then
	stored=$(cut -d' ' -f1-2 "$tmp_dir/derived.pub")
	live=$(cut -d' ' -f1-2 "$pub_file")
	if [[ "$stored" != "$live" ]]; then
		echo "ERROR: private/id_ed25519 in $secrets_file does not match $pub_file" >&2
		echo "Fix: re-encrypt $live_key as private/id_ed25519 with sops" >&2
		exit 1
	fi
else
	echo "note: $pub_file not found; parse check only"
fi

echo "ok: private/id_ed25519 parses and matches $pub_file"
