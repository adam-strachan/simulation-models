function preview_dbc_signals(dbc_file)
% PREVIEW_DBC_SIGNALS Display a summary of signals in a DBC file
%
% Usage:
%   preview_dbc_signals('path/to/file.dbc')
%
% This function displays:
%   - Total number of messages and signals
%   - List of all signals with their properties
%   - Summary statistics
%
% Example:
%   preview_dbc_signals('dbc/SEVCON_GEN4_SIZE10.dbc')

if nargin < 1
    error('Please provide a DBC file path');
end

fprintf('\n===== DBC File Analysis: %s =====\n', dbc_file);

% Try to use Vehicle Network Toolbox first
use_vnt = false;
try
    if license('test', 'Vehicle_Network_Toolbox')
        db = canDatabase(dbc_file);
        use_vnt = true;
        analyze_with_vnt(db);
    end
catch ME
    fprintf('Vehicle Network Toolbox analysis failed: %s\n', ME.message);
    fprintf('Falling back to basic parsing...\n');
end

% If VNT failed or not available, use basic parsing
if ~use_vnt
    analyze_with_parsing(dbc_file);
end

end

function analyze_with_vnt(db)
% Analyze using Vehicle Network Toolbox

fprintf('\nAnalysis using Vehicle Network Toolbox:\n');
fprintf('=====================================\n');

% Summary
total_messages = length(db.Messages);
total_signals = 0;

fprintf('\nMessages (%d total):\n', total_messages);
fprintf('-------------------\n');

% List all messages and their signals
for i = 1:length(db.Messages)
    msg = db.Messages(i);
    num_signals = length(msg.Signals);
    total_signals = total_signals + num_signals;
    
    fprintf('\n%d. %s (ID: %d, %d signals)\n', i, msg.Name, msg.ID, num_signals);
    
    for j = 1:num_signals
        sig = msg.Signals(j);
        fprintf('   - %s', sig.Name);
        
        % Add details if available
        details = {};
        if ~isempty(sig.Units) && ~strcmp(sig.Units, '')
            details{end+1} = sprintf('Unit: %s', sig.Units);
        end
        if ~isnan(sig.Min) && ~isnan(sig.Max)
            details{end+1} = sprintf('Range: [%.2f, %.2f]', sig.Min, sig.Max);
        end
        if sig.BitLength > 0
            details{end+1} = sprintf('%d bits', sig.BitLength);
        end
        
        if ~isempty(details)
            fprintf(' (%s)', strjoin(details, ', '));
        end
        fprintf('\n');
    end
end

fprintf('\n\nSummary:\n');
fprintf('--------\n');
fprintf('Total Messages: %d\n', total_messages);
fprintf('Total Signals: %d\n', total_signals);
fprintf('Average Signals per Message: %.1f\n', total_signals/total_messages);

end

function analyze_with_parsing(dbc_file)
% Analyze using basic text parsing

fprintf('\nAnalysis using basic text parsing:\n');
fprintf('==================================\n');

fid = fopen(dbc_file, 'r');
if fid == -1
    error('Cannot open DBC file: %s', dbc_file);
end

messages = struct('name', {}, 'id', {}, 'signals', {});
current_msg_idx = 0;
signal_count = 0;

while ~feof(fid)
    line = fgetl(fid);
    if ~ischar(line)
        continue;
    end
    
    % Parse message definition
    if contains(line, 'BO_ ')
        tokens = regexp(line, 'BO_\s+(\d+)\s+(\w+):', 'tokens');
        if ~isempty(tokens)
            current_msg_idx = current_msg_idx + 1;
            messages(current_msg_idx).id = str2double(tokens{1}{1});
            messages(current_msg_idx).name = tokens{1}{2};
            messages(current_msg_idx).signals = {};
        end
    end
    
    % Parse signal definition
    if contains(line, ' SG_ ') && current_msg_idx > 0
        % Extract signal name
        sig_tokens = regexp(line, '\s+SG_\s+(\w+)\s*:', 'tokens');
        if ~isempty(sig_tokens)
            signal_name = sig_tokens{1}{1};
            signal_count = signal_count + 1;
            
            % Extract additional info if possible
            signal_info = signal_name;
            
            % Try to extract unit
            unit_tokens = regexp(line, '"([^"]*)"', 'tokens');
            if ~isempty(unit_tokens) && ~isempty(unit_tokens{1})
                unit = unit_tokens{1}{1};
                if ~isempty(unit) && ~strcmp(unit, '')
                    signal_info = sprintf('%s [%s]', signal_info, unit);
                end
            end
            
            % Try to extract bit info
            bit_tokens = regexp(line, ':\s*(\d+)\|(\d+)@', 'tokens');
            if ~isempty(bit_tokens)
                start_bit = bit_tokens{1}{1};
                bit_length = bit_tokens{1}{2};
                signal_info = sprintf('%s (%s bits)', signal_info, bit_length);
            end
            
            messages(current_msg_idx).signals{end+1} = signal_info;
        end
    end
end

fclose(fid);

% Display results
fprintf('\nMessages (%d total):\n', length(messages));
fprintf('-------------------\n');

for i = 1:length(messages)
    msg = messages(i);
    fprintf('\n%d. %s (ID: %d, %d signals)\n', i, msg.name, msg.id, length(msg.signals));
    
    for j = 1:length(msg.signals)
        fprintf('   - %s\n', msg.signals{j});
    end
end

fprintf('\n\nSummary:\n');
fprintf('--------\n');
fprintf('Total Messages: %d\n', length(messages));
fprintf('Total Signals: %d\n', signal_count);
if length(messages) > 0
    fprintf('Average Signals per Message: %.1f\n', signal_count/length(messages));
end

% Create signal list for easy copying
fprintf('\n\nSignal List (for use with create_simulink_from_dbc):\n');
fprintf('----------------------------------------------------\n');
fprintf('signals = {\n');
for i = 1:length(messages)
    for j = 1:length(messages(i).signals)
        % Extract just the signal name
        sig_name = messages(i).signals{j};
        sig_name = regexp(sig_name, '^(\w+)', 'tokens', 'once');
        if ~isempty(sig_name)
            fprintf("    '%s'\n", sig_name{1});
        end
    end
end
fprintf('};\n');

end
