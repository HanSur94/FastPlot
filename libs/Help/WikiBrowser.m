classdef WikiBrowser < handle
%WIKIBROWSER Non-modal project-wide in-app wiki/help browser (Phase 1034).
%
%   Opens a uifigure with a sidebar TOC + search (left), rendered HTML
%   (uihtml center), and a breadcrumb / back / forward strip (top).
%   Reads markdown from the project's wiki/ directory via the static
%   helper WikiPageIndex, renders pages through MarkdownRenderer.render,
%   and intercepts cross-doc links to navigate within the window. External
%   http(s):// and mailto: links keep the default uihtml behaviour and
%   open in the system browser. Octave / headless MATLAB / batch sessions
%   skip the uifigure entirely and hand off the rendered HTML to the OS
%   browser, mirroring DashboardEngine.writeAndOpenInfoHtml.
%
%   This is System 2 of the unified in-app help system (CONTEXT.md D-02).
%   System 1 — DashboardEngine.InfoFile + DashboardWidget.Description —
%   stays frozen (D-01); the two systems share NO code beyond the
%   MarkdownRenderer.
%
%   Construction (NV-pair API consumed by Plans 06 / 07):
%       wb = WikiBrowser(...
%           'OpenTo',          'Tag-Status-Table', ...   % page name, no .md (default 'Home')
%           'Theme',           'dark',           ...   % 'dark' | 'light' (default 'dark')
%           'WikiDir',         '/abs/path/wiki', ...   % default <repo>/wiki
%           'ParentForAlerts', companionUifigure);     % for uialert (default [])
%
%   Public API:
%       wb.navigateTo(pageName)    — switch center pane, push history
%       wb.back()                  — step back in history (no-op at start)
%       wb.forward()               — step forward (no-op at end)
%       wb.applyTheme(themeName)   — re-render current page with new theme
%       wb.search(query)           — returns WikiPageIndex.search hits
%       wb.focus()                 — bring the uifigure to front
%       wb.close()                 — delete uifigure, clear cache
%       wb.IsOpen                  — logical (SetAccess=private)
%       wb.CurrentPage / Theme / WikiDir   — SetAccess=private state
%
%   History stack capped at 50 entries (CONTEXT.md D-11). Navigating
%   from a middle index truncates the forward portion (standard browser
%   semantics). The rendered-HTML cache is a containers.Map keyed by
%   'pageName|theme'; cleared on close() and on applyTheme().
%
%   Octave / headless fallback: writes the rendered HTML to a temp file
%   and shells out (open / xdg-open / cmd /c start). No multi-page nav
%   in this mode; one tab per click. IsOpen stays false.
%
%   The uifigure root carries Tag='WikiBrowserRoot' so the Companion's
%   theme walker (Phase 1034 Plan 08) can skip it the same way it skips
%   detached log panes — the wiki browser owns its own theming via the
%   re-render path in applyTheme.
%
%   See also WikiPageIndex, MarkdownRenderer, DashboardEngine, FastSenseCompanion.

    properties (SetAccess = private)
        IsOpen      logical = false
        CurrentPage         = ''
        Theme               = 'dark'
        WikiDir             = ''
    end

    properties (Access = private)
        hFig_           = []      % uifigure
        hRootGrid_      = []      % [2 1] grid: row 1 = breadcrumb strip, row 2 = body grid
        hCrumbGrid_     = []
        hBackBtn_       = []
        hFwdBtn_        = []
        hCrumbLbl_      = []
        hBodyGrid_      = []      % [1 2] grid: sidebar | content
        hSidebarPanel_  = []
        hSearchEdit_    = []
        hTreeHostGrid_  = []      % uigridlayout(treeHost) — children auto-resize
        hTocTree_       = []      % uitree (grouped) — direct child of hTreeHostGrid_
        hSearchResult_  = []      % uilistbox (Visible toggled) — direct child of hTreeHostGrid_
        hContent_       = []      % uihtml
        HistoryStack_   = {}      % cellstr of pageNames
        HistoryIdx_     = 0       % 1-based; 0 == empty
        HistoryCap_     = 50      % CONTEXT.md D-11
        Cache_          = []      % containers.Map keyed 'pageName|theme' -> HTML
        ParentForAlerts_ = []
        TempFile_       = ''      % Octave/headless reuse
        Listeners_      = {}      % addlistener handles (for theme change wiring etc.)
    end

    methods (Access = public)
        function obj = WikiBrowser(varargin)
        %WIKIBROWSER Construct the browser; opens the uifigure on MATLAB desktop
        %   or shells out to the OS browser on Octave / headless MATLAB.

            % Step 1 — parse NV-pairs.
            opts = struct( ...
                'OpenTo',          'Home', ...
                'Theme',           'dark', ...
                'WikiDir',         '', ...
                'ParentForAlerts', []);
            validKeys = fieldnames(opts);
            if mod(numel(varargin), 2) ~= 0
                error('WikiBrowser:invalidArgs', ...
                    'WikiBrowser requires name-value pairs. Valid keys: %s.', ...
                    strjoin(validKeys, ', '));
            end
            for ai = 1:2:numel(varargin)
                key = varargin{ai};
                val = varargin{ai+1};
                if ~ischar(key)
                    error('WikiBrowser:invalidArgs', ...
                        'Option name must be a char. Valid keys: %s.', ...
                        strjoin(validKeys, ', '));
                end
                if ~isfield(opts, key)
                    error('WikiBrowser:unknownOption', ...
                        'Unknown WikiBrowser option ''%s''. Valid keys: %s.', ...
                        key, strjoin(validKeys, ', '));
                end
                opts.(key) = val;
            end

            % Step 2 — resolve WikiDir default and stash on the object.
            if isempty(opts.WikiDir)
                here = fileparts(mfilename('fullpath'));            % .../libs/Help
                candidate = fullfile(here, '..', '..', 'wiki');     % <repo>/wiki
                if isfolder(candidate)
                    opts.WikiDir = candidate;
                elseif isfolder(fullfile(pwd, 'wiki'))
                    opts.WikiDir = fullfile(pwd, 'wiki');
                else
                    % Store the canonical candidate anyway — readPage will
                    % surface a clear 'page not found' notice on first call.
                    opts.WikiDir = candidate;
                end
            end
            obj.WikiDir          = opts.WikiDir;
            obj.Theme            = opts.Theme;
            obj.ParentForAlerts_ = opts.ParentForAlerts;
            obj.Cache_           = containers.Map( ...
                'KeyType', 'char', 'ValueType', 'char');

            % Step 3 — headless / Octave branch.
            if ~obj.isInteractiveDesktop_()
                obj.openInBrowser_(opts.OpenTo);
                obj.IsOpen = false;
                return;
            end

            % Step 4 — interactive MATLAB desktop branch.
            obj.buildFigure_();
            obj.navigateTo(opts.OpenTo);
            obj.IsOpen = true;
        end

        function navigateTo(obj, pageName)  %#ok<INUSD>
            % implementation: Task 4.3
        end

        function back(obj)  %#ok<MANU>
            % implementation: Task 4.3
        end

        function forward(obj)  %#ok<MANU>
            % implementation: Task 4.3
        end

        function applyTheme(obj, themeName)  %#ok<INUSD>
            % implementation: Task 4.3
        end

        function hits = search(obj, query)
        %SEARCH Forward to WikiPageIndex.search; usable headless.
            hits = WikiPageIndex.search(obj.WikiDir, query);
        end

        function focus(obj)  %#ok<MANU>
            % implementation: Task 4.4
        end

        function close(obj)  %#ok<MANU>
            % implementation: Task 4.4
        end

        function delete(~)
            % implementation: Task 4.4
        end
    end

    methods (Access = private)
        function tf = isInteractiveDesktop_(~)
        %ISINTERACTIVEDESKTOP_ True iff a uifigure can be safely created.
        %   Mirrors the gate in DashboardEngine.writeAndOpenInfoHtml
        %   (libs/Dashboard/DashboardEngine.m §927-948): excludes Octave,
        %   non-Java MATLAB, and -batch sessions.
            if exist('OCTAVE_VERSION', 'builtin') ~= 0
                tf = false;
                return;
            end
            tf = usejava('desktop');
            if tf && exist('batchStartupOptionUsed', 'builtin') && ...
                    batchStartupOptionUsed()
                tf = false;
            end
        end

        function openInBrowser_(obj, pageName)
        %OPENINBROWSER_ Octave / headless fallback: render + write + shell-out.
        %   Single page per click — no nav, no history. Mirrors the
        %   DashboardEngine.writeAndOpenInfoHtml shell-out idiom.
            [mdText, ~, found] = WikiPageIndex.readPage(obj.WikiDir, pageName);
            if ~found
                fprintf(2, ...
                    '[WikiBrowser] page not found and Home.md missing: %s\n', ...
                    pageName);
                return;
            end
            html = MarkdownRenderer.render(mdText, obj.Theme, obj.WikiDir);
            if isempty(obj.TempFile_)
                obj.TempFile_ = [tempname '.html'];
            end
            fid = fopen(obj.TempFile_, 'w');
            if fid == -1
                fprintf(2, ...
                    '[WikiBrowser] cannot write temp file: %s\n', ...
                    obj.TempFile_);
                return;
            end
            fwrite(fid, html);
            fclose(fid);

            % Only shell out when we have a desktop session that can host
            % a browser. Pure -batch CI runs need the temp file on disk
            % (which is the contract the System 1 TestDashboardInfo test
            % suite mirrors) — no shell-out there.
            if exist('OCTAVE_VERSION', 'builtin') ~= 0 || ~usejava('desktop')
                if ismac
                    system(['open "' obj.TempFile_ '"']);
                elseif ispc
                    system(['cmd /c start "" "' obj.TempFile_ '"']);
                else
                    system(['xdg-open "' obj.TempFile_ '"']);
                end
            end
        end

        function buildFigure_(obj)  %#ok<MANU>
            % implementation: Task 4.2
        end
    end
end
