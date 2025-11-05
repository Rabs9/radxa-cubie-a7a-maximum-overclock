#!/bin/bash

echo "==========================================="  
echo "NPU 1120MHz Unlock Attempt"
echo "==========================================="
echo "Date: $(date)"
echo

# Method 1: Try to manually add 1120MHz OPP at runtime
echo "=== Method 1: Runtime OPP Addition ==="
echo "Creating custom NPU frequency entry..."

# Check if we can write to debugfs
if [ -d /sys/kernel/debug ]; then
    echo "DebugFS available, attempting advanced unlock..."
    
    # Try to write 1120MHz to various NPU control files
    for file in /sys/class/devfreq/3600000.npu/*freq*; do
        if [ -w "$file" ]; then
            echo "Trying to write 1120000000 to $file"
            echo 1120000000 | sudo tee "$file" 2>/dev/null && echo "SUCCESS: Written to $file" || echo "FAILED: Could not write to $file"
        fi
    done
else
    echo "DebugFS not available"
fi

echo
echo "=== Method 2: Governor Manipulation ==="
# Try userspace governor to manually control frequency
echo "Switching to userspace governor..."
echo userspace | sudo tee /sys/class/devfreq/3600000.npu/governor 2>/dev/null

if [ -f /sys/class/devfreq/3600000.npu/userspace/set_freq ]; then
    echo "Userspace control available, trying 1120MHz..."
    echo 1120000000 | sudo tee /sys/class/devfreq/3600000.npu/userspace/set_freq 2>/dev/null
else
    echo "Userspace frequency control not available"
fi

# Switch back to performance governor
echo performance | sudo tee /sys/class/devfreq/3600000.npu/governor 2>/dev/null

echo
echo "=== Method 3: Voltage Override ==="
# Try to manually set the NPU voltage to support 1120MHz
echo "Attempting to set NPU voltage to 1080mV (needed for 1120MHz)..."

# Find the regulator
NPU_REGULATOR=$(find /sys/class/regulator -name "regulator.*" -exec grep -l "axp8191-dcdc2" {}/name \; 2>/dev/null | head -1)
if [ -n "$NPU_REGULATOR" ]; then
    REGULATOR_DIR=$(dirname "$NPU_REGULATOR")
    echo "Found NPU regulator at: $REGULATOR_DIR"
    
    # Try to set voltage
    if [ -w "$REGULATOR_DIR/microvolts" ]; then
        echo "Setting voltage to 1080000µV..."
        echo 1080000 | sudo tee "$REGULATOR_DIR/microvolts" 2>/dev/null && echo "Voltage set successfully" || echo "Failed to set voltage"
    else
        echo "Cannot write to regulator voltage control"
    fi
else
    echo "NPU regulator not found in sysfs"
fi

echo
echo "=== Results ==="
echo "Available frequencies: $(cat /sys/class/devfreq/3600000.npu/available_frequencies)"
echo "Current frequency: $(cat /sys/class/devfreq/3600000.npu/cur_freq)"
CURRENT_MHZ=$(echo "scale=0; $(cat /sys/class/devfreq/3600000.npu/cur_freq)/1000000" | bc)
echo "Current frequency: ${CURRENT_MHZ} MHz"

if [ "$CURRENT_MHZ" -ge "1120" ]; then
    echo "🎉 SUCCESS: NPU running at 1120MHz or higher!"
    TOPS=$(echo "scale=2; 1.2 * $CURRENT_MHZ / 1000" | bc)
    echo "Estimated TOPS: $TOPS"
else
    echo "❌ FAILED: NPU still limited to lower frequencies"
    echo "The kernel driver has hardcoded limitations preventing 1120MHz"
fi

echo "==========================================="