classdef TestDashboardBuilderInteraction < matlab.unittest.TestCase
%TESTDASHBOARDBUILDERINTERACTION Tests for drag, resize, and mouse-driven
%   interactions in DashboardBuilder edit mode.
%
%   These tests simulate the full mouse flow by triggering ButtonDownFcn
%   on overlay handles, setting figure CurrentPoint, and invoking the
%   figure's WindowButtonMotionFcn / WindowButtonUpFcn callbacks.

    properties
        Engine
        Builder
        hFig
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end

    methods (TestMethodSetup)
        function createDashboard(testCase)
            % Create a 2-widget dashboard in edit mode for each test
            testCase.Engine = DashboardEngine('Interaction Test');
            testCase.Engine.addWidget('kpi', 'Title', 'Widget A', ...
                'Position', [1 1 3 1], 'StaticValue', 10);
            testCase.Engine.addWidget('kpi', 'Title', 'Widget B', ...
                'Position', [7 1 3 1], 'StaticValue', 20);
            testCase.Engine.render();
            testCase.hFig = testCase.Engine.hFigure;
            set(testCase.hFig, 'Visible', 'off');

            testCase.Builder = DashboardBuilder(testCase.Engine);
            testCase.Builder.enterEditMode();

            testCase.addTeardown(@() testCase.cleanupDashboard());
        end
    end

    methods
        function cleanupDashboard(testCase)
            if ~isempty(testCase.hFig) && ishandle(testCase.hFig)
                close(testCase.hFig);
            end
        end
    end

    methods (Test)
        %% --- Drag Tests ---

        function testDragStartSelectsWidget(testCase)
            % Clicking the drag bar should select the widget
            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');

            % Set figure CurrentPoint to the drag bar location
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            set(testCase.hFig, 'CurrentPoint', ...
                [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01]);

            % Trigger drag start
            cb(ov.hDragBar, []);

            testCase.verifyEqual(testCase.Builder.SelectedIdx, 1, ...
                'Drag start should select the widget');
            testCase.verifyEqual(testCase.Builder.DragMode, 'drag');
            testCase.verifyEqual(testCase.Builder.DragIdx, 1);
        end

        function testDragMovesWidgetPosition(testCase)
            % Simulate a complete drag: start -> move -> release
            origPos = testCase.Engine.Widgets{1}.Position;

            % Compute step size (one grid cell in normalized coords)
            layout = testCase.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            cols = layout.Columns;
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            stepW = cellW + layout.GapH;

            % Start drag on widget 1
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Move 2 columns to the right
            endPt = [startPt(1) + 2 * stepW, startPt(2)];
            set(testCase.hFig, 'CurrentPoint', endPt);

            % Trigger mouse move (via figure callback)
            motionCb = get(testCase.hFig, 'WindowButtonMotionFcn');
            motionCb(testCase.hFig, []);

            % Release
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyEqual(newPos(1), origPos(1) + 2, ...
                'Widget should move 2 columns to the right');
            testCase.verifyEqual(newPos(3), origPos(3), ...
                'Widget width should not change during drag');
            testCase.verifyEqual(newPos(4), origPos(4), ...
                'Widget height should not change during drag');
        end

        function testDragClampsToLeftEdge(testCase)
            % Dragging far left should clamp column to 1
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Move far to the left (negative x)
            set(testCase.hFig, 'CurrentPoint', [startPt(1) - 0.9, startPt(2)]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyGreaterThanOrEqual(newPos(1), 1, ...
                'Column should be clamped to >= 1');
        end

        function testDragClampsToRightEdge(testCase)
            % Dragging far right should keep widget within 12 columns
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Move far to the right
            set(testCase.hFig, 'CurrentPoint', [startPt(1) + 0.9, startPt(2)]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyLessThanOrEqual(newPos(1) + newPos(3) - 1, 12, ...
                'Widget right edge should not exceed column 12');
        end

        function testDragClampsRowToMinOne(testCase)
            % Dragging upward should clamp row to 1
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Move far upward (large positive y in normalized coords)
            set(testCase.hFig, 'CurrentPoint', [startPt(1), startPt(2) + 0.9]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyGreaterThanOrEqual(newPos(2), 1, ...
                'Row should be clamped to >= 1');
        end

        function testDragResolvesOverlap(testCase)
            % Dragging widget A on top of widget B should resolve overlap
            origBPos = testCase.Engine.Widgets{2}.Position; % [7 1 3 1]

            % Compute step size
            layout = testCase.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            cols = layout.Columns;
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            stepW = cellW + layout.GapH;

            % Start drag on widget 1
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Move widget A to overlap with widget B (col 7)
            deltaCols = origBPos(1) - testCase.Engine.Widgets{1}.Position(1);
            set(testCase.hFig, 'CurrentPoint', ...
                [startPt(1) + deltaCols * stepW, startPt(2)]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newAPos = testCase.Engine.Widgets{1}.Position;

            % If A overlaps B's columns, it should be pushed to a different row
            if newAPos(1) <= origBPos(1) + origBPos(3) - 1 && ...
               newAPos(1) + newAPos(3) - 1 >= origBPos(1)
                % Columns overlap — rows must not overlap
                testCase.verifyGreaterThan(newAPos(2), ...
                    origBPos(2) + origBPos(4) - 1, ...
                    'Overlap should be resolved by pushing to next row');
            end
        end

        function testDragSnapsToGrid(testCase)
            % After drag, widget position should be integer grid values
            layout = testCase.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            cols = layout.Columns;
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            stepW = cellW + layout.GapH;

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Move by 1.7 columns (should snap to 2)
            set(testCase.hFig, 'CurrentPoint', ...
                [startPt(1) + 1.7 * stepW, startPt(2)]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyEqual(mod(newPos(1), 1), 0, ...
                'Column should be an integer after snap');
            testCase.verifyEqual(mod(newPos(2), 1), 0, ...
                'Row should be an integer after snap');
        end

        %% --- Resize Tests ---

        function testResizeStartSelectsWidget(testCase)
            ov = testCase.Builder.Overlays{2};
            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            set(testCase.hFig, 'CurrentPoint', ...
                [panelPos(1) + panelPos(3) - 0.005, panelPos(2) + 0.005]);

            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);

            testCase.verifyEqual(testCase.Builder.SelectedIdx, 2, ...
                'Resize start should select the widget');
            testCase.verifyEqual(testCase.Builder.DragMode, 'resize');
            testCase.verifyEqual(testCase.Builder.DragIdx, 2);
        end

        function testResizeChangesWidthHeight(testCase)
            origPos = testCase.Engine.Widgets{2}.Position;

            layout = testCase.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            totalH = ca(4) - layout.Padding(2) - layout.Padding(4);
            cols = layout.Columns;
            rows = max(layout.TotalRows, 1);
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            cellH = (totalH - (rows - 1) * layout.GapV) / rows;
            stepW = cellW + layout.GapH;
            stepH = cellH + layout.GapV;

            % Start resize on widget 2
            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            startPt = [panelPos(1) + panelPos(3) - 0.005, panelPos(2) + 0.005];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{2};
            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);

            % Resize: +2 columns wider, +1 row taller (drag right and down)
            endPt = [startPt(1) + 2 * stepW, startPt(2) - 1 * stepH];
            set(testCase.hFig, 'CurrentPoint', endPt);

            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{2}.Position;
            testCase.verifyEqual(newPos(3), origPos(3) + 2, ...
                'Width should increase by 2 columns');
            testCase.verifyEqual(newPos(4), origPos(4) + 1, ...
                'Height should increase by 1 row');
            testCase.verifyEqual(newPos(1), origPos(1), ...
                'Column origin should not change during resize');
            testCase.verifyEqual(newPos(2), origPos(2), ...
                'Row origin should not change during resize');
        end

        function testResizeClampsMinimum(testCase)
            % Shrinking a widget should not go below 1x1
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + panelPos(3) - 0.005, panelPos(2) + 0.005];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);

            % Shrink dramatically
            set(testCase.hFig, 'CurrentPoint', ...
                [startPt(1) - 0.9, startPt(2) + 0.9]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{1}.Position;
            testCase.verifyGreaterThanOrEqual(newPos(3), 1, ...
                'Width should be at least 1');
            testCase.verifyGreaterThanOrEqual(newPos(4), 1, ...
                'Height should be at least 1');
        end

        function testResizeClampsMaxWidth(testCase)
            % Resize should not push widget past column 12
            origPos = testCase.Engine.Widgets{2}.Position; % col 7, width 3

            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            startPt = [panelPos(1) + panelPos(3) - 0.005, panelPos(2) + 0.005];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{2};
            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);

            % Try to make very wide
            set(testCase.hFig, 'CurrentPoint', [startPt(1) + 0.9, startPt(2)]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            newPos = testCase.Engine.Widgets{2}.Position;
            testCase.verifyLessThanOrEqual(newPos(1) + newPos(3) - 1, 12, ...
                'Widget right edge should not exceed column 12');
        end

        %% --- Mouse Move Visual Feedback Tests ---

        function testMouseMoveDragUpdatesPanelPosition(testCase)
            % During drag, the panel should visually track the mouse
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            origPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');

            % Move mouse right by 0.1
            dx = 0.1;
            set(testCase.hFig, 'CurrentPoint', [startPt(1) + dx, startPt(2)]);
            motionCb = get(testCase.hFig, 'WindowButtonMotionFcn');
            motionCb(testCase.hFig, []);

            newPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            testCase.verifyEqual(newPanelPos(1), origPanelPos(1) + dx, ...
                'AbsTol', 1e-6, ...
                'Panel X should move by dx during drag');
            testCase.verifyEqual(newPanelPos(3), origPanelPos(3), ...
                'AbsTol', 1e-6, ...
                'Panel width should not change during drag move');
        end

        function testMouseMoveResizeUpdatesSize(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + panelPos(3) - 0.005, panelPos(2) + 0.005];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);

            origPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');

            % Move resize handle right by 0.05
            dx = 0.05;
            set(testCase.hFig, 'CurrentPoint', [startPt(1) + dx, startPt(2)]);
            motionCb = get(testCase.hFig, 'WindowButtonMotionFcn');
            motionCb(testCase.hFig, []);

            newPanelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            testCase.verifyGreaterThan(newPanelPos(3), origPanelPos(3), ...
                'Panel width should increase during resize-right');
            testCase.verifyEqual(newPanelPos(1), origPanelPos(1), ...
                'AbsTol', 1e-6, ...
                'Panel X should stay fixed during resize');
        end

        function testMouseMoveWithNoDragIsNoop(testCase)
            % Moving mouse without an active drag should do nothing
            origPos = testCase.Engine.Widgets{1}.Position;

            set(testCase.hFig, 'CurrentPoint', [0.5, 0.5]);
            motionCb = get(testCase.hFig, 'WindowButtonMotionFcn');
            motionCb(testCase.hFig, []);

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos, ...
                'Position should not change when no drag is active');
        end

        function testMouseUpWithNoDragIsNoop(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;

            set(testCase.hFig, 'CurrentPoint', [0.5, 0.5]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos, ...
                'Position should not change on mouse up without drag');
        end

        %% --- Overlay Drag Bar Label Tests ---

        function testDragBarShowsWidgetTitle(testCase)
            ov = testCase.Builder.Overlays{1};
            label = get(ov.hDragLabel, 'String');
            testCase.verifyEqual(label, 'Widget A', ...
                'Drag bar label should show widget title');

            ov2 = testCase.Builder.Overlays{2};
            label2 = get(ov2.hDragLabel, 'String');
            testCase.verifyEqual(label2, 'Widget B');
        end

        function testOverlayDeleteButtonRemovesWidget(testCase)
            testCase.verifyEqual(numel(testCase.Engine.Widgets), 2);

            % Click the X button on widget 1's overlay
            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDeleteBtn, 'Callback');
            cb(ov.hDeleteBtn, []);

            testCase.verifyEqual(numel(testCase.Engine.Widgets), 1, ...
                'Delete button should remove the widget');
            testCase.verifyEqual(testCase.Engine.Widgets{1}.Title, 'Widget B', ...
                'Widget B should remain');
        end

        %% --- Drag Label ButtonDown propagation ---

        function testDragLabelClickStartsDrag(testCase)
            % Clicking the label inside the drag bar should also start drag
            ov = testCase.Builder.Overlays{2};
            panelPos = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            set(testCase.hFig, 'CurrentPoint', ...
                [panelPos(1) + 0.02, panelPos(2) + panelPos(4) - 0.01]);

            cb = get(ov.hDragLabel, 'ButtonDownFcn');
            cb(ov.hDragLabel, []);

            testCase.verifyEqual(testCase.Builder.DragMode, 'drag');
            testCase.verifyEqual(testCase.Builder.DragIdx, 2);
            testCase.verifyEqual(testCase.Builder.SelectedIdx, 2);
        end

        %% --- State cleanup after drag ---

        function testDragStateResetAfterMouseUp(testCase)
            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            testCase.verifyEqual(testCase.Builder.DragMode, 'drag');

            % Release
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            testCase.verifyEqual(testCase.Builder.DragMode, '', ...
                'DragMode should be cleared after mouse up');
            testCase.verifyEqual(testCase.Builder.DragIdx, 0, ...
                'DragIdx should be cleared after mouse up');
        end

        %% --- Palette button callbacks ---

        function testPaletteButtonsAddWidgets(testCase)
            % Find all pushbuttons in the palette
            btns = findobj(testCase.Builder.hPalette, 'Style', 'pushbutton');
            testCase.verifyGreaterThanOrEqual(numel(btns), 8, ...
                'Palette should have at least 8 widget type buttons');

            initialCount = numel(testCase.Engine.Widgets);

            % Click the first palette button (should add a widget)
            cb = get(btns(end), 'Callback');  % btns are in reverse order
            cb(btns(end), []);

            testCase.verifyEqual(numel(testCase.Engine.Widgets), initialCount + 1, ...
                'Clicking palette button should add a widget');
        end

        %% --- Properties panel Apply/Delete button callbacks ---

        function testApplyButtonCallback(testCase)
            testCase.Builder.selectWidget(1);
            set(testCase.Builder.hPropTitle, 'String', 'Changed');
            set(testCase.Builder.hPropCol, 'String', '1');
            set(testCase.Builder.hPropRow, 'String', '1');
            set(testCase.Builder.hPropWidth, 'String', '3');
            set(testCase.Builder.hPropHeight, 'String', '1');

            % Click the Apply button
            cb = get(testCase.Builder.hPropApply, 'Callback');
            cb(testCase.Builder.hPropApply, []);

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Title, 'Changed');
        end

        function testDeleteButtonCallback(testCase)
            testCase.Builder.selectWidget(1);
            initialCount = numel(testCase.Engine.Widgets);

            % Click the Delete button
            cb = get(testCase.Builder.hPropDelete, 'Callback');
            cb(testCase.Builder.hPropDelete, []);

            testCase.verifyEqual(numel(testCase.Engine.Widgets), initialCount - 1);
        end

        %% --- Edge cases ---

        function testDragWidgetZeroMovement(testCase)
            % Start and release at same point — position unchanged
            origPos = testCase.Engine.Widgets{1}.Position;

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + 0.01, panelPos(2) + panelPos(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hDragBar, 'ButtonDownFcn');
            cb(ov.hDragBar, []);

            % Release at same point
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos, ...
                'Zero-movement drag should not change position');
        end

        function testResizeWidgetZeroMovement(testCase)
            origPos = testCase.Engine.Widgets{1}.Position;

            panelPos = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos(1) + panelPos(3) - 0.005, panelPos(2) + 0.005];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov = testCase.Builder.Overlays{1};
            cb = get(ov.hResize, 'ButtonDownFcn');
            cb(ov.hResize, []);

            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            testCase.verifyEqual(testCase.Engine.Widgets{1}.Position, origPos, ...
                'Zero-movement resize should not change position');
        end

        function testMultipleSequentialDrags(testCase)
            % Drag widget 1, then drag widget 2 — both should succeed
            layout = testCase.Engine.Layout;
            ca = layout.ContentArea;
            totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
            cols = layout.Columns;
            cellW = (totalW - (cols - 1) * layout.GapH) / cols;
            stepW = cellW + layout.GapH;

            % Drag widget 1 right by 1 col
            panelPos1 = get(testCase.Engine.Widgets{1}.hPanel, 'Position');
            startPt = [panelPos1(1) + 0.01, panelPos1(2) + panelPos1(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt);

            ov1 = testCase.Builder.Overlays{1};
            cb1 = get(ov1.hDragBar, 'ButtonDownFcn');
            cb1(ov1.hDragBar, []);

            set(testCase.hFig, 'CurrentPoint', [startPt(1) + stepW, startPt(2)]);
            upCb = get(testCase.hFig, 'WindowButtonUpFcn');
            upCb(testCase.hFig, []);

            pos1After = testCase.Engine.Widgets{1}.Position;

            % Now drag widget 2 left by 1 col
            % Need to get updated overlays after rebuild
            panelPos2 = get(testCase.Engine.Widgets{2}.hPanel, 'Position');
            startPt2 = [panelPos2(1) + 0.01, panelPos2(2) + panelPos2(4) - 0.01];
            set(testCase.hFig, 'CurrentPoint', startPt2);

            ov2 = testCase.Builder.Overlays{2};
            cb2 = get(ov2.hDragBar, 'ButtonDownFcn');
            cb2(ov2.hDragBar, []);

            set(testCase.hFig, 'CurrentPoint', [startPt2(1) - stepW, startPt2(2)]);
            upCb(testCase.hFig, []);

            pos2After = testCase.Engine.Widgets{2}.Position;

            % Both drags should have taken effect
            testCase.verifyEqual(pos1After(1), 2, ...
                'Widget 1 should have moved right by 1');
            testCase.verifyNotEqual(pos2After, [7 1 3 1], ...
                'Widget 2 should have moved');
        end
    end
end
