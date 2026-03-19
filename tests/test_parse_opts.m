function test_parse_opts()
%TEST_PARSE_OPTS Tests for parseOpts private helper function.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastplot_private_path();

    % testBasicOverride
    defs.Color = 'r';
    defs.Width = 1;
    [opts, unmatched] = parseOpts(defs, {'Color', 'b'});
    assert(strcmp(opts.Color, 'b'), 'testBasicOverride: Color overridden');
    assert(opts.Width == 1, 'testBasicOverride: Width unchanged');
    assert(isempty(fieldnames(unmatched)), 'testBasicOverride: no unmatched');

    % testCaseInsensitive
    defs.Color = 'r';
    defs.Width = 1;
    [opts, ~] = parseOpts(defs, {'color', 'g', 'WIDTH', 3});
    assert(strcmp(opts.Color, 'g'), 'testCaseInsensitive: Color matched');
    assert(opts.Width == 3, 'testCaseInsensitive: Width matched');

    % testUnmatchedOptions
    defs.Color = 'r';
    [opts, unmatched] = parseOpts(defs, {'Color', 'b', 'Name', 'foo', 'Tag', 'bar'});
    assert(strcmp(opts.Color, 'b'), 'testUnmatchedOptions: Color set');
    assert(isfield(unmatched, 'Name'), 'testUnmatchedOptions: Name in unmatched');
    assert(strcmp(unmatched.Name, 'foo'), 'testUnmatchedOptions: Name value');
    assert(isfield(unmatched, 'Tag'), 'testUnmatchedOptions: Tag in unmatched');
    assert(strcmp(unmatched.Tag, 'bar'), 'testUnmatchedOptions: Tag value');

    % testEmptyArgs
    defs.Color = 'r';
    defs.Width = 1;
    [opts, unmatched] = parseOpts(defs, {});
    assert(strcmp(opts.Color, 'r'), 'testEmptyArgs: Color unchanged');
    assert(opts.Width == 1, 'testEmptyArgs: Width unchanged');
    assert(isempty(fieldnames(unmatched)), 'testEmptyArgs: no unmatched');

    % testVerboseWarning
    defs.Color = 'r';
    w = warning('query', 'all');
    lastwarn('');
    [~, ~] = parseOpts(defs, {'Unknown', 123}, true);
    [msg, ~] = lastwarn();
    assert(~isempty(msg), 'testVerboseWarning: warning emitted');
    warning(w);

    % testMultipleOverrides — last value wins
    defs.Color = 'r';
    [opts, ~] = parseOpts(defs, {'Color', 'b', 'Color', 'g'});
    assert(strcmp(opts.Color, 'g'), 'testMultipleOverrides: last value wins');

    % testNumericValue
    defs.LineWidth = 1;
    defs.MarkerSize = 6;
    [opts, ~] = parseOpts(defs, {'LineWidth', 2.5, 'MarkerSize', 10});
    assert(opts.LineWidth == 2.5, 'testNumericValue: LineWidth');
    assert(opts.MarkerSize == 10, 'testNumericValue: MarkerSize');

    % testArrayValue
    defs.Position = [0 0 1 1];
    [opts, ~] = parseOpts(defs, {'Position', [0.1 0.2 0.8 0.6]});
    assert(isequal(opts.Position, [0.1 0.2 0.8 0.6]), 'testArrayValue: Position');

    fprintf('    All 8 parseOpts tests passed.\n');
end
