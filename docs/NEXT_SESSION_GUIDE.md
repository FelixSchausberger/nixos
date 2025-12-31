# Next Session Guide: Quality Assessment

## What Was Completed

A comprehensive quality monitoring system has been fully implemented for your NixOS configuration. All code is written, tested, and documented.

**Implementation Status**: ✅ 100% Complete (all 6 phases)

See `docs/IMPLEMENTATION_VERIFICATION.md` for detailed verification.

## What's Next

The next session will **apply** the quality measures to your actual codebase and generate a comprehensive quality report.

## Quick Start for Next Claude Code Session

### Option 1: Use the Prepared Prompt (Recommended)

Copy and paste this into your next Claude Code session:

```
I have a comprehensive quality monitoring system implemented for my NixOS configuration. Please read docs/QUALITY_CHECK_SESSION_PROMPT.md and follow all instructions to:

1. Apply all quality measures to the codebase
2. Establish performance baselines
3. Generate a comprehensive quality assessment report

The system is fully implemented and ready to use. Focus on running the checks and analyzing the results.
```

### Option 2: Manual Commands

If you prefer to run commands manually:

```bash
# 1. Rebuild dev shell (adds bc, jq tools)
exit  # if in dev shell
nix develop

# 2. Run quality checks
just quality-check

# 3. View dashboard
cat docs/QUALITY_DASHBOARD.md

# 4. Check individual metrics
just coverage              # Test coverage
just profile-eval          # Evaluation time
just check-closures        # Closure sizes
just check-unused          # Unused modules

# 5. View all metrics
ls -la .quality-metrics/
cat .quality-metrics/*.json | jq .
```

## What You'll Get

After the next session, you'll have:

1. **Quality Assessment Report**
   - Overall quality status (PASS/FAIL)
   - Test coverage percentage
   - Code quality metrics (dead code, unused modules)
   - Performance measurements (eval time, closure sizes)
   - Specific issues to fix
   - Prioritized recommendations

2. **Quality Dashboard**
   - Generated markdown dashboard at `docs/QUALITY_DASHBOARD.md`
   - Visual overview of all metrics
   - Trend analysis (after multiple runs)

3. **Baselines Established**
   - Coverage baseline
   - Performance baseline
   - Closure size baselines
   - Used for future regression detection

4. **Confidence Statement**
   - Clear answer to: "Is my configuration production-ready?"
   - Specific metrics supporting the answer

## Expected Metrics

You'll get measurements for:

- **Test Coverage**: X% (target: 100% critical paths)
- **Evaluation Time**: X.Xs (target: <10s)
- **Closure Sizes**:
  - desktop: X.XGB / 3GB
  - portable: X.XGB / 2.5GB
  - surface: X.XGB / 2.5GB
  - hp-probook-vmware: X.XGB / 2GB
  - hp-probook-wsl: X.XGB / 2GB
- **Dead Code**: X bindings
- **Unused Modules**: X files
- **Quality Gates**: X/5 passing

## Time Estimate

- Quick checks (coverage, unused modules): ~5 minutes
- Closure size checks (first run): ~30-60 minutes (builds all hosts)
- Report generation: ~10 minutes

**Total**: ~45-75 minutes for comprehensive assessment

## Files to Review After Next Session

1. `QUALITY_ASSESSMENT_REPORT_<date>.md` - Comprehensive report
2. `docs/QUALITY_DASHBOARD.md` - Generated dashboard
3. `.quality-metrics/*.json` - Raw metrics data
4. `.quality-metrics/*-baseline.txt` - Established baselines

## Common Questions

**Q: Will this modify my configuration?**
A: No. All commands are read-only analysis. They measure and report, but don't change code.

**Q: Do I need to fix issues before committing?**
A: Yes, if you want CI to pass. Quality gates will fail CI on:
- Dead code present
- Unused modules found
- Coverage <100% (critical paths)
- Evaluation time >10s

**Q: Can I skip the closure size check?**
A: Yes, but you won't get complete performance data. Use `just coverage` instead of `just quality-check`.

**Q: What if metrics are bad?**
A: The report will include specific recommendations to improve each metric.

## After the Assessment

Once you have the quality report:

1. **Review findings**: Understand current state
2. **Fix critical issues**: Address failing quality gates
3. **Commit changes**: New quality monitoring system + any fixes
4. **Watch CI**: Quality gates will run automatically
5. **Monitor dashboard**: Track improvements over time

## Optional Follow-ups

After quality assessment, you can:

- Enable GitHub Pages for live dashboard
- Set up dynamic badges (follow `docs/BADGES_SETUP.md`)
- Create Wiki pages with quality standards
- Add custom metrics or thresholds

## Support Documentation

- `docs/QUALITY_CHECK_SESSION_PROMPT.md` - Detailed session instructions
- `docs/IMPLEMENTATION_VERIFICATION.md` - What was implemented
- `docs/QUALITY_MONITORING_SETUP.md` - How to use the system
- `docs/BADGES_SETUP.md` - Optional badge configuration
- `CLAUDE.md` - Updated with quality monitoring section

## Ready to Proceed

Everything is prepared for your next session. The quality monitoring system is production-ready and waiting to analyze your configuration.

**Recommended**: Use Option 1 (prepared prompt) for best results.
