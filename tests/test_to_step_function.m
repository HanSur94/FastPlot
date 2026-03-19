function test_to_step_function()
%TEST_TO_STEP_FUNCTION Tests for toStepFunction and to_step_function_mex.

    add_sensor_path();
    add_sensor_private_path();

    % testAllNaN — no active segments
    segBounds = [1 5 10];
    values = [NaN NaN NaN];
    dataEnd = 20;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    assert(isempty(stepX), 'testAllNaN: stepX empty');
    assert(isempty(stepY), 'testAllNaN: stepY empty');

    % testSingleActive — one active segment in the middle
    segBounds = [1 5 10];
    values = [NaN 42 NaN];
    dataEnd = 20;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    assert(isequal(stepX, [5 10]), 'testSingleActive: stepX');
    assert(isequal(stepY, [42 42]), 'testSingleActive: stepY');

    % testAllActiveContiguous — all segments active, same value
    segBounds = [0 10 20];
    values = [5 5 5];
    dataEnd = 30;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    assert(isequal(stepX, [0 10 10 20 20 30]), 'testAllContiguous: stepX');
    assert(isequal(stepY, [5 5 5 5 5 5]), 'testAllContiguous: stepY');

    % testAllActiveDifferentValues — contiguous with vertical steps
    segBounds = [0 10 20];
    values = [5 10 15];
    dataEnd = 30;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    assert(isequal(stepX, [0 10 10 20 20 30]), 'testDiffValues: stepX');
    assert(isequal(stepY, [5 5 10 10 15 15]), 'testDiffValues: stepY');

    % testNaNGap — gap between active segments produces NaN separator
    segBounds = [0 10 20 30];
    values = [5 NaN NaN 8];
    dataEnd = 40;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    % First active: [0,10] with value 5
    % NaN separator
    % Last active: [30,40] with value 8
    assert(numel(stepX) == 5, 'testNaNGap: length');
    assert(isequal(stepX(1:2), [0 10]), 'testNaNGap: first segment X');
    assert(isequal(stepY(1:2), [5 5]), 'testNaNGap: first segment Y');
    assert(isnan(stepX(3)) && isnan(stepY(3)), 'testNaNGap: NaN separator');
    assert(isequal(stepX(4:5), [30 40]), 'testNaNGap: last segment X');
    assert(isequal(stepY(4:5), [8 8]), 'testNaNGap: last segment Y');

    % testMixedContiguousAndGap — contiguous pair then gap then single
    segBounds = [0 10 20 30 40];
    values = [5 10 NaN NaN 3];
    dataEnd = 50;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    % Segments: [0,10]=5, [10,20]=10 (contiguous), NaN gap, [40,50]=3
    assert(isequal(stepX(1:4), [0 10 10 20]), 'testMixed: contiguous X');
    assert(isequal(stepY(1:4), [5 5 10 10]), 'testMixed: contiguous Y');
    assert(isnan(stepX(5)) && isnan(stepY(5)), 'testMixed: NaN separator');
    assert(isequal(stepX(6:7), [40 50]), 'testMixed: gap segment X');
    assert(isequal(stepY(6:7), [3 3]), 'testMixed: gap segment Y');

    % testLastSegmentUsesDataEnd — last segment right edge is dataEnd
    segBounds = [0 10];
    values = [NaN 7];
    dataEnd = 100;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    assert(isequal(stepX, [10 100]), 'testDataEnd: stepX');
    assert(isequal(stepY, [7 7]), 'testDataEnd: stepY');

    % testSingleBoundary — one segment from segBounds(1) to dataEnd
    segBounds = [5];
    values = [42];
    dataEnd = 99;
    [stepX, stepY] = toStepFunction(segBounds, values, dataEnd);
    assert(isequal(stepX, [5 99]), 'testSingleBound: stepX');
    assert(isequal(stepY, [42 42]), 'testSingleBound: stepY');

    % testMexParity — verify MEX matches MATLAB for a complex case
    hasMex = (exist('to_step_function_mex', 'file') == 3);
    if hasMex
        segBounds = [0 5 10 15 20 25 30 35 40 45];
        values = [1 NaN 3 3 NaN NaN 6 NaN 8 8];
        dataEnd = 50;
        [mxX, mxY] = to_step_function_mex(segBounds, values, dataEnd);
        % Temporarily force MATLAB path to compare
        [mlX, mlY] = toStepFunctionMatlab(segBounds, values, dataEnd);
        assert(isequaln(mxX, mlX), 'testMexParity: stepX mismatch');
        assert(isequaln(mxY, mlY), 'testMexParity: stepY mismatch');
        fprintf('    MEX parity test passed.\n');
    else
        fprintf('    MEX not compiled, skipping parity test.\n');
    end

    fprintf('    All to_step_function tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
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

function [stepX, stepY] = toStepFunctionMatlab(segBounds, values, dataEnd)
%TOSTEPFUNCTIONMATLAB Pure MATLAB reference for parity testing.
    nB = numel(segBounds);
    active = ~isnan(values);
    if ~any(active)
        stepX = []; stepY = []; return;
    end
    segEnds = [segBounds(2:end), dataEnd];
    activeIdx = find(active);
    nActive = numel(activeIdx);
    if nActive == 1
        stepX = [segBounds(activeIdx), segEnds(activeIdx)];
        stepY = [values(activeIdx), values(activeIdx)];
        return;
    end
    maxLen = 4 * nActive;
    stepX = zeros(1, maxLen);
    stepY = zeros(1, maxLen);
    prevEnds = segEnds(activeIdx(1:end-1));
    currStarts = segBounds(activeIdx(2:end));
    isGap = (prevEnds ~= currStarts);
    pos = 0;
    k = activeIdx(1);
    pos = pos + 1; stepX(pos) = segBounds(k); stepY(pos) = values(k);
    pos = pos + 1; stepX(pos) = segEnds(k);   stepY(pos) = values(k);
    for a = 2:nActive
        k = activeIdx(a);
        if isGap(a - 1)
            pos = pos + 1; stepX(pos) = NaN;           stepY(pos) = NaN;
            pos = pos + 1; stepX(pos) = segBounds(k);  stepY(pos) = values(k);
            pos = pos + 1; stepX(pos) = segEnds(k);    stepY(pos) = values(k);
        else
            pos = pos + 1; stepX(pos) = segBounds(k);  stepY(pos) = values(k);
            pos = pos + 1; stepX(pos) = segEnds(k);    stepY(pos) = values(k);
        end
    end
    stepX = stepX(1:pos);
    stepY = stepY(1:pos);
end
