% REDUNDANCY  Constraint propagation for reaction pathway parameters.
%
% When multiple pathways share species indices, their concentrations must
% be consistent. Detects overlaps and enforces consistency:
%   Pass 1 (horizontal): within a pathway — if (i',j')==(i'',j''), lock T''
%   Pass 2 (vertical):   between pathways — shared E_i, N_j, T, rates
%
% Visual feedback: light blue = authoritative, gray = locked duplicate.

function redundancy()
    global pathwayData;
    chosenIndices = find(cellfun(@(x) x.chooseButton.Value, pathwayData));
    if isempty(chosenIndices), return; end

    % === Pass 1: Horizontal (within each pathway) ===
    for idx = 1:length(chosenIndices)
        k = chosenIndices(idx);
        if pathwayData{k}.ip.Value == pathwayData{k}.ipp.Value && ...
           pathwayData{k}.jp.Value == pathwayData{k}.jpp.Value
            pathwayData{k}.cTippjpp.Value = pathwayData{k}.cTipjp.Value;
            pathwayData{k}.Redundant.cTippjpp = 1;
            pathwayData{k}.cTippjpp.BackgroundColor = [0.9 0.9 0.9];  % gray
        end
    end

    % === Pass 2: Vertical (between pathways) ===
    for i = 1:length(chosenIndices)
        for j = i+1:length(chosenIndices)
            pI = pathwayData{chosenIndices(i)};
            pJ = pathwayData{chosenIndices(j)};

            % Same enzyme index → link E_i concentrations
            if pI.i.Value == pJ.i.Value
                pathwayData{chosenIndices(j)}.cEi.Value = pI.cEi.Value;
                pathwayData{chosenIndices(j)}.Redundant.cEi = 1;
            end

            % Same (i,j) → link background rates g, b
            if pI.i.Value == pJ.i.Value && pI.j.Value == pJ.j.Value
                pathwayData{chosenIndices(j)}.g.Value = pI.g.Value;
                pathwayData{chosenIndices(j)}.b.Value = pI.b.Value;
                pathwayData{chosenIndices(j)}.Redundant.g = 1;
                pathwayData{chosenIndices(j)}.Redundant.b = 1;
            end

            % Cross-matching: T_{i'j'} of pathway I == T_{i''j''} of pathway J
            if pI.ip.Value == pJ.ipp.Value && pI.jp.Value == pJ.jpp.Value
                pathwayData{chosenIndices(j)}.cTippjpp.Value = pI.cTipjp.Value;
                pathwayData{chosenIndices(j)}.Redundant.cTippjpp = 1;
            end

            % All 6 indices match → link association and fragmentation rates
            if pI.i.Value == pJ.i.Value && pI.j.Value == pJ.j.Value && ...
               pI.ip.Value == pJ.ip.Value && pI.jp.Value == pJ.jp.Value && ...
               pI.ipp.Value == pJ.ipp.Value && pI.jpp.Value == pJ.jpp.Value
                pathwayData{chosenIndices(j)}.a_r.Value = pI.a_r.Value;
                pathwayData{chosenIndices(j)}.f.Value = pI.f.Value;
                pathwayData{chosenIndices(j)}.Redundant.a_r = 1;
                pathwayData{chosenIndices(j)}.Redundant.f = 1;
            end
        end
    end
end
