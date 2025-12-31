# Quality Monitoring System Setup Guide

This guide walks you through enabling and using the comprehensive quality monitoring system for your NixOS configuration.

## Overview

The quality monitoring system provides:
- ✅ **Test Coverage Tracking** - Know exactly what's tested
- ✅ **Dead Code Detection** - Find unused modules and bindings
- ✅ **Performance Profiling** - Measure evaluation time and closure sizes
- ✅ **Quality Dashboard** - Single-page view of all metrics
- ✅ **Automated Quality Gates** - CI fails on quality regression
- ✅ **Trend Analysis** - Track quality improvements over time

## Prerequisites

- NixOS configuration repository with flakes enabled
- GitHub repository (for CI/CD integration)
- Development shell access (`nix develop`)

## Initial Setup

### 1. Verify Installation

All quality monitoring tools and scripts are already installed. Verify by running:

```bash
# Enter development shell
nix develop

# Verify tools are available
which nix-output-monitor
which nix-tree
which deadnix
ls tools/scripts/
```

You should see:
- `nix-output-monitor`, `nix-tree`, `nix-du`, `nixpkgs-hammering`
- Scripts in `tools/scripts/`: `detect-unused-modules.sh`, `namaka-coverage-report.sh`, etc.

### 2. Run Initial Quality Check

Generate your first quality metrics:

```bash
# Run all quality checks
nix develop -c just quality-check
```

This will:
- Detect unused modules
- Calculate test coverage
- Generate quality dashboard at `docs/QUALITY_DASHBOARD.md`

**What to expect**:
- First run will establish baselines in `.quality-metrics/`
- Some tests might fail initially - this is normal
- You'll get a report showing current state

### 3. Review Generated Dashboard

```bash
cat docs/QUALITY_DASHBOARD.md
```

This shows:
- Current test coverage percentage
- Dead code and unused modules count
- Performance metrics
- Specific areas needing improvement

### 4. Establish Baselines

After your first rebuild, create performance baselines:

```bash
# Run the critical paths test to generate snapshot
nix develop -c namaka check

# Establish evaluation performance baseline
nix develop -c just profile-eval

# Establish closure size baselines
nix develop -c just check-closures
```

Baselines are stored in `.quality-metrics/` and used to detect regressions.

## Daily Usage

### Running Quality Checks

**Before committing:**

```bash
# Format code and run all quality checks
just validate
```

This runs:
1. `just fmt` - Format all Nix files
2. `just check` - Run pre-commit hooks (includes unused module detection)
3. `just test` - Run snapshot tests

**Check specific metrics:**

```bash
just coverage           # Test coverage report
just check-unused       # Find unused modules
just profile-eval       # Evaluate performance
just check-closures     # Check system closure sizes
just dashboard          # Update quality dashboard
```

### Interpreting Results

**Coverage**:
- Target: 100% critical path coverage
- Critical paths: boot, networking, users, security, systemd services
- Green: All critical paths tested
- Red: Missing coverage for critical functionality

**Dead Code**:
- Target: 0 unused bindings, 0 unused modules
- Green: No dead code
- Red: Found unused code that should be removed

**Performance**:
- Target: Evaluation <10s
- Green: Fast iteration, good developer experience
- Red: Slow evaluation, impacts productivity

**Closure Size**:
- Target: Desktop <3GB, others <2.5GB
- Green: Lean system
- Red: Bloated, review dependencies

### Fixing Quality Issues

**Remove dead code:**

```bash
# Automatic fix
deadnix --edit .

# Remove unused modules manually after detection
just check-unused --verbose
# Then delete the reported files
```

**Improve coverage:**

```bash
# Add new test in tests/coverage/
# Or extend existing host tests in tests/hosts-*/expr.nix

# Verify improvement
just coverage
```

**Optimize performance:**

```bash
# Profile to find slow areas
just profile-eval

# Check for heavy imports
# Review module complexity
# Reduce evaluation depth

# Verify improvement
just profile-eval
```

**Reduce closure size:**

```bash
# Analyze dependencies
nix-tree  # Interactive exploration

# Check specific host
just check-closure desktop

# Identify largest packages
nix path-info -rsSh .#nixosConfigurations.desktop.config.system.build.toplevel | sort -k2 -h | tail -20
```

## CI/CD Integration

### Quality Gates Workflow

The `.github/workflows/quality-gates.yml` runs on every commit and PR.

**Gates enforced:**
1. ❌ Fail if dead code found
2. ❌ Fail if unused modules found
3. ❌ Fail if critical path coverage <100%
4. ❌ Fail if evaluation time >10s

**Viewing results:**
- GitHub Actions tab → Quality Gates workflow
- PR comments show detailed metrics
- Workflow summary shows pass/fail for each gate

### Local CI Testing

Test what CI will check:

```bash
# Run the same checks as CI
nix develop -c deadnix --fail .
nix develop -c ./tools/scripts/detect-unused-modules.sh
nix develop -c ./tools/scripts/calculate-coverage.sh
nix develop -c ./tools/scripts/profile-evaluation.sh
```

All should exit with code 0 (success) for CI to pass.

## GitHub Pages Dashboard

### Viewing the Dashboard

After setup, your quality dashboard is available at:
- `https://USERNAME.github.io/REPO/`

Shows live metrics updated on every commit to main.

### Enabling GitHub Pages

1. Go to repository Settings → Pages
2. Source: "GitHub Actions"
3. Save
4. Next push to main will deploy

The `.github/workflows/github-pages.yml` handles automatic deployment.

## Dynamic Badges (Optional)

Add auto-updating badges to your README showing current metrics.

**Complete setup guide**: See `docs/BADGES_SETUP.md`

**Quick preview:**

![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)
![Eval Time](https://img.shields.io/badge/eval%20time-4.2s-brightgreen)
![Quality Gates](https://img.shields.io/badge/quality%20gates-passing-brightgreen)

## Advanced Usage

### Profiling Builds

Use `nix-output-monitor` for detailed build timing:

```bash
# Profile full system build
just profile-build desktop

# Shows:
# - Which packages are building vs cached
# - Build time for each package
# - Total build time
# - Cache hit rate
```

### Dependency Analysis

Explore system dependencies interactively:

```bash
# Interactive dependency tree
nix-tree .#nixosConfigurations.desktop.config.system.build.toplevel

# Navigate with:
# - Enter: Expand/collapse
# - /: Search
# - q: Quit
```

### Historical Trend Analysis

Track quality over time using git-stored metrics:

```bash
# View historical metrics
ls .quality-metrics/

# Compare coverage over time
git log --all -p -- .quality-metrics/aggregate-coverage.json

# Plot trends (if you add graphing tool)
./tools/scripts/plot-trends.sh
```

### Custom Quality Metrics

Add your own metrics:

1. Create script in `tools/scripts/check-custom-metric.sh`
2. Output JSON to `.quality-metrics/custom.json`
3. Add to `just quality-check` recipe
4. Update dashboard generation to include it

## Troubleshooting

### "No baselines found"

**Cause**: First run, no baseline established yet
**Solution**: Run the check again - it will create baseline automatically

### "Coverage below threshold"

**Cause**: Missing tests for critical paths
**Solution**: Add tests in `tests/coverage/critical-paths.nix`

### "Evaluation time exceeds threshold"

**Cause**: Heavy imports or complex modules
**Solution**:
1. Run `just profile-eval` to identify slow areas
2. Review module complexity
3. Check for duplicate nixpkgs imports

### "Quality gates failing in CI but passing locally"

**Cause**: Different environments or cached results
**Solution**:
1. Clear local cache: `rm -rf .quality-metrics/`
2. Run fresh: `just quality-check`
3. Compare outputs

### "Dashboard not updating"

**Cause**: GitHub Pages not enabled or deployment failing
**Solution**:
1. Check Settings → Pages is enabled
2. Check GitHub Actions for workflow errors
3. Ensure `.github/workflows/github-pages.yml` exists

## Best Practices

1. **Run quality checks before every commit**
   ```bash
   just validate
   ```

2. **Review dashboard after changes**
   ```bash
   just dashboard && cat docs/QUALITY_DASHBOARD.md
   ```

3. **Monitor trends weekly**
   - Check `.quality-metrics/` for regressions
   - Review GitHub Pages dashboard

4. **Fix issues immediately**
   - Don't let technical debt accumulate
   - Quality gates prevent merging broken code

5. **Add tests for new features**
   - Every new module should have a test
   - Critical functionality requires 100% coverage

## Maintenance

### Updating Thresholds

Edit `tools/scripts/*.sh` to adjust:
- Coverage thresholds (default: 100% critical paths)
- Performance limits (default: 10s evaluation)
- Closure size limits (default: 3GB desktop)

### Disabling Specific Gates

To make a gate advisory instead of blocking:

1. Edit `.github/workflows/quality-gates.yml`
2. Add `continue-on-error: true` to the step
3. Gate will report but not fail CI

### Baseline Reset

To reset baselines (after major refactoring):

```bash
rm .quality-metrics/*-baseline.txt
just quality-check  # Establishes new baselines
```

## Resources

- **Main Documentation**: `CLAUDE.md`
- **Dashboard Setup**: `docs/BADGES_SETUP.md`
- **Quality Dashboard**: `docs/QUALITY_DASHBOARD.md` (auto-generated)
- **Test Directory**: `tests/`
- **Scripts Directory**: `tools/scripts/`

## Support

Quality monitoring issues? Check:
1. This guide's Troubleshooting section
2. CI workflow logs in GitHub Actions
3. Local script output: `just quality-check 2>&1 | less`

## Next Steps

After setup:

1. ✅ Run `just quality-check` - Establish baselines
2. ✅ Fix any failing gates
3. ✅ Enable GitHub Pages for live dashboard
4. ✅ (Optional) Set up dynamic badges
5. ✅ Add quality checks to your workflow
6. ✅ Monitor trends and maintain high quality

**Your configuration is now production-ready with comprehensive quality monitoring!** 🎉
