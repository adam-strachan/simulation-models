%% TugVolt DBC to Simulink Tools - Quick Start Guide
% Run this script to see all available tools and choose the right one

fprintf('===== TugVolt DBC to Simulink Tools =====\n\n');

%% Tool Selection Guide
fprintf('Which tool should you use?\n');
fprintf('-------------------------\n\n');

fprintf('1. For SMALL DBC files (<50 signals):\n');
fprintf('   → Use: create_simulink_from_dbc()\n');
fprintf('   Example: create_simulink_from_dbc(signals, ''model_name'')\n\n');

fprintf('2. For LARGE DBC files (50-300 signals):\n');
fprintf('   → Use: handle_large_dbc()\n');
fprintf('   Example: handle_large_dbc(''dbc/large_file.dbc'')\n\n');

fprintf('3. For BMS-specific files:\n');
fprintf('   → Use: create_tugvolt_bms_models()\n');
fprintf('   Example: create_tugvolt_bms_models(''dbc/CSI_eBTMS.dbc'')\n\n');

fprintf('4. For enhanced features (colors, grouping):\n');
fprintf('   → Use: create_simulink_from_dbc_enhanced()\n');
fprintf('   Example: create_simulink_from_dbc_enhanced(signals, ''model_name'', options)\n\n');

fprintf('5. To preview DBC contents:\n');
fprintf('   → Use: preview_dbc_signals()\n');
fprintf('   Example: preview_dbc_signals(''dbc/file.dbc'')\n\n');

%% Common Errors and Solutions
fprintf('\nCommon Errors:\n');
fprintf('--------------\n');
fprintf('❌ ERROR: "The use of new_system to create a subsystem is obsolete"\n');
fprintf('✅ SOLUTION: Remove slashes from model name\n');
fprintf('   Wrong: ''components/bms_csi''\n');
fprintf('   Right: ''components_bms_csi''\n\n');

%% Quick Examples
fprintf('Quick Examples:\n');
fprintf('---------------\n\n');

% Example 1: Simple model with manual signals
fprintf('%% Example 1: Simple model\n');
fprintf('signals = {''Motor_Temp'', ''Battery_Voltage'', ''Speed''};\n');
fprintf('create_simulink_from_dbc(signals, ''simple_model'');\n\n');

% Example 2: Large DBC file
fprintf('%% Example 2: Large DBC file (your case with 270 signals)\n');
fprintf('handle_large_dbc(''dbc/CSI_SBOX.dbc'');\n\n');

% Example 3: BMS models
fprintf('%% Example 3: BMS-specific models\n');
fprintf('create_tugvolt_bms_models(''dbc/CSI_eBTMS.dbc'');\n\n');

%% Interactive Menu
fprintf('\n===== Interactive Menu =====\n');
fprintf('What would you like to do?\n\n');
fprintf('1. Preview a DBC file\n');
fprintf('2. Create a simple model\n');
fprintf('3. Handle a large DBC file\n');
fprintf('4. Create BMS models\n');
fprintf('5. View complete workflow example\n');
fprintf('6. Exit\n\n');

choice = input('Enter your choice (1-6): ');

switch choice
    case 1
        dbc_files = dir(fullfile(fileparts(mfilename('fullpath')), '..', 'dbc', '*.dbc'));
        fprintf('\nAvailable DBC files:\n');
        for i = 1:length(dbc_files)
            fprintf('%d. %s\n', i, dbc_files(i).name);
        end
        file_choice = input('Select file number: ');
        if file_choice > 0 && file_choice <= length(dbc_files)
            preview_dbc_signals(fullfile(fileparts(mfilename('fullpath')), '..', 'dbc', dbc_files(file_choice).name));
        end
        
    case 2
        signals = {'Motor_Temperature_1', 'Motor_Temperature_2', 'Velocity'};
        model_name = input('Enter model name (no slashes!): ', 's');
        if isempty(model_name)
            model_name = 'test_model';
        end
        create_simulink_from_dbc(signals, model_name);
        
    case 3
        dbc_file = input('Enter DBC file path: ', 's');
        if isempty(dbc_file)
            dbc_file = 'dbc/CSI_SBOX.dbc';
        end
        handle_large_dbc(dbc_file);
        
    case 4
        create_tugvolt_bms_models();
        
    case 5
        tugvolt_simulink_workflow;
        
    case 6
        fprintf('Exiting...\n');
        
    otherwise
        fprintf('Invalid choice\n');
end

fprintf('\n===== Done =====\n');
