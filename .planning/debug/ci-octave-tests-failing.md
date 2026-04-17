---
status: awaiting_human_verify
trigger: "Tests workflow is failing on main after PR #56 merge due to 2 Octave test failures, blocking downstream workflows"
created: 2026-04-17T12:00:00Z
updated: 2026-04-17T12:00:00Z
---

## Current Focus

hypothesis: Two independent root causes — both fixed and verified locally.
test: Local Octave 11.1.0 run_all_tests() post-fix: "=== Results: 75/75 passed, 0 failed ===".
expecting: CI Tests workflow + Release v2.0 gate-tests job now green.
next_action: Await human confirmation after pushing to verify CI is green on main / PR.

## Symptoms

expected: Tests workflow passes on main and v2.0 so downstream workflows (Generate Wiki Pages, Release) can run successfully
actual: Two Octave tests fail in the Tests workflow, causing Tests to exit 1. Example Smoke Tests also fails in parallel. Release workflow on v2.0 branch also fails.
errors: |
  1. test_monitortag_persistence — "error: Scenario 3: persisted X must have 10 points" (in run_scenario_persist_true_writes_ at line 71, called from test_monitortag_persistence at line 20)
  2. test_to_step_function — "error: 'toStepFunction' undefined near line 11, column 22" (called from test_to_step_function at line 11)
  Tests job output: "=== Results: 74/76 passed, 2 failed ==="
  Tests workflow exit code: 1
  Also failing: Example Smoke Tests (run 24563614748) and Release on v2.0 (run 24565048457)
reproduction: |
  - Tests on main: gh run view 24563614716
  - Tests on PR: run 24563613361
  - Example Smoke Tests on main: run 24563614748
  - Release on v2.0: run 24565048457
  Local: docker run --rm -v "$PWD:/w" -w /w gnuoctave/octave:11.1.0 octave --eval "cd('tests'); r = run_all_tests();"
started: After PR #56 merge at 2026-04-17T11:51 (commit 2a127f8)

## Eliminated

## Evidence

- timestamp: 2026-04-17T12:05:00Z
  checked: git log for toStepFunction file history
  found: Commit 4188a7f (chore(1011-01)) deleted libs/SensorThreshold/private/toStepFunction.m along with entire private/ dir (10 .m + 4 .mex files), and 8 legacy classes + 3 standalone functions.
  implication: test_to_step_function.m was NOT updated to remove references to the deleted function. The test is orphaned — testing a function that was intentionally deleted.

- timestamp: 2026-04-17T12:06:00Z
  checked: CI run 24563614716 full log (Tests workflow)
  found: Also "MATLAB Lint" step fails (exit 1) BEFORE Octave Tests runs. Linter errors include: line 345, 596, 597, 607, 687 in MonitorTag.m — "continuations should not start with binary operators". Additional test file style issues (spurious_row_semicolon, line_length, naming_classes, redundant_brackets).
  implication: Not just 2 test failures — MATLAB Lint job also fails, adding to total failures.

- timestamp: 2026-04-17T12:07:00Z
  checked: libs/SensorThreshold/ directory (current state)
  found: Contains only: CompositeTag.m, MonitorTag.m, SensorTag.m, StateTag.m, Tag.m, TagRegistry.m. No private/ directory. No Sensor.m, no ThresholdRule.m, no toStepFunction anywhere.
  implication: The architecture moved to a Tag-based system. `toStepFunction` was deleted because it was only used by the deleted legacy Sensor/Threshold system.

- timestamp: 2026-04-17T12:15:00Z
  checked: Reproduced both failures locally using Octave 11.1.0. `mksqlite` is NOT available in Octave CI (test_mksqlite_edge_cases "SKIPPED" in all runs since 2026-04-05). test_monitortag_persistence was added 2026-04-16T20:43 (commit 1525a56), AFTER the last successful CI run. test_to_step_function passed in run 24527534029 (2026-04-16T18:42) because the toStepFunction function still existed then; it was deleted in commit 4188a7f at 2026-04-17T11:11 as part of the Phase 1011-01 cleanup.
  implication: Both tests are NEW failures on main. Fixes: (a) delete test_to_step_function.m since the function is gone; (b) add mksqlite availability skip to test_monitortag_persistence.m for scenarios 3-6 (which need actual SQLite writes).

- timestamp: 2026-04-17T12:18:00Z
  checked: Example Smoke Tests (run 24563614748) and Release v2.0 (run 24565048457).
  found: Example Smoke Tests failures are unrelated migration issues (`ResolvedViolations`, `Thresholds`, SensorTag.X/.Y setters on Dependent properties, missing `quantile` function). Release v2.0 fails with the EXACT same 2 Octave test failures as main (test_to_step_function + test_monitortag_persistence).
  implication: Release v2.0 will be fixed by the same fix. Example Smoke Tests are a SEPARATE bug not in scope of this issue.

## Resolution

root_cause: |
  Two independent issues, both introduced by Phase 1011 (legacy cleanup) + Phase 1007-02 (MonitorTag persistence):
  1. Commit 4188a7f ("chore(1011-01): delete 8 legacy classes, 3 standalone functions, 13 private helpers") deleted libs/SensorThreshold/private/toStepFunction.m (along with the entire private/ dir), but did not update tests/test_to_step_function.m which still called the now-missing function.
  2. Commit 1525a56 ("test(1007-02): add RED tests for MonitorTag Persist...") added tests/test_monitortag_persistence.m. Scenarios 3-6 call FastSenseDataStore.storeMonitor/loadMonitor/clearMonitor, which internally require UseSqlite=true (mksqlite MEX available). Octave CI runs with FASTSENSE_SKIP_BUILD=1 and downloads a mex-linux artifact that does NOT include a loadable Octave mksqlite — so UseSqlite=false, storeMonitor returns early (no-op), and Scenario 3's assertion `numel(X) == 10` fails because loadMonitor returns empty.
fix: |
  1. Deleted tests/test_to_step_function.m. The legacy wrapper toStepFunction is gone; its MEX counterpart (to_step_function_mex) is still tested by tests/suite/TestToStepFunctionMex.m which uses the MEX directly and has an `assumeTrue` skip when the MEX is not compiled.
  2. Restructured tests/test_monitortag_persistence.m to split scenarios into two groups:
     - Always-run: Scenario 1 (default Persist=false), Scenario 2 (Persist=false no writes), grep gates, Pitfall 2 structural check. These don't require SQLite writes.
     - mksqlite-gated: Scenarios 3-6 (actual monitors-table round-trip). Wrapped with `if exist('mksqlite', 'file') == 3` so Octave CI reports "SKIPPED scenarios 3-6: mksqlite MEX not available" instead of failing. MATLAB runs (via install() building mksqlite) still exercise the full 6-scenario set through suite/TestMonitorTagPersistence.m.
verification: |
  Local: Ran tests/run_all_tests.m via Octave 11.1.0 with FASTSENSE_SKIP_BUILD=1 after deleting the stale /var/folders/.../sensor_threshold_private_proxy cache. Result: "=== Results: 75/75 passed, 0 failed ===" (previously 74/76 passed, 2 failed). test_monitortag_persistence reports "2 persistence tests + gates passed" + "SKIPPED scenarios 3-6: mksqlite MEX not available".
  Pre-fix reproduction: "FAIL: 'toStepFunction' undefined near line 11, column 22" and "FAIL: Scenario 3: persisted X must have 10 points".
files_changed:
  - tests/test_to_step_function.m (DELETED)
  - tests/test_monitortag_persistence.m (MODIFIED: mksqlite-gated scenarios 3-6)
