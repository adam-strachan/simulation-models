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
if ~isfield(options, 'groupByMessage'), options.groupByMessage = true; end  % Changed to true by default
if ~isfield(options, 'addAnnotations'), options.addAnnotations = false; end  % Changed to false by default
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

% Validate model name
if contains(model_name, '/') || contains(model_name, '\')
    error('Model name cannot contain path separators (/ or \). Please use a simple name like ''%s''', ...
        strrep(model_name, '/', '_'));
end

% Create model
try
    close_system(model_name, 0);
catch
end

try
    new_system(model_name);
    open_system(model_name);
catch ME
    if contains(ME.message, 'already exists')
        error('Model ''%s'' already exists and is locked. Please close it first or use a different name.', model_name);
    else
        rethrow(ME);
    end
end

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
        
        % Use Annotation instead of Model Info block
        annotation_x = (start_x_in + start_x_out) / 2;
        annotation_y = y_position + port_height + 5;
        
        annotation_pos = [annotation_x - 50, annotation_y, annotation_x + 50, annotation_y + 20];
        add_block('built-in/Note', sprintf('%s/Note_%d', model_name, i), ...
            'Position', annotation_pos, ...
            'ShowName', 'off', ...
            'Description', annotation_text);
    end
end
end

function create_grouped_model(model_name, signals, options)
% Create model with signals grouped by message in subsystems

% Get unique messages
messages = unique({signals.message});

% Layout parameters
subsystem_width = 200;
subsystem_height = 150;
subsystem_spacing = 200;
subsystem_start_x = 100;
subsystem_start_y = 50;
columns = ceil(sqrt(length(messages)));

% Color mapping
color_map = struct();
color_map.temperature = 'red';
color_map.velocity = 'blue';
color_map.pressure = 'green';
color_map.voltage = 'yellow';
color_map.current = 'orange';
color_map.status = 'cyan';
color_map.default = 'lightBlue';

for i = 1:length(messages)
    msg = messages{i};
    msg_signals = signals(strcmp({signals.message}, msg));
    
    % Clean message name for subsystem
    clean_msg_name = regexprep(msg, '[^a-zA-Z0-9_]', '_');
    if ~isempty(regexp(clean_msg_name, '^\d', 'once'))
        clean_msg_name = ['Msg_' clean_msg_name];
    end
    
    % Calculate subsystem position
    row = floor((i-1) / columns);
    col = mod(i-1, columns);
    x_pos = subsystem_start_x + col * (subsystem_width + 50);
    y_pos = subsystem_start_y + row * subsystem_spacing;
    
    % Create subsystem
    subsys_name = clean_msg_name;
    subsys_path = sprintf('%s/%s', model_name, subsys_name);
    
    add_block('built-in/Subsystem', subsys_path);
    set_param(subsys_path, 'Position', [x_pos, y_pos, x_pos + subsystem_width, y_pos + subsystem_height]);
    
    % Delete default blocks in subsystem
    try
        delete_block(sprintf('%s/In1', subsys_path));
        delete_block(sprintf('%s/Out1', subsys_path));
    catch
        % Ignore if blocks don't exist
    end
    
    % Add signals to subsystem
    port_height = 30;
    port_width = 100;
    vertical_spacing = 40;
    horizontal_spacing = 300;
    start_y_sub = 50;
    start_x_in = 50;
    start_x_out = start_x_in + horizontal_spacing;
    
    for j = 1:length(msg_signals)
        signal = msg_signals(j);
        y_position = start_y_sub + (j-1) * vertical_spacing;
        
        % Clean signal name
        clean_signal_name = regexprep(signal.name, '[^a-zA-Z0-9_]', '_');
        if ~isempty(regexp(clean_signal_name, '^\d', 'once'))
            clean_signal_name = ['Signal_' clean_signal_name];
        end
        
        % Determine color
        if options.colorCode
            color = get_signal_color(signal.name, color_map);
        else
            color = color_map.default;
        end
        
        % Add input port
        in_name = sprintf('in_%s', clean_signal_name);
        in_path = sprintf('%s/%s', subsys_path, in_name);
        add_block('simulink/Sources/In1', in_path);
        set_param(in_path, 'Position', [start_x_in, y_position, start_x_in + port_width, y_position + port_height]);
        set_param(in_path, 'BackgroundColor', color);
        
        % Add output port
        out_name = sprintf('out_%s', clean_signal_name);
        out_path = sprintf('%s/%s', subsys_path, out_name);
        add_block('simulink/Sinks/Out1', out_path);
        set_param(out_path, 'Position', [start_x_out, y_position, start_x_out + port_width, y_position + port_height]);
        set_param(out_path, 'BackgroundColor', color);
        
        % Add data type conversion if requested
        if options.addDataTypes && isfield(signal, 'dataType') && ~strcmp(signal.dataType, 'double')
            % Add conversion block
            conv_name = sprintf('conv_%s', clean_signal_name);
            conv_path = sprintf('%s/%s', subsys_path, conv_name);
            conv_x = (start_x_in + start_x_out) / 2 - 40;
            
            add_block('simulink/Signal Attributes/Data Type Conversion', conv_path);
            set_param(conv_path, 'Position', [conv_x, y_position, conv_x + 80, y_position + port_height]);
            set_param(conv_path, 'OutDataTypeStr', signal.dataType);
            
            % Connect with conversion
            add_line(subsys_path, sprintf('%s/1', in_name), sprintf('%s/1', conv_name));
            add_line(subsys_path, sprintf('%s/1', conv_name), sprintf('%s/1', out_name));
        else
            % Direct connection
            add_line(subsys_path, sprintf('%s/1', in_name), sprintf('%s/1', out_name), 'autorouting', 'on');
        end
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
