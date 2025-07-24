% Example script for creating TugVolt Simulink model
% This script demonstrates how to use create_simulink_from_dbc function

% Example 1: Create model using a list of signals
% Based on the TugVolt train simulation system
tugvolt_signals = {
    'Motor_Temperature_1'
    'Motor_Temperature_2'
    'Velocity'
    'Battery_Voltage'
    'Battery_Current'
    'Battery_SOC'
    'Brake_Pressure'
    'Throttle_Position'
    'GPS_Latitude'
    'GPS_Longitude'
    'IMU_AccelX'
    'IMU_AccelY'
    'IMU_AccelZ'
    'Compressor_Status'
    'Charging_Status'
};

% Create the model
create_simulink_from_dbc(tugvolt_signals, 'tugvolt_spark_model');

% Example 2: Create model from a DBC file (if available)
% Uncomment the following lines to use with an actual DBC file:
% dbc_file_path = fullfile(pwd, '..', 'dbc', 'CSI_SBOX.dbc');
% create_simulink_from_dbc(dbc_file_path, 'tugvolt_from_dbc');

% Example 3: Create a simple test model with just the signals shown in the image
test_signals = {
    'Motor_Temperature_1'
    'Motor_Temperature_2'  
    'Velocity'
};

create_simulink_from_dbc(test_signals, 'simple_tugvolt_model');

fprintf('\nModels created successfully!\n');
fprintf('You can now open the models in Simulink and add your control logic.\n');
