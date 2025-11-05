#!/bin/bash

# RADXA PERFORMANCE CONTROL CENTER - Terminal Version
# Complete system performance management

echo "🚀 RADXA PERFORMANCE CONTROL CENTER 🚀"
echo "========================================"
echo ""

# Get current system status
get_current_status() {
    local cpu_e_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
    local cpu_p_freq=$(cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_cur_freq 2>/dev/null || echo "0")
    local npu_freq=$(grep "NPU:" /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock 2>/dev/null | awk '{print $2}' || echo "Unknown")
    local gpu_freq=$(grep "GPU:" /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock 2>/dev/null | awk '{print $2}' || echo "Unknown")
    
    # Check CPU overclock module status
    local cpu_oc_status="Standard"
    if [ -f "/sys/kernel/cpu_overclock/overclock" ]; then
        local cpu_oc_e=$(grep "CPU_E:" /sys/kernel/cpu_overclock/overclock 2>/dev/null | awk '{print $2}')
        if [ "$cpu_oc_e" -gt "1794" ] 2>/dev/null; then
            cpu_oc_status="🔥 OVERCLOCKED to ${cpu_oc_e}MHz"
        fi
    fi
    
    echo "CURRENT SYSTEM PERFORMANCE:"
    echo "CPU Efficiency: $((cpu_e_freq/1000))MHz ($cpu_oc_status)"
    echo "CPU Performance: $((cpu_p_freq/1000))MHz"
    echo "GPU: ${gpu_freq}MHz"
    echo "NPU: ${npu_freq}MHz ($(echo "scale=1; $npu_freq / 840 * 1.0" | bc -l 2>/dev/null || echo "?") TOPS)"
    echo ""
}

# Apply performance profile
apply_profile() {
    local profile=$1
    
    case $profile in
        "maximum")
            echo "🚀 Applying MAXIMUM performance profile..."
            # Set NPU/GPU to maximum
            echo "2520,1488" | sudo tee /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock > /dev/null
            echo "✅ GPU/NPU set to maximum performance"
            ;;
        "extreme")
            echo "🔥 Applying EXTREME performance profile..."
            # Set CPU to overclocked frequencies
            if [ -f "/sys/kernel/cpu_overclock/overclock" ]; then
                echo "2080,0" | sudo tee /sys/kernel/cpu_overclock/overclock > /dev/null
                echo "✅ CPU overclocked to 2080MHz"
            fi
            # Set NPU/GPU to maximum
            echo "2520,1488" | sudo tee /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock > /dev/null
            echo "✅ GPU/NPU set to maximum performance"
            ;;
        "conservative")
            echo "⚡ Applying CONSERVATIVE performance profile..."
            echo "1488,800" | sudo tee /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock > /dev/null
            echo "✅ Reduced power consumption mode"
            ;;
        *)
            echo "❌ Unknown profile: $profile"
            return 1
            ;;
    esac
    
    echo ""
    return 0
}

# Display current status
get_current_status

echo "AVAILABLE PERFORMANCE PROFILES:"
echo "1. conservative - Balanced power/performance"
echo "2. maximum      - Maximum stable performance (NPU: 2520MHz, GPU: 1488MHz)"
echo "3. extreme      - OVERCLOCKED! (CPU: 2080MHz, NPU: 2520MHz, GPU: 1488MHz)"
echo "4. status       - Show current status"
echo "5. quit         - Exit"
echo ""

while true; do
    read -p "Select profile (1-5): " choice
    
    case $choice in
        1)
            apply_profile "conservative"
            get_current_status
            ;;
        2)
            apply_profile "maximum"
            get_current_status
            ;;
        3)
            apply_profile "extreme"
            get_current_status
            ;;
        4)
            get_current_status
            ;;
        5)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please select 1-5."
            ;;
    esac
    echo ""
done