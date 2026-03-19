function test_append_results()
%TEST_APPEND_RESULTS Tests for appendResults private helper.

    add_sensor_path();
    add_sensor_private_path();

    % testSeedEmptyArrays — first call seeds the arrays
    th1 = struct('X', [0 5], 'Y', [10 10], 'Direction', 'upper', ...
        'Label', 'A', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 10);
    viol1 = struct('X', [3], 'Y', [12], 'Direction', 'upper', 'Label', 'A');
    [rTh, rViol] = appendResults([], [], th1, viol1);
    assert(numel(rTh) == 1, 'testSeedEmptyArrays: 1 threshold');
    assert(numel(rViol) == 1, 'testSeedEmptyArrays: 1 violation');
    assert(strcmp(rTh(1).Label, 'A'), 'testSeedEmptyArrays: label');

    % testAppendToExisting
    th2 = struct('X', [5 10], 'Y', [20 20], 'Direction', 'lower', ...
        'Label', 'B', 'Color', [0 1 0], 'LineStyle', ':', 'Value', 20);
    viol2 = struct('X', [7], 'Y', [18], 'Direction', 'lower', 'Label', 'B');
    [rTh, rViol] = appendResults(rTh, rViol, th2, viol2);
    assert(numel(rTh) == 2, 'testAppendToExisting: 2 thresholds');
    assert(numel(rViol) == 2, 'testAppendToExisting: 2 violations');
    assert(strcmp(rTh(2).Label, 'B'), 'testAppendToExisting: second label');

    % testAppendMultiple
    th3 = struct('X', [10 15], 'Y', [30 30], 'Direction', 'upper', ...
        'Label', 'C', 'Color', [], 'LineStyle', '-', 'Value', 30);
    viol3 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'C');
    [rTh, rViol] = appendResults(rTh, rViol, th3, viol3);
    assert(numel(rTh) == 3, 'testAppendMultiple: 3 thresholds');
    assert(numel(rViol) == 3, 'testAppendMultiple: 3 violations');

    % testEmptyViolation — viol with empty X/Y
    assert(isempty(rViol(3).X), 'testEmptyViolation: empty X');
    assert(isempty(rViol(3).Y), 'testEmptyViolation: empty Y');

    fprintf('    All 4 appendResults tests passed.\n');
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
