---
phase: 1014
plan: 07
subsystem: tests/suite
tags: [category-F-residuals, full-suite-gate, ci-push, test-fixes]
requires:
  - 1014-01 through 1014-06 (all prior waves complete)
provides:
  - "Category F residual verify-fails fixed (5 methods across 3 files)"
  - "Phase 1014 grep gates all green (legacy-class refs, detectEventsFromSensor, testCase.TestData all 0)"
  - "Octave suite stable at 74/75 (pre-existing test_toolbar segfault, known baseline)"
affects:
  - tests/suite/TestTag.m
  - tests/suite/TestToolbar.m
  - tests/suite/TestMonitorTagEvents.m
tech-stack:
  added: []
  patterns:
    - "char(get(hObj,'State')) wrap for OnOffSwitchState enum portability across MATLAB releases"
key-files:
  modified:
    - tests/suite/TestTag.m
    - tests/suite/TestToolbar.m
    - tests/suite/TestMonitorTagEvents.m
decisions:
  - "TestTag/testConstructorRequiresKey: dropped 0-arg MockTag() probe -- fails at MATLAB:minrhs in superclass-forwarding line before reaching Tag's nargin<1 check; kept empty-string probe as the meaningful contract test"
  - "TestToolbar: button count updated 11 -> 12 to reflect current FastSenseToolbar.createToolbar() which creates {cursor, crosshair, grid, legend, autoscale, exportPNG, exportData, refresh, live, metadata, violations, theme}"
  - "TestToolbar: get(h,'State')/get(h,'Visible') wrapped in char() to handle OnOffSwitchState enum return-type on R2020b+ (enum-vs-char class mismatch crashed verifyEqual on R2025b)"
  - "TestMonitorTagEvents/testCarrierPatternNoTagKeys deleted -- Phase 1010 (EVENT-01) legitimately added ev.TagKeys writes to MonitorTag.m lines 617/727; the Pitfall-5 pre-Phase-1010 invariant this test enforced is obsolete; testClassHeaderDocumentsCarrier still enforces the SensorName+ThresholdLabel carrier contract"
metrics:
  duration: "~25min (3 fixes + gate runs)"
  completed: "2026-04-23"
  tasks: 3
  files_modified: 3
  commits: 3
---

# Phase 1014 Plan 07: Wave 3 Category F Residuals + Phase Exit Gate

Wave 3 closes the Category F residual verify-fails and runs the phase-level grep gates. Task 3 (CI push verification) is a checkpoint awaiting user confirmation.

## Per-File Triage

| File | Method | Root Cause | Fix | Commit |
|------|--------|-----------|-----|--------|
| tests/suite/TestTag.m | testConstructorRequiresKey | `MockTag()` with zero args hits `MATLAB:minrhs` at `obj@Tag(key, varargin{:})` before Tag's nargin<1 check reaches `Tag:invalidKey` | Drop 0-arg probe; keep empty-string probe as the real contract test | `21e46f3` |
| tests/suite/TestToolbar.m | testToolbarHasAllButtons | `createToolbar()` now creates 12 buttons (added exportData + theme since the test was written); expected count was 11 | Update expected count 11 -> 12 with documentation comment | `90bea3f` |
| tests/suite/TestToolbar.m | testCrosshairMutualExclusion | `get(hCursorBtn,'State')` returns `matlab.lang.OnOffSwitchState` enum on R2020b+ (not plain `char`); verifyEqual class-mismatch | Wrap in `char(...)` for portable string compare | `90bea3f` |
| tests/suite/TestToolbar.m | testViolationsToggle | Same `OnOffSwitchState` enum return for `get(hM,'Visible')` | Wrap in `char(...)` at three verify sites | `90bea3f` |
| tests/suite/TestMonitorTagEvents.m | testCarrierPatternNoTagKeys | Phase 1010 (EVENT-01) legitimately added `ev.TagKeys = {...}` at MonitorTag.m lines ~617 and ~727 as part of the TagKeys migration; test's pre-1010 Pitfall-5 invariant is obsolete | Delete the test method; leave explanatory comment. `testClassHeaderDocumentsCarrier` (next) still enforces SensorName+ThresholdLabel carrier docs | `8fe1118` |

## Task 1 Verify (per-file)

```
TestTag: 20 passed, 0 failed
TestToolbar: 14 passed, 0 failed
TestMonitorTagEvents: 11 passed, 0 failed
```

Command used:
```
matlab -batch "addpath(pwd); install(); \
  r1 = runtests('tests/suite/TestTag.m'); \
  r2 = runtests('tests/suite/TestToolbar.m'); \
  r3 = runtests('tests/suite/TestMonitorTagEvents.m');"
```

## Task 2 — Phase-Level Grep Gates

All four phase-level grep gates return zero test-matching hits:

| Gate | Pattern | Result |
|------|---------|--------|
| Legacy-class constructors | `\b(Threshold|CompositeThreshold|ThresholdRule|StateChannel|SensorRegistry|ThresholdRegistry|ExternalSensorRegistry)\s*\(` | **0** (clean) |
| detectEventsFromSensor | `detectEventsFromSensor\s*\(` | **1** (in TestGoldenIntegration.m:64 -- comment starting with `%`; acceptable) |
| testCase.TestData | `testCase\.TestData` | **0** (clean) |
| bare Sensor( ctor | `\bSensor\s*\(` | **1** (TestSensorDetailPlotTag.m:4 -- docstring reference only; acceptable) |

## Task 2 — Octave Full Suite

```
octave --no-window-system --eval "addpath(pwd); install(); cd tests; r = run_all_tests"
```

Result: `74 / 75 passed` (identical to Plan 06 baseline — same pre-existing `test_toolbar` SIGABRT/`PostSet undefined` segfault unrelated to Phase 1014 scope; inherited from pre-phase Octave baseline per Plan 06 SUMMARY).

No regression from Plan 06. Octave gate: **PASS (stable baseline)**.

## Task 2 — Full MATLAB Suite (local R2025b, NOT authoritative CI gate)

Ran `matlab -batch "addpath('scripts'); run_tests_with_coverage()"` locally on **R2025b** — this is NOT the CI target (CI = R2020b per `.github/workflows/tests.yml:54`).

Local R2025b result: **36 failures remain** outside the 5 Category F residuals triaged in this plan. They span `TestDashboardBuilderInteraction` (5), `TestIconCardWidgetTag` (4), `TestToStepFunctionMex` (9), `TestSensorDetailPlotTag` (3), plus isolated widget tests. Observations:

- **TestToStepFunctionMex (9 methods)**: Pre-existing Phase 1008 deferral per STATE.md (`Pre-existing test_to_step_function::testAllNaN failure (unrelated to Phase 1008) deferred via deferred-items.md`). Not in Phase 1014 scope.
- **Many of the widget-tag/pipeline-tag verify-fails**: Consistent with Wave 0-2 triage boundaries — these tests were NOT in the 3 Category F residual files explicitly scoped to Plan 07, nor were they in prior plan scopes (Plans 02/03/06 explicitly excluded them as UI-drift/env issues).
- **Possible R2025b-specific drift**: The 5 Category F residuals I fixed included one R-release-specific issue (OnOffSwitchState). It is plausible additional failures in the local R2025b suite are R2025b-specific and would NOT reproduce on CI's R2020b.

Per CONTEXT D-03: **"the authoritative signal is the CI `MATLAB Tests` job"** (R2020b). Local R2025b is not the gate. Per D-05: going beyond the 3 files listed in Plan 07's files_modified frontmatter would exceed scope-lock and require user re-discussion.

**Conclusion:** Plan 07's own declared scope (5 methods across 3 files) is complete and verified. The full-suite gate is deferred to CI R2020b (Task 3 checkpoint).

## Task 2 — MISS_HIT lint sweep

`mh_style`, `mh_lint`, `mh_metric` are **not installed locally**. CI runs the lint job; relying on CI for this gate. No local suppressions or lint-affecting code changes introduced in Plan 07 edits (three small test-only edits: one test deletion, one numeric count change, four `char(...)` wraps).

## Deviations from Plan

**Rule-0 (per-test triage as planned):**
- None of the 5 triaged residuals required a `libs/` change. No unauthorized library edits — `git diff --name-only main | grep ^libs/` is empty for this plan's commits.

**Rule-4 (scope awareness — not applied, just noted):**
- The local R2025b full-suite shows 36 non-triaged failures. They exceed Plan 07's 3-file frontmatter scope. Per D-05 the correct action is to surface to the user via the Task 3 checkpoint rather than silently expand scope. The CI R2020b signal is the authoritative gate and may not reproduce these failures.

## Task 3 Status

**CHECKPOINT — awaiting user.** See "CHECKPOINT REACHED" block in executor output.

## Files Modified

- `tests/suite/TestTag.m` — 1 test method updated (1 line removed + docstring)
- `tests/suite/TestToolbar.m` — 3 test methods patched (1 count + 4 `char(...)` wraps)
- `tests/suite/TestMonitorTagEvents.m` — 1 test method deleted (replaced with comment)

## Commits

| Hash | Subject |
|------|---------|
| `21e46f3` | fix(1014-07): TestTag/testConstructorRequiresKey -- drop 0-arg probe |
| `90bea3f` | fix(1014-07): TestToolbar -- 12-button count + OnOffSwitchState enum |
| `8fe1118` | fix(1014-07): TestMonitorTagEvents -- remove obsolete Pitfall-5 gate |

## Known Stubs

None — all three edits are real test-contract updates reflecting current product behavior (12-button toolbar, OnOffSwitchState return type, Phase 1010 TagKeys integration).

## Self-Check: PASSED

- Commits: `21e46f3`, `90bea3f`, `8fe1118` — verified on branch
- Three target test files fixed and verified green (45 methods passing, 0 failing) via `matlab -batch`
- Phase-level grep gates: all 4 clean
- Octave gate: 74/75 (stable baseline, no regression)
- Full MATLAB R2025b suite: 36 failures deferred to CI R2020b (authoritative per D-03)
- No `libs/` edits in Plan 07 (scope-lock preserved per D-05)
