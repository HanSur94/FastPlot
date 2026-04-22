---
phase: 1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion
plan: 03
subsystem: tests/suite
tags: [test-migration, tag-api, threshold-strip, wave-1]
dependency_graph:
  requires: [1014-01]
  provides: [Tag-API test files cleaned of deleted legacy-class constructor calls]
  affects: [TestIconCardWidgetTag, TestMultiStatusWidgetTag, TestEventDetectorTag, TestLiveEventPipelineTag, TestFastSenseAddTag]
tech_stack:
  added: []
  patterns: [D-02-A default-delete heuristic, Pitfall 5 empty-block guard via testConstructorSmoke]
key_files:
  created: []
  modified:
    - tests/suite/TestIconCardWidgetTag.m
    - tests/suite/TestMultiStatusWidgetTag.m
    - tests/suite/TestEventDetectorTag.m
    - tests/suite/TestLiveEventPipelineTag.m
    - tests/suite/TestFastSenseAddTag.m
decisions:
  - TestSensorDetailPlotTag.m was already clean (zero legacy-class refs) — no commit needed
  - TestMonitorTagPersistence.m was already clean — all grep + structural gates pass against current MonitorTag.m and FastSenseDataStore.m source
  - TestFastSenseWidgetTag.m + TestEventTimelineWidgetTag.m explicitly NOT touched (green-in-CI guard per D-06)
metrics:
  duration: ~15 min
  completed: 2026-04-22
requirements: [PHASE-1014-GATE]
---

# Phase 1014 Plan 03: `*Tag.m` Threshold-call strip (7 files) Summary

Stripped deleted `Threshold(...)` / `addThreshold(...)` calls from five Tag-API test files via per-method triage (delete dead-class-dependent methods, migrate salvageable ones). Two in-scope files were already clean; two out-of-scope green-in-CI files were preserved byte-for-byte.

## Per-File Triage

### tests/suite/TestIconCardWidgetTag.m (commit 6734727)
- **DELETED** `testTagPrecedenceOverThreshold` — constructed `Threshold(...)` to test Tag-vs-Threshold mutex; no v2.0 equivalent (Threshold class gone)
- **DELETED** `testLegacyThresholdPathStillWorks` — the "legacy" path no longer exists in v2.0
- **UNCHANGED** `testTagPropertyRender`, `testTagOkState`, `testTagToStructRoundTrip`, `testLegacySensorPathStillWorks`, `testCompositeTagValueAt` (5 methods; all zero legacy-class refs)

### tests/suite/TestMultiStatusWidgetTag.m (commit 55bdf3d)
- **DELETED** `testLegacyThresholdItemStillWorks` — threshold-struct item built via deleted Threshold
- **UNCHANGED** `testTagItemAlarmStatus`, `testTagItemOkStatus`, `testTagItemStringKey`, `testTagRoundTripViaToStruct`, `testLegacySensorItemStillWorks`, `testCompositeTagExpansion`, `testBaseClassTagSourceEmittedInToStruct` (7 methods)

### tests/suite/TestEventDetectorTag.m (commit de5974f)
- **DELETED** `testTagOverloadDetectsEvents` — `det.detect(tag, thr)` second arg needs `.allValues()` method; Threshold class deleted, no substitute
- **DELETED** `testLegacySixArgOverloadUnchanged` — 6-arg detect overload removed in Phase 1011
- **DELETED** `testTagOverloadWithEmptyTag` — same Threshold-construction blocker
- **ADDED** `testConstructorSmoke` — Pitfall 5 non-empty `methods (Test)` block guard
- **UNCHANGED** `testNonTagNonSensorErrors`, `testPitfall1NoSubclassIsaInDetect`

### tests/suite/TestLiveEventPipelineTag.m (commit f36a24f)
- **DELETED** `testLegacySensorPathUnchanged` — used deleted Threshold + Sensor.addThreshold
- **DELETED** `testMixedSensorsAndMonitors` — Sensor-side used deleted pipeline; monitor half is redundant with `testMonitorTagPathEmitsEventsOnAppendData`
- **MIGRATED** `testMonitorsNVPairOptional` — stripped Sensor/Threshold scaffolding; kept the MonitorTargets-defaults-empty assertion by passing empty maps
- **UNCHANGED** `testMonitorTagPathEmitsEventsOnAppendData`, `testAppendDataOrderWithParent` (both pure v2.0 Tag API; use shared fixture `makeLiveTagFixture_`)

### tests/suite/TestFastSenseAddTag.m (commit add6472)
- **MIGRATED** `testAddTagMixedWithLegacy` — bug fix, not legacy-ref strip. Original code: `legacy.updateData(1:50, cos(legacy.X * 0.2))` evaluated `legacy.X` (empty at that point) before updateData, producing `Y=[]` then `updateData(1:50, [])`. Fixed to `cos((1:50) * 0.2)`. This was the "1 error" CI hit.
- **UNCHANGED** all other methods (zero legacy-class refs; all test the polymorphic `addTag` dispatcher)

### tests/suite/TestSensorDetailPlotTag.m (no commit — file already clean)
- Already zero legacy-class constructor calls (only a `Sensor` mention inside a comment). All 4 methods use `SensorTag` / `MockTag` / `MakePhase1009Fixtures`. Nothing to edit.

### tests/suite/TestMonitorTagPersistence.m (no commit — file already clean)
- Already zero legacy-class constructor calls. All 9 methods use v2.0 API (`SensorTag`, `MonitorTag`, `FastSenseDataStore`, `TagRegistry`).
- Verified grep gates + Pitfall 2 structural gate pass against current source:
  - `function storeMonitor`, `function [.*] = loadMonitor`, `function clearMonitor`, `CREATE TABLE monitors` — 4 matches in FastSenseDataStore.m (gate passes).
  - `Persist = false`, `DataStore = []` — present in MonitorTag.m properties block (gate passes).
  - 1 `storeMonitor(` call in MonitorTag.m at line 694, guarded by `if obj.Persist` on preceding line 693 — inside 5-line window (Pitfall 2 gate passes).

## NOT touched (green-in-CI guard per D-06)

- `tests/suite/TestFastSenseWidgetTag.m` — `git diff main` = 0 lines
- `tests/suite/TestEventTimelineWidgetTag.m` — `git diff main` = 0 lines

Confirmed these files already contain zero legacy-class constructor calls in current CI; editing them would violate D-06 ("no new test coverage; only restore what compiles").

## Commits Landed (5 of 7 planned; 2 files were already clean)

| Plan commit hash | Message |
|------------------|---------|
| 6734727 | fix(1014-test): strip Threshold arms from TestIconCardWidgetTag |
| b262faf | fix(1014-03): restore TestEventDetector.m (out-of-scope for Plan 03) |
| 55bdf3d | fix(1014-test): strip Threshold arms from TestMultiStatusWidgetTag |
| de5974f | fix(1014-test): strip Threshold arms from TestEventDetectorTag |
| f36a24f | fix(1014-test): strip Threshold arms from TestLiveEventPipelineTag |
| add6472 | fix(1014-test): fix TestFastSenseAddTag/testAddTagMixedWithLegacy length mismatch |

**Note on b262faf:** parallel Plan 05 agent deleted `tests/suite/TestEventDetector.m` in the shared worktree. That deletion was unintentionally carried along by my TestIconCardWidgetTag.m commit (working-tree deletion present at commit time). The follow-up commit b262faf restored the file from `HEAD~1` to preserve Plan 03's atomicity. The legitimate Plan 05 deletion lands separately (d2d1405 was already committed by the parallel agent before my restore).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Fixed `legacy.X` evaluated-before-updateData bug**
- **Found during:** Task 2 (TestFastSenseAddTag)
- **Issue:** `cos(legacy.X * 0.2)` was passed as Y to `updateData(1:50, Y)`, but `legacy.X` was empty at that point (SensorTag was constructed without X). Result: `Y=[]`, length-mismatch error.
- **Fix:** Replace with `cos((1:50) * 0.2)`.
- **Files modified:** tests/suite/TestFastSenseAddTag.m
- **Commit:** add6472

**2. [Rule 3 — Blocker] Restored accidentally-included TestEventDetector.m deletion**
- **Found during:** Task 1 commit for TestIconCardWidgetTag
- **Issue:** Parallel Plan 05 had deleted `tests/suite/TestEventDetector.m` from the working tree. My `git add tests/suite/TestIconCardWidgetTag.m` commit captured the deletion because git records working-tree deletions even without explicit staging when files are tracked.
- **Fix:** Restored file from `HEAD~1` and committed separately as b262faf to preserve Plan 03 atomicity. Plan 05's legitimate deletion (commit d2d1405) landed separately.
- **Files modified:** tests/suite/TestEventDetector.m
- **Commit:** b262faf

### Plan count discrepancy

Plan text stated "7 commits landed (one per file per D-04)" but triage discovered 2 of the 7 files (TestSensorDetailPlotTag.m, TestMonitorTagPersistence.m) already had zero legacy-class refs in current HEAD. Per D-04 ("No bundled 'cleanup' changes" and "one test-class per commit when feasible"), no-op commits for clean files would be spurious. 5 content commits + 1 scope-restoration commit = 6 total commits. Plan acceptance criterion #1 (grep = 0 on all 7 files) is met.

## Verification

- `grep -cE "\b(Threshold|CompositeThreshold|ThresholdRule|Sensor|StateChannel|SensorRegistry|ThresholdRegistry|ExternalSensorRegistry)\s*\(" tests/suite/<each>` — **0** for all 7 files (TestSensorDetailPlotTag.m shows 1, inside a docstring comment, not a constructor call)
- `grep -c "addThreshold\|detectEventsFromSensor" tests/suite/<each>` — **0** for all 7 files
- `git diff main -- tests/suite/TestFastSenseWidgetTag.m tests/suite/TestEventTimelineWidgetTag.m` — **0 lines** (NOT-in-scope guard files untouched)
- `mh_style` + `mh_lint` on all 7 files — clean ("7 file(s) analysed, everything seems fine")
- Octave function-style suite (`tests/run_all_tests.m`) — **74/75 passed, 1 failed**. The 1 failure is a pre-existing `test_add_marker` graphics-driver segfault (`"Fallback to SW vertex processing"` → `"fatal: caught signal Segmentation fault: 11"`) — unrelated to Tag/Threshold migration; affects only local macOS OpenGL, not CI.
- Authoritative signal (CI MATLAB Tests job) not runnable locally per D-03; CI run will verify.

## Self-Check: PASSED

Files verified to exist:
- tests/suite/TestIconCardWidgetTag.m — FOUND, modified
- tests/suite/TestMultiStatusWidgetTag.m — FOUND, modified
- tests/suite/TestEventDetectorTag.m — FOUND, modified
- tests/suite/TestLiveEventPipelineTag.m — FOUND, modified
- tests/suite/TestFastSenseAddTag.m — FOUND, modified
- tests/suite/TestSensorDetailPlotTag.m — FOUND, already clean
- tests/suite/TestMonitorTagPersistence.m — FOUND, already clean

Commits verified in git log:
- 6734727, b262faf, 55bdf3d, de5974f, f36a24f, add6472 — all FOUND.
