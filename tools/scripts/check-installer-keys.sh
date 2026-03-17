#!/usr/bin/env bash
set -euo pipefail

key_file="hosts/installer/authorized_keys"

if [[ ! -f "$key_file" ]]; then
  # No keys provided; nothing to validate.
  exit 0
fi

# Ensure restrictive permissions (600 or 644 are acceptable from git)
# Note: Git only stores 644/755, so we accept both 600 and 644
perm=$(stat -c "%a" "$key_file")
if [[ "$perm" != "600" && "$perm" != "644" ]]; then
  echo "ERROR: $key_file must have permissions 600 or 644 (current: $perm)" >&2
  echo "Fix with: chmod 600 $key_file" >&2
  exit 1
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
