<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Sensors

## `Sensor` --- Represents a sensor with data, state channels, and threshold entities.

> Inherits from: `handle`

Sensor is the central class of the SensorThreshold library.  It
  bundles raw time-series data (X, Y) with a set of StateChannels
  (discrete system states) and Threshold objects (condition-dependent
  limit values).  The resolve() method evaluates all thresholds against
  the state channels to produce pre-computed threshold time series,
  violation indices, and state-band regions that can be rendered by
  a plotting layer such as FastSense.

### Constructor

```matlab
obj = Sensor(key, varargin)
```

SENSOR Construct a Sensor object.
  s = Sensor(key) creates a sensor with the given string
  identifier and default property values.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Key |  | char: unique string identifier for this sensor |
| Name |  | char: human-readable display name |
| ID |  | numeric: sensor ID (e.g., from a database) |
| Source |  | char: path to the original raw data file |
| MatFile |  | char: path to .mat file with transformed data |
| KeyName |  | char: field name in .mat file (defaults to Key) |
| X |  | 1xN double: datenum time stamps |
| Y |  | 1xN (or MxN) double: sensor values |
| Units |  | char: measurement unit (e.g., 'degC', 'bar', 'rpm') |
| DataStore |  | FastSenseDataStore: disk-backed storage (set by toDisk) |
| StateChannels |  | cell array of StateChannel objects |
| Thresholds |  | cell array of Threshold handle references |
| ResolvedThresholds |  | struct array: precomputed threshold step-function lines |
| ResolvedViolations |  | struct array: precomputed violation (X,Y) points |
| ResolvedStateBands |  | struct: precomputed state region bands for shading |

### Methods

#### `load(obj)`

LOAD Load sensor data from a .mat file.
  s.load() populates s.X and s.Y by loading the file
  specified in s.MatFile using the field name s.KeyName.
  Requires MatFile and KeyName to be set.

#### `addStateChannel(obj, sc)`

ADDSTATECHANNEL Attach a StateChannel to this sensor.
  s.addStateChannel(sc) appends the given StateChannel
  object to the sensor's StateChannels list.  During
  resolve(), each attached channel's key becomes a field in
  the state struct used to evaluate ThresholdRule conditions.

#### `addThreshold(obj, thresholdOrKey)`

ADDTHRESHOLD Attach a Threshold entity to this sensor.
  s.addThreshold(t) appends the given Threshold handle to the
  sensor's Thresholds list.

#### `removeThreshold(obj, key)`

REMOVETHRESHOLD Detach a Threshold entity by key.
  s.removeThreshold(key) removes the first Threshold whose Key
  matches the given char from the sensor's Thresholds list.
  No error is raised if the key is not found.

#### `toDisk(obj)`

TODISK Move sensor X/Y data to disk-backed DataStore.
  s.toDisk() creates a FastSenseDataStore from the sensor's
  X and Y arrays, then clears X and Y from memory. The data
  remains accessible via s.DataStore.getRange() and
  s.DataStore.readSlice(). Subsequent calls to resolve(),
  addSensor(), and FastSense rendering all work transparently.

#### `toMemory(obj)`

TOMEMORY Load disk-backed data back into memory.
  s.toMemory() reads the full dataset from the DataStore
  back into s.X and s.Y, then cleans up the DataStore.

#### `tf = isOnDisk(obj)`

ISONDISK True if sensor data is stored on disk.

#### `resolve(obj)`

RESOLVE Precompute threshold time series, violations, and state bands.
  s.resolve() evaluates all Threshold conditions against the
  attached StateChannels and the sensor's own X/Y data.
  Results are stored in the ResolvedThresholds,
  ResolvedViolations, and ResolvedStateBands properties.

#### `active = getThresholdsAt(obj, t)`

GETTHRESHOLDSAT Evaluate all thresholds at a single time point.
  active = s.getThresholdsAt(t) builds the composite state
  struct at time t (by querying each StateChannel), then
  tests every condition in every Threshold against that state.
  Returns a struct array of all conditions whose conditions are
  satisfied, with fields Value, Direction, and Label.

#### `n = countViolations(obj)`

COUNTVIOLATIONS Count total violation points across all thresholds.
  n = s.countViolations() returns the total number of
  violation data points summed over all ResolvedViolations.
  Call resolve() first.

#### `st = currentStatus(obj)`

CURRENTSTATUS Derive 'ok'/'warning'/'alarm' from latest value.
  st = s.currentStatus() evaluates the sensor's latest Y
  value against all threshold conditions active at the latest
  X time. Returns 'ok' if no thresholds are violated,
  'warning' if a warning-level threshold is violated, or
  'alarm' if an alarm-level threshold is violated.

---

## `StateChannel` --- Discrete state signal with zero-order hold lookup.

> Inherits from: `handle`

StateChannel models a piecewise-constant ("zero-order hold") time
  series representing a discrete system state (e.g., machine mode,
  recipe phase).  Given a query time, it returns the most recent
  known state value.  The class supports both numeric and
  string/categorical state values.

  StateChannel is used by Sensor to condition ThresholdRule
  evaluation: each Sensor may reference one or more StateChannels
  whose values determine which threshold rules are active at any
  given moment.

### Constructor

```matlab
obj = StateChannel(key, varargin)
```

STATECHANNEL Construct a StateChannel object.
  sc = StateChannel(key) creates a channel with the given
  identifier and default properties.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Key |  | char: unique string identifier for this state channel |
| MatFile |  | char: path to .mat file containing the state data |
| KeyName |  | char: field name in .mat file (defaults to Key) |
| X |  | 1xN datenum: sorted timestamps of state transitions |
| Y |  | 1xN numeric or 1xN cell: state values at each transition |

### Methods

#### `load(obj)`

LOAD Load state data from the external data source.
  sc.load() populates sc.X and sc.Y by loading the file
  specified in sc.MatFile.  This is a placeholder that must
  be overridden or extended to integrate with your project's
  data loading library.  Alternatively, set X and Y directly.

#### `val = valueAt(obj, t)`

VALUEAT Return state value at time t using zero-order hold.
  val = sc.valueAt(t) performs a zero-order hold lookup: it
  returns the last state value whose transition timestamp is
  at or before the query time t.  If t precedes the first
  timestamp, the first state value is returned (clamp).

---

## `ThresholdRule` --- Defines a condition-value pair for dynamic thresholds.

ThresholdRule pairs a state-condition struct with a numeric
  threshold value.  A rule is "active" when every field in its
  Condition struct matches the current system state (implicit AND).
  An empty condition struct() means the rule is always active
  (unconditional threshold).

  The Direction property determines whether the threshold is an
  upper limit ('upper' -- violation when sensor > Value) or a lower
  limit ('lower' -- violation when sensor < Value).

### Constructor

```matlab
obj = ThresholdRule(condition, value, varargin)
```

THRESHOLDRULE Construct a ThresholdRule object.
  rule = ThresholdRule(condition, value) creates a rule with
  default direction 'upper', empty label, and dashed line.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DIRECTIONS | `{'upper', 'lower'}` | Allowed direction values |
| Condition |  | struct: field names = state channel keys, values = required state |
| Value |  | numeric: threshold value when condition is true |
| Direction |  | char: 'upper' or 'lower' violation direction |
| Label |  | char: display label for plots and legends |
| Color |  | 1x3 double: RGB color (empty = use theme default) |
| LineStyle |  | char: MATLAB line-style specifier (e.g., '--', ':') |

### Methods

#### `tf = matchesState(obj, st)`

MATCHESSTATE Check if a state struct satisfies this rule's condition.
  tf = rule.matchesState(st) returns true if every field in
  the rule's Condition struct exists in st and has a matching
  value (implicit AND logic).  An empty Condition always
  returns true, meaning the rule is unconditional.

---

## `SensorRegistry` --- Catalog of predefined sensor definitions.

SensorRegistry provides a centralized, singleton-style catalog of
  all known Sensor objects in the SensorThreshold library. Sensor
  definitions are specified in the private catalog() method and
  cached in a persistent variable so that repeated lookups incur no
  construction overhead.

  To add a new sensor, edit the catalog() method at the bottom of
  this file.  Each entry creates a Sensor object, optionally
  configures its state channels and threshold rules, then stores it
  in the containers.Map keyed by a short string identifier.

### Static Methods

#### `SensorRegistry.s = get(key)`

GET Retrieve a predefined sensor by key.
  s = SensorRegistry.get(key) returns the Sensor object
  registered under the string key. Throws an error if the
  key is not found in the catalog.

#### `SensorRegistry.sensors = getMultiple(keys)`

GETMULTIPLE Retrieve multiple sensors by key.
  sensors = SensorRegistry.getMultiple(keys) returns a cell
  array of Sensor objects, one per element of the input keys.

#### `SensorRegistry.list()`

LIST Print all available sensor keys and names.
  SensorRegistry.list() prints a formatted table of every
  registered sensor key and its human-readable name to the
  command window.  Keys are sorted alphabetically.

#### `SensorRegistry.register(key, sensor)`

REGISTER Add a sensor to the catalog at runtime.
  SensorRegistry.register('myKey', sensorObj)

#### `SensorRegistry.unregister(key)`

UNREGISTER Remove a sensor from the catalog.

#### `SensorRegistry.printTable()`

PRINTTABLE Print a detailed table of all registered sensors.
  SensorRegistry.printTable() prints a formatted table with
  columns: Key, Name, ID, Source, MatFile, #States, #Rules, #Points.

#### `SensorRegistry.hFig = viewer()`

VIEWER Open a GUI figure showing all registered sensors.
  hFig = SensorRegistry.viewer() creates a figure with a
  uitable listing every sensor's Key, Name, ID, Source,
  MatFile, #States, #Rules, and #Points.

---

## `CompositeThreshold` --- Threshold subclass that aggregates child Threshold objects.

> Inherits from: `Threshold`

CompositeThreshold enables hierarchical status trees where a parent
  component's status is derived from its children's statuses using
  configurable AND, OR, or MAJORITY logic.

  A composite is itself a Threshold (isa returns true), so it can be
  registered in ThresholdRegistry and used anywhere a Threshold is
  accepted.  Composites can be nested: a CompositeThreshold may be
  added as a child of another CompositeThreshold, allowing arbitrarily
  deep system-health trees.

  CompositeThreshold Properties (public):
    AggregateMode — 'and' | 'or' | 'majority' (default 'and')
                    Controls how child statuses are combined.

### Constructor

```matlab
obj = CompositeThreshold(key, varargin)
```

COMPOSITETHRESHOLD Construct a CompositeThreshold.
  c = CompositeThreshold(key) creates a composite with the
  given key and default AggregateMode='and'.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| AggregateMode | `'and'` | char: 'and' \| 'or' \| 'majority' |

### Methods

#### `set()`

SET.AGGREGATEMODE Validate and set the aggregate mode.

#### `addChild(obj, thresholdOrKey, varargin)`

ADDCHILD Add a child Threshold to this composite.
  c.addChild(threshold) adds the given Threshold object as a
  child with no associated value (computeStatus will return
  'ok' for that child since no value to compare against).

#### `status = computeStatus(obj)`

COMPUTESTATUS Evaluate the aggregate status of this composite.
  status = c.computeStatus() returns 'ok' if the aggregate of
  all children's statuses satisfies AggregateMode, or 'alarm'
  otherwise.  Returns 'ok' when children list is empty.

#### `ch = getChildren(obj)`

GETCHILDREN Return the children cell array.
  ch = c.getChildren() returns the internal cell array of child
  structs, each with fields: threshold, valueFcn, value.

#### `vals = allValues(obj)`

ALLVALUES Return [] — composites have no direct conditions.
  CompositeThreshold stores no ThresholdRule objects directly.
  Status is computed from children, not from threshold conditions.

#### `s = toStruct(obj)`

TOSTRUCT Serialize this CompositeThreshold to a plain struct.
  s = c.toStruct() returns a struct suitable for JSON encoding.
  Fields: type ('composite'), key, name, aggregateMode, children.
  Each entry in children has: key, and optionally value (when a
  static scalar value was registered via addChild(...,'Value',v)).
  Nested CompositeThreshold children additionally carry type='composite'.

### Static Methods

#### `CompositeThreshold.obj = fromStruct(s)`

FROMSTRUCT Reconstruct a CompositeThreshold from a plain struct.
  obj = CompositeThreshold.fromStruct(s) creates a new
  CompositeThreshold using fields in s and resolves children
  via ThresholdRegistry.get(key).  Any child key that is not
  found in the registry is skipped with a warning.

---

## `ExternalSensorRegistry` --- Non-singleton sensor registry for external data.

> Inherits from: `handle`

ExternalSensorRegistry holds explicitly registered Sensor objects
  and wires them to .mat file data sources for use with
  LiveEventPipeline.

  Unlike SensorRegistry (singleton with hardcoded catalog), this
  class supports multiple instances and is populated via register().

### Constructor

```matlab
obj = ExternalSensorRegistry(name)
```

EXTERNALSENSORREGISTRY Construct a named registry.
  reg = ExternalSensorRegistry('MyLab')

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Name |  | char: human-readable label for this registry |

### Methods

#### `n = count(obj)`

COUNT Number of registered sensors.

#### `k = keys(obj)`

KEYS Return all registered sensor keys.

#### `register(obj, key, sensor)`

REGISTER Add a Sensor to the catalog.
  reg.register('key', sensorObj)

#### `unregister(obj, key)`

UNREGISTER Remove a Sensor from the catalog.

#### `s = get(obj, key)`

GET Retrieve a sensor by key.

#### `sensors = getMultiple(obj, keys)`

GETMULTIPLE Retrieve multiple sensors by key.

#### `m = getAll(obj)`

GETALL Return a copy of the catalog as a containers.Map.

#### `list(obj)`

LIST Print all registered sensor keys and names.

#### `printTable(obj)`

PRINTTABLE Print a detailed table of all registered sensors.

#### `wireMatFile(obj, matFilePath, mappings)`

WIREMATFILE Wire .mat file fields to registered sensor keys.
  reg.wireMatFile('data.mat', {
      'sensorKey', 'XVar', 'time', 'YVar', 'value';
  })

#### `dsMap = getDataSourceMap(obj)`

GETDATASOURCEMAP Return the DataSourceMap for pipeline use.

#### `hFig = viewer(obj)`

VIEWER Open a GUI figure showing all registered sensors.

#### `wireStateChannel(obj, sensorKey, stateKey, matFilePath, varargin)`

WIRESTATECHANNEL Wire state channel data to a registered sensor.
  reg.wireStateChannel('sensorKey', 'stateKey', 'states.mat', ...
      'XVar', 'state_time', 'YVar', 'state_val')

---

## `Threshold` --- First-class threshold entity with condition-value pairs.

> Inherits from: `handle`

Threshold is an independent, reusable entity that encapsulates a
  threshold definition — its direction, appearance, metadata, and a
  set of condition-value pairs (ThresholdRule objects).

  Unlike ThresholdRule (which is sensor-scoped), Threshold is a
  standalone entity that can be registered in ThresholdRegistry and
  shared across multiple sensors or dashboard widgets.

### Constructor

```matlab
obj = Threshold(key, varargin)
```

THRESHOLD Construct a Threshold object.
  t = Threshold(key) creates a threshold with the given key
  and default values: Direction='upper', LineStyle='--'.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Key |  | char: unique identifier |
| Name |  | char: human-readable display name |
| Direction |  | char: 'upper' or 'lower' |
| Color |  | 1x3 double: RGB color (empty = theme default) |
| LineStyle |  | char: MATLAB line-style token |
| Units |  | char: measurement unit |
| Description |  | char: free-text description |
| Tags |  | cell: string tags for filtering/discovery |

### Methods

#### `addCondition(obj, conditionStruct, value)`

ADDCONDITION Append a condition-value pair as a ThresholdRule.
  t.addCondition(conditionStruct, value) creates an internal
  ThresholdRule using the threshold's Direction, Name, Color,
  and LineStyle, then appends it to conditions_.

#### `vals = allValues(obj)`

ALLVALUES Return numeric vector of all condition values.
  vals = t.allValues() extracts the Value from each
  ThresholdRule in conditions_ and returns them as a row
  vector.  Returns [] when no conditions are defined.

#### `fields = getConditionFields(obj)`

GETCONDITIONFIELDS Return unique sorted fieldnames across all conditions.
  fields = t.getConditionFields() iterates every condition in
  conditions_ and returns the union of all struct fieldnames as
  a sorted, deduplicated cell array of char.

#### `label = get()`

GET.LABEL Dependent property: returns Name.
  Provides backward compatibility with code that reads .Label
  (e.g., buildThresholdEntry uses rule.Label).

---

## `ThresholdRegistry` --- Singleton catalog of named Threshold entities.

ThresholdRegistry provides a centralized, persistent catalog of all
  known Threshold objects.  It mirrors the SensorRegistry API so the
  two registries have a consistent interface.

  The catalog starts EMPTY — no predefined entries.  Users add their
  own thresholds via ThresholdRegistry.register(key, t) and retrieve
  them later via ThresholdRegistry.get(key).

### Static Methods

#### `ThresholdRegistry.t = get(key)`

GET Retrieve a Threshold by key.
  t = ThresholdRegistry.get(key) returns the Threshold stored
  under key.  Throws 'ThresholdRegistry:unknownKey' if not found.

#### `ThresholdRegistry.ts = getMultiple(keys)`

GETMULTIPLE Retrieve multiple Thresholds by key.
  ts = ThresholdRegistry.getMultiple(keys) returns a 1xN cell
  array of Threshold handles, one per element of keys.

#### `ThresholdRegistry.register(key, t)`

REGISTER Add a Threshold to the catalog.
  ThresholdRegistry.register(key, t) stores t under key.
  Overwrites any existing entry with the same key.

#### `ThresholdRegistry.unregister(key)`

UNREGISTER Remove a Threshold from the catalog.
  ThresholdRegistry.unregister(key) removes the entry if it
  exists.  No error if the key is not present.

#### `ThresholdRegistry.clear()`

CLEAR Remove all entries from the catalog.
  ThresholdRegistry.clear() empties the entire catalog.
  Primarily used in tests to reset state between test runs.

#### `ThresholdRegistry.list()`

LIST Print all registered threshold keys and names.
  ThresholdRegistry.list() prints a formatted list of every
  registered threshold key and its human-readable name.
  Keys are printed in sorted order.

#### `ThresholdRegistry.printTable()`

PRINTTABLE Print a detailed table of all registered thresholds.
  ThresholdRegistry.printTable() prints a formatted table with
  columns: Key, Name, Direction, #Conditions, Tags.

#### `ThresholdRegistry.hFig = viewer()`

VIEWER Open a GUI figure showing all registered thresholds.
  hFig = ThresholdRegistry.viewer() creates a figure with a
  uitable listing every threshold's Key, Name, Direction,
  #Conditions, Units, and Tags.

#### `ThresholdRegistry.ts = findByTag(tag)`

FINDBYTAG Return all Thresholds carrying the given tag.
  ts = ThresholdRegistry.findByTag(tag) iterates the catalog
  and returns a cell array of Threshold handles whose Tags
  cell contains an entry matching tag.  Returns {} if none.

#### `ThresholdRegistry.ts = findByDirection(dir)`

FINDBYDIRECTION Return all Thresholds with the given direction.
  ts = ThresholdRegistry.findByDirection(dir) iterates the
  catalog and returns a cell array of Threshold handles whose
  Direction matches dir ('upper' or 'lower').  Returns {} if none.

