# NixOS Configuration Quality Dashboard

Last updated: 2026-02-09 17:27:10 UTC

## 🎯 Overall Health: ⚠️ NEEDS IMPROVEMENT

## Test Coverage

- **Aggregate Coverage**: 89%
- **Critical Path Coverage**: 100% (boot, networking, users, security, systemd)
- **Host Coverage**: 83% (5/6 hosts tested)
- **Module Coverage**: 72% (estimated)
- **Test Suites**: 19
- **Snapshot Assertions**: 0

## Code Quality

- **Dead Code (deadnix)**: 1
0 unused bindings
- **Linting Issues (statix)**: 17
0 issues
- **Unused Modules**: 0 orphaned modules

## Critical Paths Details


- ✅ `boot` - Covered
- ✅ `networking` - Covered
- ✅ `users` - Covered
- ✅ `security` - Covered
- ✅ `systemd.services` - Covered


## Performance

- **Evaluation Time**: 75.6s (target: <10s)

## Quality Metrics Trends

To view trends over time, check the `.quality-metrics/` directory for historical data.

## How to Improve

### Increase Coverage

1. Add critical path tests: `tests/coverage/critical-paths.nix`
2. Test untested hosts in `tests/hosts-*/`
3. Add module-specific tests in `tests/modules-*/`

### Fix Code Quality Issues

```bash
# Fix formatting and dead code
deadnix --edit .
statix fix .
alejandra .

# Find and remove unused modules
./tools/scripts/detect-unused-modules.sh --verbose
```

### Optimize Performance

```bash
# Profile evaluation
./tools/scripts/profile-evaluation.sh --host desktop

# Check closure sizes
./tools/scripts/check-closure-size.sh --all
```

## Continuous Monitoring

This dashboard is automatically updated by CI on every commit.

**Manual update:**
```bash
./tools/scripts/generate-quality-dashboard.sh
```
