<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24-column responsive |
| Tile content | FastSense instances only | 16 widget types (plots, gauges, KPIs, tables, images, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto-scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor binding | Via `addSensor` per tile | Direct widget property (auto-title, auto-units) |
| Live mode | Per-figure timer | Engine-level timer refreshing all widgets |
| Multi-page | No | Named pages with tabs |

**When to use FastSenseGrid:** A simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** Mixed widget types, grouping, pagination, JSON persistence, or the visual editor.

---

## Quick Start

```matlab
install;

% Create some data
x = linspace(0, 100, 10000);
y = sin(x) + 0.1 * randn(size(x));

% Build a dashboard
d = DashboardEngine('My First Dashboard');
d.Theme = 'dark';

d.addWidget('fastsense', 'Title', 'Signal', ...
    'Position', [1 1 24 6], ...
    'XData', x, 'YData', y);

d.addWidget('number', 'Title', 'Latest Value', ...
    'Position', [1 7 8 2], ...
    'StaticValue', y(end), 'Units', 'V');

d.render();
```

---

## Grid System

DashboardEngine uses a **24-column grid**. Widget positions are specified as:

```
Position = [col, row, width, height]
```

- `col`: column (1–24), left to right
- `row`: row (1+), top to bottom
- `width`: number of columns to span (1–24)
- `height`: number of rows to span

Examples:
```matlab
[1 1 24 4]   % Full width, 4 rows tall, top of dashboard
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

If a new widget overlaps an existing one, it is automatically pushed down to the next free row.

---

## Widget Types

DashboardEngine supports a rich set of widget types, each designed for a specific monitoring or display need. All widgets inherit from `DashboardWidget` and share common properties (Title, Position, Tag, ThemeOverride, Description). Every widget can be added by calling `d.addWidget(<type>, ...)` with optional name–value pairs.

### FastSenseWidget (time series)

The primary plotting widget, backed by FastSense. Supports multiple data sources and automatic threshold rendering.

```matlab
% Sensor-bound (still works, but see Tag system below)
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', mySensor);

% Inline data
d.addWidget('fastsense', 'Title', 'Raw', 'Position', [13 1 12 8], ...
    'XData', x, 'YData', y);

% From MAT file
d.addWidget('fastsense', 'Title', 'File', 'Position', [1 9 24 6], ...
    'File', 'data.mat', 'XVar', 'x', 'YVar', 'y');

% From DataStore
d.addWidget('fastsense', 'Title', 'Store', 'Position', [1 15 24 6], ...
    'DataStore', myDataStore);
```

When bound to a Sensor, threshold rules apply automatically. The widget title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto-derived.

Additional properties: `XLabel`, `YLabel`, `YLimits`, `ShowThresholdLabels`, `ShowEventMarkers`, `LiveViewMode`.  
See [[API Reference: Dashboard]] for a full property list.

### RawAxesWidget (custom plots)

Embed any MATLAB plot into a dashboard by providing a function handle that draws on a raw axes.

```matlab
d.addWidget('rawaxes', 'Title', 'Temperature Distribution', ...
    'Position', [1 5 8 4], ...
    'PlotFcn', @(ax) histogram(ax, tempData, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

% Sensor-bound with time range
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Sensor', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

The `PlotFcn` receives the MATLAB axes as the first argument. When a Sensor is bound, it also receives the Sensor object and optionally the current time range.  
Use `DataRangeFcn` to return `[tMin tMax]` for global time control.

### ScatterWidget

Compare two sensors by plotting one against the other. An optional third sensor can color the markers.

```matlab
d.addWidget('scatter', 'Title', 'T vs P', ...
    'Position', [1 9 8 4], ...
    'SensorX', sTemp, 'SensorY', sPress);
```

Properties: `SensorX`, `SensorY`, `SensorColor`, `MarkerSize`, `Colormap`.

### BarChartWidget

Display categorical or time‑binned data as vertical or horizontal bars.

```matlab
d.addWidget('barchart', 'Title', 'Production', ...
    'Position', [1 13 8 4], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, 'values', [12 5 8]));
```

Properties: `DataFcn`, `Orientation` (`'vertical'` or `'horizontal'`), `Stacked`.

### HistogramWidget

Draw a histogram from a dynamic data source.

```matlab
d.addWidget('histogram', 'Title', 'Distribution', ...
    'Position', [9 13 8 4], ...
    'DataFcn', @() randn(1, 1000), 'NumBins', 30);
```

Properties: `DataFcn`, `NumBins`, `ShowNormalFit`, `EdgeColor`.

### HeatmapWidget

Visualise a matrix as a coloured heatmap.

```matlab
d.addWidget('heatmap', 'Title', 'Correlation', ...
    'Position', [1 17 8 4], ...
    'DataFcn', @() corrcoef(randn(5,100)'));
```

Properties: `DataFcn`, `Colormap`, `ShowColorbar`, `XLabels`, `YLabels`.

### NumberWidget (big value display)

The classic “KPI tile”. Shows a large number, a trend arrow, and unit label.

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Or with a function callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%');
```

Properties: `ValueFcn` (scalar or struct), `Units`, `Format`, `StaticValue`.

### SparklineCardWidget

A KPI card that combines a large number with a miniature sparkline chart and a delta indicator. Ideal for trend‑rich compact displays.

```matlab
d.addWidget('sparkline', 'Title', 'CPU', ...
    'Position', [7 1 6 2], ...
    'Sensor', sCpu, 'Units', '%', 'Format', '%.1f', ...
    'NSparkPoints', 50, 'ShowDelta', true);
```

Properties: `StaticValue`, `ValueFcn`, `Units`, `Format`, `NSparkPoints`, `ShowDelta`, `DeltaFormat`, `SparkColor`, `SparkData`.  
The sparkline automatically uses the last `NSparkPoints` from the sensor data.

### IconCardWidget

A compact “mushroom card” with a coloured icon, primary value, and label. The icon colour reflects state (ok/warn/alarm) from a Sensor, a state function, or a static override.

```matlab
d.addWidget('iconcard', 'Title', 'Pump', ...
    'Position', [13 1 6 2], ...
    'Sensor', sPump, 'SecondaryLabel', 'Supply');
```

Properties: `IconColor` (`'auto'` or RGB), `StaticValue`, `ValueFcn`, `StaticState`, `Units`, `Format`, `SecondaryLabel`, `Threshold`.

### GaugeWidget (arc/donut/bar/thermometer)

Provides four styles to show a value relative to a range. Automatically derives range and units from sensor thresholds when used with a Sensor.

```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Style', 'donut');

% Static value with fixed range
d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', ...
    'Style', 'arc');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`.  
Properties: `ValueFcn`, `Range`, `Units`, `StaticValue`, `Style`, `Threshold`.

### StatusWidget (health indicator)

A coloured dot and the sensor’s latest value. Colour is determined automatically from threshold rules when a Sensor is bound, or manually via `StaticStatus` or `Threshold` + `Value`/`ValueFcn`.

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Properties: `StatusFcn`, `StaticStatus`, `Threshold`, `Value`, `ValueFcn`.

### MultiStatusWidget

A grid of coloured status dots, each driven by its own Sensor. Compact multi‑point health overview.

```matlab
d.addWidget('multistatus', 'Title', 'Tank Farm', ...
    'Position', [1 5 6 2], ...
    'Sensors', {sTemp1, sTemp2, sTemp3});
```

Properties: `Sensors`, `Columns`, `ShowLabels`, `IconStyle`.

### ChipBarWidget

A horizontal row of mini status chips — compact, colour‑coded circles with labels. Use for a dense, at‑a‑glance system health bar.

```matlab
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 11 12 1], ...
    'Chips', { ...
        struct('label', 'Pump',  'statusFcn', @() 'ok'), ...
        struct('label', 'Tank',  'statusFcn', @() 'warn'), ...
        struct('label', 'Fan',   'statusFcn', @() 'alarm') ...
    });
```

Properties: `Chips` — cell array of structs with fields: `label`, `sensor`, `statusFcn`, `iconColor`.

### TableWidget (data display)

Displays static data, live sensor data, event logs, or custom callback‑driven tables.

```matlab
% Static data
d.addWidget('table', 'Title', 'Alarm Log', ...
    'Position', [13 9 12 4], ...
    'ColumnNames', {'Time', 'Tag', 'Value'}, ...
    'Data', {{'12:00', 'T-401', '85.2'; '12:05', 'P-201', '72.1'}});

% Sensor data (last N rows)
d.addWidget('table', 'Title', 'Recent Data', ...
    'Position', [1 9 12 4], ...
    'Sensor', sTemp, 'N', 15);

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Sensor', mySensor, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

Properties: `DataFcn`, `Data`, `ColumnNames`, `Mode`, `N`, `EventStoreObj`.

### EventTimelineWidget

Visualises events as coloured bars on a horizontal timeline. Can bind to an `EventStore` from the event detection system, or use legacy event arrays.

```matlab
% From EventStore (recommended)
d.addWidget('timeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], ...
    'EventStoreObj', myEventStore);

% Filtered by sensor names
d.addWidget('timeline', 'Title', 'Temp Events', ...
    'Position', [1 19 24 3], ...
    'EventStoreObj', myEventStore, ...
    'FilterSensors', {'T-401', 'T-402'});
```

Properties: `EventStoreObj`, `Events`, `EventFcn`, `FilterSensors`, `FilterTagKey`, `ColorSource`.

### TextWidget and DividerWidget

Static layout helpers. `TextWidget` displays a centred label, header, or description. `DividerWidget` draws a horizontal line for visual separation.

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 - Shift A', 'FontSize', 16, ...
    'Alignment', 'center');

d.addWidget('divider', 'Position', [1 2 24 1], 'Thickness', 2);
```

### ImageWidget

Display a static image (PNG, JPG) in a dashboard tile.

```matlab
d.addWidget('image', 'Title', 'Site Map', ...
    'Position', [1 21 8 4], ...
    'File', 'site_map.png');
```

Properties: `File`, `ImageFcn`, `Scaling`, `Caption`.

---

## Sensor and Tag Binding

Widgets can be data‑driven through Sensor objects (for backwards compatibility) or through the newer `Tag` property. In practice, the `'Sensor'` name–value pair in `addWidget` still works — it is an alias that sets the widget’s `Tag` property to the sensor object.

```matlab
% Create and configure sensor
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;

sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% All of these auto-derive from the Sensor:
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number',    'Sensor', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status',    'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge',     'Sensor', sTemp, 'Position', [13 3 12 6]);
```

Benefits:
- **Title:** auto‑derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto‑derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, status, etc.
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations
- **Live refresh:** `refresh()` re‑reads the sensor data

The underlying `Tag` property accepts any Tag subclass (including `MonitorTag`, `ThresholdTag`). Advanced features like auto‑derived ranges and status states work through Tag interfaces.

---

## Group Widgets and Collapsible Sections

Arrange related widgets into a panel, an accordion, or a tabbed container using `GroupWidget`. Available modes:

- `'panel'` — a bordered box with an optional header (default)
- `'collapsible'` — a box that can be expanded/collapsed by the user
- `'tabbed'` — tabs to switch between sets of widgets

Add a group directly:

```matlab
% Panel
w1 = DashboardWidget('Title', 'Temp', ...); % pseudo
w2 = DashboardWidget('Title', 'Press', ...);
d.addWidget('group', 'Label', 'Sensors', ...
    'Position', [1 5 12 6], ...
    'Children', {w1, w2});
```

Convenience methods:

- `d.addCollapsible('Sensors', {w1, w2}, 'Collapsed', false)` — creates a collapsible group.
- `d.addPage('Overview')` to add a named page (see multi‑page).

Child widgets can be created inline or pre‑constructed. For dynamic child layout, set `ChildAutoFlow = true` (default).  
Properties: `Mode`, `Label`, `Collapsed`, `Children`, `Tabs`, `ActiveTab`, `ChildColumns`, `ChildAutoFlow`, `ReflowCallback`.

Nested groups (up to a depth limit) are supported, allowing complex layouts.

---

## Multi‑Page Dashboards

Dashboards can be organised into named pages, each with its own set of widgets. Page tabs appear between the toolbar and the content area.

```matlab
d = DashboardEngine('Multi-Page Demo');
d.Theme = 'light';

% Add pages
d.addPage('Overview');
d.addPage('Details');

% Widgets go to the active page (last added by default)
d.addWidget('text', 'Title', 'Over1', ...);
d.addWidget('fastsense', ...);

d.switchPage(1);  % switch back to Overview (optional)
d.addWidget('number', ...);

d.render();
```

The active page index can be changed programmatically with `d.switchPage(idx)`. The toolbar and time controls remain common. Saving and loading fully preserve multi‑page structure.

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON file captures the dashboard name, theme, live interval, grid settings, and every widget’s type, title, position, and data source. Multi‑page dashboards are stored as an array of pages.

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re‑bind Sensor objects on load, provide a resolver function:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### Export as MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` file with `DashboardEngine` constructor, `addPage` calls, and `addWidget` invocations that recreate the dashboard exactly. The generated script is re‑loadable via `DashboardEngine.load`.

---

## Theming

DashboardEngine uses `DashboardTheme`, an extension of `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, borders, status colours, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';          % Primary presets: 'light' or 'dark'
d.render();
```

The `'dark'` and `'light'` presets are the core supported themes. Legacy names `'default'`, `'industrial'`, `'scientific'`, `'ocean'` are aliased to `'light'` for backwards compatibility.

Override specific theme attributes:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

Widgets also accept a `ThemeOverride` struct, applied on top of the dashboard theme.

---

## Live Mode

DashboardEngine supports live data updates via a timer that periodically calls `refresh()` on all widgets.

```matlab
d = DashboardEngine('Live Monitor');
d.LiveInterval = 2;  % refresh every 2 seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % start periodic refresh

% ... later
d.stopLive();    % stop
```

The toolbar’s Live button toggles the live timer and visually indicates active state. The last update timestamp is shown in the toolbar.

---

## Global Time Controls

A bottom panel with two sliders defines the visible time window applied to every widget that has `UseGlobalTime = true`.

- Moving the sliders broadcasts `setTimeRange(tStart, tEnd)` to all widgets.
- If a user manually zooms a widget, that widget detaches (`UseGlobalTime = false`) and no longer follows the global sliders.
- Click the **Sync** button in the toolbar to re‑attach all widgets and reset to the full data range.

Time‑aware widgets include `FastSenseWidget`, `EventTimelineWidget`, `RawAxesWidget`, and any widget implementing `setTimeRange`.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type.
2. A **properties panel** appears on the right showing the selected widget’s settings.
3. **Drag handles** let you reposition widgets on the grid.
4. **Resize handles** let you change widget dimensions.
5. Click **Apply** to save property changes.
6. Click **Done** to exit edit mode.

The editor snaps to the 24‑column grid. You can change the widget’s title, position, axis labels, and data source directly in the properties panel.

Programmatic management functions:
- `addWidget(type)` — add a new widget
- `deleteWidget(idx)` — remove widget by index
- `selectWidget(idx)` — select a widget
- `setWidgetPosition(idx, pos)` — move/resize widget

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

An **Info** button in the toolbar renders the Markdown as HTML (via the built-in `MarkdownRenderer`) and displays it in a modal in-app browser or the system browser
