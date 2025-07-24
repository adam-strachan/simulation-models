% SOLUTION: Fix for "The use of new_system to create a subsystem is obsolete" Error
%
% This error occurs when your model name contains a forward slash (/)
% MATLAB interprets this as trying to create a subsystem, not a model

%% THE PROBLEM
% You tried something like this:
% create_simulink_from_dbc('your_dbc_file.dbc', 'components/bms_csi')
%                                                           ^
%                                                    This slash causes the error!

%% THE SOLUTION
% Replace slashes with underscores:
model_name = 'components_bms_csi';  % Good!
% model_name = 'components/bms_csi';  % Bad - causes error!

%% COMPLETE WORKING EXAMPLE

% Step 1: Choose your DBC file
dbc_file = 'dbc/CSI_SBOX.dbc';  % Update with your actual file

% Step 2: Since you have 270 signals, let's handle them intelligently
fprintf('=== Handling Large DBC File (270 signals) ===\n\n');

% Option A: Interactive selection (RECOMMENDED)
fprintf('Option A: Interactive Selection\n');
fprintf('Run: handle_large_dbc(''%s'')\n\n', dbc_file);

% Option B: Create filtered models by signal type
fprintf('Option B: Create Filtered Models\n');

% Battery signals only
battery_options.filterPattern = 'Battery|BMS|Cell|SOC|Voltage|Current';
battery_options.maxSignalsPerModel = 40;
% handle_large_dbc(dbc_file, battery_options);  % Uncomment to run

% Motor signals only  
motor_options.filterPattern = 'Motor|Speed|Torque|Temperature';
motor_options.maxSignalsPerModel = 30;
% handle_large_dbc(dbc_file, motor_options);  % Uncomment to run

% Option C: Create BMS-specific organized models
fprintf('\nOption C: BMS-Specific Models\n');
fprintf('Run: create_tugvolt_bms_models(''%s'')\n\n', dbc_file);

% Option D: Manual selection of key signals
fprintf('Option D: Manual Selection\n');
key_signals = {
    'BMS_Pack_Voltage'
    'BMS_Pack_Current'
    'BMS_SOC'
    'BMS_Cell_Voltage_Max'
    'BMS_Cell_Voltage_Min'
    'BMS_Temperature_Max'
    'Motor_Speed'
    'Motor_Torque'
    'Vehicle_Speed'
};

% Create model with CORRECT name (no slashes!)
correct_model_name = 'tugvolt_bms_csi_core';  
create_simulink_from_dbc(key_signals, correct_model_name);
fprintf('Created model: %s\n', correct_model_name);

%% QUICK TEST
% Let's create a simple test model to verify everything works
test_signals = {'Signal1', 'Signal2', 'Signal3'};
test_model_name = 'test_model_no_slash';  % Good name!

try
    create_simulink_from_dbc(test_signals, test_model_name);
    fprintf('\n✓ Success! Test model created: %s\n', test_model_name);
    close_system(test_model_name, 0);
catch ME
    fprintf('\n✗ Error: %s\n', ME.message);
end

%% SUMMARY
fprintf('\n=== REMEMBER ===\n');
fprintf('1. Model names CANNOT contain / or \\ characters\n');
fprintf('2. Use underscores _ instead of slashes\n');
fprintf('3. For large DBC files (270 signals), use filtering or grouping\n');
fprintf('4. Run handle_large_dbc() for interactive signal selection\n');

fprintf('\n=== NEXT STEPS ===\n');
fprintf('1. Update your model name: components_bms_csi (not components/bms_csi)\n');
fprintf('2. Use handle_large_dbc(''%s'') for interactive filtering\n', dbc_file);
fprintf('3. Or create multiple smaller models by subsystem\n');
