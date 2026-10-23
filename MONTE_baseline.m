%% This script generates the baseline scenario (only household profile)

clear all
close all
clc

% -- Data --
load('data_grid.mat')
% -- Parameter identification --
Vref = [11547 400];
N_total_loads = height(Load);
num_buses = height(BusNames);
num_lines = height(LineNames);
timesteps = 96;
N_MC = 100;  % number of MC runs

% Initialize P,Q
PRes = zeros(timesteps, N_total_loads);
QRes = zeros(timesteps, N_total_loads);
Pload.base = zeros(timesteps,N_total_loads,N_MC);

%Initialize Voltages,Currents
Volt.base.VAN = zeros(timesteps, num_buses, N_MC);
Volt.base.VBN = zeros(timesteps, num_buses, N_MC);
Volt.base.VCN = zeros(timesteps, num_buses, N_MC);

Curr.base.IA = zeros(timesteps, num_lines, N_MC);
Curr.base.IB = zeros(timesteps, num_lines, N_MC);
Curr.base.IC = zeros(timesteps, num_lines, N_MC);

Q_A = zeros(timesteps,N_MC);
Q_B = zeros(timesteps,N_MC);
Q_C = zeros(timesteps,N_MC);

% Typical daily household profile (without noise-stochasticity)
for m=1:N_total_loads
    PRes(:,m)=Load{m,5}*Consumption;
    QRes(:,m)= Load{m,6}*Consumption;
end

for mc = 1:N_MC
    fprintf("MC %d/%d\n", mc, N_MC);

    % -- Part 1: Residential loads -
    PRes_random = NormalDistribution(PRes);
    QRes_random = NormalDistribution(QRes);
    
    % Save every stochastic res, so that it can be used as a basis later
    Pload.base(:,:,mc) = PRes_random;
    Qload.base(:,:,mc) = QRes_random;
    
    % -- Phase separation --
    PloadA = PRes_random(:, 1:3:end);
    PloadB = PRes_random(:, 2:3:end);
    PloadC = PRes_random(:, 3:3:end);
    QloadA = QRes_random(:, 1:3:end);
    QloadB = QRes_random(:, 2:3:end);
    QloadC = QRes_random(:, 3:3:end);

    % Total KW & KVAr for each phase
    P_A.base(:,mc) = sum(PloadA, 2);  % [96x1]
    Q_A(:,mc) = sum(QloadA, 2);
    P_B.base(:,mc) = sum(PloadB, 2);
    Q_B(:,mc) = sum(QloadB, 2);
    P_C.base(:,mc) = sum(PloadC, 2);
    Q_C(:,mc) = sum(QloadC, 2);
    
    % -- Part 2: Power Flow per time --
    for t = 1:timesteps
        [Voltage, Currents, losses_matrix] = no_control(PloadA(t,:), PloadB(t,:), PloadC(t,:), ...
                             QloadA(t,:), QloadB(t,:), QloadC(t,:), ...
                             LoadNames, BusNames, LineNames);

        % Volt - Curr - Losses extraction
        Volt.base.VAN(t,:,mc) = Voltage.VAN_mag;
        Volt.base.VBN(t,:,mc) = Voltage.VBN_mag;
        Volt.base.VCN(t,:,mc) = Voltage.VCN_mag;
         
        Plosses.base(t,:,mc) = losses_matrix(:,1);

        for b = 1:num_buses
            VAN_vec = Voltage.VAN_vec(b);
            VBN_vec = Voltage.VBN_vec(b);
            VCN_vec = Voltage.VCN_vec(b);

            VAN_mag = Volt.base.VAN(t,b,mc);
            VBN_mag = Volt.base.VBN(t,b,mc);
            VCN_mag = Volt.base.VCN(t,b,mc);

            % Cigre calculation
            VUF.base(t,b,mc) = cigre_vuf(VAN_vec, VBN_vec, VCN_vec);
            V_mag_min = min([VAN_mag, VBN_mag, VCN_mag]); 
            
            % VD calculation
            if b == 1
                VD.base(t,b,mc) = (100*abs(V_mag_min - Vref(1))) / Vref(1);    % Voltage Deviation
            else
                VD.base(t,b,mc) = (100*abs(V_mag_min -Vref(2))) / Vref(2);
            end
        end
        
        % currents (not used in this study)
        for j = 1:num_lines

            Curr.base.IA(t,j,mc) = Currents(j).pha_mag;
            Curr.base.IB(t,j,mc) = Currents(j).phb_mag;
            Curr.base.IC(t,j,mc) = Currents(j).phc_mag;     
        end

    end
end

VUF.base = abs(VUF.base);
disp('MC Simulation generated stochastic baseline load succesfully!');

% SAVE
save('Stochastic_Generated_Loads.mat', 'Pload', 'Qload');
save('Phase_loads', 'P_A', 'P_B','P_C', ...
     'Q_A', 'Q_B', 'Q_C');
save('Parameters.mat', 'N_MC','timesteps', 'num_buses', 'num_lines');
save('MC_KPIS.mat', 'VUF','Volt', 'Curr', 'VD');
save('MC_LOSSES.mat', 'Plosses');