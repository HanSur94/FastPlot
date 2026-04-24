function example_event_markers
    %EXAMPLE_EVENT_MARKERS Phase 1012 demo — live event markers + click-details on FastSenseWidget.
    %
    %   Demonstrates:
    %     1. A SensorTag with a simulated threshold-exceedance sequence
    %     2. A MonitorTag binding to an EventStore
    %     3. A FastSenseWidget with ShowEventMarkers=true
    %     4. Live-tick appendData calls that produce an open event
    %        (hollow marker) and then close it (filled marker)
    %     5. Click-to-details panel on marker click (manual follow-up)
    %
    %   Usage:
    %     example_event_markers
    %
    %   See also FastSenseWidget, MonitorTag, EventStore.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root); install();

    % 1. Parent SensorTag with initial quiet history
    parent = SensorTag('pump_a_pressure');
    parent.updateData([0 1 2 3 4 5], [1 1 1 1 1 1]);

    % 2. EventStore + MonitorTag with a threshold at y > 5
    es = EventStore('');
    mon = MonitorTag('pump_a_high', parent, @(x, y) y > 5, 'EventStore', es);

    % 3. Build a dashboard with a FastSenseWidget wired to ShowEventMarkers
    d = DashboardEngine('Title', 'Phase 1012 demo');
    d.addWidget('fastsense', 'Title', 'Pump A Pressure', ...
        'Tag', parent, 'Position', [1 1 12 4], ...
        'ShowEventMarkers', true, ...
        'EventStore', es);
    d.render();

    fprintf('Rising edge at t=7 -> open event should appear HOLLOW.\n');
    pause(1);
    parent.appendData([6 7 8 9], [1 10 10 10]);
    mon.appendData([6 7 8 9], [1 10 10 10]);
    d.onLiveTick();
    drawnow;

    fprintf('Falling edge at t=12 -> marker should become FILLED.\n');
    pause(2);
    parent.appendData([10 11 12 13], [10 10 1 1]);
    mon.appendData([10 11 12 13], [10 10 1 1]);
    d.onLiveTick();
    drawnow;

    fprintf('Click any marker to open the details panel; ESC / click-outside / X button to dismiss.\n');
end
