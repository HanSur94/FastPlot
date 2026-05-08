classdef TestEventGanttCanvas < matlab.unittest.TestCase
%TESTEVENTGANTTCANVAS Unit tests for EventGanttCanvas pure helpers.

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function skipOnOctave(testCase)
            testCase.assumeFalse( ...
                exist('OCTAVE_VERSION', 'builtin') ~= 0, ...
                'TestEventGanttCanvas: skipped on Octave (companion is MATLAB-only).');
        end
    end

    methods (Test)

        function testComputeRowsEmpty(testCase)
            [map, keys] = EventGanttCanvas.computeRows(Event.empty);
            testCase.verifyEqual(map.Count, uint64(0));
            testCase.verifyEmpty(keys);
        end

        function testComputeRowsAssignsRowsInSortedTagOrder(testCase)
            ev1 = makeEvent_('b.tag', 1, 0, 1, 1);
            ev2 = makeEvent_('a.tag', 1, 2, 3, 2);
            ev3 = makeEvent_('b.tag', 1, 4, 5, 1);
            [map, keys] = EventGanttCanvas.computeRows([ev1 ev2 ev3]);
            testCase.verifyEqual(keys, {'a.tag'; 'b.tag'});
            testCase.verifyEqual(map('a.tag'), 1);
            testCase.verifyEqual(map('b.tag'), 2);
        end

        function testComputeRowsFallsBackToSensorNameWhenNoTagKeys(testCase)
            ev = Event(0, 1, 'sensor.foo', 'lbl', 1, 'upper');
            ev.TagKeys = {};
            [map, keys] = EventGanttCanvas.computeRows(ev);
            testCase.verifyEqual(keys, {'sensor.foo'});
            testCase.verifyEqual(map('sensor.foo'), 1);
        end

        function testSeverityColorMapping(testCase)
            % Severity 1 (info) -> green, 2 (warn) -> orange, 3 (alarm) -> red
            c1 = EventGanttCanvas.severityColor(1);
            c2 = EventGanttCanvas.severityColor(2);
            c3 = EventGanttCanvas.severityColor(3);
            testCase.verifyEqual(numel(c1), 3);
            testCase.verifyTrue(c1(2) > c1(1) && c1(2) > c1(3), ...
                'sev=1 (info) must be green-dominant.');
            testCase.verifyTrue(c2(1) > 0.7 && c2(2) > 0.4 && c2(3) < 0.3, ...
                'sev=2 (warn) must be orange.');
            testCase.verifyTrue(c3(1) > c3(2) && c3(1) > c3(3), ...
                'sev=3 (alarm) must be red-dominant.');
        end

        function testSeverityColorClampsOutOfRange(testCase)
            c = EventGanttCanvas.severityColor(99);
            testCase.verifyEqual(numel(c), 3);
            c2 = EventGanttCanvas.severityColor(0);
            testCase.verifyEqual(numel(c2), 3);
        end

        function testEventEndOrNowClosedReturnsEndTime(testCase)
            ev = makeEvent_('t', 1, 5, 7, 2);
            ev.IsOpen = false;
            testCase.verifyEqual(EventGanttCanvas.eventEndOrNow(ev, 1000), 7);
        end

        function testEventEndOrNowOpenReturnsNowReference(testCase)
            ev = Event(5, NaN, 'sensor', 'lbl', 1, 'upper');
            ev.IsOpen = true;
            testCase.verifyEqual(EventGanttCanvas.eventEndOrNow(ev, 1000), 1000);
        end
    end
end

function ev = makeEvent_(tagKey, severity, startT, endT, sensorIdx)
    sensorName = sprintf('sensor_%d', sensorIdx);
    ev = Event(startT, endT, sensorName, 'lbl', 1, 'upper');
    ev.TagKeys = {tagKey};
    ev.Severity = severity;
    ev.IsOpen = false;
end
