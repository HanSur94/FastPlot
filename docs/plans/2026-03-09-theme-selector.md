# Theme Selector Toolbar Button — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a toolbar button that opens a context menu for switching themes across the entire figure hierarchy (dock/figure/tiles).

**Architecture:** Three changes: (1) add `ThemeDir` to `FastPlotDefaults.m` and scan it in `getDefaults()` to populate `cfg.CustomThemes`, (2) add a paint palette `uipushtool` to `FastPlotToolbar` that opens a `uicontextmenu` with built-in + custom themes, (3) add `reapplyTheme()` methods to `FastPlotFigure` and `FastPlotDock` so the toolbar can propagate theme changes down the hierarchy.

**Tech Stack:** MATLAB (uitoolbar, uicontextmenu, uimenu)

---

### Task 1: Add `ThemeDir` and `CustomThemes` to config

**Files:**
- Modify: `FastPlotDefaults.m:33-34`
- Modify: `private/getDefaults.m`

**Step 1: Add ThemeDir field to FastPlotDefaults.m**

Add after the `cfg.Theme` line (line 34):

```matlab
    cfg.ThemeDir = '';                % folder of custom theme .m files (empty = none)
```

**Step 2: Update getDefaults.m to scan ThemeDir and populate CustomThemes**

Replace the entire file with:

```matlab
function cfg = getDefaults()
%GETDEFAULTS Return cached FastPlotDefaults struct.
%   cfg = getDefaults()
%
%   Uses a persistent variable so FastPlotDefaults() is called only once
%   per MATLAB session. This avoids re-parsing the defaults file on every
%   FastPlot construction. Call clearDefaultsCache() to force a reload
%   after editing FastPlotDefaults.m.
%
%   See also FastPlotDefaults, clearDefaultsCache.

    persistent cachedCfg;
    if isempty(cachedCfg)
        cachedCfg = FastPlotDefaults();
        cachedCfg.CustomThemes = loadCustomThemes(cachedCfg);
    end
    cfg = cachedCfg;
end

function themes = loadCustomThemes(cfg)
%LOADCUSTOMTHEMES Scan ThemeDir for .m files, call each, return struct.
    themes = struct();
    if isempty(cfg.ThemeDir)
        return;
    end
    % Resolve relative paths against FastPlot root
    themeDir = cfg.ThemeDir;
    if ~isfolder(themeDir)
        root = fileparts(mfilename('fullpath'));
        % getDefaults lives in private/, go up one level
        root = fileparts(root);
        themeDir = fullfile(root, cfg.ThemeDir);
    end
    if ~isfolder(themeDir)
        return;
    end
    files = dir(fullfile(themeDir, '*.m'));
    for i = 1:numel(files)
        [~, name] = fileparts(files(i).name);
        try
            oldPath = addpath(themeDir);
            restorePath = onCleanup(@() path(oldPath));
            fn = str2func(name);
            t = fn();
            if isstruct(t)
                themes.(name) = t;
            end
        catch
            % skip broken theme files
        end
    end
end
```

**Step 3: Commit**

```bash
git add FastPlotDefaults.m private/getDefaults.m
git commit -m "feat: add ThemeDir config and custom theme loading in getDefaults"
```

---

### Task 2: Add `reapplyTheme()` to FastPlotFigure

**Files:**
- Modify: `FastPlotFigure.m`

**Step 1: Add reapplyTheme method to FastPlotFigure**

Add this public method after the existing `render()` method (after line 247):

```matlab
        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply theme to figure and all rendered tiles.
            %   fig.reapplyTheme()
            %   Use after changing fig.Theme to update all visuals.
            set(obj.hFigure, 'Color', obj.Theme.Background);
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i}) && obj.Tiles{i}.IsRendered
                    if ~isempty(obj.TileThemes) && i <= numel(obj.TileThemes) && ~isempty(obj.TileThemes{i})
                        obj.Tiles{i}.Theme = mergeTheme(obj.Theme, obj.TileThemes{i});
                    else
                        obj.Tiles{i}.Theme = obj.Theme;
                    end
                    obj.Tiles{i}.reapplyTheme();
                end
            end
        end
```

**Step 2: Commit**

```bash
git add FastPlotFigure.m
git commit -m "feat: add reapplyTheme to FastPlotFigure for live theme switching"
```

---

### Task 3: Add `reapplyTheme()` to FastPlotDock

**Files:**
- Modify: `FastPlotDock.m`

**Step 1: Add reapplyTheme method to FastPlotDock**

Add this public method after the existing `delete()` method (after line 405), inside the `methods (Access = public)` block:

```matlab
        function reapplyTheme(obj)
            %REAPPLYTHEME Re-apply theme to dock, tab bar, panels, and all tabs.
            %   dock.reapplyTheme()
            %   Use after changing dock.Theme to update all visuals.

            % Figure background
            set(obj.hFigure, 'Color', obj.Theme.Background);

            % Tab bar buttons
            for i = 1:numel(obj.hTabButtons)
                if ishandle(obj.hTabButtons{i})
                    obj.styleTabButton(i, i == obj.ActiveTab);
                end
            end
            for i = 1:numel(obj.hUndockButtons)
                if ishandle(obj.hUndockButtons{i})
                    set(obj.hUndockButtons{i}, 'BackgroundColor', obj.Theme.Background, ...
                        'ForegroundColor', obj.Theme.ForegroundColor);
                end
            end
            for i = 1:numel(obj.hCloseButtons)
                if ishandle(obj.hCloseButtons{i})
                    set(obj.hCloseButtons{i}, 'BackgroundColor', obj.Theme.Background, ...
                        'ForegroundColor', obj.Theme.ForegroundColor);
                end
            end

            % Panels and figures
            for i = 1:numel(obj.Tabs)
                if ~isempty(obj.Tabs(i).Panel) && ishandle(obj.Tabs(i).Panel)
                    set(obj.Tabs(i).Panel, 'BackgroundColor', obj.Theme.Background);
                end
                if obj.Tabs(i).IsRendered && ~isempty(obj.Tabs(i).Figure)
                    obj.Tabs(i).Figure.Theme = obj.Theme;
                    obj.Tabs(i).Figure.reapplyTheme();
                end
            end
        end
```

**Step 2: Commit**

```bash
git add FastPlotDock.m
git commit -m "feat: add reapplyTheme to FastPlotDock for live theme switching"
```

---

### Task 4: Add theme button and context menu to FastPlotToolbar

**Files:**
- Modify: `FastPlotToolbar.m`

**Step 1: Add hThemeBtn property**

Add to the `properties (SetAccess = private)` block (after line 47, the `hMetadataBtn` line):

```matlab
        hThemeBtn     = []    % uipushtool handle for theme selector
```

**Step 2: Add theme button to createToolbar()**

Add after the metadata button block (after line 320), inside `createToolbar()`:

```matlab
            obj.hThemeBtn = uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('theme'), ...
                'TooltipString', 'Change Theme', ...
                'ClickedCallback', @(s,e) obj.onThemeClick());
```

**Step 3: Add onThemeClick() private method**

Add to the private methods block (e.g., after `onMetadataOff` around line 341):

```matlab
        function onThemeClick(obj)
            %ONTHEMECLICK Open a context menu with available themes.
            builtins = {'default', 'dark', 'light', 'industrial', 'scientific'};

            % Get custom themes
            cfg = getDefaults();
            if isfield(cfg, 'CustomThemes')
                customNames = fieldnames(cfg.CustomThemes);
            else
                customNames = {};
            end

            % Determine current theme name
            currentTheme = obj.getCurrentThemeName();

            % Build context menu
            hMenu = uicontextmenu('Parent', obj.hFigure);

            for i = 1:numel(builtins)
                label = builtins{i};
                if strcmpi(label, currentTheme)
                    checked = 'on';
                else
                    checked = 'off';
                end
                uimenu(hMenu, 'Label', label, 'Checked', checked, ...
                    'Callback', @(s,e) obj.applyThemeByName(label));
            end

            if ~isempty(customNames)
                % Add separator via a disabled separator menu item
                for i = 1:numel(customNames)
                    label = customNames{i};
                    if strcmpi(label, currentTheme)
                        checked = 'on';
                    else
                        checked = 'off';
                    end
                    sep = 'off';
                    if i == 1; sep = 'on'; end
                    uimenu(hMenu, 'Label', label, 'Checked', checked, ...
                        'Separator', sep, ...
                        'Callback', @(s,e) obj.applyThemeByName(label));
                end
            end

            % Position and show the menu near the mouse
            figPos = get(obj.hFigure, 'CurrentPoint');
            set(hMenu, 'Position', figPos, 'Visible', 'on');
        end

        function name = getCurrentThemeName(obj)
            %GETCURRENTTHEMENAME Return the name of the current theme, or ''.
            name = '';
            target = obj.Target;
            if isa(target, 'FastPlotFigure') || isa(target, 'FastPlot')
                currentTheme = target.Theme;
            else
                return;
            end
            if isempty(currentTheme); return; end

            % Check built-in presets
            presets = {'default', 'dark', 'light', 'industrial', 'scientific'};
            for i = 1:numel(presets)
                ref = FastPlotTheme(presets{i});
                if obj.themesEqual(currentTheme, ref)
                    name = presets{i};
                    return;
                end
            end

            % Check custom themes
            cfg = getDefaults();
            if isfield(cfg, 'CustomThemes')
                customs = fieldnames(cfg.CustomThemes);
                for i = 1:numel(customs)
                    ref = mergeTheme(FastPlotTheme('default'), cfg.CustomThemes.(customs{i}));
                    if obj.themesEqual(currentTheme, ref)
                        name = customs{i};
                        return;
                    end
                end
            end
        end

        function eq = themesEqual(~, a, b)
            %THEMESEQUAL Compare two theme structs (ignoring LineColorOrder).
            eq = false;
            if ~isstruct(a) || ~isstruct(b); return; end
            fields = {'Background', 'AxesColor', 'ForegroundColor', 'GridColor', ...
                      'GridAlpha', 'GridStyle', 'FontName', 'FontSize'};
            for i = 1:numel(fields)
                f = fields{i};
                if ~isfield(a, f) || ~isfield(b, f); return; end
                if isnumeric(a.(f))
                    if ~isequal(round(a.(f)*1000), round(b.(f)*1000)); return; end
                else
                    if ~strcmp(a.(f), b.(f)); return; end
                end
            end
            eq = true;
        end

        function applyThemeByName(obj, name)
            %APPLYTHEMEBYNAME Resolve theme by name and apply to hierarchy.
            cfg = getDefaults();

            % Resolve: check custom themes first, then built-in
            if isfield(cfg, 'CustomThemes') && isfield(cfg.CustomThemes, name)
                newTheme = mergeTheme(FastPlotTheme('default'), cfg.CustomThemes.(name));
            else
                newTheme = FastPlotTheme(name);
            end

            target = obj.Target;
            if isa(target, 'FastPlotFigure')
                % Check if the figure belongs to a dock (via AppData)
                dock = getappdata(obj.hFigure, 'FastPlotDock');
                if ~isempty(dock) && isa(dock, 'FastPlotDock')
                    dock.Theme = newTheme;
                    dock.reapplyTheme();
                else
                    target.Theme = newTheme;
                    target.reapplyTheme();
                end
            elseif isa(target, 'FastPlot')
                target.Theme = newTheme;
                target.reapplyTheme();
            end
        end
```

**Step 4: Add 'theme' case to makeIcon()**

Add inside the `switch name` block in `makeIcon()` (before the closing `end` of the switch, around line 782):

```matlab
                case 'theme'
                    % Paint palette shape
                    % Oval outline
                    cx = 8; cy = 8;
                    for r = 3:13
                        for c = 3:14
                            dx = (c - cx) / 5.5;
                            dy = (r - cy) / 5;
                            d = dx^2 + dy^2;
                            if d <= 1.0 && d >= 0.72
                                icon(r, c, :) = reshape(fg, 1, 1, 3);
                            end
                        end
                    end
                    % Thumb hole
                    for r = 10:12
                        for c = 5:7
                            dx = (c - 6); dy = (r - 11);
                            if dx^2 + dy^2 <= 1.5
                                icon(r, c, :) = reshape([0.94 0.94 0.94], 1, 1, 3);
                            end
                        end
                    end
                    % Paint dots (4 colors)
                    colors = {[0.85 0.2 0.2], [0.2 0.6 0.2], [0.2 0.3 0.85], [0.9 0.7 0.1]};
                    positions = {[5 8], [5 11], [7 12], [9 11]};
                    for i = 1:4
                        pr = positions{i}(1); pc = positions{i}(2);
                        clr = colors{i};
                        icon(pr, pc, :) = reshape(clr, 1, 1, 3);
                        icon(pr, pc+1, :) = reshape(clr, 1, 1, 3);
                        icon(pr+1, pc, :) = reshape(clr, 1, 1, 3);
                        icon(pr+1, pc+1, :) = reshape(clr, 1, 1, 3);
                    end
```

**Step 5: Commit**

```bash
git add FastPlotToolbar.m
git commit -m "feat: add theme selector button with context menu to toolbar"
```

---

### Task 5: Store dock reference in AppData for toolbar discovery

**Files:**
- Modify: `FastPlotDock.m`

**Step 1: Store dock reference in figure AppData**

In `FastPlotDock` constructor, after the `obj.hFigure = figure(...)` line (line 65), add:

```matlab
            setappdata(obj.hFigure, 'FastPlotDock', obj);
```

**Step 2: Commit**

```bash
git add FastPlotDock.m
git commit -m "feat: store dock reference in AppData for toolbar theme discovery"
```

---

### Task 6: Create example custom theme for testing

**Files:**
- Create: `themes/midnight.m`

**Step 1: Create themes/ directory and an example theme**

```bash
mkdir -p themes
```

Then create `themes/midnight.m`:

```matlab
function t = midnight()
%MIDNIGHT A deep blue-black custom theme for FastPlot.
    t = struct( ...
        'Background',      [0.05 0.05 0.15], ...
        'AxesColor',       [0.08 0.08 0.2], ...
        'ForegroundColor', [0.8 0.8 0.9], ...
        'GridColor',       [0.3 0.3 0.5], ...
        'GridAlpha',       0.3, ...
        'GridStyle',       ':', ...
        'FontName',        'Helvetica', ...
        'FontSize',        10, ...
        'TitleFontSize',   12, ...
        'LineWidth',       1.0, ...
        'LineColorOrder',  'vibrant', ...
        'ThresholdColor',  [1 0.3 0.3], ...
        'ThresholdStyle',  '--', ...
        'ViolationMarker', 'o', ...
        'ViolationSize',   4, ...
        'BandAlpha',       0.2 ...
    );
end
```

**Step 2: Update FastPlotDefaults.m to point to themes/**

Change the `ThemeDir` default:

```matlab
    cfg.ThemeDir = 'themes';          % folder of custom theme .m files
```

**Step 3: Commit**

```bash
git add themes/midnight.m FastPlotDefaults.m
git commit -m "feat: add example midnight theme and set ThemeDir default"
```

---

### Task 7: Manual integration test

**Step 1: Test with a standalone FastPlot**

Open MATLAB and run:

```matlab
clearDefaultsCache;
fp = FastPlot();
fp.addLine(1:1000, cumsum(randn(1,1000)));
fp.render();
tb = FastPlotToolbar(fp);
% Click the palette button → should see 6 themes (5 built-in + midnight)
% Click 'dark' → plot should switch to dark theme
% Click 'midnight' → plot should switch to midnight theme
% Click 'default' → should revert
```

**Step 2: Test with FastPlotDock**

```matlab
clearDefaultsCache;
dock = FastPlotDock('Theme', 'default', 'Name', 'Theme Test');
fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fig1.tile(1).addLine(1:1000, cumsum(randn(1,1000)));
dock.addTab(fig1, 'Tab 1');
dock.render();
% Click the palette button → context menu appears
% Click 'dark' → entire dock (tab bar + panel + axes) switches to dark
```

**Step 3: Verify checkmark on active theme**

After switching to 'dark', click the palette button again — 'dark' should have a checkmark.
