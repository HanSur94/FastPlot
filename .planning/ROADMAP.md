# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000-1003 (shipped 2026-04-15)
- ✅ **v2.0 Tag-Based Domain Model** — Phases 1004-1011 (shipped 2026-04-17)
- 📋 **v2.1 Tag-API Tech Debt Cleanup** — Phases 1012-1017 (carry-forward, parallel — not active)
- ✅ **v3.0 FastSense Companion** — Phases 1018-1023 + 1023.1 gap closure (shipped 2026-04-30)
- 🚧 **Pending milestone** — Phases 1025-1028 (promoted from backlog 2026-05-08, awaiting milestone scoping; 1024 closed via quick task 260508-d7k; 1025/1026 substantially addressed via quick tasks 260508-d8y/260508-das)
- 🚧 **v4.0 Multi-User LAN Concurrency** — Phases 1029-1033 (active, started 2026-05-13)

## Phases

<details open>
<summary>🚧 v4.0 Multi-User LAN Concurrency (Phases 1029-1033) — ACTIVE 2026-05-13</summary>

- [ ] **Phase 1029: Concurrency Foundation** — Identity + Paths + FileLock primitive + AtomicWriter, with OFD locks, mtime heartbeat, atomic temp+rename
- [ ] **Phase 1030: TagWriteCoordinator + LiveTagPipeline cluster mode** — per-tag lock around raw→.mat write; timer hardening; jitter; mtime change-detect
- [ ] **Phase 1031: EventLog (Append-Only NDJSON) + EventStore SQLite rollback-mode migration** — lock-serialised appends; reader resilience; SMB-atomicity stress test
- [ ] **Phase 1032: Single-Source MonitorTag Event Emission + ack workflow** — exactly-once event generation via per-tag lock; ack/comment/visual-state; deferred listener notify; SQLite retry wrapper
- [ ] **Phase 1033: Companion Integration + Snapshot Consolidator + Operator Docs + 50-Companion Acceptance Test** — wire SharedRoot through Companion; leader-elected snapshot; ops setup README; full acceptance gate

</details>

<details>
<summary>🚧 Pending milestone (Phases 1025-1028) — promoted from backlog 2026-05-08</summary>

- [x] Phase 1024: Fix companion app dark mode — closed via quick task [260508-d7k](./quick/260508-d7k-fix-companion-app-dark-mode-switching-th/) (2026-05-08)
- [ ] Phase 1025: FastSense hover crosshair + datatip (largely addressed via quick task 260508-d8y)
- [ ] Phase 1026: Dashboard time slider preview (addressed via quick task 260508-das)
- [x] Phase 1027: Companion detachable log window — completed 2026-05-08
- [ ] Phase 1027.1: Independent events/live log detach (gap closure)
- [ ] Phase 1028: Tag update perf — MEX + SIMD

</details>

<details>
<summary>✅ v1.0 FastSense Advanced Dashboard (Phases 1-9) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Infrastructure Hardening (4/4 plans) — completed 2026-04-01
- [x] Phase 2: Collapsible Sections (2/2 plans) — completed 2026-04-01
- [x] Phase 3: Widget Info Tooltips (3/3 plans) — completed 2026-04-01
- [x] Phase 4: Multi-Page Navigation (3/3 plans) — completed 2026-04-01
- [x] Phase 5: Detachable Widgets (3/3 plans) — completed 2026-04-02
- [x] Phase 6: Serialization & Persistence (2/2 plans) — completed 2026-04-02
- [x] Phase 7: Tech Debt Cleanup (1/1 plan) — completed 2026-04-03
- [x] Phase 8: Widget Improvements (3/3 plans) — completed 2026-04-03
- [x] Phase 9: Threshold Mini-Labels (2/2 plans) — completed 2026-04-03

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v2.0 Tag-Based Domain Model (Phases 1004-1011) — SHIPPED 2026-04-17</summary>

- [x] Phase 1004: Tag Foundation + Golden Test
- [x] Phase 1005: SensorTag + StateTag (data carriers)
- [x] Phase 1006: MonitorTag (lazy, in-memory)
- [x] Phase 1007: MonitorTag streaming + persistence
- [x] Phase 1008: CompositeTag
- [x] Phase 1009: Consumer migration (one widget at a time)
- [x] Phase 1010: Event ↔ Tag binding + FastSense overlay
- [x] Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)

</details>

<details>
<summary>🚧 v2.1 Tag-API Tech Debt Cleanup (Phases 1012-1017) — in flight</summary>

- [x] Phase 1012: Migrate examples to Tag API
- [x] Phase 1013: Dead code deletion — EventDetector, IncrementalEventDetector, EventConfig
- [x] Phase 1014: DashboardSerializer .m export for Tag-bound widgets
- 🚧 Phase 1017: Tag system event auto-wiring — registry default EventStore, dual-key emission

</details>

<details>
<summary>✅ v3.0 FastSense Companion (Phases 1018-1023 + 1023.1) — SHIPPED 2026-04-30</summary>

- [x] Phase 1018: Companion Shell + Project Handoff (3/3 plans) — completed 2026-04-29
- [x] Phase 1019: Tag Catalog (3/3 plans) — completed 2026-04-29
- [x] Phase 1020: Dashboard Browser (3/3 plans) — completed 2026-04-29
- [x] Phase 1021: Inspector (4/4 plans) — completed 2026-04-30
- [x] Phase 1022: Ad-Hoc Plot Composer (3/3 plans) — completed 2026-04-30
- [x] Phase 1023: Industrial Plant Demo Integration (2/2 plans) — completed 2026-04-30
- [x] Phase 1023.1: Cross-Phase Wiring Fixes (gap closure) — completed 2026-04-30

Full details: [milestones/v3.0-ROADMAP.md](milestones/v3.0-ROADMAP.md)

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 Advanced Dashboard | 24/24 | Complete | 2026-04-03 |
| 01. Code Review Fixes | v1.0 Code Review | 4/4 | Complete | 2026-04-03 |
| 01. Performance Optimization | v1.0 Performance | 3/3 | Complete | 2026-04-04 |
| 1000-1003 | v1.0 First-Class Thresholds | 14/14 | Complete | 2026-04-15 |
| 1004. Tag Foundation + Golden Test | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1005. SensorTag + StateTag | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1006. MonitorTag (lazy, in-memory) | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1007. MonitorTag streaming + persistence | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1008. CompositeTag | v2.0 | 3/3 | Complete | 2026-04-16 |
| 1009. Consumer migration | v2.0 | 4/4 | Complete | 2026-04-17 |
| 1010. Event ↔ Tag binding + overlay | v2.0 | 3/3 | Complete | 2026-04-17 |
| 1011. Cleanup + delete legacy | v2.0 | 5/5 | Complete | 2026-04-17 |
| 1012. Migrate examples to Tag API | v2.1 | 10/10 | Complete | — |
| 1013. Dead code deletion | v2.1 | — | Complete | — |
| 1014. DashboardSerializer .m export | v2.1 | 1/1 | Complete | — |
| 1017. Tag system event auto-wiring | v2.1 | 0/? | In progress | — |
| 1018. Companion Shell + Project Handoff | v3.0 | 3/3 | Complete    | 2026-04-29 |
| 1019. Tag Catalog | v3.0 | 3/3 | Complete    | 2026-04-29 |
| 1020. Dashboard Browser | v3.0 | 3/3 | Complete   | 2026-04-29 |
| 1021. Inspector | v3.0 | 4/4 | Complete   | 2026-04-30 |
| 1022. Ad-Hoc Plot Composer | v3.0 | 3/3 | Complete   | 2026-04-30 |
| 1023. Industrial Plant Demo Integration | v3.0 | 2/2 | Complete | 2026-04-30 |
| 1023.1. Cross-Phase Wiring Fixes | v3.0 | gap-closure | Complete | 2026-04-30 |
| 1024. Fix companion app dark mode | pending | quick-task | Complete (via 260508-d7k) | 2026-05-08 |
| 1025. FastSense hover crosshair + datatip | pending | 0/? | Not started | — |
| 1026. Dashboard time slider preview | pending | 0/? | Not started | — |
| 1027. Companion detachable log window | pending | 5/5 | Complete    | 2026-05-08 |
| 1027.1. Independent events/live log detach | pending | 8/8 | Complete    | 2026-05-08 |
| 1028. Tag update perf — MEX + SIMD | pending | 0/? | Not started | — |
| 1029. Concurrency Foundation | v4.0 | 5/5 | Complete    | 2026-05-14 |
| 1030. TagWriteCoordinator + LiveTagPipeline cluster mode | v4.0 | 2/2 | Complete    | 2026-05-14 |
| 1031. EventLog + EventStore rollback-mode migration | v4.0 | 4/4 | Complete    | 2026-05-14 |
| 1032. Single-Source MonitorTag Events + ack workflow | v4.0 | 5/5 | Complete    | 2026-05-14 |
| 1033. Companion Integration + Acceptance Test | v4.0 | 4/4 | Complete   | 2026-05-14 |

## Phase Details (v4.0 Multi-User LAN Concurrency)

### Phase 1029: Concurrency Foundation (Identity + Paths + FileLock + AtomicWriter)

**Goal:** Lay down the four cross-cutting primitives every subsequent phase depends on — process identity, cluster-mode resolution, cross-host advisory locks (OFD on Linux, LockFileEx on Win32), and atomic temp+rename writes — with the three PITFALLS.md design corrections (OFD locks, mtime heartbeat, lock-serialised semantics) baked in from the start.

**Depends on:** Nothing (foundation; sits next to existing libraries as new `libs/Concurrency/`).

**Requirements covered:**
- CONC-02 (stale-lock recovery via mtime heartbeat, ≥90s staleTimeout, kill-9 takeover within `staleTimeout + 5s`)
- CONC-03 (atomic temp+rename for all shared writes; CI lint forbids raw `save()` to shared paths)
- IDENT-01 (`userIdentity.m` resolves user@host (pid, epoch); cluster mode fails loudly on identity failure — no silent `'unknown'`)

**Success Criteria** (what must be TRUE):
1. **50 concurrent MATLAB processes** can acquire and release the same per-key lockfile on the target SMB share without deadlock, corruption, or split-brain (`TestFileLock` 50-process stress harness).
2. **Closing a second FD on a held lockfile does NOT release the lock** — proven by `TestFileLock.testCloseDoesNotReleaseLock` on Linux (OFD lock contract) and Windows (LockFileEx process-scope contract).
3. **Stale-lock takeover** after `kill -9` of the holder completes within `staleTimeout + 5s` (default 90s timeout) using server-side filesystem **mtime** (not wall-clock TTL), verified by `TestFileLock.testStaleLockAfterProcessKill` and `TestFileLock.testNegativeWallClockDeltaIgnored`.
4. **Every shared write goes through `AtomicWriter`** — concurrent reader during temp+rename never observes zero-byte or torn content (with the reader-side 3-retry/50ms-backoff helper); CI grep guard rejects any `save(<sharedRoot>...)` calls outside `AtomicWriter`.
5. **`userIdentity.m` returns a complete (user, host, pid) tuple** on MATLAB R2020b+ and Octave 7+ (including `--disable-java` Octave builds); in cluster mode, an unresolvable user or host throws `Concurrency:identityResolutionFailed` instead of returning `'unknown'`.

**Plans:** 5/5 plans complete

- [x] 1029-01-identity-paths-PLAN.md — userIdentity + ClusterIdentity + ClusterConfig + SharedPaths (IDENT-01)
- [x] 1029-02-lockfile-mex-PLAN.md — lockfile_mex.c cross-platform MEX + build_concurrency_mex.m (CONC-02 kernel)
- [x] 1029-03-filelock-PLAN.md — FileLock.m with mtime-heartbeat + re-entrance guard + sidecar fallback (CONC-02)
- [x] 1029-04-atomic-writer-PLAN.md — AtomicWriter.m + ndjsonEncode + CI grep guard (CONC-03)
- [x] 1029-05-wiring-and-probes-PLAN.md — install.m wiring + mksqlite probe + composition smoke (CONC-02 + CONC-03 + IDENT-01)

### Phase 1030: TagWriteCoordinator + LiveTagPipeline Cluster Mode

**Goal:** Wire the Phase 1029 `FileLock` primitive into the existing `LiveTagPipeline.processTag_` raw→.mat write path via a new `TagWriteCoordinator` facade — enabling two or more Companions to write the same per-tag `.mat` file on a shared share without corruption. This is the simplest non-trivial consumer of `FileLock`, hardening the single-writer-per-tag contract before EventLog ships.

**Depends on:** Phase 1029 (uses `FileLock`, `AtomicWriter`, `SharedPaths`, `ClusterIdentity`).

**Requirements covered:**
- CONC-01 (2+ Companions can write the same per-tag `.mat` via the shared share without corruption, verified by parallel-write integration test on real SMB share)

**Success Criteria** (what must be TRUE):
1. **Two-process write race** on the same `<tag.Key>.mat` produces a valid merged file with rows from both writers — no torn data, no last-writer-wins data loss (`TestLiveTagPipelineCluster.testTwoProcessWriteRace`).
2. **50-process thundering-herd scenario** (all Companions started within 1s, default `Interval=15s`) keeps per-tick latency p99 bounded under 5s and per-Companion SMB request rate bounded — verified via jittered scheduling (`Interval × (1 + 0.5*(rand-0.5))`) and mtime change-detect skipping unchanged tags.
3. **Slow share (5s mock I/O) at `Period=2s`** does NOT cause MATLAB session OOM or unbounded timer-callback queue — `BusyMode='drop'` is forced in cluster mode and `pipeline.SkippedTickCount` exposes the skip count for ops monitoring.
4. **Lock contention on a tag** causes `processTag_` to skip-and-defer that tag to the next tick (NOT block the whole tick); a structured `LockContentionEvent` carries `{holder.user, holder.host, holder.age}` for downstream UI surfacing.
5. **Single-user mode is byte-identical** — running `LiveTagPipeline` without `'SharedRoot'` NV-pair exercises zero Concurrency-library code paths (existing `tests/test_live_tag_pipeline.m` and `tests/suite/TestLiveTagPipeline.m` pass unchanged).

**Plans:** 2/2 plans complete

- [x] 1030-01-tag-write-coordinator-PLAN.md — TagWriteCoordinator facade over FileLock with per-tag-key scope (Wave 1, no deps) (CONC-01 primitive)
- [x] 1030-02-live-tag-pipeline-cluster-mode-PLAN.md — Wire TagWriteCoordinator + AtomicWriter into LiveTagPipeline.processTag_; BusyMode="drop"; jittered scheduling; mtime change-detect; stillHeldByMe gate; LockContentionEvent emission (Wave 2, depends on 1030-01) (CONC-01 full)

### Phase 1031: EventLog (Append-Only NDJSON) + EventStore SQLite Rollback-Mode Migration

**Goal:** Introduce the new per-tag append-only NDJSON event-log format — built in isolation so the SMB-atomicity reality of the target file server is validated empirically before MonitorTag and EventStore depend on it. Also migrate shared `EventStore` SQLite usage from WAL to rollback mode (`journal_mode=DELETE` + `busy_timeout=10000` + `BEGIN IMMEDIATE`), the only documented-safe mode over network filesystems.

**Depends on:** Phase 1029 (uses `FileLock`, `AtomicWriter`, `ClusterIdentity`), Phase 1030 (uses `TagWriteCoordinator` for the lock-serialised append contract).

**Requirements covered:**
- EVTLOG-01 (NDJSON appends serialised through per-tag `FileLock` — NOT `O_APPEND` atomicity, which is unreliable on SMB/NFS — and shared SQLite EventStore migrates to `journal_mode=DELETE` + `busy_timeout=10000` + `BEGIN IMMEDIATE` + app-level retry)
- EVTLOG-02 (50-process append stress test produces exactly the expected number of valid JSON lines; `EventLogReader` skips and counts any corrupt lines defensively)
- EVTLOG-03 (read-path resilience — readers observing a file mid-rewrite either see the previous or new version, never a parse error; transient parse failures trigger 50ms-backoff retry up to 3 times)

**Success Criteria** (what must be TRUE):
1. **50 concurrent MATLAB processes** each appending 1,000 events to the same `<key>.events.ndjson` via `EventLog.append` produce a file containing **exactly 50,000 valid JSON lines** — verified by `TestEventLogConcurrent` running through Phase 1030's `TagWriteCoordinator`.
2. **`EventLogReader.tail()` tolerates corrupt lines** — a deliberately injected malformed line is skipped, counted on `SkippedLineCount`, and the parse continues; never aborts the read.
3. **Reader retry-loop converts torn-rename windows into brief stalls** — a writer in a tight `temp+rename` loop with 5 concurrent readers produces <0.1% user-facing parse errors (with retry) vs <5% (without retry); never propagated as a hard error.
4. **Shared `EventStore` SQLite in `journal_mode=DELETE` mode** survives 20 concurrent writers each committing 100 inserts with zero "database is locked" errors propagated to user code; total row count exactly 2,000.
5. **`EventLogReader` mtime-cache invalidates correctly** — a re-read after a writer touches the log returns updated content; an unchanged file reuses the cached parse without re-reading.
6. **Phase 1031 contingency budget acknowledged** — if SMB atomicity stress shows torn appends on the target file server, the phase budget includes time to re-architect to per-writer-file + merge instead of single-file append.

**Plans:** 4/4 plans complete

- [x] 1031-01-ndjson-decode-PLAN.md — libs/Concurrency/ndjsonDecode.m sibling to ndjsonEncode (Wave 1, no deps) (EVTLOG-02 primitive)
- [x] 1031-02-event-log-PLAN.md — libs/Concurrency/EventLog.m lock-serialised append + magic header + 50-proc stress harness (Wave 2, depends on 01) (EVTLOG-01 + EVTLOG-02)
- [x] 1031-03-event-log-reader-PLAN.md — libs/Concurrency/EventLogReader.m with mtime cache + AtomicWriter.readWithRetry + corrupt-line tolerance (Wave 2, depends on 01) (EVTLOG-02 + EVTLOG-03)
- [x] 1031-04-event-store-cluster-mode-PLAN.md — libs/EventDetection/EventStore.m gains "SharedRoot" NV-pair + journal_mode=DELETE + busy_timeout=10000 + BEGIN IMMEDIATE + retry on "database is locked" (Wave 3, depends on 02; FastSenseDataStore UNCHANGED) (EVTLOG-01 full)

### Phase 1032: Single-Source MonitorTag Event Emission + Ack Workflow

**Goal:** Achieve the "exactly once" event-emission guarantee across 50 Companions by routing `LiveEventPipeline.processMonitorTag_` through the **same** per-tag `FileLock` that `LiveTagPipeline.processTag_` uses — making the lock holder the sole emitter for that tag's events. Layer the user-facing ack/comment/visual-state workflow on top of identity-stamped writes. Also lands the deferred-listener-notify refactor (PITFALLS Pitfall 13) and the SQLite retry wrapper (PITFALLS Pitfall 6).

**Depends on:** Phase 1029 (identity, lock, atomic writer), Phase 1030 (per-tag lock domain established), Phase 1031 (EventLog + rollback-mode SQLite available).

**Requirements covered:**
- ACK-04 (a `MonitorTag` threshold violation produces exactly ONE event in the shared EventStore regardless of how many Companions are running; single-source guarantee from lock-holder-as-sole-emitter)
- ACK-01 (when User A acks an alarm, the ack becomes visible to other Companions within ~5s — eventual-consistency target; UDP multicast hint accelerates propagation but disk state is canonical)
- ACK-02 (event displays distinct visual state for "acked but condition still active" vs "acked and cleared" vs "unacked active" per ISA-18.2 / EEMUA 191 — condition state and ack state orthogonal)
- ACK-03 (user can attach an optional free-text comment when acknowledging; comment persisted with ack record)
- IDENT-02 (every event acknowledgement records user, host, timestamp, action, target event-id; audit trail queryable and viewable in Companion event log column)

**Success Criteria** (what must be TRUE):
1. **4-node simulated cluster** (via `parfeval` or shelled-out `matlab -batch`) polling the same `MonitorTag` produces **exactly N events for N rising edges** — verified by `TestMonitorTagSingleSource.testFourNodeRisingEdges` merged-view assertion.
2. **A `MonitorTag` listener that tries to acquire a second tag's lock from inside an `EventAppended` callback** either errors loudly with `Concurrency:nestedLockAcquireForbidden` (test mode) or fires post-release with no deadlock (production mode) — `MonitorTag.fireEventsOnRisingEdges_` deferred-notify refactor verified by `TestListenerCannotAcquireLock`.
3. **Ack from User A on Companion X is visible to User B on Companion Y within ~5 seconds** — eventual-consistency target met; the ack record carries `{user, host, timestamp, action, target event-id, optional comment}`; UI shows the three orthogonal visual states (unacked-active / acked-active / acked-cleared) per ISA-18.2.
4. **SQLite `SQLITE_BUSY_SNAPSHOT` retry wrapper** handles 20-writer ack-contention stress with zero user-facing "database is locked" errors and zero double-ack records (`TestEventStoreConcurrency.testRetryOnBusySnapshot`).
5. **SMB-oplocks smoke test at startup** (`ClusterConfig.checkSharedConfig`) detects torn reads on the EventStore directory and emits a one-time operator warning when oplocks appear enabled — best-effort detection per PITFALLS Pitfall 14.

**Plans:** 5/5 plans complete

- [x] 1032-01-monitor-tag-emit-helper-PLAN.md — MonitorTag.emitEvent_ helper + deferred-notify refactor (Pitfall 13) for OnEventStart/OnEventEnd; routes all 4 EventStore.append call sites in fireEventsInTail_/fireEventsOnRisingEdges_ through emitEvent_; cluster mode (IsClusterMode_) writes to EventLog (1031-02), single-user writes to EventStore (Wave 1, no deps) (ACK-04 partial)
- [x] 1032-02-live-event-pipeline-cluster-PLAN.md — LiveEventPipeline.processMonitorTag_ acquires per-tag FileLock via TagWriteCoordinator BEFORE parent.updateData + monitor.appendData (Pitfall 13 lock-domain unification with LiveTagPipeline); skip-and-defer on contention (SkippedMonitorCount); BusyMode=drop (Pitfall 7); mirrors 1030-02 cluster pattern. Plus TestMonitorTagSingleSource (4-node parfeval/matlab -batch cluster test) (Wave 2, depends on 1032-01) (ACK-04 full)
- [x] 1032-03-event-store-retry-and-merge-PLAN.md — EventStore busyRetryWrap_ helper (extends 1031-04 retry into reusable 10-attempt exponential backoff up to 2s; Pitfall 6); refactors appendAckRecord through it; getEvents()/getEventsForTag() in cluster mode merge in-memory + EventLogReader.tail() so reads pull from BOTH SQLite snapshot AND live NDJSON. Plus TestEventStoreConcurrency (20-writer in-process ack-contention smoke) (Wave 1, no deps) (IDENT-02 indirect, ACK-04 indirect)
- [x] 1032-04-ack-workflow-PLAN.md — Event optional Identity + AckedAt + AckedBy fields (defaults empty; backward-compat fromStructSafe) + computeDisplayState() for ISA-18.2 three-state (unacked-active|acked-active|acked-cleared); EventStore.acknowledgeEvent(eventId, opts) routes single-user → acks_ array, cluster → appendAckRecord (1031-04). Plus TestEventAcknowledgement (Wave 2, depends on 1032-01) (ACK-01, ACK-02, ACK-03, IDENT-02)
- [x] 1032-05-oplock-smoke-test-PLAN.md — ClusterConfig.checkSharedConfig(sharedRoot) best-effort SMB-oplock canary smoke test (Pitfall 14); single-process write-and-immediate-read of 1024 deterministic bytes; one-time warning(Concurrency:smbOplockDetected, ...) on mismatch; never throws (advisory); operator-fix guidance in warning text (Set-SmbServerConfiguration, smb.conf). Plus TestClusterConfigOplocks (Wave 1, no deps) (operational hardening; no REQ-IDs)

**UI hint**: yes

### Phase 1033: Companion Integration + Snapshot Consolidator + Operator Docs + 50-Companion Acceptance Test

**Goal:** Wire the new `'SharedRoot'` opt through `FastSenseCompanion` and its `companionDiscoverEventStore` private helper; add the optional leader-elected `EventLogConsolidator` that periodically rolls per-tag NDJSON logs into the canonical `events.mat` snapshot; surface lock contention and skipped ticks in the Companion UI; write the operator-facing cluster-setup README; and run the full 50-Companion acceptance test against a real SMB share. This is the composition phase — no new primitives, only wiring — which makes the acceptance test meaningful.

**Depends on:** Phases 1029, 1030, 1031, 1032 (uses every primitive and integration produced upstream).

**Requirements covered:**
- OPS-01 (temporary loss of the shared file share does not crash any Companion — Companions enter a degraded "read-only / waiting for share" state, retry transparently, and resume on share return; existing single-user `.m` scripts run unchanged with no shared share)
- OPS-02 (operator-facing document specifies: (a) eventual-consistency contract "ack propagation lag up to ~5s"; (b) SMB-over-NFS recommendation on mixed-OS LANs; (c) SMB-oplocks-must-be-disabled-on-EventStore-directory with Windows-Server and Samba syntax; (d) multicast firewall rule for `udpport` notification hints; (e) NFSv3-detection startup warning)

**Success Criteria** (what must be TRUE):
1. **50 Companions running concurrently on a real SMB share** for the acceptance test produce **zero data corruption, zero lost acks, zero duplicate events**, with per-Companion responsiveness within **2× the single-user baseline** — verified by `tests/suite/Test50CompanionAcceptance.m` (gated behind `FASTSENSE_RUN_ACCEPTANCE=1`).
2. **Specific p50/p95/p99 per-tick latency** is recorded for cluster sizes **1, 10, 25, and 50 Companions** and surfaced in the phase completion artifact, replacing the coarse "2× baseline" gate with actionable numbers.
3. **Temporary shared-share loss** (simulated via firewall block) causes every Companion to enter a documented "read-only / waiting for share" state — no crashes, no orphan timers; on share return, live mode resumes within one tick of the next successful share read.
4. **Operator can follow `examples/cluster-setup/README.md`** to configure a fresh shared share (SMB oplocks disabled on EventStore directory, multicast firewall rule open, NFSv3 warning understood) and bring up the cluster end-to-end without consulting source code.
5. **Lock contention surfaces in the Companion UI** as a non-blocking notice ("Tag P-101 is being updated by alice@plant-a (5s ago)") and `pipeline.SkippedTickCount` is visible as a status badge — verified by `TestFastSenseCompanion.testClusterStatusSurface`.
6. **Existing single-user `.m` scripts and examples run unchanged** with no `'SharedRoot'` set — every cluster code path is structurally dormant (gated behind `if obj.IsClusterMode_`).

**Plans:** 4/4 plans complete

Plans:
- [x] 1033-01-companion-shared-root-PLAN.md — FastSenseCompanion 'SharedRoot' NV-pair + companionDiscoverEventStore cluster upgrade + 4 SharedRoot regression tests (Wave 1, no deps) (OPS-01 partial)
- [x] 1033-02-event-log-consolidator-PLAN.md — libs/Concurrency/EventLogConsolidator.m leader-elected NDJSON→snapshot writer + 5-test suite (Wave 1, no deps)
- [x] 1033-03-operator-docs-PLAN.md — examples/cluster-setup/{README,smb-disable-oplocks.ps1,smb-disable-oplocks.conf,multicast-firewall.md} + ClusterConfig NFSv3 detection + TestClusterConfigNfsv3 (Wave 1, no deps) (OPS-02 full)
- [x] 1033-04-acceptance-and-recovery-PLAN.md — Companion pipeline-observer + share-loss state machine + TestShareLossRecovery + gated Test50CompanionAcceptance with p50/p95/p99 at 1/10/25/50 (Wave 2, depends on 01 + 02) (OPS-01 full)

**UI hint**: yes

## Phase Details (Pending Milestone)

### Phase 1024: Fix companion app dark mode — CLOSED

**Status:** Closed 2026-05-08 via quick task [260508-d7k](./quick/260508-d7k-fix-companion-app-dark-mode-switching-th/).

**Root cause:** `applyThemeToChildren_` walker silently skipped widget classes without an explicit `case`. `uilistbox` (TagCatalogPane Row 7 — the tag list) was the visible casualty.

**Fix:** Added 8 widget cases to the walker (`ListBox`, `TextArea`, `CheckBox`, `NumericEditField`, `StateButton`, `ToggleButton`, `RadioButton`, `ButtonGroup`). Regression test asserts dark→light→dark flip across all classes.

**Promoted from:** Backlog 999.1 (2026-05-08)

### Phase 1025: FastSense hover crosshair + datatip

**Goal:** Add a vertical crosshair line that follows the mouse when hovering over a FastSense plot/widget, with a context datatip window showing the values of all lines at the hovered x position.

**Promoted from:** Backlog 999.2 (2026-05-08)
**Requirements:** TBD
**Plans:** 0 plans

### Phase 1026: Dashboard time slider preview

**Goal:** Fix the lower dashboard time slider so it shows a preview overlay of all graphed plot lines and detected events across the full time range. Currently the slider track is empty — investigate why the preview rendering isn't happening and restore it.

**Promoted from:** Backlog 999.3 (2026-05-08)
**Requirements:** TBD
**Plans:** 0 plans

### Phase 1027: Companion detachable log window

**Goal:** In the FastSense Companion app, make the log panel detachable into its own draggable, resizable window — same pop-out pattern as detachable widgets in the main dashboard. Implementation extracts the log strip into a `LogPane` class (mirrors existing pane pattern) with an `Inline`/`Detached`/`Hidden` state machine driven by a top-toolbar dropdown.

**Promoted from:** Backlog 999.4 (2026-05-08)
**Requirements:** TBD
**Plans:** 5/5 plans complete

Plans:
- [x] 1027-01-create-logpane-class-PLAN.md — extract self-contained `LogPane` class (UI + buffers + filter + theme + DetachRequested event)
- [x] 1027-02-test-logpane-PLAN.md — class-based unit suite covering attach/detach lifecycle, buffer preservation, theme switch, 500-row cap, event firing
- [x] 1027-03-integrate-logpane-companion-PLAN.md — wire `LogPane` into `FastSenseCompanion`, add toolbar `Live` button + `Log:` dropdown, implement `setLogState_` state machine, update theme walker to skip LogPaneRoot
- [x] 1027-04-extend-companion-tests-PLAN.md — add 10 state-machine + Live-button-relocation + theme-while-detached tests to `TestFastSenseCompanion`
- [x] 1027-05-update-walker-test-PLAN.md — add LogPaneRoot skip-rule assertions to `test_companion_apply_theme_walker`


### Phase 1027.1: Independent events/live log detach (gap closure)

**Goal:** Make the events log and the live updates log independently detachable. Phase 1027 detached them as one unit; this phase splits the contract so each log has its own `Inline`/`Detached`/`Hidden` state, its own pop-out icon, its own detached `uifigure`, and its own toolbar dropdown. Inline strip rebalances so the still-inline log fills the row.

**Source:** User feedback after Phase 1027 demo (2026-05-08) — "we have 2 logs right? I want both separately detachable."
**Spec:** [docs/superpowers/specs/2026-05-08-independent-log-detach-design.md](../../docs/superpowers/specs/2026-05-08-independent-log-detach-design.md)
**Requirements:** none — CONTEXT.md acceptance criteria are the contract
**Plans:** 8/8 plans complete

Plans:
- [x] 1027.1-01-create-events-log-pane-PLAN.md — port events-half of LogPane into self-contained `EventsLogPane` class (Wave 1, parallel-safe)
- [x] 1027.1-02-create-live-log-pane-PLAN.md — port live-half of LogPane into self-contained `LiveLogPane` class with own pop-out icon (Wave 1, parallel-safe)
- [x] 1027.1-03-test-events-log-pane-PLAN.md — class-based unit suite for EventsLogPane (Wave 2, depends on 01)
- [x] 1027.1-04-test-live-log-pane-PLAN.md — class-based unit suite for LiveLogPane (Wave 2, depends on 02)
- [x] 1027.1-05-companion-integration-PLAN.md — heavy: replace LogPane with two panes, two dropdowns, two detached uifigures, parameterized `setLogState_(which, newState)`, `rebalanceLogStrip_()` (Wave 3, depends on 01+02)
- [x] 1027.1-06-delete-old-logpane-PLAN.md — delete `libs/FastSenseCompanion/LogPane.m` and `tests/suite/TestLogPane.m` (Wave 4, depends on 05)
- [x] 1027.1-07-update-companion-tests-PLAN.md — migrate Phase 1027 accessors and add 5 independence tests to `TestFastSenseCompanion` (Wave 4, depends on 05)
- [x] 1027.1-08-update-walker-test-PLAN.md — assert two-panel LogPaneRoot skip-rule in walker test (Wave 4, depends on 05)


### Phase 1028: Tag update perf — MEX + SIMD

**Goal:** Profile and accelerate the tag update path (SensorTag/StateTag/MonitorTag/CompositeTag streaming + recompute). Identify hot spots and replace with C MEX kernels using SIMD (AVX2 / NEON) where it pays off, consistent with existing FastSense MEX patterns.

**Promoted from:** Backlog 999.5 (2026-05-08)
**Requirements:** TBD
**Plans:** 0 plans

## Backlog

(empty — last 5 items promoted to phases 1024-1028 on 2026-05-08)
