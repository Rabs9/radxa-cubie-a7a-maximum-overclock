/*
 * NPU 1120MHz Unlock Module - Targeted OPP Addition
 * 
 * This module specifically targets the missing 1120MHz frequency
 * that exists in device tree but is filtered out by the kernel.
 * Simple approach: just add the missing OPP and trigger refresh.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/pm_opp.h>
#include <linux/devfreq.h>
#include <linux/platform_device.h>

#define NPU_DEVICE_NAME "3600000.npu"
#define TARGET_FREQ_1120MHZ 1120000000UL
#define TARGET_VOLTAGE_1120MHZ 950000UL  // Safe voltage for 1120MHz

static struct device *npu_device = NULL;

static ssize_t unlock_1120_show(struct device *dev,
                                struct device_attribute *attr, char *buf)
{
    return sprintf(buf, "NPU 1120MHz Unlock Status\n");
}

static ssize_t unlock_1120_store(struct device *dev,
                                 struct device_attribute *attr,
                                 const char *buf, size_t count)
{
    int enable, ret;
    struct dev_pm_opp *opp;
    
    if (kstrtoint(buf, 10, &enable) || enable != 1)
        return -EINVAL;
    
    if (!npu_device) {
        dev_err(dev, "❌ NPU device not found!\n");
        return -ENODEV;
    }
    
    dev_info(dev, "🎯 ATTEMPTING 1120MHz UNLOCK...\n");
    
    // Check if 1120MHz already exists
    opp = dev_pm_opp_find_freq_exact(npu_device, TARGET_FREQ_1120MHZ, true);
    if (!IS_ERR(opp)) {
        dev_pm_opp_put(opp);
        dev_info(dev, "✅ 1120MHz already available!\n");
        return count;
    }
    
    // Add 1120MHz OPP
    ret = dev_pm_opp_add(npu_device, TARGET_FREQ_1120MHZ, TARGET_VOLTAGE_1120MHZ);
    if (ret) {
        dev_err(dev, "❌ Failed to add 1120MHz OPP: %d\n", ret);
        return ret;
    }
    
    dev_info(dev, "🚀 1120MHz OPP ADDED SUCCESSFULLY!\n");
    dev_info(dev, "💡 Try: echo 1120000000 > /sys/class/devfreq/3600000.npu/userspace/set_freq\n");
    
    return count;
}

static DEVICE_ATTR(unlock_1120, S_IRUGO | S_IWUSR, unlock_1120_show, unlock_1120_store);

static int __init npu_1120_unlock_init(void)
{
    struct device *dev;
    int ret;
    
    pr_info("🔥 NPU 1120MHz UNLOCK MODULE 🔥\n");
    pr_info("🎯 Target: Add missing 1120MHz from device tree\n");
    
    // Find NPU device
    dev = bus_find_device_by_name(&platform_bus_type, NULL, NPU_DEVICE_NAME);
    if (!dev) {
        pr_err("❌ NPU device %s not found\n", NPU_DEVICE_NAME);
        return -ENODEV;
    }
    
    npu_device = dev;
    
    // Create sysfs interface
    ret = device_create_file(dev, &dev_attr_unlock_1120);
    if (ret) {
        pr_err("❌ Failed to create unlock_1120 interface: %d\n", ret);
        put_device(dev);
        return ret;
    }
    
    pr_info("🚀 NPU 1120MHz UNLOCK MODULE LOADED!\n");
    pr_info("📍 Interface: /sys/devices/platform/soc@3000000/3600000.npu/unlock_1120\n");
    pr_info("💡 Usage: echo 1 > unlock_1120\n");
    
    return 0;
}

static void __exit npu_1120_unlock_exit(void)
{
    if (npu_device) {
        device_remove_file(npu_device, &dev_attr_unlock_1120);
        put_device(npu_device);
    }
    
    pr_info("🔥 NPU 1120MHz UNLOCK MODULE UNLOADED 🔥\n");
}

module_init(npu_1120_unlock_init);
module_exit(npu_1120_unlock_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Liberation Project");
MODULE_DESCRIPTION("NPU 1120MHz Unlock - Add Missing Device Tree Frequency");
MODULE_VERSION("1.0");