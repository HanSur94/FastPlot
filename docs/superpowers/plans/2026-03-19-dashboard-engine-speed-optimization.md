# Dashboard Engine Speed Optimization — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optimize the dashboard engine for live mode (20-40 widgets at 5s intervals) and initial load time, while maintaining R2020b + Octave compatibility.

**Architecture:** Add a dirty-flag system to skip unchanged widgets during live ticks. Replace FastSenseWidget's full-rebuild refresh with incremental `updateData()`. Add viewport culling and staggered rendering to speed initial load. Replace JSON serialization with pure `.m` function files.

**Tech Stack:** MATLAB R2020b / GNU Octave, matlab.unittest framework, no external dependencies.

**Spec:** `docs/superpowers/specs/2026-03-19-dashboard-engine-speed-optimization-design.md`

---

## Task 1: Dirty-Flag System on DashboardWidget

**Files:**
- Modify: `libs/Dashboard/DashboardWidget.m` (properties block lines 11-23, add method)
- Create: `tests/suite/TestDashboardDirtyFlag.m`

- [ ] **Step 1: Write failing test for Dirty property**

Create `tests/suite/TestDashboardDirtyFlag.m`:

```matlab
classdef TestDashboardDirtyFlag < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testNewWidgetIsDirty(testCase)
            w = MockDashboardWidget();
            testCase.verifyTrue(w.Dirty, ...
                'Newly created widget should be dirty');
        end

        function testMarkDirty(testCase)
            w = MockDashboardWidget();
            w.Dirty = false;
            w.markDirty();
            testCase.verifyTrue(w.Dirty);
        end

        function testClearDirty(testCase)
            w = MockDashboardWidget();
            testCase.verifyTrue(w.Dirty);
            w.Dirty = false;
            testCase.verifyFalse(w.Dirty);
        end

        function testRealizedDefaultFalse(testCase)
            w = MockDashboardWidget();
            testCase.verifyFalse(w.Realized, ...
                'Newly created widget should not be realized');
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd tests && octave --eval "addpath('..'); install(); addpath('suite'); result = run_test_file('suite/TestDashboardDirtyFlag.m');"` or in MATLAB: `runtests('tests/suite/TestDashboardDirtyFlag')`

Expected: FAIL — `Dirty` property does not exist.

- [ ] **Step 3: Add Dirty, Realized properties and markDirty() to DashboardWidget**

In `libs/Dashboard/DashboardWidget.m`, add to the public properties block (after line 19):

```matlab
Dirty    = true        % true when widget needs refresh (data changed)
Realized = false       % true after render() has been called
```

Change `hPanel` access from `protected` to `public` (line 21):

```matlab
properties (SetAccess = public)
    hPanel = []
end
```

Add `markDirty()` method (after the existing `delete` method, ~line 68):

```matlab
function markDirty(obj)
%MARKDIRTY Flag this widget as needing a refresh.
    obj.Dirty = true;
end
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardWidget.m tests/suite/TestDashboardDirtyFlag.m
git commit -m "feat(dashboard): add Dirty/Realized properties and markDirty() to DashboardWidget"
```

---

## Task 2: Gate onLiveTick() on Dirty Flag

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m` (onLiveTick lines 539-565, addWidget lines 66-119)
- Modify: `tests/suite/TestDashboardDirtyFlag.m`

- [ ] **Step 1: Write failing test for dirty-gated live tick**

Add to `tests/suite/TestDashboardDirtyFlag.m`:

```matlab
function testLiveTickSkipsCleanWidgets(testCase)
    d = DashboardEngine('DirtyTest');
    d.addWidget('fastsense', 'Title', 'Plot 1', ...
        'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
    d.addWidget('fastsense', 'Title', 'Plot 2', ...
        'Position', [13 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
    d.render();
    testCase.addTeardown(@() close(d.hFigure));

    % After render, widgets are dirty (default). Clear them.
    for i = 1:numel(d.Widgets)
        d.Widgets{i}.Dirty = false;
    end

    % Mark only the first widget dirty
    d.Widgets{1}.markDirty();

    % After live tick, only dirty widget should be cleared
    d.onLiveTick();
    testCase.verifyFalse(d.Widgets{1}.Dirty, ...
        'Refreshed widget should have Dirty cleared');
    % Widget 2 was already clean — it stays clean
    testCase.verifyFalse(d.Widgets{2}.Dirty);
end

function testMarkAllDirty(testCase)
    d = DashboardEngine('DirtyTest');
    d.addWidget('fastsense', 'Title', 'P1', ...
        'Position', [1 1 12 3], 'XData', 1:10, 'YData', rand(1,10));
    d.addWidget('fastsense', 'Title', 'P2', ...
        'Position', [13 1 12 3], 'XData', 1:10, 'YData', rand(1,10));

    for i = 1:numel(d.Widgets)
        d.Widgets{i}.Dirty = false;
    end

    d.markAllDirty();
    for i = 1:numel(d.Widgets)
        testCase.verifyTrue(d.Widgets{i}.Dirty);
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `onLiveTick` doesn't check `Dirty`, `markAllDirty` doesn't exist.

- [ ] **Step 3: Implement dirty-gated onLiveTick and markAllDirty**

In `libs/Dashboard/DashboardEngine.m`:

**Replace `onLiveTick()` (lines 539-565) with:**

```matlab
function onLiveTick(obj)
    if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
        return;
    end

    % Update global time range from live data
    obj.updateLiveTimeRange();

    % Only refresh widgets with dirty flag set
    for i = 1:numel(obj.Widgets)
        if obj.Widgets{i}.Dirty
            try
                obj.Widgets{i}.refresh();
            catch ME
                warning('DashboardEngine:refreshError', ...
                    'Widget "%s" refresh failed: %s', ...
                    obj.Widgets{i}.Title, ME.message);
            end
        end
    end
    obj.LastUpdateTime = now;
    if ~isempty(obj.Toolbar)
        obj.Toolbar.setLastUpdateTime(obj.LastUpdateTime);
    end

    % Re-apply current slider positions to the updated time range
    if ~isempty(obj.hTimeSliderL) && ishandle(obj.hTimeSliderL)
        obj.onTimeSlidersChanged();
    end

    % Clear dirty flags AFTER slider broadcast to avoid re-dirtying
    for i = 1:numel(obj.Widgets)
        obj.Widgets{i}.Dirty = false;
    end
end
```

**Add `markAllDirty()` method** (after `onLiveTick`):

```matlab
function markAllDirty(obj)
%MARKALLDIRTY Flag all widgets as needing refresh.
%   Called on theme change, figure resize, or other global state changes.
    for i = 1:numel(obj.Widgets)
        obj.Widgets{i}.markDirty();
    end
end
```

**IMPORTANT: Move `onLiveTick` to a public methods block.** It is currently inside `methods (Access = private)` (line 401 of DashboardEngine.m). Tests call `d.onLiveTick()` directly, which requires public access. Move `onLiveTick` (and `markAllDirty`) out of the private block into the default public `methods` block. Also move `onResize` (added in Task 6) to the public block.

- [ ] **Step 4: Run test to verify it passes**

Expected: All tests PASS.

- [ ] **Step 5: Also ensure the load() path initializes Dirty=true**

In `DashboardEngine.load()` (line 590-621), after the widget loop that adds widgets, the widgets already default to `Dirty = true` via `DashboardWidget` constructor. Verify this with the existing `testSaveAndLoad` test.

Run all dashboard tests: `runtests('tests/suite/TestDashboardEngine')`

Expected: All existing tests still PASS.

- [ ] **Step 6: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardDirtyFlag.m
git commit -m "feat(dashboard): gate onLiveTick on dirty flag, add markAllDirty"
```

---

## Task 3: FastSenseWidget Incremental Update

**Files:**
- Modify: `libs/Dashboard/FastSenseWidget.m` (add update() method, ~line 95)
- Modify: `libs/Dashboard/DashboardEngine.m` (onLiveTick to call update() for FastSenseWidgets)
- Create: `tests/suite/TestFastSenseWidgetUpdate.m`

- [ ] **Step 1: Write failing test for update() method**

Create `tests/suite/TestFastSenseWidgetUpdate.m`:

```matlab
classdef TestFastSenseWidgetUpdate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testUpdateMethodExists(testCase)
            s = Sensor('T-1', 'Name', 'Temp');
            s.X = 1:100; s.Y = rand(1,100); s.resolve();

            d = DashboardEngine('UpdateTest');
            d.addWidget('fastsense', 'Sensor', s, 'Position', [1 1 24 3]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            w = d.Widgets{1};
            % After render + refresh, FastSenseObj should be rendered
            w.refresh();
            testCase.verifyTrue(w.FastSenseObj.IsRendered);

            % update() should not error when FastSenseObj is rendered
            s.X = 1:200; s.Y = rand(1,200);
            w.update();  % should use FastSenseObj.updateData()
        end

        function testUpdateFallsBackToRefreshWhenNotRendered(testCase)
            s = Sensor('T-2', 'Name', 'Pressure');
            s.X = 1:50; s.Y = rand(1,50); s.resolve();

            w = FastSenseWidget('Sensor', s, 'Position', [1 1 12 3]);
            % FastSenseObj is empty — update() should fall back to refresh()
            % This will be a no-op since hPanel is empty, but should not error
            w.update();
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `update()` method does not exist on FastSenseWidget.

- [ ] **Step 3: Implement update() on FastSenseWidget**

In `libs/Dashboard/FastSenseWidget.m`, add after the `refresh()` method (~after line 148):

```matlab
function update(obj)
%UPDATE Incrementally update sensor data without full axes rebuild.
%   Uses FastSenseObj.updateData() to replace data and re-downsample,
%   avoiding the expensive delete/recreate cycle of refresh().
%   Falls back to refresh() if FastSenseObj is not in a renderable state.
    if isempty(obj.Sensor), return; end
    if isempty(obj.hPanel) || ~ishandle(obj.hPanel)
        return;
    end

    % Use incremental path if FastSenseObj is already rendered
    if ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
        try
            obj.FastSenseObj.updateData(1, obj.Sensor.X, obj.Sensor.Y);
            return;
        catch
            % Fall through to full refresh on any error
        end
    end

    % Fallback: full rebuild
    obj.refresh();
end
```

- [ ] **Step 4: Run test to verify it passes**

Expected: Both tests PASS.

- [ ] **Step 5: Wire onLiveTick to call update() for FastSenseWidgets**

In `libs/Dashboard/DashboardEngine.m`, update the dirty-widget loop in `onLiveTick()`:

Replace:
```matlab
    % Only refresh widgets with dirty flag set
    for i = 1:numel(obj.Widgets)
        if obj.Widgets{i}.Dirty
            try
                obj.Widgets{i}.refresh();
            catch ME
```

With:
```matlab
    % Only refresh widgets with dirty flag set
    for i = 1:numel(obj.Widgets)
        if obj.Widgets{i}.Dirty
            try
                if isa(obj.Widgets{i}, 'FastSenseWidget')
                    obj.Widgets{i}.update();
                else
                    obj.Widgets{i}.refresh();
                end
            catch ME
```

- [ ] **Step 6: Run all dashboard tests**

Run: `runtests('tests/suite/TestDashboardEngine')` and `runtests('tests/suite/TestFastSenseWidgetUpdate')`

Expected: All PASS.

- [ ] **Step 7: Commit**

```bash
git add libs/Dashboard/FastSenseWidget.m libs/Dashboard/DashboardEngine.m tests/suite/TestFastSenseWidgetUpdate.m
git commit -m "feat(dashboard): add incremental update() to FastSenseWidget using updateData()"
```

---

## Task 4: Viewport Culling — OnScrollCallback + VisibleRows

**Files:**
- Modify: `libs/Dashboard/DashboardLayout.m` (add properties, modify onScroll, add computeVisibleRows)
- Modify: `tests/suite/TestDashboardLayout.m`

- [ ] **Step 1: Write failing test for visible row calculation**

Add to `tests/suite/TestDashboardLayout.m` (or create `tests/suite/TestDashboardViewportCulling.m`):

```matlab
classdef TestDashboardViewportCulling < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testOnScrollCallbackProperty(testCase)
            layout = DashboardLayout();
            testCase.verifyEmpty(layout.OnScrollCallback);
        end

        function testVisibleRowsProperty(testCase)
            layout = DashboardLayout();
            testCase.verifyEqual(layout.VisibleRows, [1 Inf]);
        end

        function testComputeVisibleRows(testCase)
            layout = DashboardLayout();
            layout.TotalRows = 20;
            layout.RowHeight = 0.22;
            layout.GapV = 0.015;
            % With these values and scrollVal=1 (top), compute visible rows
            rows = layout.computeVisibleRows(1);
            testCase.verifyGreaterThanOrEqual(rows(1), 1);
            testCase.verifyLessThanOrEqual(rows(2), 20);
        end

        function testIsWidgetVisible(testCase)
            layout = DashboardLayout();
            layout.VisibleRows = [3 8];
            % Widget at row 5, height 2 → rows 5-6, visible
            testCase.verifyTrue(layout.isWidgetVisible([1 5 6 2], 2));
            % Widget at row 12, height 2 → rows 12-13, not visible
            testCase.verifyFalse(layout.isWidgetVisible([1 12 6 2], 2));
            % Widget at row 1, height 2 → rows 1-2, within buffer of 2
            testCase.verifyTrue(layout.isWidgetVisible([1 1 6 2], 2));
        end
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `OnScrollCallback`, `VisibleRows`, `computeVisibleRows`, `isWidgetVisible` don't exist.

- [ ] **Step 3: Add properties and methods to DashboardLayout**

In `libs/Dashboard/DashboardLayout.m`:

**Add to public properties (after line 23):**
```matlab
OnScrollCallback = []   % function handle: @(topRow, bottomRow)
VisibleRows      = [1 Inf]  % [topRow bottomRow] currently visible
```

**Add `computeVisibleRows()` method:**
```matlab
function rows = computeVisibleRows(obj, scrollVal)
%COMPUTEVISIBLEROWS Derive visible row range from scroll position.
    cr = obj.canvasRatio();
    if cr <= 1
        rows = [1, obj.TotalRows];
        return;
    end
    canvasY = scrollVal * (1 - cr);
    topOffset = -canvasY;
    cellH = obj.RowHeight / cr;
    gapV = obj.GapV / cr;
    step = cellH + gapV;
    if step <= 0
        rows = [1, obj.TotalRows];
        return;
    end
    topRow = floor(topOffset / step) + 1;
    bottomRow = topRow + floor(1 / step);
    topRow = max(1, topRow);
    bottomRow = min(obj.TotalRows, bottomRow);
    rows = [topRow, bottomRow];
end
```

**Add `isWidgetVisible()` method:**
```matlab
function vis = isWidgetVisible(obj, gridPos, buffer)
%ISWIDGETVISIBLE Check if widget rows overlap visible range + buffer.
    if nargin < 3, buffer = 2; end
    wRow = gridPos(2);
    wHeight = gridPos(4);
    wTop = wRow;
    wBottom = wRow + wHeight - 1;
    vTop = obj.VisibleRows(1) - buffer;
    vBottom = obj.VisibleRows(2) + buffer;
    vis = wBottom >= vTop && wTop <= vBottom;
end
```

**Modify `onScroll()` (lines 278-285) to fire callback and update VisibleRows:**
```matlab
function onScroll(obj, val)
%ONSCROLL Adjust canvas position from scrollbar value.
    cr = obj.canvasRatio();
    if cr <= 1, return; end
    offset = val * (1 - cr);
    set(obj.hCanvas, 'Position', [0, offset, 1, cr]);

    obj.VisibleRows = obj.computeVisibleRows(val);
    if ~isempty(obj.OnScrollCallback)
        obj.OnScrollCallback(obj.VisibleRows(1), obj.VisibleRows(2));
    end
end
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardLayout.m tests/suite/TestDashboardViewportCulling.m
git commit -m "feat(dashboard): add viewport visibility tracking to DashboardLayout"
```

---

## Task 5: Deferred Rendering — allocatePanels / realizeWidget Split

**Files:**
- Modify: `libs/Dashboard/DashboardLayout.m` (split createPanels into allocatePanels + realizeWidget)
- Modify: `libs/Dashboard/DashboardEngine.m` (add onScrollRealize, realizeBatch, wire OnScrollCallback)
- Modify: `tests/suite/TestDashboardViewportCulling.m`

- [ ] **Step 1: Write failing test for deferred rendering**

Add to `tests/suite/TestDashboardViewportCulling.m`:

```matlab
function testAllocatePanelsDoesNotCallRender(testCase)
    d = DashboardEngine('DeferredTest');
    d.addWidget('fastsense', 'Title', 'P1', ...
        'Position', [1 1 24 3], 'XData', 1:10, 'YData', rand(1,10));
    d.addWidget('fastsense', 'Title', 'P2', ...
        'Position', [1 4 24 3], 'XData', 1:10, 'YData', rand(1,10));

    % After render, check that Realized is set on visible widgets
    d.render();
    testCase.addTeardown(@() close(d.hFigure));

    % At least the first visible widgets should be realized
    testCase.verifyTrue(d.Widgets{1}.Realized);
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `Realized` is never set to `true`.

- [ ] **Step 3: Implement allocatePanels and realizeWidget**

In `libs/Dashboard/DashboardLayout.m`:

**Add `allocatePanels()` method** — this is the first half of the current `createPanels()`. It creates uipanels but does NOT call `w.render()`:

```matlab
function allocatePanels(obj, hFigure, widgets, theme)
%ALLOCATEPANELS Create widget panel shells without rendering content.
%   Each widget gets a uipanel with a "Loading..." placeholder.
%   Call realizeWidget() later to render actual content.

    % [Keep all existing createPanels code up to the widget loop]
    % ... viewport, canvas, scrollbar creation stays the same ...

    % Create widget panels on canvas (NO render call)
    for i = 1:numel(widgets)
        w = widgets{i};
        w.ParentTheme = theme;
        pos = obj.computePosition(w.Position);
        hp = uipanel('Parent', obj.hCanvas, ...
            'Units', 'normalized', ...
            'Position', pos, ...
            'BorderType', 'line', ...
            'BorderWidth', theme.WidgetBorderWidth, ...
            'ForegroundColor', theme.WidgetBorderColor, ...
            'BackgroundColor', theme.WidgetBackground);
        w.hPanel = hp;

        % Add placeholder text
        uicontrol('Parent', hp, ...
            'Style', 'text', ...
            'Units', 'normalized', ...
            'Position', [0.05 0.4 0.9 0.2], ...
            'String', [w.Title, ' — Loading...'], ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', theme.WidgetBackground, ...
            'ForegroundColor', theme.TextColor, ...
            'Tag', 'placeholder');
    end

    % Compute initial visible rows
    scrollVal = 1;
    if ~isempty(obj.hScrollbar) && ishandle(obj.hScrollbar)
        scrollVal = get(obj.hScrollbar, 'Value');
    end
    obj.VisibleRows = obj.computeVisibleRows(scrollVal);
end
```

**Add `realizeWidget()` method:**

```matlab
function realizeWidget(obj, widget)
%REALIZEWIDGET Render a single widget into its pre-allocated panel.
    if widget.Realized, return; end
    if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end

    % Remove placeholder
    ph = findobj(widget.hPanel, 'Tag', 'placeholder');
    delete(ph);

    % Render actual content
    widget.render(widget.hPanel);
    widget.Realized = true;
    widget.Dirty = false;
end
```

**Refactor `createPanels()` to call allocatePanels + realize all:**

```matlab
function createPanels(obj, hFigure, widgets, theme)
%CREATEPANELS Create and render all widget panels (legacy path).
    obj.allocatePanels(hFigure, widgets, theme);
    for i = 1:numel(widgets)
        obj.realizeWidget(widgets{i});
    end
end
```

This keeps backward compatibility — `createPanels()` still works as before but now delegates to the new methods.

- [ ] **Step 4: Run all existing dashboard tests to verify nothing broke**

Run: `runtests('tests/suite/TestDashboardEngine')` and `runtests('tests/suite/TestDashboardLayout')`

Expected: All PASS — `createPanels()` behavior unchanged.

- [ ] **Step 5: Implement realizeBatch and onScrollRealize on DashboardEngine**

In `libs/Dashboard/DashboardEngine.m`:

**Add `realizeBatch()` method:**

```matlab
function realizeBatch(obj, batchSize)
%REALIZEBATCH Render widgets in batches with drawnow between.
%   Prioritizes visible widgets first.
    if nargin < 2, batchSize = 5; end

    % Sort widgets: visible first, then buffer zone, then off-screen
    indices = 1:numel(obj.Widgets);
    visible = [];
    offscreen = [];
    for i = indices
        if ~obj.Widgets{i}.Realized
            if obj.Layout.isWidgetVisible(obj.Widgets{i}.Position)
                visible(end+1) = i; %#ok<AGROW>
            else
                offscreen(end+1) = i; %#ok<AGROW>
            end
        end
    end
    order = [visible, offscreen];

    % Realize in batches
    for b = 1:batchSize:numel(order)
        bEnd = min(b + batchSize - 1, numel(order));
        for i = b:bEnd
            obj.Layout.realizeWidget(obj.Widgets{order(i)});
        end
        drawnow;
    end
end
```

**Add `onScrollRealize()` method:**

```matlab
function onScrollRealize(obj, topRow, bottomRow)
%ONSCROLLREALIZE Realize widgets that scroll into view.
    for i = 1:numel(obj.Widgets)
        w = obj.Widgets{i};
        if ~w.Realized && obj.Layout.isWidgetVisible(w.Position)
            obj.Layout.realizeWidget(w);
        end
    end
    drawnow;
end
```

**Modify `render()` (lines 121-148)** to use staggered init:

Replace the call to `obj.Layout.createPanels(...)` with:

```matlab
    obj.Layout.allocatePanels(obj.hFigure, obj.Widgets, themeStruct);
    obj.Layout.OnScrollCallback = @(r1, r2) obj.onScrollRealize(r1, r2);
    obj.realizeBatch(5);
```

- [ ] **Step 6: Update the test and run**

The test from Step 1 should now pass — `d.Widgets{1}.Realized` will be `true` after `render()`.

Run: `runtests('tests/suite/TestDashboardViewportCulling')`

Expected: All PASS.

- [ ] **Step 7: Also gate onLiveTick refresh on Realized + visible**

In `DashboardEngine.onLiveTick()`, update the dirty-widget loop:

```matlab
    for i = 1:numel(obj.Widgets)
        w = obj.Widgets{i};
        if w.Dirty && w.Realized && obj.Layout.isWidgetVisible(w.Position)
            try
                if isa(w, 'FastSenseWidget')
                    w.update();
                else
                    w.refresh();
                end
            catch ME
                warning('DashboardEngine:refreshError', ...
                    'Widget "%s" refresh failed: %s', ...
                    w.Title, ME.message);
            end
        end
    end
```

- [ ] **Step 8: Run full test suite**

Run: `runtests('tests/suite/TestDashboardEngine')`, `runtests('tests/suite/TestDashboardDirtyFlag')`, `runtests('tests/suite/TestDashboardViewportCulling')`

Expected: All PASS.

- [ ] **Step 9: Commit**

```bash
git add libs/Dashboard/DashboardLayout.m libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardViewportCulling.m
git commit -m "feat(dashboard): add viewport culling with deferred rendering and staggered init"
```

---

## Task 6: Add ResizeFcn Hook for Bulk Re-dirty

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m` (render method, add onResize)

- [ ] **Step 1: Write failing test**

Add to `tests/suite/TestDashboardDirtyFlag.m`:

```matlab
function testResizeMarksDirty(testCase)
    d = DashboardEngine('ResizeTest');
    d.addWidget('fastsense', 'Title', 'P1', ...
        'Position', [1 1 24 3], 'XData', 1:10, 'YData', rand(1,10));
    d.render();
    testCase.addTeardown(@() close(d.hFigure));

    % Clear dirty flags
    for i = 1:numel(d.Widgets)
        d.Widgets{i}.Dirty = false;
    end

    % Trigger resize callback
    d.onResize();
    testCase.verifyTrue(d.Widgets{1}.Dirty);
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `onResize()` does not exist.

- [ ] **Step 3: Implement onResize and wire ResizeFcn**

In `libs/Dashboard/DashboardEngine.m`:

**Add `onResize()` method:**

```matlab
function onResize(obj)
%ONRESIZE Handle figure resize: mark all dirty and re-realize visible.
    obj.markAllDirty();
    if ~isempty(obj.Layout)
        obj.realizeBatch(5);
    end
end
```

**In `render()`, add ResizeFcn after figure creation** (after line ~130, the figure creation):

```matlab
    set(obj.hFigure, 'ResizeFcn', @(~,~) obj.onResize());
```

- [ ] **Step 4: Run test to verify it passes**

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m tests/suite/TestDashboardDirtyFlag.m
git commit -m "feat(dashboard): add ResizeFcn hook to mark all widgets dirty on resize"
```

---

## Task 7: Replace JSON Serialization with .m Export

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m` (addWidget return value, load/save methods)
- Modify: `libs/Dashboard/DashboardSerializer.m` (rewrite save/load)
- Create: `tests/suite/TestDashboardMSerializer.m`

- [ ] **Step 1: Make addWidget() return widget handle**

In `libs/Dashboard/DashboardEngine.m`, change the `addWidget` signature (line 66):

From: `function addWidget(obj, type, varargin)`
To: `function w = addWidget(obj, type, varargin)`

No other changes needed — `w` is already the local variable holding the widget.

- [ ] **Step 2: Run existing tests to verify backward compat**

Run: `runtests('tests/suite/TestDashboardEngine')`

Expected: All PASS — callers that ignore return value are unaffected.

- [ ] **Step 3: Write failing test for .m save/load**

Create `tests/suite/TestDashboardMSerializer.m`:

```matlab
classdef TestDashboardMSerializer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testSaveProducesMFile(testCase)
            d = DashboardEngine('SaveTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_save_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2);
            content = fileread(filepath);
            testCase.verifyFalse(isempty(strfind(content, 'DashboardEngine')));
            testCase.verifyFalse(isempty(strfind(content, 'function')));
        end

        function testLoadFromMFile(testCase)
            d = DashboardEngine('LoadTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);
            d.addWidget('number', 'Title', 'RPM', ...
                'Position', [13 1 6 1], 'ValueFcn', @() 42);

            filepath = fullfile(tempdir, 'test_load_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'LoadTest');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(d2.LiveInterval, 3);
            testCase.verifyEqual(numel(d2.Widgets), 2);
        end

        function testAddWidgetReturnsHandle(testCase)
            d = DashboardEngine('ReturnTest');
            w = d.addWidget('number', 'Title', 'RPM', ...
                'Position', [1 1 6 1]);
            testCase.verifyClass(w, 'NumberWidget');
            testCase.verifyEqual(w.Title, 'RPM');
        end
    end
end
```

- [ ] **Step 4: Run test to verify it fails**

Expected: `testSaveProducesMFile` and `testLoadFromMFile` FAIL — `save()` still writes JSON, `load()` still reads JSON.

- [ ] **Step 5: Rewrite DashboardSerializer.save() to emit .m function file**

**IMPORTANT:** The existing `exportScript()` generates a **script** (no `function` wrapper, no return value). `feval` on a script does NOT return a value, so the load path would break. The new `save()` must produce a **function file** with `function d = funcname() ... end` wrapper.

In `libs/Dashboard/DashboardSerializer.m`, replace the `save()` static method (lines 5-27) with a method that writes a function-wrapped `.m` file:

```matlab
function save(config, filepath)
%SAVE Write dashboard config as a MATLAB function file.
%   The output file is a function that returns a DashboardEngine.
%   It can be loaded via feval(funcname).
    [~, funcname] = fileparts(filepath);

    fid = fopen(filepath, 'w');
    if fid == -1
        error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
    end
    cleanup = onCleanup(@() fclose(fid));

    % Function wrapper (required for feval to return a value)
    fprintf(fid, 'function d = %s()\n', funcname);
    fprintf(fid, '%%%s Recreate dashboard.\n', upper(funcname));
    fprintf(fid, '%%   d = %s() returns a DashboardEngine.\n\n', funcname);

    % Engine construction
    fprintf(fid, '    d = DashboardEngine(''%s'');\n', ...
        strrep(config.name, '''', ''''''));
    if isfield(config, 'theme')
        fprintf(fid, '    d.Theme = ''%s'';\n', config.theme);
    end
    if isfield(config, 'liveInterval')
        fprintf(fid, '    d.LiveInterval = %g;\n', config.liveInterval);
    end
    if isfield(config, 'infoFile') && ~isempty(config.infoFile)
        fprintf(fid, '    d.InfoFile = ''%s'';\n', ...
            strrep(config.infoFile, '''', ''''''));
    end
    fprintf(fid, '\n');

    % Widgets — delegate per-widget serialization to existing exportScript helper
    % or write each widget's addWidget call inline
    for i = 1:numel(config.widgets)
        ws = config.widgets{i};
        DashboardSerializer.writeWidgetCall(fid, ws);
    end

    fprintf(fid, 'end\n');
end
```

**Also add a `writeWidgetCall()` helper** (private static method) that writes a single `w = d.addWidget(...)` call for one widget. This can be extracted from the existing `exportScript()` per-widget logic. The key difference from `exportScript()` is: (a) function wrapper, (b) uses `w = d.addWidget(...)` with return value.

**Note:** The exact format of `writeWidgetCall` depends on the existing `exportScript` code. Extract the per-widget fprintf calls from `exportScript()` (lines 136-276), replacing `d.addWidget(` with `w = d.addWidget(` and keeping property assignments as `w.Property = value;`.

- [ ] **Step 6: Rewrite DashboardSerializer.load() to use feval**

In `libs/Dashboard/DashboardSerializer.m`, replace `load()` (lines 29-49) with:

```matlab
function result = load(filepath)
%LOAD Load dashboard from a .m function file.
    if ~exist(filepath, 'file')
        error('DashboardSerializer:fileNotFound', 'File not found: %s', filepath);
    end

    [fdir, funcname, ext] = fileparts(filepath);

    % Legacy JSON support
    if strcmp(ext, '.json')
        result = DashboardSerializer.loadJSON(filepath);
        return;
    end

    % .m function file: use feval
    addpath(fdir);
    cleanupPath = onCleanup(@() rmpath(fdir));
    result = feval(funcname);
end
```

**Keep the old JSON load code as `loadJSON()` for migration:**

```matlab
function config = loadJSON(filepath)
%LOADJSON Legacy: read dashboard config from JSON file.
    fid = fopen(filepath, 'r');
    jsonStr = fread(fid, '*char')';
    fclose(fid);
    config = jsondecode(jsonStr);
    if isstruct(config.widgets)
        wa = config.widgets;
        config.widgets = cell(1, numel(wa));
        for i = 1:numel(wa)
            config.widgets{i} = wa(i);
        end
    end
end
```

- [ ] **Step 7: Update DashboardEngine.load() to handle .m files**

The `DashboardEngine.load()` static method needs to detect `.m` files and handle them differently — when loading `.m`, the script returns a `DashboardEngine` directly (not a config struct):

In `libs/Dashboard/DashboardEngine.m`, update `load()` (lines 590-621):

```matlab
function obj = load(filepath, varargin)
    resolver = [];
    for k = 1:2:numel(varargin)
        if strcmp(varargin{k}, 'SensorResolver')
            resolver = varargin{k+1};
        end
    end

    [~, ~, ext] = fileparts(filepath);

    if strcmp(ext, '.m')
        % .m function file returns a DashboardEngine directly
        [fdir, funcname] = fileparts(filepath);
        addpath(fdir);
        cleanupPath = onCleanup(@() rmpath(fdir));
        obj = feval(funcname);
        obj.FilePath = filepath;
    else
        % Legacy JSON path
        config = DashboardSerializer.load(filepath);
        obj = DashboardEngine(config.name);
        if isfield(config, 'theme')
            obj.Theme = config.theme;
        end
        if isfield(config, 'liveInterval')
            obj.LiveInterval = config.liveInterval;
        end
        obj.FilePath = filepath;
        if isfield(config, 'infoFile')
            obj.InfoFile = config.infoFile;
        end

        widgets = DashboardSerializer.configToWidgets(config, resolver);
        for i = 1:numel(widgets)
            w = widgets{i};
            existingPositions = cell(1, numel(obj.Widgets));
            for j = 1:numel(obj.Widgets)
                existingPositions{j} = obj.Widgets{j}.Position;
            end
            w.Position = obj.Layout.resolveOverlap(w.Position, existingPositions);
            obj.Widgets{end+1} = w;
        end
    end
end
```

- [ ] **Step 8: Run tests**

Run: `runtests('tests/suite/TestDashboardMSerializer')` and `runtests('tests/suite/TestDashboardEngine')`

Expected: All PASS. The existing `testSaveAndLoad` in TestDashboardEngine uses `.json` extension so it exercises the legacy path. The new tests use `.m`.

- [ ] **Step 9: Update existing testSaveAndLoad to use .m**

In `tests/suite/TestDashboardEngine.m`, update `testSaveAndLoad` (line 61-78):

Change: `filepath = fullfile(tempdir, 'test_save_dashboard.json');`
To: `filepath = fullfile(tempdir, 'test_save_dashboard.m');`

Run: `runtests('tests/suite/TestDashboardEngine')`

Expected: All PASS.

- [ ] **Step 10: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m libs/Dashboard/DashboardSerializer.m tests/suite/TestDashboardMSerializer.m tests/suite/TestDashboardEngine.m
git commit -m "feat(dashboard): replace JSON serialization with .m function file format"
```

---

## Task 8: Final Integration Test and Cleanup

**Files:**
- Create: `tests/suite/TestDashboardPerformance.m`
- Run all existing tests

- [ ] **Step 1: Write integration test for full optimized pipeline**

Create `tests/suite/TestDashboardPerformance.m`:

```matlab
classdef TestDashboardPerformance < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testLiveTickOnlyRefreshesDirtyWidgets(testCase)
            d = DashboardEngine('PerfTest');
            for k = 1:10
                d.addWidget('number', 'Title', sprintf('N%d', k), ...
                    'Position', [mod((k-1)*6, 24)+1, ceil(k*6/24), 6, 1], ...
                    'ValueFcn', @() k);
            end
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % Clear all dirty flags
            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            % Mark only 2 of 10 dirty
            d.Widgets{1}.markDirty();
            d.Widgets{5}.markDirty();

            % Live tick should only refresh dirty widgets
            d.onLiveTick();

            % All should be clean after tick
            for i = 1:numel(d.Widgets)
                testCase.verifyFalse(d.Widgets{i}.Dirty);
            end
        end

        function testSaveLoadRoundTripWithMFile(testCase)
            d = DashboardEngine('RoundTrip');
            d.Theme = 'dark';
            d.LiveInterval = 2;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:100, 'YData', rand(1,100));
            d.addWidget('number', 'Title', 'RPM', ...
                'Position', [13 1 6 1]);

            filepath = fullfile(tempdir, 'perf_roundtrip.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'RoundTrip');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(numel(d2.Widgets), 2);
        end
    end
end
```

- [ ] **Step 2: Run the full test suite**

Run: `cd tests && octave --eval "r = run_all_tests(); if r.failed > 0; exit(1); end"` or `runtests('tests/suite')`

Expected: All tests PASS across all test files.

- [ ] **Step 3: Commit**

```bash
git add tests/suite/TestDashboardPerformance.m
git commit -m "test(dashboard): add integration tests for optimized dashboard pipeline"
```

---

## Task 9: Wire markDirty() in Sensor Data-Change Callbacks

**Files:**
- Modify: `libs/Dashboard/FastSenseWidget.m` (wire markDirty when Sensor data changes)
- Modify: `libs/Dashboard/DashboardEngine.m` (wire markDirty in addWidget for sensor-bound widgets)

This task ensures that when a Sensor's data is updated externally, the widget is automatically marked dirty so the next `onLiveTick()` picks it up — without relying on `markAllDirty()`.

- [ ] **Step 1: Wire markDirty in DashboardEngine.addWidget**

In `libs/Dashboard/DashboardEngine.m`, at the end of `addWidget()`, after `obj.Widgets{end+1} = w;`, add:

```matlab
    % Wire sensor data-change listener to mark widget dirty
    if ~isempty(w.Sensor) && isprop(w.Sensor, 'X')
        try
            addlistener(w.Sensor, 'X', 'PostSet', @(~,~) w.markDirty());
        catch
            % Octave may not support addlistener on all properties
        end
    end
```

- [ ] **Step 2: Run all tests**

Run: `runtests('tests/suite/TestDashboardEngine')` and `runtests('tests/suite/TestDashboardDirtyFlag')`

Expected: All PASS.

- [ ] **Step 3: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m libs/Dashboard/FastSenseWidget.m
git commit -m "feat(dashboard): wire sensor data-change callbacks to markDirty"
```
