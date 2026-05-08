classdef EventGanttCanvas < handle
%EVENTGANTTCANVAS Gantt drawing + hit-testing helper for CompanionEventViewer.
%
%   Constructor: canvas = EventGanttCanvas(hAxes, theme)
%   Public:
%     canvas.draw(events, theme)              — redraw all bars (Task 5)
%     canvas.OnSingleClick / OnDoubleClick    — function handles (Task 5)
%   Static:
%     [map, keys] = EventGanttCanvas.computeRows(events)
%     rgb = EventGanttCanvas.severityColor(sev)
%     x   = EventGanttCanvas.eventEndOrNow(ev, nowRef)
%
%   See also CompanionEventViewer.

    properties (SetAccess = private)
        hAxes           % axes handle
        Theme           % CompanionTheme struct
        BarHandles      % rectangle/patch handles, Nx1
        BarEvents       % Event objects mirrored to handles, Nx1
    end

    properties
        OnSingleClick = []
        OnDoubleClick = []
    end

    methods
        function obj = EventGanttCanvas(hAxes, theme)
            %EVENTGANTTCANVAS Construct with a target axes and a CompanionTheme.
            obj.hAxes      = hAxes;
            obj.Theme      = theme;
            obj.BarHandles = [];
            obj.BarEvents  = Event.empty;
        end
    end

    methods (Static)
        function [map, keys] = computeRows(events)
            %COMPUTEROWS Build row-index map from an array of Event objects.
            %   [map, keys] = EventGanttCanvas.computeRows(events)
            %   map  - containers.Map: key (char) -> row index (double)
            %   keys - sorted column cellstr of unique row keys
            map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if isempty(events)
                keys = cell(0, 1);
                return;
            end
            allKeys = {};
            for i = 1:numel(events)
                ev = events(i);
                if ~isempty(ev.TagKeys)
                    allKeys = [allKeys; ev.TagKeys(:)]; %#ok<AGROW>
                else
                    allKeys = [allKeys; {ev.SensorName}]; %#ok<AGROW>
                end
            end
            keys = unique(allKeys);          % returns sorted column cellstr
            for i = 1:numel(keys)
                map(keys{i}) = i;
            end
        end

        function rgb = severityColor(sev)
            %SEVERITYCOLOR Return an RGB triple for the given severity level.
            %   rgb = EventGanttCanvas.severityColor(sev)
            %   sev = 1 -> green (info/ok)
            %   sev = 2 -> orange (warn)
            %   sev = 3 -> red (alarm)
            %   otherwise -> grey fallback
            switch double(sev)
                case 1,    rgb = [0.20 0.70 0.30];   % green  (info/ok)
                case 2,    rgb = [0.95 0.60 0.10];   % orange (warn)
                case 3,    rgb = [0.85 0.20 0.20];   % red    (alarm)
                otherwise, rgb = [0.50 0.50 0.50];   % grey   fallback
            end
        end

        function x = eventEndOrNow(ev, nowRef)
            %EVENTENDORNOW Return the display end time for an event.
            %   x = EventGanttCanvas.eventEndOrNow(ev, nowRef)
            %   For closed events returns ev.EndTime; for open or NaN-ended
            %   events returns nowRef so the bar extends to the current time.
            if ev.IsOpen || isnan(ev.EndTime)
                x = nowRef;
            else
                x = ev.EndTime;
            end
        end
    end
end
