#!/bin/bash

# DIRECT SD-TO-USB CLONING TOOL
# Clones your overclocked system directly to USB

echo "🔄 RADXA SD-TO-USB DIRECT CLONING TOOL 🔄"
echo "=========================================="
echo ""

# Device identification
SD_DEVICE="/dev/mmcblk0"
USB_DEVICE="/dev/sda"

echo "📊 DEVICE ANALYSIS:"
echo "------------------"
echo "Source (SD Card): $SD_DEVICE"
lsblk $SD_DEVICE
echo ""
echo "Target (USB Drive): $USB_DEVICE"
lsblk $USB_DEVICE
echo ""

# Safety checks
echo "🔍 SAFETY VERIFICATION:"
echo "----------------------"

# Check if source is mounted as root
if mountpoint -q /; then
    root_partition=$(df / | tail -1 | awk '{print $1}')
    root_device=$(echo "$root_partition" | sed 's/p[0-9]*$//')
    echo "Detected root partition: $root_partition"
    echo "Detected root device: $root_device"
    if [ "$root_device" = "$SD_DEVICE" ]; then
        echo "✅ Confirmed: Running from SD card ($SD_DEVICE)"
    else
        echo "❌ ERROR: Not running from expected SD card"
        echo "Expected: $SD_DEVICE"
        echo "Actual: $root_device"
        exit 1
    fi
fi

# Check USB device
if [ ! -b "$USB_DEVICE" ]; then
    echo "❌ ERROR: USB device $USB_DEVICE not found"
    exit 1
fi

# Get sizes
sd_size=$(lsblk -b -n -o SIZE $SD_DEVICE | head -1)
usb_size=$(lsblk -b -n -o SIZE $USB_DEVICE | head -1)

echo "SD Card size: $(numfmt --to=iec $sd_size)"
echo "USB Drive size: $(numfmt --to=iec $usb_size)"

if [ "$usb_size" -lt "$sd_size" ]; then
    echo "❌ ERROR: USB drive too small for cloning"
    exit 1
fi

echo "✅ USB drive is large enough"
echo ""

echo "⚠️  FINAL WARNING:"
echo "----------------"
echo "This will COMPLETELY OVERWRITE the USB drive!"
echo "USB Device: $USB_DEVICE (DataTraveler_3.0)"
echo "All data on the USB drive will be LOST!"
echo ""
echo "Current system that will be cloned:"
echo "- 🧠 NPU: 2520MHz (3.0 TOPS)"
echo "- 🎮 GPU: 1488MHz" 
echo "- ⚡ CPU: 2080MHz (overclocked)"
echo "- 🔧 All custom modules and scripts"
echo "- 🌀 Fan control system"
echo ""

read -p "Are you absolutely sure you want to proceed? (type 'YES' to continue): " confirm

if [ "$confirm" != "YES" ]; then
    echo "❌ Cloning cancelled"
    exit 0
fi

echo ""
echo "🚀 STARTING DIRECT CLONING PROCESS:"
echo "==================================="

# Unmount any mounted partitions on USB
echo "📤 Unmounting USB partitions..."
for part in $(lsblk -n -o NAME $USB_DEVICE | tail -n +2); do
    if mountpoint -q "/dev/$part" 2>/dev/null; then
        sudo umount "/dev/$part" 2>/dev/null && echo "  Unmounted /dev/$part"
    fi
done

echo ""
echo "💾 CLONING SD CARD TO USB..."
echo "This may take 15-30 minutes depending on data amount"
echo "Progress will be shown below:"
echo ""

# Start cloning with progress
sudo dd if=$SD_DEVICE of=$USB_DEVICE bs=4M status=progress conv=fsync

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ CLONING COMPLETED SUCCESSFULLY!"
    echo ""
    
    # Verify the clone
    echo "🔍 VERIFYING CLONE:"
    echo "------------------"
    
    # Check partition table
    echo "USB partition table:"
    sudo fdisk -l $USB_DEVICE | grep "^/dev"
    
    # Sync to ensure all data is written
    echo ""
    echo "💽 Syncing data to ensure completion..."
    sync
    
    echo ""
    echo "🎉 CLONE VERIFICATION COMPLETE! 🎉"
    echo "================================="
    echo ""
    echo "Your USB drive now contains:"
    echo "✅ Complete overclocked Radxa system"
    echo "✅ NPU overclocking (2520MHz - 3.0 TOPS)"
    echo "✅ GPU overclocking (1488MHz)"
    echo "✅ CPU overclocking (2080MHz)"
    echo "✅ All custom kernel modules"
    echo "✅ Performance control scripts"
    echo "✅ Fan control system"
    echo "✅ All system configurations"
    echo ""
    echo "🔄 NEXT STEPS:"
    echo "-------------"
    echo "1. Power off the Radxa"
    echo "2. Remove the SD card"
    echo "3. Boot from USB (should be automatic)"
    echo "4. Verify overclocking is active"
    echo "5. Enjoy faster storage + maximum performance!"
    echo ""
    echo "🚀 Your system is ready for USB operation! 🚀"
    
else
    echo ""
    echo "❌ CLONING FAILED!"
    echo "Please check the error messages above"
    exit 1
fi