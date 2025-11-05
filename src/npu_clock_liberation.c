/*
 * NPU Clock Liberation Module - Direct Clock Tree Manipulation
 * 
 * Based on the insight that GPU and NPU may share clock domains,
 * this module attempts to directly manipulate the clock tree to
 * unlock higher frequencies by bypassing OPP table limitations.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/pm_opp.h>
#include <linux/device.h>
#include <linux/of.h>
#include <linux/regulator/consumer.h>

static struct platform_device *npu_pdev = NULL;
static struct clk *npu_clk = NULL;
static struct device *npu_dev = NULL;

// Target frequencies to unlock
static unsigned long target_frequencies[] = {
    1120000000,  // 1120MHz - Found in device tree but filtered
    1200000000,  // 1200MHz - Safe overclock  
    1500000000,  // 1500MHz - Aggressive target
};

static ssize_t direct_freq_show(struct device *dev,
                               struct device_attribute *attr, char *buf)
{
    unsigned long current_freq = 0;
    
    if (npu_clk) {
        current_freq = clk_get_rate(npu_clk);
    }
    
    return sprintf(buf, "%lu\n", current_freq);
}

static ssize_t direct_freq_store(struct device *dev,
                                struct device_attribute *attr,
                                const char *buf, size_t count)
{
    unsigned long target_freq;
    int ret;
    
    if (kstrtoul(buf, 10, &target_freq))
        return -EINVAL;
    
    if (!npu_clk) {
        dev_err(dev, "❌ NPU clock not available!\n");
        return -ENODEV;
    }
    
    dev_info(dev, "🎯 Attempting direct clock set to %luMHz\n", target_freq/1000000);
    
    // Try direct clock setting bypassing devfreq
    ret = clk_set_rate(npu_clk, target_freq);
    if (ret) {
        dev_err(dev, "❌ Direct clock set failed: %d\n", ret);
        return ret;
    }
    
    // Verify the actual frequency
    unsigned long actual_freq = clk_get_rate(npu_clk);
    dev_info(dev, "🚀 CLOCK SET SUCCESS! Target: %luMHz, Actual: %luMHz\n", 
             target_freq/1000000, actual_freq/1000000);
    
    return count;
}

static ssize_t clock_info_show(struct device *dev,
                              struct device_attribute *attr, char *buf)
{
    struct clk *parent_clk;
    unsigned long current_rate = 0;
    const char *parent_name = "unknown";
    
    if (!npu_clk) {
        return sprintf(buf, "NPU clock not available\n");
    }
    
    current_rate = clk_get_rate(npu_clk);
    parent_clk = clk_get_parent(npu_clk);
    if (parent_clk) {
        parent_name = __clk_get_name(parent_clk);
    }
    
    return sprintf(buf, 
        "NPU Clock Info:\n"
        "Current Rate: %lu Hz (%lu MHz)\n"
        "Parent Clock: %s\n"
        "Target Liberation: 1120MHz, 1500MHz\n",
        current_rate, current_rate/1000000, parent_name);
}

static DEVICE_ATTR(direct_freq, S_IRUGO | S_IWUSR, direct_freq_show, direct_freq_store);
static DEVICE_ATTR(clock_info, S_IRUGO, clock_info_show, NULL);

static int find_npu_clock(void)
{
    struct device_node *np;
    
    // Find NPU device node
    np = of_find_node_by_path("/soc@3000000/npu@3600000");
    if (!np) {
        np = of_find_compatible_node(NULL, NULL, "allwinner,sun55i-a733-npu");
        if (!np) {
            pr_err("❌ NPU device node not found\n");
            return -ENODEV;
        }
    }
    
    // Create a temporary platform device to get the NPU device
    npu_pdev = of_find_device_by_node(np);
    if (!npu_pdev) {
        pr_err("❌ NPU platform device not found\n");
        of_node_put(np);
        return -ENODEV;
    }
    
    npu_dev = &npu_pdev->dev;
    
    // Try to get NPU clock
    npu_clk = devm_clk_get(npu_dev, NULL);
    if (IS_ERR(npu_clk)) {
        npu_clk = devm_clk_get(npu_dev, "npu");
        if (IS_ERR(npu_clk)) {
            npu_clk = devm_clk_get(npu_dev, "core");
            if (IS_ERR(npu_clk)) {
                pr_err("❌ Could not get NPU clock (tried NULL, 'npu', 'core')\n");
                of_node_put(np);
                return PTR_ERR(npu_clk);
            }
        }
    }
    
    pr_info("✅ NPU clock acquired! Rate: %lu Hz (%lu MHz)\n", 
            clk_get_rate(npu_clk), clk_get_rate(npu_clk)/1000000);
    
    of_node_put(np);
    return 0;
}

static int __init npu_clock_liberation_init(void)
{
    int ret;
    
    pr_info("🔥 NPU CLOCK LIBERATION MODULE 🔥\n");
    pr_info("🎯 Direct Clock Tree Manipulation Approach\n");
    
    ret = find_npu_clock();
    if (ret) {
        return ret;
    }
    
    // Create sysfs interfaces
    ret = device_create_file(npu_dev, &dev_attr_direct_freq);
    if (ret) {
        pr_err("❌ Failed to create direct_freq interface: %d\n", ret);
        return ret;
    }
    
    ret = device_create_file(npu_dev, &dev_attr_clock_info);
    if (ret) {
        pr_err("❌ Failed to create clock_info interface: %d\n", ret);
        device_remove_file(npu_dev, &dev_attr_direct_freq);
        return ret;
    }
    
    pr_info("🚀 NPU CLOCK LIBERATION LOADED!\n");
    pr_info("📍 Direct frequency control: /sys/devices/.../3600000.npu/direct_freq\n");
    pr_info("📍 Clock information: /sys/devices/.../3600000.npu/clock_info\n");
    pr_info("💡 Usage: echo 1120000000 > direct_freq (for 1120MHz)\n");
    
    return 0;
}

static void __exit npu_clock_liberation_exit(void)
{
    if (npu_dev) {
        device_remove_file(npu_dev, &dev_attr_direct_freq);
        device_remove_file(npu_dev, &dev_attr_clock_info);
    }
    
    pr_info("🔥 NPU CLOCK LIBERATION UNLOADED 🔥\n");
}

module_init(npu_clock_liberation_init);
module_exit(npu_clock_liberation_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Liberation Project");
MODULE_DESCRIPTION("NPU Clock Liberation - Direct Clock Tree Manipulation");
MODULE_VERSION("3.0");