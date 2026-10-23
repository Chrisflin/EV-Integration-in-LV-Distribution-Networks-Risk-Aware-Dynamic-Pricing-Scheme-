%% comprehensive review
clear
close all 

load('EV_load_simple_control.mat', 'EV_load_cntrl');
EV_load_simple = EV_load_cntrl; % same data with unctrl
clear EV_load_cntrl

load('EV_load_advanced_control.mat', 'EV_load_cntrl');
EV_load_advanced = EV_load_cntrl; % same unknown with rand additional buffer
clear EV_load_cntrl

scenarios = {'ev20','ev30','ev40'};

for i = 1:numel(scenarios)
    field = scenarios{i};

    S = EV_load_simple.(field);
    A = EV_load_advanced.(field);

    % Aggregate over nodes (33) -> system-level load
    S_sys = squeeze(sum(S, 2));   % 96 x 100
    A_sys = squeeze(sum(A, 2));

    % Statistics over scenarios (100)
    S_p95  = prctile(S_sys, 95, 2);
    A_p95  = prctile(A_sys, 95, 2);

    t = 1:96;

    % Plot
    figure; hold on; grid on;

    plot(t, S_p95,  '--b', 'LineWidth', 2)
    plot(t, A_p95,  '--k', 'LineWidth', 2)

    xlabel('Time step')
    ylabel('EV Load')
    title(sprintf('Scenario: %s', field));

    legend( ...
        'Simple Mean','Simple P95', ...
        'Unknown Mean','Unknown P95', ...
        'Advanced Mean','Advanced P95', ...
        'Location','best')
end

%% VOLTAGE ANALYSIS - VUF, VD across buses in the selected time window (1:00 - 7:00) and 24h VUF, VD at bus 36
clear
load("statsVoltage.mat")
load('statsVoltage_cntrl.mat');
statsVUF_simple = statsVUF_cntrl;
statsVD_simple = statsVD_cntrl;
clear statsVUF_cntrl statsVD_cntrl;

load('statsVoltage_cntrl_advanced.mat');
statsVUF_advanced = statsVUF_cntrl;
statsVD_advanced = statsVD_cntrl;
clear statsVUF_cntrl statsVD_cntrl;

%% 1. 24h VD at bus 36 

scenarios = {'ev20','ev30','ev40'};
time = (0:95) * 0.25;   % 96 steps, 15min each → hours

for i = 1:numel(scenarios)
    sc = scenarios{i};

    % --- Extract VD stats
    unctrl = statsVD.(sc);
    S = statsVD_simple.(sc);
    A = statsVD_advanced.(sc);

    figure; hold on; grid on;

    plot(time, unctrl.P95(:,36),  '-g', 'LineWidth', 2)
    plot(time, S.P95(:,36),  '-b', 'LineWidth', 2)
    plot(time, A.P95(:,36),  '-k', 'LineWidth', 2)

    plot(time, unctrl.mean(:,36),  '--g', 'LineWidth', 2)
    plot(time, S.mean(:,36),  '--b', 'LineWidth', 2)
    plot(time, A.mean(:,36),  '--k', 'LineWidth', 2)

    xlabel('hours')
    ylabel('VD [%]')
    title(['VD – ' upper(sc)])

    legend('unctrl','cntrl.1','cntrl.2','Location','best')
end

%% 1. 24h VUF at bus 36

for i = 1:numel(scenarios)
    sc = scenarios{i};

    % --- Extract VD stats
    unctrl = statsVUF.(sc);
    S = statsVUF_simple.(sc);
    A = statsVUF_advanced.(sc);

    figure; hold on; grid on;

    plot(time, unctrl.P95(:,36),  '-g', 'LineWidth', 2)
    plot(time, S.P95(:,36),  '-b', 'LineWidth', 2)
    plot(time, A.P95(:,36),  '-k', 'LineWidth', 2)

    plot(time, unctrl.mean(:,36),  '-g', 'LineWidth', 2)
    plot(time, S.mean(:,36),  '-b', 'LineWidth', 2)
    plot(time, A.mean(:,36),  '-k', 'LineWidth', 2)

    xlabel('Time [h]')
    ylabel('VUF [%]')
    title(['VUF – ' upper(sc)])

    legend('unctrl','cntrl.1','cntrl.2','Location','best')
end

%% VUF PDFs & CDFs ----- Extract subset (timesteps 68–92 (1:00-7:00), buses 24–37, all MC runs)
clc
clear
close all

%load('MC_KPIS.mat', 'VUF');
load('simple_control_KPIS.mat', 'VUF_cntrl');
VUF_simple = VUF_cntrl;
clear VUF_cntrl

load('unknown_control_KPIS.mat', 'VUF_cntrl');
VUF_unknown = VUF_cntrl;
clear VUF_cntrl

load('advanced_control_KPIS.mat', 'VUF_cntrl');
VUF_advanced = VUF_cntrl;
clear VUF_cntrl

scenarios = {'ev20','ev30','ev40'};

% --- PDFs ---
for i = 1:numel(scenarios)
    sc = scenarios{i};
    time_idx = 4:28;
    bus_idx  = 24:37;
    subset1   = VUF_simple.(sc)(time_idx, bus_idx, :);
    subset2   = VUF_unknown.(sc)(time_idx, bus_idx, :);
    subset3   = VUF_advanced.(sc)(time_idx, bus_idx, :);

    % Flatten all values into one vector
    simple = subset1(:);
    unknown = subset2(:);
    advanced = subset3(:);

    % Compute smooth kernel density estimate (PDF)
    [f1, x1] = ksdensity(simple);  % f = PDF values, x = VUF range
    [f2, x2] = ksdensity(unknown);
    [f3, x3] = ksdensity(advanced);

    figure; hold on; grid on;

    plot(x1, f1, 'k-', 'LineWidth', 2);
    plot(x2, f2, 'r-', 'LineWidth', 2);
    plot(x3, f3, 'b-', 'LineWidth', 2);

    xlabel('VUF value');
    ylabel('Probability Density');
    legend('simple', 'unknown', 'advanced');
    title(['Smoothed Combined PDF of VUF (buses 24–37, timesteps 68–92) - ' upper(sc)]);
end

% --- CDFs ---
for i = 1:numel(scenarios)
    sc = scenarios{i};

    subset1 = VUF_simple.(sc)(time_idx, bus_idx, :);
    subset2 = VUF_unknown.(sc)(time_idx, bus_idx, :);
    subset3 = VUF_advanced.(sc)(time_idx, bus_idx, :);

    simple   = subset1(:);
    unknown  = subset2(:);
    advanced = subset3(:);

    [F1, X1] = ecdf(simple);
    [F2, X2] = ecdf(unknown);
    [F3, X3] = ecdf(advanced);

    figure; hold on; grid on;

    plot(X1, F1, 'k-', 'LineWidth', 2)
    plot(X2, F2, 'r-', 'LineWidth', 2)
    plot(X3, F3, 'b-', 'LineWidth', 2)

    xlabel('VUF')
    ylabel('CDF')
    title(['VUF CDF – ' upper(sc)])
    legend('Simple','Unknown','Advanced','Location','best')
end


%% VD PDFs & CDFs - Extract subset (timesteps 68–92 (1:00-7:00), buses 24–37, all MC runs)
clc
clear
close all

%load('MC_KPIS.mat', 'VUF');
load('simple_control_KPIS.mat', 'VD_cntrl');
VD_simple = VD_cntrl;
clear VD_cntrl

load('unknown_control_KPIS.mat', 'VD_cntrl');
VD_unknown = VD_cntrl;
clear VD_cntrl

load('advanced_control_KPIS.mat', 'VD_cntrl');
VD_advanced = VD_cntrl;
clear VD_cntrl

scenarios = {'ev20','ev30','ev40'};
% Extract subset (timesteps 68–92, buses 24–37, all MC runs)

% --- PDFs ---
for i = 1:numel(scenarios)
    sc = scenarios{i};
    time_idx = 4:28;
    bus_idx  = 24:37;
    subset1   = VD_simple.(sc)(time_idx, bus_idx, :);
    subset2   = VD_unknown.(sc)(time_idx, bus_idx, :);
    subset3   = VD_advanced.(sc)(time_idx, bus_idx, :);

    % Flatten all values into one vector
    simple = subset1(:);
    unknown = subset2(:);
    advanced = subset3(:);

    % Compute smooth kernel density estimate (PDF)
    [f1, x1] = ksdensity(simple);  % f = PDF values, x = VUF range
    [f2, x2] = ksdensity(unknown);
    [f3, x3] = ksdensity(advanced);

    figure; hold on; grid on;

    plot(x1, f1, 'k-', 'LineWidth', 2);
    plot(x2, f2, 'r-', 'LineWidth', 2);
    plot(x3, f3, 'b-', 'LineWidth', 2);

    xlabel('VD value');
    ylabel('Probability Density');
    legend('simple', 'unknown', 'advanced');
    title(['Smoothed Combined PDF of VD (buses 24–37, timesteps 68–92) - ' upper(sc)]);
end

% --- CDFs ---
for i = 1:numel(scenarios)
    sc = scenarios{i};

    subset1 = VD_simple.(sc)(time_idx, bus_idx, :);
    subset2 = VD_unknown.(sc)(time_idx, bus_idx, :);
    subset3 = VD_advanced.(sc)(time_idx, bus_idx, :);

    simple   = subset1(:);
    unknown  = subset2(:);
    advanced = subset3(:);

    [F1, X1] = ecdf(simple);
    [F2, X2] = ecdf(unknown);
    [F3, X3] = ecdf(advanced);

    figure; hold on; grid on;

    plot(X1, F1, 'k-', 'LineWidth', 2)
    plot(X2, F2, 'r-', 'LineWidth', 2)
    plot(X3, F3, 'b-', 'LineWidth', 2)

    xlabel('VD')
    ylabel('CDF')
    title(['VD CDF – ' upper(sc)])
    legend('Simple','Unknown','Advanced','Location','best')
end