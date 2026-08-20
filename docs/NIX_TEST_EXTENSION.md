# NixOS Configuration Testing — State of the Art & Future Directions

Research findings on NixOS configuration testing, evaluator internals, and
feasibility of a coverage tool.

## The Problem

Traditional code coverage (lcov, JaCoCo) instruments the runtime to track
which lines executed. Nix's "runtime" is the evaluator — a C++ program that
processes lazy attribute sets. The NixOS module system sits on top as library
functions (`evalModules`, `mkOption`, `mkIf`), not as a distinct runtime with
hooks. There is no standard tool that answers: "which NixOS options were
exercised by this test?"

## What Exists Today

### namaka (nix-community)

Snapshot testing for Nix. Tests produce an attribute set, namaka compares it to
a committed snapshot. Pass/fail only — no coverage tracking, no "which options
were read" instrumentation.

This repo uses namaka via `flake-parts/dev.nix`:

```nix
checks = inputs.namaka.lib.load {
  src = ../tests;
  inputs = { namaka = inputs.namaka.lib; flake = self; };
};
```

### nix-unit (nix-community)

Unit test runner for Nix expressions. Has a `lib.Coverage.addCoverage`
helper, but it is **not code coverage**. It generates meta-tests that assert
"a test exists for each public attribute name" — presence checking, not
execution tracing.

```nix
addCoverage public tests
```

Internally produces tests like: `tests ? attrName == true`. No evaluator
instrumentation, no JSON coverage output, no option-access logging.

### prek hooks (this repo)

Static analysis: deadnix, statix, alejandra, shellcheck, actionlint. These
catch code quality issues but provide zero runtime insight into which options
or code paths are exercised.

### VM tests (this repo, tests-vm/)

Runtime integration tests using `pkgs.testers.runNixOSTest`. Real system
behavior — service startup, HTTP routing, mode switching. High precision but
expensive and limited to 5 tests currently.

### Nix evaluator built-in profiling

- `--eval-profiler flamegraph`: stack-sampling profiler, produces files for
  flamegraph.pl. Shows where evaluation time is spent, not which options
  were accessed.
- `NIX_SHOW_STATS=1`: aggregate counters (nrLookups, nrFunctionCalls,
  nrThunks). No per-attribute breakdown.
- `NIX_COUNT_CALLS=1`: enables internal `attrSelects` map that counts
  attribute selections per source position. Data exists internally but is
  **not exported** — no CLI flag dumps it.

## The Nix Evaluator — What's Already There

The C++ evaluator (src/expr/eval.cc) already holds the essential runtime
information for coverage tracking:

### Attribute selection tracking

`ExprSelect::eval` increments `state.nrLookups++` on every attribute
selection. When `NIX_COUNT_CALLS=1`, it also populates `attrSelects` — a map
keyed by the attribute-definition source position (`j->pos`).

### Resolved path resolution

`showAttrSelectionPath` can produce the full resolved attribute path string
(e.g., `services.nginx.enable`) from the evaluator's symbol table
(`state.symbols`) and position metadata (`state.positions`).

### Profiler hooks

The evaluator calls `profiler.preFunctionCallHook()` and
`profiler.postFunctionCallHook()` in the function-call path. A custom
profiler could record selection events.

### Summary

The evaluator already tracks "which attribute definitions were selected how
many times." It just doesn't export this data in a usable format. A small
change would expose it.

## What a Coverage Tool Would Require

### Approach A: Patched Evaluator (recommended)

Small C++ change to export `attrSelects` as JSONL:

1. Add a flag (e.g., `--dump-attr-selections=trace.jsonl`) or environment
   variable
2. At evaluation end (same place as `NIX_SHOW_STATS` dump), iterate
   `attrSelects` and write each entry as JSON:

   ```json
   {
     "path": "services.nginx.enable",
     "file": "modules/services/nginx.nix",
     "line": 42,
     "count": 3
   }
   ```

3. Filter to `config.*` paths for NixOS option coverage
4. Run each test under patched evaluator, aggregate traces
5. Diff against declared options (from `lib.optionAttrSetToDocList`) for
   coverage map

Estimated effort: 50-100 lines of C++ in `src/expr/eval.cc`.

### Approach B: Rust Wrapper (no Nix patching)

1. Use `nix-eval-jobs` for per-attribute evaluation output (already emits
   per-attribute JSON)
2. Evaluate full option tree via `nix eval .#nixosConfigurations.*.config`
3. Correlate: which declared options appear in test evaluation outputs
4. Produce coverage report

Limitation: "evaluated" is not the same as "read by test code." Module merge
evaluates all options; you'd need to force the full config to get a complete
picture.

### Approach C: Module-Level Instrumentation

Wrap `mkOption`/`defineOptions` to log accesses when values are forced.
Fragile, intrusive, requires modifying the module system or injecting
wrapper modules at every evaluation root.

## Challenges

### Laziness

Nix is lazy. If a test doesn't force `config.services.nginx.enable`, that
option won't appear in the trace. This is correct for dynamic coverage (the
test doesn't exercise that option) but means you can't distinguish "dead
code" from "tested elsewhere."

### Noise

Every attribute selection is tracked — including internal `lib.*` calls,
arbitrary attrset lookups, and `with` scope resolution. Filtering to
`config.*` paths is necessary and doable but adds complexity.

### Evaluation vs Building

Knowing every option was *evaluated* doesn't verify the resulting system
*works*. Coverage of option reads != coverage of system behavior. VM tests
fill this gap.

### Determinism

Pure evaluator runs are deterministic given identical flags, pinned inputs,
and store state. Parallel evaluation (`nix-eval-jobs`) may evaluate in
different worker processes — traces must be aggregated across workers.

### Overhead

Emitting per-selection events adds runtime overhead. The existing
`NIX_COUNT_CALLS` infrastructure is lighter (aggregate counts per position)
but less precise (no resolved path strings).

## Why This Tool Doesn't Exist

1. **Niche audience.** NixOS configuration repos are a small community. The
   people who would build this (C++ evaluator hackers) are upstream Nix
   contributors focused on the language, not config testing patterns.

2. **namaka snapshots are "good enough."** For most config repos, asserting
   specific option values in snapshots catches regressions. Full coverage
   tracking is a nice-to-have, not a necessity.

3. **The pieces aren't connected.** The evaluator has the internal
   infrastructure (attrSelects, profiler hooks, symbol table). Nobody has
   added the 50-100 lines to export it as a usable format.

4. **Evaluation != behavior.** Even with option coverage, you still need VM
   tests for runtime correctness. The gap between "options read" and
   "system works" limits the value proposition.

## Feasibility Assessment

| Approach                  | Feasibility | Precision | Effort       |
| ------------------------- | ----------- | --------- | ------------ |
| Patch Nix to export attrs | High        | High      | Low-medium   |
| Rust wrapper via eval-jobs| Medium      | Medium    | Medium       |
| Static grep (current)     | Done        | Low       | Done         |
| VM tests (current)        | Done        | High      | Per-test     |

### What's missing for this to happen

- Someone to propose a `--dump-attr-selections` flag upstream to NixOS/nix
- A small Rust or C++ tool that aggregates traces and produces coverage
  reports
- Integration with namaka or a similar test runner

### Potential upstream contribution

The cleanest path is proposing an upstream feature to Nix: a flag like
`--eval-trace` or `--dump-selection-stats` that dumps per-attribute selection
events. This would benefit the entire Nix ecosystem, not just NixOS config
testing.

## References

- Nix evaluator source: `src/expr/eval.cc` (EvalState, ExprSelect, attrSelects)
- namaka: <https://github.com/nix-community/namaka>
- nix-unit: <https://github.com/nix-community/nix-unit>
- nix-eval-jobs: <https://github.com/nix-community/nix-eval-jobs>
- Nix eval profiler docs: <https://nix.dev/manual/nix/2.24/development/testing>
- NIX_COUNT_CALLS: set in EvalState constructor, gates attrSelects population
- showAttrSelectionPath: resolves full attribute path from symbol table
