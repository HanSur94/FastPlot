function registry = loadModuleData(registry, moduleStruct)
%LOADMODULEDATA Match module struct fields to registered sensors and assign X/Y.
%   registry = loadModuleData(registry, moduleStruct) takes an
%   ExternalSensorRegistry and a module struct loaded from the external
%   system. The struct must contain a .doc field where each sub-field has
%   .name and .datum properties. The .datum value names the shared
%   datenum field. Each struct field whose name matches a registered
%   sensor key gets its data assigned as sensor.Y, with the shared
%   datenum as sensor.X.
%
%   Returns the registry (handle) for chaining convenience. Matched
%   sensors are modified in-place via handle semantics.
%
%   See also ExternalSensorRegistry, Sensor.

    narginchk(2, 2);

    % --- Extract datenum field name from doc metadata ---
    datenumField = extractDatenumField(moduleStruct, 'loadModuleData');

    % --- Extract shared time vector ---
    X = moduleStruct.(datenumField);

    % --- Match struct fields against registry ---
    fields = fieldnames(moduleStruct);
    registeredKeys = registry.keys();

    if isempty(registeredKeys)
        return;
    end

    isMatch = ismember(fields, registeredKeys);

    % Exclude doc and datenum field
    exclude = strcmp(fields, 'doc') | strcmp(fields, datenumField);
    isMatch = isMatch & ~exclude;

    matchedFields = fields(isMatch);
    nMatched = numel(matchedFields);

    % --- Assign X/Y to each matched sensor ---
    for i = 1:nMatched
        s = registry.get(matchedFields{i});
        s.X = X;
        s.Y = moduleStruct.(matchedFields{i});
    end
end
