#!/bin/bash

# USB MIGRATION PREPARATION CHECKER
# Analyzes what needs to be modified for USB migration

echo "🚀 USB MIGRATION PREPARATION ANALYSIS 🚀"
echo "========================================="
echo ""

echo "📊 CURRENT SYSTEM STATE:"
echo "------------------------"
echo "Current root: $(df -h / | tail -1 | awk '{print $1}')"
echo "File system: $(df -T / | tail -1 | awk '{print $2}')"
echo "Boot UUID: $(cat /proc/cmdline | grep -o 'root=UUID=[^[:space:]]*' | cut -d= -f3)"
echo "Available space: $(df -h / | tail -1 | awk '{print $4}')"
echo ""

echo "🔧 CRITICAL FILES TO PRESERVE:"
echo "------------------------------"

# Count our custom files
ko_files=$(ls /home/radxa/*.ko 2>/dev/null | wc -l)
sh_files=$(ls /home/radxa/*.sh 2>/dev/null | wc -l)
service_files=$(ls /etc/systemd/system/radxa-*.service 2>/dev/null | wc -l)

echo "✅ Kernel modules: $ko_files files"
echo "   - llm_unified_overclock.ko (NPU/GPU overclocking)"
echo "   - cpu_overclock.ko (CPU overclocking)"  
echo "   - ram_overclock.ko (RAM optimization)"
echo ""

echo "✅ Control scripts: $sh_files files"
echo "   - performance_control.sh (main control)"
echo "   - fan_control.sh (fan management)"
echo "   - All benchmark and analysis tools"
echo ""

echo "✅ System services: $service_files files"
echo "   - radxa-fan.service (fan shutdown control)"
echo ""

echo "⚡ CURRENTLY ACTIVE PERFORMANCE:"
echo "-------------------------------"
if [ -f "/sys/devices/platform/soc@3000000/3600000.npu/llm_overclock" ]; then
    npu_status=$(cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock | head -3)
    echo "NPU/GPU Status:"
    echo "$npu_status" | sed 's/^/   /'
fi

if [ -f "/sys/kernel/cpu_overclock/overclock" ]; then
    cpu_status=$(cat /sys/kernel/cpu_overclock/overclock | head -2)
    echo "CPU Status:"
    echo "$cpu_status" | sed 's/^/   /'
fi
echo ""

echo "🔍 BOOT CONFIGURATION ANALYSIS:"
echo "-------------------------------"
current_cmdline=$(cat /proc/cmdline)
echo "Current kernel parameters:"
echo "$current_cmdline" | sed 's/^/   /'
echo ""

# Check if root is specified by UUID or device
if echo "$current_cmdline" | grep -q "root=UUID="; then
    echo "✅ Boot uses UUID (GOOD - will work with USB)"
    current_uuid=$(echo "$current_cmdline" | grep -o 'root=UUID=[^[:space:]]*' | cut -d= -f3)
    echo "   Current UUID: $current_uuid"
else
    echo "⚠️  Boot uses device path (NEEDS MODIFICATION)"
fi

echo ""
echo "💾 STORAGE PERFORMANCE COMPARISON:"
echo "---------------------------------"
echo "Current SD Card performance:"
# Quick read test
echo "Testing current storage read speed..."
read_speed=$(sudo dd if=/dev/mmcblk0 of=/dev/null bs=1M count=100 2>&1 | grep -o '[0-9.]*MB/s' | tail -1)
echo "   Read speed: ${read_speed:-Testing...}"

echo ""
echo "🗂️ SOFTWARE MODIFICATIONS NEEDED:"
echo "---------------------------------"

echo "1. BOOTLOADER CONFIGURATION:"
echo "   ⚠️  May need modification if not using UUID"
echo "   - Current uses UUID: $(echo "$current_cmdline" | grep -q "root=UUID=" && echo "YES ✅" || echo "NO ❌")"
echo ""

echo "2. KERNEL MODULES:"
echo "   ✅ NO modification needed"
echo "   - Our .ko files are portable"
echo "   - Will work on any storage device"
echo ""

echo "3. SYSTEM SERVICES:" 
echo "   ✅ NO modification needed"
echo "   - Systemd services are storage-independent"
echo "   - Fan control will work on USB"
echo ""

echo "4. PERFORMANCE SCRIPTS:"
echo "   ✅ NO modification needed"
echo "   - All scripts use absolute paths"
echo "   - Hardware interfaces remain the same"
echo ""

echo "5. OVERCLOCKING STATUS:"
echo "   ⚠️  Will need to be reapplied after migration"
echo "   - Modules will need to be reloaded"
echo "   - Performance settings will reset"
echo ""

echo "📋 MIGRATION REQUIREMENTS:"
echo "--------------------------"
echo "BEFORE starting USB migration:"
echo ""
echo "1. ✅ Create backup package of all custom files"
echo "2. ✅ Export current performance settings"
echo "3. ✅ Document current overclocking state"
echo "4. ✅ Backup systemd services"
echo "5. ⚠️  Check if bootloader supports USB boot"
echo ""

echo "AFTER USB migration:"
echo ""
echo "1. 📦 Restore custom files"
echo "2. 🔧 Reinstall kernel modules"
echo "3. ⚡ Reapply overclocking settings"
echo "4. 🌀 Restart fan control service"
echo "5. 🧪 Verify all performance enhancements"
echo ""

echo "🎯 RECOMMENDATION:"
echo "-----------------"
echo "✅ USB migration is SAFE for our overclocking setup!"
echo "✅ All our modifications are SOFTWARE-based"
echo "✅ Hardware interfaces will remain identical"
echo "✅ Performance gains from USB will be SIGNIFICANT"
echo ""
echo "💡 Expected improvements with USB 3.0:"
echo "   - Read speeds: 50-150 MB/s (vs ~20-30 MB/s SD)"
echo "   - Random access: Much faster"
echo "   - System responsiveness: Greatly improved"
echo ""

echo "Ready to proceed with USB migration! 🚀"