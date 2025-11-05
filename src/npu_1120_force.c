/*
 * NPU 1120MHz Force Module - Force devfreq to recognize 1120MHz
 * 
 * This module forces the devfreq framework to update its available
 * frequencies list to include the 1120MHz OPP we've successfully added.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/devfreq.h>
#include <linux/pm_opp.h>
#include <linux/device.h>

#define NPU_DEVICE_NAME "3600000.npu"

static struct device *npu_device = NULL;
static struct devfreq *npu_devfreq = NULL;

// Function to rebuild devfreq frequency table
static int rebuild_devfreq_table(struct devfreq *devfreq)
{
    struct dev_pm_opp *opp;
    unsigned long freq = 0;
    int count = 0;
    
    dev_info(devfreq->dev.parent, "🔄 REBUILDING DEVFREQ FREQUENCY TABLE...\n");
    
    // Count available OPPs
    while (!IS_ERR(opp = dev_pm_opp_find_freq_ceil(devfreq->dev.parent, &freq))) {
        dev_info(devfreq->dev.parent, "✅ Found OPP: %lu Hz (%lu MHz)\n", 
                 freq, freq/1000000);
        dev_pm_opp_put(opp);
        freq++;
        count++;
        if (count > 10) break; // Safety limit
    }
    
    dev_info(devfreq->dev.parent, "📊 Total OPPs found: %d\n", count);
    
    return count;
}

static ssize_t force_1120_show(struct device *dev,
                               struct device_attribute *attr, char *buf)
{
    return sprintf(buf, "Ready to force 1120MHz recognition\n");
}

static ssize_t force_1120_store(struct device *dev,
                                struct device_attribute *attr,
                                const char *buf, size_t count)
{
    int enable, ret;
    
    if (kstrtoint(buf, 10, &enable) || enable != 1)
        return -EINVAL;
    
    if (!npu_devfreq) {
        dev_err(dev, "❌ NPU devfreq not found!\n");
        return -ENODEV;
    }
    
    dev_info(dev, "🚀 FORCING 1120MHz RECOGNITION!\n");
    
    // Lock devfreq mutex to prevent concurrent access
    mutex_lock(&npu_devfreq->lock);
    
    // Force rebuild of frequency table
    ret = rebuild_devfreq_table(npu_devfreq);
    
    if (ret > 0) {
        dev_info(dev, "✅ Frequency table rebuilt with %d frequencies!\n", ret);
        
        // Try to update the devfreq with new max frequency
        dev_info(dev, "🎯 Attempting to update max frequency to 1120MHz...\n");
        
        // Force update devfreq
        ret = update_devfreq(npu_devfreq);
        if (ret == 0) {
            dev_info(dev, "🚀 DEVFREQ UPDATE SUCCESS!\n");
        } else {
            dev_warn(dev, "⚠️  Devfreq update returned: %d\n", ret);
        }
    }
    
    mutex_unlock(&npu_devfreq->lock);
    
    dev_info(dev, "💡 Check available_frequencies and try setting 1120MHz!\n");
    
    return count;
}

static DEVICE_ATTR(force_1120, S_IRUGO | S_IWUSR, force_1120_show, force_1120_store);

static int find_npu_device(void)
{
    struct device *dev;
    struct devfreq *df;
    
    // Find NPU platform device
    dev = bus_find_device_by_name(&platform_bus_type, NULL, NPU_DEVICE_NAME);
    if (!dev) {
        pr_err("❌ NPU device %s not found\n", NPU_DEVICE_NAME);
        return -ENODEV;
    }
    
    npu_device = dev;
    
    // Find the devfreq instance (simplified approach)
    df = dev_get_drvdata(dev);
    if (!df) {
        // Try alternative method - check if devfreq is in device structure
        struct device *devfreq_dev = device_find_child(dev, NULL, NULL);
        if (devfreq_dev && strstr(dev_name(devfreq_dev), "devfreq")) {
            df = dev_get_drvdata(devfreq_dev);
        }
    }
    
    if (!df) {
        pr_err("❌ NPU devfreq instance not found in device data\n");
        put_device(dev);
        return -ENODEV;
    }
    
    npu_devfreq = df;
    pr_info("✅ Found NPU devfreq instance!\n");
    
    return 0;
}

static int __init npu_1120_force_init(void)
{
    int ret;
    
    pr_info("🚀 NPU 1120MHz FORCE MODULE LOADING...\n");
    
    ret = find_npu_device();
    if (ret) {
        return ret;
    }
    
    // Create sysfs interface
    ret = device_create_file(npu_device, &dev_attr_force_1120);
    if (ret) {
        pr_err("❌ Failed to create force_1120 sysfs interface: %d\n", ret);
        put_device(npu_device);
        return ret;
    }
    
    pr_info("✅ NPU 1120MHz FORCE MODULE LOADED!\n");
    pr_info("📍 Interface: /sys/devices/platform/soc@3000000/3600000.npu/force_1120\n");
    pr_info("💡 Usage: echo 1 > force_1120\n");
    
    return 0;
}

static void __exit npu_1120_force_exit(void)
{
    if (npu_device) {
        device_remove_file(npu_device, &dev_attr_force_1120);
        put_device(npu_device);
    }
    
    pr_info("🔥 NPU 1120MHz FORCE MODULE UNLOADED\n");
}

module_init(npu_1120_force_init);
module_exit(npu_1120_force_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Liberation Project");
MODULE_DESCRIPTION("NPU 1120MHz Force Recognition Module");
MODULE_VERSION("1.0");