classdef TestDashboardBugFixes < matlab.unittest.TestCase
%TESTDASHBOARDBUGFIXES Tests that expose and verify fixes for dashboard bugs.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        %% Bug 1: KpiWidget.getTheme() replaces theme instead of merging
        function testKpiWidgetThemeOverrideMerge(testCase)
            % Setting one ThemeOverride field should not lose base theme fields.
            w = KpiWidget('Title', 'Test KPI', 'StaticValue', 42);
            w.ThemeOverride = struct('KpiFontSize', 36);

            % getTheme is private, so test indirectly via render.
            % If getTheme replaces instead of merging, render will error
            % because ForegroundColor, FontName, WidgetBackground etc. are missing.
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig);

            % This should NOT error
            testCase.verifyWarningFree(@() w.render(hp));
        end

        %% Bug 2: StatusWidget.getTheme() replaces theme instead of merging
        function testStatusWidgetThemeOverrideMerge(testCase)
            w = StatusWidget('Title', 'Test Status', 'StaticStatus', 'ok');
            w.ThemeOverride = struct('StatusOkColor', [0 1 0]);

            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig);

            testCase.verifyWarningFree(@() w.render(hp));
        end

        %% Bug 3: TableWidget.toStruct() doesn't serialize static Data
        function testTableWidgetStaticDataSerialization(testCase)
            w = TableWidget('Title', 'Test Table', ...
                'Data', {{'A', 1; 'B', 2}}, ...
                'ColumnNames', {'Name', 'Value'});

            s = w.toStruct();

            % source.type should be 'static' AND the data must be present
            testCase.verifyTrue(isfield(s, 'source'), ...
                'toStruct should have a source field for static data');
            testCase.verifyEqual(s.source.type, 'static');
            testCase.verifyTrue(isfield(s.source, 'data'), ...
                'Static source should include the data field');
        end

        %% Bug 4: EventTimelineWidget.toStruct() doesn't serialize static Events
        function testEventTimelineStaticEventsSerialization(testCase)
            events = struct('startTime', {0, 10}, ...
                            'endTime', {5, 20}, ...
                            'label', {'A', 'B'});

            w = EventTimelineWidget('Title', 'Timeline', 'Events', events);
            s = w.toStruct();

            testCase.verifyTrue(isfield(s, 'source'), ...
                'toStruct should have a source field for static events');
            testCase.verifyEqual(s.source.type, 'static');
            testCase.verifyTrue(isfield(s.source, 'events'), ...
                'Static source should include events data');
        end

        %% Bug 5: configToWidgets leaves empty cells for unknown types
        function testConfigToWidgetsUnknownTypeFiltered(testCase)
            config = struct();
            config.name = 'Test';
            config.theme = 'default';
            config.liveInterval = 1;
            config.grid = struct('columns', 12);

            ws1 = struct('type', 'kpi', 'title', 'KPI 1', ...
                'position', struct('col', 1, 'row', 1, 'width', 3, 'height', 1));
            ws2 = struct('type', 'nonexistent_widget', 'title', 'Bad', ...
                'position', struct('col', 4, 'row', 1, 'width', 3, 'height', 1));
            ws3 = struct('type', 'text', 'title', 'Text 1', ...
                'position', struct('col', 7, 'row', 1, 'width', 3, 'height', 1));
            config.widgets = {ws1, ws2, ws3};

            widgets = DashboardSerializer.configToWidgets(config);

            % No cell should be empty — unknown widgets should be filtered out
            for i = 1:numel(widgets)
                testCase.verifyFalse(isempty(widgets{i}), ...
                    sprintf('Widget cell %d should not be empty', i));
            end
        end

        %% Bug 6: DashboardBuilder overlay indices mismatch widget indices
        function testBuilderOverlayIndexAlignment(testCase)
            d = DashboardEngine('Overlay Test');
            d.addWidget('kpi', 'Title', 'KPI 1', 'Position', [1 1 3 1], ...
                'StaticValue', 10);
            d.addWidget('kpi', 'Title', 'KPI 2', 'Position', [4 1 3 1], ...
                'StaticValue', 20);
            d.addWidget('kpi', 'Title', 'KPI 3', 'Position', [7 1 3 1], ...
                'StaticValue', 30);
            d.render();
            testCase.addTeardown(@() close(d.hFigure));

            builder = DashboardBuilder(d);
            builder.enterEditMode();
            testCase.addTeardown(@() builder.exitEditMode());

            % Overlays count must equal widget count
            testCase.verifyEqual(numel(builder.Overlays), numel(d.Widgets), ...
                'Number of overlays should match number of widgets');

            % Verify selecting widget 3 highlights the correct overlay
            builder.selectWidget(3);
            testCase.verifyEqual(builder.SelectedIdx, 3);
        end
    end
end
