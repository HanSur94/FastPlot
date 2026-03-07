function test_metadata()
%TEST_METADATA Tests for metadata support.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    close all force;
    drawnow;

    testAddLineWithMetadata();
    testAddLineWithoutMetadata();
    testMetadataStoredOnLine();
    testLookupMetadataMiddle();
    testLookupMetadataBeforeFirst();
    testLookupMetadataAfterLast();
    testLookupMetadataNoMetadata();
    testLookupMetadataExactMatch();
    testMetadataToolbarButton();
    testMetadataToggle();
    testMetadataIconSize();
    testCursorShowsMetadata();
    testCursorNoMetadataWhenToggleOff();
    testUpdateDataWithMetadata();
    testUpdateDataWithoutMetadataPreserves();

    fprintf('    All 15 metadata tests passed.\n');
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

function testLookupMetadataMiddle()
    fp = FastPlot();
    meta.datenum = [10, 50, 80];
    meta.operator = {'Alice', 'Bob', 'Charlie'};
    meta.mode = {'auto', 'manual', 'auto'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    fp.render();
    result = fp.lookupMetadata(1, 30);
    assert(strcmp(result.operator, 'Alice'), 'lookupMiddle: operator should be Alice');
    assert(strcmp(result.mode, 'auto'), 'lookupMiddle: mode should be auto');
    close(fp.hFigure);
end

function testLookupMetadataBeforeFirst()
    fp = FastPlot();
    meta.datenum = [10, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    fp.render();
    result = fp.lookupMetadata(1, 5);
    assert(isempty(result), 'lookupBeforeFirst: should be empty');
    close(fp.hFigure);
end

function testLookupMetadataAfterLast()
    fp = FastPlot();
    meta.datenum = [10, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    fp.render();
    result = fp.lookupMetadata(1, 90);
    assert(strcmp(result.operator, 'Bob'), 'lookupAfterLast: should be Bob');
    close(fp.hFigure);
end

function testLookupMetadataNoMetadata()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    result = fp.lookupMetadata(1, 50);
    assert(isempty(result), 'lookupNoMeta: should be empty');
    close(fp.hFigure);
end

function testLookupMetadataExactMatch()
    fp = FastPlot();
    meta.datenum = [10, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    fp.render();
    result = fp.lookupMetadata(1, 50);
    assert(strcmp(result.operator, 'Bob'), 'lookupExact: should be Bob');
    close(fp.hFigure);
end

function testMetadataToolbarButton()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    children = get(tb.hToolbar, 'Children');
    assert(numel(children) == 9, ...
        sprintf('testMetadataToolbarButton: expected 9 buttons, got %d', numel(children)));
    close(fp.hFigure);
end

function testMetadataToggle()
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    assert(~tb.MetadataEnabled, 'testMetadataToggle: should start off');
    tb.setMetadata(true);
    assert(tb.MetadataEnabled, 'testMetadataToggle: should be on');
    tb.setMetadata(false);
    assert(~tb.MetadataEnabled, 'testMetadataToggle: should be off again');
    close(fp.hFigure);
end

function testMetadataIconSize()
    icon = FastPlotToolbar.makeIcon('metadata');
    assert(isequal(size(icon), [16 16 3]), 'testMetadataIconSize');
end

function testCursorShowsMetadata()
    fp = FastPlot();
    meta.datenum = [1, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine([1 2 3 4 5], [10 20 30 40 50], 'Metadata', meta);
    fp.render();
    tb = FastPlotToolbar(fp);
    tb.setMetadata(true);
    tb.setCursor(true);
    % Simulate snap and build label
    [sx, sy, lineIdx] = tb.snapToNearest(fp, 3, 30);
    label = tb.buildCursorLabel(fp, sx, sy, lineIdx);
    assert(~isempty(strfind(label, 'Alice')), ...
        'testCursorShowsMetadata: should contain Alice');
    close(fp.hFigure);
end

function testCursorNoMetadataWhenToggleOff()
    fp = FastPlot();
    meta.datenum = [1, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine([1 2 3 4 5], [10 20 30 40 50], 'Metadata', meta);
    fp.render();
    tb = FastPlotToolbar(fp);
    tb.setMetadata(false);
    [sx, sy, lineIdx] = tb.snapToNearest(fp, 3, 30);
    label = tb.buildCursorLabel(fp, sx, sy, lineIdx);
    assert(isempty(strfind(label, 'Alice')), ...
        'testCursorNoMeta: should not contain Alice');
    close(fp.hFigure);
end

function testUpdateDataWithMetadata()
    fp = FastPlot();
    meta.datenum = [1, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    fp.render();

    newMeta.datenum = [1, 30, 70];
    newMeta.operator = {'X', 'Y', 'Z'};
    fp.updateData(1, 1:100, rand(1,100), 'Metadata', newMeta);

    assert(numel(fp.Lines(1).Metadata.datenum) == 3, 'updateDataMeta: 3 entries');
    assert(strcmp(fp.Lines(1).Metadata.operator{1}, 'X'), 'updateDataMeta: first operator');
    close(fp.hFigure);
end

function testUpdateDataWithoutMetadataPreserves()
    fp = FastPlot();
    meta.datenum = [1, 50];
    meta.operator = {'Alice', 'Bob'};
    fp.addLine(1:100, rand(1,100), 'Metadata', meta);
    fp.render();

    fp.updateData(1, 1:100, rand(1,100));

    assert(numel(fp.Lines(1).Metadata.datenum) == 2, 'updateDataPreserve: still 2 entries');
    close(fp.hFigure);
end
