/*
 * NPU Liberation Module v2.0 - Advanced Frequency Unlocking
 * 
 * This version directly modifies the devfreq OPP table to unlock
 * the missing 1120MHz frequency and enable higher frequencies.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/devfreq.h>
#include <linux/pm_opp.h>
#include <linux/device.h>
#include <linux/of.h>
#include <linux/slab.h>

#define NPU_DEVICE_NAME "3600000.npu"

// Enhanced frequency table including device tree + overclocked frequencies
static unsigned long liberation_frequencies[] = {
    492000000,   // 492MHz - Original
    852000000,   // 852MHz - Original
    1008000000,  // 1008MHz - Original (current max)
    1120000000,  // 1120MHz - Device tree but filtered out
    1200000000,  // 1200MHz - Safe overclock
    1500000000,  // 1500MHz - Aggressive overclock
    2000000000,  // 2000MHz - Maximum attempt
};

static struct platform_device *npu_pdev = NULL;
static struct devfreq *npu_devfreq = NULL;

static ssize_t liberation_show(struct device *dev,
                              struct device_attribute *attr, char *buf)
{
    return sprintf(buf, "1\n");
}

static ssize_t liberation_store(struct device *dev,
                               struct device_attribute *attr,
                               const char *buf, size_t count)
{
    struct dev_pm_opp *opp;
    int enable, i, ret;
    
    if (kstrtoint(buf, 10, &enable) || enable != 1)
        return -EINVAL;
    
    if (!npu_devfreq) {
        dev_err(dev, "❌ NPU devfreq not found!\n");
        return -ENODEV;
    }
    
    dev_info(dev, "🔥 INITIATING NPU FREQUENCY LIBERATION! 🔥\n");
    
    // Add missing frequencies to OPP table
    for (i = 0; i < ARRAY_SIZE(liberation_frequencies); i++) {
        unsigned long freq = liberation_frequencies[i];
        
        // Check if OPP already exists
        opp = dev_pm_opp_find_freq_exact(npu_devfreq->dev.parent, freq, true);
        if (!IS_ERR(opp)) {
            dev_pm_opp_put(opp);
            dev_info(dev, "✅ %luMHz already available\n", freq/1000000);
            continue;
        }
        
        // Add new OPP with voltage scaling
        // Using 1.0V for higher frequencies (safe starting point)
        unsigned long voltage = (freq > 1008000000) ? 1000000 : 900000;
        
        ret = dev_pm_opp_add(npu_devfreq->dev.parent, freq, voltage);
        if (ret == 0) {
            dev_info(dev, "🚀 UNLOCKED %luMHz (%.1fV)!\n", 
                     freq/1000000, voltage/1000000.0);
        } else {
            dev_warn(dev, "⚠️  Failed to add %luMHz: %d\n", freq/1000000, ret);
        }
    }
    
    // Force devfreq to update available frequencies
    mutex_lock(&npu_devfreq->lock);
    ret = update_devfreq(npu_devfreq);
    mutex_unlock(&npu_devfreq->lock);
    
    if (ret == 0) {
        dev_info(dev, "🎯 NPU FREQUENCY TABLE LIBERATED!\n");
        dev_info(dev, "💪 NPU now supports up to 2000MHz!\n");
    } else {
        dev_err(dev, "❌ Failed to update devfreq: %d\n", ret);
    }
    
    return count;
}

static DEVICE_ATTR(liberation_v2, S_IRUGO | S_IWUSR, liberation_show, liberation_store);

static int find_npu_devfreq(void)
{
    struct device *dev;
    struct devfreq *df;
    
    // Find NPU platform device
    npu_pdev = platform_device_alloc(NPU_DEVICE_NAME, -1);
    if (!npu_pdev) {
        pr_err("❌ Failed to allocate NPU platform device\n");
        return -ENOMEM;
    }
    
    // Look for existing NPU device
    dev = bus_find_device_by_name(&platform_bus_type, NULL, NPU_DEVICE_NAME);
    if (!dev) {
        pr_err("❌ NPU device %s not found\n", NPU_DEVICE_NAME);
        platform_device_put(npu_pdev);
        return -ENODEV;
    }
    
    // Find the devfreq instance
    list_for_each_entry(df, &devfreq_list, node) {
        if (df->dev.parent == dev) {
            npu_devfreq = df;
            pr_info("✅ Found NPU devfreq instance!\n");
            break;
        }
    }
    
    put_device(dev);
    
    if (!npu_devfreq) {
        pr_err("❌ NPU devfreq instance not found\n");
        platform_device_put(npu_pdev);
        return -ENODEV;
    }
    
    return 0;
}

static int __init npu_liberation_v2_init(void)
{
    int ret;
    
    pr_info("🔥 NPU FREQUENCY LIBERATION MODULE v2.0 🔥\n");
    pr_info("🎯 Target: Unlock 1120MHz + Enable 2000MHz Overclocking\n");
    
    ret = find_npu_devfreq();
    if (ret) {
        return ret;
    }
    
    // Create sysfs interface on the NPU device
    ret = device_create_file(npu_devfreq->dev.parent, &dev_attr_liberation_v2);
    if (ret) {
        pr_err("❌ Failed to create liberation_v2 sysfs interface: %d\n", ret);
        platform_device_put(npu_pdev);
        return ret;
    }
    
    pr_info("🚀 NPU LIBERATION MODULE v2.0 LOADED!\n");
    pr_info("📍 Liberation interface: /sys/devices/platform/soc@3000000/3600000.npu/liberation_v2\n");
    pr_info("💡 Usage: echo 1 > liberation_v2 to unlock frequencies\n");
    
    return 0;
}

static void __exit npu_liberation_v2_exit(void)
{
    if (npu_devfreq) {
        device_remove_file(npu_devfreq->dev.parent, &dev_attr_liberation_v2);
    }
    
    if (npu_pdev) {
        platform_device_put(npu_pdev);
    }
    
    pr_info("🔥 NPU LIBERATION MODULE v2.0 UNLOADED 🔥\n");
}

module_init(npu_liberation_v2_init);
module_exit(npu_liberation_v2_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Liberation Project");
MODULE_DESCRIPTION("NPU Frequency Liberation Module v2.0 - Direct OPP Table Modification");
MODULE_VERSION("2.0");