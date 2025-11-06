# Kernel Files Documentation

## Directory Structure

### dtb/production/
Production-ready Device Tree Binary files:
- `radxa-a7a-full-optimized.dtb` - **Main production DTB** (NPU 2520MHz, GPU 1488MHz, CPU 2080MHz)
- `radxa-a7a-extended-npu.dtb` - Extended NPU testing configuration

### dtb/testing/
Development and testing DTB files with various optimization attempts

### dts/source/
Device Tree Source files:
- `radxa-cubie-a7a.dts` - Base DTS with all customizations

### kernel-modules/
Custom kernel modules:
- `llm_unified_overclock.ko` - Unified overclocking module  
- `cpu_overclock.ko` - CPU frequency scaling
- `ram_overclock.ko` - Memory overclocking

## Usage

1. Copy DTB to `/boot/`: `sudo cp dtb/production/radxa-a7a-full-optimized.dtb /boot/`
2. Copy modules: `sudo cp kernel-modules/*.ko /lib/modules/$(uname -r)/kernel/drivers/`
3. Update module dependencies: `sudo depmod -a`
4. Load modules: `sudo modprobe llm_unified_overclock cpu_overclock ram_overclock`

## Performance Results
- **NPU**: 2520MHz (from 1680MHz) = +50% = 3.0 TOPS
- **GPU**: 1488MHz (from 840MHz) = +77%  
- **CPU**: 2080MHz (from 1800MHz) = +16%
