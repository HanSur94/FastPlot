function test_dashboard_multipage_render()
%TEST_DASHBOARD_MULTIPAGE_RENDER Regression tests for multi-page DashboardLayout/Engine.
%
%   Tests:
%     test_ensure_viewport_idempotent    - ensureViewport reuses existing viewport handle
%     test_allocate_panels_additive      - allocatePanels does not destroy earlier panels
%     test_total_rows_accumulates        - TotalRows accumulates across additive calls
%     test_render_preserves_all_pages    - DashboardEngine.render leaves all pages' hPanels alive
%     test_on_live_tick_dead_handle      - onLiveTick recovers from deleted widget hPanel
%     test_no_refresh_error_on_dead_handle - onLiveTick does not emit refreshError on dead handle

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    close all force;
    drawnow;

    tests = {
        @test_ensure_viewport_idempotent
        @test_allocate_panels_additive
        @test_total_rows_accumulates
        @test_render_preserves_all_pages
        @test_on_live_tick_dead_handle
        @test_no_refresh_error_on_dead_handle
    };

    passed = 0;
    failed = 0;
    failures = {};

    for i = 1:numel(tests)
        name = func2str(tests{i});
        try
            tests{i}();
            passed = passed + 1;
            fprintf('    %s: PASS\n', name);
        catch ME
            failed = failed + 1;
            failures{end+1} = sprintf('%s: %s', name, ME.message);
            fprintf('    %s: FAIL: %s\n', name, ME.message);
        end
        close all force;
        drawnow;
    end

    fprintf('\n    %d/%d tests passed.\n', passed, passed + failed);
    if failed > 0
        error('test_dashboard_multipage_render:failed', ...
            '%d test(s) failed:\n  %s', failed, strjoin(failures, '\n  '));
    end
end

% -------------------------------------------------------------------------
% Test 1a: ensureViewport is idempotent
% -------------------------------------------------------------------------
function test_ensure_viewport_idempotent()
    layout = DashboardLayout();
    layout.ContentArea = [0, 0, 1, 1];
    hFig = figure('Visible', 'off');
    theme = DashboardTheme('dark');
    layout.ensureViewport(hFig, theme);
    vp1 = layout.hViewport;
    assert(~isempty(vp1) && ishandle(vp1), 'viewport must be created on first call');
    layout.ensureViewport(hFig, theme);
    assert(layout.hViewport == vp1, 'ensureViewport must reuse existing viewport handle');
    assert(ishandle(vp1), 'viewport must remain alive after second ensureViewport call');
    delete(hFig);
end

% -------------------------------------------------------------------------
% Test 1b: additive allocatePanels preserves earlier widgets' hPanels
% -------------------------------------------------------------------------
function test_allocate_panels_additive()
    layout = DashboardLayout();
    layout.ContentArea = [0, 0, 1, 1];
    hFig = figure('Visible', 'off');
    theme = DashboardTheme('dark');
    layout.ensureViewport(hFig, theme);
    w1 = NumberWidget('Title', 'A', 'Position', [1 1 6 2]);
    w2 = NumberWidget('Title', 'B', 'Position', [1 3 6 2]);
    layout.allocatePanels(hFig, {w1}, theme);
    panel1 = w1.hPanel;
    assert(~isempty(panel1) && ishandle(panel1), 'w1.hPanel must be valid after first allocatePanels');
    layout.allocatePanels(hFig, {w2}, theme);
    assert(ishandle(panel1), 'page-1 panel must survive page-2 allocation (additive behaviour)');
    assert(~isempty(w2.hPanel) && ishandle(w2.hPanel), 'w2.hPanel must be valid after second allocatePanels');
    delete(hFig);
end

% -------------------------------------------------------------------------
% Test 1c: TotalRows accumulates across additive calls
% -------------------------------------------------------------------------
function test_total_rows_accumulates()
    layout = DashboardLayout();
    layout.ContentArea = [0, 0, 1, 1];
    hFig = figure('Visible', 'off');
    theme = DashboardTheme('dark');
    layout.ensureViewport(hFig, theme);
    w1 = NumberWidget('Position', [1 1 6 2]);  % ends at row 2
    w2 = NumberWidget('Position', [1 5 6 3]);  % ends at row 7
    layout.allocatePanels(hFig, {w1}, theme);
    layout.allocatePanels(hFig, {w2}, theme);
    assert(layout.TotalRows >= 7, ...
        sprintf('TotalRows should accumulate to >=7, got %d', layout.TotalRows));
    delete(hFig);
end

% -------------------------------------------------------------------------
% Test 1d: multi-page DashboardEngine.render leaves active-page hPanels valid
% -------------------------------------------------------------------------
function test_render_preserves_all_pages()
    engine = DashboardEngine('Test', 'Theme', 'dark');
    engine.addPage('P1');
    engine.addWidget(NumberWidget('Title', 'W1', 'Position', [1 1 6 2]));
    engine.addPage('P2');
    engine.switchPage(2);
    engine.addWidget(NumberWidget('Title', 'W2', 'Position', [1 1 6 2]));
    engine.addPage('P3');
    engine.switchPage(3);
    engine.addWidget(NumberWidget('Title', 'W3', 'Position', [1 1 6 2]));
    engine.switchPage(1);
    engine.render();
    p1w = engine.Pages{1}.Widgets{1};
    p2w = engine.Pages{2}.Widgets{1};
    p3w = engine.Pages{3}.Widgets{1};
    assert(~isempty(p1w.hPanel) && ishandle(p1w.hPanel), ...
        'page-1 hPanel must be alive after render');
    assert(~isempty(p2w.hPanel) && ishandle(p2w.hPanel), ...
        'page-2 hPanel must be alive after render');
    assert(~isempty(p3w.hPanel) && ishandle(p3w.hPanel), ...
        'page-3 hPanel must be alive after render');
    close(engine.hFigure);
end

% -------------------------------------------------------------------------
% Test 3a: onLiveTick recovers when a widget's hPanel is deleted mid-life
% -------------------------------------------------------------------------
function test_on_live_tick_dead_handle()
    engine = DashboardEngine('Live', 'Theme', 'dark');
    engine.addPage('Main');
    w = NumberWidget('Title', 'Victim', 'Position', [1 1 6 2]);
    engine.addWidget(w);
    engine.render();
    assert(~isempty(w.hPanel) && ishandle(w.hPanel), 'hPanel must be valid after render');
    assert(w.Realized == true, 'widget must be realized after render');
    % Simulate cascade-delete of the widget's panel
    delete(w.hPanel);
    assert(~ishandle(w.hPanel), 'hPanel must be deleted');
    % onLiveTick must not throw and must mark widget unrealized
    try
        engine.onLiveTick();
    catch ME
        error('onLiveTick threw on dead hPanel: %s', ME.message);
    end
    assert(w.Realized == false, ...
        'onLiveTick must call markUnrealized on dead hPanel');
    close(engine.hFigure);
end

% -------------------------------------------------------------------------
% Test 3b: no DashboardEngine:refreshError warnings emitted for dead handle
% -------------------------------------------------------------------------
function test_no_refresh_error_on_dead_handle()
    lastwarn('');
    engine = DashboardEngine('Live', 'Theme', 'dark');
    engine.addPage('Main');
    w = NumberWidget('Title', 'Victim', 'Position', [1 1 6 2]);
    engine.addWidget(w);
    engine.render();
    delete(w.hPanel);
    engine.onLiveTick();
    [~, wid] = lastwarn();
    assert(~strcmp(wid, 'DashboardEngine:refreshError'), ...
        'onLiveTick must not emit refreshError on cleanly-guarded dead handles');
    close(engine.hFigure);
end
