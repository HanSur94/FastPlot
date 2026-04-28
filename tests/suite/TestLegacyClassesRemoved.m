classdef TestLegacyClassesRemoved < matlab.unittest.TestCase
%TESTLEGACYCLASSESREMOVED Regression-guard contract test for v2.1 deletion.
%
%   Asserts that the 11 legacy classes deleted across Phase 1011 (v2.0)
%   and Phase 1013 (v2.1) are NOT reachable on the MATLAB path after
%   install().  Re-introduction of any of these names -- by accidental
%   git revert, careless copy-paste, or a future contributor unaware of
%   the v2.0/v2.1 cleanup -- fires a fast, focused failure here.
%
%   This is a STATIC contract test, not a behavioral one.  It runs in
%   ~milliseconds and adds no runtime cost to the suite.
%
%   See also TestGoldenIntegration (the v2.0 behavioral regression guard).

    properties (TestParameter)
        ClassName = {'EventDetector', 'IncrementalEventDetector', 'EventConfig', ...
                     'Threshold', 'CompositeThreshold', 'StateChannel', 'ThresholdRule', ...
                     'Sensor', 'SensorRegistry', 'ThresholdRegistry', 'ExternalSensorRegistry'};
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function classIsAbsent(testCase, ClassName)
            testCase.verifyEqual(exist(ClassName, 'class'), 0, ...
                sprintf('Legacy class %s should not be reachable; was deleted in Phase 1011 (v2.0) or Phase 1013 (v2.1).', ClassName));
        end
    end
end
