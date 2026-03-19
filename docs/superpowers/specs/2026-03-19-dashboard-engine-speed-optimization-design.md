# Dashboard Engine Speed Optimization — Design Spec

**Date:** 2026-03-19
**Goal:** Optimize dashboard engine for two scenarios: live mode with 20-40 widgets at ~5s intervals, and initial dashboard load time. Maintain R2020b + Octave compatibility.

---

## 1. Dirty-Flag System

### Problem
`onLiveTick()` calls `refresh()` on every widget regardless of whether its data changed. With 30 widgets and only 5 sensors updating per tick, 25 widgets do unnecessary work.

### Design
- Add `Dirty` property (logical, default `true`) to `DashboardWidget` base class.
- Add `markDirty()` method that sets `Dirty = true`.
- `onLiveTick()` only calls `refresh()` on widgets where `Dirty == true`, then sets `Dirty = false`.

### Dirty triggers (set to `true`)
- Widget created or added to dashboard
- Sensor / DataStore fires data-changed callback
- `setTimeRange()` called on the widget
- Theme change or figure resize (bulk: mark all dirty)
- User edits widget properties in edit mode

### Dirty cleared
- After successful `refresh()` in `onLiveTick()`

### Impact
Live tick drops from N_widgets refreshes to N_dirty updates. With 30 widgets and 5 active sensors: ~6x fewer refreshes per tick.

---

## 2. FastSenseWidget Incremental Update

### Problem
`FastSenseWidget.refresh()` deletes all axes children via `findobj()`, recreates axes, re-instantiates the FastSense object, and re-renders — the most expensive per-widget operation.

### Design
- Add `hLines` cell array property to store line handles from the last render.
- Add `update()` method alongside existing `refresh()`:
  - If axes handle still valid and only data changed: `set(hLine, 'XData', ..., 'YData', ...)` + adjust `XLim`/`YLim`
  - If axes destroyed (resize, theme change): fall back to full `refresh()`
- `onLiveTick()` calls `update()` for dirty FastSenseWidgets instead of `refresh()` when possible.

### Fallback conditions (trigger full refresh)
- Axes handle invalid or deleted
- Theme changed since last render
- Widget panel resized
- First render after realization

### Impact
Data-only updates become O(1) property sets instead of O(N_datapoints) full rebuilds.

---

## 3. Viewport Culling

### Problem
All widgets are rendered on initial load and refreshed on every live tick, even when off-screen in the scrollable viewport.

### Design
- Add `Realized` property (logical, default `false`) to `DashboardWidget`.
- Add `VisibleRows` property to `DashboardLayout`: `[topRow, bottomRow]` derived from scroll position and viewport height.
- A widget is "in view" if its row range overlaps `[topRow - buffer, bottomRow + buffer]` where `buffer = 2` rows.

### Widget lifecycle
- **Not realized, off-screen:** Empty placeholder panel with title + "Loading..." text.
- **Scrolled into view:** Call `render()`, set `Realized = true`.
- **Realized, scrolled out of view:** Keep panel and handles alive, but skip `refresh()` in live mode. Accumulate dirty flag; refresh on scroll-back.

### Key decision: do NOT destroy off-screen widgets
Destroying and recreating is the exact problem being solved. Memory cost of keeping handles is negligible vs render cost.

### Scroll callback
- `DashboardLayout.onScroll()` recalculates `VisibleRows`, realizes newly-visible widgets, marks scroll-back widgets dirty.

### Impact
A 40-widget dashboard with 8 visible: initial render does ~12 widgets (8 + buffer) instead of 40. Live ticks skip 28+ off-screen widgets.

---

## 4. Staggered Initial Load

### Problem
Rendering all visible widgets synchronously blocks the figure for 2-5s on large dashboards.

### Design
- `createPanels()` creates all placeholder panels immediately (cheap empty uipanels with background color), then returns.
- New method `DashboardEngine.realizeBatch(batchSize)` renders widgets in batches of 4-6 with `drawnow` between batches.

### Batch ordering
1. Visible widgets, sorted top-to-bottom, left-to-right
2. Buffer-zone widgets (1-2 rows above/below viewport)
3. Off-screen widgets skipped (viewport culling handles them on scroll)

### Implementation
- Use `drawnow`-in-loop approach (not timer-based) for R2020b + Octave compatibility.
- Each unrealized panel shows widget title + "Loading..." text (lightweight uicontrol), replaced by actual content when realized.

### Impact
User sees dashboard frame + first widgets within ~200ms. Perceived load time drops dramatically even if total render time is similar.

---

## 5. Replace JSON Serialization with Pure .m Export

### Problem
Two serialization paths exist (JSON + .m script export). JSON parsing has Octave quirks with `jsondecode`. Two code paths to maintain.

### Design
The `.m` script becomes the **only** persistence format. A saved dashboard is a valid MATLAB/Octave function that rebuilds the dashboard when executed.

### Export format
```matlab
function d = my_dashboard()
    d = DashboardEngine('My Dashboard');
    d.Theme = 'dark';
    d.LiveInterval = 5;

    w = d.addWidget('fastsense', 'Motor Temp', [1, 1, 12, 3]);
    w.Sensor = mySensorLookup('motor_temp');

    w = d.addWidget('number', 'RPM', [13, 1, 6, 1]);
    w.ValueFcn = @() getCurrentRPM();
    % ... etc
end
```

### Load path
Call `run()` on the `.m` file. The script calls `DashboardEngine` and `addWidget()` — the engine IS the deserializer.

### Changes
- `DashboardSerializer.save()` writes `.m` script (replaces `saveJSON()`)
- `DashboardSerializer.load()` calls `run()` on the `.m` file, returns the engine
- Remove `saveJSON()`, `loadJSON()`, and all JSON parsing code
- Dashboard file extension changes from `.json` to `.m`

### Benefits
- Users can read, edit, version-control dashboards as plain MATLAB code
- No JSON parser dependency
- Dashboards are composable (logic, loops, conditionals)
- One fewer code path to maintain

---

## Implementation Order

Each piece is independently shippable and testable:

1. **Dirty-flag system** — biggest live-mode win, lowest risk
2. **FastSenseWidget incremental update** — biggest per-widget speedup, depends on dirty-flag
3. **Viewport culling** — biggest initial-load win
4. **Staggered init** — polish on top of viewport culling
5. **.m serialization** — independent, can land in parallel with 1-4

## Files Modified

| File | Changes |
|------|---------|
| `DashboardWidget.m` | Add `Dirty`, `Realized` properties, `markDirty()` method |
| `DashboardEngine.m` | Gate `onLiveTick()` on dirty, add `realizeBatch()`, bulk-dirty on theme/resize |
| `FastSenseWidget.m` | Add `update()` path, store `hLines` handles, skip full rebuild when possible |
| `DashboardLayout.m` | Add `VisibleRows` tracking, `onScroll()` realization trigger, staggered init loop |
| `DashboardSerializer.m` | Rewrite to .m-only save/load, remove JSON code |
| Other widgets | Minor: call `markDirty()` in `setTimeRange()` and data callbacks |

## Testing Strategy

- Unit test: dirty flag set/clear lifecycle
- Unit test: viewport visibility calculation
- Integration test: live tick only refreshes dirty widgets (mock timer)
- Integration test: scroll triggers realization of deferred widgets
- Smoke test: existing example dashboards load and render correctly
- Performance test: measure `onLiveTick` duration before/after with 30 widgets

## Backward Compatibility

- All new properties have safe defaults (`Dirty = true`, `Realized = false`)
- Existing dashboards work unchanged — first render marks everything realized
- JSON dashboards will need a one-time migration to `.m` format (provide migration script)
- No new MATLAB version requirements — R2020b + Octave compatible
