%% IMMEDIATE FIX for your BMS model
% Run this script to create your BMS model without the annotation error

fprintf('=== Creating BMS CSI Model (Fixed Version) ===\n\n');

% Your DBC file
dbc_file = 'dbc/CSI_SBOX.dbc';

% Your desired model name (fixed - no slashes!)
model_name = 'bms_csi';

% Option 1: Create model WITHOUT annotations (fastest fix)
fprintf('Creating model without annotations to avoid error...\n');
options = struct();
options.colorCode = true;           % Keep color coding
options.addAnnotations = false;     % Disable annotations to avoid error
options.maxSignalsPerColumn = 30;   % Organize in columns

try
    create_simulink_from_dbc_fixed(dbc_file, model_name, options);
    fprintf('\n✓ Success! Model created: %s\n', model_name);
catch ME
    fprintf('\n✗ Error: %s\n', ME.message);
    
    % If that fails, try the basic version
    fprintf('\nTrying basic version...\n');
    try
        create_simulink_from_dbc(dbc_file, model_name);
        fprintf('✓ Success with basic version!\n');
    catch ME2
        fprintf('✗ Basic version also failed: %s\n', ME2.message);
    end
end

% Option 2: For large DBC file (270 signals), create filtered version
fprintf('\n\n=== Alternative: Create Filtered BMS Model ===\n');

% Extract just BMS-related signals
fprintf('Extracting BMS-specific signals...\n');

% Use the large DBC handler with BMS filter
bms_options = struct();
bms_options.filterPattern = 'BMS|Battery|Cell|SOC|Voltage|Current|Temp';
bms_options.maxSignalsPerModel = 50;
bms_options.interactiveSelection = false;  % Auto-select based on pattern

filtered_model = 'bms_csi_filtered';

fprintf('\nTo create a filtered model with just BMS signals, run:\n');
fprintf('>> handle_large_dbc(''%s'', bms_options)\n', dbc_file);

% Option 3: Create multiple smaller models
fprintf('\n\n=== Alternative: Create Multiple Smaller Models ===\n');
fprintf('Since you have 270 signals, consider creating separate models:\n\n');

fprintf('1. Core BMS signals:\n');
core_signals = {
    'BMS_Pack_Voltage'
    'BMS_Pack_Current'
    'BMS_SOC'
    'BMS_SOH'
    'BMS_Status'
};
fprintf('   >> create_simulink_from_dbc(core_signals, ''bms_csi_core'')\n\n');

fprintf('2. Cell monitoring signals:\n');
fprintf('   >> options.filterPattern = ''Cell_Voltage|Cell_Temp'';\n');
fprintf('   >> handle_large_dbc(''%s'', options)\n\n', dbc_file);

fprintf('3. Safety/Fault signals:\n');
fprintf('   >> options.filterPattern = ''Fault|Error|Alarm|Protection'';\n');
fprintf('   >> handle_large_dbc(''%s'', options)\n\n', dbc_file);

% Summary
fprintf('\n=== Summary ===\n');
fprintf('1. Main model created (if successful): %s\n', model_name);
fprintf('2. For 270 signals, use filtering or create multiple models\n');
fprintf('3. The annotation error has been fixed in create_simulink_from_dbc_fixed\n');
fprintf('4. Run START_HERE for interactive guidance\n');
