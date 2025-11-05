#!/bin/bash

echo "🚀 NPU 5GHz Testing Script"
echo "=========================="
echo

echo "=== CHECKING NPU DEVFREQ STATUS ==="
echo "Governor: $(cat /sys/class/devfreq/3600000.npu/governor 2>/dev/null || echo 'NOT FOUND')"
echo "Current Freq: $(cat /sys/class/devfreq/3600000.npu/cur_freq 2>/dev/null | awk '{print $1/1000000 " MHz"}' || echo 'NOT FOUND')"
echo "Max Freq: $(cat /sys/class/devfreq/3600000.npu/max_freq 2>/dev/null | awk '{print $1/1000000 " MHz"}' || echo 'NOT FOUND')"
echo

echo "=== AVAILABLE FREQUENCIES ==="
if [ -f /sys/class/devfreq/3600000.npu/available_frequencies ]; then
    echo "Available frequencies:"
    cat /sys/class/devfreq/3600000.npu/available_frequencies | tr ' ' '\n' | awk '{print $1/1000000 " MHz"}' | sort -n
    echo
    FREQ_COUNT=$(cat /sys/class/devfreq/3600000.npu/available_frequencies | wc -w)
    echo "Total frequency points: $FREQ_COUNT"
    
    if [ $FREQ_COUNT -gt 3 ]; then
        echo "✅ SUCCESS: Extended OPP table is active!"
        
        # Test setting to maximum frequency
        echo
        echo "=== TESTING MAXIMUM FREQUENCY ==="
        echo "Switching to userspace governor..."
        echo userspace | sudo tee /sys/class/devfreq/3600000.npu/governor > /dev/null
        
        MAX_FREQ=$(cat /sys/class/devfreq/3600000.npu/available_frequencies | tr ' ' '\n' | sort -n | tail -1)
        echo "Setting to maximum frequency: $(echo $MAX_FREQ | awk '{print $1/1000000 " MHz"}')"
        echo $MAX_FREQ | sudo tee /sys/class/devfreq/3600000.npu/userspace/set_freq > /dev/null
        
        sleep 1
        ACTUAL_FREQ=$(cat /sys/class/devfreq/3600000.npu/cur_freq)
        echo "Actual frequency achieved: $(echo $ACTUAL_FREQ | awk '{print $1/1000000 " MHz"}')"
        
        if [ $ACTUAL_FREQ -gt 2000000000 ]; then
            echo "🎉 AMAZING! NPU is running above 2GHz!"
            if [ $ACTUAL_FREQ -gt 4000000000 ]; then
                echo "🚀 INCREDIBLE! NPU is running above 4GHz!"
                if [ $ACTUAL_FREQ -ge 5000000000 ]; then
                    echo "⚡ LEGENDARY! NPU reached 5GHz target!"
                fi
            fi
        fi
        
        # Test voltage scaling
        echo
        echo "=== VOLTAGE INFORMATION ==="
        find /sys/class/regulator/ -name "microvolts" | while read reg; do
            voltage=$(cat "$reg" 2>/dev/null)
            if [ ! -z "$voltage" ] && [ $voltage -gt 800000 ]; then
                echo "$(dirname $reg | xargs basename): $(echo $voltage | awk '{print $1/1000 " mV"}')"
            fi
        done
        
    else
        echo "❌ ISSUE: Only $FREQ_COUNT frequency points available (expected 18)"
        echo "The extended OPP table may not be loading correctly."
    fi
else
    echo "❌ ERROR: NPU devfreq interface not found!"
    echo "The 5GHz DTB may not be loading correctly."
fi

echo
echo "=== SYSTEM INFORMATION ==="
echo "Kernel: $(uname -r)"
echo "DTB in use: $(cat /proc/cmdline | grep -o 'fdt=[^ ]*' | cut -d'=' -f2)"
echo "Boot time: $(uptime -s)"