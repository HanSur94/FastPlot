classdef TestAddMarker < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastplot_private_path();
        end
    end

    methods (Test)
        function testAddMarker(testCase)
            fp = FastPlot();
            fp.addMarker([10 20 30], [1 2 3], 'Marker', 'v', 'Color', [1 0 0], 'Label', 'Faults');
            testCase.verifyEqual(numel(fp.Markers), 1, 'testAddMarker: count');
            testCase.verifyEqual(fp.Markers(1).X, [10 20 30], 'testAddMarker: X');
            testCase.verifyEqual(fp.Markers(1).Label, 'Faults', 'testAddMarker: Label');
        end

        function testMarkerRendered(testCase)
            fp = FastPlot();
            fp.addLine(1:100, rand(1,100));
            fp.addMarker([10 50], [0.5 0.8], 'Marker', 'd', 'MarkerSize', 10);
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            testCase.verifyNotEmpty(fp.Markers(1).hLine, 'testMarkerRendered: hLine');
            testCase.verifyTrue(ishandle(fp.Markers(1).hLine), 'testMarkerRendered: valid handle');
            ud = get(fp.Markers(1).hLine, 'UserData');
            testCase.verifyEqual(ud.FastPlot.Type, 'marker', 'testMarkerRendered: UserData type');
        end

        function testMarkerDefaults(testCase)
            fp = FastPlot();
            fp.addMarker([5], [1]);
            testCase.verifyNotEmpty(fp.Markers(1).Marker, 'testMarkerDefaults: Marker shape');
            testCase.verifyTrue(fp.Markers(1).MarkerSize > 0, 'testMarkerDefaults: MarkerSize');
        end

        function testMarkerRejectsAfterRender(testCase)
            fp = FastPlot();
            fp.addLine(1:10, rand(1,10));
            fp.render();
            testCase.addTeardown(@close, fp.hFigure);
            threw = false;
            try
                fp.addMarker([1], [1]);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'testMarkerRejectsAfterRender');
        end
    end
end
