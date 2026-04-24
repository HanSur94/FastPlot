# Phase 1015: Demo Showcase Workspace — Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 1015-demo-showcase-workspace
**Areas discussed:** Data source story, Domain / sensor taxonomy, Dashboard scope & structure, Widget coverage, Showcase features, Location, Runtime, CI/test

---

## Data source story

| Option | Description | Selected |
|--------|-------------|----------|
| LiveTagPipeline + synthetic .dat files | Background writer appends to .dat files, LiveTagPipeline watches and ingests — exercises the REAL production path end-to-end | ✓ |
| In-memory timer updates | A MATLAB timer directly appends X/Y to SensorTag/MonitorTag.updateData() — simpler, no file I/O | |
| Both (two modes) | Demo script offers a toggle — 'live-file mode' for pipeline showcase, 'fast mode' for in-memory | |

**User's choice:** LiveTagPipeline + synthetic .dat files (Recommended)

---

## Domain / sensor taxonomy

| Option | Description | Selected |
|--------|-------------|----------|
| Industrial plant / process | Classic SCADA vibe — plays naturally to FastSense's sensor-data heritage; easy thresholds/events/composites | ✓ |
| EV battery pack | Modern, lots of per-cell data for heatmap/grid widgets; natural MonitorTag use | |
| Server / datacenter fleet | Developer-relatable; wide variety of signal types; good for status indicators and alerts | |
| Weather station network | Friendly audience; slow-changing signals easy to watch live | |

**User's choice:** Industrial plant / process

---

## Dashboard scope & structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single multi-page dashboard with themed tabs | One DashboardEngine with multiple pages — showcases tabs + groups + navigation in one place | ✓ |
| Multiple small example scripts | Separate files per theme — each focused, loses integrated 'big showcase' feel | |
| Dedicated demo/ workspace directory | New top-level dir with generator + dashboard + fixtures | |

**User's choice:** Single multi-page dashboard with themed tabs (Recommended)
(Note: final location-wise, the demo still lives in a new `demo/industrial_plant/` directory per the Location question below — the "structure" answer refers to dashboard topology, not filesystem.)

---

## Widget coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Breadth — every widget type at least once | Goal is showcase + smoke test, include all widget kinds plus tabs, tooltips, detach | ✓ |
| Curated — focus on live/data-driven widgets with depth | Fewer widgets but each used meaningfully with live data | |
| Breadth + one 'deep dive' page | Most pages cover breadth, one page does a threshold-rich analytical deep-dive | |

**User's choice:** Breadth — every widget type at least once (Recommended)

---

## Showcase features (multi-select)

| Option | Description | Selected |
|--------|-------------|----------|
| Info tooltips on every widget | Each widget has a meaningful InfoText description | ✓ |
| At least one detachable widget demonstrated | Pre-detached on startup or README hint | ✓ |
| CompositeTag system health rollup | Dashboard-level 'Plant Health' via CompositeTag over sub-systems | ✓ |
| Event-driven alerts via MonitorTag + EventStore | MonitorTag rules fire, EventTimelineWidget shows them live, FastSense round-markers overlay | ✓ |

**User's choice:** All four selected

---

## Location & persistence

| Option | Description | Selected |
|--------|-------------|----------|
| New demo/industrial_plant/ top-level dir, resets each run | Self-contained; clean-start behavior; matches request for a 'workspace' | ✓ |
| examples/example_showcase_dashboard.m (single file) | Lives alongside other examples; simpler; limits scope | |
| demo/industrial_plant/ that persists across runs | Accumulates history; more realistic but harder to reason about | |

**User's choice:** New demo/industrial_plant/ top-level dir, resets each run (Recommended)

---

## Runtime / tick rate

| Option | Description | Selected |
|--------|-------------|----------|
| Runs until user closes the figure, ~1 Hz tick | Explore indefinitely; low CPU; readable animations | ✓ |
| Runs for a fixed duration (e.g. 60 seconds) then stops cleanly | Good for CI smoke tests | |
| Runs until closed, faster tick (~10 Hz) | Denser live feel; heavier CPU | |

**User's choice:** Runs until user closes the figure, ~1 Hz tick (Recommended)

---

## CI / test

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — add a headless test that boots, ticks a few times, tears down | Regression guard as codebase evolves | ✓ |
| No — interactive demo only | Simpler; rely on per-widget unit tests | |

**User's choice:** Yes — headless smoke test added

---

## Wrap-up

| Option | Description | Selected |
|--------|-------------|----------|
| Ready — write CONTEXT.md | Lock decisions and hand to planner | ✓ |
| Discuss theming / visual style | Theme preset, colors, density | |
| Discuss page breakdown in more detail | Exact pages, widget-to-page mapping, groups | |

**User's choice:** Ready — write CONTEXT.md

## Claude's Discretion

- Exact page list and widget-to-page mapping
- Sensor naming, units, ranges, noise models
- Exact MonitorTag thresholds and hysteresis values
- Choice of DashboardTheme preset
- Whether to pre-detach a widget on startup vs. rely on README hint
- Data generator noise/trend model (sine+noise, AR, drift, etc.)
- Layout density and column widths

## Deferred Ideas

- Persisting demo data across runs
- Multiple theme variants / live theme switching
- WebBridge browser mirror of the demo
- SQLite `FastSenseDataStore` backing for demo tags
- Recorded playback mode
- Custom branding beyond default theme
