<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Examples

FastPlot includes 40+ runnable examples in the `examples/` directory. Each demonstrates specific features with realistic data.

## Running Examples

```matlab
install;
cd examples

example_basic;          % Run a specific example
run_all_examples;       % Run all (non-interactive)
demo_all;               % Interactive demo (keeps all plots open)
```

## Basic Usage

| Example | Points | Description |
|---------|--------|-------------|
| `example_basic` | 10M | Noisy sine wave with upper/lower thresholds and warning levels. Shows basic FastSense workflow: addLine, addThreshold, render. Also demonstrates setScale for logarithmic axes and updateData for replacing line data |
| `example_multi` | 5x1M | Five sensor lines with shared thresholds. Demonstrates auto color cycling and resetColorIndex for restarting color palettes |
| `example_100M` | 100M | Stress test with 100 million points (~800 MB). Demonstrates DeferDraw, ShowProgress options, and ConsoleProgressBar for batch workflows |

## Layouts and Dashboards

| Example | Description |
|---------|-------------|
| `example_dashboard` | 2x2 FastSenseGrid with bands, shading, fills, and markers. Shows setTileSpan, setTileTitle, and setTileTheme for per-tile customization |
| `example_dashboard_9tile` | 3x3 grid with 9 different signal types (15M+ total). Shows large grid layouts with mixed data sizes and features |
| `example_dock` | FastSenseDock with 5 tabbed dashboards, datetime axes, metadata. Full dock workflow with undockTab functionality |
| `example_linked` | 3 synchronized subplots using LinkGroup. Zoom one, all follow. Also demonstrates setViewMode for live update behavior |
| `example_multi_sensor_linked` | 4-channel dashboard (2M pts) with state-dependent thresholds per channel |

## Data Handling

| Example | Points | Description |
|---------|--------|-------------|
| `example_nan_gaps` | 1M | Data with NaN dropout regions. Shows seamless gap handling |
| `example_uneven_sampling` | 260K | Variable-rate event-driven data (sparse monitoring + dense bursts) |
| `example_vibration` | 20M | Accelerometer data at 50 kHz with bearing fault bursts |
| `example_ecg` | 5M | ECG signal at 1 kHz with QRS complexes, PVCs, and baseline wander |

## Visual Features

| Example | Description |
|---------|-------------|
| `example_alarm_bands` | Industrial 4-level HH/H/L/LL alarm zones with colored bands. Shows setViolationsVisible toggle |
| `example_lttb_vs_minmax` | Side-by-side comparison of LTTB and MinMax downsampling on same data |
| `example_themes` | Same data rendered in all 5 theme presets |
| `example_toolbar` | Interactive toolbar with data cursor, crosshair, grid toggle, autoscale, PNG export |
| `example_datetime` | 50M points with datetime X-axis (579 days at 1-second resolution), comparing with and without toolbar |
| `example_visual_features` | 2x2 dashboard showcasing bands, shading, fill, markers |

## Sensors and Thresholds

| Example | Description |
|---------|-------------|
| `example_sensor_static` | Basic Sensor with static upper/lower thresholds. Shows currentStatus and countViolations |
| `example_sensor_threshold` | Dynamic thresholds that change based on machine state (idle/run/evacuated) |
| `example_sensor_multi_state` | Two state channels (machine + zone) with compound conditions and string-valued states |
| `example_sensor_registry` | Using SensorRegistry API: list(), get(), getMultiple(), register(), unregister(), viewer() |
| `example_sensor_dashboard` | 2x2 dashboard combining FastSenseGrid with sensors from registry |

## Event Detection

| Example | Description |
|---------|-------------|
| `example_event_detection_live` | Live event detection with 3 industrial sensors (temperature, pressure, vibration). Mock data generation with random violations, EventViewer with Gantt timeline and hover tooltips, click-to-plot drill-down, console logging via `eventLogger()`, and a live FastSense dashboard with linked axes and `startLive` file-polling |
| `example_event_viewer_from_file` | Event store demo with 6 sensors. Auto-saves events to `.mat` file with backups, opens EventViewer from file with manual/auto-refresh controls, simulates background detection process updating the store while the viewer polls it |

## Dashboard Engine

| Example | Description |
|---------|-------------|
| `example_dashboard_engine` | DashboardEngine with sensor-bound FastSenseWidgets, dynamic thresholds, JSON save/load, and script export |
| `example_dashboard_all_widgets` | Every widget type in a single dashboard: FastSense, Number, Status, Gauge, Table, RawAxes, Timeline, Text, Heatmap, BarChart, Histogram, Scatter, Image, MultiStatus |
| `example_dashboard_live` | DashboardEngine in live mode with periodic data updates via timer-driven mock sensor data |
| `example_dashboard_groups` | GroupWidget usage with Panel, Collapsible, and Tabbed modes |
| `example_dashboard_info` | Dashboard with InfoFile property linking to rendered Markdown documentation |

## Data Storage

| Example | Description |
|---------|-------------|
| `example_disk_storage` | FastSenseDataStore with SQLite-backed chunked storage for 100M+ datasets. Shows auto/disk modes, custom MemoryLimit, range queries, and addColumn for metadata |
| `example_dock_disk` | FastSenseDock with disk-backed DataStore across 5 tabs, 35 sensors, 103M points total |
| `example_sensor_todisk` | Sensor.toDisk() workflow for moving large sensor data to disk storage, with toMemory round-trip capability |

## Sensor Detail Views

| Example | Description |
|---------|-------------|
| `example_sensor_detail` | SensorDetailPlot with state bands, threshold context, and event markers |
| `example_sensor_detail_basic` | Minimal SensorDetailPlot with defaults, showing programmatic zoom control |
| `example_sensor_detail_dashboard` | Multiple SensorDetailPlots embedded in FastSenseGrid tiles |
| `example_sensor_detail_datetime` | Sensor detail view with datetime X axis and human-readable time labels |
| `example_sensor_detail_dock` | Multi-tab dashboard with SensorDetailPlots, correlation analysis, and event focus views |

## Live Event Pipeline

| Example | Description |
|---------|-------------|
| `example_live_pipeline` | Complete live event detection pipeline with MockDataSource, IncrementalEventDetector, EventStore with backups, NotificationService with priority rules, template filling, snapshot generation, and EventViewer integration |
| `example_dynamic_thresholds_100M` | Dynamic threshold resolution on 10 sensors with 100M points each, demonstrating state-dependent rules and combined conditions |

## Other Features

| Example | Description |
|---------|-------------|
| `example_navigator_overlay` | Standalone NavigatorOverlay usage for custom overview+detail views with draggable zoom control |
| `example_dock_many_tabs` | FastSenseDock with 20 tabs to test scrollable tab bar navigation |
| `example_mixed_tiles` | Dashboard mixing FastSense tiles with raw MATLAB axes for bar charts, scatter plots, and histograms |

## Stress Tests

| Example | Description |
|---------|-------------|
| `example_stress_test` | 5-tab FastSenseDock with 26 sensors across 60M total points. Tests rendering performance at scale |

## Benchmarks

| Example | Description |
|---------|-------------|
| `benchmark` | FastPlot vs plot() across 10K to 100M points. Measures render time, zoom latency, point reduction, GPU memory |
| `benchmark_zoom` | Per-frame zoom latency analysis. Measures actual ms per zoom/pan interaction |
| `benchmark_features` | Overhead of visual features: bands, shading, fill, markers, themes |
| `benchmark_resolve` | Sensor.resolve() performance: naive per-point vs optimized segment-based approach |

## See Also

- [[Getting Started]] — Step-by-step tutorial
- [[Performance]] — Benchmark results
