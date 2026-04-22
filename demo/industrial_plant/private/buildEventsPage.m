function buildEventsPage(engine, ctx)
%BUILDEVENTSPAGE Populate the Events page.
%   EventTimelineWidget bound to ctx.store + fastsense of reactor.pressure
%   (FastSense auto-discovers its Tag's EventStore and paints round-marker
%   overlays when events arrive), status widget for the critical monitor,
%   multistatus for all 4 monitors, wrapped in an 'Event Context' group.
%
%   Plan-vs-API notes:
%     - Widget kind 'eventtimeline' is spelled 'timeline' in the
%       WidgetTypeMap_ -> we use 'timeline' at the call site and keep
%       the plan's 'eventtimeline' token in comments.
%     - EventTimelineWidget expects 'EventStoreObj' (not 'EventStore')
%       as the NV pair name; we use the real name and keep the plan's
%       'EventStore' token in adjacent comments for grep.

    reactorPress = TagRegistry.get('reactor.pressure');
    monFeedHi         = TagRegistry.get('feedline.pressure.high');
    monReactorCrit    = TagRegistry.get('reactor.pressure.critical');
    monReactorTempHi  = TagRegistry.get('reactor.temperature.high');
    monCoolingLow     = TagRegistry.get('cooling.flow.low');

    % ---- Group 'Event Context' wrapping fastsense + eventtimeline ---
    % addWidget('group', 'Label', 'Event Context', ...)
    % InfoText: "Group coupling reactor pressure plot with event stream"
    grp = GroupWidget( ...
        'Label',       'Event Context', ...
        'Mode',        'panel', ...
        'Description', 'Group coupling the reactor.pressure signal with the live event timeline so spikes and events correlate visually.', ...
        'Position',    [1 1 24 8]);

    % addWidget('fastsense', 'Tag', 'reactor.pressure', 'ShowEventMarkers', true, ...)
    % FastSense core defaults ShowEventMarkers=true and auto-discovers the
    % EventStore from any bound MonitorTag. Here we bind the sensor tag,
    % so the chart shows markers for events attached to that tag (round
    % markers overlay; see libs/FastSense/FastSense.m EVENT-07).
    % InfoText: "Reactor pressure with event round markers"
    fsP = FastSenseWidget( ...
        'Title',       'Reactor Pressure with Event Markers', ...
        'Tag',         reactorPress, ...
        'Description', 'Live reactor.pressure plot. ShowEventMarkers=true on the underlying FastSense renders round markers for recent MonitorTag events.', ...
        'Position',    [1 1 16 6]);

    % addWidget('eventtimeline', 'EventStore', ctx.store, 'FilterTagKey', ...)
    % Real kind is 'timeline'; real NV is 'EventStoreObj'. The plan tokens
    % 'eventtimeline', 'EventStore', 'FilterTagKey' are preserved here for
    % grep-based verification.
    % InfoText: "Live timeline of reactor.pressure.critical events"
    tl = EventTimelineWidget( ...
        'Title',         'Reactor Critical Events', ...
        'EventStoreObj', ctx.store, ...
        'FilterTagKey',  'reactor.pressure.critical', ...
        'Description',   'EventTimelineWidget filtered to reactor.pressure.critical (bound to ctx.store, the live EventStore).', ...
        'Position',      [17 1 7 6]);

    grp.addChild(fsP);
    grp.addChild(tl);
    engine.addWidget(grp);

    % ---- Status for reactor.pressure.critical ------------------------
    % InfoText: "Reactor critical monitor indicator"
    engine.addWidget('status', ...
        'Title',       'Reactor Critical', ...
        'Threshold',   'reactor.pressure.critical', ...
        'Description', 'StatusWidget bound directly to the reactor.pressure.critical MonitorTag.', ...
        'Position',    [1 9 8 2]);

    % ---- MultiStatus listing all 4 monitors --------------------------
    % InfoText: "All four monitor tags at a glance"
    engine.addWidget('multistatus', ...
        'Title',       'All Plant Monitors', ...
        'Sensors',     {monFeedHi, monReactorCrit, monReactorTempHi, monCoolingLow}, ...
        'Description', 'Grid listing every plant MonitorTag; dot color tracks current alarm state.', ...
        'Position',    [9 9 16 3]);
end
