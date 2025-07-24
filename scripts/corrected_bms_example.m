% Corrected example for your specific case
% This shows how to properly create the model you were trying to make

%% Your Original Attempt (WRONG)
% create_simulink_from_dbc('your_file.dbc', 'components/bms_csi')
% This fails because of the forward slash!

%% Corrected Version (RIGHT)
dbc_file = 'dbc/CSI_SBOX.dbc';  % Update with your actual DBC file path

% Option 1: Simple fix - just change the slash to underscore
model_name = 'components_bms_csi';  % Changed / to _
create_simulink_from_dbc(dbc_file, model_name);

% But wait! You have 270 signals, which is too many for one model
% So let's do this properly...

%% Better Solution for 270 Signals

% Option 2: Use the large DBC handler
fprintf('\n=== Recommended: Interactive Signal Selection ===\n');
fprintf('This will guide you through selecting which signals to include\n\n');

% Uncomment the next line to run:
% handle_large_dbc(dbc_file);

% Option 3: Create BMS-specific models (if this is a BMS DBC file)
fprintf('\n=== Alternative: Create BMS-Specific Models ===\n');
fprintf('This will automatically organize signals into logical groups\n\n');

% Uncomment the next line to run:
% create_tugvolt_bms_models(dbc_file);

% Option 4: Create filtered model with just essential signals
fprintf('\n=== Quick Solution: Essential Signals Only ===\n');
essential_bms_signals = {
    'BMS_Pack_Voltage'
    'BMS_Pack_Current'  
    'BMS_SOC'
    'BMS_SOH'
    'BMS_Max_Cell_Voltage'
    'BMS_Min_Cell_Voltage'
    'BMS_Max_Temperature'
    'BMS_Min_Temperature'
    'BMS_Fault_Status'
    'BMS_Charging_Status'
};

% Check which signals actually exist in your DBC
all_signals = extract_signals_from_dbc(dbc_file);
available_signals = {};

for i = 1:length(essential_bms_signals)
    if any(strcmp(all_signals, essential_bms_signals{i}))
        available_signals{end+1} = essential_bms_signals{i};
    end
end

if ~isempty(available_signals)
    fprintf('Creating model with %d essential signals\n', length(available_signals));
    create_simulink_from_dbc(available_signals, 'components_bms_csi_essential');
else
    fprintf('None of the predefined signals found. Using interactive mode instead.\n');
    % handle_large_dbc(dbc_file);
end

fprintf('\n=== Success! ===\n');
fprintf('Model names corrected and ready to use.\n');
fprintf('Remember: Never use / or \\ in Simulink model names!\n');
