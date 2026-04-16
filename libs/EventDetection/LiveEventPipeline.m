classdef LiveEventPipeline < handle
    % LiveEventPipeline  Orchestrates live event detection.
    %
    %   Supports two kinds of live targets:
    %     Sensors        — legacy containers.Map of key -> Sensor; processed
    %                      via IncrementalEventDetector.process (full recompute).
    %     MonitorTargets — NEW v2.0 containers.Map of key -> MonitorTag;
    %                      processed via MonitorTag.appendData (Phase 1007
    %                      MONITOR-08 streaming tail extension). Realizes
    %                      Phase 1007 Success Criterion #4 end-to-end.
    %
    %   Ordering invariant (Pitfall Y) — enforced by processMonitorTag_:
    %     monitor.Parent.updateData(newX, newY)  ← called FIRST
    %     monitor.appendData(newX, newY)         ← THEN
    %   The reverse order causes cache incoherence: MonitorTag.appendData's
    %   cold path recomputes against a stale parent grid.  See the docstring
    %   at libs/SensorThreshold/MonitorTag.m lines 330-334 for the contract.
    %
    %   Legacy Sensor path preserved byte-for-byte — tests/test_live_pipeline.m
    %   is the regression gate.

    properties
        Sensors              % containers.Map: key -> Sensor (LEGACY, unchanged)
        MonitorTargets       % containers.Map: key -> MonitorTag (NEW v2.0)
        DataSourceMap        % DataSourceMap
        EventStore           % EventStore
        NotificationService  % NotificationService
        Interval            = 15     % seconds
        Status              = 'stopped'
        MinDuration         = 0
        EscalateSeverity    = true
        MaxCallsPerEvent    = 1
        OnEventStart        = []
    end

    properties (Access = private)
        timer_
        detector_       % IncrementalEventDetector
        cycleCount_     = 0
    end

    methods
        function obj = LiveEventPipeline(sensors, dataSourceMap, varargin)
            defaults.EventFile         = '';
            defaults.Interval          = 15;
            defaults.MinDuration       = 0;
            defaults.EscalateSeverity  = true;
            defaults.MaxBackups        = 5;
            defaults.MaxCallsPerEvent  = 1;
            defaults.OnEventStart      = [];
            defaults.Monitors          = [];   % NEW — optional MonitorTag map
            opts = parseOpts(defaults, varargin);

            obj.Sensors       = sensors;
            obj.DataSourceMap = dataSourceMap;
            obj.Interval      = opts.Interval;
            obj.MinDuration   = opts.MinDuration;
            obj.EscalateSeverity = opts.EscalateSeverity;
            obj.MaxCallsPerEvent = opts.MaxCallsPerEvent;
            obj.OnEventStart     = opts.OnEventStart;

            % Initialize MonitorTargets — empty map when no 'Monitors' NV
            % pair is provided.  This preserves the legacy constructor
            % call shape (sensors, dsMap, varargin) for existing callers.
            if isa(opts.Monitors, 'containers.Map')
                obj.MonitorTargets = opts.Monitors;
            else
                obj.MonitorTargets = containers.Map( ...
                    'KeyType', 'char', 'ValueType', 'any');
            end

            if ~isempty(opts.EventFile)
                obj.EventStore = EventStore(opts.EventFile, ...
                    'MaxBackups', opts.MaxBackups);
            end

            obj.detector_ = IncrementalEventDetector( ...
                'MinDuration', obj.MinDuration, ...
                'EscalateSeverity', obj.EscalateSeverity, ...
                'MaxCallsPerEvent', obj.MaxCallsPerEvent, ...
                'OnEventStart', obj.OnEventStart);

            obj.NotificationService = NotificationService('DryRun', true);
        end

        function start(obj)
            if strcmp(obj.Status, 'running'); return; end
            obj.Status = 'running';
            obj.timer_ = timer('ExecutionMode', 'fixedSpacing', ...
                'Period', obj.Interval, ...
                'TimerFcn', @(~,~) obj.timerCallback(), ...
                'ErrorFcn', @(~,~) obj.timerError());
            start(obj.timer_);
            fprintf('[PIPELINE] Started (interval=%ds)\n', obj.Interval);
        end

        function stop(obj)
            if ~isempty(obj.timer_)
                try
                    if isvalid(obj.timer_)
                        stop(obj.timer_);
                        delete(obj.timer_);
                    end
                catch
                end
            end
            obj.timer_ = [];
            obj.Status = 'stopped';
            % Flush store
            if ~isempty(obj.EventStore)
                obj.EventStore.save();
            end
            fprintf('[PIPELINE] Stopped\n');
        end

        function runCycle(obj)
            obj.cycleCount_ = obj.cycleCount_ + 1;
            allNewEvents = [];
            hasNewData = false;

            % --- Legacy Sensor path (UNCHANGED) ---------------------------
            sensorKeys = obj.Sensors.keys();
            for i = 1:numel(sensorKeys)
                key = sensorKeys{i};
                try
                    [newEvents, gotData] = obj.processSensor(key);
                    hasNewData = hasNewData || gotData;
                    if ~isempty(newEvents)
                        if isempty(allNewEvents)
                            allNewEvents = newEvents;
                        else
                            allNewEvents = [allNewEvents, newEvents];
                        end
                    end
                catch ex
                    fprintf('[PIPELINE WARNING] Sensor "%s" failed: %s\n', key, ex.message);
                end
            end

            % --- MonitorTag path (NEW v2.0 — Phase 1007 SC#4 realization) -
            monitorKeys = obj.MonitorTargets.keys();
            for i = 1:numel(monitorKeys)
                key = monitorKeys{i};
                % Collision rule: if a key appears in BOTH maps, Sensors
                % wins (legacy preservation).  Skip the monitor branch.
                if obj.Sensors.isKey(key)
                    continue;
                end
                try
                    [newEvents, gotData] = obj.processMonitorTag_(key);
                    hasNewData = hasNewData || gotData;
                    if ~isempty(newEvents)
                        if isempty(allNewEvents)
                            allNewEvents = newEvents;
                        else
                            allNewEvents = [allNewEvents, newEvents];
                        end
                    end
                catch ex
                    fprintf('[PIPELINE WARNING] MonitorTag "%s" failed: %s\n', ...
                        key, ex.message);
                end
            end

            % Update sensor data in store only when new data arrived
            if ~isempty(obj.EventStore) && hasNewData
                obj.updateStoreSensorData();
            end

            % Write to store
            if ~isempty(obj.EventStore) && ~isempty(allNewEvents)
                obj.EventStore.append(allNewEvents);
                try
                    obj.EventStore.save();
                catch ex
                    fprintf('[PIPELINE WARNING] Store write failed: %s\n', ex.message);
                end
            elseif ~isempty(obj.EventStore) && obj.cycleCount_ == 1
                % Save even if no events on first cycle (creates the file)
                obj.EventStore.save();
            end

            % Send notifications
            if ~isempty(obj.NotificationService)
                for i = 1:numel(allNewEvents)
                    ev = allNewEvents(i);
                    sd = obj.buildSensorData(ev.SensorName);
                    try
                        obj.NotificationService.notify(ev, sd);
                    catch ex
                        fprintf('[PIPELINE WARNING] Notification failed: %s\n', ex.message);
                    end
                end
            end

            if ~isempty(allNewEvents)
                fprintf('[PIPELINE] Cycle %d: %d new events\n', obj.cycleCount_, numel(allNewEvents));
            end
        end
    end

    methods (Access = private)
        function [newEvents, gotData] = processSensor(obj, key)
            newEvents = [];
            gotData = false;

            if ~obj.DataSourceMap.has(key)
                return;
            end

            ds = obj.DataSourceMap.get(key);
            result = ds.fetchNew();

            if ~result.changed
                return;
            end

            gotData = true;

            sensor = obj.Sensors(key);

            newEvents = obj.detector_.process(key, sensor, ...
                result.X, result.Y, result.stateX, result.stateY);
        end

        function [newEvents, gotData] = processMonitorTag_(obj, key)
            %PROCESSMONITORTAG_ Tag-first live-tick path (SC#4 realization).
            %
            %   Phase 1007 MONITOR-08 contract: MonitorTag.appendData
            %   expects the monitor's Parent to already carry the new
            %   (newX, newY) tail samples before the call — so we call
            %   parent.updateData FIRST with the accumulated full grid,
            %   then appendData with the NEW tail.  Wrong order causes
            %   cache incoherence (appendData cold-path recomputes
            %   against stale parent data).  This is the Pitfall Y
            %   invariant, guarded by
            %   test_live_event_pipeline_tag -> test_append_data_order_with_parent.
            %
            %   SensorTag.updateData REPLACES the parent's X/Y (it is not
            %   an appender — that's a Phase 1005 design choice) so we
            %   first snapshot the parent's current grid via getXY(),
            %   then pass the concatenated (old + new) grid to
            %   updateData().  This keeps MonitorTag.appendData's fast
            %   path available once the cache warms up — the cascade
            %   invalidation from updateData marks the monitor dirty,
            %   but the very next appendData call refills the cache
            %   against the full grid.
            %
            %   Events are harvested as the delta of the monitor's bound
            %   EventStore size before and after appendData
            %   (MonitorTag.fireEventsOnRisingEdges_ /
            %   MonitorTag.fireEventsInTail_ write events directly — see
            %   libs/SensorThreshold/MonitorTag.m).
            newEvents = [];
            gotData   = false;
            if ~obj.DataSourceMap.has(key)
                return;
            end
            ds     = obj.DataSourceMap.get(key);
            result = ds.fetchNew();
            if ~result.changed
                return;
            end
            gotData = true;
            monitor = obj.MonitorTargets(key);

            % Snapshot the monitor's bound EventStore BEFORE appendData so
            % we can harvest only the events emitted on this tick.
            preStore = monitor.EventStore;
            preCount = 0;
            if ~isempty(preStore)
                preCount = preStore.numEvents();
            end

            % Snapshot the parent's current grid so we can hand it the
            % accumulated (old + new) grid.  SensorTag.updateData replaces
            % X/Y; without this concatenation the parent would lose its
            % history on each tick and MonitorTag.appendData's cold path
            % would recompute over just the tail.
            if ismethod(monitor.Parent, 'getXY')
                [oldX, oldY] = monitor.Parent.getXY();
            else
                oldX = [];
                oldY = [];
            end
            newX = result.X;
            newY = result.Y;
            fullX = [oldX(:).', newX(:).'];
            fullY = [oldY(:).', newY(:).'];

            % CRITICAL ORDERING (Pitfall Y): parent.updateData BEFORE
            % monitor.appendData.  See MonitorTag.m:330-334 docstring.
            if ismethod(monitor.Parent, 'updateData')
                monitor.Parent.updateData(fullX, fullY);
            else
                error('LiveEventPipeline:parentNoUpdateData', ...
                    ['MonitorTag parent "%s" does not support updateData — ' ...
                     'cannot drive live tick.'], monitor.Parent.Key);
            end
            monitor.appendData(newX, newY);

            % Harvest delta from the monitor's bound EventStore (if any).
            if ~isempty(preStore)
                allEvts = preStore.getEvents();
                postCount = numel(allEvts);
                if postCount > preCount
                    newEvents = allEvts((preCount+1):postCount);
                end
            end
        end

        function sd = buildSensorData(obj, sensorKey)
            % Build sensorData struct for snapshot generation.
            %
            % Tag-originated events (from MonitorTag via MONITOR-05 carrier)
            % set SensorName = parent.Key — that key may not exist in
            % obj.Sensors (legacy map).  Emit a minimal struct in that
            % case to keep notifications flowing without crashing.
            st = obj.detector_.getSensorState(sensorKey);
            if ~obj.Sensors.isKey(sensorKey)
                sd = struct('X', [], 'Y', [], ...
                    'thresholdValue', NaN, 'thresholdDirection', 'upper');
                return;
            end
            sensor = obj.Sensors(sensorKey);

            thVal = NaN;
            thDir = 'upper';
            if ~isempty(sensor.Thresholds)
                vals = sensor.Thresholds{1}.allValues();
                if ~isempty(vals)
                    thVal = vals(1);
                end
                thDir = sensor.Thresholds{1}.Direction;
            end

            sd = struct('X', st.fullX, 'Y', st.fullY, ...
                'thresholdValue', thVal, 'thresholdDirection', thDir);
        end

        function updateStoreSensorData(obj)
            % Build sensorData struct array from detector state for EventViewer.
            %
            % Iterates only obj.Sensors.keys() (legacy path) — Tag-backed
            % MonitorTag targets are NOT surfaced into store.SensorData in
            % Phase 1009.  Phase 1010 revisits SensorData semantics for
            % Tag-originated events (EVENT-01 Tag-keyed sensor data).
            sensorKeys = obj.Sensors.keys();
            sd = struct('name', {}, 't', {}, 'y', {}, 'thresholds', {});
            for i = 1:numel(sensorKeys)
                key = sensorKeys{i};
                st = obj.detector_.getSensorState(key);
                if ~isempty(st.fullX)
                    sd(end+1).name = key; %#ok<AGROW>
                    sd(end).t = st.fullX;
                    sd(end).y = st.fullY;
                    % Store threshold handles for reconstruction in EventViewer
                    sensor = obj.Sensors(key);
                    sd(end).thresholds = sensor.Thresholds;
                end
            end
            obj.EventStore.SensorData = sd;
        end

        function timerCallback(obj)
            try
                obj.runCycle();
            catch ex
                fprintf('[PIPELINE ERROR] Cycle failed: %s\n', ex.message);
            end
        end

        function timerError(obj)
            obj.Status = 'error';
            fprintf('[PIPELINE] Timer error — status set to error\n');
        end
    end
end
