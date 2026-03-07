function test_metadata()
%TEST_METADATA Tests for metadata support.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    close all force;
    drawnow;

    testAddLineWithMetadata();
    testAddLineWithoutMetadata();
    testMetadataStoredOnLine();

    fprintf('    All 3 metadata tests passed.\n');
end

function testAddLineWithMetadata()
    fp = FastPlot();
    meta.datenum = [10, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    assert(~isempty(fp.Lines(1).Metadata), 'testAddLineWithMetadata: should have metadata');
    assert(isequal(fp.Lines(1).Metadata.datenum, [10, 50]), 'testAddLineWithMetadata: datenum');
end

function testAddLineWithoutMetadata()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    assert(isempty(fp.Lines(1).Metadata), 'testAddLineWithoutMetadata: should be empty');
end

function testMetadataStoredOnLine()
    fp = FastPlot();
    meta.datenum = [1, 20, 80];
    meta.mode = {'auto', 'manual', 'auto'};
    meta.operator = {'Alice', 'Bob', 'Alice'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    assert(numel(fp.Lines(1).Metadata.datenum) == 3, 'testMetadataStoredOnLine: 3 entries');
    assert(strcmp(fp.Lines(1).Metadata.operator{2}, 'Bob'), 'testMetadataStoredOnLine: operator');
end
