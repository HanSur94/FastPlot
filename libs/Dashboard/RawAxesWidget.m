classdef RawAxesWidget < DashboardWidget
%RAWAXESWIDGET User-supplied plot function on raw MATLAB axes.
%
%   w = RawAxesWidget('Title', 'Histogram', ...
%       'PlotFcn', @(ax) histogram(ax, randn(1,1000)));

    properties (Access = public)
        PlotFcn    = []    % @(ax) or @(ax, tRange) — tRange = [tMin tMax] from time controls
        DataRangeFcn = []  % @() returning [tMin tMax] for global time range detection
    end

    properties (SetAccess = private)
        hAxes      = []
        TimeRange  = []    % [tMin tMax] set by global time controls
        IsSettingTime = false
    end

    methods
        function obj = RawAxesWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 8 2];
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;

            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.12 0.12 0.82 0.76], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'XColor', fgColor, ...
                'YColor', fgColor, ...
                'Color', theme.AxesColor);
            try disableDefaultInteractivity(obj.hAxes); catch, end

            if ~isempty(obj.Title)
                title(obj.hAxes, obj.Title, ...
                    'Color', fgColor, ...
                    'FontSize', theme.WidgetTitleFontSize);
            end

            obj.callPlotFcn();
        end

        function refresh(obj)
            if ~isempty(obj.PlotFcn) && ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                cla(obj.hAxes);
                obj.callPlotFcn();
                if ~isempty(obj.Title)
                    theme = obj.getTheme();
                    title(obj.hAxes, obj.Title, 'Color', theme.ForegroundColor);
                end
            end
        end

        function setTimeRange(obj, tStart, tEnd)
            if ~obj.UseGlobalTime, return; end
            obj.TimeRange = [tStart tEnd];
            if ~isempty(obj.hAxes) && ishandle(obj.hAxes)
                obj.IsSettingTime = true;
                cla(obj.hAxes);
                obj.callPlotFcn();
                if ~isempty(obj.Title)
                    theme = obj.getTheme();
                    title(obj.hAxes, obj.Title, 'Color', theme.ForegroundColor);
                end
                obj.IsSettingTime = false;
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            tMin = inf; tMax = -inf;
            if ~isempty(obj.DataRangeFcn)
                r = obj.DataRangeFcn();
                tMin = r(1); tMax = r(2);
            end
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'rawaxes';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.PlotFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.PlotFcn));
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = RawAxesWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source') && strcmp(s.source.type, 'callback')
                obj.PlotFcn = str2func(s.source.function);
            end
        end
    end

    methods (Access = private)
        function callPlotFcn(obj)
            if isempty(obj.PlotFcn), return; end
            if ~isempty(obj.TimeRange) && nargin(obj.PlotFcn) >= 2
                obj.PlotFcn(obj.hAxes, obj.TimeRange);
            else
                obj.PlotFcn(obj.hAxes);
            end
        end

    end
end
