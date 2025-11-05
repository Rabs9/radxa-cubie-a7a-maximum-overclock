#!/bin/bash

echo "========================================="
echo "Comprehensive System Performance Benchmark"
echo "========================================="
echo "Timestamp: $(date)"
echo ""

# Check current boot configuration
echo "=== BOOT CONFIGURATION ==="
echo "Current DTB: $(ls -la /boot/radxa-* | head -1)"
echo ""

# Memory frequency and bandwidth test
echo "=== MEMORY PERFORMANCE ==="
echo "LPDDR5 Frequency:"
if [ -f /sys/class/devfreq/dmc/cur_freq ]; then
    cur_freq=$(cat /sys/class/devfreq/dmc/cur_freq)
    echo "Current: ${cur_freq} Hz ($(echo "scale=1; $cur_freq/1000000" | bc) MHz)"
else
    echo "Memory frequency info not available"
fi

echo ""
echo "Memory Bandwidth Test (sysbench):"
sysbench memory --memory-block-size=1M --memory-total-size=1G --threads=4 run | grep -E "(total time|transferred)"

# NPU frequency check
echo ""
echo "=== NPU PERFORMANCE ==="
echo "NPU Frequency:"
if [ -f /sys/class/devfreq/fde40000.npu/cur_freq ]; then
    npu_freq=$(cat /sys/class/devfreq/fde40000.npu/cur_freq)
    echo "Current: ${npu_freq} Hz ($(echo "scale=0; $npu_freq/1000000" | bc) MHz)"
    echo "Available frequencies:"
    cat /sys/class/devfreq/fde40000.npu/available_frequencies 2>/dev/null | tr ' ' '\n' | while read freq; do
        if [ -n "$freq" ]; then
            echo "  - $(echo "scale=0; $freq/1000000" | bc) MHz"
        fi
    done
else
    echo "NPU frequency info not available"
fi

# GPU frequency check  
echo ""
echo "=== GPU PERFORMANCE ==="
echo "GPU Frequency:"
if [ -f /sys/class/devfreq/fde60000.gpu/cur_freq ]; then
    gpu_freq=$(cat /sys/class/devfreq/fde60000.gpu/cur_freq)
    echo "Current: ${gpu_freq} Hz ($(echo "scale=0; $gpu_freq/1000000" | bc) MHz)"
    echo "Available frequencies:"
    cat /sys/class/devfreq/fde60000.gpu/available_frequencies 2>/dev/null | tr ' ' '\n' | while read freq; do
        if [ -n "$freq" ]; then
            echo "  - $(echo "scale=0; $freq/1000000" | bc) MHz"
        fi
    done
else
    echo "GPU frequency info not available"
fi

# CPU performance test
echo ""
echo "=== CPU PERFORMANCE ==="
echo "CPU Frequencies:"
for cpu in /sys/devices/system/cpu/cpu[0-7]; do
    if [ -f "$cpu/cpufreq/scaling_cur_freq" ]; then
        freq=$(cat $cpu/cpufreq/scaling_cur_freq)
        echo "CPU$(basename $cpu | sed 's/cpu//'): $(echo "scale=0; $freq/1000" | bc) MHz"
    fi
done

echo ""
echo "CPU Performance Test (sysbench):"
sysbench cpu --threads=8 --time=10 run | grep -E "(total time|events per second)"

echo ""
echo "Memory Read/Write Performance:"
sysbench memory --memory-oper=read --memory-block-size=1M --memory-total-size=512M run | grep -E "(total time|transferred)"
sysbench memory --memory-oper=write --memory-block-size=1M --memory-total-size=512M run | grep -E "(total time|transferred)"

echo ""
echo "========================================="
echo "Benchmark Complete"
echo "========================================="