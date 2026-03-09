# Theme Selector Toolbar Button — Design

## Overview

Add a toolbar button with a paint palette icon that opens a context menu listing all available themes. Clicking a theme applies it to the entire figure hierarchy (dock, figure, and all tiles).

## Components

### 1. Theme Registry (file-based custom themes)

- Custom themes live as `.m` files in a `themes/` folder (relative to FastPlot root)
- Each file is a function returning a theme struct: `function t = midnight(); t = struct('Background', [0 0 0.1], ...); end`
- `FastPlotDefaults.m` gets a `ThemeDir` field (default: `'themes'`)
- `getDefaults()` scans `ThemeDir` at load time, calls each `.m` file, and attaches results to `cfg.CustomThemes` (struct where field name = filename)

### 2. Toolbar Button

- New `uipushtool` added to `FastPlotToolbar.m` with a 16x16 paint palette icon
- On click: opens a `uicontextmenu` positioned near the toolbar
- Menu items:
  - 5 built-in presets: default, dark, light, industrial, scientific
  - Separator
  - Custom themes discovered from `cfg.CustomThemes`
- Checkmark on the currently active theme

### 3. Theme Application (full hierarchy)

- Applies theme to the entire hierarchy: dock background/tab bar, figure, all tiles
- Toolbar detects whether its target is `FastPlot`, `FastPlotFigure`, or `FastPlotDock` and propagates accordingly
- Reuses existing `applyTheme()` / `render()` methods

### Data Flow

```
Button click
  → build uicontextmenu with built-in + custom themes
  → user picks theme
  → resolveTheme(name) produces theme struct
  → store theme on target
  → re-render entire hierarchy
```

### Icon

16x16 pixel-art paint palette in the same style as existing toolbar icons (RGB matrix, light gray background, colored paint dots).
