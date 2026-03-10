classdef (Abstract) DataSource < handle
    % DataSource  Abstract interface for fetching new sensor data.
    %
    %   Subclasses must implement fetchNew() which returns a struct:
    %     .X       — 1xN datenum timestamps
    %     .Y       — 1xN (or MxN) values
    %     .stateX  — 1xK datenum state timestamps (empty if none)
    %     .stateY  — 1xK state values (empty if none)
    %     .changed — logical, true if new data since last call

    methods (Abstract)
        result = fetchNew(obj)
    end

    methods (Static)
        function result = emptyResult()
            result = struct('X', [], 'Y', [], 'stateX', [], 'stateY', {{}}, 'changed', false);
        end
    end
end
