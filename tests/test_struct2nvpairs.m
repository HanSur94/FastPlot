function test_struct2nvpairs()
%TEST_STRUCT2NVPAIRS Tests for struct2nvpairs private helper function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    % testSingleField
    s.Color = 'r';
    c = struct2nvpairs(s);
    assert(iscell(c), 'testSingleField: output is cell');
    assert(numel(c) == 2, 'testSingleField: length is 2');
    assert(strcmp(c{1}, 'Color'), 'testSingleField: name');
    assert(strcmp(c{2}, 'r'), 'testSingleField: value');

    % testMultipleFields
    s.Color = 'b';
    s.LineWidth = 2;
    s.Visible = true;
    c = struct2nvpairs(s);
    assert(numel(c) == 6, 'testMultipleFields: length is 6');
    names = c(1:2:end);
    vals  = c(2:2:end);
    % Check all fields present
    fnames = fieldnames(s);
    for i = 1:numel(fnames)
        assert(strcmp(names{i}, fnames{i}), ['testMultipleFields: name ' fnames{i}]);
    end

    % testEmptyStruct
    s = struct();
    c = struct2nvpairs(s);
    assert(iscell(c), 'testEmptyStruct: output is cell');
    assert(isempty(c), 'testEmptyStruct: empty cell');

    % testFieldOrder
    s = struct();
    s.Alpha = 1;
    s.Beta = 2;
    s.Gamma = 3;
    c = struct2nvpairs(s);
    fnames = fieldnames(s);
    for i = 1:numel(fnames)
        assert(strcmp(c{2*i-1}, fnames{i}), ['testFieldOrder: ' fnames{i}]);
    end

    % testMixedValueTypes
    s.Name = 'test';
    s.Value = 42;
    s.Data = [1 2 3];
    s.Flag = false;
    c = struct2nvpairs(s);
    assert(ischar(c{2}), 'testMixedValueTypes: char');
    assert(isnumeric(c{4}), 'testMixedValueTypes: numeric');
    assert(isnumeric(c{6}), 'testMixedValueTypes: array');
    assert(islogical(c{8}), 'testMixedValueTypes: logical');

    fprintf('    All 5 struct2nvpairs tests passed.\n');
end
