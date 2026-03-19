# loadModuleMetadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a function that compresses dense metadata signals to sparse transitions and attaches them as StateChannels to sensors based on their ThresholdRule conditions.

**Architecture:** Single standalone function `loadModuleMetadata(metadataStruct, sensors)`. Validates the metadata struct (same format as module data), compresses each referenced state field from dense to sparse transitions via `diff`/`strcmp`, caches compressed results in a struct, and attaches new StateChannel instances to each sensor that references the state key in its ThresholdRules.

**Tech Stack:** MATLAB/Octave, StateChannel, ThresholdRule, Sensor

**Spec:** `docs/superpowers/specs/2026-03-19-load-module-metadata-design.md`

---

### Task 1: Write tests for loadModuleMetadata

**Files:**
- Create: `tests/suite/TestLoadModuleMetadata.m`

- [ ] **Step 1: Write test class**

```matlab
classdef TestLoadModuleMetadata < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Static)
        function ms = makeMetadataStruct(stateKeys, nPoints)
            %MAKEMETADATASTRUCT Build a fake metadata struct for testing.
            ms.doc.date = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), nPoints);
            for i = 1:numel(stateKeys)
                ms.(stateKeys{i}) = zeros(1, nPoints);
            end
        end

        function s = makeSensorWithRule(key, conditionStruct, value)
            %MAKESENSORWITHRULE Create a sensor with one ThresholdRule.
            s = Sensor(key);
            s.X = linspace(datenum(2024,1,1), datenum(2024,1,2), 100);
            s.Y = randn(1, 100);
            s.addThresholdRule(conditionStruct, value, ...
                'Direction', 'upper', 'Label', 'test');
        end
    end

    methods (Test)
        function testBasicNumericState(testCase)
            % One sensor with one rule referencing 'machine' state
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            % Set state: 0 for first 50 points, 1 for last 50
            ms.machine(51:100) = 1;

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyEqual(numel(sensors), 1, 'returns_sensors');
            testCase.verifyEqual(numel(sensors{1}.StateChannels), 1, 'one_sc');
            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(sc.Key, 'machine', 'sc_key');
            % Compressed: 2 transitions (first point=0, then change to 1)
            testCase.verifyEqual(numel(sc.X), 2, 'sparse_X');
            testCase.verifyEqual(sc.Y, [0 1], 'sparse_Y');
        end

        function testCellStringState(testCase)
            % State channel with cell array of char values
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('recipe', 'bake'), 80);

            ms.doc.date = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 6);
            ms.recipe = {'idle', 'idle', 'bake', 'bake', 'bake', 'idle'};

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(sc.Key, 'recipe', 'sc_key');
            % Transitions: idle->bake->idle = 3 points
            testCase.verifyEqual(numel(sc.X), 3, 'sparse_X');
            testCase.verifyEqual(sc.Y, {'idle', 'bake', 'idle'}, 'sparse_Y');
        end

        function testMultipleSensorsGetIndependentHandles(testCase)
            % Two sensors both reference 'machine' — same data, own instances
            s1 = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);
            s2 = TestLoadModuleMetadata.makeSensorWithRule( ...
                'press', struct('machine', 1), 100);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            ms.machine(51:100) = 1;

            sensors = loadModuleMetadata(ms, {s1, s2});

            sc1 = sensors{1}.StateChannels{1};
            sc2 = sensors{2}.StateChannels{1};
            % Both get same data
            testCase.verifyEqual(sc1.X, sc2.X, 'same_X_data');
            testCase.verifyEqual(sc1.Y, sc2.Y, 'same_Y_data');
            % But independent handles: mutating one does not affect the other
            origX = sc2.X;
            sc1.X = [];
            testCase.verifyEqual(sc2.X, origX, 'sc2_independent');
        end

        function testSensorWithNoRulesSkipped(testCase)
            % Sensor without ThresholdRules gets no StateChannels
            s = Sensor('temp');
            s.X = [1 2 3]; s.Y = [4 5 6];

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyTrue(isempty(sensors{1}.StateChannels), 'no_sc');
        end

        function testRuleReferencesUnknownState(testCase)
            % Rule references 'recipe' but metadata only has 'machine'
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('recipe', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyTrue(isempty(sensors{1}.StateChannels), ...
                'no_sc_for_unknown_key');
        end

        function testMultipleConditionFields(testCase)
            % Rule with condition referencing two state channels
            s = Sensor('temp');
            s.X = linspace(datenum(2024,1,1), datenum(2024,1,2), 100);
            s.Y = randn(1, 100);
            s.addThresholdRule(struct('machine', 1, 'recipe', 2), 50, ...
                'Direction', 'upper', 'Label', 'test');

            ms = TestLoadModuleMetadata.makeMetadataStruct( ...
                {'machine', 'recipe'}, 100);
            ms.machine(51:100) = 1;
            ms.recipe(31:60) = 2;

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyEqual(numel(sensors{1}.StateChannels), 2, 'two_scs');
            keys = cellfun(@(c) c.Key, sensors{1}.StateChannels, ...
                'UniformOutput', false);
            testCase.verifyTrue(all(ismember({'machine', 'recipe'}, keys)), ...
                'both_keys_attached');
        end

        function testAllIdenticalValues(testCase)
            % State never changes — produces single-point StateChannel
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 0), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            % machine stays 0 everywhere (default)

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(numel(sc.X), 1, 'single_point');
            testCase.verifyEqual(sc.Y, 0, 'single_value');
        end

        function testSinglePointMetadata(testCase)
            % Metadata with only one time point
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms.doc.date = 'time_utc';
            ms.time_utc = datenum(2024,1,1);
            ms.machine = 1;

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(numel(sc.X), 1, 'single_pt_X');
            testCase.verifyEqual(sc.Y, 1, 'single_pt_Y');
        end

        function testColumnVectorInputs(testCase)
            % Column vector inputs must produce row vector StateChannel
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms.doc.date = 'time_utc';
            ms.time_utc = linspace(datenum(2024,1,1), datenum(2024,1,2), 6)';
            ms.machine = [0; 0; 1; 1; 0; 0];

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(size(sc.X, 1), 1, 'X_is_row');
            testCase.verifyEqual(size(sc.Y, 1), 1, 'Y_is_row');
        end

        function testEmptySensors(testCase)
            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            sensors = loadModuleMetadata(ms, {});
            testCase.verifyTrue(isempty(sensors), 'empty_passthrough');
        end

        function testMissingDocErrors(testCase)
            ms = struct('machine', [1 2 3]);
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_doc_throws');
        end

        function testMissingDocDateErrors(testCase)
            ms = struct('doc', struct('version', '1.0'), 'machine', [1 2 3]);
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'missing_doc_date_throws');
        end

        function testDocDateNotInStructErrors(testCase)
            ms = struct('doc', struct('date', 'nonexistent'), ...
                'machine', [1 2 3]);
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'bad_datenum_ref_throws');
        end

        function testDocDateNotCharErrors(testCase)
            % Defensive test beyond spec scope
            ms = struct('doc', struct('date', 42), 'machine', [1 2 3]);
            threw = false;
            try
                loadModuleMetadata(ms, {});
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'non_char_date_throws');
        end

        function testOutputRowOrientation(testCase)
            % StateChannel X/Y must be row vectors (1xN)
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            ms.machine(51:100) = 1;

            sensors = loadModuleMetadata(ms, {s});

            sc = sensors{1}.StateChannels{1};
            testCase.verifyEqual(size(sc.X, 1), 1, 'X_is_row');
            testCase.verifyEqual(size(sc.Y, 1), 1, 'Y_is_row');
        end

        function testUnconditionalRuleNoStateChannel(testCase)
            % Rule with empty condition struct() needs no state channels
            s = Sensor('temp');
            s.X = [1 2 3]; s.Y = [4 5 6];
            s.addThresholdRule(struct(), 50, ...
                'Direction', 'upper', 'Label', 'always');

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);

            sensors = loadModuleMetadata(ms, {s});

            testCase.verifyTrue(isempty(sensors{1}.StateChannels), ...
                'unconditional_no_sc');
        end

        function testRepeatedCallAccumulatesChannels(testCase)
            % Calling twice adds duplicate StateChannels (by design)
            s = TestLoadModuleMetadata.makeSensorWithRule( ...
                'temp', struct('machine', 1), 50);

            ms = TestLoadModuleMetadata.makeMetadataStruct({'machine'}, 100);
            ms.machine(51:100) = 1;

            loadModuleMetadata(ms, {s});
            loadModuleMetadata(ms, {s});

            testCase.verifyEqual(numel(s.StateChannels), 2, ...
                'duplicates_accumulated');
        end
    end
end
```

- [ ] **Step 2: Run tests to verify they all fail**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestLoadModuleMetadata.m'); disp(results)"`
Expected: All tests FAIL with "Undefined function 'loadModuleMetadata'"

- [ ] **Step 3: Commit test file**

```bash
git add tests/suite/TestLoadModuleMetadata.m
git commit -m "test: add tests for loadModuleMetadata state channel wiring"
```

---

### Task 2: Implement loadModuleMetadata

**Files:**
- Create: `libs/SensorThreshold/loadModuleMetadata.m`

- [ ] **Step 1: Write the implementation**

```matlab
function sensors = loadModuleMetadata(metadataStruct, sensors)
%LOADMODULEMETADATA Attach state channels from metadata to sensors.
%   sensors = loadModuleMetadata(metadataStruct, sensors) reads discrete
%   state signals from metadataStruct, compresses them from dense to
%   sparse transitions, and attaches StateChannel objects to each sensor
%   whose ThresholdRules reference matching state keys.
%
%   metadataStruct must have the same format as module data: fields +
%   doc.date naming the datenum field. State signals can be numeric
%   arrays or cell arrays of char.
%
%   ThresholdRules must be attached to sensors before calling this
%   function. Sensors with no rules or rules with empty conditions are
%   skipped. State keys not found in the metadata are skipped silently.
%
%   Each sensor receives its own StateChannel instance (no shared
%   handles). Compressed data is cached so each field is processed once.
%
%   Repeated calls add additional StateChannels without clearing existing
%   ones. Caller is responsible for avoiding duplicates.
%
%   See also loadModuleData, StateChannel, ThresholdRule, Sensor.

    narginchk(2, 2);

    % --- Validate doc metadata (same pattern as loadModuleData) ---
    if ~isfield(metadataStruct, 'doc')
        error('loadModuleMetadata:missingDoc', ...
            'Metadata struct must contain a ''doc'' field.');
    end
    if ~isfield(metadataStruct.doc, 'date')
        error('loadModuleMetadata:missingDocDate', ...
            'Metadata struct .doc must contain a ''date'' field naming the datenum variable.');
    end

    datenumField = metadataStruct.doc.date;

    if ~ischar(datenumField)
        error('loadModuleMetadata:invalidDocDate', ...
            'Metadata struct .doc.date must be a char (field name), got %s.', ...
            class(datenumField));
    end

    if ~isfield(metadataStruct, datenumField)
        error('loadModuleMetadata:missingDatenum', ...
            'Datenum field ''%s'' (from doc.date) not found in metadata struct.', ...
            datenumField);
    end

    % --- Early exit for empty sensors ---
    if isempty(sensors)
        return;
    end

    % --- Extract timestamps ---
    X = metadataStruct.(datenumField);

    % --- Struct-based cache for compressed transitions (Octave-safe) ---
    cache = struct();

    % --- Attach state channels to each sensor ---
    for i = 1:numel(sensors)
        s = sensors{i};

        % Skip sensors with no threshold rules
        if isempty(s.ThresholdRules)
            continue;
        end

        % Collect unique state keys from all rule conditions
        neededKeys = {};
        for r = 1:numel(s.ThresholdRules)
            rule = s.ThresholdRules{r};
            condFields = fieldnames(rule.Condition);
            neededKeys = [neededKeys; condFields]; %#ok<AGROW>
        end
        neededKeys = unique(neededKeys);

        % Attach StateChannels for keys found in metadata
        for k = 1:numel(neededKeys)
            key = neededKeys{k};

            % Skip keys not in metadata (exclude doc and datenum)
            if ~isfield(metadataStruct, key) || ...
                    strcmp(key, 'doc') || strcmp(key, datenumField)
                continue;
            end

            % Compress on first access, cache for reuse
            if ~isfield(cache, key)
                cache.(key) = compressTransitions(X, metadataStruct.(key));
            end
            cached = cache.(key);

            % Create new StateChannel instance per sensor
            sc = StateChannel(key);
            sc.X = cached.X;
            sc.Y = cached.Y;
            s.addStateChannel(sc);
        end
    end
end


function result = compressTransitions(X, Y_dense)
%COMPRESSTRANSITIONS Compress dense state signal to sparse transitions.
%   result = compressTransitions(X, Y_dense) returns struct with fields
%   X and Y containing only the transition points (plus the first point).
%   Handles both numeric arrays and cell arrays of char.

    if iscell(Y_dense)
        changes = [true, ~strcmp(Y_dense(1:end-1), Y_dense(2:end))];
    else
        changes = [true, diff(Y_dense) ~= 0];
    end

    % Ensure row orientation (1xN) per StateChannel contract
    result.X = reshape(X(changes), 1, []);
    result.Y = Y_dense(changes);
    if ~iscell(result.Y)
        result.Y = reshape(result.Y, 1, []);
    end
end
```

- [ ] **Step 2: Run tests to verify they all pass**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite/TestLoadModuleMetadata.m'); disp(results)"`
Expected: All tests PASS

- [ ] **Step 3: Commit implementation**

```bash
git add libs/SensorThreshold/loadModuleMetadata.m
git commit -m "feat: add loadModuleMetadata for state channel wiring from metadata"
```

---

### Task 3: Run full test suite to verify no regressions

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = runtests('tests/suite'); disp(table(results))"`
Expected: All existing tests PASS, no regressions (1 pre-existing failure in test_to_step_function is known)

- [ ] **Step 2: Commit if any fixups were needed**

Only if test failures required changes.
