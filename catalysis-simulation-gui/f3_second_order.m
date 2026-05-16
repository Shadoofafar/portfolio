% F3_SECOND_ORDER  ODE right-hand side for autocatalytic reaction network.
%
% Computes time derivatives of 6 chemical species stored as multidimensional
% tensors: E(i), N(j), T(i,j), ENTT(i,j,i',j',i'',j''), TT, TTT.
% Supports both batch and CSTR (continuous stirred-tank reactor) modes
% with time-phased feed switching.
%
% State vector size grows as O((numE * numN)^3) — e.g. for 3×3 species,
% the TTT tensor alone has 729 elements.

function dy = f3_second_order(t, y, numE, numN, a, a_r, b, f, f_r, d, d_r, g, ...
    D, preqtime, intime, E_feed_vec, N_feed_vec, T_feed_mat)

    % --- Unpack flattened state vector into multidimensional arrays ---
    numEN = numE * numN;
    % ... (index boundary computation) ...
    E    = y(1:numE);
    N    = y(numE+1:numE+numN);
    T    = reshape(y(numE+numN+1:numE+numN+numEN), [numE, numN]);
    ENTT = reshape(...);  % 6D tensor: [numE, numN, numE, numN, numE, numN]
    TT   = reshape(...);  % 4D tensor: [numE, numN, numE, numN]
    TTT  = reshape(...);  % 6D tensor

    dE = zeros(numE, 1);  dN = zeros(numN, 1);  dT = zeros(numE, numN);
    % ... (initialize dENTT, dTT, dTTT as zero tensors) ...

    % === Core chemical kinetics: 6 nested loops over all index combinations ===
    for i = 1:numE
        for j = 1:numN
            % Background (uncatalyzed) template formation: E_i + N_j -> T_ij
            dg = g(i,j) * E(i) * N(j);
            dE(i) = dE(i) - dg;
            dN(j) = dN(j) - dg;
            dT(i,j) = dT(i,j) + dg;

            for ip = 1:numE
                for jp = 1:numN
                    for ipp = 1:numE
                        for jpp = 1:numN
                            % Association: E + N + TT <-> ENTT
                            da = a*E(i)*N(j)*TT(ip,jp,ipp,jpp) ...
                                 - a_r(i,j,ip,jp,ipp,jpp)*ENTT(i,j,ip,jp,ipp,jpp);
                            % Catalytic turnover: ENTT -> products
                            db = b(i,j) * ENTT(i,j,ip,jp,ipp,jpp);
                            % Fragmentation: TTT <-> T + TT
                            df = f(i,j,ip,jp,ipp,jpp)*TTT(i,j,ip,jp,ipp,jpp) ...
                                 - f_r*T(i,j)*TT(ip,jp,ipp,jpp);

                            dE(i) = dE(i) - da;
                            dN(j) = dN(j) - da;
                            dENTT(i,j,ip,jp,ipp,jpp) = dENTT(i,j,ip,jp,ipp,jpp) + da - db;
                            dTT(ip,jp,ipp,jpp)       = dTT(ip,jp,ipp,jpp) - da + df;
                            dTTT(i,j,ip,jp,ipp,jpp)  = dTTT(i,j,ip,jp,ipp,jpp) + db - df;
                            dT(i,j) = dT(i,j) + df;
                        end
                    end
                end
            end
        end
    end

    % === CSTR flow terms (time-phased operation) ===
    %   t < preqtime                → Batch (D_eff = 0)
    %   preqtime ≤ t ≤ preqtime+in → Feed ON (D_eff = D, inlet concentrations)
    %   t > preqtime + intime       → Washout (D_eff = D, inlet = 0)
    if D > 0
        if t < preqtime,         D_eff = 0;
        elseif t <= preqtime + intime, D_eff = D;  % feed phase
        else,                    D_eff = D;         % washout phase
        end

        dE = dE + D_eff * (E_in - E);   % monomers: flow + reaction
        dT = dT + D_eff * (T_in - T);   % templates: flow + reaction
        dENTT = dENTT - D_eff * ENTT;   % complexes: dilution only (no inlet)
        dTT   = dTT   - D_eff * TT;
        dTTT  = dTTT  - D_eff * TTT;
    end

    % Flatten back into column vector for ode15s
    dy = [dE; dN; reshape(dT,[numEN,1]); reshape(dENTT,...); ...
          reshape(dTT,...); reshape(dTTT,...)];
end
