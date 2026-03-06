# FastPlot

Ultra-fast time series plotting for MATLAB/Octave. Plot 100M+ data points with fluid zoom and pan.

## Features

- **Dynamic MinMax downsampling** — reduces data to screen resolution (~4000 points for 1920px)
- **Fluid zoom/pan** — O(log n) binary search + instant re-downsample on every interaction
- **NaN gaps** — handled natively, no preprocessing needed
- **Unevenly sampled data** — no uniform spacing assumption
- **Threshold lines** with violation markers
- **Linked axes** — synchronized zoom/pan across subplots (opt-in)
- **UserData tagging** — programmatically identify all plot elements
- **Pure MATLAB/Octave** — no MEX, no toolbox dependencies

## Quick Start

```matlab
addpath('FastPlot');

fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Sensor1', 'Color', 'b');
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

## Requirements

- MATLAB R2020b+ or GNU Octave 7+

## Building MEX (optional)

For maximum performance, compile the C MEX accelerators:

```matlab
cd FastPlot
build_mex()
```

Requires a C compiler (Xcode on macOS, GCC on Linux, MSVC on Windows). Uses AVX2/NEON SIMD intrinsics when available.

If MEX files are not compiled, FastPlot automatically uses the pure-MATLAB implementations — no functionality is lost.

## Running Tests

```matlab
cd FastPlot
addpath('tests'); addpath('private');
run_all_tests();
```

## Examples

See `examples/` folder for complete demos.
