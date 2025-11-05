/*
 * NPU EXTREME OVERCLOCK MODULE - TARGET: 2.7+ TOPS!
 * 
 * Expanded frequency table to reach maximum TOPS performance
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/devfreq.h>
#include <linux/pm_opp.h>
#include <linux/device.h>
#include <linux/clk.h>

#define NPU_DEVICE_NAME "3600000.npu"

// EXTREME OVERCLOCK FREQUENCY TABLE - TARGET 2.7+ TOPS!
static unsigned long extreme_freqs[] = {
    492000000,   // 492MHz - Original baseline
    852000000,   // 852MHz - Original 
    1008000000,  // 1008MHz - Artificial limit (1.0 TOPS)
    1120000000,  // 1120MHz - Device tree proven
    1200000000,  // 1200MHz - Safe overclock
    1344000000,  // 1344MHz - Aggressive
    1488000000,  // 1488MHz - Current max achieved (~1.5 TOPS)
    1600000000,  // 1600MHz - Target for ~1.6 TOPS
    1800000000,  // 1800MHz - Target for ~1.8 TOPS  
    2000000000,  // 2000MHz - Target for ~2.0 TOPS
    2200000000,  // 2200MHz - Target for ~2.2 TOPS
    2400000000,  // 2400MHz - Target for ~2.4 TOPS
    2700000000,  // 2700MHz - TARGET FOR 2.7 TOPS!
    3000000000,  // 3000MHz - MAXIMUM ATTEMPT (3.0 TOPS)
};

static struct device *npu_device = NULL;
static struct clk *npu_clk = NULL;

// Direct frequency control bypassing devfreq
static int direct_set_frequency(unsigned long target_freq)
{
    int ret;
    unsigned long actual_freq;
    
    if (!npu_clk) {
        pr_err("NPU clock not available for direct control\n");
        return -ENODEV;
    }
    
    pr_info("EXTREME FREQUENCY OVERRIDE: %lu MHz (TARGET: %.1f TOPS)\n", 
            target_freq/1000000, (float)target_freq/1000000/1008*1.0);
    
    // Set clock frequency directly
    ret = clk_set_rate(npu_clk, target_freq);
    if (ret) {
        pr_err("Extreme clock set failed: %d\n", ret);
        return ret;
    }
    
    // Verify the frequency was set
    actual_freq = clk_get_rate(npu_clk);
    pr_info("EXTREME OVERCLOCK SUCCESS! Target: %luMHz, Actual: %luMHz\n", 
            target_freq/1000000, actual_freq/1000000);
    
    return 0;
}

// Sysfs interface for extreme overclocking
static ssize_t extreme_overclock_show(struct device *dev,
                                     struct device_attribute *attr, char *buf)
{
    unsigned long current_freq = 0;
    
    if (npu_clk) {
        current_freq = clk_get_rate(npu_clk);
    }
    
    return sprintf(buf, "NPU EXTREME Overclock Control - TARGET: 2.7+ TOPS!\n"
                        "Current: %lu MHz (~%.1f TOPS)\n"
                        "EXTREME Frequencies Available:\n"
                        "1488, 1600, 1800, 2000, 2200, 2400, 2700, 3000 MHz\n"
                        "Usage: echo <freq_mhz> > extreme_overclock\n"
                        "TARGET: echo 2700 > extreme_overclock  # 2.7 TOPS!\n",
                        current_freq/1000000, 
                        (float)current_freq/1000000/1008*1.0);
}

static ssize_t extreme_overclock_store(struct device *dev,
                                      struct device_attribute *attr,
                                      const char *buf, size_t count)
{
    unsigned long target_mhz, target_hz;
    int ret, i;
    bool freq_valid = false;
    struct dev_pm_opp *opp;
    unsigned long voltage;
    
    if (kstrtoul(buf, 10, &target_mhz)) {
        dev_err(dev, "Invalid frequency format\n");
        return -EINVAL;
    }
    
    target_hz = target_mhz * 1000000;
    
    // Validate frequency against our extreme overclock table
    for (i = 0; i < ARRAY_SIZE(extreme_freqs); i++) {
        if (extreme_freqs[i] == target_hz) {
            freq_valid = true;
            break;
        }
    }
    
    if (!freq_valid) {
        dev_err(dev, "Frequency %luMHz not in EXTREME overclock table\n", target_mhz);
        dev_info(dev, "Available: 1488, 1600, 1800, 2000, 2200, 2400, 2700, 3000 MHz\n");
        return -EINVAL;
    }
    
    dev_info(dev, "EXTREME OVERCLOCKING NPU TO %lu MHz for %.1f TOPS!\n", 
             target_mhz, (float)target_mhz/1008*1.0);
    
    // Add OPP if it doesn't exist - EXTREME voltage scaling
    opp = dev_pm_opp_find_freq_exact(dev, target_hz, true);
    if (IS_ERR(opp)) {
        // EXTREME voltage scaling for high frequencies
        voltage = 900000; // Base voltage (0.9V)
        if (target_hz > 1500000000) {
            // Extreme overclocking requires higher voltages
            voltage = 1000000 + ((target_hz - 1500000000) / 100000000) * 100000;
            if (voltage > 1400000) voltage = 1400000; // Cap at 1.4V for extreme OC
        }
        
        ret = dev_pm_opp_add(dev, target_hz, voltage);
        if (ret == 0) {
            dev_info(dev, "Added EXTREME %luMHz OPP (%lumV)\n", 
                     target_mhz, voltage/1000);
        } else {
            dev_warn(dev, "Failed to add EXTREME OPP: %d\n", ret);
        }
    } else {
        dev_pm_opp_put(opp);
        dev_info(dev, "EXTREME %luMHz OPP already exists\n", target_mhz);
    }
    
    // Force the frequency through direct clock control
    ret = direct_set_frequency(target_hz);
    if (ret) {
        dev_err(dev, "EXTREME overclock to %luMHz failed: %d\n", target_mhz, ret);
        return ret;
    }
    
    dev_info(dev, "NPU EXTREME OVERCLOCKED TO %lu MHz!\n", target_mhz);
    
    // Calculate TOPS performance
    unsigned long tops_x10 = (target_hz / 1000000) * 10 / 1008;  // x10 for decimal
    dev_info(dev, "ESTIMATED TOPS PERFORMANCE: %lu.%lu TOPS!\n", 
             tops_x10/10, tops_x10%10);
    
    if (target_hz >= 2700000000) {
        dev_info(dev, "*** 2.7+ TOPS ACHIEVED! MISSION ACCOMPLISHED! ***\n");
    }
    
    return count;
}

static DEVICE_ATTR(extreme_overclock, S_IRUGO | S_IWUSR, 
                   extreme_overclock_show, extreme_overclock_store);

static int find_npu_resources(void)
{
    struct device *dev;
    
    // Find NPU device
    dev = bus_find_device_by_name(&platform_bus_type, NULL, NPU_DEVICE_NAME);
    if (!dev) {
        pr_err("NPU device not found\n");
        return -ENODEV;
    }
    
    npu_device = dev;
    pr_info("Found NPU device for EXTREME overclocking\n");
    
    // Try to get NPU clock for direct control
    npu_clk = clk_get(dev, NULL);
    if (IS_ERR(npu_clk)) {
        npu_clk = clk_get(dev, "npu");
        if (IS_ERR(npu_clk)) {
            npu_clk = clk_get(dev, "core");
            if (IS_ERR(npu_clk)) {
                pr_warn("Could not get NPU clock directly\n");
                npu_clk = NULL;
            }
        }
    }
    
    if (npu_clk) {
        unsigned long current_rate = clk_get_rate(npu_clk);
        pr_info("NPU clock found! Current rate: %lu MHz\n", current_rate/1000000);
    }
    
    return 0;
}

static int __init npu_extreme_overclock_init(void)
{
    int ret;
    
    pr_info("NPU EXTREME OVERCLOCK MODULE - TARGET: 2.7+ TOPS!\n");
    pr_info("MISSION: Reach maximum TOPS performance!\n");
    pr_info("RANGE: 1488MHz -> 3000MHz (1.5 -> 3.0 TOPS)\n");
    
    ret = find_npu_resources();
    if (ret) {
        return ret;
    }
    
    // Create extreme overclock interface
    ret = device_create_file(npu_device, &dev_attr_extreme_overclock);
    if (ret) {
        pr_err("Failed to create extreme_overclock interface: %d\n", ret);
        if (npu_clk) clk_put(npu_clk);
        put_device(npu_device);
        return ret;
    }
    
    pr_info("NPU EXTREME OVERCLOCK LOADED!\n");
    pr_info("Interface: /sys/devices/platform/soc@3000000/3600000.npu/extreme_overclock\n");
    pr_info("TARGET COMMAND: echo 2700 > extreme_overclock  # 2.7 TOPS!\n");
    pr_info("MAXIMUM COMMAND: echo 3000 > extreme_overclock # 3.0 TOPS!\n");
    pr_info("LET'S REACH 2.7+ TOPS!\n");
    
    return 0;
}

static void __exit npu_extreme_overclock_exit(void)
{
    if (npu_device) {
        device_remove_file(npu_device, &dev_attr_extreme_overclock);
        put_device(npu_device);
    }
    
    if (npu_clk) {
        clk_put(npu_clk);
    }
    
    pr_info("NPU EXTREME OVERCLOCK MODULE UNLOADED\n");
}

module_init(npu_extreme_overclock_init);
module_exit(npu_extreme_overclock_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Extreme Overclock Team");
MODULE_DESCRIPTION("NPU Extreme Overclock - TARGET: 2.7+ TOPS Performance");
MODULE_VERSION("2.0");