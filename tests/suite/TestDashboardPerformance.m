classdef TestDashboardPerformance < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testLiveTickOnlyRefreshesDirtyWidgets(testCase)
            d = DashboardEngine('PerfTest');
            for k = 1:10
                d.addWidget('number', 'Title', sprintf('N%d', k), ...
                    'Position', [mod((k-1)*6, 24)+1, ceil(k*6/24), 6, 1], ...
                    'ValueFcn', @() k);
            end
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            % Clear all dirty flags
            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            % Mark only 2 of 10 dirty
            d.Widgets{1}.markDirty();
            d.Widgets{5}.markDirty();

            % Live tick should only refresh dirty widgets
            d.onLiveTick();

            % All should be clean after tick
            for i = 1:numel(d.Widgets)
                testCase.verifyFalse(d.Widgets{i}.Dirty);
            end
        end

        function testSaveLoadRoundTripWithMFile(testCase)
            d = DashboardEngine('RoundTrip');
            d.Theme = 'dark';
            d.LiveInterval = 2;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:100, 'YData', rand(1,100));
            d.addWidget('number', 'Title', 'RPM', ...
                'Position', [13 1 6 1]);

            filepath = fullfile(tempdir, 'perf_roundtrip.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'RoundTrip');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(numel(d2.Widgets), 2);
        end

        function testWidgetsRealizedAfterRender(testCase)
            d = DashboardEngine('RealizeTest');
            d.addWidget('number', 'Title', 'N1', ...
                'Position', [1 1 12 1]);
            d.addWidget('number', 'Title', 'N2', ...
                'Position', [13 1 12 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            for i = 1:numel(d.Widgets)
                testCase.verifyTrue(d.Widgets{i}.Realized);
            end
        end

        function testResizeMarksDirtyAndRealizeBatch(testCase)
            d = DashboardEngine('ResizePerfTest');
            d.addWidget('number', 'Title', 'N1', ...
                'Position', [1 1 24 1]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            for i = 1:numel(d.Widgets)
                d.Widgets{i}.Dirty = false;
            end

            d.onResize();
            testCase.verifyTrue(d.Widgets{1}.Dirty);
        end
    end
end
