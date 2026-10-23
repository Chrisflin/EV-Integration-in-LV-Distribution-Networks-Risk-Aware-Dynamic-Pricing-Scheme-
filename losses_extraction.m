function [ losses ] = losses_extraction( DSSCircuit, Linenames )

for l=1:length(Linenames)
    DSSCircuit.SetActiveElement(['line.',Linenames{l}]);
    losses(l,:)=DSSCircuit.ActiveElement.losses;
end

end

