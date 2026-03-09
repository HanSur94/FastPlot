classdef Sensor < handle
    %SENSOR Represents a sensor with data, state channels, and threshold rules.
    %   s = Sensor('pressure', 'Name', 'Chamber Pressure', 'MatFile', 'data.mat')
    %   s.addStateChannel(stateChannel);
    %   s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper');
    %   s.load();
    %   s.resolve();

    properties
        Key           % char: unique identifier
        Name          % char: human-readable display name
        ID            % numeric: sensor ID
        Source        % char: path to original data file
        MatFile       % char: path to .mat file with transformed data
        KeyName       % char: field name in .mat file (defaults to Key)
        X             % array: time data (datenum)
        Y             % array: sensor values (1xN or MxN)
        StateChannels % cell array of StateChannel objects
        ThresholdRules % cell array of ThresholdRule objects
        ResolvedThresholds  % struct: precomputed threshold time series
        ResolvedViolations  % struct: precomputed violation points
        ResolvedStateBands  % struct: precomputed state region bands
    end

    methods
        function obj = Sensor(key, varargin)
            obj.Key = key;
            obj.KeyName = key;
            obj.Name = '';
            obj.ID = [];
            obj.Source = '';
            obj.MatFile = '';
            obj.X = [];
            obj.Y = [];
            obj.StateChannels = {};
            obj.ThresholdRules = {};
            obj.ResolvedThresholds = struct();
            obj.ResolvedViolations = struct();
            obj.ResolvedStateBands = struct();

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Name',     obj.Name = varargin{i+1};
                    case 'ID',       obj.ID = varargin{i+1};
                    case 'Source',   obj.Source = varargin{i+1};
                    case 'MatFile',  obj.MatFile = varargin{i+1};
                    case 'KeyName',  obj.KeyName = varargin{i+1};
                    otherwise
                        error('Sensor:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function load(obj)
            %LOAD Thin wrapper — delegates to external loading library.
            error('Sensor:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function addStateChannel(obj, sc)
            %ADDSTATECHANNEL Attach a StateChannel to this sensor.
            obj.StateChannels{end+1} = sc;
        end

        function addThresholdRule(obj, conditionFn, value, varargin)
            %ADDTHRESHOLDRULE Add a dynamic threshold rule.
            %   s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper')
            rule = ThresholdRule(conditionFn, value, varargin{:});
            obj.ThresholdRules{end+1} = rule;
        end
    end
end
