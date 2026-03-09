classdef ConsoleProgressBar < handle
%CONSOLEPROGRESSBAR Single-line console progress bar for rendering.
%   Lightweight helper that uses fprintf + carriage return to display
%   a progress bar that overwrites itself in the MATLAB command window.
%
%   Usage:
%     pb = ConsoleProgressBar();
%     pb.start();
%     for k = 1:8
%         pb.update(k, 8, 'Rendering');
%         pause(0.1);
%     end
%     pb.finish();
%
%   Bar format:
%     Rendering    [████████████████████░░░░░░░░░░] 5/8
%
%   See also FastPlot, FastPlotFigure.

    properties (Access = private)
        Label        char = ''
        Current      (1,1) double = 0
        Total        (1,1) double = 0
        BarWidth     (1,1) double = 30
        IsStarted    (1,1) logical = false
        LastLen      (1,1) double = 0   % length of last printed line
    end

    methods
        function obj = ConsoleProgressBar()
        %CONSOLEPROGRESSBAR Construct a single-line progress bar.
        end

        function start(obj)
        %START Initialize the progress display.
            obj.IsStarted = true;
            obj.LastLen = 0;
            obj.printBar();
        end

        function update(obj, current, total, label)
        %UPDATE Update progress.
        %   pb.update(current, total)
        %   pb.update(current, total, label)
            obj.Current = current;
            obj.Total   = total;
            if nargin >= 4
                obj.Label = label;
            end
            if obj.IsStarted
                obj.printBar();
            end
        end

        function finish(obj)
        %FINISH Finalize — leave bar at 100% and move to next line.
            if ~obj.IsStarted; return; end
            obj.Current = obj.Total;
            obj.printBar();
            fprintf('\n');
            obj.IsStarted = false;
        end
    end

    methods (Access = private)
        function printBar(obj)
        %PRINTBAR Redraw the progress bar using carriage return.
            filled = char(9608);   % Unicode full block
            empty  = char(9617);   % Unicode light shade

            % Pad label to 12 characters
            lbl = obj.Label;
            if numel(lbl) > 12
                lbl = lbl(1:12);
            end
            lbl = sprintf('%-12s', lbl);

            % Compute filled portion
            if obj.Total > 0
                nFilled = round(obj.BarWidth * obj.Current / obj.Total);
            else
                nFilled = 0;
            end
            nFilled = max(0, min(obj.BarWidth, nFilled));
            nEmpty  = obj.BarWidth - nFilled;

            barStr = [repmat(filled, 1, nFilled), ...
                      repmat(empty,  1, nEmpty)];

            line = sprintf('%s [%s] %d/%d', lbl, barStr, obj.Current, obj.Total);

            % Overwrite previous line with carriage return + padding
            padding = max(0, obj.LastLen - numel(line));
            fprintf('\r%s%s', line, repmat(' ', 1, padding));
            obj.LastLen = numel(line);
        end
    end
end
