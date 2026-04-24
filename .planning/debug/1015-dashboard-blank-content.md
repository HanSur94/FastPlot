---
status: diagnosed
phase: 1015
severity: blocker
created: 2026-04-23T20:00:00Z
updated: 2026-04-23T20:00:00Z
---

## Symptoms

- **Expected:** On `run_demo()` the dashboard figure shows the Overview page populated with widgets (plant.health StatusWidget, reactor.pressure FastSenseWidget, IconCard, ChipBar, Sparkline, NumberWidget, Gauge, MultiStatus, Divider, TextWidget), all live-updating.
- **Actual:** Dashboard figure boots; toolbar, 6-tab PageBar, and From/To time sliders render correctly; "Last update: 19:34:12" shows the live timer is firing; BUT the entire widget content area below the tab bar is solid black / completely empty. Zero widgets visible on Overview. The pre-detached "Reactor Pressure (live)" figure DOES render and updates live in its own window.
- **Errors:** No error dialog. Dashboard silently renders a blank viewport. Live timer most likely emits `DashboardEngine:refreshError` warnings (dead panel handles) to the command window but the UAT report did not capture them.
- **Reproduction:** `install(); ctx = run_demo();` on MATLAB with the 1015-04 `MultiStatusWidget.deriveColor` fix applied (commit 16bd36e). Wait ~5-10 s for the writer to emit samples.
- **Started:** First observed on the UAT re-test for 1015-04 (2026-04-23). Did not surface in the 1015-02 test because the prior MultiStatusWidget crash halted `render()` before the second-viewport bug could be reached.

## Evidence

### Evidence 1 — render() pre-allocation loop destroys the active page's panels

File: `libs/Dashboard/DashboardEngine.m` lines 273-292

```matlab
obj.Layout.allocatePanels(obj.hFigure, obj.activePageWidgets(), themeStruct);  % page 1 (active)
obj.Layout.OnScrollCallback = @(r1, r2) obj.onScrollRealize(r1, r2);
obj.realizeBatch(5);                                                          % render page 1 widgets

% Pre-allocate panels for non-active pages (hidden) ...
if numel(obj.Pages) > 1
    for pgIdx = 1:numel(obj.Pages)
        if pgIdx == obj.ActivePage, continue; end
        pgWidgets = obj.Pages{pgIdx}.Widgets;
        obj.Layout.allocatePanels(obj.hFigure, pgWidgets, themeStruct);        % RE-ENTERS allocatePanels
        for wi = 1:numel(pgWidgets)
            if ~isempty(pgWidgets{wi}.hPanel) && ishandle(pgWidgets{wi}.hPanel)
                set(pgWidgets{wi}.hPanel, 'Visible', 'off');
            end
        end
    end
end
```

File: `libs/Dashboard/DashboardLayout.m` lines 177-299 (allocatePanels body)

```matlab
% Clean up old viewport/canvas/scrollbar
if ~isempty(obj.hViewport) && ishandle(obj.hViewport)
    delete(obj.hViewport);                 %  <-- lines 211-213
end
if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
    delete(obj.hScrollbar);
end
...
% Create viewport (clips content to visible area)
obj.hViewport = uipanel('Parent', hFigure, ...);          %  <-- line 226 (fresh viewport)
...
obj.hCanvas = uipanel('Parent', obj.hViewport, ...);      %  <-- line 244 (fresh canvas parented on new viewport)
...
% Create widget panels on canvas (placeholder only, no render)
for i = 1:numel(widgets)
    ...
    hp = uipanel('Parent', obj.hCanvas, ...);             % widget panels parented on new canvas
    w.hPanel = hp;
    ...
end
```

**Implication:** `allocatePanels` was designed as a ONE-SHOT allocator that also services `reflow()` (line 334). It unconditionally deletes `obj.hViewport` at the top, which cascades a handle-delete to every child widget panel parented on that viewport's canvas.

The loop in `DashboardEngine.render()` calls `allocatePanels` N times (once per page). Sequence with N=6 pages, ActivePage=1:

1. Allocate page 1 → `viewport_v1`, `canvas_v1`; page 1 widget hPanels live.
2. `realizeBatch(5)` → page 1 widgets render into their panels (MultiStatus patches, FastSense axes, StatusWidget uicontrols, etc.) — all parented under `viewport_v1`.
3. Loop iter pgIdx=2: `allocatePanels(page 2 widgets)` → **`delete(hViewport)` destroys `viewport_v1` and EVERY child, including every page-1 hPanel and every rendered child uicontrol/axes.** Creates `viewport_v2` + `canvas_v2`; page 2 widget hPanels live in `canvas_v2`.
4. Hide loop (lines 286-290) sets `Visible='off'` on page 2 panels.
5. Loop iter pgIdx=3: destroys `viewport_v2` → page 2 hPanels dead; `viewport_v3` lives with page 3 panels (then hidden).
6. ...
7. Loop iter pgIdx=6: destroys `viewport_v5` → page 5 hPanels dead; `viewport_v6` lives with page 6 hPanels; page 6 hide loop sets `Visible='off'`.

**Final state:** Only `viewport_v6` exists, parenting page 6's (hidden) widget panels. Page 1's widget `hPanel` references all point to handles that were deleted in step 3. The viewport area is literally empty except for the dashboard background color — which matches "solid black" under the Dark theme.

### Evidence 2 — Realized flag is stale so the live timer "works" but writes nowhere

`DashboardLayout.realizeWidget` calls `widget.markRealized()` (line 314) after `render()`. `DashboardWidget.markRealized` only flips a boolean; it does NOT pin the hPanel handle. After `delete(viewport_v1)` in step 3 above, every page-1 widget still has `Realized=true` and a stale `hPanel` property pointing to a deleted handle.

`DashboardEngine.onLiveTick` (lines 937-1006):
- `ws = obj.activePageWidgets();` → returns page 1 widgets.
- `obj.updateLiveTimeRangeFrom(ws);` → each widget's `getTimeRange()` uses in-object cached fields (e.g., `FastSenseWidget.CachedXMin/Max`), NOT hPanel, so this succeeds and updates `DataTimeRange` to ~posix seconds.
- `w.markDirty()` for any widget with a Tag/Sensor → succeeds.
- `if w.Dirty && w.Realized && Layout.isWidgetVisible(w.Position)` → **`Realized` is still true**, `isWidgetVisible` uses grid rows (in-memory), so the condition passes.
- `w.refresh()` or `w.update()` runs — tries to write to dead handles inside the stale hPanel. Most widgets wrap this in try/catch or the attempted `set()` on an invalid handle raises, caught by the outer `catch ME` at line 964 and emitted as `warning DashboardEngine:refreshError`. Nothing on the dashboard canvas changes.
- `obj.Toolbar.setLastUpdateTime(obj.LastUpdateTime)` — updates the toolbar chrome → this is why "Last update: 19:34:12" advances even though widgets do not.

This explains the user-observed split: chrome ticks, widgets do not.

### Evidence 3 — year 5182 sliders come from posix-seconds being fed to `datestr`

`DashboardEngine.formatTimeVal` (lines 1277-1297):

```matlab
function str = formatTimeVal(~, t)
    % Detect datenum (modern dates are > 700000)
    if t > 700000
        if t > 730000
            str = datestr(t, 'yyyy-mm-dd HH:MM');
        else
            str = datestr(t, 'HH:MM:SS');
        end
    else
        % Raw numeric (seconds, samples, etc.)
        if abs(t) >= 86400
            str = sprintf('%.1f d', t / 86400);
        ...
    end
end
```

The threshold `t > 700000` was designed to discriminate MATLAB datenum (days since year 0000; modern dates 7.3e5-7.5e5) from "raw numeric" values. But posix-epoch seconds are ~1.776e9 on 2026-04-23 — also `> 700000` AND `> 730000` — so they're fed into `datestr(..., 'yyyy-mm-dd HH:MM')` as if they were datenum days. `datestr` does not wrap; a datenum of 1.776e9 days represents a year in the millions, but MATLAB's displayed year is governed by the `yyyy` format which only has ~4 active digits in practice — consistent with the user-observed "5182-03-13" / "5186-05-12" readout (the visible low-order digits of what is internally a huge year value, with the sub-day fraction yielding the HH:MM offset).

Where the posix-seconds come from:
- `FastSenseWidget.CachedXMin/Max` is set from `Tag.getXY()` X values.
- `SensorTag` X values for `reactor.pressure` are written by `IndustrialPlantDataGen` (demo private) which publishes posix-seconds — confirmed by the detached Reactor Pressure window showing `Time axis ~1.776972e9` (posix on the x-axis).
- `DashboardEngine.updateGlobalTimeRange` (lines 823-844) aggregates `getTimeRange()` and stores in `obj.DataTimeRange` verbatim, no conversion.
- `updateTimeLabels(tMin, tMax)` → `formatTimeVal(tMin)` → posix-seconds misinterpreted as datenum → year 5182.

**Note:** The Feedline/Reactor demo helper `tagValueToStatus_` in `buildOverviewPage.m` line 177 explicitly converts `now() - datenum(1970,1,1)` × 86400 to posix-seconds before calling `CompositeTag.valueAt`, confirming the whole Tag/Demo pipeline operates in POSIX seconds. But `DashboardEngine`'s time panel is written for DATENUM (per the `> 700000` heuristic + `datestr` call).

### Evidence 4 — detached Reactor Pressure is immune to the viewport destruction

`DashboardEngine.detachWidget` (lines 759-780) creates a `DetachedMirror` — an independent figure window with its own axes. It does not depend on the original widget's `hPanel`. The `DetachedMirror.tick` method reads `widget.Tag.getXY()` every live-tick and redraws its own axes. This is why the detached figure updates correctly while the in-dashboard FastSenseWidget (dead hPanel) does not.

### Evidence 5 — recent git indicator and state trail

`git status` shows `demo/industrial_plant/private/buildOverviewPage.m` modified (uncommitted) alongside `run_demo.m` — consistent with the UAT iteration path after 1015-04. The 1015-04-SUMMARY documents that `MultiStatusWidget.deriveColor` was fixed; no mention of render()-pre-allocate-pages; this bug pre-existed and was simply unreached until 1015-04 unblocked `render()`.

Commit `b6d8065` ("docs(1015-04): gap closure plan for MultiStatusWidget MonitorTag crash") — 1015-04 scope was strictly `deriveColor`; it did not touch `DashboardEngine.render` or `DashboardLayout.allocatePanels`, so the per-page re-allocation bug was latent the moment multi-page demo dashboards were introduced in 1015-02.

## Hypotheses (ranked)

### H1 (CONFIRMED) — `allocatePanels` destroys the previously-populated viewport on every subsequent call, so `DashboardEngine.render()`'s per-page pre-allocation loop leaves only the LAST page's panels alive, all hidden. The active (Overview) page's panels are dead handles.

Evidence: Direct read of `DashboardLayout.allocatePanels` lines 211-213 + DE render loop 278-292. The pre-allocation strategy was added for `switchPage` O(1) toggling (state decision log: "render() pre-allocates all page panels at startup with non-active pages hidden so switchPage is pure visibility toggle") but `allocatePanels` was never made additive — it still wipes the viewport on every call. This is a single-viewport-vs-N-pages contract mismatch.

Specificity: The identical bug should reproduce any time `numel(Pages) > 1` AND `ActivePage != last page` at render. A one-page demo, or a demo with ActivePage=6, would not show the blank Overview (the active page would coincidentally be the last pre-allocated).

### H2 (CONFIRMED, SECONDARY) — `formatTimeVal`'s "datenum detection" threshold (`t > 700000`) mis-classifies posix epoch seconds as datenum, so From/To labels render as year ~5182.

Evidence: `DashboardEngine.formatTimeVal` + `IndustrialPlantDataGen` emitting posix seconds + detached figure x-axis confirming posix domain. Independent of H1: even after H1 is fixed and the Overview renders, the From/To labels will still read year 5182 unless the formatter is taught about posix-seconds.

### H3 (ELIMINATED) — `realizeBatch` did not realize page-1 widgets.

Counter-evidence: `realizeBatch` is called unconditionally at line 275; its filter is `~ws{i}.Realized`, so on first pass every widget is realized (as long as its `hPanel` is live at call time, which it is). Each page-1 widget is rendered into a live panel — the panel is destroyed later in the pre-allocation loop.

### H4 (ELIMINATED) — Detach of the reactor-pressure FastSense panel cleared some shared state that also voided the other widgets.

Counter-evidence: `detachWidget` (lines 759-780) only appends a `DetachedMirror` to `DetachedMirrors` and does NOT touch `hPanel`. The blank-content symptom reproduces regardless of whether the pre-detach succeeds (buildDashboard.m:46-54 wraps it in try/catch). H1 is sufficient to explain the blankness.

### H5 (ELIMINATED) — The Overview-page widget constructors threw and were silently swallowed, leaving `Pages{1}.Widgets` empty.

Counter-evidence: UAT reports the PageBar shows 6 tabs including Overview. If widget construction had thrown, `buildDashboard.m` would have propagated the error (no try/catch around the build*Page calls) and `run_demo()` would fail before `engine.startLive()`. The UAT shows `Last update: 19:34:12` → live timer is running → render() returned successfully.

## Root Cause

**`DashboardEngine.render()` calls `DashboardLayout.allocatePanels(...)` once per page to pre-allocate panels for fast `switchPage()` visibility toggling, but `allocatePanels` unconditionally deletes `obj.hViewport` at entry (DashboardLayout.m:211-213). Each call therefore destroys the previously-populated page's widget hPanels (they are grandchildren of the viewport). After the loop finishes, only the LAST page's panels remain alive in the current viewport — and they are set `Visible='off'`. The ACTIVE (first) page's hPanels are dangling handles. The viewport is effectively empty, so the content region renders as solid dashboard-background color.**

Compounding secondary bug: `DashboardEngine.formatTimeVal` (line 1277) uses a naive `t > 700000 / t > 730000` heuristic to discriminate MATLAB datenum from "raw numeric". Posix epoch seconds (~1.776e9 on 2026-04-23) pass the heuristic and are fed to `datestr(t, 'yyyy-mm-dd HH:MM')`, which formats a year in the millions — the user sees "5182-03-13 21:51" and "5186-05-12 06:18" on the From/To labels.

These are independent defects — both must be fixed to green Test 1.

## Fix Plan

### Fix 1 (primary, unblocks widget rendering): make multi-page pre-allocation additive

The design intent in state.md is explicit: "render() pre-allocates all page panels at startup with non-active pages hidden so switchPage is pure visibility toggle." `allocatePanels` must be split into a one-shot viewport+canvas setup and a per-page panel allocator that reuses the existing canvas.

**File: `libs/Dashboard/DashboardLayout.m`**

Refactor `allocatePanels` (lines 177-303) into two methods:

1. New private method `ensureViewport(obj, hFigure, theme)` — the current lines 181-268 (up through scrollbar creation + WindowScrollWheelFcn), called exactly once per `render()`. Idempotent: if `hViewport` already exists and is valid, returns without deleting.
2. New/refactored `allocatePanels(obj, hFigure, widgets, theme)` — body becomes just lines 270-299 (the per-widget uipanel+placeholder creation loop) + `obj.VisibleRows` update. It no longer touches viewport/canvas/scrollbar. Calls `ensureViewport` defensively if no viewport exists yet (first call).

Additionally: the `obj.TotalRows = obj.calculateMaxRow(widgets)` computation at line 189 is currently scoped to only the widgets in this call. After the split, accumulate total rows across ALL calls, or — simpler — have `DashboardEngine.render()` pass the union of all page widgets to `calculateMaxRow` once before the per-page allocate loop. Specific change:

```matlab
% In DashboardLayout.allocatePanels, change line 189 from:
%   obj.TotalRows = obj.calculateMaxRow(widgets);
% to:
obj.TotalRows = max(obj.TotalRows, obj.calculateMaxRow(widgets));
```

And reset `obj.TotalRows = 0` inside the new `ensureViewport` at first-time init.

**File: `libs/Dashboard/DashboardEngine.m`**

Change `render()` (lines 269-295) so it calls `ensureViewport` once then allocates every page into the same canvas:

```matlab
obj.Layout.ContentArea = [0, obj.TimePanelHeight, ...
    1, 1 - toolbarH - pageBarH - obj.TimePanelHeight];
obj.Layout.DetachCallback = @(w) obj.detachWidget(w);
obj.Layout.ensureViewport(obj.hFigure, themeStruct);    % NEW: one-shot

% Allocate the active page first, then all non-active pages into the SAME canvas
obj.Layout.allocatePanels(obj.hFigure, obj.activePageWidgets(), themeStruct);
obj.Layout.OnScrollCallback = @(r1, r2) obj.onScrollRealize(r1, r2);
obj.realizeBatch(5);

if numel(obj.Pages) > 1
    for pgIdx = 1:numel(obj.Pages)
        if pgIdx == obj.ActivePage, continue; end
        pgWidgets = obj.Pages{pgIdx}.Widgets;
        obj.Layout.allocatePanels(obj.hFigure, pgWidgets, themeStruct);   % additive now
        for wi = 1:numel(pgWidgets)
            if ~isempty(pgWidgets{wi}.hPanel) && ishandle(pgWidgets{wi}.hPanel)
                set(pgWidgets{wi}.hPanel, 'Visible', 'off');
            end
        end
    end
end

obj.updateGlobalTimeRange();
```

Also audit `DashboardLayout.reflow` (line 334, calls `createPanels` which calls `allocatePanels`) — if it is used mid-life to rebuild a single page's layout, it needs to pass ALL pages' widgets in multi-page mode (or be updated to also loop). Current single-page callers (`reflowAfterCollapse` → `rerenderWidgets`) bypass `reflow` entirely, so this is low-risk, but verify by grep.

Grep confirmation after the change:
- `grep -n "delete(obj.hViewport)" libs/Dashboard/DashboardLayout.m` — should appear ONLY inside `ensureViewport`'s not-yet-initialised branch, and `rerenderWidgets`/`createPanels` paths that are explicit single-shot resets.
- Add regression test in `tests/suite/TestDashboardEngine.m` (or new `test_multipage_render_preserves_active_panels.m`) that asserts, after `render()` on a 3-page dashboard with ActivePage=1, every page-1 widget's `hPanel` is a valid handle.

### Fix 2 (secondary, corrects From/To labels): unit-aware time formatter

**File: `libs/Dashboard/DashboardEngine.m`, `formatTimeVal` method (lines 1277-1297)**

The `> 700000` datenum heuristic is insufficient once posix epoch seconds enter the pipeline. Two options:

**Option A (recommended, minimal):** Explicitly detect posix epoch seconds by bracketing modern posix ranges. Posix for year 2000 = 946684800 (~9.47e8); for year 2100 = 4102444800 (~4.10e9). Modern datenum is 730000-750000.

```matlab
function str = formatTimeVal(~, t)
    if t > 9e8 && t < 5e9
        % Posix epoch seconds (year ~2000 - 2128)
        str = datestr(datenum(1970,1,1,0,0,0) + t/86400, 'yyyy-mm-dd HH:MM');
    elseif t > 700000
        % MATLAB datenum
        if t > 730000
            str = datestr(t, 'yyyy-mm-dd HH:MM');
        else
            str = datestr(t, 'HH:MM:SS');
        end
    else
        if abs(t) >= 86400
            str = sprintf('%.1f d', t / 86400);
        elseif abs(t) >= 3600
            str = sprintf('%.1f h', t / 3600);
        elseif abs(t) >= 60
            str = sprintf('%.1f m', t / 60);
        else
            str = sprintf('%.1f s', t);
        end
    end
end
```

Order matters: posix bracket must be tested BEFORE the datenum bracket because any posix value > 9e8 is also > 700000.

**Option B (cleaner, bigger change):** Introduce a `TimeFormat` property on `DashboardEngine` (`'auto' | 'posix' | 'datenum' | 'seconds'`) and have `FastSenseWidget.getTimeRange` advertise its unit so `DashboardEngine` can disambiguate deterministically. Defer to a follow-up plan; Option A is sufficient to unblock UAT Test 1.

Regression test:
- `test_format_time_val_posix.m` — asserts `formatTimeVal(1.776e9)` renders as `'2026-04-23 ...'` not as a year > 3000.

### Fix 3 (safety net, optional): live-tick guard against dead panel handles

Even after Fix 1, future regressions that leave a widget with `Realized=true` + dead `hPanel` should not silently accumulate warnings. In `DashboardEngine.onLiveTick` (line 957), add a handle-validity check:

```matlab
if w.Dirty && w.Realized && ishandle(w.hPanel) && obj.Layout.isWidgetVisible(w.Position)
```

and, in the same block, drop `Realized` if the handle is dead so future ticks don't retry forever:

```matlab
if ~ishandle(w.hPanel)
    w.markUnrealized();
end
```

This is belt-and-suspenders; Fix 1 is the actual cure.

### Verification checklist

- [ ] `install(); ctx = run_demo();` on MATLAB renders all Overview widgets visibly within 5 s.
- [ ] Tab-switch to Feed Line, Reactor, Cooling, Events, Diagnostics each shows that page's widgets; returning to Overview still shows widgets (no handle re-destruction).
- [ ] Pre-detached `Reactor Pressure (live)` figure continues to update live.
- [ ] From/To slider labels show `2026-04-23 HH:MM`, not year 5182.
- [ ] Headless suite `tests/run_all_tests.m` stays green (77/78 baseline, plus the new regression tests).
- [ ] No repeated `DashboardEngine:refreshError` warnings during a 60 s live session.
