function test_dashboard_switch_page_refresh()
%TEST_DASHBOARD_SWITCH_PAGE_REFRESH Regression: switchPage repaints widgets
%   even when their Dirty flag self-cleared on a previous render.
%   Covers HistogramWidget paint, GroupWidget cascade into nested children,
%   and per-widget refresh-failure isolation. Locks in 260508-ny6 fix
%   where widgets like HistogramWidget rendered empty on tab switch
%   because their Dirty flag had self-cleared and switchPage did not
%   re-arm them.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), 'fixtures'));
    install();

    % Skip on headless runtimes that can't construct dashboards
    % (mirrors test_dashboard_engine_event_markers guard).
    if ~probeFigureAvailable()
        fprintf('    test_dashboard_switch_page_refresh skipped: figure unavailable.\n');
        return;
    end

    nPassed = 0;
    nPassed = nPassed + runCase(@() case_switch_page_paints_histogram(),       'paints_histogram');
    nPassed = nPassed + runCase(@() case_switch_page_paints_group_children(),  'paints_group_children');
    nPassed = nPassed + runCase(@() case_switch_page_isolates_failing_widget(),'isolates_failure');
    nPassed = nPassed + runCase(@() case_switch_page_repeated_marks_dirty(),   'repeated_marks_dirty');
    fprintf('    All %d tests passed.\n', nPassed);
end

function n = runCase(fn, name)
    try
        fn();
        n = 1;
    catch err
        fprintf('  CASE %s FAILED: %s\n', name, err.message);
        rethrow(err);
    end
end

function tf = probeFigureAvailable()
    try
        f = figure('Visible', 'off');
        close(f);
        tf = true;
    catch
        tf = false;
    end
end

function closeDashboard(d)
    try
        if ~isempty(d) && ~isempty(d.hFigure) && ishandle(d.hFigure)
            close(d.hFigure);
        end
    catch
    end
end

function s = makeSensor(name, n)
    %MAKESENSOR Build a SensorTag with non-empty Y so HistogramWidget.refresh
    %   does real work (it short-circuits on empty Y).
    s = SensorTag(name, 'Name', name, 'X', (1:n)', 'Y', randn(1, n)');
end

function case_switch_page_paints_histogram()
    d = DashboardEngine('NY6Hist');
    d.addPage('P1');
    d.addWidget(TextWidget('Title', 't1', 'Content', 'hi'));
    d.addPage('P2');
    h = HistogramWidget('Title', 'H', 'Sensor', makeSensor('s1', 200));
    d.addWidget(h);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d)); %#ok<NASGU>
    d.switchPage(2);
    assert(~h.Dirty, ...
        'HistogramWidget.Dirty should be false after switchPage refresh sweep');
    assert(~isempty(h.hAxes) && ishandle(h.hAxes), 'hAxes must exist');
    kids = get(h.hAxes, 'Children');
    assert(~isempty(kids), ...
        'HistogramWidget.hAxes must have content after switchPage');
end

function case_switch_page_paints_group_children()
    d = DashboardEngine('NY6Group');
    d.addPage('P1');
    d.addWidget(TextWidget('Title', 't1', 'Content', 'hi'));
    d.addPage('P2');
    h1 = HistogramWidget('Title', 'H1', 'Sensor', makeSensor('s1', 200));
    h2 = HistogramWidget('Title', 'H2', 'Sensor', makeSensor('s2', 200));
    g  = GroupWidget('Title', 'G', 'Mode', 'panel', 'Label', 'Group');
    g.Children = {h1, h2};
    d.addWidget(g);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d)); %#ok<NASGU>
    d.switchPage(2);
    assert(~h1.Dirty && ~h2.Dirty, ...
        'group children should have Dirty=false after sweep');
    assert(~isempty(get(h1.hAxes, 'Children')) && ...
           ~isempty(get(h2.hAxes, 'Children')), ...
        'group children axes must contain content');
end

function case_switch_page_isolates_failing_widget()
    d = DashboardEngine('NY6Iso');
    d.addPage('P1');
    d.addWidget(TextWidget('Title', 't1', 'Content', 'hi'));
    d.addPage('P2');
    h = HistogramWidget('Title', 'H', 'Sensor', makeSensor('s1', 200));
    d.addWidget(h);
    bad = ThrowingTextWidget('Title', 'BadStub', 'Content', 'x');
    d.addWidget(bad);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d)); %#ok<NASGU>
    d.DebugPreview_ = false;  % suppress warnings during test
    % Must NOT throw even though BadStub.refresh errors
    d.switchPage(2);
    assert(~h.Dirty && ~isempty(get(h.hAxes, 'Children')), ...
        'HistogramWidget must still paint when sibling refresh throws');
end

function case_switch_page_repeated_marks_dirty()
    d = DashboardEngine('NY6Repeat');
    d.addPage('P1');
    d.addWidget(TextWidget('Title', 't1', 'Content', 'hi'));
    d.addPage('P2');
    h = HistogramWidget('Title', 'H', 'Sensor', makeSensor('s1', 200));
    d.addWidget(h);
    d.render();
    cleanup = onCleanup(@() closeDashboard(d)); %#ok<NASGU>
    d.switchPage(2);
    assert(~h.Dirty, 'first switchPage refreshes');
    % Simulate the user-reported "stuck after tab change" scenario:
    % the axes have been emptied (e.g. by a re-layout / re-realize / a
    % theme switch that called cla) and Dirty self-cleared on the prior
    % paint. Without the switchPage refresh sweep, the widget would
    % short-circuit on `if ~obj.Dirty, return; end` and leave the axes
    % visibly empty until the next live tick (or forever, in static mode).
    cla(h.hAxes);
    h.Dirty = false;
    d.switchPage(1);
    d.switchPage(2);  % bug case: would short-circuit without sweep
    assert(~h.Dirty, ...
        'switchPage refresh sweep must re-arm + clear Dirty');
    assert(~isempty(get(h.hAxes, 'Children')), ...
        'switchPage must repaint axes that were emptied while clean');
end
