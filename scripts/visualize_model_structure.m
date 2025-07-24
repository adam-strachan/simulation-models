function visualize_model_structure(signal_list, output_file)
% VISUALIZE_MODEL_STRUCTURE Create a visual representation of the Simulink model structure
%
% Usage:
%   visualize_model_structure({'Signal1', 'Signal2', ...})
%   visualize_model_structure({'Signal1', 'Signal2', ...}, 'output.png')
%
% This creates a simple diagram showing the input/output port structure

if nargin < 2
    output_file = '';
end

% Create figure
fig = figure('Position', [100, 100, 800, 600], 'Color', 'white');
ax = axes('Position', [0.1, 0.1, 0.8, 0.8]);
hold on;

% Layout parameters
num_signals = length(signal_list);
y_spacing = 1 / (num_signals + 1);
port_width = 0.15;
port_height = 0.04;
text_offset = 0.02;

% Colors
input_color = [0.7, 0.9, 1.0];  % Light blue
output_color = [0.7, 1.0, 0.7];  % Light green
line_color = [0.3, 0.3, 0.3];    % Dark gray

% Draw title
text(0.5, 0.95, 'TugVolt Simulink Model Structure', ...
    'HorizontalAlignment', 'center', ...
    'FontSize', 14, 'FontWeight', 'bold');

% Draw ports and connections
for i = 1:num_signals
    y_pos = 1 - (i * y_spacing);
    
    % Draw input port
    in_x = 0.1;
    rectangle('Position', [in_x, y_pos - port_height/2, port_width, port_height], ...
        'FaceColor', input_color, 'EdgeColor', 'black', 'LineWidth', 1.5);
    
    % Input port label
    text(in_x + port_width/2, y_pos, sprintf('in_%s', signal_list{i}), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 10);
    
    % Draw output port
    out_x = 0.75;
    rectangle('Position', [out_x, y_pos - port_height/2, port_width, port_height], ...
        'FaceColor', output_color, 'EdgeColor', 'black', 'LineWidth', 1.5);
    
    % Output port label
    text(out_x + port_width/2, y_pos, sprintf('out_%s', signal_list{i}), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 10);
    
    % Draw connection line
    line_x = [in_x + port_width, out_x];
    line_y = [y_pos, y_pos];
    plot(line_x, line_y, 'Color', line_color, 'LineWidth', 2);
    
    % Add arrow
    arrow_x = out_x - 0.02;
    arrow_y = y_pos;
    plot(arrow_x, arrow_y, '>', 'Color', line_color, 'MarkerSize', 8, ...
        'MarkerFaceColor', line_color);
end

% Add legend
leg_y = 0.05;
rectangle('Position', [0.3, leg_y, 0.05, 0.02], ...
    'FaceColor', input_color, 'EdgeColor', 'black');
text(0.36, leg_y + 0.01, 'Input Port', 'VerticalAlignment', 'middle');

rectangle('Position', [0.5, leg_y, 0.05, 0.02], ...
    'FaceColor', output_color, 'EdgeColor', 'black');
text(0.56, leg_y + 0.01, 'Output Port', 'VerticalAlignment', 'middle');

% Set axis properties
xlim([0, 1]);
ylim([0, 1]);
axis off;

% Save if output file specified
if ~isempty(output_file)
    saveas(fig, output_file);
    fprintf('Model structure saved to: %s\n', output_file);
end

end
