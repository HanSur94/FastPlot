function test_event_config()
%TEST_EVENT_CONFIG Tests for EventConfig configuration class.

    add_event_path();

    % testConstructorDefaults
    cfg = EventConfig();
    assert(isempty(cfg.Sensors), 'defaults: Sensors empty');
    assert(isempty(cfg.SensorData), 'defaults: SensorData empty');
    assert(cfg.MinDuration == 0, 'defaults: MinDuration');
    assert(cfg.MaxCallsPerEvent == 1, 'defaults: MaxCallsPerEvent');
    assert(isempty(cfg.OnEventStart), 'defaults: OnEventStart');
    assert(cfg.AutoOpenViewer == false, 'defaults: AutoOpenViewer');

    % testAddSensor
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    assert(numel(cfg.Sensors) == 1, 'addSensor: count');
    assert(numel(cfg.SensorData) == 1, 'addSensor: data count');
    assert(strcmp(cfg.SensorData(1).name, 'Temperature'), 'addSensor: data name');
    assert(isequal(cfg.SensorData(1).t, s.X), 'addSensor: data t');
    assert(isequal(cfg.SensorData(1).y, s.Y), 'addSensor: data y');

    % testSetColor
    cfg = EventConfig();
    cfg.setColor('warn', [1 0 0]);
    assert(isequal(cfg.ThresholdColors('warn'), [1 0 0]), 'setColor: stored');

    % testBuildDetector
    cfg = EventConfig();
    cfg.MinDuration = 5;
    cfg.MaxCallsPerEvent = 3;
    cfg.OnEventStart = @(e) disp(e);
    det = cfg.buildDetector();
    assert(isa(det, 'EventDetector'), 'buildDetector: class');
    assert(det.MinDuration == 5, 'buildDetector: MinDuration');
    assert(det.MaxCallsPerEvent == 3, 'buildDetector: MaxCallsPerEvent');
    assert(~isempty(det.OnEventStart), 'buildDetector: OnEventStart');

    % testRunDetection
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    events = cfg.runDetection();
    assert(numel(events) >= 1, 'runDetection: found events');
    assert(strcmp(events(1).SensorName, 'Temperature'), 'runDetection: sensor name');

    fprintf('    All 5 event_config tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
