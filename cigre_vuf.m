% Inputs: VAN, VBN, VCN (complex phase voltages per bus/timestep)
% Output: VUF_cigre (%) for each bus/timestep

function VUF_cigre = cigre_vuf(VAN, VBN, VCN)

    % --- Line-to-line magnitudes ---
    Vab = abs(VAN - VBN);
    Vbc = abs(VBN - VCN);
    Vca = abs(VCN - VAN);

    % --- β parameter ---
    num = Vab.^4 + Vbc.^4 + Vca.^4;
    den = (Vab.^2 + Vbc.^2 + Vca.^2).^2;
    beta = num ./ den;

    % --- CIGRÉ Unbalance Factor ---
    term = sqrt(3 - 6*beta);
    UF = sqrt( (1 - term) ./ (1 + term) );

    % Convert to percentage
    VUF_cigre = 100 * UF;
end
