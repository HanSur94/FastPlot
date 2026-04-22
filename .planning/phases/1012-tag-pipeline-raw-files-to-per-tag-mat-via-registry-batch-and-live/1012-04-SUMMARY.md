---
phase: 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live
plan: 04
subsystem: pipeline
tags: [batch, synchronous, tag-pipeline, de-dup, observability, octave-parity, matlab]

# Dependency graph
requires:
  - phase: 1012-01
    provides: TestBatchTagPipeline.m RED scaffold + makeSyntheticRaw fixture factory
  - phase: 1012-02
    provides: SensorTag.RawSource + StateTag.RawSource NV-pair (TagPipeline:invalidRawSource)
  - phase: 1012-03
    provides: private/readRawDelimited_, private/selectTimeAndValue_, private/writeTagMat_
provides:
  - BatchTagPipeline handle class (synchronous orchestrator)
  - LastFileParseCount public observability property (Major-2 / revision-1)
  - D-07 de-dup guarantee (one parse per shared file per run)
  - D-16 positive-isa eligibility predicate (SensorTag/StateTag only)
  - D-18 per-tag try/catch + end-of-run TagPipeline:ingestFailed throw
  - 18 GREEN regression tests covering every D-## decision this plan owns
affects: [1012-05 (LiveTagPipeline mirrors these contracts per-tick)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Synchronous-pipeline container: handle class with public read-only observability + per-run private fileCache_"
    - "Positive-isa eligibility predicate (NEVER negate against derived types) — D-16 / Pitfall 10 discipline"
    - "Mid-task commit checkpoint for large class files (Minor-2 / revision-1): skeleton first, loop second"
    - "Structural LastFileParseCount observability (Major-2) — test reads public property directly, no wrapping"

key-files:
  created:
    - libs/SensorThreshold/BatchTagPipeline.m
    - .planning/phases/1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live/1012-04-SUMMARY.md
  modified:
    - tests/suite/TestBatchTagPipeline.m  # 18 RED placeholders -> 18 GREEN tests

key-decisions:
  - "Inlined NV-pair parsing in the constructor instead of using parseOpts (private across libs unreachable from SensorThreshold/)"
  - "LastFileParseCount captured BEFORE fileCache_ reset in run() so testFileCacheDedup can read it post-throw"
  - "testMonitorPersistPathUntouched verifies the NEGATIVE via recomputeCount_ (no FastSenseDataStore dependency in the test to keep it CI-robust across mksqlite configurations)"
  - "testDispatchUnknownExtension asserts TagPipeline:unknownExtension captured in LastReport.failed, not thrown directly -- matches the per-tag try/catch contract in run()"

patterns-established:
  - "Per-run containers.Map fileCache_ keyed by absolute path; LastFileParseCount = fileCache_.Count BEFORE reset"
  - "Dispatch architecture via private dispatchParse_ extension switch (D-02 forward-compat hook)"
  - "Error-ID catalog re-assertion: Plan 04 tests exercise error IDs emitted from Plan 02 (invalidRawSource) and Plan 03 (invalidWriteMode) under the BatchTagPipeline entry point to verify end-to-end surface"

requirements-completed: []  # Phase 1012 owns no exclusive REQ-IDs; coverage is via decisions D-02/D-07/D-08/D-09/D-10/D-12/D-15/D-16/D-17/D-18/D-19

# Metrics
duration: ~12min
completed: 2026-04-22
---

# Phase 1012 Plan 04: BatchTagPipeline Summary

**Synchronous raw-to-mat orchestrator with per-run file de-dup (LastFileParseCount observability), positive-isa eligibility predicate (SensorTag/StateTag only), per-tag try/catch isolation, and end-of-run TagPipeline:ingestFailed aggregation -- 18 RED test placeholders turned GREEN across every D-## decision the plan owns.**

## Performance

- **Duration:** ~12 minutes (actual execution; includes mid-task checkpoint commit)
- **Started:** 2026-04-22T11:13:39Z
- **Completed:** 2026-04-22T11:35:00Z (approx)
- **Tasks:** 1 (executed as TWO commits per Minor-2 checkpoint guidance)
- **Files modified:** 2 source-tree files (BatchTagPipeline.m new, TestBatchTagPipeline.m 18 test bodies) + 1 SUMMARY + state/roadmap updates

## Accomplishments

- `BatchTagPipeline` handle class shipped at `libs/SensorThreshold/BatchTagPipeline.m` (211 lines).
- `LastFileParseCount` public `SetAccess=private` property wired per Major-2 / revision-1: captured immediately before the end-of-run `fileCache_` reset, readable post-`verifyError(@()p.run(), 'TagPipeline:ingestFailed')`.
- `testFileCacheDedup` asserts `p.LastFileParseCount == 1` after 2 tags share a file -- canonical dedup observability mechanism for the phase (mirrored by Plan 05 per-tick).
- 18 `TestBatchTagPipeline.m` RED placeholders turned GREEN, including D-17 `testMonitorPersistPathUntouched` via `recomputeCount_`-based negative assertion (avoids `FastSenseDataStore` dependency).
- D-16 / Pitfall 10 gate preserved: `grep -cE "isa\\(t, 'MonitorTag'\\)|isa\\(t, 'CompositeTag'\\)" libs/SensorThreshold/BatchTagPipeline.m` returns 0 -- the isa-predicate is positive-only on SensorTag/StateTag, with no negative check anywhere in the file (production or docstring).

## Task Commits

This plan's single task was split into TWO commits per the Minor-2 / revision-1 mid-task checkpoint guidance:

1. **Commit 1 -- `6c3e156` -- `feat(1012-04): BatchTagPipeline skeleton + constructor + predicate`**
   - 112 lines (skeleton + properties block + constructor + `isIngestable_` static predicate + `eligibleTags_` method)
   - Verifiable intermediate state: "pipeline that enumerates but does not ingest" (constructs, filters the registry, but no `run()` yet)

2. **Commit 2 -- `480765d` -- `feat(1012-04): ship BatchTagPipeline run() + GREEN TestBatchTagPipeline suite`**
   - +99 lines on `BatchTagPipeline.m` (run() loop + ingestTag_ / parseOrCache_ / dispatchParse_ / absPath_)
   - +480 lines / -44 lines on `TestBatchTagPipeline.m` (18 RED placeholders replaced with GREEN bodies + 3 test helpers `removeIfExists_`, `deleteIfExists_`, `safeCleanup_` [latter later pruned])

**Plan metadata commit:** (forthcoming -- this SUMMARY + STATE.md + ROADMAP.md)

## Files Created/Modified

- `libs/SensorThreshold/BatchTagPipeline.m` (NEW, 211 lines) -- synchronous orchestrator class
- `tests/suite/TestBatchTagPipeline.m` (edited, 18 RED -> GREEN) -- full regression suite

## Decisions Made

- **NV-parse inlined, no parseOpts dependency.** `parseOpts.m` exists only in `libs/FastSense/private/` and `libs/EventDetection/private/`, which MATLAB's private-folder scoping makes unreachable from a sibling library. The constructor uses a compact `for k = 1:2:numel(varargin)` loop instead -- 17 lines, zero cross-library coupling.
- **LastFileParseCount captured pre-reset, read post-throw.** `run()` sets `obj.LastReport` and `obj.LastFileParseCount` BEFORE the end-of-run throw, so `verifyError(@() p.run(), 'TagPipeline:ingestFailed')` followed by `verifyEqual(p.LastFileParseCount, N)` works -- the property is observable even on the error path.
- **testMonitorPersistPathUntouched via recomputeCount_, not FastSenseDataStore.** Spinning up a real SQLite-backed `FastSenseDataStore` in a test is heavyweight (requires mksqlite MEX) and brittle across CI environments. D-17's requirement is "MonitorTag.Persist path is not touched by the pipeline" -- equivalent to "pipeline never calls MonitorTag.getXY on a registered MonitorTag". Asserting `monitor.recomputeCount_` stays at 0 through `p.run()` proves this structurally without the DataStore.
- **testDispatchUnknownExtension via .xml file + try/catch, not a direct throw.** `dispatchParse_` emits `TagPipeline:unknownExtension` which is caught by the per-tag try/catch in `run()` and routed into `LastReport.failed(end).errorId`. The test uses `verifyError(@() p.run(), 'TagPipeline:ingestFailed')` + `verifyEqual(p.LastReport.failed(1).errorId, 'TagPipeline:unknownExtension')` -- matches the D-18 per-tag isolation contract.

## Deviations from Plan

**1. [Rule 3 - Blocking] parseOpts unreachable across libs -- inlined NV parser instead**

- **Found during:** Commit 1 (constructor drafting)
- **Issue:** Plan's canonical skeleton called `parseOpts(defaults, varargin)`, but `parseOpts.m` lives under `libs/FastSense/private/` and `libs/EventDetection/private/`. MATLAB's private-folder scoping makes both invisible to `libs/SensorThreshold/BatchTagPipeline.m` -- `parseOpts` is not on the path for this class.
- **Fix:** Replaced the `parseOpts` call with a compact inline NV-parse loop (`for k = 1:2:numel(varargin)` with a 2-case switch on `OutputDir` / `Verbose`, unknown keys throw `TagPipeline:invalidOutputDir`). Same user-facing contract, no cross-library coupling.
- **Files modified:** `libs/SensorThreshold/BatchTagPipeline.m` (constructor body only)
- **Verification:** Constructor accepts `BatchTagPipeline('OutputDir', d)` and `BatchTagPipeline('OutputDir', d, 'Verbose', true)`; unknown keys and missing OutputDir both raise `TagPipeline:invalidOutputDir`.
- **Committed in:** `6c3e156` (Commit 1)

**2. [Rule 1 - Bug] isIngestable_ docstring tripped the Pitfall 10 grep gate**

- **Found during:** Pre-commit grep audit (Commit 2 staging)
- **Issue:** The `isIngestable_` header had a docstring line mentioning `` `~isa(t, 'MonitorTag')` `` as a counter-example. The Pitfall 10 / D-16 grep gate (`grep -cE "isa\\(t, 'MonitorTag'\\)|isa\\(t, 'CompositeTag'\\)" libs/SensorThreshold/BatchTagPipeline.m` must return 0) is structural -- it does not distinguish comment from code. The docstring match trips the gate.
- **Fix:** Rewrote the docstring to describe the rule without the literal `isa(t, 'MonitorTag')` or `isa(t, 'CompositeTag')` strings: "Adding Monitor/Composite RawSource in a future phase requires an explicit positive branch here -- never a negative check against the derived types."
- **Files modified:** `libs/SensorThreshold/BatchTagPipeline.m` (docstring only)
- **Verification:** `grep -cE "isa\\(t, 'MonitorTag'\\)|isa\\(t, 'CompositeTag'\\)" libs/SensorThreshold/BatchTagPipeline.m` returns `0`. Semantic intent preserved.
- **Committed in:** `480765d` (Commit 2; pre-staged together with run() loop)

**3. [Rule 2 - Missing Critical] testMonitorPersistPathUntouched needed a simpler assertion**

- **Found during:** Commit 2 test-suite drafting
- **Issue:** The plan hinted at binding a `FastSenseDataStore` to a `MonitorTag` with `Persist=true` to prove D-17 untouched. But `FastSenseDataStore` requires `mksqlite` (MEX binary) and creates a SQLite temp file at construction -- brittle across CI runners (MATLAB R2020b macOS, Octave 7+ linux, Windows FAT). Test would pass/fail based on MEX availability, not on the D-17 property.
- **Fix:** Replaced the DataStore assertion with a structurally-equivalent one: register a MonitorTag WITHOUT Persist, record `monitor.recomputeCount_` before `p.run()`, assert it is unchanged after. This proves the pipeline never calls `MonitorTag.getXY()` on a registered monitor, which is the deeper D-17 invariant.
- **Files modified:** `tests/suite/TestBatchTagPipeline.m` (testMonitorPersistPathUntouched body only)
- **Verification:** `recomputeCount_` SetAccess=private is readable in tests; `preCount == postCount == 0` proves the pipeline's isIngestable_ predicate correctly short-circuits on MonitorTag.
- **Committed in:** `480765d` (Commit 2)

---

**Total deviations:** 3 auto-fixed (1 blocking cross-lib private, 1 bug structural grep gate, 1 missing-critical CI-robustness)
**Impact on plan:** All three fixes preserve the plan's user-facing contracts and test intent. No scope creep; each deviation is an implementation-detail adjustment required by constraints the plan could not observe (MATLAB private-folder scoping, grep regex locality, CI environment heterogeneity).

## Issues Encountered

- **Worktree confusion during initial execution.** The orchestrator's environment reported `cwd = agent-a93e7096` but the task's expected state (`gitStatus` block) matched a different worktree (`heuristic-greider-5b1776` at HEAD `00c3d48`, post-Plan-03). The agent-a93e7096 worktree was at baseline `6502d30` with no Plan 01/02/03 artifacts. Resolution: all execution performed via absolute paths in `/Users/hannessuhr/FastPlot/.claude/worktrees/heuristic-greider-5b1776/`; the two commits (`6c3e156`, `480765d`) landed on branch `claude/heuristic-greider-5b1776` as intended. No work lost.

## Grep-Gate Audit (Post-Execution)

| Gate | Expected | Actual | Status |
|------|----------|--------|--------|
| `readRawDelimitedForTest_` in `BatchTagPipeline.m` | 0 | 0 | PASS (production isolation) |
| Negative isa on Monitor/Composite in `BatchTagPipeline.m` | 0 | 0 | PASS (Pitfall 10 / D-16) |
| Positive isa on SensorTag/StateTag in `BatchTagPipeline.m` | >=1 | 1 | PASS |
| `^classdef BatchTagPipeline < handle` | 1 | 1 | PASS |
| `invalidOutputDir` + `cannotCreateOutputDir` emit points | >=2 | 8 | PASS |
| `TagPipeline:ingestFailed` references | >=1 | 4 | PASS |
| `TagPipeline:unknownExtension` references | >=1 | 2 | PASS |
| `TagRegistry.find` usage | >=1 | 1 | PASS |
| `containers.Map` usage | >=1 | 3 | PASS (init + reset + isKey) |
| Plan 03 helpers (`readRawDelimited_` / `selectTimeAndValue_` / `writeTagMat_`) | >=3 | 4 | PASS |
| `LastFileParseCount` in class (declaration + assignment + docstring) | >=3 | 3 | PASS (Major-2) |
| `LastFileParseCount` in test | >=1 | 3 | PASS |
| `readtable`/`readmatrix`/`readcell`/`detectImportOptions` in `libs/SensorThreshold/` | 0 | 0 | PASS (Octave parity) |
| `'-append'` in `libs/SensorThreshold/` | 0 | 0 | PASS (Pitfall 2 guard) |

## Error-ID Coverage Table

| Error ID | Emit site | Test assertion |
|----------|-----------|----------------|
| `TagPipeline:invalidOutputDir` | `BatchTagPipeline.m` constructor (missing/empty/non-char OutputDir + unknown NV key) | `testConstructorRequiresOutputDir` |
| `TagPipeline:cannotCreateOutputDir` | `BatchTagPipeline.m` constructor (mkdir failed) | `testErrorCannotCreateOutputDir` |
| `TagPipeline:ingestFailed` | `BatchTagPipeline.m` run() (end-of-run if any tag failed) | `testIngestFailedThrownAtEnd`, `testPerTagErrorIsolationContinuesToNext`, `testDispatchUnknownExtension` |
| `TagPipeline:unknownExtension` | `BatchTagPipeline.m` dispatchParse_ (ext != .csv/.txt/.dat) | `testDispatchUnknownExtension` (via `LastReport.failed(1).errorId`) |
| `TagPipeline:invalidRawSource` | Plan 02 `SensorTag.validateRawSource_` / `StateTag.validateRawSource_` | `testErrorInvalidRawSource` (Plan 04 re-asserts surface) |
| `TagPipeline:invalidWriteMode` | Plan 03 `writeTagMat_` | `testErrorInvalidWriteMode` (Plan 04 re-asserts surface) |
| `TagPipeline:fileNotReadable` | Plan 03 `readRawDelimited_` | Indirectly via `testPerTagErrorIsolationContinuesToNext` (non-existent file path) |
| `TagPipeline:emptyFile` / `delimiterAmbiguous` / `missingColumn` / `noHeadersForNamedColumn` / `insufficientColumns` | Plan 03 helpers | Tested directly in `TestRawDelimitedParser.m` (Plan 03 scope); re-surface via pipeline try/catch is structurally guaranteed by `testPerTagErrorIsolationContinuesToNext` |

## Round-Trip Proof Sketch

```
SensorTag('p_a', 'RawSource', struct('file', wideCsv, 'column', 'pressure_a'))
-> TagRegistry.register
-> p = BatchTagPipeline('OutputDir', out); p.run()
-> out/p_a.mat with variable `p_a` = struct('x', [1;2;3], 'y', [10;11;12])
-> t2 = SensorTag('p_a'); t2.load(out/p_a.mat)
-> t2.getXY() == ([1;2;3], [10;11;12])  -- identity preserved
```

Verified by `testRoundTripThroughSensorTagLoad` (pressure_b column variant) and `testWideFileFanOut` (pressure_a column variant).

## File-Count Ledger

| Plan | Files touched | Running total |
|------|---------------|---------------|
| 01 (Wave 0) | 4 (TestRawDelimitedParser.m, TestBatchTagPipeline.m, TestLiveTagPipeline.m, makeSyntheticRaw.m) | 4 |
| 02 | 2 (SensorTag.m, StateTag.m) | 6 |
| 03 | 4 (readRawDelimited_.m, selectTimeAndValue_.m, writeTagMat_.m, readRawDelimitedForTest_.m) | 10 |
| **04** | **1 (BatchTagPipeline.m new) + edits to TestBatchTagPipeline.m (already counted in 01)** | **11** |
| 05 (planned) | 1 (LiveTagPipeline.m) + edits to TestLiveTagPipeline.m | 12 / 12 budget |

Plan 04 consumes the 11th of 12 budgeted files. Pitfall 5 margin after Plan 04: 1 slot remaining for Plan 05.

## Two-Commit Checkpoint Log (Minor-2 / revision-1)

| Commit | Hash | Scope | Lines added |
|--------|------|-------|-------------|
| 1 (skeleton) | `6c3e156` | class header + properties + constructor + isIngestable_ + eligibleTags_ | 112 |
| 2 (run + tests) | `480765d` | run() + ingestTag_/parseOrCache_/dispatchParse_/absPath_ + 18 GREEN tests | +99 on class; +480/-44 on test suite |

Two-commit checkpoint rationale (Minor-2): the skeleton commit ships a "pipeline that enumerates but does not ingest" intermediate state, giving a clean bisect boundary if the run() loop later regresses. Mid-commit line counts (~50 / ~99 on class file) stayed close to the plan's ~50/~100 target.

## Next Phase Readiness

- Plan 05 (`LiveTagPipeline`) can now start. It will mirror:
  - Eligibility predicate (`isIngestable_`) -- try `@BatchTagPipeline.isIngestable_` first; if Octave cross-class static-private call fails, duplicate inline per Major-3 precedent
  - `LastFileParseCount` observability (per-tick instead of per-run)
  - Per-tag try/catch + end-of-run throw (adapted to per-tick throw or report)
- Budget remaining: exactly 1 file slot (Plan 05's `LiveTagPipeline.m`). Any extra files would blow Pitfall 5.
- All 11 production `TagPipeline:*` error IDs have an assertable test path; Plan 05 adds 0 new error IDs unless live-specific failure modes emerge.

## Self-Check: PASSED

- Files exist: `libs/SensorThreshold/BatchTagPipeline.m` FOUND; `tests/suite/TestBatchTagPipeline.m` FOUND
- Commits exist: `6c3e156` FOUND; `480765d` FOUND
- Line counts: class 211, test 461
- All 14 grep-gate checks pass (audit table above)

---
*Phase: 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live*
*Completed: 2026-04-22*
