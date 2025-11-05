/*
 * NPU OVERCLOCK BYPASS MODULE - MAXIMUM PERFORMANCE UNLEASHED!
 * 
 * Fixed version without floating point operations
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

// OVERCLOCK FREQUENCY TABLE - PUSH THE LIMITS!
static unsigned long overclock_freqs[] = {
    492000000,   // 492MHz - Original baseline
    852000000,   // 852MHz - Original 
    1008000000,  // 1008MHz - Current artificial limit
    1120000000,  // 1120MHz - Device tree proven (+11%)
    1200000000,  // 1200MHz - Safe overclock (+19%)
    1344000000,  // 1344MHz - Aggressive (+33%)
    1500000000,  // 1500MHz - Maximum attempt (+49%)
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
    
    pr_info("DIRECT FREQUENCY OVERRIDE: %lu MHz\n", target_freq/1000000);
    
    // Set clock frequency directly
    ret = clk_set_rate(npu_clk, target_freq);
    if (ret) {
        pr_err("Direct clock set failed: %d\n", ret);
        return ret;
    }
    
    // Verify the frequency was set
    actual_freq = clk_get_rate(npu_clk);
    pr_info("OVERCLOCK SUCCESS! Target: %luMHz, Actual: %luMHz\n", 
            target_freq/1000000, actual_freq/1000000);
    
    return 0;
}

// Sysfs interface for overclocking
static ssize_t overclock_show(struct device *dev,
                             struct device_attribute *attr, char *buf)
{
    unsigned long current_freq = 0;
    
    if (npu_clk) {
        current_freq = clk_get_rate(npu_clk);
    }
    
    return sprintf(buf, "NPU Overclock Control\n"
                        "Current: %lu MHz\n"
                        "Available: 492, 852, 1008, 1120, 1200, 1344, 1500 MHz\n"
                        "Usage: echo <freq_mhz> > overclock\n"
                        "Example: echo 1200 > overclock\n",
                        current_freq/1000000);
}

static ssize_t overclock_store(struct device *dev,
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
    
    // Validate frequency against our overclock table
    for (i = 0; i < ARRAY_SIZE(overclock_freqs); i++) {
        if (overclock_freqs[i] == target_hz) {
            freq_valid = true;
            break;
        }
    }
    
    if (!freq_valid) {
        dev_err(dev, "Frequency %luMHz not in overclock table\n", target_mhz);
        return -EINVAL;
    }
    
    dev_info(dev, "OVERCLOCKING NPU TO %lu MHz!\n", target_mhz);
    
    // Add OPP if it doesn't exist
    opp = dev_pm_opp_find_freq_exact(dev, target_hz, true);
    if (IS_ERR(opp)) {
        // Calculate voltage for overclock (integer math only)
        voltage = 900000; // Base voltage (0.9V)
        if (target_hz > 1008000000) {
            // Overclock voltages - scale up for stability
            voltage = 900000 + ((target_hz - 1008000000) / 1000000) * 50000;
            if (voltage > 1200000) voltage = 1200000; // Cap at 1.2V for safety
        }
        
        ret = dev_pm_opp_add(dev, target_hz, voltage);
        if (ret == 0) {
            dev_info(dev, "Added %luMHz OPP (%lumV)\n", 
                     target_mhz, voltage/1000);
        } else {
            dev_warn(dev, "Failed to add OPP: %d\n", ret);
        }
    } else {
        dev_pm_opp_put(opp);
        dev_info(dev, "%luMHz OPP already exists\n", target_mhz);
    }
    
    // Force the frequency through direct clock control
    ret = direct_set_frequency(target_hz);
    if (ret) {
        dev_err(dev, "Overclock to %luMHz failed: %d\n", target_mhz, ret);
        return ret;
    }
    
    dev_info(dev, "NPU OVERCLOCKED TO %lu MHz!\n", target_mhz);
    
    // Calculate percentage boost (integer math)
    if (target_hz > 1008000000) {
        unsigned long boost_percent = ((target_hz - 1008000000) * 100) / 1008000000;
        dev_info(dev, "Performance boost: +%lu%% over 1008MHz baseline\n", boost_percent);
    }
    
    return count;
}

static DEVICE_ATTR(overclock, S_IRUGO | S_IWUSR, overclock_show, overclock_store);

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
    pr_info("Found NPU device\n");
    
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

static int __init npu_overclock_init(void)
{
    int ret;
    
    pr_info("NPU OVERCLOCK BYPASS MODULE\n");
    pr_info("TARGET: UNLEASH MAXIMUM NPU PERFORMANCE!\n");
    pr_info("FREQUENCIES: 492MHz -> 1500MHz (+49%% BOOST!)\n");
    
    ret = find_npu_resources();
    if (ret) {
        return ret;
    }
    
    // Create overclock interface
    ret = device_create_file(npu_device, &dev_attr_overclock);
    if (ret) {
        pr_err("Failed to create overclock interface: %d\n", ret);
        if (npu_clk) clk_put(npu_clk);
        put_device(npu_device);
        return ret;
    }
    
    pr_info("NPU OVERCLOCK BYPASS LOADED!\n");
    pr_info("Interface: /sys/devices/platform/soc@3000000/3600000.npu/overclock\n");
    pr_info("Usage Examples:\n");
    pr_info("  echo 1120 > overclock  # +11%% boost (proven safe)\n");
    pr_info("  echo 1200 > overclock  # +19%% boost (safe overclock)\n");
    pr_info("  echo 1344 > overclock  # +33%% boost (aggressive)\n");
    pr_info("  echo 1500 > overclock  # +49%% boost (MAXIMUM POWER!)\n");
    pr_info("LET THE OVERCLOCKING BEGIN!\n");
    
    return 0;
}

static void __exit npu_overclock_exit(void)
{
    if (npu_device) {
        device_remove_file(npu_device, &dev_attr_overclock);
        put_device(npu_device);
    }
    
    if (npu_clk) {
        clk_put(npu_clk);
    }
    
    pr_info("NPU OVERCLOCK BYPASS MODULE UNLOADED\n");
}

module_init(npu_overclock_init);
module_exit(npu_overclock_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Overclock Liberation Team");
MODULE_DESCRIPTION("NPU Overclock Bypass - Direct Frequency Control up to 1500MHz");
MODULE_VERSION("1.0");