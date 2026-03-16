classdef EventDetector < handle
    %EVENTDETECTOR Detects events from threshold violations.
    %   det = EventDetector()
    %   det = EventDetector('MinDuration', 2, 'OnEventStart', @myCallback)
    %   events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)

    properties
        MinDuration      % numeric: minimum event duration (default 0)
        OnEventStart     % function handle: callback f(event) on new event
        MaxCallsPerEvent % numeric: max callback invocations per event (default 1)
    end

    methods
        function obj = EventDetector(varargin)
            obj.MinDuration = 0;
            obj.OnEventStart = [];
            obj.MaxCallsPerEvent = 1;

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'MinDuration',      obj.MinDuration = varargin{i+1};
                    case 'OnEventStart',     obj.OnEventStart = varargin{i+1};
                    case 'MaxCallsPerEvent', obj.MaxCallsPerEvent = varargin{i+1};
                    otherwise
                        error('EventDetector:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function events = detect(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)
            %DETECT Find events from threshold violations.
            %   events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)
            %   Returns Event array.

            groups = groupViolations(t, values, thresholdValue, direction);
            events = [];

            if isempty(groups)
                return;
            end

            for i = 1:numel(groups)
                si = groups(i).startIdx;
                ei = groups(i).endIdx;

                startTime = t(si);
                endTime   = t(ei);
                duration  = endTime - startTime;

                % Debounce filter
                if duration < obj.MinDuration
                    continue;
                end

                ev = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction);

                % Compute stats over all points in event window
                windowValues = values(si:ei);
                nPts    = numel(windowValues);
                minVal  = min(windowValues);
                maxVal  = max(windowValues);
                meanVal = mean(windowValues);
                rmsVal  = sqrt(mean(windowValues.^2));
                stdVal  = std(windowValues);

                if strcmp(direction, 'upper')
                    peakVal = maxVal;
                else
                    peakVal = minVal;
                end

                ev = ev.setStats(peakVal, nPts, minVal, maxVal, meanVal, rmsVal, stdVal);

                if isempty(events)
                    events = ev;
                else
                    events(end+1) = ev;
                end

                % Callback (MaxCallsPerEvent limits per-event; each event seen once)
                if ~isempty(obj.OnEventStart) && obj.MaxCallsPerEvent > 0
                    obj.OnEventStart(ev);
                end
            end
        end
    end
end
