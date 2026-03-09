function example_event_viewer_from_file()
%EXAMPLE_EVENT_VIEWER_FROM_FILE Demonstrates saving events to file and viewing them later.
%
%   Part 1: Detect events and auto-save to a .mat file
%   Part 2: Open EventViewer from the saved file (no sensors needed)
%
%   Run:  example_event_viewer_from_file()

    setup();

    eventFile = fullfile(tempdir, 'demo_event_store.mat');
    fprintf('\n=== Event Store Demo ===\n\n');

    % --- Part 1: Detect events and auto-save ---
    fprintf('--- Part 1: Detecting events and saving to file ---\n');
    fprintf('  File: %s\n\n', eventFile);

    % Create mock sensor data
    N = 500;
    dt = 0.1;
    t = (0:N-1) * dt;

    % Temperature: baseline 70 C, with ramps and spikes
    temp = 70 + 5*sin(t/5) + 2*randn(1, N);
    rampIdx = t >= 20 & t <= 30;
    temp(rampIdx) = temp(rampIdx) + linspace(0, 25, sum(rampIdx));
    spikeIdx = t >= 40 & t <= 42;
    temp(spikeIdx) = temp(spikeIdx) + 30;

    % Pressure: baseline 6 bar, with dips
    pressure = 6 + 0.5*sin(t/3) + 0.3*randn(1, N);
    lowIdx = t >= 15 & t <= 18;
    pressure(lowIdx) = pressure(lowIdx) - 4;

    % Set up sensors
    sTemp = Sensor('temperature', 'Name', 'Temperature');
    sTemp.X = t; sTemp.Y = temp;
    sTemp.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'temp warning');
    sTemp.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'temp critical');

    sPres = Sensor('pressure', 'Name', 'Pressure');
    sPres.X = t; sPres.Y = pressure;
    sPres.addThresholdRule(struct(), 4, 'Direction', 'lower', 'Label', 'pressure low');

    % Configure detection with auto-save
    cfg = EventConfig();
    cfg.MinDuration = 0.5;
    cfg.EventFile = eventFile;       % <-- enables auto-save
    cfg.MaxBackups = 3;              % <-- keep up to 3 backup files

    cfg.addSensor(sTemp);
    cfg.addSensor(sPres);

    cfg.setColor('temp warning',  [1.0 0.8 0.0]);
    cfg.setColor('temp critical', [1.0 0.2 0.0]);
    cfg.setColor('pressure low',  [0.2 0.5 1.0]);

    % Run detection - events are automatically saved to eventFile
    events = cfg.runDetection();
    fprintf('  Detected %d events, saved to file.\n\n', numel(events));

    % --- Part 2: Open viewer from file ---
    fprintf('--- Part 2: Opening EventViewer from saved file ---\n');
    fprintf('  Loading: %s\n', eventFile);

    viewer = EventViewer.fromFile(eventFile);
    fprintf('  Viewer opened with %d events.\n', numel(viewer.Events));
    fprintf('  Figure title shows save timestamp.\n\n');

    % --- Part 3: Run detection again to demonstrate backup ---
    fprintf('--- Part 3: Running detection again (backup created) ---\n');

    % Add some more data
    tNew = (N:N+99) * dt;
    tempNew = 70 + 5*sin(tNew/5) + 2*randn(1, 100);
    tempNew(40:60) = tempNew(40:60) + 25;
    presNew = 6 + 0.5*sin(tNew/3) + 0.3*randn(1, 100);

    sTemp.X = [t, tNew]; sTemp.Y = [temp, tempNew];
    sPres.X = [t, tNew]; sPres.Y = [pressure, presNew];

    % Update sensor data in config
    cfg.SensorData(1).t = sTemp.X;
    cfg.SensorData(1).y = sTemp.Y;
    cfg.SensorData(2).t = sPres.X;
    cfg.SensorData(2).y = sPres.Y;

    events2 = cfg.runDetection();
    fprintf('  Detected %d events, saved (previous version backed up).\n', numel(events2));

    % Show backup files
    [fDir, fName, fExt] = fileparts(eventFile);
    backups = dir(fullfile(fDir, [fName, '_*', fExt]));
    fprintf('  Backup files:\n');
    for i = 1:numel(backups)
        fprintf('    %s\n', backups(i).name);
    end
    fprintf('\nDone.\n');
end
