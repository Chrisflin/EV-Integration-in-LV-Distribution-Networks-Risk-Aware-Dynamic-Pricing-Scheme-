function [VUF, V0, V1, V2] = compute_VUF(VA, VB, VC)
% VUF : Voltage Unbalance Factor
    a = exp(1j * 2 * pi / 3);  % α = 120°
    
    % Ακολουθιακές συνιστώσες
    ZERO = (VA + VB + VC) ./3;
    POS = (VA + a*VB + a^2*VC) ./ 3;
    NEG = (VA + a^2*VB + a*VC) ./ 3;
    V0 = abs(ZERO);
    V1 = abs(POS);
    V2 = abs(NEG);
    
    VUF = abs(NEG) / abs(POS) * 100;  % σε %
end
