% Generic FMU Build Script for any Simulink model
% This script is called by the Makefile with variables:
%   model_name - name of the model (without .slx)
%   model_dir - absolute path to directory containing the model
%   fmu_dir - absolute path to where FMU should be saved
%   has_dict - 'true' or 'false' string indicating if .sldd exists

try
    fprintf('=== Generic FMU Build Script ===\n');
    fprintf('Model: %s\n', model_name);
    fprintf('Model directory: %s\n', model_dir);
    fprintf('FMU output directory: %s\n', fmu_dir);
    fprintf('Has dictionary: %s\n', has_dict);
    
    % Store the FMU output directory
    outputDir = fmu_dir;
    
    % Add model directory to path
    fprintf('Adding model directory to path...\n');
    addpath(model_dir);
    
    % Change to model directory (some models expect to be loaded from their directory)
    fprintf('Changing to model directory...\n');
    cd(model_dir);
    
    % Load data dictionary if it exists
    dictObj = [];
    if strcmp(has_dict, 'true')
        fprintf('Loading data dictionary: %s.sldd\n', model_name);
        try
            dictObj = Simulink.data.dictionary.open([model_name '.sldd']);
            fprintf('✓ Data dictionary loaded successfully\n');
        catch ME
            fprintf('Warning: Could not load dictionary: %s\n', ME.message);
            fprintf('Continuing without dictionary...\n');
        end
    end
    
    % Load the model
    fprintf('Loading model: %s.slx\n', model_name);
    load_system([model_name '.slx']);
    
    % Configure model for automated build
    fprintf('Configuring model for automated build...\n');
    try
        % Get configuration set
        cs = getActiveConfigSet(model_name);
        
        % Disable all report generation
        set_param(cs, 'GenerateReport', 'off');
        set_param(cs, 'LaunchReport', 'off');
        
        % Try to set additional report parameters (may not exist for all models)
        params_to_disable = {
            'GenerateCodeMetricsReport'
            'GenerateCodeReplacementReport'
            'GenerateWebview'
            'GenerateTraceInfo'
            'GenerateTraceReport'
            'GenerateTraceReportSl'
            'GenerateTraceReportSf'
            'GenerateTraceReportEml'
            'RTWVerbose'
            'ProfileTLC'
            'TLCDebug'
            'TLCCoverage'
            'TLCAssert'
        };
        
        for i = 1:length(params_to_disable)
            try
                set_param(cs, params_to_disable{i}, 'off');
            catch
                % Parameter might not exist for this model
            end
        end
        
        % Try to retain RTW file for debugging
        try
            set_param(cs, 'RetainRTWFile', 'on');
        catch
        end
        
    catch ME
        fprintf('Warning: Could not fully configure model: %s\n', ME.message);
        fprintf('Continuing with default configuration...\n');
    end
    
    % Export to FMU
    fprintf('\nExporting model to FMU...\n');
    fprintf('Working directory: %s\n', pwd);
    
    % Try FMU export
    fmuExported = false;
    try
        exportToFMU(model_name, ...
            'FMUType', 'CoSimulation', ...
            'FMIVersion', '3.0', ...
            'CreateModelAfterGeneratingFMU', 'off');
        
        fprintf('FMU export completed with FMI 3.0.\n');
        fmuExported = true;
    catch FMU_ERR
        fprintf('FMI 3.0 export failed: %s\n', FMU_ERR.message);
        fprintf('Trying FMI 2.0...\n');
        try
            exportToFMU(model_name, ...
                'FMUType', 'CoSimulation', ...
                'FMIVersion', '2.0', ...
                'CreateModelAfterGeneratingFMU', 'off');
            
            fprintf('FMU export completed with FMI 2.0.\n');
            fmuExported = true;
        catch FMU_ERR2
            error('FMU export failed for both FMI 3.0 and 2.0: %s', FMU_ERR2.message);
        end
    end
    
    % Check if FMU was created and move it to output directory
    fmuFile = [model_name '.fmu'];
    if exist(fmuFile, 'file')
        % Get full paths
        sourcePath = fullfile(pwd, fmuFile);
        destPath = fullfile(outputDir, fmuFile);
        
        % Move FMU to output directory
        fprintf('Moving FMU from %s to %s\n', sourcePath, destPath);
        movefile(sourcePath, destPath);
        
        fprintf('\n✓ FMU successfully created: %s\n', destPath);
        
        % Verify file exists at destination
        if ~exist(destPath, 'file')
            error('FMU file was not properly moved to destination!');
        end
    else
        error('FMU file was not created! Expected: %s', fmuFile);
    end
    
    % Clean up
    fprintf('Cleaning up...\n');
    close_system(model_name, 0);
    
    if ~isempty(dictObj)
        try
            close(dictObj);
        catch
            % Dictionary might already be closed
        end
    end
    
    fprintf('\n=== FMU build completed successfully! ===\n');
    fprintf('Output: %s\n', fullfile(outputDir, fmuFile));
    
    % Exit MATLAB with success
    exit(0);
    
catch ME
    % Error handling
    fprintf('\n=== Error during FMU build ===\n');
    fprintf('Error: %s\n', ME.message);
    
    % Display stack trace
    fprintf('\nError stack:\n');
    for i = 1:length(ME.stack)
        fprintf('  In %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    
    % Try to clean up
    try
        if exist('model_name', 'var')
            close_system(model_name, 0);
        end
    catch
    end
    
    try
        if exist('dictObj', 'var') && ~isempty(dictObj)
            close(dictObj);
        end
    catch
    end
    
    % Exit with error
    exit(1);
end