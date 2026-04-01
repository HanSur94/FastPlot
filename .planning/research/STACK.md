# Technology Stack

**Project:** FastSense Advanced Dashboard (nested layouts, tooltips, detachable widgets)
**Researched:** 2026-04-01
**Scope:** Subsequent milestone — adding advanced UI patterns to existing dashboard engine

---

## Context: What the Codebase Already Uses

The existing Dashboard engine is built entirely on MATLAB's traditional `figure`/`uipanel`/`uicontrol` API — not the App Designer (`uifigure`) API. Specifically:

- `figure(...)` — top-level window
- `uipanel(...)` — widget containers and layout areas
- `uicontrol(...)` — buttons, sliders, text labels, togglebuttons
- `axes(...)` — plot areas inside `uipanel`
- MATLAB `timer` — live refresh loop
- Normalized `Units` throughout — all positions as `[x y w h]` in `[0..1]`

**All new features must stay within this `figure`/`uicontrol` surface.** Mixing in `uifigure` (App Designer) would break the entire graphics hierarchy: `uifigure` and `figure` cannot share children, so widgets rendered inside one cannot be moved into the other. This is a hard constraint.

---

## Recommended APIs and Patterns for Each Feature

### 1. Tabbed Layout Sections

**Chosen approach:** Custom tab buttons via `uicontrol` + per-tab `uipanel` visibility toggling

**What to use:**
- `uicontrol('Style', 'pushbutton', ...)` — one button per tab in a thin header bar
- One `uipanel` per tab for content, same `Position`, toggled with `'Visible', 'on'/'off'`
- Active tab button distinguished by `BackgroundColor`

**Why this approach and not `uitabgroup`/`uitab`:**
- `uitabgroup` is a `uifigure`-only component in modern MATLAB. In traditional `figure` contexts, `uitabgroup` exists but its visual integration with custom themes is poor — it renders with system-native styling that ignores `BackgroundColor`/`ForegroundColor` on many platforms and cannot be styled to match the dashboard's dark/light themes.
- The codebase already implements this exact pattern in `GroupWidget.renderTabbedChildren()`. The custom button approach gives full theming control and works identically in MATLAB R2020b+ and GNU Octave 7+. **The pattern is already proven** — no new API needed.
- `uitab`/`uitabgroup` also have Octave compatibility gaps; `uicontrol` pushbuttons are universally supported.

**Confidence:** HIGH — verified by reading existing `GroupWidget.m` implementation.

---

### 2. Collapsible Sections

**Chosen approach:** Toggle button in header + `Visible` toggle on content `uipanel` + grid reflow

**What to use:**
- `uicontrol('Style', 'pushbutton', ...)` in the header bar as the collapse toggle
- Set `hChildPanel.Visible = 'off'` to hide content; `'on'` to restore
- When collapsing: record `ExpandedHeight`, set `Position(4) = 1` (minimum grid height)
- When expanding: restore `Position(4)` from `ExpandedHeight`
- After state change: call `DashboardLayout.reflow(hFigure, widgets, theme)` to re-pack the grid

**Critical gap identified in existing code:** `GroupWidget.collapse()` and `expand()` already set `Position(4)` and toggle `hChildPanel.Visible`, but they contain a `TODO` comment: `% TODO: call DashboardLayout.reflow() — requires engine-level wiring`. This wiring is the remaining work. The GroupWidget needs a reference to the DashboardEngine (or a callback to it) so collapse/expand can trigger `reflow()`.

**Implementation pattern:**
```
% In GroupWidget, add property:
EngineRef = []    % weak reference to owning DashboardEngine

% In collapse()/expand(), after toggling Visible:
if ~isempty(obj.EngineRef)
    theme = DashboardTheme(obj.EngineRef.Theme);
    obj.EngineRef.Layout.reflow(obj.EngineRef.hFigure, ...
        obj.EngineRef.Widgets, theme);
end
```

**Why not CSS-style animation:** MATLAB has no built-in animation for panel resize. Instant resize (no tween) is appropriate and consistent with the rest of the UI.

**Confidence:** HIGH — pattern is already 80% implemented; gap is well-defined.

---

### 3. Multi-Page Navigation

**Chosen approach:** Top-level page concept in `DashboardEngine` with per-page widget sets and a page-selector control in the toolbar

**What to use:**
- Add `Pages` property to `DashboardEngine` — cell array of structs, each with `name` and `widgets` cell array
- Add `ActivePage` index/name property
- Page selector: `uicontrol('Style', 'popupmenu', ...)` or a row of `pushbutton` controls in `DashboardToolbar`
- On page switch: hide all current widget panels (`set(w.hPanel, 'Visible', 'off')`), show the new page's panels
- Lazy realization: unrealized widgets on inactive pages are not rendered until page is first shown

**Why `popupmenu` for page selector:**
- Compact, scales to many pages without consuming toolbar width
- Single `uicontrol` call, no layout arithmetic
- Works in MATLAB R2020b+ and Octave

**Alternative (pushbuttons per page):** Better for 2-4 pages, matches the tab button aesthetic already used in `GroupWidget`. Use this when page count <= 5; fall back to `popupmenu` for more.

**Serialization:** `DashboardSerializer` needs a `pages` key alongside `widgets` in the JSON schema. Backward compatibility: if `pages` key is absent, all widgets go to a single default page (current behavior preserved).

**Confidence:** MEDIUM — pattern is straightforward but multi-page serialization is new territory; the existing `DashboardSerializer` JSON schema will need careful extension.

---

### 4. Per-Widget Info Tooltips

**Two sub-features with different APIs:**

#### 4a. Hover tooltip (passive)

**What to use:** `uicontrol` `TooltipString` property

```matlab
uicontrol(hPanel, 'Style', 'pushbutton', 'String', 'i', ...
    'TooltipString', widget.Description, ...
    'Units', 'normalized', 'Position', [0.90 0.85 0.08 0.13], ...
    'FontSize', 7, 'FontWeight', 'bold')
```

- Set on the info icon `uicontrol` inside each widget's `hPanel`
- `TooltipString` is a native MATLAB property on all `uicontrol` objects — no additional machinery required
- Tooltip appears automatically on hover after a system-defined delay; no `ButtonDownFcn` needed

**Why `TooltipString` and not a custom overlay:**
- Zero implementation cost — it's a single property set
- Works in MATLAB R2020b+ and Octave 7+
- Native OS tooltip styling; no z-order issues, no need to manage a floating panel

**Confidence:** HIGH — `TooltipString` is a documented, stable `uicontrol` property. Already used in the existing codebase: `DashboardToolbar.m` line 104 sets `'TooltipString', 'Reset all widgets to global time range'` on the Sync button.

#### 4b. Click-to-expand description (richer text)

For widgets where `Description` contains longer text or the user wants persistent display:

**What to use:** A small modal `figure` window (not `uifigure`) opened via a button callback

```matlab
function showTooltipPopup(widget)
    f = figure('Name', [widget.Title, ' — Info'], ...
        'NumberTitle', 'off', 'MenuBar', 'none', ...
        'ToolBar', 'none', 'Resize', 'on', ...
        'Units', 'normalized', ...
        'OuterPosition', [0.3 0.4 0.4 0.2]);
    uicontrol(f, 'Style', 'text', ...
        'Units', 'normalized', 'Position', [0.02 0.05 0.96 0.90], ...
        'String', widget.Description, ...
        'HorizontalAlignment', 'left', ...
        'FontSize', 10);
end
```

**Recommended default:** Use `TooltipString` only (4a). The click-to-expand popup is optional and should only be added if user testing shows `TooltipString` truncates descriptions too aggressively (MATLAB truncates at ~500 chars).

**Confidence:** HIGH — both mechanisms are established MATLAB patterns.

---

### 5. Detachable Live-Mirrored Widgets

**Chosen approach:** Clone widget into a new `figure` window; hook into the `DashboardEngine.LiveTimer` via a second per-widget timer or a shared timer list

**What to use:**

#### 5a. Creating the detached window

```matlab
function hDetached = detach(widget, engine)
    hDetached = figure('Name', ['[Detached] ', widget.Title], ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'OuterPosition', [0.1 0.1 0.5 0.5], ...
        'CloseRequestFcn', @(~,~) onDetachClose(widget));

    % Create a full-window uipanel as render target
    hp = uipanel(hDetached, 'Units', 'normalized', ...
        'Position', [0 0 1 1], 'BorderType', 'none');

    % Deep-clone the widget
    wClone = widget.cloneForDetach();
    wClone.render(hp);

    % Register clone with engine for live updates
    engine.registerDetachedWidget(wClone, hDetached);
end
```

#### 5b. Live mirroring strategy — shared timer (recommended)

**Do not create a separate timer per detached widget.** MATLAB timers are expensive system objects; excessive timers degrade overall performance and the command-line timer list becomes cluttered.

**Instead:** Extend `DashboardEngine.onLiveTick()` to also refresh a `DetachedWidgets` list:

```matlab
% DashboardEngine additions:
DetachedWidgets = {}    % cell array of {widget, hFigure} pairs

function registerDetachedWidget(obj, widget, hFig)
    obj.DetachedWidgets{end+1} = {widget, hFig};
end

% In onLiveTick(), after the main refresh loop:
for i = 1:numel(obj.DetachedWidgets)
    entry = obj.DetachedWidgets{i};
    w = entry{1};
    hf = entry{2};
    if ishandle(hf)
        w.refresh();
    else
        % Figure was closed — prune entry
        obj.DetachedWidgets(i) = [];
    end
end
```

This piggybacks on the existing timer; detached widgets get the same `LiveInterval` refresh as the dashboard. Overhead is proportional to the number of detached widgets, which in practice is 1-3.

#### 5c. Widget cloning

Each `DashboardWidget` subclass needs a `cloneForDetach()` method. The base class should provide a default implementation using `toStruct()` + `fromStruct()` (the serialization round-trip is already implemented). Custom widgets with non-serializable state (e.g., `FastSenseWidget` with a live `FastSenseObj`) need to override `cloneForDetach()` to re-bind to the same data source rather than deep-copying the MATLAB graphics handle.

```matlab
% Base class default (works for stateless widgets):
function w = cloneForDetach(obj)
    s = obj.toStruct();
    w = DashboardSerializer.createWidgetFromStruct(s);
end

% FastSenseWidget override (rebind, don't copy graphics):
function w = cloneForDetach(obj)
    w = FastSenseWidget('Sensor', obj.Sensor, ...
        'Title', obj.Title, 'Position', [1 1 24 6]);
end
```

**Why `figure` not `uifigure` for detached window:** Same constraint as above — widgets are rendered into traditional `figure`/`uipanel` hierarchies. A `uifigure` cannot host `uipanel`/`axes` children created with `figure`-API calls.

**Confidence:** HIGH for the timer-sharing approach. MEDIUM for `cloneForDetach()` — the `toStruct()`/`fromStruct()` round-trip works for most widgets but `FastSenseWidget` and `RawAxesWidget` have non-serializable state that requires explicit overrides.

---

## What NOT to Use

| Component | Reason to Avoid |
|-----------|-----------------|
| `uitabgroup` / `uitab` | `uifigure`-only in modern MATLAB; cannot be themed to match dashboard colors; Octave support gaps. Custom button tabs already exist and work. |
| `uifigure` | Incompatible graphics hierarchy — cannot host children created via `figure` API. Would require rewriting the entire dashboard. |
| `uipanel` `Title` property for collapsible headers | The Title renders as a labeled border frame, not a clickable header bar. Cannot be used as a button. |
| `uilabel` / `uibutton` (App Designer components) | Only work inside `uifigure`. Any `ui*` component from R2016b+ App Designer is `uifigure`-only. |
| Separate `timer` per detached widget | Creates O(n) timers; MATLAB timer overhead is significant; adds cleanup complexity on figure close. |
| `msgbox` / `helpdlg` for tooltips | Modal, blocking — destroys live dashboard UX. `TooltipString` is non-blocking and sufficient. |
| `javaframe` hacks for custom tooltips | Removed in MATLAB R2023b+; never supported in Octave. |

---

## Alternatives Considered

| Feature | Recommended | Alternative | Why Not |
|---------|-------------|-------------|---------|
| Tabs | Custom `uicontrol` pushbuttons (existing) | `uitabgroup` | `uifigure`-only styling; Octave gaps |
| Tooltip | `uicontrol` `TooltipString` | Custom floating `uipanel` overlay | Z-order management in figure is fragile; `TooltipString` is native and free |
| Detach window | New `figure()` | `uifigure()` | Incompatible with existing graphics hierarchy |
| Live mirror | Extend `DashboardEngine.onLiveTick()` | Per-widget `timer` | Timer proliferation; cleanup complexity |
| Page navigation | `popupmenu` in toolbar | New toolbar row | Toolbar row consumes permanent vertical space; popupmenu is compact |
| Collapse reflow | `DashboardLayout.reflow()` callback | Partial re-layout | `reflow()` already exists; partial layout would diverge from existing position-tracking logic |

---

## Version Compatibility Notes

| API | MATLAB min | Octave min | Notes |
|-----|------------|------------|-------|
| `uipanel` + `uicontrol` | R2006a | 4.0 | Core API; stable |
| `uicontrol` `TooltipString` | R2006a | 4.0 | Stable; may truncate long strings |
| `timer` (ExecutionMode fixedRate) | R2008a | 4.0 | Already used in `LiveEventPipeline` |
| `figure` `WindowScrollWheelFcn` | R2007a | 5.0 | Already used in `DashboardLayout` |
| `ishandle()` | All | All | Used throughout for validity checks |
| `uitabgroup` / `uitab` (native `figure`) | R2014b | 5.0 partial | **Do not use** — theming broken |

The existing codebase targets MATLAB R2020b+ and Octave 7+. All recommended APIs above are available in both environments at these versions.

---

## Implementation Priority Mapping

| Feature | API Complexity | Existing Foundation | Work Remaining |
|---------|---------------|--------------------|-----------------------|
| Info tooltips | Very low | `TooltipString` already used in toolbar | Add `TooltipString` to info icon in widget header |
| Collapsible reflow | Low | `collapse()`/`expand()` exist; `reflow()` exists | Wire `EngineRef` callback into `GroupWidget` |
| Tabbed sections | Low | `renderTabbedChildren()` fully implemented | Polish/bug-fix only; no new API needed |
| Detachable widgets | Medium | `figure`, `uipanel`, `timer` all used | Add `cloneForDetach()`, `registerDetachedWidget()`, detach button in widget header |
| Multi-page nav | Medium | `DashboardEngine` widget list already per-engine | Add `Pages` struct, page selector control, serialization extension |

---

## Sources

- Codebase analysis: `/Users/hannessuhr/FastPlot/libs/Dashboard/` (DashboardEngine.m, DashboardWidget.m, GroupWidget.m, DashboardLayout.m, DashboardToolbar.m) — HIGH confidence, read directly
- MATLAB `uicontrol` `TooltipString` usage: confirmed in `DashboardToolbar.m` line 104 — HIGH confidence
- `uitabgroup` theming limitations in traditional `figure`: training data — MEDIUM confidence (flag for validation if Octave + styled tabs are ever needed)
- Timer per-widget anti-pattern: inferred from existing `LiveEventPipeline` single-timer design — HIGH confidence (consistent with MATLAB best practices)
- `uifigure` / `figure` hierarchy incompatibility: MATLAB fundamental constraint (handle graphics vs. web-based graphics systems) — HIGH confidence
