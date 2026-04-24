<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Event Detection

## `EventDetector` --- Detects events from threshold violations.

> Inherits from: `handle`

det = EventDetector()
  det = EventDetector('MinDuration', 2, 'OnEventStart', @myCallback)

  Call shape:
    events = det.detect(tag, threshold)   % 2-arg Tag overload

  Reads (X, Y) from tag.getXY() and derives threshold metadata
  from the Threshold handle; forwards to the private detect_ body.
  Dispatch is entry-level on isa(arg, 'Tag') — the ABSTRACT BASE —
  matching the FastSense.addTag precedent (Pitfall 1: NO subclass
  isa anywhere in this file).

### Constructor

```matlab
obj = EventDetector(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| MinDuration |  | numeric: minimum event duration (default 0) |
| OnEventStart |  | function handle: callback f(event) on new event |
| MaxCallsPerEvent |  | numeric: max callback invocations per event (default 1) |

### Methods

#### `events = detect(obj, tag, threshold)`

DETECT Find events from threshold violations.
  events = det.detect(tag, threshold)

---

## `IncrementalEventDetector` --- Wraps EventDetector with incremental state.

> Inherits from: `handle`

Tracks last-processed index per sensor and carries over open events.

### Constructor

```matlab
obj = IncrementalEventDetector(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| MinDuration | `0` |  |
| MaxCallsPerEvent | `1` |  |
| OnEventStart | `[]` |  |
| EscalateSeverity | `true` |  |

### Methods

#### `newEvents = process(~, ~, ~, ~, ~, ~, ~)`

PROCESS Legacy entry point -- no longer functional.
  The Sensor/Threshold/StateChannel pipeline this method relied
  on was deleted in Phase 1011.  LiveEventPipeline now uses
  MonitorTag.appendData() for incremental detection (Phase 1007
  MONITOR-08).  This stub remains so that callers get a clear
  error rather than a missing-method crash.

#### `tf = hasOpenEvent(obj, sensorKey)`

#### `st = getSensorState(obj, sensorKey)`

---

## `Event` --- Represents a single detected threshold violation event.

> Inherits from: `handle`

e = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
  e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)

### Constructor

```matlab
obj = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| TagKeys | `{}` | cell of char: tag keys bound to this event (EVENT-01) |
| Severity | `1` | numeric: 1=ok/info, 2=warn, 3=alarm (EVENT-04) |
| Category | `''` | char: alarm\|maintenance\|process_change\|manual_annotation (EVENT-05) |
| Id | `''` | char: unique id assigned by EventStore.append (EVENT-02) |
| IsOpen | `false` | logical: true while event is still open (EndTime = NaN) — Phase 1012 |
| Notes | `''` | char: free-form user annotation edited via details popup — Phase 1012 |
| DIRECTIONS | `{'upper', 'lower'}` |  |

### Methods

#### `obj = setStats(obj, peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)`

SETSTATS Set event statistics.

#### `obj = close(obj, endTime, finalStats)`

CLOSE Close an open event in place; update EndTime, Duration, and optional running stats.
  ev.close(endTime, finalStats) mutates the SetAccess=private
  fields EndTime and Duration and optionally populates stats
  from a struct with fields {PeakValue, NumPoints, MinValue,
  MaxValue, MeanValue, RmsValue, StdValue}. Toggles IsOpen
  false. Called by EventStore.closeEvent.

#### `obj = escalateTo(obj, newLabel, newThresholdValue)`

ESCALATETOP Escalate event to a higher severity threshold.

---

## `EventConfig` --- Configuration for the event detection system.

> Inherits from: `handle`

cfg = EventConfig()
  cfg.MinDuration = 2;
  cfg.addSensor(sensor);
  events = cfg.runDetection();

### Constructor

```matlab
obj = EventConfig()
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Sensors |  | cell array of Sensor objects |
| SensorData |  | struct array: name, t, y (for viewer click-to-plot) |
| MinDuration |  | numeric: debounce (default 0) |
| MaxCallsPerEvent |  | numeric: callback limit (default 1) |
| OnEventStart |  | function handle: callback |
| ThresholdColors |  | containers.Map: label -> [R G B] |
| AutoOpenViewer |  | logical: auto-open EventViewer after detection |
| EscalateSeverity |  | logical: escalate events to higher thresholds (default true) |
| EventFile |  | char: path to .mat file for auto-saving events (empty = disabled) |
| MaxBackups |  | numeric: number of backup files to keep (default 5, 0 = no backups) |

### Methods

#### `addSensor(~, ~)`

ADDSENSOR Legacy entry point -- no longer functional.
  The Sensor.resolve() pipeline was deleted in Phase 1011.
  Use MonitorTag + EventStore for event detection.

#### `setColor(obj, label, rgb)`

SETCOLOR Set color for a threshold label.

#### `det = buildDetector(obj)`

BUILDDETECTOR Create a configured EventDetector.

#### `events = runDetection(obj)`

RUNDETECTION Detect events across all configured sensors.

---

## `EventStore` --- Atomic read/write of events to a shared .mat file.

> Inherits from: `handle`

### Constructor

```matlab
obj = EventStore(filePath, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| FilePath | `''` |  |
| MaxBackups | `5` |  |
| PipelineConfig | `struct()` |  |
| SensorData | `[]` | struct array: name, t, y (for EventViewer click-to-plot) |
| ThresholdColors | `struct()` | serialized threshold colors struct |
| Timestamp | `[]` | datetime: when events were saved |

### Methods

#### `append(obj, newEvents)`

#### `events = getEvents(obj)`

#### `closeEvent(obj, eventId, endTime, finalStats)`

CLOSEEVENT Close an open event in place.
  es.closeEvent(eventId, endTime, finalStats) locates an open
  Event by Id, delegates to ev.close(endTime, finalStats) for
  the in-place mutation, and returns. finalStats may be []
  (empty) to skip stats update. Does NOT call save() — consumers
  decide when to persist (Pitfall 2).

#### `events = getEventsForTag(obj, tagKey)`

GETEVENTSFORTAG Return events bound to tagKey via EventBinding + carrier fallback.
  Primary path: uses EventBinding.getEventsForTag for events
  with non-empty Id (Phase 1010 EVENT-01/EVENT-03).
  Fallback path: carrier-field matching (SensorName/ThresholdLabel)
  for events without Id (backward compat, Pitfall 4).

#### `save(obj)`

#### `n = numEvents(obj)`

### Static Methods

#### `EventStore.[events, meta, changed] = loadFile(filePath)`

---

## `EventViewer` --- Figure-based event viewer with Gantt timeline and filterable table.

> Inherits from: `handle`

viewer = EventViewer(events)
  viewer = EventViewer(events, sensorData)
  viewer = EventViewer(events, sensorData, thresholdColors)
  viewer.update(newEvents)

### Constructor

```matlab
obj = EventViewer(events, sensorData, thresholdColors)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Events |  | Event array |
| SensorData |  | struct array: name, t, y (for click-to-plot) |
| ThresholdColors |  | containers.Map: label -> [R G B] |
| hFigure |  | figure handle |
| BarPositions |  | Nx4 matrix: [x, y, w, h] cached from drawTimeline |
| BarRects |  | rectangle handles for hover detection |
| BarEvents |  | Event objects corresponding to BarRects |

### Methods

#### `update(obj, events)`

UPDATE Refresh the viewer with new events.

#### `names = getSensorNames(obj)`

GETSENSORNAMES Get unique sensor names from events.

#### `labels = getThresholdLabels(obj)`

GETTHRESHOLDLABELS Get unique threshold labels from events.

#### `refreshFromFile(obj)`

REFRESHFROMFILE Reload events from the source .mat file.

#### `startAutoRefresh(obj, interval)`

STARTAUTOREFRESH Start polling the source file at given interval.
  obj.startAutoRefresh(5)  % refresh every 5 seconds

#### `stopAutoRefresh(obj)`

STOPAUTOREFRESH Stop the auto-refresh timer.

### Static Methods

#### `EventViewer.viewer = fromFile(filepath)`

FROMFILE Open EventViewer from a saved .mat event store file.
  viewer = EventViewer.fromFile('events.mat')

---

## `LiveEventPipeline` --- Orchestrates live event detection.

> Inherits from: `handle`

Uses MonitorTargets — containers.Map of key -> MonitorTag;
  processed via MonitorTag.appendData (Phase 1007 MONITOR-08
  streaming tail extension).

  Ordering invariant (Pitfall Y) — enforced by processMonitorTag_:
    monitor.Parent.updateData(newX, newY)  <- called FIRST
    monitor.appendData(newX, newY)         <- THEN
  The reverse order causes cache incoherence: MonitorTag.appendData's
  cold path recomputes against a stale parent grid.  See the docstring
  at libs/SensorThreshold/MonitorTag.m lines 330-334 for the contract.

### Constructor

```matlab
obj = LiveEventPipeline(monitors, dataSourceMap, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| MonitorTargets |  | containers.Map: key -> MonitorTag |
| DataSourceMap |  | DataSourceMap |
| EventStore |  | EventStore |
| NotificationService |  | NotificationService |
| Interval | `15` | seconds |
| Status | `'stopped'` |  |
| MinDuration | `0` |  |
| EscalateSeverity | `true` |  |
| MaxCallsPerEvent | `1` |  |
| OnEventStart | `[]` |  |

### Methods

#### `start(obj)`

#### `stop(obj)`

#### `runCycle(obj)`

---

## `NotificationService` --- Rule-based email notifications with event snapshots.

> Inherits from: `handle`

### Constructor

```matlab
obj = NotificationService(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Rules | `[]` |  |
| DefaultRule | `[]` |  |
| Enabled | `true` |  |
| DryRun | `false` |  |
| SnapshotDir | `''` |  |
| SnapshotRetention | `7` | days |
| SmtpServer | `''` |  |
| SmtpPort | `25` |  |
| SmtpUser | `''` |  |
| SmtpPassword | `''` |  |
| FromAddress | `'fastsense@noreply.com'` |  |
| NotificationCount | `0` |  |

### Methods

#### `addRule(obj, rule)`

#### `setDefaultRule(obj, rule)`

#### `rule = findBestRule(obj, event)`

#### `notify(obj, event, sensorData)`

#### `cleanupSnapshots(obj)`

---

## `NotificationRule` --- Configures notification for sensor/threshold events.

> Inherits from: `handle`

### Constructor

```matlab
obj = NotificationRule(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| SensorKey | `''` |  |
| ThresholdLabel | `''` |  |
| Recipients | `{{}}` |  |
| Subject | `'Event: {sensor} - {threshold}'` |  |
| Message | `'{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}'` |  |
| IncludeSnapshot | `true` |  |
| ContextHours | `2` |  |
| SnapshotPadding | `0.1` |  |
| SnapshotSize | `[800, 400]` |  |

### Methods

#### `score = matches(obj, event)`

Returns match score: 3=sensor+threshold, 2=sensor, 1=default, 0=no match

#### `txt = fillTemplate(~, template, event)`

---

## `DataSource` --- Abstract interface for fetching new sensor data.

> Inherits from: `handle`

Subclasses must implement fetchNew() which returns a struct:
    .X       — 1xN datenum timestamps
    .Y       — 1xN (or MxN) values
    .stateX  — 1xK datenum state timestamps (empty if none)
    .stateY  — 1xK state values (empty if none)
    .changed — logical, true if new data since last call

### Methods

#### `result = fetchNew(obj)`

### Static Methods

#### `DataSource.result = emptyResult()`

---

## `MatFileDataSource` --- Reads sensor data from a continuously-updated .mat file.

> Inherits from: `DataSource`

### Constructor

```matlab
obj = MatFileDataSource(filePath, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| FilePath | `''` |  |
| XVar | `'X'` |  |
| YVar | `'Y'` |  |
| StateXVar | `''` |  |
| StateYVar | `''` |  |

### Methods

#### `result = fetchNew(obj)`

---

## `DataSourceMap` --- Maps sensor keys to DataSource instances.

> Inherits from: `handle`

### Constructor

```matlab
obj = DataSourceMap()
```

### Methods

#### `add(obj, key, dataSource)`

#### `ds = get(obj, key)`

#### `k = keys(obj)`

#### `tf = has(obj, key)`

#### `remove(obj, key)`

---

## `EventBinding` --- Singleton many-to-many registry binding Events to Tags.

EventBinding stores (eventId, tagKey) pairs using two persistent
  containers.Map indexes (forward: eventId -> {tagKeys}, reverse:
  tagKey -> {eventIds}) for O(1) lookup in both directions.

  This is the single-write-side for Event-Tag binding (EVENT-02).
  Only EventBinding.attach mutates the registry. Convenience wrappers
  on Event/Tag/EventStore delegate to this class.

### Static Methods

#### `EventBinding.attach(eventId, tagKey)`

ATTACH Bind an event to a tag (idempotent).
  EventBinding.attach(eventId, tagKey) adds the (eventId, tagKey)
  pair to both forward and reverse indexes. Silent on duplicate.

#### `EventBinding.keys = getTagKeysForEvent(eventId)`

GETTAGKEYSFOREVENT Return cell of tagKey strings bound to eventId.

#### `EventBinding.events = getEventsForTag(tagKey, eventStore)`

GETEVENTSFORTAG Return Event array bound to tagKey via reverse index.
  Uses the reverse index for O(1) lookup of eventIds, then
  filters the eventStore's events by matching Id.

#### `EventBinding.clear()`

CLEAR Reset all bindings in both forward and reverse indexes.

---

## `MockDataSource` --- Generates realistic industrial sensor signals for testing.

> Inherits from: `DataSource`

### Constructor

```matlab
obj = MockDataSource(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| BaseValue | `100` |  |
| NoiseStd | `1` |  |
| DriftRate | `0` | drift per second |
| SampleInterval | `3` | seconds between points |
| BacklogDays | `3` | days of history on first fetch |
| ViolationProbability | `0.005` | chance per point of starting violation |
| ViolationAmplitude | `20` | how far signal ramps beyond base |
| ViolationDuration | `60` | seconds per violation episode |
| StateValues | `{{}}` | cell of char, e.g. {'idle','running'} |
| StateChangeProbability | `0.001` | chance per point of state transition |
| Seed | `[]` | optional RNG seed |
| PipelineInterval | `15` | seconds per fetch cycle |

### Methods

#### `result = fetchNew(obj)`

