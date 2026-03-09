function test_threshold_rule()
%TEST_THRESHOLD_RULE Tests for ThresholdRule class.

    add_sensor_path();

    % testConstructorDefaults
    rule = ThresholdRule(@(st) st.x == 1, 50);
    assert(rule.Value == 50, 'testConstructorDefaults: Value');
    assert(strcmp(rule.Direction, 'upper'), 'testConstructorDefaults: Direction default');
    assert(isempty(rule.Label), 'testConstructorDefaults: Label default');
    assert(isempty(rule.Color), 'testConstructorDefaults: Color default');
    assert(strcmp(rule.LineStyle, '--'), 'testConstructorDefaults: LineStyle default');

    % testConstructorWithOptions
    rule = ThresholdRule(@(st) st.x > 2, 100, ...
        'Direction', 'lower', 'Label', 'Low Alarm', ...
        'Color', [1 0 0], 'LineStyle', ':');
    assert(rule.Value == 100, 'testConstructorWithOptions: Value');
    assert(strcmp(rule.Direction, 'lower'), 'testConstructorWithOptions: Direction');
    assert(strcmp(rule.Label, 'Low Alarm'), 'testConstructorWithOptions: Label');
    assert(isequal(rule.Color, [1 0 0]), 'testConstructorWithOptions: Color');
    assert(strcmp(rule.LineStyle, ':'), 'testConstructorWithOptions: LineStyle');

    % testConditionEvaluation
    rule = ThresholdRule(@(st) st.machine == 1 && st.zone == 0, 50);
    st.machine = 1; st.zone = 0;
    assert(rule.ConditionFn(st) == true, 'testConditionEval: true case');
    st.machine = 2; st.zone = 0;
    assert(rule.ConditionFn(st) == false, 'testConditionEval: false case');

    % testInvalidDirection
    threw = false;
    try
        ThresholdRule(@(st) true, 50, 'Direction', 'sideways');
    catch
        threw = true;
    end
    assert(threw, 'testInvalidDirection: should throw');

    fprintf('    All 4 threshold_rule tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
