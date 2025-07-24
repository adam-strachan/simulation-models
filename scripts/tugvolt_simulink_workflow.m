% Complete TugVolt Simulink Model Generation Workflow
% This script demonstrates the full workflow for creating Simulink models
% for the TugVolt train simulation system (SPARK)

%% Step 1: Preview available DBC files
fprintf('=== Step 1: Preview Available DBC Files ===\n');
dbc_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'dbc');

% Show available DBC files
dbc_files = dir(fullfile(dbc_dir, '*.dbc'));
fprintf('\nAvailable DBC files:\n');
for i = 1:length(dbc_files)
    fprintf('  %d. %s\n', i, dbc_files(i).name);
end

%% Step 2: Analyze a relevant DBC file (SEVCON motor controller)
fprintf('\n\n=== Step 2: Analyze SEVCON Motor Controller DBC ===\n');
sevcon_dbc = fullfile(dbc_dir, 'SEVCON_GEN4_SIZE10.dbc');
preview_dbc_signals(sevcon_dbc);

%% Step 3: Create basic TugVolt model with manual signal list
fprintf('\n\n=== Step 3: Create Basic TugVolt Model ===\n');

% Define comprehensive TugVolt signals based on concept document
tugvolt_signals = {
    % Motor/Drive signals
    'Motor_Temperature_1'
    'Motor_Temperature_2'
    'Velocity'
    'Torque_Actual'
    'Torque_Demand'
    'Control_Word'
    'Status_Word'
    
    % Battery/Energy signals
    'DC_bus_voltage'
    'DC_bus_current'
    'Battery_SOC'
    'Charging_Status'
    
    % Pneumatic signals
    'Brake_Pressure'
    'Compressor_Status'
    
    % Navigation signals
    'GPS_Latitude'
    'GPS_Longitude'
    'IMU_AccelX'
    'IMU_AccelY'
    'IMU_AccelZ'
    
    % Communication/Status
    'Operational_State'
    'Emergency_Status'
};

% Create the basic model
model_name_basic = 'tugvolt_spark_basic';
create_simulink_from_dbc(tugvolt_signals, model_name_basic);

%% Step 4: Create enhanced model from SEVCON DBC
fprintf('\n\n=== Step 4: Create Enhanced Model from SEVCON DBC ===\n');

model_name_sevcon = 'tugvolt_sevcon_enhanced';
options = struct();
options.groupByMessage = true;
options.colorCode = true;
options.addAnnotations = true;
options.addDataTypes = false;

create_simulink_from_dbc_enhanced(sevcon_dbc, model_name_sevcon, options);

%% Step 5: Create integrated TugVolt model with structured signals
fprintf('\n\n=== Step 5: Create Integrated TugVolt Model ===\n');

% Define structured signals with metadata
clear integrated_signals;

% Motor control signals (from SEVCON)
integrated_signals(1).name = 'Motor_Temperature_1';
integrated_signals(1).message = 'Motor_Status';
integrated_signals(1).dataType = 'int16';
integrated_signals(1).unit = 'degC';

integrated_signals(2).name = 'Motor_Temperature_2';
integrated_signals(2).message = 'Motor_Status';
integrated_signals(2).dataType = 'int16';
integrated_signals(2).unit = 'degC';

integrated_signals(3).name = 'Velocity';
integrated_signals(3).message = 'Motor_Status';
integrated_signals(3).dataType = 'int32';
integrated_signals(3).unit = 'rpm';

integrated_signals(4).name = 'Torque_Actual';
integrated_signals(4).message = 'Motor_Control';
integrated_signals(4).dataType = 'double';
integrated_signals(4).unit = 'Nm';

integrated_signals(5).name = 'Torque_Demand';
integrated_signals(5).message = 'Motor_Control';
integrated_signals(5).dataType = 'double';
integrated_signals(5).unit = 'Nm';

% Battery management signals
integrated_signals(6).name = 'DC_Bus_Voltage';
integrated_signals(6).message = 'Battery_Status';
integrated_signals(6).dataType = 'double';
integrated_signals(6).unit = 'V';

integrated_signals(7).name = 'DC_Bus_Current';
integrated_signals(7).message = 'Battery_Status';
integrated_signals(7).dataType = 'double';
integrated_signals(7).unit = 'A';

integrated_signals(8).name = 'Battery_SOC';
integrated_signals(8).message = 'Battery_Status';
integrated_signals(8).dataType = 'double';
integrated_signals(8).unit = '%';

% Pneumatic system signals
integrated_signals(9).name = 'Brake_Pressure';
integrated_signals(9).message = 'Pneumatic_System';
integrated_signals(9).dataType = 'double';
integrated_signals(9).unit = 'psi';

integrated_signals(10).name = 'Compressor_Status';
integrated_signals(10).message = 'Pneumatic_System';
integrated_signals(10).dataType = 'uint8';
integrated_signals(10).unit = '';

% Navigation signals
integrated_signals(11).name = 'GPS_Latitude';
integrated_signals(11).message = 'Navigation';
integrated_signals(11).dataType = 'double';
integrated_signals(11).unit = 'deg';

integrated_signals(12).name = 'GPS_Longitude';
integrated_signals(12).message = 'Navigation';
integrated_signals(12).dataType = 'double';
integrated_signals(12).unit = 'deg';

% Create the integrated model
model_name_integrated = 'tugvolt_spark_integrated';
options_integrated = struct();
options_integrated.groupByMessage = true;
options_integrated.colorCode = true;
options_integrated.addAnnotations = true;
options_integrated.addDataTypes = true;

create_simulink_from_dbc_enhanced(integrated_signals, model_name_integrated, options_integrated);

%% Step 6: Summary and next steps
fprintf('\n\n=== Summary ===\n');
fprintf('Created the following Simulink models:\n');
fprintf('1. %s - Basic model with signal list\n', model_name_basic);
fprintf('2. %s - Enhanced model from SEVCON DBC\n', model_name_sevcon);
fprintf('3. %s - Integrated model with full metadata\n', model_name_integrated);

fprintf('\n=== Next Steps ===\n');
fprintf('1. Open the models in Simulink to review the structure\n');
fprintf('2. Add control logic between input and output ports\n');
fprintf('3. Configure data logging for signals of interest\n');
fprintf('4. Set up simulation parameters for TugVolt operation\n');
fprintf('5. Integrate with CAN communication blocks for HIL testing\n');

fprintf('\nTo open a model, use:\n');
fprintf('  open_system(''%s'')\n', model_name_integrated);

%% Optional: Create a simple test harness
fprintf('\n\n=== Optional: Create Test Harness ===\n');
response = input('Create a test harness model? (y/n): ', 's');

if strcmpi(response, 'y')
    harness_name = 'tugvolt_test_harness';
    
    % Create new model
    try
        close_system(harness_name, 0);
    catch
    end
    new_system(harness_name);
    open_system(harness_name);
    
    % Add the integrated model as a reference
    add_block('simulink/Ports & Subsystems/Model', [harness_name '/TugVolt_System']);
    set_param([harness_name '/TugVolt_System'], 'ModelName', model_name_integrated);
    set_param([harness_name '/TugVolt_System'], 'Position', [200, 100, 400, 300]);
    
    % Add test signal generators
    add_block('simulink/Sources/Signal Generator', [harness_name '/Speed_Command']);
    set_param([harness_name '/Speed_Command'], 'Position', [50, 50, 100, 80]);
    set_param([harness_name '/Speed_Command'], 'WaveForm', 'square');
    set_param([harness_name '/Speed_Command'], 'Frequency', '0.1');
    
    % Add scope for monitoring
    add_block('simulink/Sinks/Scope', [harness_name '/Output_Monitor']);
    set_param([harness_name '/Output_Monitor'], 'Position', [500, 150, 550, 200]);
    
    % Save harness
    save_system(harness_name);
    
    fprintf('Test harness "%s" created successfully!\n', harness_name);
end

fprintf('\n=== Workflow Complete ===\n');
