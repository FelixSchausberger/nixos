#!/usr/bin/env bash
# Print the one-line verdict for a failed daily-update run.
#
# The workflow opens the tracking issue and update-system.sh prints the local
# hint, so both callers share this implementation instead of keeping mirror
# regexes that drift.
#
# Inputs:
#   DECISION        update-flake's decision output; eval-failed is a verdict
#   CANCELLED_JOBS  newline-separated names of cancelled jobs
#   stdin           full failed-job log plus check-run annotations
set -euo pipefail

decision="${DECISION:-}"
cancelled_jobs="${CANCELLED_JOBS:-}"
log_full="$(cat)"

# `printf | grep -q` returns 141 under pipefail when grep exits before printf
# finishes; process substitution leaves only grep's status.
log_matches() {
	grep -Eq "$1" < <(printf '%s\n' "$log_full")
}
log_matches_i() {
	grep -Eqi "$1" < <(printf '%s\n' "$log_full")
}

# The update job's own decision is the most precise classifier: eval-failed
# is emitted only for configuration problems, and the per-host assert details
# land in the run's eval-errors artifact and step summary rather than the job
# log.
if [ "$decision" = "eval-failed" ]; then
	verdict="config change needed (eval-failed): the eval-errors artifact and step summary on the run page name the failing option"
elif [ -n "$cancelled_jobs" ]; then
	cancelled_list="$(printf '%s\n' "$cancelled_jobs" | paste -sd ', ' -)"
	verdict="cancelled: $cancelled_list stopped without a failure; GitHub reports a job timeout as cancelled (desktop cap 330 min). The run did not finish its cache warm-up."
elif log_matches_i "hosted runner lost communication|runner lost communication|runner has received a shutdown signal"; then
	verdict="runner lost: the hosted runner stopped communicating and left no job log; re-run the failed jobs (not a build defect)"
elif log_matches "no longer has any effect|can no longer be used since it's been removed|Failed assertions"; then
	offending="$(printf '%s\n' "$log_full" |
		grep -m1 -oE "option definition '[^']+' in '[^']+'" |
		sed -E "s#/nix/store/[a-z0-9]{32}-source##" || true)"
	verdict="config change needed ($offending - removed-option assert or failed module assertion)"
# The disk pattern names the executed error only: the nix-setup step's script
# echo contains the literal `disk budget insufficient: ${avail}G free`, so
# the bare token reads a passing disk check as a full disk in every log.
elif log_matches "(::error::|##\[error\])disk budget insufficient: [0-9]+G free|No space left on device"; then
	verdict="disk full (ENOSPC): the closure build overflowed the runner disk - instantiation, not the cache push, fills the store, so a warm cache shortens builds but not the footprint; the free-disk step's df line names the volume class (72 GB vs 145 GB runners)"
# narinfo is deliberately not a cache-gap token: the build-host action prints
# narinfo-cache-*-ttl lines in successful steps of a failed job's log, which
# would misreport a real build failure as a cache gap.
elif log_matches_i "hash mismatch|missing from cache"; then
	verdict="cache gap: closures absent from all substituters (CI warms felixschausberger.cachix.org before the lock PR merge)"
# Both the old (`builder for ... failed`) and the new (`Cannot build` /
# `Reason: builder failed with exit code`) nix error wording mean an uncached
# dependency failed to compile.
elif log_matches "builder for .* failed|error: build of|Cannot build|Reason: builder failed"; then
	verdict="dependency build failure"
else
	verdict="unclassified - read the log tail"
fi

printf '%s\n' "$verdict"
