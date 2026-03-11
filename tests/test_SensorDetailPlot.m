function tests = test_SensorDetailPlot
    tests = functiontests(localfunctions);
end

function setup(testCase)
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'FastPlot'));
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'SensorThreshold'));
    addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'libs', 'EventDetection'));

    % Create a simple sensor
    s = Sensor('test_pressure', 'Name', 'Test Pressure');
    t = linspace(0, 100, 10000);
    s.X = t;
    s.Y = 50 + 10*sin(2*pi*t/20) + randn(1, numel(t));
    testCase.TestData.sensor = s;
end

function teardown(testCase)
    % Close any figures opened during tests
    close all force;
end

%% Construction
function test_constructor_stores_sensor(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    verifyEqual(testCase, sdp.Sensor.Key, 'test_pressure');
    delete(sdp);
end

function test_constructor_default_options(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    verifyEqual(testCase, sdp.NavigatorHeight, 0.20, 'AbsTol', 1e-10);
    verifyTrue(testCase, sdp.ShowThresholds);
    verifyTrue(testCase, sdp.ShowThresholdBands);
    verifyTrue(testCase, isempty(sdp.Events));
    delete(sdp);
end

function test_constructor_custom_options(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor, ...
        'NavigatorHeight', 0.30, ...
        'ShowThresholds', false, ...
        'Theme', 'dark', ...
        'Title', 'Custom Title');
    verifyEqual(testCase, sdp.NavigatorHeight, 0.30, 'AbsTol', 1e-10);
    verifyFalse(testCase, sdp.ShowThresholds);
    delete(sdp);
end

%% Render creates two FastPlot instances
function test_render_creates_main_and_navigator(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyClass(testCase, sdp.MainPlot, ?FastPlot);
    verifyClass(testCase, sdp.NavigatorPlot, ?FastPlot);
    delete(sdp);
end

%% Render guard
function test_render_twice_throws(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyError(testCase, @() sdp.render(), 'SensorDetailPlot:alreadyRendered');
    delete(sdp);
end

%% MainPlot has sensor data
function test_main_plot_has_sensor_line(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyGreaterThanOrEqual(testCase, numel(sdp.MainPlot.Lines), 1);
    delete(sdp);
end

%% NavigatorPlot has data line
function test_navigator_has_data_line(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    verifyGreaterThanOrEqual(testCase, numel(sdp.NavigatorPlot.Lines), 1);
    delete(sdp);
end

%% Zoom range methods
function test_set_get_zoom_range(testCase)
    sdp = SensorDetailPlot(testCase.TestData.sensor);
    sdp.render();
    sdp.setZoomRange(20, 60);
    [xMin, xMax] = sdp.getZoomRange();
    verifyEqual(testCase, xMin, 20, 'AbsTol', 1);
    verifyEqual(testCase, xMax, 60, 'AbsTol', 1);
    delete(sdp);
end
