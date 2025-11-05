#!/bin/bash

# Comprehensive A7A Performance Benchmark Suite
# Tests CPU, Memory, NPU, GPU, and I/O performance

echo "================================================"
echo "Radxa A7A Comprehensive Performance Benchmark"
echo "Started at: $(date)"
echo "================================================"

# System Info
echo ""
echo "=== SYSTEM INFORMATION ==="
echo "Kernel: $(uname -r)"
echo "DTB File: $(cat /proc/device-tree/model 2>/dev/null || echo 'Not available')"
echo "Current Boot Entry: $(cat /proc/cmdline | grep -o 'fdt=[^ ]*' | cut -d= -f2)"

# CPU Performance
echo ""
echo "=== CPU PERFORMANCE ==="
echo "CPU Cores: $(nproc)"
echo "CPU Info:"
lscpu | grep -E "(Model name|CPU MHz|BogoMIPS)"

echo ""
echo "CPU Frequencies:"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
    if [ -f "$cpu" ]; then
        cpu_num=$(echo $cpu | grep -o 'cpu[0-9]*' | grep -o '[0-9]*')
        freq=$(cat $cpu)
        echo "CPU$cpu_num: $((freq/1000)) MHz"
    fi
done

echo ""
echo "CPU Governor:"
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [ -f "$cpu" ]; then
        cpu_num=$(echo $cpu | grep -o 'cpu[0-9]*' | grep -o '[0-9]*')
        gov=$(cat $cpu)
        echo "CPU$cpu_num: $gov"
    fi
done

# Memory Performance
echo ""
echo "=== MEMORY PERFORMANCE ==="
echo "Memory Info:"
free -h

echo ""
echo "Memory Frequency & Performance:"
if [ -f /sys/class/devfreq/a020000.dmcfreq/cur_freq ]; then
    ddr_freq=$(cat /sys/class/devfreq/a020000.dmcfreq/cur_freq)
    echo "LPDDR5 Frequency: $((ddr_freq/1000000)) MHz"
fi

echo ""
echo "Memory Bandwidth Test (dd):"
echo "Writing 1GB to memory..."
time dd if=/dev/zero of=/tmp/benchmark_write bs=1M count=1024 2>&1 | grep -E "(copied|MB/s|GB/s)"

echo "Reading 1GB from memory..."
time dd if=/tmp/benchmark_write of=/dev/null bs=1M 2>&1 | grep -E "(copied|MB/s|GB/s)"
rm -f /tmp/benchmark_write

# NPU Performance
echo ""
echo "=== NPU PERFORMANCE ==="
if [ -d /sys/class/devfreq/3600000.npu ]; then
    echo "NPU Available Frequencies:"
    cat /sys/class/devfreq/3600000.npu/available_frequencies | tr ' ' '\n' | while read freq; do
        if [ ! -z "$freq" ]; then
            echo "  $((freq/1000000)) MHz"
        fi
    done
    
    echo ""
    echo "NPU Current Frequency: $(($(cat /sys/class/devfreq/3600000.npu/cur_freq)/1000000)) MHz"
    echo "NPU Governor: $(cat /sys/class/devfreq/3600000.npu/governor)"
    echo "NPU Max Frequency: $(($(cat /sys/class/devfreq/3600000.npu/max_freq)/1000000)) MHz"
    echo "NPU Min Frequency: $(($(cat /sys/class/devfreq/3600000.npu/min_freq)/1000000)) MHz"
else
    echo "NPU devfreq not found!"
fi

# GPU Performance  
echo ""
echo "=== GPU PERFORMANCE ==="
if [ -d /sys/class/devfreq/1800000.gpu ]; then
    echo "GPU Available Frequencies:"
    cat /sys/class/devfreq/1800000.gpu/available_frequencies | tr ' ' '\n' | while read freq; do
        if [ ! -z "$freq" ]; then
            echo "  $((freq/1000000)) MHz"
        fi
    done
    
    echo ""
    echo "GPU Current Frequency: $(($(cat /sys/class/devfreq/1800000.gpu/cur_freq)/1000000)) MHz"
    echo "GPU Governor: $(cat /sys/class/devfreq/1800000.gpu/governor)"
else
    echo "GPU devfreq not found!"
fi

# CPU Stress Test
echo ""
echo "=== CPU STRESS TEST ==="
echo "Running 10-second CPU stress test..."
stress-ng --cpu $(nproc) --timeout 10s --metrics-brief 2>/dev/null || echo "stress-ng not available, trying alternative..."

if ! command -v stress-ng >/dev/null 2>&1; then
    echo "Running sysbench CPU test..."
    sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) --time=10 run 2>/dev/null | grep -E "(events per second|total time)" || echo "sysbench not available"
fi

# Temperature Monitoring
echo ""
echo "=== THERMAL STATUS ==="
echo "CPU Temperature:"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    temp=$(cat /sys/class/thermal/thermal_zone0/temp)
    echo "Zone 0: $((temp/1000))°C"
fi

for zone in /sys/class/thermal/thermal_zone*/temp; do
    if [ -f "$zone" ]; then
        zone_num=$(echo $zone | grep -o 'thermal_zone[0-9]*' | grep -o '[0-9]*')
        temp=$(cat $zone)
        zone_type=$(cat ${zone%/*}/type 2>/dev/null || echo "unknown")
        echo "Zone $zone_num ($zone_type): $((temp/1000))°C"
    fi
done

# I/O Performance
echo ""
echo "=== STORAGE I/O PERFORMANCE ==="
echo "Testing eMMC/SD Card performance..."
echo "Random Write (4K blocks):"
dd if=/dev/urandom of=/tmp/test_4k bs=4k count=1000 2>&1 | grep -E "(copied|MB/s|GB/s)"

echo "Sequential Read (1MB blocks):"  
dd if=/tmp/test_4k of=/dev/null bs=1M 2>&1 | grep -E "(copied|MB/s|GB/s)"
rm -f /tmp/test_4k

# Network Performance (if available)
echo ""
echo "=== NETWORK STATUS ==="
echo "Network Interfaces:"
ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | tr -d ' '

# Process and Load
echo ""
echo "=== SYSTEM LOAD ==="
echo "Uptime and Load Average:"
uptime

echo ""
echo "Top CPU Processes:"
ps aux --sort=-%cpu | head -6

# Final Summary
echo ""
echo "================================================"
echo "Benchmark completed at: $(date)"
echo "================================================"

# Key Performance Summary
echo ""
echo "=== PERFORMANCE SUMMARY ==="
if [ -f /sys/class/devfreq/a020000.dmcfreq/cur_freq ]; then
    ddr_freq=$(cat /sys/class/devfreq/a020000.dmcfreq/cur_freq)
    echo "✓ Memory: $((ddr_freq/1000000)) MHz LPDDR5"
fi

if [ -f /sys/class/devfreq/3600000.npu/cur_freq ]; then
    npu_freq=$(cat /sys/class/devfreq/3600000.npu/cur_freq)
    echo "✓ NPU: $((npu_freq/1000000)) MHz"
fi

if [ -f /sys/class/devfreq/1800000.gpu/cur_freq ]; then
    gpu_freq=$(cat /sys/class/devfreq/1800000.gpu/cur_freq)
    echo "✓ GPU: $((gpu_freq/1000000)) MHz"
fi

cpu_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
if [ "$cpu_freq" != "0" ]; then
    echo "✓ CPU: $((cpu_freq/1000)) MHz"
fi