% example_live.m — Interactive live mode demo (GUI)
%
% Opens a visible dashboard, then simulates 10 data updates with pauses
% so you can watch the plot update in real time.
%
% Usage:
%   octave examples/example_live.m     (with GUI)
%   Run from MATLAB command window

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

fprintf('=== FastPlot Live Mode Demo ===\n\n');

% --- Create initial data and save to .mat ---
tmpFile = fullfile(tempdir, 'fastplot_live_demo.mat');
nPoints = 100000;
x = linspace(0, 100, nPoints);
s.time = x;
s.pressure = sin(x * 2*pi/10) + 0.3*randn(1, nPoints);
s.temperature = 50 + 5*cos(x * 2*pi/20) + 0.5*randn(1, nPoints);
save(tmpFile, '-struct', 's');
fprintf('Initial data: %d points saved to %s\n', nPoints, tmpFile);

% --- Create dashboard ---
fig = FastPlotFigure(2, 1, 'Theme', 'dark', 'Name', 'Live Dashboard');

fp1 = fig.tile(1);
fp1.addLine(s.time, s.pressure, 'DisplayName', 'Pressure', 'Color', [0.3 0.7 1]);
fp1.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);

fp2 = fig.tile(2);
fp2.addLine(s.time, s.temperature, 'DisplayName', 'Temperature', 'Color', [1 0.5 0.3]);
fp2.addThreshold(58, 'Direction', 'upper', 'ShowViolations', true);

fig.renderAll();
fig.tileTitle(1, 'Pressure');
fig.tileTitle(2, 'Temperature');
tb = FastPlotToolbar(fig);
drawnow;

fprintf('Dashboard open. Simulating 10 live data updates (2s apart)...\n');
fprintf('Watch the plot update! Close the figure to stop early.\n\n');

% --- Simulate a background process updating the .mat file ---
for i = 1:10
    pause(2);
    if ~ishandle(fig.hFigure)
        fprintf('Figure closed.\n');
        break;
    end

    % New data: more points, shifted signals
    nNew = nPoints + i * 10000;
    s.time = linspace(0, 100 + i*10, nNew);
    s.pressure = sin(s.time * 2*pi/10) + 0.3*randn(1, nNew) + 0.15*i;
    s.temperature = 50 + 5*cos(s.time * 2*pi/20) + 0.5*randn(1, nNew) + 0.3*i;

    % Write updated data to .mat file
    save(tmpFile, '-struct', 's');

    % Update the plot (this is what startLive/runLive does automatically)
    fig.tile(1).updateData(1, s.time, s.pressure);
    fig.tile(2).updateData(1, s.time, s.temperature);
    drawnow;

    fprintf('  Update %d/%d: %d points, t=[0..%d]\n', i, 10, nNew, 100 + i*10);
end

fprintf('\nDemo complete. Figure stays open — zoom and pan to explore.\n');
fprintf('Temp file: %s\n', tmpFile);
