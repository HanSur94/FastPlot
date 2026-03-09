classdef ThresholdRule
    %THRESHOLDRULE Defines a condition-value pair for dynamic thresholds.
    %   rule = ThresholdRule(@(st) st.machine == 1, 50)
    %   rule = ThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper')
    %
    %   The condition function receives a struct with state channel values
    %   and returns true/false. When true, the threshold Value applies.

    properties
        ConditionFn   % function_handle: @(st) logical expression
        Value         % numeric: threshold value when condition is true
        Direction     % char: 'upper' or 'lower'
        Label         % char: display label
        Color         % 1x3 double: RGB color (empty = use theme default)
        LineStyle     % char: line style
    end

    methods
        function obj = ThresholdRule(conditionFn, value, varargin)
            obj.ConditionFn = conditionFn;
            obj.Value = value;

            % Defaults
            obj.Direction = 'upper';
            obj.Label = '';
            obj.Color = [];
            obj.LineStyle = '--';

            % Parse name-value pairs
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Direction'
                        d = varargin{i+1};
                        if ~ismember(d, {'upper', 'lower'})
                            error('ThresholdRule:invalidDirection', ...
                                'Direction must be ''upper'' or ''lower'', got ''%s''.', d);
                        end
                        obj.Direction = d;
                    case 'Label'
                        obj.Label = varargin{i+1};
                    case 'Color'
                        obj.Color = varargin{i+1};
                    case 'LineStyle'
                        obj.LineStyle = varargin{i+1};
                    otherwise
                        error('ThresholdRule:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end
    end
end
