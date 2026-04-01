# Domain Pitfalls

**Domain:** MATLAB dashboard UI — nested layouts, detachable windows, live-mirrored views
**Researched:** 2026-04-01
**Confidence:** HIGH (based on direct codebase analysis of DashboardEngine, GroupWidget, DashboardSerializer, DashboardLayout, DashboardWidget)

---

## Critical Pitfalls

Mistakes that cause rewrites, cascading handle errors, or timer-driven crashes.

---

### Pitfall 1: Detached Figure Timer Orphans

**What goes wrong:** A detached widget spawns a separate `figure` window. If the user closes the detached window without going through a controlled teardown path, the detached widget's handle (`hPanel`, axes handles, etc.) becomes invalid. On the next `DashboardEngine.onLiveTick()`, the engine iterates `obj.Widgets` and calls `refresh()` on the detached widget, which then calls `ishandle()` or `set()` on a deleted handle, producing a cascade of errors or silent silently-broken updates.

**Why it happens:** `DashboardEngine.onLiveTick()` (line 564–612) checks `ishandle(obj.hFigure)` for the main figure but each widget's `refresh()` method is expected to defend its own handles. Existing widgets rely on the fact that their panel lives inside the main figure (so if the main figure is alive, all panels are alive). A detached widget breaks this assumption — it has a lifecycle independent of `obj.hFigure`.

**Consequences:**
- `ishandle` errors logged every `LiveInterval` seconds, eventually flooding the command window.
- If the timer's error handler is not set, MATLAB may silently stop the timer entirely, killing live refresh for the whole dashboard.
- Memory leak: the widget object remains in `obj.Widgets` with no live graphics.

**Prevention:**
- Attach a `CloseRequestFcn` to every detached figure that calls a cleanup method on the mirror widget, which in turn unregisters the mirror from `DashboardEngine`'s refresh loop (or sets a `Detached = false` flag).
- In `onLiveTick`, check a mirror widget's validity before calling `refresh()` — either via an `IsAlive` property or a wrapped `ishandle` test.
- Never rely on handle-validity checks in the widget's own `refresh()` being sufficient — add a guard in the engine loop itself.

**Warning signs:**
- `warning('DashboardEngine:refreshError', ...)` appearing on every tick.
- Detached figure window disappears but no error is thrown (ghost widget in `obj.Widgets`).

**Phase:** Detachable widget implementation phase.

---

### Pitfall 2: Collapsed Group Does Not Reflow the Grid

**What goes wrong:** `GroupWidget.collapse()` sets `Position(4) = 1` and hides `hChildPanel`, but does not trigger `DashboardLayout.reflow()` or any equivalent. The grid leaves a gap at the widget's original vertical extent. Widgets below it do not shift up. The visual result is large dead whitespace between the collapsed group and lower widgets.

**Why it happens:** The existing `collapse()` and `expand()` methods both have `% TODO: call DashboardLayout.reflow()` comments (GroupWidget.m lines 241 and 258). The TODO is explicit: collapse hides content but does not compact the grid.

**Consequences:**
- Collapsible sections provide no screen-real-estate benefit, which is the core use case.
- Expand after collapse may restore the wrong height if rows below shifted in any interim.

**Prevention:**
- Implement grid reflow as part of collapse/expand. This requires GroupWidget to hold a reference to its owning `DashboardEngine` (or the engine wires a callback into GroupWidget, similar to how `DashboardLayout.OnScrollCallback` is wired).
- The cleanest pattern is: GroupWidget triggers a `LayoutChangedFcn` callback, DashboardEngine handles the reflow. This avoids a circular dependency (widget → engine).
- Alternatively, DashboardEngine intercepts collapse/expand by wrapping them in engine-level methods.

**Warning signs:**
- Collapsing a group leaves visible empty space where its content was.
- The `TODO` comments in GroupWidget.m are the in-code warning sign.

**Phase:** Collapsible section implementation (even if GroupWidget already has stub collapse/expand).

---

### Pitfall 3: jsondecode Struct-vs-Cell Inconsistency for Nested Widgets

**What goes wrong:** MATLAB's `jsondecode` converts JSON arrays of objects into struct arrays, not cell arrays. `GroupWidget.fromStruct()` already handles this for the top-level `children` and `tabs` (lines 491–505 and 508–537), but adding new nested structures — e.g., multi-page dashboards where each page contains a widget list — requires the same normalization pattern every time. Forgetting even one level causes `ch{i}` indexing to fail with a struct-indexing error that is hard to trace.

**Why it happens:** `jsondecode` is consistent with the JSON spec (arrays of homogeneous objects become struct arrays for efficiency), but MATLAB user code that expects cell arrays will break silently or loudly depending on how the struct array is accessed.

**Consequences:**
- Serialized dashboards with multi-page or nested group structures fail to load with cryptic indexing errors.
- The failure is load-time, not save-time, so dashboards appear to save correctly then fail on the next session.

**Prevention:**
- Create a single shared helper function (e.g., `DashboardSerializer.normalizeArray(val)`) that converts struct arrays to cell arrays, and call it at every level of `fromStruct` deserialization.
- Write a round-trip test (save → load → compare widget tree) for every new layout type before shipping.

**Warning signs:**
- `fromStruct` method for a new layout type doesn't have the `if isstruct(...)` normalization block.
- Errors like `Subscript indices must either be real positive integers...` when loading a JSON dashboard.

**Phase:** Multi-page dashboard serialization phase; any phase that adds new nested widget structures.

---

### Pitfall 4: Live Mirror Doubles the Refresh Work Per Widget

**What goes wrong:** Detached mirror widgets are live-refreshed independently. If the naive implementation registers each mirror as a new entry in `DashboardEngine.Widgets`, the engine will call `refresh()` on both the original widget and its mirror every tick. For expensive widgets (FastSenseWidget with downsampling, EventTimelineWidget), this doubles rendering work at the cadence of `LiveInterval`, directly degrading dashboard performance.

**Why it happens:** `onLiveTick()` iterates `obj.Widgets` unconditionally for dirty sensor-bound widgets. If mirrors are added to this list, they participate in the same dirty-flag scan.

**Consequences:**
- Dashboard refresh rate slows proportionally to the number of open detached windows.
- Violates the project constraint: "Detached live-mirrored widgets must not degrade dashboard refresh rate."

**Prevention:**
- Mirrors must NOT be added to `DashboardEngine.Widgets`. Instead, maintain a separate `DetachedMirrors` list (or a `MirrorRegistry` on the engine).
- On each live tick, after refreshing the original widget, copy the rendered output (or share the backing data source) to the mirror using a lightweight update path — ideally a `mirror.syncFrom(originalWidget)` call that only redraws without re-fetching data.
- Alternatively, mirrors can subscribe to a post-refresh event on the original widget rather than participating in the engine's timer loop.

**Warning signs:**
- Timer callback takes noticeably longer after detaching a widget.
- `onLiveTick` timing log shows linear increase per open mirror.

**Phase:** Live mirror implementation phase.

---

### Pitfall 5: uipanel Visibility Toggle Does Not Release Underlying Axes Resources

**What goes wrong:** Switching tabs in GroupWidget hides inactive tab panels with `set(panel, 'Visible', 'off')`. In traditional `figure`/`uipanel` MATLAB (not App Designer uifigure), setting a panel's `Visible` to `off` hides it visually but does NOT release or deactivate the axes and graphics objects inside. For tabs containing FastSenseWidget instances, all underlying axes continue to receive `drawnow` flushes and consume memory. For a dashboard with 4 tabs of 5 widgets each, 3x as many axes are alive as the user sees.

**Why it happens:** MATLAB's HG2 (Handle Graphics 2) defers rendering for invisible objects but still allocates their graphics state. This is different from App Designer, where UIAxes behave more like web-style visibility.

**Consequences:**
- Memory consumption scales with total widgets across all tabs, not visible widgets.
- `drawnow` and figure resize callbacks become slower as more invisible axes accumulate.

**Prevention:**
- For widgets inside inactive tabs, call `refresh()` only when the tab becomes active (lazy refresh). Set a `Dirty = true` flag on tab switch rather than maintaining continuous updates for invisible tabs.
- Consider deferring `render()` of inactive tab children until first activation (lazy render), storing widget objects but not creating their graphics until the tab is first shown.

**Warning signs:**
- `whos` in MATLAB shows memory growing proportional to total tab widgets, not visible ones.
- Figure resize operations become noticeably laggy with many tabs.

**Phase:** Tabbed layout implementation phase; visibility and refresh loop integration.

---

### Pitfall 6: Timer Callback Error Silently Stops the Timer

**What goes wrong:** MATLAB timers with `ExecutionMode = 'fixedRate'` stop executing if the callback throws an unhandled error. `DashboardEngine.onLiveTick()` wraps individual widget `refresh()` calls in `try/catch` (lines 585–597), but if an error occurs outside those guards (e.g., in `updateLiveTimeRange()`, `onTimeSlidersChanged()`, or new detached-mirror code), the timer stops without notification to the user. The dashboard appears frozen, with no error in the command window unless `ErrorFcn` is set on the timer.

**Why it happens:** `timer` objects in MATLAB have an `ErrorFcn` property that defaults to empty. Without it, errors thrown by `TimerFcn` are silently swallowed after stopping the timer.

**Consequences:**
- Live mode appears to work (toolbar shows last update time) but data stops updating.
- Bugs in new feature code (detached mirror sync, page-level refresh) are invisible during development.

**Prevention:**
- Set `ErrorFcn` on `LiveTimer` to log the error and attempt a restart or at least display a visible warning.
- Extend the `try/catch` coverage in `onLiveTick` to wrap all new code paths introduced by detached mirrors, tab refresh coordination, and page navigation.

**Warning signs:**
- Dashboard stops updating but no error is shown.
- `DashboardEngine.LiveTimer` is not empty but `isrunning(obj.LiveTimer)` returns false.

**Phase:** Any phase that adds code paths in `onLiveTick` or timer callbacks (detached mirrors, multi-page refresh).

---

## Moderate Pitfalls

---

### Pitfall 7: Info Tooltip Uses Hover on uicontrol — Octave Does Not Support It

**What goes wrong:** The planned widget info tooltip requires a small info icon in the widget header. If implemented using a `uicontrol` with a `TooltipString` property (hover tooltip), this will only work in MATLAB R2020b+. Octave 7+ supports `TooltipString` on some controls but the behavior is inconsistent across platforms (particularly on macOS and Linux where the OS tooltip system differs). A click-driven modal or a text panel that appears on click is more reliable cross-platform.

**Why it happens:** `DashboardWidget.Description` property already exists (base class line 17) and is populated, suggesting tooltip behavior is expected — but the delivery mechanism has not been chosen yet.

**Consequences:**
- Users on Octave see no tooltip even though `Description` is populated.
- On macOS with Octave, `TooltipString` sometimes requires focus change to trigger.

**Prevention:**
- Implement the info icon as a pushbutton. On click, show a small `uipanel` overlay with the description text. This is click-driven, works identically in MATLAB and Octave, and requires no hover-event support.
- Avoid relying on `TooltipString` for primary discoverability; treat it as a secondary hint.

**Warning signs:**
- Testing tooltip on MATLAB Windows passes but Octave macOS shows nothing.

**Phase:** Widget info tooltip implementation phase.

---

### Pitfall 8: Multi-Page Dashboard Breaks the Single-Figure Assumption

**What goes wrong:** `DashboardEngine` assumes exactly one `hFigure`. The render guard at line 135 (`if ~isempty(obj.hFigure) && ishandle(obj.hFigure), return; end`) enforces this. Multi-page navigation that creates/destroys widget panels must work within a single figure — not by creating a new figure per page. If implemented naively as "hide all current panels, show next page's panels," the render guard will block re-renders after page switches because `hFigure` is already set.

**Why it happens:** The guard is designed to prevent double-renders, not to accommodate page switching. It treats "figure exists" as "already rendered."

**Consequences:**
- Page 2 shows blank panels because `render()` returns early without realizing widgets.
- Alternatively, if the guard is bypassed incorrectly, double-renders occur on page 1.

**Prevention:**
- Multi-page must be implemented at the layout level, not by re-calling `render()`. The correct approach is to show/hide widget panels (like tab switching) rather than re-rendering. Each page's widgets are realized once; page navigation toggles their panel visibility.
- Add a `currentPage` concept to `DashboardLayout` and route `isWidgetVisible()` through it so the scroll-realize and dirty-refresh logic respects the active page.

**Warning signs:**
- Page navigation calls `render()` or `rerenderWidgets()` on every switch.
- Blank page 2 on first navigation.

**Phase:** Multi-page dashboard implementation phase.

---

### Pitfall 9: Collapsible Height Restore After Reflow Corruption

**What goes wrong:** `GroupWidget.ExpandedHeight` stores the original `Position(4)` at collapse time. If other widgets are repositioned during a reflow (e.g., another group collapses/expands), `ExpandedHeight` becomes stale — it refers to a grid height that no longer makes sense in the new layout. Calling `expand()` restores a height value that may overlap with other widgets, triggering `resolveOverlap` to push the widget further down, which is not where the user placed it.

**Why it happens:** `ExpandedHeight` is stored as a single integer without any reference to the surrounding layout state. It is purely "what height was it before."

**Consequences:**
- Expand-after-reflow places widgets in wrong positions.
- Repeated collapse/expand cycles drift widgets downward incrementally.

**Prevention:**
- Store the full `Position` vector (not just height) in `ExpandedHeight` (rename to `ExpandedPosition`).
- Only restore `Position` from `ExpandedPosition` if the row is still unoccupied; otherwise, let `resolveOverlap` find the next valid slot.
- Consider making collapse height-agnostic: a collapsed group always occupies 1 row; expand always attempts to restore the saved full position.

**Warning signs:**
- Expanding a group after another group has collapsed leaves widgets in unexpected positions.

**Phase:** Collapsible groups phase, specifically when grid reflow is integrated.

---

### Pitfall 10: Serializer `.m` Export Does Not Reconstruct GroupWidget Children

**What goes wrong:** `DashboardSerializer.save()` generates `.m` script lines for each top-level widget (lines 29–93). For `group` type widgets it emits only the `addWidget('group', ...)` call with the `Label` and `Mode` — it does not emit `addChild()` calls for the children. Loading a saved `.m` file for a dashboard with populated GroupWidgets produces empty groups.

**Why it happens:** The `.m` exporter handles each widget type with a flat `switch` statement. The `group` case (line 83) only serializes the outer widget properties, not the recursive child tree.

**Consequences:**
- Dashboards saved via `.m` export silently lose all GroupWidget content on reload.
- Users who rely on `.m` export for reproducibility get dashboards that look structurally correct but have empty groups.

**Prevention:**
- Extend the `group` case in `DashboardSerializer.save()` to emit `addChild()` calls (or a helper function call) for each child, recursively.
- Add a round-trip test: build a dashboard with a GroupWidget, export to `.m`, execute the `.m`, compare widget trees.

**Warning signs:**
- `.m` export test passes (file writes without error) but loaded dashboard has empty groups.
- No test currently covers GroupWidget `.m` round-trip.

**Phase:** Any phase that adds child structures to GroupWidget (tabs, collapsible groups) and relies on `.m` persistence.

---

## Minor Pitfalls

---

### Pitfall 11: Tab Button Width Formula Breaks for > 6 Tabs

**What goes wrong:** `GroupWidget.renderTabbedChildren()` (line 408) computes tab button width as `min(0.15, 0.9 / nTabs)`. For up to 6 tabs this gives reasonable widths, but for 7+ tabs each button is narrower than 0.15 (≈ 13%) and tab labels are truncated at short string lengths. At 10+ tabs the buttons become unreadably narrow.

**Prevention:** Implement tab overflow — either a scrollable tab bar or a dropdown fallback when tab count exceeds the available header width. Enforce a minimum usable width per tab label length.

**Warning signs:** Tab headers with very short labels or truncated text.

**Phase:** Tabbed layout polishing; add overflow handling before feature is considered complete.

---

### Pitfall 12: Detached Window Theme Does Not Follow Dashboard Theme Changes

**What goes wrong:** If the user switches the dashboard theme (light ↔ dark) via the toolbar after a widget has been detached, the detached figure retains the old theme colors. The original widget in the dashboard re-renders with the new theme; the detached mirror does not.

**Prevention:** Register detached mirrors as theme-change listeners. When `DashboardEngine` applies a theme change (calls `markAllDirty`), it should also push a theme update to all active mirrors.

**Warning signs:** Detached figure appears visually inconsistent with the dashboard after a theme switch.

**Phase:** Detachable widget implementation; wire theme propagation to the mirror registry.

---

### Pitfall 13: `ishandle` Is Expensive in Tight Loops

**What goes wrong:** `DashboardEngine.onLiveTick()` calls `ishandle` on `obj.hFigure` at the top (line 565) and widget code calls it repeatedly inside loops. In MATLAB's traditional HG2 graphics system, `ishandle` on large figure trees is O(1) per call but when called hundreds of times per second (e.g., very short `LiveInterval`) across many widgets and mirrors, the aggregate cost becomes measurable.

**Prevention:** Cache handle validity using the widget's `Realized` flag (already present on DashboardWidget) and only call `ishandle` when `Realized` is true. For the detached mirror registry, invalidate lazily on the tick where `ishandle` first returns false, then remove from the registry — do not check every tick for dead handles in steady state.

**Warning signs:** Profiler shows `ishandle` calls in the top 5 hotspots during live refresh.

**Phase:** Performance optimization pass; not blocking for initial implementation.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Tabbed layout (GroupWidget) | Tab button overflow for many tabs (Pitfall 11) | Cap tabs or implement overflow bar before release |
| Tabbed layout (GroupWidget) | Hidden tab axes consuming memory (Pitfall 5) | Implement lazy render + lazy refresh for inactive tabs |
| Collapsible groups | Grid does not reflow on collapse (Pitfall 2) | Wire `LayoutChangedFcn` callback from GroupWidget to engine |
| Collapsible groups | Height restore corruption after reflow (Pitfall 9) | Store full position vector, not just height |
| Multi-page dashboard | Single-figure render guard blocks page switches (Pitfall 8) | Implement page switching via panel visibility, not re-render |
| Multi-page serialization | `jsondecode` struct-vs-cell normalization missed (Pitfall 3) | Add shared `normalizeArray` helper; write round-trip tests |
| Widget info tooltips | Hover tooltip unreliable on Octave (Pitfall 7) | Use click-driven panel, not `TooltipString` |
| Detachable widgets | Orphan timer callbacks after window close (Pitfall 1) | `CloseRequestFcn` + engine-level guard in `onLiveTick` |
| Live mirror refresh | Mirror doubles refresh work (Pitfall 4) | Separate `DetachedMirrors` list, not added to `obj.Widgets` |
| Live mirror theme sync | Mirror keeps old theme after dashboard theme change (Pitfall 12) | Push theme update through mirror registry |
| Any new `onLiveTick` code | Timer silently stops on error (Pitfall 6) | Set `ErrorFcn`; extend `try/catch` coverage |
| `.m` export with GroupWidget | Children not serialized (Pitfall 10) | Extend `save()` to emit recursive `addChild()` calls |

---

## Sources

- Direct analysis of `libs/Dashboard/DashboardEngine.m` (lines 564–612, 134–164, 630–633)
- Direct analysis of `libs/Dashboard/GroupWidget.m` (lines 241, 258, 386–457, 469–537)
- Direct analysis of `libs/Dashboard/DashboardWidget.m` (lines 12–19, 131–136)
- Direct analysis of `libs/Dashboard/DashboardSerializer.m` (lines 29–93, 104–162)
- Direct analysis of `libs/Dashboard/DashboardLayout.m` (lines 166–200)
- Project requirements: `.planning/PROJECT.md`
- Architecture context: `.planning/codebase/ARCHITECTURE.md`
- Confidence: HIGH — all pitfalls derived from direct codebase evidence, not WebSearch
