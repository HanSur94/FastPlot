classdef TestDashboardBuilder < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            d = DashboardEngine('Test');
            b = DashboardBuilder(d);
            testCase.verifyFalse(b.IsActive);
        end

        function testEnterExitEditMode(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'KPI1', 'Position', [1 1 3 1]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            testCase.verifyTrue(b.IsActive);
            testCase.verifyNotEmpty(b.Overlays);

            b.exitEditMode();
            testCase.verifyFalse(b.IsActive);
            testCase.verifyEmpty(b.Overlays);
        end

        function testAddWidgetFromPalette(testCase)
            d = DashboardEngine('Test');
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();

            testCase.verifyEqual(numel(d.Widgets), 0);
            b.addWidget('kpi');
            testCase.verifyEqual(numel(d.Widgets), 1);
            testCase.verifyEqual(d.Widgets{1}.Type, 'kpi');
        end

        function testDeleteWidget(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'A', 'Position', [1 1 3 1]);
            d.addWidget('kpi', 'Title', 'B', 'Position', [4 1 3 1]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            testCase.verifyEqual(numel(d.Widgets), 2);

            b.deleteWidget(1);
            testCase.verifyEqual(numel(d.Widgets), 1);
            testCase.verifyEqual(d.Widgets{1}.Title, 'B');
        end

        function testSelectWidget(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'Metric', 'Position', [1 1 3 1]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            b.selectWidget(1);
            testCase.verifyEqual(b.SelectedIdx, 1);
        end

        function testApplyProperties(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'Old', 'Position', [1 1 3 1]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            b.selectWidget(1);

            % Simulate changing title via properties panel
            set(b.hPropTitle, 'String', 'New Title');
            set(b.hPropCol, 'String', '2');
            set(b.hPropRow, 'String', '1');
            set(b.hPropWidth, 'String', '4');
            set(b.hPropHeight, 'String', '2');
            b.applyProperties();

            testCase.verifyEqual(d.Widgets{1}.Title, 'New Title');
            testCase.verifyEqual(d.Widgets{1}.Position, [2 1 4 2]);
        end

        function testOverlayCountMatchesWidgets(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'A', 'Position', [1 1 3 1]);
            d.addWidget('text', 'Title', 'B', 'Position', [4 1 3 1]);
            d.addWidget('gauge', 'Title', 'C', 'Position', [1 2 4 2]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            testCase.verifyEqual(numel(b.Overlays), 3);

            b.addWidget('status');
            testCase.verifyEqual(numel(b.Overlays), 4);
        end

        function testToolbarEditToggle(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'M', 'Position', [1 1 3 1]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            % Simulate clicking Edit button
            toolbar = d.Toolbar;
            toolbar.onEdit();
            testCase.verifyEqual(get(toolbar.hEditBtn, 'String'), 'Done');

            toolbar.onEdit();
            testCase.verifyEqual(get(toolbar.hEditBtn, 'String'), 'Edit');
        end

        function testFindNextSlotPlacesBelowExisting(testCase)
            d = DashboardEngine('Test');
            d.addWidget('kpi', 'Title', 'A', 'Position', [1 1 3 2]);
            d.render();
            set(d.hFigure, 'Visible', 'off');
            testCase.addTeardown(@() close(d.hFigure));

            b = DashboardBuilder(d);
            b.enterEditMode();
            pos = b.findNextSlot('kpi');
            testCase.verifyEqual(pos(2), 3, ...
                'New widget should be placed in row 3 (below row 1-2)');
        end
    end
end
