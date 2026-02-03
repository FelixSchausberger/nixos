#!/usr/bin/env bash
set -euo pipefail

key_file="hosts/installer/authorized_keys"

if [[ ! -f "$key_file" ]]; then
  # No keys provided; nothing to validate.
  exit 0
fi

# Ensure restrictive permissions
perm=$(stat -c "%a" "$key_file")
if [[ "$perm" != "600" ]]; then
  echo "⚠️  Fixing $key_file permissions: $perm → 600" >&2
  chmod 600 "$key_file"
fi

line_no=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_no=$((line_no + 1))
  # Skip blank lines or comments
  if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  if ! echo "$line" | ssh-keygen -lf /dev/stdin >/dev/null 2>&1; then
    echo "ERROR: Invalid SSH public key in $key_file at line $line_no" >&2
    exit 1
  fi
done <"$key_file"

exit 0
