function create_tugvolt_bms_models(dbc_file)
% CREATE_TUGVOLT_BMS_MODELS Create organized BMS models for TugVolt
%
% This function creates well-organized Simulink models specifically for
% TugVolt Battery Management System (BMS) signals from CSI DBC files.
%
% Usage:
%   create_tugvolt_bms_models('dbc/CSI_eBTMS.dbc')
%   create_tugvolt_bms_models('dbc/CSI_SBOX.dbc')
%
% Creates multiple models:
%   - tugvolt_bms_core: Essential BMS signals
%   - tugvolt_bms_cells: Individual cell voltages/temperatures
%   - tugvolt_bms_safety: Safety and fault signals
%   - tugvolt_bms_charging: Charging-related signals

if nargin < 1
    % List available CSI DBC files
    dbc_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'dbc');
    csi_files = dir(fullfile(dbc_dir, 'CSI_*.dbc'));
    
    fprintf('Available CSI DBC files:\n');
    for i = 1:length(csi_files)
        fprintf('%d. %s\n', i, csi_files(i).name);
    end
    
    choice = input('Select file number: ');
    if choice > 0 && choice <= length(csi_files)
        dbc_file = fullfile(dbc_dir, csi_files(choice).name);
    else
        error('Invalid selection');
    end
end

fprintf('\n=== Creating TugVolt BMS Models from %s ===\n', dbc_file);

% Extract all signals
all_signals = extract_signals_for_bms(dbc_file);

if isempty(all_signals)
    error('No signals found in DBC file');
end

fprintf('Found %d total signals\n', length(all_signals));

% Categorize signals
categories = categorize_bms_signals(all_signals);

% Create models for each category
create_bms_model_set(categories);

fprintf('\n=== BMS Model Creation Complete ===\n');
fprintf('Created models:\n');
fprintf('  - tugvolt_bms_core\n');
fprintf('  - tugvolt_bms_cells\n');
fprintf('  - tugvolt_bms_safety\n');
fprintf('  - tugvolt_bms_charging\n');
fprintf('  - tugvolt_bms_thermal\n');
fprintf('\nUse open_system(''model_name'') to view each model\n');

end

function signals = extract_signals_for_bms(dbc_file)
% Extract signals with BMS-specific parsing

% First try standard extraction
signals = extract_signals_basic(dbc_file);

% Clean and validate signal names
for i = 1:length(signals)
    % Remove special characters but preserve underscores
    signals(i).name = regexprep(signals(i).name, '[^a-zA-Z0-9_]', '_');
    
    % Ensure valid MATLAB names
    if ~isempty(regexp(signals(i).name, '^\d', 'once'))
        signals(i).name = ['Signal_' signals(i).name];
    end
end

end

function categories = categorize_bms_signals(signals)
% Categorize signals into BMS subsystems

categories = struct();
categories.core = [];
categories.cells = [];
categories.safety = [];
categories.charging = [];
categories.thermal = [];
categories.other = [];

for i = 1:length(signals)
    sig_name_lower = lower(signals(i).name);
    
    % Core BMS signals
    if contains(sig_name_lower, {'soc', 'soh', 'pack_voltage', 'pack_current', ...
                                'total_voltage', 'total_current', 'power', ...
                                'energy', 'capacity', 'resistance'})
        categories.core(end+1) = i;
        
    % Cell-level signals
    elseif contains(sig_name_lower, {'cell', 'module'}) && ...
           (contains(sig_name_lower, {'voltage', 'temp', 'balance', 'resistance'}))
        categories.cells(end+1) = i;
        
    % Safety and fault signals
    elseif contains(sig_name_lower, {'fault', 'error', 'alarm', 'warning', ...
                                    'protection', 'safety', 'emergency', ...
                                    'overvoltage', 'undervoltage', 'overcurrent'})
        categories.safety(end+1) = i;
        
    % Charging signals
    elseif contains(sig_name_lower, {'charge', 'charging', 'charger', ...
                                    'plug', 'inlet', 'dc_', 'ac_'})
        categories.charging(end+1) = i;
        
    % Thermal management
    elseif contains(sig_name_lower, {'temp', 'thermal', 'cooling', 'heating', ...
                                    'fan', 'pump', 'coolant'})
        categories.thermal(end+1) = i;
        
    % Other signals
    else
        categories.other(end+1) = i;
    end
end

% Display categorization summary
fprintf('\nSignal categorization:\n');
fprintf('  Core BMS: %d signals\n', length(categories.core));
fprintf('  Cell-level: %d signals\n', length(categories.cells));
fprintf('  Safety/Faults: %d signals\n', length(categories.safety));
fprintf('  Charging: %d signals\n', length(categories.charging));
fprintf('  Thermal: %d signals\n', length(categories.thermal));
fprintf('  Other: %d signals\n', length(categories.other));

end

function create_bms_model_set(categories)
% Create organized models for each category

all_signals = evalin('caller', 'all_signals');

% Model options
opts = struct();
opts.colorCode = true;
opts.addAnnotations = true;

% 1. Core BMS Model
if ~isempty(categories.core)
    core_signals = all_signals(categories.core);
    
    % Add essential signals if missing
    essential_names = {'Battery_SOC', 'Pack_Voltage', 'Pack_Current'};
    for i = 1:length(essential_names)
        if ~any(strcmp({core_signals.name}, essential_names{i}))
            core_signals(end+1).name = essential_names{i};
            core_signals(end).message = 'BMS_Core';
            core_signals(end).dataType = 'double';
            core_signals(end).unit = '';
        end
    end
    
    create_simulink_from_dbc_enhanced(core_signals, 'tugvolt_bms_core', opts);
end

% 2. Cell Monitoring Model
if ~isempty(categories.cells)
    cell_signals = all_signals(categories.cells);
    
    % Limit to reasonable number of cells
    if length(cell_signals) > 96  % Max 96 cells (typical for large packs)
        fprintf('Warning: Found %d cell signals, limiting to first 96\n', length(cell_signals));
        cell_signals = cell_signals(1:96);
    end
    
    opts.groupByMessage = true;  % Group by cell modules
    create_simulink_from_dbc_enhanced(cell_signals, 'tugvolt_bms_cells', opts);
end

% 3. Safety Model
if ~isempty(categories.safety)
    safety_signals = all_signals(categories.safety);
    create_simulink_from_dbc_enhanced(safety_signals, 'tugvolt_bms_safety', opts);
end

% 4. Charging Model
if ~isempty(categories.charging)
    charging_signals = all_signals(categories.charging);
    
    % Add standard charging signals if missing
    standard_charging = {'Charging_Status', 'Charge_Current', 'Charge_Voltage'};
    for i = 1:length(standard_charging)
        if ~any(strcmp({charging_signals.name}, standard_charging{i}))
            charging_signals(end+1).name = standard_charging{i};
            charging_signals(end).message = 'Charging_Control';
            charging_signals(end).dataType = 'double';
            charging_signals(end).unit = '';
        end
    end
    
    create_simulink_from_dbc_enhanced(charging_signals, 'tugvolt_bms_charging', opts);
end

% 5. Thermal Management Model
if ~isempty(categories.thermal)
    thermal_signals = all_signals(categories.thermal);
    create_simulink_from_dbc_enhanced(thermal_signals, 'tugvolt_bms_thermal', opts);
end

% 6. Create integrated test harness
create_bms_test_harness();

end

function create_bms_test_harness()
% Create a test harness that references all BMS models

harness_name = 'tugvolt_bms_test_harness';

try
    close_system(harness_name, 0);
catch
end

new_system(harness_name);
open_system(harness_name);

% Add subsystem references
models = {'tugvolt_bms_core', 'tugvolt_bms_cells', 'tugvolt_bms_safety', ...
          'tugvolt_bms_charging', 'tugvolt_bms_thermal'};

y_pos = 50;
for i = 1:length(models)
    try
        % Check if model exists
        load_system(models{i});
        
        % Add model reference
        block_name = sprintf('%s/%s', harness_name, models{i});
        add_block('simulink/Ports & Subsystems/Model', block_name);
        set_param(block_name, 'ModelName', models{i});
        set_param(block_name, 'Position', [100, y_pos, 300, y_pos + 80]);
        
        y_pos = y_pos + 120;
    catch
        % Model doesn't exist, skip
    end
end

% Add test sources
add_block('simulink/Sources/Constant', [harness_name '/SOC_Setpoint']);
set_param([harness_name '/SOC_Setpoint'], 'Position', [400, 50, 450, 80]);
set_param([harness_name '/SOC_Setpoint'], 'Value', '80');

add_block('simulink/Sources/Signal Generator', [harness_name '/Current_Profile']);
set_param([harness_name '/Current_Profile'], 'Position', [400, 120, 450, 150]);
set_param([harness_name '/Current_Profile'], 'WaveForm', 'sine');
set_param([harness_name '/Current_Profile'], 'Amplitude', '50');
set_param([harness_name '/Current_Profile'], 'Frequency', '0.01');

% Add monitoring
add_block('simulink/Sinks/Scope', [harness_name '/BMS_Monitor']);
set_param([harness_name '/BMS_Monitor'], 'Position', [550, 85, 600, 115]);
set_param([harness_name '/BMS_Monitor'], 'NumInputPorts', '4');

% Save harness
save_system(harness_name);

end

function signals = extract_signals_basic(dbc_file)
% Basic signal extraction (simplified version)

signals = struct([]);

fid = fopen(dbc_file, 'r');
if fid == -1
    error('Cannot open DBC file: %s', dbc_file);
end

current_message = 'Unknown';
idx = 1;

while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line)
        continue;
    end
    
    % Parse message
    if contains(line, 'BO_ ')
        tokens = regexp(line, 'BO_\s+\d+\s+(\w+)', 'tokens');
        if ~isempty(tokens)
            current_message = tokens{1}{1};
        end
    end
    
    % Parse signal
    if contains(line, ' SG_ ')
        tokens = regexp(line, '\s+SG_\s+(\w+)\s*:', 'tokens');
        if ~isempty(tokens)
            signals(idx).name = tokens{1}{1};
            signals(idx).message = current_message;
            signals(idx).dataType = 'double';
            signals(idx).unit = '';
            
            % Extract unit if present
            unit_tokens = regexp(line, '"([^"]*)"', 'tokens');
            if ~isempty(unit_tokens) && ~isempty(unit_tokens{1})
                signals(idx).unit = unit_tokens{1}{1};
            end
            
            idx = idx + 1;
        end
    end
end

fclose(fid);
end
