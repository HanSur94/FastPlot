function [stepX, stepY] = toStepFunction(segBounds, values, dataEnd)
%TOSTEPFUNCTION Convert segment boundary values to step-function arrays.
%   [stepX, stepY] = TOSTEPFUNCTION(segBounds, values, dataEnd) transforms
%   a segment-boundary representation (one value per boundary) into a
%   piecewise-constant plot-ready representation where each segment is a
%   horizontal line from segStart to segEnd.
%
%   Rendering rules:
%     - Active segments (non-NaN value) emit two X/Y points:
%       [segStart, value] and [segEnd, value].
%     - Contiguous active segments share a boundary; the shared X is
%       duplicated to produce a vertical step between differing values.
%     - Non-contiguous active segments (separated by NaN gaps) are joined
%       by NaN separators so that the plot line breaks between them.
%
%   Inputs:
%     segBounds — 1xS double, segment boundary timestamps
%     values    — 1xS double, threshold value at each boundary (NaN =
%                 inactive)
%     dataEnd   — scalar double, end-of-data timestamp (used as the right
%                 edge of the last segment)
%
%   Outputs:
%     stepX — 1xP double, X coordinates for plotting
%     stepY — 1xP double, Y coordinates for plotting
%
%   See also mergeResolvedByLabel.

    % MEX fast path — bypass MATLAB interpreter overhead entirely
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('to_step_function_mex', 'file') == 3);
    end
    if useMex
        [stepX, stepY] = to_step_function_mex(segBounds, values, dataEnd);
        return;
    end

    nB = numel(segBounds);

    % Vectorized active-segment detection
    active = ~isnan(values);

    if ~any(active)
        stepX = [];
        stepY = [];
        return;
    end

    % Compute right edges for all segments at once
    segEnds = [segBounds(2:end), dataEnd];

    % Find active indices
    activeIdx = find(active);
    nActive = numel(activeIdx);

    % Detect where contiguous runs break: a gap occurs when the previous
    % segment's right edge does not equal the current segment's left edge,
    % OR when the previous segment was not the immediately preceding index.
    % For the first active segment, there is always a "break" (new run).
    if nActive == 1
        % Single active segment — no gaps, no NaN separators
        stepX = [segBounds(activeIdx), segEnds(activeIdx)];
        stepY = [values(activeIdx), values(activeIdx)];
        return;
    end

    % Pre-allocate to maximum possible size:
    %   Each active segment emits 2 points (start, end).
    %   Contiguous segments add 2 more (step at shared boundary).
    %   Gaps add 1 NaN separator.
    % Worst case: 3*nActive + nActive = 4*nActive (generous upper bound)
    maxLen = 4 * nActive;
    stepX = zeros(1, maxLen);
    stepY = zeros(1, maxLen);

    % Vectorized gap detection: gap where consecutive active indices are
    % not adjacent, OR where the previous segment's right edge differs
    % from the current segment's left edge.
    prevEnds = segEnds(activeIdx(1:end-1));
    currStarts = segBounds(activeIdx(2:end));
    isGap = (prevEnds ~= currStarts);

    % Fill output in a single pass
    pos = 0;

    % First active segment
    k = activeIdx(1);
    pos = pos + 1; stepX(pos) = segBounds(k); stepY(pos) = values(k);
    pos = pos + 1; stepX(pos) = segEnds(k);   stepY(pos) = values(k);

    for a = 2:nActive
        k = activeIdx(a);
        if isGap(a - 1)
            % Non-contiguous: insert NaN separator, then new segment
            pos = pos + 1; stepX(pos) = NaN;           stepY(pos) = NaN;
            pos = pos + 1; stepX(pos) = segBounds(k);  stepY(pos) = values(k);
            pos = pos + 1; stepX(pos) = segEnds(k);    stepY(pos) = values(k);
        else
            % Contiguous: duplicate boundary X for vertical step
            pos = pos + 1; stepX(pos) = segBounds(k);  stepY(pos) = values(k);
            pos = pos + 1; stepX(pos) = segEnds(k);    stepY(pos) = values(k);
        end
    end

    % Trim to actual length
    stepX = stepX(1:pos);
    stepY = stepY(1:pos);
end
