function test_parse_opts()
%TEST_PARSE_OPTS Tests for the shared parseOpts helper.

    add_private_path();

    % testBasicParsing — known keys are parsed correctly
    defaults.Color = [1 0 0];
    defaults.Label = '';
    [opts, unmatched] = parseOpts(defaults, {'Color', [0 1 0], 'Label', 'test'});
    assert(isequal(opts.Color, [0 1 0]), 'testBasicParsing: Color');
    assert(strcmp(opts.Label, 'test'), 'testBasicParsing: Label');
    assert(isempty(fieldnames(unmatched)), 'testBasicParsing: no unmatched');

    % testDefaultsApplied — missing keys keep defaults
    defaults.Color = [1 0 0];
    defaults.Label = 'default';
    [opts, ~] = parseOpts(defaults, {});
    assert(isequal(opts.Color, [1 0 0]), 'testDefaultsApplied: Color');
    assert(strcmp(opts.Label, 'default'), 'testDefaultsApplied: Label');

    % testCaseInsensitive — keys are matched case-insensitively
    defaults.FaceColor = [1 0 0];
    [opts, ~] = parseOpts(defaults, {'facecolor', [0 0 1]});
    assert(isequal(opts.FaceColor, [0 0 1]), 'testCaseInsensitive');

    % testUnmatchedKeysReturned — unknown keys go to unmatched
    defaults.Color = [1 0 0];
    [opts, unmatched] = parseOpts(defaults, {'Color', [0 1 0], 'DisplayName', 'foo'});
    assert(isequal(opts.Color, [0 1 0]), 'testUnmatched: known key');
    assert(isfield(unmatched, 'DisplayName'), 'testUnmatched: unknown key returned');
    assert(strcmp(unmatched.DisplayName, 'foo'), 'testUnmatched: unknown value');

    % testVerboseWarning — warns on unknown keys when verbose is true
    defaults.Color = [1 0 0];
    lastwarn('');
    [~, ~] = parseOpts(defaults, {'Colr', [0 1 0]}, true);
    [warnMsg, ~] = lastwarn();
    assert(~isempty(warnMsg), 'testVerboseWarning: should warn on unknown key');
    assert(contains(warnMsg, 'Colr'), 'testVerboseWarning: mentions bad key');

    % testNoWarningWhenNotVerbose — silent on unknown keys by default
    defaults.Color = [1 0 0];
    lastwarn('');
    [~, ~] = parseOpts(defaults, {'Colr', [0 1 0]});
    [warnMsg, ~] = lastwarn();
    assert(isempty(warnMsg), 'testNoWarning: should not warn');

    % testEmptyVarargin — handles empty args
    defaults.Color = [1 0 0];
    [opts, unmatched] = parseOpts(defaults, {});
    assert(isequal(opts.Color, [1 0 0]), 'testEmptyVarargin');
    assert(isempty(fieldnames(unmatched)), 'testEmptyVarargin: no unmatched');

    % testMultipleUnmatchedKeys — multiple unknown keys
    defaults.Color = [1 0 0];
    [~, unmatched] = parseOpts(defaults, {'LineWidth', 2, 'DisplayName', 'foo'});
    assert(isfield(unmatched, 'LineWidth'), 'testMultiUnmatched: LineWidth');
    assert(isfield(unmatched, 'DisplayName'), 'testMultiUnmatched: DisplayName');

    fprintf('    All 8 parseOpts tests passed.\n');
end
