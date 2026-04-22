# Phase 1015: Demo Showcase Workspace — Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a **runnable, self-contained demo workspace** that serves as both a showcase and an end-to-end smoke test of the FastSense dashboard system. The demo drives a single multi-page dashboard from live-updating, file-backed data sources simulating an industrial plant, exercising every widget type plus tabs, collapsible groups, info tooltips, detachable widgets, CompositeTag health rollups, and MonitorTag event alerts.

**In scope:**
- A new `demo/industrial_plant/` directory containing: a synthetic data generator, raw `.dat` files, a `TagRegistry` wiring script, and the demo dashboard script.
- A single `DashboardEngine` with multiple themed pages (Overview / Pressures / Temperatures / Events / Diagnostics — final page list is Claude's discretion).
- Coverage of **every** widget type at least once across pages.
- All four showcase features: info tooltips on every widget, at least one detached widget, a CompositeTag plant-health rollup, event-driven alerts via MonitorTag + EventStore + EventTimelineWidget + FastSense overlay markers.
- Live ingestion via `LiveTagPipeline` (shipped in Phase 1012) — the REAL production path.
- A headless CI smoke test that boots the demo, ticks a few times, and tears down cleanly.

**Out of scope (deferred):**
- Persisting demo data across runs (resets each run).
- Multiple themes / branding variants.
- WebBridge browser serving of the demo (pure MATLAB/Octave local figure).

</domain>

<decisions>
## Implementation Decisions

### Data source story
- **D-01:** Simulate live data via **`LiveTagPipeline` reading synthetic `.dat` files**. A background writer (MATLAB timer) appends rows to plain delimited files in `demo/industrial_plant/data/raw/`; `LiveTagPipeline` watches those files and ingests via `TagRegistry` into the tag state.
- **D-02:** Data sources reset on each demo run (clean-start behavior). The demo script wipes/recreates `data/raw/` and `data/tags/` before starting.

### Domain / sensor taxonomy
- **D-03:** Domain is an **industrial process plant** (pressures, flows, temperatures, valve states, pump RPM, tank levels, etc.). Exact sensor list, units, and ranges are Claude's discretion — the planner picks a coherent fictional plant (e.g., 2–3 sub-systems such as Feed Line, Reactor, Cooling Loop).
- **D-04:** Signal mix must include enough variety to exercise every widget type — continuous sensors (SensorTag), discrete states (StateTag), derived alert flags (MonitorTag with debounce/hysteresis), and system rollups (CompositeTag).

### Dashboard scope & structure
- **D-05:** One `DashboardEngine` instance, multi-page layout (tabs). Pages are themed (Overview, per-subsystem, Events, Diagnostics). Exact page count and tab labels are Claude's discretion.
- **D-06:** Each page uses **`GroupWidget`** (collapsible) to organize related widgets — demonstrates Phase 02 collapsible groups.

### Widget coverage
- **D-07:** **Breadth** coverage — every widget type must appear at least once. Required inventory:
  - Core charting: `FastSenseWidget`, `RawAxesWidget`
  - Numeric & status: `NumberWidget`, `StatusWidget`, `GaugeWidget`, `MultiStatusWidget`
  - Data display: `TextWidget`, `TableWidget`
  - Other charts: `BarChartWidget`, `HeatmapWidget`, `HistogramWidget`, `ScatterWidget`
  - Media: `ImageWidget`
  - Events: `EventTimelineWidget`
  - Structural: `GroupWidget`, `DividerWidget`, `CollapsibleWidget`
  - Mushroom cards: `IconCardWidget`, `ChipBarWidget`, `SparklineCardWidget`

### Showcase features
- **D-08:** **Info tooltips on every widget** — each widget constructed with a meaningful `InfoText` (short plain-language description of what it shows and why it matters).
- **D-09:** **At least one detachable widget visibly demonstrated** — a high-value widget (e.g., the main FastSense plot on the Overview page) should either be pre-detached on startup or the demo README explicitly calls out the detach action.
- **D-10:** **CompositeTag plant-health rollup** — a top-level `CompositeTag` aggregates sub-system health (e.g., `Reactor.health AND Cooling.health AND FeedLine.health`). The rollup drives a prominent `StatusWidget` or `IconCardWidget` on the Overview page.
- **D-11:** **Event-driven alerts** — at least two `MonitorTag` rules with debounce/hysteresis fire during the demo run; `EventStore` persists them; `EventTimelineWidget` displays the live stream; `FastSenseWidget` shows round-marker overlays on the underlying signal.

### Runtime behavior
- **D-12:** Dashboard runs **until the user closes the figure**. Tick rate ~**1 Hz** for both the data-writer timer and the dashboard `LiveTimer` (keeps CPU light, animations readable).
- **D-13:** Clean teardown on figure close — stop writer timer, stop `LiveTagPipeline`, stop dashboard `LiveTimer`.

### Location & layout
- **D-14:** New top-level directory `demo/industrial_plant/` containing at minimum:
  - `run_demo.m` — entry-point script (creates data, starts pipeline, renders dashboard, hooks teardown)
  - `private/` or equivalent — helpers: data generator, tag wiring, page builders
  - `data/raw/` — synthetic `.dat` files (gitignored at runtime)
  - `data/tags/` — per-tag `.mat` outputs from `LiveTagPipeline` (gitignored at runtime)
  - `README.md` — how to run, what to click, what to look for (includes detach hint)
- **D-15:** Directory must be added to `install.m` path setup so `run_demo` is callable without manual `addpath`.

### CI / test
- **D-16:** A **headless smoke test** (`tests/test_demo_industrial_plant.m` or similar) that:
  - Boots the demo with figure visibility off (or `'Visible','off'`)
  - Runs the live pipeline for a small number of ticks (e.g., 3–5 seconds simulated)
  - Asserts: all widgets rendered without error, at least one event fired, CompositeTag health resolved, no timer errors
  - Tears down cleanly (no dangling timers)
- **D-17:** Test must pass on MATLAB **and** Octave (platform parity — consistent with project convention).

### Claude's Discretion
- Exact page list and widget-to-page mapping
- Sensor naming, units, ranges, noise models
- Exact MonitorTag thresholds and hysteresis values used for event demos
- Choice of `DashboardTheme` preset
- Whether to pre-detach a widget on startup vs. rely on README hint
- Data generator noise/trend model (sine + noise, AR process, drift, etc.)
- Specific layout density and column widths

### Folded Todos
None.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project context
- `.planning/PROJECT.md` — project vision, constraints, non-negotiables
- `.planning/STATE.md` — recent decisions and accumulated context
- `CLAUDE.md` — project instructions, tech stack, conventions

### Widget catalog & dashboard engine
- `libs/Dashboard/DashboardEngine.m` — orchestrator; page/tab/group/detach wiring
- `libs/Dashboard/DashboardWidget.m` — widget base contract (including `InfoText`)
- `libs/Dashboard/DashboardLayout.m` — 24-column grid layout
- `libs/Dashboard/GroupWidget.m` — collapsible groups (Phase 02)
- `libs/Dashboard/CollapsibleWidget.m` — Phase 08 addition
- `libs/Dashboard/DividerWidget.m` — Phase 08 addition
- `libs/Dashboard/DashboardPage.m` — multi-page navigation (Phase 04)
- `libs/Dashboard/DashboardSerializer.m` — save/load (not required for demo but useful reference)
- `libs/Dashboard/DashboardTheme.m` — theme presets
- `libs/Dashboard/FastSenseWidget.m`, `NumberWidget.m`, `StatusWidget.m`, `GaugeWidget.m`, `TextWidget.m`, `TableWidget.m`, `BarChartWidget.m`, `HeatmapWidget.m`, `HistogramWidget.m`, `ScatterWidget.m`, `ImageWidget.m`, `MultiStatusWidget.m`, `EventTimelineWidget.m`, `RawAxesWidget.m`, `IconCardWidget.m`, `ChipBarWidget.m`, `SparklineCardWidget.m` — individual widget contracts

### Tag system (v2.0 domain model)
- `libs/SensorThreshold/Tag.m` — abstract base
- `libs/SensorThreshold/TagRegistry.m` — singleton registry + `loadFromStructs` two-phase loader
- `libs/SensorThreshold/SensorTag.m` — continuous time series carrier
- `libs/SensorThreshold/StateTag.m` — discrete state carrier (ZOH)
- `libs/SensorThreshold/MonitorTag.m` — derived 0/1 with debounce/hysteresis; `appendData` for streaming
- `libs/SensorThreshold/CompositeTag.m` — AND/OR/MAJORITY aggregation

### Tag pipeline (just shipped in Phase 1012)
- `libs/SensorThreshold/BatchTagPipeline.m` — raw → per-tag `.mat` (batch mode)
- `libs/SensorThreshold/LiveTagPipeline.m` — raw → per-tag `.mat` (live/tick-based)
- `.planning/phases/1012-.../1012-CONTEXT.md` and `1012-RESEARCH.md` — pipeline design notes

### Events
- `libs/EventDetection/EventStore.m` — atomic save; `eventsForTag` query
- `libs/EventDetection/EventConfig.m` — configuration
- `libs/EventDetection/NotificationRule.m`, `NotificationService.m` — optional event side-effects

### Core plotting
- `libs/FastSense/FastSense.m` — `addTag`, `addThreshold`, round-marker overlays
- `libs/FastSense/FastSenseDataStore.m` — SQLite backend (optional for demo)

### Examples to pattern after
- `examples/example_dashboard_advanced.m` — existing showcase of Phase 1-8 features
- `examples/example_mushroom_cards.m` — mushroom widget usage
- `quick/260403-nvv-add-or-edit-example-script-showcasing-al/` — prior showcase quick-task
- `examples/example_live_tag_pipeline*.m` (if any from Phase 1012) — LiveTagPipeline usage

### Install / path setup
- `install.m` — paths added on first run; demo dir must be included here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`LiveTagPipeline`** (Phase 1012) — ready-to-use file-watching ingestion with tick state machine (modTime + lastIndex); avoids re-writing pipeline plumbing.
- **Every widget class** — fully self-contained; plug-and-play via `DashboardEngine.addWidget(...)`.
- **`MonitorTag.appendData`** (Phase 1007) — incremental tail computation for streaming; ideal for this demo's tick loop.
- **`CompositeTag` merge-sort streaming** (Phase 1008) — handles multi-child aggregation at demo scale cheaply.
- **`EventStore` + `EventTimelineWidget.FilterTagKey`** (Phases 1009/1010) — ready-made event surface.
- **Existing example scripts** (`examples/example_dashboard_advanced.m`, `example_mushroom_cards.m`) — templates for builder-style dashboard composition.

### Established Patterns
- Widgets constructed via `d.addWidget(kind, NVPairs...)` on `DashboardEngine`.
- Multi-page pattern: `d.addPage('name')` + `d.switchPage(i)` + `d.addWidget(...)`.
- `GroupWidget` holds children via constructor-style emission (Phase 01 infra hardening).
- `InfoText` is an NV-pair on the widget base class (Phase 03).
- Tags bound to widgets via `Tag` NV-pair (Phase 1009 consumer migration) — legacy `Sensor` NV still supported for backward compat.
- Live timer on `DashboardEngine` drives `refresh()` via `onLiveTick`; errors caught via `onLiveTimerError` (Phase 01).
- Tests live in `tests/` as either `test_*.m` (function-based, Octave-friendly) or `tests/suite/Test*.m` (class-based).

### Integration Points
- `install.m` — add `demo/industrial_plant/` to path.
- `TagRegistry` — demo registers all tags at startup via `TagRegistry.register(key, tag)`.
- `LiveTagPipeline` constructor / start method — wired to the raw-file directory created by the demo generator.
- `DashboardEngine` — receives tags by key via widget `Tag` NV-pairs.
- Dashboard figure `CloseRequestFcn` — teardown hook.
- `tests/run_all_tests.m` — auto-discovers new test file; no wiring needed.

</code_context>

<specifics>
## Specific Ideas

- Industrial-plant vibe (SCADA-style): plays naturally to FastSense's sensor-data heritage.
- Overview page should prominently feature the **CompositeTag plant-health** rollup.
- A **Diagnostics** page is a good home for Heatmap (per-sub-system correlation), Scatter (two-signal relationship), Histogram (signal distribution), Image (plant schematic or fake camera still).
- An **Events** page should host `EventTimelineWidget` + a FastSenseWidget showing the sensor that triggered recent events, with round-marker overlay.
- Mushroom cards (IconCard/ChipBar/Sparkline) belong on the Overview page as at-a-glance summary tiles.
- README should include a short "what to click" section (switch tabs, collapse a group, click the info icon, click the detach button).

</specifics>

<deferred>
## Deferred Ideas

- **Persisting demo data across runs** — rejected in favor of clean-start; revisit if users ask for replay/inspection workflows.
- **Multiple theme variants** (switching between DashboardTheme presets live) — out of scope; one theme chosen by planner.
- **WebBridge browser mirror of the demo** — natural follow-up phase; would demonstrate full stack (MATLAB → Python → browser).
- **Persistent `FastSenseDataStore` SQLite backing** for the demo tags — out of scope; demo runs fully in-memory (plus flat `.dat`/`.mat` files from LiveTagPipeline).
- **Recorded playback mode** (replay a captured run without the live generator) — possible future enhancement.
- **Theming / branding beyond default DashboardTheme** — not discussed.
- **Exact page breakdown and widget-to-page mapping** — left to planner/executor as Claude's discretion.

### Reviewed Todos (not folded)
None surfaced from cross-reference.

</deferred>

---

*Phase: 1015-demo-showcase-workspace*
*Context gathered: 2026-04-22*
