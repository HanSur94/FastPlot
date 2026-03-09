function [mergedTh, mergedViol] = mergeResolvedByLabel(resolvedTh, resolvedViol, segBounds, dataEnd)
%MERGERESOLVEDBYLABEL Merge resolved thresholds sharing the same Label+Direction.
%   Rules covering different state conditions with the same label produce
%   separate entries during resolve(). This function:
%     1. Overlays their values (fills NaN gaps between condition groups)
%     2. Converts to step-function format for correct rendering
%     3. Merges corresponding violation arrays
%
%   Step-function format: duplicate X at boundaries for sharp steps,
%   NaN separators between non-contiguous active segments.

    if isempty(resolvedTh)
        mergedTh = resolvedTh;
        mergedViol = resolvedViol;
        return;
    end

    nEntries = numel(resolvedTh);

    % Build merge keys from Label+Direction
    mergeKeys = cell(1, nEntries);
    for i = 1:nEntries
        lbl = resolvedTh(i).Label;
        if isempty(lbl)
            % Don't merge unlabeled entries — give unique key
            mergeKeys{i} = sprintf('__unlabeled_%d__', i);
        else
            mergeKeys{i} = [lbl '|' resolvedTh(i).Direction];
        end
    end

    [uniqueKeys, ~, groupIdx] = unique(mergeKeys, 'stable');
    nGroups = numel(uniqueKeys);

    mergedTh = [];
    mergedViol = [];

    for g = 1:nGroups
        members = find(groupIdx == g);

        % Start with first member's Y array
        base = resolvedTh(members(1));
        mergedY = base.Y;

        % Overlay non-NaN values from other members
        for m = 2:numel(members)
            otherY = resolvedTh(members(m)).Y;
            fill = isnan(mergedY) & ~isnan(otherY);
            mergedY(fill) = otherY(fill);
        end

        % Convert to step-function format
        [stepX, stepY] = toStepFunction(segBounds, mergedY, dataEnd);
        base.X = stepX;
        base.Y = stepY;

        % Merge violation arrays from all members
        allViolX = [];
        allViolY = [];
        for m = 1:numel(members)
            v = resolvedViol(members(m));
            allViolX = [allViolX, v.X];
            allViolY = [allViolY, v.Y];
        end
        if numel(allViolX) > 1
            [allViolX, sortIdx] = sort(allViolX);
            allViolY = allViolY(sortIdx);
        end
        mergedViol_entry = struct('X', allViolX, 'Y', allViolY, ...
            'Direction', base.Direction, 'Label', base.Label);

        [mergedTh, mergedViol] = appendResults(mergedTh, mergedViol, ...
            base, mergedViol_entry);
    end
end


function [stepX, stepY] = toStepFunction(segBounds, values, dataEnd)
%TOSTEPFUNCTION Convert segment boundary values to step-function arrays.
%   Each segment becomes a horizontal line [segStart, segEnd] at its value.
%   Contiguous segments with different values create vertical steps at the
%   shared boundary. Non-contiguous active segments get NaN separators.

    nB = numel(segBounds);
    parts = {};  % cell array of {X_array, Y_array} pairs

    for k = 1:nB
        if isnan(values(k))
            continue;
        end

        segStart = segBounds(k);
        if k < nB
            segEnd = segBounds(k + 1);
        else
            segEnd = dataEnd;
        end

        % Check if this continues from the previous part (contiguous boundary)
        if ~isempty(parts) && parts{end}{1}(end) == segStart
            % Contiguous — extend with step at shared boundary
            parts{end}{1} = [parts{end}{1}, segStart, segEnd];
            parts{end}{2} = [parts{end}{2}, values(k), values(k)];
        else
            % New disconnected part
            parts{end+1} = {[segStart, segEnd], [values(k), values(k)]};
        end
    end

    if isempty(parts)
        stepX = [];
        stepY = [];
        return;
    end

    % Concatenate parts with NaN separators between non-contiguous groups
    if numel(parts) == 1
        stepX = parts{1}{1};
        stepY = parts{1}{2};
        return;
    end

    totalLen = 0;
    for p = 1:numel(parts)
        totalLen = totalLen + numel(parts{p}{1});
    end
    totalLen = totalLen + numel(parts) - 1;  % NaN separators

    stepX = zeros(1, totalLen);
    stepY = zeros(1, totalLen);
    idx = 1;
    for p = 1:numel(parts)
        if p > 1
            stepX(idx) = NaN;
            stepY(idx) = NaN;
            idx = idx + 1;
        end
        n = numel(parts{p}{1});
        stepX(idx:idx+n-1) = parts{p}{1};
        stepY(idx:idx+n-1) = parts{p}{2};
        idx = idx + n;
    end
end
