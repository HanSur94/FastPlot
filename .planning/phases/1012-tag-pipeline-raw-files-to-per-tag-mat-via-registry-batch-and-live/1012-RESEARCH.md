# Phase 1012: Tag Pipeline — raw files to per-tag MAT via registry, batch and live — Research

**Researched:** 2026-04-22
**Domain:** MATLAB/Octave delimited-text ingestion pipeline feeding the v2.0 Tag domain model
**Confidence:** HIGH on codebase-internal patterns (direct read of SensorTag/StateTag/Tag/TagRegistry/MatFileDataSource/LiveEventPipeline); HIGH on Octave parser constraint (official Octave 11 docs confirm `readtable`/`readmatrix` absence); MEDIUM on filesystem mtime resolution edge cases (documented but untested on project CI matrix)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Raw input surface:**
- **D-01:** Ship **one shared delimited-text parser** used for `.csv`, `.txt`, and `.dat`. Extension is a hint only; the parser sniffs the delimiter (comma / tab / semicolon / whitespace).
- **D-02:** **No public parser-registration API this phase.** Built-ins are fixed. Architect the internal dispatch so a future phase can add `registerParser(ext, fn)` without rewrite, but do not expose it now.
- **D-03:** **Synthetic in-test fixtures only** — no real sample files to target. Tests generate CSV/TXT/DAT variants in-suite.
- **D-04:** Pipeline supports **both wide** (time column + N value columns) **and tall** (2 cols: time + value) raw shapes. Dispatch by column count vs. the `RawSource.column` field.

**Tag ↔ file binding:**
- **D-05:** Binding lives on the **tag itself** via a new `RawSource` struct property on `SensorTag` and `StateTag`. `Tag` base is **not** touched (preserves Pitfall-1/5 discipline from v2.0).
  ```matlab
  SensorTag('pump_a_pressure', 'Units', 'bar', ...
      'RawSource', struct('file',   'data/raw/loggerA.csv', ...
                          'column', 'pressure_a', ...
                          'format', ''));
  ```
  `MonitorTag` / `CompositeTag` deliberately do **not** get this property (they are derived).
- **D-06:** For tall files, `column` may be omitted. For wide files, `column` is required; missing-column at ingest → per-tag error.
- **D-07:** **Pipeline de-dups file reads internally**: when N tags share the same `RawSource.file`, the file is opened/parsed once per pipeline run and fanned out to each tag's column.
- **D-08:** Tags without a `RawSource` (or `MonitorTag` / `CompositeTag`) are **skipped silently**.

**Per-tag `.mat` output schema:**
- **D-09:** Each output file contains exactly `data.<KeyName> = struct('x', X, 'y', Y)` — data only, matching `SensorTag.load()`.
- **D-10:** **Strict one-tag-per-`.mat`** — output file is `<OutputDir>/<tagKey>.mat`.
- **D-11:** `StateTag` output reuses the same `{x, y}` shape (`y` may be numeric or cellstr).

**Batch vs live orchestration:**
- **D-12:** **Two classes**: `BatchTagPipeline` + `LiveTagPipeline`. Shared private helper module handles parse-and-write.
- **D-13:** `LiveTagPipeline` mirrors `MatFileDataSource`'s `modTime + lastIndex` pattern on raw files.
- **D-14:** `LiveTagPipeline` does **not** subclass `LiveEventPipeline`. Lives in its own module to avoid cross-library coupling.

**Output location:**
- **D-15:** `OutputDir` is a **constructor parameter** on both pipeline classes. Pipeline creates directory if missing. No per-tag override.

**Monitor / composite policy:**
- **D-16:** **Raw-only pipeline.** `MonitorTag` / `CompositeTag` are never materialized to disk. Preserves MONITOR-03 lazy-by-default.
- **D-17:** Users continue to use `MonitorTag.Persist = true` + `FastSenseDataStore.storeMonitor` for monitor persistence (Phase 1007). Orthogonal to this pipeline.

**Error policy:**
- **D-18:** **Per-tag isolated error handling.** Each tag's ingest is a try/catch boundary. End-of-run → `TagPipeline:ingestFailed` throw with report.
- **D-19:** Specific errors: corrupt file, unreadable file, missing column, delimiter-detect failure, empty/header-only file. Each gets a `TagPipeline:*` error ID.

### Claude's Discretion
- Exact delimiter-sniffing algorithm (likely: try `,` → `\t` → `;` → whitespace and pick the one producing consistent column counts).
- Internal parser dispatch shape (switch-by-extension vs. private `containers.Map` keyed by extension).
- Directory-create behavior (`mkdir -p` semantics; error only on permission failures).
- Error-ID naming under `TagPipeline:*`.
- Private helper placement (`+private` folder vs. static class vs. plain function file).
- File-count budget (likely ≤12).
- Whether to add a `.pipelineVersion` getter.

### Deferred Ideas (OUT OF SCOPE)
- Public `registerParser(ext, fn)` plugin API.
- Binary `.dat` layout support.
- Metadata snapshot inside `.mat` files.
- Multi-tag `.mat` layouts.
- Monitor/composite pre-materialization.
- `FastSenseDataStore` handoff for huge ingests.
- Load-side API rework / new `TagLoader` class.
- GUI / builder for tag-definition `.m` file.
- Ingest provenance fields inside `.mat` outputs.
- Byte-offset tail-reading for huge append-only CSVs.

</user_constraints>

---

## Project Constraints (from CLAUDE.md)

- **Pure MATLAB; no external MATLAB toolboxes.** No Python, no npm, no external deps in ingestion path.
- **Runtime parity: MATLAB R2020b+ AND GNU Octave 7+.** Every code path in the pipeline must execute correctly on both. This is the single hardest constraint because Octave's builtin CSV support diverges sharply from MATLAB's (see §Standard Stack).
- **Backward compatibility.** Existing dashboard scripts and serialized dashboards continue to work. `SensorTag.load()` contract at [libs/SensorThreshold/SensorTag.m:176](libs/SensorThreshold/SensorTag.m:176) is FROZEN — pipeline output must satisfy it unchanged.
- **Tag base class ≤ 6 abstract methods.** D-05's `RawSource` lives on `SensorTag`/`StateTag` only; this is aligned with Pitfall 1.
- **MEX absence must be tolerated.** MEX binaries may be absent on a fresh Octave clone. Pipeline does not depend on MEX kernels — it's a pure-MATLAB/Octave text-processing layer.
- **Tests dual-style.** Both `tests/suite/Test*.m` (class-based) and `tests/test_*.m` (function-based) patterns are established. New tests must be runnable under both MATLAB `runtests` and Octave's flat-function runner.
- **Style: MISS_HIT enforced.** Line length ≤ 160, tab width 4, function length ≤ 520, cyclomatic ≤ 80, nesting ≤ 5.
- **`arguments` blocks are Octave-unsupported** — use the codebase's `varargin` + `splitArgs_` NV-pair pattern.

---

<phase_requirements>
## Phase Requirements

This phase has **no mapped REQ-IDs** in the roadmap (v2.0 closed at Phase 1011 MIGRATE-03). Scope is authoritatively captured by CONTEXT.md decisions D-01..D-19. The table below maps each decision to the research finding that enables its implementation.

| ID | Description | Research Support |
|----|-------------|------------------|
| D-01 | One shared delimited-text parser covering `.csv`/`.txt`/`.dat` with delimiter sniffing | §Standard Stack "Delimited-text parser" + §Architecture Patterns "Pattern 1: Dual-runtime parser" |
| D-02 | No public parser-registration API; architect for future extension | §Architecture Patterns "Pattern 3: Hidden parser dispatch" |
| D-03 | Synthetic in-test fixtures (CSV/TXT/DAT) | §Architecture Patterns "Pattern 6: Fixture factory" + §Common Pitfalls "Pitfall 4: mtime resolution flakiness" |
| D-04 | Wide + tall shape dispatch | §Architecture Patterns "Pattern 2: Shape dispatch by column presence" |
| D-05 | `RawSource` struct on `SensorTag`/`StateTag` only | §Code Examples "Example 1" + §Architecture Patterns "Pattern 4: splitArgs_ integration" |
| D-06 | `column` required for wide, optional for tall; missing-column = per-tag error | §Code Examples "Example 2: shape dispatch" |
| D-07 | Internal file-read de-dup via cache keyed by absolute path | §Architecture Patterns "Pattern 5: Per-run file cache" |
| D-08 | Silent skip for tags without `RawSource` | §Architecture Patterns "Pattern 7: Tag enumeration via TagRegistry.find" |
| D-09 | Output = `data.<KeyName> = struct('x',X,'y',Y)` | §Code Examples "Example 3: output writer" matches [libs/SensorThreshold/SensorTag.m:176](libs/SensorThreshold/SensorTag.m:176) |
| D-10 | Strict one-tag-per-`.mat`; file = `<OutputDir>/<tagKey>.mat` | §Code Examples "Example 3" |
| D-11 | `StateTag` output reuses `{x,y}` shape; numeric or cellstr `y` | §Code Examples "Example 3" + StateTag already supports both |
| D-12 | `BatchTagPipeline` + `LiveTagPipeline` with shared private helper | §Standard Stack layout + §Architecture Patterns "Pattern 8: Shared helper" |
| D-13 | Live mode = `modTime + lastIndex` on raw text | §Code Examples "Example 4: LiveTagPipeline tick loop" (adapted from [libs/EventDetection/MatFileDataSource.m](libs/EventDetection/MatFileDataSource.m)) |
| D-14 | `LiveTagPipeline` does NOT subclass `LiveEventPipeline` | §Architecture Patterns "Pattern 9: Borrowed timer skeleton" |
| D-15 | `OutputDir` constructor parameter; auto-mkdir | §Architecture Patterns "Pattern 10: OutputDir lifecycle" |
| D-16/17 | Raw-only — MonitorTag/CompositeTag not materialized | §Architecture Patterns "Pattern 7" filter predicate preserves MONITOR-03 |
| D-18 | Per-tag try/catch + end-of-run `TagPipeline:ingestFailed` | §Architecture Patterns "Pattern 11: Fail-soft-yell-at-end" |
| D-19 | Specific `TagPipeline:*` error IDs for enumerated failure modes | §Common Pitfalls table + §Open Questions Q4 |

</phase_requirements>

---

## Summary

The pipeline is a **pure-MATLAB text ingestion layer** that bridges arbitrary delimited raw files to the Tag-model `.mat` contract already shipped by Phases 1004-1005. The central engineering problem is **not** the pipeline shape (which is idiomatic: iterate registry → parse file → write mat-file) but **Octave parity of the parser itself**. MATLAB's `readtable` / `detectImportOptions` / `readmatrix` are absent from Octave (confirmed against Octave 11 official docs); this forces a hand-rolled parser built on the intersection of what both runtimes support: `fopen` + `fgetl` for header sniffing, then `textscan` for bulk-parse. Every other architectural decision flows from that constraint.

The **second architectural risk** is live-mode incremental ingest. `MatFileDataSource`'s `modTime + lastIndex` pattern is proven for `.mat` files but text files have different characteristics: line-count-based indexing (not array-index-based), mid-write truncation on HFS+ at 1-second mtime resolution (test flakiness surface), and row-granularity that makes byte-tail-reading tempting but out-of-scope per CONTEXT.md's deferrals. The pattern transfers cleanly if we treat `lastIndex_` as "last data-row index after header skip."

The **third risk** is decision ordering during wave planning. `RawSource` property on SensorTag and StateTag touches Tag-family code that was deliberately locked by Phases 1004-1005 (Pitfall 5 file-budget discipline). Additive-only — the classes already have a `splitArgs_` NV-pair entry point ([libs/SensorThreshold/SensorTag.m:319](libs/SensorThreshold/SensorTag.m:319)) designed for exactly this extension. Expect one new NV key per class, one new property, minimal serialization delta to `toStruct`/`fromStruct`.

**Primary recommendation:** Pick a runtime-polyglot parser built on `textscan` + `fgetl`, cache parsed results per-run via a `containers.Map` keyed by absolute file path, and keep the parser private to `libs/SensorThreshold/private/` so `BatchTagPipeline` and `LiveTagPipeline` both call into it. Mirror `MatFileDataSource`'s state machine almost byte-for-byte in `LiveTagPipeline`, substituting "row count after header" for `numel(allX)`.

---

## Standard Stack

### Core (all built-in, Octave-safe)

| Building block | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| `textscan` | MATLAB R2020b+, Octave 7+ | Bulk-parse numeric data rows given a known delimiter and known column count | Only truly portable API. Explicit delimiter and headerlines control. Handles both whitespace-separated and comma-separated uniformly. |
| `fopen` / `fgetl` / `fclose` | All | Sniff the header line(s) and probe candidate delimiters line-by-line | Works identically on both runtimes. Low-level enough to avoid version drift. |
| `strsplit` | All | Split a header line on a candidate delimiter; count resulting fields for delimiter-sniff heuristic | Portable; present in Octave from 3.0 onward. |
| `save` / `load` (`-v7` or default) | All | Write and read `.mat` output files; `-append` semantics used by live pipeline | Existing codebase uses default (`-v7` via `save(path, varName)`). `MatFileDataSource` and `SensorTag.load` both use `builtin('load', path)`. |
| `dir()` + `info.datenum` | All | Stat a file's mtime for live-mode change detection | Exactly the pattern used by [libs/EventDetection/MatFileDataSource.m:41-46](libs/EventDetection/MatFileDataSource.m:41). |
| `timer` (MATLAB) / `timer` (Octave Instrument Control pkg NOT required — borrow `LiveEventPipeline` pattern) | All | Periodic tick for `LiveTagPipeline` | `LiveEventPipeline` uses `timer` with `ExecutionMode='fixedSpacing'`; proven portable. |
| `containers.Map` | All | Internal per-run file cache (D-07), registry-like structures | Already used extensively (`TagRegistry`, `MonitorTargets`). |

### Explicitly AVOIDED (MATLAB-only or problematic)

| Library | Why Rejected |
|---------|--------------|
| `readtable` / `readmatrix` / `readcell` | **Not present in Octave** (verified against [Octave 11 official docs](https://docs.octave.org/latest/Simple-File-I_002fO.html) — no mention of these functions). Using them breaks the dual-runtime invariant. |
| `detectImportOptions` / `delimitedTextImportOptions` | MATLAB-only; no Octave equivalent. |
| `csvread` / `dlmread` | Numeric-only in both runtimes. Fails on files with header strings — a documented pain point in Octave's own ecosystem that drove users to the Octave-Forge `io` package's `csv2cell`. |
| Octave-Forge `io` package (`csv2cell`) | Adds an external dependency; violates CLAUDE.md "pure MATLAB, no external deps" constraint. |
| `importdata` | Available in both but **unpredictable output shape** — returns struct vs matrix vs cell depending on content heuristics. Unsuitable for deterministic parsing. |
| `jsondecode` | N/A for this phase, but worth noting: project uses its own `DashboardSerializer.loadJSON` precisely because MATLAB/Octave JSON API shapes diverge. |

### Internal structure (no external libs — all bespoke)

| Module | Path (proposed) | Purpose |
|--------|-----------------|---------|
| `readRawDelimited_` | `libs/SensorThreshold/private/readRawDelimited_.m` | Core parser: takes a file path, returns `struct('headers', cellstr, 'data', matrix-or-cell-of-cols, 'delimiter', char, 'format', char)` |
| `sniffDelimiter_` | `libs/SensorThreshold/private/sniffDelimiter_.m` | Try each candidate delimiter, return the one producing consistent column counts on the first N lines |
| `detectHeader_` | `libs/SensorThreshold/private/detectHeader_.m` | Given file's first 2 lines + chosen delimiter, return `true` if row 1 is a header (non-numeric) and `false` otherwise |
| `selectTimeAndValue_` | `libs/SensorThreshold/private/selectTimeAndValue_.m` | Given parsed table + `RawSource.column`, return `(X, Y)` vectors after time-column resolution |
| `writeTagMat_` | `libs/SensorThreshold/private/writeTagMat_.m` | Atomic per-tag write of `data.<KeyName> = struct('x',X,'y',Y)` to `<OutputDir>/<tagKey>.mat`; live-mode append variant |
| `BatchTagPipeline` | `libs/SensorThreshold/BatchTagPipeline.m` | Orchestrator; enumerates `TagRegistry`, de-dups files, invokes the four private helpers per tag |
| `LiveTagPipeline` | `libs/SensorThreshold/LiveTagPipeline.m` | Timer-driven wrapper over the same private helpers; mirrors `MatFileDataSource` state machine per tag |

**Installation:** Nothing to install — pure additive MATLAB code. Path is already on the `install()` path list ([install.m:47-48](install.m:47)).

**Version verification:** N/A — no packages to pin. All builtins confirmed present on MATLAB R2020b+ (project floor) and Octave 7+ (project floor) via direct doc read. `textscan` has been stable since MATLAB R14 and Octave 3.0.

---

## Architecture Patterns

### Recommended Project Structure

```
libs/SensorThreshold/
├── SensorTag.m                     [EDIT] + RawSource_ property, NV-pair routing, toStruct/fromStruct delta
├── StateTag.m                      [EDIT] + RawSource property, parallel to SensorTag
├── BatchTagPipeline.m              [NEW] orchestrator for one-shot ingest
├── LiveTagPipeline.m               [NEW] timer-driven orchestrator
└── private/
    ├── readRawDelimited_.m         [NEW] the parser (public-to-module, private-to-lib)
    ├── sniffDelimiter_.m           [NEW] 4-candidate heuristic
    ├── detectHeader_.m             [NEW] header-row heuristic
    ├── selectTimeAndValue_.m       [NEW] column selection + wide/tall dispatch
    └── writeTagMat_.m              [NEW] save('-append') logic + atomic write

tests/suite/
├── TestRawDelimitedParser.m        [NEW] unit tests for readRawDelimited_/sniff/detect/select
├── TestBatchTagPipeline.m          [NEW] suite tests (class-based)
└── TestLiveTagPipeline.m           [NEW] suite tests with mtime-bump fixture

tests/
├── test_raw_delimited_parser.m     [NEW] flat-style mirror of suite
├── test_batch_tag_pipeline.m       [NEW] flat-style mirror
└── test_live_tag_pipeline.m        [NEW] flat-style mirror
```

**File-count budget:** 2 edits + 7 new source files + 3-6 new test files = **12-15 touched files**. If this overruns the v2.0-style ≤12 target (see §Common Pitfalls), the flat-function tests can be dropped first — `run_all_tests.m` auto-discovers suite classes without them.

### Pattern 1: Dual-runtime parser (the Octave constraint drives the whole design)

**What:** A single function `readRawDelimited_(path, varargin)` that uses only `fopen/fgetl/textscan/strsplit` — features present identically in both runtimes.

**When to use:** Every parse of a raw file goes through this function. Even wide files with one header scan are single-call — the function returns all columns, and the caller picks the one it wants.

**Example (skeleton):**
```matlab
function out = readRawDelimited_(path, varargin)
    %READRAWDELIMITED_ Pure-MATLAB/Octave delimited-text parser.
    %   out = readRawDelimited_(path) returns:
    %     out.headers   — 1xN cellstr of column names (or {} if headerless)
    %     out.data      — NxM numeric OR NxM cell for mixed-type columns
    %     out.delimiter — char, the delimiter that was sniffed
    %     out.hasHeader — logical
    %
    %   Errors:
    %     TagPipeline:fileNotReadable
    %     TagPipeline:delimiterAmbiguous
    %     TagPipeline:emptyFile

    if ~exist(path, 'file')
        error('TagPipeline:fileNotReadable', 'File not found: %s', path);
    end

    % Sniff delimiter on the first ~5 non-empty lines
    delim = sniffDelimiter_(path);

    % Open and skip header if present
    fid = fopen(path, 'r');
    if fid == -1
        error('TagPipeline:fileNotReadable', 'Cannot open: %s', path);
    end
    cleanup = onCleanup(@() fclose(fid));

    firstLine = fgetl(fid);
    if ~ischar(firstLine)
        error('TagPipeline:emptyFile', 'File is empty: %s', path);
    end
    secondLine = fgetl(fid);  % may be -1 if header-only
    hasHeader = detectHeader_(firstLine, secondLine, delim);

    headers = {};
    if hasHeader
        headers = strsplit(firstLine, delim);
    end

    % Reset to start; bulk-parse via textscan with correct header skip
    frewind(fid);
    nCols = numel(strsplit(firstLine, delim));
    fmtSpec = repmat('%f', 1, nCols);   % attempt numeric — fall back on error
    skipN = double(hasHeader);

    try
        C = textscan(fid, fmtSpec, 'Delimiter', delim, ...
            'HeaderLines', skipN, 'CollectOutput', true);
        data = C{1};
    catch
        % Fallback: read as strings (mixed-type / cellstr Y for StateTag)
        frewind(fid);
        fmtSpec = repmat('%s', 1, nCols);
        C = textscan(fid, fmtSpec, 'Delimiter', delim, ...
            'HeaderLines', skipN, 'CollectOutput', true);
        data = C{1};
    end

    out = struct('headers', {headers}, 'data', data, ...
                 'delimiter', delim, 'hasHeader', hasHeader);
end
```

**Source:** Pattern synthesized from [Octave textscan docs](https://docs.octave.org/latest/Simple-File-I_002fO.html) (`Delimiter`, `HeaderLines`, `CollectOutput` all documented) cross-verified against MATLAB's [textscan documentation](https://www.mathworks.com/help/matlab/ref/textscan.html) — intersection of both APIs.

### Pattern 2: Shape dispatch by column presence (D-04 + D-06)

**What:** The `RawSource.column` field drives wide-vs-tall disambiguation. This is cleaner than guessing by column count.

**When to use:** After `readRawDelimited_` returns, before slicing columns.

**Logic:**
```matlab
function [x, y] = selectTimeAndValue_(parsed, rawSource)
    nCols = size(parsed.data, 2);
    if nCols == 2 && (~isfield(rawSource, 'column') || isempty(rawSource.column))
        % Tall: col 1 = time, col 2 = value
        x = parsed.data(:, 1);
        y = parsed.data(:, 2);
        return;
    end
    if nCols < 2
        error('TagPipeline:insufficientColumns', 'Need ≥2 columns, got %d', nCols);
    end
    if ~isfield(rawSource, 'column') || isempty(rawSource.column)
        error('TagPipeline:missingColumn', ...
            'Wide file (%d cols) requires RawSource.column', nCols);
    end
    if isempty(parsed.headers)
        error('TagPipeline:noHeadersForNamedColumn', ...
            'Cannot resolve column ''%s'' — file has no header row', rawSource.column);
    end
    colIdx = find(strcmpi(parsed.headers, rawSource.column), 1);
    if isempty(colIdx)
        error('TagPipeline:missingColumn', ...
            'Column ''%s'' not found. Available: %s', ...
            rawSource.column, strjoin(parsed.headers, ', '));
    end
    timeIdx = findTimeColumn_(parsed.headers);
    x = parsed.data(:, timeIdx);
    y = parsed.data(:, colIdx);
end
```

### Pattern 3: Hidden parser dispatch (D-02 forward-compat)

**What:** Even though the public API has no `registerParser`, the internal dispatch table must look like a map so a future phase can expose it.

**Canonical shape:** `readRawDelimited_` is the _default_ parser. It lives behind a tiny dispatch:

```matlab
% Inside BatchTagPipeline / LiveTagPipeline
function parsed = dispatchParse_(obj, path, rawSource)
    [~, ~, ext] = fileparts(path);
    ext = lower(ext);
    % Phase 1012: all three extensions → same parser
    switch ext
        case {'.csv', '.txt', '.dat'}
            parsed = readRawDelimited_(path);
        otherwise
            error('TagPipeline:unknownExtension', ...
                'Unsupported extension ''%s''. Supported: .csv .txt .dat', ext);
    end
end
```

Future `registerParser(ext, fn)` just adds cases to that switch (or converts to a `containers.Map` keyed by ext).

### Pattern 4: `splitArgs_` integration for `RawSource` NV-pair (D-05)

**SensorTag edit** (follows existing sensor-extras convention at [libs/SensorThreshold/SensorTag.m:27-31](libs/SensorThreshold/SensorTag.m:27)):

```matlab
% In properties (Access = private):
RawSource_ = struct()    % struct: {file, column, format}

% In splitArgs_ (classify RawSource alongside ID/Source/MatFile/KeyName):
sensorKeys = {'ID', 'Source', 'MatFile', 'KeyName', 'RawSource'};

% In constructor body (after the ID/Source/MatFile/KeyName switch):
case 'RawSource', obj.RawSource_ = validateRawSource_(sensorArgs{i+1});

% New public getter (match DataStore read-only dependent pattern):
properties (Dependent)
    RawSource   % read-only view of RawSource_
end
methods
    function r = get.RawSource(obj), r = obj.RawSource_; end
end

% In toStruct (under sensor-extras block):
if ~isempty(fieldnames(obj.RawSource_))
    sensorExtras.rawsource = obj.RawSource_;
end

% In fromStruct sensorKeyMap row additions:
'rawsource', 'RawSource'
```

**StateTag edit** is structurally parallel, but StateTag's `splitArgs_` lives in that class directly ([libs/SensorThreshold/StateTag.m:222](libs/SensorThreshold/StateTag.m:222)) — just add `'RawSource'` alongside the Tag universals switch.

**Validator** (`validateRawSource_`, Static Access=private helper on each class):
- Must be a struct
- Must have a non-empty `file` field (char)
- `column` and `format` are optional; default to empty string
- Unknown fields → warning (future-compat) or ignored

### Pattern 5: Per-run file cache (D-07)

**What:** Inside `BatchTagPipeline.run()` (or each tick of `LiveTagPipeline`), maintain a cache of parsed files so N tags sharing one CSV cause one parse.

**Shape:**
```matlab
% Inside BatchTagPipeline (persistent for scope of one run() call)
properties (Access = private)
    fileCache_   % containers.Map: absolute path -> parsed struct
end

function run(obj)
    obj.fileCache_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
    try
        % iterate tags, each calling obj.parseOrCache_(path) ...
    ...
    end
    delete(obj.fileCache_);  % ensure cache discarded post-run
end

function parsed = parseOrCache_(obj, path)
    abspath = obj.absPath_(path);
    if obj.fileCache_.isKey(abspath)
        parsed = obj.fileCache_(abspath);
        return;
    end
    parsed = readRawDelimited_(abspath);
    obj.fileCache_(abspath) = parsed;
end
```

**Cache lifetime:**
- **Batch:** one `run()` call. Cache allocated at top, discarded at end.
- **Live:** one `onTick()` callback. Cache allocated per tick (because a raw file may have grown between ticks). Discarded at end of tick. `lastIndex_` state is stored on the tag record, separate from the parse cache.

### Pattern 6: Fixture factory (D-03)

**What:** A test-only helper that writes synthetic CSV/TXT/DAT fixtures into a `tempname()` directory and registers teardown for cleanup.

**Why explicit:** `tempname()` is portable between MATLAB and Octave; filesystem cleanup is straightforward. But mtime bumping between writes in live-mode tests requires a `pause(1.1)` to cross 1-second filesystem resolution boundaries (see Pitfall 4 below).

**Example:**
```matlab
function [dir, files] = makeRawFixtures_(testCase)
    dir = tempname();
    mkdir(dir);
    testCase.addTeardown(@() rmdir(dir, 's'));

    % Wide CSV
    files.wideCsv = fullfile(dir, 'logger.csv');
    fid = fopen(files.wideCsv, 'w');
    fprintf(fid, 'time,pressure_a,pressure_b,temperature\n');
    fprintf(fid, '%f,%f,%f,%f\n', [1 10 20 30; 2 11 21 31; 3 12 22 32]');
    fclose(fid);

    % Tall TXT (whitespace-separated)
    files.tallTxt = fullfile(dir, 'level.txt');
    fid = fopen(files.tallTxt, 'w');
    fprintf(fid, '1 100\n2 101\n3 102\n');
    fclose(fid);

    % Tab-separated DAT
    files.tallDat = fullfile(dir, 'flow.dat');
    fid = fopen(files.tallDat, 'w');
    fprintf(fid, 'time\tflow_rate\n');
    fprintf(fid, '1\t3.14\n2\t3.15\n3\t3.16\n');
    fclose(fid);
end
```

### Pattern 7: Tag enumeration via `TagRegistry.find` (D-08 silent skip)

```matlab
function tags = eligibleTags_(~)
    predicate = @(t) isIngestable_(t);
    tags = TagRegistry.find(predicate);
end

function tf = isIngestable_(t)
    % Silent skip for MonitorTag, CompositeTag, or any tag with empty RawSource
    if ~isa(t, 'SensorTag') && ~isa(t, 'StateTag')
        tf = false;
        return;
    end
    rs = t.RawSource;
    tf = isstruct(rs) && isfield(rs, 'file') && ~isempty(rs.file);
end
```

**Note:** `TagRegistry.find(pred)` already exists ([libs/SensorThreshold/TagRegistry.m:118](libs/SensorThreshold/TagRegistry.m:118)) — no registry API change needed.

### Pattern 8: Shared private helper (D-12)

Both `BatchTagPipeline.run()` and `LiveTagPipeline.onTick_()` iterate tags and call:
```matlab
[x, y] = ingestTag_(obj, tag)   % reads raw file (via cache), selects columns
writeTagMat_(obj.OutputDir, tag, x, y, opts)  % save or append
```

`ingestTag_` and `writeTagMat_` are where the logic diverges slightly:
- Batch: `writeTagMat_` always writes a fresh `data.<KeyName>` field.
- Live: `writeTagMat_` uses `save('-append', ...)` but because `data` is the variable and `save('-append')` overwrites same-named variables, the actual live-append path must **load, concatenate, save** to avoid data loss on repeat ticks.

### Pattern 9: Borrowed timer skeleton (D-14)

`LiveTagPipeline` copies the skeleton from [libs/EventDetection/LiveEventPipeline.m:73-99](libs/EventDetection/LiveEventPipeline.m:73) — about 30 lines — without subclassing:

```matlab
properties
    Interval = 15    % seconds
    Status   = 'stopped'
    OutputDir
    ErrorFcn = []
end
properties (Access = private)
    timer_
    tagState_   % containers.Map: tagKey -> struct('lastModTime', d, 'lastIndex', n)
end

function start(obj)
    if strcmp(obj.Status, 'running'); return; end
    obj.Status = 'running';
    obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
        'Period', obj.Interval, ...
        'TimerFcn', @(~,~) obj.onTick_(), ...
        'ErrorFcn', @(~,~) obj.onTimerError_());
    start(obj.timer_);
    fprintf('[TAG-PIPELINE] Started (interval=%ds)\n', obj.Interval);
end

function stop(obj)
    % Copy from LiveEventPipeline.stop at :84-100 — isvalid guard, delete, set Status
end
```

**Status tri-state:** `'stopped'` | `'running'` | `'error'` — matches `LiveEventPipeline` exactly.

### Pattern 10: OutputDir lifecycle (D-15)

```matlab
function obj = BatchTagPipeline(varargin)
    defaults.OutputDir = '';
    opts = parseOpts(defaults, varargin);
    if isempty(opts.OutputDir)
        error('TagPipeline:invalidOutputDir', 'OutputDir is required');
    end
    if ~exist(opts.OutputDir, 'dir')
        [ok, msg] = mkdir(opts.OutputDir);
        if ~ok
            error('TagPipeline:cannotCreateOutputDir', ...
                'Cannot create %s: %s', opts.OutputDir, msg);
        end
    end
    obj.OutputDir = opts.OutputDir;
end
```

**Portability note:** `mkdir` is recursive by default on both MATLAB and Octave since early versions; no `mkdir -p` equivalent needed.

### Pattern 11: Fail-soft-yell-at-end (D-18)

```matlab
function report = run(obj)
    tags = obj.eligibleTags_();
    report = struct('succeeded', {{}}, 'failed', struct([]));
    for i = 1:numel(tags)
        t = tags{i};
        try
            [x, y] = obj.ingestTag_(t);
            writeTagMat_(obj.OutputDir, t, x, y);
            report.succeeded{end+1} = t.Key;
        catch ex
            fprintf(2, '[TAG-PIPELINE] %s failed: %s\n', t.Key, ex.message);
            entry = struct('key', t.Key, ...
                'file', t.RawSource.file, ...
                'errorId', ex.identifier, ...
                'message', ex.message);
            if isempty(report.failed)
                report.failed = entry;
            else
                report.failed(end+1) = entry;
            end
        end
    end
    obj.LastReport = report;
    if ~isempty(report.failed)
        error('TagPipeline:ingestFailed', ...
            '%d tag(s) failed during ingest (successful: %d). See LastReport.', ...
            numel(report.failed), numel(report.succeeded));
    end
end
```

### Anti-Patterns to Avoid

- **Calling `readtable` or `readmatrix` anywhere in the pipeline** — Octave-breaking. Verified against Octave 11 docs: neither function exists.
- **Silent swallowing of per-tag errors** — D-18 is explicit: fail soft per-tag but throw at end of run so CI catches failures. No "log and continue" without the end-of-run throw.
- **Materializing a MonitorTag or CompositeTag `.mat` from this pipeline** — D-16 is explicit; preserves MONITOR-03 lazy-by-default. The eligibility predicate (Pattern 7) guards this.
- **Byte-offset tail-reading for live mode** — CONTEXT.md defers explicitly. Re-parse on each tick, slice by row index.
- **A `Tag`-base RawSource property** — CONTEXT.md D-05 explicit: Tag base stays untouched, property is per-subclass on SensorTag and StateTag only. Preserves Pitfall 1 file-budget.
- **A `SensorTag.pipelineVersion` or similar "refresh monitor" lever** — ghost of Pitfall 2. Monitors remain lazy, no materialization, no freshness stamps.
- **Multi-tag output files** — D-10 is strict. One tag per file; live-mode per-tag appends never collide.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Number-string parsing | Custom `str2double` loop | `textscan('%f', ...)` | Handles scientific notation, NaN, locale issues, faster than MATLAB-level loops. |
| Delimiter detection | Ad-hoc regex | `strsplit` + count-cardinality heuristic | `strsplit` is the portable, well-understood primitive. |
| File existence check | Multi-step `exist` wrapper | `exist(path, 'file')` — the pattern already used by [libs/SensorThreshold/SensorTag.m:191](libs/SensorThreshold/SensorTag.m:191) | Consistent with codebase convention. |
| `.mat` atomic write | Temp-file rename dance | `save()` directly (v7 format is single-write in both runtimes) | `EventStore.save()` uses a documented temp-file-rename — see [libs/EventDetection/EventStore.m]. Mirror if atomicity desired, but simpler direct `save` is acceptable for per-tag files (one-tag-per-file means corruption is localized). |
| mtime detection | Manual `stat` call | `info = dir(path); info.datenum` | Proven pattern from `MatFileDataSource:41-46`. |
| Timer ergonomics | Custom scheduling | `timer` builtin with `'fixedSpacing'` | Proven via `LiveEventPipeline`. |
| NV-pair parsing | Custom loop | `splitArgs_` (existing on each class) + `parseOpts` ([libs/FastSense/private/parseOpts.m](libs/FastSense/private/parseOpts.m)) | Codebase convention; two established patterns already. |
| Fixture cleanup | Manual `delete()` post-test | `testCase.addTeardown(@() rmdir(dir, 's'))` | Pattern at [tests/suite/TestSensorTag.m:244](tests/suite/TestSensorTag.m:244). Guarantees cleanup even on assertion failure. |
| Struct validation | Custom `isfield` wrapper chain | Inline `isstruct/isfield/~isempty` checks | No `validateattributes` for structs is truly portable; simple checks match the codebase style. |

**Key insight:** Every piece of this pipeline has a precedent in the existing codebase. `MatFileDataSource` is the direct structural template for live mode; `SensorTag.splitArgs_` is the template for the `RawSource` NV-pair; `LiveEventPipeline` is the timer template; `TagRegistry.find` is the tag-discovery primitive. This is integration work, not greenfield engineering.

---

## Runtime State Inventory

Not applicable — this phase is greenfield code addition, not a rename/refactor/migration. There is no existing "tag pipeline" whose stored state, live-service config, or OS-registered tasks need to be audited. Synthetic in-test fixtures (D-03) are the only data artifacts, and those live in `tempname()` directories with test-scoped teardown.

---

## Common Pitfalls

### Pitfall 1: `readtable` / `readmatrix` sneaking into the implementation

**What goes wrong:** A developer sees MATLAB's clean `T = readtable(path)` API and reaches for it without remembering Octave parity.

**Why it happens:** `readtable` is the "obvious" MATLAB answer; it has delimiter auto-detection, header detection, column typing — all the pieces this pipeline needs.

**How to avoid:** Test matrix gates every PR; `textscan`-based implementation. A `grep -rn "readtable\|readmatrix\|readcell\|detectImportOptions" libs/SensorThreshold/` test enforces zero usage in the pipeline path.

**Warning signs:** Any commit introducing `readtable` into `libs/SensorThreshold/*.m` or its `private/`.

### Pitfall 2: Silent data loss in live-mode append

**What goes wrong:** A naive `save(path, '-append', 'data')` call **overwrites** the existing `data` variable in the file, not merges it. Live mode ticks each lose all prior samples.

**Why it happens:** `-append` in MATLAB/Octave means "add this variable alongside other variables in the file" not "concatenate this variable's contents with the existing one." Confirmed by [MATLAB save docs](https://www.mathworks.com/help/matlab/ref/save.html) and [Octave save docs](https://docs.octave.org/latest/Simple-File-I_002fO.html).

**How to avoid:** Live-mode append path is explicit:
```matlab
if exist(outPath, 'file')
    prior = load(outPath);
    oldStruct = prior.data.(tag.Key);  % struct with .x, .y
    newX = [oldStruct.x(:); x(:)];
    newY = [oldStruct.y(:); y(:)];
else
    newX = x;
    newY = y;
end
data = struct();
data.(tag.Key) = struct('x', newX, 'y', newY);  %#ok<STRNU>
save(outPath, 'data');   % no -append needed; one tag per file
```

**Warning signs:** A `save(..., '-append', 'data')` pattern in `writeTagMat_` or any live-mode write path; a test that reads back the mat-file after two ticks and finds only the last tick's rows.

### Pitfall 3: Incorrect `lastIndex_` semantics for text vs mat

**What goes wrong:** `MatFileDataSource` uses `lastIndex_ = numel(allX)` where `allX` is a MATLAB array loaded from a mat-file. For a CSV, the analog is "number of data rows after header skip." A developer copies the pattern literally and uses `size(parsed.data, 1)` — which is correct but needs care because re-parsing a growing CSV re-parses the header too; the header skip must be consistent across ticks.

**How to avoid:** `lastIndex_` is always the count of **data rows** (not file rows). The header is always skipped on each re-parse. Test: grow a CSV from 3 to 5 rows over two ticks, verify second tick yields exactly 2 new rows.

**Warning signs:** Tests passing on first tick but failing on second; off-by-one in the delta slice.

### Pitfall 4: Filesystem mtime resolution flakiness

**What goes wrong:** HFS+ (pre-APFS macOS) has **1-second** mtime resolution. Tests that write a file, immediately overwrite it, and expect `MatFileDataSource` to detect the change fail because both writes fall into the same mtime second. APFS and ext4 have nanosecond resolution; NTFS has 100ns; Windows FAT32 has 2-second resolution.

**Why it matters:** `MatFileDataSource` tests work around this with `pause(1.1)` ([tests/suite/TestMatFileDataSource.m:38](tests/suite/TestMatFileDataSource.m:38)). Same requirement for `LiveTagPipeline` tests.

**How to avoid:** Every test that bumps an mtime between writes must `pause(1.1)` before the second write. Alternatively, use `touch` with an explicit future mtime — but that's not portable between MATLAB/Octave.

**Warning signs:** Test flakiness on macOS-HFS+ CI runners; intermittent failures that don't reproduce locally on APFS Macs.

### Pitfall 5: Delimiter-sniffing ambiguity in multi-line files

**What goes wrong:** A file where the first line looks like `time pressure_a pressure_b` (space-separated header) but data rows are `1.0, 10.2, 20.4` (comma-separated, perhaps with a header typo). The sniff returns space; parsing the second line with space delimiter produces 1 column not 3.

**How to avoid:** Sniff on at least **the first 5 non-empty lines** and require **consistent column count** across all candidates. If no single delimiter produces consistency, raise `TagPipeline:delimiterAmbiguous`. If the file has only 1 line, fall back to extension hint or raise.

**Warning signs:** Sniff always returning the same "default" (e.g., always `,`); tests that pass on single-file fixtures but fail on mixed-delimiter fixtures.

### Pitfall 6: Time-column resolution drift

**What goes wrong:** "First column is time" is the obvious convention, but some logger exports put time in column 2 (column 1 = row index). With a header like `id, time, pressure_a`, the pipeline quietly uses the `id` column as `X`.

**How to avoid:** Time column is detected by header name first (case-insensitive match against `{'time', 't', 'timestamp', 'datenum', 'datetime'}`), then falls back to column 1. Document this; add a unit test for each alternative name.

**Warning signs:** A tag whose produced `X` values don't look like timestamps (check in a test by verifying monotonicity or `X(end) > X(1)`).

### Pitfall 7: `containers.Map` key collisions across runs

**What goes wrong:** `fileCache_` keyed by relative path works on the first run; on a second run from a different working directory, the cache "hits" but the cached data is stale.

**How to avoid:** Always canonicalize via `which` or absolute-path resolution before using the key:
```matlab
function ap = absPath_(~, path)
    if java.io.File(path).isAbsolute()
        ap = path;
    else
        ap = fullfile(pwd, path);
    end
    % Octave-safe: use fileattrib('resolve') or manually normalize
end
```

For Octave 7+, `java.io.File` works in MATLAB but not all Octave builds. Portable alternative: start with `fileparts(which(path))` fallback to `fullfile(pwd, path)`.

**Warning signs:** Second test run in a session reading stale data.

### Pitfall 8: Live-mode stop-during-tick race

**What goes wrong:** A user calls `pipeline.stop()` while `onTick_` is mid-execution. If `stop` deletes the timer and `onTick_` is still running on it, errors cascade.

**How to avoid:** Copy the `LiveEventPipeline.stop()` pattern exactly ([libs/EventDetection/LiveEventPipeline.m:84-100](libs/EventDetection/LiveEventPipeline.m:84)) — guard with `isvalid(obj.timer_)`, wrap `stop/delete` in try/catch. MATLAB timers are not re-entrant by default, so in-tick stop() typically enqueues after the tick completes. Still, document the behavior: "stop() completes the current tick then halts."

**Warning signs:** Tests that call `start/stop/start/stop` in quick succession failing intermittently.

### Pitfall 9: File-count budget overrun (v2.0 Pitfall 5 discipline)

**What goes wrong:** Naive plan has 2 edits + 7 new source + 3 suite tests + 3 flat tests = 15 files. Exceeds the v2.0 ≤12 convention.

**How to avoid (options):**
- Drop flat-function test mirrors (`run_all_tests.m` auto-discovers suite classes; flat mirrors are redundant for Octave as long as the suite classes work under `matlab.unittest` on both runtimes — verified by existing project tests).
- Collapse small private helpers: `sniffDelimiter_` + `detectHeader_` into `readRawDelimited_.m` as nested/local functions rather than separate files.

**Recommended budget:** 2 edits + 5-6 new source files (merging small helpers) + 3 new suite tests = **10-11 touched files**. Fits comfortably.

### Pitfall 10: Tag eligibility predicate filter drift

**What goes wrong:** A later phase adds `MonitorTag.RawSource` (violating D-05 retroactively) and the predicate at Pattern 7 picks it up, materializing derived data to disk. This is exactly Pitfall 2 (premature MonitorTag persistence) creeping in.

**How to avoid:** The predicate uses **positive isa checks** (`isa(t, 'SensorTag') || isa(t, 'StateTag')`), not `~isa(t, 'MonitorTag')`. Adding `CompositeTag.RawSource` in the future requires an explicit new branch — the guard is explicit.

**Warning signs:** A test or code change that adds `'|| isa(t, ''MonitorTag'')'` to the eligibility predicate.

### Pitfall 11: Octave `containers.Map` default value semantics

**What goes wrong:** `map('nonexistent_key')` throws in MATLAB but historically returned empty in some Octave versions. Tests may pass on one and fail on the other.

**How to avoid:** Always guard with `isKey` before access. The existing codebase (TagRegistry, LiveEventPipeline) uses this pattern consistently.

**Warning signs:** `KeyError` or unexpected `[]` return when dereferencing a missing cache key.

### Pitfall 12: Empty-file and header-only edge cases

**What goes wrong:** A logger restarted mid-day produces a file with just a header, no data rows. `textscan` returns empty columns, the per-tag ingest quietly writes `data.<key> = struct('x', [], 'y', [])`, and the `SensorTag.load` downstream call succeeds but produces a blank plot.

**How to avoid:** After parse, check `size(parsed.data, 1) == 0`. Raise `TagPipeline:emptyFile` (header-only counts as empty). End-of-run summary includes file path + line count for diagnosis.

**Warning signs:** Dashboards rendering with empty time series after a pipeline run completes without error.

---

## Code Examples

Verified idioms synthesized from codebase patterns and cross-runtime docs.

### Example 1: `RawSource` NV-pair wiring in SensorTag constructor (D-05)

Minimal delta to [libs/SensorThreshold/SensorTag.m](libs/SensorThreshold/SensorTag.m):

```matlab
% Add to properties (Access = private):
RawSource_ = struct()

% Add to Dependent properties:
RawSource   % read-only view of RawSource_

% Add get accessor:
function r = get.RawSource(obj)
    r = obj.RawSource_;
end

% splitArgs_: add 'RawSource' to sensorKeys list at line 323:
sensorKeys = {'ID', 'Source', 'MatFile', 'KeyName', 'RawSource'};

% Constructor body: add case to switch at lines 59-65:
case 'RawSource'
    obj.RawSource_ = SensorTag.validateRawSource_(sensorArgs{i+1});

% Static private method:
function rs = validateRawSource_(rs)
    if ~isstruct(rs)
        error('SensorTag:invalidRawSource', ...
            'RawSource must be a struct with fields file/column/format');
    end
    if ~isfield(rs, 'file') || isempty(rs.file) || ~ischar(rs.file)
        error('SensorTag:invalidRawSource', ...
            'RawSource.file must be a non-empty char');
    end
    if ~isfield(rs, 'column'), rs.column = ''; end
    if ~isfield(rs, 'format'), rs.format = ''; end
end

% toStruct: add to sensorExtras block (around line 166):
if ~isempty(fieldnames(obj.RawSource_))
    sensorExtras.rawsource = obj.RawSource_;
end

% fromStruct: add to sensorKeyMap at line 295:
sensorKeyMap = {'id', 'ID'; 'source', 'Source'; ...
                'matfile', 'MatFile'; 'keyname', 'KeyName'; ...
                'rawsource', 'RawSource'};
```

### Example 2: Wide-vs-tall dispatch (D-04, D-06)

```matlab
function [x, y] = selectTimeAndValue_(parsed, rawSource)
    nCols = size(parsed.data, 2);

    % Tall (2 cols, no column name provided)
    if nCols == 2 && (~isfield(rawSource, 'column') || isempty(rawSource.column))
        x = parsed.data(:, 1);
        y = parsed.data(:, 2);
        return;
    end

    % Wide requires a column name
    if ~isfield(rawSource, 'column') || isempty(rawSource.column)
        error('TagPipeline:missingColumn', ...
            'Wide raw file (%d cols) requires RawSource.column', nCols);
    end
    if isempty(parsed.headers)
        error('TagPipeline:noHeadersForNamedColumn', ...
            'Cannot resolve column ''%s'' — file has no header row', ...
            rawSource.column);
    end

    % Locate the requested value column (case-insensitive)
    vIdx = find(strcmpi(parsed.headers, rawSource.column), 1);
    if isempty(vIdx)
        error('TagPipeline:missingColumn', ...
            'Column ''%s'' not found. Available: %s', ...
            rawSource.column, strjoin(parsed.headers, ', '));
    end

    % Locate the time column: match by name first, else column 1
    timeNames = {'time', 't', 'timestamp', 'datenum', 'datetime'};
    tIdx = [];
    for k = 1:numel(timeNames)
        m = find(strcmpi(parsed.headers, timeNames{k}), 1);
        if ~isempty(m)
            tIdx = m;
            break;
        end
    end
    if isempty(tIdx), tIdx = 1; end

    x = parsed.data(:, tIdx);
    y = parsed.data(:, vIdx);
end
```

### Example 3: Per-tag `.mat` writer (D-09, D-10, D-11)

```matlab
function writeTagMat_(outputDir, tag, x, y, mode)
    %WRITETAGMAT_ Write per-tag .mat file matching SensorTag.load contract.
    %   mode: 'overwrite' (batch) or 'append' (live).
    %
    %   File layout: data.<tag.Key> = struct('x', X, 'y', Y)
    %   Load contract: SensorTag.load reads data.<KeyName>.x / .y

    if nargin < 5, mode = 'overwrite'; end

    outPath = fullfile(outputDir, [char(tag.Key) '.mat']);

    switch mode
        case 'overwrite'
            data = struct();
            data.(char(tag.Key)) = struct('x', x, 'y', y); %#ok<STRNU>
            save(outPath, 'data');
        case 'append'
            if exist(outPath, 'file')
                prior = load(outPath);
                if isfield(prior, 'data') && isfield(prior.data, tag.Key)
                    old = prior.data.(tag.Key);
                    if isfield(old, 'x') && isfield(old, 'y')
                        x = [old.x(:); x(:)];
                        y = [old.y(:); y(:)];
                    end
                end
            end
            data = struct();
            data.(char(tag.Key)) = struct('x', x, 'y', y); %#ok<STRNU>
            save(outPath, 'data');
        otherwise
            error('TagPipeline:invalidWriteMode', ...
                'Unknown write mode ''%s''', mode);
    end
end
```

**Note on `y` for StateTag:** if `y` is cellstr, `save` handles it via v7 mat format natively; `load` returns it as a cell. No special handling needed here — the cellstr-collapse defense in `StateTag.toStruct` doesn't apply because we're saving a struct field, not passing through MATLAB's `struct(...)` constructor.

### Example 4: `LiveTagPipeline` tick loop (D-13)

Adapted from [libs/EventDetection/MatFileDataSource.m:34-79](libs/EventDetection/MatFileDataSource.m:34):

```matlab
function onTick_(obj)
    try
        tags = obj.eligibleTags_();
        tickCache = containers.Map('KeyType', 'char', 'ValueType', 'any');

        for i = 1:numel(tags)
            t = tags{i};
            key = char(t.Key);
            rs = t.RawSource;
            abspath = obj.absPath_(rs.file);

            % Ensure per-tag state record exists
            if ~obj.tagState_.isKey(key)
                obj.tagState_(key) = struct('lastModTime', 0, 'lastIndex', 0);
            end
            state = obj.tagState_(key);

            % Stat the file; skip if unchanged
            if ~exist(abspath, 'file')
                continue;
            end
            info = dir(abspath);
            if info.datenum <= state.lastModTime
                continue;
            end

            % Parse (cached per tick to de-dup across tags on same file)
            if tickCache.isKey(abspath)
                parsed = tickCache(abspath);
            else
                try
                    parsed = readRawDelimited_(abspath);
                catch ex
                    fprintf(2, '[TAG-PIPELINE] %s parse failed: %s\n', ...
                        key, ex.message);
                    continue;
                end
                tickCache(abspath) = parsed;
            end

            try
                [x, y] = selectTimeAndValue_(parsed, rs);
            catch ex
                fprintf(2, '[TAG-PIPELINE] %s column-select failed: %s\n', ...
                    key, ex.message);
                continue;
            end

            % Slice only the new rows
            total = numel(x);
            if total <= state.lastIndex
                state.lastModTime = info.datenum;
                obj.tagState_(key) = state;
                continue;
            end
            newRange = (state.lastIndex + 1):total;
            newX = x(newRange);
            newY = y(newRange,:);

            try
                writeTagMat_(obj.OutputDir, t, newX, newY, 'append');
            catch ex
                fprintf(2, '[TAG-PIPELINE] %s write failed: %s\n', ...
                    key, ex.message);
                continue;
            end

            % Commit state after successful write
            state.lastModTime = info.datenum;
            state.lastIndex   = total;
            obj.tagState_(key) = state;
        end
    catch ex
        if ~isempty(obj.ErrorFcn)
            obj.ErrorFcn(ex);
        else
            fprintf(2, '[TAG-PIPELINE] Tick error: %s\n', ex.message);
        end
    end
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `csvread` / `dlmread` | `textscan` for mixed data in Octave; `readtable` in MATLAB-only contexts | Octave 4.0+ | Project must use `textscan` exclusively for portability. `csvread` / `dlmread` are numeric-only on both runtimes. |
| MATLAB v1 `PreserveVariableNames` | R2020b `VariableNamingRule='preserve'` | MATLAB R2020b | N/A here (not using `readtable`), but noted for awareness. |
| MATLAB `readtable` with auto-delimiter | Still the recommended MATLAB-only path; now with `detectImportOptions` | R2016b+ | MATLAB-only — Octave-incompatible. We reject it. |
| Manual tempfile cleanup in tests | `testCase.addTeardown(@() rmdir(dir, 's'))` | matlab.unittest since R2014a+ / Octave parity post-7 | Codebase already uses this idiom; our tests follow suit. |

**Deprecated/outdated:**
- `csvread`: marked "(Not recommended)" in MATLAB docs since R2019a; use `readtable` in MATLAB. Since Octave doesn't have `readtable`, we use `textscan`.
- `inputParser`: works but `parseOpts` (existing private helper) is the codebase convention.

---

## Open Questions

### Q1: Should `RawSource` accept a cell of file paths (multi-file tags)?

- **What we know:** CONTEXT.md decisions D-05 show `file` as a single char. Real-world daily-rotated logs are multi-file.
- **What's unclear:** Whether the planner should add `file` as cellstr support, or defer.
- **Recommendation (CONFIDENCE: HIGH):** **Defer.** Not in CONTEXT.md; adding it now widens scope and complicates the dedup cache (cache key becomes sorted(cellstr) concatenation). Single-file per tag is sufficient for the initial ship. Add a TODO comment at the validator.

### Q2: What happens when a raw file's column count changes between live ticks?

- **What we know:** Re-parse reads the new shape; `selectTimeAndValue_` uses the new `headers` to resolve the column.
- **What's unclear:** If the NAMED column went missing (wide file, user deleted a column mid-stream), the per-tag ingest raises `TagPipeline:missingColumn` on the next tick. Is that the right UX?
- **Recommendation (CONFIDENCE: MEDIUM):** Yes — same semantics as batch mode. The error surfaces in the console on that tick and the end-of-tick report logs it. The tag's `lastIndex_` does NOT advance (because the write failed), so the user can fix the file and the next tick retries. Document explicitly.

### Q3: How does live mode handle tag unregister events mid-run?

- **What we know:** The pipeline re-enumerates eligible tags each tick (Pattern 7). Unregister-while-running just means that tag skips the next tick.
- **What's unclear:** Does the pipeline drop its `tagState_` entry for the unregistered tag?
- **Recommendation (CONFIDENCE: HIGH):** Yes. At the start of each tick, reconcile `tagState_` keys against the current eligible set and drop stale entries. Small GC pass. Prevents slow memory growth during long-running pipelines with churn.

### Q4: `LiveTagPipeline.stop()` — finish current tick or interrupt?

- **What we know:** `LiveEventPipeline.stop()` calls `stop(obj.timer_)` which, by MATLAB timer semantics, lets the current tick complete before the timer stops calling `TimerFcn`. It doesn't forcibly interrupt.
- **What's unclear:** Nothing — this is well-documented MATLAB timer behavior.
- **Recommendation (CONFIDENCE: HIGH):** Mirror `LiveEventPipeline.stop` exactly. Document in the class header: "stop() completes the in-flight tick, then halts. Call `pipeline.Status` to confirm `'stopped'`."

### Q5: Error-ID taxonomy — how granular should `TagPipeline:*` be?

- **What we know:** D-19 names five expected failure modes.
- **Recommendation (CONFIDENCE: HIGH):** Use the following concrete IDs (each gets an assertable test):
  - `TagPipeline:fileNotReadable` (file missing or unreadable)
  - `TagPipeline:emptyFile` (0 data rows after header skip)
  - `TagPipeline:delimiterAmbiguous` (sniff failed to find consistent delimiter)
  - `TagPipeline:missingColumn` (wide file, named column not in header)
  - `TagPipeline:noHeadersForNamedColumn` (wide dispatch attempted, no header row)
  - `TagPipeline:insufficientColumns` (file has <2 columns after parse)
  - `TagPipeline:invalidRawSource` (RawSource struct malformed — fatal at construction or ingest)
  - `TagPipeline:invalidOutputDir` (constructor parameter missing)
  - `TagPipeline:cannotCreateOutputDir` (mkdir failed)
  - `TagPipeline:invalidWriteMode` (writer helper called with bad mode — internal bug)
  - `TagPipeline:ingestFailed` (the end-of-run throw)

### Q6: Does the pipeline need a perf benchmark?

- **What we know:** Pitfall 9 of v2.0 research (MEX wrapping cost) is context-general; this pipeline doesn't touch MEX paths.
- **Recommendation (CONFIDENCE: MEDIUM):** **Optional — include if budget permits.** Batch mode processing 20 tags across 2 wide CSVs of 10k rows: target < 2s end-to-end on a reference machine. Live mode tick with 20 tags (no new data): target < 50ms. Not a gate, but a PR-time check to catch regression. If budget is tight, skip and revisit if real usage shows slowness.

### Q7: Parser dispatch — switch vs `containers.Map`?

- **What we know:** CONTEXT.md leaves this to discretion (D-02).
- **Recommendation (CONFIDENCE: HIGH):** Start with a **switch inside `dispatchParse_`**. The three cases (`.csv`, `.txt`, `.dat`) all route to the same parser, so the map would be degenerate. When a future phase adds `registerParser`, the switch becomes a map — but do that refactor when the feature ships, not speculatively.

### Q8: Should `readRawDelimited_` write its result via `load('-append')` semantics?

- **What we know:** D-09 specifies `data.<KeyName>` as the output shape. `SensorTag.load` expects this.
- **What's unclear:** Some existing mat-files may carry metadata (from a future phase) alongside `data`. Live append that uses `save(path, 'data')` (no `-append`) would clobber them.
- **Recommendation (CONFIDENCE: MEDIUM):** For this phase, no co-variable preservation. If a future phase adds metadata blocks (deferred item from CONTEXT.md), the writer gets a flag. Document the current behavior as "overwrite all variables in file; one tag per file."

---

## Environment Availability

This phase is pure-MATLAB/Octave code. No external tools, runtimes, or services are introduced. Install matrix is unchanged.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b+ | Primary runtime | (project floor) | R2020b+ | Octave 7+ |
| GNU Octave 7+ | Alternative runtime | (project floor) | Octave 7+ | — |
| `textscan` | Parser core | ✓ on both runtimes (since MATLAB R14 / Octave 3.0) | builtin | — |
| `fopen/fgetl/fclose` | Header sniff | ✓ on both | builtin | — |
| `strsplit` | Delimiter sniff | ✓ on both | builtin | — |
| `containers.Map` | File cache | ✓ on both | builtin | — |
| `timer` | Live pipeline | ✓ on both (Octave: core since 4.0) | builtin | — |
| `dir` / `.datenum` | mtime polling | ✓ on both | builtin | — |
| `save` / `load` | Output write / append | ✓ on both | builtin (-v7 default) | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None.

**Nothing additional to install.** The existing `install.m` path-setup already adds `libs/SensorThreshold` and its `private/` subfolder.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (R2014a+) and Octave function-style tests (dual-mode) |
| Config file | None — `tests/run_all_tests.m` auto-discovers both styles |
| Quick run command | `matlab -batch "cd tests; run_all_tests"` or `octave --eval "cd tests; run_all_tests"` |
| Full suite command | Same (single test runner handles both suite and flat) |
| Phase gate | Full `run_all_tests` green on both MATLAB and Octave before `/gsd:verify-work` |

### Phase Requirements → Test Map

| Req (CONTEXT decision) | Behavior | Test Type | Automated Command | File |
|------------------------|----------|-----------|-------------------|------|
| D-01 | Shared parser handles `.csv`, `.txt`, `.dat` | unit | `matlab -batch "runtests('tests/suite/TestRawDelimitedParser.m')"` | TestRawDelimitedParser.m — Wave 0 |
| D-02 | Parser dispatch is switch-based internally | static | grep test: no `registerParser` public symbol | TestBatchTagPipeline.m::testNoPublicRegisterParser |
| D-03 | Synthetic fixtures (no disk artifacts shipped) | static | grep test: no files in `tests/fixtures/raw_*` | (Wave 0) meta-test |
| D-04 | Wide + tall shapes dispatch correctly | unit | `runtests('TestBatchTagPipeline.m::testWideDispatch', '::testTallDispatch')` | TestBatchTagPipeline.m — Wave 0 |
| D-05 | `RawSource` property on SensorTag + StateTag, not Tag | unit | `runtests('TestSensorTag.m::testRawSourceProperty')` + StateTag equivalent | edits to existing TestSensorTag.m + TestStateTag.m |
| D-06 | Missing column on wide → per-tag error | unit | `runtests('TestBatchTagPipeline.m::testMissingColumn')` | TestBatchTagPipeline.m — Wave 0 |
| D-07 | Shared file parsed once per run | unit (via spy/mock or instrumented cache) | `runtests('TestBatchTagPipeline.m::testFileCacheDedup')` | TestBatchTagPipeline.m |
| D-08 | Tags without RawSource / Monitor / Composite skipped | unit | `runtests('TestBatchTagPipeline.m::testSilentSkip')` | TestBatchTagPipeline.m |
| D-09 | Output shape is `data.<key> = struct('x',X,'y',Y)` | integration | `runtests('TestBatchTagPipeline.m::testRoundTripThroughSensorTagLoad')` | TestBatchTagPipeline.m |
| D-10 | One .mat per tag; no collision | integration | `runtests('TestLiveTagPipeline.m::testPerTagFileIsolation')` | TestLiveTagPipeline.m |
| D-11 | StateTag cellstr Y round-trips | unit | `runtests('TestBatchTagPipeline.m::testStateTagCellstrOutput')` | TestBatchTagPipeline.m |
| D-12 | Two classes share helper path | static | grep test: both classes call `writeTagMat_` / `readRawDelimited_` | structural test |
| D-13 | Live mode reuses modTime+lastIndex | integration (mtime-bumping) | `runtests('TestLiveTagPipeline.m::testIncrementalTick')` | TestLiveTagPipeline.m — uses pause(1.1) |
| D-14 | `LiveTagPipeline` does NOT extend `LiveEventPipeline` | static | `runtests('TestLiveTagPipeline.m::testNoSubclassOfLiveEventPipeline')` (isa check) | TestLiveTagPipeline.m |
| D-15 | `OutputDir` constructor parameter; auto-mkdir | unit | `runtests('TestBatchTagPipeline.m::testAutoMkdir')` | TestBatchTagPipeline.m |
| D-16 | Monitor / Composite never written | integration | `runtests('TestBatchTagPipeline.m::testMonitorNotMaterialized')` | TestBatchTagPipeline.m |
| D-17 | MonitorTag.Persist path untouched | regression | existing `TestMonitorTagPersistence.m` still green | (existing test) |
| D-18 | Fail-soft + end-of-run throw | integration | `runtests('TestBatchTagPipeline.m::testIngestFailedWithReport')` | TestBatchTagPipeline.m |
| D-19 | Each `TagPipeline:*` error ID is assertable | unit | `runtests('TestBatchTagPipeline.m::testErrorIDs')` (parameterized) | TestBatchTagPipeline.m |

### Sampling Rate

- **Per task commit:** `matlab -batch "cd tests; runtests('suite/TestBatchTagPipeline.m')"` — run the single touched suite.
- **Per wave merge:** `matlab -batch "cd tests; run_all_tests"` (full suite on primary runtime).
- **Phase gate:** Full suite green on both MATLAB and Octave before `/gsd:verify-work`.

### Wave 0 Gaps

- [ ] `tests/suite/TestRawDelimitedParser.m` — unit-tests `readRawDelimited_` via a small public shim (the private helper is reached from a suite file in the same library; use a thin `readRawDelimitedForTest_` wrapper in `libs/SensorThreshold/` that calls through)
- [ ] `tests/suite/TestBatchTagPipeline.m` — suite-style tests (all D-## decisions)
- [ ] `tests/suite/TestLiveTagPipeline.m` — suite-style tests (D-13, D-14, D-15 + mtime-bump)
- [ ] Shared fixture helper: `tests/suite/makeRawFixtures_.m` (or inlined in each suite's private methods block) — writes CSV/TXT/DAT to `tempname()` dir with teardown
- [ ] Edits to `TestSensorTag.m` + `TestStateTag.m` to add `RawSource` property coverage

*(No framework install needed — `matlab.unittest.TestCase` and flat tests both already configured.)*

---

## Sources

### Primary (HIGH confidence)

- [libs/SensorThreshold/SensorTag.m](libs/SensorThreshold/SensorTag.m) — direct read, construction/splitArgs/toStruct/fromStruct patterns
- [libs/SensorThreshold/StateTag.m](libs/SensorThreshold/StateTag.m) — direct read, parallel structure
- [libs/SensorThreshold/Tag.m](libs/SensorThreshold/Tag.m) — direct read, confirms ≤6 abstract method budget and locked surface
- [libs/SensorThreshold/TagRegistry.m](libs/SensorThreshold/TagRegistry.m) — direct read, `find(predicate)` query pattern
- [libs/EventDetection/MatFileDataSource.m](libs/EventDetection/MatFileDataSource.m) — direct read, modTime+lastIndex state machine (direct template)
- [libs/EventDetection/LiveEventPipeline.m](libs/EventDetection/LiveEventPipeline.m) — direct read, timer skeleton (borrowed pattern)
- [libs/EventDetection/DataSource.m](libs/EventDetection/DataSource.m) — direct read, abstract interface (noted but not inherited by LiveTagPipeline)
- [libs/FastSense/private/parseOpts.m](libs/FastSense/private/parseOpts.m) — direct read, NV-pair parsing convention
- [tests/suite/TestSensorTag.m](tests/suite/TestSensorTag.m) — direct read, test style + fixture helper pattern
- [tests/suite/TestMatFileDataSource.m](tests/suite/TestMatFileDataSource.m) — direct read, mtime-bump pause(1.1) pattern
- [Octave 11 Simple File I/O docs](https://docs.octave.org/latest/Simple-File-I_002fO.html) — verified absence of `readtable`/`readmatrix`; confirmed `textscan` delimiter + headerlines semantics
- [MATLAB readtable docs](https://www.mathworks.com/help/matlab/ref/readtable.html) — for comparison; confirms VariableNamingRule change in R2020b
- [MATLAB detectImportOptions docs](https://www.mathworks.com/help/matlab/ref/detectimportoptions.html) — MATLAB-only; auto-delimiter reference

### Secondary (MEDIUM confidence)

- [MATLAB save reference](https://www.mathworks.com/help/matlab/ref/save.html) — confirms `-append` overwrites same-named variables (Pitfall 2 guard)
- [Octave save docs](https://docs.octave.org/v11.1.0/Simple-File-I_002fO.html) — confirms v7 append semantics
- [Octave csvread Forge page](https://octave.sourceforge.io/octave/function/csvread.html) — confirms numeric-only limitation
- [Octave textscan Forge page](https://octave.sourceforge.io/octave/function/textscan.html) — confirms Delimiter / HeaderLines options
- [Filesystem mtime resolution reference](https://en.wikipedia.org/wiki/Comparison_of_file_systems) — HFS+ 1s, APFS ns, ext4 ns, NTFS 100ns, FAT32 2s
- [Octave help-octave list: Import large field-delimited file with strings and numbers](https://help.octave.narkive.com/5gCYdcHE/import-large-field-delimited-file-with-strings-and-numbers) — ecosystem precedent for `textscan` usage on mixed data

### Tertiary (LOW confidence — flagged for validation)

- None. All architectural claims in this document are grounded in either direct codebase read or primary-source documentation.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs verified against both runtime docs; no MATLAB-only trapdoors in the proposed set.
- Architecture: HIGH — every pattern has a direct codebase precedent (cited line numbers).
- Pitfalls: MEDIUM-HIGH — runtime-specific ones verified against docs; filesystem mtime ones known but project's CI matrix hasn't hit all combinations.
- Validation Architecture: HIGH — mirror of existing dual-runtime test style; `pause(1.1)` mtime guard is proven by `TestMatFileDataSource`.
- Open questions: answered with confidence levels per item.

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (30 days for stable MATLAB/Octave APIs)

---

*Phase: 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live*
*Researched: 2026-04-22 by gsd-researcher*
