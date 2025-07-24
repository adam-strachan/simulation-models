function create_simulink_from_dbc_fixed(dbc_file_or_signals, model_name, options)
% CREATE_SIMULINK_FROM_DBC_FIXED Fixed version with better annotation handling
%
% This version fixes the annotation error and provides better compatibility
%
% Usage:
%   create_simulink_from_dbc_fixed('path/to/file.dbc', 'model_name')
%   create_simulink_from_dbc_fixed('path/to/file.dbc', 'model_name', options)
%   create_simulink_from_dbc_fixed({signal_list}, 'model_name')
%
% Options:
%   .groupByMessage - Group signals by CAN message (default: false)
%   .addAnnotations - Add signal descriptions (default: false) 
%   .colorCode - Color code by signal type (default: true)
%   .useTextAnnotations - Use text annotations instead of blocks (default: true)
%   .maxSignalsPerColumn - Max signals per column (default: 25)

% Default options
if nargin < 3
    options = struct();
end
if ~isfield(options, 'groupByMessage'), options.groupByMessage = false; end
if ~isfield(options, 'addAnnotations'), options.addAnnotations = false; end
if ~isfield(options, 'colorCode'), options.colorCode = true; end
if ~isfield(options, 'useTextAnnotations'), options.useTextAnnotations = true; end
if ~isfield(options, 'maxSignalsPerColumn'), options.maxSignalsPerColumn = 25; end

% Extract signals
if ischar(dbc_file_or_signals) || isstring(dbc_file_or_signals)
    signals = extract_signals_safe(dbc_file_or_signals);
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

% Check signal count
if length(signals) > 100
    fprintf('Warning: Creating model with %d signals. This may take a while.\n', length(signals));
    fprintf('Consider using handle_large_dbc() for better organization.\n');
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
        error('Model ''%s'' already exists. Please close it first or use a different name.', model_name);
    else
        rethrow(ME);
    end
end

% Create the model
create_model_layout(model_name, signals, options);

% Add model description
try
    set_param(model_name, 'Description', sprintf('Generated from %d signals', length(signals)));
catch
    % Ignore if setting description fails
end

% Save and arrange
try
    Simulink.BlockDiagram.arrangeSystem(model_name);
catch
    % If auto-arrange fails, continue anyway
end

save_system(model_name);

fprintf('Model "%s" created successfully with %d signals.\n', model_name, length(signals));
fprintf('Annotations: %s\n', options.addAnnotations ? 'Enabled (text format)' : 'Disabled');

end

function create_model_layout(model_name, signals, options)
% Create the model layout with proper signal organization

% Layout parameters
port_height = 30;
port_width = 120;
vertical_spacing = 40;
horizontal_spacing = 400;
column_spacing = 600;
start_y = 50;
start_x_in = 50;
start_x_out = start_x_in + horizontal_spacing;

% Color mapping
color_map = get_color_map();

% Calculate layout
max_per_col = options.maxSignalsPerColumn;
num_columns = ceil(length(signals) / max_per_col);

% Create ports
for i = 1:length(signals)
    signal = signals(i);
    
    % Calculate position
    column = floor((i-1) / max_per_col);
    row = mod(i-1, max_per_col);
    
    y_position = start_y + row * vertical_spacing;
    x_offset = column * column_spacing;
    
    % Clean signal name
    clean_name = regexprep(signal.name, '[^a-zA-Z0-9_]', '_');
    
    % Ensure valid MATLAB identifier
    if ~isempty(regexp(clean_name, '^\d', 'once'))
        clean_name = ['Signal_' clean_name];
    end
    
    % Get color
    if options.colorCode
        block_color = get_signal_color(clean_name, color_map);
    else
        block_color = 'lightBlue';
    end
    
    % Create input port
    in_port_name = sprintf('in_%s', clean_name);
    in_port_path = sprintf('%s/%s', model_name, in_port_name);
    
    try
        add_block('simulink/Sources/In1', in_port_path);
        set_param(in_port_path, 'Position', ...
            [start_x_in + x_offset, y_position, start_x_in + x_offset + port_width, y_position + port_height]);
        set_param(in_port_path, 'BackgroundColor', block_color);
    catch ME
        warning('Failed to create input port %s: %s', in_port_name, ME.message);
        continue;
    end
    
    % Create output port
    out_port_name = sprintf('out_%s', clean_name);
    out_port_path = sprintf('%s/%s', model_name, out_port_name);
    
    try
        add_block('simulink/Sinks/Out1', out_port_path);
        set_param(out_port_path, 'Position', ...
            [start_x_out + x_offset, y_position, start_x_out + x_offset + port_width, y_position + port_height]);
        set_param(out_port_path, 'BackgroundColor', block_color);
    catch ME
        warning('Failed to create output port %s: %s', out_port_name, ME.message);
        continue;
    end
    
    % Connect ports
    try
        add_line(model_name, sprintf('%s/1', in_port_name), sprintf('%s/1', out_port_name), 'autorouting', 'on');
    catch
        % If autorouting fails, try direct connection
        try
            add_line(model_name, sprintf('%s/1', in_port_name), sprintf('%s/1', out_port_name));
        catch
            warning('Failed to connect %s to %s', in_port_name, out_port_name);
        end
    end
    
    % Add text annotation if enabled
    if options.addAnnotations && options.useTextAnnotations
        add_text_annotation(model_name, signal, x_offset, y_position, start_x_in, start_x_out, port_height);
    end
end

end

function add_text_annotation(model_name, signal, x_offset, y_position, start_x_in, start_x_out, port_height)
% Add text annotation for signal info

annotation_text = signal.name;
if isfield(signal, 'unit') && ~isempty(signal.unit) && ~strcmp(signal.unit, '')
    annotation_text = sprintf('%s [%s]', annotation_text, signal.unit);
end

% Position annotation below the connection line
ann_x1 = (start_x_in + start_x_out + x_offset * 2) / 2 - 50;
ann_y1 = y_position + port_height + 5;
ann_x2 = ann_x1 + 100;
ann_y2 = ann_y1 + 15;

% Create annotation using Simulink annotation
try
    annotation_obj = Simulink.Annotation([model_name '/' annotation_text]);
    annotation_obj.position = [ann_x1 ann_y1 ann_x2 ann_y2];
    annotation_obj.BackgroundColor = 'white';
    annotation_obj.FontSize = 8;
catch
    % If Simulink annotation fails, skip
end

end

function color_map = get_color_map()
% Get color mapping for different signal types

color_map = struct();
color_map.temperature = 'red';
color_map.velocity = 'blue';
color_map.speed = 'blue';
color_map.pressure = 'green';
color_map.voltage = 'yellow';
color_map.current = 'orange';
color_map.status = 'cyan';
color_map.soc = 'magenta';
color_map.fault = 'red';
color_map.battery = 'yellow';
color_map.motor = 'lightBlue';
color_map.default = 'lightBlue';

end

function color = get_signal_color(signal_name, color_map)
% Determine color based on signal name keywords

signal_lower = lower(signal_name);

% Check each keyword
keywords = fieldnames(color_map);
for i = 1:length(keywords)-1  % Skip 'default'
    if contains(signal_lower, keywords{i})
        color = color_map.(keywords{i});
        return;
    end
end

% Default color
color = color_map.default;

end

function signals = extract_signals_safe(dbc_file)
% Safely extract signals from DBC file

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
                signals(idx).dataType = 'double';
                
                try
                    signals(idx).unit = sig.Units;
                catch
                    signals(idx).unit = '';
                end
                
                idx = idx + 1;
            end
        end
        
        fprintf('Extracted %d signals using Vehicle Network Toolbox\n', length(signals));
        return;
    end
catch
    % Continue to basic parsing
end

% Basic parsing
fprintf('Using basic DBC parsing...\n');

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
            
            % Try to extract unit
            unit_tokens = regexp(line, '"([^"]*)"', 'tokens');
            if ~isempty(unit_tokens) && ~isempty(unit_tokens{1})
                signals(idx).unit = unit_tokens{1}{1};
            else
                signals(idx).unit = '';
            end
            
            idx = idx + 1;
        end
    end
end

fclose(fid);

fprintf('Extracted %d signals using basic parsing\n', length(signals));

end
