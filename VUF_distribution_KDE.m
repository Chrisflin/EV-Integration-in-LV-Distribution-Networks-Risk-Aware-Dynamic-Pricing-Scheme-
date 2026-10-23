clc
clear
close all

%load('MC_KPIS.mat', 'VUF');
load('simple_control_KPIS.mat', 'VUF_cntrl');
% Extract subset (timesteps 68–92, buses 24–37, all MC runs)
time_idx = 4:28;
bus_idx  = 24:37;
%subset1   = VUF_cntrl.base(time_idx, bus_idx, :);
subset2   = VUF_cntrl.ev20(time_idx, bus_idx, :);
subset3   = VUF_cntrl.ev30(time_idx, bus_idx, :);
subset4   = VUF_cntrl.ev40(time_idx, bus_idx, :);

% Flatten all values into one vector
%base = subset1(:);
ev20 = subset2(:);
ev30 = subset3(:);
ev40 = subset4(:);

% Compute smooth kernel density estimate (PDF)
%[f1, x1] = ksdensity(base);  % f = PDF values, x = VUF range
[f2, x2] = ksdensity(ev20);
[f3, x3] = ksdensity(ev30);
[f4, x4] = ksdensity(ev40);

% Plot
figure;
hold on
%plot(x1, f1, 'k-', 'LineWidth', 2);
plot(x2, f2, 'r-', 'LineWidth', 2);
plot(x3, f3, 'b-', 'LineWidth', 2);
plot(x4, f4, 'g-', 'LineWidth', 2);
legend('ev20', 'ev30', 'ev40');
title('Smoothed Combined PDF of VUF (buses 24–37, timesteps 68–92)');
xlabel('VUF value');
ylabel('Probability Density');
grid on;

%%

clc
clear
close all

load('simple_control_KPIS.mat', 'VD_cntrl');

% Extract subset (timesteps 68–92, buses 24–37, all MC runs)
time_idx = 4:28;
bus_idx  = 24:37;
%subset1   = VD_cntrl.base(time_idx, bus_idx, :);
subset2   = VD_cntrl.ev20(time_idx, bus_idx, :);
subset3   = VD_cntrl.ev30(time_idx, bus_idx, :);
subset4   = VD_cntrl.ev40(time_idx, bus_idx, :);

% Flatten all values into one vector
%base = subset1(:);
ev20 = subset2(:);
ev30 = subset3(:);
ev40 = subset4(:);

% Compute smooth kernel density estimate (PDF)
%[f1, x1] = ksdensity(base);  % f = PDF values, x = VUF range
[f2, x2] = ksdensity(ev20);
[f3, x3] = ksdensity(ev30);
[f4, x4] = ksdensity(ev40);

% Plot
figure;
hold on
%plot(x1, f1, 'k-', 'LineWidth', 2);
plot(x2, f2, 'r-', 'LineWidth', 2);
plot(x3, f3, 'b-', 'LineWidth', 2);
plot(x4, f4, 'g-', 'LineWidth', 2);
legend('ev20', 'ev30', 'ev40');
title('Smoothed Combined PDF of VUF (buses 24–37, timesteps 68–92)');
xlabel('VUF value');
ylabel('Probability Density');
grid on;