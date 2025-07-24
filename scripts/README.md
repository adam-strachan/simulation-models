# Simulink Model Generation from DBC Files

This directory contains MATLAB scripts for automatically generating Simulink models from DBC (CAN database) files or signal lists. The generated models create input/output port pairs for each signal, which can be used for TugVolt train simulation testing.

## Scripts

### 1. `create_simulink_from_dbc.m`
Basic script that creates a Simulink model with input/output ports for each signal.

**Features:**
- Reads signals from DBC files (with or without Vehicle Network Toolbox)
- Accepts manual signal lists as input
- Creates connected input/output port pairs
- Auto-arranges the model layout

**Usage:**
```matlab
% Option 1: Read from DBC file
create_simulink_from_dbc('dbc/CSI_SBOX.dbc', 'my_model');

% Option 2: Use signal list
signals = {'Motor_Temperature_1', 'Motor_Temperature_2', 'Velocity'};
create_simulink_from_dbc(signals, 'my_model');
```

### 2. `create_simulink_from_dbc_enhanced.m`
Advanced script with additional features for more complex models.

**Features:**
- All features from basic script
- Color coding by signal type (temperature, velocity, pressure, etc.)
- Signal grouping by CAN message
- Data type conversion blocks
- Signal annotations with units and descriptions
- Subsystem organization

**Usage:**
```matlab
% Basic usage
create_simulink_from_dbc_enhanced('dbc/CSI_SBOX.dbc', 'advanced_model');

% With options
options.groupByMessage = true;
options.colorCode = true;
options.addAnnotations = true;
options.addDataTypes = false;
create_simulink_from_dbc_enhanced('dbc/CSI_SBOX.dbc', 'advanced_model', options);

% With signal structure
signals(1).name = 'Motor_Temperature_1';
signals(1).message = 'Motor_Status';
signals(1).dataType = 'double';
signals(1).unit = 'degC';
create_simulink_from_dbc_enhanced(signals, 'custom_model', options);
```

### 3. `example_create_tugvolt_model.m`
Example script showing how to create TugVolt-specific models.

**Creates three example models:**
- Full TugVolt model with all typical signals
- Model from DBC file (commented out - uncomment to use)
- Simple model matching the documentation example

### 4. `preview_dbc_signals.m`
Utility to analyze and preview signals in DBC files.

**Features:**
- Lists all messages and signals in a DBC file
- Shows signal properties (units, bit length, etc.)
- Generates ready-to-use signal lists for model creation
- Works with or without Vehicle Network Toolbox

**Usage:**
```matlab
preview_dbc_signals('dbc/SEVCON_GEN4_SIZE10.dbc');
```

### 5. `tugvolt_simulink_workflow.m`
Complete workflow demonstration for TugVolt system.

**Demonstrates:**
- Previewing available DBC files
- Analyzing motor controller signals
- Creating multiple model variations
- Building integrated models with full metadata
- Optional test harness generation

**Usage:**
```matlab
tugvolt_simulink_workflow
```

### 6. `visualize_model_structure.m`
Creates a visual diagram of the model structure.

**Features:**
- Generates a graphical preview of the port layout
- Helps visualize signal flow before model creation
- Can save diagrams as image files

**Usage:**
```matlab
signals = {'Motor_Temperature_1', 'Velocity', 'Battery_SOC'};
visualize_model_structure(signals);
visualize_model_structure(signals, 'model_preview.png');
```

## Requirements

### Option 1: With Vehicle Network Toolbox
- MATLAB (R2018a or later recommended)
- Simulink
- Vehicle Network Toolbox (for direct DBC file reading)

### Option 2: Without Vehicle Network Toolbox
- MATLAB (R2018a or later recommended)
- Simulink
- Scripts will use basic text parsing for DBC files

## TugVolt Signal Examples

Based on the TugVolt train concept, typical signals include:

**Motor/Drive Signals:**
- Motor_Temperature_1, Motor_Temperature_2
- Velocity
- Throttle_Position

**Battery/Energy Signals:**
- Battery_Voltage
- Battery_Current
- Battery_SOC (State of Charge)
- Charging_Status

**Pneumatic/Brake Signals:**
- Brake_Pressure
- Compressor_Status

**Navigation Signals:**
- GPS_Latitude, GPS_Longitude
- IMU_AccelX, IMU_AccelY, IMU_AccelZ

## Color Coding (Enhanced Script)

The enhanced script automatically color-codes blocks based on signal type:
- **Red**: Temperature signals
- **Blue**: Velocity/speed signals
- **Green**: Pressure signals
- **Yellow**: Voltage signals
- **Orange**: Current signals
- **Cyan**: Status signals
- **Light Blue**: Default/other signals

## Tips

1. **DBC File Location**: DBC files are stored in the `dbc/` directory
2. **Model Organization**: Use the `groupByMessage` option for complex systems
3. **Signal Naming**: Follow the convention `in_SignalName` and `out_SignalName`
4. **Custom Logic**: After generation, add your control logic between the input and output ports

## Example Workflow

```matlab
% Step 1: Create basic model
create_simulink_from_dbc('dbc/CSI_SBOX.dbc', 'tugvolt_base');

% Step 2: Create enhanced model with grouping
options.groupByMessage = true;
options.colorCode = true;
create_simulink_from_dbc_enhanced('dbc/CSI_SBOX.dbc', 'tugvolt_enhanced', options);

% Step 3: Open in Simulink and add control logic
open_system('tugvolt_enhanced');

% Step 4: Save and use for simulation
save_system('tugvolt_enhanced');
```

## Troubleshooting

1. **"Cannot find DBC file"**: Check file path is correct relative to current directory
2. **"Vehicle Network Toolbox not available"**: Script will fall back to basic parsing
3. **"Signal not found"**: Verify signal exists in DBC file or check parsing output
4. **Model already exists**: Script will close and recreate - save work first!

## Integration with SPARK System

These models can be integrated with the SPARK (TugVolt train simulation) system for:
- Hardware-in-the-loop (HIL) testing
- Control algorithm development
- Signal flow visualization
- System integration testing
