%% FastPlot Stress Test — 5 Tabbed Dashboards with Sensors & Thresholds
% Demonstrates:
%   - 5-tab interface using uitabgroup (simulating FastPlotDock)
%   - Each tab is a FastPlotFigure dashboard with multiple axes
%   - Sensors with state-dependent thresholds, violations, bands, markers
%   - Total ~80M+ data points across all tabs
%   - Tests rendering, downsampling, threshold resolve, and zoom/pan

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

fprintf('\n=== FastPlot Stress Test: 5 Tabbed Dashboards ===\n');
totalTic = tic;

% --- Shared state channels (reused across dashboards) ---
scMachine = StateChannel('machine');
scMachine.X = [0 600 1800 2700 3600];
scMachine.Y = [0 1 2 1 0];

scVacuum = StateChannel('vacuum');
scVacuum.X = [0 900 2400 3200];
scVacuum.Y = [0 1 0 1];

scZone = StateChannel('zone');
scZone.X = [0 1200 2400];
scZone.Y = [0 1 2];

% Create tabbed figure
hFig = figure('Name', 'FastPlot Stress Test — 5 Dashboards', ...
    'NumberTitle', 'off', 'Position', [50 50 1800 1000], 'Visible', 'off');
tabGroup = uitabgroup(hFig);

% =========================================================================
% TAB 1: Vacuum Chamber — 3x2 grid, 6 sensors, ~25M points
% =========================================================================
fprintf('Building Tab 1: Vacuum Chamber (6 tiles, ~25M pts)...\n');
tab1Tic = tic;
tab1 = uitab(tabGroup, 'Title', 'Vacuum Chamber');

fig1 = FastPlotFigure(3, 2, 'Theme', 'dark', 'Name', 'ignore');
set(fig1.hFigure, 'Visible', 'off');
panels1 = create_tab_axes(tab1, 3, 2, fig1.Theme);

% Tile 1.1: Chamber Pressure — 5M pts, state-dependent thresholds
s = Sensor('pressure', 'Name', 'Chamber Pressure');
N = 5e6; t = linspace(0, 3600, N);
s.X = t; s.Y = 40 + 18*sin(2*pi*t/800) + 4*randn(1, N);
s.addStateChannel(scMachine); s.addStateChannel(scVacuum);
s.addThresholdRule(struct('machine', 1), 55, 'Direction', 'upper', ...
    'Label', 'HH Run', 'Color', [0.9 0.2 0.1]);
s.addThresholdRule(struct('machine', 2, 'vacuum', 1), 45, 'Direction', 'upper', ...
    'Label', 'HH Evac+Vac', 'Color', [1 0 0]);
s.addThresholdRule(struct('machine', 1), 25, 'Direction', 'lower', ...
    'Label', 'LL Run', 'Color', [0.1 0.3 0.9]);
s.resolve();
fp = FastPlot('Parent', panels1{1}, 'Theme', fig1.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels1{1}, 'Chamber Pressure (5M pts)', 'Color', 'w');

% Tile 1.2: Base Pressure — 5M pts
s = Sensor('base_pressure', 'Name', 'Base Pressure');
s.X = t; s.Y = 1e-3 + 5e-4*sin(2*pi*t/1200) + 2e-4*randn(1, N);
s.Y(2e6:2.1e6) = s.Y(2e6:2.1e6) + 3e-3;  % leak event
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 2e-3, 'Direction', 'upper', ...
    'Label', 'Leak Alarm', 'Color', [1 0.3 0]);
s.addThresholdRule(struct('machine', 2), 1e-3, 'Direction', 'upper', ...
    'Label', 'Evac Limit', 'Color', [0.9 0.6 0.1]);
s.resolve();
fp = FastPlot('Parent', panels1{2}, 'Theme', fig1.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels1{2}, 'Base Pressure (5M pts)', 'Color', 'w');

% Tile 1.3: Gate Valve Position — 3M pts
s = Sensor('gate_valve', 'Name', 'Gate Valve');
N3 = 3e6; t3 = linspace(0, 3600, N3);
s.X = t3; s.Y = 50 + 45*sin(2*pi*t3/900) + 2*randn(1, N3);
s.addThresholdRule(struct(), 95, 'Direction', 'upper', ...
    'Label', 'Max Open', 'Color', [0.9 0.5 0.1]);
s.addThresholdRule(struct(), 5, 'Direction', 'lower', ...
    'Label', 'Min Open', 'Color', [0.1 0.5 0.9]);
s.resolve();
fp = FastPlot('Parent', panels1{3}, 'Theme', fig1.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels1{3}, 'Gate Valve Position (3M pts)', 'Color', 'w');

% Tile 1.4: Gas Flow — 5M pts, multi-state
s = Sensor('gas_flow', 'Name', 'Gas Flow');
s.X = t; s.Y = 100 + 30*sin(2*pi*t/600) + 8*randn(1, N);
s.addStateChannel(scMachine); s.addStateChannel(scZone);
s.addThresholdRule(struct('machine', 1, 'zone', 0), 135, 'Direction', 'upper', ...
    'Label', 'HH Z0', 'Color', [0.9 0.4 0.1]);
s.addThresholdRule(struct('machine', 1, 'zone', 1), 125, 'Direction', 'upper', ...
    'Label', 'HH Z1', 'Color', [1 0.2 0]);
s.addThresholdRule(struct('machine', 1, 'zone', 2), 115, 'Direction', 'upper', ...
    'Label', 'HH Z2', 'Color', [1 0 0]);
s.addThresholdRule(struct('machine', 1), 70, 'Direction', 'lower', ...
    'Label', 'LL Run', 'Color', [0.2 0.4 1]);
s.resolve();
fp = FastPlot('Parent', panels1{4}, 'Theme', fig1.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels1{4}, 'Gas Flow (5M pts, 3 zones)', 'Color', 'w');

% Tile 1.5: RF Power — 4M pts
s = Sensor('rf_power', 'Name', 'RF Power');
N5 = 4e6; t5 = linspace(0, 3600, N5);
s.X = t5; s.Y = 200 + 80*sin(2*pi*t5/700) + 15*randn(1, N5);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 300, 'Direction', 'upper', ...
    'Label', 'Power HH', 'Color', [1 0.2 0.2]);
s.addThresholdRule(struct('machine', 2), 250, 'Direction', 'upper', ...
    'Label', 'Power HH Evac', 'Color', [0.9 0.5 0.1]);
s.resolve();
fp = FastPlot('Parent', panels1{5}, 'Theme', fig1.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels1{5}, 'RF Power (4M pts)', 'Color', 'w');

% Tile 1.6: Substrate Temp — 3M pts
s = Sensor('substrate_temp', 'Name', 'Substrate Temp');
s.X = t3; s.Y = 350 + 40*sin(2*pi*t3/1000) + 8*randn(1, N3);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 400, 'Direction', 'upper', ...
    'Label', 'Temp HH', 'Color', [1 0 0]);
s.addThresholdRule(struct('machine', 1), 310, 'Direction', 'lower', ...
    'Label', 'Temp LL', 'Color', [0.2 0.3 1]);
s.resolve();
fp = FastPlot('Parent', panels1{6}, 'Theme', fig1.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels1{6}, 'Substrate Temp (3M pts)', 'Color', 'w');

close(fig1.hFigure);
fprintf('  Tab 1 done in %.2f s\n', toc(tab1Tic));

% =========================================================================
% TAB 2: Motor Diagnostics — 2x3 grid, 6 sensors, ~20M points
% =========================================================================
fprintf('Building Tab 2: Motor Diagnostics (6 tiles, ~20M pts)...\n');
tab2Tic = tic;
tab2 = uitab(tabGroup, 'Title', 'Motor Diagnostics');

fig2 = FastPlotFigure(2, 3, 'Theme', 'dark', 'Name', 'ignore');
set(fig2.hFigure, 'Visible', 'off');
panels2 = create_tab_axes(tab2, 2, 3, fig2.Theme);

% Tile 2.1: Motor Current Phase A — 5M pts
s = Sensor('motor_A', 'Name', 'Motor Current A');
N = 5e6; t = linspace(0, 3600, N);
s.X = t; s.Y = 12 + 4*sin(2*pi*t/400) + 1.5*randn(1, N);
s.Y(1.5e6:1.55e6) = s.Y(1.5e6:1.55e6) + 8;  % overcurrent
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 18, 'Direction', 'upper', ...
    'Label', 'Overcurrent', 'Color', [1 0.2 0]);
s.addThresholdRule(struct('machine', 1), 6, 'Direction', 'lower', ...
    'Label', 'Undercurrent', 'Color', [0.2 0.4 1]);
s.resolve();
fp = FastPlot('Parent', panels2{1}, 'Theme', fig2.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels2{1}, 'Motor Current A (5M pts)', 'Color', 'w');

% Tile 2.2: Motor Current Phase B — 5M pts
s = Sensor('motor_B', 'Name', 'Motor Current B');
s.X = t; s.Y = 12 + 4*sin(2*pi*t/400 + 2*pi/3) + 1.5*randn(1, N);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 18, 'Direction', 'upper', ...
    'Label', 'Overcurrent', 'Color', [1 0.2 0]);
s.resolve();
fp = FastPlot('Parent', panels2{2}, 'Theme', fig2.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels2{2}, 'Motor Current B (5M pts)', 'Color', 'w');

% Tile 2.3: Motor Current Phase C — 5M pts
s = Sensor('motor_C', 'Name', 'Motor Current C');
s.X = t; s.Y = 12 + 4*sin(2*pi*t/400 + 4*pi/3) + 1.5*randn(1, N);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 18, 'Direction', 'upper', ...
    'Label', 'Overcurrent', 'Color', [1 0.2 0]);
s.resolve();
fp = FastPlot('Parent', panels2{3}, 'Theme', fig2.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels2{3}, 'Motor Current C (5M pts)', 'Color', 'w');

% Tile 2.4: Vibration X — 2M pts
s = Sensor('vib_x', 'Name', 'Vibration X');
N4 = 2e6; t4 = linspace(0, 3600, N4);
s.X = t4; s.Y = 0.5*randn(1, N4);
faults = [500 1200 2600];
for fi = 1:numel(faults)
    idx = max(1,round(faults(fi)*N4/3600)):min(round((faults(fi)+40)*N4/3600), N4);
    s.Y(idx) = s.Y(idx) + 3*randn(1, numel(idx));
end
s.addThresholdRule(struct(), 2.5, 'Direction', 'upper', ...
    'Label', 'Vib Alarm', 'Color', [1 0.3 0]);
s.addThresholdRule(struct(), -2.5, 'Direction', 'lower', ...
    'Label', 'Vib Alarm', 'Color', [1 0.3 0]);
s.resolve();
fp = FastPlot('Parent', panels2{4}, 'Theme', fig2.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels2{4}, 'Vibration X (2M pts)', 'Color', 'w');

% Tile 2.5: RPM — 1M pts
s = Sensor('rpm', 'Name', 'Spindle RPM');
N5 = 1e6; t5 = linspace(0, 3600, N5);
s.X = t5; s.Y = 3000 + 500*sin(2*pi*t5/900) + 80*randn(1, N5);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 3600, 'Direction', 'upper', ...
    'Label', 'Overspeed', 'Color', [1 0 0]);
s.addThresholdRule(struct('machine', 1), 2400, 'Direction', 'lower', ...
    'Label', 'Underspeed', 'Color', [0.2 0.5 1]);
s.resolve();
fp = FastPlot('Parent', panels2{5}, 'Theme', fig2.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels2{5}, 'Spindle RPM (1M pts)', 'Color', 'w');

% Tile 2.6: Bearing Temp — 2M pts
s = Sensor('bearing_temp', 'Name', 'Bearing Temp');
s.X = t4; s.Y = 65 + 10*sin(2*pi*t4/1200) + 3*randn(1, N4);
s.Y(1.2e6:1.25e6) = s.Y(1.2e6:1.25e6) + 20;  % thermal event
s.addThresholdRule(struct(), 85, 'Direction', 'upper', ...
    'Label', 'Temp Warning', 'Color', [0.9 0.6 0.1]);
s.addThresholdRule(struct(), 95, 'Direction', 'upper', ...
    'Label', 'Temp Alarm', 'Color', [1 0 0]);
s.resolve();
fp = FastPlot('Parent', panels2{6}, 'Theme', fig2.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels2{6}, 'Bearing Temp (2M pts)', 'Color', 'w');

close(fig2.hFigure);
fprintf('  Tab 2 done in %.2f s\n', toc(tab2Tic));

% =========================================================================
% TAB 3: Environmental — 2x2 grid, 4 sensors, ~16M points
% =========================================================================
fprintf('Building Tab 3: Environmental (4 tiles, ~16M pts)...\n');
tab3Tic = tic;
tab3 = uitab(tabGroup, 'Title', 'Environmental');

fig3 = FastPlotFigure(2, 2, 'Theme', 'dark', 'Name', 'ignore');
set(fig3.hFigure, 'Visible', 'off');
panels3 = create_tab_axes(tab3, 2, 2, fig3.Theme);

% Tile 3.1: Cleanroom Temp — 5M pts
s = Sensor('room_temp', 'Name', 'Cleanroom Temp');
N = 5e6; t = linspace(0, 3600, N);
s.X = t; s.Y = 22 + 1.5*sin(2*pi*t/1800) + 0.3*randn(1, N);
s.Y(3e6:3.05e6) = s.Y(3e6:3.05e6) + 3;  % HVAC fault
s.addThresholdRule(struct(), 24, 'Direction', 'upper', ...
    'Label', 'Temp High', 'Color', [0.9 0.3 0.1]);
s.addThresholdRule(struct(), 20, 'Direction', 'lower', ...
    'Label', 'Temp Low', 'Color', [0.1 0.3 0.9]);
s.resolve();
fp = FastPlot('Parent', panels3{1}, 'Theme', fig3.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels3{1}, 'Cleanroom Temp (5M pts)', 'Color', 'w');

% Tile 3.2: Humidity — 5M pts
s = Sensor('humidity', 'Name', 'Humidity');
s.X = t; s.Y = 45 + 8*sin(2*pi*t/2400) + 2*randn(1, N);
s.addThresholdRule(struct(), 55, 'Direction', 'upper', ...
    'Label', 'RH High', 'Color', [0.8 0.4 0.1]);
s.addThresholdRule(struct(), 35, 'Direction', 'lower', ...
    'Label', 'RH Low', 'Color', [0.1 0.4 0.8]);
s.resolve();
fp = FastPlot('Parent', panels3{2}, 'Theme', fig3.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels3{2}, 'Humidity (5M pts)', 'Color', 'w');

% Tile 3.3: Particle Count — 3M pts, state-dependent
s = Sensor('particles', 'Name', 'Particle Count');
N3 = 3e6; t3 = linspace(0, 3600, N3);
s.X = t3; s.Y = abs(200 + 100*sin(2*pi*t3/600) + 50*randn(1, N3));
s.Y(1e6:1.02e6) = s.Y(1e6:1.02e6) + 500;  % contamination burst
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 0), 400, 'Direction', 'upper', ...
    'Label', 'Idle Limit', 'Color', [0.9 0.6 0.1]);
s.addThresholdRule(struct('machine', 1), 300, 'Direction', 'upper', ...
    'Label', 'Run Limit', 'Color', [1 0.2 0]);
s.addThresholdRule(struct('machine', 2), 200, 'Direction', 'upper', ...
    'Label', 'Evac Limit', 'Color', [1 0 0]);
s.resolve();
fp = FastPlot('Parent', panels3{3}, 'Theme', fig3.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels3{3}, 'Particle Count (3M pts, state-dep)', 'Color', 'w');

% Tile 3.4: Differential Pressure — 3M pts
s = Sensor('diff_pressure', 'Name', 'Differential Pressure');
s.X = t3; s.Y = 12.5 + 2*sin(2*pi*t3/900) + 0.8*randn(1, N3);
s.addThresholdRule(struct(), 15, 'Direction', 'upper', ...
    'Label', 'dP High', 'Color', [0.9 0.3 0.1]);
s.addThresholdRule(struct(), 10, 'Direction', 'lower', ...
    'Label', 'dP Low', 'Color', [0.1 0.3 0.9]);
s.resolve();
fp = FastPlot('Parent', panels3{4}, 'Theme', fig3.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels3{4}, 'Differential Pressure (3M pts)', 'Color', 'w');

close(fig3.hFigure);
fprintf('  Tab 3 done in %.2f s\n', toc(tab3Tic));

% =========================================================================
% TAB 4: Gas Delivery — 3x2 grid, 6 sensors, ~15M points
% =========================================================================
fprintf('Building Tab 4: Gas Delivery (6 tiles, ~15M pts)...\n');
tab4Tic = tic;
tab4 = uitab(tabGroup, 'Title', 'Gas Delivery');

fig4 = FastPlotFigure(3, 2, 'Theme', 'dark', 'Name', 'ignore');
set(fig4.hFigure, 'Visible', 'off');
panels4 = create_tab_axes(tab4, 3, 2, fig4.Theme);

gasNames = {'Argon', 'Nitrogen', 'Oxygen', 'CF4', 'CHF3', 'He'};
gasNominal = [200 150 80 50 30 500];
gasNoise = [10 8 5 3 2 20];
gasSizes = [3e6 3e6 2e6 2e6 2e6 3e6];
gasThHi = [240 180 100 60 38 560];
gasThLo = [160 120 60 40 22 440];

for gi = 1:6
    Ng = gasSizes(gi);
    tg = linspace(0, 3600, Ng);
    s = Sensor(lower(gasNames{gi}), 'Name', [gasNames{gi} ' Flow']);
    s.X = tg;
    s.Y = gasNominal(gi) + gasNoise(gi)*sin(2*pi*tg/600) + ...
          (gasNoise(gi)/3)*randn(1, Ng);
    % Add a flow excursion in each gas
    excStart = round(Ng * (0.3 + 0.1*gi));
    excEnd = min(excStart + round(Ng*0.02), Ng);
    s.Y(excStart:excEnd) = s.Y(excStart:excEnd) + gasNoise(gi)*3;
    s.addStateChannel(scMachine);
    s.addThresholdRule(struct('machine', 1), gasThHi(gi), 'Direction', 'upper', ...
        'Label', [gasNames{gi} ' HH'], 'Color', [0.9 0.2 0.1]);
    s.addThresholdRule(struct('machine', 1), gasThLo(gi), 'Direction', 'lower', ...
        'Label', [gasNames{gi} ' LL'], 'Color', [0.1 0.3 0.9]);
    s.resolve();
    fp = FastPlot('Parent', panels4{gi}, 'Theme', fig4.Theme);
    fp.addSensor(s, 'ShowThresholds', true);
    fp.render();
    title(panels4{gi}, sprintf('%s Flow (%.0fM pts)', gasNames{gi}, Ng/1e6), ...
        'Color', 'w');
end

close(fig4.hFigure);
fprintf('  Tab 4 done in %.2f s\n', toc(tab4Tic));

% =========================================================================
% TAB 5: Power & Cooling — 2x2 grid, 4 sensors, ~10M points
% =========================================================================
fprintf('Building Tab 5: Power & Cooling (4 tiles, ~10M pts)...\n');
tab5Tic = tic;
tab5 = uitab(tabGroup, 'Title', 'Power & Cooling');

fig5 = FastPlotFigure(2, 2, 'Theme', 'dark', 'Name', 'ignore');
set(fig5.hFigure, 'Visible', 'off');
panels5 = create_tab_axes(tab5, 2, 2, fig5.Theme);

% Tile 5.1: Chiller Supply Temp — 3M pts
s = Sensor('chiller_supply', 'Name', 'Chiller Supply');
N = 3e6; t = linspace(0, 3600, N);
s.X = t; s.Y = 18 + 2*sin(2*pi*t/1200) + 0.5*randn(1, N);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 21, 'Direction', 'upper', ...
    'Label', 'Supply High', 'Color', [0.9 0.3 0.1]);
s.addThresholdRule(struct('machine', 1), 15, 'Direction', 'lower', ...
    'Label', 'Supply Low', 'Color', [0.1 0.3 0.9]);
s.resolve();
fp = FastPlot('Parent', panels5{1}, 'Theme', fig5.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels5{1}, 'Chiller Supply Temp (3M pts)', 'Color', 'w');

% Tile 5.2: Chiller Return Temp — 3M pts
s = Sensor('chiller_return', 'Name', 'Chiller Return');
s.X = t; s.Y = 24 + 3*sin(2*pi*t/1200) + 0.8*randn(1, N);
s.Y(2e6:2.05e6) = s.Y(2e6:2.05e6) + 5;  % cooling loss
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 29, 'Direction', 'upper', ...
    'Label', 'Return High', 'Color', [1 0.2 0]);
s.resolve();
fp = FastPlot('Parent', panels5{2}, 'Theme', fig5.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels5{2}, 'Chiller Return Temp (3M pts)', 'Color', 'w');

% Tile 5.3: Mains Voltage — 2M pts
s = Sensor('mains_v', 'Name', 'Mains Voltage');
N3 = 2e6; t3 = linspace(0, 3600, N3);
s.X = t3; s.Y = 230 + 5*sin(2*pi*t3/600) + 2*randn(1, N3);
s.Y(8e5:8.1e5) = s.Y(8e5:8.1e5) - 15;  % voltage dip
s.addThresholdRule(struct(), 240, 'Direction', 'upper', ...
    'Label', 'Overvoltage', 'Color', [1 0.2 0]);
s.addThresholdRule(struct(), 220, 'Direction', 'lower', ...
    'Label', 'Undervoltage', 'Color', [0.2 0.4 1]);
s.resolve();
fp = FastPlot('Parent', panels5{3}, 'Theme', fig5.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels5{3}, 'Mains Voltage (2M pts)', 'Color', 'w');

% Tile 5.4: UPS Load — 2M pts
s = Sensor('ups_load', 'Name', 'UPS Load');
s.X = t3; s.Y = 60 + 15*sin(2*pi*t3/1800) + 5*randn(1, N3);
s.addStateChannel(scMachine);
s.addThresholdRule(struct('machine', 1), 80, 'Direction', 'upper', ...
    'Label', 'Load Warning', 'Color', [0.9 0.6 0.1]);
s.addThresholdRule(struct('machine', 1), 90, 'Direction', 'upper', ...
    'Label', 'Load Alarm', 'Color', [1 0 0]);
s.resolve();
fp = FastPlot('Parent', panels5{4}, 'Theme', fig5.Theme);
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(panels5{4}, 'UPS Load (2M pts)', 'Color', 'w');

close(fig5.hFigure);
fprintf('  Tab 5 done in %.2f s\n', toc(tab5Tic));

% =========================================================================
% Show the window
% =========================================================================
set(hFig, 'Visible', 'on');
drawnow;

totalTime = toc(totalTic);
totalPts = 5e6*4 + 3e6*4 + 4e6 + 2e6*4 + 1e6 + sum(gasSizes);
fprintf('\n=== Stress Test Complete ===\n');
fprintf('  5 tabs, 26 sensor tiles\n');
fprintf('  %.1fM total data points\n', totalPts/1e6);
fprintf('  Total time: %.2f seconds\n', totalTime);


function panels = create_tab_axes(tab, rows, cols, theme)
%CREATE_TAB_AXES Create a grid of axes inside a uitab.
    nTiles = rows * cols;
    panels = cell(1, nTiles);
    pad = 0.06;
    gapH = 0.05;
    gapV = 0.07;
    totalW = 1 - 2*pad;
    totalH = 1 - 2*pad;
    cellW = (totalW - (cols-1)*gapH) / cols;
    cellH = (totalH - (rows-1)*gapV) / rows;

    tab.BackgroundColor = theme.Background;

    for n = 1:nTiles
        row = ceil(n / cols);
        col = mod(n - 1, cols) + 1;
        x = pad + (col-1) * (cellW + gapH);
        y = 1 - pad - row * cellH - (row-1) * gapV;
        panels{n} = axes('Parent', tab, 'Position', [x y cellW cellH]);
    end
end
