% Quick fix for model naming error
% This script shows how to properly use the DBC to Simulink tools

%% Fix for the error you encountered

% The error occurred because you tried to use a model name with a slash
% Example of WRONG usage:
% create_simulink_from_dbc('your_file.dbc', 'components/bms_csi')  % ERROR!

% Example of CORRECT usage:
% create_simulink_from_dbc('your_file.dbc', 'components_bms_csi')  % GOOD!

%% Handling DBC file with 270 signals

% Since you have 270 signals, here are better approaches:

% Option 1: Use the large DBC handler (RECOMMENDED)
% This will give you interactive options to filter and organize signals
dbc_file = 'dbc/CSI_SBOX.dbc';  % Replace with your DBC file
handle_large_dbc(dbc_file);

% Option 2: Create a filtered model with specific signals
% Extract signals but only use ones matching a pattern
signal_pattern = 'Temperature|Voltage|Current';  % Example pattern
options.filterPattern = signal_pattern;
options.maxSignalsPerModel = 30;
handle_large_dbc(dbc_file, options);

% Option 3: Extract signals and manually select which ones to use
% First, preview what's in the file
preview_dbc_signals(dbc_file);

% Then create a model with just the signals you need
selected_signals = {
    'BMS_Cell_Voltage_1'
    'BMS_Cell_Temperature_1' 
    'BMS_Pack_Current'
    'BMS_SOC'
    % Add more signals as needed
};
create_simulink_from_dbc(selected_signals, 'bms_csi_selected');

% Option 4: Create separate models for different subsystems
% This is useful when you have different CAN nodes/subsystems

% Battery Management System signals
bms_signals = {
    'BMS_Pack_Voltage'
    'BMS_Pack_Current'
    'BMS_SOC'
    'BMS_Temperature_Max'
};
create_simulink_from_dbc(bms_signals, 'tugvolt_bms');

% Motor Controller signals  
motor_signals = {
    'Motor_Temperature_1'
    'Motor_Speed'
    'Motor_Torque_Actual'
};
create_simulink_from_dbc(motor_signals, 'tugvolt_motor');

%% Tips for large DBC files

fprintf('\n=== Tips for handling large DBC files ===\n');
fprintf('1. Use handle_large_dbc() for interactive filtering\n');
fprintf('2. Group signals by CAN message or subsystem\n');
fprintf('3. Create multiple smaller models instead of one huge model\n');
fprintf('4. Use the enhanced version with color coding for better visualization\n');
fprintf('5. Filter signals by pattern (e.g., all temperature signals)\n');

%% Example: Complete workflow for your case

% Step 1: Analyze the DBC file
fprintf('\n=== Step 1: Analyzing your DBC file ===\n');
your_dbc = 'dbc/CSI_SBOX.dbc';  % Update this path
% preview_dbc_signals(your_dbc);  % Uncomment to see all signals

% Step 2: Create a model with smart filtering
fprintf('\n=== Step 2: Creating filtered model ===\n');
options = struct();
options.maxSignalsPerModel = 40;  % Reasonable number for one model
options.groupByMessage = true;     % Group by CAN message
options.interactiveSelection = true; % Let you choose which signals

% This will guide you through selecting signals
% handle_large_dbc(your_dbc, options);  % Uncomment to run

% Step 3: Alternative - create model with enhanced features
fprintf('\n=== Step 3: Creating enhanced model ===\n');
% If you know specific signals you want:
key_signals = {
    'Battery_Voltage'
    'Battery_Current'
    'Motor_Temperature'
    'Vehicle_Speed'
    % Add your specific signals here
};

% Create the model with proper name (no slashes!)
model_name = 'tugvolt_bms_csi';  % Good name
% model_name = 'components/bms_csi';  % BAD - will cause error!

% Uncomment to create:
% create_simulink_from_dbc_enhanced(key_signals, model_name);

fprintf('\n=== Workflow complete! ===\n');
fprintf('Remember: Model names cannot contain / or \\ characters\n');
