% RUNNETWORK1  Core solver — assembles initial conditions, runs ode15s,
% computes total template counts R_{ij} across all molecular complexes.
%
% Key: GUI inputs are µM; internally converted to M (×1e-6).
% Uses ode15s (stiff solver) with RelTol/AbsTol = 1e-12.

function [tAll, RAll, ...] = RunNetwork1(networkData, preqtime, intime, ...
    vint, reactorVolume, Eint_feed, Nint_feed, Tint_feed)

    global pathwayData aValue frValue drValue isCSTR;

    % --- Compute CSTR dilution rate D = flow_rate / volume [1/s] ---
    if isCSTR && any(Eint_feed ~= 0) && intime > 0 && reactorVolume > 0
        D = (vint / intime) / reactorVolume;
    else
        D = 0;  % pure batch
    end

    % --- Build initial conditions from pathway definitions ---
    E0 = zeros(numE, 1);  N0 = zeros(numN, 1);  T0 = zeros(numE, numN);
    a_r = 1e20 * ones(numE, numN, numE, numN, numE, numN);  % default: off
    % ... (similar for g, d, b, f rate constant tensors) ...

    for i = 1:length(networkData.pathways)
        p = networkData.pathways{i};
        % Set concentrations (only non-redundant entries, converted µM → M)
        if ~pathwayData{i}.Redundant.cEi
            E0(p.i) = p.cEi * 1e-6;
        end
        % ... (same pattern for N0, T0, rate constants) ...
    end

    % --- Solve ODE system ---
    options = odeset('RelTol', 1e-12, 'AbsTol', 1e-12);
    [t, Y] = ode15s(@(t,y) f3_second_order(t, y, numE, numN, ...
                    a, a_r, b, f, f_r, d, d_r, g, ...
                    D, preqtime, intime, E_feed_vec, N_feed_vec, T_feed_mat), ...
                [0, t_end], initial_conditions, options);

    % --- Post-process: compute R_{ij} = total template across all complexes ---
    for itime = 1:size(Y, 1)
        T_t    = reshape(Y(itime, ...), [numE, numN]);
        ENTT_t = reshape(Y(itime, ...), [numE, numN, numE, numN, numE, numN]);
        TT_t   = reshape(Y(itime, ...), [numE, numN, numE, numN]);
        TTT_t  = reshape(Y(itime, ...), [numE, numN, numE, numN, numE, numN]);

        % R = free template + sum over all bound forms (ENTT, TT, TTT)
        Rmatrix = T_t ...
            + squeeze(sum(sum(sum(sum(ENTT_t,2),1),4),3)) ...
            + squeeze(sum(sum(TT_t,2),1)) + squeeze(sum(sum(TT_t,4),3)) ...
            + squeeze(sum(sum(sum(sum(TTT_t,2),1),4),3)) ...
            + squeeze(sum(sum(sum(sum(TTT_t,4),3),6),5)) ...
            + squeeze(sum(sum(sum(sum(TTT_t,6),5),2),1));
        R(itime,:,:) = Rmatrix;
    end
end
