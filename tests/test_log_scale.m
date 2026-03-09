function test_log_scale()
%TEST_LOG_SCALE Tests for logarithmic axis support.

    add_private_path();

    % testDefaultScale
    fp = FastPlot();
    assert(strcmp(fp.XScale, 'linear'), 'testDefaultScale: XScale');
    assert(strcmp(fp.YScale, 'linear'), 'testDefaultScale: YScale');

    % testConstructorYScale
    fp = FastPlot('YScale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testConstructorYScale');
    assert(strcmp(fp.XScale, 'linear'), 'testConstructorYScale: XScale unchanged');

    % testConstructorXScale
    fp = FastPlot('XScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testConstructorXScale');

    % testConstructorBothScales
    fp = FastPlot('XScale', 'log', 'YScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testConstructorBothScales: X');
    assert(strcmp(fp.YScale, 'log'), 'testConstructorBothScales: Y');

    fprintf('    All 4 log_scale property tests passed.\n');

    % testRenderAppliesYScale
    fp = FastPlot('YScale', 'log');
    fp.addLine(1:100, rand(1,100) * 100 + 1);
    fp.render();
    assert(strcmp(get(fp.hAxes, 'YScale'), 'log'), 'testRenderAppliesYScale');
    close(fp.hFigure);

    % testRenderAppliesXScale
    fp = FastPlot('XScale', 'log');
    fp.addLine(logspace(0, 3, 100), rand(1,100));
    fp.render();
    assert(strcmp(get(fp.hAxes, 'XScale'), 'log'), 'testRenderAppliesXScale');
    close(fp.hFigure);

    % testRenderAppliesLogLog
    fp = FastPlot('XScale', 'log', 'YScale', 'log');
    fp.addLine(logspace(0, 3, 100), rand(1,100) * 100 + 1);
    fp.render();
    assert(strcmp(get(fp.hAxes, 'XScale'), 'log'), 'testRenderAppliesLogLog: X');
    assert(strcmp(get(fp.hAxes, 'YScale'), 'log'), 'testRenderAppliesLogLog: Y');
    close(fp.hFigure);

    % testLinearScaleDefault
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    assert(strcmp(get(fp.hAxes, 'XScale'), 'linear'), 'testLinearScaleDefault: X');
    assert(strcmp(get(fp.hAxes, 'YScale'), 'linear'), 'testLinearScaleDefault: Y');
    close(fp.hFigure);

    fprintf('    All 4 render log_scale tests passed.\n');

    % testSetScaleYLog
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100) * 100 + 1);
    fp.render();
    fp.setScale('YScale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testSetScaleYLog: property');
    assert(strcmp(get(fp.hAxes, 'YScale'), 'log'), 'testSetScaleYLog: axes');
    close(fp.hFigure);

    % testSetScaleXLog
    fp = FastPlot();
    fp.addLine(logspace(0, 3, 100), rand(1,100));
    fp.render();
    fp.setScale('XScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testSetScaleXLog: property');
    assert(strcmp(get(fp.hAxes, 'XScale'), 'log'), 'testSetScaleXLog: axes');
    close(fp.hFigure);

    % testSetScaleBoth
    fp = FastPlot('YScale', 'log');
    fp.addLine(logspace(0, 3, 100), rand(1,100) * 100 + 1);
    fp.render();
    fp.setScale('XScale', 'log', 'YScale', 'linear');
    assert(strcmp(fp.XScale, 'log'), 'testSetScaleBoth: X');
    assert(strcmp(fp.YScale, 'linear'), 'testSetScaleBoth: Y');
    close(fp.hFigure);

    % testSetScaleBeforeRender
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100) * 100 + 1);
    fp.setScale('YScale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testSetScaleBeforeRender: property set');
    fp.render();
    assert(strcmp(get(fp.hAxes, 'YScale'), 'log'), 'testSetScaleBeforeRender: applied');
    close(fp.hFigure);

    % testSetScaleInvalidValue
    fp = FastPlot();
    threw = false;
    try
        fp.setScale('YScale', 'invalid');
    catch
        threw = true;
    end
    assert(threw, 'testSetScaleInvalidValue: should error');

    fprintf('    All 5 setScale tests passed.\n');
end
