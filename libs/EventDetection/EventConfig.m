classdef EventConfig < handle
    %EVENTCONFIG Configuration for the event detection system.
    %   cfg = EventConfig()
    %   cfg.MinDuration = 2;
    %   cfg.addSensor(sensor);
    %   events = cfg.runDetection();

    properties
        Sensors           % cell array of Sensor objects
        SensorData        % struct array: name, t, y (for viewer click-to-plot)
        MinDuration       % numeric: debounce (default 0)
        MaxCallsPerEvent  % numeric: callback limit (default 1)
        OnEventStart      % function handle: callback
        ThresholdColors   % containers.Map: label -> [R G B]
        AutoOpenViewer    % logical: auto-open EventViewer after detection
    end

    methods
        function obj = EventConfig()
            obj.Sensors = {};
            obj.SensorData = [];
            obj.MinDuration = 0;
            obj.MaxCallsPerEvent = 1;
            obj.OnEventStart = [];
            obj.ThresholdColors = containers.Map();
            obj.AutoOpenViewer = false;
        end

        function addSensor(obj, sensor)
            %ADDSENSOR Register a sensor with its data.
            sensor.resolve();
            obj.Sensors{end+1} = sensor;

            % Store data for viewer
            if ~isempty(sensor.Name)
                name = sensor.Name;
            else
                name = sensor.Key;
            end
            entry.name = name;
            entry.t = sensor.X;
            entry.y = sensor.Y;

            if isempty(obj.SensorData)
                obj.SensorData = entry;
            else
                obj.SensorData(end+1) = entry;
            end
        end

        function setColor(obj, label, rgb)
            %SETCOLOR Set color for a threshold label.
            obj.ThresholdColors(label) = rgb;
        end

        function det = buildDetector(obj)
            %BUILDDETECTOR Create a configured EventDetector.
            args = {'MinDuration', obj.MinDuration, ...
                    'MaxCallsPerEvent', obj.MaxCallsPerEvent};
            if ~isempty(obj.OnEventStart)
                args = [args, {'OnEventStart', obj.OnEventStart}];
            end
            det = EventDetector(args{:});
        end

        function events = runDetection(obj)
            %RUNDETECTION Detect events across all configured sensors.
            det = obj.buildDetector();
            events = [];

            for i = 1:numel(obj.Sensors)
                newEvents = detectEventsFromSensor(obj.Sensors{i}, det);
                if isempty(events)
                    events = newEvents;
                elseif ~isempty(newEvents)
                    events = [events, newEvents];
                end
            end

            if obj.AutoOpenViewer && ~isempty(events)
                if isempty(obj.ThresholdColors) || obj.ThresholdColors.Count == 0
                    EventViewer(events, obj.SensorData);
                else
                    EventViewer(events, obj.SensorData, obj.ThresholdColors);
                end
            end
        end
    end
end
