# loadModuleMetadata — Attach State Channels from Metadata to Sensors

**Date:** 2026-03-19
**Status:** Draft

## Problem

After loading sensor data via `loadModuleData`, sensors need state channels for threshold resolution. The external system stores metadata (discrete state signals) in the same module struct format: fields + `doc.date` + datenum. This metadata is dense (same length as sensor data, values repeated between transitions), but StateChannel needs sparse transition data for fast binary search during `resolve()`.

We need a function that:
1. Reads metadata fields
2. Compresses dense signals to sparse transitions
3. Introspects each sensor's ThresholdRules to determine which state channels it needs
4. Attaches only the relevant StateChannels to each sensor

## Key Constraints

- **Speed:** Compression via vectorized operations is O(N) per field, done once per unique field
- **No redundant work:** If multiple sensors reference the same state channel key, compress only once (cache results)
- **Introspection-driven:** Only attach StateChannels that are actually referenced in ThresholdRule conditions
- **Same struct format:** Metadata struct follows the same convention as module data (fields + `doc.date` naming the datenum field)
- **Sequencing:** ThresholdRules must be attached to sensors before calling this function. The function reads but does not modify ThresholdRules.

## Function Signature

```matlab
sensors = loadModuleMetadata(metadataStruct, sensors)
```

**Input:**
- `metadataStruct` — Scalar struct from external system, same format as module data
- `sensors` — `1xN` cell array of Sensor objects (from `loadModuleData`) with ThresholdRules already attached

**Output:**
- `sensors` — Same `1xN` cell array, now with StateChannels attached to sensors that have matching ThresholdRule conditions

## Algorithm

1. Validate `metadataStruct.doc.date`, extract datenum field name and timestamps `X`
2. `metaFields = fieldnames(metadataStruct)`, exclude `doc` and the field named by `doc.date`
3. Build a cache (`containers.Map('KeyType', 'char', 'ValueType', 'any')`) for compressed transitions
4. For each sensor in `sensors`:
   a. Collect all unique condition field names via `fieldnames(rule.Condition)` for each `rule` in `sensor.ThresholdRules`
   b. For each required state key that exists in `metaFields`:
      - If not in cache: compress dense signal to transitions (see below) and store in cache
      - Create a **new** `StateChannel(key)` instance, assign `sc.X` and `sc.Y` from cached data
      - `sensor.addStateChannel(sc)`
5. Return `sensors`

**Important:** Each sensor gets its own `StateChannel` object instance. The cache stores data arrays, not handle objects. This avoids shared mutable state between sensors.

### Compression (dense → sparse transitions)

Handles both numeric arrays and cell arrays of char (both types are supported by StateChannel):

```matlab
Y_dense = metadataStruct.(key);
if iscell(Y_dense)
    % String/categorical state: compare consecutive elements
    changes = [true, ~strcmp(Y_dense(1:end-1), Y_dense(2:end))];
else
    % Numeric state: use diff
    changes = [true, diff(Y_dense) ~= 0];
end
sparseX = X(changes);
sparseY = Y_dense(changes);
```

Ensure output is row vector orientation (`1xN`) to match StateChannel's contract.

This is O(N) per field, producing only the transition points.

## Performance Design

- **One-time compression:** Each metadata field is compressed at most once via the cache, even if 100 sensors reference it
- **Vectorized operations:** `diff` / `strcmp` on full arrays — single pass
- **Introspection is cheap:** Iterating ThresholdRules is O(R) per sensor where R is typically 1-10
- **No disk I/O:** Function receives already-loaded struct

## Location

`libs/SensorThreshold/loadModuleMetadata.m` — standalone function alongside `loadModuleData` and `ExternalSensorRegistry`.

## Edge Cases

- If `doc` or `doc.date` is missing: error with clear message (same as `loadModuleData`)
- If `doc.date` names a nonexistent field: error with clear message
- If `doc.date` is not a char: error with clear message
- If a sensor has no ThresholdRules: skip it (no state channels needed)
- If a ThresholdRule condition references a key not in the metadata: skip that key silently (may come from a different source)
- If a metadata field has all identical values (no transitions): produces a single-point StateChannel (first point only)
- If `sensors` is empty: return it unchanged
- Repeated calls add additional StateChannels (does not clear existing ones — caller's responsibility to avoid duplicates)
