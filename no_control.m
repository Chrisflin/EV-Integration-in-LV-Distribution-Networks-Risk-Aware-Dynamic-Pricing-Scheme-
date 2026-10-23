function [Voltage, Currents, losses_matrix] =no_control(PloadA,PloadB,PloadC, ...
                                                 QloadA,QloadB,QloadC,LoadNames,BusNames, LineNames)

% Initialization of the OpenDSS
DSSObj = actxserver('OpenDSSEngine.DSS');
Start = DSSObj.Start(0);
DSSCircuit = DSSObj.ActiveCircuit;
DSSText = DSSObj.Text;

% path of the .dss file
DSSText.Command = 'compile C:\Users\xrhstos\Desktop\DIPLOMA_THESIS\LV_Diploma_Thesis\simulation\neutral.dss';

% Load determination. 
for i=1:11 % 11 is the number of loads in the examined grid

    DSSCircuit.SetActiveElement([char(LoadNames(i)),'a']);  
    DSSCircuit.ActiveElement.Properties('kW').Val=num2str(PloadA(i));
    DSSCircuit.ActiveElement.Properties('kvar').Val=num2str(QloadA(i));
    
    DSSCircuit.SetActiveElement([char(LoadNames(i)),'b']);  
    DSSCircuit.ActiveElement.Properties('kW').Val=num2str(PloadB(i));
    DSSCircuit.ActiveElement.Properties('kvar').Val=num2str(QloadB(i));
    
    DSSCircuit.SetActiveElement([char(LoadNames(i)),'c']);  
    DSSCircuit.ActiveElement.Properties('kW').Val=num2str(PloadC(i));
    DSSCircuit.ActiveElement.Properties('kvar').Val=num2str(QloadC(i));

end

% Load Flow Solution
DSSSolution=DSSCircuit.Solution;
DSSSolution.Solve;

% Voltage extraction
if DSSSolution.Converged==1
    Voltage = voltage_extraction(BusNames,DSSCircuit.AllNodename,DSSCircuit.AllBusVolts);
    Currents = current_extraction(DSSCircuit, LineNames);
    losses_matrix = losses_extraction(DSSCircuit, LineNames);  % Nx2 matrix
    %Losses = losses_matrix(:,1);  % Κρατάμε μόνο τα P_loss (ανά γραμμή)
else
    
    disp('Cannot converge');
    Voltage = [];
    Currents = [];
    %Losses = [];
end

DSSObj.ClearAll;

end