clear all
close all
clc

load('data_grid.mat');
load('Parameters.mat');
load('Stochastic_Generated_Loads.mat', 'Pload', 'Qload');
load('EV_unknown_data.mat');            % new
%load('EV_data.mat', 'EV_info');        old
load('adjusted_DP.mat');
load('additional_buffer.mat');


scenarios = {'ev20', 'ev30', 'ev40'};
N_EVs = [7, 10, 13];

for scen = 1:numel(scenarios)
    s = scenarios{scen};
    number_evs = N_EVs(scen);

    N_loads = height(Load);
    Pmax = 7.4;
    Vref = [11547 400];

    Volt_cntrl.(s).VAN = zeros(timesteps, num_buses, N_MC);
    Volt_cntrl.(s).VBN = zeros(timesteps, num_buses, N_MC);
    Volt_cntrl.(s).VCN = zeros(timesteps, num_buses, N_MC);

    Curr_cntrl.(s).IA = zeros(timesteps, num_lines, N_MC);
    Curr_cntrl.(s).IB = zeros(timesteps, num_lines, N_MC);
    Curr_cntrl.(s).IC = zeros(timesteps, num_lines, N_MC);

    Pload_cntrl.(s) = zeros(timesteps, N_loads, N_MC);
    EV_load_cntrl.(s) = zeros(timesteps, N_loads, N_MC);

    perUser_cost_cntrl.(s) = zeros(number_evs,N_MC);
    total_cost_cntrl.(s) = zeros(1,N_MC);

    for mc = 1:N_MC
        fprintf('run %d/%d\n', mc, N_MC);
        P_new = zeros(timesteps, N_loads);

        EVs = EV_info.(s)(:,:,mc);          % [max_EVs x 8]
        buffer = additional_buffer.(s)(:,mc);
        % Use number of EVs (or filter non-NaN rows)
        EVs = EVs(1:number_evs, :);
        buffer = buffer(1:number_evs,:);

        % SoC0 fraction -> kWh
        EVs(:,3) = EVs(:,3) .* EVs(:,4);

        % Defensive clamps
        EVs(:,7) = max(1, min(96, EVs(:,7)));                % tstart
        EVs(:,8) = max(1, min(33, EVs(:,8)));                % load index
        EVs(:,6) = ceil(max(1, EVs(:,6)));                   % dur_needed slots

        % Build per-EV price matrix by LOAD
        NEV = size(EVs,1);
        price_ev = zeros(96, NEV);
        for e = 1:NEV
            load_idx = EVs(e,8);              % 1..33
            price_ev(:,e) = Price_per_load.(s)(:, load_idx);
        end
        % Optimization
        out = optimize_EVs_LP(EVs, price_ev, N_loads, Pmax, buffer);

        % Costs
        perUser_cost_cntrl.(s)(:,mc) = out.cost_ev;      % [NEV x 1]
        total_cost_cntrl.(s)(mc)   = out.cost_total;   % scalar

        EV_load_cntrl.(s)(:,:,mc) = out.EVload_cols;
        P_new  = Pload.base(:,:,mc) + EV_load_cntrl.(s)(:,:,mc);

        % Controlled load saved for each scenario and mc
        Pload_cntrl.(s)(:,:,mc) = P_new;

        PloadA = P_new(:,1:3:end);  
        PloadB = P_new(:,2:3:end);  
        PloadC = P_new(:,3:3:end);
        QloadA = Qload.base(:,1:3:end,mc); 
        QloadB = Qload.base(:,2:3:end,mc); 
        QloadC = Qload.base(:,3:3:end,mc);

        % -- Part 2: Power Flow per time --

        for t = 1:timesteps
            [Voltage, Currents, losses_matrix] = no_control(PloadA(t,:), PloadB(t,:), PloadC(t,:), ...
                             QloadA(t,:), QloadB(t,:), QloadC(t,:), ...
                             LoadNames, BusNames, LineNames);

            % Volt - Curr - Losses extraction
            Volt_cntrl.(s).VAN(t,:,mc) = Voltage.VAN_mag;
            Volt_cntrl.(s).VBN(t,:,mc) = Voltage.VBN_mag;
            Volt_cntrl.(s).VCN(t,:,mc) = Voltage.VCN_mag;
         
            Plosses_cntrl.(s)(t,:,mc) = losses_matrix(:,1);

            for b = 1:num_buses
                VAN_vec = Voltage.VAN_vec(b);
                VBN_vec = Voltage.VBN_vec(b);
                VCN_vec = Voltage.VCN_vec(b);

                VAN_mag = Volt_cntrl.(s).VAN(t,b,mc);
                VBN_mag = Volt_cntrl.(s).VBN(t,b,mc);
                VCN_mag = Volt_cntrl.(s).VCN(t,b,mc);

                VUF_cntrl.(s)(t,b,mc) = cigre_vuf(VAN_vec, VBN_vec, VCN_vec); % VUF
                V_mag_min = min([VAN_mag, VBN_mag, VCN_mag]); 

                if b == 1
                    VD_cntrl.(s)(t,b,mc) = (100*abs(V_mag_min - Vref(1))) / Vref(1);    % Voltage Deviation
                else
                    VD_cntrl.(s)(t,b,mc) = (100*abs(V_mag_min -Vref(2))) / Vref(2);
                end
            end

            for j = 1:num_lines

                Curr_cntrl.(s).IA(t,j,mc) = Currents(j).pha_mag;
                Curr_cntrl.(s).IB(t,j,mc) = Currents(j).phb_mag;
                Curr_cntrl.(s).IC(t,j,mc) = Currents(j).phc_mag;      
            end

        end

    end
end

%% simple dp
save('advanced_control_KPIS.mat', 'VUF_cntrl', 'VD_cntrl', 'Volt_cntrl', 'Curr_cntrl');
save('EV_load_advanced_control.mat', 'EV_load_cntrl');
save('LOADS_advanced_control.mat', 'Pload_cntrl');
save('LOSSES_advanced_control.mat', 'Plosses_cntrl');
save('costs_cntrl_advanced.mat', 'total_cost_cntrl', 'perUser_cost_cntrl');