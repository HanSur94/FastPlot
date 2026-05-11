function y = buildSensorExcursions(cfg, key, tHist)
%BUILDSENSOREXCURSIONS Build the historical y(t) for one sensor.
%   y = buildSensorExcursions(cfg, key, tHist) returns the synthetic
%   1 Hz historical signal for SensorTag `key` over the time vector
%   `tHist` (column of MATLAB datenums). The signal is:
%       y(t) = baseline(t) + sum(excursions(t))
%   then clamped to cfg.Ranges.<field>.
%
%   For sensors with no monitor (cfg.MonitorDefs lookup misses) the
%   excursion overlay is empty and y is the bare sine + noise baseline.
%   Monitored sensors get a deterministic excursion schedule (Task 3).
%
%   The caller is responsible for seeding the RNG before calling this
%   function. Inside this function we only use randn() / rand() — no
%   reseeding — so multiple sensor calls in the same `seedHistory` run
%   produce a coherent, reproducible record.
%
%   See also: seedHistory, plantConfig.

    field = strrep(key, '.', '_');
    assert(isfield(cfg.Baselines, field), ...
        sprintf('plantConfig().Baselines.%s missing for key=%s', field, key));
    assert(isfield(cfg.Ranges, field), ...
        sprintf('plantConfig().Ranges.%s missing for key=%s', field, key));

    b         = cfg.Baselines.(field);
    sensorRng = cfg.Ranges.(field);

    tHist = tHist(:);
    tRel  = (tHist - tHist(1)) * 86400;   % seconds since first sample

    % Baseline: sine + Gaussian noise (matches makeDataGenerator's model).
    y = b.mean + b.amp * sin(2*pi*tRel/b.period + b.phase) ...
          + b.noise * randn(size(tRel));

    % Excursion overlay (monitored sensors only). Task 3 fills this in;
    % for now this is a no-op.
    y = applyExcursions_(cfg, key, tHist, tRel, y);

    % Clamp to physical range so the signal stays plausible.
    y = max(sensorRng(1), min(sensorRng(2), y));
end

function y = applyExcursions_(cfg, key, tHist, tRel, y) %#ok<INUSL>
    %APPLYEXCURSIONS_ No-op stub; Task 3 implements the schedule.
    %#ok<INUSD>
end
