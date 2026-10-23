% This script creates the 20%-30%-40% scenarios for uncontrolled case 

% Updated Monte Carlo EV Charging Script: Fixed 7.4 kW Charger + Latin Hypercube Sampling
% EV_info.(scenario) : [max_EVs x 8 x N_MC] where 
% 1 : Loadphase 
% 2 : Bus connected     (Bus connected is the true bus)
% 3 : inital SoC
% 4 : Capacity battery
% 5 : E_needed
% 6 : Charging Duration (number of 15min)
% 7 : start-time
% 8 : In which load of the 33 total an EV is connected 

clear all
close all
clc

%% Parameters
load('Parameters.mat')
Vref = [11547 400];
penetration_levels = [0.20, 0.30, 0.40];
scenarios          = {'ev20', 'ev30', 'ev40'};
charger_power      = 7.4;          % kW, fixed
target_SoC         = 0.80;         % 80% target
weibull_shape      = 3;
weibull_scale      = 20;           % percent
loPct = 10; hiPct = 40; % truncate to [10,40] 
%% Load baseline data
load('data_grid.mat');                  % grid topology, names, etc.
load('MC_KPIS.mat');
load('Phase_loads.mat');
load('MC_LOSSES.mat');
load('EV_StartTime_Distribution.mat');  % CDF of EV start times
load('Stochastic_Generated_Loads.mat'); % Pload.base, Qload.base

cdf = startCDF;
%% Determine max EV count for presampling
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
for mc = 1:N_MC
    EV_buses_master(mc, :) = randperm(N_loads, max_EVs);
end

%% 100 times loop over penetration levels
for s = 1:numel(penetration_levels)
    pen = penetration_levels(s);
    scenario = scenarios{s};
    N_EVs = round(pen * N_loads);

    % Initialize storage
    Volt.(scenario).VAN = zeros(timesteps, num_buses, N_MC);
    Volt.(scenario).VBN = zeros(timesteps, num_buses, N_MC);
    Volt.(scenario).VCN = zeros(timesteps, num_buses, N_MC);

    Curr.(scenario).IA = zeros(timesteps, num_lines, N_MC);
    Curr.(scenario).IB = zeros(timesteps, num_lines, N_MC);
    Curr.(scenario).IC = zeros(timesteps, num_lines, N_MC);

    Pload.(scenario) = zeros(timesteps, N_loads, N_MC);
    EV_info.(scenario)   = zeros(max_EVs, 8, N_MC);
    EV_load_unctrl.(scenario) = zeros(timesteps, N_loads, N_MC);

    %Fixed rate costs of EV drawing energy
    perUser_cost.(scenario) = zeros(timesteps,N_loads,N_MC);
    total_cost.(scenario) = zeros(1,N_MC);

    % Slice presampled LHS draws and bus assignments to current EV count
    U_soc = U_soc_master(:, 1:N_EVs);
    U_cap = U_cap_master(:, 1:N_EVs);
    U_start = U_start_master(:, 1:N_EVs);
    EV_buses_slice = EV_buses_master(:, 1:N_EVs);
    
    for mc = 1:N_MC
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
        EV_start_int = arrayfun(@(x) find(cdf >= x,1), u_start);

        % 7) Build EV load profile with wrap-around
        EV_profile = zeros(timesteps, N_loads);
        for i = 1:N_EVs
            st  = EV_start_int(i);
            len = intervals_needed(i);
            idx = mod((st-1):(st+len-2), timesteps) + 1;
            EV_profile(idx, EV_buses(i)) = charger_power;
        end
        
        % 8) Add EV loads to baseline
        P_base = Pload.base(:, :, mc);
        P_new  = P_base;
        P_new(:, EV_buses) = P_new(:, EV_buses) + EV_profile(:, EV_buses);

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
        EV_load_unctrl.(scenario)(:,:,mc) = EV_profile;

        perUser_cost.(scenario)(:,:,mc) = (EV_profile * 0.189)/4;    % flat rate 0.189 €/kWh
        total_cost.(scenario)(mc) = sum((EV_profile * 0.189)/4, 'all');

        % Recalculate phase loads
        PloadA = P_new(:,1:3:end);
        PloadB = P_new(:,2:3:end);
        PloadC = P_new(:,3:3:end);
        QloadA = Qload.base(:,1:3:end,mc);
        QloadB = Qload.base(:,2:3:end,mc);
        QloadC = Qload.base(:,3:3:end,mc);

        % Store adjusted loads
        Pload.(scenario)(:,:,mc) = P_new;
        P_A.(scenario)(:,mc) = sum(PloadA, 2);
        P_B.(scenario)(:,mc) = sum(PloadB, 2);
        P_C.(scenario)(:,mc) = sum(PloadC, 2);

        % Power flow & metrics
        for t = 1:timesteps
            [Voltage, Currents, losses_matrix] = no_control(PloadA(t,:), PloadB(t,:), PloadC(t,:), ...
                                QloadA(t,:), QloadB(t,:), QloadC(t,:), ...
                                LoadNames, BusNames, LineNames);

            % Volt - Curr - Losses extraction
            Volt.(scenario).VAN(t,:,mc) = Voltage.VAN_mag;
            Volt.(scenario).VBN(t,:,mc) = Voltage.VBN_mag;
            Volt.(scenario).VCN(t,:,mc) = Voltage.VCN_mag;
         
            Plosses.(scenario)(t,:,mc) = losses_matrix(:,1);

            for b = 1:num_buses
                VAN_vec = Voltage.VAN_vec(b);
                VBN_vec = Voltage.VBN_vec(b);
                VCN_vec = Voltage.VCN_vec(b);
            
                VAN_mag = Volt.(scenario).VAN(t,b,mc);
                VBN_mag = Volt.(scenario).VBN(t,b,mc);
                VCN_mag = Volt.(scenario).VCN(t,b,mc);
                
                % Cigre calculation
                VUF.(scenario)(t,b,mc) = cigre_vuf(VAN_vec, VBN_vec, VCN_vec); % xigre VUF
                V_mag_min = min([VAN_mag, VBN_mag, VCN_mag]); 
                
                % VD calculation
                if b == 1
                    VD.(scenario)(t,b,mc) = (100*abs(V_mag_min - Vref(1))) / Vref(1);    % Voltage Deviation
                else
                    VD.(scenario)(t,b,mc) = (100*abs(V_mag_min -Vref(2))) / Vref(2);
                end
            end

            for j = 1:num_lines

                Curr.(scenario).IA(t,j,mc) = Currents(j).pha_mag;
                Curr.(scenario).IB(t,j,mc) = Currents(j).phb_mag;
                Curr.(scenario).IC(t,j,mc) = Currents(j).phc_mag;       
            end
        end
    
    end
    VUF.(scenario) = abs(VUF.(scenario));
end

%%
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

%% Save updated results
save('Stochastic_Generated_Loads.mat', 'Pload', 'Qload', '-append');
save('Phase_loads', 'P_A', 'P_B','P_C', '-append');
save('MC_KPIS.mat', 'VUF','Volt', 'Curr', 'VD', '-append');
save('MC_LOSSES.mat', 'Plosses', '-append');
save('EV_data.mat', 'EV_info', 'EV_load_unctrl');
save('unctrl_costs.mat', 'perUser_cost', 'total_cost');
