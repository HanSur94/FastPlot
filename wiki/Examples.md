<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Examples

FastPlot includes 40+ runnable examples in the `examples/` directory. Each demonstrates specific features with realistic data.

## Running Examples

```matlab
setup;
cd examples

example_basic;          % Run a specific example
run_all_examples;       % Run all (non-interactive)
demo_all;               % Interactive demo (keeps all plots open)
```

## Basic Usage

| Example | Points | Description |
|---------|--------|-------------|
| `example_basic` | 10M | Noisy sine wave with upper/lower thresholds and warning levels. Shows basic FastSense workflow: addLine, addThreshold, render. Includes setScale for logarithmic axes and updateData |
| `example_multi` | 5x1M | Five sensor lines with shared thresholds. Demonstrates auto color cycling, multiple lines, and resetColorIndex |
| `example_100M` | 100M | Stress test with 100 million points (~800 MB). Demonstrates DeferDraw, ShowProgress, and ConsoleProgressBar |

## Layouts and Dashboards

| Example | Description |
|---------|-------------|
| `example_dashboard` | 2x2 FastSenseGrid with bands, shading, fills, and markers. Shows setTileSpan, tileTitle, and per-tile theming |
| `example_dashboard_9tile` | 3x3 grid with 9 different signal types (15M+ total). Shows large grid layouts with mixed data sizes |
| `example_dock` | FastSenseDock with 5 tabbed dashboards, datetime axes, metadata. Full dock workflow with undockTab |
| `example_linked` | 3 synchronized subplots using LinkGroup. Zoom one, all follow. Shows setViewMode |
| `example_multi_sensor_linked` | 4-channel dashboard (2M pts) with state-dependent thresholds per channel |
| `example_mixed_tiles` | Mixed FastSense + raw MATLAB axes in one dashboard (bar charts, scatter plots, histograms) |

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
| `example_alarm_bands` | Industrial 4-level HH/H/L/LL alarm zones with colored bands. Shows setViolationsVisible |
| `example_lttb_vs_minmax` | Side-by-side comparison of LTTB and MinMax downsampling on same data |
| `example_themes` | Same data rendered in all 6 theme presets. Shows color palettes, reapplyTheme, and distFig |
| `example_toolbar` | Interactive toolbar with data cursor, crosshair, grid toggle, autoscale, PNG export. Includes metadata examples |
| `example_datetime` | 50M points with datetime X-axis, comparing with and without toolbar |
| `example_visual_features` | 2x2 dashboard showcasing bands, shading, fill, markers |
| `example_navigator_overlay` | Standalone NavigatorOverlay usage for custom overview+detail views |

## Sensors and Thresholds

| Example | Description |
|---------|-------------|
| `example_sensor_static` | Basic Sensor with static upper/lower thresholds. Shows currentStatus and countViolations |
| `example_sensor_threshold` | Dynamic thresholds that change based on machine state (idle/run/evacuated) |
| `example_sensor_multi_state` | Two state channels (machine + zone) with compound conditions. Shows getThresholdsAt |
| `example_sensor_registry` | Using SensorRegistry API: list(), get(), getMultiple(), register(), unregister(), printTable(), viewer() |
| `example_sensor_dashboard` | 2x2 dashboard combining FastSenseGrid with sensors from registry |

## Event Detection

| Example | Description |
|---------|-------------|
| `example_event_detection_live` | Live event detection with 3 industrial sensors (temperature, pressure, vibration). Mock data generation with random violations, EventViewer with Gantt timeline and hover tooltips, click-to-plot drill-down, console logging via eventLogger(), and a live FastSense dashboard with linked axes and startLive file-polling |
| `example_event_viewer_from_file` | Event store demo with 6 sensors. Auto-saves events to .mat file with backups, opens EventViewer from file with manual/auto-refresh controls, simulates background detection process updating the store while the viewer polls it |
| `example_live_pipeline` | Complete live event detection pipeline with MockDataSource, IncrementalEventDetector, severity escalation, EventStore with backups, NotificationService with rule-based matching, and EventViewer |

## Dashboard Engine

| Example | Description |
|---------|-------------|
| `example_dashboard_engine` | DashboardEngine with sensor-bound FastSenseWidgets, dynamic thresholds, JSON save/load |
| `example_dashboard_all_widgets` | Every widget type in a single dashboard: FastSense, Number, Status, Gauge, Table, RawAxes, Timeline, Text |
| `example_dashboard_live` | DashboardEngine in live mode with periodic data updates |

## Data Storage

| Example | Description |
|---------|-------------|
| `example_disk_storage` | FastSenseDataStore with SQLite-backed chunked storage for 100M+ datasets. Shows auto/disk storage modes, custom memory limits, and direct DataStore API |
| `example_dock_disk` | FastSenseDock with disk-backed DataStore across multiple tabs (~100M points) |
| `example_sensor_todisk` | Sensor data written to disk via DataStore for large datasets. Shows toDisk/toMemory workflow |

## Sensor Detail Views

| Example | Description |
|---------|-------------|
| `example_sensor_detail` | SensorDetailPlot with state bands and threshold context. Shows main+navigator panels |
| `example_sensor_detail_basic` | Minimal SensorDetailPlot without events - shows setZoomRange and getZoomRange |
| `example_sensor_detail_dashboard` | Multiple SensorDetailPlots embedded in FastSenseGrid using tilePanel() |
| `example_sensor_detail_datetime` | SensorDetailPlot with datetime X axis |
| `example_sensor_detail_dock` | 4-tab dock with SensorDetailPlots and correlation analysis |

## Stress Tests

| Example | Description |
|---------|-------------|
| `example_stress_test` | 5-tab FastSenseDock with 26 sensors across 86M total points. Tests rendering performance at scale with dynamic thresholds |
| `example_dynamic_thresholds_100M` | 10 sensors × 100M timestamps with state-dependent thresholds. Shows performance of condition-based threshold resolution |

## Other Features

| Example | Description |
|---------|-------------|
| `example_dock_many_tabs` | FastSenseDock with 20 tabs testing scrollable tab bar |

## See Also

- [[Getting Started]] — Step-by-step tutorial
- [[Performance]] — Benchmark results
- [[Live Mode Guide]] — Real-time data streaming
- [[Dashboard Engine Guide]] — Widget-based dashboards
- [[Sensors]] — Dynamic threshold system
