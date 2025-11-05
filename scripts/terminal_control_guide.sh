#!/bin/bash

# TERMINAL CONTROL SYSTEM GUIDE
# Complete guide to using the overclocking controls

echo "📖 RADXA PERFORMANCE CONTROL - TERMINAL GUIDE 📖"
echo "=================================================="
echo ""

echo "🎯 CONTROL METHODS:"
echo "-------------------"
echo ""

echo "METHOD 1: Interactive Menu System"
echo "  Command: ./performance_control.sh"
echo "  Features:"
echo "    • User-friendly menu interface"
echo "    • Real-time status display"
echo "    • Pre-configured performance profiles"
echo "    • Automatic system monitoring"
echo ""

echo "METHOD 2: Direct GPU/NPU Control"
echo "  Location: /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock"
echo "  Usage Examples:"
echo "    • Maximum performance:    echo '2520,1488' | sudo tee llm_overclock"
echo "    • Conservative mode:      echo 'conservative' | sudo tee llm_overclock"
echo "    • Custom frequencies:     echo '2000,1200' | sudo tee llm_overclock"
echo "    • Check current status:   cat llm_overclock"
echo ""

echo "METHOD 3: Direct CPU Overclocking"
echo "  Location: /sys/kernel/cpu_overclock/overclock"
echo "  Usage Examples:"
echo "    • Overclock E-cores:      echo '2080,0' | sudo tee overclock"
echo "    • Maximum safe:           echo '1794,2002' | sudo tee overclock"
echo "    • Extreme overclocking:   echo '2100,2400' | sudo tee overclock"
echo "    • Check current status:   cat overclock"
echo ""

echo "🔍 MONITORING COMMANDS:"
echo "-----------------------"
echo ""

echo "Real-time Performance Monitoring:"
echo "  watch -n 1 'cat /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock'"
echo ""

echo "CPU Frequency Monitoring:"
echo "  watch -n 1 'for i in {0..7}; do echo \"CPU\$i: \$(cat /sys/devices/system/cpu/cpu\$i/cpufreq/scaling_cur_freq | awk '{print \$1/1000}')MHz\"; done'"
echo ""

echo "Temperature Monitoring:"
echo "  watch -n 1 'cat /sys/class/thermal/thermal_zone*/temp | awk \"{print \\\$1/1000 \\\"°C\\\"}\"'"
echo ""

echo "System Load Monitoring:"
echo "  watch -n 1 'uptime && free -h'"
echo ""

echo "⚡ PERFORMANCE PROFILES EXPLAINED:"
echo "----------------------------------"
echo ""

echo "CONSERVATIVE Profile:"
echo "  • NPU: 1488MHz (1.7 TOPS)"
echo "  • GPU: 800MHz"
echo "  • CPU: Standard frequencies"
echo "  • Use case: Battery saving, light workloads"
echo ""

echo "MAXIMUM Profile:"
echo "  • NPU: 2520MHz (3.0 TOPS)"
echo "  • GPU: 1488MHz"
echo "  • CPU: Standard frequencies"
echo "  • Use case: Maximum stable performance"
echo ""

echo "EXTREME Profile:"
echo "  • NPU: 2520MHz (3.0 TOPS)"
echo "  • GPU: 1488MHz"
echo "  • CPU: 2080MHz (overclocked)"
echo "  • Use case: Maximum performance, short bursts"
echo ""

echo "🛠️ PRACTICAL EXAMPLES:"
echo "----------------------"
echo ""

echo "Example 1: Quick Performance Boost for LLM Inference"
echo "  sudo sh -c 'echo maximum > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock'"
echo ""

echo "Example 2: Full System Overclocking"
echo "  sudo sh -c 'echo 2520,1488 > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock'"
echo "  sudo sh -c 'echo 2080,0 > /sys/kernel/cpu_overclock/overclock'"
echo ""

echo "Example 3: Battery Saving Mode"
echo "  sudo sh -c 'echo conservative > /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock'"
echo ""

echo "Example 4: Create Custom Profile Script"
echo "  echo '#!/bin/bash' > my_profile.sh"
echo "  echo 'echo 2200,1200 | sudo tee /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock' >> my_profile.sh"
echo "  echo 'echo 1900,0 | sudo tee /sys/kernel/cpu_overclock/overclock' >> my_profile.sh"
echo "  chmod +x my_profile.sh"
echo ""

echo "⚠️  SAFETY NOTES:"
echo "----------------"
echo ""

echo "• Always monitor temperatures when overclocking"
echo "• Start with conservative settings and work up"
echo "• The system will fallback to safe frequencies if needed"
echo "• Higher frequencies = higher power consumption"
echo "• Use extreme overclocking for short bursts only"
echo ""

echo "🚀 Ready to control your Radxa's performance! 🚀"
echo ""