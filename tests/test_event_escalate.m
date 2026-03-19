function test_event_escalate()
%TEST_EVENT_ESCALATE Tests for Event.escalateTo method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testEscalateUpdatesFields
    e = Event(10, 20, 'sensor1', 'warning', 50, 'high');
    e = e.escalateTo('critical', 100);
    assert(strcmp(e.ThresholdLabel, 'critical'), 'testEscalateUpdatesFields: label');
    assert(e.ThresholdValue == 100, 'testEscalateUpdatesFields: value');

    % testEscalatePreservesOtherFields
    e = Event(10, 20, 'sensor1', 'warning', 50, 'high');
    e = e.setStats(75, 100, 10, 80, 45, 48, 12);
    e = e.escalateTo('critical', 100);
    assert(e.StartTime == 10, 'testEscalatePreservesOtherFields: StartTime');
    assert(e.EndTime == 20, 'testEscalatePreservesOtherFields: EndTime');
    assert(e.Duration == 10, 'testEscalatePreservesOtherFields: Duration');
    assert(strcmp(e.SensorName, 'sensor1'), 'testEscalatePreservesOtherFields: SensorName');
    assert(strcmp(e.Direction, 'high'), 'testEscalatePreservesOtherFields: Direction');
    assert(e.PeakValue == 75, 'testEscalatePreservesOtherFields: PeakValue');
    assert(e.NumPoints == 100, 'testEscalatePreservesOtherFields: NumPoints');
    assert(e.MinValue == 10, 'testEscalatePreservesOtherFields: MinValue');
    assert(e.MaxValue == 80, 'testEscalatePreservesOtherFields: MaxValue');
    assert(e.MeanValue == 45, 'testEscalatePreservesOtherFields: MeanValue');
    assert(e.RmsValue == 48, 'testEscalatePreservesOtherFields: RmsValue');
    assert(e.StdValue == 12, 'testEscalatePreservesOtherFields: StdValue');

    % testEscalateLowDirection
    e = Event(5, 15, 'sensor2', 'info', 10, 'low');
    e = e.escalateTo('warning', 25);
    assert(strcmp(e.ThresholdLabel, 'warning'), 'testEscalateLowDirection: label');
    assert(strcmp(e.Direction, 'low'), 'testEscalateLowDirection: direction preserved');

    fprintf('    All 3 Event.escalateTo tests passed.\n');
end
