function [xOut, yOut] = downsample_violations(xViol, yViol, pixelWidth, thresholdValue, xmin)
%DOWNSAMPLE_VIOLATIONS Cull violation markers to one per pixel column.
%   Keeps the point with maximum |y - thresholdValue| per pixel-X bucket.
%   This preserves the visual extremes while eliminating sub-pixel overlap.
%
%   Inputs:
%     xViol, yViol   — violation coordinates (from compute_violations)
%     pixelWidth     — X-axis span per pixel (diff(xlim) / axesWidthPixels)
%     thresholdValue — threshold value (used to pick max-deviation point)
%     xmin           — left edge of current axis range (anchor for buckets)
%
%   See also compute_violations, FastPlot.updateViolations.

    if isempty(xViol) || pixelWidth <= 0
        xOut = xViol(:)';
        yOut = yViol(:)';
        return;
    end

    % Remove NaN entries (segment separators) before binning
    nanMask = isnan(xViol) | isnan(yViol);
    xClean = xViol(~nanMask);
    yClean = yViol(~nanMask);

    if isempty(xClean)
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    % Assign each point to a pixel-column bucket (anchored to view left edge)
    buckets = floor((xClean - xmin) / pixelWidth);

    % Find unique buckets and pick max-deviation point in each
    [uBuckets, ~, ic] = unique(buckets);
    nBuckets = numel(uBuckets);
    xOut = zeros(1, nBuckets);
    yOut = zeros(1, nBuckets);

    deviation = abs(yClean - thresholdValue);
    for b = 1:nBuckets
        mask = (ic == b);
        devs = deviation(mask);
        [~, bestIdx] = max(devs);
        bx = xClean(mask);
        by = yClean(mask);
        xOut(b) = bx(bestIdx);
        yOut(b) = by(bestIdx);
    end
end
