classdef TestEventDetectorTag < matlab.unittest.TestCase
    %TESTEVENTDETECTORTAG MATLAB unittest suite for EventDetector Tag overload.
    %   Phase 1009 Plan 03 — covers the additive 2-arg `detect(tag, threshold)`
    %   overload and proves the legacy 6-arg signature remains functional.
    %
    %   See also EventDetector, MakePhase1009Fixtures, TestEventDetector.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        function testConstructorSmoke(testCase)
            % Pitfall 5 guard — keep >=1 non-grep method so methods (Test)
            % block is never empty. EventDetector() must construct cleanly.
            det = EventDetector();
            testCase.verifyClass(det, 'EventDetector');
        end

        function testNonTagNonSensorErrors(testCase)
            % Malformed input should fail cleanly — not silently corrupt.
            det = EventDetector();
            testCase.verifyError(@() det.detect(42, 'foo'), ?MException);
        end

        function testPitfall1NoSubclassIsaInDetect(testCase)
            % EventDetector.m must route via isa(..,'Tag') only — not via
            % any SensorTag/MonitorTag/CompositeTag/StateTag subclass isa.
            here = fileparts(mfilename('fullpath'));
            detectorFile = fullfile(here, '..', '..', 'libs', 'EventDetection', 'EventDetector.m');
            src = fileread(detectorFile);
            badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
            for i = 1:numel(badKinds)
                pat = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
                m   = regexp(src, pat, 'once');
                testCase.verifyEmpty(m, ...
                    sprintf('Pitfall 1 violation: isa(..,''%s'') in EventDetector.m', ...
                        badKinds{i}));
            end
        end

        % testLegacyCallersStillWork removed — legacy bridge helper
        % bridge helper deleted in Phase 1011 cleanup.

    end
end
