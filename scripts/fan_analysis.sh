#!/bin/bash

# COMPREHENSIVE FAN ANALYSIS & PIN TESTING
# Tests fan behavior and investigates pin connections

echo "🌀 COMPREHENSIVE FAN & PIN ANALYSIS 🌀"
echo "======================================"
echo ""

FAN_PWM_PATH="/sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1"

echo "📊 CURRENT FAN STATUS:"
echo "---------------------"
current_speed=$(cat "$FAN_PWM_PATH")
percentage=$(( (current_speed * 100) / 255 ))
temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}' || echo "Unknown")

echo "PWM Value: $current_speed/255 (${percentage}%)"
echo "Temperature: ${temp}°C"
echo "Fan Control Path: $FAN_PWM_PATH"
echo ""

echo "🔍 PIN INVESTIGATION - PINS 4 & 20:"
echo "-----------------------------------"

# Check if these are physical GPIO pins
echo "Checking if pins 4 and 20 correspond to GPIO numbers..."

# Look for GPIO mappings
if [ -d "/sys/kernel/debug/pinctrl" ]; then
    echo "Pinctrl debug info available"
    sudo ls /sys/kernel/debug/pinctrl/ 2>/dev/null | head -3
else
    echo "Pinctrl debug not available"
fi

# Check PWM chip assignments
echo ""
echo "🔧 PWM SYSTEM ANALYSIS:"
echo "----------------------"
echo "Available PWM chips:"
ls /sys/class/pwm/
echo ""

echo "PWM Fan connection details:"
ls -la /sys/devices/platform/pwm-fan/supplier:*

echo ""
echo "⚡ POWER CONSUMPTION TEST:"
echo "-------------------------"

# Test power consumption at different speeds
for speed in 0 64 128 192 255; do
    echo "Setting fan to PWM $speed..."
    echo "$speed" | sudo tee "$FAN_PWM_PATH" > /dev/null
    percentage=$(( (speed * 100) / 255 ))
    echo "  PWM: $speed/255 (${percentage}%)"
    sleep 2
    
    # Check if we can measure any power-related changes
    if [ -f "/sys/class/power_supply/axp2202-battery/current_now" ]; then
        current=$(cat /sys/class/power_supply/axp2202-battery/current_now 2>/dev/null || echo "N/A")
        echo "  System current: $current μA"
    fi
    echo ""
done

echo "🔌 PIN POWER ANALYSIS:"
echo "---------------------"

# Check if pins 4 and 20 might be controlled by regulators
echo "Looking for fan-related power controls..."

# Check for fan-related regulators
if find /sys -name "*fan*" -path "*regulator*" 2>/dev/null | head -1; then
    echo "Found fan-related power regulation"
else
    echo "No dedicated fan power regulation found"
fi

# Check device tree for pin assignments
echo ""
echo "Device tree PWM configuration:"
if [ -f "/sys/firmware/devicetree/base/pwm-fan/pwms" ]; then
    echo "PWM configuration found in device tree"
    # The raw data shows PWM controller and pin assignment
else
    echo "No PWM fan configuration in device tree"
fi

echo ""
echo "💡 ANALYSIS RESULTS:"
echo "-------------------"
echo "1. Fan is controlled via PWM (Pulse Width Modulation)"
echo "2. PWM values: 0 (off) to 255 (maximum speed)"
echo "3. Current control path: $FAN_PWM_PATH"
echo ""

if [ "$current_speed" -eq 0 ]; then
    echo "⚠️  POTENTIAL ISSUE IDENTIFIED:"
    echo "Fan is currently OFF. When system shuts down, the fan will stay OFF."
    echo "This is actually GOOD behavior!"
else
    echo "⚠️  SHUTDOWN BEHAVIOR:"
    echo "If fan stays at PWM $current_speed after shutdown, it indicates:"
    echo "- Pin 4 or 20 might provide continuous power"
    echo "- Fan needs explicit shutdown control"
fi

echo ""
echo "🛠️ SOLUTION IMPLEMENTED:"
echo "------------------------"
echo "✅ Created fan control script: /home/radxa/fan_control.sh"
echo "✅ Created shutdown service: radxa-fan.service"
echo "✅ Service will turn off fan on system shutdown"
echo ""

echo "🎮 USAGE:"
echo "--------"
echo "./fan_control.sh off      # Turn fan off"
echo "./fan_control.sh max      # Maximum speed"
echo "./fan_control.sh thermal  # Automatic thermal control"
echo ""

# Restore fan to maximum
echo "Restoring fan to maximum speed..."
echo "255" | sudo tee "$FAN_PWM_PATH" > /dev/null
echo "🌀 Fan restored to maximum speed"