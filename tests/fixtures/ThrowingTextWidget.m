classdef ThrowingTextWidget < TextWidget
%THROWINGTEXTWIDGET Test fixture: a TextWidget whose refresh() throws.
%   Used by test_dashboard_switch_page_refresh to verify that
%   DashboardEngine.switchPage isolates per-widget refresh failures so
%   one broken widget does not prevent siblings on the same page from
%   painting.
%
%   See also test_dashboard_switch_page_refresh.

    methods
        function obj = ThrowingTextWidget(varargin)
            obj = obj@TextWidget(varargin{:});
        end

        function refresh(~)
            error('ThrowingTextWidget:boom', 'intentional refresh failure');
        end

        function t = getType(~)
            t = 'throwing-text';
        end
    end
end
