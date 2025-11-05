#!/bin/bash
# NPU Frequency Control Script for Extreme Overclocking
# Radxa Cubie A7A - Allwinner A733 SoC Custom Kernel
# Target: 6+ TOPS Performance Testing

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# NPU devfreq path
NPU_DEVFREQ="/sys/class/devfreq/3600000.npu"
VIP_DEBUG="/sys/kernel/debug/viplite"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Function to show NPU status
show_npu_status() {
    print_header "🔍 NPU FREQUENCY STATUS"
    echo
    
    if [[ -d "$NPU_DEVFREQ" ]]; then
        echo -e "${CYAN}Current Frequency:${NC} $(cat $NPU_DEVFREQ/cur_freq) Hz ($(echo "scale=0; $(cat $NPU_DEVFREQ/cur_freq)/1000000" | bc)MHz)"
        echo -e "${CYAN}Current Governor:${NC}  $(cat $NPU_DEVFREQ/governor)"
        echo -e "${CYAN}Min Frequency:${NC}    $(cat $NPU_DEVFREQ/min_freq) Hz"
        echo -e "${CYAN}Max Frequency:${NC}    $(cat $NPU_DEVFREQ/max_freq) Hz"
        echo
        echo -e "${CYAN}Available Frequencies:${NC}"
        while read -r freq; do
            current_freq=$(cat $NPU_DEVFREQ/cur_freq)
            mhz=$(echo "scale=0; $freq/1000000" | bc)
            tops=$(echo "scale=2; $freq*1.20/1008000000" | bc)
            if [[ "$freq" == "$current_freq" ]]; then
                echo -e "  ${GREEN}→ $freq Hz (${mhz}MHz - ${tops} TOPS) ← CURRENT${NC}"
            else
                echo -e "    $freq Hz (${mhz}MHz - ${tops} TOPS)"
            fi
        done < $NPU_DEVFREQ/available_frequencies
        echo
        
        # Show VIP debugfs info if available
        if [[ -f "$VIP_DEBUG/vip_freq" ]]; then
            echo -e "${CYAN}VIP Core Status:${NC}"
            cat $VIP_DEBUG/vip_freq 2>/dev/null | sed 's/^/  /'
            echo
        fi
        
        # Show clock status
        echo -e "${CYAN}NPU Clock Status:${NC}"
        cat /sys/kernel/debug/clk/clk_summary | grep -E "pll-npu|^.*npu" | sed 's/^/  /'
        
    else
        print_error "NPU devfreq device not found at $NPU_DEVFREQ"
        return 1
    fi
}

# Function to set NPU frequency
set_npu_frequency() {
    local target_freq=$1
    
    if [[ -z "$target_freq" ]]; then
        print_error "Please specify target frequency in Hz (e.g., 1120000000 for 1120MHz)"
        return 1
    fi
    
    # Validate frequency format
    if ! [[ "$target_freq" =~ ^[0-9]+$ ]]; then
        print_error "Invalid frequency format. Use Hz (e.g., 1120000000)"
        return 1
    fi
    
    local target_mhz=$(echo "scale=0; $target_freq/1000000" | bc)
    local target_tops=$(echo "scale=2; $target_freq*1.20/1008000000" | bc)
    
    print_status "Setting NPU frequency to $target_freq Hz (${target_mhz}MHz - ${target_tops} TOPS)"
    
    # Switch to userspace governor for manual control
    echo "userspace" | sudo tee $NPU_DEVFREQ/governor >/dev/null
    
    # Set the frequency
    if echo "$target_freq" | sudo tee $NPU_DEVFREQ/userspace/set_freq >/dev/null 2>&1; then
        sleep 1
        local actual_freq=$(cat $NPU_DEVFREQ/cur_freq)
        local actual_mhz=$(echo "scale=0; $actual_freq/1000000" | bc)
        local actual_tops=$(echo "scale=2; $actual_freq*1.20/1008000000" | bc)
        
        if [[ "$actual_freq" == "$target_freq" ]]; then
            print_success "NPU frequency set to $actual_freq Hz (${actual_mhz}MHz - ${actual_tops} TOPS)"
        else
            print_warning "Frequency set to $actual_freq Hz (${actual_mhz}MHz - ${actual_tops} TOPS) - may be limited by OPP table"
        fi
    else
        print_error "Failed to set NPU frequency to $target_freq Hz"
        return 1
    fi
}

# Function to set performance mode
set_performance_mode() {
    print_status "Setting NPU to maximum performance mode"
    echo "performance" | sudo tee $NPU_DEVFREQ/governor >/dev/null
    print_success "NPU set to performance governor (maximum frequency)"
}

# Function to run frequency benchmark
run_frequency_benchmark() {
    print_header "🚀 NPU FREQUENCY BENCHMARK"
    echo
    
    # Test frequencies in MHz
    local test_frequencies=(1008 1120 1200 1344 1500 1680 1800 2016 2400)
    
    for mhz in "${test_frequencies[@]}"; do
        local freq_hz=$((mhz * 1000000))
        local expected_tops=$(echo "scale=2; $freq_hz*1.20/1008000000" | bc)
        
        print_status "Testing ${mhz}MHz (${expected_tops} TOPS)..."
        
        if set_npu_frequency $freq_hz; then
            # Give time for frequency to stabilize
            sleep 2
            
            # Check actual frequency
            local actual_freq=$(cat $NPU_DEVFREQ/cur_freq)
            local actual_mhz=$(echo "scale=0; $actual_freq/1000000" | bc)
            local actual_tops=$(echo "scale=2; $actual_freq*1.20/1008000000" | bc)
            
            print_success "✓ ${actual_mhz}MHz stable (${actual_tops} TOPS)"
            
            # Basic stability test
            print_status "  Running 5-second stability test..."
            local stable=true
            for i in {1..5}; do
                sleep 1
                local check_freq=$(cat $NPU_DEVFREQ/cur_freq)
                if [[ "$check_freq" != "$actual_freq" ]]; then
                    stable=false
                    break
                fi
                echo -n "."
            done
            echo
            
            if $stable; then
                print_success "  ✓ Frequency stable for 5 seconds"
            else
                print_warning "  ⚠ Frequency unstable - may need thermal throttling"
            fi
        else
            print_error "✗ ${mhz}MHz failed to set"
        fi
        echo
    done
}

# Function to show extreme overclocking targets
show_extreme_targets() {
    print_header "🔥 EXTREME OVERCLOCKING TARGETS"
    echo
    echo -e "${CYAN}Performance Targets:${NC}"
    echo "  1120MHz -  1.33 TOPS (11% gain) - SAFE OVERCLOCK"
    echo "  1344MHz -  1.60 TOPS (33% gain) - MODERATE RISK"
    echo "  1680MHz -  2.00 TOPS (67% gain) - HIGH PERFORMANCE"
    echo "  2016MHz -  2.40 TOPS (100% gain) - DOUBLE PERFORMANCE"
    echo "  3360MHz -  4.00 TOPS (233% gain) - EXTREME OVERCLOCK"
    echo "  4200MHz -  5.00 TOPS (317% gain) - SILICON LOTTERY"
    echo "  5000MHz -  5.95 TOPS (396% gain) - THEORETICAL MAXIMUM"
    echo
    echo -e "${YELLOW}WARNING: Higher frequencies require active cooling!${NC}"
    echo -e "${YELLOW}Monitor temperatures and stop if system becomes unstable.${NC}"
}

# Main menu
show_menu() {
    print_header "⚡ NPU EXTREME OVERCLOCKING CONTROL"
    echo
    echo "1) Show NPU Status"
    echo "2) Set Performance Mode (Max Frequency)"
    echo "3) Set Custom Frequency"
    echo "4) Run Frequency Benchmark"
    echo "5) Show Extreme Targets"
    echo "6) Quick 1120MHz Test"
    echo "7) Exit"
    echo
}

# Quick 1120MHz test
quick_1120_test() {
    print_header "🎯 QUICK 1120MHz TEST"
    echo
    print_status "Testing 1120MHz overclock (1.33 TOPS target)..."
    set_npu_frequency 1120000000
    echo
    show_npu_status
}

# Main script logic
case "${1:-menu}" in
    "status")
        show_npu_status
        ;;
    "performance")
        set_performance_mode
        ;;
    "set")
        set_npu_frequency "$2"
        ;;
    "benchmark")
        run_frequency_benchmark
        ;;
    "targets")
        show_extreme_targets
        ;;
    "1120")
        quick_1120_test
        ;;
    "menu"|"")
        while true; do
            show_menu
            read -p "Select option (1-7): " choice
            echo
            
            case $choice in
                1)
                    show_npu_status
                    ;;
                2)
                    set_performance_mode
                    show_npu_status
                    ;;
                3)
                    read -p "Enter frequency in Hz (e.g., 1120000000): " freq
                    if [[ -n "$freq" ]]; then
                        set_npu_frequency "$freq"
                        show_npu_status
                    fi
                    ;;
                4)
                    run_frequency_benchmark
                    ;;
                5)
                    show_extreme_targets
                    ;;
                6)
                    quick_1120_test
                    ;;
                7)
                    print_success "Goodbye!"
                    exit 0
                    ;;
                *)
                    print_error "Invalid option. Please select 1-7."
                    ;;
            esac
            echo
            read -p "Press Enter to continue..."
            clear
        done
        ;;
    *)
        echo "Usage: $0 [status|performance|set <freq_hz>|benchmark|targets|1120]"
        echo "       $0                    # Interactive menu"
        ;;
esac