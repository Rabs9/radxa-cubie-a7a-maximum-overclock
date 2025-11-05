# Installation Guide

## Prerequisites

1. **Hardware Requirements:**
   - Radxa Cubie A7A with Allwinner A733 SoC
   - Adequate cooling (fan recommended for sustained overclocking)
   - Stable power supply

2. **Software Requirements:**
   - Linux kernel 5.15.147-7-a733 or compatible
   - Kernel headers installed
   - Build essentials (gcc, make)

## Quick Installation

```bash
# 1. Clone the repository
git clone <repository-url>
cd radxa-maximum-overclock

# 2. Build and install modules
make install

# 3. Start performance control
./scripts/performance_control.sh
```

## Manual Installation

### Step 1: Build Kernel Modules
```bash
# Compile all modules
make

# Or build individually
make -C /lib/modules/$(uname -r)/build M=$(pwd)/src modules
```

### Step 2: Load Modules
```bash
# Load overclocking modules
sudo insmod llm_unified_overclock.ko
sudo insmod cpu_overclock.ko  
sudo insmod ram_overclock.ko
```

### Step 3: Install System Services
```bash
# Install fan control service
sudo cp services/radxa-fan.service /etc/systemd/system/
sudo systemctl enable radxa-fan.service
sudo systemctl start radxa-fan.service
```

### Step 4: Set Permissions
```bash
# Make scripts executable
chmod +x scripts/*.sh
```

## Configuration

### Maximum Performance Settings
```bash
# Set maximum overclocking
echo "2520,1488" > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock
echo "2080" > /sys/devices/platform/cpu_overclock/max_freq
```

### Performance Profiles
- **Conservative:** Balanced power/performance
- **High:** Increased performance with good stability
- **Maximum:** Full overclocking capabilities

## Verification

### Check Module Status
```bash
make status
```

### Monitor Performance
```bash
./scripts/performance_summary.sh
```

### Temperature Monitoring
```bash
./scripts/fan_control.sh thermal
```

## Troubleshooting

### Common Issues

1. **Module Loading Fails:**
   - Check kernel version compatibility
   - Ensure kernel headers are installed
   - Verify build completed successfully

2. **Permission Denied:**
   - Run with sudo privileges
   - Check file permissions
   - Ensure user is in appropriate groups

3. **Overheating:**
   - Reduce overclock settings
   - Improve cooling
   - Monitor temperatures

### Recovery

To return to default settings:
```bash
make uninstall
sudo reboot
```

## Performance Verification

After installation, verify your overclocking results:

```bash
# Check NPU frequency
cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock

# Check CPU frequencies  
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Run benchmarks
./scripts/benchmark_suite.sh
```

Expected results:
- **NPU:** 2520MHz (3.0 TOPS)
- **GPU:** 1488MHz 
- **CPU:** 2080MHz on performance cores

## Automatic Startup

To load modules automatically on boot:

```bash
# Add to /etc/modules
echo "llm_unified_overclock" | sudo tee -a /etc/modules
echo "cpu_overclock" | sudo tee -a /etc/modules  
echo "ram_overclock" | sudo tee -a /etc/modules
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review system logs: `dmesg | tail -50`
3. Verify hardware compatibility
4. Ensure proper cooling

Remember: **Start with conservative settings and increase gradually!**