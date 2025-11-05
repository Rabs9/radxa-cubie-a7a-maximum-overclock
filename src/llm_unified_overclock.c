/*
 * UNIFIED GPU/NPU OVERCLOCKING MODULE FOR LLMs
 * 
 * This module overclocks both GPU and NPU for maximum LLM performance
 * Bypasses software limitations on both compute units
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/devfreq.h>
#include <linux/pm_opp.h>
#include <linux/device.h>
#include <linux/clk.h>
#include <linux/of.h>

#define NPU_DEVICE_NAME "3600000.npu"
#define GPU_DEVICE_NAME "1800000.gpu"

// EXTREME OVERCLOCKING FOR LLM PERFORMANCE
static unsigned long llm_npu_freqs[] = {
    1008000000,  // 1008MHz - Baseline
    1200000000,  // 1200MHz - Safe overclock
    1488000000,  // 1488MHz - Current achievement
    1600000000,  // 1600MHz - Push higher
    1800000000,  // 1800MHz - Aggressive for LLMs
    2000000000,  // 2000MHz - Maximum attempt
};

static unsigned long llm_gpu_freqs[] = {
    400000000,   // 400MHz - Conservative baseline
    600000000,   // 600MHz - Moderate boost
    800000000,   // 800MHz - Aggressive boost
    1000000000,  // 1000MHz - Maximum attempt
};

static struct device *npu_device = NULL;
static struct device *gpu_device = NULL;
static struct clk *npu_clk = NULL;
static struct clk *gpu_clk = NULL;

// Unified GPU/NPU frequency control
static int set_unified_frequency(unsigned long npu_freq, unsigned long gpu_freq)
{
    int ret = 0;
    
    pr_info("🚀 UNIFIED GPU/NPU OVERCLOCKING FOR LLMs! 🚀\n");
    pr_info("Target NPU: %luMHz, Target GPU: %luMHz\n", 
            npu_freq/1000000, gpu_freq/1000000);
    
    // Set NPU frequency
    if (npu_clk) {
        ret = clk_set_rate(npu_clk, npu_freq);
        if (ret == 0) {
            unsigned long actual_npu = clk_get_rate(npu_clk);
            pr_info("✅ NPU: %luMHz achieved\n", actual_npu/1000000);
        } else {
            pr_err("❌ NPU overclock failed: %d\n", ret);
        }
    }
    
    // Set GPU frequency (attempt direct clock control)
    if (gpu_clk) {
        ret = clk_set_rate(gpu_clk, gpu_freq);
        if (ret == 0) {
            unsigned long actual_gpu = clk_get_rate(gpu_clk);
            pr_info("✅ GPU: %luMHz achieved\n", actual_gpu/1000000);
        } else {
            pr_info("⚠️ GPU direct clock control failed: %d\n", ret);
        }
    } else {
        pr_info("⚠️ GPU clock not accessible - trying alternative method\n");
    }
    
    return ret;
}

// Sysfs interface for unified overclocking
static ssize_t llm_overclock_show(struct device *dev,
                                  struct device_attribute *attr, char *buf)
{
    unsigned long npu_freq = 0, gpu_freq = 0;
    
    if (npu_clk) npu_freq = clk_get_rate(npu_clk);
    if (gpu_clk) gpu_freq = clk_get_rate(gpu_clk);
    
    return sprintf(buf, "UNIFIED GPU/NPU OVERCLOCKING FOR LLMs\n"
                        "NPU: %lu MHz\n"
                        "GPU: %lu MHz\n"
                        "Usage: echo <npu_mhz>,<gpu_mhz> > llm_overclock\n"
                        "Example: echo 1800,800 > llm_overclock\n"
                        "Presets:\n"
                        "  conservative: echo conservative > llm_overclock\n"
                        "  aggressive: echo aggressive > llm_overclock\n"
                        "  maximum: echo maximum > llm_overclock\n",
                        npu_freq/1000000, gpu_freq/1000000);
}

static ssize_t llm_overclock_store(struct device *dev,
                                   struct device_attribute *attr,
                                   const char *buf, size_t count)
{
    unsigned long npu_mhz, gpu_mhz;
    int ret;
    
    // Check for preset modes
    if (strncmp(buf, "conservative", 12) == 0) {
        npu_mhz = 1200; gpu_mhz = 600;
    } else if (strncmp(buf, "aggressive", 10) ==0) {
        npu_mhz = 1800; gpu_mhz = 800;
    } else if (strncmp(buf, "maximum", 7) == 0) {
        npu_mhz = 2000; gpu_mhz = 1000;
    } else {
        // Parse custom frequencies
        if (sscanf(buf, "%lu,%lu", &npu_mhz, &gpu_mhz) != 2) {
            dev_err(dev, "Invalid format. Use: npu_mhz,gpu_mhz\n");
            return -EINVAL;
        }
    }
    
    dev_info(dev, "🔥 LLM OVERCLOCKING: NPU %luMHz, GPU %luMHz\n", npu_mhz, gpu_mhz);
    
    // Add OPPs if needed
    struct dev_pm_opp *opp;
    unsigned long npu_hz = npu_mhz * 1000000;
    unsigned long gpu_hz = gpu_mhz * 1000000;
    
    // Add NPU OPP
    opp = dev_pm_opp_find_freq_exact(npu_device, npu_hz, true);
    if (IS_ERR(opp)) {
        unsigned long voltage = 1000000 + (npu_mhz - 1008) * 1000; // Scale voltage
        if (voltage > 1300000) voltage = 1300000; // Cap at 1.3V
        
        ret = dev_pm_opp_add(npu_device, npu_hz, voltage);
        if (ret == 0) {
            dev_info(dev, "✅ Added NPU %luMHz OPP\n", npu_mhz);
        }
    } else {
        dev_pm_opp_put(opp);
    }
    
    // Add GPU OPP (if possible)
    if (gpu_device) {
        opp = dev_pm_opp_find_freq_exact(gpu_device, gpu_hz, true);
        if (IS_ERR(opp)) {
            unsigned long voltage = 900000 + (gpu_mhz - 400) * 500; // Scale voltage
            if (voltage > 1200000) voltage = 1200000; // Cap at 1.2V
            
            ret = dev_pm_opp_add(gpu_device, gpu_hz, voltage);
            if (ret == 0) {
                dev_info(dev, "✅ Added GPU %luMHz OPP\n", gpu_mhz);
            }
        } else {
            dev_pm_opp_put(opp);
        }
    }
    
    // Apply unified overclocking
    ret = set_unified_frequency(npu_hz, gpu_hz);
    
    if (ret == 0) {
        dev_info(dev, "🎉 UNIFIED GPU/NPU OVERCLOCKED FOR LLM PERFORMANCE!\n");
        dev_info(dev, "🚀 Ready for maximum LLM inference speed!\n");
    }
    
    return count;
}

static DEVICE_ATTR(llm_overclock, S_IRUGO | S_IWUSR, llm_overclock_show, llm_overclock_store);

static int find_gpu_npu_devices(void)
{
    // Find NPU device
    npu_device = bus_find_device_by_name(&platform_bus_type, NULL, NPU_DEVICE_NAME);
    if (!npu_device) {
        pr_err("❌ NPU device not found\n");
        return -ENODEV;
    }
    pr_info("✅ Found NPU device\n");
    
    // Find GPU device
    gpu_device = bus_find_device_by_name(&platform_bus_type, NULL, GPU_DEVICE_NAME);
    if (!gpu_device) {
        pr_warn("⚠️ GPU device not found - NPU only mode\n");
    } else {
        pr_info("✅ Found GPU device\n");
    }
    
    // Get NPU clock
    npu_clk = clk_get(npu_device, NULL);
    if (IS_ERR(npu_clk)) {
        npu_clk = clk_get(npu_device, "npu");
        if (IS_ERR(npu_clk)) {
            pr_warn("⚠️ NPU clock not directly accessible\n");
            npu_clk = NULL;
        }
    }
    
    if (npu_clk) {
        pr_info("✅ NPU clock found: %luMHz\n", clk_get_rate(npu_clk)/1000000);
    }
    
    // Try to get GPU clock
    if (gpu_device) {
        gpu_clk = clk_get(gpu_device, NULL);
        if (IS_ERR(gpu_clk)) {
            gpu_clk = clk_get(gpu_device, "gpu");
            if (IS_ERR(gpu_clk)) {
                gpu_clk = clk_get(gpu_device, "core");
                if (IS_ERR(gpu_clk)) {
                    pr_info("⚠️ GPU clock not directly accessible\n");
                    gpu_clk = NULL;
                }
            }
        }
        
        if (gpu_clk) {
            pr_info("✅ GPU clock found: %luMHz\n", clk_get_rate(gpu_clk)/1000000);
        }
    }
    
    return 0;
}

static int __init llm_unified_overclock_init(void)
{
    int ret;
    
    pr_info("🔥🔥🔥 UNIFIED GPU/NPU OVERCLOCKING FOR LLMs! 🔥🔥🔥\n");
    pr_info("🎯 MISSION: Maximum LLM inference performance!\n");
    pr_info("⚡ TARGET: GPU + NPU combined overclocking!\n");
    
    ret = find_gpu_npu_devices();
    if (ret) {
        return ret;
    }
    
    // Create unified overclocking interface on NPU device
    ret = device_create_file(npu_device, &dev_attr_llm_overclock);
    if (ret) {
        pr_err("❌ Failed to create llm_overclock interface: %d\n", ret);
        goto cleanup;
    }
    
    pr_info("✅ UNIFIED GPU/NPU OVERCLOCKING MODULE LOADED!\n");
    pr_info("📍 Interface: /sys/devices/platform/soc@3000000/3600000.npu/llm_overclock\n");
    pr_info("🚀 READY FOR LLM OVERCLOCKING!\n");
    pr_info("💡 Quick start: echo aggressive > llm_overclock\n");
    
    return 0;
    
cleanup:
    if (npu_clk) clk_put(npu_clk);
    if (gpu_clk) clk_put(gpu_clk);
    if (npu_device) put_device(npu_device);
    if (gpu_device) put_device(gpu_device);
    return ret;
}

static void __exit llm_unified_overclock_exit(void)
{
    if (npu_device) {
        device_remove_file(npu_device, &dev_attr_llm_overclock);
        put_device(npu_device);
    }
    
    if (gpu_device) put_device(gpu_device);
    if (npu_clk) clk_put(npu_clk);
    if (gpu_clk) clk_put(gpu_clk);
    
    pr_info("🔥 UNIFIED GPU/NPU OVERCLOCKING MODULE UNLOADED\n");
}

module_init(llm_unified_overclock_init);
module_exit(llm_unified_overclock_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("LLM Performance Team");
MODULE_DESCRIPTION("Unified GPU/NPU Overclocking for Maximum LLM Performance");
MODULE_VERSION("1.0");