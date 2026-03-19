# Dashboard ASCII Preview — Design Spec

**Date:** 2026-03-19
**Status:** Approved

## Summary

Add an ASCII preview function to the dashboard engine that prints a graphical console representation of the dashboard layout with widget content. This allows users to visualize their dashboard layout without calling `render()` — useful during programmatic dashboard construction.

## Usage

```matlab
d = DashboardEngine('My Dashboard');
d.addWidget('fastsense', 'Title', 'Temp', 'Position', [1 1 12 3]);
d.addWidget('number', 'Title', 'Max', 'Position', [13 1 6 1]);
d.addWidget('status', 'Title', 'Pump', 'Position', [13 2 6 1]);
d.preview();              % default 120 chars wide
d.preview('Width', 80);   % custom width
```

## Architecture

### Approach: Abstract `asciiRender()` on widgets + compositor in engine

Follows the existing architectural pattern where widgets implement abstract methods (`render()`, `refresh()`, `getType()`). Each widget knows best how to represent itself in ASCII.

### Widget Interface

Each widget subclass implements:

```matlab
lines = asciiRender(obj, width, height)
```

- `width`: available character columns for content (inside box border)
- `height`: available character rows (inside box border)
- Returns: cell array of strings, each exactly `width` characters (padded/truncated)

**Height contract:**
- `asciiRender` may return fewer lines than `height` — the compositor pads with blank lines at the bottom.
- `asciiRender` may return more lines than `height` — the compositor truncates to `height`.
- When `height == 0`, `asciiRender` must return an empty cell `{}`.

`DashboardWidget` provides a **default implementation** (non-abstract) that shows `[type] Title`. Subclasses override for richer output. This means existing and future widgets work without requiring an override.

### Graceful Degradation

The preview works **before `render()` is called**. Widgets check whether data is available and degrade gracefully:

- **Data available** (Sensor with Y data, StaticValue, XData/YData): show detailed representation
- **No data yet**: show a type-specific placeholder

### Per-Widget ASCII Representations

| Widget | With data | Without data |
|--------|-----------|--------------|
| `fastsense` | Sparkline `▁▃▅▇▅▃▁` + title | `[~~ fastsense ~~]` + title |
| `number` | `72.5 °C  ▲` | `[-- number --]` + title |
| `status` | `● OK` or `● ALARM` | `[● status]` + title |
| `text` | Title + Content text | Title only |
| `gauge` | Bar `[████░░░░] 65%` | `[-- gauge --]` + title |
| `table` | `3 cols × 10 rows` summary | `[-- table --]` + title |
| `group` | Panel/collapsible: `[group: N children]`; Tabbed: `[group: N tabs]` | `[-- group --]` + title |
| `heatmap` | Matrix size summary | `[-- heatmap --]` + title |
| `barchart` | Category count summary | `[-- barchart --]` + title |
| `histogram` | Data range summary | `[-- histogram --]` + title |
| `scatter` | Point count summary | `[-- scatter --]` + title |
| `image` | `[img: filename.ext]` | `[-- image --]` + title |
| `timeline` | `N events` | `[-- timeline --]` + title |
| `rawaxes` | `[custom axes]` | `[-- rawaxes --]` + title |
| `multistatus` | `N sensors: OK/WARN` (uses cached status from existing `refresh` logic) | `[-- multistatus --]` + title |

### Engine Compositor: `DashboardEngine.preview()`

```matlab
d.preview()              % default 120 chars wide
d.preview('Width', 80)   % custom width
```

**Algorithm:**

1. **Handle empty dashboard** — if `numel(obj.Widgets) == 0`, print `"  DashboardName (empty — no widgets)"` and return
2. **Enforce minimum width** — `width = max(width, 48)`. Below 48 chars, widgets become unreadable (24 columns at 2 chars each). If the user passed a value below 48, issue a warning.
3. **Calculate grid bounds** — scan all widgets for max row; columns from `obj.Layout.Columns` (default 24)
4. **Map grid to characters** — each grid column gets `floor(width / obj.Layout.Columns)` chars; each grid row gets a fixed height in character lines (4 lines per grid row: title + 1-2 content lines + borders)
3. **Create 2D character buffer** — filled with spaces, sized `(maxRow * linesPerRow) × width`
4. **For each widget:**
   - Convert grid position `[col, row, w, h]` to character coordinates
   - Draw box-drawing border (`┌─┐│└─┘`)
   - Call `widget.asciiRender(innerW, innerH)` for content lines
   - Place content inside box
5. **Print** — `fprintf` each row with dashboard name header

**Example output:**
```
  My Dashboard (3 widgets, 24×3 grid)
┌────────────────────────────┐┌─────────────────────────┐
│ Temperature                ││ Max Temp                │
│ ▁▂▃▅▇▅▃▂▁▂▃▅▇▅▃▂▁        ││       72.5 °C         ▲ │
│                            │├─────────────────────────┤
│                            ││ ● Pump 1: OK            │
│                            ││                         │
└────────────────────────────┘└─────────────────────────┘
```

## Scope

### Files to modify

1. **`DashboardWidget.m`** — add default `asciiRender(width, height)` method
2. **`DashboardEngine.m`** — add `preview(varargin)` public method
3. **15 widget subclasses** — each overrides `asciiRender()` with type-specific content

### Not in scope

- No ANSI color codes (MATLAB command window support unreliable)
- No interactive mode — one-shot print only
- No changes to existing `render()`, `refresh()`, or serialization paths
- No new files — everything fits into existing classes
- Overlapping widgets: `addWidget()` already enforces overlap resolution. If overlaps occur from manual `setWidgetPosition` or malformed JSON, last-writer-wins in the character buffer is acceptable.

### Unicode Portability

Box-drawing characters (`┌─┐│└─┘`) and sparkline blocks (`▁▂▃▅▇`) require UTF-8 support in the command window. This works on MATLAB R2020b+ and modern Octave. On older environments these may render as `?`. We use Unicode as the default since the project already targets R2020b+; no ASCII fallback is needed.

## Testing

New test class `TestDashboardPreview.m`:

- Empty dashboard preview
- Single widget preview
- Multi-widget grid layout
- Preview with and without bound data
- Custom width parameter
- All widget types produce valid ASCII output (correct dimensions, no errors)
