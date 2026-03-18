classdef TestExternalSensorRegistry < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            reg = ExternalSensorRegistry('TestLab');
            testCase.verifyEqual(reg.Name, 'TestLab', 'name_set');
        end

        function testEmptyOnCreation(testCase)
            reg = ExternalSensorRegistry('TestLab');
            testCase.verifyEqual(reg.count(), 0, 'empty_count');
            testCase.verifyTrue(isempty(reg.keys()), 'empty_keys');
        end
    end
end
