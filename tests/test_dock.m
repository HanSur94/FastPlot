function test_dock()
%TEST_DOCK Tests for FastPlotDock tabbed container.

    add_private_path();
    close all force;
    drawnow;

    % testConstruction
    dock = FastPlotDock('Theme', 'dark', 'Name', 'Test Dock');
    assert(~isempty(dock.hFigure), 'testConstruction: hFigure');
    assert(ishandle(dock.hFigure), 'testConstruction: hFigure valid');
    assert(strcmp(get(dock.hFigure, 'Name'), 'Test Dock'), 'testConstruction: Name');
    close(dock.hFigure);

    % testDefaultTheme
    dock = FastPlotDock();
    assert(~isempty(dock.Theme), 'testDefaultTheme: should have theme');
    close(dock.hFigure);

    % testAddTab
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(2, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    fp = fig1.tile(2); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Dashboard 1');
    assert(numel(dock.Tabs) == 1, 'testAddTab: 1 tab');
    assert(strcmp(dock.Tabs(1).Name, 'Dashboard 1'), 'testAddTab: name');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Dashboard 2');
    assert(numel(dock.Tabs) == 2, 'testAddTab: 2 tabs');
    close(dock.hFigure);

    % testRender
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');

    dock.render();
    assert(dock.ActiveTab == 1, 'testRender: first tab active');
    assert(strcmp(get(dock.hFigure, 'Visible'), 'on'), 'testRender: figure visible');
    assert(numel(dock.hTabButtons) == 2, 'testRender: 2 tab buttons');
    % Tab A tiles should be on-screen
    posA = get(fig1.tile(1).hAxes, 'Position');
    assert(posA(1) >= 0, 'testRender: tab A on-screen');
    % Tab B tiles should be off-screen
    posB = get(fig2.tile(1).hAxes, 'Position');
    assert(posB(1) < 0, 'testRender: tab B off-screen');
    close(dock.hFigure);

    % testSelectTab
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');
    dock.render();

    % Switch to tab 2
    dock.selectTab(2);
    assert(dock.ActiveTab == 2, 'testSelectTab: active is 2');
    posA = get(fig1.tile(1).hAxes, 'Position');
    posB = get(fig2.tile(1).hAxes, 'Position');
    assert(posA(1) < 0, 'testSelectTab: tab A off-screen');
    assert(posB(1) >= 0, 'testSelectTab: tab B on-screen');

    % Switch back to tab 1
    dock.selectTab(1);
    assert(dock.ActiveTab == 1, 'testSelectTab: active is 1');
    posA = get(fig1.tile(1).hAxes, 'Position');
    posB = get(fig2.tile(1).hAxes, 'Position');
    assert(posA(1) >= 0, 'testSelectTab: tab A on-screen again');
    assert(posB(1) < 0, 'testSelectTab: tab B off-screen again');
    close(dock.hFigure);

    % testSelectTabOutOfBounds
    dock = FastPlotDock();
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Only Tab');
    dock.render();
    threw = false;
    try
        dock.selectTab(5);
    catch
        threw = true;
    end
    assert(threw, 'testSelectTabOutOfBounds: should error');
    close(dock.hFigure);

    % testResize
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');
    dock.render();
    posBefore = get(fig1.tile(1).hAxes, 'Position');
    % Simulate resize by calling the recompute method
    dock.recomputeLayout();
    posAfter = get(fig1.tile(1).hAxes, 'Position');
    % Positions should remain consistent (no crash)
    assert(abs(posBefore(1) - posAfter(1)) < 0.01, 'testResize: x stable');
    assert(abs(posBefore(2) - posAfter(2)) < 0.01, 'testResize: y stable');
    close(dock.hFigure);

    % testCloseStopsLive
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:100, zeros(1,100));
    dock.addTab(fig1, 'Live Tab');
    dock.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = rand(1,100);
    save(tmpFile, '-struct', 's');
    fig1.startLive(tmpFile, @(f,d) f.tile(1).updateData(1, d.x, d.y), 'Interval', 1.0);
    assert(fig1.LiveIsActive, 'testCloseStopsLive: live active before close');

    close(dock.hFigure);
    assert(~fig1.LiveIsActive, 'testCloseStopsLive: live stopped after close');
    delete(tmpFile);

    % testAddTabAfterRender
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');
    dock.render();

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');

    assert(numel(dock.Tabs) == 2, 'testAddTabAfterRender: 2 tabs');
    assert(numel(dock.hTabButtons) == 2, 'testAddTabAfterRender: 2 buttons');
    % New tab should be off-screen (first tab still active)
    posB = get(fig2.tile(1).hAxes, 'Position');
    assert(posB(1) < 0, 'testAddTabAfterRender: new tab off-screen');
    % Switch to it
    dock.selectTab(2);
    posB = get(fig2.tile(1).hAxes, 'Position');
    assert(posB(1) >= 0, 'testAddTabAfterRender: new tab on-screen');
    close(dock.hFigure);

    fprintf('    All 9 dock tests passed.\n');
end
