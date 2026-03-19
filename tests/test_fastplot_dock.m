function test_fastplot_dock()
%TEST_FASTPLOT_DOCK Tests for FastPlotDock class.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testConstructorDefault
    dock = FastPlotDock('Visible', 'off');
    assert(~isempty(dock.hFigure), 'testConstructorDefault: has figure');
    assert(ishandle(dock.hFigure), 'testConstructorDefault: valid handle');
    assert(~isempty(dock.Theme), 'testConstructorDefault: has theme');
    delete(dock);

    % testConstructorWithTheme
    dock = FastPlotDock('Theme', 'dark', 'Visible', 'off');
    assert(~isempty(dock.Theme), 'testConstructorWithTheme: has theme');
    delete(dock);

    % testAddTab
    dock = FastPlotDock('Visible', 'off');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fig1.tile(1).addLine(1:10, rand(1,10));
    dock.addTab(fig1, 'Tab 1');
    assert(numel(dock.Tabs) == 1, 'testAddTab: one tab');
    assert(strcmp(dock.Tabs(1).Name, 'Tab 1'), 'testAddTab: name');
    delete(dock);

    % testAddMultipleTabs
    dock = FastPlotDock('Visible', 'off');
    for i = 1:3
        fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
        fig.tile(1).addLine(1:10, rand(1,10));
        dock.addTab(fig, sprintf('Tab %d', i));
    end
    assert(numel(dock.Tabs) == 3, 'testAddMultipleTabs: three tabs');
    delete(dock);

    % testRenderWithNoTabs
    dock = FastPlotDock('Visible', 'off');
    dock.render();  % should not crash
    assert(true, 'testRenderWithNoTabs: no error');
    delete(dock);

    % testRenderLazy
    dock = FastPlotDock('Visible', 'off');
    for i = 1:2
        fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
        fig.tile(1).addLine(1:10, rand(1,10));
        dock.addTab(fig, sprintf('Tab %d', i));
    end
    dock.render();
    assert(dock.ActiveTab == 1, 'testRenderLazy: tab 1 active');
    assert(dock.Tabs(1).IsRendered, 'testRenderLazy: tab 1 rendered');
    delete(dock);

    % testSelectTabOutOfBounds
    dock = FastPlotDock('Visible', 'off');
    fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fig.tile(1).addLine(1:10, rand(1,10));
    dock.addTab(fig, 'Tab 1');
    dock.render();
    threw = false;
    try
        dock.selectTab(5);
    catch
        threw = true;
    end
    assert(threw, 'testSelectTabOutOfBounds: error thrown');
    delete(dock);

    % testSelectTabSwitch
    dock = FastPlotDock('Visible', 'off');
    for i = 1:3
        fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
        fig.tile(1).addLine(1:10, rand(1,10));
        dock.addTab(fig, sprintf('Tab %d', i));
    end
    dock.render();
    dock.selectTab(2);
    assert(dock.ActiveTab == 2, 'testSelectTabSwitch: tab 2 active');
    dock.selectTab(3);
    assert(dock.ActiveTab == 3, 'testSelectTabSwitch: tab 3 active');
    delete(dock);

    % testRemoveTab
    dock = FastPlotDock('Visible', 'off');
    for i = 1:3
        fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
        fig.tile(1).addLine(1:10, rand(1,10));
        dock.addTab(fig, sprintf('Tab %d', i));
    end
    dock.render();
    dock.removeTab(2);
    assert(numel(dock.Tabs) == 2, 'testRemoveTab: two tabs remain');
    delete(dock);

    % testRemoveActiveTab
    dock = FastPlotDock('Visible', 'off');
    for i = 1:3
        fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
        fig.tile(1).addLine(1:10, rand(1,10));
        dock.addTab(fig, sprintf('Tab %d', i));
    end
    dock.render();
    dock.selectTab(2);
    dock.removeTab(2);
    assert(numel(dock.Tabs) == 2, 'testRemoveActiveTab: two tabs remain');
    assert(dock.ActiveTab >= 1, 'testRemoveActiveTab: valid active tab');
    delete(dock);

    % testRemoveAllTabs
    dock = FastPlotDock('Visible', 'off');
    fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fig.tile(1).addLine(1:10, rand(1,10));
    dock.addTab(fig, 'Only Tab');
    dock.render();
    dock.removeTab(1);
    assert(isempty(dock.Tabs), 'testRemoveAllTabs: no tabs');
    assert(dock.ActiveTab == 0, 'testRemoveAllTabs: no active tab');
    delete(dock);

    % testRemoveOutOfBounds — should be no-op
    dock = FastPlotDock('Visible', 'off');
    fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fig.tile(1).addLine(1:10, rand(1,10));
    dock.addTab(fig, 'Tab 1');
    dock.render();
    dock.removeTab(99);  % out of bounds — no-op
    assert(numel(dock.Tabs) == 1, 'testRemoveOutOfBounds: tab remains');
    delete(dock);

    % testReapplyTheme
    dock = FastPlotDock('Theme', 'dark', 'Visible', 'off');
    fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fig.tile(1).addLine(1:10, rand(1,10));
    dock.addTab(fig, 'Tab 1');
    dock.render();
    dock.reapplyTheme();  % should not crash
    assert(true, 'testReapplyTheme: no error');
    delete(dock);

    % testRenderAllNoTabs
    dock = FastPlotDock('Visible', 'off');
    dock.renderAll();  % should not crash
    assert(true, 'testRenderAllNoTabs: no error');
    delete(dock);

    % testRenderAll
    dock = FastPlotDock('Visible', 'off');
    dock.ShowProgress = false;
    for i = 1:2
        fig = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
        fig.tile(1).addLine(1:10, rand(1,10));
        dock.addTab(fig, sprintf('Tab %d', i));
    end
    dock.renderAll();
    assert(dock.Tabs(1).IsRendered, 'testRenderAll: tab 1 rendered');
    assert(dock.Tabs(2).IsRendered, 'testRenderAll: tab 2 rendered');
    assert(dock.ActiveTab == 1, 'testRenderAll: tab 1 active');
    delete(dock);

    % testTabBarHeight
    dock = FastPlotDock('Visible', 'off');
    cfg = FastPlotDefaults();
    assert(dock.TabBarHeight == cfg.TabBarHeight, 'testTabBarHeight: matches defaults');
    delete(dock);

    fprintf('    All 16 FastPlotDock tests passed.\n');
end
