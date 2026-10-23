%% EV-demand-driven PDF and CDF
clc
clear
close all

%% Step 1: Create Synthetic Data
power = readmatrix('interpolated_output_15min.csv');

totalPoints = length(power);
time = (0:totalPoints-1)' * 0.25;

%% Step 2: Calculate the Numerical Derivative (dP/dt)
dt = time(2) - time(1); % Time step (0.25 hours)
derivative = zeros(size(power));

% Central difference for interior points
for i = 2:length(power)-1
    derivative(i) = (power(i+1) - power(i-1)) / (2 * dt);
end

% Forward difference for first point
derivative(1) = (power(2) - power(1)) / dt;

% Backward difference for last point
derivative(end) = (power(end) - power(end-1)) / dt;

%% Step 3: Create the Start Signal
startSignal = max(0, derivative); % Only keep positive values (start events)

%% Step 4: Normalize to create the PDF
areaUnderSignal = trapz(time, startSignal);
startPDF = startSignal / areaUnderSignal; % This is now a valid PDF

%% Step 5: Create the CDF
startCDF = zeros(size(time));
for i = 1:length(time)
    if i == 1
        startCDF(i) = 0;
    else
        startCDF(i) = trapz(time(1:i), startPDF(1:i));
    end
end

% Ensure CDF ends at 1 (handles numerical precision)
startCDF = startCDF / startCDF(end);

%% Plotting
figure('Position', [100, 100, 1200, 800]);

% Plot 1: Original Load Profile
subplot(2,2,1);
stairs(time, power, 'b-', 'LineWidth', 1.5); % Use stairs for step-like data
title('Original EV Load Demand (p.u.)');
xlabel('Time (hours)');
ylabel('Power (p.u.)');
grid on;
xlim([0, 24]);

% Plot 2: Derivative and Start Signal
subplot(2,2,2);
plot(time, derivative, 'r--', 'LineWidth', 1.5); hold on;
plot(time, startSignal, 'g-', 'LineWidth', 2);
legend('Derivative (dP/dt)', 'Start Signal (max(0, dP/dt))');
title('Derivative and Start Signal');
xlabel('Time (hours)');
grid on;
xlim([0, 24]);

% Plot 3: Start Time PDF
subplot(2,2,3);
stairs(time, startPDF, 'k-', 'LineWidth', 1.5); hold on;
area(time, startPDF, 'FaceColor', 'k', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
title('Start Time Probability Density Function (PDF)');
xlabel('Time (hours)');
ylabel('Probability Density');
grid on;
xlim([0, 24]);

% Plot 4: Start Time CDF
subplot(2,2,4);
plot(time, startCDF, 'm-', 'LineWidth', 2);
title('Start Time Cumulative Distribution Function (CDF)');
xlabel('Time (hours)');
ylabel('Cumulative Probability');
grid on;
xlim([0, 24]);
ylim([0, 1.05]);

%% Export the PDF and CDF for use in other simulations
save('EV_StartTime_Distribution.mat', 'time', 'startPDF', 'startCDF');
