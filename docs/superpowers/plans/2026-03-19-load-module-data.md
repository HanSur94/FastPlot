# loadModuleData Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a fast function that matches fields from an external module struct against sensors in an ExternalSensorRegistry and assigns X/Y data to each matched sensor.

**Architecture:** Single standalone function `loadModuleData(registry, moduleStruct)`. Reads `moduleStruct.doc.date` to identify the datenum field, uses `ismember` to match struct fields against registry keys, then assigns X/Y to each matched sensor via handle references.

**Tech Stack:** MATLAB/Octave, ExternalSensorRegistry, Sensor

**Spec:** `docs/superpowers/specs/2026-03-19-load-module-data-design.md`

---

### Task 1: Write tests for loadModuleData

**Files:**
- Create: `tests/suite/TestLoadModuleData.m`

- [ ] **Step 1: Write test class with helper to build module structs**

```matlab
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
            ms.doc.date = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), nPoints);
            for i = 1:numel(sensorKeys)
                ms.(sensorKeys{i}) = randn(1, nPoints);
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
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 3, 'all_matched');
            for i = 1:numel(sensors)
                testCase.verifyEqual(numel(sensors{i}.X), 100, 'X_length');
                testCase.verifyEqual(numel(sensors{i}.Y), 100, 'Y_length');
            end
        end

        function testPartialMatch(testCase)
            % 2 sensors registered, struct has 3 fields + doc + datenum
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));
            reg.register('press', Sensor('press'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press', 'flow'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 2, 'partial_match');
        end

        function testNoMatch(testCase)
            % Registry has sensors not in struct
            reg = ExternalSensorRegistry('Test');
            reg.register('voltage', Sensor('voltage'));

            ms = TestLoadModuleData.makeModuleStruct({'temp', 'press'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyTrue(isempty(sensors), 'no_match_empty');
            testCase.verifyEqual(size(sensors), [1 0], 'empty_1x0');
        end

        function testEmptyRegistry(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyTrue(isempty(sensors), 'empty_registry');
        end

        function testSharedXValues(testCase)
            % All matched sensors receive the same X values
            reg = ExternalSensorRegistry('Test');
            reg.register('a', Sensor('a'));
            reg.register('b', Sensor('b'));

            ms = TestLoadModuleData.makeModuleStruct({'a', 'b'}, 100);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(sensors{1}.X, sensors{2}.X, 'shared_X');
            testCase.verifyEqual(sensors{1}.X, ms.time_utc, 'X_matches_datenum');
        end

        function testOutputOrderFollowsFieldnames(testCase)
            % Output order matches fieldnames(moduleStruct), not registry order
            reg = ExternalSensorRegistry('Test');
            reg.register('beta', Sensor('beta'));
            reg.register('alpha', Sensor('alpha'));

            % Struct fields: doc, time_utc, alpha, beta
            ms = TestLoadModuleData.makeModuleStruct({'alpha', 'beta'}, 10);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(sensors{1}.Key, 'alpha', 'first_is_alpha');
            testCase.verifyEqual(sensors{2}.Key, 'beta', 'second_is_beta');
        end

        function testDocFieldExcluded(testCase)
            % Even if registry has a sensor named 'doc', it should be excluded
            reg = ExternalSensorRegistry('Test');
            reg.register('doc', Sensor('doc'));
            reg.register('temp', Sensor('temp'));

            % Manually build struct so 'doc' is a data field that also has .date
            ms.doc.date = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 50);
            ms.temp = randn(1, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 1, 'doc_excluded');
            testCase.verifyEqual(sensors{1}.Key, 'temp', 'only_temp');
        end

        function testDatenumFieldExcluded(testCase)
            % If registry has a sensor with same name as datenum field, exclude it
            reg = ExternalSensorRegistry('Test');
            reg.register('time_utc', Sensor('time_utc'));
            reg.register('temp', Sensor('temp'));

            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(numel(sensors), 1, 'datenum_excluded');
            testCase.verifyEqual(sensors{1}.Key, 'temp', 'only_temp');
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

        function testMissingDocDateErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = struct('doc', struct('version', '1.0'), 'temp', [1 2 3]);
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_doc_date_throws');
        end

        function testDatenumFieldNotInStructErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = struct('doc', struct('date', 'nonexistent'), 'temp', [1 2 3]);
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'bad_datenum_ref_throws');
        end

        function testDocDateNotCharErrors(testCase)
            reg = ExternalSensorRegistry('Test');
            ms = struct('doc', struct('date', 42), 'temp', [1 2 3]);
            threw = false;
            try
                loadModuleData(reg, ms);
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'non_char_date_throws');
        end

        function testOutputIsRowCell(testCase)
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));

            ms = TestLoadModuleData.makeModuleStruct({'temp'}, 10);
            sensors = loadModuleData(reg, ms);

            testCase.verifyEqual(size(sensors, 1), 1, 'row_cell');
        end

        function testOverwriteOnRepeatedCall(testCase)
            % Calling twice overwrites sensor data (handle semantics)
            reg = ExternalSensorRegistry('Test');
            reg.register('temp', Sensor('temp'));

            ms1 = TestLoadModuleData.makeModuleStruct({'temp'}, 50);
            sensors1 = loadModuleData(reg, ms1);

            ms2 = TestLoadModuleData.makeModuleStruct({'temp'}, 100);
            sensors2 = loadModuleData(reg, ms2);

            % Same handle, new data
            testCase.verifyEqual(numel(sensors2{1}.Y), 100, 'overwritten_Y');
            testCase.verifyTrue(sensors1{1} == sensors2{1}, 'same_handle');
        end
    end
end
```

- [ ] **Step 2: Run tests to verify they all fail (function doesn't exist yet)**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestLoadModuleData.m'); disp(results)"`
Expected: All tests FAIL with "Undefined function 'loadModuleData'"

- [ ] **Step 3: Commit test file**

```bash
git add tests/suite/TestLoadModuleData.m
git commit -m "test: add tests for loadModuleData module-to-registry bridge"
```

---

### Task 2: Implement loadModuleData

**Files:**
- Create: `libs/SensorThreshold/loadModuleData.m`

- [ ] **Step 1: Write the implementation**

```matlab
function sensors = loadModuleData(registry, moduleStruct)
%LOADMODULEDATA Match module struct fields to registered sensors and assign X/Y.
%   sensors = loadModuleData(registry, moduleStruct) takes an
%   ExternalSensorRegistry and a module struct loaded from the external
%   system. The struct must contain a .doc.date field naming the datenum
%   field. Each struct field whose name matches a registered sensor key
%   gets its data assigned as sensor.Y, with the shared datenum as
%   sensor.X.
%
%   Returns a 1xN cell array of filled Sensor handles (empty 1x0 if no
%   matches). Output order follows fieldnames(moduleStruct).
%
%   Repeated calls overwrite sensor.X and sensor.Y in-place (handle
%   semantics).
%
%   See also ExternalSensorRegistry, Sensor.

    narginchk(2, 2);

    % --- Validate doc metadata ---
    if ~isfield(moduleStruct, 'doc')
        error('loadModuleData:missingDoc', ...
            'Module struct must contain a ''doc'' field.');
    end
    if ~isfield(moduleStruct.doc, 'date')
        error('loadModuleData:missingDocDate', ...
            'Module struct .doc must contain a ''date'' field naming the datenum variable.');
    end

    datenumField = moduleStruct.doc.date;

    if ~ischar(datenumField)
        error('loadModuleData:invalidDocDate', ...
            'Module struct .doc.date must be a char (field name), got %s.', class(datenumField));
    end

    if ~isfield(moduleStruct, datenumField)
        error('loadModuleData:missingDatenum', ...
            'Datenum field ''%s'' (from doc.date) not found in module struct.', datenumField);
    end

    % --- Extract shared time vector ---
    X = moduleStruct.(datenumField);

    % --- Match struct fields against registry ---
    fields = fieldnames(moduleStruct);
    registeredKeys = registry.keys();

    if isempty(registeredKeys)
        sensors = cell(1, 0);
        return;
    end

    isMatch = ismember(fields, registeredKeys);

    % Exclude doc and datenum field
    exclude = strcmp(fields, 'doc') | strcmp(fields, datenumField);
    isMatch = isMatch & ~exclude;

    matchedFields = fields(isMatch);
    nMatched = numel(matchedFields);

    % --- Assign X/Y to each matched sensor ---
    sensors = cell(1, nMatched);
    for i = 1:nMatched
        s = registry.get(matchedFields{i});
        s.X = X;
        s.Y = moduleStruct.(matchedFields{i});
        sensors{i} = s;
    end
end
```

- [ ] **Step 2: Run tests to verify they all pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestLoadModuleData.m'); disp(results)"`
Expected: All tests PASS

- [ ] **Step 3: Commit implementation**

```bash
git add libs/SensorThreshold/loadModuleData.m
git commit -m "feat: add loadModuleData for fast module-to-registry data wiring"
```

---

### Task 3: Run full test suite to verify no regressions

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite'); disp(table(results))"`
Expected: All existing tests PASS, no regressions

- [ ] **Step 2: Commit if any fixups were needed**

Only if test failures required changes.
