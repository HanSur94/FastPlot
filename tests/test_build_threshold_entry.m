function test_build_threshold_entry()
%TEST_BUILD_THRESHOLD_ENTRY Tests for buildThresholdEntry private helper.

    add_sensor_path();
    add_sensor_private_path();

    % testBasicConstruction
    rule = ThresholdRule(struct('machine', 1), 50, ...
        'Direction', 'upper', 'Label', 'Pressure HH', ...
        'Color', [1 0 0], 'LineStyle', '--');
    segBounds = [0 5 10 15];
    thY = [50 NaN 50 NaN];
    th = buildThresholdEntry(segBounds, thY, rule);
    assert(isequal(th.X, segBounds), 'testBasicConstruction: X');
    assert(isequal(th.Y, thY), 'testBasicConstruction: Y');
    assert(strcmp(th.Direction, 'upper'), 'testBasicConstruction: Direction');
    assert(strcmp(th.Label, 'Pressure HH'), 'testBasicConstruction: Label');
    assert(isequal(th.Color, [1 0 0]), 'testBasicConstruction: Color');
    assert(strcmp(th.LineStyle, '--'), 'testBasicConstruction: LineStyle');
    assert(th.Value == 50, 'testBasicConstruction: Value');

    % testLowerDirection
    rule = ThresholdRule(struct(), 10, 'Direction', 'lower', 'Label', 'Low');
    th = buildThresholdEntry([0 5], [10 10], rule);
    assert(strcmp(th.Direction, 'lower'), 'testLowerDirection');

    % testAllNaNY — inactive segments
    rule = ThresholdRule(struct(), 25, 'Direction', 'upper', 'Label', 'None');
    thY = [NaN NaN NaN];
    th = buildThresholdEntry([0 5 10], thY, rule);
    assert(all(isnan(th.Y)), 'testAllNaNY: all NaN');

    % testEmptyColor — rule with no color
    rule = ThresholdRule(struct(), 30, 'Direction', 'upper', 'Label', 'Test');
    th = buildThresholdEntry([0 10], [30 30], rule);
    assert(isempty(th.Color), 'testEmptyColor: Color is empty');

    % testSingleSegment
    rule = ThresholdRule(struct(), 42, 'Direction', 'upper', 'Label', 'Single');
    th = buildThresholdEntry([0], [42], rule);
    assert(numel(th.X) == 1, 'testSingleSegment: single X');
    assert(th.Y == 42, 'testSingleSegment: Y value');

    fprintf('    All 5 buildThresholdEntry tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end

function add_sensor_private_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    privDir = fullfile(repo_root, 'libs', 'SensorThreshold', 'private');

    w = warning('off', 'all');
    addpath(privDir);
    warning(w);

    dirs = strsplit(path, pathsep);
    if ~any(strcmp(dirs, privDir))
        tmpDir = fullfile(tempdir, 'sensor_threshold_private_proxy');
        if ~exist(tmpDir, 'dir')
            mkdir(tmpDir);
        end
        files = dir(fullfile(privDir, '*.m'));
        for i = 1:numel(files)
            src = fullfile(privDir, files(i).name);
            dst = fullfile(tmpDir, files(i).name);
            copyfile(src, dst);
        end
        addpath(tmpDir);
    end
end
