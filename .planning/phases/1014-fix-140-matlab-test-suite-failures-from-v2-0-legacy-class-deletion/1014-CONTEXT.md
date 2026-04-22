# Phase 1014: Fix ~140 MATLAB test-suite failures from v2.0 legacy-class deletion — Context

**Gathered:** 2026-04-22
**Status:** Ready for planning
**Source:** Pre-planning investigation (CI log analysis + code reading) — no /gsd:discuss-phase session

<domain>
## Phase Boundary

**In scope:** Fix the failing tests in `tests/suite/*.m` under MATLAB CI so the `Tests → MATLAB Tests` job returns to green.

**Scope = tests only.** Library code under `libs/` is assumed correct. Changes to `libs/` are permitted only when a test surfaces a genuine product bug (see "Category E" below); everywhere else, the test is updated to the new v2.0 Tag API or deleted if it exercised behaviour that no longer exists.

**Out of scope:**
- Octave tests (`tests/test_*.m`) — already green; do not touch.
- Function-style tests under `tests/` root.
- Non-test product code changes except the two confirmed bugs in Category E.
- Performance tuning, refactoring, documentation (beyond phase artefacts).

**Success = MATLAB Tests job green on CI** for a push to a topic branch (same command as CI: `addpath('scripts'); run_tests_with_coverage();`). Octave Tests must remain green. No new MISS_HIT lint warnings.

</domain>

<decisions>
## Implementation Decisions

### D-01. Scope = `tests/suite/*.m` only
Fix all failing tests in the classdef suite under `tests/suite/`. Do not re-work library code to match old tests. Do not touch `tests/test_*.m`.

### D-02. Failure categorisation (locked)
Every failing test falls into exactly one of these categories. The plan per category is prescriptive:

**A. Legacy-class constructors removed (~80 failures across ~13 files)**
Tests instantiate classes deleted in commit `4188a7f` (Phase 1011 cleanup): `Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`. Also `detectEventsFromSensor`, `loadModuleData`, `loadModuleMetadata`.

**Action:**
- If a reasonable Tag-API equivalent exists (e.g. `SensorTag`, `MonitorTag`, `TagRegistry`, `CompositeTag`) and the test still expresses a meaningful invariant → **migrate** to the new API, keeping the test name, preserving what's being verified.
- If the test was specifically exercising deleted behaviour (e.g. `detectEventsFromSensor` standalone function, `ExternalSensorRegistry` construction) and no v2.0 equivalent exists → **delete** the individual `function testX` method (not the whole file unless every method falls in this bucket).

**B. `EventDetector.detect(...)` signature change (~8 failures, `TestEventDetector`)**
Old API: `det.detect(t, values, threshold, direction, label, sensorName)` — 6 args.
Current API: — verify actual signature by reading `libs/EventDetection/EventDetector.m` during planning. Tests must be rewritten against current signature OR deleted if the old overload was removed for good.

**C. `testCase.TestData` property not available in R2020b (~10 failures, `TestNavigatorOverlay` primary victim)**
`testCase.TestData` was added in R2023a. MATLAB CI is pinned to R2020b (Phase 1006 locked this).

**Action:** Migrate every `testCase.TestData.X` reference to a `properties (Access = private)` block on the test class — this is exactly what Phase 1006's MATLABFIX-B did for other tests. Pattern proven.

**D. Headless image export (4 failures, `TestDashboardToolbarImageExport`)**
Error: `'DashboardEngine:imageWriteFailed' — Specified handle is not valid for export`. Phase 1006 supposedly fixed this (`1006-04-PLAN.md`), so verify during research whether it regressed or whether these tests bypass the fix.

**Action:** If regression → narrow fix in the test or in `DashboardEngine.exportImage` if a library bug. If never-fixed → same pattern as Phase 1006-04.

**E. Two genuine product bugs in `DashboardBugFixes` (MUST fix in `libs/`)**
1. `TestDashboardBugFixes/testSensorListenersMultiPage` (line 265) — **fail cause is in the TEST not product**: the test reassigns local variable `s_y_ = rand(1,10)` which cannot trigger a PostSet listener on `SensorTag.Y`. Fix = call `s.updateData(x, newY)` so the listener fires. No `libs/` change needed.
2. `TestDashboardBugFixes/testExitEditModeAfterFigureClose` (line 200) — **fail cause is in `libs/Dashboard/DashboardBuilder.m:124`**. `exitEditMode` calls `set(hFig, 'WindowButtonMotionFcn', ...)` before checking `ishandle(hFig)`. There is already an `ishandle` guard at line 140, but it runs AFTER the first two `set` calls. Reorder: check `ishandle` first, guard the early `set` calls too. This IS a library fix.

**F. Residual single-test oddballs (verify-failed, not errored)**
- `TestTag/testConstructorRequiresKey` — verify Tag constructor contract; may be outdated.
- `TestToolbar/*` (3) — may be UI-layer drift.
- `TestMonitorTagEvents/testCarrierPatternNoTagKeys` — read current MonitorTag contract.
- `TestMonitorTagPersistence/*` (3) — persistence semantics may have changed.
- `TestDashboardSerializerRoundTrip/testRoundTripPreservesWidgetSpecificProperties` — 4 sub-verifications fail; widget property list drift.
- Others listed in research.

**Action:** Per-test root-cause; no bulk rule. Research pass enumerates them; planner assigns each to "fix test" or "fix lib".

### D-03. Verification strategy
- Must run the MATLAB suite locally before CI. Use `scripts/run_tests_with_coverage.m` in a MATLAB instance (user has MATLAB). If the orchestrator lacks MATLAB, use `tests/run_all_tests.m` under Octave as a smoke proxy, but the authoritative signal is the CI `MATLAB Tests` job.
- Octave suite must stay green (`octave tests/run_all_tests.m`) — every plan includes an Octave sanity check in verification.
- MISS_HIT must stay clean (`mh_style libs/ tests/ examples/`, `mh_lint ...`, `mh_metric --ci ...`).

### D-04. Commit discipline
- **One test-class per commit** when feasible, so bisection of future regressions remains trivial.
- Commit messages: `fix(1014-test): migrate TestXxx to Tag API` or `fix(1014-lib): <exact product fix>`.
- No bundled "cleanup" changes to unrelated files in the same commit.
- No MISS_HIT suppressions added — if lint breaks, rewrite the test.

### D-05. Budget and kill-switch
- Soft budget: 2 working days of Claude execution time. Hard budget: 4 days.
- If any single test class takes > 45 minutes to migrate, **delete the failing test methods** rather than over-investing. A missing test is recoverable; a bad migration that hides a bug is not.
- If fixes to `libs/` cascade beyond the two explicitly-authorised files in Category E, STOP and re-discuss — that means the scope was mis-categorised.

### D-06. Defer list (explicit non-goals)
- Do **not** add new test coverage. Only restore what compiles.
- Do **not** migrate Octave function-style tests to classdef.
- Do **not** re-introduce legacy shims (`Threshold.m`, `Sensor.m`, etc.) even if "faster". The v2.0 migration was deliberate; shims would leak dead code.
- Do **not** rename test classes unless the migration strictly requires it.

### Claude's Discretion
- Exact wave structure for the plan (likely: Wave 1 = Category A bulk-migration infra + pattern doc; Wave 2 = per-file migrations in parallel; Wave 3 = residual Categories B/C/D/E/F).
- Whether to split `TestSensorDetailPlot` (21 failures, largest offender) across multiple plans or keep as one.
- Choice between "migrate to Tag API" vs "delete" for each individual legacy-class test — planner uses the D-02-A heuristic.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Test infrastructure
- `scripts/run_tests_with_coverage.m` — MATLAB CI entry point; lists the suite directory and runs `TestRunner.withTextOutput`.
- `tests/run_all_tests.m` — Octave test runner (function-style tests). Must stay green.
- `.github/workflows/tests.yml` — CI workflow; MATLAB is pinned to R2020b (line 54).

### v2.0 Tag API (replaces deleted legacy classes)
- `libs/SensorThreshold/Tag.m` — abstract base.
- `libs/SensorThreshold/SensorTag.m` — replaces legacy `Sensor`.
- `libs/SensorThreshold/MonitorTag.m` — replaces the `Threshold` + alarm concept (see docstring lines 1-60 — explains lazy/persist/event semantics).
- `libs/SensorThreshold/StateTag.m` — replaces `StateChannel`.
- `libs/SensorThreshold/CompositeTag.m` — replaces `CompositeThreshold`.
- `libs/SensorThreshold/TagRegistry.m` — replaces `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`.

### Prior-art test migrations (use as pattern source)
- `tests/suite/TestCompositeTag.m` — green, uses new API. Shows `TagRegistry.register/unregister` cleanup pattern.
- `tests/suite/TestFastSenseTheme.m` — green, uses `properties` pattern (not `TestData`).
- Commit `4188a7f` — deletion of legacy classes. `git show 4188a7f` lists every removed symbol.
- Commit `6502d30` — last known R2020b-green MATLAB CI baseline (before legacy deletion).

### Prior phase artefacts to reference (do not duplicate)
- `.planning/phases/1006-fix-.../1006-CONTEXT.md` + four PLAN.md files — previous "fix N MATLAB test failures" phase. Categories MATLABFIX-A, -B, -C, -D, -E, -F, -G. Phase 1014's Category C matches MATLABFIX-B exactly; pattern is reusable.
- `.planning/debug/matlab-tests-failures-investigation.md` (if still present) — may document further patterns.

### Library files that MUST be touched (Category E only)
- `libs/Dashboard/DashboardBuilder.m:117-145` — `exitEditMode` method; needs early-return `ishandle` guard.
- No other `libs/` files in scope.

### Product contract (do NOT break)
- `libs/SensorThreshold/SensorTag.m` PostSet listener on `Y` — confirm `updateData(x, y)` still fires PostSet. The `testSensorListenersMultiPage` regression tests this contract.

</canonical_refs>

<specifics>
## Specific Ideas

### Failing-test inventory (from CI run `24780979036`)

**Error-occurred (did not run to completion) — 112 unique methods:**
TestChipBarWidget (3), TestDashboardBugFixes (1 of 2), TestDashboardEngine (1), TestDashboardPerformance (1), TestDashboardToolbarImageExport (4), TestDataStoreWAL (2), TestDatastoreEdgeCases (1), TestEventConfig (6), TestEventDetector (8), TestEventDetectorTag (3), TestEventStore (7), TestFastSenseAddTag (1), TestFastSenseWidget (2), TestFastSenseWidgetUpdate (1), TestGaugeWidget (7), TestIconCardWidget (6), TestIconCardWidgetTag (3), TestIncrementalDetector (8), TestLiveEventPipelineTag (4), TestLivePipeline (8), TestMonitorTagPersistence (2), TestMultiStatusWidget (9), TestMultiStatusWidgetTag (2), TestNavigatorOverlay (10), TestNumberWidget (1), TestSensorDetailPlot (21), TestSensorDetailPlotTag (3), TestStatusWidget (11), TestWebBridge (5).

**Verification-failed (ran but assertion failed) — ~28 unique methods:**
TestDashboardBugFixes (1), TestDashboardBuilderInteraction (5), TestDashboardSerializerRoundTrip (1 × 4 sub-verifications), TestDataSource (1), TestFastSenseWidget (1), TestGaugeWidget (1), TestIconCardWidgetTag (4), TestLiveEventPipelineTag (2), TestMonitorTagEvents (1), TestMonitorTagPersistence (3), TestMultiStatusWidgetTag (1), TestNumberWidget (2), TestStatusWidget (1), TestTag (1), TestToolbar (3).

### Example migration patterns

**A. Legacy `Threshold(...)` → `MonitorTag(...)`:**
```matlab
% Before (fails — Threshold class deleted):
t = Threshold('cbw_thr_test', 'Direction', 'upper');
t.addCondition(struct(), 50);

% After (Tag API — check exact constructor in libs/SensorThreshold/MonitorTag.m):
parent = SensorTag('cbw_thr_parent');   % placeholder parent
parent.updateData([1 2], [0 0]);
t = MonitorTag('cbw_thr_test', 'Parent', parent, ...
               'ConditionFn', @(x,y) y > 50);
```
**NB:** The old `Threshold` encapsulated "value + direction + label". The new `MonitorTag` encapsulates a conditional boolean series bound to a parent. If a test was only checking threshold *values*, the test may need a simpler `struct('upper', 50)` mock rather than a `MonitorTag` — planner decides per test.

**B. Legacy `testCase.TestData` → `properties`:**
```matlab
% Before (fails on R2020b):
classdef TestX < matlab.unittest.TestCase
    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.TestData.hFig = figure('Visible','off');
        end
    end
end

% After:
classdef TestX < matlab.unittest.TestCase
    properties (Access = private)
        hFig
    end
    methods (TestMethodSetup)
        function createFixture(testCase)
            testCase.hFig = figure('Visible','off');
        end
    end
end
```
Every reference inside test methods: `testCase.TestData.hFig` → `testCase.hFig`.

**C. `DashboardBuilder.exitEditMode` deleted-handle guard (Category E):**
```matlab
function exitEditMode(obj)
    if ~obj.IsActive, return; end
    obj.IsActive = false;
    obj.SelectedIdx = 0;
    obj.DragMode = '';

    hFig = obj.Engine.hFigure;
    % FIX: guard deleted figure BEFORE any `set` calls.
    if ~isempty(hFig) && ishandle(hFig)
        set(hFig, 'WindowButtonMotionFcn', obj.OldMotionFcn);
        set(hFig, 'WindowButtonUpFcn', obj.OldButtonUpFcn);
    end
    obj.OldMotionFcn = '';
    obj.OldButtonUpFcn = '';

    obj.clearOverlays();
    obj.clearGrid();
    obj.destroyGhost();

    safeDelete(obj.hPalette);  obj.hPalette = [];
    safeDelete(obj.hPropsPanel); obj.hPropsPanel = [];

    if isempty(hFig) || ~ishandle(hFig)
        return;
    end
    set(hFig, 'WindowButtonMotionFcn', '');
    set(hFig, 'WindowButtonUpFcn', '');
    % ... rest unchanged
end
```

**D. `testSensorListenersMultiPage` fix (Category E, test side):**
```matlab
% Before (line 263-265, local assignment doesn't trigger PostSet):
try
    s_y_ = rand(1, 10);   % BUG: assigns to local var, not s.Y
    testCase.verifyTrue(w.Dirty, ...);

% After:
try
    s.updateData(1:10, rand(1, 10));  % triggers PostSet on s.Y
    testCase.verifyTrue(w.Dirty, ...);
```

</specifics>

<deferred>
## Deferred Ideas

- **Test coverage gap audit.** Some tests deleted under Category A previously exercised deleted behaviour that *might* have a new-API analogue we haven't written coverage for. Capturing this is a v2.1 concern, not a 1014 concern. Track as a backlog item if it emerges.
- **Consolidating `TestSensorDetailPlot`, `TestSensorDetailPlotTag`, `TestFastSenseWidget`, `TestFastSenseAddTag`** — there is likely duplication between the `*Tag` variants and originals. Deferred: consolidation is a separate refactor.
- **MATLAB R2020b → R2023b upgrade.** Would eliminate Category C fixes entirely (native `TestData` support). Phase 1006 deliberately pinned R2020b; re-opening the pin is out of scope.
- **Octave classdef suite coverage.** Octave runs only function-style tests. Expanding to classdef is a CI enhancement, not a 1014 goal.

</deferred>

---

*Phase: 1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion*
*Context gathered: 2026-04-22 from CI log analysis + code reading + Phase 1006 precedent*
