# Dashboard Grouping & New Widgets Design

## Overview

Expand the FastSense dashboard with a widget grouping system (Phase A) and six new widget types (Phase B). Phase A introduces `GroupWidget` — a container that organizes child widgets into titled panels, collapsible sections, or tabbed views. Phase B adds HeatmapWidget, BarChartWidget, HistogramWidget, ScatterWidget, ImageWidget, and MultiStatusWidget.

## Phasing

- **Phase A — GroupWidget**: Adds grouping to the layout system. Must land first since all future widgets benefit from being groupable. Phase A integration tests use existing widget types (NumberWidget, GaugeWidget, etc.) as children.
- **Phase B — New Widgets**: Six new widget types built on the existing `DashboardWidget` pattern with Sensor-first data binding. Phase B adds combination tests (new widgets inside GroupWidget).

---

## Phase A: GroupWidget

### Class Definition

**File**: `libs/Dashboard/GroupWidget.m`
**Extends**: `DashboardWidget`

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Mode` | `'panel'` \| `'collapsible'` \| `'tabbed'` | `'panel'` | Grouping behavior |
| `Label` | string | `''` | Title shown in header bar |
| `Collapsed` | logical | `false` | Whether group is collapsed (collapsible mode only) |
| `Children` | cell array of DashboardWidget | `{}` | Child widgets (panel/collapsible modes) |
| `Tabs` | cell array of structs | `{}` | Ordered list of `struct('name', '...', 'widgets', {{}})` entries (tabbed mode only) |
| `ActiveTab` | string | `''` | Currently visible tab (tabbed mode only) |
| `ChildColumns` | integer | `24` | Column count for child sub-grid |
| `ChildAutoFlow` | logical | `true` | Auto-arrange children left-to-right |
| `ExpandedHeight` | integer | `[]` | Stores original `Position(4)` when collapsed; set automatically |

### Internal Handle Storage

GroupWidget stores rendering handles for post-render operations:

- `hHeader` — header bar uipanel handle
- `hChildPanel` — child content area uipanel handle
- `hTabButtons` — cell array of uicontrol handles for tab buttons (tabbed mode)
- `hChildPanels` — cell array of per-child uipanel handles

These are set during `render()` and used by `collapse()`, `expand()`, and `switchTab()`.

### API

```matlab
% Panel mode (default)
g = GroupWidget('Label', 'Motor Health');
g.addChild(NumberWidget('Sensor', rpm_sensor));
g.addChild(GaugeWidget('Sensor', temp_sensor));

% Collapsible mode
g = GroupWidget('Label', 'Motor Health', 'Mode', 'collapsible');
g.addChild(NumberWidget('Sensor', rpm_sensor));
g.addChild(GaugeWidget('Sensor', temp_sensor));

% Tabbed mode
g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
g.addChild(chart1, 'Overview');
g.addChild(chart2, 'Overview');
g.addChild(table1, 'Detail');
```

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `addChild` | `addChild(widget)` or `addChild(widget, tabName)` | Add child widget. Second form required for tabbed mode. Errors if nesting depth > 2. |
| `removeChild` | `removeChild(idx)` | Remove child by index (consistent with `DashboardEngine.removeWidget`) |
| `render` | `render(parentPanel)` | Render header + child sub-layout into parent uipanel |
| `refresh` | `refresh()` | Calls `refresh()` on all visible children |
| `setTimeRange` | `setTimeRange(tStart, tEnd)` | Cascades to all children (all tabs, not just active) |
| `getType` | `getType()` | Returns `'group'` |
| `toStruct` | `toStruct()` | Returns serializable struct with recursively embedded children via their `toStruct()` |
| `fromStruct` | `static fromStruct(s)` | Deserializes group + recursively creates children via `DashboardSerializer.configToWidgets` |
| `collapse` | `collapse()` | Collapse (collapsible mode only) |
| `expand` | `expand()` | Expand (collapsible mode only) |
| `switchTab` | `switchTab(tabName)` | Switch active tab (tabbed mode only) |

### Layout Integration

GroupWidget occupies a position on the main 24-column grid like any other widget (e.g., `Position = [1, 1, 12, 4]`). Inside, it creates a child layout context.

**Child positioning (auto-flow)**:
When `ChildAutoFlow = true`, children are assigned a fixed width of `floor(ChildColumns / maxPerRow)` grid units, where `maxPerRow = min(numChildren, 4)`. For example: 2 children → each gets 12 columns; 5 children → 4 per row (6 columns each), 5th wraps to row 2. Children do not need explicit `Position`.

**Child positioning (explicit)**:
When `ChildAutoFlow = false`, or when a child has an explicit `Position` set, the position is interpreted relative to the group's sub-grid (column 1 = left edge of the group, not the dashboard). `ChildColumns` defines the total column count of this sub-grid.

**Collapse behavior** (collapsible mode):
- On `collapse()`: store current `Position(4)` in `ExpandedHeight`, then set `Position(4) = 1` (one grid row for the header). Hide child panel. Call `DashboardLayout.reflow()` to re-run overlap resolution and compact the grid.
- On `expand()`: restore `Position(4)` from `ExpandedHeight`. Show child panel. Call `DashboardLayout.reflow()`.
- `DashboardLayout.reflow()` is a new method that re-runs `resolveOverlap()` followed by `createPanels()` to update all widget positions. Since `createPanels()` tears down and recreates all `uipanel` containers, it calls `render()` on every widget — including GroupWidget. This means GroupWidget's stored handles (`hHeader`, `hChildPanel`, `hTabButtons`, `hChildPanels`) are naturally refreshed during `reflow()`. No special handle-preservation logic is needed.
- Children are hidden (not destroyed) when collapsed — their data/state persists across the render cycle because it lives in widget properties, not in graphics handles.

**Tabbed behavior**:
- All tabs share the same spatial area inside the group.
- Only the active tab's children are visible (other tab panels have `Visible = 'off'`).
- Tab switching updates `Visible` on child panels — no re-creation, so widget state is preserved.
- Tab bar rendered as `uicontrol('Style', 'pushbutton')` in the header area.

**Nesting**: Groups may contain other groups. `addChild` checks nesting depth by walking the parent chain; errors if depth exceeds 2 with `error('GroupWidget:maxDepth', 'Maximum nesting depth of 2 exceeded')`.

**Edge cases**:
- Tabbed mode with 0 tabs: renders header with "(no tabs)" placeholder text. `switchTab` is a no-op.
- Collapsible mode with 0 children: collapses to header only, expands to empty content area.

### DashboardEngine Integration

`DashboardEngine.addWidget` gains a `case 'group'` in its type switch:

```matlab
case 'group'
    w = GroupWidget(varargin{:});
```

`DashboardEngine.widgetTypes()` updated to include `'group'`.

`DashboardEngine.broadcastTimeRange` already iterates `obj.Widgets` and calls `setTimeRange`. GroupWidget's `setTimeRange` cascades to all children (including all tabs), so children inside groups respond to the time slider without any engine changes.

### Serialization

`DashboardSerializer` changes:
- `widgetsToConfig`: calls `toStruct()` on each widget as before. `GroupWidget.toStruct()` recursively calls `toStruct()` on each child, embedding them as a nested struct array.
- `configToWidgets`: adds `case 'group'` that calls `GroupWidget.fromStruct(s)`. `fromStruct` recursively calls `DashboardSerializer.configToWidgets` on each child entry in `s.children` or `s.tabs{i}.widgets`.
- `exportScript`: adds `case 'group'` that generates `GroupWidget(...)` constructor + `addChild(...)` calls.

**JSON format** (all field names lowercase, matching existing convention):

Panel/collapsible mode:
```json
{
  "type": "group",
  "label": "Motor Health",
  "mode": "collapsible",
  "collapsed": false,
  "position": [1, 1, 12, 4],
  "childAutoFlow": true,
  "children": [
    { "type": "number", "sensor": "rpm_main" },
    { "type": "gauge", "sensor": "temp_bearing" }
  ]
}
```

Tabbed mode:
```json
{
  "type": "group",
  "label": "Analysis",
  "mode": "tabbed",
  "position": [1, 1, 24, 6],
  "activeTab": "Overview",
  "tabs": [
    {
      "name": "Overview",
      "widgets": [
        { "type": "number", "sensor": "rpm_main" },
        { "type": "gauge", "sensor": "temp_bearing" }
      ]
    },
    {
      "name": "Detail",
      "widgets": [
        { "type": "table", "sensor": "rpm_main" }
      ]
    }
  ]
}
```

### Theming

New fields added to `DashboardTheme.m`:

| Field | Description |
|-------|-------------|
| `GroupHeaderBg` | Header bar background |
| `GroupHeaderFg` | Header bar text color |
| `GroupBorderColor` | Panel border |
| `TabActiveBg` | Active tab background |
| `TabInactiveBg` | Inactive tab background |

`GroupBorderRadius` is omitted — `uipanel` in R2020b and Octave does not support corner radius. Border radius is applied only in the web/JS bridge export.

**Theme values per preset**:

| Preset | GroupHeaderBg | GroupHeaderFg | GroupBorderColor | TabActiveBg | TabInactiveBg |
|--------|--------------|--------------|-----------------|-------------|---------------|
| dark | `[0.16 0.22 0.34]` | `[0.95 0.95 0.95]` | `[0.25 0.30 0.40]` | `[0.16 0.22 0.34]` | `[0.10 0.12 0.18]` |
| light | `[0.90 0.92 0.95]` | `[0.15 0.15 0.15]` | `[0.80 0.82 0.85]` | `[0.90 0.92 0.95]` | `[0.82 0.84 0.88]` |
| industrial | `[0.22 0.22 0.22]` | `[0.90 0.90 0.90]` | `[0.35 0.35 0.35]` | `[0.22 0.22 0.22]` | `[0.14 0.14 0.14]` |
| scientific | `[0.88 0.88 0.86]` | `[0.15 0.15 0.20]` | `[0.80 0.80 0.78]` | `[0.88 0.88 0.86]` | `[0.94 0.94 0.92]` |
| ocean | `[0.10 0.22 0.30]` | `[0.80 0.95 1.00]` | `[0.18 0.30 0.40]` | `[0.10 0.22 0.30]` | `[0.06 0.14 0.22]` |
| default | `[0.20 0.20 0.25]` | `[0.92 0.92 0.92]` | `[0.30 0.30 0.35]` | `[0.20 0.20 0.25]` | `[0.12 0.12 0.16]` |

### DashboardLayout Changes

- `DashboardEngine.addWidget` adds `case 'group'` (see above). `DashboardLayout` itself does not need an `addWidget` method — it already receives widgets via `createPanels`.
- `computePosition` unchanged — GroupWidget gets a position like any widget.
- New method `reflow()`: re-runs `resolveOverlap()` + `createPanels()` to handle dynamic height changes from collapse/expand.
- New helper: `computeChildPositions(groupWidget)` for sub-grid layout within a group.

### Bridge / Web Export Changes

- `dashboard.js`: Add CSS Grid nesting for group containers. Collapsible groups get a click handler on the header. Border radius applied via CSS.
- `widgets.js`: Add `group` type dispatcher that renders header + child container, handles collapse toggle and tab switching via JavaScript.

---

## Phase B: New Widgets

All widgets follow the existing `DashboardWidget` pattern: Sensor-first data binding, `render()` / `refresh()` / `toStruct()` / `fromStruct()` interface, R2020b + Octave compatible.

### Type Strings

Each widget must implement `getType()` and be registered in `DashboardEngine.addWidget` and `DashboardSerializer.configToWidgets`:

| Class | `getType()` returns |
|-------|-------------------|
| `HeatmapWidget` | `'heatmap'` |
| `BarChartWidget` | `'barchart'` |
| `HistogramWidget` | `'histogram'` |
| `ScatterWidget` | `'scatter'` |
| `ImageWidget` | `'image'` |
| `MultiStatusWidget` | `'multistatus'` |

### HeatmapWidget

**File**: `libs/Dashboard/HeatmapWidget.m`
**Purpose**: 2D color grid for visualizing matrices — sensor values over time-of-day vs. day-of-week, spatial temperature maps.

| Property | Type | Description |
|----------|------|-------------|
| `Sensor` | Sensor | Primary data source |
| `DataFcn` | function_handle | Alternative: callback returning matrix |
| `Colormap` | string or Nx3 | Colormap name or matrix (default `'parula'`) |
| `ShowColorbar` | logical | Show colorbar (default `true`) |
| `XLabels` | cell array | Optional axis labels |
| `YLabels` | cell array | Optional axis labels |

**Renders with**: `imagesc` or `pcolor` + `colorbar` on a standard `axes`.

### BarChartWidget

**File**: `libs/Dashboard/BarChartWidget.m`
**Purpose**: Horizontal or vertical bars for comparing discrete categories.

| Property | Type | Description |
|----------|------|-------------|
| `Sensor` | Sensor or Sensor array | Data source(s) |
| `DataFcn` | function_handle | Alternative: callback returning struct with `categories` and `values` |
| `Orientation` | `'vertical'` \| `'horizontal'` | Bar direction (default `'vertical'`) |
| `Stacked` | logical | Stacked bars when multiple sensors (default `false`) |

**Renders with**: `bar` or `barh`.

### HistogramWidget

**File**: `libs/Dashboard/HistogramWidget.m`
**Purpose**: Distribution of sensor values with bin counts.

| Property | Type | Description |
|----------|------|-------------|
| `Sensor` | Sensor | Data source |
| `DataFcn` | function_handle | Alternative: callback returning numeric vector |
| `NumBins` | integer | Number of bins (default auto) |
| `ShowNormalFit` | logical | Overlay normal distribution curve (default `false`) |
| `EdgeColor` | RGB | Bin edge color |

**Renders with**: `bar` on computed bin edges (for Octave compatibility, not `histogram`).

### ScatterWidget

**File**: `libs/Dashboard/ScatterWidget.m`
**Purpose**: X vs. Y scatter plot correlating two sensors.

| Property | Type | Description |
|----------|------|-------------|
| `SensorX` | Sensor | X-axis data |
| `SensorY` | Sensor | Y-axis data |
| `SensorColor` | Sensor | Optional: color-code points by a third sensor |
| `MarkerSize` | scalar | Point size (default `6`) |
| `Colormap` | string or Nx3 | Colormap for color-coded mode |

**Renders with**: `scatter` or `line(..., 'LineStyle', 'none', 'Marker', '.')` for Octave fallback.

### ImageWidget

**File**: `libs/Dashboard/ImageWidget.m`
**Purpose**: Display a static image — plant layouts, P&ID diagrams, camera snapshots.

| Property | Type | Description |
|----------|------|-------------|
| `File` | string | Path to image file (PNG, JPG). File existence validated before `imread`. |
| `ImageFcn` | function_handle | Alternative: callback returning image matrix |
| `Scaling` | `'fit'` \| `'fill'` \| `'stretch'` | How image fits the widget area (default `'fit'`) |
| `Caption` | string | Optional caption below image |

**Renders with**: `image` with `axis image` for aspect ratio. SVG is not supported (neither base MATLAB nor Octave can read SVG via `imread`).

### MultiStatusWidget

**File**: `libs/Dashboard/MultiStatusWidget.m`
**Purpose**: Grid of colored status indicators — monitor many sensors at a glance.

| Property | Type | Description |
|----------|------|-------------|
| `Sensors` | Sensor array | Array of sensors with ThresholdRules. Note: this widget uses `Sensors` (plural) instead of the inherited `Sensor` property. The base class `Sensor` property is unused and `toStruct` is fully overridden to serialize `Sensors` as an array of sensor keys. |
| `Columns` | integer | Grid column count (default auto based on count) |
| `ShowLabels` | logical | Show sensor display name next to each dot (default `true`) |
| `IconStyle` | `'dot'` \| `'square'` \| `'icon'` | Indicator shape (default `'dot'`) |

**Renders with**: `patch` or `rectangle` objects + `text` labels, colored by `ThresholdRule.Color`.

---

## Compatibility

- **MATLAB**: R2020b+ (pure `figure`, `uipanel`, `uicontrol`, `axes` — no App Designer)
- **Octave**: Compatible via same rendering primitives. Known limitations: tab button styling and border radius have no visual effect on Octave; tests skip rendering assertions for those features using `if exist('OCTAVE_VERSION', 'builtin')` guards.
- **No new dependencies**: All rendering uses base MATLAB/Octave graphics

## Testing

Each new widget and each GroupWidget mode gets:
- Unit tests for construction, property validation, render, refresh, serialize/deserialize
- Integration test with DashboardEngine (add to dashboard, verify layout)
- Round-trip serialization test (JSON save → load → `toStruct` equality check)
- Octave compatibility test (skip tab styling and border radius assertions on Octave)
- GroupWidget-specific: collapse/expand reflow test, tab switching test, nesting depth enforcement test, 0-tab edge case test, `setTimeRange` cascade test
