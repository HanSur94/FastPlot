# Feature Landscape

**Domain:** Advanced dashboard layout, widget documentation, detachable views (MATLAB sensor data tool)
**Researched:** 2026-04-01
**Confidence note:** Tool comparisons (Grafana, Plotly Dash, Streamlit, MATLAB App Designer, LabVIEW) based on training knowledge (HIGH confidence for established features, MEDIUM for nuanced details). Codebase analysis is HIGH confidence (read directly from source).

---

## Existing Baseline (Already Implemented)

The following are confirmed present in the codebase and are NOT part of this milestone's feature work. Listed here to prevent re-implementing or blocking on them.

| Feature | Implementation Location | Notes |
|---------|------------------------|-------|
| GroupWidget with tabbed mode | `GroupWidget.m` — `Mode = 'tabbed'` | Tab switching, per-tab widget arrays, active tab tracking, theme-aware tab buttons |
| GroupWidget with collapsible mode | `GroupWidget.m` — `Mode = 'collapsible'` | collapse/expand methods exist; reflow TODO noted in code |
| GroupWidget nesting (depth 2) | `GroupWidget.m` — `ancestorDepth()` | Max depth 2 enforced with error |
| `Description` field on every widget | `DashboardWidget.m` line 17 | Base class field; serialized in `toStruct()` |
| Dashboard-level `InfoFile` | `DashboardEngine.m` — `showInfo()` | Markdown file → HTML → browser via `web()` |
| DashboardSerializer round-trip | `DashboardSerializer.m` | `.m` function files and legacy `.json`; tabs/collapse serialized in GroupWidget.toStruct |
| Timer-driven live refresh | `DashboardEngine.m` — `startLive()`, `onLiveTick()` | Fixed-rate timer, dirty flag pattern, sensor PostSet listeners |
| Theme propagation to children | `GroupWidget.renderChildren()` | `ParentTheme` set before each child's render |

**Gap between implemented and rendered:** GroupWidget tabs and collapsible are structurally implemented but have a documented TODO: `toggleCollapse` does NOT trigger `DashboardLayout.reflow()`, so the grid does not compact after collapse. This is the primary unfinished piece in the layout features.

---

## Table Stakes

Features that users of any serious dashboard tool expect. Missing these makes the product feel unfinished or hard to use.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Collapse/expand reflow | Grafana rows, Streamlit expanders, MATLAB uitabgroup — all recompute layout when a section collapses. Without it, collapsing creates a blank gap. | Medium | The `collapse()`/`expand()` methods exist; the missing piece is wiring `DashboardLayout.reflow()` and propagating the figure repaint. The TODO comment is already in GroupWidget lines 242 and 258. |
| Active tab persists through save/load | All tabbed UI tools (Grafana, Dash) restore the last-selected tab. The `activeTab` field is already in `toStruct()`/`fromStruct()` but must be verified to round-trip correctly in edge cases. | Low | Structural support exists; needs integration test coverage. |
| Tab keyboard/click switching (visual feedback) | Users expect visual differentiation of active vs inactive tabs — active tab highlighted. | Low | Already implemented in `renderTabbedChildren()` with `TabActiveBg`/`TabInactiveBg` theme fields. Verify contrast is legible in both light/dark themes. |
| Info tooltip on widget (per-widget description) | Grafana panel "description" tooltip is a flagship feature — engineers rely on it to document sensor context, alarm thresholds, expected ranges. | Medium | `Description` field exists on all widgets. Missing: the info icon in the widget header and the tooltip/popup rendering on hover or click. This is the primary work item for widget documentation. |
| Per-widget detach button | Grafana "View" fullscreen, MATLAB "Open in new window" buttons, LabVIEW detachable sub-VIs — power users expect to pop out a single chart for closer inspection. | Medium | Not yet implemented. Needs a button in each widget's header/chrome area. |
| Detached window stays live | If a widget pops out and then goes stale, users interpret it as broken. The expectation from live dashboards (Grafana, Streamlit) is that all views of the same data stay synchronized. | High | Most complex item. Requires hooking a cloned or mirrored widget into the DashboardEngine timer. Must not increase timer callback time proportionally. |
| Multi-page navigation | Grafana dashboards link to other dashboards. LabVIEW SubVIs act as pages. MATLAB App Designer uses `uitabgroup` at the figure level for page-level nav. | Medium | Not mentioned as an explicit requirement in PROJECT.md's Active list. The project calls it "multi-page dashboards." Implementation approach: a top-level `uitabgroup` or a page-registry pattern in DashboardEngine. |

---

## Differentiators

Features that go beyond what MATLAB users expect from a script-driven dashboard library. Competitive advantage vs. custom figure scripts or basic App Designer panels.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Info tooltip with Markdown rendering | Most MATLAB tooling has plain-text descriptions. Rendering Description text as Markdown (using existing `MarkdownRenderer`) in a tooltip or floating panel makes documentation first-class. | Low-Medium | `MarkdownRenderer.render()` already exists. A tooltip panel overlay on widget hover is a small addition. The main decision: hover-triggered vs. click-triggered (click is more reliable in MATLAB uicontrols). |
| Detached widget maintains independent time zoom | A detached window that allows panning/zooming the time axis independently while the main dashboard keeps its global time range is more useful than a simple static copy. `UseGlobalTime = false` already exists on DashboardWidget. | Medium | The detach mechanism should set `UseGlobalTime = false` on the detached copy and let the user interact with the standalone FastSense plot zoom controls. |
| Two-level nesting of groups (tabs inside collapsible sections) | Grafana supports rows containing panels containing sub-panels, but most MATLAB tooling is flat. The depth-2 nesting limit is already enforced, enabling configurations like: collapsible section > tabbed sub-group > widgets. | Low (structural support exists) | The `ancestorDepth()` guard is already in place. Value comes from documenting this capability clearly so users know to use it. |
| Collapsible sections as screen-real-estate management | For dashboards with 30+ widgets, collapsing rarely-used sections is practical. Grafana rows and Plotly Dash `dcc.Collapse` are staple features; in MATLAB this is unusual. | Medium (needs reflow) | Differentiating because MATLAB users typically deal with this via separate figures. The collapsed/expanded state serializes to `.m` files, enabling dashboard scripts that ship with sections pre-collapsed. |
| Page-level navigation without multiple figures | Multi-page in a single figure window (like a MATLAB uitabgroup at figure level) is cleaner than separate `figure()` calls per page — which is what users do today. | Medium | Less cognitive overhead when managing related views (e.g., overview page + detail page + alert log page). |

---

## Anti-Features

Features to deliberately NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Drag-and-drop widget rearrangement | Already out of scope in PROJECT.md. MATLAB uicontrol drag semantics are unreliable. High implementation cost, low value for script-driven workflows where layout is defined once. | Use the 24-column grid position system with `resolveOverlap()`. |
| Cross-filtering / data binding between widgets | Not requested. Would require a new reactive data model (similar to Dash's `@callback`). Pulling this in would be a multi-week effort and would conflict with the sensor-driven data model. | Sensor objects already share data by reference — multiple widgets bound to the same Sensor object automatically see the same data. |
| Interactive controls (sliders, dropdowns) driving widget data | Not requested. MATLAB `uicontrol` widgets for live data manipulation are more suited to App Designer with its MVC pattern. DashboardEngine is a visualization system, not a control panel. | Point users toward App Designer or separate control figures that push data into Sensor objects. |
| Tooltip animations or fancy hover effects | MATLAB uicontrols do not support CSS-style hover animations. Attempting to simulate them via `WindowButtonMotionFcn` is fragile and performance-degrading. | A click-triggered info panel (pushbutton + uipanel overlay) is more reliable and consistent. |
| Deep nesting beyond depth 2 | Depth-3+ nesting causes exponential rendering complexity in normalized-unit coordinate math. GroupWidget already enforces the depth-2 limit. | Use page-level navigation to separate deep hierarchies instead of nesting. |
| Detached widgets that are editable independently | Allowing edits in the detached window to sync back to the main dashboard adds bidirectional state management complexity disproportionate to value. | Detached widgets are read-only live mirrors. |
| Browser/WebBridge updates | Explicitly out of scope in PROJECT.md. WebBridge is a separate rendering path. | Focus changes on native MATLAB figure rendering; WebBridge parity is a future milestone. |
| New widget types | 20+ types exist. Adding types during this milestone would dilute focus and create serialization maintenance overhead. | Satisfy new visualization needs by composing existing widgets inside GroupWidget. |

---

## Feature Dependencies

```
Collapse/expand reflow
  └── requires DashboardLayout.reflow() wiring (does not exist yet)
  └── requires figure-level repaint propagation from GroupWidget up to DashboardEngine

Widget info tooltip (click-triggered)
  └── requires info icon uicontrol in widget header chrome
  └── requires DashboardWidget.render() to add the icon unconditionally when Description is non-empty
  └── optionally: MarkdownRenderer for rich content in the popup

Detachable widget (pop-out button)
  └── requires detach button in widget header chrome
  └── requires widget clone/copy mechanism (struct round-trip via toStruct/fromStruct)
  └── requires standalone figure creation with DashboardEngine subset or direct widget render

Live-mirrored detached widget
  └── requires: Detachable widget (above)
  └── requires: DashboardEngine to maintain a registry of detached figure handles
  └── requires: onLiveTick() to also call refresh() on detached widget mirrors
  └── performance constraint: detached widgets must be marked dirty same as main widgets

Multi-page navigation
  └── independent of tabs/collapsible — operates at DashboardEngine level, not GroupWidget level
  └── requires: page registry in DashboardEngine (cell array of widget sets)
  └── requires: page navigation UI (toolbar buttons or top-level tab strip)
  └── requires: DashboardSerializer to persist page structure

Nested layout serialization (tabs/collapse/pages in .m files)
  └── tabs/collapse: largely done in GroupWidget.toStruct()/fromStruct()
  └── pages: requires new DashboardSerializer support when page feature is added
  └── collapse reflow: serialized Collapsed=true state must survive round-trip (already stored in toStruct)
```

---

## Feature Gaps (What Currently Exists vs. What Must Be Built)

This section maps PROJECT.md Active requirements to the delta between existing code and the target state.

| Requirement (from PROJECT.md) | Existing State | Delta to Build |
|-------------------------------|----------------|----------------|
| Tabbed layout sections | GroupWidget Mode='tabbed' fully implemented including render and serialize | Verify tab count does not overflow header (tabWidth formula already caps at 15% width); add integration tests |
| Collapsible sections | collapse()/expand() methods implemented; Collapsed serializes | Wire DashboardLayout.reflow() call; propagate repaint to parent figure |
| Multi-page dashboards | Not implemented | New feature: page registry in DashboardEngine, page nav UI, serialization |
| Widget info tooltips | Description field exists on all widgets; not rendered in UI | Add info icon to widget header render path; implement click-to-show popup panel |
| Detachable widgets | Not implemented | Detach button in header; clone via toStruct/fromStruct; standalone figure render |
| Live-mirrored detached widgets | DashboardEngine timer exists; no mirror registry | Add mirror registry to DashboardEngine; onLiveTick propagates to mirrors |
| Nested layout serialization | GroupWidget tabs/collapse fully serializes | Multi-page needs new serialization; verify round-trip edge cases for nested tabs |

---

## MVP Recommendation

Given the complexity assessment and dependencies, prioritize in this order:

1. **Collapse/expand reflow** — unblocks the existing collapsible feature from being cosmetic-only. Users will immediately notice sections do not reflow.
2. **Widget info tooltip** — high visibility, low risk, standalone implementation. The Description field is already in place.
3. **Detachable widget (static)** — pop-out to a new figure without live mirroring. Validates the clone mechanism.
4. **Live-mirrored detached widget** — builds on #3. Add mirror registry to DashboardEngine.
5. **Multi-page navigation** — most self-contained new feature (DashboardEngine level, not GroupWidget).
6. **Nested layout serialization** — verification task; most serialization already works, gaps are in multi-page and edge cases.

Defer: Visual polish on tab overflow (more than ~6 tabs in a small group). Acceptable to ship with the existing tabWidth capping; can be improved later.

---

## Sources

| Source | Confidence | Notes |
|--------|------------|-------|
| Codebase reading: `DashboardWidget.m`, `GroupWidget.m`, `DashboardEngine.m`, `DashboardSerializer.m` | HIGH | Read directly from `/Users/hannessuhr/FastPlot/libs/Dashboard/` |
| PROJECT.md requirements | HIGH | Direct requirements document |
| Grafana panel description tooltip, collapsible rows, dashboard linking | HIGH | Established features in Grafana since v6+; training knowledge |
| Plotly Dash `dcc.Tabs`, `dcc.Collapse` patterns | HIGH | Core Dash components; stable since Dash 1.x |
| Streamlit `st.expander`, `st.tabs` patterns | HIGH | Introduced in Streamlit 1.4 (expander earlier); well-established |
| MATLAB App Designer uitabgroup, uitab | HIGH | Native MATLAB UI since R2016a; standard approach for tabbed MATLAB GUIs |
| LabVIEW detachable sub-VIs, front panel patterns | MEDIUM | Training knowledge; LabVIEW specifics may have evolved |
