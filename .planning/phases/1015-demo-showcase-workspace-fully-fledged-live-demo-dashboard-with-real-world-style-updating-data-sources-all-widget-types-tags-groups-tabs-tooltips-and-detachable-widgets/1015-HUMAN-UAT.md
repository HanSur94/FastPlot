---
status: partial
phase: 1015-demo-showcase-workspace
source: [1015-VERIFICATION.md]
started: 2026-04-23T18:28:32Z
updated: 2026-04-23T18:28:32Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. UAT Test 1 — Cold Start Smoke (MATLAB re-run with 1015-05 fixes)
expected: `install(); ctx = run_demo();` — Overview page content area shows visible widgets (not blank/black). From/To slider labels show `2026-xx-xx` (not year 5182). No `DashboardEngine:refreshError` warnings over a 30 s live session. All 6 page tabs switch to non-blank content.
result: [pending]

### 2. UAT Tests 2-8 + 10 — unblocked by Test 1
expected: Re-run UAT tests 2-8 and 10 from 1015-UAT.md once Test 1 passes on MATLAB. Code-level blockers are resolved; end-to-end visual confirmation is the remaining gate.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
