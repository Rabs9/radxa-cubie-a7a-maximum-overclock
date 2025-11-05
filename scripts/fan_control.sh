#!/bin/bash

# RADXA FAN CONTROL SCRIPT
# Controls fan speed and ensures shutdown behavior

FAN_PWM_PATH="/sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1"
TEMP_PATH="/sys/class/thermal/thermal_zone0/temp"

# Check if fan control is available
if [ ! -f "$FAN_PWM_PATH" ]; then
    echo "❌ Fan control not available at $FAN_PWM_PATH"
    exit 1
fi

# Functions
get_temperature() {
    if [ -f "$TEMP_PATH" ]; then
        local temp_millidegrees=$(cat "$TEMP_PATH")
        echo $((temp_millidegrees / 1000))
    else
        echo "0"
    fi
}

set_fan_speed() {
    local speed=$1
    if [ "$speed" -lt 0 ]; then speed=0; fi
    if [ "$speed" -gt 255 ]; then speed=255; fi
    
    echo "$speed" | sudo tee "$FAN_PWM_PATH" > /dev/null
    local percentage=$(( (speed * 100) / 255 ))
    echo "🌀 Fan speed set to $speed/255 (${percentage}%)"
}

get_fan_speed() {
    cat "$FAN_PWM_PATH"
}

show_status() {
    local current_speed=$(get_fan_speed)
    local temperature=$(get_temperature)
    local percentage=$(( (current_speed * 100) / 255 ))
    
    echo "🌀 FAN STATUS:"
    echo "Speed: $current_speed/255 (${percentage}%)"
    echo "Temperature: ${temperature}°C"
    if [ "$current_speed" -eq 0 ]; then
        echo "Status: OFF ⚫"
    elif [ "$current_speed" -lt 128 ]; then
        echo "Status: LOW 🟡"
    elif [ "$current_speed" -lt 200 ]; then
        echo "Status: MEDIUM 🟠"
    else
        echo "Status: HIGH 🔴"
    fi
}

thermal_control() {
    echo "🌡️ Starting thermal-based fan control..."
    echo "Press Ctrl+C to stop"
    
    while true; do
        local temp=$(get_temperature)
        local new_speed
        
        if [ "$temp" -lt 45 ]; then
            new_speed=64    # 25% - Cool
        elif [ "$temp" -lt 55 ]; then
            new_speed=128   # 50% - Warm
        elif [ "$temp" -lt 65 ]; then
            new_speed=192   # 75% - Hot
        else
            new_speed=255   # 100% - Very hot
        fi
        
        local current_speed=$(get_fan_speed)
        if [ "$new_speed" -ne "$current_speed" ]; then
            echo "Temperature: ${temp}°C - Adjusting fan speed"
            set_fan_speed "$new_speed"
        fi
        
        sleep 5
    done
}

# Main menu
case "${1:-menu}" in
    "status"|"s")
        show_status
        ;;
    "off"|"0")
        echo "🔴 Turning fan OFF"
        set_fan_speed 0
        ;;
    "low"|"25")
        echo "🟡 Setting fan to LOW speed"
        set_fan_speed 64
        ;;
    "medium"|"50")
        echo "🟠 Setting fan to MEDIUM speed"
        set_fan_speed 128
        ;;
    "high"|"75")
        echo "🟠 Setting fan to HIGH speed"
        set_fan_speed 192
        ;;
    "max"|"100")
        echo "🔴 Setting fan to MAXIMUM speed"
        set_fan_speed 255
        ;;
    "thermal"|"auto")
        thermal_control
        ;;
    [0-9]|[0-9][0-9]|[0-9][0-9][0-9])
        echo "🔧 Setting custom fan speed: $1"
        set_fan_speed "$1"
        ;;
    "menu"|*)
        echo "🌀 RADXA FAN CONTROL"
        echo "===================="
        echo ""
        show_status
        echo ""
        echo "USAGE: $0 [option]"
        echo ""
        echo "OPTIONS:"
        echo "  status, s     - Show current fan status"
        echo "  off, 0        - Turn fan OFF"
        echo "  low, 25       - Set to LOW speed (25%)"
        echo "  medium, 50    - Set to MEDIUM speed (50%)"
        echo "  high, 75      - Set to HIGH speed (75%)"
        echo "  max, 100      - Set to MAXIMUM speed (100%)"
        echo "  thermal, auto - Automatic thermal control"
        echo "  [0-255]       - Set custom PWM value"
        echo ""
        echo "EXAMPLES:"
        echo "  $0 off        # Turn fan off"
        echo "  $0 128        # Set to 50% speed"
        echo "  $0 thermal    # Automatic control"
        ;;
esac