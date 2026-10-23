function out = optimize_EVs_LP(EV_info_s, price_kWh, num_load_cols, Pmax, buffer)
% Multi-EV LP (96×15min). Supports overnight (wrap-around) availability.
% Availability window = (duration NEEDED) + randi(additional buffer).
%
% EV_info_s: [NEV × 8]
%   1: phase (1=A,2=B,3=C)        (meta only)
%   2: bus index                   (meta only)
%   3: SoC0 (kWh)
%   4: Cap (kWh)
%   5: Eneed (kWh)                 ← net energy to deliver by departure
%   6: dur_needed (slots)          ← minimum # of 15-min slots needed
%   7: tstart (1..96)
%   8: load_col (1..num_load_cols) ← maps to Pload columns (1..33)
%
% price_kWh    : [96×1] €/kWh (CPP already applied)
% num_load_cols: integer (e.g., 33)
% Pmax         : charger kW (default 7.4)
% allowV2G     : true/false (default false)
%
% Returns:
%   out.P_ev        : [NEV × 96] kW per EV
%   out.EVload_cols : [96 × num_load_cols] kW increments (zeros elsewhere)
%   out.meta        : basic fields for traceability

    if nargin < 5 || isempty(Pmax), Pmax = 7.4; end

    T = 96;
    dt = 0.25; 
    eff = 1;

    % USER: per-slot fleet cap at midnight hours to specific kW
    midnight_slots = 1:36;    % <<< change this range as you like (e.g., 1:12 for 00:00–03:00)
    cap_kW         = 70;     % <<< fleet kW cap per 15-min slot in those midnight slots
    % ----------------------------------------------------------------

    % keep EVs with valid target column
    mask = ~isnan(EV_info_s(:,8)) & EV_info_s(:,8) >= 1 & EV_info_s(:,8) <= num_load_cols;
    EV   = EV_info_s(mask, :);
    NEV  = size(EV,1);

    % 3 VERSIONS : idia data + rand additional buffer 2. new + rand (additional bafer
    EXTRA_SLOTS = buffer;

    out.P_ev        = zeros(NEV, T);
    out.EVload_cols = zeros(T, num_load_cols);
    out.meta        = struct('loadcol', [], 'tstart', [], 'dur_needed', [], 'Eneed', []);

    if NEV == 0
        return; 
    end

    % unpack
    SoC0    = EV(:,3);
    Cap     = EV(:,4);
    Eneed   = EV(:,5);
    durN    = EV(:,6);    % minimum slots needed
    tstart  = EV(:,7);
    loadcol = EV(:,8);

    SoCmin  = 0.10 .* Cap;
    SoCmax  = 0.90 .* Cap;

    % decision x = vec(P_ev) (EVs stacked per time)
    nvar = NEV * T;

    % --- price_kWh can be 96x1 (same for all EVs) OR 96xNEV (per-EV) ---
    if size(price_kWh,1) ~= T
        error('price_kWh must have 96 rows');
    end

    if size(price_kWh,2) == 1
        % one price for everyone
        f = zeros(nvar,1);
        for t = 1:T
            f((t-1)*NEV + (1:NEV)) = price_kWh(t) * dt;   % same price across EVs
        end
    elseif size(price_kWh,2) == NEV
        % per-EV price (column e is EV e)
        f = zeros(nvar,1);
        for t = 1:T
            % 1xNEV row assigned to the corresponding slice
            f((t-1)*NEV + (1:NEV)) = price_kWh(t,:) * dt;
        end
    else
        error('price_kWh must be 96x1 or 96xNEV (got %dx%d)', size(price_kWh,1), size(price_kWh,2));
    end

    % bounds (availability) with wrap-around
    lb = zeros(nvar,1); 
    ub = zeros(nvar,1);
    idx = @(e,t) (t-1)*NEV + e;

    % helper to set contiguous range [a..b]
    function set_bounds_range(e,a,b)
        ub(idx(e,a:b)) = Pmax;
    end

    for e = 1:NEV
        t1 = max(1, tstart(e));
        t2_raw = t1 + durN(e) - 1 + EXTRA_SLOTS(e);  % can exceed 96
        if t2_raw <= T
            % no wrap
            t2 = t2_raw;
            window_len = (t2 - t1 + 1);
            can_deliver = eff * dt * Pmax * window_len;

            if Eneed(e) > can_deliver + 1e-9
                error('Infeasible EV %d: Eneed > capacity over window (no wrap).', e);
            end
            set_bounds_range(e, t1, t2);
        else
            % wrap-around into next day
            wrap = t2_raw - T; % slots next day
            window_len = (T - t1 + 1) + wrap;
            can_deliver = eff * dt * Pmax * window_len;

            if Eneed(e) > can_deliver + 1e-9
                error('Infeasible EV %d: Eneed > capacity over window (wrap).', e);
            end
            set_bounds_range(e, t1, T);
            set_bounds_range(e, 1, wrap);
        end
    end

    % SoC inequalities over availability window (handle wrap)
    A = []; b = [];
    for e = 1:NEV
        t1 = max(1, tstart(e));
        t2_raw = t1 + durN(e) - 1 + EXTRA_SLOTS(e);

        if t2_raw <= T
            for t = (t1+1):t2_raw
                row = zeros(1,nvar);
                row(1, idx(e, t1:(t-1))) = eff * dt;
                A = [A;  row]; b = [b;  (SoCmax(e) - SoC0(e))];   % SoC ≤ max
                A = [A; -row]; b = [b; -(SoCmin(e) - SoC0(e))];   % SoC ≥ min
            end
        else
            wrap = t2_raw - T;
            % tail of current day
            for t = (t1+1):T
                row = zeros(1,nvar);
                row(1, idx(e, t1:(t-1))) = eff * dt;
                A = [A;  row]; b = [b;  (SoCmax(e) - SoC0(e))];
                A = [A; -row]; b = [b; -(SoCmin(e) - SoC0(e))];
            end
            % next day 1..wrap (accumulate last-day tail + early next-day)
            for t = 1:wrap
                row = zeros(1,nvar);
                row(1, idx(e, t1:T)) = eff * dt;
                if t > 1
                    row(1, idx(e, 1:(t-1))) = row(1, idx(e, 1:(t-1))) + eff * dt;
                end
                A = [A;  row]; b = [b;  (SoCmax(e) - SoC0(e))];
                A = [A; -row]; b = [b; -(SoCmin(e) - SoC0(e))];
            end
        end
    end

    % Energy equality over full (buffered) window: eff*dt*sum P = Eneed
    Aeq = zeros(NEV, nvar); beq = Eneed(:);
    for e = 1:NEV
        t1 = max(1, tstart(e));
        t2_raw = t1 + durN(e) - 1 + EXTRA_SLOTS(e);

        if t2_raw <= T
            Aeq(e, idx(e, t1:t2_raw)) = eff * dt;
        else
            wrap = t2_raw - T;
            Aeq(e, idx(e, t1:T)) = eff * dt;
            Aeq(e, idx(e, 1:wrap)) = Aeq(e, idx(e, 1:wrap)) + eff * dt;
        end
    end
    
    % Capping
    Pcap_slot = inf(T,1);           % no cap initially
    Pcap_slot(midnight_slots) = cap_kW;

    for t = 1:T
        if isfinite(Pcap_slot(t))
            row = zeros(1, nvar);
            row(1, (t-1)*NEV + (1:NEV)) = 1;   % sum_e P(e,t)
            A = [A; row];
            b = [b; Pcap_slot(t)];
        end
    end

    % LP - Solving
    opts = optimoptions('linprog','Display','none');
    [x_opt, ~, exitflag] = linprog(f, A, b, Aeq, beq, lb, ub, opts);
    if exitflag <= 0
        error('linprog failed'); 
    end

    out.P_ev = reshape(x_opt, [NEV, T]);

    % aggregate to 96×num_load_cols (zeros elsewhere)
    for e = 1:NEV
        out.EVload_cols(:, loadcol(e)) = out.EVload_cols(:, loadcol(e)) + out.P_ev(e,:).';
    end

    % per-EV and total cost
    if size(price_kWh,2) == 1
        pmat = repmat(price_kWh, 1, NEV);
    else
        pmat = price_kWh;
    end
    out.cost_ev    = sum((out.P_ev.' .* pmat) * dt, 1).';   % [NEV×1] in currency
    out.cost_total = sum(out.cost_ev);

    out.meta.loadcol = loadcol; 
    out.meta.tstart = tstart; 
    out.meta.dur_needed = durN; 
    out.meta.Eneed = Eneed;
end