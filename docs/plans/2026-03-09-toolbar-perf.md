# Toolbar Rendering Performance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Minimize toolbar rendering time by caching icons and reusing toolbar HG objects across tab switches.

**Architecture:** Add persistent icon cache in `makeIcon`, a static `initIcons` pre-warmer, and a `rebind(target)` method on `FastPlotToolbar` that swaps the logical target without recreating HG objects. `FastPlotDock` keeps one shared toolbar and calls `rebind` on tab switch instead of constructing new toolbars.

**Tech Stack:** MATLAB OOP, uitoolbar/uipushtool/uitoggletool HG objects

---

### Task 1: Add Icon Caching to makeIcon

**Files:**
- Modify: `FastPlotToolbar.m:830-975` (makeIcon static method)

**Step 1: Write the failing test**

Add test to `tests/test_toolbar.m` after the existing `testAllIconNames` block (line 47). This test verifies caching returns the same matrix and includes all icon names.

```matlab
% testIconCaching
icon1 = FastPlotToolbar.makeIcon('grid');
icon2 = FastPlotToolbar.makeIcon('grid');
assert(isequal(icon1, icon2), 'testIconCaching: cached icon should match');

% testAllIconNamesComplete (updated to include metadata and theme)
allNames = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'refresh', 'live', 'metadata', 'theme'};
for i = 1:numel(allNames)
    icon = FastPlotToolbar.makeIcon(allNames{i});
    assert(isequal(size(icon), [16 16 3]), ...
        sprintf('testAllIconNamesComplete: %s', allNames{i}));
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); addpath('tests'); addpath('private'); test_toolbar"`
Expected: PASS (caching test passes trivially since icons are deterministic, but this confirms the baseline)

**Step 3: Add persistent cache to makeIcon**

In `FastPlotToolbar.m`, modify `makeIcon` (line 830) to add a persistent cache at the top of the function:

```matlab
function icon = makeIcon(name)
    persistent cache
    if isempty(cache)
        cache = containers.Map();
    end
    if cache.isKey(name)
        icon = cache(name);
        return;
    end

    % ... existing icon generation code unchanged ...

    cache(name) = icon;
end
```

Wrap: after the `switch` block ends (before the existing `end` of the function), add `cache(name) = icon;`.

**Step 4: Add static initIcons method**

Add a new static method right after `makeIcon` in the `methods (Static)` block:

```matlab
function initIcons()
    %INITICONS Pre-warm the icon cache for all toolbar buttons.
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', ...
             'export', 'refresh', 'live', 'metadata', 'theme'};
    for i = 1:numel(names)
        FastPlotToolbar.makeIcon(names{i});
    end
end
```

**Step 5: Call initIcons at top of createToolbar**

In `createToolbar` (line 270), add as the first line:

```matlab
function createToolbar(obj)
    FastPlotToolbar.initIcons();
    obj.hToolbar = uitoolbar(obj.hFigure);
    % ... rest unchanged ...
end
```

**Step 6: Update testAllIconNames to include metadata and theme**

In `tests/test_toolbar.m` line 42, update the names list:

```matlab
names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export', 'refresh', 'live', 'metadata', 'theme'};
```

**Step 7: Run tests to verify everything passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); addpath('tests'); addpath('private'); test_toolbar"`
Expected: All tests pass

**Step 8: Commit**

```bash
git add FastPlotToolbar.m tests/test_toolbar.m
git commit -m "perf: add persistent icon cache to FastPlotToolbar.makeIcon"
```

---

### Task 2: Add rebind Method to FastPlotToolbar

**Files:**
- Modify: `FastPlotToolbar.m:51-80` (public methods section)

**Step 1: Write the failing test**

Add to `tests/test_toolbar.m` before the final `fprintf`:

```matlab
% testRebind
fp1 = FastPlot();
fp1.addLine(1:100, rand(1,100));
fp1.render();
tb = FastPlotToolbar(fp1);
hToolbar1 = tb.hToolbar;

fp2 = FastPlot();
fp2.addLine(1:50, rand(1,50));
fp2.render();

fig2 = FastPlotFigure(1, 1);
fig2.tile(1).addLine(1:50, rand(1,50));
fig2.renderAll();

tb.rebind(fig2);
assert(tb.hToolbar == hToolbar1, 'testRebind: toolbar handle should be reused');
assert(strcmp(tb.Mode, 'none'), 'testRebind: mode should reset to none');
close(fp1.hFigure);
close(fp2.hFigure);
close(fig2.hFigure);
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); addpath('tests'); addpath('private'); test_toolbar"`
Expected: FAIL with "No method 'rebind'"

**Step 3: Implement rebind method**

Add to `FastPlotToolbar.m` in the `methods (Access = public)` block, after the `setMetadata` method (after line 206):

```matlab
function rebind(obj, target)
    %REBIND Switch toolbar to a new target without recreating HG objects.
    %   tb.rebind(newTarget)
    %
    %   Cleans up any active mode, updates the target and figure
    %   references, and syncs toggle button states.

    % Clean up active interactive mode
    if strcmp(obj.Mode, 'crosshair')
        obj.cleanupCrosshair();
    elseif strcmp(obj.Mode, 'cursor')
        obj.cleanupCursor();
    end
    obj.Mode = 'none';
    set(obj.hCursorBtn, 'State', 'off');
    set(obj.hCrosshairBtn, 'State', 'off');

    % Update target references
    obj.Target = target;
    if isa(target, 'FastPlotFigure')
        obj.hFigure = target.hFigure;
        obj.FastPlots = {};
        for i = 1:numel(target.Tiles)
            if ~isempty(target.Tiles{i})
                obj.FastPlots{end+1} = target.Tiles{i};
            end
        end
    elseif isa(target, 'FastPlot')
        obj.hFigure = target.hFigure;
        obj.FastPlots = {target};
    end

    % Sync toggle states to new target
    if target.LiveIsActive
        set(obj.hLiveBtn, 'State', 'on');
    else
        set(obj.hLiveBtn, 'State', 'off');
    end
    if obj.MetadataEnabled
        setappdata(obj.hFigure, 'FastPlotMetadataEnabled', true);
    end

    % Reinstall datacursor callback
    obj.installDataCursorCallback();
end
```

**Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); addpath('tests'); addpath('private'); test_toolbar"`
Expected: All tests pass

**Step 5: Commit**

```bash
git add FastPlotToolbar.m tests/test_toolbar.m
git commit -m "feat: add rebind method to FastPlotToolbar for handle reuse"
```

---

### Task 3: Update FastPlotDock to Reuse Toolbar

**Files:**
- Modify: `FastPlotDock.m:37` (Tabs struct — remove Toolbar field)
- Modify: `FastPlotDock.m:175` (renderAll — create shared toolbar)
- Modify: `FastPlotDock.m:199-202` (selectTab — rebind instead of create)
- Modify: `FastPlotDock.m:232-238` (removeTab — remove per-tab toolbar cleanup)
- Modify: `FastPlotDock.m:300-304` (undockTab — adjust toolbar deletion)
- Modify: `FastPlotDock.m:456-466` (renderTab — remove toolbar creation)

**Step 1: Add Toolbar property to FastPlotDock**

In `FastPlotDock.m` line 37, remove `'Toolbar'` from the per-tab struct and add a dock-level property. Change line 37:

```matlab
Tabs      = struct('Name', {}, 'Figure', {}, 'Panel', {}, 'IsRendered', {})
```

Add a new property in the `SetAccess = private` block (after line 38):

```matlab
Toolbar   = []         % shared FastPlotToolbar instance
```

**Step 2: Update renderAll to create shared toolbar**

In `FastPlotDock.m` line 174-176, change from per-tab toolbar to shared:

```matlab
% Create shared toolbar, then show tab 1
obj.Toolbar = FastPlotToolbar(obj.Tabs(1).Figure);
obj.selectTab(1);
```

**Step 3: Update render method**

In the `render` method (line 108-138), the toolbar is created lazily in `selectTab`. After updating `selectTab` (next step), this path will create the shared toolbar on first tab selection. Add toolbar creation before `selectTab` in `render`:

After line 129 (`obj.createTabBar();`), before `selectTab`:

```matlab
% Create shared toolbar for first tab
obj.Toolbar = FastPlotToolbar(obj.Tabs(1).Figure);
```

**Step 4: Update selectTab to rebind**

In `FastPlotDock.m` lines 199-202, replace lazy toolbar creation with rebind:

```matlab
% Rebind shared toolbar to new tab
if ~isempty(obj.Toolbar)
    obj.Toolbar.rebind(obj.Tabs(n).Figure);
else
    obj.Toolbar = FastPlotToolbar(obj.Tabs(n).Figure);
end
```

**Step 5: Update removeTab — remove per-tab toolbar cleanup**

In `FastPlotDock.m` lines 232-238, remove the per-tab toolbar deletion block:

```matlab
% Delete toolbar (only exists if tab was rendered)
if obj.Tabs(n).IsRendered
    tb = obj.Tabs(n).Toolbar;
    if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
        delete(tb.hToolbar);
    end
end
```

Replace with: nothing (delete these lines entirely). The shared toolbar persists on the dock figure.

Also update line 96 in `addTab` — remove `obj.Tabs(idx).Toolbar = [];`.

**Step 6: Update undockTab — use shared toolbar**

In `FastPlotDock.m` lines 300-304, replace per-tab toolbar deletion with shared toolbar check. Remove these lines:

```matlab
% Delete the dock's toolbar for this tab
tb = obj.Tabs(n).Toolbar;
if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
    delete(tb.hToolbar);
end
```

The shared toolbar stays on the dock. It will rebind to the next active tab via `selectTab`.

**Step 7: Update renderTab — remove toolbar creation**

In `FastPlotDock.m` lines 456-466, remove toolbar creation from `renderTab`. Change to:

```matlab
function renderTab(obj, idx)
    %RENDERTAB Render a single tab: figure and axes reparenting.
    obj.Tabs(idx).Figure.renderAll();
    obj.reparentAxes(idx);
    obj.Tabs(idx).IsRendered = true;
end
```

**Step 8: Update addTab — remove Toolbar field**

In `FastPlotDock.m` line 96, remove `obj.Tabs(idx).Toolbar = [];` line.

In `renderTab` call within `addTab` (line 102), the toolbar creation was already handled by `renderTab`. After our change, `renderTab` no longer creates toolbars, so no further change needed.

**Step 9: Update delete method — clean up shared toolbar**

In `FastPlotDock.m` `delete` method (line 429-439), add toolbar cleanup:

```matlab
function delete(obj)
    for i = 1:numel(obj.Tabs)
        if ~isempty(obj.Tabs(i).Figure)
            try obj.Tabs(i).Figure.stopLive(); catch; end
        end
    end
    if ~isempty(obj.Toolbar) && ~isempty(obj.Toolbar.hToolbar) && ishandle(obj.Toolbar.hToolbar)
        delete(obj.Toolbar.hToolbar);
    end
    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
        delete(obj.hFigure);
    end
end
```

**Step 10: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); addpath('tests'); addpath('private'); test_toolbar; test_dock"`
Expected: All tests pass

**Step 11: Commit**

```bash
git add FastPlotDock.m
git commit -m "perf: reuse shared toolbar in FastPlotDock instead of per-tab creation"
```

---

### Task 4: Final Verification and Cleanup

**Step 1: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); addpath('tests'); addpath('private'); run_tests"`
Expected: All tests pass

**Step 2: Commit test updates if any remaining**

```bash
git add tests/test_toolbar.m
git commit -m "test: add rebind and icon cache tests, fix testAllIconNames completeness"
```
