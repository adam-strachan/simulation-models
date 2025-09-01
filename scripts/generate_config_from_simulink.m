function generate_config_from_simulink(simulink_file, dbc_file, output_yaml_file, component_type)
    % Generate YAML configuration file from Simulink model and DBC file
    %
    % Inputs:
    %   simulink_file - Path to Simulink .slx or .mdl file
    %   dbc_file - Path to DBC file
    %   output_yaml_file - Path for output YAML config file
    %   component_type - Component type string (e.g., 'dynamics', 'pneumatics')
    %
    % Example:
    %   generate_config_from_simulink('model.slx', 'can.dbc', 'config.yaml', 'my_component')
    
    if nargin < 4
        error('Usage: generate_config_from_simulink(simulink_file, dbc_file, output_yaml_file, component_type)');
    end
    
    % Load Simulink model
    [~, model_name, ~] = fileparts(simulink_file);
    load_system(simulink_file);
    
    % Get model inputs and outputs
    model_inputs = get_model_io_ports(model_name, 'Inport');
    model_outputs = get_model_io_ports(model_name, 'Outport');
    
    % Load DBC file
    dbc_data = parse_dbc_file(dbc_file);
    
    % Create configuration structure
    config = struct();
    config.component_type = component_type;
    
    % Process inputs
    [config.inputs, input_can_messages] = process_io_signals(model_inputs, dbc_data, 'in_');
    
    % Process outputs
    [config.outputs, output_can_messages] = process_io_signals(model_outputs, dbc_data, 'out_');
    
    % Add empty parameters section
    config.parameters = struct();
    
    % Add CAN message configuration
    if ~isempty(input_can_messages) || ~isempty(output_can_messages)
        config.can_message_config = struct();
        
        % Add input messages (just the list)
        if ~isempty(input_can_messages)
            config.can_message_config.input_messages = unique(input_can_messages);
        else
            config.can_message_config.input_messages = {};
        end
        
        % Add output messages with publish rate
        if ~isempty(output_can_messages)
            config.can_message_config.output_messages = struct();
            unique_output_messages = unique(output_can_messages);
            for i = 1:length(unique_output_messages)
                msg_name = unique_output_messages{i};
                config.can_message_config.output_messages.(msg_name) = struct('publish_rate', 5);
            end
        else
            config.can_message_config.output_messages = struct();
        end
    end
    
    % Write YAML file
    write_yaml_config(output_yaml_file, config, component_type);
    
    % Close the model
    close_system(model_name, 0);
    
    fprintf('Configuration file generated: %s\n', output_yaml_file);
end

function ports = get_model_io_ports(model_name, port_type)
    % Get all input or output ports from the model
    ports = {};
    
    % Find all blocks of specified type
    blocks = find_system(model_name, 'SearchDepth', 1, 'BlockType', port_type);
    
    for i = 1:length(blocks)
        port_name = get_param(blocks{i}, 'Name');
        ports{end+1} = port_name;
    end
end

function dbc_data = parse_dbc_file(dbc_file)
    % Parse DBC file to extract signals and their messages
    % Returns a structure with signal-to-message mapping
    dbc_data = struct();
    dbc_data.signals = {};
    dbc_data.signal_to_message = containers.Map();
    dbc_data.messages = {};
    
    if ~exist(dbc_file, 'file')
        warning('DBC file not found: %s', dbc_file);
        return;
    end
    
    fid = fopen(dbc_file, 'r');
    if fid == -1
        warning('Could not open DBC file: %s', dbc_file);
        return;
    end
    
    current_message = '';
    
    % Read DBC file line by line
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            % Look for message definitions (BO_ prefix)
            if startsWith(line, 'BO_')
                % Extract message name
                tokens = regexp(line, 'BO_\s+\d+\s+(\w+)', 'tokens');
                if ~isempty(tokens)
                    current_message = tokens{1}{1};
                    if ~ismember(current_message, dbc_data.messages)
                        dbc_data.messages{end+1} = current_message;
                    end
                end
            % Look for signal definitions (SG_ prefix)
            elseif startsWith(strtrim(line), 'SG_')
                % Extract signal name
                tokens = regexp(line, 'SG_\s+(\w+)', 'tokens');
                if ~isempty(tokens) && ~isempty(current_message)
                    signal_name = tokens{1}{1};
                    dbc_data.signals{end+1} = signal_name;
                    dbc_data.signal_to_message(signal_name) = current_message;
                end
            end
        end
    end
    
    fclose(fid);
end

function [io_struct, can_messages] = process_io_signals(port_names, dbc_data, prefix)
    % Process input or output signals
    io_struct = struct();
    can_messages = {};
    
    for i = 1:length(port_names)
        port_name = port_names{i};
        
        % Remove prefix (in_ or out_) to get signal name
        if startsWith(port_name, prefix)
            signal_name = port_name(length(prefix)+1:end);
        else
            signal_name = port_name;
        end
        
        % Check if signal exists in DBC
        signal_found = any(strcmp(signal_name, dbc_data.signals));
        
        % Create signal configuration
        signal_config = struct();
        
        if signal_found && isKey(dbc_data.signal_to_message, signal_name)
            signal_config.type = 'can';
            % Get message name from DBC data
            message_name = dbc_data.signal_to_message(signal_name);
            signal_config.can_message = message_name;
            signal_config.can_signal = signal_name;
            
            % Add to list of CAN messages
            can_messages{end+1} = message_name;
        else
            signal_config.type = 'model';
            signal_config.source_component = '';  % To be filled manually
            signal_config.source_signal = '';     % To be filled manually
        end
        
        % Common fields
        signal_config.unit = '';              % To be filled manually
        signal_config.default = 0.0;
        signal_config.description = sprintf('Signal %s', signal_name);
        signal_config.range = [0, 0];         % To be filled manually
        signal_config.fmu_variable = port_name;  % Original Simulink port name
        
        % Add to structure using signal name (without prefix)
        io_struct.(signal_name) = signal_config;
    end
end

function write_yaml_config(filename, config, component_type)
    % Write configuration to YAML file
    
    fid = fopen(filename, 'w');
    if fid == -1
        error('Could not create output file: %s', filename);
    end
    
    % Write header
    fprintf(fid, '# %s Model Configuration\n', component_type);
    fprintf(fid, '# Generated from Simulink model and DBC file\n');
    fprintf(fid, '# Please review and update placeholder values\n\n');
    
    % Write component type
    fprintf(fid, '# Component metadata (REQUIRED)\n');
    fprintf(fid, 'component_type: %s\n\n', config.component_type);
    
    % Write inputs
    fprintf(fid, '# Input signals (mapped to FMU inputs)\n');
    fprintf(fid, 'inputs:\n');
    write_io_section(fid, config.inputs, '  ');
    
    % Write outputs
    fprintf(fid, '\n# Output signals (mapped to FMU outputs)\n');
    fprintf(fid, 'outputs:\n');
    write_io_section(fid, config.outputs, '  ');
    
    % Write parameters
    fprintf(fid, '\n# Model parameters (FMU parameters)\n');
    fprintf(fid, 'parameters: {}\n');
    
    % Write CAN configuration if present
    if isfield(config, 'can_message_config')
        fprintf(fid, '\n# CAN message configuration\n');
        fprintf(fid, 'can_message_config:\n');
        
        % Write input messages
        if isfield(config.can_message_config, 'input_messages')
            if isempty(config.can_message_config.input_messages)
                fprintf(fid, '  input_messages: []\n');
            else
                fprintf(fid, '  input_messages:\n');
                for i = 1:length(config.can_message_config.input_messages)
                    fprintf(fid, '    - %s\n', config.can_message_config.input_messages{i});
                end
            end
        end
        
        % Write output messages
        if isfield(config.can_message_config, 'output_messages')
            output_msg_names = fieldnames(config.can_message_config.output_messages);
            if isempty(output_msg_names)
                fprintf(fid, '  output_messages: {}\n');
            else
                fprintf(fid, '  output_messages:\n');
                for i = 1:length(output_msg_names)
                    msg_name = output_msg_names{i};
                    msg_config = config.can_message_config.output_messages.(msg_name);
                    fprintf(fid, '    %s:\n', msg_name);
                    fprintf(fid, '      publish_rate: %d\n', msg_config.publish_rate);
                end
            end
        end
    end
    
    fclose(fid);
end

function write_io_section(fid, io_struct, indent)
    % Write input or output section
    
    if isempty(fieldnames(io_struct))
        fprintf(fid, '%s{}\n', indent);
        return;
    end
    
    fields = fieldnames(io_struct);
    for i = 1:length(fields)
        signal_name = fields{i};
        signal = io_struct.(signal_name);
        
        fprintf(fid, '%s%s:\n', indent, signal_name);
        
        % Write signal properties
        fprintf(fid, '%s  type: %s\n', indent, signal.type);
        
        if strcmp(signal.type, 'can')
            fprintf(fid, '%s  can_message: %s\n', indent, signal.can_message);
            fprintf(fid, '%s  can_signal: %s\n', indent, signal.can_signal);
        else
            fprintf(fid, '%s  source_component: "%s"  # TODO: Specify source component\n', indent, signal.source_component);
            fprintf(fid, '%s  source_signal: "%s"  # TODO: Specify source signal\n', indent, signal.source_signal);
        end
        
        fprintf(fid, '%s  unit: "%s"  # TODO: Specify unit\n', indent, signal.unit);
        fprintf(fid, '%s  default: %.1f\n', indent, signal.default);
        fprintf(fid, '%s  description: "%s"\n', indent, signal.description);
        fprintf(fid, '%s  range: [%.1f, %.1f]  # TODO: Update range\n', indent, signal.range(1), signal.range(2));
        fprintf(fid, '%s  fmu_variable: "%s"\n', indent, signal.fmu_variable);
        
        if i < length(fields)
            fprintf(fid, '\n');
        end
    end
end