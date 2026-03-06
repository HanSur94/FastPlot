function test_figure_layout()
%TEST_FIGURE_LAYOUT Tests for FastPlotFigure layout manager.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testConstruction
    fig = FastPlotFigure(2, 3);
    assert(isequal(fig.Grid, [2 3]), 'testConstruction: Grid');
    assert(~isempty(fig.hFigure), 'testConstruction: hFigure');
    assert(ishandle(fig.hFigure), 'testConstruction: hFigure valid');
    close(fig.hFigure);

    % testTileReturnsFastPlot
    fig = FastPlotFigure(2, 1);
    fp = fig.tile(1);
    assert(isa(fp, 'FastPlot'), 'testTileReturnsFastPlot');
    close(fig.hFigure);

    % testTileLazy
    fig = FastPlotFigure(2, 1);
    fp1a = fig.tile(1);
    fp1b = fig.tile(1);
    % In Octave, handle == isn't always defined; check axes handle identity
    fp1a.addLine(1:10, rand(1,10));
    assert(numel(fp1b.Lines) == 1, 'testTileLazy: same object on repeat call');
    close(fig.hFigure);

    % testTileCreatesAxes
    fig = FastPlotFigure(2, 1);
    fp = fig.tile(1);
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(~isempty(fp.hAxes), 'testTileCreatesAxes: axes exist');
    assert(ishandle(fp.hAxes), 'testTileCreatesAxes: axes valid');
    close(fig.hFigure);

    % testMultipleTiles
    fig = FastPlotFigure(2, 2);
    for i = 1:4
        fp = fig.tile(i);
        fp.addLine(1:50, rand(1,50));
    end
    fig.renderAll();
    for i = 1:4
        fp = fig.tile(i);
        assert(fp.IsRendered, sprintf('testMultipleTiles: tile %d rendered', i));
    end
    close(fig.hFigure);

    % testRenderAllSkipsRendered
    fig = FastPlotFigure(2, 1);
    fp1 = fig.tile(1);
    fp1.addLine(1:10, rand(1,10));
    fp1.render();
    fp2 = fig.tile(2);
    fp2.addLine(1:10, rand(1,10));
    fig.renderAll();  % should not error on already-rendered tile 1
    assert(fp2.IsRendered, 'testRenderAllSkipsRendered: tile 2');
    close(fig.hFigure);

    % testOutOfBoundsTileErrors
    fig = FastPlotFigure(2, 2);
    threw = false;
    try
        fig.tile(5);  % only 4 tiles in 2x2
    catch
        threw = true;
    end
    assert(threw, 'testOutOfBoundsTileErrors');
    close(fig.hFigure);

    fprintf('    All 7 figure layout tests passed.\n');
end
