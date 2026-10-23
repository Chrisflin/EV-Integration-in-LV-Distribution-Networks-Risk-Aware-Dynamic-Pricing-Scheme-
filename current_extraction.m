function [ cur ] = current_extraction( DSSCircuit, Linenames )

% This function computes the currents of network lines
% Inputs...
% The DSSCircuit object and the names of all network lines (stored in table Linename)
% Outputs...
% A struct containing the curresnt magnitude ang angle (results are provided for all three phases)

for l=1:length(Linenames)
    DSSCircuit.SetActiveElement(['line.',Linenames{l}]);
    curline=DSSCircuit.ActiveElement.Currents;
    cur(l).pha_vec=curline(1)+1i*curline(2);
    cur(l).phb_vec=curline(3)+1i*curline(4);
    cur(l).phc_vec=curline(5)+1i*curline(6);
    cur(l).pha_mag=abs(cur(l).pha_vec);
    cur(l).phb_mag=abs(cur(l).phb_vec);
    cur(l).phc_mag=abs(cur(l).phc_vec);
    cur(l).pha_ang=rad2deg(angle(cur(l).pha_vec));
    cur(l).phb_ang=rad2deg(angle(cur(l).phb_vec));
    cur(l).phc_ang=rad2deg(angle(cur(l).phc_vec));
end

end

