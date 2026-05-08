classdef LogPane < handle
%LOGPANE Detachable log strip for FastSenseCompanion (events log + live-updates log).
%
%   Self-contained handle class that owns the FastSense Companion's log strip:
%   events table, live-updates table, header controls (search, level filter,
%   updated-time label, pop-out icon), and the underlying buffers. The pane
%   can be attached to either a uipanel (inline, embedded in the companion)
%   or directly to a uifigure (detached, in its own window). Buffers persist
%   across attach/detach round-trips so re-attaching restores full history.
%
%   The pane is independent of FastSenseCompanion. The companion instantiates
%   it, listens to the DetachRequested event, and forwards log entries via
%   addLogEntry / addLiveLogEntry. Pipeline state (per-tag last-seen sample
%   counter map) does NOT live here — that is FastSenseCompanion's
%   responsibility (see Phase 1027 CONTEXT.md "Live-pipeline integration
%   boundary").
%
%   Usage (called by FastSenseCompanion):
%     pane = LogPane(theme);
%     pane.attach(parent, theme);   % parent: uipanel or uifigure
%     pane.addLogEntry('info', 'msg');
%     pane.addLiveLogEntry('tag.a', 5, 1.234);
%     pane.detach();                % UI handles released; buffers preserved
%
%   Events fired:
%     DetachRequested — fired when the user clicks the inline pop-out icon.
%                       Carries no payload; listener reads pane state if
%                       needed.
%
%   See also FastSenseCompanion, TagCatalogPane, CompanionTheme.

    events
        DetachRequested  % fired when user clicks the inline pop-out icon
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_     = []          % resolved CompanionTheme struct
        hRoot_           = []          % outer uigridlayout (the [4 1] grid)
        hLogTable_       = []          % uitable for events log
        hLogSearch_      = []          % uieditfield (search)
        hLogLevelDD_     = []          % uidropdown level filter
        hLastUpdateLbl_  = []          % "Updated: HH:MM:SS" label
        hPopoutBtn_      = []          % pop-out icon uibutton in header col 5
        hLiveLogTable_   = []          % uitable for live updates log
        LogBuffer_       = cell(0, 3)  % {Time, Level, Message} newest first, capped 500
        LiveLogBuffer_   = cell(0, 4)  % {Time, Tag, +Samples, Latest} newest first, capped 500
    end

    methods (Access = public)

        function obj = LogPane(themeStruct)
        %LOGPANE Construct a LogPane with an initial theme. UI is NOT built — call attach().
            % TODO Task 2
        end

        function attach(obj, parent, themeStruct)
        %ATTACH Build the log-strip UI inside parent (uipanel or uifigure).
            % TODO Task 2
        end

        function detach(obj)
        %DETACH Destroy UI handles. LogBuffer_ + LiveLogBuffer_ preserved.
            % TODO Task 2
        end

        function addLogEntry(obj, level, msg)
        %ADDLOGENTRY Append a timestamped log line. Buffers always; renders if attached.
            % TODO Task 3
        end

        function addLiveLogEntry(obj, tagKey, deltaSamples, latestY)
        %ADDLIVELOGENTRY Push a row into the live-updates log; cap at 500.
            % TODO Task 3
        end

        function clearLiveLog(obj)
        %CLEARLIVELOG Wipe the live-updates buffer + table.
            % TODO Task 3
        end

        function setLastUpdated(obj, dt)
        %SETLASTUPDATED Update the 'Updated: HH:MM:SS' label.
            % TODO Task 3
        end

        function applyTheme(obj, themeStruct)
        %APPLYTHEME Live theme switch — restyle existing UI without rebuilding handles.
            % TODO Task 4
        end

        function delete(obj)
        %DELETE Handle class destructor — calls detach() for safety.
            % TODO Task 2
        end

    end

    methods (Access = private)

        function applyLogFilter_(obj)
        %APPLYLOGFILTER_ Re-apply level + text filter to LogBuffer_ then render.
            % TODO Task 3
        end

        function renderLiveTable_(obj)
        %RENDERLIVETABLE_ Push LiveLogBuffer_ into hLiveLogTable_.Data.
            % TODO Task 3
        end

        function styleTables_(obj)
        %STYLETABLES_ Pick striped uitable BackgroundColor pair from theme darkness.
            % TODO Task 4 (helper) — currently inlined into attach() and applyTheme().
        end

    end
end
