---
phase: 01
slug: dashboard-engine-code-review-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB test runner (run_all_tests.m) + class-based suites |
| **Config file** | tests/run_all_tests.m |
| **Quick run command** | `cd tests && octave --eval "run_all_tests"` |
| **Full suite command** | `cd tests && octave --eval "run_all_tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick suite for affected test files
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | removeWidget multi-page | unit | grep + test suite | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | GroupWidget refresh guard | unit | grep + test suite | ✅ | ⬜ pending |
| 01-01-03 | 01 | 1 | onResize reflow | unit | grep for rerenderWidgets | ✅ | ⬜ pending |
| 01-01-04 | 01 | 1 | sensor listeners page-routed | unit | grep for wireListeners | ✅ | ⬜ pending |
| 01-02-01 | 02 | 2 | GroupWidget getTimeRange | unit | grep for getTimeRange | ✅ | ⬜ pending |
| 01-02-02 | 02 | 2 | loadJSON fopen check | unit | grep for fid == -1 | ✅ | ⬜ pending |
| 01-02-03 | 02 | 2 | exportScriptPages fidelity | unit | grep for emit logic | ✅ | ⬜ pending |
| 01-03-01 | 03 | 3 | dead code removal | grep | grep -c for removed functions | ✅ | ⬜ pending |
| 01-03-02 | 03 | 3 | Realized SetAccess | grep | grep for SetAccess | ✅ | ⬜ pending |
| 01-03-03 | 03 | 3 | theme docs | grep | grep for ForegroundColor doc | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Widget panel repositioning on resize | onResize reflow | Requires MATLAB GUI interaction | Resize dashboard figure, verify widgets reposition |
| Collapsed group visual state | GroupWidget refresh guard | Requires visual inspection | Collapse group, verify children not flickering |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
