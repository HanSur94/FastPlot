function test_add_marker()
%TEST_ADD_MARKER Tests for FastPlot.addMarker method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    % testAddMarker
    fp = FastPlot();
    fp.addMarker([10 20 30], [1 2 3], 'Marker', 'v', 'Color', [1 0 0], 'Label', 'Faults');
    assert(numel(fp.Markers) == 1, 'testAddMarker: count');
    assert(isequal(fp.Markers(1).X, [10 20 30]), 'testAddMarker: X');
    assert(strcmp(fp.Markers(1).Label, 'Faults'), 'testAddMarker: Label');

    % testMarkerRendered
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.addMarker([10 50], [0.5 0.8], 'Marker', 'd', 'MarkerSize', 10);
    fp.render();
    assert(~isempty(fp.Markers(1).hLine), 'testMarkerRendered: hLine');
    assert(ishandle(fp.Markers(1).hLine), 'testMarkerRendered: valid handle');
    ud = get(fp.Markers(1).hLine, 'UserData');
    assert(strcmp(ud.FastPlot.Type, 'marker'), 'testMarkerRendered: UserData type');
    close(fp.hFigure);

    % testMarkerDefaults
    fp = FastPlot();
    fp.addMarker([5], [1]);
    assert(~isempty(fp.Markers(1).Marker), 'testMarkerDefaults: Marker shape');
    assert(fp.Markers(1).MarkerSize > 0, 'testMarkerDefaults: MarkerSize');

    % testMarkerRejectsAfterRender
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.render();
    threw = false;
    try
        fp.addMarker([1], [1]);
    catch
        threw = true;
    end
    assert(threw, 'testMarkerRejectsAfterRender');
    close(fp.hFigure);

    % testMarkerColumnVectors — column vectors converted to rows
    fp = FastPlot();
    fp.addMarker((1:5)', (1:5)');
    assert(isrow(fp.Markers(1).X), 'testMarkerColumnVectors: X is row');
    assert(isrow(fp.Markers(1).Y), 'testMarkerColumnVectors: Y is row');

    % testMarkerDefaultMatchesTheme
    fp = FastPlot();
    fp.addMarker([1], [1]);
    assert(isequal(fp.Markers(1).Color, fp.Theme.ThresholdColor), ...
        'testMarkerDefaultMatchesTheme: Color');
    assert(strcmp(fp.Markers(1).Marker, 'o'), 'testMarkerDefaultMatchesTheme: shape');
    assert(fp.Markers(1).MarkerSize == 6, 'testMarkerDefaultMatchesTheme: size');

    % testMultipleMarkerGroups
    fp = FastPlot();
    fp.addMarker([1 2], [3 4], 'Label', 'Group A');
    fp.addMarker([5 6], [7 8], 'Marker', 'd', 'Label', 'Group B');
    assert(numel(fp.Markers) == 2, 'testMultipleMarkerGroups: count');
    assert(strcmp(fp.Markers(1).Label, 'Group A'), 'testMultipleMarkerGroups: label 1');
    assert(strcmp(fp.Markers(2).Label, 'Group B'), 'testMultipleMarkerGroups: label 2');

    % testSingleMarkerPoint
    fp = FastPlot();
    fp.addMarker(42, 7);
    assert(numel(fp.Markers(1).X) == 1, 'testSingleMarkerPoint: single X');

    fprintf('    All 8 addMarker tests passed.\n');
end
