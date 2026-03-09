classdef StateChannel < handle
    %STATECHANNEL Discrete state signal with zero-order hold lookup.
    %   sc = StateChannel('machine_state', 'MatFile', 'data/states.mat')
    %   sc.load();
    %   val = sc.valueAt(datenum_time);

    properties
        Key       % char: unique identifier
        MatFile   % char: path to .mat file
        KeyName   % char: field name in .mat (defaults to Key)
        X         % 1xN datenum timestamps
        Y         % 1xN numeric, or 1xN cell of char/string
    end

    methods
        function obj = StateChannel(key, varargin)
            obj.Key = key;
            obj.KeyName = key;
            obj.MatFile = '';
            obj.X = [];
            obj.Y = [];

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'MatFile'
                        obj.MatFile = varargin{i+1};
                    case 'KeyName'
                        obj.KeyName = varargin{i+1};
                    otherwise
                        error('StateChannel:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function load(obj)
            %LOAD Thin wrapper — delegates to external loading library.
            %   Override or extend this method to use your data loading system.
            error('StateChannel:notImplemented', ...
                'load() is a wrapper for an external loading library. Set X and Y directly or implement your loader.');
        end

        function val = valueAt(obj, t)
            %VALUEAT Return state value at time t using zero-order hold.
            %   val = sc.valueAt(5.0)       — single scalar query
            %   vals = sc.valueAt([1 2 3])  — vectorized bulk query
            %
            %   Returns the last known value at or before time t.
            %   If t is before the first timestamp, returns the first value.

            if isscalar(t)
                % Single lookup — binary search
                idx = obj.bsearchRight(t);
                if iscell(obj.Y)
                    val = obj.Y{idx};
                else
                    val = obj.Y(idx);
                end
            else
                % Bulk lookup — vectorized
                n = numel(t);
                if iscell(obj.Y)
                    val = cell(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight(t(k));
                        val{k} = obj.Y{idx};
                    end
                else
                    val = zeros(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight(t(k));
                        val(k) = obj.Y(idx);
                    end
                end
            end
        end
    end

    methods (Access = private)
        function idx = bsearchRight(obj, val)
            %BSEARCHRIGHT Last index where X(idx) <= val, clamped to [1, N].
            x = obj.X;
            n = numel(x);
            if val < x(1)
                idx = 1;
                return;
            end
            lo = 1; hi = n; idx = 1;
            while lo <= hi
                mid = floor((lo + hi) / 2);
                if x(mid) <= val
                    idx = mid;
                    lo = mid + 1;
                else
                    hi = mid - 1;
                end
            end
        end
    end
end
