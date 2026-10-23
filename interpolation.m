% Φόρτωση δεδομένων από CSV
data = readtable('data_sampling.csv', 'Delimiter', ';', 'DecimalSeparator', ',');

% Μετατροπή σε αριθμητικά δεδομένα
x = data{:,1};  % χρόνος σε ώρες
y = data{:,2};

% Νέα σημεία ανά 15 λεπτά (0.25 ώρες), συνολικά 96 σημεία από 0 έως <24
xq = 0.15:0.25:24;

% Παρεμβολή (γραμμική ή spline αν θέλεις πιο ομαλό αποτέλεσμα)
yq = interp1(x, y, xq, 'linear', 'extrap');

% Γράφημα: Πρωτογενή δεδομένα και παρεμβολή
figure;
plot(x, y, 'bo-', 'LineWidth', 1.2); hold on;
plot(xq, yq, 'r*--', 'LineWidth', 1);
legend('Initial Data', 'Interpolation every 15min');
xlabel('Time (hours)');
ylabel('Τιμή');
title('Data interpolation every 15 minutes for 24 hours');
grid on;

% Αποθήκευση αποτελεσμάτων
output = table(yq', 'VariableNames', {'Interpolated_EV_profile'});
writetable(output, 'interpolated_output_15min.csv');
