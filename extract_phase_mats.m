function [VAN, VBN, VCN] = extract_phase_mats(VoltScenario, busID)
% Attempts two common layouts. Adjust if your storage differs.
% Returns VAN/VBN/VCN matrices sized [96×N_MC] for the given bus.

    if iscell(VoltScenario)
        % Case A: Volt.(s){mc}(t).VAN_mag is a vector over buses
        N_MC = numel(VoltScenario);
        T = numel(VoltScenario{1});    % 96 structs per run
        VAN = zeros(T, N_MC); VBN = zeros(T, N_MC); VCN = zeros(T, N_MC);
        for mc = 1:N_MC
            for t = 1:T
                VAN(t,mc) = VoltScenario(mc)(t).VAN_mag(busID);
                VBN(t,mc) = VoltScenario(mc)(t).VBN_mag(busID);
                VCN(t,mc) = VoltScenario{mc}(t).VCN_mag(busID);
            end
        end

    elseif isstruct(VoltScenario)
        % Case B: Volt.(s)(t,mc) is a struct with *_mag vectors over buses
        % e.g. size 96×N_MC of struct
        sz = size(VoltScenario);
        if numel(sz) == 2 && sz(1) >= 96  % [T × N_MC] struct array
            T = sz(1); N_MC = sz(2);
            VAN = zeros(T, N_MC); VBN = zeros(T, N_MC); VCN = zeros(T, N_MC);
            for mc = 1:N_MC
                for t = 1:T
                    VAN(t,mc) = VoltScenario(t,mc).VAN_mag(busID);
                    VBN(t,mc) = VoltScenario(t,mc).VBN_mag(busID);
                    VCN(t,mc) = VoltScenario(t,mc).VCN_mag(busID);
                end
            end
        else
            error('Unrecognized Volt struct layout. Please adapt the extractor.');
        end

    else
        error('VoltScenario must be a cell array of runs or a [T×N_MC] struct array.');
    end
end