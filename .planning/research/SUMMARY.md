# Project Research Summary

**Project:** FastSense Advanced Dashboard (nested layouts, tooltips, detachable widgets)
**Domain:** MATLAB sensor data dashboard — advanced UI patterns atop existing dashboard engine
**Researched:** 2026-04-01
**Confidence:** HIGH

## Executive Summary

This milestone adds advanced UI patterns to an existing, well-structured MATLAB dashboard engine (`libs/Dashboard/`). The engine is built entirely on the traditional `figure`/`uipanel`/`uicontrol` API — not App Designer (`uifigure`) — and all new work must stay within this surface. This is a hard constraint with no workaround: `uifigure` and `figure` cannot share a graphics hierarchy. The good news is that the codebase is in better shape than typical for this kind of work: `GroupWidget` already has structural stubs for tabbed and collapsible modes, `Description` fields exist on every widget, and a live-refresh timer with dirty-flag filtering is already operational.

The recommended approach is incremental extension, not redesign. Three of the six deliverables are completion tasks (wiring existing stubs), two are additive new features (multi-page navigation and detachable mirrors), and one is a verification pass (serialization round-trips). The main architectural addition is a `DetachedMirror` class as a parallel track in the engine's timer loop — explicitly NOT a `DashboardWidget` subclass — and a `DashboardPage` thin container for multi-page support. Both follow established patterns already present in the codebase.

The principal risks are timer-related: MATLAB timers silently stop on unhandled errors, and detached figure windows become orphaned handles that cause cascading refresh errors. Both risks have clear mitigations (an `ErrorFcn` on `LiveTimer` and `CloseRequestFcn` on detached figures that unregister from the engine). A secondary risk is `jsondecode`'s struct-vs-cell inconsistency, which has already bitten this codebase and must be handled at every new level of nested deserialization.

## Key Findings

### Recommended Stack

The entire feature set is implementable using the existing MATLAB API surface: `uipanel`, `uicontrol`, `figure`, and `timer`. No new toolboxes, no App Designer, no Java frame hacks. The version baseline (MATLAB R2020b+ / Octave 7+) is already established and all recommended patterns work within it.

The one API choice worth highlighting: `TooltipString` on `uicontrol` is already used in `DashboardToolbar.m` and is the correct approach for hover hints, but it is unreliable on Octave (especially macOS/Linux). The primary info display for widget descriptions should be click-driven (pushbutton + panel overlay or `msgbox`), with `TooltipString` as a secondary hint only.

**Core technologies:**
- `uipanel` + `uicontrol` (pushbutton): All layout, tab switching, collapsible headers, page navigation, info icons — these APIs are the entire UI surface
- `timer` (fixedRate): Existing live refresh mechanism — extend `onLiveTick()` to cover detached mirrors; do not create additional timers
- `figure` (traditional): Detached widget windows — must use `figure`, not `uifigure`, to host children from the existing graphics hierarchy
- `DashboardLayout.reflow()`: Already implemented; wiring it into `GroupWidget` collapse/expand fills the primary existing TODO

**What NOT to use:**
- `uitabgroup`/`uitab`: Broken theming in `figure` context; Octave gaps; custom button tabs already exist
- `uifigure` / App Designer components: Incompatible graphics hierarchy — would require rewriting the entire engine
- Per-widget timers for detached mirrors: Creates O(n) timer objects; shared timer approach is correct

### Expected Features

The 6 deliverables from `PROJECT.md` map to the following readiness tiers:

**Must have (table stakes — these are expected and partially built):**
- Collapse/expand with grid reflow — collapsing without reflow produces dead whitespace; the `TODO` is explicit in source
- Widget info tooltips — Grafana-style description display; `Description` field exists but is not rendered in the UI
- Tabbed sections working end-to-end — structural implementation exists; integration testing and edge-case polish needed
- Detachable live-mirrored widgets — users expect pop-out with live data; not yet implemented

**Should have (differentiators):**
- Multi-page navigation — single-figure multi-page is cleaner than multiple `figure()` calls; not yet implemented
- Two-level group nesting (tabs inside collapsible) — structural support exists; primarily a documentation and testing gap
- Independent time zoom on detached windows (`UseGlobalTime = false`) — adds value beyond a simple static copy

**Defer (out of scope for this milestone):**
- Drag-and-drop widget rearrangement
- Cross-filtering / data binding between widgets
- Browser/WebBridge parity
- New widget types
- Detached windows that are editable (bidirectional sync)

### Architecture Approach

All four feature clusters extend existing abstractions without changing the `DashboardWidget` contract. The key additions are: `DashboardPage` (thin widget-list container scoped per page), `PageBar` (page-switcher button strip), `DetachedMirror` (independent handle class, not a widget subclass), and an `EngineRef` back-reference on `GroupWidget` to enable reflow callbacks. `DashboardEngine` gains `Pages[]`, `ActivePage`, and `DetachedMirrors[]` properties. `DashboardSerializer` needs extension for multi-page persistence only.

**Major components and new additions:**
1. `DashboardEngine` — orchestration, timer, page navigation, mirror registry (extended)
2. `DashboardPage` — scoped widget collection per page (new, thin)
3. `PageBar` — page-switcher UI button strip (new)
4. `DetachedMirror` — live mirror in independent figure, refreshed by shared timer (new)
5. `GroupWidget` — gains `EngineRef` to trigger `reflowPage()` on collapse/expand (extended)
6. `DashboardWidget` base — gains `renderInfoIcon()` protected helper (minor extension)
7. `DashboardSerializer` — extended for multi-page serialization; `normalizeArray()` helper needed

### Critical Pitfalls

1. **Detached figure timer orphans** — When a detached window is closed by the user, handles become invalid and `onLiveTick()` throws on every subsequent tick. Prevention: `CloseRequestFcn` on every detached figure that unregisters the mirror from `DetachedMirrors[]`; explicit `ishandle` guard in the engine loop before calling `mirror.refresh()`.

2. **Timer silently stops on error** — MATLAB `timer` with `ExecutionMode = 'fixedRate'` swallows unhandled errors and stops the timer with no user notification. Prevention: set `ErrorFcn` on `LiveTimer`; extend `try/catch` coverage in `onLiveTick()` to all new code paths (mirror refresh, page-level refresh).

3. **Collapse does not reflow the grid** — Already documented as a `TODO` in `GroupWidget.m` lines 241 and 258. Without wiring `DashboardLayout.reflow()`, collapsing creates dead whitespace. Prevention: implement `EngineRef` + `reflowPage()` callback pattern before shipping collapsible feature.

4. **`jsondecode` struct-vs-cell inconsistency** — `jsondecode` converts JSON arrays of objects to struct arrays, not cell arrays. `GroupWidget.fromStruct()` already handles this at the top level, but every new nested structure (pages, multi-page widget lists) must apply the same `normalizeArray()` normalization or deserialization will fail silently at load time (not save time).

5. **Live mirror doubles refresh work** — If detached mirrors are added to `DashboardEngine.Widgets[]`, they will be refreshed twice per tick (once as a widget, once as a mirror). Prevention: maintain `DetachedMirrors[]` as a completely separate list; mirrors call `SourceWidget.refresh()` after the main widget has already been refreshed, using a lightweight redraw-only path.

## Implications for Roadmap

Based on research, dependency analysis, and the existing codebase state, a 5-phase structure is recommended:

### Phase 1: Collapsible Reflow Wiring
**Rationale:** This is the highest-value / lowest-cost item. The implementation is 80% done; the `TODO` is explicit in source. Shipping this unblocks the collapsible feature from being cosmetic-only and validates the `EngineRef` callback pattern that the detach phase will also use. No new files needed.
**Delivers:** Fully functional collapsible sections with grid compaction on collapse/expand
**Addresses:** Table-stakes collapse/expand reflow; fixes `GroupWidget` TODO at lines 241 and 258
**Avoids:** Pitfall 2 (grid does not reflow), Pitfall 9 (height restore corruption — store full position vector, not just height)

### Phase 2: Widget Info Tooltips
**Rationale:** Fully self-contained with no dependencies on other phases. The `Description` property exists on every widget; this phase only adds the UI rendering path. Low risk, high visibility. Validates the `renderInfoIcon()` pattern in the base class before adding more complexity.
**Delivers:** Info icon in widget header chrome; click-driven description popup for all widgets with non-empty `Description`
**Addresses:** Widget documentation feature; all 20+ widget types benefit automatically
**Avoids:** Pitfall 7 (hover tooltip unreliable on Octave) — use click-driven panel, not `TooltipString` as primary mechanism

### Phase 3: Multi-Page Navigation
**Rationale:** Architecturally independent of GroupWidget changes. Adding `DashboardPage` and `PageBar` is additive to `DashboardEngine` and does not interfere with collapse/expand or tooltip work. Serialization for pages is best done immediately after the page model exists, while context is fresh.
**Delivers:** `DashboardPage` container, `PageBar` UI, `DashboardEngine.switchPage()`, backward-compatible serialization extension
**Addresses:** Multi-page dashboard feature; serialization extension
**Avoids:** Pitfall 8 (single-figure render guard blocks re-renders — implement switching via panel visibility, not `render()` re-calls); Pitfall 3 (`jsondecode` normalization — add `normalizeArray()` helper)

### Phase 4: Detachable Widgets (Static, then Live)
**Rationale:** Most complex feature; builds on stable `EngineRef` pattern from Phase 1 and stable timer loop from existing code. Split into two sub-phases: static detach first (pop-out to new figure, no live mirroring), then live mirroring (add `DetachedMirrors[]` registry to timer loop). This allows the clone mechanism to be validated before adding live-sync complexity.
**Delivers:** Detach button in widget header; `DetachedMirror` class; live mirror refresh via shared timer
**Addresses:** Detachable widget and live-mirror features
**Avoids:** Pitfall 1 (timer orphans — `CloseRequestFcn` + engine guard); Pitfall 4 (mirror doubles refresh work — separate `DetachedMirrors[]` list); Pitfall 6 (timer stops on error — set `ErrorFcn`, extend `try/catch`); Pitfall 12 (theme sync for mirrors)

### Phase 5: Serialization Verification and Polish
**Rationale:** Most serialization already works. This phase addresses the known gap in `.m` export (GroupWidget children not serialized) and validates round-trip correctness for all new structures added in Phases 3-4. Integration tests go here.
**Delivers:** Fixed `.m` export for GroupWidget; round-trip tests for multi-page; tab overflow polish (>6 tabs)
**Addresses:** Nested layout serialization; edge cases in GroupWidget tabs
**Avoids:** Pitfall 10 (`.m` export loses GroupWidget children); Pitfall 11 (tab button overflow for >6 tabs)

### Phase Ordering Rationale

- Phase 1 before everything: fills the critical `TODO` and validates the `EngineRef` callback pattern used by Phase 4
- Phase 2 before Phase 4: simpler header chrome work validates the widget header modification pattern before the more complex detach button is added
- Phase 3 before Phase 4: stable per-page widget lists are needed before attaching detached mirrors to the timer (which iterates `ActivePage.Widgets`)
- Phase 5 last: serialization verification is a correctness pass on everything built in Phases 1-4; doing it earlier would require re-running tests

### Research Flags

Phases with well-documented patterns (skip additional research):
- **Phase 1 (Collapsible Reflow):** Pattern is entirely within existing codebase; `TODO` comment is a specification. No research needed.
- **Phase 2 (Info Tooltips):** `renderInfoIcon()` pattern is straightforward; `msgbox` and `uipanel` overlay are established.
- **Phase 5 (Serialization Polish):** Known gaps already identified in source. Round-trip test patterns are standard.

Phases that may benefit from deeper research during planning:
- **Phase 3 (Multi-Page):** The `DashboardSerializer` schema extension is new territory. The `DashboardEngine` single-figure render guard needs careful analysis to ensure page switching via panel visibility does not conflict with existing `realizeBatch()` logic. Flag for brief architecture review before implementation starts.
- **Phase 4 (Detachable Mirrors):** The `cloneForDetach()` mechanism for `FastSenseWidget` and `RawAxesWidget` involves non-serializable state (live sensor bindings). The correct rebind pattern for each widget type should be confirmed before implementation. MEDIUM confidence on this specific sub-problem.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All claims verified by direct codebase reading; `TooltipString` already used in toolbar; `figure`/`uifigure` incompatibility is a MATLAB fundamental |
| Features | HIGH | Gap analysis derived from direct source reading; comparison to Grafana/Dash/Streamlit features based on well-established training knowledge |
| Architecture | HIGH | All component boundaries derived from direct inspection of `DashboardEngine.m`, `GroupWidget.m`, `DashboardLayout.m`, `DashboardSerializer.m` |
| Pitfalls | HIGH | Every critical pitfall is grounded in specific file/line evidence from the codebase, not speculation |

**Overall confidence:** HIGH

### Gaps to Address

- **`uitabgroup` theming on Octave:** Training data only; flagged as MEDIUM confidence. If Octave + styled tabs become a requirement, validate `uitabgroup` behavior on Octave 7+ before assuming custom button tabs are the only path.
- **`cloneForDetach()` for non-serializable widgets:** The `toStruct()`/`fromStruct()` round-trip works for most widget types, but `FastSenseWidget` and `RawAxesWidget` have live MATLAB object references that cannot serialize. Each type needs an explicit `cloneForDetach()` override. The set of affected types should be enumerated at the start of Phase 4.
- **`DashboardEngine` render guard interaction with page switching:** The guard at `DashboardEngine.m` line 135 treats "figure exists" as "already rendered." Phase 3 must confirm that panel-visibility-based page switching does not conflict with `realizeBatch()` lazy realization logic.

## Sources

### Primary (HIGH confidence — direct codebase inspection)
- `libs/Dashboard/DashboardEngine.m` — timer mechanics, render guard, `onLiveTick()` structure, widget list iteration
- `libs/Dashboard/GroupWidget.m` — collapse/expand TODOs (lines 241, 258), tabbed render, `ancestorDepth()` guard
- `libs/Dashboard/DashboardWidget.m` — `Description` property (line 17), `toStruct()` serialization
- `libs/Dashboard/DashboardLayout.m` — `reflow()` method existence and signature
- `libs/Dashboard/DashboardToolbar.m` — `TooltipString` usage (line 104)
- `libs/Dashboard/DashboardSerializer.m` — `.m` export structure, `jsondecode` normalization pattern
- `.planning/PROJECT.md` — requirements

### Secondary (HIGH confidence — established reference knowledge)
- Grafana panel description tooltip, collapsible rows — established since Grafana v6+
- Plotly Dash `dcc.Tabs`, `dcc.Collapse` patterns — stable since Dash 1.x
- MATLAB `timer` ErrorFcn behavior — documented MATLAB behavior
- `jsondecode` struct-array output — documented MATLAB behavior

### Tertiary (MEDIUM confidence — training knowledge)
- `uitabgroup` theming limitations in traditional `figure` context — not directly tested on target versions; flagged for validation if needed

---
*Research completed: 2026-04-01*
*Ready for roadmap: yes*
