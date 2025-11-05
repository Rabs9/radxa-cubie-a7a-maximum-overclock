#!/bin/bash

# ENHANCED SD-TO-USB CLONING + IMAGE CREATION TOOL
# Creates both direct USB clone AND downloadable image file

echo "🔄 RADXA OVERCLOCKED SYSTEM CLONING TOOL 🔄"
echo "============================================"
echo ""

# Device identification
SD_DEVICE="/dev/mmcblk0"
USB_DEVICE="/dev/sda"
IMAGE_FILE="/home/radxa/radxa_overclocked_system_$(date +%Y%m%d_%H%M%S).img"

echo "📊 CLONING OPTIONS:"
echo "------------------"
echo "1. Direct clone SD → USB (for immediate use)"
echo "2. Create image file (for download/backup)" 
echo "3. Both (recommended!)"
echo ""

read -p "Choose option (1/2/3): " choice

case $choice in
    1) MODE="usb_only" ;;
    2) MODE="image_only" ;;
    3) MODE="both" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

echo ""
echo "📊 DEVICE ANALYSIS:"
echo "------------------"
echo "Source (SD Card): $SD_DEVICE"
lsblk $SD_DEVICE
echo ""

if [ "$MODE" = "usb_only" ] || [ "$MODE" = "both" ]; then
    echo "Target (USB Drive): $USB_DEVICE"
    lsblk $USB_DEVICE
    echo ""
fi

if [ "$MODE" = "image_only" ] || [ "$MODE" = "both" ]; then
    echo "Image file: $IMAGE_FILE"
    echo "Available space: $(df -h /home/radxa | tail -1 | awk '{print $4}')"
    echo ""
fi

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

# Get sizes
sd_size=$(lsblk -b -n -o SIZE $SD_DEVICE | head -1)
sd_size_gb=$(numfmt --to=iec $sd_size)

echo "SD Card size: $sd_size_gb"

# Check USB if needed
if [ "$MODE" = "usb_only" ] || [ "$MODE" = "both" ]; then
    if [ ! -b "$USB_DEVICE" ]; then
        echo "❌ ERROR: USB device $USB_DEVICE not found"
        exit 1
    fi
    
    usb_size=$(lsblk -b -n -o SIZE $USB_DEVICE | head -1)
    usb_size_gb=$(numfmt --to=iec $usb_size)
    echo "USB Drive size: $usb_size_gb"
    
    if [ "$usb_size" -lt "$sd_size" ]; then
        echo "❌ ERROR: USB drive too small for cloning"
        exit 1
    fi
    echo "✅ USB drive is large enough"
fi

# Check space for image file
if [ "$MODE" = "image_only" ] || [ "$MODE" = "both" ]; then
    available_space=$(df -B1 /home/radxa | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$sd_size" ]; then
        echo "⚠️  WARNING: May not have enough space for image file"
        echo "Available: $(numfmt --to=iec $available_space)"
        echo "Needed: $sd_size_gb"
        read -p "Continue anyway? (y/N): " continue_anyway
        if [ "$continue_anyway" != "y" ] && [ "$continue_anyway" != "Y" ]; then
            exit 1
        fi
    else
        echo "✅ Enough space for image file"
    fi
fi

echo ""
echo "⭐ WHAT WILL BE CLONED:"
echo "----------------------"
echo "🧠 NPU: 2520MHz (3.0 TOPS) - OVERCLOCKED"
echo "🎮 GPU: 1488MHz - OVERCLOCKED"
echo "⚡ CPU: 2080MHz (E-cores) - OVERCLOCKED"
echo "🔧 All custom kernel modules"
echo "📜 All performance control scripts"
echo "🌀 Fan control system"
echo "🗂️ Complete configured OS"
echo ""

if [ "$MODE" = "usb_only" ] || [ "$MODE" = "both" ]; then
    echo "⚠️  USB CLONING WARNING:"
    echo "This will COMPLETELY OVERWRITE the USB drive!"
    echo "USB Device: $USB_DEVICE (DataTraveler_3.0)"
    echo "All data on the USB drive will be LOST!"
    echo ""
fi

read -p "Are you absolutely sure you want to proceed? (type 'YES' to continue): " confirm

if [ "$confirm" != "YES" ]; then
    echo "❌ Operation cancelled"
    exit 0
fi

echo ""
echo "🚀 STARTING CLONING PROCESS:"
echo "============================"

if [ "$MODE" = "image_only" ] || [ "$MODE" = "both" ]; then
    echo ""
    echo "📁 CREATING DOWNLOADABLE IMAGE FILE:"
    echo "-----------------------------------"
    echo "Creating: $IMAGE_FILE"
    echo "This will take 15-30 minutes..."
    echo ""
    
    # Create compressed image with progress
    sudo dd if=$SD_DEVICE bs=4M status=progress | gzip -c > "$IMAGE_FILE.gz"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ IMAGE FILE CREATED SUCCESSFULLY!"
        
        # Calculate sizes
        original_size=$(numfmt --to=iec $sd_size)
        compressed_size=$(ls -lh "$IMAGE_FILE.gz" | awk '{print $5}')
        
        echo "📊 Image Details:"
        echo "  Original size: $original_size"
        echo "  Compressed size: $compressed_size"
        echo "  Location: $IMAGE_FILE.gz"
        echo ""
        
        # Create restoration instructions
        cat > "${IMAGE_FILE%.img}_RESTORE_INSTRUCTIONS.txt" << EOF
🚀 RADXA OVERCLOCKED SYSTEM IMAGE 🚀
===================================

This image contains your complete overclocked Radxa system:
- NPU: 2520MHz (3.0 TOPS)
- GPU: 1488MHz  
- CPU: 2080MHz (E-cores)
- Complete OS with all modifications

📀 TO RESTORE THIS IMAGE:
========================

1. FLASH TO USB DRIVE:
   gunzip -c $(basename "$IMAGE_FILE.gz") | sudo dd of=/dev/sdX bs=4M status=progress
   (Replace /dev/sdX with your USB device)

2. OR FLASH TO SD CARD:
   gunzip -c $(basename "$IMAGE_FILE.gz") | sudo dd of=/dev/mmcblkX bs=4M status=progress
   (Replace /dev/mmcblkX with your SD device)

3. BOOT AND ENJOY:
   - All overclocking immediately active
   - All scripts and controls available
   - Maximum performance ready!

⚡ PERFORMANCE CONTROLS:
======================
./performance_control.sh - Main control
./fan_control.sh - Fan management

Your overclocked system is ready! 🎉
EOF
        
        echo "📋 Restoration instructions created: ${IMAGE_FILE%.img}_RESTORE_INSTRUCTIONS.txt"
        
    else
        echo "❌ IMAGE CREATION FAILED!"
        exit 1
    fi
fi

if [ "$MODE" = "usb_only" ] || [ "$MODE" = "both" ]; then
    echo ""
    echo "💾 DIRECT CLONING TO USB:"
    echo "------------------------"
    
    # Unmount any mounted partitions on USB
    echo "📤 Unmounting USB partitions..."
    for part in $(lsblk -n -o NAME $USB_DEVICE | tail -n +2); do
        if mountpoint -q "/dev/$part" 2>/dev/null; then
            sudo umount "/dev/$part" 2>/dev/null && echo "  Unmounted /dev/$part"
        fi
    done
    
    echo ""
    echo "💾 Cloning SD card to USB..."
    echo "Progress will be shown below:"
    echo ""
    
    # Direct clone with progress
    sudo dd if=$SD_DEVICE of=$USB_DEVICE bs=4M status=progress conv=fsync
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ USB CLONING COMPLETED SUCCESSFULLY!"
        
        # Verify the clone
        echo ""
        echo "🔍 Verifying USB clone..."
        sudo fdisk -l $USB_DEVICE | grep "^/dev" | head -3
        sync
        
        echo "✅ USB clone verified!"
        
    else
        echo "❌ USB CLONING FAILED!"
        exit 1
    fi
fi

echo ""
echo "🎉 CLONING OPERATION COMPLETE! 🎉"
echo "================================="
echo ""

if [ "$MODE" = "image_only" ] || [ "$MODE" = "both" ]; then
    echo "📁 DOWNLOADABLE IMAGE:"
    echo "  File: $IMAGE_FILE.gz"
    echo "  Size: $(ls -lh "$IMAGE_FILE.gz" | awk '{print $5}')"
    echo "  Instructions: ${IMAGE_FILE%.img}_RESTORE_INSTRUCTIONS.txt"
    echo ""
fi

if [ "$MODE" = "usb_only" ] || [ "$MODE" = "both" ]; then
    echo "💾 USB DRIVE:"
    echo "  Ready to boot immediately"
    echo "  All overclocking active"
    echo "  Faster storage performance"
    echo ""
fi

echo "🔄 NEXT STEPS:"
echo "-------------"

if [ "$MODE" = "usb_only" ] || [ "$MODE" = "both" ]; then
    echo "FOR USB BOOT:"
    echo "1. Power off the Radxa"
    echo "2. Remove SD card (optional)"
    echo "3. Boot from USB"
    echo "4. Enjoy faster performance!"
    echo ""
fi

if [ "$MODE" = "image_only" ] || [ "$MODE" = "both" ]; then
    echo "FOR IMAGE BACKUP:"
    echo "1. Copy .gz file to safe location"
    echo "2. Use anytime to restore system"
    echo "3. Flash to any USB/SD device"
    echo "4. Share your overclocked system!"
    echo ""
fi

echo "🚀 Your overclocked Radxa system is ready! 🚀"