function test_event_store()
%TEST_EVENT_STORE Tests for event store persistence and EventViewer.fromFile.

    add_event_path();

    % testAutoSave
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    cfg.setColor('warn', [1 0.8 0]);

    tmpFile = fullfile(tempdir, 'test_event_store.mat');
    cfg.EventFile = tmpFile;
    events = cfg.runDetection();

    assert(exist(tmpFile, 'file') == 2, 'auto-save: file created');
    data = load(tmpFile);
    assert(isfield(data, 'events'), 'auto-save: has events');
    assert(isfield(data, 'sensorData'), 'auto-save: has sensorData');
    assert(isfield(data, 'thresholdColors'), 'auto-save: has thresholdColors');
    assert(isfield(data, 'timestamp'), 'auto-save: has timestamp');
    assert(numel(data.events) == numel(events), 'auto-save: event count');
    assert(strcmp(data.sensorData(1).name, 'Temperature'), 'auto-save: sensor name');

    % testFromFile
    viewer = EventViewer.fromFile(tmpFile);
    assert(isa(viewer, 'EventViewer'), 'fromFile: returns EventViewer');
    assert(numel(viewer.Events) == numel(events), 'fromFile: event count');
    close(viewer.hFigure);

    % testFromFileColors
    assert(viewer.ThresholdColors.isKey('warn'), 'fromFile: color key restored');
    assert(isequal(viewer.ThresholdColors('warn'), [1 0.8 0]), 'fromFile: color value');

    % testNoEventFile
    cfg2 = EventConfig();
    s2 = Sensor('temp', 'Name', 'Temperature');
    s2.X = 1:10;
    s2.Y = [5 5 12 14 11 13 5 5 5 5];
    s2.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg2.addSensor(s2);
    tmpFile2 = fullfile(tempdir, 'test_event_store_2.mat');
    if exist(tmpFile2, 'file'); delete(tmpFile2); end
    events2 = cfg2.runDetection();
    assert(exist(tmpFile2, 'file') ~= 2, 'no-file: nothing saved when EventFile empty');

    % testFromFileNotFound
    threw = false;
    try
        EventViewer.fromFile('/tmp/nonexistent_event_store.mat');
    catch e
        threw = true;
        assert(contains(e.identifier, 'fileNotFound'), 'fromFile: correct error id');
    end
    assert(threw, 'fromFile: throws on missing file');

    % Cleanup
    if exist(tmpFile, 'file'); delete(tmpFile); end

    fprintf('    All 5 event_store tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); setup();
end
