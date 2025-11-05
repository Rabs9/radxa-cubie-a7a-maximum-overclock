#!/bin/bash

# RADXA SHUTDOWN FAN CONTROL
# Ensures fan turns off during system shutdown

FAN_PWM_PATH="/sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1"

case "$1" in 
    start)
        # Set fan to maximum on boot
        echo "255" > "$FAN_PWM_PATH" 2>/dev/null
        echo "🌀 Fan started at maximum speed"
        ;;
    stop)
        # Turn off fan on shutdown
        echo "0" > "$FAN_PWM_PATH" 2>/dev/null
        echo "🔴 Fan turned off for shutdown"
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit 0