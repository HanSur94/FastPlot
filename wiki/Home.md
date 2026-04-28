<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# FastPlot

Ultra-fast time series plotting for MATLAB and GNU Octave with dynamic downsampling, sensor monitoring, and dashboard layouts.

## Key Metrics

| Metric | Value |
|--------|-------|
| 10M point zoom cycle | 4.7 ms (212 FPS) |
| Point reduction | 99.96% (10M to ~4K displayed) |
| GPU memory (10M pts) | 0.06 MB vs 153 MB for plot() |
| Implementation | Pure MATLAB + optional C MEX (AVX2/NEON SIMD) |

## Library Components

FastPlot consists of five integrated libraries:

| Library | Description |
|---------|-------------|
| **FastSense** | Core plotting engine with dynamic downsampling, tiled (`FastSenseGrid`) and tabbed (`FastSenseDock`) layouts, interactive toolbar, theme‑based styling, disk‑backed storage via `FastSenseDataStore`, and live file‑polling. |
| **Dashboard** | Widget‑based dashboard engine with edit mode, JSON persistence, a 24‑column responsive grid, and 20+ widget types (`FastSenseWidget`, `GaugeWidget`, `StatusWidget`, `NumberWidget`, `SparklineCardWidget`, etc.). |
| **SensorThreshold** | Tag‑based domain model for sensor data (`SensorTag`), discrete states (`StateTag`), derived binary monitors (`MonitorTag`), composite aggregations (`CompositeTag`), and a centralised `TagRegistry` catalogue. |
| **EventDetection** | Event detection from threshold violations, persistent `EventStore`, `EventViewer` with Gantt timeline, incremental streaming via `MonitorTag.appendData`, and live pipeline with notifications. |
| **WebBridge** | TCP server for web‑based data relay using NDJSON protocol, enabling direct MATLAB → external clients communication. |

## Features

- **Smart downsampling** — per‑pixel MinMax and LTTB algorithms, user‑selectable per line
- **Pyramid cache** — multi‑resolution pre‑computation for instant zoom‑out on datasets of 50M+ points  
- **MEX acceleration** — optional C with SIMD (AVX2/NEON), automatic fallback to pure MATLAB
- **Dashboard layouts** — tiled grids (`FastSenseGrid`) and tabbed containers (`FastSenseDock`)
- **Interactive toolbar** — data cursor, crosshair, grid/legend toggle, Y‑autoscale, PNG export, live mode controls
- **2 built‑in themes** — `light` and `dark` with 4 colour palettes (vibrant, muted, colorblind, ocean)  
  Legacy preset names (`default`, `industrial`, `scientific`, `ocean`) are automatically aliased to `light`.
- **Linked axes** — synchronised zoom/pan across subplots via `LinkGroup`
- **Tag‑based threshold monitoring** — `MonitorTag` with hysteresis, debounce (MinDuration), and streaming tail append
- **Event detection** — groups violations into events with statistics, Gantt viewer, click‑to‑detail plot
- **Live mode** — file polling with auto‑refresh (preserve/follow/reset view modes)
- **Disk‑backed storage** — SQLite‑backed chunked `FastSenseDataStore` for 100M+ point datasets

## Quick Start

```matlab
install;

% Basic plot with 10M points
fp = FastSense('Theme', 'dark');
x = linspace(0, 100, 1e7);
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.render();
```

```matlab
% Dashboard with tiled layout
fig = FastSenseGrid(2, 2, 'Theme', 'dark');
fig.setTileSpan(1, [1 2]);

fp1 = fig.tile(1);
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'Alarm');
fig.setTileTitle(1, 'Pressure Monitor');

fp2 = fig.tile(2);
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fig.renderAll();
```

```matlab
% Using the Tag API: create a sensor and render it
st = SensorTag('pressure', ...
               'X', linspace(0, 100, 1e6), ...
               'Y', randn(1, 1e6)*10 + 50, ...
               'Units', 'bar');
TagRegistry.register('pressure', st);

fp = FastSense('Theme', 'dark');
fp.addTag(st);
fp.render();
```

## Requirements

- MATLAB R2020b+ or GNU Octave 7+
- C compiler (optional) for MEX acceleration
- No toolbox dependencies

## Getting Started

Start with the [[Installation]] guide to set up FastPlot and compile MEX acceleration. Then follow the [[Getting Started]] tutorial for step‑by‑step examples covering basic plotting, dashboards, sensors, and live mode.

## API Reference

**Core Classes**
- [[API Reference: FastPlot]] — main plotting engine with dynamic downsampling
- [[API Reference: Dashboard]] — `FastSenseGrid`, `FastSenseDock`, `FastSenseToolbar`, `DashboardEngine` and all widget types
- [[API Reference: Sensors]] — `Tag`, `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`, pipeline pipelines
- [[API Reference: Event Detection]] — `EventDetector`, `EventStore`, `EventViewer`, `LiveEventPipeline`
- [[API Reference: Themes]] — theme presets, customisation, colour palettes
- [[API Reference: Utilities]] — `ConsoleProgressBar`, `FastSenseDefaults`

**Specialized Guides**
- [[Live Mode Guide]] — file polling, view modes, live dashboards
- [[Dashboard Engine Guide]] — widget‑based dashboards with edit mode and persistence
- [[Datetime Guide]] — working with time series data
- [[Examples]] — 40+ categorized runnable examples
