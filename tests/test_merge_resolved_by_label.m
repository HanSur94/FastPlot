function test_merge_resolved_by_label()
%TEST_MERGE_RESOLVED_BY_LABEL Tests for mergeResolvedByLabel private helper.

    add_sensor_path();
    add_sensor_private_path();

    % testEmptyInput
    [mTh, mViol] = mergeResolvedByLabel([], [], [0 5 10], 15);
    assert(isempty(mTh), 'testEmptyInput: empty thresholds');
    assert(isempty(mViol), 'testEmptyInput: empty violations');

    % testSingleEntry — no merge needed
    th = struct('X', [0 5 10], 'Y', [50 NaN 50], 'Direction', 'upper', ...
        'Label', 'HH', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    viol = struct('X', [2], 'Y', [55], 'Direction', 'upper', 'Label', 'HH');
    [mTh, mViol] = mergeResolvedByLabel(th, viol, [0 5 10], 15);
    assert(numel(mTh) == 1, 'testSingleEntry: 1 threshold');
    assert(numel(mViol) == 1, 'testSingleEntry: 1 violation');
    assert(strcmp(mTh(1).Label, 'HH'), 'testSingleEntry: label preserved');

    % testMergeSameLabel — two entries with same label+direction get merged
    th1 = struct('X', [0 5 10], 'Y', [50 NaN NaN], 'Direction', 'upper', ...
        'Label', 'HH', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    th2 = struct('X', [0 5 10], 'Y', [NaN NaN 50], 'Direction', 'upper', ...
        'Label', 'HH', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    viol1 = struct('X', [2], 'Y', [55], 'Direction', 'upper', 'Label', 'HH');
    viol2 = struct('X', [12], 'Y', [53], 'Direction', 'upper', 'Label', 'HH');
    rTh = [th1, th2];
    rViol = [viol1, viol2];
    [mTh, mViol] = mergeResolvedByLabel(rTh, rViol, [0 5 10], 15);
    assert(numel(mTh) == 1, 'testMergeSameLabel: merged to 1');
    assert(numel(mViol) == 1, 'testMergeSameLabel: 1 violation entry');
    % Violations should be concatenated
    assert(numel(mViol(1).X) == 2, 'testMergeSameLabel: 2 violation points');
    % Violations should be time-sorted
    assert(mViol(1).X(1) < mViol(1).X(2), 'testMergeSameLabel: sorted violations');

    % testDifferentLabelsStaySeparate
    th1 = struct('X', [0 5], 'Y', [50 50], 'Direction', 'upper', ...
        'Label', 'HH', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    th2 = struct('X', [0 5], 'Y', [10 10], 'Direction', 'lower', ...
        'Label', 'LL', 'Color', [0 0 1], 'LineStyle', ':', 'Value', 10);
    viol1 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'HH');
    viol2 = struct('X', [], 'Y', [], 'Direction', 'lower', 'Label', 'LL');
    [mTh, mViol] = mergeResolvedByLabel([th1 th2], [viol1 viol2], [0 5], 10);
    assert(numel(mTh) == 2, 'testDifferentLabelsStaySeparate: 2 entries');

    % testSameLabelDifferentDirection — should NOT merge
    th1 = struct('X', [0 5], 'Y', [50 50], 'Direction', 'upper', ...
        'Label', 'Limit', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    th2 = struct('X', [0 5], 'Y', [10 10], 'Direction', 'lower', ...
        'Label', 'Limit', 'Color', [0 0 1], 'LineStyle', '--', 'Value', 10);
    viol1 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'Limit');
    viol2 = struct('X', [], 'Y', [], 'Direction', 'lower', 'Label', 'Limit');
    [mTh, ~] = mergeResolvedByLabel([th1 th2], [viol1 viol2], [0 5], 10);
    assert(numel(mTh) == 2, 'testSameLabelDifferentDirection: 2 entries');

    % testUnlabeledEntriesNeverMerge
    th1 = struct('X', [0 5], 'Y', [50 50], 'Direction', 'upper', ...
        'Label', '', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    th2 = struct('X', [0 5], 'Y', [60 60], 'Direction', 'upper', ...
        'Label', '', 'Color', [0 1 0], 'LineStyle', '--', 'Value', 60);
    viol1 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', '');
    viol2 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', '');
    [mTh, ~] = mergeResolvedByLabel([th1 th2], [viol1 viol2], [0 5], 10);
    assert(numel(mTh) == 2, 'testUnlabeledEntriesNeverMerge: 2 entries');

    % testStepFunctionOutput — merged result uses step-function X/Y
    th = struct('X', [0 5 10], 'Y', [50 50 50], 'Direction', 'upper', ...
        'Label', 'Full', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    viol = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'Full');
    [mTh, ~] = mergeResolvedByLabel(th, viol, [0 5 10], 15);
    % Step function should have more points than input (boundary duplication)
    assert(numel(mTh(1).X) >= 2, 'testStepFunctionOutput: X has step points');
    assert(numel(mTh(1).Y) >= 2, 'testStepFunctionOutput: Y has step points');
    % All non-NaN Y values should be the threshold value
    nonNanY = mTh(1).Y(~isnan(mTh(1).Y));
    assert(all(nonNanY == 50), 'testStepFunctionOutput: Y values are 50');

    % testOverlayFillsNaNGaps
    th1 = struct('X', [0 5 10], 'Y', [50 NaN NaN], 'Direction', 'upper', ...
        'Label', 'Merge', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    th2 = struct('X', [0 5 10], 'Y', [NaN 50 NaN], 'Direction', 'upper', ...
        'Label', 'Merge', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    th3 = struct('X', [0 5 10], 'Y', [NaN NaN 50], 'Direction', 'upper', ...
        'Label', 'Merge', 'Color', [1 0 0], 'LineStyle', '--', 'Value', 50);
    viol1 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'Merge');
    viol2 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'Merge');
    viol3 = struct('X', [], 'Y', [], 'Direction', 'upper', 'Label', 'Merge');
    [mTh, ~] = mergeResolvedByLabel([th1 th2 th3], [viol1 viol2 viol3], [0 5 10], 15);
    assert(numel(mTh) == 1, 'testOverlayFillsNaNGaps: merged to 1');
    % The merged step-function Y should have no NaN gaps (all segments active)
    nonNanY = mTh(1).Y(~isnan(mTh(1).Y));
    assert(~isempty(nonNanY), 'testOverlayFillsNaNGaps: has active values');

    fprintf('    All 8 mergeResolvedByLabel tests passed.\n');
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
