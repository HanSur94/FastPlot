# Dashboard Info Page — Design Spec

## Overview

Add an "Info" button to the dashboard toolbar that opens a rendered Markdown file in MATLAB's built-in browser. Users link a `.md` file to their dashboard via the `InfoFile` property; the button only appears when a file is linked.

## Decisions

| Question | Decision |
|----------|----------|
| Content purpose | General-purpose "about this dashboard" page |
| Content authoring | Link a `.md` Markdown file in the dashboard config |
| Button placement | Right of the title text, separate from action buttons |
| Rendering | MATLAB `web()` with a lightweight Markdown-to-HTML converter |
| No file linked | Info button is hidden entirely |
| Property API | Public property + construction name-value pair (matches existing patterns) |

## Components

### 1. `InfoFile` property on `DashboardEngine`

- New public property: `InfoFile = ''`
- Accepts a path to a `.md` file (absolute or relative to dashboard JSON location)
- Settable at construction: `DashboardEngine('Name', 'InfoFile', 'info.md')`
- Settable after construction: `d.InfoFile = 'docs/info.md'`
- No constructor changes needed — existing name-value parsing loop handles any public property

### 2. Info button in `DashboardToolbar`

- New private handle property: `hInfoBtn`
- Created only when `engine.InfoFile` is non-empty
- Position: `[0.32, btnY, btnW, btnH]` — immediately right of the title text
- Label: `"Info"` (plain text, no Unicode for cross-platform compatibility)
- Callback: `obj.onInfo()` → delegates to `obj.Engine.showInfo()`

### 3. `MarkdownRenderer` — new file `libs/Dashboard/MarkdownRenderer.m`

Static utility class with one public method:

```matlab
html = MarkdownRenderer.render(mdText)
```

Supported Markdown subset:
- `#`, `##`, `###` headings → `<h1>`, `<h2>`, `<h3>`
- `**bold**` → `<strong>`, `*italic*` → `<em>`
- `- item` and `* item` → `<ul><li>`
- `1. item` → `<ol><li>`
- `` `inline code` `` → `<code>`
- Fenced code blocks (triple backtick) → `<pre><code>`
- `[text](url)` → `<a href>`
- Blank lines → paragraph breaks
- `---` → `<hr>`

Output is wrapped in a full HTML document with inline CSS for clean typography. CSS adapts to the dashboard theme (light/dark) — the theme name is passed as an optional second argument: `MarkdownRenderer.render(mdText, 'dark')`.

Pure MATLAB string operations (`regexprep`, `strsplit`, line-by-line). No external dependencies.

### 4. `showInfo()` method on `DashboardEngine`

Flow when the Info button is clicked:

1. **Resolve file path** — if `InfoFile` is relative, resolve against `fileparts(obj.FilePath)` (the saved JSON directory). If `FilePath` is empty (unsaved), resolve against `pwd`.
2. **Read the `.md` file** — `fopen`/`fread`/`fclose`. If file not found, show `warndlg` with the attempted path.
3. **Convert to HTML** — `html = MarkdownRenderer.render(mdText, obj.Theme)`
4. **Write temp HTML file** — `[tempname '.html']` in `tempdir`
5. **Display** — `web(htmlFile, '-new')` opens MATLAB's internal browser

No caching — re-reads the file each click so edits are reflected immediately.

### 5. Serialization

**JSON format** — `infoFile` at the top level:
```json
{
  "name": "My Dashboard",
  "theme": "dark",
  "liveInterval": 5,
  "infoFile": "docs/dashboard_info.md",
  "grid": {"columns": 24},
  "widgets": [...]
}
```

**`DashboardSerializer` changes:**
- `widgetsToConfig` — accepts `infoFile` as 5th argument, includes it in config struct only when non-empty
- `exportScript` — emits `d.InfoFile = '...';` when `infoFile` is present in config

**`DashboardEngine` changes:**
- `save()` — passes `obj.InfoFile` to `widgetsToConfig`
- `load()` — reads `config.infoFile` if the field exists, sets `obj.InfoFile`
- `exportScript()` — passes `obj.InfoFile` to `widgetsToConfig`

## Testing

New test file: `tests/suite/TestDashboardInfo.m`

| Test | Description |
|------|-------------|
| InfoFile property defaults | Default is empty string, settable at construction and after |
| Toolbar button visibility | Button handle exists when `InfoFile` is set, absent when empty |
| MarkdownRenderer headings | `# H1`, `## H2`, `### H3` produce correct HTML tags |
| MarkdownRenderer inline | Bold, italic, inline code, links convert correctly |
| MarkdownRenderer lists | Unordered and ordered lists produce `<ul>/<ol>` with `<li>` items |
| MarkdownRenderer code blocks | Fenced code blocks produce `<pre><code>` |
| MarkdownRenderer horizontal rule | `---` produces `<hr>` |
| Serialization round-trip | Save with `InfoFile` → load → `InfoFile` preserved |
| Serialization without InfoFile | Save without it → JSON has no `infoFile` field |
| File path resolution | Relative paths resolve against dashboard `FilePath` directory |
| Missing file handling | `showInfo()` with nonexistent path produces warning, no crash |

## Files Changed

| File | Change |
|------|--------|
| `libs/Dashboard/DashboardEngine.m` | Add `InfoFile` property, `showInfo()` method, update `save`/`load`/`exportScript` |
| `libs/Dashboard/DashboardToolbar.m` | Add `hInfoBtn`, conditional creation, `onInfo()` callback |
| `libs/Dashboard/DashboardSerializer.m` | Add `infoFile` to `widgetsToConfig`, `load`, `exportScript` |
| `libs/Dashboard/MarkdownRenderer.m` | New file — Markdown-to-HTML converter |
| `tests/suite/TestDashboardInfo.m` | New file — test suite |
