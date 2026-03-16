%% Dashboard Engine — Live Mode Demo
% Demonstrates every widget type updating in real time. A background timer
% simulates incoming sensor data (temperature, pressure, flow) and the
% dashboard refreshes automatically so you can watch values change.
%
%   Widget types shown:
%     text       — static header (no refresh needed)
%     kpi        — big number driven by ValueFcn
%     status     — colored indicator driven by StatusFcn
%     rawaxes    — live time-series plots via PlotFcn
%     gauge      — arc gauge driven by ValueFcn
%     rawaxes    — live histogram redrawn each tick
%     table      — alarm log driven by DataFcn
%     timeline   — machine mode events driven by EventFcn
%
% Usage:
%   example_dashboard_live
%
% Press "Live" in the toolbar to start/stop the update timer.
% Close the figure to clean up the background data timer.

close all force;
clear functions;

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

example_dashboard_live_run();

function example_dashboard_live_run()
%EXAMPLE_DASHBOARD_LIVE_RUN Main function — nested functions share workspace
%   so all callbacks see the latest state without handle-class boilerplate.

    %% ========== Shared live state ==========
    S.t    = zeros(1, 0);
    S.temp = zeros(1, 0);
    S.pres = zeros(1, 0);
    S.flow = zeros(1, 0);
    S.mode = 'idle';
    S.alarms = {};
    S.modeEvents = struct('startTime', {}, 'endTime', {}, 'label', {}, 'color', {});

    % Mode schedule: cycle through modes
    modeSchedule  = {'idle', 'running', 'running', 'maintenance', 'running', 'idle'};
    modeDurations  = [15, 30, 25, 10, 30, 20];  % seconds per mode

    % Seed with a few seconds of history
    rng('shuffle');
    nSeed = 50;
    tSeed = linspace(-5, 0, nSeed);
    S.t    = tSeed;
    S.temp = 70 + 2*sin(2*pi*tSeed/10) + randn(1, nSeed)*0.5;
    S.pres = 50 + 5*sin(2*pi*tSeed/15) + randn(1, nSeed)*1.0;
    S.flow = 120 + 8*sin(2*pi*tSeed/8)  + randn(1, nSeed)*2.0;

    S.modeEvents(1) = struct('startTime', -5, 'endTime', 0, ...
        'label', 'Idle', 'color', [0.6 0.6 0.6]);

    %% ========== Data generation timer (10 Hz) ==========
    tStart = tic;
    hDataTimer = timer('ExecutionMode', 'fixedRate', ...
        'Period', 0.1, ...
        'TimerFcn', @(~,~) updateState());

    %% ========== Build Dashboard ==========
    d = DashboardEngine('Live Process Monitoring');
    d.Theme = 'light';
    d.LiveInterval = 1;

    % --- Row 1-2: Header + KPIs + Status ---
    d.addWidget('text', 'Title', 'Live Monitor', ...
        'Position', [1 1 4 2], ...
        'Content', 'Simulated Process', ...
        'FontSize', 14, ...
        'Alignment', 'left');

    d.addWidget('kpi', 'Title', 'Temperature', ...
        'Position', [5 1 5 2], ...
        'Units', [char(176) 'F'], ...
        'Format', '%.1f', ...
        'ValueFcn', @getTemp);

    d.addWidget('kpi', 'Title', 'Pressure', ...
        'Position', [10 1 5 2], ...
        'Units', 'psi', ...
        'Format', '%.0f', ...
        'ValueFcn', @getPres);

    d.addWidget('status', 'Title', 'Temp', ...
        'Position', [15 1 5 2], ...
        'StatusFcn', @tempStatus);

    d.addWidget('status', 'Title', 'Press', ...
        'Position', [20 1 5 2], ...
        'StatusFcn', @presStatus);

    % --- Row 3-10: Live time-series plots ---
    d.addWidget('rawaxes', 'Title', 'Temperature', ...
        'Position', [1 3 12 8], ...
        'PlotFcn', @plotTemp, ...
        'DataRangeFcn', @getDataRange);

    d.addWidget('rawaxes', 'Title', 'Pressure', ...
        'Position', [13 3 12 8], ...
        'PlotFcn', @plotPres, ...
        'DataRangeFcn', @getDataRange);

    % --- Row 11-18: Flow + Gauge + Histogram ---
    d.addWidget('rawaxes', 'Title', 'Flow Rate', ...
        'Position', [1 11 12 8], ...
        'PlotFcn', @plotFlow, ...
        'DataRangeFcn', @getDataRange);

    d.addWidget('gauge', 'Title', 'Flow', ...
        'Position', [13 11 6 6], ...
        'Range', [0 170], ...
        'Units', 'L/min', ...
        'ValueFcn', @getFlow);

    d.addWidget('rawaxes', 'Title', 'Temp Distribution', ...
        'Position', [19 11 6 6], ...
        'PlotFcn', @plotHist);

    % --- Row 17-20: Table + Timeline ---
    d.addWidget('table', 'Title', 'Alarm Log', ...
        'Position', [13 17 12 4], ...
        'ColumnNames', {'Time', 'Tag', 'Value', 'Severity'}, ...
        'DataFcn', @getAlarms);

    d.addWidget('timeline', 'Title', 'Machine Mode', ...
        'Position', [1 19 24 3], ...
        'EventFcn', @getEvents);

    %% ========== Render and go live ==========
    d.render();
    start(hDataTimer);
    d.startLive();

    fprintf('Dashboard is LIVE — data at 10 Hz, display refreshes every %d s.\n', ...
        d.LiveInterval);
    fprintf('Close the figure to stop.\n');

    % Clean up data timer when figure closes (engine handles its own timer)
    origCloseFcn = get(d.hFigure, 'CloseRequestFcn');
    set(d.hFigure, 'CloseRequestFcn', ...
        @(src,~) cleanupAndClose(hDataTimer, origCloseFcn, src));

    %% ==================== Nested: data update ====================
    function updateState()
        elapsed = toc(tStart);

        % Determine current mode from schedule
        cumDur = cumsum(modeDurations);
        cycleT = mod(elapsed, cumDur(end));
        mIdx = find(cycleT < cumDur, 1);
        newMode = modeSchedule{mIdx};

        if ~strcmp(newMode, S.mode)
            % Close previous event, open new one
            if ~isempty(S.modeEvents)
                S.modeEvents(end).endTime = elapsed;
            end
            switch newMode
                case 'idle',        lbl = 'Idle';        clr = [0.6 0.6 0.6];
                case 'running',     lbl = 'Running';     clr = [0.2 0.7 0.3];
                case 'maintenance', lbl = 'Maintenance'; clr = [1.0 0.6 0.1];
                otherwise,          lbl = newMode;        clr = [0.5 0.5 0.5];
            end
            S.modeEvents(end+1) = struct('startTime', elapsed, ...
                'endTime', elapsed + 0.1, 'label', lbl, 'color', clr);
            S.mode = newMode;
        else
            if ~isempty(S.modeEvents)
                S.modeEvents(end).endTime = elapsed;
            end
        end

        % Generate sensor values based on mode
        switch S.mode
            case 'idle',        tB = 68; pB = 30; fB = 5;
            case 'running',     tB = 76; pB = 58; fB = 125;
            case 'maintenance', tB = 64; pB = 20; fB = 0;
            otherwise,          tB = 70; pB = 40; fB = 60;
        end

        newT = tB + 3*sin(2*pi*elapsed/10) + randn*0.8;
        newP = pB + 6*sin(2*pi*elapsed/15) + randn*1.2;
        newF = max(0, fB + 8*sin(2*pi*elapsed/8) + randn*3);

        S.t(end+1)    = elapsed;
        S.temp(end+1) = newT;
        S.pres(end+1) = newP;
        S.flow(end+1) = newF;

        % Threshold alarms (running mode only)
        if strcmp(S.mode, 'running')
            if newT > 82
                logAlarm(elapsed, 'T-401', newT, 'Hi Alarm');
            elseif newT > 78
                logAlarm(elapsed, 'T-401', newT, 'Hi Warn');
            end
            if newP > 68
                logAlarm(elapsed, 'P-201', newP, 'Hi Alarm');
            elseif newP > 64
                logAlarm(elapsed, 'P-201', newP, 'Hi Warn');
            end
            if newF > 145
                logAlarm(elapsed, 'F-301', newF, 'Hi Alarm');
            end
        end
    end

    function logAlarm(elapsed, tag, val, severity)
        mins = floor(elapsed / 60);
        secs = floor(mod(elapsed, 60));
        S.alarms(end+1, :) = {sprintf('%02d:%02d', mins, secs), ...
            tag, sprintf('%.1f', val), severity};
        if size(S.alarms, 1) > 12
            S.alarms = S.alarms(end-11:end, :);
        end
    end

    %% ==================== Nested: value callbacks ====================
    function v = getTemp(),  v = S.temp(end); end
    function v = getPres(),  v = S.pres(end); end
    function v = getFlow(),  v = S.flow(end); end
    function a = getAlarms(), a = S.alarms;   end
    function e = getEvents(), e = S.modeEvents; end
    function r = getDataRange(), r = [S.t(1), S.t(end)]; end

    function st = tempStatus()
        v = S.temp(end);
        if v > 82,     st = 'alarm';
        elseif v > 78, st = 'warning';
        else,          st = 'ok';
        end
    end

    function st = presStatus()
        v = S.pres(end);
        if v > 68,     st = 'alarm';
        elseif v > 64, st = 'warning';
        else,          st = 'ok';
        end
    end

    %% ==================== Nested: plot callbacks ====================
    function plotTemp(ax, tRange)
        if nargin < 2, tRange = []; end
        plotTimeSeries(ax, tRange, S.t, S.temp, 'Temperature', ...
            [char(176) 'F'], [60 90], [78 82]);
    end

    function plotPres(ax, tRange)
        if nargin < 2, tRange = []; end
        plotTimeSeries(ax, tRange, S.t, S.pres, 'Pressure', ...
            'psi', [10 80], [64 68]);
    end

    function plotFlow(ax, tRange)
        if nargin < 2, tRange = []; end
        plotTimeSeries(ax, tRange, S.t, S.flow, 'Flow Rate', ...
            'L/min', [0 170], [135 145]);
    end

    function plotTimeSeries(ax, tRange, t, y, titleStr, yLbl, yRange, thresh)
        if numel(t) < 2, return; end

        % Use time range from sliders, or default to last 60 seconds
        if ~isempty(tRange)
            mask = t >= tRange(1) & t <= tRange(2);
        else
            tNow = t(end);
            mask = t >= tNow - 60;
        end
        tV = t(mask);
        yV = y(mask);
        if numel(tV) < 2, return; end

        plot(ax, tV, yV, 'LineWidth', 1.5, 'Color', [0.31 0.80 0.64]);
        hold(ax, 'on');
        if ~isempty(thresh)
            yline(ax, thresh(1), '--', 'Color', [1 0.8 0], 'LineWidth', 1);
            if numel(thresh) > 1
                yline(ax, thresh(2), '-', 'Color', [1 0.2 0.2], 'LineWidth', 1);
            end
        end
        hold(ax, 'off');
        ylim(ax, yRange);
        xlim(ax, [tV(1), tV(end)]);
        xlabel(ax, 'Time (s)');
        ylabel(ax, yLbl);
        title(ax, titleStr);
        grid(ax, 'on');
    end

    function plotHist(ax)
        if numel(S.temp) < 2, return; end
        nH = min(numel(S.temp), 600);
        histogram(ax, S.temp(end-nH+1:end), 30, ...
            'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none');
        xlabel(ax, [char(176) 'F']);
        ylabel(ax, 'Count');
        title(ax, 'Temp Distribution');
    end
end

%% ========== Cleanup ==========
function cleanupAndClose(hTimer, origCloseFcn, src)
    if strcmp(hTimer.Running, 'on')
        stop(hTimer);
    end
    delete(hTimer);
    % Call the engine's original CloseRequestFcn (stops live timer + deletes figure)
    if isa(origCloseFcn, 'function_handle')
        origCloseFcn(src, []);
    else
        delete(src);
    end
end
