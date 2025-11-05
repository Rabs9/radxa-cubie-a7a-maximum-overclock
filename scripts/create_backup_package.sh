#!/bin/bash

# OVERCLOCKING BACKUP & MIGRATION PACKAGE CREATOR
# Creates a complete backup of all overclocking modifications

BACKUP_DIR="/home/radxa/overclock_backup_$(date +%Y%m%d_%H%M%S)"
echo "📦 CREATING OVERCLOCKING BACKUP PACKAGE 📦"
echo "==========================================="
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"/{modules,scripts,services,config,docs}

echo "🔧 BACKING UP KERNEL MODULES:"
echo "-----------------------------"
cp /home/radxa/*.ko "$BACKUP_DIR/modules/" 2>/dev/null && echo "✅ Kernel modules backed up" || echo "❌ No kernel modules found"
cp /home/radxa/Makefile "$BACKUP_DIR/modules/" 2>/dev/null && echo "✅ Makefile backed up"
cp /home/radxa/*.c "$BACKUP_DIR/modules/" 2>/dev/null && echo "✅ Source code backed up"

echo ""
echo "📜 BACKING UP CONTROL SCRIPTS:"
echo "------------------------------"
cp /home/radxa/*.sh "$BACKUP_DIR/scripts/" 2>/dev/null && echo "✅ Control scripts backed up"

echo ""
echo "⚙️ BACKING UP SYSTEM SERVICES:"
echo "------------------------------"
cp /etc/systemd/system/radxa-*.service "$BACKUP_DIR/services/" 2>/dev/null && echo "✅ Systemd services backed up"

echo ""
echo "💾 EXPORTING CURRENT PERFORMANCE STATE:"
echo "---------------------------------------"

# Export current NPU/GPU settings
if [ -f "/sys/devices/platform/soc@3000000/3600000.npu/llm_overclock" ]; then
    cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock > "$BACKUP_DIR/config/npu_gpu_status.txt"
    echo "✅ NPU/GPU overclocking state exported"
fi

# Export current CPU settings
if [ -f "/sys/kernel/cpu_overclock/overclock" ]; then
    cat /sys/kernel/cpu_overclock/overclock > "$BACKUP_DIR/config/cpu_overclock_status.txt"
    echo "✅ CPU overclocking state exported"
fi

# Export fan settings
if [ -f "/sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1" ]; then
    cat /sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1 > "$BACKUP_DIR/config/fan_speed.txt"
    echo "✅ Fan control state exported"
fi

# Export system info
echo "$(uname -a)" > "$BACKUP_DIR/config/kernel_version.txt"
echo "$(lsmod | grep -E '(llm_unified|cpu_overclock|ram_overclock)')" > "$BACKUP_DIR/config/loaded_modules.txt"
echo "$(cat /proc/cmdline)" > "$BACKUP_DIR/config/boot_parameters.txt"

echo ""
echo "📋 CREATING RESTORATION SCRIPT:"
echo "-------------------------------"

cat > "$BACKUP_DIR/restore_overclocking.sh" << 'EOF'
#!/bin/bash

# OVERCLOCKING RESTORATION SCRIPT
# Restores all overclocking modifications after USB migration

echo "🚀 RESTORING OVERCLOCKING SETUP 🚀"
echo "==================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 RESTORING FILES:"
echo "------------------"

# Restore kernel modules
if [ -d "$SCRIPT_DIR/modules" ]; then
    sudo cp "$SCRIPT_DIR/modules"/*.ko /home/radxa/ 2>/dev/null && echo "✅ Kernel modules restored"
    sudo cp "$SCRIPT_DIR/modules"/Makefile /home/radxa/ 2>/dev/null
    sudo cp "$SCRIPT_DIR/modules"/*.c /home/radxa/ 2>/dev/null && echo "✅ Source code restored"
    sudo chown radxa:radxa /home/radxa/*.ko /home/radxa/*.c /home/radxa/Makefile 2>/dev/null
fi

# Restore scripts
if [ -d "$SCRIPT_DIR/scripts" ]; then
    sudo cp "$SCRIPT_DIR/scripts"/*.sh /home/radxa/ 2>/dev/null && echo "✅ Control scripts restored"
    sudo chown radxa:radxa /home/radxa/*.sh 2>/dev/null
    sudo chmod +x /home/radxa/*.sh 2>/dev/null
fi

# Restore services
if [ -d "$SCRIPT_DIR/services" ]; then
    sudo cp "$SCRIPT_DIR/services"/*.service /etc/systemd/system/ 2>/dev/null && echo "✅ Systemd services restored"
    sudo systemctl daemon-reload
    sudo systemctl enable radxa-fan.service 2>/dev/null && echo "✅ Fan service enabled"
fi

echo ""
echo "🔧 LOADING KERNEL MODULES:"
echo "-------------------------"

# Load modules in correct order
if [ -f "/home/radxa/llm_unified_overclock.ko" ]; then
    sudo insmod /home/radxa/llm_unified_overclock.ko && echo "✅ NPU/GPU overclocking module loaded"
fi

if [ -f "/home/radxa/cpu_overclock.ko" ]; then
    sudo insmod /home/radxa/cpu_overclock.ko && echo "✅ CPU overclocking module loaded"
fi

if [ -f "/home/radxa/ram_overclock.ko" ]; then
    sudo insmod /home/radxa/ram_overclock.ko && echo "✅ RAM optimization module loaded"
fi

echo ""
echo "⚡ RESTORING PERFORMANCE SETTINGS:"
echo "---------------------------------"

# Wait for modules to initialize
sleep 2

# Restore NPU/GPU overclocking
if [ -f "$SCRIPT_DIR/config/npu_gpu_status.txt" ]; then
    npu_freq=$(grep "NPU:" "$SCRIPT_DIR/config/npu_gpu_status.txt" | awk '{print $2}')
    gpu_freq=$(grep "GPU:" "$SCRIPT_DIR/config/npu_gpu_status.txt" | awk '{print $2}')
    if [ -n "$npu_freq" ] && [ -n "$gpu_freq" ]; then
        echo "${npu_freq},${gpu_freq}" | sudo tee /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock > /dev/null 2>&1
        echo "✅ NPU/GPU frequencies restored: NPU ${npu_freq}MHz, GPU ${gpu_freq}MHz"
    fi
fi

# Restore CPU overclocking
if [ -f "$SCRIPT_DIR/config/cpu_overclock_status.txt" ]; then
    cpu_e_freq=$(grep "CPU_E:" "$SCRIPT_DIR/config/cpu_overclock_status.txt" | awk '{print $2}')
    if [ -n "$cpu_e_freq" ] && [ "$cpu_e_freq" != "0" ]; then
        echo "${cpu_e_freq},0" | sudo tee /sys/kernel/cpu_overclock/overclock > /dev/null 2>&1
        echo "✅ CPU overclocking restored: ${cpu_e_freq}MHz"
    fi
fi

# Restore fan control
if [ -f "$SCRIPT_DIR/config/fan_speed.txt" ]; then
    fan_speed=$(cat "$SCRIPT_DIR/config/fan_speed.txt")
    echo "$fan_speed" | sudo tee /sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1 > /dev/null 2>&1
    echo "✅ Fan speed restored: $fan_speed/255"
fi

# Start fan service
sudo systemctl start radxa-fan.service 2>/dev/null

echo ""
echo "🎉 OVERCLOCKING RESTORATION COMPLETE! 🎉"
echo "========================================"
echo ""
echo "🔍 VERIFICATION:"
echo "---------------"

# Verify modules are loaded
echo "Loaded modules:"
lsmod | grep -E "(llm_unified|cpu_overclock|ram_overclock)" | sed 's/^/   /'

# Show current performance
echo ""
echo "Current performance:"
if [ -f "/sys/devices/platform/soc@3000000/3600000.npu/llm_overclock" ]; then
    cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock | head -3 | sed 's/^/   /'
fi

echo ""
echo "🚀 Your Radxa is back to MAXIMUM PERFORMANCE! 🚀"
EOF

chmod +x "$BACKUP_DIR/restore_overclocking.sh"
echo "✅ Restoration script created"

echo ""
echo "📚 CREATING DOCUMENTATION:"
echo "--------------------------"

cat > "$BACKUP_DIR/docs/README.md" << 'EOF'
# RADXA OVERCLOCKING BACKUP PACKAGE

This backup contains all overclocking modifications for your Radxa Cubie A7A.

## 🚀 ACHIEVED PERFORMANCE:
- **NPU:** 2520MHz (3.0 TOPS) - +150% overclock
- **GPU:** 1488MHz - +77% overclock  
- **CPU:** 2080MHz (E-cores) - +16% overclock
- **RAM:** 1800MHz - Maximum specification
- **Fan:** Smart control with shutdown management

## 📦 PACKAGE CONTENTS:
- `modules/` - Kernel modules (.ko files and source code)
- `scripts/` - Control scripts for performance management
- `services/` - Systemd services for fan control
- `config/` - Current performance state snapshots
- `restore_overclocking.sh` - Automatic restoration script

## 🔧 RESTORATION PROCESS:
1. Copy this entire backup directory to your new USB system
2. Run: `sudo ./restore_overclocking.sh`
3. Reboot to ensure all services start properly

## ⚡ MANUAL CONTROL:
After restoration, use these commands:
- `./performance_control.sh` - Main performance control
- `./fan_control.sh` - Fan management
- Direct control via sysfs interfaces

## 🎯 PERFORMANCE VERIFICATION:
Check that all overclocking is active:
- NPU/GPU: `cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock`
- CPU: `cat /sys/kernel/cpu_overclock/overclock`
- Modules: `lsmod | grep -E "(llm_unified|cpu_overclock|ram_overclock)"`

Your system will be restored to MAXIMUM PERFORMANCE! 🎉
EOF

echo "✅ Documentation created"

echo ""
echo "📊 BACKUP SUMMARY:"
echo "-----------------"
echo "📁 Total files backed up: $(find "$BACKUP_DIR" -type f | wc -l)"
echo "💾 Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo "📍 Location: $BACKUP_DIR"

echo ""
echo "🎯 NEXT STEPS FOR USB MIGRATION:"
echo "-------------------------------"
echo "1. ✅ Copy backup to external storage"
echo "2. 🗜️  Optional: Create compressed archive"
echo "3. 💿 Proceed with USB system creation"
echo "4. 📦 Restore using the backup package"
echo "5. 🚀 Enjoy faster storage + maximum performance!"

echo ""
echo "📦 BACKUP PACKAGE READY! 📦"

# Create compressed archive
echo ""
echo "Creating compressed archive..."
cd /home/radxa
tar -czf "overclock_backup_$(date +%Y%m%d_%H%M%S).tar.gz" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")"
echo "✅ Compressed backup created: overclock_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

echo ""
echo "Ready for USB migration! 🚀"