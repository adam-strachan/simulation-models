function handle_large_dbc(dbc_file, options)
% HANDLE_LARGE_DBC Process DBC files with many signals
%
% This function helps manage DBC files with large numbers of signals by:
% - Analyzing and categorizing signals
% - Creating filtered models
% - Generating multiple smaller models
% - Providing selection interface
%
% Usage:
%   handle_large_dbc('path/to/file.dbc')
%   handle_large_dbc('path/to/file.dbc', options)
%
% Options:
%   .maxSignalsPerModel - Maximum signals per model (default: 50)
%   .groupByMessage - Group by CAN message (default: true)
%   .filterPattern - Regex pattern to filter signals (default: '')
%   .interactiveSelection - Allow interactive signal selection (default: true)

% Default options
if nargin < 2
    options = struct();
end
if ~isfield(options, 'maxSignalsPerModel'), options.maxSignalsPerModel = 50; end
if ~isfield(options, 'groupByMessage'), options.groupByMessage = true; end
if ~isfield(options, 'filterPattern'), options.filterPattern = ''; end
if ~isfield(options, 'interactiveSelection'), options.interactiveSelection = true; end

% Extract base name from DBC file
[~, base_name, ~] = fileparts(dbc_file);
base_name = regexprep(base_name, '[^a-zA-Z0-9_]', '_');

% Analyze DBC file
fprintf('\n=== Analyzing DBC File: %s ===\n', dbc_file);
signals = extract_signals_enhanced(dbc_file);

if isempty(signals)
    error('No signals found in DBC file');
end

fprintf('Found %d signals in %s\n', length(signals), dbc_file);

% Get unique messages
messages = unique({signals.message});
fprintf('Distributed across %d messages\n', length(messages));

% Apply filter if specified
if ~isempty(options.filterPattern)
    fprintf('\nApplying filter pattern: %s\n', options.filterPattern);
    filtered_idx = ~cellfun(@isempty, regexp({signals.name}, options.filterPattern));
    signals = signals(filtered_idx);
    fprintf('Filtered to %d signals\n', length(signals));
end

% Interactive selection mode
if options.interactiveSelection && length(signals) > options.maxSignalsPerModel
    signals = interactive_signal_selection(signals, messages);
end

% Determine strategy based on signal count
if length(signals) <= options.maxSignalsPerModel
    % Create single model
    create_single_model(signals, base_name);
elseif options.groupByMessage
    % Create models grouped by message
    create_message_based_models(signals, messages, base_name, options.maxSignalsPerModel);
else
    % Create multiple models split by signal count
    create_split_models(signals, base_name, options.maxSignalsPerModel);
end

fprintf('\n=== Processing Complete ===\n');
end

function signals = interactive_signal_selection(signals, messages)
% Interactive signal selection interface

fprintf('\n=== Interactive Signal Selection ===\n');
fprintf('Total signals: %d\n', length(signals));
fprintf('\nOptions:\n');
fprintf('1. Select by message\n');
fprintf('2. Select by keyword\n');
fprintf('3. Select specific signals\n');
fprintf('4. Use first N signals\n');
fprintf('5. Use all signals (not recommended)\n');

choice = input('Enter choice (1-5): ');

switch choice
    case 1
        % Select by message
        fprintf('\nAvailable messages:\n');
        for i = 1:length(messages)
            msg_signals = signals(strcmp({signals.message}, messages{i}));
            fprintf('%d. %s (%d signals)\n', i, messages{i}, length(msg_signals));
        end
        
        msg_indices = input('Enter message numbers (e.g., [1 3 5]): ');
        selected_messages = messages(msg_indices);
        
        selected_idx = ismember({signals.message}, selected_messages);
        signals = signals(selected_idx);
        
    case 2
        % Select by keyword
        keyword = input('Enter keyword to filter signals: ', 's');
        selected_idx = ~cellfun(@isempty, regexpi({signals.name}, keyword));
        signals = signals(selected_idx);
        
    case 3
        % Select specific signals
        fprintf('\nSignal list:\n');
        for i = 1:length(signals)
            fprintf('%d. %s (%s)\n', i, signals(i).name, signals(i).message);
            if mod(i, 20) == 0 && i < length(signals)
                input('Press Enter to continue...');
            end
        end
        
        sig_indices = input('Enter signal numbers (e.g., [1 5 10:20]): ');
        signals = signals(sig_indices);
        
    case 4
        % Use first N signals
        n = input('Enter number of signals to use: ');
        signals = signals(1:min(n, length(signals)));
        
    case 5
        % Use all signals
        fprintf('Warning: Creating model with %d signals...\n', length(signals));
        
    otherwise
        error('Invalid choice');
end

fprintf('\nSelected %d signals\n', length(signals));
end

function create_single_model(signals, base_name)
% Create a single model with all signals

model_name = sprintf('%s_model', base_name);
fprintf('\nCreating single model: %s\n', model_name);

opts = struct();
opts.groupByMessage = length(unique({signals.message})) < length(signals)/3;
opts.colorCode = true;
opts.addAnnotations = length(signals) < 30;

create_simulink_from_dbc_enhanced(signals, model_name, opts);
end

function create_message_based_models(signals, messages, base_name, max_signals)
% Create separate models for each message or group of messages

fprintf('\nCreating message-based models...\n');
model_count = 0;

for i = 1:length(messages)
    msg_signals = signals(strcmp({signals.message}, messages{i}));
    
    if isempty(msg_signals)
        continue;
    end
    
    % Clean message name for model name
    clean_msg_name = regexprep(messages{i}, '[^a-zA-Z0-9_]', '_');
    model_name = sprintf('%s_%s', base_name, clean_msg_name);
    
    fprintf('Creating model %s with %d signals\n', model_name, length(msg_signals));
    
    opts = struct();
    opts.groupByMessage = false;  % Already grouped
    opts.colorCode = true;
    opts.addAnnotations = true;
    
    create_simulink_from_dbc_enhanced(msg_signals, model_name, opts);
    model_count = model_count + 1;
end

fprintf('\nCreated %d message-based models\n', model_count);
end

function create_split_models(signals, base_name, max_signals)
% Create multiple models split by signal count

num_models = ceil(length(signals) / max_signals);
fprintf('\nCreating %d split models...\n', num_models);

for i = 1:num_models
    start_idx = (i-1) * max_signals + 1;
    end_idx = min(i * max_signals, length(signals));
    
    model_signals = signals(start_idx:end_idx);
    model_name = sprintf('%s_part%d', base_name, i);
    
    fprintf('Creating model %s with signals %d-%d\n', model_name, start_idx, end_idx);
    
    opts = struct();
    opts.groupByMessage = true;
    opts.colorCode = true;
    opts.addAnnotations = length(model_signals) < 30;
    
    create_simulink_from_dbc_enhanced(model_signals, model_name, opts);
end
end

function signals = extract_signals_enhanced(dbc_file)
% Extract enhanced signal information from DBC file
% (Reusing the function from create_simulink_from_dbc_enhanced.m)

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
                
                % Try to extract unit
                unit_tokens = regexp(line, '"([^"]*)"', 'tokens');
                if ~isempty(unit_tokens) && ~isempty(unit_tokens{1})
                    signals(idx).unit = unit_tokens{1}{1};
                end
                
                idx = idx + 1;
            end
        end
    end
end

fclose(fid);
end
