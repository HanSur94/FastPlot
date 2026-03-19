# loadModuleData — Module Struct to Sensor Registry Bridge

**Date:** 2026-03-19
**Status:** Draft

## Problem

An external system stores sensor data in .mat files as structs ("modules"). Each struct contains:
- Many sensor fields (field name = sensor key, value = 1xN double vector)
- A shared datenum field (name varies per module)
- A `.doc` sub-struct with metadata, including `doc.date` which names the datenum field

We need a fast function to match struct fields against sensors already registered in an `ExternalSensorRegistry` and assign X/Y data to each matched sensor.

## Function Signature

```matlab
sensors = loadModuleData(registry, moduleStruct)
```

**Input:**
- `registry` — `ExternalSensorRegistry` with sensors pre-registered
- `moduleStruct` — Loaded struct from external system

**Output:**
- `sensors` — Cell array of Sensor objects that were matched and filled with X/Y data

## Algorithm

1. Read `moduleStruct.doc.date` to get the datenum field name
2. Extract datenum vector: `X = moduleStruct.(datenumField)`
3. Get all struct field names via `fieldnames(moduleStruct)`
4. Get registered sensor keys via `registry.keys()`
5. Use `ismember()` to find fields that exist in both sets (excluding `doc` and datenum field)
6. Loop over matches: get sensor from registry, assign `sensor.X = X`, `sensor.Y = moduleStruct.(field)`
7. Return cell array of filled sensors

## Performance Design

- **Single pass:** One `fieldnames()` call, one `ismember()` — O(N) matching
- **Copy-on-write:** The datenum vector `X` is assigned to all matched sensors without memory duplication (MATLAB COW semantics). As long as no sensor modifies X in-place, only one copy exists in memory.
- **No validation/normalization:** Raw speed. The caller is responsible for data integrity.
- **No disk I/O:** Function receives already-loaded struct, does not call `load()`

## Location

`libs/SensorThreshold/loadModuleData.m` — standalone function alongside ExternalSensorRegistry.

## Edge Cases

- If `doc` or `doc.date` is missing: error with clear message
- If no fields match registered sensors: return empty cell array
- Fields named `doc` and the datenum field are always excluded from matching
