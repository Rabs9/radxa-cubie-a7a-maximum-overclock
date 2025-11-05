#!/bin/bash

# RADXA PERFORMANCE CONTROL CENTER - GUI VERSION
# Complete system performance management with GUI

# Check if zenity is installed for GUI
if ! command -v zenity &> /dev/null; then
    echo "Installing zenity for GUI..."
    sudo apt update && sudo apt install -y zenity
fi

# Performance Profiles
declare -A profiles=(
    ["eco"]="CPU_E:1404 CPU_P:1716 GPU:600 NPU:1200 RAM:conservative"
    ["conservative"]="CPU_E:1612 CPU_P:1898 GPU:800 NPU:1488 RAM:conservative"
    ["balanced"]="CPU_E:1716 CPU_P:1950 GPU:1000 NPU:1800 RAM:performance"
    ["performance"]="CPU_E:1794 CPU_P:2002 GPU:1200 NPU:2200 RAM:performance"
    ["maximum"]="CPU_E:1794 CPU_P:2002 GPU:1488 NPU:2520 RAM:performance"
    ["extreme"]="CPU_E:2080 CPU_P:2002 GPU:1488 NPU:2520 RAM:performance"
)

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
            cpu_oc_status="OVERCLOCKED to ${cpu_oc_e}MHz"
        fi
    fi
    
    echo "🚀 CURRENT SYSTEM PERFORMANCE 🚀"
    echo "================================"
    echo "CPU Efficiency: $((cpu_e_freq/1000))MHz ($cpu_oc_status)"
    echo "CPU Performance: $((cpu_p_freq/1000))MHz"
    echo "GPU: ${gpu_freq}MHz"
    echo "NPU: ${npu_freq}MHz ($(echo "scale=1; $npu_freq / 840 * 1.0" | bc -l 2>/dev/null || echo "?") TOPS)"
}

# Apply performance profile
apply_profile() {
    local profile=$1
    local settings=${profiles[$profile]}
    
    if [ -z "$settings" ]; then
        zenity --error --text="Invalid profile: $profile"
        return 1
    fi
    
    echo "Applying $profile profile..."
    
    # Parse settings
    local cpu_e_freq=$(echo $settings | grep -o 'CPU_E:[0-9]*' | cut -d: -f2)
    local cpu_p_freq=$(echo $settings | grep -o 'CPU_P:[0-9]*' | cut -d: -f2)
    local gpu_freq=$(echo $settings | grep -o 'GPU:[0-9]*' | cut -d: -f2)
    local npu_freq=$(echo $settings | grep -o 'NPU:[0-9]*' | cut -d: -f2)
    local ram_mode=$(echo $settings | grep -o 'RAM:[a-z]*' | cut -d: -f2)
    
    # Apply CPU frequencies (if we can overclock them)
    echo "Setting CPU frequencies..."
    
    # Apply CPU frequencies (if we can overclock them)
    echo "Setting CPU frequencies..."
    if [ -f "/sys/kernel/cpu_overclock/overclock" ]; then
        sudo sh -c "echo ${cpu_e_freq},0 > /sys/kernel/cpu_overclock/overclock" 2>/dev/null
    fi
    
    # Apply GPU/NPU frequencies
    echo "Setting GPU/NPU frequencies..."
    sudo sh -c "echo ${npu_freq},${gpu_freq} > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock" 2>/dev/null
    
    # Set RAM performance
    echo "Setting RAM performance..."
    if [ "$ram_mode" = "performance" ]; then
        # Enable performance mode for memory
        echo performance | sudo tee /sys/devices/platform/a020000.dmcfreq/devfreq/a020000.dmcfreq/governor > /dev/null 2>&1
    else
        echo powersave | sudo tee /sys/devices/platform/a020000.dmcfreq/devfreq/a020000.dmcfreq/governor > /dev/null 2>&1
    fi
    
    return 0
}

# GUI Main Menu
show_main_menu() {
    local choice
    choice=$(zenity --list --radiolist \
        --title="🚀 Radxa Performance Control Center 🚀" \
        --text="Select Performance Profile:\n\n$(get_current_status)" \
        --column="Select" --column="Profile" --column="Description" \
        --width=800 --height=500 \
        FALSE "eco" "Battery saving mode - Lowest performance" \
        FALSE "conservative" "Balanced power/performance" \
        FALSE "balanced" "Good performance, moderate power" \
        TRUE "performance" "High performance mode" \
        FALSE "maximum" "Maximum stable performance" \
        FALSE "extreme" "EXPERIMENTAL - Beyond spec limits!" \
        FALSE "custom" "Custom frequency settings" \
        FALSE "monitor" "System performance monitor" \
        FALSE "status" "Current system status")
    
    case $choice in
        "eco"|"conservative"|"balanced"|"performance"|"maximum"|"extreme")
            if apply_profile $choice; then
                zenity --info --text="✅ $choice profile applied successfully!\n\nNew system performance:\n$(get_current_status)"
            else
                zenity --error --text="❌ Failed to apply $choice profile"
            fi
            ;;
        "custom")
            show_custom_menu
            ;;
        "monitor")
            show_monitor
            ;;
        "status")
            zenity --info --title="System Status" --text="$(get_current_status)\n\n$(uptime)\n\nTemperature: $(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1 | awk '{print $1/1000}')°C"
            ;;
        *)
            exit 0
            ;;
    esac
}

# Custom settings menu
show_custom_menu() {
    local result
    result=$(zenity --forms --title="Custom Performance Settings" \
        --text="Enter custom frequencies (MHz):" \
        --add-entry="NPU Frequency (current: max 2520MHz)" \
        --add-entry="GPU Frequency (current: max 1488MHz)" \
        --add-combo="RAM Mode" --combo-values="conservative|performance")
    
    if [ $? -eq 0 ]; then
        local npu_freq=$(echo "$result" | cut -d'|' -f1)
        local gpu_freq=$(echo "$result" | cut -d'|' -f2)
        local ram_mode=$(echo "$result" | cut -d'|' -f3)
        
        if [[ "$npu_freq" =~ ^[0-9]+$ ]] && [[ "$gpu_freq" =~ ^[0-9]+$ ]]; then
            sudo sh -c "echo ${npu_freq},${gpu_freq} > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock"
            zenity --info --text="✅ Custom settings applied!\nNPU: ${npu_freq}MHz\nGPU: ${gpu_freq}MHz"
        else
            zenity --error --text="❌ Invalid frequency values"
        fi
    fi
}

# Performance monitor
show_monitor() {
    while true; do
        local status="🚀 LIVE PERFORMANCE MONITOR 🚀\n"
        status+="================================\n\n"
        status+="$(get_current_status)\n\n"
        status+="System Load: $(uptime | awk -F'load average:' '{print $2}')\n"
        status+="Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')\n"
        status+="Temperature: $(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1 | awk '{print $1/1000}')°C\n\n"
        status+="Press Cancel to return to main menu"
        
        if ! zenity --info --title="Performance Monitor" --text="$status" --timeout=5; then
            break
        fi
    done
}

# Check if running as root for some operations
if [ "$EUID" -ne 0 ] && [ "$1" != "--gui-only" ]; then
    echo "Some features require root privileges."
    echo "You can still use the GUI, but changes may require password."
fi

# Start GUI
while true; do
    show_main_menu
    if [ $? -ne 0 ]; then
        break
    fi
done