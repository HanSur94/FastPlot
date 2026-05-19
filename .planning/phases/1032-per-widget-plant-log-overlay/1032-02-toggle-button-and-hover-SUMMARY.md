---
phase: 1032-per-widget-plant-log-overlay
plan: 02
subsystem: dashboard-overlay
tags: [matlab, plant-log, fastsense-widget, dashboard-layout, dashboard-widget, plant-log-widget-hover, chained-wbm-hover, three-button-chrome, friend-class-access, idempotent-chrome, software-enable-guard]

# Dependency graph
requires:
  - phase: 1029-plant-log-storage-foundation
    provides: PlantLogStore.getEntriesInRange (range-clipped lookup feeding the per-widget hover); PlantLogEntry.Metadata (insertion-order struct fields rendered in the tooltip)
  - phase: 1031-live-tail-slider-preview-overlay (Plan 03)
    provides: PlantLogSliderHover (chained-WBM template literally copied + extended for the metadata-rich layout); engine.lookupPlantLogEntries_ (live store re-read used by the new widget hover); hover-before-selector teardown rule (mirrored here as hover-before-TRS in DashboardEngine.delete)
  - phase: 1032-per-widget-plant-log-overlay (Plan 01)
    provides: FastSenseWidget.ShowPlantLog public property + setShowPlantLog setter (extended with hover attach/detach); FastSenseWidget.setPlantLogMarkers (used unchanged); DashboardEngine.refreshPlantLogOverlayForWidget_ + attachPlantLogXLimListener_ + onPlantLogTailTick_ (unchanged, all consumed by the toggle + hover flow); MarkerPlantLog theme token (used as pressed-state ON background)

provides:
  - DashboardLayout.EngineRef public property -- back-reference to the owning DashboardEngine, set in DashboardEngine constructor; used by realizeWidget's plant-log toggle invocation site to thread the engine handle through the callback closure
  - DashboardLayout.addPlantLogToggle(widget, engine) -- public method; creates a 24x24 uicontrol pushbutton with Tag='PlantLogToggleButton', String='L', positioned as the LEFTMOST of the three button-bar buttons (x = barW - 84). Idempotent (deletes any prior tag before create). Pressed-state colors derived from theme.MarkerPlantLog (ON) vs theme.ToolbarBackground (OFF). Disabled with tooltip 'No plant log attached' when no store is attached.
  - DashboardLayout.onPlantLogTogglePressed_(src, widget, engine) -- public callback wrapping widget.setShowPlantLog(~ShowPlantLog, engine) + idempotent button rebuild. Wraps every operation in try/catch + namespaced warning DashboardLayout:plantLogToggleParentMissing. Software-level Enable='off' guard short-circuits force-call paths.
  - DashboardLayout.reflowChrome_ -- extended to re-anchor all THREE buttons on resize: Detach (barW - 24 - 4), Info (barW - 24 - 24 - 4 - 4), PlantLog (barW - 84). Single new branch added inside the existing if-bar block.
  - DashboardLayout.realizeWidget -- now invokes obj.addPlantLogToggle(widget, obj.EngineRef) for every FastSenseWidget instance, gated behind the existing needsBar chrome path.
  - DashboardWidget.clearPanelControls -- protectedTags array extended to include 'PlantLogToggleButton' so the toggle survives re-render sweeps.
  - PlantLogWidgetHover -- new handle class at libs/PlantLog/PlantLogWidgetHover.m (~480 LOC). Mirrors PlantLogSliderHover's chained-WBM lifecycle exactly; differs only in the showTooltip_ string-builder (full metadata + overlap stacking + 40-char value truncation + '+N more' footer) and the simulateHoverAt_ return shape (full array within tolerance, not single nearest pick). PlantLogWidgetHover:invalidInput error namespace.
  - DashboardEngine.WidgetHovers_ -- new public-read property (SetAccess friend = {?DashboardEngine, ?FastSenseWidget, ?matlab.unittest.TestCase}) storing a cell of {widget, PlantLogWidgetHover} pairs.
  - DashboardEngine.attachPlantLogWidgetHover_(widget) -- friend-restricted method (in the existing Plan 01 friend block); idempotent + early-returns when widget/engine/store/axes prerequisites are missing; constructs a PlantLogWidgetHover parented to the figure ancestor of the widget axes and routes lookup through obj.lookupPlantLogEntries_.
  - DashboardEngine.detachPlantLogWidgetHover_(widget) -- friend-restricted; tears down the hover for one widget AND sweeps any stale (already-destroyed) widget pairs that linger in WidgetHovers_.
  - DashboardEngine.delete() -- extended to tear down WidgetHovers_ BEFORE TimeRangeSelector_ (mirrors Phase 1031's hover-before-selector ordering rule).
  - FastSenseWidget.setShowPlantLog -- ON branch additionally calls engine.attachPlantLogWidgetHover_(obj); OFF branch additionally calls engine.detachPlantLogWidgetHover_(obj) BEFORE the marker clear.
  - tests/test_dashboard_layout_plant_log_toggle.m + tests/suite/TestDashboardLayoutPlantLogToggle.m -- 12 sub-tests each (MATLAB-only function-style with Octave SKIP gate; MATLAB-only class-based suite). Covers all 12 must-have truths for Task 1.
  - tests/test_plant_log_widget_hover.m + tests/suite/TestPlantLogWidgetHover.m -- 13 sub-tests each, mirroring Task 2's behavior contract verbatim.
  - tests/Probe_DW_PanelClear.m -- test-only DashboardWidget subclass exposing the protected clearPanelControls static. Sits under tests/ so production code never depends on it.

affects:
  - 1032-03-detached-mirror-and-smoke -- will exercise the full toggle UI + hover pipeline end-to-end (single-page + multi-page + detached mirror parity). Hover wiring through PlantLogWidgetHover + engine.WidgetHovers_ + setShowPlantLog attach/detach hooks is the live surface Plan 03 builds on. DetachedMirror clone construction will copy ShowPlantLog via the toStruct/fromStruct round-trip that Plan 01 wired AND will need its own per-mirror hover lifecycle.
  - 1033-dashboard-companion-integration -- attachPlantLog/detachPlantLog public API needs to drive setShowPlantLog(false, engine) + detachPlantLogWidgetHover_ on every widget when the store is removed. The Companion's "Open Plant Log…" toolbar entry will need to call setPlantLogStoreForTest_ replacement that runs through the same wiring.

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three-button chrome reflow: existing two-button (Detach + Info) reflowChrome_ pattern extended to N buttons by adding a third Tag-based findobj + set Position branch. The math (barW - 24 - 4 [detach], barW - 24 - 24 - 4 - 4 [info], barW - 24 - 4 - 24 - 4 - 24 - 4 = barW - 84 [plantlog]) is verifiable by static grep and is the SAME math the realizeWidget initial-create path uses (DRY across reflowChrome_ + addPlantLogToggle)."
    - "Idempotent chrome creation: every addPlantLogToggle call first runs `findobj(bar, 'Tag', 'PlantLogToggleButton', '-depth', 1)` + delete on any prior result before creating the new uicontrol. Same pattern can be retro-fitted to addInfoIcon + addDetachButton if double-call protection becomes a future need."
    - "Engine back-reference via DashboardLayout.EngineRef public property: addresses the architectural problem that chrome callbacks need engine context but DashboardLayout was previously engine-agnostic. The single-line constructor edit `obj.Layout.EngineRef = obj` in DashboardEngine keeps the back-pointer in sync; chrome callbacks (currently just addPlantLogToggle, future ones if needed) read through obj.EngineRef."
    - "Software-level Enable guard in callback wrappers: uicontrols natively skip the Callback for Enable='off' user clicks, but FORCE-CALLS (`cb([],[])`) from tests / automation bypass that. The wrapper inside onPlantLogTogglePressed_ inspects `get(src, 'Enable')` and returns early when 'off' — defensive against both force-call paths AND the rare race where the Enable state changes between dispatch and execution."
    - "Cell-of-pairs storage for per-widget hover lifecycle: DashboardEngine.WidgetHovers_ holds {widget, PlantLogWidgetHover} pairs in a cell array. Attach pushes a pair; detach (idempotent + stale-widget sweep) keeps a logical mask + reassigns the cell to its kept subset. MATLAB handle identity (`pair{1} == widget`) is used for matching; Octave's lack of `==` overload is acceptable because the entire hover path is MATLAB-only (function-style tests SKIP cleanly on Octave)."
    - "Public-read + friend-write SetAccess on engine state slots: WidgetHovers_ exposes `SetAccess = {?DashboardEngine, ?FastSenseWidget, ?matlab.unittest.TestCase}` so the engine + widget owner can write while public READ stays open for tests + downstream observers. Mirrors the Plan 01 PlantLogXLimListener_ pattern that emerged as Rule 3 D-LISTENER-SETACCESS."
    - "Tooltip layout single-vs-multi entry branching: showTooltip_ accepts a PlantLogEntry ARRAY (not a single pick). When `numel(picks) == 1`, the layout omits the '-- ts --' decoration and renders a clean two-line header (timestamp + message + metadata stack). When `numel(picks) > 1`, every block gets the '-- ts --' header — Decision E + F from CONTEXT.md."
    - "40-char metadata value truncation via `[val(1:39), char(8230)]`: char(8230) is the Unicode horizontal ellipsis '…'. Renders correctly in MATLAB's uicontrol(text) at default font. Newlines collapsed FIRST (regexprep `[\\r\\n]+` to ' '), THEN length-truncated, so a multi-line value gets a single tooltip row regardless of original line breaks."
    - "Hover-before-selector teardown ordering, mirrored from Phase 1031: DashboardEngine.delete() now tears down WidgetHovers_ BEFORE TimeRangeSelector_. The widget hovers chain WBMFcn the same way the slider hover does; restoring the chained callback while the underlying figure/axes is still alive is the only way to avoid stale-closure callbacks landing on a deleted handle."
    - "char(10) -> newline migration: R2024b checkcode emits CHARTEN on `char(10)`; switched the strjoin separator to `newline` (which returns char(10) but reads more clearly). Minor diagnostics-hygiene improvement, no behavioral change."

key-files:
  created:
    - libs/PlantLog/PlantLogWidgetHover.m
    - tests/Probe_DW_PanelClear.m
    - tests/test_dashboard_layout_plant_log_toggle.m
    - tests/suite/TestDashboardLayoutPlantLogToggle.m
    - tests/test_plant_log_widget_hover.m
    - tests/suite/TestPlantLogWidgetHover.m
  modified:
    - libs/Dashboard/DashboardLayout.m
    - libs/Dashboard/DashboardWidget.m
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/FastSenseWidget.m

key-decisions:
  - "DashboardLayout.addPlantLogToggle adopts PUBLIC method access (not private like addInfoIcon / addDetachButton). Rationale: tests + future Companion / serialization paths need to invoke the rebuild directly (e.g. when ShowPlantLog flips remotely or when the store attaches via Phase 1033's attachPlantLog public API). The existing private methods stayed private because nobody outside the layout calls them; PlantLog inverts this requirement."
  - "Software-level Enable guard inside onPlantLogTogglePressed_ (Task 1 Test 10): uicontrols skip Callback for user clicks when Enable='off', BUT programmatic force-calls (`cb(btn, [])`) bypass that. The wrapper inspects `get(src, 'Enable')` and early-returns 'off' — defensive against test harnesses + future automation that may force-dispatch the callback."
  - "PlantLogWidgetHover constructor signature kept verbatim from PlantLogSliderHover (parentFig, widgetAxes, lookupFn). Renaming SliderAxes -> WidgetAxes is the only signature delta. The diff between the two classes is intentionally minimal to keep the chained-WBM contract diffable; future changes to the throttle / auto-hide / cleanup machinery should land on both classes together."
  - "PlantLogWidgetHover.showTooltip_ accepts an entry ARRAY rather than a single pick (the slider hover takes a single pick). This is the core PLOG-VIZ-07 contract: when overlapping entries land in the 3px hit zone they must stack, sorted ASC. The simulateHoverAt_ test seam mirrors the change — it returns the full entry array within tolerance."
  - "40-char truncation boundary: a value of EXACTLY 40 chars is preserved verbatim; 41+ chars are truncated to 39 chars + char(8230) (Unicode '…') for total final length 40. Boundary verified by Task 2 Test 6 (k40 + k41 metadata struct round-trip)."
  - "WidgetHovers_ uses public-read + friend-write SetAccess so tests can verify lifecycle directly (`pairs = eng.WidgetHovers_`) without needing a Hidden test seam proxy. Mirrors the Plan 01 PlantLogXLimListener_ pattern that grew out of the same need."
  - "WidgetHovers_ teardown in DashboardEngine.delete() lands BEFORE TimeRangeSelector_ teardown — same rule Plan 01 followed for the slider hover. Both hovers chain WBMFcn off the parent figure; the restore must run while the chained-from object (selector for slider, axes for widget) is still alive."
  - "Test widget needs `Description` set so the InfoIconButton renders alongside the L button. Discovered during Task 1 sub-test 8 (reflow three buttons). Easy fix: the test fixture passes `Description='info text so the InfoIconButton renders alongside the L button'`. This documents the InfoIcon chrome contract precisely: it gates on `~isempty(widget.Description)`."
  - "DashboardEngine.render() takes NO arguments — it creates its own figure via `figure(...)`. Initial test design called `eng.render(fig)` with a pre-created figure (misreading the contract); fixed by calling `eng.render()` then capturing `eng.hFigure` and setting Visible='off'."

patterns-established:
  - "Per-widget plant-log overlay UI surface (PLOG-VIZ-05 + PLOG-VIZ-07): L toggle button in the widget button bar (leftmost of three) + chained-WBM hover tooltip with full-metadata content + overlap stacking + 40-char truncation + '+N more' footer. Plan 03 will exercise this surface end-to-end through the DetachedMirror clone + smoke test."
  - "Engine back-reference via DashboardLayout.EngineRef: any future chrome callback that needs the engine context (e.g. detached-widget specific chrome, multi-engine companion routing) can reach the engine through `obj.EngineRef` set at construction. Single-line per-engine init contract."
  - "Idempotent chrome creation pattern: `findobj(parent, 'Tag', T, '-depth', 1)` + try-delete + create. Survives double-creation calls (Task 1 Test 11) AND survives panel re-render sweeps (the protected-tag list in clearPanelControls)."
  - "Cell-of-pairs storage for per-widget secondary state: WidgetHovers_ stores {widget, hover} pairs without depending on widget identity hashing (containers.Map keyed by handle works on MATLAB but not Octave). The cell-of-pairs walk + logical-mask kept-subset reassignment is the cross-runtime-safe shape."

requirements-completed: [PLOG-VIZ-05, PLOG-VIZ-07]

# Metrics
duration: 27min
completed: 2026-05-19
---

# Phase 1032 Plan 02: Toggle Button and Hover Summary

**Per-widget plant-log overlay UI: L toggle button in the widget button bar (leftmost of three, theme-aware pressed-state colors, disabled when no store) + chained-WBM hover tooltip on widget plant-log lines showing timestamp + message + every metadata column with 40-char value truncation and '+N more' overlap-stacking footer -- 12/12 layout tests + 13/13 hover tests pass on MATLAB; Phase 1029-1031 regression intact (Phase 1031 25/25 + Plan 01 20/20 = 45/45; Phase 1029 31/31).**

## Performance

- **Duration:** ~27 min
- **Started:** 2026-05-19T08:27:58Z
- **Completed:** 2026-05-19T08:55:09Z
- **Tasks:** 2 (1 TDD task `L button + chrome reflow + protected tag`, 1 TDD task `PlantLogWidgetHover + engine attach/detach + setShowPlantLog wire-up`)
- **Files created:** 6 (PlantLogWidgetHover.m + Probe_DW_PanelClear.m + 2 function-style test files + 2 class-based suite files)
- **Files modified:** 4 (DashboardLayout.m, DashboardWidget.m, DashboardEngine.m, FastSenseWidget.m)

## Accomplishments

### Task 1 -- L toggle button + three-button chrome reflow + protected tag

- **DashboardLayout.EngineRef public property** -- new back-reference to the owning DashboardEngine, set in the DashboardEngine constructor (`obj.Layout.EngineRef = obj`). Provides the chrome callbacks (currently `addPlantLogToggle`, future ones if needed) with the engine handle.
- **DashboardLayout.addPlantLogToggle(widget, engine)** -- shipped as a public method (intentional access bump vs. the existing private `addInfoIcon` / `addDetachButton`; tests + future Companion/serialization paths need to call it). Creates a 24×24 uicontrol pushbutton with `Tag='PlantLogToggleButton'`, `String='L'`, `FontWeight='bold'`, positioned as the LEFTMOST of the three button-bar buttons (x = barW - 84). Idempotent: deletes any prior tag before creating the new control. Pressed-state colors derived from `theme.MarkerPlantLog` (ON: bg=[0 0 0], fg=[1 1 1]) vs theme defaults (OFF). Disabled with tooltip `'No plant log attached'` when no store is attached.
- **DashboardLayout.onPlantLogTogglePressed_(src, widget, engine)** -- callback wrapper. Calls `widget.setShowPlantLog(~ShowPlantLog, engine)` then rebuilds the button look. Wraps every operation in try/catch + namespaced warning `DashboardLayout:plantLogToggleParentMissing` + best-effort uialert. Software-level `Enable='off'` guard short-circuits force-call paths (defensive against tests / automation that bypass uicontrol's native click filter).
- **DashboardLayout.reflowChrome_** -- extended to re-anchor all THREE buttons on resize: Detach (barW - 24 - 4), Info (barW - 24 - 24 - 4 - 4), PlantLog (barW - 84). Single new branch added inside the existing `if ~isempty(bar) && ishandle(bar(1))` block.
- **DashboardLayout.realizeWidget** -- now invokes `obj.addPlantLogToggle(widget, obj.EngineRef)` for every FastSenseWidget instance, gated behind the existing `needsBar` chrome path.
- **DashboardWidget.clearPanelControls** -- `protectedTags` array extended to include `'PlantLogToggleButton'` so the toggle survives re-render sweeps.
- **DashboardEngine constructor** -- one-line edit: `obj.Layout.EngineRef = obj;` directly after `obj.Layout = DashboardLayout();`. Wires the back-reference.
- Tests: 12/12 function-style + 12/12 class-based PASS on MATLAB; Octave SKIPs cleanly.

### Task 2 -- PlantLogWidgetHover + engine attach/detach + setShowPlantLog wire-up

- **libs/PlantLog/PlantLogWidgetHover.m** (NEW, ~480 LOC) -- chained-WBM hover helper class. Mirrors `PlantLogSliderHover`'s lifecycle exactly, differing only in:
  - Property `SliderAxes` -> `WidgetAxes`
  - `showTooltip_` rewritten for full metadata + overlap stacking + 40-char truncation + '+N more' footer
  - `simulateHoverAt_` returns the FULL entry array within tolerance (not single nearest pick) so stacking lights up
  - Tooltip uipanel initial size `[0 0 320 180]` (wider/taller than the slider hover's `[0 0 240 44]`)
  - Error namespace `PlantLogWidgetHover:invalidInput`
- **DashboardEngine.WidgetHovers_** -- new public-read property (SetAccess friend = `{?DashboardEngine, ?FastSenseWidget, ?matlab.unittest.TestCase}`) storing a cell of `{widget, PlantLogWidgetHover}` pairs.
- **DashboardEngine.attachPlantLogWidgetHover_(widget)** -- friend-restricted method (added inside the existing Plan 01 `methods (Access = {?FastSenseWidget, ?matlab.unittest.TestCase})` block). Lazy-constructs a `PlantLogWidgetHover` parented to the figure ancestor of the widget axes, routing lookup through `obj.lookupPlantLogEntries_` (so subsequent store swaps reflect immediately). Idempotent: tears down any prior hover for the same widget first.
- **DashboardEngine.detachPlantLogWidgetHover_(widget)** -- friend-restricted; tears down the hover for one widget AND sweeps any stale (already-destroyed) widget pairs that linger in `WidgetHovers_`.
- **DashboardEngine.delete()** -- extended to tear down `WidgetHovers_` BEFORE `TimeRangeSelector_` (mirrors Phase 1031's hover-before-selector ordering rule).
- **FastSenseWidget.setShowPlantLog** -- ON branch additionally calls `engine.attachPlantLogWidgetHover_(obj)` (after the listener + refresh); OFF branch additionally calls `engine.detachPlantLogWidgetHover_(obj)` BEFORE the marker clear.
- Tests: 13/13 function-style + 13/13 class-based PASS on MATLAB.

## Task Commits

Each task was committed atomically (TDD: RED test commit, then GREEN feature commit):

1. **RED tests (Task 1)** -- `0f5fd3e` (test): 12-sub-test function-style file + 12-method class-based suite + Probe_DW_PanelClear helper. Intentionally failing until `addPlantLogToggle` ships.
2. **GREEN (Task 1)** -- `4bd65cc` (feat): `addPlantLogToggle` + `onPlantLogTogglePressed_` + `EngineRef` + three-button `reflowChrome_` + `protectedTags` extension + `realizeWidget` invocation. Sub-tests 1-12 pass after this commit.
3. **RED tests (Task 2)** -- `22e279c` (test): 13-sub-test function-style file + 13-method class-based suite. Intentionally failing until `PlantLogWidgetHover` + engine attach/detach + widget wire-up ships.
4. **GREEN (Task 2)** -- `317ebcb` (feat): `PlantLogWidgetHover.m` + `WidgetHovers_` property + `attachPlantLogWidgetHover_` + `detachPlantLogWidgetHover_` + `delete()` teardown extension + `setShowPlantLog` wire-up. Sub-tests 1-13 pass after this commit.

## Files Created/Modified

### Created

- `libs/PlantLog/PlantLogWidgetHover.m` -- ~480 LOC, chained-WBM hover with full-metadata tooltip layout, overlap stacking, 40-char truncation, '+N more' footer.
- `tests/Probe_DW_PanelClear.m` -- test-only DashboardWidget subclass exposing protected `clearPanelControls` static.
- `tests/test_dashboard_layout_plant_log_toggle.m` -- 12 sub-tests (MATLAB-only function-style with Octave SKIP gate).
- `tests/suite/TestDashboardLayoutPlantLogToggle.m` -- 12-method class-based suite.
- `tests/test_plant_log_widget_hover.m` -- 13 sub-tests (MATLAB-only function-style with Octave SKIP gate).
- `tests/suite/TestPlantLogWidgetHover.m` -- 13-method class-based suite.

### Modified

- `libs/Dashboard/DashboardLayout.m` -- `+EngineRef` public property, `+addPlantLogToggle(widget, engine)` + `+onPlantLogTogglePressed_(src, widget, engine)` public methods, `+addPlantLogToggle` invocation inside `realizeWidget`, `+PlantLogToggleButton` re-anchor in `reflowChrome_`. ~125 lines added.
- `libs/Dashboard/DashboardWidget.m` -- `clearPanelControls` `protectedTags` extended with `'PlantLogToggleButton'` + one-line clarifying comment. 3 lines.
- `libs/Dashboard/DashboardEngine.m` -- `+WidgetHovers_` public-read/friend-write property block; `+attachPlantLogWidgetHover_` + `+detachPlantLogWidgetHover_` methods inside the existing friend block; `+WidgetHovers_` teardown loop in `delete()`; one-line `Layout.EngineRef = obj` in constructor. ~95 lines added.
- `libs/Dashboard/FastSenseWidget.m` -- 2 new lines in `setShowPlantLog` (`engine.attachPlantLogWidgetHover_(obj);` and `engine.detachPlantLogWidgetHover_(obj);`).

## Decisions Made

1. **DashboardLayout.addPlantLogToggle is PUBLIC, not private** -- breaking with the addInfoIcon / addDetachButton convention. Tests need to invoke `addPlantLogToggle` directly to verify the idempotent rebuild contract (sub-test 11), and Phase 1033's `attachPlantLog` public API will eventually invoke it remotely too.
2. **Software-level Enable guard inside the callback wrapper** -- uicontrols natively skip Callback on `Enable='off'` user clicks, but force-calls (`cb(btn, [])`) bypass that. The wrapper inspects `get(src, 'Enable')` and returns early when `'off'`. Defensive against tests + future automation. (Required to satisfy sub-test 10.)
3. **PlantLogWidgetHover.simulateHoverAt_ returns an entry ARRAY** -- not a single nearest pick like the slider hover. This is the core PLOG-VIZ-07 contract: overlapping entries within the 3px hit zone must stack as separated blocks. (Tests 8 + 9 enforce.)
4. **40-char truncation boundary: 40 chars preserved, 41+ truncated to 39 + char(8230)** -- the truncated form is `[val(1:39), char(8230)]` for total final length 40. Verified by sub-test 6 with paired k40 + k41 metadata values.
5. **WidgetHovers_ uses public-read + friend-write SetAccess** -- mirrors Plan 01's PlantLogXLimListener_ pattern. Tests verify lifecycle via direct `eng.WidgetHovers_` reads; engine + widget mutate via friend write access.
6. **Cell-of-pairs storage rather than containers.Map** -- `{widget, hover}` pairs in a cell are cross-runtime safe (Octave's containers.Map differs subtly from MATLAB's; handle identity hashing isn't portable). The detach helper walks the cell with a logical mask + reassigns the cell to its kept subset.
7. **char(10) -> newline migration** -- R2024b's checkcode emits CHARTEN on `char(10)`. Switched to `newline` (which returns char(10) but reads more clearly) to keep the new file diagnostics-clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test fixture used a wrong `eng.render(fig)` call**
- **Found during:** Task 1 first test run (sub-test 1)
- **Issue:** Tests called `eng.render(fig)` after constructing their own figure. `DashboardEngine.render()` takes no arguments — it creates its own figure internally. Result: "Too many input arguments" error.
- **Fix:** Tests now call `eng.render()` then capture `eng.hFigure` and set `Visible='off'` on the engine-created figure.
- **Files modified:** `tests/test_dashboard_layout_plant_log_toggle.m`, `tests/suite/TestDashboardLayoutPlantLogToggle.m`
- **Committed in:** `4bd65cc` (Task 1 GREEN; fixture fix bundled with production code so tests went GREEN in one commit).

**2. [Rule 2 - Missing critical functionality] Test fixture widget had no `Description` so InfoIconButton never rendered**
- **Found during:** Task 1 sub-test 8 (`test_reflow_chrome_three_buttons`)
- **Issue:** `realizeWidget` gates `addInfoIcon` on `~isempty(widget.Description)`. Test widget had no Description -> only DetachButton + PlantLogToggleButton rendered; reflow assertion expecting three buttons failed.
- **Fix:** Fixture widget now passes `Description='info text so the InfoIconButton renders alongside the L button'`. Documents the InfoIcon chrome contract explicitly for future test writers.
- **Files modified:** `tests/test_dashboard_layout_plant_log_toggle.m`, `tests/suite/TestDashboardLayoutPlantLogToggle.m`
- **Committed in:** `4bd65cc`.

**3. [Rule 1 - Bug] Test attempted to drive `clearPanelControls` through `NumberWidget.refresh`**
- **Found during:** Task 1 sub-test 9 (`test_clear_panel_controls_protects_toggle`)
- **Issue:** First draft of the test built a `NumberWidget('Title', 'probe', 'Value', 0)` instance to indirectly invoke `clearPanelControls`. `NumberWidget` exposes `ValueFcn` / `StaticValue` — not `Value`. The fixture threw `Unrecognized property 'Value'`.
- **Fix:** Switched the test to use the `Probe_DW_PanelClear` helper class (test-only DashboardWidget subclass that re-exposes the protected `clearPanelControls` static) directly. Cleaner anyway — the test no longer depends on NumberWidget's internals.
- **Files modified:** `tests/test_dashboard_layout_plant_log_toggle.m`, `tests/Probe_DW_PanelClear.m`
- **Committed in:** `4bd65cc`.

**4. [Rule 1 - Bug / diagnostic-hygiene] PlantLogWidgetHover.m carried a stale `%#ok<AGROW>` suppression + a `char(10)` advisory**
- **Found during:** Task 2 GREEN-phase static analysis (`checkcode` post-GREEN run)
- **Issue:** R2024b's checkcode no longer flags AGROW on the `+N more` footer line where the previous draft had `%#ok<AGROW>`. That left an MSNU (suppression-no-longer-needed) warning. Separately, `strjoin(lines, char(10))` triggered CHARTEN (use `newline` instead).
- **Fix:** Removed the stale `%#ok<AGROW>` suppression on line 439; switched `char(10)` to `newline` on the strjoin separator. PlantLogWidgetHover.m now has only 2 pre-existing-style NASGU warnings on `cleanupGuard` -- matching the PlantLogSliderHover baseline exactly.
- **Files modified:** `libs/PlantLog/PlantLogWidgetHover.m`
- **Committed in:** `317ebcb` (Task 2 GREEN; hygiene-fix bundled with the production code so the file ships clean from commit one).

## Performance

- **Duration:** ~27 min (target: 25-35 min; on schedule)
- **Tasks completed:** 2 / 2 (100%)
- **Tests written:** 50 (12 function-style + 12 class-based Task 1; 13 + 13 Task 2)
- **Tests passed:** 50 / 50 on MATLAB
- **Regression integrity:** Phase 1029-1031 + Plan 01 = 67/67 PASS across the v3.1 plant-log suite (TestPlantLogSliderHover, TestPlantLogSliderOverlay, TestFastSenseWidgetPlantLog, TestDashboardLayoutPlantLogToggle, TestPlantLogWidgetHover). Broader Phase 1029-1030 (TestPlantLogStore, TestPlantLogEntry, TestPlantLogReader, TestPlantLogLiveTail, TestPlantLogIntegrationSmoke) = 59/59 PASS. Combined: 126/126.
- **checkcode integrity:**
  - `libs/PlantLog/PlantLogWidgetHover.m`: 2 pre-existing-style NASGU warnings on `cleanupGuard` (matching PlantLogSliderHover baseline) — no NEW Error- or Critical-level diagnostics.
  - `libs/Dashboard/DashboardLayout.m`: 4 pre-existing NASGU/INUSD warnings (unchanged from baseline; line numbers shifted by 1 because the EngineRef property addition adds a single line above the existing `properties` block in their lexical range).
  - `libs/Dashboard/DashboardWidget.m`: no diagnostic changes (the 1-line protectedTags edit didn't move any messages).
  - `libs/Dashboard/DashboardEngine.m`: 22 pre-existing warnings unchanged from baseline; the new methods + property + delete() teardown add zero NEW messages.
  - `libs/Dashboard/FastSenseWidget.m`: 2 pre-existing warnings unchanged; the 2-line setShowPlantLog edits add zero NEW messages.

## Known Stubs

None -- every Plan 02 truth has runtime test coverage; no placeholders or empty data flows. The hover wiring is fully end-to-end: tooltip String content is generated from real PlantLogStore entries via `engine.lookupPlantLogEntries_`, and the engine-side attach/detach lifecycle is exercised through the public `widget.setShowPlantLog(tf, engine)` setter (sub-tests 12 + 13 verify both directions).

## Self-Check: PASSED

- `libs/PlantLog/PlantLogWidgetHover.m`: FOUND
- `libs/Dashboard/DashboardLayout.m`: FOUND, modified (verified via `git diff` + `grep "addPlantLogToggle"` = 4 hits)
- `libs/Dashboard/DashboardWidget.m`: FOUND, modified (verified via `grep "PlantLogToggleButton"` = 1 hit)
- `libs/Dashboard/DashboardEngine.m`: FOUND, modified (verified via `grep "WidgetHovers_"` = 10 hits)
- `libs/Dashboard/FastSenseWidget.m`: FOUND, modified (verified via `grep "attachPlantLogWidgetHover_"` = 1 hit + `detachPlantLogWidgetHover_` = 1 hit)
- `tests/test_dashboard_layout_plant_log_toggle.m`: FOUND
- `tests/suite/TestDashboardLayoutPlantLogToggle.m`: FOUND
- `tests/test_plant_log_widget_hover.m`: FOUND
- `tests/suite/TestPlantLogWidgetHover.m`: FOUND
- `tests/Probe_DW_PanelClear.m`: FOUND
- Commit `0f5fd3e` (Task 1 RED tests): FOUND
- Commit `4bd65cc` (Task 1 GREEN feat): FOUND
- Commit `22e279c` (Task 2 RED tests): FOUND
- Commit `317ebcb` (Task 2 GREEN feat): FOUND
- All Task 1 grep acceptance criteria: PASS
  (`function addPlantLogToggle`=1, `function onPlantLogTogglePressed_`=1, `PlantLogToggleButton` in Layout=10, `PlantLogToggleButton` in Widget=1, `EngineRef`=3, `obj.Layout.EngineRef = obj`=1, `DashboardLayout:plantLogToggleParentMissing`=4, `'L'`=1, `MarkerPlantLog`=2, `barW - 24 - 4 - 24 - 4 - 24 - 4`=2 — all >= plan minima)
- All Task 2 grep acceptance criteria: PASS
  (`classdef PlantLogWidgetHover < handle`=1, `PlantLogWidgetHover:invalidInput`=7, `more entries near this point`=2, `char(8230)`=1, `'-- %s --'`=1, `function attachPlantLogWidgetHover_`=1, `function detachPlantLogWidgetHover_`=1, `WidgetHovers_`=10, attach/detach in Widget=2 — all >= plan minima)
- Test execution on MATLAB: function-style 12 + 13 = 25/25; class-based 12 + 13 = 25/25; total 50/50 PASS
- Regression on Phase 1031: TestPlantLogSliderHover + TestPlantLogSliderOverlay = 25/25 PASS
- Regression on Plan 01: TestFastSenseWidgetPlantLog = 20/20 PASS
- Broader regression: TestPlantLogStore + TestPlantLogEntry + TestPlantLogReader + TestPlantLogLiveTail + TestPlantLogIntegrationSmoke = 59/59 PASS
- checkcode integrity: zero NEW Error- or Critical-level diagnostics on any modified or new production file
