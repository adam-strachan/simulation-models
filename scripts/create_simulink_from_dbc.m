function create_simulink_from_dbc(dbc_file_or_signals, model_name)
% CREATE_SIMULINK_FROM_DBC Creates a Simulink model with input/output ports for each signal
%
% Usage:
%   create_simulink_from_dbc('path/to/file.dbc', 'model_name')  % Read from DBC file
%   create_simulink_from_dbc({'Signal1', 'Signal2', ...}, 'model_name')  % Use signal list
%
% Inputs:
%   dbc_file_or_signals - Either a path to a DBC file (string) or a cell array of signal names
%   model_name - Name for the new Simulink model (string)
%
% Example:
%   create_simulink_from_dbc('dbc/CSI_SBOX.dbc', 'tugvolt_model')
%   create_simulink_from_dbc({'Motor_Temperature_1', 'Motor_Temperature_2', 'Velocity'}, 'tugvolt_model')

% Check if input is a DBC file or signal list
if ischar(dbc_file_or_signals) || isstring(dbc_file_or_signals)
    % Input is a file path
    signal_names = extract_signals_from_dbc(dbc_file_or_signals);
elseif iscell(dbc_file_or_signals)
    % Input is a cell array of signal names
    signal_names = dbc_file_or_signals;
else
    error('First input must be either a DBC file path or a cell array of signal names');
end

% Create new Simulink model
try
    close_system(model_name, 0);
catch
    % Model doesn't exist, that's fine
end

new_system(model_name);
open_system(model_name);

% Layout parameters
port_height = 30;
port_width = 100;
vertical_spacing = 60;
horizontal_spacing = 400;
start_y = 50;
start_x_in = 50;
start_x_out = start_x_in + horizontal_spacing;

% Add blocks for each signal
for i = 1:length(signal_names)
    signal_name = signal_names{i};
    y_position = start_y + (i-1) * vertical_spacing;
    
    % Create input port
    in_port_name = sprintf('in_%s', signal_name);
    in_port_path = sprintf('%s/%s', model_name, in_port_name);
    add_block('simulink/Sources/In1', in_port_path);
    set_param(in_port_path, 'Position', [start_x_in, y_position, start_x_in + port_width, y_position + port_height]);
    
    % Create output port
    out_port_name = sprintf('out_%s', signal_name);
    out_port_path = sprintf('%s/%s', model_name, out_port_name);
    add_block('simulink/Sinks/Out1', out_port_path);
    set_param(out_port_path, 'Position', [start_x_out, y_position, start_x_out + port_width, y_position + port_height]);
    
    % Connect input to output
    add_line(model_name, sprintf('%s/1', in_port_name), sprintf('%s/1', out_port_name), 'autorouting', 'on');
end

% Auto-arrange the model
Simulink.BlockDiagram.arrangeSystem(model_name);

% Save the model
save_system(model_name);

fprintf('Simulink model "%s" created successfully with %d signal pairs.\n', model_name, length(signal_names));

end

function signal_names = extract_signals_from_dbc(dbc_file)
% EXTRACT_SIGNALS_FROM_DBC Extract signal names from a DBC file
%
% This function attempts to extract signals using two methods:
% 1. Using Vehicle Network Toolbox (if available)
% 2. Basic text parsing of the DBC file

signal_names = {};

% Method 1: Try using Vehicle Network Toolbox
try
    % Check if Vehicle Network Toolbox is available
    if license('test', 'Vehicle_Network_Toolbox')
        db = canDatabase(dbc_file);
        
        % Extract all signal names
        message_names = {db.Messages.Name};
        for i = 1:length(db.Messages)
            msg = db.Messages(i);
            if ~isempty(msg.Signals)
                signal_names = [signal_names, {msg.Signals.Name}];
            end
        end
        
        % Remove duplicates
        signal_names = unique(signal_names);
        
        fprintf('Extracted %d unique signals using Vehicle Network Toolbox\n', length(signal_names));
        return;
    end
catch
    % Vehicle Network Toolbox not available or error occurred
    fprintf('Vehicle Network Toolbox not available, using basic parsing...\n');
end

% Method 2: Basic text parsing
try
    fid = fopen(dbc_file, 'r');
    if fid == -1
        error('Cannot open DBC file: %s', dbc_file);
    end
    
    % Read file line by line
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            % Look for signal definitions (lines starting with " SG_")
            if contains(line, ' SG_ ')
                % Extract signal name
                % Format: SG_ SignalName : ...
                tokens = regexp(line, '\s+SG_\s+(\w+)\s*:', 'tokens');
                if ~isempty(tokens)
                    signal_names{end+1} = tokens{1}{1};
                end
            end
        end
    end
    
    fclose(fid);
    
    % Remove duplicates
    signal_names = unique(signal_names);
    
    fprintf('Extracted %d unique signals using basic parsing\n', length(signal_names));
    
catch ME
    if exist('fid', 'var') && fid ~= -1
        fclose(fid);
    end
    error('Error parsing DBC file: %s', ME.message);
end

if isempty(signal_names)
    warning('No signals found in DBC file');
end

end
