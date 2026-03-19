function test_fastplot_defaults()
%TEST_FASTPLOT_DEFAULTS Tests for FastPlotDefaults function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testReturnsStruct
    cfg = FastPlotDefaults();
    assert(isstruct(cfg), 'testReturnsStruct: output is struct');

    % testExpectedFields
    expected = {'Theme', 'ThemeDir', 'Verbose', 'MinPointsForDownsample', ...
        'DownsampleFactor', 'PyramidReduction', 'DefaultDownsampleMethod', ...
        'XScale', 'YScale', 'LiveInterval', 'DashboardPadding', ...
        'DashboardGapH', 'DashboardGapV', 'TabBarHeight'};
    for i = 1:numel(expected)
        assert(isfield(cfg, expected{i}), ...
            ['testExpectedFields: missing field ' expected{i}]);
    end

    % testDefaultTypes
    assert(ischar(cfg.Theme), 'testDefaultTypes: Theme is char');
    assert(ischar(cfg.ThemeDir), 'testDefaultTypes: ThemeDir is char');
    assert(islogical(cfg.Verbose), 'testDefaultTypes: Verbose is logical');
    assert(isnumeric(cfg.MinPointsForDownsample), 'testDefaultTypes: MinPointsForDownsample');
    assert(isnumeric(cfg.DownsampleFactor), 'testDefaultTypes: DownsampleFactor');
    assert(isnumeric(cfg.PyramidReduction), 'testDefaultTypes: PyramidReduction');
    assert(ischar(cfg.DefaultDownsampleMethod), 'testDefaultTypes: DefaultDownsampleMethod');
    assert(ischar(cfg.XScale), 'testDefaultTypes: XScale');
    assert(ischar(cfg.YScale), 'testDefaultTypes: YScale');
    assert(isnumeric(cfg.LiveInterval), 'testDefaultTypes: LiveInterval');
    assert(isnumeric(cfg.DashboardPadding) && numel(cfg.DashboardPadding) == 4, ...
        'testDefaultTypes: DashboardPadding is 1x4');
    assert(isnumeric(cfg.DashboardGapH), 'testDefaultTypes: DashboardGapH');
    assert(isnumeric(cfg.DashboardGapV), 'testDefaultTypes: DashboardGapV');
    assert(isnumeric(cfg.TabBarHeight), 'testDefaultTypes: TabBarHeight');

    % testDefaultValues
    assert(strcmp(cfg.Theme, 'default'), 'testDefaultValues: Theme');
    assert(cfg.Verbose == false, 'testDefaultValues: Verbose');
    assert(cfg.MinPointsForDownsample == 5000, 'testDefaultValues: MinPointsForDownsample');
    assert(strcmp(cfg.DefaultDownsampleMethod, 'minmax'), 'testDefaultValues: DefaultDownsampleMethod');
    assert(strcmp(cfg.XScale, 'linear'), 'testDefaultValues: XScale');
    assert(strcmp(cfg.YScale, 'linear'), 'testDefaultValues: YScale');
    assert(cfg.LiveInterval == 2.0, 'testDefaultValues: LiveInterval');

    % testIdempotent — calling twice returns same values
    cfg1 = FastPlotDefaults();
    cfg2 = FastPlotDefaults();
    assert(isequal(cfg1, cfg2), 'testIdempotent: two calls return same result');

    fprintf('    All 5 FastPlotDefaults tests passed.\n');
end
