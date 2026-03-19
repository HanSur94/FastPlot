classdef TestFastSenseWidgetUpdate < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testUpdateMethodExists(testCase)
            s = Sensor('T-1', 'Name', 'Temp');
            s.X = 1:100; s.Y = rand(1,100); s.resolve();

            d = DashboardEngine('UpdateTest');
            d.addWidget('fastsense', 'Sensor', s, 'Position', [1 1 24 3]);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            w = d.Widgets{1};
            % After render + refresh, FastSenseObj should be rendered
            w.refresh();
            testCase.verifyTrue(w.FastSenseObj.IsRendered);

            % update() should not error when FastSenseObj is rendered
            s.X = 1:200; s.Y = rand(1,200);
            w.update();
        end

        function testUpdateFallsBackToRefreshWhenNotRendered(testCase)
            s = Sensor('T-2', 'Name', 'Pressure');
            s.X = 1:50; s.Y = rand(1,50); s.resolve();

            w = FastSenseWidget('Sensor', s, 'Position', [1 1 12 3]);
            % FastSenseObj is empty — update() should fall back to refresh()
            % This will be a no-op since hPanel is empty, but should not error
            w.update();
        end
    end
end
