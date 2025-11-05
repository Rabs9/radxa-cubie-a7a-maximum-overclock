#!/bin/bash

echo "=========================================="
echo "NPU Overclocking Potential Analysis"
echo "=========================================="
echo "Date: $(date)"
echo

echo "=== HARDWARE ANALYSIS ==="
echo "NPU Hardware Max: 1200MHz (from dmesg)"
echo "Current Driver Limit: 1008MHz (3 frequencies)"
echo "Target from DTB: 1120MHz (4th frequency)"
echo

echo "=== VOLTAGE ANALYSIS ==="
echo "Current working voltages:"
echo "  492MHz: 800mV"
echo "  852MHz: 800mV" 
echo "  1008MHz: 960mV"
echo "  1120MHz: 1080mV (defined but blocked)"
echo
echo "Regulator capacity: 500mV - 1540mV"
echo "Available headroom: $(echo '1540 - 1080' | bc)mV above 1120MHz target"
echo

echo "=== OVERCLOCKING POTENTIAL ==="
echo "With custom kernel, theoretical frequencies:"

# Calculate potential frequencies based on voltage scaling
voltages=(800 850 900 950 960 1000 1050 1080 1100 1150 1200 1250 1300 1350 1400 1450 1500 1540)
base_freq=492
base_voltage=800

echo "Voltage -> Estimated Max Frequency -> TOPS"
for voltage in "${voltages[@]}"; do
    # Rough frequency scaling based on voltage (not perfectly linear but approximation)
    freq_ratio=$(echo "scale=3; sqrt($voltage / $base_voltage)" | bc -l)
    estimated_freq=$(echo "scale=0; $base_freq * $freq_ratio" | bc)
    
    # Estimate TOPS (1.2 TOPS baseline at 1000MHz)
    tops=$(echo "scale=2; 1.2 * $estimated_freq / 1000" | bc)
    
    # Mark current known points
    marker=""
    case $voltage in
        800) marker=" (CURRENT 492MHz)" ;;
        960) marker=" (CURRENT 1008MHz)" ;;
        1080) marker=" (DTB TARGET 1120MHz)" ;;
        1200) marker=" (HARDWARE MAX)" ;;
        1540) marker=" (REGULATOR MAX)" ;;
    esac
    
    if [ "$estimated_freq" -le 1600 ]; then  # Reasonable upper bound
        printf "%4dmV -> %4dMHz -> %4.2f TOPS%s\n" "$voltage" "$estimated_freq" "$tops" "$marker"
    fi
done

echo
echo "=== CUSTOM KERNEL MODIFICATIONS NEEDED ==="
echo "1. NPU devfreq driver: Remove 3-frequency limit"
echo "2. OPP table validation: Accept voltages up to 1540mV"
echo "3. Thermal management: Add higher frequency thermal points"
echo "4. Clock tree: Ensure PLL can generate target frequencies"
echo

echo "=== ESTIMATED OVERCLOCKING RESULTS ==="
max_safe_voltage=1300  # Conservative estimate
max_freq=$(echo "scale=0; $base_freq * sqrt($max_safe_voltage / $base_voltage)" | bc -l)
max_tops=$(echo "scale=2; 1.2 * $max_freq / 1000" | bc)

echo "Conservative overclock target: ${max_freq}MHz at ${max_safe_voltage}mV"
echo "Estimated TOPS at max OC: ${max_tops} TOPS"
echo "Improvement over current: $(echo "scale=1; ($max_tops - 1.2) / 1.2 * 100" | bc)%"
echo "Improvement over baseline: $(echo "scale=1; ($max_tops - 0.59) / 0.59 * 100" | bc)%"

echo
echo "=== RISKS & CONSIDERATIONS ==="
echo "⚠️  Higher frequencies = more heat"
echo "⚠️  Silicon lottery - not all chips can handle max overclock"
echo "⚠️  Potential system instability at extreme settings"
echo "⚠️  Increased power consumption"
echo "✅ Your regulator has plenty of headroom (1540mV max)"
echo "✅ Hardware reports 1200MHz capability"
echo "✅ Good cooling with HDMI passive setup"

echo "=========================================="
