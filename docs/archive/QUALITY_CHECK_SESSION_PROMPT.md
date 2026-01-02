# Claude Code Session Prompt: Quality Assessment & Performance Measurement

## Context

A comprehensive quality monitoring system has been implemented for this NixOS configuration repository. This session will apply the quality measures to the codebase, establish baselines, and generate a complete quality report.

## Your Task

Apply all quality monitoring measures to the codebase and provide a comprehensive performance measurement and code coverage report.

## Prerequisites

The quality monitoring system has been fully implemented with:
- 6 analysis scripts in `tools/scripts/`
- Critical path coverage tests in `tests/coverage-critical-paths/`
- 9 quality metric commands in `justfile`
- Quality gates CI workflow
- GitHub Pages dashboard

**Verification**: See `docs/IMPLEMENTATION_VERIFICATION.md` for complete implementation details.

## Step-by-Step Instructions

### 1. Rebuild Development Shell

The dev shell needs to be rebuilt to include the quality analysis tools (bc, jq).

```bash
# Exit any existing dev shell
exit

# Enter fresh dev shell (will rebuild with new tools)
nix develop

# Verify tools are available
which bc jq nix-output-monitor nix-tree nix-du nixpkgs-hammering
```

**Expected**: All tools should be found in `/nix/store/...`

### 2. Run Individual Quality Checks

Execute each quality check separately to understand what they measure:

#### A. Detect Unused Modules

```bash
just check-unused
```

**What it does**: Analyzes import graph to find orphaned module files
**Expected output**: List of modules with ✅ Used or ❌ Unused
**Success criteria**: All modules should show ✅ Used (or identify legitimate unused modules)

#### B. Calculate Test Coverage

```bash
just coverage-report
just coverage
```

**What it does**:
- `coverage-report`: Generates detailed coverage report
- `coverage`: Calculates aggregate coverage percentage

**Expected output**:
- Coverage percentage for critical paths (boot, networking, users, security, systemd)
- Breakdown by hosts, modules, test suites
- JSON metrics in `.quality-metrics/`

**Success criteria**: Critical path coverage should be measurable (target: 100%)

#### C. Profile Evaluation Performance

```bash
just profile-eval
```

**What it does**: Measures how long it takes to evaluate the NixOS configuration
**Expected output**:
- Evaluation time in seconds
- NIX_SHOW_STATS output with detailed timing
- JSON metrics in `.quality-metrics/eval-time.json`

**Success criteria**: Evaluation time <10s (target)

#### D. Check Closure Sizes

```bash
just check-closures
```

**What it does**: Calculates system closure size for all hosts
**Expected output**:
- Closure size in MB for each host (desktop, portable, surface, hp-probook-vmware, hp-probook-wsl)
- Comparison to baseline (first run creates baseline)
- JSON metrics for each host

**Success criteria**:
- Desktop <3GB
- Other hosts <2.5GB

**Note**: First run will be slow as it builds configurations. Subsequent runs compare to baseline.

### 3. Run Comprehensive Quality Check

```bash
just quality-check
```

**What it does**: Runs all quality checks in sequence
**Includes**:
1. Detect unused modules
2. Calculate coverage
3. Generate quality dashboard

**Expected output**: Combined output from all checks + dashboard generated

### 4. Review Generated Dashboard

```bash
cat docs/QUALITY_DASHBOARD.md
```

**What it shows**:
- Overall health status (✅ PASS / ⚠️ NEEDS IMPROVEMENT)
- Test coverage metrics
- Code quality metrics (dead code, unused modules, linting)
- Performance metrics (evaluation time, closure sizes)
- Recommendations for improvement

### 5. Analyze Metrics Directory

```bash
ls -la .quality-metrics/
cat .quality-metrics/*.json | jq .
```

**What to look for**:
- `coverage.json` - Test coverage data
- `aggregate-coverage.json` - Combined coverage metrics
- `eval-time.json` - Evaluation performance
- `closure-*.json` - Closure sizes per host
- `*-baseline.txt` - Baseline values for comparison

### 6. Run Snapshot Tests

```bash
just test
```

**What it does**: Runs namaka snapshot tests including new critical path tests
**Expected**: All tests should pass, new critical path test should be included

### 7. Check for Dead Code

```bash
nix develop -c deadnix --fail .
```

**What it does**: Detects unused Nix variable bindings
**Expected**: Should either pass (0 unused) or list specific unused bindings to remove

### 8. Run Linting

```bash
nix develop -c statix check
```

**What it does**: Checks for Nix anti-patterns and issues
**Expected**: Should either pass or list issues to fix

## Deliverable: Comprehensive Quality Report

Generate a comprehensive report with the following sections:

### Section 1: Executive Summary

Provide a high-level summary:
- Overall quality status (PASS/FAIL)
- Number of quality issues found
- Key metrics snapshot (coverage %, eval time, closure sizes)
- Recommendation: Production-ready? Needs improvement?

### Section 2: Test Coverage Analysis

Report on:
- **Aggregate Coverage**: X%
- **Critical Path Coverage**: X% (target: 100%)
  - boot.* - covered? Y/N
  - networking.* - covered? Y/N
  - users.* - covered? Y/N
  - security.* - covered? Y/N
  - systemd.services.* - covered? Y/N
- **Host Coverage**: X/5 hosts tested
- **Module Coverage**: ~X% of modules tested
- **Test Suites**: X total suites
- **Snapshot Assertions**: X total assertions

**Analysis**: Are critical paths sufficiently covered? What's missing?

### Section 3: Code Quality Assessment

Report on:
- **Dead Code**: X unused bindings found
- **Unused Modules**: X orphaned modules found
- **Linting Issues**: X statix issues found
- **Format Issues**: X files need formatting

**List specific issues** found by:
- deadnix
- detect-unused-modules.sh
- statix

**Recommendations**: Which files need cleanup?

### Section 4: Performance Measurements

Report on:
- **Evaluation Time**: X.Xs (target: <10s)
  - Status: ✅ Within target / ❌ Exceeds target
  - Trend: Improving / Stable / Degrading (if baseline exists)

- **Closure Sizes** (for each host):
  - desktop: X.XGB / 3GB limit (X%)
  - portable: X.XGB / 2.5GB limit (X%)
  - surface: X.XGB / 2.5GB limit (X%)
  - hp-probook-vmware: X.XGB / 2GB limit (X%)
  - hp-probook-wsl: X.XGB / 2GB limit (X%)

**Analysis**: Which hosts are within limits? Which are bloated?

### Section 5: Quality Gate Status

For each gate, report PASS/FAIL:
- ✅/❌ **No Dead Code** - deadnix --fail
- ✅/❌ **No Unused Modules** - detect-unused-modules.sh
- ✅/❌ **Critical Path Coverage** ≥100%
- ✅/❌ **Evaluation Time** <10s
- ✅/❌ **Closure Size** within limits

**CI Prediction**: Would CI pass with current state?

### Section 6: Baselines Established

Document the baselines created:
- Coverage baseline: X%
- Evaluation time baseline: X.Xs
- Closure size baselines:
  - desktop: X.XGB
  - portable: X.XGB
  - surface: X.XGB
  - hp-probook-vmware: X.XGB
  - hp-probook-wsl: X.XGB

These will be used for regression detection in future commits.

### Section 7: Recommendations

Provide actionable recommendations:

**High Priority** (blocking quality gates):
- [ ] Fix dead code in X files
- [ ] Remove X unused modules
- [ ] Add tests for X uncovered critical paths
- [ ] Optimize evaluation (if >10s)
- [ ] Reduce closure size for X hosts (if exceeding limits)

**Medium Priority** (improves quality):
- [ ] Fix X statix linting issues
- [ ] Improve test coverage from X% to target (if not 100%)
- [ ] Add tests for X modules without coverage

**Low Priority** (optional improvements):
- [ ] Consider X nixpkgs-hammering suggestions
- [ ] Add tests for edge cases
- [ ] Document complex modules

### Section 8: Next Steps

Outline what should be done:

1. **Immediate** (required before merge):
   - Fix all failing quality gates
   - Establish all baselines (done in this session)

2. **Short-term** (within 1 week):
   - Enable GitHub Pages for live dashboard
   - (Optional) Set up dynamic badges

3. **Ongoing** (continuous):
   - Monitor quality metrics on each commit
   - Keep coverage at 100% for critical paths
   - Maintain evaluation time <10s

## Format for Report

Save the report as: `QUALITY_ASSESSMENT_REPORT_<DATE>.md`

Use this structure:
```markdown
# Quality Assessment Report
Date: YYYY-MM-DD
Generated by: Claude Code Quality Monitoring System

## Executive Summary
[As described above]

## Detailed Findings

### 1. Test Coverage Analysis
[Detailed coverage metrics]

### 2. Code Quality Assessment
[Specific issues found]

### 3. Performance Measurements
[Detailed performance data]

### 4. Quality Gate Status
[Gate by gate status]

### 5. Baselines Established
[Documented baselines]

### 6. Recommendations
[Prioritized action items]

### 7. Next Steps
[Timeline and actions]

## Appendix

### Metrics Files Generated
- Coverage: .quality-metrics/coverage.json
- Aggregate: .quality-metrics/aggregate-coverage.json
- Evaluation: .quality-metrics/eval-time.json
- Closures: .quality-metrics/closure-*.json

### Commands Run
[List of all commands executed]

### Raw Output
[Include key snippets if helpful]
```

## Important Notes

- **First run is slow**: Closure size checks require building configurations (can take 30-60 minutes)
- **Baselines are created automatically**: First run establishes baselines for future comparisons
- **CI won't run yet**: Quality gates CI workflow needs first commit to main branch
- **Be thorough**: This is the initial quality assessment that sets expectations

## Success Criteria

This session is successful when:
- [ ] All quality check commands run without errors
- [ ] Quality dashboard is generated
- [ ] Baselines are established
- [ ] Comprehensive report is created
- [ ] Clear recommendations are provided
- [ ] User understands current quality state

## Troubleshooting

If commands fail:

1. **bc command not found**: Dev shell didn't rebuild. Exit and re-enter: `exit`, then `nix develop`
2. **jq command not found**: Same as above
3. **namaka test fails**: Review test output, may indicate configuration issues
4. **Evaluation takes >10s**: This is a finding, not an error. Document in report.
5. **Closure size exceeds limit**: This is a finding, not an error. Document in report.

## Questions to Answer

Your report should answer:
1. What is the current test coverage percentage?
2. Are all critical paths (boot, networking, users, security, systemd) tested?
3. Is there any dead code or unused modules?
4. How long does configuration evaluation take?
5. What are the system closure sizes?
6. Would CI pass if these changes were committed?
7. What are the top 3 quality improvements needed?
8. Is this configuration production-ready?

## Final Output

Provide:
1. Comprehensive quality assessment report (markdown)
2. Summary of all metrics (concise table)
3. Clear pass/fail status for each quality gate
4. Prioritized list of issues to fix
5. Confirmation that baselines are established

This will give the user complete visibility into their configuration's quality and clear next steps for improvement.
