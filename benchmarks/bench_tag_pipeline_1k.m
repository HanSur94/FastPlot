function result = bench_tag_pipeline_1k(varargin)
    %BENCH_TAG_PIPELINE_1K Phase 1028 primary CI gate harness — 1000 synthetic tags.
    %
    %   Drives LiveTagPipeline.tickOnce() over a synthetic 1000-tag graph
    %   (700 SensorTag + 100 StateTag + 150 MonitorTag + 50 CompositeTag)
    %   fed by 8 wide CSV "machine" files. Establishes the empirical baseline
    %   and CI gate referenced by phase 1028 (D-01, D-06, D-07, D-12).
    %
    %   Forms (mirror existing bench_*.m self-bootstrap pattern):
    %     bench_tag_pipeline_1k()                  % NoIO mode, gated, full run
    %     bench_tag_pipeline_1k('--smoke')         % NoIO, nTicks=10, no gate (CI smoke)
    %     bench_tag_pipeline_1k('Mode', 'WithIO')  % diagnostic, not gated
    %     result = bench_tag_pipeline_1k(...)      % returns struct with timings
    %
    %   Output struct fields:
    %     tickMin       — minimum tick wall (seconds)
    %     tickMedian    — median tick wall (seconds)
    %     tBreakdown    — struct('parse', t1, 'perTag', t2, 'fanout', t3, 'merge', t4)
    %                     Wave 0: all zeros (slot reserved for Wave 1+ named-region wiring).
    %     mode          — 'NoIO' | 'WithIO'
    %     wallTotal     — total wall time of the warmup+measurement loop (seconds)
    %     nTagsTotal    — 1000 (sanity check)
    %
    %   Modes (P2 mitigation per RESEARCH §"Risks and Unknowns"):
    %     'NoIO'   (default, gated): writeTagMat_ shimmed to no-op via path
    %                                priority so the harness measures the
    %                                tag/MEX path without .mat I/O dominance.
    %     'WithIO' (diagnostic, NOT gated): full lifecycle including .mat
    %                                       writes; surfaces D-12 limitation.
    %
    %   NoIO implementation choice (per Task 1 plan note):
    %     Path-priority shim. We materialize a no-op `writeTagMat_.m` into a
    %     temp directory and `addpath(tempShimDir, '-begin')`, then `rmpath`
    %     in the cleanup (try/finally). Public API is untouched (D-10).
    %     Octave's private-method visibility rule does NOT block this — the
    %     SensorThreshold caller resolves writeTagMat_ via its parent's
    %     `private/` directory, but the leading addpath wins on the search
    %     order in both MATLAB and Octave for top-level (non-private) names
    %     at the same level. This was selected over a constructor 'SkipWrite'
    %     option to keep LiveTagPipeline's public surface exactly as-is.
    %
    %   Determinism:
    %     - rng(0) on MATLAB; rand('state',0)/randn('state',0) on Octave
    %       (verbatim mirror of bench_compositetag_merge.m lines 50-54).
    %     - TagRegistry.clear() at top AND in cleanup (try/finally).
    %
    %   Wall budget:
    %     The whole nWarmup+nTicks loop is wrapped in tic/toc and asserted
    %     <30s (the CI fast-bench budget per D-07 / RESEARCH §"CI-Fast 1000-Tag
    %     Harness Design"). The smoke variant uses fewer ticks and inherits
    %     the same budget.
    %
    %   Gate:
    %     If called WITHOUT '--smoke', asserts result.tickMin < GATE_THRESHOLD_SECONDS.
    %     Wave 0: GATE_THRESHOLD_SECONDS = inf (no gate yet); Task 5 of plan
    %     1028-01 replaces this with the measured baseline * 1.10 once CI
    %     captures the baseline numbers (per D-03 profile-first).
    %
    %   See also: LiveTagPipeline, SensorTag, StateTag, MonitorTag, CompositeTag,
    %             TagRegistry, bench_monitortag_tick, bench_compositetag_merge.

    % --------- Self-bootstrap (mirror existing bench_*.m pattern) ---------
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    % --------- Mode + smoke parsing ---------
    mode = 'NoIO';
    smoke = false;
    i = 1;
    while i <= numel(varargin)
        arg = varargin{i};
        if ischar(arg) && strcmp(arg, '--smoke')
            smoke = true;
            i = i + 1;
        elseif ischar(arg) && strcmpi(arg, 'Mode')
            if i + 1 > numel(varargin)
                error('bench_tag_pipeline_1k:badArgs', ...
                    '''Mode'' requires a value (''NoIO'' | ''WithIO'').');
            end
            mode = char(varargin{i+1});
            i = i + 2;
        else
            error('bench_tag_pipeline_1k:badArgs', ...
                'Unknown argument %s. Expected ''--smoke'' or ''Mode''.', ...
                disp_(arg));
        end
    end
    if ~any(strcmpi(mode, {'NoIO', 'WithIO'}))
        error('bench_tag_pipeline_1k:badArgs', ...
            'Mode must be ''NoIO'' or ''WithIO''; got ''%s''.', mode);
    end
    isNoIO = strcmpi(mode, 'NoIO');

    % --------- Gate threshold (Wave 0: inf; Task 5 sets the real number) ---------
    GATE_THRESHOLD_SECONDS = inf;   % Set in Wave 0 Task 5 per D-03

    % --------- Topology constants (HARD per RESEARCH §1000-Tag Harness Design) ---------
    nSensors   = 700;
    nState     = 100;
    nMonitor   = 150;
    nComposite = 50;
    nMachines  = 8;
    nWarmup    = 5;
    nTicks     = 30;
    if smoke
        nWarmup = 2;
        nTicks  = 10;
    end
    nAppend = 100;          % rows per file per tick
    nPrefill = 1000;        % initial rows per file
    nCols = 15;             % wide CSV (time + 14 value columns)

    % --------- Determinism (Octave-safe, mirrors bench_compositetag_merge.m:50-54) ---------
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0);   %#ok<RAND>
        randn('state', 0);  %#ok<RAND>
    end

    fprintf('\n== bench_tag_pipeline_1k: %d tags (%d sensors + %d state + %d monitor + %d composite), %d machines, mode=%s%s ==\n', ...
        nSensors + nState + nMonitor + nComposite, nSensors, nState, nMonitor, nComposite, ...
        nMachines, mode, char(repmat('  [SMOKE]', 1, double(smoke))));

    % --------- Setup: temp dirs + path-priority NoIO shim ---------
    rawDir = setupTempRawDir_('bench_tp1k_raw');
    outDir = setupTempRawDir_('bench_tp1k_out');
    shimDir = '';
    if isNoIO
        shimDir = installNoIOShim_();
    end

    % Cleanup discipline: TagRegistry + temp dirs + path shim teardown.
    cleanupObj = onCleanup(@() teardown_(shimDir, rawDir, outDir));    %#ok<NASGU>
    TagRegistry.clear();

    % --------- Build synthetic raw files (8 wide CSVs) ---------
    csvPaths = cell(1, nMachines);
    for k = 1:nMachines
        csvPaths{k} = fullfile(rawDir, sprintf('machine_%02d.csv', k));
        writeInitialCsv_(csvPaths{k}, nCols, nPrefill);
    end

    % --------- Build tag graph ---------
    sensors    = buildSensorTags_(csvPaths, nSensors, nCols);
    states     = buildStateTags_(csvPaths, nState, nCols, nSensors); %#ok<NASGU>
    monitors   = buildMonitorTags_(sensors, nMonitor);
    composites = buildCompositeTags_(monitors, nComposite); %#ok<NASGU>

    nTagsTotal = nSensors + nState + nMonitor + nComposite;
    assert(nTagsTotal == 1000, 'bench_tag_pipeline_1k: topology must be exactly 1000 tags (%d)', nTagsTotal);

    % --------- Pipeline driver ---------
    p = LiveTagPipeline('OutputDir', outDir, 'Interval', 999);   % timer never used

    tickTimes = nan(1, nTicks);
    tBreakdown = struct('parse', 0, 'perTag', 0, 'fanout', 0, 'merge', 0);

    wallStart = tic;
    for k = 1:(nWarmup + nTicks)
        growAllRawFiles_(csvPaths, nAppend, nCols);   % outside timing
        if k > nWarmup
            t0 = tic;
            p.tickOnce();
            tickTimes(k - nWarmup) = toc(t0);
        else
            p.tickOnce();
        end
    end
    wallTotal = toc(wallStart);

    % --------- Wall-budget guard (D-07 / RESEARCH §CI-Fast Harness) ---------
    assert(wallTotal < 30, ...
        sprintf('bench_tag_pipeline_1k: wall budget exceeded (%.1fs > 30s)', wallTotal));

    result = struct();
    result.tickMin    = min(tickTimes);
    result.tickMedian = median(tickTimes);
    result.tBreakdown = tBreakdown;
    result.mode       = mode;
    result.wallTotal  = wallTotal;
    result.nTagsTotal = nTagsTotal;

    fprintf('  tickMin    : %.4f s\n', result.tickMin);
    fprintf('  tickMedian : %.4f s\n', result.tickMedian);
    fprintf('  wallTotal  : %.2f s (budget: <30 s)\n', wallTotal);

    % --------- Gate (only when not smoke) ---------
    if ~smoke
        assert(result.tickMin < GATE_THRESHOLD_SECONDS, ...
            sprintf('bench_tag_pipeline_1k: tickMin %.4f s exceeds gate %.4f s', ...
                    result.tickMin, GATE_THRESHOLD_SECONDS));
        fprintf('  PASS: tickMin %.4f s < gate %.4f s\n\n', result.tickMin, GATE_THRESHOLD_SECONDS);
    else
        fprintf('  SMOKE PASS (no gate)\n\n');
    end
end

% =====================================================================
%  Helpers
% =====================================================================

function s = disp_(x)
    %DISP_ Robust scalar display for unknown-type error reporting.
    try
        s = char(x);
    catch
        s = class(x);
    end
end

function dir_ = setupTempRawDir_(suffix)
    %SETUPTEMPRAWDIR_ Create a unique tempdir for the bench (raw or output).
    base = tempname();
    dir_ = sprintf('%s_%s', base, suffix);
    [ok, msg] = mkdir(dir_);
    if ~ok
        error('bench_tag_pipeline_1k:tempdir', ...
            'Cannot create tempdir %s: %s', dir_, msg);
    end
end

function teardown_(shimDir, rawDir, outDir)
    %TEARDOWN_ Best-effort cleanup of TagRegistry, path shim, and temp dirs.
    try
        TagRegistry.clear();
    catch
    end
    if ~isempty(shimDir)
        try
            rmpath(shimDir);
        catch
        end
        try
            if exist(shimDir, 'dir')
                rmdir(shimDir, 's');
            end
        catch
        end
    end
    try
        if exist(rawDir, 'dir')
            rmdir(rawDir, 's');
        end
    catch
    end
    try
        if exist(outDir, 'dir')
            rmdir(outDir, 's');
        end
    catch
    end
end

function shimDir = installNoIOShim_()
    %INSTALLNOIOSHIM_ Materialize a no-op writeTagMat_ shim and prepend to path.
    %   Path priority makes the shim's writeTagMat_ resolved before the
    %   SensorThreshold/private/writeTagMat_.m. The shim ignores all inputs.
    shimDir = setupTempRawDir_('bench_tp1k_shim');
    shimFile = fullfile(shimDir, 'writeTagMat_.m');
    fid = fopen(shimFile, 'w');
    if fid == -1
        error('bench_tag_pipeline_1k:shim', 'Cannot create shim file %s', shimFile);
    end
    fprintf(fid, 'function writeTagMat_(varargin)\n');
    fprintf(fid, '    %%WRITETAGMAT_ NoIO shim — bench_tag_pipeline_1k. Discards inputs.\n');
    fprintf(fid, 'end\n');
    fclose(fid);
    addpath(shimDir, '-begin');
end

function writeInitialCsv_(path, nCols, nRows)
    %WRITEINITIALCSV_ Write a wide CSV with header + nRows of synthetic data.
    fid = fopen(path, 'w');
    if fid == -1
        error('bench_tag_pipeline_1k:csv', 'Cannot create %s', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % Header: time + col_01..col_(nCols-1).
    headers = cell(1, nCols);
    headers{1} = 'time';
    for c = 2:nCols
        headers{c} = sprintf('col_%02d', c - 1);
    end
    fprintf(fid, '%s\n', strjoin(headers, ','));

    % Rows: time monotonic 0..nRows-1; values = sin(2*pi*t/30 + phase) + noise.
    for r = 1:nRows
        t = r - 1;
        row = zeros(1, nCols);
        row(1) = t;
        for c = 2:nCols
            row(c) = sin(2*pi*t/30 + (c-2)*0.3) + 0.05 * randn();
        end
        fprintf(fid, '%g', row(1));
        fprintf(fid, ',%g', row(2:end));
        fprintf(fid, '\n');
    end
end

function growAllRawFiles_(csvPaths, nAppend, nCols)
    %GROWALLRAWFILES_ Append nAppend rows to each CSV (mtime bump).
    %   Uses 'a' mode + the file mtime advances naturally on close.
    for k = 1:numel(csvPaths)
        path = csvPaths{k};
        % Determine the next start time by counting lines (cheap on small files
        % during smoke; for the full run we re-stat to get current size).
        nExisting = countLines_(path) - 1;     % minus header
        if nExisting < 0, nExisting = 0; end
        fid = fopen(path, 'a');
        if fid == -1
            error('bench_tag_pipeline_1k:csv', 'Cannot append to %s', path);
        end
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        for r = 1:nAppend
            t = nExisting + (r - 1);
            row = zeros(1, nCols);
            row(1) = t;
            for c = 2:nCols
                row(c) = sin(2*pi*t/30 + (c-2)*0.3) + 0.05 * randn();
            end
            fprintf(fid, '%g', row(1));
            fprintf(fid, ',%g', row(2:end));
            fprintf(fid, '\n');
        end
    end
end

function n = countLines_(path)
    %COUNTLINES_ Count lines via fgetl (Octave-safe; small CSVs).
    fid = fopen(path, 'r');
    if fid == -1
        n = 0;
        return;
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    n = 0;
    while ischar(fgetl(fid))
        n = n + 1;
    end
end

function sensors = buildSensorTags_(csvPaths, n, nCols)
    %BUILDSENSORTAGS_ 700 SensorTags spread across 8 files, named col_01..col_(nCols-1).
    sensors = cell(1, n);
    nMachines = numel(csvPaths);
    valueCols = nCols - 1;   % columns minus 'time'
    for i = 1:n
        machineIdx = mod(i - 1, nMachines) + 1;
        colIdx = mod(i - 1, valueCols) + 1;   % 1..14
        rs = struct('file', csvPaths{machineIdx}, ...
                    'column', sprintf('col_%02d', colIdx));
        key = sprintf('sensor_%04d', i);
        s = SensorTag(key, 'RawSource', rs);
        TagRegistry.register(key, s);
        sensors{i} = s;
    end
end

function states = buildStateTags_(csvPaths, n, nCols, sensorOffset)
    %BUILDSTATETAGS_ 100 StateTags (treated as discrete sources from the same CSVs).
    %   Each shares the time column from machines + a different value column.
    %   sensorOffset starts the state's column rotation past the sensor block
    %   so state and sensor tags don't collide on the same column.
    states = cell(1, n);
    nMachines = numel(csvPaths);
    valueCols = nCols - 1;
    for i = 1:n
        machineIdx = mod(i - 1, nMachines) + 1;
        colIdx = mod(i + sensorOffset - 1, valueCols) + 1;
        rs = struct('file', csvPaths{machineIdx}, ...
                    'column', sprintf('col_%02d', colIdx));
        key = sprintf('state_%04d', i);
        s = StateTag(key, 'RawSource', rs);
        TagRegistry.register(key, s);
        states{i} = s;
    end
end

function monitors = buildMonitorTags_(sensors, n)
    %BUILDMONITORTAGS_ 150 MonitorTags over a subset of sensors.
    %   Mix:
    %     100 simple `y > thresh`
    %      30 with AlarmOffConditionFn (hysteresis — exercises H2)
    %      20 with MinDuration > 0 (debounce — exercises H3)
    monitors = cell(1, n);
    nSensors = numel(sensors);
    for i = 1:n
        parent = sensors{mod(i - 1, nSensors) + 1};
        key = sprintf('mon_%04d', i);
        if i <= 100
            m = MonitorTag(key, parent, @(x, y) y > 0.5);
        elseif i <= 130
            m = MonitorTag(key, parent, @(x, y) y > 0.5, ...
                'AlarmOffConditionFn', @(x, y) y < 0.3);
        else
            m = MonitorTag(key, parent, @(x, y) y > 0.5, ...
                'MinDuration', 0.5);
        end
        m.Persist = false;
        TagRegistry.register(key, m);
        monitors{i} = m;
    end
end

function composites = buildCompositeTags_(monitors, n)
    %BUILDCOMPOSITETAGS_ 50 CompositeTags over 4-8 MonitorTag children each.
    %   Distribution: and=10, or=10, worst=10, count=8, majority=6, severity=6.
    modes = [repmat({'and'}, 1, 10), ...
             repmat({'or'}, 1, 10), ...
             repmat({'worst'}, 1, 10), ...
             repmat({'count'}, 1, 8), ...
             repmat({'majority'}, 1, 6), ...
             repmat({'severity'}, 1, 6)];
    assert(numel(modes) == n, ...
        'buildCompositeTags_: mode mix must total %d (got %d)', n, numel(modes));

    composites = cell(1, n);
    nMon = numel(monitors);
    for i = 1:n
        nChildren = 4 + mod(i - 1, 5);   % 4..8
        key = sprintf('comp_%04d', i);
        c = CompositeTag(key, modes{i});
        for ci = 1:nChildren
            childIdx = mod((i - 1) * 7 + (ci - 1), nMon) + 1;
            c.addChild(monitors{childIdx});
        end
        TagRegistry.register(key, c);
        composites{i} = c;
    end
end
