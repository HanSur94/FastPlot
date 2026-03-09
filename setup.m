function setup()
%SETUP Add FastPlot, SensorThreshold, and EventDetection libraries to the MATLAB path.
%   SETUP() locates the project root (the directory containing this
%   file), then adds the FastPlot, SensorThreshold, and EventDetection
%   library folders to the MATLAB search path using addpath. This makes
%   all library classes, functions, and MEX binaries available for the
%   current session without requiring manual path configuration.
%
%   Run this once per MATLAB session, or add a call to your startup.m
%   for automatic initialization.
%
%   The following directories are added:
%     <project_root>/libs/FastPlot
%     <project_root>/libs/SensorThreshold
%     <project_root>/libs/EventDetection
%
%   Example:
%     setup();   % adds libraries to path; prints confirmation
%
%   See also addpath, FastPlotDefaults, build_mex.

    % Determine the project root from this file's location
    root = fileparts(mfilename('fullpath'));

    % Add library directories to the MATLAB search path
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    fprintf('FastPlot + SensorThreshold + EventDetection libraries added to path.\n');
end
