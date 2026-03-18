<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense achieves dramatic performance improvements over MATLAB's built-in `plot()` function through intelligent downsampling, multi-level caching, and optimized MEX kernels. Here's what you can expect and how to measure it yourself.

## Key Performance Metrics

Based on benchmarks with 10M data points on Apple M4 with GNU Octave 11:

| Metric | Value | Description |
|--------|-------|-------------|
| Zoom cycle time | 4.7 ms | Time to re-downsample and redraw on zoom/pan |
| Effective zoom FPS | 212 FPS | Interactive frames per second during zoom |
| Point reduction | 99.96% | 10M points → ~4K rendered points |
| GPU memory usage | 0.06 MB | vs 153 MB for equivalent `plot()` |

The key advantage isn't just initial render time — it's maintaining fluid interactivity. With `plot()`, 10M points make zoom/pan unusable, while FastSense maintains sub-5ms response times.

## FastSense vs plot() Performance

| Points | plot() render | FastSense render | Speedup |
|--------|---------------|------------------|---------|
| 10K | instant | instant | ~1x |
| 100K | moderate lag | instant | ~5x |
| 1M | slow | fast | ~10x |
| 10M | very slow | 0.19 s | ~50x |
| 100M | often fails | works | ∞ |

At 100M+ points, `plot()` frequently runs out of memory or becomes completely unresponsive, while FastSense handles it gracefully.

## Dashboard Performance

Multi-tile dashboards show increasing advantage as tile count grows:

| Layout | subplot() | FastSenseGrid | Speedup |
|--------|-----------|---------------|---------|
| 1x1 | 0.195 s | 0.187 s | 1.0x |
| 2x2 | 0.451 s | 0.377 s | 1.2x |
| 3x3 | 0.964 s | 0.709 s | 1.4x |

Each FastSenseGrid tile downsamples independently to ~4K points regardless of raw data size, so rendering cost stays nearly flat. Traditional approaches scale linearly with total point count.

## MEX vs Pure MATLAB

Compiled MEX kernels provide substantial acceleration for core operations:

| Operation (10M points) | MATLAB | MEX | Speedup |
|------------------------|--------|-----|---------|
| Binary search | ~1 ms | ~0.05 ms | 20x |
| MinMax downsample | ~25 ms | ~7 ms | 3.5x |
| LTTB downsample | ~200 ms | ~4 ms | 50x |
| Violation detection | ~50 ms | ~2 ms | 25x |

MEX kernels use SIMD instructions (AVX2/NEON) to process 4 doubles per CPU cycle when possible.

## Running Your Own Benchmarks

FastSense includes several example scripts to test performance on your system:

```matlab
install;
cd examples

% Compare MinMax vs LTTB downsampling methods
example_lttb_vs_minmax;

% Test 100M point stress case with DeferDraw option
example_100M;

% Full stress test: 5 tabs, 26 sensors, 86M points, 104 thresholds
example_stress_test;
```

The stress test example creates a realistic large-scale scenario with [[FastSenseDock]] managing multiple dashboard tabs.

## Why FastSense is Fast

### 1. Downsample to Screen Resolution
Only renders ~4,000 points regardless of dataset size. A 100M point dataset uses the same GPU memory as a 4K dataset once downsampled.

### 2. Binary Search for Range Queries
Uses O(log N) binary search instead of O(N) linear scanning to find visible data ranges on zoom/pan. The `binary_search()` function is accelerated by MEX:

```matlab
% Find visible data range for current zoom window
idx_start = binary_search(x, xMin, 'left');
idx_end = binary_search(x, xMax, 'right');
visible_data = y(idx_start:idx_end);
```

### 3. Lazy Multi-Level Pyramid
Pre-computes downsampled levels (100:1, 10000:1, etc.) so zooming out never touches raw data. Cache is built incrementally as needed.

### 4. SIMD-Optimized MEX Kernels
C implementations use vectorized instructions to process multiple data points per CPU cycle:
- **AVX2** on x86_64: processes 4 doubles simultaneously
- **NEON** on ARM64: processes 2-4 elements per cycle

Compile with `build_mex()` to enable acceleration.

### 5. Fused Operations
Combines multiple operations in single passes:
- Violation detection + pixel coordinate culling
- Downsampling + threshold line intersection
- Range lookup + metadata forwarding

### 6. Direct Graphics Updates
Updates line data via direct XData/YData assignment — the fastest path through MATLAB's graphics system. Avoids object recreation or property listeners.

### 7. Frame Rate Limiting
Uses `drawnow limitrate` to cap display refresh at 20 FPS, preventing GPU thrashing during rapid zoom/pan sequences.

## Performance Tuning Options

Several properties control the performance vs. quality trade-off:

```matlab
fp = FastSense();

% Increase points per pixel for denser traces (default: 2)
fp.DownsampleFactor = 4;

% Adjust pyramid compression (default: 100)
fp.PyramidReduction = 50;  % more levels, finer granularity

% Switch algorithms for different data characteristics
fp.DefaultDownsampleMethod = 'lttb';  % vs 'minmax'

% Control when downsampling kicks in (default: 5000)
fp.MinPointsForDownsample = 10000;
```

## Memory Management

FastSense automatically switches between in-memory and disk-backed storage:

```matlab
fp = FastSense();

% Force storage mode (default: 'auto')
fp.StorageMode = 'memory';  % always RAM
fp.StorageMode = 'disk';    % always SQLite

% Adjust memory threshold (default: 500 MB)
fp.MemoryLimit = 1e9;  % 1 GB threshold
```

The `'auto'` mode uses [[FastSenseDataStore|API Reference: FastSenseDataStore]] for lines exceeding the memory limit, seamlessly providing disk-based storage without performance degradation.

## Monitoring Performance

Enable verbose output to see detailed timing information:

```matlab
fp = FastSense('Verbose', true);
fp.addLine(x, y);
fp.render();

% Output:
% [FastSense] Line 1: 10000000 points → 3847 (MinMax, 23.4 ms)
% [FastSense] Pyramid L1: 100000 points (7.8 ms)  
% [FastSense] Pyramid L2: 1000 points (0.3 ms)
% [FastSense] Total render: 187.2 ms
```

Control progress display with the `ShowProgress` property:

```matlab
fp = FastSense();
fp.ShowProgress = false;  % hide progress bar
fp.DeferDraw = true;      % skip drawnow during render
fp.render();
drawnow;                  % manual drawnow when ready
```

The [[ConsoleProgressBar]] class (used internally) is also available for your own batch operations:

```matlab
pb = ConsoleProgressBar();
pb.start();
for k = 1:1000
    % your processing
    pb.update(k, 1000, 'Processing');
end
pb.finish();
```

## Downsampling Methods

FastSense supports two downsampling algorithms optimized for different use cases:

### MinMax (Default)
Preserves extremes (peaks and valleys) by selecting minimum and maximum values in each pixel bucket. Ideal for:
- Signal analysis where peak detection is critical
- Quality control data with threshold violations
- Any scenario where you can't afford to miss extreme values

```matlab
fp.addLine(x, y, 'DownsampleMethod', 'minmax');
```

### LTTB (Largest-Triangle-Three-Buckets)
Preserves visual shape and trends by selecting points that form the largest triangular area with their neighbors. Better for:
- Smooth signals where overall shape matters more than individual peaks
- Presentation graphics where visual fidelity is key
- Dense noisy data where MinMax creates jagged artifacts

```matlab
fp.addLine(x, y, 'DownsampleMethod', 'lttb');
```

Both algorithms downsample to approximately `DownsampleFactor` points per screen pixel, but with different selection criteria. Use `example_lttb_vs_minmax.m` to see the visual difference.
