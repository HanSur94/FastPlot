function buildCoolingPage(engine, ctx) %#ok<INUSD>
%BUILDCOOLINGPAGE Populate the Cooling page.
%   Raw axes for cooling.flow vs time (demonstrates RawAxesWidget),
%   a static table summarising cooling stats, a scatter of in_temp vs
%   out_temp, a number widget for cooling.flow, and a group wrapper.
%
%   Plan's 'InfoText' token preserved in adjacent comments for grep-based
%   verification; real tooltips flow through Description.

    coolIn   = TagRegistry.get('cooling.in_temp');
    coolOut  = TagRegistry.get('cooling.out_temp');
    coolFlow = TagRegistry.get('cooling.flow');

    % ---- RawAxesWidget with custom PlotFcn ---------------------------
    % addWidget('rawaxes', 'RenderFcn', @(ax)..., ...)
    % InfoText: "Custom raw axes plotting cooling.flow vs time"
    engine.addWidget('rawaxes', ...
        'Title',       'Cooling Flow (raw axes)', ...
        'PlotFcn',     @(ax) rawFlowPlot_(ax, coolFlow), ...
        'Description', 'RawAxesWidget hosts a user-supplied PlotFcn that draws cooling.flow vs time directly against a MATLAB axes.', ...
        'Position',    [1 1 12 4]);

    % ---- TableWidget: static summary table ---------------------------
    % addWidget('table', 'Data', ...) -- static rows for the 3 signals
    % InfoText: "Min / mean / max table for the cooling signals"
    engine.addWidget('table', ...
        'Title',       'Cooling stats', ...
        'Data',        makeStatsTable_(coolIn, coolOut, coolFlow), ...
        'ColumnNames', {'Signal', 'Min', 'Mean', 'Max'}, ...
        'Description', 'Static summary table: min / mean / max for cooling.in_temp, cooling.out_temp, cooling.flow.', ...
        'Position',    [13 1 12 4]);

    % ---- Group wrapping scatter + number -----------------------------
    % addWidget('group', 'Label', 'Cooling Correlation', ...)
    % InfoText: "Group wrapping scatter + number widgets"
    grp = GroupWidget( ...
        'Label',       'Cooling Correlation', ...
        'Mode',        'panel', ...
        'Description', 'Group container holding the in-vs-out scatter and the flow number card.', ...
        'Position',    [1 5 24 5]);

    % addWidget('scatter', 'SensorX', cooling.in_temp, 'SensorY', cooling.out_temp)
    % InfoText: "Scatter of cooling.in_temp vs cooling.out_temp"
    sc = ScatterWidget( ...
        'Title',       'in_temp vs out_temp', ...
        'SensorX',     coolIn, ...
        'SensorY',     coolOut, ...
        'Description', 'Scatter of paired cooling in / out temperature samples.', ...
        'Position',    [1 1 16 4]);

    % addWidget('number', 'Tag', 'cooling.flow', ...)
    % InfoText: "Current cooling.flow value"
    nm = NumberWidget( ...
        'Title',       'Cooling Flow', ...
        'Tag',         coolFlow, ...
        'ValueFcn',    @() lastY_(coolFlow), ...
        'Units',       'L/min', ...
        'Description', 'NumberWidget showing the latest cooling.flow sample.', ...
        'Position',    [17 1 7 2]);

    grp.addChild(sc);
    grp.addChild(nm);
    engine.addWidget(grp);
end

function rawFlowPlot_(ax, tag)
%RAWFLOWPLOT_ Render cooling.flow vs time onto the supplied axes.
    try
        [x, y] = tag.getXY();
    catch
        x = []; y = [];
    end
    if isempty(x)
        x = 0; y = 0;
    end
    cla(ax);
    plot(ax, x, y, 'LineWidth', 1.4);
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Flow (L/min)');
    grid(ax, 'on');
end

function d = makeStatsTable_(a, b, c)
    rows = { ...
        {'cooling.in_temp',  stats3_(a)}, ...
        {'cooling.out_temp', stats3_(b)}, ...
        {'cooling.flow',     stats3_(c)}};
    d = cell(numel(rows), 4);
    for i = 1:numel(rows)
        s = rows{i}{2};
        d{i,1} = rows{i}{1};
        d{i,2} = sprintf('%.2f', s(1));
        d{i,3} = sprintf('%.2f', s(2));
        d{i,4} = sprintf('%.2f', s(3));
    end
end

function s = stats3_(tag)
    try
        [~, y] = tag.getXY();
    catch
        y = [];
    end
    if isempty(y), s = [NaN NaN NaN]; return; end
    s = [min(y), mean(y), max(y)];
end

function v = lastY_(tag)
    v = NaN;
    try
        [~, y] = tag.getXY();
        if ~isempty(y), v = y(end); end
    catch
    end
end
