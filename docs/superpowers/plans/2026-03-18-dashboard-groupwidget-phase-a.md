# GroupWidget (Phase A) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a GroupWidget container to the dashboard that supports panel, collapsible, and tabbed modes for organizing child widgets.

**Architecture:** GroupWidget extends DashboardWidget, occupies a grid position like any widget, and creates a child sub-layout inside its panel. Children auto-flow or use explicit positions. Collapsible mode mutates Position(4) and triggers layout reflow. Tabbed mode manages multiple child sets with tab-switching visibility.

**Tech Stack:** MATLAB/Octave, pure figure-based UI (uipanel, uicontrol, axes), JSON serialization, R2020b compatible.

**Spec:** `docs/superpowers/specs/2026-03-18-dashboard-grouping-and-widgets-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `libs/Dashboard/GroupWidget.m` | GroupWidget class — panel/collapsible/tabbed container |
| Modify | `libs/Dashboard/DashboardEngine.m:66-105` | Add `case 'group'` to `addWidget` switch + update `widgetTypes()` |
| Modify | `libs/Dashboard/DashboardSerializer.m:69-114` | Add `case 'group'` to `configToWidgets` + `exportScript` |
| Modify | `libs/Dashboard/DashboardLayout.m` | Add `reflow()` method and `computeChildPositions()` helper |
| Modify | `libs/Dashboard/DashboardTheme.m:37-103` | Add Group* and Tab* theme fields to all 6 presets |
| Modify | `bridge/web/js/widgets.js` | Add `group` type dispatcher |
| Modify | `bridge/web/js/dashboard.js` | Add CSS grid nesting for group containers |
| Create | `tests/suite/TestGroupWidget.m` | Unit + integration tests for GroupWidget |

---

## Chunk 1: Core GroupWidget — Panel Mode

### Task 1: Scaffold GroupWidget and write panel-mode construction tests

**Files:**
- Create: `libs/Dashboard/GroupWidget.m`
- Create: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing tests for GroupWidget construction and panel mode**

```matlab
classdef TestGroupWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultConstruction(testCase)
            g = GroupWidget();
            testCase.verifyEqual(g.Mode, 'panel');
            testCase.verifyEqual(g.Label, '');
            testCase.verifyEqual(g.Collapsed, false);
            testCase.verifyEqual(g.Children, {});
            testCase.verifyEqual(g.Tabs, {});
            testCase.verifyEqual(g.ActiveTab, '');
            testCase.verifyEqual(g.ChildColumns, 24);
            testCase.verifyEqual(g.ChildAutoFlow, true);
            testCase.verifyEqual(g.getType(), 'group');
        end

        function testConstructionWithNameValue(testCase)
            g = GroupWidget('Label', 'Motor Health', 'Mode', 'panel');
            testCase.verifyEqual(g.Label, 'Motor Health');
            testCase.verifyEqual(g.Mode, 'panel');
        end

        function testAddChild(testCase)
            g = GroupWidget('Label', 'Test');
            m1 = MockDashboardWidget('Title', 'W1');
            m2 = MockDashboardWidget('Title', 'W2');
            g.addChild(m1);
            g.addChild(m2);
            testCase.verifyLength(g.Children, 2);
            testCase.verifyEqual(g.Children{1}.Title, 'W1');
            testCase.verifyEqual(g.Children{2}.Title, 'W2');
        end

        function testRemoveChild(testCase)
            g = GroupWidget('Label', 'Test');
            g.addChild(MockDashboardWidget('Title', 'W1'));
            g.addChild(MockDashboardWidget('Title', 'W2'));
            g.removeChild(1);
            testCase.verifyLength(g.Children, 1);
            testCase.verifyEqual(g.Children{1}.Title, 'W2');
        end
    end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"` (or Octave equivalent)
Expected: FAIL — GroupWidget class not found

- [ ] **Step 3: Write minimal GroupWidget class — construction, addChild, removeChild**

```matlab
classdef GroupWidget < DashboardWidget
    properties (Access = public)
        Mode          = 'panel'    % 'panel', 'collapsible', 'tabbed'
        Label         = ''         % Title shown in header bar
        Collapsed     = false      % Collapsed state (collapsible mode only)
        Children      = {}         % Cell array of DashboardWidget (panel/collapsible)
        Tabs          = {}         % Cell array of struct('name','...','widgets',{{}})
        ActiveTab     = ''         % Current tab name (tabbed mode)
        ChildColumns  = 24         % Sub-grid column count
        ChildAutoFlow = true       % Auto-arrange children
        ExpandedHeight = []        % Stores original Position(4) when collapsed
    end

    properties (Access = protected)
        hHeader       = []         % Header bar uipanel
        hChildPanel   = []         % Child content area uipanel
        hTabButtons   = {}         % Tab button handles (tabbed mode)
        hChildPanels  = {}         % Per-child uipanel handles
    end

    methods
        function obj = GroupWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            % Default position: wide, medium height
            if nargin == 0 || ~any(strcmp(varargin(1:2:end), 'Position'))
                obj.Position = [1 1 12 4];
            end
        end

        function addChild(obj, widget, tabName)
            % Check nesting depth: this group's ancestor depth + 1 (for itself)
            % + 1 (for the child) must not exceed 2
            if isa(widget, 'GroupWidget')
                myDepth = obj.ancestorDepth() + 1;  % depth of obj itself
                if myDepth + 1 > 2
                    error('GroupWidget:maxDepth', ...
                        'Maximum nesting depth of 2 exceeded');
                end
                widget.ParentGroup = obj;
            end

            if nargin >= 3 && ~isempty(tabName)
                % Tabbed mode: add to named tab
                idx = obj.findTab(tabName);
                if idx == 0
                    obj.Tabs{end+1} = struct('name', tabName, 'widgets', {{widget}});
                    if isempty(obj.ActiveTab)
                        obj.ActiveTab = tabName;
                    end
                else
                    obj.Tabs{idx}.widgets{end+1} = widget;
                end
            else
                obj.Children{end+1} = widget;
            end
        end

        function removeChild(obj, idx)
            if idx >= 1 && idx <= numel(obj.Children)
                obj.Children(idx) = [];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            % Stub — will be implemented in Task 2
        end

        function refresh(obj)
            % Refresh visible children
            if strcmp(obj.Mode, 'tabbed')
                idx = obj.findTab(obj.ActiveTab);
                if idx > 0
                    for i = 1:numel(obj.Tabs{idx}.widgets)
                        obj.Tabs{idx}.widgets{i}.refresh();
                    end
                end
            else
                for i = 1:numel(obj.Children)
                    obj.Children{i}.refresh();
                end
            end
        end

        function t = getType(obj)
            t = 'group';
        end

        function setTimeRange(obj, tStart, tEnd)
            % Cascade to ALL children (all tabs, not just active)
            % No ismethod guard needed — DashboardWidget base provides setTimeRange
            for i = 1:numel(obj.Children)
                obj.Children{i}.setTimeRange(tStart, tEnd);
            end
            for i = 1:numel(obj.Tabs)
                for j = 1:numel(obj.Tabs{i}.widgets)
                    obj.Tabs{i}.widgets{j}.setTimeRange(tStart, tEnd);
                end
            end
        end
    end

    properties (Access = public)
        ParentGroup   = []         % Reference to parent GroupWidget (if nested)
    end

    methods (Access = protected)
        function d = ancestorDepth(obj)
            % Walk up the parent chain to find how deep this group is nested
            d = 0;
            p = obj.ParentGroup;
            while ~isempty(p)
                d = d + 1;
                p = p.ParentGroup;
            end
        end

        function idx = findTab(obj, name)
            idx = 0;
            for i = 1:numel(obj.Tabs)
                if strcmp(obj.Tabs{i}.name, name)
                    idx = i;
                    return;
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = GroupWidget();
            % Stub — will be implemented in serialization task
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"`
Expected: PASS — all 4 tests green

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GroupWidget.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): scaffold GroupWidget with construction and child management"
```

---

### Task 2: Panel mode rendering

**Files:**
- Modify: `libs/Dashboard/GroupWidget.m` (render method)
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing test for panel mode rendering**

Add to `TestGroupWidget.m`:

```matlab
function testPanelModeRender(testCase)
    g = GroupWidget('Label', 'Motor Health', 'Mode', 'panel');
    g.addChild(MockDashboardWidget('Title', 'W1'));
    g.addChild(MockDashboardWidget('Title', 'W2'));

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    g.ParentTheme = DashboardTheme('dark');
    g.render(hp);

    % Header should exist with label text
    testCase.verifyNotEmpty(g.hHeader);
    testCase.verifyNotEmpty(g.hChildPanel);
    % Children should have been rendered (hPanel set)
    testCase.verifyNotEmpty(g.Children{1}.hPanel);
    testCase.verifyNotEmpty(g.Children{2}.hPanel);
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m', 'ProcedureName', 'testPanelModeRender'); disp(results);"`
Expected: FAIL — hHeader is empty (render is a stub)

- [ ] **Step 3: Implement panel mode render**

Replace the `render` method in `GroupWidget.m`:

```matlab
function render(obj, parentPanel)
    obj.hPanel = parentPanel;
    theme = obj.getTheme();

    % Header bar height as fraction of panel
    headerFrac = 0.12;
    if isempty(obj.Label)
        headerFrac = 0;
    end

    % Get group theme colors (with fallback to widget colors)
    headerBg = obj.getThemeField(theme, 'GroupHeaderBg', [0.20 0.20 0.25]);
    headerFg = obj.getThemeField(theme, 'GroupHeaderFg', [0.92 0.92 0.92]);

    % Create header bar
    if headerFrac > 0
        obj.hHeader = uipanel(parentPanel, ...
            'Units', 'normalized', ...
            'Position', [0 1-headerFrac 1 headerFrac], ...
            'BackgroundColor', headerBg, ...
            'BorderType', 'none');
        uicontrol(obj.hHeader, ...
            'Style', 'text', ...
            'String', obj.Label, ...
            'Units', 'normalized', ...
            'Position', [0.02 0 0.96 1], ...
            'HorizontalAlignment', 'left', ...
            'FontWeight', 'bold', ...
            'FontSize', 11, ...
            'ForegroundColor', headerFg, ...
            'BackgroundColor', headerBg);
    end

    % Create child content area
    obj.hChildPanel = uipanel(parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0 0 1 1-headerFrac], ...
        'BorderType', 'none', ...
        'BackgroundColor', obj.getThemeField(theme, 'WidgetBackground', [0.15 0.15 0.20]));

    % Render children into sub-panels
    obj.renderChildren();
end
```

Add helper methods:

```matlab
function renderChildren(obj)
    % Determine which children to render
    if strcmp(obj.Mode, 'tabbed')
        obj.renderTabbedChildren();
        return;
    end

    children = obj.Children;
    positions = obj.computeChildPositions(children);
    obj.hChildPanels = cell(1, numel(children));

    for i = 1:numel(children)
        pos = positions{i};
        hp = uipanel(obj.hChildPanel, ...
            'Units', 'normalized', ...
            'Position', pos, ...
            'BorderType', 'none');
        children{i}.ParentTheme = obj.getTheme();
        children{i}.render(hp);
        obj.hChildPanels{i} = hp;
    end
end

function positions = computeChildPositions(obj, children)
    n = numel(children);
    positions = cell(1, n);

    if n == 0
        return;
    end

    if obj.ChildAutoFlow
        maxPerRow = min(n, 4);
        colWidth = 1.0 / maxPerRow;
        gap = 0.01;
        for i = 1:n
            col = mod(i-1, maxPerRow);
            row = floor((i-1) / maxPerRow);
            totalRows = ceil(n / maxPerRow);
            rowHeight = 1.0 / totalRows;
            x = col * colWidth + gap/2;
            y = 1 - (row+1) * rowHeight + gap/2;
            w = colWidth - gap;
            h = rowHeight - gap;
            positions{i} = [x y w h];
        end
    else
        % Explicit positioning: use child Position relative to sub-grid
        for i = 1:n
            cp = children{i}.Position;
            x = (cp(1) - 1) / obj.ChildColumns;
            y_top = (cp(2) - 1);
            maxRow = max(cellfun(@(c) c.Position(2) + c.Position(4) - 1, children));
            y = 1 - (cp(2) + cp(4) - 1) / maxRow;
            w = cp(3) / obj.ChildColumns;
            h = cp(4) / maxRow;
            positions{i} = [x y w h];
        end
    end
end
```

Add the `getThemeField` helper:

```matlab
function val = getThemeField(~, theme, field, default)
    if isfield(theme, field)
        val = theme.(field);
    else
        val = default;
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"`
Expected: PASS — all tests green

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GroupWidget.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): implement GroupWidget panel mode rendering"
```

---

### Task 3: DashboardTheme — add group theme fields

**Files:**
- Modify: `libs/Dashboard/DashboardTheme.m:37-103`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing test for group theme fields**

Add to `TestGroupWidget.m`:

```matlab
function testThemeHasGroupFields(testCase)
    presets = {'dark', 'light', 'industrial', 'scientific', 'ocean', 'default'};
    for i = 1:numel(presets)
        theme = DashboardTheme(presets{i});
        testCase.verifyTrue(isfield(theme, 'GroupHeaderBg'), ...
            sprintf('%s missing GroupHeaderBg', presets{i}));
        testCase.verifyTrue(isfield(theme, 'GroupHeaderFg'), ...
            sprintf('%s missing GroupHeaderFg', presets{i}));
        testCase.verifyTrue(isfield(theme, 'GroupBorderColor'), ...
            sprintf('%s missing GroupBorderColor', presets{i}));
        testCase.verifyTrue(isfield(theme, 'TabActiveBg'), ...
            sprintf('%s missing TabActiveBg', presets{i}));
        testCase.verifyTrue(isfield(theme, 'TabInactiveBg'), ...
            sprintf('%s missing TabInactiveBg', presets{i}));
    end
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — fields missing from theme struct

- [ ] **Step 3: Add group fields to DashboardTheme.m**

Add after each existing preset block in `DashboardTheme.m` (inside the switch cases) and in shared defaults. Add these shared defaults after the existing shared fields (around line 95):

```matlab
d.GroupHeaderBg     = [0.20 0.20 0.25];
d.GroupHeaderFg     = [0.92 0.92 0.92];
d.GroupBorderColor  = [0.30 0.30 0.35];
d.TabActiveBg       = [0.20 0.20 0.25];
d.TabInactiveBg     = [0.12 0.12 0.16];
```

Then override per-preset in each `case` block:

**dark:**
```matlab
d.GroupHeaderBg     = [0.16 0.22 0.34];
d.GroupHeaderFg     = [0.95 0.95 0.95];
d.GroupBorderColor  = [0.25 0.30 0.40];
d.TabActiveBg       = [0.16 0.22 0.34];
d.TabInactiveBg     = [0.10 0.12 0.18];
```

**light:**
```matlab
d.GroupHeaderBg     = [0.90 0.92 0.95];
d.GroupHeaderFg     = [0.15 0.15 0.15];
d.GroupBorderColor  = [0.80 0.82 0.85];
d.TabActiveBg       = [0.90 0.92 0.95];
d.TabInactiveBg     = [0.82 0.84 0.88];
```

**industrial:**
```matlab
d.GroupHeaderBg     = [0.22 0.22 0.22];
d.GroupHeaderFg     = [0.90 0.90 0.90];
d.GroupBorderColor  = [0.35 0.35 0.35];
d.TabActiveBg       = [0.22 0.22 0.22];
d.TabInactiveBg     = [0.14 0.14 0.14];
```

**scientific:**
```matlab
d.GroupHeaderBg     = [0.88 0.88 0.86];
d.GroupHeaderFg     = [0.15 0.15 0.20];
d.GroupBorderColor  = [0.80 0.80 0.78];
d.TabActiveBg       = [0.88 0.88 0.86];
d.TabInactiveBg     = [0.94 0.94 0.92];
```

**ocean:**
```matlab
d.GroupHeaderBg     = [0.10 0.22 0.30];
d.GroupHeaderFg     = [0.80 0.95 1.00];
d.GroupBorderColor  = [0.18 0.30 0.40];
d.TabActiveBg       = [0.10 0.22 0.30];
d.TabInactiveBg     = [0.06 0.14 0.22];
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardTheme.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): add group theme fields to all 6 presets"
```

---

## Chunk 2: Collapsible & Tabbed Modes

### Task 4: Collapsible mode — collapse/expand

**Files:**
- Modify: `libs/Dashboard/GroupWidget.m`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing tests for collapsible mode**

Add to `TestGroupWidget.m`:

```matlab
function testCollapsibleModeConstruction(testCase)
    g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
    testCase.verifyEqual(g.Mode, 'collapsible');
    testCase.verifyEqual(g.Collapsed, false);
end

function testCollapseChangesPosition(testCase)
    g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
    g.Position = [1 1 12 4];
    g.collapse();
    testCase.verifyEqual(g.Collapsed, true);
    testCase.verifyEqual(g.Position(4), 1);
    testCase.verifyEqual(g.ExpandedHeight, 4);
end

function testExpandRestoresPosition(testCase)
    g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
    g.Position = [1 1 12 4];
    g.collapse();
    g.expand();
    testCase.verifyEqual(g.Collapsed, false);
    testCase.verifyEqual(g.Position(4), 4);
end

function testCollapseRenderHidesChildren(testCase)
    g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
    g.addChild(MockDashboardWidget('Title', 'W1'));
    g.Position = [1 1 12 4];

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    g.ParentTheme = DashboardTheme('dark');
    g.render(hp);

    testCase.verifyEqual(get(g.hChildPanel, 'Visible'), 'on');
    g.collapse();
    testCase.verifyEqual(get(g.hChildPanel, 'Visible'), 'off');
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — collapse/expand methods not implemented

- [ ] **Step 3: Implement collapse and expand methods**

Add to `GroupWidget.m` public methods:

```matlab
function collapse(obj)
    if ~strcmp(obj.Mode, 'collapsible')
        return;
    end
    if obj.Collapsed
        return;
    end
    obj.ExpandedHeight = obj.Position(4);
    obj.Position(4) = 1;
    obj.Collapsed = true;
    if ~isempty(obj.hChildPanel) && ishandle(obj.hChildPanel)
        set(obj.hChildPanel, 'Visible', 'off');
    end
end

function expand(obj)
    if ~strcmp(obj.Mode, 'collapsible')
        return;
    end
    if ~obj.Collapsed
        return;
    end
    if ~isempty(obj.ExpandedHeight)
        obj.Position(4) = obj.ExpandedHeight;
    end
    obj.Collapsed = false;
    if ~isempty(obj.hChildPanel) && ishandle(obj.hChildPanel)
        set(obj.hChildPanel, 'Visible', 'on');
    end
end
```

Update `render()` to add collapse toggle button in header for collapsible mode:

In the header creation section, after the label uicontrol, add:

```matlab
if strcmp(obj.Mode, 'collapsible')
    btnStr = '▼';
    if obj.Collapsed
        btnStr = '►';
    end
    uicontrol(obj.hHeader, ...
        'Style', 'pushbutton', ...
        'String', btnStr, ...
        'Units', 'normalized', ...
        'Position', [0.92 0.1 0.06 0.8], ...
        'Callback', @(~,~) obj.toggleCollapse(), ...
        'FontSize', 10, ...
        'ForegroundColor', headerFg, ...
        'BackgroundColor', headerBg);
end
```

Add toggle helper:

```matlab
function toggleCollapse(obj)
    if obj.Collapsed
        obj.expand();
    else
        obj.collapse();
    end
end
```

Also in `render()`, if already collapsed, hide the child panel:

```matlab
if obj.Collapsed
    set(obj.hChildPanel, 'Visible', 'off');
end
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GroupWidget.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): implement GroupWidget collapsible mode"
```

---

### Task 5: Tabbed mode — tab switching

**Files:**
- Modify: `libs/Dashboard/GroupWidget.m`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing tests for tabbed mode**

Add to `TestGroupWidget.m`:

```matlab
function testTabbedModeAddChild(testCase)
    g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
    g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
    g.addChild(MockDashboardWidget('Title', 'W2'), 'Overview');
    g.addChild(MockDashboardWidget('Title', 'W3'), 'Detail');

    testCase.verifyLength(g.Tabs, 2);
    testCase.verifyEqual(g.Tabs{1}.name, 'Overview');
    testCase.verifyLength(g.Tabs{1}.widgets, 2);
    testCase.verifyEqual(g.Tabs{2}.name, 'Detail');
    testCase.verifyLength(g.Tabs{2}.widgets, 1);
    testCase.verifyEqual(g.ActiveTab, 'Overview');
end

function testSwitchTab(testCase)
    g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
    g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
    g.addChild(MockDashboardWidget('Title', 'W2'), 'Detail');
    testCase.verifyEqual(g.ActiveTab, 'Overview');
    g.switchTab('Detail');
    testCase.verifyEqual(g.ActiveTab, 'Detail');
end

function testTabbedModeRender(testCase)
    g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
    g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
    g.addChild(MockDashboardWidget('Title', 'W2'), 'Detail');

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    g.ParentTheme = DashboardTheme('dark');
    g.render(hp);

    testCase.verifyNotEmpty(g.hTabButtons);
    testCase.verifyLength(g.hTabButtons, 2);
end

function testZeroTabsRender(testCase)
    g = GroupWidget('Label', 'Empty', 'Mode', 'tabbed');

    fig = figure('Visible', 'off');
    cleanup = onCleanup(@() close(fig));
    hp = uipanel(fig, 'Position', [0 0 1 1]);
    g.ParentTheme = DashboardTheme('dark');
    g.render(hp);

    % Should not error, should render placeholder
    testCase.verifyNotEmpty(g.hHeader);
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — switchTab and tabbed render not implemented

- [ ] **Step 3: Implement tabbed mode render and switchTab**

Add `switchTab` to public methods:

```matlab
function switchTab(obj, tabName)
    if ~strcmp(obj.Mode, 'tabbed')
        return;
    end
    idx = obj.findTab(tabName);
    if idx == 0
        return;
    end
    obj.ActiveTab = tabName;

    % Update visibility of tab content panels
    if ~isempty(obj.hChildPanels)
        for i = 1:numel(obj.hChildPanels)
            if i == idx
                set(obj.hChildPanels{i}, 'Visible', 'on');
            else
                set(obj.hChildPanels{i}, 'Visible', 'off');
            end
        end
    end

    % Update tab button appearance
    if ~isempty(obj.hTabButtons)
        theme = obj.getTheme();
        activeBg = obj.getThemeField(theme, 'TabActiveBg', [0.20 0.20 0.25]);
        inactiveBg = obj.getThemeField(theme, 'TabInactiveBg', [0.12 0.12 0.16]);
        for i = 1:numel(obj.hTabButtons)
            if i == idx
                set(obj.hTabButtons{i}, 'BackgroundColor', activeBg);
            else
                set(obj.hTabButtons{i}, 'BackgroundColor', inactiveBg);
            end
        end
    end
end
```

Add `renderTabbedChildren` method:

```matlab
function renderTabbedChildren(obj)
    theme = obj.getTheme();
    activeBg = obj.getThemeField(theme, 'TabActiveBg', [0.20 0.20 0.25]);
    inactiveBg = obj.getThemeField(theme, 'TabInactiveBg', [0.12 0.12 0.16]);
    headerFg = obj.getThemeField(theme, 'GroupHeaderFg', [0.92 0.92 0.92]);

    nTabs = numel(obj.Tabs);

    if nTabs == 0
        % Render placeholder for empty tabbed group
        uicontrol(obj.hChildPanel, ...
            'Style', 'text', ...
            'String', '(no tabs)', ...
            'Units', 'normalized', ...
            'Position', [0.3 0.4 0.4 0.2], ...
            'HorizontalAlignment', 'center', ...
            'ForegroundColor', [0.5 0.5 0.5], ...
            'BackgroundColor', get(obj.hChildPanel, 'BackgroundColor'));
        return;
    end

    % Create tab buttons in header
    obj.hTabButtons = cell(1, nTabs);
    tabWidth = min(0.15, 0.9 / nTabs);
    for i = 1:nTabs
        isActive = strcmp(obj.Tabs{i}.name, obj.ActiveTab);
        bg = activeBg;
        if ~isActive
            bg = inactiveBg;
        end
        tabName = obj.Tabs{i}.name;
        obj.hTabButtons{i} = uicontrol(obj.hHeader, ...
            'Style', 'pushbutton', ...
            'String', tabName, ...
            'Units', 'normalized', ...
            'Position', [0.02 + (i-1)*tabWidth 0 tabWidth 0.5], ...
            'FontSize', 9, ...
            'ForegroundColor', headerFg, ...
            'BackgroundColor', bg, ...
            'Callback', @(~,~) obj.switchTab(tabName));
    end

    % Create content panel per tab
    obj.hChildPanels = cell(1, nTabs);
    for i = 1:nTabs
        isActive = strcmp(obj.Tabs{i}.name, obj.ActiveTab);
        vis = 'off';
        if isActive
            vis = 'on';
        end
        tabPanel = uipanel(obj.hChildPanel, ...
            'Units', 'normalized', ...
            'Position', [0 0 1 1], ...
            'BorderType', 'none', ...
            'Visible', vis, ...
            'BackgroundColor', get(obj.hChildPanel, 'BackgroundColor'));
        obj.hChildPanels{i} = tabPanel;

        % Render tab's widgets
        widgets = obj.Tabs{i}.widgets;
        positions = obj.computeChildPositions(widgets);
        for j = 1:numel(widgets)
            wp = uipanel(tabPanel, ...
                'Units', 'normalized', ...
                'Position', positions{j}, ...
                'BorderType', 'none');
            widgets{j}.ParentTheme = obj.getTheme();
            widgets{j}.render(wp);
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GroupWidget.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): implement GroupWidget tabbed mode with tab switching"
```

---

### Task 6: Nesting depth enforcement

**Files:**
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing test for nesting depth limit**

Add to `TestGroupWidget.m`:

```matlab
function testNestingDepthLimit(testCase)
    inner = GroupWidget('Label', 'Inner');
    outer = GroupWidget('Label', 'Outer');
    outer.addChild(inner);  % depth = 2, should work

    tooDeep = GroupWidget('Label', 'TooDeep');
    testCase.verifyError(@() inner.addChild(tooDeep), ...
        'GroupWidget:maxDepth');
end

function testNestingDepthAllowsTwo(testCase)
    inner = GroupWidget('Label', 'Inner');
    outer = GroupWidget('Label', 'Outer');
    outer.addChild(inner);  % depth = 2, should not error
    testCase.verifyLength(outer.Children, 1);
end
```

- [ ] **Step 2: Run tests to verify they pass**

The nesting logic was already implemented in Task 1's `addChild` and `nestingDepth`. Run tests to confirm.

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add tests/suite/TestGroupWidget.m
git commit -m "test(dashboard): add nesting depth enforcement tests for GroupWidget"
```

---

## Chunk 3: Serialization & Engine Integration

### Task 7: GroupWidget serialization — toStruct and fromStruct

**Files:**
- Modify: `libs/Dashboard/GroupWidget.m`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing tests for serialization**

Add to `TestGroupWidget.m`:

```matlab
function testToStructPanel(testCase)
    g = GroupWidget('Label', 'Motor Health', 'Mode', 'panel');
    g.Position = [1 1 12 4];
    g.addChild(MockDashboardWidget('Title', 'W1'));

    s = g.toStruct();
    testCase.verifyEqual(s.type, 'group');
    testCase.verifyEqual(s.label, 'Motor Health');
    testCase.verifyEqual(s.mode, 'panel');
    testCase.verifyTrue(isfield(s, 'children'));
    testCase.verifyLength(s.children, 1);
end

function testToStructTabbed(testCase)
    g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
    g.addChild(MockDashboardWidget('Title', 'W1'), 'Overview');
    g.addChild(MockDashboardWidget('Title', 'W2'), 'Detail');

    s = g.toStruct();
    testCase.verifyEqual(s.type, 'group');
    testCase.verifyEqual(s.mode, 'tabbed');
    testCase.verifyTrue(isfield(s, 'tabs'));
    testCase.verifyLength(s.tabs, 2);
    testCase.verifyEqual(s.tabs{1}.name, 'Overview');
    testCase.verifyEqual(s.activeTab, 'Overview');
end

function testRoundTripPanel(testCase)
    g = GroupWidget('Label', 'Test', 'Mode', 'collapsible');
    g.Position = [3 2 8 3];
    g.addChild(TextWidget('Title', 'W1'));
    g.addChild(TextWidget('Title', 'W2'));

    s = g.toStruct();
    g2 = GroupWidget.fromStruct(s);
    testCase.verifyEqual(g2.Label, 'Test');
    testCase.verifyEqual(g2.Mode, 'collapsible');
    testCase.verifyEqual(g2.Position, [3 2 8 3]);
    testCase.verifyLength(g2.Children, 2);
end
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — toStruct returns base class struct without group fields

- [ ] **Step 3: Implement toStruct and fromStruct**

Replace `toStruct` in `GroupWidget.m`:

```matlab
function s = toStruct(obj)
    s = struct();
    s.type = 'group';
    s.title = obj.Title;
    s.label = obj.Label;
    s.description = obj.Description;
    s.mode = obj.Mode;
    s.position = struct('col', obj.Position(1), 'row', obj.Position(2), ...
                        'width', obj.Position(3), 'height', obj.Position(4));
    s.childAutoFlow = obj.ChildAutoFlow;
    s.childColumns = obj.ChildColumns;

    if ~isempty(fieldnames(obj.ThemeOverride))
        s.themeOverride = obj.ThemeOverride;
    end

    if strcmp(obj.Mode, 'tabbed')
        s.tabs = cell(1, numel(obj.Tabs));
        for i = 1:numel(obj.Tabs)
            tab = struct();
            tab.name = obj.Tabs{i}.name;
            tab.widgets = cell(1, numel(obj.Tabs{i}.widgets));
            for j = 1:numel(obj.Tabs{i}.widgets)
                tab.widgets{j} = obj.Tabs{i}.widgets{j}.toStruct();
            end
            s.tabs{i} = tab;
        end
        s.activeTab = obj.ActiveTab;
        s.children = {};
    else
        s.collapsed = obj.Collapsed;
        s.children = cell(1, numel(obj.Children));
        for i = 1:numel(obj.Children)
            s.children{i} = obj.Children{i}.toStruct();
        end
        s.tabs = {};
    end
end
```

Replace `fromStruct` in `GroupWidget.m`:

```matlab
function obj = fromStruct(s)
    obj = GroupWidget();
    if isfield(s, 'title'), obj.Title = s.title; end
    if isfield(s, 'label'), obj.Label = s.label; end
    if isfield(s, 'description'), obj.Description = s.description; end
    if isfield(s, 'mode'), obj.Mode = s.mode; end
    if isfield(s, 'position')
        obj.Position = [s.position.col, s.position.row, ...
                        s.position.width, s.position.height];
    end
    if isfield(s, 'childAutoFlow'), obj.ChildAutoFlow = s.childAutoFlow; end
    if isfield(s, 'childColumns'), obj.ChildColumns = s.childColumns; end
    if isfield(s, 'collapsed'), obj.Collapsed = s.collapsed; end
    if isfield(s, 'activeTab'), obj.ActiveTab = s.activeTab; end

    if isfield(s, 'themeOverride')
        obj.ThemeOverride = s.themeOverride;
    end

    % Deserialize children (panel/collapsible mode)
    if isfield(s, 'children') && ~isempty(s.children)
        for i = 1:numel(s.children)
            cs = s.children{i};
            child = DashboardSerializer.createWidgetFromStruct(cs);
            if ~isempty(child)
                obj.Children{end+1} = child;
            end
        end
    end

    % Deserialize tabs (tabbed mode)
    if isfield(s, 'tabs') && ~isempty(s.tabs)
        for i = 1:numel(s.tabs)
            ts = s.tabs{i};
            tabEntry = struct('name', ts.name, 'widgets', {{}});
            for j = 1:numel(ts.widgets)
                ws = ts.widgets{j};
                w = DashboardSerializer.createWidgetFromStruct(ws);
                if ~isempty(w)
                    tabEntry.widgets{end+1} = w;
                end
            end
            obj.Tabs{end+1} = tabEntry;
        end
        if isempty(obj.ActiveTab) && ~isempty(obj.Tabs)
            obj.ActiveTab = obj.Tabs{1}.name;
        end
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/GroupWidget.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): implement GroupWidget serialization (toStruct/fromStruct)"
```

---

### Task 8: DashboardSerializer — add group case + createWidgetFromStruct helper

**Files:**
- Modify: `libs/Dashboard/DashboardSerializer.m:69-114`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing test for serializer integration**

Add to `TestGroupWidget.m`:

```matlab
function testSerializerRoundTrip(testCase)
    % Build a dashboard config with a group widget
    g = GroupWidget('Label', 'Motors', 'Mode', 'panel');
    g.Position = [1 1 12 4];
    g.addChild(TextWidget('Title', 'RPM'));

    s = g.toStruct();

    % Verify DashboardSerializer can reconstruct it
    w = DashboardSerializer.createWidgetFromStruct(s);
    testCase.verifyClass(w, 'GroupWidget');
    testCase.verifyEqual(w.Label, 'Motors');
    testCase.verifyLength(w.Children, 1);
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `createWidgetFromStruct` method does not exist on DashboardSerializer

- [ ] **Step 3: Extract createWidgetFromStruct from configToWidgets**

In `DashboardSerializer.m`, extract the switch-case body from `configToWidgets` into a new static method, and add `case 'group'`:

```matlab
function w = createWidgetFromStruct(ws)
    w = [];
    switch ws.type
        case 'fastsense'
            w = FastSenseWidget.fromStruct(ws);
        case 'number'
            w = NumberWidget.fromStruct(ws);
        case 'gauge'
            w = GaugeWidget.fromStruct(ws);
        case 'status'
            w = StatusWidget.fromStruct(ws);
        case 'text'
            w = TextWidget.fromStruct(ws);
        case 'table'
            w = TableWidget.fromStruct(ws);
        case 'timeline'
            w = EventTimelineWidget.fromStruct(ws);
        case 'rawaxes'
            w = RawAxesWidget.fromStruct(ws);
        case 'group'
            w = GroupWidget.fromStruct(ws);
        otherwise
            warning('DashboardSerializer:unknownType', ...
                'Unknown widget type: %s — skipping', ws.type);
    end
end
```

Update `configToWidgets` to call `createWidgetFromStruct` instead of inlining the switch:

```matlab
function widgets = configToWidgets(config, resolver)
    if nargin < 2, resolver = []; end
    widgets = cell(1, numel(config.widgets));
    for i = 1:numel(config.widgets)
        ws = config.widgets{i};
        widgets{i} = DashboardSerializer.createWidgetFromStruct(ws);
        % Resolve sensor binding if resolver provided
        if ~isempty(resolver) && ~isempty(widgets{i}) && ...
                isfield(ws, 'source') && strcmp(ws.source.type, 'sensor')
            try
                widgets{i}.Sensor = resolver(ws.source.name);
            catch
                warning('DashboardSerializer:sensorNotFound', ...
                    'Could not resolve sensor: %s', ws.source.name);
            end
        end
    end
    widgets = widgets(~cellfun('isempty', widgets));
end
```

Also add `case 'group'` to `exportScript` method. In the widget-generation switch inside `exportScript`, add:

```matlab
case 'group'
    lines{end+1} = sprintf('g_%d = GroupWidget(''Label'', ''%s'', ''Mode'', ''%s'', ''Position'', [%d %d %d %d]);', ...
        i, ws.label, ws.mode, ws.position.col, ws.position.row, ws.position.width, ws.position.height);
    if isfield(ws, 'children') && ~isempty(ws.children)
        for ci = 1:numel(ws.children)
            lines{end+1} = sprintf('g_%d.addChild(%s);', i, ...
                DashboardSerializer.widgetConstructorStr(ws.children{ci}));
        end
    end
    if isfield(ws, 'tabs') && ~isempty(ws.tabs)
        for ti = 1:numel(ws.tabs)
            tab = ws.tabs{ti};
            for ci = 1:numel(tab.widgets)
                lines{end+1} = sprintf('g_%d.addChild(%s, ''%s'');', i, ...
                    DashboardSerializer.widgetConstructorStr(tab.widgets{ci}), tab.name);
            end
        end
    end
    lines{end+1} = sprintf('d.addWidget(g_%d);', i);
```

Note: `widgetConstructorStr` is an existing helper in DashboardSerializer that generates a one-line widget constructor string from a struct. If it doesn't exist, inline the type-switch logic.

- [ ] **Step 4: Run tests to verify they pass**

Run all dashboard tests: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardSerializer.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): add group widget support to DashboardSerializer"
```

---

### Task 9: DashboardEngine — add group type

**Files:**
- Modify: `libs/Dashboard/DashboardEngine.m:66-105` and `:555-567`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing test for engine integration**

Add to `TestGroupWidget.m`:

```matlab
function testEngineAddGroupWidget(testCase)
    d = DashboardEngine('TestDash', 'Theme', 'dark');
    d.addWidget('group', 'Label', 'Motor Health');
    testCase.verifyLength(d.Widgets, 1);
    testCase.verifyClass(d.Widgets{1}, 'GroupWidget');
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `Unknown widget type: group`

- [ ] **Step 3: Add case 'group' to DashboardEngine.addWidget**

In `DashboardEngine.m`, inside `addWidget` switch block (around line 82), add before the `otherwise`:

```matlab
case 'group'
    w = GroupWidget(varargin{:});
```

In `widgetTypes()` static method (around line 561), add:

```matlab
'group',        'Widget container with panel/collapsible/tabbed modes (GroupWidget)'
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"`
Expected: PASS

Also run existing dashboard tests to ensure no regressions:
Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboardEngine.m'); disp(results);"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardEngine.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): register GroupWidget in DashboardEngine"
```

---

## Chunk 4: Layout Reflow & Bridge Export

### Task 10: DashboardLayout — reflow method

**Files:**
- Modify: `libs/Dashboard/DashboardLayout.m`
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write failing test for reflow**

Add to `TestGroupWidget.m`:

```matlab
function testLayoutReflow(testCase)
    layout = DashboardLayout();
    % Verify reflow method exists and is callable
    testCase.verifyTrue(ismethod(layout, 'reflow'));
end
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `reflow` method not found

- [ ] **Step 3: Add reflow method to DashboardLayout**

Add to `DashboardLayout.m` public methods:

```matlab
function reflow(obj, hFigure, widgets, theme)
    % Re-run layout after dynamic changes (e.g., group collapse/expand).
    % This tears down and recreates all panels, calling render() on each widget.
    % Matches createPanels(obj, hFigure, widgets, theme) argument order.
    if isempty(hFigure) || ~ishandle(hFigure)
        return;
    end
    obj.createPanels(hFigure, widgets, theme);
end
```

This delegates to the existing `createPanels` which already handles teardown and rebuild.

- [ ] **Step 4: Run tests to verify they pass**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add libs/Dashboard/DashboardLayout.m tests/suite/TestGroupWidget.m
git commit -m "feat(dashboard): add reflow() method to DashboardLayout"
```

---

### Task 11: Bridge — web export for group widget

**Files:**
- Modify: `bridge/web/js/widgets.js`
- Modify: `bridge/web/js/dashboard.js`

- [ ] **Step 1: Add group type to widgets.js**

In `widgets.js`, add a new case to the `Widgets.render` dispatch. Add after the existing cases:

```javascript
case 'group':
    Widgets.renderGroup(config, bodyEl);
    break;
```

Add the `renderGroup` method:

```javascript
renderGroup: function(config, container) {
    var mode = config.mode || 'panel';
    var label = config.label || '';

    // Header
    if (label) {
        var header = document.createElement('div');
        header.className = 'widget-group-header';
        header.textContent = label;

        if (mode === 'collapsible') {
            var toggle = document.createElement('span');
            toggle.className = 'widget-group-toggle';
            toggle.textContent = config.collapsed ? '►' : '▼';
            header.insertBefore(toggle, header.firstChild);
            header.style.cursor = 'pointer';
            header.addEventListener('click', function() {
                var content = container.querySelector('.widget-group-content');
                var isCollapsed = content.style.display === 'none';
                content.style.display = isCollapsed ? 'grid' : 'none';
                toggle.textContent = isCollapsed ? '▼' : '►';
            });
        }

        if (mode === 'tabbed' && config.tabs && config.tabs.length > 0) {
            var tabBar = document.createElement('div');
            tabBar.className = 'widget-group-tabbar';
            config.tabs.forEach(function(tab, idx) {
                var tabBtn = document.createElement('button');
                tabBtn.className = 'widget-group-tab';
                if (tab.name === config.activeTab) {
                    tabBtn.classList.add('active');
                }
                tabBtn.textContent = tab.name;
                tabBtn.addEventListener('click', function() {
                    // Hide all tab panels, show selected
                    var panels = container.querySelectorAll('.widget-group-tabpanel');
                    panels.forEach(function(p) { p.style.display = 'none'; });
                    panels[idx].style.display = 'grid';
                    // Update active class
                    tabBar.querySelectorAll('.widget-group-tab').forEach(function(b) {
                        b.classList.remove('active');
                    });
                    tabBtn.classList.add('active');
                });
                tabBar.appendChild(tabBtn);
            });
            header.appendChild(tabBar);
        }

        container.appendChild(header);
    }

    // Content
    if (mode === 'tabbed' && config.tabs) {
        config.tabs.forEach(function(tab, idx) {
            var tabPanel = document.createElement('div');
            tabPanel.className = 'widget-group-tabpanel widget-group-content';
            tabPanel.style.display = (tab.name === config.activeTab) ? 'grid' : 'none';
            tabPanel.style.gridTemplateColumns = 'repeat(auto-fit, minmax(200px, 1fr))';
            tabPanel.style.gap = '8px';
            tabPanel.style.padding = '8px';

            (tab.widgets || []).forEach(function(wCfg) {
                var wEl = document.createElement('div');
                wEl.className = 'widget';
                var wBody = document.createElement('div');
                wBody.className = 'widget-body';
                wEl.appendChild(wBody);
                Widgets.render(wCfg, wBody);
                tabPanel.appendChild(wEl);
            });
            container.appendChild(tabPanel);
        });
    } else {
        var content = document.createElement('div');
        content.className = 'widget-group-content';
        content.style.display = config.collapsed ? 'none' : 'grid';
        content.style.gridTemplateColumns = 'repeat(auto-fit, minmax(200px, 1fr))';
        content.style.gap = '8px';
        content.style.padding = '8px';

        (config.children || []).forEach(function(childCfg) {
            var wEl = document.createElement('div');
            wEl.className = 'widget';
            var wBody = document.createElement('div');
            wBody.className = 'widget-body';
            wEl.appendChild(wBody);
            Widgets.render(childCfg, wBody);
            content.appendChild(wEl);
        });
        container.appendChild(content);
    }
}
```

- [ ] **Step 2: Add CSS for group widget to dashboard.js**

Add CSS styles in the `Dashboard.render` method's style block:

```css
.widget-group-header {
    padding: 6px 12px;
    font-weight: bold;
    font-size: 13px;
    border-radius: 4px 4px 0 0;
}
.widget-group-toggle {
    margin-right: 8px;
}
.widget-group-tabbar {
    display: inline-flex;
    gap: 2px;
    margin-left: 16px;
}
.widget-group-tab {
    padding: 3px 12px;
    border: none;
    cursor: pointer;
    font-size: 11px;
    border-radius: 3px 3px 0 0;
    opacity: 0.6;
}
.widget-group-tab.active {
    opacity: 1.0;
}
```

- [ ] **Step 3: Commit**

```bash
git add bridge/web/js/widgets.js bridge/web/js/dashboard.js
git commit -m "feat(dashboard): add group widget support to web bridge export"
```

---

## Chunk 5: Integration Test & Cleanup

### Task 12: Full integration test

**Files:**
- Modify: `tests/suite/TestGroupWidget.m`

- [ ] **Step 1: Write integration test — group widget in a full dashboard**

Add to `TestGroupWidget.m`:

```matlab
function testFullDashboardIntegration(testCase)
    % Build a dashboard with a group widget containing children
    d = DashboardEngine('GroupTest', 'Theme', 'dark');
    d.addWidget('group', 'Label', 'Motor Health', 'Mode', 'panel', ...
        'Position', [1 1 24 4]);

    % Add children to the group (use TextWidget for serialization support)
    g = d.Widgets{1};
    g.addChild(TextWidget('Title', 'RPM Label'));
    g.addChild(TextWidget('Title', 'Temp Label'));

    testCase.verifyLength(g.Children, 2);

    % Test serialization round-trip via file save/load
    tmpFile = [tempname '.json'];
    cleanupFile = onCleanup(@() delete(tmpFile));
    d.save(tmpFile);
    loaded = DashboardEngine.load(tmpFile);
    testCase.verifyLength(loaded.Widgets, 1);
    testCase.verifyClass(loaded.Widgets{1}, 'GroupWidget');
    testCase.verifyLength(loaded.Widgets{1}.Children, 2);
end

function testSetTimeRangeCascade(testCase)
    g = GroupWidget('Label', 'Test', 'Mode', 'tabbed');
    m1 = MockDashboardWidget('Title', 'W1');
    m2 = MockDashboardWidget('Title', 'W2');
    g.addChild(m1, 'Tab1');
    g.addChild(m2, 'Tab2');

    % setTimeRange should not error even though MockDashboardWidget
    % doesn't have setTimeRange — the ismethod check handles it
    g.setTimeRange(0, 100);
    % If we get here without error, cascade logic works
    testCase.verifyTrue(true);
end
```

- [ ] **Step 2: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestGroupWidget.m'); disp(results);"`
Expected: PASS — all tests green

Also run full dashboard test suite to check for regressions:
Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestDashboard*.m'); disp(results);"`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add tests/suite/TestGroupWidget.m
git commit -m "test(dashboard): add full integration tests for GroupWidget"
```

---

### Task 13: Example script

**Files:**
- Create: `examples/example_dashboard_groups.m`

- [ ] **Step 1: Create example demonstrating all 3 group modes**

```matlab
% example_dashboard_groups.m — Demonstrates GroupWidget panel, collapsible, and tabbed modes
install();

% Create sample sensors
s_rpm   = Sensor('rpm_main', 'Main RPM');
s_rpm.addData(0:0.1:10, 100 + 20*sin(0:0.1:10));

s_temp  = Sensor('temp_bearing', 'Bearing Temp');
s_temp.addData(0:0.1:10, 60 + 5*randn(1, 101));
s_temp.addThresholdRule(ThresholdRule('Warning', 65, 'color', [0.91 0.63 0.27]));
s_temp.addThresholdRule(ThresholdRule('Alarm', 70, 'color', [0.91 0.27 0.38]));

s_pres  = Sensor('pressure', 'Line Pressure');
s_pres.addData(0:0.1:10, 2.5 + 0.3*randn(1, 101));

% Build dashboard
d = DashboardEngine('Name', 'GroupWidget Demo', 'Theme', 'dark');

% 1. Panel group — always visible
d.addWidget('group', 'Label', 'Motor Overview', 'Mode', 'panel', ...
    'Position', [1 1 12 4]);
g1 = d.Widgets{end};
g1.addChild(NumberWidget('Sensor', s_rpm, 'Title', 'RPM'));
g1.addChild(GaugeWidget('Sensor', s_temp, 'Title', 'Temperature'));
g1.addChild(StatusWidget('Sensor', s_temp, 'Title', 'Temp Status'));

% 2. Collapsible group — can be hidden
d.addWidget('group', 'Label', 'Pressure Detail', 'Mode', 'collapsible', ...
    'Position', [13 1 12 4]);
g2 = d.Widgets{end};
g2.addChild(FastSenseWidget('Sensor', s_pres, 'Title', 'Pressure Over Time'));

% 3. Tabbed group — multiple views in one space
d.addWidget('group', 'Label', 'Analysis', 'Mode', 'tabbed', ...
    'Position', [1 5 24 5]);
g3 = d.Widgets{end};
g3.addChild(FastSenseWidget('Sensor', s_rpm, 'Title', 'RPM Trend'), 'Trends');
g3.addChild(FastSenseWidget('Sensor', s_temp, 'Title', 'Temp Trend'), 'Trends');
g3.addChild(NumberWidget('Sensor', s_rpm, 'Title', 'Current RPM'), 'Summary');
g3.addChild(NumberWidget('Sensor', s_temp, 'Title', 'Current Temp'), 'Summary');
g3.addChild(StatusWidget('Sensor', s_temp, 'Title', 'Status'), 'Summary');

d.render();
```

- [ ] **Step 2: Commit**

```bash
git add examples/example_dashboard_groups.m
git commit -m "docs(dashboard): add example script demonstrating GroupWidget modes"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | GroupWidget scaffold + construction tests | GroupWidget.m, TestGroupWidget.m |
| 2 | Panel mode rendering | GroupWidget.m, TestGroupWidget.m |
| 3 | Theme fields for all 6 presets | DashboardTheme.m, TestGroupWidget.m |
| 4 | Collapsible mode | GroupWidget.m, TestGroupWidget.m |
| 5 | Tabbed mode | GroupWidget.m, TestGroupWidget.m |
| 6 | Nesting depth tests | TestGroupWidget.m |
| 7 | Serialization (toStruct/fromStruct) | GroupWidget.m, TestGroupWidget.m |
| 8 | DashboardSerializer integration | DashboardSerializer.m, TestGroupWidget.m |
| 9 | DashboardEngine integration | DashboardEngine.m, TestGroupWidget.m |
| 10 | Layout reflow | DashboardLayout.m, TestGroupWidget.m |
| 11 | Web bridge export | widgets.js, dashboard.js |
| 12 | Full integration tests | TestGroupWidget.m |
| 13 | Example script | example_dashboard_groups.m |
