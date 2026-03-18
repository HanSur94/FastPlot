# Dashboard Info Page — Design Spec

## Overview

Add an "Info" button to the dashboard toolbar that opens a rendered Markdown file in MATLAB's built-in browser (or the system browser on Octave). Users link a `.md` file to their dashboard via the `InfoFile` property; the button only appears when a file is linked.

## Decisions

| Question | Decision |
|----------|----------|
| Content purpose | General-purpose "about this dashboard" page |
| Content authoring | Link a `.md` Markdown file in the dashboard config |
| Button placement | Right of the title text, separate from action buttons |
| Rendering | MATLAB `web()` with a lightweight Markdown-to-HTML converter; Octave fallback to system browser |
| No file linked | Info button is hidden entirely |
| Property API | Public property (`Access = public`) + construction name-value pair (matches existing patterns) |

## Components

### 1. `InfoFile` property on `DashboardEngine`

- New public property (`Access = public`): `InfoFile = ''`
- Accepts a path to a `.md` file (absolute or relative to dashboard JSON location)
- Settable at construction: `DashboardEngine('Name', 'InfoFile', 'info.md')`
- Settable after construction: `d.InfoFile = 'docs/info.md'`
- No constructor changes needed — existing name-value parsing loop handles any public property
- **Note:** Setting `InfoFile` after `render()` has been called does not retroactively add or remove the toolbar button. The property takes effect on the next `render()` call. This matches how `Theme` works — changes after render require re-rendering.

### 2. Info button in `DashboardToolbar`

- New handle property in `properties (SetAccess = private)` block (matching all other toolbar handles): `hInfoBtn`
- Created only when `engine.InfoFile` is non-empty at render time
- **Position:** Title text is shortened from `0.30` to `0.27` width when the Info button is present. Info button placed at `[0.29, btnY, 0.05, btnH]` — a narrower button (`0.05` vs `0.06` for action buttons) with a `0.01` gap after the title.
- Label: `"Info"` (plain text, no Unicode for cross-platform compatibility)
- Callback: `obj.onInfo()` → delegates to `obj.Engine.showInfo()`

### 3. `MarkdownRenderer` — new file `libs/Dashboard/MarkdownRenderer.m`

Static utility class with one public method:

```matlab
html = MarkdownRenderer.render(mdText)
html = MarkdownRenderer.render(mdText, themeName)
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

Output is wrapped in a full HTML document with inline CSS for clean typography. CSS adapts to the dashboard theme (light/dark) — the theme name is passed as an optional second argument.

**Unknown theme handling:** If `themeName` is omitted or not recognized, defaults to `'light'` styling.

Pure MATLAB string operations (`regexprep`, `strsplit`, line-by-line). No external dependencies.

### 4. `showInfo()` method on `DashboardEngine`

Flow when the Info button is clicked:

1. **Resolve file path** — if `InfoFile` is relative, resolve against `fileparts(obj.FilePath)` (the saved JSON directory). If `FilePath` is empty (unsaved), resolve against `pwd`. Note: `FilePath` reflects the last save/load location; if the JSON is moved externally, relative resolution may point to an unexpected location.
2. **Read the `.md` file** — `fid = fopen(path, 'r')`, `mdText = fread(fid, '*char')'`, `fclose(fid)` — wrapped in `try/catch`. `fclose(fid)` is called on both the success path (after `fread`, still inside `try`) and in the `catch` block. This matches the `fread` pattern in `DashboardSerializer.load`. If file not found, show `warndlg` with the attempted path.
3. **Convert to HTML** — `html = MarkdownRenderer.render(mdText, obj.Theme)`
4. **Write temp HTML file** — Store the temp file path as a private property `InfoTempFile`. Reuse and overwrite the same path on each click (avoids temp file leaks). Create the path on first use with `[tempname '.html']`. The `delete(obj)` destructor cleans up the temp file when the engine is destroyed (check `~isempty(obj.InfoTempFile) && exist(obj.InfoTempFile, 'file')` before deleting).
5. **Display** — Use `web(htmlFile, '-new')` on MATLAB. On Octave (detected via `exist('OCTAVE_VERSION', 'builtin')`), fall back to `system()` with the platform-appropriate command: `xdg-open` (Linux), `open` (macOS), or `cmd /c start` (Windows). The file path must be quoted in the `system()` call to handle paths with spaces: e.g. `system(['open "' htmlFile '"'])`.

No caching — re-reads the `.md` file each click so edits are reflected immediately.

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
- `widgetsToConfig` — add optional 5th argument `infoFile` (defaults to `''` when omitted via `nargin < 5` check, preserving backward compatibility with existing callers and tests). Include `infoFile` in config struct only when non-empty. Existing `TestDashboardSerializer` and `TestDashboardEngine` tests pass unmodified — 4-argument calls continue to work and produce configs without an `infoFile` field.
- `exportScript` — emits `d.InfoFile = '...';` when `infoFile` is present in config

**`DashboardEngine` changes:**
- `save()` — passes `obj.InfoFile` to `widgetsToConfig` (5th argument)
- `exportScript()` — passes `obj.InfoFile` to `widgetsToConfig` (5th argument)
- `load()` — reads `config.infoFile` if the field exists, sets `obj.InfoFile`

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
| MarkdownRenderer unknown theme | Unknown theme name defaults to light styling |
| Serialization round-trip | Save with `InfoFile` → load → `InfoFile` preserved |
| Serialization without InfoFile | Save without it → JSON has no `infoFile` field |
| Serialization backward compat | `widgetsToConfig` with 4 args still works (no `infoFile`) |
| Export script with InfoFile | `exportScript` emits `d.InfoFile = '...';` when set |
| Export script without InfoFile | `exportScript` omits `InfoFile` line when not set |
| File path resolution | Relative paths resolve against dashboard `FilePath` directory |
| File path resolution (unsaved) | Relative path with empty `FilePath` resolves against `pwd` |
| Missing file handling | `showInfo()` with nonexistent path produces warning, no crash |

## Files Changed

| File | Change |
|------|--------|
| `libs/Dashboard/DashboardEngine.m` | Add `InfoFile` property, `InfoTempFile` private property, `showInfo()` method, temp file cleanup in `delete()`, update `save`/`load`/`exportScript` |
| `libs/Dashboard/DashboardToolbar.m` | Add `hInfoBtn`, conditional creation with title resize, `onInfo()` callback |
| `libs/Dashboard/DashboardSerializer.m` | Add optional `infoFile` param to `widgetsToConfig`, handle in `exportScript` |
| `libs/Dashboard/MarkdownRenderer.m` | New file — Markdown-to-HTML converter |
| `tests/suite/TestDashboardInfo.m` | New file — test suite |
