function dy = f3_second_order(t, y, numE, numN, a, a_r, b, f, f_r, d, d_r, g, ...
    D, preqtime, intime, E_feed_vec, N_feed_vec, T_feed_mat)
% F3_SECOND_ORDER  ODE right-hand side for the autocatalytic reaction network.
%
%   Computes the time derivatives of all chemical species:
%     E(i)           — Enzyme/activator concentrations
%     N(j)           — Nutrient/substrate concentrations
%     T(i,j)         — Template concentrations
%     ENTT(i,j,i',j',i'',j'')  — Ternary complex: enzyme-nutrient bound to template duplex
%     TT(i',j',i'',j'')        — Template duplex concentrations
%     TTT(i,j,i',j',i'',j'')   — Template triplex concentrations
%
%   Inputs:
%     t        — Current time (used for CSTR phase switching)
%     y        — State vector (all species flattened into a column vector)
%     numE     — Number of enzyme species
%     numN     — Number of nutrient species
%     a, a_r   — Association and reverse association rate constants
%     b        — Catalytic turnover rate
%     f, f_r   — Forward and reverse fragmentation rates
%     d, d_r   — Dimerization and reverse dimerization rates
%     g        — Background (uncatalyzed) reaction rate
%     D        — Maximum dilution rate [1/s] (0 for batch mode)
%     preqtime — Pre-equilibration time before CSTR feed begins
%     intime   — Duration of the inlet feed phase
%     E_feed_vec, N_feed_vec, T_feed_mat — Inlet concentrations for CSTR mode

    % ===== Unpack state vector into multidimensional arrays =====
    numEN = numE * numN;
    numEN2 = numEN^2;
    numEN3 = numEN^3;
    lastE = numE;
    lastN = lastE + numN;
    lastT = lastN + numEN;
    lastENTT = lastT + numEN3;
    lastTT = lastENTT + numEN2;
    lastTTT = lastTT + numEN3;

    E    = y(1:lastE);
    N    = y(lastE+1:lastN);
    T    = reshape(y(lastN+1:lastT),       [numE, numN]);
    ENTT = reshape(y(lastT+1:lastENTT),    [numE, numN, numE, numN, numE, numN]);
    TT   = reshape(y(lastENTT+1:lastTT),   [numE, numN, numE, numN]);
    TTT  = reshape(y(lastTT+1:lastTTT),    [numE, numN, numE, numN, numE, numN]);

    % ===== Initialize derivative arrays =====
    dE    = zeros(numE, 1);
    dN    = zeros(numN, 1);
    dT    = zeros(numE, numN);
    dENTT = zeros(numE, numN, numE, numN, numE, numN);
    dTT   = zeros(numE, numN, numE, numN);
    dTTT  = zeros(numE, numN, numE, numN, numE, numN);

    % ===== Chemical kinetics (6 nested loops over all index combinations) =====
    for i = 1:numE
        for j = 1:numN
            % Background (uncatalyzed) template formation: E_i + N_j -> T_ij
            dg = g(i,j) * E(i) * N(j);
            dE(i)   = dE(i) - dg;
            dN(j)   = dN(j) - dg;
            dT(i,j) = dT(i,j) + dg;

            for ip = 1:numE
                for jp = 1:numN
                    for ipp = 1:numE
                        for jpp = 1:numN
                            % Association: E_i + N_j + TT_{i'j',i''j''} <-> ENTT_{ij,i'j',i''j''}
                            da = a * E(i) * N(j) * TT(ip,jp,ipp,jpp) ...
                                 - a_r(i,j,ip,jp,ipp,jpp) * ENTT(i,j,ip,jp,ipp,jpp);

                            % Catalytic turnover: ENTT -> T_ij + TT (product release)
                            db = b(i,j) * ENTT(i,j,ip,jp,ipp,jpp);

                            % Fragmentation: TTT <-> T_ij + TT_{i'j',i''j''}
                            df = f(i,j,ip,jp,ipp,jpp) * TTT(i,j,ip,jp,ipp,jpp) ...
                                 - f_r * T(i,j) * TT(ip,jp,ipp,jpp);

                            % Update derivatives
                            dE(i)   = dE(i) - da;
                            dN(j)   = dN(j) - da;
                            dENTT(i,j,ip,jp,ipp,jpp) = dENTT(i,j,ip,jp,ipp,jpp) + da - db;
                            dTT(ip,jp,ipp,jpp)       = dTT(ip,jp,ipp,jpp) - da + df;
                            dTTT(i,j,ip,jp,ipp,jpp)  = dTTT(i,j,ip,jp,ipp,jpp) + db - df;
                            dT(i,j)                  = dT(i,j) + df;
                        end
                    end
                end
            end
        end
    end

    % Template dimerization: T_{i'j'} + T_{i''j''} <-> TT_{i'j',i''j''}
    for ip = 1:numE
        for jp = 1:numN
            for ipp = 1:numE
                for jpp = 1:numN
                    dd = d(ip,jp,ipp,jpp) * TT(ip,jp,ipp,jpp) ...
                         - d_r * T(ip,jp) * T(ipp,jpp);

                    dTT(ip,jp,ipp,jpp) = dTT(ip,jp,ipp,jpp) - dd;
                    dT(ip,jp)          = dT(ip,jp) + dd;
                    dT(ipp,jpp)        = dT(ipp,jpp) + dd;
                end
            end
        end
    end

    % ===== CSTR flow terms (time-phased operation) =====
    % D is the maximum dilution rate. Effective rate depends on time phase:
    %   t < preqtime               : Closed batch (D_eff = 0)
    %   preqtime <= t <= preqtime+intime : Feed ON (D_eff = D, inlet = feed vectors)
    %   t > preqtime + intime      : Washout (D_eff = D, inlet = 0)

    if D <= 0
        D_eff = 0;
        E_in  = zeros(numE, 1);
        N_in  = zeros(numN, 1);
        T_in  = zeros(numE, numN);
    else
        if t < preqtime
            D_eff = 0;
            E_in  = zeros(numE, 1);
            N_in  = zeros(numN, 1);
            T_in  = zeros(numE, numN);
        elseif t <= preqtime + intime
            D_eff = D;
            E_in  = E_feed_vec;
            N_in  = N_feed_vec;
            T_in  = T_feed_mat;
        else
            D_eff = D;
            E_in  = zeros(numE, 1);
            N_in  = zeros(numN, 1);
            T_in  = zeros(numE, numN);
        end
    end

    if D_eff ~= 0
        % Monomers: reaction + continuous feed
        dE = dE + D_eff * (E_in - E);
        dN = dN + D_eff * (N_in - N);

        % Templates: reaction + continuous feed
        dT = dT + D_eff * (T_in - T);

        % Complexes: only dilution (no inlet of complexes)
        dENTT = dENTT - D_eff * ENTT;
        dTT   = dTT   - D_eff * TT;
        dTTT  = dTTT  - D_eff * TTT;
    end

    % ===== Flatten derivatives back into a column vector =====
    dy = [dE; dN; reshape(dT, [numEN, 1]); ...
          reshape(dENTT, [numEN3, 1]); ...
          reshape(dTT, [numEN2, 1]); ...
          reshape(dTTT, [numEN3, 1])];
end
