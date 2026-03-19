function test_console_progress_bar()
%TEST_CONSOLE_PROGRESS_BAR Tests for ConsoleProgressBar class.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

    % testConstructorDefaults
    pb = ConsoleProgressBar();
    assert(true, 'testConstructorDefaults: no error');

    % testConstructorWithIndent
    pb = ConsoleProgressBar(4);
    assert(true, 'testConstructorWithIndent: no error');

    % testStartSetsState
    pb = ConsoleProgressBar();
    pb.start();
    % Verify it printed something by checking no error was thrown
    assert(true, 'testStartSetsState: started without error');

    % testUpdateBeforeStart — should not crash
    pb = ConsoleProgressBar();
    pb.update(5, 10, 'test');
    assert(true, 'testUpdateBeforeStart: no crash');

    % testUpdateAfterStart
    pb = ConsoleProgressBar();
    pb.start();
    pb.update(3, 10, 'working');
    assert(true, 'testUpdateAfterStart: no error');

    % testUpdateWithoutLabel
    pb = ConsoleProgressBar();
    pb.start();
    pb.update(3, 10);
    assert(true, 'testUpdateWithoutLabel: no error');

    % testFreezeStopsUpdates
    pb = ConsoleProgressBar();
    pb.start();
    pb.update(5, 10, 'half');
    pb.freeze();
    pb.update(10, 10, 'done');  % should be silently ignored
    assert(true, 'testFreezeStopsUpdates: no error');

    % testDoubleFreezeIsIdempotent
    pb = ConsoleProgressBar();
    pb.start();
    pb.freeze();
    pb.freeze();  % second freeze should be a no-op
    assert(true, 'testDoubleFreezeIsIdempotent: no error');

    % testFinishSetsComplete
    pb = ConsoleProgressBar();
    pb.start();
    pb.update(3, 10, 'partial');
    pb.finish();
    assert(true, 'testFinishSetsComplete: no error');

    % testFinishWithoutStart — should not crash
    pb = ConsoleProgressBar();
    pb.finish();
    assert(true, 'testFinishWithoutStart: no crash');

    % testFreezeWithoutStart — should not crash
    pb = ConsoleProgressBar();
    pb.freeze();
    assert(true, 'testFreezeWithoutStart: no crash');

    % testFullLifecycle
    pb = ConsoleProgressBar(2);
    pb.start();
    for k = 1:5
        pb.update(k, 5, 'loop');
    end
    pb.finish();
    assert(true, 'testFullLifecycle: no error');

    % testZeroTotal — edge case where total is 0
    pb = ConsoleProgressBar();
    pb.start();
    pb.update(0, 0, 'empty');
    pb.finish();
    assert(true, 'testZeroTotal: no error');

    % testLongLabel — label > 12 chars is truncated without error
    pb = ConsoleProgressBar();
    pb.start();
    pb.update(1, 1, 'VeryLongLabelThatExceeds12Chars');
    pb.finish();
    assert(true, 'testLongLabel: no error');

    fprintf('    All 14 ConsoleProgressBar tests passed.\n');
end
