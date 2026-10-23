% Initialization of the OpenDSS

% The OpenDSS is initialized and simulates the 
% benchmark MV distribution grid of Cigre
% This initialization is performed to acquire network data and to load them
% to the MATLAB enviroment.

DSSObj = actxserver('OpenDSSEngine.DSS');
Start = DSSObj.Start(0);
DSSCircuit = DSSObj.ActiveCircuit;
DSSText = DSSObj.Text;
DSSText.Command = ['compile ','C:\Users\xrhstos\Desktop\DIPLOMA_THESIS\LV_Diploma_Thesis\simulation\neutral.dss'];

% First Load Flow Solution
DSSSolution=DSSCircuit.Solution;
DSSSolution.Solve;

%% Results extraction
% Convergence check...
if DSSSolution.Converged==1    
    % Read data from the .dss file...
    % All lines, loads, DRESS, transformers, and buses are stored in
    % appropriate matrixes

    DSSLines=DSSCircuit.Lines;
    LineNames=DSSLines.Allnames;
    DSSLoads=DSSCircuit.Loads;
    LoadNames=DSSLoads.Allnames;
    DSSGenerators=DSSCircuit.Generators;
    GenNames=DSSGenerators.AllNames;
    DSSTransformer=DSSCircuit.Transformers;
    TrNames=DSSTransformer.AllNames;
    % The meter is used to calculate buses distances from the PCC with the
    % transmission grid
    DSSMeters=DSSCircuit.Meters;
    Meternames=DSSMeters.AllNames;
    BusNames=DSSCircuit.AllBusNames;
    AllElementNames=DSSCircuit.Allelementnames;


    % slack bus data
    SW{1,1}=AllElementNames{1};
    DSSCircuit.SetActiveElement(AllElementNames{1});
    SW{1,2}=DSSCircuit.ActiveDSSElement.Properties('bus1').val;
    SW{1,3}=str2double(DSSCircuit.ActiveDSSElement.Properties('baseKv').val);
    SW{1,4}=str2double(DSSCircuit.ActiveDSSElement.Properties('angle').val);
    SW{1,5}=str2double(DSSCircuit.ActiveDSSElement.Properties('frequency').val);
    SW{1,6}=str2double(DSSCircuit.ActiveDSSElement.Properties('phases').val);
    SW{1,7}=str2double(DSSCircuit.ActiveDSSElement.Properties('MVAsc1').val);
    SW{1,8}=str2double(DSSCircuit.ActiveDSSElement.Properties('MVAsc3').val);
    SW{1,9}=str2double(DSSCircuit.ActiveDSSElement.Properties('x1r1').val);
    SW{1,10}=str2double(DSSCircuit.ActiveDSSElement.Properties('x0r0').val);
    
    
    % Data of all network lines 
    for k=1:length(LineNames)
        Line{k,1}=LineNames{k};
        DSSCircuit.SetActiveElement(['line.',LineNames{k}]);
        %Line{k,2}=find(strcmp(DSSLines.Bus1,BusNames)==1);
        %Line{k,3}=find(strcmp(DSSLines.Bus2,BusNames)==1);
        Line{k,2}=DSSLines.bus1;
        Line{k,3}=DSSLines.bus2;
        Line{k,4}=DSSLines.length;
        Line{k,5}=DSSLines.phases;
        Line{k,6}=DSSLines.R1;
        Line{k,7}=DSSLines.X1;
        Line{k,8}=DSSLines.Rg;
        Line{k,9}=DSSLines.Xg;
    end

    % Data of all network loads
    for k=1:length(LoadNames)
        Load{k,1}=LoadNames{k};
        DSSCircuit.SetActiveElement(['load.',LoadNames{k}]);
        %Load{k,2}=find(strcmp(DSSCircuit.ActiveElement.BusNames,BusNames)==1);
        Load{k,2}=DSSCircuit.ActiveElement.Properties('bus1').val;
        Load{k,3}=str2double(DSSCircuit.ActiveElement.Properties('phases').val);
        Load{k,4}=str2double(DSSCircuit.ActiveElement.Properties('kv').val);    
        Load{k,5}=str2double(DSSCircuit.ActiveElement.Properties('kw').val);
        Load{k,6}=str2double(DSSCircuit.ActiveElement.Properties('kvar').val);
        Load{k,7}=str2double(DSSCircuit.ActiveElement.Properties('model').val);
        Load{k,8}=str2double(DSSCircuit.ActiveElement.Properties('CVRwatts').val);
        Load{k,9}=str2double(DSSCircuit.ActiveElement.Properties('CVRvars').val);
        Load{k,10}=str2double(DSSCircuit.ActiveElement.Properties('Vminpu').val);
        Load{k,11}=str2double(DSSCircuit.ActiveElement.Properties('Vmaxpu').val);
    end

    % Data of all network DRESs
    for k=1:length(GenNames)
        Gen{k,1}=GenNames{k};
        DSSCircuit.SetActiveElement(['generator.',GenNames{k}]);
        %Gen{k,2}=find(strcmp(DSSCircuit.ActiveElement.BusNames,BusNames)==1);
        Gen{k,2}=DSSCircuit.ActiveElement.Properties('bus1').val;
        Gen{k,3}=str2double(DSSCircuit.ActiveElement.Properties('phases').val);
        Gen{k,4}=str2double(DSSCircuit.ActiveElement.Properties('kv').val);    
        Gen{k,5}=str2double(DSSCircuit.ActiveElement.Properties('kw').val);
        Gen{k,6}=str2double(DSSCircuit.ActiveElement.Properties('kvar').val);
        Gen{k,7}=str2double(DSSCircuit.ActiveElement.Properties('model').val);
        Gen{k,8}=str2double(DSSCircuit.ActiveElement.Properties('Vminpu').val);
        Gen{k,9}=str2double(DSSCircuit.ActiveElement.Properties('Vmaxpu').val);
    end

    % Data of all network transformers
    for k=1:length(TrNames)
        Tr{k,1}=TrNames{1};
        DSSCircuit.SetActiveElement(['transformer.',TrNames{k}]);
        Tr{k,2}=str2double(DSSCircuit.ActiveElement.Properties('phases').val);
        Tr{k,3}=str2double(DSSCircuit.ActiveElement.Properties('windings').val);
        buses=DSSCircuit.ActiveElement.BusNames;
        %Tr{k,4}=find(strcmp(buses{1},BusNames)==1);
        %Tr{k,5}=find(strcmp(buses{2},BusNames)==1);
        Tr{k,4}=buses{1};
        Tr{k,5}=buses{2};
        conns=strsplit(DSSCircuit.ActiveElement.Properties('conns').val,',');
        Tr{k,6}=regexprep(conns{1},'[','');
        Tr{k,7}=regexprep(conns{2},' ','');
        kvs=strsplit(DSSCircuit.ActiveElement.Properties('kvs').val,',');
        Tr{k,8}=str2double(regexprep(kvs{1},'[',''));
        Tr{k,9}=str2double(regexprep(kvs{2},' ',''));
        kvas=strsplit(DSSCircuit.ActiveElement.Properties('kvas').val,',');
        Tr{k,10}=str2double(regexprep(kvas{1},'[',''));
        Tr{k,11}=Tr{k,10};
        taps=strsplit(DSSCircuit.ActiveElement.Properties('taps').val,',');
        Tr{k,12}=str2double(regexprep(taps{1},'[',''));
        Tr{k,13}=str2double(regexprep(taps{2},' ',''));
        Tr{k,14}=str2double(DSSCircuit.ActiveElement.Properties('Xhl').val);
        Tr{k,15}=str2double(DSSCircuit.ActiveElement.Properties('%loadloss').val);
        Tr{k,16}=str2double(DSSCircuit.ActiveElement.Properties('%noloadloss').val);
        Tr{k,17}=DSSCircuit.ActiveElement.Properties('Sub').val;
        Tr{k,18}=str2double(DSSCircuit.ActiveElement.Properties('MaxTap').val);
        Tr{k,19}=str2double(DSSCircuit.ActiveElement.Properties('MinTap').val);
        %Tr{k,20}=str2double(DSSCircuit.ActiveElement.Properties('NumTap').val);
        Tr{k,20}=32;
        Tr{k,21}=str2double(DSSCircuit.ActiveElement.Properties('%imag').val);
    end   
    
else
    display('OpenDSS cannot be initialized.');      
end
