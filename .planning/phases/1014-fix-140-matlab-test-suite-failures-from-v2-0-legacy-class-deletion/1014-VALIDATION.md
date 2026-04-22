---
phase: 1014
slug: fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 1014 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` (classdef) + GNU Octave function-style |
| **Config file** | `scripts/run_tests_with_coverage.m` (MATLAB), `tests/run_all_tests.m` (Octave), `miss_hit.cfg` (lint) |
| **Quick run command** | Per-class: `matlab -batch "addpath('scripts'); install(); runtests('tests/suite/TestX.m')"` (MATLAB) or `octave --eval "cd tests; test_x()"` (Octave) |
| **Full suite command** | `matlab -batch "addpath('scripts'); run_tests_with_coverage()"` (authoritative) + `octave --eval "cd tests; run_all_tests()"` (sanity) + `mh_style libs/ tests/ examples/ && mh_lint libs/ tests/ examples/ && mh_metric --ci libs/ tests/ examples/` (lint gate) |
| **Estimated runtime** | MATLAB full suite: ~90-120s. Octave full suite: ~30s. Lint: ~15s. Per-class quick: <10s. |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the exact `TestX.m` file touched. Sanity-run Octave (`octave --eval "cd tests; run_all_tests()"`) — must stay green, no regressions from test-deletion collateral.
- **After every plan wave:** Run full MATLAB suite (`matlab -batch "addpath('scripts'); run_tests_with_coverage()"`) + full Octave + MISS_HIT lint.
- **Before `/gsd:verify-work`:** All three gates green (MATLAB, Octave, lint). CI push to a topic branch must show `MATLAB Tests` green.
- **Max feedback latency:** 120 seconds (MATLAB full run). Per-commit loop is <30s (Octave + lint).

---

## Per-Task Verification Map

> Concrete task IDs are assigned by the planner. The table below is the template shape — planner fills per-plan rows. Every task MUST have a command that proves the test count for its affected file is ≥ what the log claims AND that no previously-green suite-level test regresses.

| Task ID | Plan | Wave | Scope | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------|-----------|-------------------|-------------|--------|
| 1014-01-* | 01 | 0 | Category C (TestData → properties) + Category E (DashboardBuilder guard + listener test fix) | classdef migration | `matlab -batch "runtests('tests/suite/TestNavigatorOverlay.m'); runtests('tests/suite/TestSensorDetailPlot.m'); runtests('tests/suite/TestDashboardBugFixes.m')"` | ✅ (exists, broken) | ⬜ pending |
| 1014-02-* | 02 | 1 | Widget threshold-test DELETE batch | classdef delete-method | `matlab -batch "runtests(['TestStatusWidget','TestGaugeWidget','TestIconCardWidget','TestMultiStatusWidget','TestChipBarWidget'])"` | ✅ | ⬜ pending |
| 1014-03-* | 03 | 1 | `*Tag.m` Threshold-call strip | classdef migration | `matlab -batch "runtests({Tag suite})"` | ✅ | ⬜ pending |
| 1014-04-* | 04 | 1 | TestSensorDetailPlot heavy-hitter | classdef bulk migration | `matlab -batch "runtests('tests/suite/TestSensorDetailPlot.m')"` | ✅ | ⬜ pending |
| 1014-05-* | 05 | 1 | EventDetection tests collapse | classdef delete-file | `matlab -batch "runtests(['TestEventDetector','TestIncrementalDetector','TestEventStore','TestEventConfig','TestLivePipeline'])"` | ✅ (delete-majority) | ⬜ pending |
| 1014-06-* | 06 | 2 | Dashboard small-numbers batch | classdef mixed | `matlab -batch "runtests({Dashboard suite})"` | ✅ | ⬜ pending |
| 1014-07-* | 07 | 3 | Category F residual triage | classdef per-test | `matlab -batch "runtests({residual})"` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestNavigatorOverlay.m` — migrate `testCase.TestData.{hFig, hAxes}` → `properties (Access = private)` block (Category C pattern; replicated across ~10 test methods)
- [ ] `tests/suite/TestSensorDetailPlot.m` — identify Category C subset (`testCase.TestData.sensor`) vs Category A subset (legacy `Sensor(...)` calls). Migration of `TestData` is Wave 0; legacy-class migration is Wave 1 (Plan 04).
- [ ] `tests/suite/TestDashboardBugFixes.m:263-265` — replace local-variable assignment `s_y_ = rand(1,10)` with `s.updateData(1:10, rand(1,10))` so PostSet listener fires.
- [ ] `libs/Dashboard/DashboardBuilder.m:117-151` — hoist `ishandle(hFig)` guard ABOVE line-124 `set(hFig, 'WindowButtonMotionFcn', ...)` so deleted-figure cleanup doesn't throw.
- [ ] `scripts/run_tests_with_coverage.m` — DO NOT modify. Keep authoritative CI entry untouched.
- [ ] No new MATLAB toolboxes required (pure classdef migration, leverages existing `matlab.unittest`).

*Infrastructure already in place: `matlab.unittest` framework, Octave function-style suite, MISS_HIT, CI workflow (`.github/workflows/tests.yml`). Nothing to install.*

---

## Manual-Only Verifications

| Behavior | Category | Why Manual | Test Instructions |
|----------|----------|------------|-------------------|
| CI `MATLAB Tests` job green on push | D-03 (CONTEXT) | Requires GitHub Actions runner; cannot run locally | Push branch → check `gh run list --workflow "Tests" --branch <branch>` → confirm `MATLAB Tests` = success |
| Figure-close cleanup in interactive edit mode | E1 | `testExitEditModeAfterFigureClose` covers this automatically — but sanity-check locally by opening a dashboard, entering edit mode, `close(gcf)`, calling `b.exitEditMode()` — should not throw | Local MATLAB session only — automated test should be authoritative |
| PostSet listener routes widget dirty on multi-page `SensorTag.Y` change | E2 | `testSensorListenersMultiPage` covers this — but visual-verify at least once that the widget actually re-renders | MATLAB session: create 2-page dashboard with sensor widget, assign new data → widget refreshes |

*Everything else has automated verification via `matlab.unittest`.*

---

## Validation Sign-Off

- [ ] All tasks have a direct `runtests('tests/suite/TestX.m')` or `runtests(['TestX','TestY'])` verification command in their `<verify>` block
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify; every commit runs Octave + lint at minimum
- [ ] Wave 0 covers Category C (2 files) + Category E (1 test, 1 lib) before Wave 1 parallel work begins
- [ ] No watch-mode flags (classdef `runtests` runs once and exits — no `-continuous`)
- [ ] Feedback latency < 120s (MATLAB full suite) / < 30s (per-class quick)
- [ ] `nyquist_compliant: true` set in frontmatter once planner's Wave 0 tasks land

**Approval:** pending (set to `approved YYYY-MM-DD` after Wave 0 green)
