function test_load_meta_struct()
%TEST_LOAD_META_STRUCT Tests for loadMetaStruct private helper function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    tmpDir = tempdir();

    % testEmptyFilepath
    meta = loadMetaStruct('', {'x'});
    assert(isempty(meta), 'testEmptyFilepath: returns []');

    % testEmptyVars
    meta = loadMetaStruct('/tmp/somefile.mat', {});
    assert(isempty(meta), 'testEmptyVars: returns []');

    % testNonExistentFile
    meta = loadMetaStruct('/tmp/nonexistent_file_xyz123.mat', {'x'});
    assert(isempty(meta), 'testNonExistentFile: returns []');

    % testWithDatenumField
    f = fullfile(tmpDir, 'test_meta_datenum.mat');
    datenum_vec = [1 2 3 4 5];
    x = [10 20 30 40 50];
    save(f, 'datenum_vec', 'x', '-v7');
    % Rename datenum_vec to datenum using a workaround
    data = load(f);
    data.datenum = datenum_vec;
    data = rmfield(data, 'datenum_vec');
    save(f, '-struct', 'data', '-v7');
    meta = loadMetaStruct(f, {'x'});
    assert(~isempty(meta), 'testWithDatenumField: not empty');
    assert(isfield(meta, 'datenum'), 'testWithDatenumField: has datenum');
    assert(isequal(meta.datenum, [1 2 3 4 5]), 'testWithDatenumField: datenum values');
    assert(isfield(meta, 'x'), 'testWithDatenumField: has x');
    assert(isequal(meta.x, [10 20 30 40 50]), 'testWithDatenumField: x values');
    delete(f);

    % testWithDatetimeField (fallback)
    f = fullfile(tmpDir, 'test_meta_datetime.mat');
    data = struct();
    data.datetime = [100 200 300];
    data.y = [1.1 2.2 3.3];
    save(f, '-struct', 'data', '-v7');
    meta = loadMetaStruct(f, {'y'});
    assert(~isempty(meta), 'testWithDatetimeField: not empty');
    assert(isfield(meta, 'datenum'), 'testWithDatetimeField: normalized to datenum');
    assert(isequal(meta.datenum, [100 200 300]), 'testWithDatetimeField: values');
    assert(isfield(meta, 'y'), 'testWithDatetimeField: has y');
    delete(f);

    % testMissingTimestamp
    f = fullfile(tmpDir, 'test_meta_notime.mat');
    data = struct();
    data.x = [1 2 3];
    save(f, '-struct', 'data', '-v7');
    meta = loadMetaStruct(f, {'x'});
    assert(isempty(meta), 'testMissingTimestamp: returns [] without timestamp');
    delete(f);

    % testMissingRequestedVar — silently skipped
    f = fullfile(tmpDir, 'test_meta_skipvar.mat');
    data = struct();
    data.datenum = [1 2 3];
    data.x = [10 20 30];
    save(f, '-struct', 'data', '-v7');
    meta = loadMetaStruct(f, {'x', 'nonexistent'});
    assert(~isempty(meta), 'testMissingRequestedVar: not empty');
    assert(isfield(meta, 'x'), 'testMissingRequestedVar: has x');
    assert(~isfield(meta, 'nonexistent'), 'testMissingRequestedVar: missing var skipped');
    delete(f);

    fprintf('    All 7 loadMetaStruct tests passed.\n');
end
