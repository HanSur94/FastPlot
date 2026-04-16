classdef SensorTag < Tag
    %SENSORTAG Concrete Tag subclass wrapping a legacy Sensor data carrier.
    %   SensorTag composes a legacy Sensor (HAS-A, not IS-A) via a private
    %   Sensor_ delegate.  It satisfies the Tag contract (getXY, valueAt,
    %   getTimeRange, getKind='sensor', toStruct, fromStruct) and forwards
    %   data-role methods (load, toDisk, toMemory, isOnDisk) to the inner
    %   Sensor.  Threshold machinery on Sensor (addThreshold, resolve,
    %   ResolvedThresholds/Violations/StateBands) is deliberately NOT
    %   forwarded — that stays on the legacy class until Phase 1011 cleanup.
    %
    %   Properties (Dependent): DataStore — mirrors obj.Sensor_.DataStore.
    %
    %   Constructor accepts Tag universals (Name, Units, Description,
    %   Labels, Metadata, Criticality, SourceRef), Sensor extras (ID,
    %   Source, MatFile, KeyName), and inline 'X'/'Y' data arrays.
    %
    %   Example:
    %     st = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar');
    %     st.load('data/press_a.mat');  % populates inner Sensor X, Y
    %     [x, y] = st.getXY();
    %     TagRegistry.register('press_a', st);
    %
    %   See also Tag, TagRegistry, Sensor, StateTag.

    properties (Access = private)
        Sensor_   % handle to legacy Sensor instance (composition delegate)
    end

    properties (Dependent)
        DataStore   % mirrors obj.Sensor_.DataStore (read-only view)
    end

    methods
        function obj = SensorTag(key, varargin)
            %SENSORTAG Construct a SensorTag by delegating to Tag + Sensor.
            %   t = SensorTag(key) creates a SensorTag with the given key
            %   and an inner Sensor delegate bearing the same key.
            %
            %   t = SensorTag(key, Name, Value, ...) accepts Tag universals
            %   (Name, Units, Description, Labels, Metadata, Criticality,
            %   SourceRef), Sensor extras (ID, Source, MatFile, KeyName),
            %   and inline data payload (X, Y).
            %
            %   Errors:
            %     Tag:invalidKey           — key empty / not char
            %     SensorTag:unknownOption  — unrecognized NV key
            [tagArgs, sensorArgs, inlineX, inlineY] = SensorTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});              % MUST be first — no obj access before
            obj.Sensor_ = Sensor(key, sensorArgs{:});
            if ~isempty(inlineX) || ~isempty(inlineY)
                obj.Sensor_.X = inlineX;
                obj.Sensor_.Y = inlineY;
            end
            % Tag defaults Name to Key; mirror to inner Sensor for any
            % downstream consumer that still reads Sensor.Name directly.
            obj.Sensor_.Name = obj.Name;
        end

        function ds = get.DataStore(obj)
            %GET.DATASTORE Forward the dependent DataStore read to the delegate.
            ds = obj.Sensor_.DataStore;
        end

        % ---- Tag contract ----

        function [X, Y] = getXY(obj)
            %GETXY Return delegate X, Y by reference (zero-copy via COW).
            %   MATLAB copy-on-write guarantees no memory allocation until
            %   the caller mutates X or Y — this is the Pitfall 9 path.
            X = obj.Sensor_.X;
            Y = obj.Sensor_.Y;
        end

        function v = valueAt(obj, t)
            %VALUEAT Return Y at the last index where X <= t (ZOH, clamped).
            %   Mirrors StateChannel.bsearchRight semantics for a consistent
            %   behaviour across Tag kinds.  Returns NaN on empty data.
            if isempty(obj.Sensor_.X) || isempty(obj.Sensor_.Y)
                v = NaN;
                return;
            end
            idx = binary_search(obj.Sensor_.X, t, 'right');
            v = obj.Sensor_.Y(idx);
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)].  [NaN NaN] if empty.
            if isempty(obj.Sensor_.X)
                tMin = NaN;
                tMax = NaN;
                return;
            end
            tMin = obj.Sensor_.X(1);
            tMax = obj.Sensor_.X(end);
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Return the literal kind identifier 'sensor'.
            k = 'sensor';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize SensorTag state to a plain struct.
            %   Tag universals at the top level; Sensor-specific extras
            %   nested under `s.sensor` (only when non-default) to keep the
            %   struct compact.  X/Y are INTENTIONALLY OMITTED — runtime
            %   data, not serialization state (RESEARCH §6 / Pitfall 5).
            s = struct();
            s.kind        = 'sensor';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.labels      = {obj.Labels};    % MockTag cellstr-wrap pattern
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.sourceref   = obj.SourceRef;

            sensorExtras = struct();
            if ~isempty(obj.Sensor_.ID)
                sensorExtras.id = obj.Sensor_.ID;
            end
            if ~isempty(obj.Sensor_.Source)
                sensorExtras.source = obj.Sensor_.Source;
            end
            if ~isempty(obj.Sensor_.MatFile)
                sensorExtras.matfile = obj.Sensor_.MatFile;
            end
            if ~isempty(obj.Sensor_.KeyName) && ~strcmp(obj.Sensor_.KeyName, obj.Key)
                sensorExtras.keyname = obj.Sensor_.KeyName;
            end
            if ~isempty(fieldnames(sensorExtras))
                s.sensor = sensorExtras;
            end
        end

        % ---- Data-role delegation ----

        function load(obj, matFile)
            %LOAD Delegate to inner Sensor.load with optional MatFile override.
            %   t.load() uses the already-configured MatFile on the delegate.
            %   t.load(path) sets Sensor_.MatFile = path before delegating.
            %
            %   Re-raises: Sensor:noMatFile, Sensor:fileNotFound,
            %              Sensor:fieldNotFound (see Sensor.load).
            if nargin >= 2 && ~isempty(matFile)
                obj.Sensor_.MatFile = matFile;
            end
            obj.Sensor_.load();
        end

        function toDisk(obj)
            %TODISK Delegate to inner Sensor.toDisk (0-arg parity).
            obj.Sensor_.toDisk();
        end

        function toMemory(obj)
            %TOMEMORY Delegate to inner Sensor.toMemory.
            obj.Sensor_.toMemory();
        end

        function tf = isOnDisk(obj)
            %ISONDISK Delegate to inner Sensor.isOnDisk.
            tf = obj.Sensor_.isOnDisk();
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct SensorTag from a toStruct output.
            %   Unwraps the cellstr Labels wrap (same pattern as MockTag),
            %   extracts Sensor extras from the optional s.sensor nested
            %   struct, and forwards everything to the SensorTag ctor.
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('SensorTag:invalidSource', ...
                    'fromStruct requires a struct with non-empty .key');
            end

            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}),  L = L{1};  end
                if iscell(L),  labels = L;  end
            end
            metadata = SensorTag.fieldOr_(s, 'metadata',    struct());
            if ~isstruct(metadata),  metadata = struct();  end

            nvArgs = { ...
                'Name',        SensorTag.fieldOr_(s, 'name',        s.key),  ...
                'Labels',      labels, ...
                'Metadata',    metadata, ...
                'Criticality', SensorTag.fieldOr_(s, 'criticality', 'medium'), ...
                'Units',       SensorTag.fieldOr_(s, 'units',       ''), ...
                'Description', SensorTag.fieldOr_(s, 'description', ''), ...
                'SourceRef',   SensorTag.fieldOr_(s, 'sourceref',   '')};

            if isfield(s, 'sensor') && isstruct(s.sensor)
                sensorKeyMap = {'id', 'ID'; 'source', 'Source'; ...
                                'matfile', 'MatFile'; 'keyname', 'KeyName'};
                for r = 1:size(sensorKeyMap, 1)
                    if isfield(s.sensor, sensorKeyMap{r, 1})
                        nvArgs(end+1:end+2) = ...
                            {sensorKeyMap{r, 2}, s.sensor.(sensorKeyMap{r, 1})}; %#ok<AGROW>
                    end
                end
            end

            obj = SensorTag(s.key, nvArgs{:});
        end
    end

    methods (Static, Access = private)
        function v = fieldOr_(s, fieldName, defaultVal)
            %FIELDOR_ Return s.(fieldName) if present and non-empty, else defaultVal.
            if isfield(s, fieldName) && ~isempty(s.(fieldName))
                v = s.(fieldName);
            else
                v = defaultVal;
            end
        end

        function [tagArgs, sensorArgs, inlineX, inlineY] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag NV / Sensor NV / inline X,Y.
            tagKeys    = {'Name', 'Units', 'Description', 'Labels', ...
                          'Metadata', 'Criticality', 'SourceRef'};
            sensorKeys = {'ID', 'Source', 'MatFile', 'KeyName'};
            tagArgs    = {};
            sensorArgs = {};
            inlineX    = [];
            inlineY    = [];
            for i = 1:2:numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('SensorTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', k);
                end
                v = args{i+1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k;    tagArgs{end+1} = v;    %#ok<AGROW>
                elseif any(strcmp(k, sensorKeys))
                    sensorArgs{end+1} = k; sensorArgs{end+1} = v; %#ok<AGROW>
                elseif strcmp(k, 'X')
                    inlineX = v;
                elseif strcmp(k, 'Y')
                    inlineY = v;
                else
                    error('SensorTag:unknownOption', ...
                        'Unknown option ''%s''.', k);
                end
            end
        end
    end
end
