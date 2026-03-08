function test_figure_config()
%TEST_FIGURE_CONFIG Tests for config integration in FastPlotFigure.

    add_private_path();

    % testFigureLoadsDefaults
    fig = FastPlotFigure(2, 2);
    assert(fig.Padding == 0.06, 'testFigureDefaults: Padding');
    assert(fig.GapH == 0.05, 'testFigureDefaults: GapH');
    assert(fig.GapV == 0.07, 'testFigureDefaults: GapV');
    close(fig.hFigure);

    % testFigureDefaultTheme
    fig = FastPlotFigure(1, 1);
    assert(isstruct(fig.Theme), 'testFigureDefaultTheme: has theme');
    close(fig.hFigure);

    % testFigureCustomTheme
    fig = FastPlotFigure(1, 1, 'Theme', 'dark');
    assert(all(fig.Theme.Background < [0.2 0.2 0.2]), 'testFigureCustomTheme: dark bg');
    close(fig.hFigure);

    % testBackwardCompatibility — existing figure API works
    fig = FastPlotFigure(2, 2, 'Theme', 'dark');
    fp = fig.tile(1);
    fp.addLine(1:100, rand(1,100));
    fig.tileTitle(1, 'Test');
    fig.renderAll();
    assert(ishandle(fig.hFigure), 'testBackwardCompat: figure created');
    close(fig.hFigure);

    fprintf('    All 4 figure config tests passed.\n');
end
