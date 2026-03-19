function test_set_scale()
%TEST_SET_SCALE Tests for FastPlot.setScale method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testSetYScaleBeforeRender
    fp = FastPlot();
    fp.setScale('YScale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testSetYScaleBeforeRender: YScale');
    assert(strcmp(fp.XScale, 'linear'), 'testSetYScaleBeforeRender: XScale unchanged');

    % testSetXScaleBeforeRender
    fp = FastPlot();
    fp.setScale('XScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testSetXScaleBeforeRender: XScale');
    assert(strcmp(fp.YScale, 'linear'), 'testSetXScaleBeforeRender: YScale unchanged');

    % testSetBothScales
    fp = FastPlot();
    fp.setScale('XScale', 'log', 'YScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testSetBothScales: XScale');
    assert(strcmp(fp.YScale, 'log'), 'testSetBothScales: YScale');

    % testInvalidXScale
    fp = FastPlot();
    threw = false;
    try
        fp.setScale('XScale', 'invalid');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidXScale: error thrown');

    % testInvalidYScale
    fp = FastPlot();
    threw = false;
    try
        fp.setScale('YScale', 'invalid');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidYScale: error thrown');

    % testCaseInsensitiveOption
    fp = FastPlot();
    fp.setScale('yscale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testCaseInsensitiveOption: YScale');

    % testSetScaleAfterRender
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    fp.setScale('YScale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testSetScaleAfterRender: YScale');
    assert(strcmp(get(fp.hAxes, 'YScale'), 'log'), 'testSetScaleAfterRender: axes YScale');
    close(fp.hFigure);

    % testSetScaleAfterRenderBoth
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    fp.setScale('XScale', 'log', 'YScale', 'log');
    assert(strcmp(get(fp.hAxes, 'XScale'), 'log'), 'testSetScaleAfterRenderBoth: XScale');
    assert(strcmp(get(fp.hAxes, 'YScale'), 'log'), 'testSetScaleAfterRenderBoth: YScale');
    close(fp.hFigure);

    % testSetScaleLinearToLinear — no-op, no crash
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    fp.setScale('XScale', 'linear', 'YScale', 'linear');
    assert(strcmp(get(fp.hAxes, 'XScale'), 'linear'), 'testLinearToLinear: XScale');
    close(fp.hFigure);

    fprintf('    All 9 setScale tests passed.\n');
end
