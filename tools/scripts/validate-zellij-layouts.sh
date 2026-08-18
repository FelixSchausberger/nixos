#!/usr/bin/env bash
set -euo pipefail

# Validate that every zellij layout KDL defined in Nix parses correctly.
# `zellij setup --check` only validates config.kdl, so broken layouts would
# otherwise ship silently and produce sessions with no panes.

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

eval_layout() {
	local layout="$1"
	nix eval --raw \
		'.#nixosConfigurations.m920q.config.home-manager.users.schausberger.programs.zellij.layouts.'"$layout"'' 2>/dev/null
}

for layout in default rust; do
	if ! eval_layout "$layout" | nix shell nixpkgs#kdlfmt -c kdlfmt format - >/dev/null 2>&1; then
		echo "ERROR: zellij layout '$layout' failed KDL parse validation" >&2
		exit 1
	fi
done

echo "zellij layouts parse correctly"
