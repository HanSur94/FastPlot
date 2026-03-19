function test_add_line_extended()
%TEST_ADD_LINE_EXTENDED Extended edge-case tests for FastPlot.addLine.
%   Supplements the existing test_add_line.m with coverage for paths
%   that were previously untested.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testNaNInY — auto-detection of HasNaN
    fp = FastPlot();
    y = [1 2 NaN 4 5];
    fp.addLine(1:5, y);
    assert(fp.Lines(1).HasNaN == true, 'testNaNInY: HasNaN auto-detected');

    % testNoNaNInY
    fp = FastPlot();
    fp.addLine(1:5, [1 2 3 4 5]);
    assert(fp.Lines(1).HasNaN == false, 'testNoNaNInY: HasNaN false');

    % testHasNaNOverrideTrue
    fp = FastPlot();
    fp.addLine(1:5, [1 2 3 4 5], 'HasNaN', true);
    assert(fp.Lines(1).HasNaN == true, 'testHasNaNOverrideTrue');

    % testHasNaNOverrideFalse
    fp = FastPlot();
    fp.addLine(1:5, [1 NaN 3 4 5], 'HasNaN', false);
    assert(fp.Lines(1).HasNaN == false, 'testHasNaNOverrideFalse');

    % testAssumeSorted — non-monotonic X accepted when AssumeSorted=true
    fp = FastPlot();
    fp.addLine([5 3 1], [1 2 3], 'AssumeSorted', true);
    assert(numel(fp.Lines) == 1, 'testAssumeSorted: line added');

    % testMetadataAttachment
    fp = FastPlot();
    meta = struct('datenum', [1 2 3], 'temp', [20 21 22]);
    fp.addLine(1:3, [10 20 30], 'Metadata', meta);
    assert(isstruct(fp.Lines(1).Metadata), 'testMetadataAttachment: is struct');
    assert(isfield(fp.Lines(1).Metadata, 'datenum'), 'testMetadataAttachment: has datenum');

    % testXTypeExplicit
    fp = FastPlot();
    fp.addLine(1:5, rand(1,5), 'XType', 'datenum');
    assert(strcmp(fp.XType, 'datenum'), 'testXTypeExplicit: XType set');

    % testColorAutoCycling
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:10, rand(1,10));
    c1 = fp.Lines(1).Options.Color;
    c2 = fp.Lines(2).Options.Color;
    c3 = fp.Lines(3).Options.Color;
    assert(~isequal(c1, c2), 'testColorAutoCycling: line 1 != line 2');
    assert(~isequal(c2, c3), 'testColorAutoCycling: line 2 != line 3');

    % testIsStaticFlagSmallData
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    assert(fp.Lines(1).IsStatic == true, 'testIsStaticFlagSmallData: small data is static');

    % testIsStaticFlagLargeData
    fp = FastPlot();
    n = fp.MinPointsForDownsample + 1;
    fp.addLine(1:n, rand(1,n));
    assert(fp.Lines(1).IsStatic == false, 'testIsStaticFlagLargeData: large data not static');

    % testColumnVectorConversion
    fp = FastPlot();
    fp.addLine((1:10)', (1:10)');
    assert(isrow(fp.Lines(1).X), 'testColumnVectorConversion: X is row');
    assert(isrow(fp.Lines(1).Y), 'testColumnVectorConversion: Y is row');

    % testNaNInXMonotonicity — NaN gaps in X should not fail monotonicity check
    fp = FastPlot();
    x = [1 2 3 NaN 5 6 7];
    y = [1 2 3 4 5 6 7];
    fp.addLine(x, y);
    assert(numel(fp.Lines) == 1, 'testNaNInXMonotonicity: accepted');

    % testSinglePoint
    fp = FastPlot();
    fp.addLine(1, 5);
    assert(numel(fp.Lines(1).X) == 1, 'testSinglePoint: single element');

    % testExplicitColor
    fp = FastPlot();
    fp.addLine(1:5, rand(1,5), 'Color', [0.5 0.5 0.5]);
    assert(isequal(fp.Lines(1).Options.Color, [0.5 0.5 0.5]), 'testExplicitColor');

    % testDownsampleMethodLTTB
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10), 'DownsampleMethod', 'lttb');
    assert(strcmp(fp.Lines(1).DownsampleMethod, 'lttb'), 'testDownsampleMethodLTTB');

    fprintf('    All 15 addLine extended tests passed.\n');
end
