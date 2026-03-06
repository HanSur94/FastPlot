function test_add_shaded()
%TEST_ADD_SHADED Tests for FastPlot.addShaded method.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testAddShaded
    x = 1:100;
    y1 = ones(1,100) * 2;
    y2 = ones(1,100) * -2;
    fp = FastPlot();
    fp.addShaded(x, y1, y2, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2);
    assert(numel(fp.Shadings) == 1, 'testAddShaded: count');
    assert(isequal(fp.Shadings(1).X, x), 'testAddShaded: X');
    assert(isequal(fp.Shadings(1).Y1, y1), 'testAddShaded: Y1');
    assert(isequal(fp.Shadings(1).Y2, y2), 'testAddShaded: Y2');

    % testShadedRendered
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.addShaded(1:100, ones(1,100), zeros(1,100), 'FaceColor', [1 0 0]);
    fp.render();
    assert(~isempty(fp.Shadings(1).hPatch), 'testShadedRendered: hPatch');
    assert(ishandle(fp.Shadings(1).hPatch), 'testShadedRendered: valid');
    ud = get(fp.Shadings(1).hPatch, 'UserData');
    assert(strcmp(ud.FastPlot.Type, 'shaded'), 'testShadedRendered: type');
    close(fp.hFigure);

    % testShadedValidation
    fp = FastPlot();
    threw = false;
    try
        fp.addShaded(1:10, 1:10, 1:5);  % mismatched lengths
    catch
        threw = true;
    end
    assert(threw, 'testShadedValidation: length mismatch');

    % testShadedMonotonicX
    fp = FastPlot();
    threw = false;
    try
        fp.addShaded([3 1 2], [1 1 1], [0 0 0]);
    catch
        threw = true;
    end
    assert(threw, 'testShadedMonotonicX');

    % testShadedRejectsAfterRender
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.render();
    threw = false;
    try
        fp.addShaded(1:10, ones(1,10), zeros(1,10));
    catch
        threw = true;
    end
    assert(threw, 'testShadedRejectsAfterRender');
    close(fp.hFigure);

    % testShadedColumnVectors
    fp = FastPlot();
    fp.addShaded((1:10)', (1:10)', zeros(10,1));
    assert(isrow(fp.Shadings(1).X), 'testShadedColumnVectors: X row');
    assert(isrow(fp.Shadings(1).Y1), 'testShadedColumnVectors: Y1 row');
    assert(isrow(fp.Shadings(1).Y2), 'testShadedColumnVectors: Y2 row');

    fprintf('    All 6 addShaded tests passed.\n');
end
