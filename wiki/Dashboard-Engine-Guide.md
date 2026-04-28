<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, a visual editor, and multi‑page support.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows x cols | 24‑column responsive |
| Tile content | FastSense instances only | 15+ widget types (plots, gauges, numbers, tables, images, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets + data‑preview envelope |
| Sensor binding | Via addSensor per tile | Direct widget property (auto‑title, auto‑units) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets + stale‑data detection |
| Multi‑page | No | Yes – addPage / switchPage |
| Chrome customisation | Toolbar only | ShowTimePanel, EventMarkersVisible, Config dialog |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines, images), JSON persistence, multi‑page dashboards, or the visual editor.

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

DashboardEngine uses a **24‑column grid**. Widget positions are specified as:

```
Position = [col, row, width, height]
```

- `col`: column (1–24), left to right
- `row`: row (1+), top to bottom
- `width`: number of columns to span (1–24)
- `height`: number of rows to span (minimum ~0.22 per row in height)

Examples:
```matlab
[1 1 24 4]   % Full width, 4 rows tall, top of dashboard
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

If a new widget overlaps an existing one, it is automatically pushed down to the next free row. The layout supports scrolling when the content height exceeds the viewport.

---

## Widget Types

### FastSense (time series)

```matlab
% Sensor‑bound (recommended)
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

When bound to a Sensor, threshold rules apply automatically (resolved violations are shown). Title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived. You can also show event markers by setting `ShowEventMarkers = true` and providing an `EventStore`.

### Number (big value display)

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Function callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data. Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'

% Threshold‑bound (no sensor)
d.addWidget('status', 'Title', 'Pressure', ...
    'Position', [1 3 5 2], ...
    'Threshold', t, 'ValueFcn', @() getPressure());
```

Shows a colored dot (green/amber/red) and the sensor’s latest value. Status is derived automatically from threshold rules.

### MultiStatus (grid of sensor status dots)

```matlab
d.addWidget('multistatus', 'Title', 'Vessels', ...
    'Position', [1 3 8 4], ...
    'Sensors', {s1, s2, s3}, 'Columns', 2, 'IconStyle', 'dot');
```

### Gauge (arc/donut/bar/thermometer)

```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Range', [0 160], 'Units', 'L/min', ...
    'Style', 'donut');

% Static value
d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', ...
    'Style', 'arc');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`.

When Sensor‑bound, range and units are auto‑derived from threshold rules and sensor properties.

### Text (labels and headers)

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 – Shift A', 'FontSize', 16, ...
    'Alignment', 'center');
```

### Divider (horizontal rule)

```matlab
d.addWidget('divider', 'Position', [1 3 24 1], 'Thickness', 2);
```

Thickness levels: 1 (thin), 2 (medium), 3 (thick). Color can be overridden with the `Color` property.

### Table (data display)

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

% Dynamic data via callback
d.addWidget('table', 'Title', 'Live Log', ...
    'Position', [1 13 12 4], ...
    'DataFcn', @() getRecentAlarms(), ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Level'});

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Sensor', mySensor, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

### Raw Axes (custom plots)

```matlab
d.addWidget('rawaxes', 'Title', 'Temperature Distribution', ...
    'Position', [1 5 8 4], ...
    'PlotFcn', @(ax) histogram(ax, tempData, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

% Sensor‑bound with time range
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Sensor', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

PlotFcn receives MATLAB axes as the first argument. When Sensor‑bound it also receives the Sensor object and optionally a time range (`tRange`). Provide `DataRangeFcn` to contribute to the global time range.

### Event Timeline

```matlab
% From event structs (legacy)
events = struct('startTime', {0, 3600}, 'endTime', {3600, 7200}, ...
    'label', {'Idle', 'Running'}, 'color', {[0.6 0.6 0.6], [0.2 0.7 0.3]});

d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], ...
    'Events', events);

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

### ChipBar (compact multi‑status strip)

```matlab
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 1 24 1], ...
    'Chips', { ...
        struct('label', 'Pump',  'statusFcn', @() 'ok'), ...
        struct('label', 'Tank',  'statusFcn', @() 'warn'), ...
        struct('label', 'Fan',   'statusFcn', @() 'alarm') ...
    });
```

Each chip has a colored dot and a label. Status can be driven by sensors.

### IconCard (mushroom‑style KPI card)

```matlab
d.addWidget('iconcard', 'Title', 'Temperature', ...
    'Position', [1 1 6 3], ...
    'StaticValue', 23.5, 'Units', '°C', ...
    'StaticState', 'ok');
```

Supports `Sensor`, `ValueFcn`, threshold‑derived icon color.

### SparklineCard (KPI with mini‑chart)

```matlab
d.addWidget('sparkline', 'Title', 'CPU Load', ...
    'Position', [1 1 6 3], ...
    'StaticValue', 42, 'SparkData', cpuHistory, 'Units', '%');
```

Displays a big number, a delta indicator, and a small sparkline of the last N points (default 50). Supports `Sensor` or inline `SparkData`.

### BarChart and Histogram

```matlab
d.addWidget('barchart', 'Title', 'Throughput', ...
    'Position', [1 1 6 3], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, 'values', [30 45 20]), ...
    'Orientation', 'vertical');

d.addWidget('histogram', 'Title', 'Distribution', ...
    'Position', [7 1 6 3], ...
    'DataFcn', @() randn(1,1000), ...
    'NumBins', 50, 'ShowNormalFit', true);
```

### Heatmap

```matlab
d.addWidget('heatmap', 'Title', 'Correlation', ...
    'Position', [1 1 8 6], ...
    'DataFcn', @() corr(rand(10,5)), ...
    'XLabels', {'V1','V2','V3','V4','V5'}, ...
    'YLabels', {'V1','V2','V3','V4','V5'}, ...
    'ShowColorbar', true);
```

### Image

```matlab
d.addWidget('image', 'Title', 'Floor Plan', ...
    'Position', [1 1 12 8], ...
    'File', 'floorplan.png', ...
    'Scaling', 'fit', 'Caption', 'Level 1');
```

Supports `ImageFcn` returning an image matrix as an alternative to a file.

### Scatter (sensor cross‑plots)

```matlab
d.addWidget('scatter', 'Title', 'P vs T', ...
    'Position', [1 1 6 6], ...
    'SensorX', sensorPressure, 'SensorY', sensorTemp, ...
    'SensorColor', sensorFlow, 'MarkerSize', 8);
```

### GroupWidget (panel, collapsible, tabbed)

GroupWidgets organise children in sub‑grids.

```matlab
% Collapsible group
w = GroupWidget('Mode', 'collapsible', 'Label', 'Sensors', ...
    'Collapsed', false);
w.addChild(NumberWidget('Title', 'T1', 'StaticValue', 100));
w.addChild(StatusWidget('Title', 'Pump', 'StaticStatus', 'ok'));
d.addWidget(w);

% Tabbed group
tabs = GroupWidget('Mode', 'tabbed', 'Label', 'Views');
tabs.addChild(NumberWidget('Title', 'Tab A', 'StaticValue', 1), 'Overview');
tabs.addChild(NumberWidget('Title', 'Tab B', 'StaticValue', 2), 'Details');
d.addWidget(tabs);
```

Simplify with convenience methods:
```matlab
d.addWidget('group', 'Mode', 'collapsible', 'Label', 'Controls', ...
    'Children', {w1, w2});
d.addWidget('group', 'Mode', 'tabbed', 'Label', 'Views', ...
    'Tabs', {{'Overview', {w1}}, {'Details', {w2}}});
```

---

## Sensor Binding

The recommended way to drive dashboard widgets is through Sensor objects. Create sensors with data, state channels, and threshold rules, then bind them to widgets:

```matlab
% Create and configure sensor
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;

sc = StateChannel('machine');
sc.X = [0 7200 43200]; sc.Y = [0 1 0];
sTemp.addStateChannel(sc);

sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% Bind to multiple widgets
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status', 'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Sensor', sTemp, 'Position', [13 3 12 6]);
```

Benefits of Sensor binding:

- **Title:** auto‑derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto‑derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, status, iconcard, sparkline widgets
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations; StatusWidget and IconCardWidget derive colour from threshold rules
- **Live refresh:** calling `refresh()` rereads updated sensor data

The `Sensor` property is a backward‑compat alias for the internal `Tag` property (v2.0 Tag API). Any widget that accepts `'Sensor'` also works with `'Tag'`.

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON file contains the dashboard name, theme, live interval, grid settings, and each widget’s type, title, position, and data source. Multi‑page dashboards are fully serialised.

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

Generates a readable `.m` file (a function returning a `DashboardEngine`) that recreates the dashboard. Multi‑page dashboards are emitted with `addPage()` and `switchPage()` calls.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colours, group headers, status indicator colours, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

Available presets: `'dark'` and `'light'`. Older presets (`'industrial'`, `'scientific'`, `'ocean'`) alias to `'light'`.

Override specific properties:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

Relevant dashboard‑specific theme fields: `DashboardBackground`, `WidgetBackground`, `WidgetBorderColor`, `ToolbarBackground`, `ToolbarFontColor`, `DragHandleColor`, `DropZoneColor`, `GridLineColor`, `GroupHeaderBg`, `GroupHeaderFg`, `GroupBorderColor`, `TabActiveBg`, `TabInactiveBg`, `StatusOkColor`, `StatusWarnColor`, `StatusAlarmColor`, `KpiFontSize`, `WidgetTitleFontSize`, etc.

---

## Live Mode

DashboardEngine supports live data updates via a timer that periodically calls `refresh()` on all widgets.

```matlab
d = DashboardEngine('Live Monitor');
d.Theme = 'dark';
d.LiveInterval = 2;   % seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();        % start periodic refresh
% ... later
d.stopLive();         % stop
```

Toggle live mode from the toolbar’s **Live** button (blue border when active). The toolbar shows the last‑update timestamp.

### Stale‑Data Detection

During live mode, the engine tracks the maximum timestamp of each widget. If a widget’s `tMax` does not advance for multiple ticks, a stale‑data banner appears below the toolbar listing the stalled widget titles.

---

## Global Time Controls

The time panel at the bottom (visible when `ShowTimePanel = true`) contains:

- Two time‑range sliders
- An aggregate **envelope** (data‑preview) showing the min/max extents of all contributed widgets
- Event‑marker lines (if widgets expose events)
- Per‑widget down‑sampled line previews

Moving the sliders or dragging the selection window broadcasts the time range to all widgets using `setTimeRange(tStart, tEnd)`.

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the PlotFcn

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** toolbar button to re‑attach all widgets.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type
2. A **properties panel** appears on the right showing the selected widget’s settings
3. **Drag handles** let you reposition widgets on the grid
4. **Resize handles** let you change widget dimensions
5. Click **Apply** to save property changes
6. Click **Done** to exit edit mode

The editor snaps to the 24‑column grid. You can change the widget’s title, position, axis labels, and data source directly in the properties panel.

Widget management functions:
- `addWidget(type)` – add a new widget of the specified type
- `deleteWidget(idx)` – remove widget by index
- `selectWidget(idx)` – select a widget for property editing
- `setWidgetPosition(idx, pos)` – move/resize widget programmatically

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML (using the built‑in `MarkdownRenderer`) and opens it in the system browser. When no file is set, a placeholder page is shown.

---

## Multi‑Page Dashboards

Create tabbed pages within the same dashboard figure:

```matlab
d = DashboardEngine('Multi‑Page');
d.Theme = 'dark';

% Page 1 (default)
d.addWidget('number', 'Title', 'Page 1 Value', 'Position', [1 1 6 2], 'StaticValue', 1);

% Page 2
d.addPage('Details');
d.addWidget('number', 'Title', 'Page 2 Value', 'Position', [1 1 6 2], 'StaticValue', 2);

d.render();
```

Pages are switched with `d.switchPage(idx)` or via the tab bar that appears automatically at the top.

When calling `addWidget`, the widget goes to the currently active page (the one last added or set by `switchPage`). Serialisation exports and imports the entire page list.

---

## Other Features

### Detached Mirrors

Pop any widget out as a standalone live mirror window:

```matlab
d.detachWidget(widget);
```

The mirror window updates on every live tick and closes when the original dashboard is closed.

### Image Export

Save the dashboard figure as a PNG or JPEG:

```matlab
d.exportImage('output.png');
% or via toolbar Image button
```

### ASCII Preview

Print a text‑based approximation of the dashboard layout to the console:

```matlab
d.preview();
d.preview('Width', 120);
```

### Config Dialog

Open a property editor for all DashboardEngine public properties (name, theme, live interval, progress mode, etc.) via the toolbar Config button.

### Progress Bar

By default Dashboards show a progress bar in the console during render:

```matlab
d.ProgressMode = 'off';  % suppress
```

### Event Markers Toggle

Hide or show event markers across all widgets globally:

```matlab
d.EventMarkersVisible = false;  % also togglable from toolbar
```

---

## Complete Example

```matlab
install;

rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours

% Machine mode state channel
scMode = StateChannel('machine');
scMode.X = [0, 3600, 7200, 28800, 36000];
scMode.Y = [0, 1,    1,    2,     1    ];

% Temperature sensor
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = 74 + 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
sTemp.addStateChannel(scMode);
sTemp.addThresholdRule(struct('machine', 1), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% Pressure sensor
sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'psi';
sPress.X = t;
sPress.Y = 55 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, 'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 70, 'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

%% Build dashboard
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Header row: text + numbers + status
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 – Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], ...
    'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], ...
    'Sensor', sPress);

% Plot row: sensor‑bound FastSense widgets
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

% Bottom row: gauge + custom plot
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 11 8 6], ...
    'Sensor', sPress, 'Range', [0 100], 'Units', 'psi');
d.addWidget('rawaxes', 'Title', 'Temp Distribution', 'Position', [9 11 8 6], ...
    'PlotFcn', @(ax) histogram(ax, sTemp.Y, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## See Also

- [[API Reference: Dashboard]] -- Full API reference for all dashboard classes  
- [[API Reference: Sensors]] -- Sensor, StateChannel, ThresholdRule  
- [[Live Mode Guide]] -- Live data polling  
- [[Examples]] -- `example_dashboard_engine`, `example_dashboard_all_widgets`
