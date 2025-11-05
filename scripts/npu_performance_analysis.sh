#!/bin/bash

echo "=================================================="
echo "NPU Performance Analysis & TOPS Calculation"
echo "=================================================="
echo "Timestamp: $(date)"
echo

# Current NPU status
echo "=== CURRENT NPU STATUS ==="
NPU_FREQ=$(cat /sys/class/devfreq/3600000.npu/cur_freq)
NPU_FREQ_MHZ=$(echo "scale=0; $NPU_FREQ/1000000" | bc)
echo "Current NPU Frequency: ${NPU_FREQ_MHZ} MHz"
echo "Available NPU Frequencies: $(cat /sys/class/devfreq/3600000.npu/available_frequencies | sed 's/000000/ MHz/g')"
echo "NPU Governor: $(cat /sys/class/devfreq/3600000.npu/governor)"
echo

# Theoretical TOPS calculation
echo "=== NPU TOPS CALCULATION ==="
echo "NPU Architecture: Allwinner A733 NPU (AI Processing Unit)"
echo "Current Frequency: ${NPU_FREQ_MHZ} MHz"

# Estimate TOPS based on frequency (typical ARM NPU scaling)
# Base estimation: ~1.2 TOPS at 1000MHz for A733-class NPU
BASE_TOPS_1000MHZ=1.2
CURRENT_TOPS=$(echo "scale=2; $BASE_TOPS_1000MHZ * $NPU_FREQ_MHZ / 1000" | bc)
echo "Estimated Current TOPS: ${CURRENT_TOPS} TOPS"

# Calculate TOPS at different frequencies
echo
echo "=== TOPS AT DIFFERENT FREQUENCIES ==="
for freq in 492 852 1008 1120; do
    tops=$(echo "scale=2; $BASE_TOPS_1000MHZ * $freq / 1000" | bc)
    if [ $freq -eq $NPU_FREQ_MHZ ]; then
        echo "  ${freq} MHz: ${tops} TOPS (CURRENT)"
    elif [ $freq -eq 1120 ]; then
        echo "  ${freq} MHz: ${tops} TOPS (TARGET - NOT AVAILABLE)"
    else
        echo "  ${freq} MHz: ${tops} TOPS"
    fi
done
echo

# Performance comparison
echo "=== PERFORMANCE COMPARISON ==="
BASELINE_FREQ=492
BASELINE_TOPS=$(echo "scale=2; $BASE_TOPS_1000MHZ * $BASELINE_FREQ / 1000" | bc)
CURRENT_IMPROVEMENT=$(echo "scale=1; ($CURRENT_TOPS - $BASELINE_TOPS) / $BASELINE_TOPS * 100" | bc)
TARGET_TOPS_1120=$(echo "scale=2; $BASE_TOPS_1000MHZ * 1120 / 1000" | bc)
TARGET_IMPROVEMENT=$(echo "scale=1; ($TARGET_TOPS_1120 - $BASELINE_TOPS) / $BASELINE_TOPS * 100" | bc)

echo "Baseline (492MHz): ${BASELINE_TOPS} TOPS"
echo "Current (${NPU_FREQ_MHZ}MHz): ${CURRENT_TOPS} TOPS (+${CURRENT_IMPROVEMENT}% vs baseline)"
echo "Target (1120MHz): ${TARGET_TOPS_1120} TOPS (+${TARGET_IMPROVEMENT}% vs baseline)"
echo

# System performance summary
echo "=== OVERALL SYSTEM PERFORMANCE ==="
echo "CPU Max Frequency: $(cat /proc/cpuinfo | grep "cpu MHz" | tail -1 | awk '{print $4}') MHz"
echo "LPDDR5 Frequency: $(cat /sys/class/devfreq/a020000.dmcfreq/cur_freq | awk '{print $1/1000000 " MHz"}')"
echo "NPU Frequency: ${NPU_FREQ_MHZ} MHz (${CURRENT_TOPS} TOPS)"

# Performance vs previous optimal configuration
echo
echo "=== COMPARISON TO PREVIOUS OPTIMAL CONFIG ==="
echo "Previous Target: 1120MHz NPU (${TARGET_TOPS_1120} TOPS)"  
echo "Current Actual: ${NPU_FREQ_MHZ}MHz NPU (${CURRENT_TOPS} TOPS)"
MISSING_PERFORMANCE=$(echo "scale=1; ($TARGET_TOPS_1120 - $CURRENT_TOPS) / $TARGET_TOPS_1120 * 100" | bc)
echo "Missing Performance: ${MISSING_PERFORMANCE}% of target TOPS"
echo

echo "=================================================="
echo "Analysis Complete"
echo "=================================================="
