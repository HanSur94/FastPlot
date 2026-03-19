classdef TestLoadModuleData < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Static)
        function ms = makeModuleStruct(sensorKeys, nPoints)
            %MAKEMODULESTRUCT Build a fake module struct for testing.
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), nPoints);
            for i = 1:numel(sensorKeys)
                ms.(sensorKeys{i}) = randn(1, nPoints);
                ms.doc.(sensorKeys{i}).name = sensorKeys{i};
                ms.doc.(sensorKeys{i}).datum = 'time_utc';
            end
        end
    end

    methods (Test)
        function testBasicMatch(testCase)
            % 3 sensors registered, 3 fields in struct — all match
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));
            reg.register('press', Sensor('press'));
            reg.register('flow', Sensor('flow'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press', 'flow'}, 100);
            out = loadModuleData(reg, ms);

            testCase.verifyTrue(isa(out, 'ExternalSensorRegistry'), 'returns_registry');
            testCase.verifyEqual(numel(reg.get('temp').X), 100, 'temp_X');
            testCase.verifyEqual(numel(reg.get('press').Y), 100, 'press_Y');
            testCase.verifyEqual(numel(reg.get('flow').Y), 100, 'flow_Y');
        end

        function testPartialMatch(testCase)
            % 2 sensors registered, struct has 3 fields + doc + datenum
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));
            reg.register('press', Sensor('press'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press', 'flow'}, 50);
            loadModuleData(reg, ms);

            testCase.verifyEqual(numel(reg.get('temp').X), 50, 'temp_filled');
            testCase.verifyEqual(numel(reg.get('press').X), 50, 'press_filled');
        end

        function testNoMatch(testCase)
            % Registry has sensors not in struct — sensor stays empty
            reg = ExternalSensorRegistry('Test');
            reg.register('voltage', Sensor('voltage'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press'}, 50);
            loadModuleData(reg, ms);

            testCase.verifyTrue(isempty(reg.get('voltage').X), 'voltage_empty');
        end

        function testEmptyRegistry(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            out = loadModuleData(reg, ms);

            testCase.verifyTrue(isa(out, 'ExternalSensorRegistry'), 'returns_registry');
            testCase.verifyEqual(reg.count(), 0, 'still_empty');
        end

        function testSharedXValues(testCase)
            % All matched sensors receive the same X values
            reg = ExternalSensorRegistry('Test');
            reg.register('a', Sensor('a'));
            reg.register('b', Sensor('b'));

            ms = TestLoadModuleData.makeModuleStruct({'a', 'b'}, 100);
            loadModuleData(reg, ms);

            testCase.verifyEqual(reg.get('a').X, reg.get('b').X, 'shared_X');
            testCase.verifyEqual(reg.get('a').X, ms.time_utc, 'X_matches_datenum');
        end

        function testDocFieldExcluded(testCase)
            % Even if registry has a sensor named 'doc', it should be excluded
            reg = ExternalSensorRegistry('Test');
            reg.register('doc', Sensor('doc'));
            reg.register('temp', Sensor('temp'));

            ms.doc.temp.name = 'Temperature';
            ms.doc.temp.datum = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 50);
            ms.temp = randn(1, 50);
            loadModuleData(reg, ms);

            testCase.verifyEqual(numel(reg.get('temp').X), 50, 'temp_filled');
            testCase.verifyTrue(isempty(reg.get('doc').X), 'doc_excluded');
        end

        function testDatenumFieldExcluded(testCase)
            % If registry has a sensor with same name as datenum field, exclude it
            reg = ExternalSensorRegistry('Test');
            reg.register('time_utc', Sensor('time_utc'));
            reg.register('temp', Sensor('temp'));

            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            loadModuleData(reg, ms);

            testCase.verifyEqual(numel(reg.get('temp').X), 50, 'temp_filled');
            testCase.verifyTrue(isempty(reg.get('time_utc').X), 'datenum_excluded');
        end

        function testMissingDocFieldErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = struct('temp', [1 2 3]);  % no doc field
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_doc_throws');
        end

        function testDocMissingDatumErrors(testCase)
            % doc entry without .datum field
            reg = ExternalSensorRegistry('Test');
            ms.doc.temp.name = 'Temperature';  % no .datum
            ms.temp = [1 2 3];
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_datum_throws');
        end

        function testDatenumFieldNotInStructErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms.doc.temp.name = 'Temperature';
            ms.doc.temp.datum = 'nonexistent';
            ms.temp = [1 2 3];
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'bad_datenum_ref_throws');
        end

        function testDatumNotCharErrors(testCase)
            % Defensive test: validates datum type
            reg = ExternalSensorRegistry('Test');
            ms.doc.temp.name = 'Temperature';
            ms.doc.temp.datum = 42;
            ms.temp = [1 2 3];
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'non_char_datum_throws');
        end

        function testOverwriteOnRepeatedCall(testCase)
            % Calling twice overwrites sensor data (handle semantics)
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));

            ms1 = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            loadModuleData(reg, ms1);
            testCase.verifyEqual(numel(reg.get('temp').Y), 50, 'first_call');

            ms2 = TestLoadModuleData.makeModuleStruct({'temp'}, 100);
            loadModuleData(reg, ms2);
            testCase.verifyEqual(numel(reg.get('temp').Y), 100, 'overwritten');
        end
    end
end
