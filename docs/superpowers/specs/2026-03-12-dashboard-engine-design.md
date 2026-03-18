# Dashboard Engine Design

## Overview

A flexible dashboarding system for FastPlot inspired by TrendMiner. Users create dashboards containing multiple FastPlot instances and lightweight widgets (KPIs, gauges, status indicators, tables, event timelines) arranged on a responsive 24-column snap grid. Dashboards support drag-and-resize editing, Sensor/ThresholdRule integration, global live mode, and JSON serialization with `.m` script export.

**Constraints:**
- MATLAB R2020b compatible — figure-based only (no `uifigure`, no App Designer)
- Builds on existing FastPlot API — reuses `FastPlot`, `FastPlotToolbar`, `FastPlotTheme`, `Sensor`, `ThresholdRule`, `DataStore`, `EventViewer`
- Each dashboard is a single `figure()` handle

## Architecture

### Approach: Thin Wrapper

A new `DashboardEngine` class that orchestrates layout, widgets, live mode, and serialization. It does not replace `FastPlotFigure` — it uses FastPlot instances internally and adds lightweight widget classes alongside them.

### Class Hierarchy

```
DashboardEngine          — top-level orchestrator
├── DashboardLayout      — responsive 24-col grid, snap, drag, resize
├── DashboardToolbar     — global controls (live, theme, export, edit mode)
├── DashboardTheme       — extends FastPlotTheme with dashboard properties
├── DashboardSerializer  — JSON load/save, .m export
├── DashboardBuilder     — GUI builder overlay (edit mode)
└── widgets/
    ├── DashboardWidget  — abstract base class
    ├── FastPlotWidget   — wraps FastPlot + Sensor + ThresholdRule
    ├── RawAxesWidget    — bar/scatter/histogram (raw MATLAB axes)
    ├── NumberWidget        — big number with label, trend arrow
    ├── GaugeWidget      — circular gauge with range
    ├── StatusWidget     — colored indicator (OK/Warn/Alarm)
    ├── TableWidget      — tabular data display
    ├── TextWidget       — static labels / section headers
    └── EventTimelineWidget — wraps EventViewer
```

### Relationships

- `DashboardEngine` owns one `figure()` handle
- `DashboardLayout` manages a 24-column grid of `uipanel` containers, one per widget
- Each `DashboardWidget` subclass renders into its assigned `uipanel`
- `FastPlotWidget` creates a `FastPlot` instance inside its panel — full reuse of zoom/pan/thresholds/downsampling
- When a `Sensor` is bound to a `FastPlotWidget`, its `ThresholdRule`s automatically apply
- `DashboardEngine` holds the global live timer — on tick, calls `refresh()` on every widget

## Data Binding Model

Three ways to feed data into widgets:

### 1. Sensor Binding (richest)

```matlab
w = FastPlotWidget('Sensor', mySensor);
```

- Data from `Sensor.DataStore`
- `ThresholdRule`s auto-resolve (including condition-dependent via `StateChannel`)
- Violation markers and bands render automatically
- Widget title defaults to `Sensor.Name` if not overridden

### 2. DataStore / .mat File Binding

```matlab
w = FastPlotWidget('DataStore', myStore);
w = FastPlotWidget('File', 'data/temperature.mat', 'XVar', 't', 'YVar', 'T');
```

`.mat` files are loaded and wrapped in a `FastPlotDataStore` automatically.

### 3. Callback Binding (simple widgets)

```matlab
w = NumberWidget('Label', 'Current Temp', 'ValueFcn', @() readTemp());
w = GaugeWidget('Label', 'Pressure', 'ValueFcn', @() getPressure(), ...
                'Range', [0 100], 'Units', 'bar');
w = StatusWidget('Label', 'Pump 1', 'StatusFcn', @() getPumpStatus());
```

`ValueFcn` returns a scalar or struct `{value, unit, trend}`. `StatusFcn` returns `'ok'`, `'warning'`, or `'alarm'`.

### Live Refresh

Global toggle. One shared timer in `DashboardEngine`. On tick:
- `FastPlotWidget.refresh()` → calls `FastPlot.refresh()` (existing API)
- Simple widgets → call their `ValueFcn`/`StatusFcn` and update display

Timer lifecycle: the timer is created on `startLive()` and deleted on `stopLive()`. The figure's `CloseRequestFcn` calls `stopLive()` before `delete(gcf)` to prevent orphaned timers (follows the same pattern as `FastPlotFigure`).

## Layout Engine

### 12-Column Responsive Grid

- Widgets snap to column boundaries on drag/resize
- Minimum widget size: 2 columns wide, 1 row tall
- Drag: click title bar to move, snaps to nearest grid cell
- Resize: drag bottom-right corner handle, snaps to grid
- Auto-compact: widgets push up to fill gaps (gravity toward top-left)
- Overlap handling: if a widget is placed (via API or JSON) at a position that overlaps an existing widget, the existing widget is pushed down to the next available row
- Edit mode toggle: drag/resize only active when "Edit" is on

### R2020b Implementation

- Grid cells mapped to normalized `uipanel` positions within the figure
- Drag: `WindowButtonMotionFcn` + `WindowButtonUpFcn` on figure
- Resize: corner `uicontrol` with same motion callbacks
- Grid snap: round position to nearest grid cell on mouse-up
- Column width = `(1 - leftPadding - rightPadding - (23 * gap)) / 24`
- Row height configurable, default auto-calculated from figure height

## Widget Specifications

| Widget | Renders with | Data binding | Default size |
|---|---|---|---|
| FastPlotWidget | `FastPlot` instance (full zoom/pan/downsample) | Sensor, DataStore, or .mat file | 6×3 |
| RawAxesWidget | MATLAB `axes()` — bar, scatter, histogram | `PlotFcn` callback receiving an `axes` handle — user calls `bar(ax,...)` etc. | 4×2 |
| NumberWidget | Big number + label + optional trend arrow | `ValueFcn` → scalar or struct | 3×1 |
| GaugeWidget | Circular arc with `patch()`/`line()` | `ValueFcn` → scalar, plus Range, Units | 4×2 |
| StatusWidget | Colored circle (`patch`) + label | `StatusFcn` → `'ok'`/`'warning'`/`'alarm'` | 2×1 |
| TableWidget | `uitable()` inside panel | `DataFcn` → cell array or table | 4×2 |
| TextWidget | `uicontrol('Style','text')` | Static — configured at creation | 3×1 |
| EventTimelineWidget | Wraps `EventViewer` (Gantt bars) | `EventDetector` or event array | 12×2 |

### DashboardWidget Base Class

All widgets implement:
- `render(parentPanel)` — create graphics objects inside the panel
- `refresh()` — update data/display (called by live timer)
- `toStruct()` — serialize widget config to struct
- `fromStruct(s)` — restore widget from struct (static factory)
- `getType()` — return widget type string

## GUI Builder (Edit Mode)

### Layout

Three-panel layout when edit mode is active:
- **Left sidebar** — widget palette with all 8 widget types as clickable buttons
- **Center** — the dashboard grid with edit overlays on each widget
- **Right sidebar** — properties panel for the selected widget

### Edit Overlays

Each widget gets:
- **Drag handle** — colored title bar at top, cursor changes to move
- **Delete button** — × button at top-right corner
- **Config button** — gear icon, opens properties panel for this widget
- **Resize handle** — bottom-right corner, cursor changes to nwse-resize
- **Grid lines** — faint column guides visible in background

### Properties Panel

When a widget is selected (via gear button), the right sidebar shows:
- Title (editable text field)
- Data source (Sensor picker, file browser, or callback name)
- Thresholds (auto from Sensor, or manual override)
- Grid position (col, row — editable)
- Size (width in cols, height in rows — editable)
- Theme override (dropdown: inherit / preset name)

### Behavior

- Live mode is disabled during editing
- Save persists current layout to JSON
- Cancel reverts to last saved state
- Adding a widget: click type in palette → placed in next empty grid slot
- Widget palette uses `uicontrol('Style','pushbutton')` buttons in a `uipanel`
- Properties panel uses `uicontrol('Style','edit')` and `uicontrol('Style','popupmenu')`

## Serialization

### JSON Format

```json
{
  "name": "Process Monitoring — Line 4",
  "theme": "dark",
  "liveInterval": 5,
  "grid": {"columns": 24},
  "widgets": [
    {
      "type": "fastplot",
      "title": "Temperature Trend",
      "position": {"col": 1, "row": 2, "width": 8, "height": 3},
      "source": {"type": "sensor", "name": "T-401"},
      "thresholds": "auto"
    },
    {
      "type": "kpi",
      "title": "Current Temp",
      "position": {"col": 1, "row": 1, "width": 3, "height": 1},
      "source": {"type": "callback", "function": "readTemp"}
    }
  ]
}
```

`"thresholds": "auto"` means inherit from the Sensor's ThresholdRules.

**Callback resolution in JSON:** Callback strings (e.g. `"function": "readTemp"`) are resolved via `str2func` on load, so the function must be on the MATLAB path. Anonymous functions and closures cannot be serialized to JSON — use `.m` scripts for those. The GUI builder warns if a widget uses a non-serializable callback on save.

### Programmatic API

```matlab
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'dark';
d.LiveInterval = 5;

d.addWidget('fastplot', 'Title', 'Temperature Trend', ...
    'Position', [1 2 8 3], ...
    'Sensor', SensorRegistry.get('T-401'));

d.addWidget('kpi', 'Title', 'Current Temp', ...
    'Position', [1 1 3 1], ...
    'ValueFcn', @readTemp);

d.addWidget('gauge', 'Title', 'Pressure', ...
    'Position', [9 2 4 2], ...
    'File', 'data/pressure.mat', 'Var', 'P', ...
    'Range', [0 100], 'Units', 'bar');

d.render();
```

### Loading and Saving

```matlab
d = DashboardEngine.load('dashboards/process_line4.json');
d.render();

d.save('dashboards/process_line4.json');
d.exportScript('dashboards/process_line4.m');
```

Position format: `[col, row, width, height]` in grid units.

## Dashboard Theme Extensions

`DashboardTheme` is a function that calls `FastPlotTheme()` and appends dashboard-specific fields to the returned struct (since `FastPlotTheme` is a struct-returning function, not a class):

| Property | Description |
|---|---|
| DashboardBackground | Figure background color |
| WidgetBackground | Widget panel background |
| WidgetBorderColor | Panel border color |
| WidgetBorderWidth | Border width in pixels |
| DragHandleColor | Edit mode drag handle color |
| DropZoneColor | Empty cell dashed border color |
| ToolbarBackground | Toolbar panel background |
| ToolbarFontColor | Toolbar text color |
| HeaderFontSize | Dashboard title font size |
| WidgetTitleFontSize | Widget title font size |
| StatusOkColor | Green for OK status |
| StatusWarnColor | Yellow/orange for warnings |
| StatusAlarmColor | Red for alarms |
| GaugeArcWidth | Gauge arc stroke width |
| KpiFontSize | Big number font size in KPI widgets |

Cascade: `DashboardTheme` → per-widget theme override → element-level override. All 6 existing presets get dashboard extensions.

## Implementation Phasing

### Phase 1: Core API
`DashboardEngine`, `DashboardLayout`, `DashboardWidget` base class, `FastPlotWidget`, `DashboardSerializer` (JSON load/save). Minimum viable dashboard — FastPlot tiles on a 24-column grid with Sensor/ThresholdRule integration and live mode.

### Phase 2: Simple Widgets
`NumberWidget`, `StatusWidget`, `TextWidget`, `GaugeWidget`. Lightweight figure-based widgets with callback data binding.

### Phase 3: Complex Widgets
`TableWidget`, `RawAxesWidget`, `EventTimelineWidget`. These have more rendering complexity and external dependencies.

### Phase 4: GUI Builder
Edit mode, widget palette, drag/resize with snap, properties panel, `DashboardBuilder` class. This is the most complex phase due to R2020b mouse callback constraints.

### Phase 5: Polish
`.m` export via `DashboardSerializer.exportScript()`, `DashboardTheme` extensions with all 6 preset variants, toolbar refinements.

## Testing Strategy

Each phase gets its own test classes:
- `TestDashboardEngine` — creation, render, live timer, save/load round-trip
- `TestDashboardLayout` — grid positioning, snap logic, overlap detection, auto-compact
- `TestDashboardWidget` (per type) — render, refresh, toStruct/fromStruct round-trip
- `TestDashboardSerializer` — JSON parse/emit, `.m` export validity
- `TestDashboardBuilder` — edit mode enter/exit, widget add/remove/move/resize
- `TestDashboardTheme` — cascade inheritance, preset extensions
