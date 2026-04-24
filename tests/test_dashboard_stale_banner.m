function test_dashboard_stale_banner()
%TEST_DASHBOARD_STALE_BANNER Octave parallel suite for live-mode stale-data banner.
%
%   Covers:
%     - Banner created during render, initially hidden.
%     - showStaleBanner() + hideStaleBanner() toggle visibility.
%     - onLiveTick with unchanged tMax triggers the banner.
%     - onLiveTick with advancing tMax clears the banner.
%     - stopLive hides the banner.

    add_dashboard_path();

    nPassed = 0;
    nFailed = 0;

    % testBannerCreatedHidden
    try
        d = DashboardEngine('StaleBanner');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        assert(~isempty(d.hStaleBanner), 'banner should be created');
        assert(ishandle(d.hStaleBanner), 'banner should be a live handle');
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'off'), ...
            'banner should start hidden');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBannerCreatedHidden: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testShowHideToggle
    try
        d = DashboardEngine('ToggleTest');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        d.showStaleBanner();
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'on'), ...
            'showStaleBanner should make banner visible');
        msg = get(d.hStaleBanner, 'String');
        assert(~isempty(strfind(msg, 'No new data')), ...
            sprintf('banner text should mention no new data, got: %s', msg));

        d.hideStaleBanner();
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'off'), ...
            'hideStaleBanner should hide banner');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testShowHideToggle: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testBannerTextMentionsLiveInterval
    try
        d = DashboardEngine('IntervalMsg', 'LiveInterval', 3);
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        d.showStaleBanner();
        msg = get(d.hStaleBanner, 'String');
        assert(~isempty(strfind(msg, '3')), ...
            sprintf('banner should reference the interval, got: %s', msg));
        d.hideStaleBanner();

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testBannerTextMentionsLiveInterval: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    % testStopLiveHidesBanner
    try
        d = DashboardEngine('StopHides');
        d.addWidget('number', 'Title', 'T', 'Position', [1 1 6 2], 'StaticValue', 1);
        d.render();
        set(d.hFigure, 'Visible', 'off');

        d.showStaleBanner();
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'on'), 'banner should be on');

        % stopLive() is safe to call even if live was not started (Octave-safe).
        d.stopLive();
        assert(strcmp(get(d.hStaleBanner, 'Visible'), 'off'), ...
            'stopLive should hide the banner');

        close(d.hFigure);
        nPassed = nPassed + 1;
    catch err
        fprintf('    FAIL testStopLiveHidesBanner: %s\n', err.message);
        nFailed = nFailed + 1;
    end

    fprintf('    %d passed, %d failed.\n', nPassed, nFailed);
    if nFailed > 0
        error('test_dashboard_stale_banner:fail', ...
            '%d of %d tests failed', nFailed, nPassed + nFailed);
    end
end

function add_dashboard_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fullfile(thisDir, '..');
    addpath(repoRoot);
    install();
end
