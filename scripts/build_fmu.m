% FMU Build Script for TugVolt Train Dynamics Model
% This script can be run as a MATLAB batch command or regular script

try
    fprintf('Starting FMU build process...\n');
    
    % Define paths
    modelPath = './train_dynamics/train_dynamics.slx';
    dictPath = './train_dynamics/train_dynamics.sldd';
    modelName = 'train_dynamics';
    
    % Get current directory to restore later
    originalDir = pwd;
    
    % Add train_dynamics directory to MATLAB path
    fprintf('Adding train_dynamics directory to path...\n');
    addpath('./train_dynamics');
    
    % Change to the train_dynamics directory
    % This ensures the model can find its dictionary
    fprintf('Changing to train_dynamics directory...\n');
    cd('./train_dynamics');
    
    % Load the data dictionary
    fprintf('Loading data dictionary: %s\n', 'train_dynamics.sldd');
    dictObj = Simulink.data.dictionary.open('train_dynamics.sldd');
    
    % Load the model
    fprintf('Loading model: %s\n', 'train_dynamics.slx');
    load_system('train_dynamics.slx');
    
    % Check if we're in batch/headless mode
    if usejava('desktop')
        fprintf('Running in desktop mode\n');
    else
        fprintf('Running in headless/batch mode\n');
        % Try to suppress all GUI elements
        set_param(0, 'CharacterEncoding', 'UTF-8');
        bdclose('all');
        load_system('train_dynamics.slx');
    end
    
    % Set model configuration to suppress reports
    fprintf('Configuring model for automated build...\n');
    cs = getActiveConfigSet(modelName);
    if ~isempty(cs)
        % Disable all report generation
        set_param(cs, 'GenerateReport', 'off');
        set_param(cs, 'LaunchReport', 'off');
        set_param(cs, 'GenerateCodeMetricsReport', 'off');
        set_param(cs, 'GenerateCodeReplacementReport', 'off');
        set_param(cs, 'GenerateWebview', 'off');
        set_param(cs, 'GenerateTraceInfo', 'off');
        set_param(cs, 'GenerateTraceReport', 'off');
        set_param(cs, 'GenerateTraceReportSl', 'off');
        set_param(cs, 'GenerateTraceReportSf', 'off');
        set_param(cs, 'GenerateTraceReportEml', 'off');
        
        % Try to disable code generation report
        try
            set_param(cs, 'RTWVerbose', 'off');
            set_param(cs, 'RetainRTWFile', 'on');
            set_param(cs, 'ProfileTLC', 'off');
            set_param(cs, 'TLCDebug', 'off');
            set_param(cs, 'TLCCoverage', 'off');
            set_param(cs, 'TLCAssert', 'off');
        catch
            % Some parameters might not exist
        end
    end
    
    % Export to FMU
    fprintf('Exporting model to FMU...\n');
    fprintf('Working directory: %s\n', pwd);
    
    % Export with minimal options
    exportToFMU(modelName, ...
        'FMUType', 'CoSimulation', ...
        'FMIVersion', '3.0', ...
        'CreateModelAfterGeneratingFMU', 'off');
    
    % Check if FMU was created
    if exist([modelName '.fmu'], 'file')
        % Move FMU to original directory if desired
        movefile([modelName '.fmu'], fullfile(originalDir, [modelName '.fmu']));
        fprintf('\nFMU file successfully created and moved to: %s\n', originalDir);
    else
        error('FMU file was not created!');
    end
    
    % Close the model and dictionary
    fprintf('Cleaning up...\n');
    close_system(modelName, 0);
    close(dictObj);
    
    % Return to original directory
    cd(originalDir);
    
    fprintf('\n=== FMU build completed successfully! ===\n');
    fprintf('FMU file: %s/%s.fmu\n', originalDir, modelName);
    
    % Exit MATLAB if in script mode
    if ~usejava('desktop')
        exit(0);
    end
    
catch ME
    % Error handling
    fprintf('\n=== Error during FMU build ===\n');
    fprintf('Error message: %s\n', ME.message);
    
    % Display full error stack
    fprintf('\nFull error stack:\n');
    for i = 1:length(ME.stack)
        fprintf('  In %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    
    % Try to clean up if error occurred
    try
        close_system(modelName, 0);
    catch
        % Model might not be loaded
    end
    
    try
        close(dictObj);
    catch
        % Dictionary might not be loaded
    end
    
    % Try to return to original directory
    try
        cd(originalDir);
    catch
        % originalDir might not be set
    end
    
    % Exit with error code if in script mode
    if ~usejava('desktop')
        exit(1);
    else
        % Re-throw error for interactive mode
        rethrow(ME);
    end
end