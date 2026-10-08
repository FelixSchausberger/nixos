#!/usr/bin/env bash
# Emit deploy-time closure metrics for the Prometheus node_exporter textfile
# collector after a system generation is activated.
#
# Runs from the comin post-deployment hook as root, which is what lets it write
# the textfile directory the node exporter reads (owned by node-exporter). The
# emitter never fails a deployment: a missing generation link, an unsizeable
# store path or an unwritable directory logs to the journal and exits 0.
#
# Series carry only a host label so the closure-size series stays continuous
# across deploys. The deployed revision is exposed once as
# nixos_deploy_info{host,rev} rather than as a label on every metric, which
# would create a new series per commit and break range queries.
#
# Env overrides (used by tests and the local remote):
#   COMIN_PROFILE          system profile path (default /nix/var/nix/profiles/system)
#   COMIN_HOSTNAME         host label (default /etc/hostname)
#   COMIN_GIT_SHA          revision label (default unknown)
#   NIX_DEPLOY_METRICS_DIR output directory (default /var/lib/node-exporter/textfile)
set -euo pipefail

profile="${COMIN_PROFILE:-/nix/var/nix/profiles/system}"
host="${COMIN_HOSTNAME:-$(cat /etc/hostname 2>/dev/null || echo unknown)}"
rev="${COMIN_GIT_SHA:-unknown}"
out_dir="${NIX_DEPLOY_METRICS_DIR:-/var/lib/node-exporter/textfile}"

note() { printf 'emit-deploy-metrics: %s\n' "$*" >&2; }

cleanup() {
	if [[ -n "${tmp:-}" ]]; then rm -rf "$tmp"; fi
	if [[ -n "${tmp_out:-}" ]]; then rm -f "$tmp_out"; fi
}
trap cleanup EXIT

# The profile link target is a relative "system-<N>-link"; its only digits are
# the generation number (the store path's version digits are not in this
# string), matching the parse in detect-downgrades.sh.
target="$(readlink "$profile" 2>/dev/null || true)"
if [[ -z "$target" ]]; then
	note "no system profile link at $profile; nothing to emit"
	exit 0
fi
gen="${target//[^0-9]/}"
if [[ -z "$gen" ]]; then
	note "cannot parse a generation number from '$target'"
	exit 0
fi

new="$(readlink -f "$profile" 2>/dev/null || true)"
if [[ -z "$new" ]]; then
	note "cannot resolve $profile"
	exit 0
fi

# `nix path-info -S` prints "<path>\t<closureSize>"; the last whitespace field
# is the byte count.
size_of() {
	local line
	line="$(nix path-info -S "$1" 2>/dev/null || true)"
	[[ -n "$line" ]] || return 0
	printf '%s' "${line##*[[:space:]]}"
}

cur_size="$(size_of "$new")"
if [[ -z "$cur_size" ]]; then
	note "nix path-info could not size $new"
	exit 0
fi

prev_link="$(dirname "$profile")/system-$((gen - 1))-link"
delta=""
added=""
removed=""
if [[ -e "$prev_link" ]]; then
	old="$(readlink -f "$prev_link" 2>/dev/null || true)"
	old_size="$(size_of "${old:-}")"
	if [[ -n "$old_size" ]]; then
		delta=$((cur_size - old_size))
	fi
	if [[ -n "$old" ]]; then
		tmp="$(mktemp -d)"
		nix path-info -r "$old" 2>/dev/null | sort >"$tmp/old" || true
		nix path-info -r "$new" 2>/dev/null | sort >"$tmp/new" || true
		added="$(comm -13 "$tmp/old" "$tmp/new" | wc -l)"
		added="${added//[!0-9]/}"
		removed="$(comm -23 "$tmp/old" "$tmp/new" | wc -l)"
		removed="${removed//[!0-9]/}"
	fi
fi

if ! tmp_out="$(mktemp "$out_dir/.nix_deploy.prom.XXXXXX" 2>/dev/null)"; then
	note "cannot create a temp file in $out_dir; skipping"
	exit 0
fi

{
	printf '# HELP nixos_deploy_info Deployed system revision and generation.\n'
	printf '# TYPE nixos_deploy_info gauge\n'
	printf 'nixos_deploy_info{host="%s",rev="%s"} 1\n' "$host" "$rev"
	printf '# HELP nixos_deploy_generation Current system generation number.\n'
	printf '# TYPE nixos_deploy_generation gauge\n'
	printf 'nixos_deploy_generation{host="%s"} %s\n' "$host" "$gen"
	printf '# HELP nixos_deploy_closure_size_bytes Closure size of the newly activated generation.\n'
	printf '# TYPE nixos_deploy_closure_size_bytes gauge\n'
	printf 'nixos_deploy_closure_size_bytes{host="%s"} %s\n' "$host" "$cur_size"
	printf '# HELP nixos_deploy_timestamp_seconds Unix time these deploy metrics were emitted.\n'
	printf '# TYPE nixos_deploy_timestamp_seconds gauge\n'
	printf 'nixos_deploy_timestamp_seconds{host="%s"} %s\n' "$host" "$(date +%s)"
	if [[ -n "$delta" ]]; then
		printf '# HELP nixos_deploy_closure_delta_bytes Closure-size change versus the previous generation; positive is growth.\n'
		printf '# TYPE nixos_deploy_closure_delta_bytes gauge\n'
		printf 'nixos_deploy_closure_delta_bytes{host="%s"} %s\n' "$host" "$delta"
	fi
	if [[ -n "$added" && -n "$removed" ]]; then
		printf '# HELP nixos_deploy_paths_added Store paths added versus the previous generation.\n'
		printf '# TYPE nixos_deploy_paths_added gauge\n'
		printf 'nixos_deploy_paths_added{host="%s"} %s\n' "$host" "$added"
		printf '# HELP nixos_deploy_paths_removed Store paths removed versus the previous generation.\n'
		printf '# TYPE nixos_deploy_paths_removed gauge\n'
		printf 'nixos_deploy_paths_removed{host="%s"} %s\n' "$host" "$removed"
	fi
} >"$tmp_out"

chmod 0644 "$tmp_out"
mv -f "$tmp_out" "$out_dir/nix_deploy.prom"
note "wrote $out_dir/nix_deploy.prom (generation $gen, closure ${cur_size}B)"
