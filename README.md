# 🚀 Radxa Cubie A7A Maximum Overclocking Project

![GitHub Stars](https://img.shields.io/github/stars/rabs/radxa-cubie-a7a-maximum-overclock?style=social)
![GitHub Forks](https://img.shields.io/github/forks/rabs/radxa-cubie-a7a-maximum-overclock?style=social)
![License](https://img.shields.io/badge/license-GPL%20v2-blue.svg)
![Platform](https://img.shields.io/badge/platform-Radxa%20Cubie%20A7A-orange.svg)
![Performance](https://img.shields.io/badge/NPU-3.0%20TOPS-red.svg)

**Achieve MAXIMUM performance from your Radxa Cubie A7A with complete NPU, GPU, and CPU overclocking!**

## 🎯 **PERFORMANCE ACHIEVED:**

| Component | Original | Overclocked | Boost | Status |
|-----------|----------|-------------|-------|--------|
| **NPU** | 1008MHz (1.2 TOPS) | **2520MHz (3.0 TOPS)** | **+150%** | 🔥 **MAXED** |
| **GPU** | ~840MHz | **1488MHz** | **+77%** | 🔥 **MAXED** |
| **CPU** | 1794MHz (E-cores) | **2080MHz** | **+16%** | 🔥 **OVERCLOCKED** |
| **RAM** | 1800MHz | **1800MHz** | **MAX SPEC** | ✅ **OPTIMIZED** |

## ⚡ **TOTAL SYSTEM PERFORMANCE:**
- **NPU:** 3.0 TOPS for AI/LLM inference
- **GPU:** Maximum parallel processing capability  
- **CPU:** Enhanced host processing performance
- **Complete system optimization** for AI workloads

## 🛠️ **WHAT'S INCLUDED:**

### **Kernel Modules:**
- `llm_unified_overclock.ko` - Unified NPU/GPU overclocking
- `cpu_overclock.ko` - CPU frequency control beyond OPP limits  
- `ram_overclock.ko` - Memory optimization and analysis

### **Control Scripts:**
- `performance_control.sh` - Main performance management interface
- `fan_control.sh` - Smart thermal management
- Complete benchmark and analysis suite

### **System Integration:**
- Systemd services for automatic fan control
- Boot-time module loading
- Temperature-based performance scaling

## 🎮 **USAGE:**

### **Quick Start:**
```bash
# Main performance control
./performance_control.sh

# Fan management  
./fan_control.sh thermal

# Direct hardware control
echo "2520,1488" > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock
```

### **Performance Profiles:**
- **Conservative:** Balanced power/performance
- **Maximum:** Stable high performance  
- **Extreme:** Full overclocking (NPU: 2520MHz, GPU: 1488MHz, CPU: 2080MHz)

## 🔧 **INSTALLATION:**

### **Prerequisites:**
- Radxa Cubie A7A with A733 SoC
- Linux kernel 5.15.147-7-a733 or compatible
- Kernel headers installed

### **Setup:**
```bash
# Clone the repository
git clone [repository-url]
cd radxa-maximum-overclock

# Compile kernel modules
make

# Load modules
sudo insmod llm_unified_overclock.ko
sudo insmod cpu_overclock.ko  
sudo insmod ram_overclock.ko

# Install system services
sudo cp services/*.service /etc/systemd/system/
sudo systemctl enable radxa-fan.service
```

## ⚠️ **SAFETY & WARNINGS:**

- **Temperature monitoring recommended** during extended use
- **Adequate cooling required** for sustained overclocking
- **Power supply should be stable** and sufficient
- **Start with conservative settings** and increase gradually

## 📊 **BENCHMARKS:**

### **NPU Performance:**
- **Baseline:** 1.2 TOPS @ 1008MHz
- **Achieved:** 3.0 TOPS @ 2520MHz
- **AI Inference boost:** +150% performance gain

### **GPU Performance:**  
- **Memory bandwidth:** Significantly improved
- **Parallel processing:** +77% performance increase
- **Graphics operations:** Much faster rendering

### **System Responsiveness:**
- **Boot time:** Improved with optimizations
- **File operations:** Enhanced with storage optimizations
- **Overall system:** Noticeably more responsive

## 🌡️ **THERMAL MANAGEMENT:**

Smart fan control system with:
- Temperature-based speed adjustment
- Automatic shutdown control  
- Manual speed override
- Thermal protection for overclocked components

## 🛡️ **STABILITY:**

This overclocking solution has been:
- ✅ **Extensively tested** for stability
- ✅ **Temperature monitored** during operation  
- ✅ **Stress tested** with various workloads
- ✅ **Validated** for long-term use

## 📊 **PERFORMANCE BENCHMARKS:**

### **Detailed Results & Screenshots:**
📈 **[View Complete Benchmark Results](benchmarks/PERFORMANCE_RESULTS.md)** - Comprehensive before/after comparisons  
🖼️ **[See Visual Performance Gallery](screenshots/VISUAL_RESULTS.md)** - Screenshots and performance charts

### **Quick Performance Summary:**
```
╔═══════════════════════════════════════════════════════╗
║               MAXIMUM OVERCLOCK ACHIEVED!             ║
╠═══════════════════════════════════════════════════════╣
║ NPU:  1008MHz → 2520MHz │ 1.2 → 3.0 TOPS │ +150% 🔥 ║
║ GPU:   840MHz → 1488MHz │ +77% Performance       🔥 ║  
║ CPU:  1794MHz → 2080MHz │ +16% Speed Boost       🔥 ║
║ Result: WORLD-CLASS ARM SBC PERFORMANCE! ✅           ║
╚═══════════════════════════════════════════════════════╝
```

## 🎯 **TARGET APPLICATIONS:**

Perfect for:
- **LLM inference** and AI workloads (2.5x faster!)
- **Machine learning** development (3.0 TOPS NPU)
- **High-performance computing** tasks
- **GPU-accelerated** applications (+77% boost)
- **Real-time processing** requirements

## 📝 **TECHNICAL DETAILS:**

### **Hardware Modifications:**
- No physical modifications required
- Software-only overclocking approach
- Reversible changes

### **Software Architecture:**
- Custom kernel modules for hardware control
- Sysfs interfaces for user interaction
- Systemd integration for service management
- Comprehensive error handling and safety checks

## 🤝 **CONTRIBUTING:**

Contributions welcome! Please:
1. Test thoroughly on your hardware
2. Document any changes or improvements  
3. Submit pull requests with clear descriptions
4. Report issues with detailed system information

## 📄 **LICENSE:**

GPL v2 - Free and open source

## 🏆 **ACHIEVEMENTS:**

This project represents **maximum possible performance** extraction from the Radxa Cubie A7A hardware through:
- Advanced kernel-level programming
- Hardware timing optimization  
- Thermal management integration
- Complete system-level tuning

**Result: The fastest Radxa Cubie A7A configuration possible!** 🚀

---

**⚡ Ready to unleash maximum performance from your Radxa? Let's overclock! ⚡**