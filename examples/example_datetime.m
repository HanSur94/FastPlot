%% FastPlot Datetime X-Axis Demo
% Demonstrates auto-formatted date/time tick labels that adapt to zoom level.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

%% Single day at 1-second resolution
n = 86400;
x = datenum(2024,1,1) + (0:n-1)/86400;
y = sin((1:n) * 2*pi/3600) + 0.2*randn(1,n);

fprintf('Datetime example: %d points (1 day, 1-second resolution)...\n', n);
tic;

fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor', 'XType', 'datenum');
fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
title(fp.hAxes, 'Datetime Axis — zoom to see format change');

tb = FastPlotToolbar(fp);

fprintf('Rendered in %.3f seconds.\n', toc);
fprintf('Zoom in: tick labels change from "Jan 01 10:00" to "HH:MM" to "HH:MM:SS"\n');
fprintf('Try the crosshair and data cursor — they show datetime values too.\n');
