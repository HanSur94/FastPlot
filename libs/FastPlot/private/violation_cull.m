function [xOut, yOut] = violation_cull(x, y, thX, thY, direction, pixelWidth, xmin)
%VIOLATION_CULL Fused violation detection + pixel-density culling.
%   [xOut, yOut] = violation_cull(x, y, thX, thY, direction, pixelWidth, xmin)
%
%   Uses violation_cull_mex if compiled, otherwise falls back to MATLAB.
%
%   See also compute_violations, compute_violations_dynamic, downsample_violations.

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('violation_cull_mex', 'file') == 3);
    end

    if useMex
        if strcmp(direction, 'upper')
            dirNum = 1;
        else
            dirNum = 0;
        end
        [xOut, yOut] = violation_cull_mex(x, y, thX, thY, dirNum, pixelWidth, xmin);
        return;
    end

    % MATLAB fallback: compute violations then downsample
    if numel(thX) <= 1
        thVal = thY(1);
        [xV, yV] = compute_violations(x, y, thVal, direction);
    else
        [xV, yV] = compute_violations_dynamic(x, y, thX, thY, direction);
        thVal = median(thY(~isnan(thY)));
    end

    if isempty(xV)
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    [xOut, yOut] = downsample_violations(xV, yV, pixelWidth, thVal, xmin);
end
