function aligned = alignStateToTime(stateX, stateY, sensorX)
%ALIGNSTATETOTIME Align state values to sensor timestamps via zero-order hold.
%   aligned = alignStateToTime(stateX, stateY, sensorX)
%
%   For each timestamp in sensorX, returns the last known state value
%   from stateY (zero-order hold / nearest-previous). If sensorX timestamp
%   is before the first stateX, returns the first state value.
%
%   Inputs:
%     stateX  — 1xM sorted timestamps of state changes
%     stateY  — 1xM state values (numeric array or cell array of char/string)
%     sensorX — 1xN sorted sensor timestamps to align to
%
%   Output:
%     aligned — 1xN aligned state values (same type as stateY)

    n = numel(sensorX);
    isCellY = iscell(stateY);

    if isCellY
        aligned = cell(1, n);
    else
        aligned = zeros(1, n);
    end

    % Vectorized: use histc/discretize-style binning for bulk alignment
    % For each sensorX value, find the last stateX <= sensorX
    % This is equivalent to a right binary search for each element
    m = numel(stateX);

    % Use interp1 with 'previous' for numeric, manual for cell
    if ~isCellY && m > 1
        % Fast vectorized path for numeric states
        % interp1 'previous' does exactly zero-order hold
        aligned = interp1(stateX, stateY, sensorX, 'previous', 'extrap');
        % interp1 extrap with 'previous' returns NaN for values before first
        % Fix: set those to the first state value
        beforeFirst = sensorX < stateX(1);
        aligned(beforeFirst) = stateY(1);
    elseif ~isCellY && m == 1
        aligned(:) = stateY(1);
    else
        % Cell path — loop with binary search
        for k = 1:n
            idx = binary_search(stateX, sensorX(k), 'right');
            aligned{k} = stateY{idx};
        end
    end
end
