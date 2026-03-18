classdef ExternalSensorRegistry < handle
    %EXTERNALSENSORREGISTRY Non-singleton sensor registry for external data.
    %   ExternalSensorRegistry holds explicitly registered Sensor objects
    %   and wires them to .mat file data sources for use with
    %   LiveEventPipeline.
    %
    %   Unlike SensorRegistry (singleton with hardcoded catalog), this
    %   class supports multiple instances and is populated via register().
    %
    %   See also SensorRegistry, Sensor, DataSourceMap.

    properties
        Name  % char: human-readable label for this registry
    end

    properties (Access = private)
        catalog_  % containers.Map (char -> Sensor)
        dsMap_    % DataSourceMap
    end

    methods
        function obj = ExternalSensorRegistry(name)
            %EXTERNALSENSORREGISTRY Construct a named registry.
            %   reg = ExternalSensorRegistry('MyLab')
            obj.Name = name;
            obj.catalog_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.dsMap_ = DataSourceMap();
        end

        function n = count(obj)
            %COUNT Number of registered sensors.
            n = double(obj.catalog_.Count);
        end

        function k = keys(obj)
            %KEYS Return all registered sensor keys.
            k = obj.catalog_.keys();
        end
    end
end
