# Event Detection Library Design

## Overview

Third library (`libs/EventDetection/`) for FastPlot — detects events from threshold violations, groups consecutive violations into events with statistics, and supports configurable callbacks and debounce.

## Structure

```
libs/EventDetection/
├── EventDetector.m          % Main class — configurable detector
├── Event.m                  % Value class — single event with metadata + stats
├── detectEventsFromSensor.m % Convenience wrapper for Sensor objects
└── private/
    └── groupViolations.m    % Core algorithm: consecutive violations → events
```

## Event (value class)

Read-only properties:

| Property | Description |
|---|---|
| `StartTime` | First violation timestamp |
| `EndTime` | Last violation timestamp |
| `Duration` | `EndTime - StartTime` |
| `SensorName` | Sensor/channel name (string) |
| `ThresholdLabel` | e.g. "warning high", "critical low" |
| `ThresholdValue` | The threshold that was violated |
| `Direction` | `"high"` or `"low"` (above or below threshold) |
| `PeakValue` | Worst violation value (furthest from threshold) |
| `NumPoints` | Number of data points in the event time window |
| `MinValue` | Minimum signal value during event |
| `MaxValue` | Maximum signal value during event |
| `MeanValue` | Mean signal value during event |
| `RmsValue` | Root mean square of signal during event |
| `StdValue` | Standard deviation of signal during event |

Statistics (`MinValue`, `MaxValue`, `MeanValue`, `RmsValue`, `StdValue`) are computed over **all data points** within the event time window, not just violation points.

`PeakValue` = `MaxValue` for high violations, `MinValue` for low violations.

## EventDetector (main class)

### Properties

| Property | Default | Description |
|---|---|---|
| `MinDuration` | `0` | Debounce filter — events shorter than this are discarded |
| `OnEventStart` | `[]` | Function handle callback `f(event)`, called when a new event is detected |
| `MaxCallsPerEvent` | `1` | Max times `OnEventStart` fires for the same ongoing event |

### Methods

- `events = detect(obj, t, values, thresholdValue, thresholdLabel, sensorName)` — returns `Event` array
  - Calls `groupViolations` to cluster consecutive violation points
  - Computes stats over each event's time window
  - Filters by `MinDuration`
  - Fires `OnEventStart` callback (up to `MaxCallsPerEvent` times per event)

### Threshold independence

Each threshold independently produces its own events. If a sensor has a warning limit at 80 and a critical limit at 100, `detect()` is called separately for each threshold, producing independent event streams.

## detectEventsFromSensor (convenience function)

```matlab
events = detectEventsFromSensor(sensor, t, values)
events = detectEventsFromSensor(sensor, t, values, detector)
```

- Resolves thresholds from a `Sensor` object (SensorThreshold library)
- Calls `EventDetector.detect()` for each threshold
- Returns combined `Event` array
- Accepts optional `EventDetector` instance for custom configuration; creates default if omitted

## groupViolations (private)

- Input: sorted time array, value array, threshold value, direction
- Walks through data, identifies contiguous runs where value violates threshold
- Returns struct array with start/end indices for each group

## Integration

- No direct FastPlot dependency — events can be visualized via `addMarker`-style calls by the caller
- No direct SensorThreshold dependency in core — only `detectEventsFromSensor` bridges the two libraries
- Path setup: root `setup.m` updated to add `libs/EventDetection/`
