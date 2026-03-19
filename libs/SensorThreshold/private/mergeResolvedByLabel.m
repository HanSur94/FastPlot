function [mergedTh, mergedViol] = mergeResolvedByLabel(resolvedTh, resolvedViol, segBounds, dataEnd)
%MERGERESOLVEDBYLABEL Merge resolved thresholds sharing the same Label+Direction.
%   [mergedTh, mergedViol] = MERGERESOLVEDBYLABEL(resolvedTh, resolvedViol, segBounds, dataEnd)
%   consolidates threshold and violation entries that were produced by
%   different condition groups during Sensor.resolve() but logically
%   represent the same threshold line (same Label and Direction).
%
%   The merge involves three operations per group:
%     1. Overlay Y values: fill NaN gaps in one entry with non-NaN values
%        from sibling entries, producing a single composite Y array that
%        covers all active segments for the shared label.
%     2. Convert to step-function format via toStepFunction(), which
%        duplicates X at boundaries for sharp vertical steps and inserts
%        NaN separators between non-contiguous active regions.
%     3. Concatenate and time-sort the violation X/Y arrays from all
%        sibling entries.
%
%   Unlabeled entries (empty Label) are never merged; each receives a
%   unique synthetic key to keep them separate.
%
%   Inputs:
%     resolvedTh   — struct array of threshold entries from resolve()
%     resolvedViol — struct array of violation entries (same length)
%     segBounds    — 1xS double, segment boundary timestamps
%     dataEnd      — scalar double, timestamp of the last sensor sample
%
%   Outputs:
%     mergedTh   — struct array, one entry per unique Label+Direction
%     mergedViol — struct array, companion violation data (same length)
%
%   See also Sensor.resolve, appendResults, buildThresholdEntry.

    % Pass through when there is nothing to merge
    if isempty(resolvedTh)
        mergedTh = resolvedTh;
        mergedViol = resolvedViol;
        return;
    end

    nEntries = numel(resolvedTh);

    % --- Build merge keys from Label + Direction ---
    % Labeled entries with the same label and direction share a key;
    % unlabeled entries get unique synthetic keys to prevent merging.
    mergeKeys = cell(1, nEntries);
    for i = 1:nEntries
        lbl = resolvedTh(i).Label;
        if isempty(lbl)
            mergeKeys{i} = sprintf('__unlabeled_%d__', i);
        else
            mergeKeys{i} = [lbl '|' resolvedTh(i).Direction];
        end
    end

    % Group entries by their merge key (stable preserves original order).
    % Octave's unique() does not support the 3rd output for cell arrays,
    % so we compute groupIdx manually.
    [uniqueKeys, ~] = unique(mergeKeys, 'stable');
    nGroups = numel(uniqueKeys);
    groupIdx = zeros(1, nEntries);
    for gi = 1:nGroups
        groupIdx(strcmp(mergeKeys, uniqueKeys{gi})) = gi;
    end

    mergedTh = [];
    mergedViol = [];

    for g = 1:nGroups
        members = find(groupIdx == g);
        nMembers = numel(members);
        base = resolvedTh(members(1));

        if nMembers == 1
            % --- Fast path: single member, no merge needed ---
            % Violations are already sorted (produced by left-to-right
            % segment scan).  Skip allocation, copy, and sort entirely.
            [stepX, stepY] = toStepFunction(segBounds, base.Y, dataEnd);
            base.X = stepX;
            base.Y = stepY;

            v = resolvedViol(members(1));
            mergedViol_entry = struct('X', v.X, 'Y', v.Y, ...
                'Direction', base.Direction, 'Label', base.Label);
        else
            % --- Multi-member merge ---
            % Overlay Y arrays from all members
            mergedY = base.Y;
            for m = 2:nMembers
                otherY = resolvedTh(members(m)).Y;
                fill = isnan(mergedY) & ~isnan(otherY);
                mergedY(fill) = otherY(fill);
            end

            [stepX, stepY] = toStepFunction(segBounds, mergedY, dataEnd);
            base.X = stepX;
            base.Y = stepY;

            % Concatenate violation arrays from all members.
            % Each member's violations are already sorted (segment scan
            % order) and come from non-overlapping time segments, so the
            % concatenation is already in chronological order — skip sort.
            totalViolLen = 0;
            for m = 1:nMembers
                totalViolLen = totalViolLen + numel(resolvedViol(members(m)).X);
            end

            if totalViolLen == 0
                allViolX = [];
                allViolY = [];
            else
                allViolX = zeros(1, totalViolLen);
                allViolY = zeros(1, totalViolLen);
                pos = 0;
                for m = 1:nMembers
                    v = resolvedViol(members(m));
                    nv = numel(v.X);
                    if nv > 0
                        allViolX(pos+1:pos+nv) = v.X;
                        allViolY(pos+1:pos+nv) = v.Y;
                        pos = pos + nv;
                    end
                end
            end
            mergedViol_entry = struct('X', allViolX, 'Y', allViolY, ...
                'Direction', base.Direction, 'Label', base.Label);
        end

        [mergedTh, mergedViol] = appendResults(mergedTh, mergedViol, ...
            base, mergedViol_entry);
    end
end

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
