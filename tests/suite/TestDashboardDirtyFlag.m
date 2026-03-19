classdef TestDashboardDirtyFlag < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testNewWidgetIsDirty(testCase)
            w = MockDashboardWidget();
            testCase.verifyTrue(w.Dirty, ...
                'Newly created widget should be dirty');
        end

        function testMarkDirty(testCase)
            w = MockDashboardWidget();
            w.Dirty = false;
            w.markDirty();
            testCase.verifyTrue(w.Dirty);
        end

        function testRealizedDefaultFalse(testCase)
            w = MockDashboardWidget();
            testCase.verifyFalse(w.Realized, ...
                'Newly created widget should not be realized');
        end
    end
end
