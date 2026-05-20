<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a render-once, re-downsample‑on‑zoom architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight cache and re‑downsamples only the visible range on every interaction. The library is built around a **Tag‑based domain model** (v2.0) for sensor data, thresholds, and derived signals, and a **widget–based dashboard engine** that composes interactive displays from those tags.

## Project Structure

```
FastPlot/
├── install.m                          # Path install + MEX compilation
├── libs/
│   ├── FastSense/                      # Core plotting engine
│   │   ├── FastSense.m                 # Main class
│   │   ├── FastSenseGrid.m             # Dashboard layout
│   │   ├── FastSenseDock.m             # Tabbed container
│   │   ├── FastSenseToolbar.m          # Interactive toolbar
│   │   ├── FastSenseTheme.m            # Theme system
│   │   ├── FastSenseDataStore.m        # SQLite‑backed chunked storage
│   │   ├── FastSenseDefaults.m         # Global default settings
│   │   ├── SensorDetailPlot.m          # Sensor detail view with state bands
│   │   ├── NavigatorOverlay.m          # Minimap zoom navigator
│   │   ├── ConsoleProgressBar.m        # Progress indication
│   │   ├── binary_search.m             # Binary search utility
│   │   ├── build_mex.m                 # MEX compilation script
│   │   ├── mex_stamp.m                 # Deterministic build stamp
│   │   └── private/                    # Internal algorithms + MEX sources
│   ├── SensorThreshold/                # Tag‑based domain model (v2.0)
│   │   ├── Tag.m                       # Abstract base
│   │   ├── SensorTag.m                 # Sensor time‑series data
│   │   ├── StateTag.m                  # Discrete state signals
│   │   ├── MonitorTag.m                # Threshold monitor (0/1 output)
│   │   ├── CompositeTag.m              # Boolean aggregation of monitors
│   │   ├── TagRegistry.m               # Singleton catalog of tags
│   │   ├── BatchTagPipeline.m          # Off‑line raw‑data → per‑tag .mat
│   │   ├── LiveTagPipeline.m           # Timer‑driven raw‑data → .mat
│   │   └── readRawDelimitedForTest_.m  # Test shim for private parser
│   ├── EventDetection/                 # Event detection and viewer
│   │   ├── Event.m                     # Event handle
│   │   ├── EventDetector.m             # Off‑line threshold‑based detector
│   │   ├── EventViewer.m               # Gantt chart + filterable table
│   │   ├── LiveEventPipeline.m         # Streaming event pipeline (MonitorTag)
│   │   ├── NotificationService.m       # Email alerts
│   │   ├── EventStore.m                # Persistence (.mat)
│   │   ├── EventConfig.m               # Legacy configuration (deprecated)
│   │   ├── IncrementalEventDetector.m  # Legacy wrapper (no‑op)
│   │   ├── EventBinding.m              # Many‑to‑many Event ↔ Tag registry
│   │   ├── DataSource.m                # Abstract data source
│   │   ├── DataSourceMap.m             # Key → DataSource map
│   │   ├── MatFileDataSource.m         # .mat‑file data source
│   │   ├── MockDataSource.m            # Test signal generator
│   │   ├── NotificationRule.m          # Per‑sensor/threshold notification rules
│   │   ├── printEventSummary.m         # Console table helper
│   │   ├── eventLogger.m               # Factory for simple event logger
│   │   └── generateEventSnapshot.m     # PNG snapshot generation
│   ├── Dashboard/                      # Dashboard engine (serializable)
│   │   ├── DashboardEngine.m           # Top‑level orchestrator
│   │   ├── DashboardBuilder.m          # Edit mode overlay (drag/resize, palette, properties)
│   │   ├── DashboardLayout.m           # 24‑column grid + scrollable canvas
│   │   ├── DashboardSerializer.m       # JSON load/save + .m script export
│   │   ├── DashboardTheme.m            # FastSenseTheme + dashboard‑specific fields
│   │   ├── DashboardToolbar.m          # Toolbar (live, edit, config, export, info)
│   │   ├── DashboardWidget.m           # Abstract widget base
│   │   ├── DashboardPage.m             # Named page container (multi‑page)
│   │   ├── DashboardConfigDialog.m     # Config editor popup
│   │   ├── DashboardProgress.m         # Render‑progress helper
│   │   ├── TimeRangeSelector.m         # Dual‑slider time‑range control with envelope
│   │   ├── FastSenseWidget.m           # FastSense instance wrapper
│   │   ├── GaugeWidget.m               # Arc/donut/bar/thermometer gauge
│   │   ├── NumberWidget.m              # Big number with trend arrow
│   │   ├── StatusWidget.m              # Colored dot indicator
│   │   ├── TextWidget.m                # Static label or header
│   │   ├── TableWidget.m               # uitable display
│   │   ├── RawAxesWidget.m             # User‑supplied plot function
│   │   ├── EventTimelineWidget.m       # Colored event bars on timeline
│   │   ├── GroupWidget.m               # Collapsible panels, tabbed containers
│   │   ├── MultiStatusWidget.m         # Grid of sensor status dots
│   │   ├── BarChartWidget.m            # Bar chart
│   │   ├── ScatterWidget.m             # Scatter plot
│   │   ├── HeatmapWidget.m             # Heat map
│   │   ├── HistogramWidget.m           # Histogram
│   │   ├── ImageWidget.m               # Image display
│   │   ├── ChipBarWidget.m             # Compact horizontal chip strip
│   │   ├── IconCardWidget.m            # Mushroom‑style card (icon + value)
│   │   ├── SparklineCardWidget.m       # KPI card with sparkline + delta
│   │   ├── DividerWidget.m             # Visual section divider
│   │   └── MarkdownRenderer.m          # Markdown‑to‑HTML for info pages
│   └── WebBridge/                      # TCP server for web visualization
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                           # 40+ runnable examples
└── tests/                              # 30+ test suites
```

## Render Pipeline (FastSense)

1. User calls `render()`
2. Create figure/axes if not parented
3. Validate all data (X monotonic, dimensions match)
4. Switch to disk storage mode if data exceeds `MemoryLimit`
5. Allocate downsampling buffers based on axes pixel width
6. For each line: initial downsample of full range, create graphics object
7. Create threshold, band, shading, marker objects
8. Install XLim PostSet listener for zoom/pan events
9. Set axis limits, disable auto‑limits
10. `drawnow` to display

## Zoom/Pan Callback

When the user zooms or pans:

1. XLim listener fires
2. Compare new XLim to cached value (skip if unchanged)
3. For each line:
   - Binary search visible X range — O(log N)
   - Select pyramid level with sufficient resolution
   - Build pyramid level lazily if needed
   - Downsample visible range to ~4,000 points
   - Update hLine.XData/YData (dot notation for speed)
4. Recompute violation markers (fused SIMD with pixel culling)
5. If LinkGroup active: propagate XLim to linked plots
6. `drawnow limitrate` (caps display at 20 FPS)

## Downsampling Algorithms

### MinMax (default)
For each pixel bucket, keep the minimum and maximum Y values. Preserves signal envelope and extreme values. Fast O(N/bucket) per bucket.

### LTTB (Largest Triangle Three Buckets)
Visually optimal downsampling that preserves signal shape by maximizing triangle area between consecutive buckets. Better visual fidelity but slightly slower.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions independently.

## Lazy Multi‑Resolution Pyramid

Problem: At full zoom‑out with 50M+ points, scanning all data is O(N).

Solution: Pre‑computed MinMax pyramid with configurable reduction factor (default 100× per level):

```
Level 0: Raw data         (50,000,000 points)
Level 1: 100× reduction   (   500,000 points)
Level 2: 100× reduction   (     5,000 points)
```

On zoom, the coarsest level with sufficient resolution is selected. Full zoom‑out reads level 2 (5K points) and downsamples to ~4K in under 1ms.

Levels are built lazily on first access — the first zoom‑out pays a one‑time build cost (~70 ms with MEX), subsequent queries are instant.

## MEX Acceleration

Optional C MEX functions with SIMD intrinsics (AVX2 on x86_64, NEON on arm64). For details, see [[MEX Acceleration]].

| Function | Speedup | Description |
|----------|---------|-------------|
| `binary_search_mex` | 10‑20× | O(log n) visible range lookup |
| `minmax_core_mex` | 3‑10× | Per‑pixel MinMax reduction |
| `lttb_core_mex` | 10‑50× | Triangle area computation |
| `violation_cull_mex` | significant | Fused detection + pixel culling |
| `compute_violations_mex` | significant | Batch violation detection (legacy `resolve`) |
| `resolve_disk_mex` | significant | SQLite disk‑based sensor resolution (legacy) |
| `build_store_mex` | 2‑3× | Bulk SQLite writer for `FastSenseDataStore` init |
| `to_step_function_mex` | significant | SIMD step‑function conversion for thresholds |

All share a common `simd_utils.h` abstraction layer. If MEX is unavailable, pure‑MATLAB implementations are used with identical behavior.

## Data Flow Architecture

### Tag‑Based Data Model (v2.0)

FastPlot v2.0 introduces a unified **Tag** abstraction that replaces the old Sensor/Threshold/StateChannel pipeline. Tags are registered in a global `TagRegistry` and serve as the single source of truth for all time‑series data, states, and derived signals.

- **`SensorTag`** — holds raw X/Y sensor data. Data may reside in memory or be backed by `FastSenseDataStore` (disk).
- **`StateTag`** — models discrete piecewise‑constant states (e.g., machine mode) with zero‑order‑hold lookup.
- **`MonitorTag`** — wraps a parent Tag and a condition function to produce a binary 0/1 signal (alarm/ok) on the parent’s native time grid. Supports hysteresis, minimum duration, and callback‑based event emission (via `EventStore`). Streaming tail extension is done through `appendData()`.
- **`CompositeTag`** — aggregates multiple `MonitorTag` or `CompositeTag` children using boolean logic (AND, OR, WORST, COUNT, MAJORITY, SEVERITY) or a user‑supplied function to produce a combined derived signal.

Tags are lazy‑evaluated — a `SensorTag` provides data by reference, and derived tags (`MonitorTag`, `CompositeTag`) recompute only when invalidated. Invalidation cascades through listener chains, keeping downstream consumers in sync.

### Core Tag Pipeline

```
SensorTag (X, Y)
    ↓
MonitorTag (condition → 0/1)  ←─ hysteresis, MinDuration
    ↓
CompositeTag (AND/OR aggregation of multiple monitors)
    ↓
EventStore ←─ events triggered by MonitorTag/CompositeTag edges
    ↓
Dashboard Widgets (FastSenseWidget, EventTimelineWidget, …)
```

### Data Ingestion

- **`BatchTagPipeline`** — offline bulk processing: enumerates `TagRegistry` for tags with `RawSource` bindings, de‑duplicates file reads, parses raw CSV/TXT files, and writes per‑tag `.mat` files.
- **`LiveTagPipeline`** — timer‑driven analogue of the batch pipeline: polls raw files, detects new rows, and appends to the per‑tag `.mat` in streaming fashion.

### FastSense Data Path

```
Raw Data (X, Y from SensorTag.getXY())
    ↓
FastSenseDataStore (optional, for large datasets)
    ↓
Downsampling Engine (MinMax/LTTB)
    ↓
Pyramid Cache (lazy multi‑resolution)
    ↓
Graphics Objects (line handles)
    ↓
Interactive Display
```

### Storage Modes
- **Memory mode**: X/Y arrays held in MATLAB workspace
- **Disk mode**: Data chunked into SQLite database via `FastSenseDataStore`
- **Auto mode**: Switches to disk when data exceeds `MemoryLimit` (default 500 MB)

## Tag‑Based Threshold Monitoring

`MonitorTag` is the primary mechanism for threshold‑based event detection in the v2.0 model.

1. A `MonitorTag` is created with a **parent Tag** (e.g., a `SensorTag`) and a **condition function** `(x, y) -> logical`.
2. On first `getXY()`, the parent’s full (X, Y) grid is fetched and the condition evaluated, producing a 0/1 vector. The result is cached.
3. The condition can be augmented with an `AlarmOffConditionFn` for hysteresis (e.g., rising edge at 50, falling edge at 48).
4. A minimum duration `MinDuration` (in parent X units) can be specified; runs shorter than this are filtered out.
5. On subsequent `updateData()` calls to the parent, all registered listeners (including the `MonitorTag`) are invalidated. The `MonitorTag` then recomputes lazily on the next `getXY()`.

For **live streaming**, `LiveEventPipeline` periodically fetches new data from a `DataSource`, calls `parent.updateData(newX, newY)` to update the parent’s data **first**, then calls `monitor.appendData(newX, newY)`. The `appendData` method extends the cached binary vector using the condition function only on the new samples, preserving hysteresis state and `MinDuration` bookkeeping across the append boundary. Open events at the tail are carried over; events that complete within the new data fire callbacks and are persisted via `EventStore`.

**`CompositeTag`** extends this to combine multiple monitors with Boolean algebra, enabling complex alarm logic (e.g., “alarm if pump A OR pump B exceeds threshold”).

The legacy `Sensor.resolve()` algorithm (which evaluated threshold rules per state segment) has been removed in Phase 1011. All threshold logic now lives in the Tag layer.

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (~10K‑500K points each, auto‑tuned)
2. Each chunk stored as a pair of typed BLOBs (X and Y) with X‑range metadata
3. On zoom/pan, only chunks overlapping the visible range are loaded
4. Pre‑computed L1 MinMax pyramid for instant zoom‑out

The bulk write path uses `build_store_mex` — a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20K mksqlite round‑trips.

If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

```
Element override  >  Tile theme  >  Figure theme  >  'default' preset
```

Each level fills in only the fields it specifies; unspecified fields cascade from the next level. (See [[API Reference: Themes]]).

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: Simple tiled grid of FastSense instances with synchronized live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, edit mode, multi‑page support, and a time‑range selector.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar        — Top toolbar (Live, Edit, Config, Export, Info)
├── DashboardLayout         — 24‑column responsive grid with scrollable canvas
├── DashboardTheme          — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder        — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer     — JSON save/load and .m script export
├── DashboardProgress       — Console progress bar during batch render
├── DashboardConfigDialog   — Figure‑based config editor
├── TimeRangeSelector       — Dual‑slider time range with aggregate envelope preview
├── DashboardPage           — Named page container (multi‑page mode)
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Tag/DataStore/inline)
    ├── GaugeWidget            — Arc/donut/bar/thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Colored event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── BarChartWidget         — Bar chart
    ├── ScatterWidget          — Scatter plot
    ├── HeatmapWidget          — Heat map
    ├── HistogramWidget        — Histogram
    ├── ImageWidget            — Image display
    ├── ChipBarWidget          — Compact horizontal chip strip (system health)
    ├── IconCardWidget         — Mushroom card (icon + primary value)
    ├── SparklineCardWidget    — KPI card with sparkline + delta
    └── DividerWidget          — Horizontal section divider
```

### Render Flow

1. `DashboardEngine.render()` creates the figure.
2. Theme is resolved via `DashboardTheme(preset)`.
3. `DashboardToolbar` renders the top toolbar.
4. If `ShowTimePanel` is true, the `TimeRangeSelector` panel (dual sliders with envelope preview) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates a viewport/canvas with optional scrollbar, and allocates one `uipanel` per widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans widgets for data bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:
1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called (sensor‑bound widgets re‑read `SensorTag.Y(end)`, monitor‑bound widgets re‑evaluate conditions, etc.).
3. The time‑range selector is updated, and the toolbar timestamp label shows last‑update time.
4. A stale‑data banner warns if any widget’s data did not advance.

### Edit Mode

Clicking “Edit” in the toolbar creates a `DashboardBuilder` instance:
1. A palette sidebar (left) shows widget type buttons.
2. A properties panel (right) shows selected widget settings.
3. Drag/resize overlays are added on top of each widget panel.
4. The content area narrows to accommodate sidebars.
5. Mouse move/up callbacks handle drag and resize interactions.
6. Grid snap rounds positions to the nearest column/row.

### Multi‑Page Dashboards

`DashboardEngine` supports multiple named pages. Each `DashboardPage` holds its own list of widgets. `addPage('name')` creates a new page and makes it active; `switchPage(n)` toggles visibility of competing pages. Page state is fully serializable in JSON.

### Time Range Selector

`TimeRangeSelector` provides a dual‑slider with an aggregate min‑max envelope (downsampled from all `FastSenseWidget`s and event markers) that allows panning and resize of the visible time window. The selector owns its own axes, uses figure‑level mouse callbacks, and is compatible with both MATLAB and Octave.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialization:
- **Save:** each widget’s `toStruct()` produces a plain struct with type, title, position, and source. The struct is encoded to JSON with heterogeneous widget arrays assembled manually (MATLAB’s `jsonencode` cannot handle cell arrays of mixed structs).
- **Load:** JSON is decoded, widgets array is normalized to cell, and `configToWidgets()` dispatches to each widget class’s `fromStruct()` static method. An optional `SensorResolver` function handle re‑binds `SensorTag` objects by key. Multi‑page dashboards are stored in a `pages` array, each page containing its own `widgets`.
- **Export script:** generates a `.m` file with `DashboardEngine` constructor calls and `addWidget` / `addPage` calls for each widget.

## Event Detection Architecture

The event detection system is built on top of the Tag model. The primary live pipeline is `LiveEventPipeline`, which uses `MonitorTag` to detect threshold crossings in streaming data.

### Core Components

```
LiveEventPipeline
├── MonitorTargets           — containers.Map: tag key → MonitorTag
├── DataSourceMap            — maps parent tag keys to DataSource instances
├── EventStore              — thread‑safe .mat file persistence
├── NotificationService     — rule‑based email alerts
└── EventViewer            — interactive Gantt chart + filterable table
```

### Data Sources

- **MatFileDataSource**: Polls .mat files for new data
- **MockDataSource**: Generates realistic test signals with violations
- **Custom sources**: Implement `DataSource.fetchNew()` interface

### Event Detection Flow (Live)

1. `LiveEventPipeline.runCycle()` polls each parent tag’s data source.
2. New data for a parent (e.g., a `SensorTag`) is passed to `parent.updateData(newX, newY)` to update the parent’s grid.
3. The corresponding `MonitorTag`’s `appendData(newX, newY)` is called, which extends the cached binary time series and fires events for closed violation runs.
4. New events are sent to `EventStore.append()`, which persists them atomically.
5. `NotificationService` applies rule‑based email alerts with optional PNG snapshots.
6. Any active `EventViewer` instances auto‑refresh to show new events.

### Off‑line Detection

`EventDetector.detect(tag, threshold)` can be used for one‑shot, full‑history detection on any Tag. It evaluates the tag’s full (X, Y) grid against the threshold rules and returns an array of `Event` objects. This is useful for batch analysis or after loading a new dataset.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:
- A violation starts at “Warning” level
- If “Alarm” threshold is also crossed, the event is escalated to “Alarm”
- The event retains the highest severity level encountered

### Event‑Tag Binding

`EventBinding` provides a many‑to‑many registry that binds `Event.Id` to `Tag.Key`. This enables widgets like `EventTimelineWidget` to filter events by tag and supports the query method `EventStore.getEventsForTag(tagKey)`.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback:
- Single‑line ASCII/Unicode bars with backspace‑based updates
- Indentation support for nested operations (e.g., dock → tabs → tiles)
- Freeze/finish modes for permanent status lines
`DashboardProgress` is a thin wrapper used during dashboard render passes.

## Interactive Features

### Toolbars and Navigation
- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid toggle, autoscale, export, live mode
- **DashboardToolbar**: Live toggle, edit mode, save/export, name editing, config dialog, info button
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`
- **TimeRangeSelector**: Dual‑slider time range with data envelope and event markers on the dashboard

### Link Groups
Multiple FastSense instances can share synchronized zoom/pan via `LinkGroup` strings. When one plot’s XLim changes, all plots in the same group update automatically.

### Loupe
`openLoupe()` creates a standalone magnified copy of any tile, preserving the current zoom and adding its own toolbar.
