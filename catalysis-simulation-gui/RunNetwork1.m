function [tAll, RAll, TTTAll, TTAll, ENTTAll, TijAll, TipjpAll, TippjppAll] = ...
    RunNetwork1(networkData, preqtime, intime, vint, reactorVolume, ...
                Eint_feed, Nint_feed, Tint_feed)
% RUNNETWORK1  Core simulation solver for the catalytic reaction network.
%
%   Assembles initial conditions from pathway data, computes the CSTR
%   dilution rate, calls ode15s to integrate the ODE system, and processes
%   the raw solution into physically meaningful quantities (R_{ij} total
%   template counts, intermediate species).
%
%   Inputs:
%     networkData    — Struct with fields: numE, numN, t_end, pathways{...}
%     preqtime       — Pre-equilibration time (batch phase before feed)
%     intime         — Duration of inlet feed (CSTR intake phase)
%     vint           — Inlet volume flow [µL]
%     reactorVolume  — Reactor volume [µL]
%     Eint_feed      — Enzyme inlet concentrations [M] (numE×1)
%     Nint_feed      — Nutrient inlet concentrations [M] (numN×1)
%     Tint_feed      — Template inlet concentrations [M] (numE×numN)
%
%   Outputs:
%     tAll, RAll, etc. — Cell arrays of time vectors and concentration matrices.
%                        R_{ij} represents the TOTAL amount of template T_{ij}
%                        across all molecular complexes (free + bound).
%
%   NOTE: GUI inputs are in µM; internally everything is converted to M (×1e-6).
%         Plot outputs are converted back to µM (×1e6).

    global pathwayData aValue frValue drValue isCSTR debugMode;

    % Validate global parameters with sensible defaults
    if isempty(aValue) || ~isnumeric(aValue)
        aValue = 1e9;
        warning('aValue not set, using default: 1e9');
    end
    if isempty(frValue) || ~isnumeric(frValue)
        frValue = 10;
        warning('frValue not set, using default: 10');
    end
    if isempty(drValue) || ~isnumeric(drValue)
        drValue = 1e6;
        warning('drValue not set, using default: 1e6');
    end

    a   = aValue;
    f_r = frValue;
    d_r = drValue;

    % ===== Compute CSTR dilution rate =====
    % D = volumetric flow rate / reactor volume [1/s]
    % Only activates when: CSTR toggle is ON, feeds are non-zero, and
    % timing/volume parameters are physically meaningful
    E_feed_vec = Eint_feed(:);
    N_feed_vec = Nint_feed(:);
    T_feed_mat = Tint_feed;
    hasFeeds = any(E_feed_vec ~= 0) || any(N_feed_vec ~= 0) || any(T_feed_mat(:) ~= 0);

    if isCSTR && hasFeeds && intime > 0 && vint > 0 && reactorVolume > 0
        flowRate = vint / intime;        % [µL/s]
        D = flowRate / reactorVolume;    % [1/s]
    else
        D = 0;                           % Pure batch (no washout)
    end

    % ===== Extract network dimensions =====
    numE = networkData.numE;
    numN = networkData.numN;
    t_end = networkData.t_end;

    % ===== Configure ODE solver =====
    % Using ode15s (stiff solver) with tight tolerances for chemical accuracy
    options = odeset('RelTol', 1e-12, 'AbsTol', 1e-12);

    % ===== Compute index boundaries for the flattened state vector =====
    numEN  = numE * numN;
    numEN2 = numEN^2;
    numEN3 = numEN^3;
    lastE    = numE;
    lastN    = lastE + numN;
    lastT    = lastN + numEN;
    lastENTT = lastT + numEN3;
    lastTT   = lastENTT + numEN2;
    lastTTT  = lastTT + numEN3;

    % ===== Build initial conditions from pathway data =====
    E0    = zeros(numE, 1);
    N0    = zeros(numN, 1);
    T0    = zeros(numE, numN);
    ENTT0 = zeros(numE, numN, numE, numN, numE, numN);
    TT0   = zeros(numE, numN, numE, numN);
    TTT0  = zeros(numE, numN, numE, numN, numE, numN);

    % Rate constant tensors (default: very fast reverse = effectively off)
    a_r = 1e20 * ones(numE, numN, numE, numN, numE, numN);
    g   = zeros(numE, numN);
    d   = 1e20 * ones(numE, numN, numE, numN);
    b   = zeros(numE, numN);
    f   = 1e20 * ones(numE, numN, numE, numN, numE, numN);

    % Populate from each defined pathway
    for i = 1:length(networkData.pathways)
        p = networkData.pathways{i};

        % Set initial concentrations (convert µM → M)
        % Redundancy flags prevent overwriting linked parameters
        if ~pathwayData{i}.Redundant.cEi
            E0(p.i) = p.cEi * 1e-6;
        end
        if ~pathwayData{i}.Redundant.cNj
            N0(p.j) = p.cNj * 1e-6;
        end
        if ~pathwayData{i}.Redundant.cTipjp
            T0(p.ip, p.jp) = p.cTipjp * 1e-6;
        end
        if ~pathwayData{i}.Redundant.cTippjpp
            T0(p.ipp, p.jpp) = p.cTippjpp * 1e-6;
        end

        % Set rate constants (only non-redundant entries)
        if ~pathwayData{i}.Redundant.a_r
            a_r(p.i, p.j, p.ip, p.jp, p.ipp, p.jpp) = p.a_r;
        end
        if ~pathwayData{i}.Redundant.f
            f(p.i, p.j, p.ip, p.jp, p.ipp, p.jpp) = p.f;
        end
        if ~pathwayData{i}.Redundant.d
            d(p.ip, p.jp, p.ipp, p.jpp) = p.d;
        end
        if ~pathwayData{i}.Redundant.g
            g(p.i, p.j) = p.g;
        end
        if ~pathwayData{i}.Redundant.b
            b(p.i, p.j) = p.b;
        end
    end

    % ===== Assemble and solve the ODE system =====
    initial_conditions = [E0; N0; ...
        reshape(T0, [numEN, 1]); ...
        reshape(ENTT0, [numEN3, 1]); ...
        reshape(TT0, [numEN2, 1]); ...
        reshape(TTT0, [numEN3, 1])];

    [t, Y] = ode15s(@(t, y) f3_second_order( ...
                    t, y, numE, numN, ...
                    a, a_r, b, f, f_r, d, d_r, g, ...
                    D, preqtime, intime, ...
                    E_feed_vec, N_feed_vec, T_feed_mat), ...
                [0, t_end], initial_conditions, options);

    % ===== Post-process results =====
    % Compute R_{ij}: total template count across ALL molecular complexes
    % R_{ij} = T_{ij} + Σ ENTT + Σ TT + Σ TTT (summed over bound partners)
    ltime = size(Y, 1);
    R    = zeros(ltime, numE, numN);
    TTT  = zeros(ltime, numE, numN);
    TT   = zeros(ltime, numE, numN);
    ENTT = zeros(ltime, numE, numN);
    Tij  = zeros(ltime, numE, numN);

    for itime = 1:ltime
        T_t    = reshape(Y(itime, lastN+1:lastT),       [numE, numN]);
        ENTT_t = reshape(Y(itime, lastT+1:lastENTT),    [numE, numN, numE, numN, numE, numN]);
        TT_t   = reshape(Y(itime, lastENTT+1:lastTT),   [numE, numN, numE, numN]);
        TTT_t  = reshape(Y(itime, lastTT+1:lastTTT),    [numE, numN, numE, numN, numE, numN]);

        % Store resolved intermediates
        Tij(itime,:,:)  = T_t;
        ENTT(itime,:,:) = squeeze(sum(sum(sum(sum(ENTT_t, 2), 1), 4), 3));
        TT(itime,:,:)   = squeeze(sum(sum(TT_t, 2), 1));
        TTT(itime,:,:)  = squeeze(sum(sum(sum(sum(TTT_t, 2), 1), 4), 3));

        % Total R_{ij} = free template + all bound forms
        Rmatrix = T_t;
        Rmatrix = Rmatrix + squeeze(sum(sum(sum(sum(ENTT_t,2),1),4),3)) ...
                          + squeeze(sum(sum(sum(sum(ENTT_t,2),1),6),5));
        Rmatrix = Rmatrix + squeeze(sum(sum(TT_t,2),1)) ...
                          + squeeze(sum(sum(TT_t,4),3));
        Rmatrix = Rmatrix + squeeze(sum(sum(sum(sum(TTT_t,2),1),4),3)) ...
                          + squeeze(sum(sum(sum(sum(TTT_t,4),3),6),5)) ...
                          + squeeze(sum(sum(sum(sum(TTT_t,6),5),2),1));
        R(itime,:,:) = Rmatrix;
    end

    % Package into cell arrays (for compatibility with multi-scenario runner)
    tAll{1}        = t;
    RAll{1}        = R;
    TTTAll{1}      = TTT;
    TTAll{1}       = TT;
    ENTTAll{1}     = ENTT;
    TijAll{1}      = Tij;
    TipjpAll{1}    = squeeze(sum(sum(TT_t, 2), 1));   % Marginal over i'',j''
    TippjppAll{1}  = squeeze(sum(sum(TT_t, 4), 3));   % Marginal over i',j'

    % Save results for offline analysis
    save('network_simulation_results.mat', ...
         'tAll', 'RAll', 'TTTAll', 'TTAll', 'ENTTAll', ...
         'TijAll', 'TipjpAll', 'TippjppAll', 'networkData');

    % Export numerical results to text file (all values in micromolar)
    fileID = fopen('simulation_results.txt', 'w');
    if fileID ~= -1
        fprintf(fileID, '# Simulation Results (all concentrations in µM)\n');
        fprintf(fileID, '%-15s', '# Time');
        for i = 1:numE
            for j = 1:numN
                fprintf(fileID, '%-15s', sprintf('R_%d%d', i, j));
            end
        end
        fprintf(fileID, '\n');
        for idx = 1:length(t)
            fprintf(fileID, '%-15.6g', t(idx));
            for i = 1:numE
                for j = 1:numN
                    fprintf(fileID, '%-15.6g', R(idx, i, j) * 1e6);
                end
            end
            fprintf(fileID, '\n');
        end
        fclose(fileID);
    end
end
