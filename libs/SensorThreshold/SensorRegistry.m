classdef SensorRegistry
    %SENSORREGISTRY Catalog of predefined sensor definitions.
    %   s = SensorRegistry.get('pressure')
    %   sensors = SensorRegistry.getMultiple({'pressure', 'temperature'})
    %   SensorRegistry.list()
    %
    %   All sensors are defined in the catalog() method below. Edit that
    %   method to add, remove, or modify sensor definitions. Definitions
    %   are cached in a persistent variable for fast repeated lookups.

    methods (Static)
        function s = get(key)
            %GET Retrieve a predefined sensor by key.
            map = SensorRegistry.catalog();
            if ~map.isKey(key)
                error('SensorRegistry:unknownKey', ...
                    'No sensor defined with key ''%s''. Use SensorRegistry.list() to see available sensors.', key);
            end
            s = map(key);
        end

        function sensors = getMultiple(keys)
            %GETMULTIPLE Retrieve multiple sensors by key.
            sensors = cell(1, numel(keys));
            for i = 1:numel(keys)
                sensors{i} = SensorRegistry.get(keys{i});
            end
        end

        function list()
            %LIST Print all available sensor keys and names.
            map = SensorRegistry.catalog();
            keys = sort(map.keys());
            fprintf('\n  Available sensors:\n');
            for i = 1:numel(keys)
                s = map(keys{i});
                name = s.Name;
                if isempty(name); name = '(no name)'; end
                fprintf('    %-25s  %s\n', keys{i}, name);
            end
            fprintf('\n');
        end
    end

    methods (Static, Access = private)
        function map = catalog()
            %CATALOG Define all sensors here. Cached via persistent variable.
            persistent cache;
            if isempty(cache)
                cache = containers.Map();

                % === Example sensor definitions ===
                % Edit this section to define your sensors.

                s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
                cache('pressure') = s;

                s = Sensor('temperature', 'Name', 'Chamber Temperature', 'ID', 102);
                cache('temperature') = s;

                % Add more sensors below:
                % s = Sensor('flow', 'Name', 'Gas Flow Rate', 'ID', 103, ...
                %     'MatFile', 'data/flow.mat');
                % s.addThresholdRule(@(st) st.machine == 1, 100, ...
                %     'Direction', 'upper', 'Label', 'Flow HH');
                % cache('flow') = s;
            end
            map = cache;
        end
    end
end
