<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Architecture

## Overview

FastPlot uses a **render-once, re-downsample-on-zoom** architecture. Instead of pushing millions of points to the GPU, it maintains a lightweight in-memory (or disk‑backed) cache and re‑downsamples only the visible range on every pan or zoom interaction. MEX‑accelerated kernels with pure‑MATLAB fallbacks provide consistent behavior across platforms.

## Project Structure

```
FastPlot/
├── install.m                        # Path install + MEX compilation
├── libs/
│   ├── FastSense/                    # Core plotting engine
│   │   ├── FastSense.m               # Main class
│   │   ├── FastSenseGrid.m           # Grid‑based dashboard (tiled FastSense)
│   │   ├── FastSenseDock.m           # Tabbed container for FastSenseGrid
│   │   ├── FastSenseToolbar.m        # Interactive toolbar
│   │   ├── FastSenseTheme.m          # Theme system (light/dark presets)
│   │   ├── FastSenseDataStore.m      # SQLite‑backed chunked storage
│   │   ├── SensorDetailPlot.m        # Sensor detail view with navigator
│   │   ├── NavigatorOverlay.m        # Minimap zoom rectangle
│   │   ├── ConsoleProgressBar.m      # ASCII progress indicator
│   │   ├── binary_search.m           # O(log N) binary search utility
│   │   ├── HoverCrosshair.m          # Hover‑driven vertical crosshair + datatip
│   │   ├── build_mex.m               # MEX compilation script
│   │   ├── mex_stamp.m               # Deterministic fingerprint for MEX sources
│   │   └── private/                  # Internal algorithms + MEX sources
│   ├── SensorThreshold/              # Sensor and tag‑based thresholds
│   │   ├── SensorTag.m               # Tag subclass for raw sensor data
│   │   ├── StateTag.m                # Tag subclass for discrete state signals
│   │   ├── Tag.m                     # Abstract base for unified domain model
│   │   ├── TagRegistry.m             # Singleton catalog of Tag entities
│   │   ├── MonitorTag.m              # Derived 0/1 binary monitor
│   │   ├── CompositeTag.m            # Aggregate N Monitor/Composite children
│   │   ├── DerivedTag.m              # Continuous signal from N parent Tags
│   │   ├── BatchTagPipeline.m        # Raw‑file → per‑tag .mat batch pipeline
│   │   ├── LiveTagPipeline.m        # Timer‑driven live pipeline for raw files
│   │   └── private/                  # Resolution algorithms + MEX copies
│   ├── EventDetection/               # Event detection and viewing
│   │   ├── Event.m                   # Single threshold violation event
│   │   ├── EventStore.m              # Atomic .mat save/load with backups
│   │   ├── EventBinding.m            # Many‑to‑many Event↔Tag binding
│   │   ├── EventViewer.m             # Gantt timeline + filterable table
│   │   ├── LiveEventPipeline.m       # Real‑time event detection orchestrator
│   │   ├── DataSource.m              # Abstract data source interface
│   │   ├── MatFileDataSource.m       # File‑based data source
│   │   ├── MockDataSource.m          # Synthetic test data generator
│   │   ├── NotificationService.m     # Email alerts with snapshot attachments
│   │   ├── NotificationRule.m        # Per‑sensor/threshold notification rules
│   │   └── private/                  # Event grouping algorithms
│   ├── Dashboard/                    # Full widget‑based dashboard engine
│   │   ├── DashboardEngine.m         # Top‑level orchestrator (multi‑page)
│   │   ├── DashboardBuilder.m        # Edit mode with drag/resize and palette
│   │   ├── DashboardLayout.m         # 24‑column responsive grid with scrolling
│   │   ├── DashboardTheme.m          # FastSenseTheme + dashboard‑specific fields
│   │   ├── DashboardToolbar.m        # Global toolbar for live/edit/export
│   │   ├── DashboardWidget.m         # Abstract base for all widgets
│   │   ├── FastSenseWidget.m         # FastSense instance wrapper
│   │   ├── GaugeWidget.m             # Arc, donut, bar, thermometer gauges
│   │   ├── NumberWidget.m            # Big number with trend arrow
│   │   ├── StatusWidget.m            # Colored dot + threshold evaluation
│   │   ├── TextWidget.m              # Static label or section header
│   │   ├── TableWidget.m             # uitable display
│   │   ├── RawAxesWidget.m           # User‑supplied plot function
│   │   ├── EventTimelineWidget.m     # Colored event bars on a timeline
│   │   ├── GroupWidget.m             # Collapsible/tabbed widget groups
│   │   ├── MultiStatusWidget.m       # Grid of sensor status dots
│   │   ├── ChipBarWidget.m           # Horizontal row of status chips
│   │   ├── IconCardWidget.m          # Mushroom‑card style with icon+value
│   │   ├── SparklineCardWidget.m     # KPI card with inline sparkline
│   │   ├── BarChartWidget.m          # Bar chart
│   │   ├── ScatterWidget.m           # Scatter plot (two sensors)
│   │   ├── HeatmapWidget.m           # Heatmap display
│   │   ├── HistogramWidget.m         # Histogram
│   │   ├── ImageWidget.m             # Image display
│   │   ├── DividerWidget.m           # Horizontal separator
│   │   ├── TimeRangeSelector.m       # Global time‑slider with preview
│   │   ├── MarkdownRenderer.m        # Markdown‑to‑HTML for info panels
│   │   ├── DashboardSerializer.m     # JSON save/load and .m script export
│   │   └── DashboardProgress.m       # Progress bar for render passes
│   └── WebBridge/                    # TCP server for web visualisation
│       ├── WebBridge.m
│       └── WebBridgeProtocol.m
├── examples/                         # 40+ runnable examples
└── tests/                            # 30+ test suites
```

## Class Hierarchy

The core drawing surface is `FastSense`. Higher‑level layouts (`FastSenseGrid`, `FastSenseDock`, `DashboardEngine`) compose collections of `FastSense` instances or widget objects.

```
FastSense (direct plotting)
 ├── FastSenseGrid (tiled grid of FastSense instances)
 │    └── FastSenseDock (tabbed container of grids)

DashboardWidget (abstract)
 ├── FastSenseWidget           (wraps a FastSense)
 ├── RawAxesWidget             (plain axes with user function)
 ├── GaugeWidget, NumberWidget, StatusWidget, TextWidget
 ├── EventTimelineWidget, TableWidget, ImageWidget
 ├── GroupWidget               (collapsible / tabbed container of widgets)
 ├── MultiStatusWidget, ChipBarWidget, IconCardWidget, SparklineCardWidget
 └── …                        (others as listed)
```

The event detection pipeline uses `Event`, `EventStore`, and `LiveEventPipeline`. The new **tag‑based domain model** (`SensorTag`, `MonitorTag`, `CompositeTag`, `DerivedTag`) provides a unified interface for data, thresholds, and derived signals.

## Render Pipeline

1. User calls `render()` on a `FastSense` instance.
2. A figure and axes are created (or `ParentAxes` is reused).
3. All data is validated: X must be monotonic, dimensions match.
4. If total data exceeds `MemoryLimit` (500 MB by default), storage automatically switches to SQLite‑backed `FastSenseDataStore` (disk mode).
5. Downsampling buffers are allocated based on the axes pixel width and `DownsampleFactor` (default 2 points per pixel).
6. For each line:
   - The full range is downsampled once to create the initial graphics object.
   - A multi‑resolution pyramid is built lazily (see below).
7. Threshold lines, violation markers, bands, shaded regions, and custom markers are rendered.
8. A listener on the axes `XLim` property is installed to catch zoom/pan events.
9. Axis limits are set (auto‑scale with 5% padding) and auto‑limit mode is disabled.
10. `drawnow` is called to display.

## Zoom/Pan Callback

When the user zooms or pans:

1. The `XLim` listener fires.
2. New XLim is compared to the cached value; if unchanged (e.g., on identical zoom), the callback exits immediately.
3. For each line:
   - A **binary search** (O(log N)) locates the index range visible.
   - The pyramid level that provides sufficient resolution is selected (lazy build if necessary).
   - The visible range is downsampled to approximately 4,000 points.
   - The graphics line’s `XData` and `YData` are updated in place using dot‑notation assignment (fastest way to update existing objects).
4. Violation markers are recomputed with SIMD‑accelerated culling (fused detection and pixel culling).
5. If the `LinkGroup` property is set, the new XLim is propagated to all other `FastSense` instances in the same group.
6. `drawnow limitrate` caps the display update to 20 frames per second.

## Downsampling Algorithms

All downsampling maps a pixel column to a small number of representative Y values.

### MinMax (default)
For each pixel bucket, the minimum and maximum Y are kept. This preserves the signal envelope and extreme values. Complexity O(N / bucket).

### LTTB (Largest Triangle Three Buckets)
Visually optimises shape preservation by maximising triangle area between consecutive buckets. Slightly slower but produces a more accurate visual representation of the waveform.

Both algorithms handle NaN gaps by segmenting contiguous non‑NaN regions before processing.

## Lazy Multi‑Resolution Pyramid

When fully zoomed out, a naive scan of 50M+ points would be O(N). FastPlot avoids this by constructing a **pre‑computed MinMax pyramid** with a configurable reduction factor (default 100× per level):

```
Level 0: Raw data        (50,000,000 pts)
Level 1: 100× reduction  (500,000 pts)
Level 2: 100× reduction  (5,000 pts)
```

On any zoom, the coarsest level that still provides sufficient pixel resolution is selected. Full zoom‑out only touches level 2 (≈5K points), which is then downsampled to the display width in under 1 ms.

Pyramid levels are built **lazily**: the first zoom‑out incurs a one‑time build cost (~70 ms with MEX), but every subsequent query is instant.

## MEX Acceleration

Optional C MEX functions use SIMD intrinsics (AVX2 on x86‑64, NEON on arm64) for critical paths. All functions have pure‑MATLAB fallbacks with identical semantics, checked once per session:

| Function | Speedup | Description |
|----------|---------|-------------|
| [`binary_search_mex`](libs/FastSense/private/mex_src/binary_search_mex.c) | 10–20× | O(log N) visible‑range lookup |
| [`minmax_core_mex`](libs/FastSense/private/mex_src/minmax_core_mex.c) | 3–10× | Per‑pixel MinMax reduction |
| [`lttb_core_mex`](libs/FastSense/private/mex_src/lttb_core_mex.c) | 10–50× | Triangle‑area computation for LTTB |
| [`violation_cull_mex`](libs/FastSense/private/mex_src/violation_cull_mex.c) | significant | Fused detection + pixel culling |
| [`compute_violations_mex`](libs/FastSense/private/mex_src/compute_violations_mex.c) | significant | Batch violation detection (used by `resolve()`) |
| [`resolve_disk_mex`](libs/FastSense/private/mex_src/resolve_disk_mex.c) | significant | SQLite disk‑based sensor resolution |
| [`build_store_mex`](libs/FastSense/private/mex_src/build_store_mex.c) | 2–3× | Bulk SQLite writer for `DataStore` initialisation |
| [`to_step_function_mex`](libs/FastSense/private/mex_src/to_step_function_mex.c) | significant | SIMD step‑function conversion for thresholds |

All sharing a common `simd_utils.h` abstraction. Compilation is managed by `build_mex.m`, which detects the architecture and sets appropriate compiler flags.

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

- **Memory mode**: X/Y arrays are held directly in the MATLAB workspace.
- **Disk mode**: Data is chunked into a temporary SQLite database via `FastSenseDataStore`. Only chunks overlapping the visible range are loaded on demand.
- **Auto mode**: Automatically falls back to disk storage when the total in‑memory data exceeds `MemoryLimit` (default 500 MB).

## Sensor Threshold Resolution

The `Sensor.resolve()` algorithm (used internally by the legacy event detection) is **segment‑based**:

1. Collect all state‑change timestamps from all `StateChannel`s.
2. Divide the time axis into segments, each with a constant system state.
3. For each segment, evaluate which `ThresholdRule`s match the current state.
4. Assign threshold values per segment.
5. Detect violations using SIMD‑accelerated comparison.

Complexity is O(S × R), where S = number of state segments and R = number of rules, instead of the naive O(N × R) per‑point evaluation.

## Disk‑Backed Data Storage

For datasets exceeding available memory (100M+ points), `FastSenseDataStore` provides SQLite‑backed chunked storage:

1. Data is split into chunks (10k–500k points each, auto‑tuned).
2. Each chunk is stored as a pair of typed BLOBs (X and Y) with X‑range metadata.
3. On zoom/pan, only chunks that overlap the visible range are loaded, then trimmed to the exact window.
4. A pre‑computed level‑1 MinMax pyramid enables instant zoom‑out.

The bulk‑write path uses `build_store_mex` – a single C call that writes all chunks with SIMD‑accelerated Y min/max computation, replacing ~20k individual `mksqlite` round trips. If SQLite is unavailable, a binary file fallback is used automatically.

## Theme Inheritance

Themes cascade through four levels, each filling in only the fields it specifies:

```
Element override  >  Tile theme  >  Figure theme  >  'light' / 'dark' preset
```

Unspecified fields inherit from the next broader level.

## Dashboard Architecture

### FastSenseGrid vs DashboardEngine

- **[[Dashboard|FastSenseGrid]]**: Simple tiled grid of `FastSense` instances with optional synchronised live mode.
- **[[Dashboard Engine Guide|DashboardEngine]]**: Full widget‑based dashboard with gauges, numbers, status indicators, tables, timelines, etc., plus an interactive **edit mode** and JSON serialisation.

### DashboardEngine Components

```
DashboardEngine
├── DashboardToolbar      — Top toolbar (Live, Edit, Config, Export, Image, Info)
├── DashboardLayout       — 24‑column responsive grid with scrollable canvas
├── DashboardTheme        — FastSenseTheme + dashboard‑specific fields
├── DashboardBuilder      — Edit mode overlay (drag/resize, palette, properties)
├── DashboardSerializer   — JSON save/load and .m script export
└── Widgets (DashboardWidget subclasses)
    ├── FastSenseWidget         — FastSense instance (Sensor/DataStore/inline data)
    ├── GaugeWidget            — Arc / donut / bar / thermometer gauge
    ├── NumberWidget            — Big number with trend arrow
    ├── StatusWidget           — Colored dot indicator
    ├── TextWidget             — Static label or header
    ├── TableWidget            — uitable display
    ├── RawAxesWidget          — User‑supplied plot function
    ├── EventTimelineWidget    — Colored event bars on timeline
    ├── GroupWidget            — Collapsible panels, tabbed containers
    ├── MultiStatusWidget      — Grid of sensor status dots
    ├── ChipBarWidget          — Horizontal row of mini status chips
    ├── IconCardWidget         — Compact icon + value card
    ├── SparklineCardWidget    — KPI card with inline sparkline
    ├── BarChartWidget, HeatmapWidget, HistogramWidget, ScatterWidget, ImageWidget
    └── DividerWidget          — Horizontal separator
```

### Render Flow (Dashboard)

1. `DashboardEngine.render()` creates the figure.
2. `DashboardTheme(preset)` generates the full theme struct.
3. `DashboardToolbar` creates the top toolbar panel.
4. A `TimeRangeSelector` (dual‑slider time control) is created at the bottom.
5. `DashboardLayout.createPanels()` computes grid positions, creates a scrollable viewport/canvas, and allocates a `uipanel` per widget.
6. Each widget’s `render(parentPanel)` is called to populate its panel.
7. `updateGlobalTimeRange()` scans all widgets for data time bounds and configures the time sliders.

### Live Mode

When `startLive()` is called, a timer fires at `LiveInterval` seconds:

1. `updateLiveTimeRange()` expands time bounds from new data.
2. Each widget’s `refresh()` is called (e.g., FastSenseWidget re‑fetches data).
3. The toolbar timestamp label is updated.
4. Current slider positions are re‑applied to the updated time range.

### Edit Mode

Clicking **Edit** in the toolbar creates a `DashboardBuilder` instance:

1. A palette sidebar (left) shows widget type buttons.
2. A properties panel (right) shows selected widget settings.
3. Drag/resize overlays are added on top of each widget panel.
4. The content area narrows to accommodate sidebars.
5. Mouse callbacks handle drag and resize interactions.
6. Grid snap rounds positions to the nearest column/row.

### JSON Persistence

`DashboardSerializer` handles round‑trip serialisation:

- **Save** – each widget’s `toStruct()` produces a plain struct with `type`, `title`, `position`, and source‑specific fields. The struct is encoded to JSON with heterogeneous widget arrays assembled manually (MATLAB’s `jsonencode` cannot handle cell arrays of mixed structs).
- **Load** – JSON is decoded, widgets array normalised to a cell, and `configToWidgets()` dispatches to each widget class’s `fromStruct()` static method. An optional `SensorResolver` function handle re‑binds Sensor objects by name.
- **Export script** – generates a `.m` file that reconstructs the dashboard programmatically.

## Event Detection Architecture

### Core Components

```
LiveEventPipeline
├── MonitorTargets        — containers.Map of key -> MonitorTag
├── DataSourceMap         — Maps sensor keys to DataSource instances
├── IncrementalEventDetector — Tracks per‑sensor state and open events
├── EventStore            — Thread‑safe .mat file persistence
├── NotificationService   — Rule‑based email alerts with PNG snapshots
└── EventViewer           — Interactive Gantt chart + filterable table
```

### Data Sources

- **[[API Reference: Event Detection|MatFileDataSource]]**: Polls `.mat` files for new data.
- **[[API Reference: Event Detection|MockDataSource]]**: Generates realistic test signals with configurable violations.
- Custom sources implement the `DataSource.fetchNew()` interface.

### Event Detection Flow

1. `LiveEventPipeline.runCycle()` polls all data sources.
2. New data is passed to `IncrementalEventDetector.process()`.
3. Sensor state is evaluated via `Sensor.resolve()`.
4. Violations are grouped into events with debouncing (`MinDuration`).
5. Events are stored via `EventStore.append()` (atomic `.mat` writes).
6. `NotificationService` sends rule‑based email alerts with optional plot snapshots.
7. Active `EventViewer` instances auto‑refresh on new events.

### Escalation Logic

When `EscalateSeverity` is enabled, events are promoted to the highest violated threshold:

- A violation starts at “Warning”.
- If an “Alarm” threshold is also crossed, the event is escalated to “Alarm” and retains the highest severity.

## Progress Indication

`ConsoleProgressBar` provides hierarchical progress feedback during multi‑tile rendering:

- Single‑line ASCII/Unicode bars with backspace‑based updates.
- Indentation support for nested operations (e.g., dock → tabs → tiles).
- `freeze()` makes the current state permanent; `finish()` fills to 100% and freezes.

## Interactive Features

### Toolbars and Navigation

- **[[API Reference: FastPlot|FastSenseToolbar]]**: Data cursor, crosshair, grid toggle, autoscale, export PNG, live mode, violation‑marker toggle.
- **[[Dashboard Engine Guide|DashboardToolbar]]**: Live toggle, events toggle, edit mode, config dialog, image/export, info.
- **NavigatorOverlay**: Minimap with draggable zoom rectangle for `SensorDetailPlot`.

### Hover Crosshair

`HoverCrosshair` attaches a vertical line that tracks the mouse and displays a multi‑line datatip with the interpolated Y values of all visible lines. It chains with any pre‑existing `WindowButtonMotionFcn`, co‑existing with the toolbar crosshair.

### Link Groups

Multiple `FastSense` instances can share synchronised zoom/pan via the `LinkGroup` string. When one plot’s `XLim` changes, all plots in the same group update automatically.
