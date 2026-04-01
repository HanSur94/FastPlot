# Architecture Patterns

**Domain:** MATLAB dashboard engine — advanced layout and widget features
**Researched:** 2026-04-01
**Confidence:** HIGH (based on direct codebase inspection)

---

## Existing Architecture Snapshot

The dashboard layer sits atop the core FastSense rendering engine. All widget types inherit from `DashboardWidget` (abstract handle class). `DashboardEngine` owns the widget list, drives the live refresh timer, and delegates layout math to `DashboardLayout`. `DashboardSerializer` handles JSON round-trip.

```
DashboardEngine
  ├── DashboardLayout (24-col grid, canvas+viewport+scrollbar)
  ├── DashboardToolbar (global controls in figure toolbar band)
  ├── Widgets[] (cell array of DashboardWidget subclasses)
  │     ├── FastSenseWidget  (wraps FastSense core renderer)
  │     ├── NumberWidget, GaugeWidget, StatusWidget, ...
  │     └── GroupWidget (panel | collapsible | tabbed modes)
  └── LiveTimer (MATLAB timer → onLiveTick)
```

`DashboardLayout.allocatePanels()` assigns each widget a `uipanel` handle (`hPanel`). `realizeWidget()` then calls `widget.render(hPanel)` lazily (visible-first, batched). The live timer calls `widget.refresh()` each tick on dirty, realized, visible widgets.

---

## Recommended Architecture for New Features

### Overview

All four feature clusters (nested layouts, info tooltips, multi-page, detachable mirrors) follow the same principle: extend existing abstractions without breaking the `DashboardWidget` contract. No new base class is needed.

```
DashboardEngine
  ├── Pages[]   (NEW — cell array of DashboardPage, replaces flat Widgets[])
  │     └── DashboardPage
  │           ├── Widgets[]  (existing widget list, scoped per-page)
  │           └── Label
  ├── ActivePage  (NEW — index into Pages[])
  ├── PageBar     (NEW — uipanel with page-switcher buttons, sibling to Toolbar)
  ├── DashboardLayout  (unchanged)
  ├── DashboardToolbar (unchanged)
  ├── DetachedMirrors[] (NEW — cell array of DetachedMirror handles)
  └── LiveTimer   (extended tick: also refreshes DetachedMirrors[])

GroupWidget (existing, extended)
  ├── Mode: 'panel' | 'collapsible' | 'tabbed'  (unchanged)
  ├── EngineRef   (NEW weak ref to parent DashboardEngine)
  └── collapse()/expand() → calls EngineRef.reflowPage()  (fills existing TODO)

DashboardWidget (base, minimal addition)
  └── Description  (already exists)
  └── render() implementations add info icon when Description non-empty

DetachedMirror (NEW — standalone handle class, NOT a DashboardWidget)
  ├── SourceWidget  (handle to the original DashboardWidget)
  ├── hFigure       (independent MATLAB figure)
  ├── refresh()     (delegates to SourceWidget.refresh() then redraws own axes)
  └── close()       (removes self from engine's DetachedMirrors[])
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `DashboardEngine` | Orchestration, timer, page navigation, detached mirror registry | `DashboardLayout`, `DashboardPage`, `DashboardToolbar`, `PageBar`, `DetachedMirror[]` |
| `DashboardPage` | Scoped widget collection for one page | `DashboardEngine` (owner), `DashboardLayout` (layout ops) |
| `DashboardLayout` | Grid math, canvas/viewport/scrollbar | `DashboardEngine`, `DashboardPage.Widgets` |
| `DashboardToolbar` | Global toolbar UI | `DashboardEngine` (callbacks) |
| `PageBar` | Page-switcher button strip | `DashboardEngine.switchPage()` |
| `DashboardWidget` (base) | Render/refresh/toStruct contract | `DashboardEngine` (caller), `DashboardLayout` (receives `hPanel`) |
| `GroupWidget` | Container with tabs/collapsible/panel modes | `DashboardEngine` (via `EngineRef` for reflow), children `DashboardWidget[]` |
| `DetachedMirror` | Independent figure showing a live copy of one widget | `DashboardEngine` (registered in `DetachedMirrors[]`), `SourceWidget` (data delegation) |
| `DashboardSerializer` | JSON/`.m` round-trip | `DashboardEngine`, `DashboardPage`, `GroupWidget`, all widget `toStruct()`/`fromStruct()` |

**Boundary rule:** `DetachedMirror` is NOT a `DashboardWidget` subclass. It does not participate in the main grid layout. It is a parallel track refreshed by the same timer tick.

**Boundary rule:** `DashboardPage` is a thin container (no UI of its own). It holds a `Widgets{}` cell array and delegates all rendering to the existing `DashboardLayout`. On page switch, the engine calls `DashboardLayout.allocatePanels()` with the new page's widget list.

---

## Data Flow

### Render (one-time)

```
d.render()
  → DashboardEngine creates figure, toolbar, page bar
  → Activates Page[1]
  → DashboardLayout.allocatePanels(Page[1].Widgets) → assigns hPanel per widget
  → DashboardEngine.realizeBatch() → widget.render(hPanel) for visible widgets
  → Each widget.render() draws into its uipanel
      → GroupWidget.render() recursively renders children into sub-panels
      → If widget.Description non-empty, render() adds info icon uicontrol
```

### Live Refresh (recurring)

```
LiveTimer fires → DashboardEngine.onLiveTick()
  → marks sensor-bound widgets dirty
  → for each w in ActivePage.Widgets: if dirty+realized+visible → w.refresh()
  → for each m in DetachedMirrors: m.refresh()
      → m.refresh() calls m.SourceWidget.refresh() (re-runs data read)
      → redraws m.hFigure axes
  → GroupWidget.refresh() propagates to active-tab or all children
```

### Page Switch

```
User clicks PageBar button for page N
  → DashboardEngine.switchPage(N)
  → deletes existing canvas/viewport panels from hFigure
  → DashboardLayout.allocatePanels(Pages[N].Widgets)
  → DashboardEngine.realizeBatch()
  → ActivePage = N
```

### Collapse/Expand (fixing existing TODO)

```
GroupWidget header button click → toggleCollapse()
  → collapse(): Position(4) = 1, Collapsed = true, hide hChildPanel
  → calls EngineRef.reflowPage()
  → DashboardEngine.reflowPage() → DashboardLayout.reflow(hFigure, ActivePage.Widgets, theme)
```

### Detach

```
User clicks detach icon on widget header
  → DashboardWidget subclass calls EngineRef.detachWidget(self)
  → DashboardEngine.detachWidget(w):
      → m = DetachedMirror(w)
      → m.hFigure = figure(...)
      → w.render(m.hFigure panel) — renders a fresh copy
      → DetachedMirrors{end+1} = m
  → Next timer tick calls m.refresh() → keeps mirror live
```

### Serialization

```
DashboardEngine.save(path)
  → DashboardSerializer.widgetsToConfig(Name, Theme, LiveInterval, Pages, InfoFile)
  → Each Page → struct with label + widgets[]
  → Each widget → widget.toStruct()
  → GroupWidget.toStruct() recurses into Children[]/Tabs[]
  → DetachedMirrors are NOT serialized (runtime state only)
```

---

## Patterns to Follow

### Pattern 1: EngineRef for Reflow

GroupWidget needs to trigger layout reflow on collapse/expand. Pass a reference to DashboardEngine at `addWidget()` time:

```matlab
% In DashboardEngine.addWidget():
if isa(w, 'GroupWidget')
    w.EngineRef = obj;
end

% In GroupWidget.collapse():
if ~isempty(obj.EngineRef) && isvalid(obj.EngineRef)
    obj.EngineRef.reflowPage();
end
```

This fills the existing TODO in `GroupWidget.collapse()`/`expand()` without coupling GroupWidget to the full engine interface — only `reflowPage()` is called.

### Pattern 2: Info Icon in Widget Header

The base class `render()` is abstract, so info icon injection must happen either in each subclass or in a shared helper. Recommended: add a protected `renderInfoIcon(parentPanel)` method to `DashboardWidget` that subclasses call at the end of their `render()` implementation. The icon is a small `uicontrol pushbutton` anchored top-right. When Description is empty, the method is a no-op.

```matlab
% In DashboardWidget:
function renderInfoIcon(obj, parentPanel)
    if isempty(obj.Description), return; end
    uicontrol(parentPanel, 'Style', 'pushbutton', ...
        'String', 'i', ...
        'Units', 'normalized', ...
        'Position', [0.93 0.93 0.06 0.06], ...
        'Callback', @(~,~) obj.showDescription());
end

function showDescription(obj)
    msgbox(obj.Description, obj.Title, 'help');
end
```

This requires no change to `DashboardWidget`'s abstract interface; subclasses opt in by calling `renderInfoIcon`.

Alternatively, `DashboardLayout.realizeWidget()` could inject the icon after calling `widget.render()` — this avoids touching all subclasses but requires the Layout to know about Description. The per-subclass `renderInfoIcon` call is preferable for encapsulation.

### Pattern 3: DetachedMirror as Parallel Track

DetachedMirror is a new handle class (`libs/Dashboard/DetachedMirror.m`), not a DashboardWidget subclass. It holds a reference to the source widget and a separate figure. The live timer iterates `DetachedMirrors{}` separately from `Widgets{}`. This ensures:

- Detached mirrors are invisible to `DashboardLayout` (no grid position needed)
- Mirror closure via figure `CloseRequestFcn` removes entry from `DetachedMirrors{}`
- The source widget continues to exist and render normally in the main dashboard

```matlab
classdef DetachedMirror < handle
    properties
        SourceWidget  % handle to original DashboardWidget
        hFigure
        hPanel
    end
    methods
        function obj = DetachedMirror(sourceWidget)
            obj.SourceWidget = sourceWidget;
            obj.hFigure = figure('Name', ['[Detached] ' sourceWidget.Title], ...
                'CloseRequestFcn', @(~,~) obj.onClose());
            obj.hPanel = uipanel(obj.hFigure, 'Units', 'normalized', ...
                'Position', [0 0 1 1], 'BorderType', 'none');
            sourceWidget.render(obj.hPanel);
        end
        function refresh(obj)
            if ~ishandle(obj.hFigure), return; end
            obj.SourceWidget.refresh();
        end
        function onClose(obj)
            % Engine removes this from DetachedMirrors[] via CloseRequestFcn
            delete(obj.hFigure);
        end
    end
end
```

### Pattern 4: DashboardPage as Thin Container

`DashboardPage` wraps a widget list and a label. No rendering logic lives here — that stays in `DashboardEngine` + `DashboardLayout`:

```matlab
classdef DashboardPage < handle
    properties
        Label   = 'Page 1'
        Widgets = {}
    end
end
```

`DashboardEngine` gains a `Pages{}` property (replaces or wraps `Widgets{}`). For backward compatibility, `addWidget()` routes to `ActivePage.Widgets` if pages exist, else to the legacy flat `Widgets{}` list. Single-page dashboards remain unaffected.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Making DetachedMirror a DashboardWidget

**What:** Subclassing DetachedMirror from DashboardWidget so it appears in the Widgets[] list.
**Why bad:** DashboardLayout would assign it a grid position, and realizeWidget() would try to render it into a main-dashboard uipanel, fighting with its independent figure window. The engine's dirty/realized/visible filtering would also suppress refreshes incorrectly.
**Instead:** Maintain a separate `DetachedMirrors{}` cell array in DashboardEngine, iterated independently in `onLiveTick()`.

### Anti-Pattern 2: Deep Cloning the Widget for Detach

**What:** Deep-copy the source widget's data into the detached mirror so it becomes fully independent.
**Why bad:** MATLAB handle classes do not support deep copy natively. A shallow copy shares all data references anyway, and duplicating sensor bindings would double the data pipeline load.
**Instead:** Detached mirror holds a reference to the original widget and calls its `refresh()`. The mirror renders into its own figure panel but reads data from the same source.

### Anti-Pattern 3: Global Widgets[] for Multi-Page

**What:** Keep all pages' widgets in a single flat `Widgets{}` array, using a page tag per widget to filter.
**Why bad:** The timer iterates all widgets each tick even for inactive pages, wasting refresh cycles. `DashboardLayout` would compute positions for all pages simultaneously.
**Instead:** Per-page `Widgets{}` list. Active page's list is passed to DashboardLayout. Inactive pages are not iterated by the timer.

### Anti-Pattern 4: Modal Dialog for Info Tooltips

**What:** Show a blocking `inputdlg` or `questdlg` for widget descriptions.
**Why bad:** Blocks MATLAB execution, preventing live timer ticks and making the dashboard appear hung while the dialog is open.
**Instead:** Non-blocking `msgbox()` or a `uipanel` overlay drawn inside the widget panel with a close button. `msgbox` is non-blocking by default in MATLAB.

---

## Build Order (Dependencies)

Features have these dependencies:

```
A: GroupWidget reflow wiring (EngineRef + reflowPage)
   └── Required by: collapsible expand/collapse visual update
   └── Prerequisite: none (pure wiring of existing code)

B: Info tooltips
   └── Required by: nothing downstream
   └── Prerequisite: none (Description property already exists on DashboardWidget)

C: Multi-page (DashboardPage + PageBar)
   └── Required by: nothing downstream
   └── Prerequisite: none (additive to DashboardEngine)

D: Detachable widgets (DetachedMirror + detach button in header)
   └── Required by: nothing downstream
   └── Prerequisite: none (additive to DashboardEngine timer loop)

E: Serialization for multi-page
   └── Prerequisite: C (need DashboardPage to exist)

F: Serialization for detached state
   └── Verdict: NOT needed — detached mirrors are runtime-only, not persisted
```

**Recommended build order:**

1. **A — Reflow wiring** (small, fixes existing TODO, no new files, immediate unblocking)
2. **B — Info tooltips** (small, self-contained, tests description rendering in widget subclasses)
3. **C — Multi-page** (medium, adds DashboardPage + PageBar, extends DashboardEngine)
4. **E — Serialization for multi-page** (immediately after C, while context is fresh)
5. **D — Detachable live mirrors** (last — most complex, depends on stable refresh loop)

---

## Scalability Considerations

| Concern | At 10 widgets | At 100 widgets | At 500+ widgets |
|---------|---------------|----------------|-----------------|
| Timer tick cost | Negligible | Visible; dirty-flag filtering critical | Must restrict to active page only — page scoping is essential |
| Detached mirrors per tick | Negligible (<5 typical) | Problematic if >20; each calls SourceWidget.refresh() | Hard limit; mirrors should be closed when not needed |
| Collapse/reflow cost | Instant | Acceptable (reflow deletes+recreates all panels) | Consider partial reflow (only affected rows) |
| Serialization size | Small JSON | Large for nested groups | MATLAB `.m` export scales better than JSON for deep nesting |

---

## Sources

- Direct inspection of `libs/Dashboard/DashboardWidget.m` (confirmed Description property exists, toStruct serializes it)
- Direct inspection of `libs/Dashboard/GroupWidget.m` (confirmed collapse/expand TODOs for reflow wiring; tabbed/collapsible modes fully implemented)
- Direct inspection of `libs/Dashboard/DashboardEngine.m` (confirmed onLiveTick iterates Widgets{}, timer mechanics, no page abstraction currently)
- Direct inspection of `libs/Dashboard/DashboardLayout.m` (confirmed reflow() method exists, ready to be called)
- Confidence: HIGH for all claims — derived from current source code, not documentation or training data
