function updateDashboard(fig, d)
%UPDATEDASHBOARD Live mode callback for the dashboard demo.
%   Updates pressure (tile 1) and temperature (tile 2) from loaded data.
    fig.tile(1).updateData(1, d.time, d.pressure);
    fig.tile(2).updateData(1, d.time, d.temperature);
end
