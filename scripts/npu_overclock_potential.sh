#!/bin/bash

echo "=========================================="
echo "NPU OVERCLOCKING POTENTIAL (Custom Kernel)"
echo "=========================================="
echo

echo "=== CURRENT STATUS ==="
echo "Hardware Max: 1200MHz (from dmesg)"
echo "Driver Limit: 1008MHz (artificial 3-freq limit)" 
echo "Regulator: 500-1540mV (plenty of headroom)"
echo

echo "=== REALISTIC OVERCLOCKING TARGETS ==="
echo
printf "%-8s %-8s %-8s %-12s %s\n" "Voltage" "Freq" "TOPS" "vs Current" "Status"
echo "------------------------------------------------------------"

# Define realistic frequency/voltage pairs for overclocking
declare -A oc_points=(
    [960]=1008   # Current max
    [1080]=1120  # DTB target (blocked)
    [1150]=1200  # Hardware max
    [1200]=1300  # Conservative OC
    [1250]=1400  # Moderate OC  
    [1300]=1500  # Aggressive OC
    [1350]=1600  # Extreme OC
    [1400]=1700  # Dangerous territory
)

current_tops=1.20

for voltage in $(echo "${!oc_points[@]}" | tr ' ' '\n' | sort -n); do
    freq=${oc_points[$voltage]}
    tops=$(echo "scale=2; 1.2 * $freq / 1000" | bc)
    improvement=$(echo "scale=1; ($tops - $current_tops) / $current_tops * 100" | bc)
    
    case $voltage in
        960) status="(CURRENT MAX)" ;;
        1080) status="(DTB TARGET - blocked)" ;;
        1150) status="(HARDWARE MAX)" ;;
        1200) status="(Safe OC)" ;;
        1250) status="(Moderate OC)" ;;
        1300) status="(Aggressive OC)" ;;
        1350) status="(Extreme OC)" ;;
        1400) status="(RISKY)" ;;
    esac
    
    printf "%-8s %-8s %-8s +%-10s %s\n" "${voltage}mV" "${freq}MHz" "${tops}" "${improvement}%" "$status"
done

echo
echo "=== CUSTOM KERNEL MODIFICATIONS ==="
echo "File to modify: drivers/devfreq/allwinner-npu-devfreq.c"
echo
echo "Required changes:"
echo "1. Remove hardcoded 3-frequency limit in OPP table parsing"
echo "2. Add additional voltage/frequency pairs up to 1400mV"
echo "3. Update thermal throttling points for higher frequencies"
echo "4. Ensure clock generator supports target frequencies"
echo

echo "=== RECOMMENDED OVERCLOCKING STRATEGY ==="
echo
echo "🎯 TARGET: 1400MHz @ 1250mV = 1.68 TOPS"
echo "   - 40% performance increase over current 1.2 TOPS"
echo "   - Well within regulator limits (1540mV max)"
echo "   - Reasonable voltage for silicon"
echo
echo "🚀 AGGRESSIVE: 1600MHz @ 1350mV = 1.92 TOPS"  
echo "   - 60% performance increase"
echo "   - 1.92 TOPS approaches useful AI workload threshold"
echo "   - Still 190mV below regulator maximum"
echo

echo "=== AI WORKLOAD CAPABILITY ==="
current_tops=1.20
moderate_tops=1.68
aggressive_tops=1.92

echo "Current (1008MHz): ${current_tops} TOPS - Limited small models only"
echo "Moderate OC (1400MHz): ${moderate_tops} TOPS - Small LLMs feasible"
echo "Aggressive OC (1600MHz): ${aggressive_tops} TOPS - Decent small LLM performance"
echo

echo "=== IMPLEMENTATION STEPS ==="
echo "1. Build custom kernel with modified NPU driver"
echo "2. Create custom DTB with additional frequency points"
echo "3. Test stability at each frequency level"
echo "4. Add thermal monitoring for safety"
echo "5. Create frequency scaling profiles"

echo "=========================================="
