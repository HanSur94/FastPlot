classdef TestIndustrialPlantHistory < matlab.unittest.TestCase
    %TESTINDUSTRIALPLANTHISTORY Suite for the demo's 1-week seed step.
    %   Each test that depends on a live ctx uses TestMethodSetup /
    %   TestMethodTeardown to keep test isolation. The pure-helper tests
    %   (Tasks 1–3) need no ctx and run instantly.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
            addpath(fullfile(here, '..', '..', 'demo', 'industrial_plant'));
        end
    end

    methods (Test)
        function testStateHistoryHasSevenReactorCycles(testCase)
            cfg     = plantConfig();
            tStart  = now() - 7;
            nDays   = 7;
            [~, ~, xMode, yMode] = buildStateHistory(cfg, tStart, nDays);
            testCase.assertEqual(numel(xMode), numel(yMode), ...
                'mode X/Y length mismatch');
            testCase.assertGreaterThan(numel(xMode), 0, 'mode history empty');

            % Count `running` -> `cooldown` transitions; one per day = 7.
            nTransitions = 0;
            for k = 2:numel(yMode)
                if strcmp(yMode{k-1}, 'running') && strcmp(yMode{k}, 'cooldown')
                    nTransitions = nTransitions + 1;
                end
            end
            testCase.assertEqual(nTransitions, 7, ...
                sprintf('expected 7 running->cooldown transitions, got %d', nTransitions));
        end

        function testStateHistoryHasSevenValveCycles(testCase)
            cfg     = plantConfig();
            tStart  = now() - 7;
            nDays   = 7;
            [xValve, yValve, ~, ~] = buildStateHistory(cfg, tStart, nDays);
            testCase.assertEqual(numel(xValve), numel(yValve), ...
                'valve X/Y length mismatch');
            testCase.assertGreaterThan(numel(xValve), 0, 'valve history empty');

            % Count `closing` -> `closed` transitions; one per day = 7.
            nClose = 0;
            for k = 2:numel(yValve)
                if strcmp(yValve{k-1}, 'closing') && strcmp(yValve{k}, 'closed')
                    nClose = nClose + 1;
                end
            end
            testCase.assertEqual(nClose, 7, ...
                sprintf('expected 7 closing->closed transitions, got %d', nClose));
        end

        function testSensorExcursionsBaselineMatchesSineModel(testCase)
            cfg    = plantConfig();
            tStart = now() - 7;
            % 600 samples (10 min at 1 Hz) is enough to verify shape
            % without committing to a full week here.
            tHist  = (tStart : 1/86400 : tStart + 600/86400)';

            % An unmonitored sensor: no excursions overlay, so y should
            % be exactly baseline + noise (within RNG determinism).
            key  = 'feedline.flow';   % unmonitored
            rng(1015, 'twister');
            yA = buildSensorExcursions(cfg, key, tHist);

            rng(1015, 'twister');
            yB = buildSensorExcursions(cfg, key, tHist);

            testCase.assertEqual(yA, yB, ...
                'buildSensorExcursions must be deterministic under fixed seed');
            testCase.assertEqual(numel(yA), numel(tHist), ...
                'output length must match input time vector');
            testCase.assertEqual(size(yA, 2), 1, ...
                'output must be a column vector (callers feed tag.updateData)');

            field     = strrep(key, '.', '_');
            sensorRng = cfg.Ranges.(field);
            testCase.assertGreaterThanOrEqual(min(yA), sensorRng(1) - 1e-9, ...
                'baseline below sensor range');
            testCase.assertLessThanOrEqual(max(yA), sensorRng(2) + 1e-9, ...
                'baseline above sensor range');
        end

        function testMonitoredSensorHasExcursions(testCase)
            cfg    = plantConfig();
            % Full week so the schedule is exercised.
            tStart = now() - 7;
            tHist  = (tStart : 1/86400 : tStart + 7 - 1/86400)';

            % `reactor.pressure` has trip at y > 18.
            rng(1015, 'twister');
            y = buildSensorExcursions(cfg, 'reactor.pressure', tHist);

            % Per spec §4: 18-28 short trips + 5-8 long + 6-10 cascade
            % trips per monitor. Each excursion must briefly carry y above
            % the monitor's trip value. Count samples > 18.
            nAbove = sum(y > 18);
            testCase.assertGreaterThan(nAbove, 50, ...
                sprintf('expected >50 samples above 18 bar over the week, got %d', nAbove));
            testCase.assertLessThan(nAbove, 100000, ...
                sprintf('too many samples above 18 — sustained breach? got %d', nAbove));

            % Cooling.flow has lower-direction trip at y < 20.
            rng(1015, 'twister');
            yCool = buildSensorExcursions(cfg, 'cooling.flow', tHist);
            nBelow = sum(yCool < 20);
            testCase.assertGreaterThan(nBelow, 50, ...
                sprintf('expected >50 cooling samples below 20 L/min, got %d', nBelow));

            % Unmonitored sensor: no excursions, no breaches near any
            % imagined threshold — just verify the baseline is bounded.
            rng(1015, 'twister');
            yFlow = buildSensorExcursions(cfg, 'feedline.flow', tHist);
            field = 'feedline_flow';
            r = cfg.Ranges.(field);
            testCase.assertGreaterThanOrEqual(min(yFlow), r(1) - 1e-9);
            testCase.assertLessThanOrEqual(max(yFlow), r(2) + 1e-9);
        end
    end
end
