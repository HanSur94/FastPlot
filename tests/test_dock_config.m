function test_dock_config()
%TEST_DOCK_CONFIG Tests for config integration in FastPlotDock.

    add_private_path();

    % testDockLoadsDefaults
    dock = FastPlotDock();
    assert(dock.TabBarHeight == 0.03, 'testDockDefaults: TabBarHeight');
    close(dock.hFigure);

    % testDockDefaultTheme
    dock = FastPlotDock();
    assert(isstruct(dock.Theme), 'testDockDefaultTheme: has theme');
    close(dock.hFigure);

    % testDockCustomTheme
    dock = FastPlotDock('Theme', 'dark');
    assert(all(dock.Theme.Background < [0.2 0.2 0.2]), 'testDockCustomTheme: dark bg');
    close(dock.hFigure);

    fprintf('    All 3 dock config tests passed.\n');
end
