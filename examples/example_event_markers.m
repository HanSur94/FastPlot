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
    d = DashboardEngine('Phase 1012 demo');
    d.addWidget('fastsense', 'Title', 'Pump A Pressure', ...
        'Tag', parent, 'Position', [1 1 12 4], ...
        'ShowEventMarkers', true, ...
        'EventStore', es);
    d.render();

    % Overlay a visible threshold line at y=5 (the MonitorTag condition y>5).
    % FastSense.addThreshold must be called before render(); here we're post-
    % render, so draw a plain horizontal reference line + label directly on
    % the axes. Persists across incremental refreshes (Phase 1000 behavior).
    ax = d.Widgets{1}.FastSenseObj.hAxes;
    xr = get(ax, 'XLim');
    hold(ax, 'on');
    line(ax, xr, [5 5], 'LineStyle', '--', 'Color', [0.95 0.40 0.25], ...
         'LineWidth', 1.2, 'HandleVisibility', 'off', 'Tag', 'demoThreshold');
    text(ax, xr(2), 5, '  y > 5 (MonitorTag threshold)', ...
         'Color', [0.95 0.40 0.25], 'VerticalAlignment', 'bottom', ...
         'HorizontalAlignment', 'right', 'Tag', 'demoThresholdLabel');
    hold(ax, 'off');

    fprintf('Rising edge at t=7 -> open event should appear HOLLOW.\n');
    pause(1);
    newX1 = [6 7 8 9];
    newY1 = [1 10 10 10];
    parent.updateData([parent.X, newX1], [parent.Y, newY1]);  % SensorTag: full replace
    mon.appendData(newX1, newY1);                              % MonitorTag: incremental
    d.onLiveTick();
    autoscaleY(d);
    drawnow;

    fprintf('Falling edge at t=12 -> marker should become FILLED.\n');
    pause(2);
    newX2 = [10 11 12 13];
    newY2 = [10 10 1 1];
    parent.updateData([parent.X, newX2], [parent.Y, newY2]);
    mon.appendData(newX2, newY2);
    d.onLiveTick();
    autoscaleY(d);
    drawnow;

    fprintf('Click any marker to open the details panel; ESC / click-outside / X button to dismiss.\n');
end

function autoscaleY(d)
    %AUTOSCALEY Force ylim='auto' on every FastSenseWidget's inner axes.
    %   The Phase-1000 incremental refresh path preserves the ylim set at
    %   the initial render so repeated zooms stay stable. For a demo where
    %   data range expands dramatically during a live tick, we explicitly
    %   reset ylim to auto after each onLiveTick. Also extends the demo
    %   threshold line to the new x-range so it always spans the whole plot.
    for i = 1:numel(d.Widgets)
        w = d.Widgets{i};
        if isa(w, 'FastSenseWidget') && ~isempty(w.FastSenseObj) && ...
                ~isempty(w.FastSenseObj.hAxes) && ishandle(w.FastSenseObj.hAxes)
            ax = w.FastSenseObj.hAxes;
            ylim(ax, 'auto');
            thr = findobj(ax, 'Tag', 'demoThreshold');
            if ~isempty(thr)
                xr = get(ax, 'XLim');
                set(thr, 'XData', xr);
            end
            lbl = findobj(ax, 'Tag', 'demoThresholdLabel');
            if ~isempty(lbl)
                xr = get(ax, 'XLim');
                set(lbl, 'Position', [xr(2), 5, 0]);
            end
        end
    end
end
