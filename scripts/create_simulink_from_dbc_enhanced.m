function create_simulink_from_dbc_enhanced(dbc_file_or_signals, model_name, options)
% CREATE_SIMULINK_FROM_DBC_ENHANCED Enhanced version with additional features
%
% Usage:
%   create_simulink_from_dbc_enhanced('path/to/file.dbc', 'model_name')
%   create_simulink_from_dbc_enhanced('path/to/file.dbc', 'model_name', options)
%   create_simulink_from_dbc_enhanced({signal_struct}, 'model_name', options)
%
% Inputs:
%   dbc_file_or_signals - DBC file path or signal structure
%   model_name - Name for the new Simulink model
%   options - Structure with optional settings:
%     .groupByMessage - Group signals by CAN message (default: false)
%     .addAnnotations - Add signal descriptions (default: true)
%     .colorCode - Color code by signal type (default: true)
%     .addDataTypes - Add data type conversion blocks (default: false)
%
% Signal structure format for manual input:
%   signals(1).name = 'Motor_Temperature_1';
%   signals(1).message = 'Motor_Status';
%   signals(1).dataType = 'double';
%   signals(1).min = 0;
%   signals(1).max = 150;
%   signals(1).unit = 'degC';

% Default options
if nargin < 3
    options = struct();
end
if ~isfield(options, 'groupByMessage'), options.groupByMessage = false; end
if ~isfield(options, 'addAnnotations'), options.addAnnotations = true; end
if ~isfield(options, 'colorCode'), options.colorCode = true; end
if ~isfield(options, 'addDataTypes'), options.addDataTypes = false; end

% Extract signals
if ischar(dbc_file_or_signals) || isstring(dbc_file_or_signals)
    signals = extract_signals_enhanced(dbc_file_or_signals);
elseif isstruct(dbc_file_or_signals)
    signals = dbc_file_or_signals;
elseif iscell(dbc_file_or_signals)
    % Convert cell array to struct array
    for i = 1:length(dbc_file_or_signals)
        signals(i).name = dbc_file_or_signals{i};
        signals(i).message = 'Unknown';
        signals(i).dataType = 'double';
    end
else
    error('Invalid input type');
end

% Create model
try
    close_system(model_name, 0);
catch
end
new_system(model_name);
open_system(model_name);

% Group signals by message if requested
if options.groupByMessage
    create_grouped_model(model_name, signals, options);
else
    create_flat_model(model_name, signals, options);
end

% Save and arrange
Simulink.BlockDiagram.arrangeSystem(model_name);
save_system(model_name);

fprintf('Enhanced Simulink model "%s" created with %d signals.\n', model_name, length(signals));
end

function create_flat_model(model_name, signals, options)
% Create model with all signals at top level

% Layout parameters
port_height = 30;
port_width = 120;
vertical_spacing = 50;
horizontal_spacing = 500;
start_y = 50;
start_x_in = 50;
start_x_out = start_x_in + horizontal_spacing;

% Color mapping for different signal types
color_map = struct();
color_map.temperature = 'red';
color_map.velocity = 'blue';
color_map.pressure = 'green';
color_map.voltage = 'yellow';
color_map.current = 'orange';
color_map.status = 'cyan';
color_map.default = 'lightBlue';

for i = 1:length(signals)
    signal = signals(i);
    y_position = start_y + (i-1) * vertical_spacing;
    
    % Determine color based on signal name
    if options.colorCode
        color = get_signal_color(signal.name, color_map);
    else
        color = color_map.default;
    end
    
    % Input port
    in_port_name = sprintf('in_%s', signal.name);
    in_port_path = sprintf('%s/%s', model_name, in_port_name);
    add_block('simulink/Sources/In1', in_port_path);
    set_param(in_port_path, 'Position', [start_x_in, y_position, start_x_in + port_width, y_position + port_height]);
    set_param(in_port_path, 'BackgroundColor', color);
    
    % Output port
    out_port_name = sprintf('out_%s', signal.name);
    out_port_path = sprintf('%s/%s', model_name, out_port_name);
    add_block('simulink/Sinks/Out1', out_port_path);
    set_param(out_port_path, 'Position', [start_x_out, y_position, start_x_out + port_width, y_position + port_height]);
    set_param(out_port_path, 'BackgroundColor', color);
    
    % Add data type conversion if requested
    if options.addDataTypes && isfield(signal, 'dataType') && ~strcmp(signal.dataType, 'double')
        % Add conversion block
        conv_name = sprintf('conv_%s', signal.name);
        conv_path = sprintf('%s/%s', model_name, conv_name);
        conv_x = (start_x_in + start_x_out) / 2 - 40;
        
        add_block('simulink/Signal Attributes/Data Type Conversion', conv_path);
        set_param(conv_path, 'Position', [conv_x, y_position, conv_x + 80, y_position + port_height]);
        set_param(conv_path, 'OutDataTypeStr', signal.dataType);
        
        % Connect with conversion
        add_line(model_name, sprintf('%s/1', in_port_name), sprintf('%s/1', conv_name));
        add_line(model_name, sprintf('%s/1', conv_name), sprintf('%s/1', out_port_name));
    else
        % Direct connection
        add_line(model_name, sprintf('%s/1', in_port_name), sprintf('%s/1', out_port_name), 'autorouting', 'on');
    end
    
    % Add annotations
    if options.addAnnotations && (isfield(signal, 'unit') || isfield(signal, 'message'))
        annotation_text = signal.name;
        if isfield(signal, 'unit') && ~isempty(signal.unit)
            annotation_text = sprintf('%s [%s]', annotation_text, signal.unit);
        end
        if isfield(signal, 'message')
            annotation_text = sprintf('%s\n(%s)', annotation_text, signal.message);
        end
        
        annotation_pos = [start_x_in + port_width + 10, y_position - 10, start_x_in + port_width + 200, y_position + 20];
        add_block('simulink/Model-Wide Utilities/Model Info', sprintf('%s/info_%s', model_name, signal.name));
        set_param(sprintf('%s/info_%s', model_name, signal.name), 'Position', annotation_pos);
        set_param(sprintf('%s/info_%s', model_name, signal.name), 'ShowName', 'off');
        set_param(sprintf('%s/info_%s', model_name, signal.name), 'InfoString', annotation_text);
    end
end
end

function create_grouped_model(model_name, signals, options)
% Create model with signals grouped by message in subsystems

% Get unique messages
messages = unique({signals.message});

% Create subsystems for each message
subsystem_spacing = 200;
subsystem_width = 200;
subsystem_start_x = 100;
subsystem_start_y = 50;

for i = 1:length(messages)
    msg = messages{i};
    msg_signals = signals(strcmp({signals.message}, msg));
    
    % Create subsystem
    subsys_name = sprintf('Message_%s', msg);
    subsys_path = sprintf('%s/%s', model_name, subsys_name);
    
    y_pos = subsystem_start_y + (i-1) * subsystem_spacing;
    
    add_block('simulink/Ports & Subsystems/Subsystem', subsys_path);
    set_param(subsys_path, 'Position', [subsystem_start_x, y_pos, subsystem_start_x + subsystem_width, y_pos + 150]);
    
    % Delete default blocks in subsystem
    delete_block(sprintf('%s/In1', subsys_path));
    delete_block(sprintf('%s/Out1', subsys_path));
    
    % Add signals to subsystem
    for j = 1:length(msg_signals)
        signal = msg_signals(j);
        
        % Add input port
        in_name = sprintf('in_%s', signal.name);
        add_block('simulink/Sources/In1', sprintf('%s/%s', subsys_path, in_name));
        set_param(sprintf('%s/%s', subsys_path, in_name), 'Position', [30, 30 + (j-1)*60, 100, 50 + (j-1)*60]);
        
        % Add output port
        out_name = sprintf('out_%s', signal.name);
        add_block('simulink/Sinks/Out1', sprintf('%s/%s', subsys_path, out_name));
        set_param(sprintf('%s/%s', subsys_path, out_name), 'Position', [300, 30 + (j-1)*60, 370, 50 + (j-1)*60]);
        
        % Connect
        add_line(subsys_path, sprintf('%s/1', in_name), sprintf('%s/1', out_name));
    end
end
end

function signals = extract_signals_enhanced(dbc_file)
% Extract enhanced signal information from DBC file

signals = struct([]);

try
    % Try Vehicle Network Toolbox first
    if license('test', 'Vehicle_Network_Toolbox')
        db = canDatabase(dbc_file);
        
        idx = 1;
        for i = 1:length(db.Messages)
            msg = db.Messages(i);
            for j = 1:length(msg.Signals)
                sig = msg.Signals(j);
                signals(idx).name = sig.Name;
                signals(idx).message = msg.Name;
                signals(idx).dataType = class(sig.InitialValue);
                signals(idx).min = sig.Min;
                signals(idx).max = sig.Max;
                signals(idx).unit = sig.Units;
                idx = idx + 1;
            end
        end
        return;
    end
catch
end

% Fallback to basic parsing
fid = fopen(dbc_file, 'r');
if fid == -1
    error('Cannot open DBC file');
end

current_message = 'Unknown';
idx = 1;

while ~feof(fid)
    line = fgetl(fid);
    if ischar(line)
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
                idx = idx + 1;
            end
        end
    end
end

fclose(fid);
end

function color = get_signal_color(signal_name, color_map)
% Determine color based on signal name keywords

signal_lower = lower(signal_name);

if contains(signal_lower, 'temperature') || contains(signal_lower, 'temp')
    color = color_map.temperature;
elseif contains(signal_lower, 'velocity') || contains(signal_lower, 'speed')
    color = color_map.velocity;
elseif contains(signal_lower, 'pressure')
    color = color_map.pressure;
elseif contains(signal_lower, 'voltage')
    color = color_map.voltage;
elseif contains(signal_lower, 'current')
    color = color_map.current;
elseif contains(signal_lower, 'status')
    color = color_map.status;
else
    color = color_map.default;
end
end
