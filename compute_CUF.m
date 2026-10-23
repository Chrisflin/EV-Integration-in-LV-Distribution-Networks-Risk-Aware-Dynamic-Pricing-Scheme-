function CUF = compute_CUF(IA, IB, IC)
%   CUF = calculate_CUF(IA, IB, IC) returns the percentage unbalance of
%   phase currents IA, IB, and IC
%   Unbalance (%) = (Max deviation from average / Average current) * 100

    % Validate sizes
    if ~isequal(size(IA), size(IB), size(IC))
        error('IA, IB, and IC must have the same dimensions.');
    end

    % 1) Compute the average current
    Iavg = (IA + IB + IC) ./ 3;

    % 2) Compute absolute deviations from average
    devA = abs(IA - Iavg);
    devB = abs(IB - Iavg);
    devC = abs(IC - Iavg);

    % 3) Find the maximum deviation at each element
    %    Concatenate along a new dimension and take max
    D = cat(ndims(Iavg)+1, devA, devB, devC);
    maxDev = max(D, [], ndims(Iavg)+1);

    % 4) Compute unbalance percentage
    CUF = (maxDev ./ Iavg) * 100;
end
