classdef PlantLogReader < handle
%PLANTLOGREADER CSV/XLSX file reader for plant-log entries (PLOG-IM-01..05).
%   PlantLogReader is a handle class with three static methods:
%     PlantLogReader.openInteractive(filePath, varargin) -- Plan 03 wiring,
%       full pipeline with dialog. NOT IMPLEMENTED in this plan; Plan 03 adds it.
%     PlantLogReader.readFile(filePath, mapping) -- headless variant: parse
%       a file using a known mapping struct, return PlantLogEntry[].
%     mapping = PlantLogReader.autoDetect(rawTable) -- score columns and
%       return a mapping struct suggesting timestamp/message columns.
%
%   Mapping struct shape (caller decides; the dialog in Plan 02 produces this):
%     mapping.TimestampColumn  char  variable name in the table
%     mapping.MessageColumn    char  variable name in the table
%     mapping.TimestampFormat  char  explicit format ('' means use ladder)
%
%   Entry contract (each row -> one PlantLogEntry):
%     Timestamp  = datenum (numeric double) from parseTimestampLadder
%     Message    = char(row.<MessageColumn>)
%     Metadata   = struct with one field per non-timestamp/non-message column,
%                  field names sanitized via sanitizeFieldName, values stored
%                  as char (every metadata value is a char string per
%                  CONTEXT.md "Auto-detection of categorical vs numeric
%                  metadata columns is OUT").
%     SourceFile = filePath (the path passed to readFile)
%     Id         = '' (assigned later by PlantLogStore.addEntries)
%     RowHash    = '' (auto-computed in PlantLogEntry ctor)
%
%   Auto-detect thresholds:
%     - Timestamp: column with parse-success ratio >= 0.9 wins.
%       Ties broken by column order (first wins). If no column reaches
%       0.9, TimestampColumn is '' and the caller must surface PLOG-IM-08.
%     - Message: first non-timestamp column with text-ness ratio >= 0.7.
%       If none, MessageColumn is '' and caller picks one manually.
%     - TimestampFormat: '' (the ladder picks the best format on parse).
%
%   Error namespace:
%     PlantLogReader:fileNotFound       -- file does not exist (via readtablePortable)
%     PlantLogReader:unsupportedFormat  -- extension not .csv/.xlsx
%     PlantLogReader:xlsxUnavailable    -- Octave without xlsread JVM
%     PlantLogReader:invalidInput       -- non-char filePath or bad mapping struct
%     PlantLogReader:unknownColumn      -- mapping refers to a column not in the table
%     PlantLogReader:readError          -- readtable threw an unrelated error
%
%   See also PlantLogEntry, PlantLogStore, PlantLogImportDialog.

    methods (Static)

        function entries = readFile(filePath, mapping)
            %READFILE Headless read: parse filePath using mapping, return PlantLogEntry[].
            %
            %   entries = PlantLogReader.readFile(filePath, mapping) parses
            %   the file at filePath, applies the given mapping struct
            %   (TimestampColumn, MessageColumn, TimestampFormat), and
            %   returns a PlantLogEntry array (possibly empty).
            %
            %   Used by Phase 1031 live-tail re-reads, by Plan 03 of this
            %   phase (after the dialog confirms a mapping), and by tests.

            if isstring(filePath); filePath = char(filePath); end
            if ~ischar(filePath) || isempty(filePath)
                error('PlantLogReader:invalidInput', ...
                    'filePath must be a non-empty char/string.');
            end
            if ~isstruct(mapping) || ~isfield(mapping, 'TimestampColumn') ...
                    || ~isfield(mapping, 'MessageColumn')
                error('PlantLogReader:invalidInput', ...
                    'mapping must be a struct with TimestampColumn + MessageColumn fields.');
            end
            if ~isfield(mapping, 'TimestampFormat')
                mapping.TimestampFormat = '';
            end

            % Load the raw table (throws fileNotFound / unsupportedFormat / xlsxUnavailable)
            try
                T = readtablePortable(filePath);
            catch err
                rethrow(err);
            end

            % Empty table -> empty result, no error
            if height(T) == 0
                entries = [];
                return;
            end

            varNames = T.Properties.VariableNames;

            tsCol = char(mapping.TimestampColumn);
            msgCol = char(mapping.MessageColumn);
            if ~ismember(tsCol, varNames)
                error('PlantLogReader:unknownColumn', ...
                    'Timestamp column "%s" not found in file. Available: %s', ...
                    tsCol, strjoin(varNames, ', '));
            end
            if ~ismember(msgCol, varNames)
                error('PlantLogReader:unknownColumn', ...
                    'Message column "%s" not found in file. Available: %s', ...
                    msgCol, strjoin(varNames, ', '));
            end

            % Parse the timestamp column using the ladder (or hint)
            tsColIdx = find(strcmp(varNames, tsCol), 1);
            rawTs = T.(varNames{tsColIdx});
            [parsedTs, ~] = parseTimestampLadder(rawTs, mapping.TimestampFormat);

            % Identify metadata columns (everything except timestamp + message)
            metaIdx = find(~ismember(varNames, {tsCol, msgCol}));
            metaFieldNames = cell(1, numel(metaIdx));
            for mi = 1:numel(metaIdx)
                metaFieldNames{mi} = sanitizeFieldName(varNames{metaIdx(mi)});
            end

            % Build one PlantLogEntry per row, skipping rows whose timestamp NaN'd
            nRows = height(T);
            entries = [];
            for r = 1:nRows
                if ~isfinite(parsedTs(r)); continue; end

                msgRaw = T.(msgCol)(r);
                if iscell(msgRaw); msgRaw = msgRaw{1}; end
                if isstring(msgRaw); msgRaw = char(msgRaw); end
                if isnumeric(msgRaw); msgRaw = num2str(msgRaw); end
                if ~ischar(msgRaw); msgRaw = char(string(msgRaw)); end

                meta = struct();
                for mi = 1:numel(metaIdx)
                    raw = T.(varNames{metaIdx(mi)})(r);
                    if iscell(raw); raw = raw{1}; end
                    if isstring(raw); raw = char(raw); end
                    if isnumeric(raw); raw = num2str(raw); end
                    if ~ischar(raw); raw = char(string(raw)); end
                    meta.(metaFieldNames{mi}) = raw;
                end

                e = PlantLogEntry(struct( ...
                    'Timestamp',  parsedTs(r), ...
                    'Message',    msgRaw, ...
                    'Metadata',   meta, ...
                    'SourceFile', filePath));
                if isempty(entries)
                    entries = e;
                else
                    entries(end+1) = e; %#ok<AGROW>
                end
            end
        end

        function mapping = autoDetect(rawTable)
            %AUTODETECT Score columns and return a suggested mapping struct.
            %
            %   mapping = PlantLogReader.autoDetect(rawTable) inspects the
            %   first 50 rows of each column, scores each as timestamp
            %   (parse ratio >= 0.9 wins) and message (text ratio >= 0.7
            %   wins, must NOT be the timestamp column). Returns:
            %
            %     mapping.TimestampColumn -- '' if none scores >= 0.9
            %     mapping.MessageColumn   -- '' if no non-ts text column found
            %     mapping.TimestampFormat -- '' (the ladder picks at parse time)

            if ~istable(rawTable)
                error('PlantLogReader:invalidInput', ...
                    'rawTable must be a table; got %s.', class(rawTable));
            end

            varNames = rawTable.Properties.VariableNames;
            nCols = numel(varNames);

            mapping = struct( ...
                'TimestampColumn', '', ...
                'MessageColumn',   '', ...
                'TimestampFormat', '');

            if nCols == 0 || height(rawTable) == 0
                return;
            end

            % Score every column as timestamp; pick the best >= 0.9
            tsRatios = zeros(1, nCols);
            for c = 1:nCols
                tsRatios(c) = scoreColumnAsTimestamp(rawTable.(varNames{c}));
            end
            [bestTs, bestTsIdx] = max(tsRatios);
            if bestTs >= 0.9
                mapping.TimestampColumn = varNames{bestTsIdx};
            else
                bestTsIdx = -1;  % no winner
            end

            % Score every non-timestamp column as message; first >= 0.7 wins
            for c = 1:nCols
                if c == bestTsIdx; continue; end
                if scoreColumnAsMessage(rawTable.(varNames{c})) >= 0.7
                    mapping.MessageColumn = varNames{c};
                    break;
                end
            end
        end

    end
end
