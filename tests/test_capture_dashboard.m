function test_capture_dashboard()
%TEST_CAPTURE_DASHBOARD Octave-safe function-style test for captureDashboard.
%
%   Covers the four user-facing behaviours of libs/Dashboard/captureDashboard.m:
%     1. testCaptureFullDashboard       — whole-figure capture writes PNG.
%     2. testCaptureByWidgetTitle       — 'Widget', 'Title' capture writes PNG
%                                          (on Octave this falls back to whole
%                                           figure by documented design).
%     3. testCaptureReturnsAbsolutePath — relative filepath resolves to abs.
%     4. testCaptureUnknownOptionThrows — unrecognised NV key raises the
%                                          captureDashboard:unknownOption id.
%
%   Each test uses headless dashboards (Visible='off') so it runs under
%   xvfb-run in CI without spawning visible windows.

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % --- testCaptureFullDashboard -----------------------------------------
    try
        d = DashboardEngine('CapFull');
        d.addWidget('number', 'Title', 'N1', ...
            'Position', [1 1 6 2], 'StaticValue', 42);
        x = linspace(0, 10, 100);
        y = sin(x);
        d.addWidget('fastsense', 'Title', 'Wave', ...
            'Position', [1 3 12 6], 'XData', x, 'YData', y);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        tmp = [tempname, '.png'];
        p = captureDashboard(d, tmp);
        assert(exist(p, 'file') == 2, ...
            'testCaptureFullDashboard: PNG must exist on disk');
        info = dir(p);
        assert(~isempty(info) && info.bytes > 1000, ...
            sprintf('testCaptureFullDashboard: expected bytes>1000, got %d', ...
                info.bytes));
        % Spot-check readability when imread is available
        try
            img = imread(p);
            assert(~isempty(img), ...
                'testCaptureFullDashboard: imread returned empty');
        catch
            % imread unavailable in some minimal Octave builds — not fatal
        end
        delete(p);
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCaptureFullDashboard: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- testCaptureByWidgetTitle -----------------------------------------
    try
        d = DashboardEngine('CapWidget');
        d.addWidget('number', 'Title', 'X', ...
            'Position', [1 1 6 2], 'StaticValue', 7);
        d.addWidget('number', 'Title', 'Y', ...
            'Position', [7 1 6 2], 'StaticValue', 9);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        tmp = [tempname, '.png'];
        p = captureDashboard(d, tmp, 'Widget', 'X');
        assert(exist(p, 'file') == 2, ...
            'testCaptureByWidgetTitle: PNG must exist on disk');
        info = dir(p);
        assert(~isempty(info) && info.bytes > 500, ...
            sprintf('testCaptureByWidgetTitle: expected bytes>500, got %d', ...
                info.bytes));
        delete(p);
        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCaptureByWidgetTitle: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- testCaptureReturnsAbsolutePath -----------------------------------
    % Pass a relative filename (cd into tempdir so cleanup is easy).
    origDir = pwd;
    relFile = '';
    try
        tmpDir = tempname();
        mkdir(tmpDir);
        cd(tmpDir);

        d = DashboardEngine('CapAbs');
        d.addWidget('number', 'Title', 'Z', ...
            'Position', [1 1 6 2], 'StaticValue', 3);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        relFile = 'out_relative.png';
        p = captureDashboard(d, relFile);

        isAbs = (numel(p) > 0 && (p(1) == '/' || p(1) == '\')) || ...
                (numel(p) > 1 && p(2) == ':');
        assert(isAbs, ...
            sprintf('testCaptureReturnsAbsolutePath: expected abs path, got ''%s''', p));
        assert(exist(p, 'file') == 2, ...
            'testCaptureReturnsAbsolutePath: returned path must exist');

        close(d.hFigure);
        cd(origDir);
        % Best-effort cleanup
        try; delete(p); end %#ok<*TRYNC>
        try; rmdir(tmpDir); end
        nPassed = nPassed + 1;
    catch err
        cd(origDir);
        fprintf('    FAIL testCaptureReturnsAbsolutePath: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % --- testCaptureUnknownOptionThrows -----------------------------------
    try
        d = DashboardEngine('CapErr');
        d.addWidget('number', 'Title', 'Q', ...
            'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');
        tmp = [tempname, '.png'];

        threw = false;
        gotId = '';
        try
            captureDashboard(d, tmp, 'Bogus', 1);
        catch err
            threw = true;
            gotId = err.identifier;
        end
        assert(threw, ...
            'testCaptureUnknownOptionThrows: expected an error, got none');
        assert(strcmp(gotId, 'captureDashboard:unknownOption'), ...
            sprintf('testCaptureUnknownOptionThrows: expected id ''captureDashboard:unknownOption'', got ''%s''', gotId));

        close(d.hFigure);
        if exist(tmp, 'file'); delete(tmp); end
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testCaptureUnknownOptionThrows: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_capture_dashboard:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
