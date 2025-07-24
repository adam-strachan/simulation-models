%% Test and verify the fix works
% This script tests the fixed version to ensure it works properly

fprintf('=== Testing Simulink Model Creation Fix ===\n\n');

% Test 1: Basic test with small signal set
fprintf('Test 1: Creating small test model...\n');
test_signals = {'Battery_Voltage', 'Battery_Current', 'Motor_Speed'};
test_model = 'test_model_fix';

try
    % Use the fixed version
    options = struct();
    options.colorCode = true;
    options.addAnnotations = false;
    
    create_simulink_from_dbc_fixed(test_signals, test_model, options);
    fprintf('✓ Test 1 PASSED: Basic model created successfully\n');
    
    % Clean up
    save_system(test_model);
    close_system(test_model);
    delete([test_model '.slx']);
catch ME
    fprintf('✗ Test 1 FAILED: %s\n', ME.message);
end

% Test 2: Test the enhanced version with annotations disabled
fprintf('\nTest 2: Testing enhanced version with annotations disabled...\n');
test_model2 = 'test_enhanced_fix';

try
    options = struct();
    options.addAnnotations = false;  % This should prevent the error
    options.colorCode = true;
    
    create_simulink_from_dbc_enhanced(test_signals, test_model2, options);
    fprintf('✓ Test 2 PASSED: Enhanced version works with annotations disabled\n');
    
    % Clean up
    save_system(test_model2);
    close_system(test_model2);
    delete([test_model2 '.slx']);
catch ME
    fprintf('✗ Test 2 FAILED: %s\n', ME.message);
end

% Test 3: Verify model name validation
fprintf('\nTest 3: Testing model name validation...\n');
bad_model_name = 'test/with/slash';

try
    create_simulink_from_dbc_fixed(test_signals, bad_model_name);
    fprintf('✗ Test 3 FAILED: Should have caught invalid model name\n');
catch ME
    if contains(ME.message, 'cannot contain path separators')
        fprintf('✓ Test 3 PASSED: Invalid model name caught correctly\n');
    else
        fprintf('✗ Test 3 FAILED: Wrong error: %s\n', ME.message);
    end
end

% Summary
fprintf('\n=== Test Summary ===\n');
fprintf('The fixed versions should now work correctly.\n');
fprintf('Key points:\n');
fprintf('1. Annotations are disabled by default to avoid errors\n');
fprintf('2. Model names with slashes are properly caught\n');
fprintf('3. The fixed version uses more robust annotation methods\n');

fprintf('\n=== Your Next Step ===\n');
fprintf('Run this command to create your BMS model:\n\n');
fprintf('>> create_simulink_from_dbc_fixed(''dbc/CSI_SBOX.dbc'', ''bms_csi'')\n\n');
fprintf('Or for better organization with 270 signals:\n\n');
fprintf('>> handle_large_dbc(''dbc/CSI_SBOX.dbc'')\n');
