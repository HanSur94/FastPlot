classdef StatusWidget < DashboardWidget
%STATUSWIDGET Colored circle indicator with label.
%
%   w = StatusWidget('Title', 'Pump 1', 'StatusFcn', @() getPumpStatus());
%
%   StatusFcn returns 'ok', 'warning', or 'alarm'.

    properties (Access = public)
        StatusFcn    = []       % function_handle returning 'ok'/'warning'/'alarm'
        StaticStatus = ''       % fixed status (no callback)
    end

    properties (SetAccess = private)
        CurrentStatus = ''
        hAxes        = []
        hCircle      = []
        hLabelText   = []
        hStatusText  = []
    end

    methods
        function obj = StatusWidget(varargin)
            obj = obj@DashboardWidget();
            obj.Position = [1 1 2 1]; % default compact size
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

            % Create axes for the circle
            obj.hAxes = axes('Parent', parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0.1 0.3 0.35 0.6], ...
                'Visible', 'off', ...
                'XLim', [-1.2 1.2], 'YLim', [-1.2 1.2], ...
                'DataAspectRatio', [1 1 1]);
            hold(obj.hAxes, 'on');

            % Draw circle
            theta = linspace(0, 2*pi, 60);
            obj.hCircle = fill(obj.hAxes, cos(theta), sin(theta), ...
                [0.5 0.5 0.5], 'EdgeColor', 'none');

            % Title/label text
            obj.hLabelText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', obj.Title, ...
                'Units', 'normalized', ...
                'Position', [0.45 0.5 0.5 0.35], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', fgColor, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            % Status text below label
            obj.hStatusText = uicontrol('Parent', parentPanel, ...
                'Style', 'text', ...
                'String', '--', ...
                'Units', 'normalized', ...
                'Position', [0.45 0.15 0.5 0.3], ...
                'FontName', fontName, ...
                'FontSize', theme.WidgetTitleFontSize - 1, ...
                'ForegroundColor', fgColor * 0.6 + bgColor * 0.4, ...
                'BackgroundColor', bgColor, ...
                'HorizontalAlignment', 'left');

            obj.refresh();
        end

        function refresh(obj)
            if ~isempty(obj.StatusFcn)
                obj.CurrentStatus = obj.StatusFcn();
            elseif ~isempty(obj.StaticStatus)
                obj.CurrentStatus = obj.StaticStatus;
            else
                return;
            end

            theme = obj.getTheme();
            switch obj.CurrentStatus
                case 'ok'
                    color = theme.StatusOkColor;
                    label = 'OK';
                case 'warning'
                    color = theme.StatusWarnColor;
                    label = 'WARNING';
                case 'alarm'
                    color = theme.StatusAlarmColor;
                    label = 'ALARM';
                otherwise
                    color = [0.5 0.5 0.5];
                    label = upper(obj.CurrentStatus);
            end

            if ~isempty(obj.hCircle) && ishandle(obj.hCircle)
                set(obj.hCircle, 'FaceColor', color);
            end
            if ~isempty(obj.hStatusText) && ishandle(obj.hStatusText)
                set(obj.hStatusText, 'String', label, 'ForegroundColor', color);
            end
        end

        function configure(~)
        end

        function t = getType(~)
            t = 'status';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if ~isempty(obj.StatusFcn)
                s.source = struct('type', 'callback', ...
                    'function', func2str(obj.StatusFcn));
            elseif ~isempty(obj.StaticStatus)
                s.source = struct('type', 'static', 'value', obj.StaticStatus);
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = StatusWidget();
            obj.Title = s.title;
            obj.Position = [s.position.col, s.position.row, ...
                            s.position.width, s.position.height];
            if isfield(s, 'source')
                switch s.source.type
                    case 'callback'
                        obj.StatusFcn = str2func(s.source.function);
                    case 'static'
                        obj.StaticStatus = s.source.value;
                end
            end
        end
    end

    methods (Access = private)
        function theme = getTheme(obj)
            theme = DashboardTheme();
            if ~isempty(obj.ThemeOverride) && ~isempty(fieldnames(obj.ThemeOverride))
                fns = fieldnames(obj.ThemeOverride);
                for i = 1:numel(fns)
                    theme.(fns{i}) = obj.ThemeOverride.(fns{i});
                end
            end
        end
    end
end
