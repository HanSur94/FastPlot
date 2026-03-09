# Severity Escalation Design

## Problem

When multiple thresholds exist on the same sensor in the same direction (e.g., 85=warning, 95=critical), detection runs each independently. A brief spike above 95 may get debounced by `MinDuration`, leaving only a "temp warning" event whose peak (96) clearly exceeds the critical threshold. The user sees a warning where they expect a critical alarm.

## Solution

Post-detection severity escalation in `EventConfig.runDetection()`.

### Algorithm

After collecting all events from all sensors:

1. **Group** events by `(SensorName, Direction)`
2. **Build threshold hierarchy** per group — sorted by threshold value (ascending for `high`, descending for `low`)
3. **Escalate** each event: check if its `PeakValue` exceeds any higher threshold in the same group. If so, update `ThresholdLabel` and `ThresholdValue` to the highest threshold exceeded.
4. **Deduplicate**: if two events in the same group now share the same label and overlap in time (one contained within the other), remove the shorter one.

### API

- `EventConfig.EscalateSeverity` — logical, default `true`. Set to `false` to disable.
- No changes to `Event`, `EventDetector`, `EventViewer`, or `detectEventsFromSensor`.

### Changes

- `Event.m`: add `escalateTo(newLabel, newThresholdValue)` method (returns new Event since it's a value class)
- `EventConfig.m`: add `EscalateSeverity` property, add private `escalateEvents()` method called at end of `runDetection()`

### Example

```
Thresholds: temp warning=85 (upper), temp critical=95 (upper)
Data spike: 70 → 87 → 96 → 88 → 70

Before escalation:
  Event 1: "temp warning",  start=10, end=18, peak=96
  Event 2: "temp critical", start=13, end=15, peak=96  (may be debounced)

After escalation:
  Event 1: "temp critical", start=10, end=18, peak=96
  Event 2: removed (contained within Event 1, same label)
```

### Edge Cases

- 3+ thresholds: escalate to the highest one the peak exceeds
- `low` direction: threshold hierarchy is descending (4 > 2), peak must be below each threshold
- No escalation when `EscalateSeverity = false`
- Events on different sensors never interact
