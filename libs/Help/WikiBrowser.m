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

        function buildFigure_(obj)
        %BUILDFIGURE_ Construct the non-modal three-pane uifigure.
        %   Called from the constructor's interactive-desktop branch
        %   only. Lays out: row 1 = [< back | fwd > | breadcrumb] in a
        %   32-px strip, row 2 = [sidebar 260 px | content 1x] body
        %   grid. The sidebar holds a search uieditfield on top and a
        %   uitree (TOC) under it, with the search-results uilistbox
        %   layered into the same uigridlayout cell so non-empty queries
        %   swap visibility without reshuffling positions.
        %
        %   Plan-checker I4 — Option A: TOC tree + search-results
        %   listbox are direct children of a uigridlayout, NOT of a
        %   plain uipanel. Children of uigridlayout auto-fill the cell
        %   and ignore .Position, so resizing the figure reflows the
        %   tree / listbox correctly. The plain-uipanel approach would
        %   leave the children stuck at their initial Position size.
            t = CompanionTheme.get(obj.Theme);

            obj.hFig_ = uifigure( ...
                'Name',               ['Wiki ' char(8212) ' FastSense'], ...
                'Position',           [100 100 1100 750], ...
                'WindowStyle',        'normal', ...
                'Color',              t.DashboardBackground, ...
                'AutoResizeChildren', 'off', ...
                'Visible',            'off', ...
                'Tag',                'WikiBrowserRoot');
            obj.hFig_.CloseRequestFcn = @(~, ~) obj.close();

            % Root layout: row 1 = breadcrumb strip (32 px), row 2 = body (1x).
            obj.hRootGrid_ = uigridlayout(obj.hFig_, [2 1]);
            obj.hRootGrid_.RowHeight     = {32, '1x'};
            obj.hRootGrid_.ColumnWidth   = {'1x'};
            obj.hRootGrid_.Padding       = [8 6 8 6];
            obj.hRootGrid_.RowSpacing    = 6;
            obj.hRootGrid_.BackgroundColor = t.DashboardBackground;

            % Breadcrumb strip: [< back | fwd > | crumb label (1x)].
            obj.hCrumbGrid_ = uigridlayout(obj.hRootGrid_, [1 3]);
            obj.hCrumbGrid_.Layout.Row     = 1;
            obj.hCrumbGrid_.Layout.Column  = 1;
            obj.hCrumbGrid_.ColumnWidth    = {32, 32, '1x'};
            obj.hCrumbGrid_.RowHeight      = {'1x'};
            obj.hCrumbGrid_.Padding        = [0 0 0 0];
            obj.hCrumbGrid_.ColumnSpacing  = 4;
            obj.hCrumbGrid_.BackgroundColor = t.DashboardBackground;

            obj.hBackBtn_ = uibutton(obj.hCrumbGrid_, 'push');
            obj.hBackBtn_.Layout.Row    = 1;
            obj.hBackBtn_.Layout.Column = 1;
            obj.hBackBtn_.Text          = char(8592);   % left arrow
            obj.hBackBtn_.Tooltip       = 'Back';
            obj.hBackBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hBackBtn_.FontColor       = t.ForegroundColor;
            obj.hBackBtn_.Enable          = 'off';   % nothing in history yet
            obj.hBackBtn_.ButtonPushedFcn = @(~, ~) obj.back();

            obj.hFwdBtn_ = uibutton(obj.hCrumbGrid_, 'push');
            obj.hFwdBtn_.Layout.Row    = 1;
            obj.hFwdBtn_.Layout.Column = 2;
            obj.hFwdBtn_.Text          = char(8594);   % right arrow
            obj.hFwdBtn_.Tooltip       = 'Forward';
            obj.hFwdBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hFwdBtn_.FontColor       = t.ForegroundColor;
            obj.hFwdBtn_.Enable          = 'off';
            obj.hFwdBtn_.ButtonPushedFcn = @(~, ~) obj.forward();

            obj.hCrumbLbl_ = uilabel(obj.hCrumbGrid_);
            obj.hCrumbLbl_.Layout.Row    = 1;
            obj.hCrumbLbl_.Layout.Column = 3;
            obj.hCrumbLbl_.Text          = '';
            obj.hCrumbLbl_.FontWeight    = 'bold';
            obj.hCrumbLbl_.FontSize      = 12;
            obj.hCrumbLbl_.FontColor     = t.ForegroundColor;
            obj.hCrumbLbl_.HorizontalAlignment = 'left';
            obj.hCrumbLbl_.VerticalAlignment   = 'center';

            % Body row: [sidebar 260 px | content 1x].
            obj.hBodyGrid_ = uigridlayout(obj.hRootGrid_, [1 2]);
            obj.hBodyGrid_.Layout.Row     = 2;
            obj.hBodyGrid_.Layout.Column  = 1;
            obj.hBodyGrid_.ColumnWidth    = {260, '1x'};
            obj.hBodyGrid_.RowHeight      = {'1x'};
            obj.hBodyGrid_.Padding        = [0 0 0 0];
            obj.hBodyGrid_.ColumnSpacing  = 8;
            obj.hBodyGrid_.BackgroundColor = t.DashboardBackground;

            % Sidebar panel hosts the search edit on top and the TOC /
            % search-results stack below.
            obj.hSidebarPanel_ = uipanel(obj.hBodyGrid_);
            obj.hSidebarPanel_.Layout.Row    = 1;
            obj.hSidebarPanel_.Layout.Column = 1;
            obj.hSidebarPanel_.BackgroundColor = t.WidgetBackground;
            obj.hSidebarPanel_.BorderType      = 'line';
            try
                obj.hSidebarPanel_.BorderColor = t.WidgetBorderColor;
            catch
                % Older releases may not expose BorderColor on uipanel.
            end

            sidebarGrid = uigridlayout(obj.hSidebarPanel_, [2 1]);
            sidebarGrid.RowHeight       = {32, '1x'};
            sidebarGrid.ColumnWidth     = {'1x'};
            sidebarGrid.Padding         = [6 6 6 6];
            sidebarGrid.RowSpacing      = 4;
            sidebarGrid.BackgroundColor = t.WidgetBackground;

            obj.hSearchEdit_ = uieditfield(sidebarGrid, 'text');
            obj.hSearchEdit_.Layout.Row    = 1;
            obj.hSearchEdit_.Layout.Column = 1;
            try
                obj.hSearchEdit_.Placeholder = ['Search wiki' char(8230)];
            catch
                % R2020b lacks the Placeholder property — tolerate.
            end
            obj.hSearchEdit_.FontSize        = 11;
            obj.hSearchEdit_.BackgroundColor = t.WidgetBackground;
            obj.hSearchEdit_.FontColor       = t.ForegroundColor;
            obj.hSearchEdit_.ValueChangedFcn = @(s, e) obj.onSearchChanged_(s, e);

            % ---- TOC + search-results stack (plan-checker I4 Option A) ----
            % Both children sit in the same row/column of hTreeHostGrid_
            % and are swapped via Visible='on'/'off'. Because they're
            % uigridlayout children, .Position is ignored — they fill
            % the cell, so figure resize reflows them cleanly.
            obj.hTreeHostGrid_ = uigridlayout(sidebarGrid, [1 1]);
            obj.hTreeHostGrid_.Layout.Row     = 2;
            obj.hTreeHostGrid_.Layout.Column  = 1;
            obj.hTreeHostGrid_.Padding        = [4 4 4 4];
            obj.hTreeHostGrid_.RowHeight      = {'1x'};
            obj.hTreeHostGrid_.ColumnWidth    = {'1x'};
            obj.hTreeHostGrid_.BackgroundColor = t.WidgetBackground;

            obj.hTocTree_ = uitree(obj.hTreeHostGrid_);
            obj.hTocTree_.Layout.Row    = 1;
            obj.hTocTree_.Layout.Column = 1;
            obj.hTocTree_.FontColor       = t.ForegroundColor;
            obj.hTocTree_.BackgroundColor = t.WidgetBackground;
            obj.hTocTree_.SelectionChangedFcn = @(s, e) obj.onTocSelected_(s, e);

            obj.hSearchResult_ = uilistbox(obj.hTreeHostGrid_);
            obj.hSearchResult_.Layout.Row    = 1;
            obj.hSearchResult_.Layout.Column = 1;
            obj.hSearchResult_.Items         = {};
            obj.hSearchResult_.FontColor       = t.ForegroundColor;
            obj.hSearchResult_.BackgroundColor = t.WidgetBackground;
            obj.hSearchResult_.Visible       = 'off';
            obj.hSearchResult_.ValueChangedFcn = @(s, e) obj.onSearchHitSelected_(s, e);

            obj.buildTocTree_();

            % Content uihtml.
            obj.hContent_ = uihtml(obj.hBodyGrid_);
            obj.hContent_.Layout.Row    = 1;
            obj.hContent_.Layout.Column = 2;
            obj.hContent_.HTMLSource    = ['<html><body style="font-family: sans-serif; padding: 20px;">' ...
                '<p>Loading' char(8230) '</p></body></html>'];
            % HTMLEventReceivedFcn: when the rendered HTML posts back data
            % via htmlComponent.Data (the JS bridge injected by Task 4.3's
            % rewriteCrossDocLinks_), treat it as a navigateTo request.
            % External http(s):// and mailto: links remain un-rewritten
            % and the default uihtml behaviour opens them in the system
            % browser (CONTEXT.md D-10). Older MATLAB releases that lack
            % HTMLEventReceivedFcn lose in-window navigation gracefully —
            % all <a href> clicks open in the OS browser instead.
            try
                obj.hContent_.HTMLEventReceivedFcn = @(s, e) obj.onHtmlEvent_(s, e);
            catch
                % Best effort — silently fall back.
            end

            movegui(obj.hFig_, 'center');
            obj.hFig_.Visible = 'on';
        end

        function buildTocTree_(obj)
        %BUILDTOCTREE_ Wipe and rebuild children of hTocTree_ from
        %   WikiPageIndex.buildToc. Cheaper to rebuild than to mutate
        %   individual nodes; called from buildFigure_ and reused by
        %   future Companion-driven refresh paths.
            if isempty(obj.hTocTree_) || ~isvalid(obj.hTocTree_)
                return;
            end
            delete(obj.hTocTree_.Children);
            toc = WikiPageIndex.buildToc(obj.WikiDir);
            for gi = 1:numel(toc)
                groupNode = uitreenode(obj.hTocTree_);
                groupNode.Text = toc(gi).group;
                entries = toc(gi).entries;
                for ei = 1:numel(entries)
                    leaf = uitreenode(groupNode);
                    leaf.Text     = entries(ei).title;
                    leaf.NodeData = entries(ei).pageName;
                end
            end
            expand(obj.hTocTree_);
        end

        function onTocSelected_(obj, src, ~)
        %ONTOCSELECTED_ uitree SelectionChangedFcn — leaf-node click navigates.
            try
                sel = src.SelectedNodes;
                if isempty(sel) || isempty(sel.NodeData)
                    return;
                end
                obj.navigateTo(sel.NodeData);
            catch err
                obj.alert_(sprintf('TOC navigation failed: %s', err.message));
            end
        end

        function onSearchChanged_(obj, ~, ~)
        %ONSEARCHCHANGED_ Search-field ValueChangedFcn — show / hide results.
        %   Empty query restores the TOC tree; non-empty query runs
        %   WikiPageIndex.search and populates the listbox.
            try
                q = strtrim(obj.hSearchEdit_.Value);
                if isempty(q)
                    obj.hSearchResult_.Visible = 'off';
                    obj.hTocTree_.Visible      = 'on';
                    return;
                end
                hits = WikiPageIndex.search(obj.WikiDir, q);
                if isempty(hits)
                    obj.hSearchResult_.Items     = {'(no matches)'};
                    obj.hSearchResult_.ItemsData = {''};
                else
                    items = arrayfun(@(h) sprintf('%s %s %s', ...
                        h.title, char(8212), h.excerpt), hits, ...
                        'UniformOutput', false);
                    data  = arrayfun(@(h) {h.pageName}, hits);
                    obj.hSearchResult_.Items     = items;
                    obj.hSearchResult_.ItemsData = data;
                end
                obj.hSearchResult_.Visible = 'on';
                obj.hTocTree_.Visible      = 'off';
            catch err
                obj.alert_(sprintf('Search failed: %s', err.message));
            end
        end

        function onSearchHitSelected_(obj, src, ~)
        %ONSEARCHHITSELECTED_ uilistbox ValueChangedFcn — pick a result.
            try
                page = src.Value;
                if isempty(page) || ~ischar(page)
                    return;
                end
                obj.navigateTo(page);
            catch err
                obj.alert_(sprintf('Hit selection failed: %s', err.message));
            end
        end

        function onHtmlEvent_(obj, ~, evt)
        %ONHTMLEVENT_ uihtml HTMLEventReceivedFcn — bridge from JS.
        %   The JS bridge injected by rewriteCrossDocLinks_ (Task 4.3)
        %   intercepts clicks on a.wiki-internal and posts
        %   {page, ts} to htmlComponent.Data. evt.Data carries that
        %   struct; we forward to navigateTo. External http(s):// and
        %   mailto: links are NOT rewritten — they keep the default
        %   uihtml behaviour and open in the system browser
        %   (CONTEXT.md D-10).
            try
                if isstruct(evt.Data) && isfield(evt.Data, 'page')
                    obj.navigateTo(evt.Data.page);
                end
            catch
                % Best effort — silently ignore malformed payloads.
            end
        end

        function alert_(obj, msg)
        %ALERT_ Non-blocking error surface. Prefers uialert on the
        %   ParentForAlerts_ uifigure when available; otherwise writes
        %   to stderr with a [WikiBrowser] prefix.
            if ~isempty(obj.ParentForAlerts_) && isvalid(obj.ParentForAlerts_)
                try
                    uialert(obj.ParentForAlerts_, msg, 'Wiki Browser');
                    return;
                catch
                    % Fall through to stderr.
                end
            end
            fprintf(2, '[WikiBrowser] %s\n', msg);
        end
    end
end
