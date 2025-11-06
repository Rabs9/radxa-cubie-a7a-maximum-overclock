# SPI Flash USB Boot Guide

## ⚠️ Important: ARM Boot Architecture

Unlike x86 PCs, ARM single-board computers like the Radxa Cubie A7A don't have BIOS/UEFI. They use **U-Boot bootloader** which must be stored on the boot device or SPI flash.

### Why USB/NVMe Don't Boot Directly:

1. **CPU Boot ROM** → Looks for U-Boot on SD card or SPI flash only
2. **U-Boot** → Can then load kernel from USB/NVMe/eMMC/UFS
3. **No U-Boot = No Boot** → USB alone won't work

## Boot Options Available:

### Option 1: SD Card Boot (Default)
- ✅ Everything on SD card
- ✅ Works out of box
- ❌ Slower than USB/NVMe

### Option 2: Hybrid Boot (Recommended)
- ✅ SD card: Only U-Boot + /boot (~500MB, rarely written)
- ✅ USB/NVMe: Root filesystem (all data, constant R/W)
- ✅ Best of both worlds
- ✅ Safe and reversible

### Option 3: SPI Flash + USB Boot (Advanced)
- ✅ U-Boot in SPI flash chip
- ✅ Boot entirely from USB/NVMe
- ✅ No SD card needed
- ⚠️ Requires flashing SPI (can brick if done wrong)
- ✅ Recoverable with backup

## SPI Flash USB Boot Setup

Your Radxa Cubie A7A has an 8MB SPI flash chip (`/dev/mtd0`) that can store U-Boot permanently.

### Prerequisites:
1. ✅ Full SD card backup created (to USB)
2. ✅ USB drive with system ready
3. ✅ Serial console access (recommended for recovery)

### Flash U-Boot to SPI:

```bash
# Install required tools
sudo apt install -y mtd-utils

# Backup current SPI contents (just in case)
sudo dd if=/dev/mtd0 of=/home/radxa/spi_backup.bin bs=1M

# Flash U-Boot to SPI
sudo dd if=/usr/lib/u-boot/radxa-cubie-a7a/boot0_spinor.bin of=/dev/mtd0 bs=1M
sudo sync

# Verify
sudo md5sum /usr/lib/u-boot/radxa-cubie-a7a/boot0_spinor.bin
sudo dd if=/dev/mtd0 bs=1M count=8 | md5sum
```

### After SPI Flash:
1. Shutdown: `sudo shutdown -h now`
2. Remove SD card
3. Power on → Boots from USB!

## Recovery if Something Goes Wrong:

### Method 1: Restore SD Card Backup
1. Use another computer with Rufus (Windows) or dd (Linux)
2. Write backup USB to SD card
3. Boot from SD card
4. System restored to working state

### Method 2: Re-flash SPI (if you have serial console)
1. Connect serial console cable
2. Interrupt U-Boot at boot
3. Use `fastboot` or `sunxi-fel` to reflash

## Current Status:

- ✅ SD card backup: `/dev/sdb` (32GB USB)
- ✅ System prepared for SPI flash
- ✅ U-Boot binary available: `/usr/lib/u-boot/radxa-cubie-a7a/boot0_spinor.bin`
- ⏳ Ready to flash when you confirm

## Notes:

- **Hybrid boot** is safer and gives 99% of USB performance benefits
- **SPI flash** is the only way to boot without SD card
- **GRUB/UEFI** not available on ARM boards like this
- All overclocking works the same regardless of boot method
