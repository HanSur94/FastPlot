classdef TestGoldenIntegration < matlab.unittest.TestCase
% GOLDEN INTEGRATION TEST — regression guard for v2.0 Tag migration.
% DO NOT REWRITE without architectural review.  Modifying this test
% before Phase 1011 invalidates the safety net across the entire
% Tag-based domain model migration.
%
% Written against the legacy Sensor/Threshold/CompositeThreshold/
% EventDetector API as of Phase 1003.  Will be rewritten to the Tag
% API exactly once, in Phase 1011 cleanup.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase) %#ok<MANU>
            ThresholdRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearAfter(testCase) %#ok<MANU>
            ThresholdRegistry.clear();
        end
    end

    methods (Test)

        function testGoldenIntegration(testCase)
            % Fixture — synthetic sensor crossing threshold twice
            % (same Y pattern as tests/test_event_integration.m)
            s = Sensor('press_a', 'Name', 'Pressure A', 'Units', 'bar');
            s.X = 1:20;
            s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

            sc = StateChannel('machine');
            sc.X = [1 11];
            sc.Y = [1 1];
            s.addStateChannel(sc);

            tHi = Threshold('press_hi', 'Name', 'Pressure High', 'Direction', 'upper');
            tHi.addCondition(struct('machine', 1), 10);
            s.addThreshold(tHi);
            s.resolve();

            % Assertion 1 — resolve correctness
            testCase.verifyTrue(s.countViolations() > 0, ...
                'golden: violations detected');

            % Assertion 2 — default event detection
            events = detectEventsFromSensor(s);
            testCase.verifyEqual(numel(events), 2, ...
                'golden: two events detected');
            testCase.verifyEqual(events(1).StartTime, 4, ...
                'golden: event1 start');
            testCase.verifyEqual(events(1).EndTime, 7, ...
                'golden: event1 end');
            testCase.verifyEqual(events(1).PeakValue, 16, ...
                'golden: event1 peak');
            testCase.verifyEqual(events(2).StartTime, 13, ...
                'golden: event2 start');
            testCase.verifyEqual(events(2).PeakValue, 22, ...
                'golden: event2 peak');

            % Assertion 3 — debounced detection
            det = EventDetector('MinDuration', 3);
            eventsLong = detectEventsFromSensor(s, det);
            testCase.verifyEqual(numel(eventsLong), 1, ...
                'golden: debounce keeps only longer event');
            testCase.verifyEqual(eventsLong(1).StartTime, 4, ...
                'golden: debounce kept first event');

            % Assertion 4 — CompositeThreshold AND aggregation
            tLo = Threshold('temp_hi', 'Direction', 'upper');
            tLo.addCondition(struct(), 80);

            comp = CompositeThreshold('pump_a_health', 'AggregateMode', 'and');
            comp.addChild(tHi, 'Value', 15);  % > 10 -> alarm leg
            comp.addChild(tLo, 'Value', 50);  % < 80 -> ok leg
            testCase.verifyEqual(comp.computeStatus(), 'alarm', ...
                'golden: AND mode with one alarm child -> alarm');

            % Assertion 5 — FastSense wiring
            fp = FastSense();
            fp.addSensor(s);
            testCase.verifyEqual(numel(fp.Lines), 1, ...
                'golden: one line after addSensor');
        end

    end
end
