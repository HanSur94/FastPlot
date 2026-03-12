classdef KpiWidget < DashboardWidget
%KPIWIDGET Dashboard widget showing a big number with label and trend.
%
%   w = KpiWidget('Title', 'Temp', 'ValueFcn', @() readTemp(), 'Units', 'degC');
%
%   ValueFcn returns either:
%     - A scalar (displayed as-is)
%     - A struct with fields: value, unit, trend ('up'/'down'/'flat')

    properties (Access = public)
        ValueFcn     = []       % function_handle returning scalar or struct
        Units        = ''       % unit label string
        Format       = '%.1f'   % sprintf format for value
        StaticValue  = []       % fixed value (no callback needed)
    end

    properties (SetAccess = private)
        CurrentValue = []
        CurrentTrend = ''
        hValueText   = []
        hUnitText    = []
        hTrendText   = []
        hTitleText   = []
    end

    methods
        function obj = KpiWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 3 1]; % default KPI size
            for k = 1:2:numel(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();

            bgColor = theme.WidgetBackground;
            fgColor = theme.ForegroundColor;
            fontName = theme.FontName;
            kpiFontSize = theme.KpiFontSize;
            titleFontSize = theme.WidgetTitleFontSize;

            % Title at top
            obj.hTitleText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.75 0.9 0.2], ...
                'FontName', fontName, ...
                'FontSize', titleFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor * 0.7 + bgColor * 0.3, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Big value number in center
            obj.hValueText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.05 0.25 0.7 0.5], ...
                'FontName', fontName, ...
                'FontSize', kpiFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Trend arrow (right of value)
            obj.hTrendText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '', ...
                'Units', 'normalized', ...
                'Position', [0.75 0.25 0.2 0.5], ...
                'FontName', fontName, ...
                'FontSize', round(kpiFontSize * 0.6), ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            % Units label at bottom
            obj.hUnitText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Units, ...
                'Units', 'normalized', ...
                'Position', [0.05 0.05 0.9 0.2], ...
                'FontName', fontName, ...
                'FontSize', titleFontSize, ...
                'ForegroundColor', fgColor * 0.5 + bgColor * 0.5, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'center');

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.ValueFcn)
                result = obj.ValueFcn();
            elseif ~isempty(obj.StaticValue)
                result = obj.StaticValue;
            else
                return;
            end

            if isstruct(result)
                obj.CurrentValue = result.value;
                if isfield(result, 'unit')
                    obj.Units = result.unit;
                end
                if isfield(result, 'trend')
                    obj.CurrentTrend = result.trend;
                end
            else
                obj.CurrentValue = result;
            end

            % Update display
            if ~isempty(obj.hValueText) && ishandle(obj.hValueText)
                set(obj.hValueText, 'String', sprintf(obj.Format, obj.CurrentValue));
            end

            if ~isempty(obj.hUnitText) && ishandle(obj.hUnitText)
                set(obj.hUnitText, 'String', obj.Units);
            end

            if ~isempty(obj.hTrendText) && ishandle(obj.hTrendText)
                switch obj.CurrentTrend
                    case 'up'
                        set(obj.hTrendText, 'String', char(9650));  % up triangle
                    case 'down'
                        set(obj.hTrendText, 'String', char(9660));  % down triangle
                    case 'flat'
                        set(obj.hTrendText, 'String', char(9654));  % right triangle
                    otherwise
                        set(obj.hTrendText, 'String', '');
                end
            end
        end

        function configure(obj) %#ok<MANU>
            % Placeholder for Phase 4 edit mode
        end

        function t = getType(~)
            t = 'kpi';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            s.units = obj.Units;
            s.format = obj.Format;
            if ~isempty(obj.ValueFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.ValueFcn));
            elseif ~isempty(obj.StaticValue)
                s.source = struct('type', 'static', 'value', obj.StaticValue);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = KpiWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'units')
                obj.Units = s.units;
            end
            if isfield(s, 'format')
                obj.Format = s.format;
            end
            if isfield(s, 'source')
                switch s.source.type
                    case 'callback'
                        obj.ValueFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticValue = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            if isstruct(obj.ThemeOverride) && ~isempty(fieldnames(obj.ThemeOverride))
                theme = obj.ThemeOverride;
            else
                theme = DashboardTheme();
            end
        end
    end
end
