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

- **Speed:** Compression via `diff` + logical indexing is O(N) per field, done once per unique field
- **No redundant work:** If multiple sensors reference the same state channel key, compress only once (cache results)
- **Introspection-driven:** Only attach StateChannels that are actually referenced in ThresholdRule conditions
- **Same struct format:** Metadata struct follows the same convention as module data (fields + `doc.date` naming the datenum field)

## Function Signature

```matlab
sensors = loadModuleMetadata(registry, metadataStruct, sensors)
```

**Input:**
- `registry` — `ExternalSensorRegistry` (used for consistency, not strictly required but keeps API uniform with `loadModuleData`)
- `metadataStruct` — Scalar struct from external system, same format as module data
- `sensors` — `1xN` cell array of Sensor objects (from `loadModuleData`) with ThresholdRules already attached

**Output:**
- `sensors` — Same `1xN` cell array, now with StateChannels attached to sensors that have matching ThresholdRule conditions

## Algorithm

1. Validate `metadataStruct.doc.date`, extract datenum field name and timestamps `X`
2. `metaFields = fieldnames(metadataStruct)`, exclude `doc` and datenum field
3. Build a cache (`containers.Map`) for compressed transitions: key → `struct('X', sparseX, 'Y', sparseY)`
4. For each sensor in `sensors`:
   a. Collect all unique condition field names from `sensor.ThresholdRules{i}.Condition`
   b. For each required state key that exists in `metaFields`:
      - If not in cache: compress dense signal to transitions and cache
      - Create `StateChannel(key)` with cached sparse X/Y
      - `sensor.addStateChannel(sc)`
5. Return `sensors`

### Compression (dense → sparse transitions)

```matlab
Y_dense = metadataStruct.(key);
changes = [true, diff(Y_dense) ~= 0];  % always keep first point
sparseX = X(changes);
sparseY = Y_dense(changes);
```

This is O(N) vectorized, producing only the transition points.

## Performance Design

- **One-time compression:** Each metadata field is compressed at most once via the cache, even if 100 sensors reference it
- **Vectorized diff:** `diff(Y) ~= 0` is a single MATLAB vectorized operation on the full array
- **Introspection is cheap:** Iterating ThresholdRules is O(R) per sensor where R is typically 1-10
- **No disk I/O:** Function receives already-loaded struct

## Location

`libs/SensorThreshold/loadModuleMetadata.m` — standalone function alongside `loadModuleData` and `ExternalSensorRegistry`.

## Edge Cases

- If `doc` or `doc.date` is missing: error with clear message (same as `loadModuleData`)
- If `doc.date` names a nonexistent field: error with clear message
- If a sensor has no ThresholdRules: skip it (no state channels needed)
- If a ThresholdRule condition references a key not in the metadata: skip that key silently (may come from a different source)
- If a metadata field has all identical values (no transitions): produces a single-point StateChannel (first point only)
- If `sensors` is empty: return empty cell array unchanged
- Repeated calls add additional StateChannels (does not clear existing ones)
