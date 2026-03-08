function test_config_integration()
%TEST_CONFIG_INTEGRATION Tests for config management integration in FastPlot.

    add_private_path();

    % testConstructorLoadsDefaults
    fp = FastPlot();
    assert(fp.MinPointsForDownsample == 5000, 'testConstructorDefaults: MinPointsForDownsample');
    assert(fp.DownsampleFactor == 2, 'testConstructorDefaults: DownsampleFactor');
    assert(fp.PyramidReduction == 100, 'testConstructorDefaults: PyramidReduction');

    % testConstructorOverrideConstants
    fp = FastPlot('MinPointsForDownsample', 10000, 'DownsampleFactor', 4);
    assert(fp.MinPointsForDownsample == 10000, 'testOverrideConstants: MinPointsForDownsample');
    assert(fp.DownsampleFactor == 4, 'testOverrideConstants: DownsampleFactor');

    % testResetColorIndex
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    c2 = fp.Lines(2).Options.Color;
    fp.resetColorIndex();
    fp.addLine(1:10, rand(1,10));
    c3 = fp.Lines(3).Options.Color;
    % After reset, next color should be the first palette color again
    expected = fp.Theme.LineColorOrder(1, :);
    assert(isequal(c3, expected), 'testResetColorIndex: color resets to first');

    % testReapplyTheme
    fp = FastPlot('Theme', 'default');
    fp.addLine(1:100, rand(1,100));
    fp.render();
    fp.Theme = FastPlotTheme('dark');
    fp.reapplyTheme();
    bgColor = get(fp.hFigure, 'Color');
    assert(all(bgColor < [0.2 0.2 0.2]), 'testReapplyTheme: figure bg updated to dark');
    axColor = get(fp.hAxes, 'Color');
    assert(all(axColor < [0.25 0.25 0.25]), 'testReapplyTheme: axes bg updated to dark');
    close(fp.hFigure);

    % testReapplyThemeBeforeRender — should not error
    fp = FastPlot('Theme', 'default');
    fp.Theme = FastPlotTheme('dark');
    fp.reapplyTheme();  % no-op before render, should not error

    % testVerboseWarnsOnUnknownKey
    lastwarn('');
    fp = FastPlot('Verbose', true);
    fp.addThreshold(5.0, 'Colr', [1 0 0]);
    [warnMsg, ~] = lastwarn();
    assert(~isempty(warnMsg), 'testVerboseWarning: should warn on Colr');

    % testSilentOnUnknownKeyByDefault
    lastwarn('');
    fp = FastPlot();
    fp.addThreshold(5.0, 'Colr', [1 0 0]);
    [warnMsg, ~] = lastwarn();
    assert(isempty(warnMsg), 'testSilent: no warn by default');

    % testBackwardCompatibility — existing API still works identically
    fp = FastPlot('Theme', 'dark', 'Verbose', true);
    fp.addLine(1:100, rand(1,100), 'Color', [1 0 0], 'DisplayName', 'Test');
    fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', [0 1 0]);
    fp.addBand(0.2, 0.8, 'FaceColor', [0.9 0.9 0.9], 'FaceAlpha', 0.3);
    fp.addMarker(50, 0.5, 'Marker', 'v', 'MarkerSize', 8);
    fp.addShaded(1:100, rand(1,100), zeros(1,100), 'FaceColor', [0 0 1]);
    fp.render();
    assert(ishandle(fp.hAxes), 'testBackwardCompat: renders ok');
    assert(isequal(fp.Lines(1).Options.Color, [1 0 0]), 'testBackwardCompat: line color');
    assert(isequal(fp.Thresholds(1).Color, [0 1 0]), 'testBackwardCompat: threshold color');
    assert(fp.Thresholds(1).ShowViolations == true, 'testBackwardCompat: showviolations');
    close(fp.hFigure);

    % testAddLinePassthroughOptions — unknown keys in addLine pass through to line handle
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'Signal', 'LineWidth', 2);
    assert(isfield(fp.Lines(1).Options, 'DisplayName'), 'testPassthrough: DisplayName');
    assert(isfield(fp.Lines(1).Options, 'LineWidth'), 'testPassthrough: LineWidth');

    % testDefaultDownsampleMethod
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    assert(strcmp(fp.Lines(1).DownsampleMethod, 'minmax'), 'testDefaultDS: minmax');

    fprintf('    All 10 config integration tests passed.\n');
end
