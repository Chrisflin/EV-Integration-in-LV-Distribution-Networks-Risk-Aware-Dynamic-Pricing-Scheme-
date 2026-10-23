function probVUF_unctrl = hourly_bus_probability_metrics(X_metric, limit)

[~,B,MC] = size(X_metric);
H = 24; stepsPerHour = 4;   % 96 steps/day → 4 per hour

% Preallocate (fractions in [0,1]; multiply by 100 later if you want %)
Pany   = zeros(H,B);
Stime  = nan(H,B);
Smag   = zeros(H,B);
RoV    = zeros(H,B);

for h = 1:H
    idx = (h-1)*stepsPerHour + (1:stepsPerHour);   % 4 indices for this hour
    T = numel(idx);

    % ---- Relative exceedance e = (M - θ)+ / θ ----
    e = max(X_metric(idx,:,:) - limit, 0) ./ limit; % [T x B x MC]
    I = e > 0;                                              % indicator

    % ---- P(any) per bus ----
    any_run = squeeze(any(I,1));        % [B x MC]
    Pany(h,:) = mean(any_run, 2).';     % [1 x B]

    % ---- Time-based severity (conditional duration) ----
    frac_run = squeeze(sum(I,1)) / T;   % [B x MC] fraction of hour violated in each run
    num_viol_runs = sum(any_run, 2);    % [B x 1]
    st = (sum(frac_run .* any_run, 2) ./ max(num_viol_runs,1)).'; % [1 x B]
    st(num_viol_runs==0) = NaN;         % undefined if never violates
    Stime(h,:) = st;

    % ---- Magnitude-based severity (minute-weighted) ----
    sumE = squeeze(sum(e, [1 3])).';    % [1 x B] sum of relative excess over all t,m
    sumI = squeeze(sum(I, [1 3])).';    % [1 x B] total violating minutes (t,m)
    Smag(h,:) = sumE ./ max(sumI, 1);   % average excess when violating (fraction of limit)

    % ---- RoV (unconditional time frequency) & AOT ----
    RoV(h,:) = (squeeze(sum(I, [1 3])) / (T*MC)).';  % [1 x B]
end

% Package results (choose % or fractions as you prefer)
probVUF_unctrl.Pany   = Pany;             % fraction in [0,1]
probVUF_unctrl.Stime  = Stime;            % fraction in [0,1]
probVUF_unctrl.Smag   = Smag;             % fraction (relative to the limit), unitless
probVUF_unctrl.RoV    = RoV;              % fraction in [0,1]

% Convenience: also return % versions
OUT_pct.Pany  = 100*Pany;
OUT_pct.Stime = 100*Stime;
OUT_pct.RoV   = 100*RoV;
OUT_pct.Smag  = 100*Smag;  % "% of the limit" average excess during violations
OUT_pct_meta  = struct('per_hour', true, 'per_bus', true);

OUT_pct.meta = OUT_pct_meta;
probVUF_unctrl.meta = struct('H',H,'B',B,'MC',MC,'stepsPerHour',stepsPerHour,'limit',limit);
end
