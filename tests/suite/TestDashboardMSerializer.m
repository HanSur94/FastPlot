classdef TestDashboardMSerializer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testSaveProducesMFile(testCase)
            d = DashboardEngine('SaveTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_save_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            testCase.verifyTrue(exist(filepath, 'file') == 2);
            content = fileread(filepath);
            testCase.verifyFalse(isempty(strfind(content, 'DashboardEngine')));
            testCase.verifyFalse(isempty(strfind(content, 'function')));
        end

        function testLoadFromMFile(testCase)
            d = DashboardEngine('LoadTest');
            d.Theme = 'dark';
            d.LiveInterval = 3;
            d.addWidget('fastsense', 'Title', 'Temp', ...
                'Position', [1 1 12 3], 'XData', 1:10, 'YData', 1:10);

            filepath = fullfile(tempdir, 'test_load_dash.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(d2.Name, 'LoadTest');
            testCase.verifyEqual(d2.Theme, 'dark');
            testCase.verifyEqual(d2.LiveInterval, 3);
            testCase.verifyEqual(numel(d2.Widgets), 1);
        end

        function testAddWidgetReturnsHandle(testCase)
            d = DashboardEngine('ReturnTest');
            w = d.addWidget('number', 'Title', 'RPM', ...
                'Position', [1 1 6 1]);
            testCase.verifyClass(w, 'NumberWidget');
            testCase.verifyEqual(w.Title, 'RPM');
        end

        function testGroupWithChildrenRoundTrip(testCase)
            d = DashboardEngine('GroupPanel');
            g = d.addWidget('group', 'Label', 'Motors', 'Mode', 'panel', ...
                'Position', [1 1 24 4]);
            g.addChild(TextWidget('Title', 'RPM', 'Position', [1 1 6 1]));
            g.addChild(TextWidget('Title', 'Temp', 'Position', [7 1 6 1]));

            filepath = fullfile(tempdir, 'test_group_children.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            testCase.verifyClass(d2.Widgets{1}, 'GroupWidget');
            testCase.verifyEqual(numel(d2.Widgets{1}.Children), 2);
            testCase.verifyEqual(d2.Widgets{1}.Children{1}.Title, 'RPM');
            testCase.verifyEqual(d2.Widgets{1}.Children{2}.Title, 'Temp');
        end

        function testGroupTabbedRoundTrip(testCase)
            d = DashboardEngine('GroupTabbed');
            g = d.addWidget('group', 'Label', 'Analysis', 'Mode', 'tabbed', ...
                'Position', [1 1 24 4]);
            g.addChild(TextWidget('Title', 'Overview', 'Position', [1 1 12 2]), 'Tab1');
            g.addChild(TextWidget('Title', 'Details', 'Position', [1 1 12 2]), 'Tab2');

            filepath = fullfile(tempdir, 'test_group_tabbed.m');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            d2 = DashboardEngine.load(filepath);
            testCase.verifyEqual(numel(d2.Widgets), 1);
            g2 = d2.Widgets{1};
            testCase.verifyClass(g2, 'GroupWidget');
            testCase.verifyEqual(g2.Mode, 'tabbed');
            testCase.verifyEqual(numel(g2.Tabs), 2);
            testCase.verifyEqual(g2.Tabs{1}.name, 'Tab1');
            testCase.verifyEqual(numel(g2.Tabs{1}.widgets), 1);
            testCase.verifyEqual(g2.Tabs{2}.name, 'Tab2');
            testCase.verifyEqual(numel(g2.Tabs{2}.widgets), 1);
        end

        % ----------------------------------------------------------------
        % SERIAL-02: Multi-page .m export/import round-trip
        % ----------------------------------------------------------------

        function testMultiPageMExportRoundTrip(testCase)
            % Build a two-page engine
            d = DashboardEngine('MultiPageDash');
            d.addPage('Overview');
            d.addWidget('text', 'Title', 'T1', 'Position', [1 1 6 1]);
            d.addPage('Details');
            d.switchPage(2);
            d.addWidget('number', 'Title', 'N1', 'Position', [1 1 6 1], ...
                'StaticValue', 42);

            % Use a safe function-name-compatible tempfile
            tmpName = sprintf('dash_%d', floor(rand()*1e9));
            filepath = fullfile(tempdir, [tmpName '.m']);
            testCase.addTeardown(@() delete(filepath));
            testCase.addTeardown(@() close('all'));
            d.save(filepath);

            loaded = DashboardEngine.load(filepath);

            testCase.verifyEqual(numel(loaded.Pages), 2);
            testCase.verifyEqual(loaded.Pages{1}.Name, 'Overview');
            testCase.verifyEqual(loaded.Pages{2}.Name, 'Details');
            testCase.verifyEqual(numel(loaded.Pages{1}.Widgets), 1);
            testCase.verifyEqual(numel(loaded.Pages{2}.Widgets), 1);
            testCase.verifyEqual(loaded.Pages{1}.Widgets{1}.Title, 'T1');
            testCase.verifyEqual(loaded.Pages{2}.Widgets{1}.Title, 'N1');
        end

        function testMultiPageMExportScriptContent(testCase)
            % Build a two-page engine
            d = DashboardEngine('ContentCheck');
            d.addPage('Overview');
            d.addWidget('text', 'Title', 'W1', 'Position', [1 1 6 1]);
            d.addPage('Details');
            d.switchPage(2);
            d.addWidget('text', 'Title', 'W2', 'Position', [1 1 6 1]);

            tmpName = sprintf('dashcontent_%d', floor(rand()*1e9));
            filepath = fullfile(tempdir, [tmpName '.m']);
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            content = fileread(filepath);
            testCase.verifyFalse(isempty(strfind(content, 'DashboardEngine')));
            testCase.verifyFalse(isempty(strfind(content, 'd.addPage(''Overview'')')));
            testCase.verifyFalse(isempty(strfind(content, 'd.addPage(''Details'')')));
        end

        % ----------------------------------------------------------------
        % SERIAL-03: Collapsed state persistence through JSON save/load
        % ----------------------------------------------------------------

        function testCollapsedStatePersistedJson(testCase)
            d = DashboardEngine('CollapseTest');
            g = d.addWidget('group', 'Label', 'G', 'Mode', 'collapsible', ...
                'Position', [1 1 24 4]);
            g.collapse();

            filepath = fullfile(tempdir, 'test_collapsed_state.json');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            loaded = DashboardEngine.load(filepath);
            testCase.verifyClass(loaded.Widgets{1}, 'GroupWidget');
            testCase.verifyTrue(loaded.Widgets{1}.Collapsed);
        end

        function testExpandedStatePersistedJson(testCase)
            d = DashboardEngine('ExpandTest');
            d.addWidget('group', 'Label', 'G2', 'Mode', 'collapsible', ...
                'Position', [1 1 24 4]);

            filepath = fullfile(tempdir, 'test_expanded_state.json');
            testCase.addTeardown(@() delete(filepath));
            d.save(filepath);

            loaded = DashboardEngine.load(filepath);
            testCase.verifyClass(loaded.Widgets{1}, 'GroupWidget');
            testCase.verifyFalse(loaded.Widgets{1}.Collapsed);
        end

        function testCollapsedStateRoundTripStruct(testCase)
            g = GroupWidget('Label', 'TestGroup', 'Mode', 'collapsible', ...
                'Position', [1 1 24 4]);
            g.collapse();

            s = g.toStruct();
            g2 = GroupWidget.fromStruct(s);

            testCase.verifyTrue(g2.Collapsed);
            testCase.verifyEqual(g2.Mode, 'collapsible');
        end
    end
end
