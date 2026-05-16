function redundancy()
% REDUNDANCY  Constraint propagation for reaction pathway parameters.
%
%   When multiple reaction pathways share the same species indices, their
%   concentrations and rate constants must be consistent. This function
%   detects such overlaps and enforces consistency by:
%     1. Horizontal check — within a single pathway (e.g., T_{i'j'} == T_{i''j''})
%     2. Vertical check — between different pathways (e.g., same E_i or N_j)
%
%   Redundant fields are visually marked:
%     - Light blue [0.8 0.9 1] — First occurrence (authoritative value)
%     - Gray [0.9 0.9 0.9]     — Duplicate (locked to the first occurrence)
%
%   The redundancy flags (pathwayData{k}.Redundant.fieldName) are read by
%   RunNetwork1 to avoid double-counting initial conditions.

    global pathwayData;

    % Get indices of user-selected (chosen) pathways
    chosenIndices = find(cellfun(@(x) x.chooseButton.Value, pathwayData));
    if isempty(chosenIndices)
        return;
    end

    % ===== Pass 1: Horizontal Redundancy (within each pathway) =====
    % If (i',j') == (i'',j'') within a pathway, then cT_{i'j'} == cT_{i''j''}
    for idx = 1:length(chosenIndices)
        pathwayIdx = chosenIndices(idx);

        if (pathwayData{pathwayIdx}.ip.Value == pathwayData{pathwayIdx}.ipp.Value && ...
            pathwayData{pathwayIdx}.jp.Value == pathwayData{pathwayIdx}.jpp.Value)

            % Copy concentration from T' to T'' and mark as redundant
            pathwayData{pathwayIdx}.cTippjpp.Value = pathwayData{pathwayIdx}.cTipjp.Value;
            pathwayData{pathwayIdx}.Redundant.cTippjpp = 1;

            % Mark first occurrence as authoritative (light blue)
            if ~pathwayData{pathwayIdx}.Redundant.cTipjp
                pathwayData{pathwayIdx}.cTipjp.BackgroundColor = [0.8 0.9 1];
            end
            % Mark duplicate as locked (gray)
            pathwayData{pathwayIdx}.cTippjpp.BackgroundColor = [0.9 0.9 0.9];
        end
    end

    % ===== Pass 2: Vertical Redundancy (between pathways) =====
    for i = 1:length(chosenIndices)
        for j = i+1:length(chosenIndices)
            pathwayI = pathwayData{chosenIndices(i)};
            pathwayJ = pathwayData{chosenIndices(j)};

            % --- Check if enzyme index (i) matches ---
            if (pathwayI.i.Value == pathwayJ.i.Value)
                pathwayData{chosenIndices(j)}.cEi.Value = pathwayI.cEi.Value;
                pathwayData{chosenIndices(j)}.Redundant.cEi = 1;
                if ~pathwayI.Redundant.cEi
                    pathwayData{chosenIndices(i)}.cEi.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.cEi.BackgroundColor = [0.9 0.9 0.9];
            end

            % --- Check if nutrient index (j) matches ---
            if (pathwayI.j.Value == pathwayJ.j.Value)
                pathwayData{chosenIndices(j)}.cNj.Value = pathwayI.cNj.Value;
                pathwayData{chosenIndices(j)}.Redundant.cNj = 1;
                if ~pathwayI.Redundant.cNj
                    pathwayData{chosenIndices(i)}.cNj.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.cNj.BackgroundColor = [0.9 0.9 0.9];
            end

            % --- Check if both (i,j) match → link g and b rates ---
            if (pathwayI.i.Value == pathwayJ.i.Value && ...
                pathwayI.j.Value == pathwayJ.j.Value)
                pathwayData{chosenIndices(j)}.g.Value = pathwayI.g.Value;
                pathwayData{chosenIndices(j)}.b.Value = pathwayI.b.Value;
                pathwayData{chosenIndices(j)}.Redundant.g = 1;
                pathwayData{chosenIndices(j)}.Redundant.b = 1;
                if ~pathwayI.Redundant.g
                    pathwayData{chosenIndices(i)}.g.BackgroundColor = [0.8 0.9 1];
                end
                if ~pathwayI.Redundant.b
                    pathwayData{chosenIndices(i)}.b.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.g.BackgroundColor = [0.9 0.9 0.9];
                pathwayData{chosenIndices(j)}.b.BackgroundColor = [0.9 0.9 0.9];
            end

            % --- Check template index matches (direct and cross) ---
            if (pathwayI.ip.Value == pathwayJ.ip.Value && ...
                pathwayI.jp.Value == pathwayJ.jp.Value)
                pathwayData{chosenIndices(j)}.cTipjp.Value = pathwayI.cTipjp.Value;
                pathwayData{chosenIndices(j)}.Redundant.cTipjp = 1;
                if ~pathwayI.Redundant.cTipjp
                    pathwayData{chosenIndices(i)}.cTipjp.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.cTipjp.BackgroundColor = [0.9 0.9 0.9];
            end

            % Cross-matching: T_{i'j'} of pathway I == T_{i''j''} of pathway J
            if (pathwayI.ip.Value == pathwayJ.ipp.Value && ...
                pathwayI.jp.Value == pathwayJ.jpp.Value)
                pathwayData{chosenIndices(j)}.cTippjpp.Value = pathwayI.cTipjp.Value;
                pathwayData{chosenIndices(j)}.Redundant.cTippjpp = 1;
                if ~pathwayI.Redundant.cTipjp
                    pathwayData{chosenIndices(i)}.cTipjp.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.cTippjpp.BackgroundColor = [0.9 0.9 0.9];
            end

            % Cross-matching: T_{i''j''} of pathway I == T_{i'j'} of pathway J
            if (pathwayI.ipp.Value == pathwayJ.ip.Value && ...
                pathwayI.jpp.Value == pathwayJ.jp.Value)
                pathwayData{chosenIndices(j)}.cTipjp.Value = pathwayI.cTippjpp.Value;
                pathwayData{chosenIndices(j)}.Redundant.cTipjp = 1;
                if ~pathwayI.Redundant.cTippjpp
                    pathwayData{chosenIndices(i)}.cTippjpp.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.cTipjp.BackgroundColor = [0.9 0.9 0.9];
            end

            % --- Check if both template pairs match → link dimerization rate ---
            if (pathwayI.ip.Value == pathwayJ.ip.Value && ...
                pathwayI.jp.Value == pathwayJ.jp.Value && ...
                pathwayI.ipp.Value == pathwayJ.ipp.Value && ...
                pathwayI.jpp.Value == pathwayJ.jpp.Value)
                pathwayData{chosenIndices(j)}.d.Value = pathwayI.d.Value;
                pathwayData{chosenIndices(j)}.Redundant.d = 1;
                if ~pathwayI.Redundant.d
                    pathwayData{chosenIndices(i)}.d.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.d.BackgroundColor = [0.9 0.9 0.9];
            end

            % --- Check if ALL six indices match → link a_r and f rates ---
            if (pathwayI.i.Value == pathwayJ.i.Value && ...
                pathwayI.j.Value == pathwayJ.j.Value && ...
                pathwayI.ip.Value == pathwayJ.ip.Value && ...
                pathwayI.jp.Value == pathwayJ.jp.Value && ...
                pathwayI.ipp.Value == pathwayJ.ipp.Value && ...
                pathwayI.jpp.Value == pathwayJ.jpp.Value)
                pathwayData{chosenIndices(j)}.a_r.Value = pathwayI.a_r.Value;
                pathwayData{chosenIndices(j)}.f.Value = pathwayI.f.Value;
                pathwayData{chosenIndices(j)}.Redundant.a_r = 1;
                pathwayData{chosenIndices(j)}.Redundant.f = 1;
                if ~pathwayI.Redundant.a_r
                    pathwayData{chosenIndices(i)}.a_r.BackgroundColor = [0.8 0.9 1];
                end
                if ~pathwayI.Redundant.f
                    pathwayData{chosenIndices(i)}.f.BackgroundColor = [0.8 0.9 1];
                end
                pathwayData{chosenIndices(j)}.a_r.BackgroundColor = [0.9 0.9 0.9];
                pathwayData{chosenIndices(j)}.f.BackgroundColor = [0.9 0.9 0.9];
            end
        end
    end
end
