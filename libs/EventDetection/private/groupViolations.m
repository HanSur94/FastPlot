function groups = groupViolations(t, values, thresholdValue, direction)
%GROUPVIOLATIONS Cluster consecutive threshold violations into groups.
%   groups = groupViolations(t, values, thresholdValue, direction)
%
%   Returns struct array with fields: startIdx, endIdx.
%   Empty if no violations found.

    if strcmp(direction, 'upper')
        violating = values > thresholdValue;
    else
        violating = values < thresholdValue;
    end

    groups = [];

    if ~any(violating)
        return;
    end

    % Find transitions: 0→1 = start, 1→0 = end
    d = diff([0, violating, 0]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    nGroups = numel(starts);
    groups = struct('startIdx', cell(1, nGroups), 'endIdx', cell(1, nGroups));
    for i = 1:nGroups
        groups(i).startIdx = starts(i);
        groups(i).endIdx   = ends(i);
    end
end
