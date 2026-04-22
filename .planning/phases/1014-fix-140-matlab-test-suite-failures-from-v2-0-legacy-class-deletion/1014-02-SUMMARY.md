---
phase: 1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion
plan: 02
subsystem: tests
tags: [test-cleanup, legacy-deletion, widget-tests, wave-1]
requires: [1014-01]
provides: [widget-threshold-test-cleanup]
affects: [tests/suite]
tech_added: []
key_files:
  modified:
    - tests/suite/TestStatusWidget.m
    - tests/suite/TestGaugeWidget.m
    - tests/suite/TestIconCardWidget.m
    - tests/suite/TestMultiStatusWidget.m
    - tests/suite/TestChipBarWidget.m
decisions:
  - "Deletion-only per D-02-A: every method that instantiates Threshold/CompositeThreshold was removed outright, no migration to MonitorTag (widget-side dispatch branches are dead post-Phase 1011)"
  - "Pitfall 5 satisfied: every modified file retains >=1 surviving method in methods (Test) block; TestMultiStatusWidget has the minimum 2 survivors"
metrics:
  duration: ~15min
  tasks_completed: 2
  files_modified: 5
  commits: 5
  methods_deleted: 35
---

# Phase 1014 Plan 02: Widget Threshold-Test DELETE Batch Summary

One-liner: Stripped 35 legacy-class (Threshold / CompositeThreshold) test methods across 5 widget-test classdef files so the MATLAB test suite compiles and the widget-side dead-code dispatch branches are no longer exercised.

## What Changed

Five `tests/suite/Test*Widget.m` classdef files each had every test method whose body instantiated the v2.0-removed `Threshold` or `CompositeThreshold` class deleted. Per D-02-A heuristic: these methods were specifically exercising widget branches (`t.IsUpper`, `t.allValues()` in `StatusWidget.m:162-200`, `GaugeWidget`, `IconCardWidget`, `MultiStatusWidget`, `ChipBarWidget`) that became unreachable when `Threshold.m` was deleted in commit `4188a7f` (Phase 1011 cleanup). No object of the deleted type can flow through those branches, so deletion preserves semantic coverage — the tests were testing dead code.

Parallel coverage for the live `MonitorTag` API path lives in the `*Tag.m` test files (Plan 03's scope, untouched by this plan).

## Per-File Method Breakdown

### tests/suite/TestStatusWidget.m — 10 deleted, 10 kept

**Deleted** (commit `6f318b1`):
- testDeriveStatusFromSensorWithThresholds
- testConstructorThresholdBinding
- testThresholdKeyResolution
- testMutualExclusivity
- testDeriveStatusFromThreshold
- testThresholdPathPriority
- testValueFcnLiveTick
- testSerializeThresholdRoundTrip
- testThresholdValueLabel
- testLowerThresholdViolation

**Kept**: testConstruction, testDefaultPosition, testRender, testRefreshStaticStatus, testRefreshWithStatusFcn, testRefreshWithTag, testToStruct, testToStructWithStaticStatus, testFromStruct, testGetType

### tests/suite/TestGaugeWidget.m — 7 deleted, 14 kept

**Deleted** (commit `b083ade`):
- testRangeDeriveFromTag
- testConstructorThresholdBinding
- testThresholdRangeDerivation
- testThresholdColorPath
- testMutualExclusivity
- testSerializeThresholdRoundTrip
- testThresholdWithValueFcn

**Kept**: testConstruction, testDefaultPosition, testFourStyles, testRenderArc, testRenderDonut, testRenderBar, testRenderThermometer, testRefreshStaticValue, testRefreshWithValueFcn, testRefreshWithTag, testUnitsDeriveFromTag, testToStruct, testFromStruct, testGetType

### tests/suite/TestIconCardWidget.m — 6 deleted, 12 kept

**Deleted** (commit `15f1dd7`):
- testThresholdBinding
- testThresholdKeyResolution
- testMutualExclusivity
- testDeriveStateFromThreshold
- testThresholdWithValueFcn
- testSerializeThresholdRoundTrip

**Kept**: testDefaultConstruction, testRenderNoError, testRefreshBeforeRender, testToStruct, testFromStruct, testStateColorOk, testStateColorWarn, testStateColorAlarm, testInfoColorInTheme, testInfoColorAllPresets, testStateColorInfo, testStateColorInactive

### tests/suite/TestMultiStatusWidget.m — 9 deleted, 2 kept

**Deleted** (commit `cae8513`):
- testThresholdStructItem
- testThresholdStructColor
- testThresholdStructSerialize
- testMixedSensorAndThresholdItems
- testCompositeExpansion
- testCompositeExpansionMixed
- testCompositeExpansionNestedFlattens
- testCompositeExpansionSummaryColor
- testNonCompositeUnchanged

**Kept**: testDefaultConstruction, testToStruct

(Pitfall 5 guard: `methods (Test)` block still non-empty with 2 survivors; no empty-block syntax error.)

### tests/suite/TestChipBarWidget.m — 3 deleted, 7 kept

**Deleted** (commit `483f85a`):
- testChipThreshold
- testChipThresholdWithValueFcn
- testChipThresholdSerialize

**Kept**: testDefaultConstruction, testRenderThreeChips, testSingleAxes, testRefreshBeforeRender, testToStruct, testFromStruct, testChipColorUpdate

## Totals

| Metric | Value |
|---|---|
| Files modified | 5 |
| Methods deleted | 35 |
| Methods kept | 45 |
| Migrations performed | 0 (deletion-only plan per D-02-A) |
| Commits | 5 (one per file per D-04) |

## Verification

- Grep gate: all 5 files return 0 for `\b(Threshold|CompositeThreshold|ThresholdRule|Sensor|StateChannel|SensorRegistry|ThresholdRegistry|ExternalSensorRegistry)\s*\(`
- Grep gate: all 5 files return 0 for `detectEventsFromSensor`
- Every file retains >=1 surviving test method (Pitfall 5 non-empty guard)
- MISS_HIT `mh_style`: 5 file(s) analysed, everything seems fine — EXIT=0
- MISS_HIT `mh_lint`: 5 file(s) analysed, everything seems fine — EXIT=0
- Octave function-style suite: `75/75 passed, 0 failed` (the classdef suite runs on MATLAB R2020b+ only; Octave skips `matlab.unittest.TestCase` classdefs by design — Plan 01 established this convention)
- Commit graph: 5 commits, all prefixed `fix(1014-02): delete legacy-class methods from ...`, all committed with `--no-verify` per parallel-execution protocol

## Deviations from Plan

None — plan executed exactly as written. All enumerated method lists matched the files on disk; no additional methods surfaced via the defense-in-depth grep rule; no migration was attempted (deletion-only per D-02-A default and D-05 kill-switch).

## Known Stubs

None. All retained methods exercise live v2.0 APIs.

## Deferred Items

None.

## Commits

- `6f318b1` fix(1014-02): delete legacy-class methods from TestStatusWidget
- `b083ade` fix(1014-02): delete legacy-class methods from TestGaugeWidget
- `15f1dd7` fix(1014-02): delete legacy-class methods from TestIconCardWidget
- `cae8513` fix(1014-02): delete legacy-class methods from TestMultiStatusWidget
- `483f85a` fix(1014-02): delete legacy-class methods from TestChipBarWidget

## Self-Check: PASSED

Files created/modified all present on disk; all 5 commit hashes found in `git log`:

- tests/suite/TestStatusWidget.m — FOUND
- tests/suite/TestGaugeWidget.m — FOUND
- tests/suite/TestIconCardWidget.m — FOUND
- tests/suite/TestMultiStatusWidget.m — FOUND
- tests/suite/TestChipBarWidget.m — FOUND
- Commits 6f318b1, b083ade, 15f1dd7, cae8513, 483f85a — all FOUND in git log
