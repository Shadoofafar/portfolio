% GUI: always type µM (pathways cEi=100, feeds Eint=100, etc.)
% Internal ODE: always M (everything multiplied by 1e-6)
% Plots/exports: multiplied back by 1e6 and labeled µM.
% Run this function to open GUI
function CatalysisSimulationGUI()
    % Main GUI function for Catalysis Simulation
    % Clear all variables and globals
    clear global;disp('globals cleared');
    % clear all;disp('globals cleared');
    % Initialize global variables
    % At the top of CatalysisSimulationGUI function
    global pathwayData statusText numE numN numENLabel numEField ...
       numNField aValue frValue drValue aField frField drField ...
       t_endField RSelector RijButtons mainPanel plotAllRsButton debugMode ...
       flowRate volumeField reactorVolume isCSTR preqtime intime vint ...
       Eint Nint Tint EintRows NintRows TintRows feedRows ...
       preqtimeField intimeField vintField;

    pathwayData = {};
    numE = 3; % Default value
    numN = 3; % Default value

    if isempty(aValue) || ~isnumeric(aValue)
        aValue = 1e9;
    end
    if isempty(frValue) || ~isnumeric(frValue)
        frValue = 10;
    end
    if isempty(drValue) || ~isnumeric(drValue)
        drValue = 1e6;
    end
    
    if isempty(aValue) || ~isnumeric(aValue)
    aValue = 1e9;
    end
    if isempty(frValue) || ~isnumeric(frValue)
        frValue = 10;
    end
    if isempty(drValue) || ~isnumeric(drValue)
        drValue = 1e6;
    end
    
    % CSTR parameters
    isCSTR        = false;         % start in batch mode
    reactorVolume = 1;             % µL
    preqtime      = 120;           % pre-equilibration time (s)
    intime        = 3600;          % intake time (s)
    vint          = 0.3;           % intake volume (µL)
    Eint          = repmat(0, numE, 1);    % length numE
    Nint          = repmat(0, numN, 1);    % length numN
    Tint          = repmat(0, numE, numN);  % numE x numN
    EintRows = {};
    NintRows = {};
    TintRows = {};

    % Create main figure
    fig = uifigure('Name', 'Catalysis Simulation GUI', 'Position', [30, 30, 1550, 800]);
    % Add keyboard event listener to the figure
    fig.KeyPressFcn = @handleKeyPress;

    % Create UI components
    createUIComponents(fig);

    % Add initial pathway
    addPathway(fig);

    % Refresh display
    refreshDisplay(fig);
    updateRijSelection();
    % Helper functions
    function createUIComponents(fig)
        % Create main panel
        mainPanel = uipanel(fig, 'Position', [10, 10, 1010, 780]);
        % Add Pathway button
        uibutton(mainPanel, 'push', 'Text', '+', 'Position', [20, 740, 30, 22], ...
            'ButtonPushedFcn', @(btn, event) addPathway(fig), 'Tooltip', 'Press ''a'' to add pathway. Press d then a number of Pathway to choose/unchoose the selection of that pathway');
    
        % Save Network button
        uibutton(mainPanel, 'push', 'Text', 'Save Network', 'Position', [60, 740, 100, 22], ...
            'ButtonPushedFcn', @(btn, event) saveNetwork(fig), 'Tooltip', 'Press Ctrl+a to save network');
    
        % Load Network button
        uibutton(mainPanel, 'push', 'Text', 'Load Network', 'Position', [170, 740, 100, 22], ...
            'ButtonPushedFcn', @(btn, event) loadNetwork(fig),'Tooltip', 'Press ''e'' to load network');
    
        % Clear All button
        uibutton(mainPanel, 'push', 'Text', 'Clear All', 'Position', [280, 740, 100, 22], ...
            'ButtonPushedFcn', @(btn, event) clearAll(fig), 'Tooltip', 'Press Ctrl+c to clear all');
    
        % Run Network button
        uibutton(mainPanel, 'push', 'Text', 'Run Network', 'Position', [390, 740, 100, 22], ...
            'ButtonPushedFcn', @(btn, event) runNetwork(fig), 'Tooltip', 'Press ''r'' to run network');
    
        % Choose All Pathways button
        uibutton(mainPanel, 'push', 'Text', 'Choose All Pathways', 'Position', [500, 740, 120, 22], ...
            'ButtonPushedFcn', @(btn, event) chooseAllPathways(fig), 'Tooltip', 'Press ''w'' to choose all pathways');
        % Add field for t_end
        uilabel(mainPanel, 'Position', [850, 740, 50, 22], 'Text', 't,(s/a.u.):');
        t_endField = uieditfield(mainPanel, 'numeric', 'Position', [900, 740, 50, 22], ...
        'Value', 5000, 'ValueChangedFcn', @updateTend);
    
        % Add fields for numE and numN
        uilabel(mainPanel, 'Position', [630, 740, 50, 22], 'Text', 'Num E:');
        numEField = uieditfield(mainPanel, 'numeric', 'Position', [680, 740, 50, 22], ...
            'Value', numE, 'ValueChangedFcn', @updateNumE);
    
        uilabel(mainPanel, 'Position', [740, 740, 50, 22], 'Text', 'Num N:');
        numNField = uieditfield(mainPanel, 'numeric', 'Position', [790, 740, 50, 22], ...
            'Value', numN, 'ValueChangedFcn', @updateNumN);
        debugMode = false;
        
        uilabel(mainPanel, 'Position', [780, 710, 20, 22], 'Text', 'a:');
        aField = uieditfield(mainPanel, 'numeric', 'Position', [795, 710, 60, 22], ...
            'Value', aValue, 'ValueChangedFcn', @updateA);
        
        uilabel(mainPanel, 'Position', [860, 710, 30, 22], 'Text', 'f_r:');
        frField = uieditfield(mainPanel, 'numeric', 'Position', [880, 710, 40, 22], ...
            'Value', frValue, 'ValueChangedFcn', @updateFr);
        
        uilabel(mainPanel, 'Position', [930, 710, 30, 22], 'Text', 'd_r:');
        drField = uieditfield(mainPanel, 'numeric', 'Position', [950, 710, 55, 22], ...
            'Value', drValue, 'ValueChangedFcn', @updateDr);
        % After Add Rs / Reac.order buttons:
        % clearRButton = uibutton(mainPanel, 'push', ...
        %     'Text', 'Clear Rs', ...
        %     'Position', [850, 350, 55, 40], ...
        %     'ButtonPushedFcn', @ClearAllRij);
        
        % CSTR buttons
        % Create a “CSTR Controls” panel on the right
        cstrPanel = uipanel(fig, ...
            'Title', 'CSTR Controls', ...
            'FontSize', 14, ...
            'Position', [1020, 10, 500, 780]);

        % CSTR Mode toggle
        cstrToggle = uibutton(cstrPanel, 'state', ...
            'Text', 'CSTR Mode: Off', ...
            'Position', [20, 720, 140, 30], ...
            'ValueChangedFcn', @toggleCSTRMode);

        % Pre-equilibration time
        uilabel(cstrPanel, ...
            'Position', [20, 690, 120, 22], ...
            'Text', 'preqtime (s):');
        preqtimeField = uieditfield(cstrPanel, 'numeric', ...
            'Position', [100, 690, 50, 22], ...
            'Value', preqtime, ...
            'ValueChangedFcn', @updatePreqtime);

        % Intake time
        uilabel(cstrPanel, ...
            'Position', [180, 690, 120, 22], ...
            'Text', 'intime (s):');
        intimeField = uieditfield(cstrPanel, 'numeric', ...
            'Position', [260, 690, 50, 22], ...
            'Value', intime, ...
            'ValueChangedFcn', @updateIntime);

        % Intake volume
        uilabel(cstrPanel, ...
            'Position', [20, 660, 120, 22], ...
            'Text', 'vint (µL):');
        vintField = uieditfield(cstrPanel, 'numeric', ...
            'Position', [100, 660, 50, 22], ...
            'Value', vint, ...
            'ValueChangedFcn', @updateVint);
        % Reactor volume
        uilabel(cstrPanel, ...
            'Position', [180, 660, 120, 22], ...
            'Text', 'Volume (µL):');
        volumeField = uieditfield(cstrPanel, 'numeric', ...
            'Position', [260, 660, 50, 22], ...
            'Value', reactorVolume, ...
            'ValueChangedFcn', @updateVolume);
        

        % Base positions for feed rows
        eintBaseY  = 600;   % Eint rows start here
        nintBaseY  = 600;   % Nint rows start here (to the right)
        tintBaseY  = 520;   % Tint rows block below
        feedRowH   = 22;
        feedRowStep = feedRowH + 4;

        % Row of +Tint+, +Eint+, +Nint+ buttons
        tintBtn = uibutton(cstrPanel, 'push', ...
            'Text', '+Tint+', ...
            'Position', [20, 630, 70, 22], ...
            'ButtonPushedFcn', @createTintRow);

        eintBtn = uibutton(cstrPanel, 'push', ...
            'Text', '+Eint+', ...
            'Position', [100, 630, 70, 22], ...
            'ButtonPushedFcn', @createEintRow);

        nintBtn = uibutton(cstrPanel, 'push', ...
            'Text', '+Nint+', ...
            'Position', [180, 630, 70, 22], ...
            'ButtonPushedFcn', @createNintRow);

               % === Unified feed rows (Eint / Nint / Tint) =======================
        % All rows share one vertical stack, so no gaps after deletions.
        feedBaseY   = eintBaseY;        % top Y for first row
        feedRows    = {};               % ordered list of all rows (any type)

        % Helper: compute Y for row k (1-based)
        getRowY = @(k) feedBaseY - (k-1)*feedRowStep;

        % createEintRow
        % -------------
        % Adds a new inlet row for E-species feed (Eint): lets the user specify
        % which Ei and at what inlet concentration it enters the CSTR.
        %------------------ create Eint row --------------------------------
        function createEintRow(~, ~)
            idx = numel(feedRows) + 1;          % global row index
            y   = getRowY(idx);
            x0  = 20;                           % left margin

            r.type      = 'Eint';
            r.idxLabel  = uilabel(cstrPanel, ...
                           'Position',[x0, y, 18, feedRowH], ...
                           'Text', num2str(idx));      % pathway number

            r.iLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+20, y, 15, feedRowH], ...
                           'Text','i:');
            r.iField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+35, y, 35, feedRowH], ...
                   'Limits',[1 Inf], 'RoundFractionalValues',true, ...
                   'Value', 1, ...
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());   
            r.cLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+75, y, 35, feedRowH], ...
                           'Text','Ei:');
            r.cField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+115, y, 60, feedRowH], ...
                   'Value', 100, ...
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());

            r.deleteBtn = uibutton(cstrPanel,'push', ...
                           'Text','-', ...
                           'Position',[x0+180, y, 25, feedRowH], ...
                           'ButtonPushedFcn', @(btn,evt) deleteFeedRow(btn));

            feedRows{idx} = r;
            EintRows{end+1} = r;
            % run redundancy check on creation
            updateCSTRRedundancy();
        end
        % createNintRow
        % -------------
        % Adds a new inlet row for N-species feed (Nint): lets the user specify
        % which Nj and at what inlet concentration it enters the CSTR.
        %------------------ create Nint row --------------------------------
        function createNintRow(~, ~)
            idx = numel(feedRows) + 1;
            y   = getRowY(idx);
            x0  = 20;

            r.type      = 'Nint';
            r.idxLabel  = uilabel(cstrPanel, ...
                           'Position',[x0, y, 18, feedRowH], ...
                           'Text', num2str(idx));

            r.jLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+20, y, 15, feedRowH], ...
                           'Text','j:');
            r.jField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+35, y, 35, feedRowH], ...
                   'Limits',[1 Inf], 'RoundFractionalValues',true, ...
                   'Value', 1, ...
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());

            r.cLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+75, y, 35, feedRowH], ...
                           'Text','Nj:');
            r.cField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+115, y, 60, feedRowH], ...
                   'Value', 100, ...   % 100 µM
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());

            r.deleteBtn = uibutton(cstrPanel,'push', ...
                           'Text','-', ...
                           'Position',[x0+180, y, 25, feedRowH], ...
                           'ButtonPushedFcn', @(btn,evt) deleteFeedRow(btn));

            feedRows{idx} = r;
            NintRows{end+1} = r;
            % redundancy check
            updateCSTRRedundancy();
        end
        % createTintRow
        % -------------
        % Adds a new inlet row for template feed (Tint): defines which Tij complex
        % is continuously supplied to the CSTR and at what concentration.
        %------------------ create Tint row --------------------------------
        function createTintRow(~, ~)
            idx = numel(feedRows) + 1;
            y   = getRowY(idx);
            x0  = 20;

            r.type      = 'Tint';
            r.idxLabel  = uilabel(cstrPanel, ...
                           'Position',[x0, y, 18, feedRowH], ...
                           'Text', num2str(idx));

            r.iLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+20, y, 15, feedRowH], ...
                           'Text','i:');
            r.iField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+35, y, 35, feedRowH], ...
                   'Limits',[1 Inf], 'RoundFractionalValues',true, ...
                   'Value', 1, ...
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());

            r.jLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+75, y, 15, feedRowH], ...
                           'Text','j:');
            r.jField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+90, y, 35, feedRowH], ...
                   'Limits',[1 Inf], 'RoundFractionalValues',true, ...
                   'Value', 1, ...
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());

            r.cLabel    = uilabel(cstrPanel, ...
                           'Position',[x0+130, y, 40, feedRowH], ...
                           'Text','Tij:');
            r.cField    = uieditfield(cstrPanel,'numeric', ...
                   'Position',[x0+175, y, 60, feedRowH], ...
                   'Value', 100, ...
                   'ValueChangedFcn', @(src,evt)updateCSTRRedundancy());

            r.deleteBtn = uibutton(cstrPanel,'push', ...
                           'Text','-', ...
                           'Position',[x0+240, y, 25, feedRowH], ...
                           'ButtonPushedFcn', @(btn,evt) deleteFeedRow(btn));

            feedRows{idx} = r;
            TintRows{end+1} = r;
            % redundancy check
            updateCSTRRedundancy();
        end
        % deleteFeedRow
        % -------------
        % Deletes a single Eint/Nint/Tint feed row from the CSTR panel and then
        % compacts the remaining rows.
        function deleteFeedRow(btn)
            % find which row this button belongs to
            idx = [];
            for k = 1:numel(feedRows)
                if isequal(feedRows{k}.deleteBtn, btn)
                    idx = k;
                    break;
                end
            end
            if isempty(idx), return; end

            r = feedRows{idx};

            % delete all HG objects belonging to that row
            fieldNames = fieldnames(r);
            for f = 1:numel(fieldNames)
                h = r.(fieldNames{f});
                if ishghandle(h)
                    delete(h);
                end
            end

            % remove row from ordered list & re-pack
            feedRows(idx) = [];
            relayoutFeedRows();
            % new: re-check redundancy after deletion
            updateCSTRRedundancy();
        end
        % relayoutFeedRows
        % ----------------
        % Recomputes vertical positions and row numbers for all remaining CSTR
        % feed rows after any insertion/deletion.
        function relayoutFeedRows()
            % re-compute Y and row numbers for all remaining rows
            for k = 1:numel(feedRows)
                y = getRowY(k);
                r = feedRows{k};

                r.idxLabel.Position(2) = y;
                r.idxLabel.Text        = num2str(k);  % pathway number

                switch r.type
                    case 'Eint'
                        r.iLabel.Position(2)    = y;
                        r.iField.Position(2)    = y;
                        r.cLabel.Position(2)    = y;
                        r.cField.Position(2)    = y;
                        r.deleteBtn.Position(2) = y;
                    case 'Nint'
                        r.jLabel.Position(2)    = y;
                        r.jField.Position(2)    = y;
                        r.cLabel.Position(2)    = y;
                        r.cField.Position(2)    = y;
                        r.deleteBtn.Position(2) = y;
                    case 'Tint'
                        r.iLabel.Position(2)    = y;
                        r.iField.Position(2)    = y;
                        r.jLabel.Position(2)    = y;
                        r.jField.Position(2)    = y;
                        r.cLabel.Position(2)    = y;
                        r.cField.Position(2)    = y;
                        r.deleteBtn.Position(2) = y;
                end

                feedRows{k} = r;   % store back updated struct
            end
        end
 
        % --------------------------------
        % All feed rows live in a single ordered list (may already exist)
        if isempty(feedRows)
            feedRows = {};
        end
        % setCSTREnabled
        % --------------
        % Enables or disables all CSTR-related controls (feed rows, time/volume
        % fields, add-buttons) when CSTR is toggled on/off.
        % ---------- CSTR enable/disable helpers -------------------------
        function setCSTREnabled(isEnabled)
            % Enable/disable all CSTR-related controls       
            if isEnabled
                enableState = 'on';
            else
                enableState = 'off';
            end
        
            % small helper that can accept scalar or vector of handles
            function enableList(list)
                if isempty(list), return; end
                list = list(:).';  % row
                for hh = list
                    if ishghandle(hh) && isprop(hh, 'Enable')
                        hh.Enable = enableState;
                    end
                end
            end
        
            % 1) Static controls (EXCEPT the toggle itself – we keep it usable)
            staticControls = [preqtimeField, intimeField, vintField, volumeField, ...
                              tintBtn, eintBtn, nintBtn];
            enableList(staticControls);
        
            % 2) Dynamic Eint rows
            for k = 1:numel(EintRows)
                row = EintRows{k};
                % fields that exist in createEintRow:
                %   iField, cField, deleteBtn
                handles = [row.iField, row.cField, row.deleteBtn];
                enableList(handles);
            end
        
            % 3) Dynamic Nint rows
            for k = 1:numel(NintRows)
                row = NintRows{k};
                % fields that exist in createNintRow:
                %   jField, cField, deleteBtn
                handles = [row.jField, row.cField, row.deleteBtn];
                enableList(handles);
            end
        
            % 4) Dynamic Tint rows
            for k = 1:numel(TintRows)
                row = TintRows{k};
                % fields that exist in createTintRow:
                %   iField, jField, cField, deleteBtn
                handles = [row.iField, row.jField, row.cField, row.deleteBtn];
                enableList(handles);
            end
        end

        % toggleCSTRMode
        % --------------
        % Callback for the “CSTR Mode” state button: flips the global isCSTR flag,
        % updates button text/background, and calls setCSTREnabled accordingly.
        function toggleCSTRMode(src, ~)
            % keep the global flag in sync with the toggle
            isCSTR = logical(src.Value);

            if isCSTR
                src.Text = 'CSTR Mode: On';
                src.BackgroundColor = [0.7 1.0 0.7];
            else
                src.Text = 'CSTR Mode: Off';
                src.BackgroundColor = [0.94 0.94 0.94];
            end

            setCSTREnabled(isCSTR);
        end

        % ---- initial state: CSTR OFF and everything disabled -----------
        cstrToggle.Value = 0;     % make sure it's off
        setCSTREnabled(false);

        
        function updatePreqtime(src, ~)
            % src is the NumericEditField
            preqtime = src.Value;
            fprintf('preqtime updated to %.3g s\n', preqtime);
        end
        
        function updateIntime(src, ~)
            intime = src.Value;
            fprintf('intime updated to %.3g s\n', intime);
        end
        
        function updateVint(src, ~)
            vint = src.Value;
            fprintf('vint (inlet volume) updated to %.3g µL\n', vint);
        end
        
        function updateVolume(src, ~)
            reactorVolume = src.Value;
            fprintf('reactorVolume updated to %.3g µL\n', reactorVolume);
        end
        
        function updateCSTRRedundancy()
            % Handles redundant rows in the CSTR feed panel.
            % Rules:
            %   - Eint rows: duplicates by same i
            %   - Nint rows: duplicates by same j
            %   - Tint rows: duplicates by same (i,j)
            %
            % For duplicates:
            %   * concentration is forced to that of the first row
            %   * background color is changed
            %   * row.redundant = true          
            if isempty(feedRows)
                return;
            end
            
            % Colors: adjust if you want different shades
            defaultColor   = [1 1 1];        % normal
            redundantColor = [0.9 0.95 1.0]; % light blue for redundant
            
            % 1) reset all rows
            for k = 1:numel(feedRows)
                row = feedRows{k};
                if isempty(row), continue; end
                
                if isfield(row, 'cField') && isvalid(row.cField)
                    row.cField.BackgroundColor = defaultColor;
                end
                
                % optional flag
                row.redundant = false;
                feedRows{k} = row;
            end
            
            % 2) scan in order and mark duplicates
            seen = containers.Map('KeyType','char','ValueType','double'); % key -> first concentration
            
            for k = 1:numel(feedRows)
                row = feedRows{k};
                if isempty(row), continue; end
                
                % Build key by row type
                key = '';
                switch row.type
                    case 'Eint'
                        if isempty(row.iField) || ~isvalid(row.iField), continue; end
                        i = row.iField.Value;
                        if isnan(i), continue; end
                        key = sprintf('E_%d', i);
                        
                    case 'Nint'
                        if isempty(row.jField) || ~isvalid(row.jField), continue; end
                        j = row.jField.Value;
                        if isnan(j), continue; end
                        key = sprintf('N_%d', j);
                        
                    case 'Tint'
                        if isempty(row.iField) || isempty(row.jField) || ...
                           ~isvalid(row.iField) || ~isvalid(row.jField)
                            continue;
                        end
                        i = row.iField.Value;
                        j = row.jField.Value;
                        if isnan(i) || isnan(j), continue; end
                        key = sprintf('T_%d_%d', i, j);
                        
                    otherwise
                        % unknown row type → ignore
                        continue;
                end
                
                if isempty(key)
                    continue;
                end
                
                % Get current concentration (numeric uieditfield)
                if isempty(row.cField) || ~isvalid(row.cField)
                    continue;
                end
                cVal = row.cField.Value;
                
                if ~isKey(seen, key)
                    % First row of this type/index → remember its concentration
                    seen(key) = cVal;
                    % stays normal color
                else
                    % Duplicate row → force to first value and recolor
                    cFirst = seen(key);
                    row.cField.Value            = cFirst;
                    row.cField.BackgroundColor  = redundantColor;
                    row.redundant               = true;
                    feedRows{k}                 = row;
                end
            end
        end


        % Add callback functions
        function updateA(src, ~)
            aValue = src.Value;
            statusText.Text = sprintf('a updated to %g', aValue);
        end
        
        function updateFr(src, ~)
            frValue = src.Value;
            statusText.Text = sprintf('f_r updated to %g', frValue);
        end
        
        function updateDr(src, ~)
            % global drValue;
            drValue = src.Value;
            statusText.Text = sprintf('d_r updated to %g', drValue);
        end

        % Debug Mode toggle
        debugToggle = uibutton(mainPanel, 'state', ...
            'Text', 'Debug Mode: Off', ...
            'Position', [960, 740, 120, 22], ...
            'Value', 0, ...
            'FontSize', 12, ...
            'ValueChangedFcn', @toggleDebugMode);
        
        function toggleDebugMode(src, ~) 
           debugMode = src.Value;
           if debugMode
               src.Text = 'Debug Mode: On';
               src.BackgroundColor = [1 0.7 0.7]; % Light red
               disp('Debug Mode Enabled');
           else
               src.Text = 'Debug Mode: Off'; 
               src.BackgroundColor = [0.94 0.94 0.94];
               disp('Debug Mode Disabled');
           end
        end
        % Create matrix of Rij buttons
        buttonSize = 50;  
        startX = 600;  
        startY = 300; 
        
        % Initialize matrix to store button handles
        RijButtons = zeros(numE, numN);
        
        % Create buttons in a grid
        for i = 1:numE
            for j = 1:numN
                xPos = startX + (j-1)*buttonSize;
                yPos = startY - (i-1)*buttonSize;
                
                RijButtons(i,j) = uicontrol(mainPanel, ...
                    'Style', 'togglebutton', ...
                    'String', sprintf('R%d%d', i, j), ...  % Simple Rij format without LaTeX
                    'Position', [xPos, yPos, buttonSize, buttonSize], ...
                    'Value', 0, ...
                    'BackgroundColor', [0.94 0.94 0.94], ...
                    'Callback', {@toggleRij, i, j}, ...
                    'FontSize', 12, ...
                    'FontWeight', 'bold');
            end
        end
        
        % Create Add Rs button
        addRsButton = uibutton(mainPanel, 'push', ...
            'Text', 'Add Rs', ...
            'Position', [startX + (numN-1) * buttonSize, startY + 50, buttonSize, 40], ...
            'FontSize', 12, ...
            'ButtonPushedFcn', @addRsButtonClick);
        
        % Add Rs button callback
        function addRsButtonClick(~, ~)
            % Load existing simulation results
            if ~exist('network_simulation_results.mat', 'file')
                statusText.Text = 'No simulation results found. Run simulation first.';
                return;
            end
        
            try
                % Load simulation data
                simResults = load('network_simulation_results.mat');
                networkData = simResults.networkData;
                tAll = simResults.tAll;
                RAll = simResults.RAll;
        
                % Add check for data structure
                if ~iscell(tAll)
                    tAll = {tAll};
                    RAll = {RAll};
                end
        
                % Get most recent simulation result
                lastIdx = length(tAll);
                if lastIdx == 0
                    statusText.Text = 'No simulation data found.';
                    return;
                end
        
                % Get current time points and results
                t = tAll{lastIdx};
                R = RAll{lastIdx};
        
                % Get currently selected Rs from matrix
                selectedRs = [];
                selectedRsIndices = [];
                for i = 1:numE
                    for j = 1:numN
                        if get(RijButtons(i,j), 'Value') == 1
                            selectedRs = [selectedRs; sprintf('R_{%d%d}', i, j)];
                            selectedRsIndices = [selectedRsIndices; i j];
                        end
                    end
                end
        
                if isempty(selectedRs)
                    statusText.Text = 'Please select at least one R from the matrix.';
                    return;
                end
        
                % Get the current figure with simulation results
                figHandles = findall(0, 'Type', 'figure', 'Name', 'Simulation Results');
                if isempty(figHandles)
                    statusText.Text = 'No simulation plot found. Run simulation first.';
                    return;
                end
                plotFig = figHandles(1);
                ax = findall(plotFig, 'Type', 'axes');
        
                % Get current legend entries and count
                currentLegend = get(legend(ax), 'String');
                if isempty(currentLegend)
                    statusText.Text = 'No existing legend entries found for reference.';
                    return;
                end
        
                % Calculate total number of plots needed
                existingPlots = length(currentLegend);
                plotCount = existingPlots;
                legendEntries = currentLegend;
                totalPlots = plotCount + size(selectedRsIndices, 1);
        
                % Generate dynamic color map
                if totalPlots <= 7
                    % For small number of plots, use the default qualitative colors
                    colorMap = [
                        0 0.4470 0.7410;    % blue
                        0.8500 0.3250 0.0980;    % orange
                        0.9290 0.6940 0.1250;    % yellow
                        0.4940 0.1840 0.5560;    % purple
                        0.4660 0.6740 0.1880;    % green
                        0.3010 0.7450 0.9330;    % light blue
                        0.6350 0.0780 0.1840     % burgundy
                    ];
                else
                    % For larger sets, generate a broader color palette
                    hueValues = linspace(0, 1, totalPlots + 1);
                    hueValues = hueValues(1:end-1);
                    saturationValues = ones(1, totalPlots) * 0.7 + rand(1, totalPlots) * 0.3;
                    valueValues = ones(1, totalPlots) * 0.8 + rand(1, totalPlots) * 0.2;
                    
                    colorMap = zeros(totalPlots, 3);
                    for i = 1:totalPlots
                        colorMap(i,:) = hsv2rgb([hueValues(i), saturationValues(i), valueValues(i)]);
                    end
                end
        
                % For each selected R
                for r = 1:size(selectedRsIndices, 1)
                    i = selectedRsIndices(r, 1);
                    j = selectedRsIndices(r, 2);
        
                    % Get reference template entries
                    templateEntries = cell(existingPlots, 1);
                    templateCount = 0;
                    
                    % Find unique scenario entries
                    for idx = 1:existingPlots
                        currentEntry = currentLegend{idx};
                        if contains(currentEntry, 'S') && contains(currentEntry, ']')
                            templateCount = templateCount + 1;
                            templateEntries{templateCount} = currentEntry;
                        end
                    end
                    templateEntries = templateEntries(1:templateCount);
        
                    % For each scenario based on template entries
                    for s = 1:length(templateEntries)
                        % Update plot counter
                        plotCount = plotCount + 1;
        
                        % Get current R data
                        currentR = squeeze(R(:, i, j));
        
                        % Use template to create new legend entry
                        template = templateEntries{s};
                        newLegend = template;
        
                        % Update R indices and final value
                        newLegend = regexprep(newLegend, 'R_{\d+\d+}', sprintf('R_{%d%d}', i, j));
                        newLegend = regexprep(newLegend, '=[\d.]+e[+-]\d+', sprintf('=%.5e', currentR(end)));
        
                        % Plot with cycling colors
                        colorIdx = mod(plotCount-1, size(colorMap, 1)) + 1;
                        plot(ax, t, currentR, 'LineWidth', 1.5, 'Color', colorMap(colorIdx,:));
        
                        % Add to legend entries
                        legendEntries{plotCount} = newLegend;
                    end
                end
        
                % Update legend
                legend(ax, legendEntries(1:plotCount), 'Location', 'southeast', ...
                    'NumColumns', 1, 'FontSize', 10, 'Box', 'off');
        
                % Update plot formatting
                ax.FontSize = 12;
                ax.TitleFontSizeMultiplier = 1.2;
                ax.LabelFontSizeMultiplier = 1.1;
                % ylabel(ax, 'Concentration'); 
        
                % Add numE/numN text
                text(ax, 0.02, 0.98, sprintf('numE: %d, numN: %d', numE, numN), ...
                    'Units', 'normalized', 'VerticalAlignment', 'top', ...
                    'FontSize', 10, 'FontWeight', 'bold');
        
                % Update status with actual count
                newPlots = plotCount - existingPlots;
                statusText.Text = sprintf('Added %d new plots', newPlots);
        
            catch err
                statusText.Text = ['Error adding Rs: ' err.message];
                disp(['Full error: ' getReport(err)]);
            end
        end
        
        % In createUIComponents, update the Plot All Rs button creation:
        % Calculate position for Plot All Rs button
        plotAllRsButtonX = startX;  % Same X as matrix start
        plotAllRsButtonY = startY + 50;  % Under matrix 
        plotAllRsButtonWidth = numN * buttonSize;  % Width spans all columns
        plotAllRsButtonHeight = 40;  % Taller than regular buttons
        
        % Create Plot All Rs button
        plotAllRsButton = uibutton(mainPanel, 'push', ...
            'Text', 'Plot All Rs', ...
            'Position', [plotAllRsButtonX, plotAllRsButtonY, plotAllRsButtonWidth-buttonSize, plotAllRsButtonHeight], ...
            'FontSize', 14, ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @plotAllRsButtonClick, ...
            'Enable', 'off');  % Start disabled
        
        % Update the plotAllRsButtonClick function:
        function plotAllRsButtonClick(btn, ~)
            if ~exist('network_simulation_results.mat', 'file')
                statusText.Text = 'No simulation results found. Run simulation first.';
                return;
            end
            
            try
                % Load and verify data
                data = load('network_simulation_results.mat');
                if ~isfield(data, 'tAll') || ~isfield(data, 'RAll') || ...
                   isempty(data.tAll) || isempty(data.RAll)
                    statusText.Text = 'Invalid simulation data. Please run simulation again.';
                    return;
                end
                
                % Get the last simulation result
                lastIdx = length(data.tAll);
                timeData = data.tAll{lastIdx};
                Rdata = data.RAll{lastIdx};
                
                % Create a new figure window
                newFig = figure('Name', 'All Rs Plot', 'NumberTitle', 'off', ...
                    'Position', [100, 100, 800, 600]);
                ax = axes(newFig);
                
                % Plot each Rij
                legendLabels = {};
                colorMap = [
                    0 0.4470 0.7410;    % blue
                    0.8500 0.3250 0.0980;    % orange
                    0.9290 0.6940 0.1250;    % yellow
                    0.4940 0.1840 0.5560;    % purple
                    0.4660 0.6740 0.1880;    % green
                    0.3010 0.7450 0.9330;    % light blue
                    0.6350 0.0780 0.1840     % burgundy
                ];
                
                hold(ax, 'on');
                plotCount = 0;
                for i = 1:size(Rdata,2)
                    for j = 1:size(Rdata,3)
                        plotCount = plotCount + 1;
                        colorIdx = mod(plotCount-1, size(colorMap, 1)) + 1;
                        plot(ax, timeData, squeeze(Rdata(:,i,j)), 'LineWidth', 2, 'Color', colorMap(colorIdx,:));
                        legendLabels{end+1} = sprintf('R_{%d%d}', i, j);
                    end
                end
                
                % Set plot properties
                title(ax, 'All R_{ij} Concentrations');
                xlabel(ax, 'Time');
                ylabel(ax, 'Concentration');
                legend(ax, legendLabels, 'Location', 'best');
                grid(ax, 'on');
                
                statusText.Text = 'All Rs plotted in new window';
                
            catch err
                statusText.Text = ['Error: ' err.message];
                disp(['Full error: ' getReport(err)]);
            end
        end

               
    
        % Add labels for pathway components
        labels = {'i (E)', 'j (N)', 'i''', 'j''', 'i''''', 'j''''', '<a>', 'f', 'd', 'g', 'b', ...
                  '$E_{i}$', '$N_{j}$', '$T_{i''j''}$', '$T_{i''''j''''}$'};
        positions = [80, 130, 180, 205, 230, 255, 280, 330, 380, 430, 480, 530, 600, 670, 740];
        
        for i = 1:length(labels)
            uilabel(mainPanel, 'Position', [positions(i), 710, 50, 22], 'Text', labels{i}, ...
                'Interpreter', 'latex');
        end
    
        % Create status text
        statusText = uilabel(fig, 'Position', [20, 10, 940, 30], ...
            'Text', 'Ready', 'HorizontalAlignment', 'left');
    
        % Create label for numE and numN display
        numENLabel = uilabel(fig, 'Position', [20, 40, 940, 30], ...
            'Text', sprintf('numE: %d, numN: %d', numE, numN), ...
            'HorizontalAlignment', 'left');

        % Create Reaction order Analysis button
        uibutton(mainPanel, 'push', ...
            'Text', 'Reac.order', ...
            'Position', [plotAllRsButtonX+150, plotAllRsButtonY, plotAllRsButtonWidth-buttonSize, plotAllRsButtonHeight], ...
            'FontSize', 14, ...
            'FontWeight', 'bold', ...
            'Tooltip', 'Press ''o'' to calculate reaction order',...
            'ButtonPushedFcn', @reacorderButtonClick);
        
        % Add the callback function for the Run Derivatives button
        function reacorderButtonClick(~, ~)
            if ~exist('simulation_results.txt', 'file')
                statusText.Text = 'No simulation results found. Run simulation first.';
                return;
            end
            
            try
                % Call the dtdc1 function
                statusText.Text = 'Running derivative analysis...';
                dtdc1('simulation_results.txt');
                statusText.Text = 'Derivative analysis completed. Check plots for results.';
            catch err
                statusText.Text = ['Error in derivative analysis: ' err.message];
                disp(['Full error: ' getReport(err)]);
            end
        end
    end
    
    function updateRijSelection()
        % First, clear all existing selections
        for i = 1:size(RijButtons,1)
            for j = 1:size(RijButtons,2)
                if ishandle(RijButtons(i,j))
                    set(RijButtons(i,j), 'Value', 0);
                    set(RijButtons(i,j), 'BackgroundColor', [0.94 0.94 0.94]);  % Light gray for unselected
                end
            end
        end
        
        % Then set new selections based on pathways
        if ~isempty(pathwayData)
            for idx = 1:length(pathwayData)
                i = pathwayData{idx}.i.Value;
                j = pathwayData{idx}.j.Value;
                
                % Select corresponding Rij button if within range
                if i <= size(RijButtons,1) && j <= size(RijButtons,2)
                    % Use set() instead of dot notation
                    set(RijButtons(i,j), 'Value', 1);
                    set(RijButtons(i,j), 'BackgroundColor', [0.5 0.8 0.5]);  % Green when selected
                end
            end
        end
    end

    function toggleRij(btn, ~, i, j)
        if btn.Value
            btn.BackgroundColor = [0.5 0.8 0.5];  % Green when selected
        else
            btn.BackgroundColor = [0.94 0.94 0.94];  % Light gray when not selected
        end
    end

    function updateNumE(src, ~)
        numE = src.Value;
        
        % Delete existing Rij buttons
        if ~isempty(RijButtons)
            for i = 1:size(RijButtons, 1)
                for j = 1:size(RijButtons, 2)
                    if ishandle(RijButtons(i,j))
                        delete(RijButtons(i,j));
                    end
                end
            end
        end
        
        % Create new matrix of buttons
        buttonSize = 35;
        startX = 600;  
        startY = 300;
        
        % Initialize new button matrix
        RijButtons = zeros(numE, numN);
        
        % Create new buttons in a grid
        for i = 1:numE
            for j = 1:numN
                xPos = startX + (j-1)*buttonSize;
                yPos = startY - (i-1)*buttonSize;
                
                RijButtons(i,j) = uicontrol(mainPanel, ...
                    'Style', 'togglebutton', ...
                    'String', sprintf('R%d%d', i, j), ...
                    'Position', [xPos, yPos, buttonSize, buttonSize], ...
                    'Value', 0, ...
                    'BackgroundColor', [0.94 0.94 0.94], ...
                    'Callback', {@toggleRij, i, j}, ...
                    'FontSize', 12, ...
                    'FontWeight', 'bold');
            end
        end
        
        % Update Add Rs button position
        if exist('addRsButton', 'var') && isvalid(addRsButton)
            newY = startY - numE*buttonSize - 10;
            currentPos = get(addRsButton, 'Position');
            set(addRsButton, 'Position', [currentPos(1), newY, currentPos(3), currentPos(4)]);
        end
        
        statusText.Text = sprintf('Number of E variables updated to %d', numE);
        updateNumENDisplay();
        updateRijSelection();
    end
    
    function updateNumN(src, ~)
        numN = src.Value;
        
        % Delete existing Rij buttons
        if ~isempty(RijButtons)
            for i = 1:size(RijButtons, 1)
                for j = 1:size(RijButtons, 2)
                    if ishandle(RijButtons(i,j))
                        delete(RijButtons(i,j));
                    end
                end
            end
        end
        
        % Create new matrix of buttons
        buttonSize = 50;
        startX = 600;  
        startY = 300;
        
        % Initialize new button matrix
        RijButtons = zeros(numE, numN);
        
        % Create new buttons in a grid
        for i = 1:numE
            for j = 1:numN
                xPos = startX + (j-1)*buttonSize;
                yPos = startY - (i-1)*buttonSize;
                
                RijButtons(i,j) = uicontrol(mainPanel, ...
                    'Style', 'togglebutton', ...
                    'String', sprintf('R%d%d', i, j), ...
                    'Position', [xPos, yPos, buttonSize, buttonSize], ...
                    'Value', 0, ...
                    'BackgroundColor', [0.94 0.94 0.94], ...
                    'Callback', {@toggleRij, i, j}, ...
                    'FontSize', 12, ...
                    'FontWeight', 'bold');
            end
        end
        
        % Update Add Rs button width
        if exist('addRsButton', 'var') && isvalid(addRsButton)
            currentPos = get(addRsButton, 'Position');
            newWidth = numN * buttonSize;
            set(addRsButton, 'Position', [currentPos(1), currentPos(2), newWidth, currentPos(4)]);
        end
        
        statusText.Text = sprintf('Number of N variables updated to %d', numN);
        updateNumENDisplay();
        updateRijSelection();
    end
    
    % Helper function to update the numE and numN display
    function updateNumENDisplay()
        numENLabel.Text = sprintf('numE: %d, numN: %d', numE, numN);
        drawnow;
    end

    % Helper function to update RSelector
    function updateRSelector()
        RItems = cell(1, numE * numN + 1);
        index = 1;
        for i = 1:numE
            for j = 1:numN
                RItems{index} = sprintf('R_{%d%d}', i, j);
                index = index + 1;
            end
        end
        RItems{end} = 'All';
        RSelector.Items = RItems;
    end

    function updateTend(src, ~)
        t_end = src.Value;
        statusText.Text = sprintf('Simulation end time updated to %d', t_end);
    end
    function chooseAllPathways(fig)
        if isempty(pathwayData)
            statusText.Text = 'No pathways available to choose.';
            return;
        end
        
        % Check if any pathway is not chosen to determine the action
        anyNotChosen = any(cellfun(@(x) ~x.chooseButton.Value, pathwayData));
        
        % If any pathway is not chosen, choose all. Otherwise, unchoose all
        for i = 1:length(pathwayData)
            pathwayData{i}.chooseButton.Value = anyNotChosen;
            if anyNotChosen
                pathwayData{i}.chooseButton.Text = 'Chosen';
                pathwayData{i}.chooseButton.BackgroundColor = [0.5 0.8 0.5];
                % Reset redundancy flags when choosing
                fields = {'cTipjp', 'cTippjpp', 'g', 'b', 'cEi', 'cNj', 'd'};
                for field = fields
                    if isfield(pathwayData{i}.Redundant, field{1})
                        pathwayData{i}.Redundant.(field{1}) = 0;
                    end
                end
            else
                pathwayData{i}.chooseButton.Text = 'Choose';
                pathwayData{i}.chooseButton.BackgroundColor = [0.94 0.94 0.94];
            end
        end
        
        % Update status text
        if anyNotChosen
            statusText.Text = 'All pathways chosen.';
        else
            statusText.Text = 'All pathways unchosen.';
        end
        
        % Force redundancy checks
        % redundancy();
        % updateRedundancyIndicators();
        refreshDisplay(fig);
        updateRijSelection();
    end
    
    function addPathway(fig)

        % Function to add a new pathway
        
        % Create new pathway UI elements
        index = length(pathwayData) + 1;
        yPos = 680 - (index - 1) * 30;

        newPathway = struct();
        newPathway.chooseButton = uibutton(fig, 'state', 'Text', 'Choose', 'Position', [20, yPos, 50, 22], ...
            'ValueChangedFcn', @(btn, event) choosePathway(index));
        newPathway.i = uieditfield(fig, 'numeric', 'Position', [80, yPos, 45, 22], 'Value', 1);
        newPathway.j = uieditfield(fig, 'numeric', 'Position', [130, yPos, 45, 22], 'Value', 1);
        newPathway.ip = uieditfield(fig, 'numeric', 'Position', [180, yPos, 20, 22], 'Value', 1);
        newPathway.jp = uieditfield(fig, 'numeric', 'Position', [205, yPos, 20, 22], 'Value', 1);
        newPathway.ipp = uieditfield(fig, 'numeric', 'Position', [230, yPos, 20, 22], 'Value', 1);
        newPathway.jpp = uieditfield(fig, 'numeric', 'Position', [255, yPos, 20, 22], 'Value', 1);
        newPathway.a_r = uieditfield(fig, 'text', 'Position', [280, yPos, 45, 22], 'Value', '10');
        newPathway.f = uieditfield(fig, 'text', 'Position', [330, yPos, 45, 22], 'Value', '1000');
        newPathway.d = uieditfield(fig, 'text', 'Position', [380, yPos, 45, 22], 'Value', '10');
        newPathway.g = uieditfield(fig, 'text', 'Position', [430, yPos, 45, 22], 'Value', '1');
        newPathway.b = uieditfield(fig, 'text', 'Position', [480, yPos, 45, 22], 'Value', '10');
        newPathway.cEi = uieditfield(fig, 'text', 'Position', [530, yPos, 45, 22], 'Value', '100');
        newPathway.cNj = uieditfield(fig, 'text', 'Position', [600, yPos, 45, 22], 'Value', '100');
        newPathway.cTipjp = uieditfield(fig, 'text', 'Position', [670, yPos, 45, 22], 'Value', '0,10');
        newPathway.cTippjpp = uieditfield(fig, 'text', 'Position', [740, yPos, 45, 22], 'Value', '0,10');
        newPathway.label = uilabel(fig, 'Position', [790, yPos, 30, 22], 'Text', num2str(index));
        newPathway.deleteButton = uibutton(fig, 'push', 'Text', '-', 'Position', [830, yPos, 30, 22], ...
            'ButtonPushedFcn', @(btn, event) deletePathway(fig, index));
        newPathway.Redundant = struct(...
            'a_r', 0, ...
            'f', 0, ...
            'd', 0, ...
            'g', 0, ...
            'b', 0, ...
            'cEi', 0, ...
            'cNj', 0, ...
            'cTipjp', 0, ...
            'cTippjpp', 0);       

        % Add new pathway data to pathwayData
        pathwayData{index} = newPathway;
        addPathwayListeners(newPathway, index, fig);  % Added fig parameter
        addTValueListeners(newPathway, index);        % Removed duplicate call
        % After adding the new pathway and refreshing display
        displayPathwayLabels(fig);
        % update numE and numN for each pathway
        adjustNumEN();
        % Refresh display
        refreshDisplay(fig);
        updateRijSelection();
    end

    function addPathwayListeners(pathway, pathwayIdx, figHandle)
        % Remove any existing callbacks first
        if isfield(pathway.i, 'ValueChangedFcn')
            pathway.i.ValueChangedFcn = [];
        end
        if isfield(pathway.j, 'ValueChangedFcn')
            pathway.j.ValueChangedFcn = [];
        end
    
        % Set value change callbacks for i and j fields that trigger numE/numN updates
        pathway.i.ValueChangedFcn = @(src,~) handleIValueChange(src);
        pathway.j.ValueChangedFcn = @(src,~) handleJValueChange(src);
    
        % Add regular parameter listeners for redundancy checking
        addlistener(pathway.a_r, 'ValueChanged', @(~,~) handleParameterChange('a_r', pathwayIdx));
        addlistener(pathway.f, 'ValueChanged', @(~,~) handleParameterChange('f', pathwayIdx));
        addlistener(pathway.d, 'ValueChanged', @(~,~) handleParameterChange('d', pathwayIdx));
        addlistener(pathway.g, 'ValueChanged', @(~,~) handleParameterChange('g', pathwayIdx));
        addlistener(pathway.b, 'ValueChanged', @(~,~) handleParameterChange('b', pathwayIdx));
        addlistener(pathway.cEi, 'ValueChanged', @(~,~) handleParameterChange('cEi', pathwayIdx));
        addlistener(pathway.cNj, 'ValueChanged', @(~,~) handleParameterChange('cNj', pathwayIdx));
        addlistener(pathway.cTipjp, 'ValueChanged', @(~,~) handleParameterChange('cTipjp', pathwayIdx));
        addlistener(pathway.cTippjpp, 'ValueChanged', @(~,~) handleParameterChange('cTippjpp', pathwayIdx));
            
        % Add structural parameter listeners
        addlistener(pathway.ip, 'ValueChanged', @(~,~) handleStructuralChange());
        addlistener(pathway.ipp, 'ValueChanged', @(~,~) handleStructuralChange());
        addlistener(pathway.jp, 'ValueChanged', @(~,~) handleStructuralChange());
        addlistener(pathway.jpp, 'ValueChanged', @(~,~) handleStructuralChange());
    
        % Local functions to handle i and j value changes
        function handleIValueChange(src)
            % Find maximum i value across all pathways
            maxI = max(cellfun(@(x) x.i.Value, pathwayData));
            
            % Always update numE to match the maximum i value found
            if maxI ~= numE
                numE = maxI;
                numEField.Value = maxI;
                updateNumE(numEField);
                displayPathwayLabels(figHandle);
                refreshDisplay(figHandle);
                drawnow;
            end
        end
    
        function handleJValueChange(src)
            % Find maximum j value across all pathways
            maxJ = max(cellfun(@(x) x.j.Value, pathwayData));
            
            % Always update numN to match the maximum j value found
            if maxJ ~= numN
                numN = maxJ;
                numNField.Value = maxJ;
                updateNumN(numNField);
                displayPathwayLabels(figHandle);
                refreshDisplay(figHandle);
                drawnow;
            end
        end
    end
    
    % Add this helper function to set up the callbacks
    function addValueChangedCallback(field, pathwayIndex)        
        % Create a function that captures both fig and pathwayIndex
        function handleIndexChange(src, event)
            displayPathwayLabels(fig);
        end
        
        field.ValueChangedFcn = @handleIndexChange;
    end

    % Add new handler functions:
    function handleParameterChange(paramName, changedIdx)
        chosenPathways = find(cellfun(@(x) x.chooseButton.Value, pathwayData));
        if length(chosenPathways) >= 1
            % Reset redundancy for this parameter
            pathwayData{changedIdx}.Redundant.(paramName) = 0;
            pathwayData{changedIdx}.(paramName).BackgroundColor = [1 1 1];
            
            % Force redundancy check immediately
            % redundancy();
            % updateRedundancyIndicators();
        end
        refreshDisplay(fig);
    end
        
    function handleStructuralChange()
        % updateRedundancyIndicators();
        refreshDisplay(fig);
    end

    % Handler for pathway parameter changes
    function handlePathwayChange()
        % Update redundancy indicators
        % updateRedundancyIndicators();
        % Update display
        refreshDisplay(fig);
    end

    % Labeling for all pathways in the GUI
    function displayPathwayLabels(fig)
        % Remove any existing label displays first
        delete(findall(fig, 'Tag', 'PathwayLabel'));
        
        % Create labels in reverse order to maintain proper stacking
        for i = length(pathwayData):-1:1
            if isstruct(pathwayData{i})
                % Get pathway indices
                idx_i = pathwayData{i}.i.Value;
                idx_j = pathwayData{i}.j.Value;
                idx_ip = pathwayData{i}.ip.Value;
                idx_jp = pathwayData{i}.jp.Value;
                idx_ipp = pathwayData{i}.ipp.Value;
                idx_jpp = pathwayData{i}.jpp.Value;
                
                % Calculate position for label
                yPos = 670 - (i - 1) * 30;
                
                % Create label with LaTeX subscripts
                uilabel(mainPanel, ...
                    'Position', [860, yPos, 400, 22], ...
                    'Text', ['$E_{' num2str(idx_i) '} + N_{' num2str(idx_j) '} + ' ...
                            'TT_{' num2str(idx_ip) num2str(idx_jp) num2str(idx_ipp) num2str(idx_jpp) '} ' ...
                            '\rightarrow R_{' num2str(idx_i) num2str(idx_j) '}$'], ...
                    'Tag', 'PathwayLabel', ...
                    'FontSize', 12, ...
                    'BackgroundColor', 'none', ...
                    'HorizontalAlignment', 'left', ...
                    'Interpreter', 'latex');
            end
        end
    end
    
    function saveNetwork(fig)
        % Function to save network configuration
        
        % Extract only the necessary data from pathwayData
        saveData = cellfun(@(x) struct('i', x.i.Value, 'j', x.j.Value, 'ip', x.ip.Value, ...
            'jp', x.jp.Value, 'ipp', x.ipp.Value, 'jpp', x.jpp.Value, 'a_r', x.a_r.Value, ...
            'f', x.f.Value, 'd', x.d.Value, 'g', x.g.Value, 'b', x.b.Value, ...
            'cEi', x.cEi.Value, 'cNj', x.cNj.Value, 'cTipjp', x.cTipjp.Value, ...
            'cTippjpp', x.cTippjpp.Value), pathwayData, 'UniformOutput', false);
        
        % Get file name from user
        [file, path] = uiputfile('*.mat', 'Save Network Data');
        if isequal(file, 0) || isequal(path, 0)
            return;
        end
        
        % Save the extracted data
        save(fullfile(path, file), 'saveData');
        
        % Update status text
        statusText.Text = ['Network saved to ' fullfile(path, file)];
    end

    function loadNetwork(fig)
        % Get file to load
        [file, path] = uigetfile('*.mat', 'Load Network Data');
        if isequal(file, 0) || isequal(path, 0)
            return;
        end
        
        % Load the data
        loadedData = load(fullfile(path, file));
        if ~isfield(loadedData, 'saveData')
            errordlg('Invalid file format. Please select a valid network data file.', 'Error');
            return;
        end
        
        % Clear existing pathways
        clearAll(fig);
        
        % Create new pathways and update their values
        fields_to_update = {'i', 'j', 'ip', 'jp', 'ipp', 'jpp', 'a_r', 'f', 'd', 'g', 'b', 'cEi', 'cNj', 'cTipjp', 'cTippjpp'};
        
        for i = 1:length(loadedData.saveData)
            addPathway(fig);
            data = loadedData.saveData{i};
            
            % Update each field if it exists and is valid
            for field = fields_to_update
                if isfield(pathwayData{i}, field{1}) && ...
                   isfield(data, field{1}) && ...
                   isvalid(pathwayData{i}.(field{1}))
                    
                    % Convert value to string for text fields
                    if isprop(pathwayData{i}.(field{1}), 'Type') && ...
                       strcmp(pathwayData{i}.(field{1}).Type, 'text')
                        pathwayData{i}.(field{1}).Value = num2str(data.(field{1}));
                    else
                        pathwayData{i}.(field{1}).Value = data.(field{1});
                    end
                end
            end
            addTValueListeners(pathwayData{i}, i);
        end
    
        % Add listeners to new pathways
        for i = 1:length(pathwayData)
            addPathwayListeners(pathwayData{i}, i, fig);
        end
        % update numE and numN for each pathway
        adjustNumEN();
        % Update display
        refreshDisplay(fig);
        displayPathwayLabels(fig);
        resetColors();
        % updateRedundancyIndicators();
        updateRijSelection();
        statusText.Text = ['Network loaded from ' fullfile(path, file)];
    end

    function clearAll(fig)
        % Check if pathwayData exists and is not empty
        if ~isempty(pathwayData)
            % Delete pathways from last to first to avoid indexing issues
            for i = length(pathwayData):-1:1
                if isstruct(pathwayData{i})
                    % Get all field names
                    fields = fieldnames(pathwayData{i});
                    
                    % Delete each UI component if it exists and is valid
                    for j = 1:length(fields)
                        if isfield(pathwayData{i}, fields{j}) && ...
                           isobject(pathwayData{i}.(fields{j})) && ...
                           isvalid(pathwayData{i}.(fields{j}))
                            delete(pathwayData{i}.(fields{j}));
                        end
                    end
                end
            end
            delete(findall(fig, 'Tag', 'PathwayLabel'));
            % Clear the pathwayData array
            pathwayData = {};
             % Reset numE and numN to default values
            numE = 3;
            numN = 3;
            numEField.Value = numE;
            numNField.Value = numN;
            updateNumE(numEField);
            updateNumN(numNField);

            % Reset a, fr, and dr to default values
            aValue = 1e9;
            frValue = 10;
            drValue = 1e6;
            
            % Update the UI fields with default values
            aField.Value = aValue;
            frField.Value = frValue;
            drField.Value = drValue;
        end
        
        % Update status text
        statusText.Text = 'All pathways cleared';
    end

    function deletePathway(fig, index)
        % Check if pathwayData is empty or index is out of bounds
        if isempty(pathwayData) || index > length(pathwayData)
            return;
        end
        
        % Delete UI components
        fields = fieldnames(pathwayData{index});
        for i = 1:length(fields)
            if isfield(pathwayData{index}, fields{i}) && ...
               isobject(pathwayData{index}.(fields{i})) && ...
               ishandle(pathwayData{index}.(fields{i}))
                delete(pathwayData{index}.(fields{i}));
            end
        end
        
        % Remove pathway from data
        pathwayData(index) = [];
        
        % Update remaining pathways
        for i = index:length(pathwayData)
            updatePathwayPosition(fig, i);
        end
        
        % Refresh display
        refreshDisplay(fig);
        displayPathwayLabels(fig);
        
        % Reset numE and numN to match current maximum values
        adjustNumEN();
    end

    function updatePathwayPosition(fig, index)
        % Calculate new vertical position
        yPos = 680 - (index - 1) * 30;
        
        % Update position of all UI elements for this pathway
        fields = fieldnames(pathwayData{index});
        for i = 1:length(fields)
            if isprop(pathwayData{index}.(fields{i}), 'Position')
                currentPosition = pathwayData{index}.(fields{i}).Position;
                pathwayData{index}.(fields{i}).Position = [currentPosition(1), yPos, currentPosition(3), currentPosition(4)];
            end
        end
        
        % Update label text
        pathwayData{index}.label.Text = num2str(index);
        
        % Update delete button callback
        pathwayData{index}.deleteButton.ButtonPushedFcn = @(btn, event) deletePathway(fig, index);
        % Update choose button callback
        pathwayData{index}.chooseButton.ValueChangedFcn = @(btn, event) choosePathway(index);
    end

    function refreshDisplay(fig)
        % Update the GUI display
        for i = 1:length(pathwayData)
            yPos = 680 - (i - 1) * 30;
            pathway = pathwayData{i};
            
            % Update positions of all UI elements
            pathway.chooseButton.Position = [20, yPos, 50, 22];
            pathway.i.Position = [80, yPos, 45, 22];
            pathway.j.Position = [130, yPos, 45, 22];
            pathway.ip.Position = [180, yPos, 20, 22];
            pathway.jp.Position = [205, yPos, 20, 22];
            pathway.ipp.Position = [230, yPos, 20, 22];
            pathway.jpp.Position = [255, yPos, 20, 22];
            pathway.a_r.Position = [280, yPos, 45, 22];
            pathway.f.Position = [330, yPos, 45, 22];
            pathway.d.Position = [380, yPos, 45, 22];
            pathway.g.Position = [430, yPos, 45, 22];
            pathway.b.Position = [480, yPos, 45, 22];
            pathway.cEi.Position = [530, yPos, 45, 22];
            pathway.cNj.Position = [600, yPos, 45, 22];
            pathway.cTipjp.Position = [670, yPos, 45, 22];
            pathway.cTippjpp.Position = [740, yPos, 45, 22];
            pathway.label.Position = [790, yPos, 30, 22];
            pathway.deleteButton.Position = [830, yPos, 30, 22];

            displayPathwayLabels(fig);
            % Adjust figure size if necessary
            if length(pathwayData) > 20
                fig.Position(4) = 800 + (length(pathwayData) - 20) * 30;
            else
                fig.Position(4) = 800;
            end
            
            % Update label text
            pathway.label.Text = num2str(i);
            
            % Update delete button callback
            pathway.deleteButton.ButtonPushedFcn = @(btn, event) deletePathway(fig, i);
            
            % Update choose button callback
            pathway.chooseButton.ValueChangedFcn = @(btn, event) choosePathway(i);
        end
        
        % Adjust figure size if necessary
        if length(pathwayData) > 20
            fig.Position(4) = 800 + (length(pathwayData) - 20) * 30;
        else
            fig.Position(4) = 800;
        end
    end
    
    % UpdatePathwayLabel for reaction schemes
    function updatePathwayLabel(src, event, index)    
        % Find the main figure
        figs = findall(0, 'Type', 'figure');
        mainfig = findobj(figs, 'Name', 'Catalysis Simulation GUI');
        
        if ~isempty(mainfig)
            % Remove old labels
            delete(findall(mainfig, 'Tag', 'PathwayLabel'));
            
            % Recreate all labels
            displayPathwayLabels(mainfig);
        end
    end

    
    function resetColors()
        for i = 1:length(pathwayData)
            if isvalid(pathwayData{i}.cTipjp)
                pathwayData{i}.cTipjp.BackgroundColor = [1 1 1];
                pathwayData{i}.cTippjpp.BackgroundColor = [1 1 1];
                pathwayData{i}.g.BackgroundColor = [1 1 1];
                pathwayData{i}.b.BackgroundColor = [1 1 1];
                pathwayData{i}.cEi.BackgroundColor = [1 1 1];
                pathwayData{i}.cNj.BackgroundColor = [1 1 1];
            end
        end
    end 
    
    function checkVerticalRedundancy(param, chosenPathways)
        firstValue = pathwayData{chosenPathways(1)}.(param).Value;
        firstFound = false;
        
        for idx = chosenPathways
            currentValue = pathwayData{idx}.(param).Value;
            if isequal(currentValue, firstValue)
                if ~firstFound
                    pathwayData{idx}.(param).BackgroundColor = [0.8 0.9 1];
                    firstFound = true;
                else
                    pathwayData{idx}.(param).BackgroundColor = [0.9 0.9 0.9];
                end
            end
        end
    end
    
    function choosePathway(index)
        if pathwayData{index}.chooseButton.Value
            pathwayData{index}.chooseButton.Text = 'Chosen';
            pathwayData{index}.chooseButton.BackgroundColor = [0.5 0.8 0.5];
        else
            % Set unchosen state
            pathwayData{index}.chooseButton.Text = 'Choose';
            pathwayData{index}.chooseButton.BackgroundColor = [0.94 0.94 0.94];
            
            % Reset redundancy flags and colors for unchosen pathway
            fields = {'cTipjp', 'cTippjpp', 'g', 'b', 'cEi', 'cNj', 'd'};
            for i = 1:length(fields)
                field = fields{i};
                if isfield(pathwayData{index}.Redundant, field)
                    pathwayData{index}.Redundant.(field) = 0;
                    pathwayData{index}.(field).BackgroundColor = [1 1 1];
                end
            end
        end
        % Always check redundancy after choose/unchoose
        % checkRedundancy();
    end

    % Add value change listeners for pathway T values
    function addTValueListeners(pathway, idx)
        % Single handler for both T values
        function handleTChange(~, ~, isFirstT)
            if (pathway.ip.Value == pathway.ipp.Value) && (pathway.jp.Value == pathway.jpp.Value)
                % If source is Tipjp, update Tippjpp, and vice versa
                if isFirstT
                    pathway.cTippjpp.Value = pathway.cTipjp.Value;
                else
                    pathway.cTipjp.Value = pathway.cTippjpp.Value;
                end
            end
            % updateRedundancyIndicators();
            refreshDisplay(fig);
        end
    
        % Set callbacks with flag to indicate source
        pathway.cTipjp.ValueChangedFcn = @(s,e) handleTChange(s,e,true);
        pathway.cTippjpp.ValueChangedFcn = @(s,e) handleTChange(s,e,false);
    end

    % Handler for T value changes
    function handleTValueChange(source, pathwayIdx)
        if checkPathwayRedundancy(pathwayData{pathwayIdx})
            enforceRedundantTValues(pathwayIdx);
        end
        % updateRedundancyIndicators();
        refreshDisplay(fig);
    end 

    function colorMap = generateColorMap(numColors)
        % Generate a dynamic color map based on the number of colors needed
        if numColors <= 7
            % For small number of plots, use the default qualitative colors
            colorMap = [
                0 0.4470 0.7410;    % blue
                0.8500 0.3250 0.0980;    % orange
                0.9290 0.6940 0.1250;    % yellow
                0.4940 0.1840 0.5560;    % purple
                0.4660 0.6740 0.1880;    % green
                0.3010 0.7450 0.9330;    % light blue
                0.6350 0.0780 0.1840     % burgundy
            ];
            colorMap = colorMap(1:numColors, :);
        else
            % For larger sets, generate a broader color palette using HSV space
            hueValues = linspace(0, 1, numColors + 1);
            hueValues = hueValues(1:end-1);
            
            % Create variations in saturation and value for more distinct colors
            saturationValues = ones(1, numColors) * 0.7 + rand(1, numColors) * 0.3;
            valueValues = ones(1, numColors) * 0.8 + rand(1, numColors) * 0.2;
            
            % Convert HSV to RGB
            colorMap = zeros(numColors, 3);
            for i = 1:numColors
                colorMap(i,:) = hsv2rgb([hueValues(i), saturationValues(i), valueValues(i)]);
            end
        end
    end

    % change NumE and NumN to fit the maximum value of i and j respectively in pathways
     function adjustNumEN()
        if isempty(pathwayData)
            return;
        end
        
        try
            % Get maximum values
            maxI = max(cellfun(@(x) x.i.Value, pathwayData));
            maxJ = max(cellfun(@(x) x.j.Value, pathwayData));
            
            % Always update if values are different
            if maxI ~= numE
                numE = maxI;
                numEField.Value = maxI;
                updateNumE(numEField);
            end
            
            if maxJ ~= numN
                numN = maxJ;
                numNField.Value = maxJ;
                updateNumN(numNField);
            end
            
            % Update display
            updateNumENDisplay();
            drawnow;
            
        catch err
            disp(['Error in adjustNumEN: ' err.message]);
        end
    end
    
    % Define the keyboard event handler
    % Basic Operations
    % Press r - Run Network
    % Press w - Choose All Pathways
    % Press e - Load Network
    % Press a - Add New Pathway (same as '+' button)
    % Advanced Operations
    % Press Ctrl + a - Save Network
    % Press Ctrl + t - Clear All Pathways
    % Press 'd' then a number (e.g., '1', '2', '3', etc.) to choose/unchoose the selection of that pathway
    % Press 'o' to calculate reaction order
    persistent dPressed;
    if isempty(dPressed)
        dPressed = false;
    end
    
    % Define the keyboard event handler
    function handleKeyPress(src, event)
        % Get modifier keys state
        isCtrlPressed = ismember('control', event.Modifier);
        
        % Check for numbers after q press
        if dPressed
            % Check if a number was pressed
            num = str2double(event.Key);
            if ~isnan(num) && num > 0 && num <= length(pathwayData)
                % Toggle the choose state of the pathway
                pathwayData{num}.chooseButton.Value = ~pathwayData{num}.chooseButton.Value;
                choosePathway(num);
                statusText.Text = ['Toggled selection of pathway ' num2str(num)];
            end
            dPressed = false;
            return;
        end
        
        % Handle other shortcuts
        switch event.Key
            case 'd'
                dPressed = true;
            case 'r'  % Run Network
                runNetwork(fig);
            case 'e'  % Load Network
                loadNetwork(fig);
            case 'w'  % Choose All
                chooseAllPathways(fig);
            case 'a'  % Add pathway or Save Network
                if isCtrlPressed
                    saveNetwork(fig);  % Ctrl+A for Save Network
                else
                    addPathway(fig);   % Just 'a' for Add pathway
                end
            case 'c'  % Clear All
                if isCtrlPressed
                    clearAll(fig);     % Ctrl+C for Clear All
                end
            case 'o'  % Run Derivatives Analysis
                if exist('simulation_results.txt', 'file')
                    dtdc1('simulation_results.txt');
                    statusText.Text = 'Derivative analysis completed. Check plots for results.';
                else
                    statusText.Text = 'No simulation results found. Run simulation first.';
                end
            otherwise
                dPressed = false;  % Reset d state if any other key is pressed
        end
    end
    % functions runNetwork(fig)
    % and
    % function scenarios = generateScenarios(Tipjp_values, Tippjpp_values)
    % in separate file named as runNetwork
end

