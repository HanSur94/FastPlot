<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render‑once, re‑downsample‑on‑zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight multi‑resolution cache and re‑downsamples only the visible range on every interaction. Data is fed through a composable pipeline that supports in‑memory, file‑backed, and disk‑backed stores, all while offering MEX‑accelerated algorithms with pure‑MATLAB fallbacks.

A v2.0 tag‑based domain model unifies sensors, states, monitors, composites, and derived signals, enabling rich threshold logic and event detection without tying data to rendering.

---

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Dashboard layout
│   │   ├── FastSenseDock.m           # Tabbed container
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system
│   │   ├── FastSenseDataStore.m      # SQLite-backed chunked storage
│   │   ├── SensorDetailPlot.m        # Sensor detail view with state bands
│   │   ├── NavigatorOverlay.m        # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m      # Progress indication
│   │   ├── binary_search.m           # Binary search utility
│   │   ├── build_mex.m               # MEX compilation script
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Tag‑based domain model & threshold logic
│   │   ├── Tag.m                     # Abstract Tag base
│   │   ├── SensorTag.m              # Sensor data tag
│   │   ├── StateTag.m               # Discrete state tag
│   │   ├── MonitorTag.m             # Binary monitor derived from a parent
│   │   ├── CompositeTag.m           # Aggregator over multiple Monitors
│   │   ├── DerivedTag.m             # Continuous derived signal
│   │   ├── TagRegistry.m            # Singleton catalog of Tags
│   │   ├── EventBinding.m           # Many‑to‑many Event↔Tag binding
│   │   ├── BatchTagPipeline.m       # Offline batch ingestor
│   │   ├── LiveTagPipeline.m        # Live file‑watching ingestor
│   │   └── private/                  # Resolution algorithms, parser helpers
│   ├── EventDetection/               # Event detection and viewer
│   │   ├── Event.m
│   │   ├── EventStore.m
│   │   ├── LiveEventPipeline.m       # Live pipeline driven by MonitorTags
│   │   ├── NotificationService.m
│   │   ├── NotificationRule.m
│   │   ├── DataSourceMap.m
│   │   ├── MatFileDataSource.m
│   │   ├── MockDataSource.m
│   │   └── private/
│   ├── Dashboard/                    # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m
│   │   ├── DashboardBuilder.m
│   │   ├── DashboardLayout.m
│   │   ├── DashboardSerializer.m
│   │   ├── DashboardTheme.m
│   │   ├── DashboardToolbar.m
│   │   ├── DashboardWidget.m         # Abstract widget base
│   │   ├── FastSenseWidget.m         # FastSense instance wrapper
│   │   ├── GaugeWidget.m
│   │   ├── NumberWidget.m
│   │   ├── StatusWidget.m
│   │   ├── TextWidget.m
│   │   ├── TableWidget.m
│   │   ├── RawAxesWidget.m
│   │   ├── EventTimelineWidget.m
│   │   ├── GroupWidget.m             # Collapsible/ tabbed widget groups
│   │   ├── MultiStatusWidget.m
│   │   ├── BarChartWidget.m
│   │   ├── ScatterWidget.m
│   │   ├── HeatmapWidget.m
│   │   ├── HistogramWidget.m
│   │   ├── ImageWidget.m
│   │   ├── ChipBarWidget.m           # Compact status chips
│   │   ├── IconCardWidget.m          # Mushroom‑style KPI card
│   │   ├── SparklineCardWidget.m     # Big number + sparkline
│   │   ├── DividerWidget.m           # Horizontal divider
│   │   ├── TimeRangeSelector.m       # Dual‑slider time range selector
│   │   └── MarkdownRenderer.m        # HTML conversion for info panels
│   └── WebBridge/                    # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

---

## Render Pipeline

1.  User calls `render()`.
2.  Create figure and axes if no `ParentAxes` is supplied.
3.  Validate all data (monotonic X, matching dimensions).
4.  Switch to disk‑storage mode if total data exceeds `MemoryLimit` (default 500 MB).
5.  Allocate downsampling buffers based on the pixel width of the axes.
6.  For each line: initial downsample of the full X‑range, then create the graphics object.
7.  Create threshold lines, violation markers, bands, shading, and custom markers.
8.  Install a `PostSet` listener on `XLim` to handle zoom/pan.
9.  Set axis limits, disable auto‑limits, and apply all theme settings.
10. `drawnow` to render.

---

## Zoom / Pan Callback

When the user zooms or pans:

1.  The `XLim` listener fires.
2.  The new `XLim` is compared to a cached value (skip if unchanged).
3.  For each line:  
    - binary‑search the visible X‑range – O(log N)  
    - select the coarsest pyramid level that provides sufficient resolution  
    - build that level lazily if it does not yet exist  
    - downsample the visible portion to ~4 000 points  
    - update `hLine.XData` and `hLine.YData` using dot‑notation (fast)
4.  Recompute violation markers (fused SIMD kernel with pixel culling).
5.  If a `LinkGroup` is active, propagate the new `XLim` to all linked plots.
6.  `drawnow limitrate` caps the display update to 20 FPS.

---

## Downsampling Algorithms

### MinMax *(default)*
For each pixel bucket, the minimum and maximum Y values are kept. This preserves the signal envelope and guarantees that extreme values are never lost. Complexity is O(N / bucket) per bucket.

### LTTB (Largest‑Triangle‑Three‑Buckets)
Visually optimal downsampling that preserves the shape of the signal by maximising the triangle area between consecutive buckets. Slightly slower than MinMax but gives better visual fidelity for low‑point‑count lines.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions and downsampling each segment independently.

---

## Lazy Multi‑Resolution Pyramid

**Problem:** Scanning 50 M+ points at full zoom‑out is O(N).

**Solution:** A pre‑computed MinMax pyramid with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data          (50 000 000 points)
Level 1: 100× reduction    (    500 000 points)
Level 2: 100× reduction    (      5 000 points)
```

On zoom, the coarsest level that gives at least one sample per pixel is selected. Full zoom‑out reads level 2 (5 K points) and downsamples to ~4 K in under 1 ms. Levels are built **lazily** on first access – the initial build cost (~70 ms with MEX) is paid once; subsequent queries are instant.

---

## MEX Acceleration

Optional C MEX functions using SIMD intrinsics (AVX2 on x86‑64, NEON on arm64). If the MEX binaries are not available, pure‑MATLAB implementations are used with identical behaviour.

| MEX function              | Speedup   | Description |
|---------------------------|-----------|-------------|
| `binary_search_mex`       | 10–20×    | O(log N) visible‑range lookup |
| `minmax_core_mex`         | 3–10×     | Per‑pixel MinMax reduction |
| `lttb_core_mex`           | 10–50×    | Triangle area computation for LTTB |
| `violation_cull_mex`      | significant | Fused violation detection + pixel culling |
| `compute_violations_mex`  | significant | Batch violation detection for `resolve()` |
| `resolve_disk_mex`        | significant | SQLite‑backed sensor resolution |
| `build_store_mex`         | 2–3×      | Bulk SQLite writer for DataStore initialisation |
| `to_step_function_mex`    | significant | SIMD step‑function conversion for thresholds |

All MEX files share a common `simd_utils.h` abstraction layer. The compilation script `build_mex()` detects the platform and SIMD capabilities at build time; if AVX2 fails, it falls back to SSE2 automatically.

---

## Data Flow Architecture

### Core Data Path

```
Raw Data (X, Y arrays)
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax / LTTB)
    ↓
Pyramid Cache (lazy multi‑resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes

- **Memory mode:** X and Y are held directly in MATLAB arrays.  
- **Disk mode:** Data is chunked into a SQLite database via `FastSenseDataStore`.  
- **Auto mode:** Switches to disk automatically when total data exceeds `MemoryLimit`.

---

## Disk‑Backed Data Storage

For datasets exceeding available memory (100 M+ points), `FastSenseDataStore` provides chunked SQLite storage:

1. Data is split into chunks (≈10 K – 500 K points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y), indexed by the chunk’s X range.
3. On zoom/pan, only the chunks overlapping the visible range are loaded and trimmed.
4. A pre‑computed L1 MinMax pyramid is stored alongside the chunks so that full zoom‑out remains instant.

`build_store_mex` is used for the bulk write path – a single C call with SIMD‑accelerated Y min/max computation, replacing tens of thousands of individual SQLite round trips. If SQLite is unavailable, a binary‑file fallback is used transparently.

---

## Sensor Threshold Resolution

**(Legacy Sensor class – still supported for backwards compatibility.)**  
The `Sensor.resolve()` algorithm is segment‑based:

1. Collect all state‑change timestamps from all StateChannels.
2. For each segment between state changes:  
   - evaluate which ThresholdRules match the current state  
   - group rules with identical conditions
3. Assign threshold values per segment.
4. Detect violations using SIMD‑accelerated comparison.

Complexity: O(S × R) where S = number of state segments and R = number of rules, instead of the per‑point O(N × R) evaluation.

---

## Tag‑Based Domain Model (v2.0)

FastPlot introduces a unified, composable Tag hierarchy that decouples data modelling from rendering and threshold logic.

### Core Hierarchy

```
Tag (abstract base)
├── SensorTag     – raw sensor time series (X, Y)
├── StateTag      – piecewise‑constant state (numeric or cellstr Y)
├── MonitorTag    – binary 0/1 derived from a single parent
├── CompositeTag  – logical/severity aggregation of N children
└── DerivedTag    – continuous derived series via a compute function
```

Each Tag exposes `getXY()`, `valueAt(t)`, `getTimeRange()`, `getKind()`, `toStruct()` / `fromStruct()`, and supports two‑phase deserialisation via `resolveRefs()`.

### Key Classes

| Class | Purpose |
|-------|---------|
| **`SensorTag`** | Holds X/Y data; supports disk‑backed storage and raw‑file sources for batch/live pipelines. |
| **`StateTag`** | Staircase signal; `valueAt(t)` uses zero‑order hold. |
| **`MonitorTag`** | Evaluates a `ConditionFn` on a parent Tag’s grid to produce a 0/1 alarm signal. Supports hysteresis (`AlarmOffConditionFn`), debouncing (`MinDuration`), and persistence (`Persist` + `DataStore`). |
| **`CompositeTag`** | Aggregates multiple MonitorTag children using AND, OR, MAJORITY, COUNT, WORST, SEVERITY, or a user‑defined function. |
| **`DerivedTag`** | Lazy‑evaluated continuous output from N parents via a `ComputeFn` (function handle or object). |
| **`TagRegistry`** | Singleton providing `register`, `get`, `findByKind`, `findByLabel`, and two‑phase `loadFromStructs`. |
| **`EventBinding`** | Singleton many‑to‑many registry linking events to tags by ID, enabling `getEventsForTag()`. |

### Data Ingestion Pipelines

- **`BatchTagPipeline`**: Enumerates Tags with a `RawSource`, parses each raw file once, and writes per‑tag `.mat` files.
- **`LiveTagPipeline`**: Timer‑driven, watches raw files for changes and appends new rows to per‑tag `.mat` files.

Both pipelines share a common parse‑and‑write core, avoid duplicate file reads per tick, and isolate failures per tag.

---

## Theme Inheritance

```
Element override  →  Tile theme  →  Figure theme  →  'light' or 'dark' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level.

---

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **`FastSenseGrid`** – A simple tiled grid of FastSense instances with synchronous live mode.  
- **`DashboardEngine`** – A full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, and an interactive edit mode.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      ― Top toolbar (Live, Edit, Save, Export, Sync, Info)
├── DashboardLayout       ― 24‑column responsive grid with scrollable canvas
├── DashboardTheme        ― FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      ― Edit‑mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   ― JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         ― FastSense instance (Tag / DataStore / inline / file)
    ├── GaugeWidget            ― Arc, donut, bar, thermometer
    ├── NumberWidget            ― Big number with trend arrow
    ├── StatusWidget           ― Coloured dot indicator
    ├── TextWidget             ― Static label or header
    ├── TableWidget            ― uitable display
    ├── RawAxesWidget          ― User‑supplied plot function
    ├── EventTimelineWidget    ― Coloured event bars on a timeline
    ├── GroupWidget            ― Collapsible panels, tabbed containers
    ├── MultiStatusWidget      ― Grid of sensor status dots
    ├── ChipBarWidget          ― Compact row of status chips
    ├── IconCardWidget         ― Mushroom‑card‑style KPI with icon
    ├── SparklineCardWidget   ― Big number plus mini sparkline
    ├── DividerWidget          ― Horizontal divider line
    └── … (BarChart, Scatter, Heatmap, Histogram, Image)
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` builds the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. Time‑control panel (dual sliders + time labels) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates a scrollable canvas, and allocates a `uipanel` for each widget.
6. Each widget’s `render(parentPanel)` populates its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called.
3. The toolbar timestamp label is updated.
4. Current slider positions are re‑applied to the updated time range.

### Edit Mode

Clicking **Edit** in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar (left) shows widget type buttons.
2. A properties panel (right) shows the selected widget’s settings.
3. Drag/resize overlays are added on top of each widget panel.
4. Grid snap rounds positions to the nearest column/row.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation:
- **Save:** each widget’s `toStruct()` produces a plain struct; the JSON array is assembled manually to support heterogeneous widget types.
- **Load:** JSON is decoded, and each widget’s `fromStruct()` is called. An optional `SensorResolver` function re‑binds Sensor/Tag objects by name.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` calls for every widget.

---

## Event Detection Architecture

The event detection system is built on the **MonitorTag** model: each monitor evaluates a condition on its parent Tag and emits events when a binary alarm begins or ends.

### Core Components

```
LiveEventPipeline
├── MonitorTargets          ― containers.Map of key → MonitorTag
├── DataSourceMap           ― Maps sensor keys to DataSource instances
├── EventStore             ― Thread‑safe .mat file persistence
├── NotificationService    ― Rule‑based email alerts
└── EventViewer            ― Interactive Gantt chart + filterable table
```

### Data Sources

- **`MatFileDataSource`** – Polls `.mat` files for new data.
- **`MockDataSource`** – Generates realistic test signals with violations.
- **Custom sources** – Implement the `DataSource.fetchNew()` interface.

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is fed to the **parent Tag** via `parent.updateData()`.
3. The pipeline then calls `MonitorTag.appendData(newX, newY)`, which:  
   - evaluates the condition function on the new data,  
   - applies hysteresis and debouncing,  
   - generates `Event` objects for opened/closed alarm runs.
4. Events are handed to `EventStore.append()` and `EventBinding.attach()`.
5. `NotificationService` processes matching `NotificationRule`s and sends email alerts (optionally with PNG snapshots).
6. Active `EventViewer` instances auto‑refresh to show new events.

### Escalation Logic

When `EscalateSeverity` is enabled, an event is promoted to the highest severity threshold it crosses. For example, a violation crossing both a “Warning” and an “Alarm” threshold will be saved as “Alarm”. The `Severity` field is set accordingly and used for display colouring.

---

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` and `finish()` modes for permanent status lines.

---

## Interactive Features

### Toolbars and Navigation
- **`FastSenseToolbar`**: Data cursor, crosshair, grid/legend toggle, Y‑autoscale, PNG/CSV export, live mode, metadata toggle.
- **`DashboardToolbar`**: Live toggle, edit mode, save/export, name editing, config, info panel.
- **`NavigatorOverlay`**: Minimap with a draggable zoom rectangle for `SensorDetailPlot`.

### Link Groups
Multiple FastSense instances can share synchronised zoom/pan by assigning the same `LinkGroup` string. When one plot’s `XLim` changes, the listener propagates the new limits to all plots in the group.

### Hover Crosshair
`HoverCrosshair` adds a vertical tracking line and a multi‑line datatip that shows interpolated values for every visible line, enabled by default (`HoverCrosshair = true`).

---

*For more details on the MEX acceleration internals, see [[MEX Acceleration]]. Performance tuning guidance is available in [[Performance]]. The full public API is documented in [[API Reference: FastPlot]] and [[Dashboard]].*
