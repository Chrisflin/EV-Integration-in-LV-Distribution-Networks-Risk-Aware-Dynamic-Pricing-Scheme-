clear all
close all
clc

penetration_levels = [0.20, 0.30, 0.40];
scenarios          = {'ev20', 'ev30', 'ev40'};
target_SoC         = 0.80;         % 80% target
charger_power = 7.4;
weibull_shape      = 3;
weibull_scale      = 20;           % percent
loPct = 10; 
hiPct = 40;

load('Parameters.mat')
load('data_grid.mat');                  % grid topology, names, etc.
load('EV_StartTime_Distribution.mat');  % CDF of EV start times

cdf = startCDF;
% ---------------------------

% Determine max EV count for presampling
N_loads = height(Load);
max_EVs = round(max(penetration_levels) * N_loads);

% Precompute the truncated CDF bounds for the SoC
Flo = wblcdf(loPct, weibull_scale, weibull_shape);
Fhi = wblcdf(hiPct, weibull_scale, weibull_shape);
% Map LHS U -> truncated Weibull via inverse CDF

% Pre-sample master LHS matrices [N_MC x max_EVs] so all scenarios use the
% same uncertain variables + the new that have to be added (unit interval samples)
epsU = 1e-12;
U_soc_master   = lhsdesign(N_MC, max_EVs);
U_soc_master = max(min(U_soc_master, 1-epsU), epsU);
U_cap_master   = lhsdesign(N_MC, max_EVs);
U_start_master = lhsdesign(N_MC, max_EVs);

% Pre-sample master EV bus assignments [N_MC x max_EVs] with same logic
EV_buses_master = zeros(N_MC, max_EVs);
EV_buffer_master = zeros(N_MC, max_EVs);
for mc = 1:N_MC
    EV_buses_master(mc, :) = randperm(N_loads, max_EVs);
    EV_buffer_master(mc, :) = randi([28,40], 1, max_EVs);  %7-10 hours
end


for s = 1:numel(penetration_levels)
    pen = penetration_levels(s);
    scenario = scenarios{s};
    N_EVs = round(pen * N_loads);

    % PINAKAS EV
    EV_info.(scenario)   = zeros(max_EVs, 8, N_MC);
    additional_buffer.(scenario) = zeros(max_EVs, N_MC);

    U_soc = U_soc_master(:, 1:N_EVs);
    U_cap = U_cap_master(:, 1:N_EVs);
    U_start = U_start_master(:, 1:N_EVs);
    EV_buses_slice = EV_buses_master(:, 1:N_EVs);
    EV_buffer_slice = EV_buffer_master(:, 1:N_EVs);


    for mc=1:N_MC
        fprintf('%s: run %d/%d\n', scenario, mc, N_MC);
        % 1) Use presampled bus assignments
        EV_buses = EV_buses_slice(mc, :);

        % 2) Initial SoC via LHS + Weibull, truncated at 10% and 40%
        u_soc = U_soc(mc, :)';
        soc_pct = wblinv( Flo + (Fhi - Flo).*u_soc, weibull_scale, weibull_shape); % in %
        initial_SoC = soc_pct/100;  % per-unit [0.10..0.40]

        % 3) Battery capacity via LHS (60–80 kWh)
        u_cap = U_cap(mc, :)';
        battery_capacity = 60 + u_cap* (80 - 60);

        % 4) Energy needed to reach target SoC
        energy_needed = (target_SoC - initial_SoC) .* battery_capacity;

        % 5) Charge duration in 15-min intervals
        hours_needed     = energy_needed ./ charger_power;
        intervals_needed = ceil(hours_needed * 4);

        % 6) Start intervals via LHS + CDF mapping
        u_start = U_start(mc, :)';
        u_start = min(max(u_start, realmin), 1 - eps);   % avoid 0 or 1
        %EV_start_int = discretize(u_start, edges);       % 1..96 integers
        %EV_start_int = find(cdf >= u_start);
        EV_start_int = arrayfun(@(x) find(cdf >= x,1), u_start);


                % Save EV metadata
        info = zeros(max_EVs,8);
        for i=1:N_EVs
            mod_phase = mod(EV_buses(i), 3);
            find_load = ceil(EV_buses(i)/3);
            if mod_phase == 0
                info(i,1) = 3;
            else 
                info(i,1) = mod_phase;
            end

            info(i,2) = cell2mat(LoadNames(find_load,3));
            info(i,3) = initial_SoC(i);
            info(i,4) = battery_capacity(i);
            info(i,5) = energy_needed(i);
            info(i,6) = intervals_needed(i);
            info(i,7) = EV_start_int(i);
            info(i,8) = EV_buses(i);
        end

    EV_info.(scenario)(:,:,mc) = info;
    
    % additional buffer se slots
    buf = zeros(max_EVs,1);
    buf(1:N_EVs) = EV_buffer_slice(mc, :)';
    additional_buffer.(scenario)(:, mc) = buf;

    end
end

mc = 2;
p  = 1;  % pick a position within ev10's N_EVs prefix
b20 = EV_info.ev20(p,2,mc);
b30 = EV_info.ev30(p,2,mc);
b40 = EV_info.ev40(p,2,mc);

assert(b20==b30 && b30==b40, 'Bus mismatch across scenarios');

soc20 = EV_info.ev20(p,3,mc); soc30 = EV_info.ev30(p,3,mc); soc40 = EV_info.ev40(p,3,mc);
cap20 = EV_info.ev20(p,4,mc); cap30 = EV_info.ev30(p,4,mc); cap40 = EV_info.ev40(p,4,mc);
st20  = EV_info.ev20(p,6,mc); st30  = EV_info.ev30(p,6,mc); st40  = EV_info.ev40(p,6,mc);

assert(isequal(soc20,soc30) && isequal(soc30,soc40), 'SoC differs');
assert(isequal(cap20,cap30) && isequal(cap30,cap40), 'Capacity differs');
assert(isequal(st20,st30)   && isequal(st30,st40),   'Start interval differs');
disp('CRN across scenarios verified for this run/position.');


save('EV_unknown_data.mat', 'EV_info');
save('additional_buffer.mat', 'additional_buffer');