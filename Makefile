# Makefile for Radxa Maximum Overclocking Project
# Builds all kernel modules for maximum performance

obj-m += llm_unified_overclock.o
obj-m += cpu_overclock.o
obj-m += ram_overclock.o

KERNEL_DIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
SRC_DIR := $(PWD)/src

all:
make -C $(KERNEL_DIR) M=$(SRC_DIR) modules
cp $(SRC_DIR)/*.ko .

clean:
make -C $(KERNEL_DIR) M=$(SRC_DIR) clean
rm -f *.ko

install: all
sudo insmod llm_unified_overclock.ko
sudo insmod cpu_overclock.ko
sudo insmod ram_overclock.ko
@echo "All overclocking modules loaded successfully!"

uninstall:
sudo rmmod ram_overclock 2>/dev/null || true
sudo rmmod cpu_overclock 2>/dev/null || true
sudo rmmod llm_unified_overclock 2>/dev/null || true
@echo "All overclocking modules unloaded"

status:
@echo "=== LOADED MODULES ==="
@lsmod | grep -E "(llm_unified|cpu_overclock|ram_overclock)" || echo "No overclocking modules loaded"
@echo ""
@echo "=== NPU/GPU STATUS ==="
@cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock 2>/dev/null || echo "NPU/GPU overclock not active"
@echo ""
@echo "=== CPU STATUS ==="
@cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | head -4 || echo "CPU frequency info not available"

help:
@echo "Radxa Maximum Overclocking Project"
@echo "=================================="
@echo "Usage:"
@echo "  make        - Compile all modules"
@echo "  make install - Load all modules"
@echo "  make uninstall - Unload all modules" 
@echo "  make status - Show current overclocking status"
@echo "  make clean  - Clean build files"
@echo ""
@echo "Performance Control:"
@echo "  ./scripts/performance_control.sh - Main control interface"
@echo "  ./scripts/fan_control.sh - Thermal management"
@echo ""
@echo "Maximum Settings:"
@echo "  NPU: 2520MHz (3.0 TOPS)"
@echo "  GPU: 1488MHz (+77%)"
@echo "  CPU: 2080MHz (+16%)"

.PHONY: all clean install uninstall status help
