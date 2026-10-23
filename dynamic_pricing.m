%% Calculation of PoV, Stime, Smag, RoV for every bus
% PoV : Probability a bus violates at least once the limit
% Stime : Conditional prob, if it violates for how long does it stay above limit
% Smag : When it violates, how far above the limit (average, relative to the limit)
% RoV : Uncoditional prob, over all runs avg duration above limit
clc
clear all
close all

num_buses = 37;
load('MC_KPIS.mat');  % The outputs of uncontrolled version
scenarios = {'ev20', 'ev30', 'ev40'};
VUF_limit = 2;
VD_limit = 5;

for i=1:numel(scenarios)
    
    s = scenarios{i};
    VUF_temp = VUF.(s);
    VD_temp = VD.(s);
    probVUF_unctrl.(s) = hourly_bus_probability_metrics(VUF_temp, VUF_limit);
    probVD_unctrl.(s) = hourly_bus_probability_metrics(VD_temp, VD_limit);
end

%% save results
save('probability_metrics_results.mat', 'probVUF_unctrl', 'probVD_unctrl');

%% Build dynamic pricing scheme
clc
clear
close all
load('probability_metrics_results.mat', 'probVD_unctrl');
scenarios = {'ev20', 'ev30', 'ev40'};

bus_loads = 11;
T = 96;
bus_ids = [10, 8, 12, 18, 15, 23, 25, 29, 34, 36, 37];
a = 1;
b =0.15;


Pbase = 0.189;          % fixed price with taxes etc
% greece Wholesale market sample 24/03/25
%Pbase = readtable('pricing.xlsx');
%Pbase = table2array(Pbase);
%Pbase = Pbase / 1000;

for i=1:numel(scenarios)

    scen = scenarios{i};
    signal = probVD_unctrl.(scen).RoV;
    signal_15min = repelem(signal, 4, 1);

    nb = numel(bus_ids);
    dynamic_price.(scen) = zeros(T, nb);
    for t = 1:T
        for j = 1:nb
            bus = bus_ids(j);
            temp_signal = signal_15min(t, bus);
            if temp_signal ~= 0
                dynamic_price.(scen)(t, j) = Pbase * (1 + a*temp_signal);
            else
                dynamic_price.(scen)(t, j) = Pbase * (1 - b);
            end
        end
    end

    load_to_bus_col = repelem(1:nb, 3);  % 1 1 1 2 2 2 ... 11 11 11
    Price_per_load.(scen) = dynamic_price.(scen)(:, load_to_bus_col);
end

save('adjusted_DP.mat', "Price_per_load");