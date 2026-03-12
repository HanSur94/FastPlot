classdef TestStatusWidget < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (Test)
        function testConstruction(testCase)
            w = StatusWidget('Title', 'Pump 1', ...
                'StatusFcn', @() 'ok');
            testCase.verifyEqual(w.Title, 'Pump 1');
        end

        function testDefaultPosition(testCase)
            w = StatusWidget('Title', 'Test');
            testCase.verifyEqual(w.Position, [1 1 2 1]);
        end

        function testGetType(testCase)
            w = StatusWidget('Title', 'Test');
            testCase.verifyEqual(w.getType(), 'status');
        end

        function testToStruct(testCase)
            w = StatusWidget('Title', 'Valve', ...
                'StatusFcn', @() 'ok', ...
                'Position', [1 1 2 1]);
            s = w.toStruct();
            testCase.verifyEqual(s.type, 'status');
            testCase.verifyEqual(s.title, 'Valve');
        end

        function testFromStruct(testCase)
            s = struct();
            s.type = 'status';
            s.title = 'Pump';
            s.position = struct('col', 1, 'row', 1, 'width', 2, 'height', 1);
            s.source = struct('type', 'static', 'value', 'ok');
            w = StatusWidget.fromStruct(s);
            testCase.verifyEqual(w.Title, 'Pump');
        end

        function testRenderCreatesGraphics(testCase)
            w = StatusWidget('Title', 'Motor', 'StatusFcn', @() 'ok');
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            testCase.verifyEqual(w.CurrentStatus, 'ok');
        end

        function testRefreshUpdatesStatus(testCase)
            status = containers.Map('KeyType','char','ValueType','char');
            status('val') = 'ok';
            w = StatusWidget('Title', 'Motor', ...
                'StatusFcn', @() status('val'));
            hFig = figure('Visible', 'off');
            testCase.addTeardown(@() close(hFig));
            hp = uipanel('Parent', hFig, 'Position', [0 0 1 1]);
            w.render(hp);
            status('val') = 'alarm';
            w.refresh();
            testCase.verifyEqual(w.CurrentStatus, 'alarm');
        end
    end
end
