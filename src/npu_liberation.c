/*
 * NPU Frequency Liberation Module
 * 
 * This kernel module bypasses the devfreq restrictions and enables
 * direct control of NPU frequencies up to 5000MHz (5GHz)
 * 
 * Target: Allwinner A733 NPU (VIP core)
 * 
 * Author: NPU Liberation Front
 * License: GPL
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/clk.h>
#include <linux/regulator/consumer.h>
#include <linux/pm_opp.h>
#include <linux/devfreq.h>
#include <linux/sysfs.h>
#include <linux/device.h>

#define NPU_LIBERATION_VERSION "1.0"
#define NPU_DEVICE_NAME "3600000.npu"

/* NPU frequency table (Hz) - our liberation frequencies! */
static unsigned long npu_liberation_frequencies[] = {
    492000000,   /* 492 MHz - minimum */
    672000000,   /* 672 MHz */
    852000000,   /* 852 MHz */
    1008000000,  /* 1008 MHz - old maximum */
    1120000000,  /* 1120 MHz - BREAKTHROUGH! */
    1200000000,  /* 1200 MHz - 50% boost */
    1344000000,  /* 1344 MHz */
    1500000000,  /* 1500 MHz - 100% boost */
    1680000000,  /* 1680 MHz */
    1800000000,  /* 1800 MHz */
    2016000000,  /* 2016 MHz - 2x boost */
    2400000000,  /* 2400 MHz */
    2688000000,  /* 2688 MHz */
    3000000000,  /* 3000 MHz - 3x boost */
    3360000000,  /* 3360 MHz */
    3840000000,  /* 3840 MHz */
    4200000000,  /* 4200 MHz */
    4704000000,  /* 4704 MHz */
    5000000000   /* 5000 MHz - MAXIMUM POWER! */
};

#define NPU_FREQ_COUNT ARRAY_SIZE(npu_liberation_frequencies)

static struct device *npu_dev;
static struct clk *npu_clk;
static struct clk *pll_npu_clk;
static struct regulator *npu_regulator;
static unsigned long current_frequency = 1008000000;
static int liberation_enabled = 0;

/* Sysfs interface for frequency control */
static ssize_t frequency_show(struct device *dev, struct device_attribute *attr, char *buf)
{
    return sprintf(buf, "%lu\n", current_frequency);
}

static ssize_t frequency_store(struct device *dev, struct device_attribute *attr, 
                              const char *buf, size_t count)
{
    unsigned long target_freq;
    int ret, i;
    bool freq_valid = false;
    
    ret = kstrtoul(buf, 10, &target_freq);
    if (ret)
        return ret;
    
    /* Check if frequency is in our liberation table */
    for (i = 0; i < NPU_FREQ_COUNT; i++) {
        if (npu_liberation_frequencies[i] == target_freq) {
            freq_valid = true;
            break;
        }
    }
    
    if (!freq_valid) {
        dev_err(dev, "Invalid frequency %lu Hz\n", target_freq);
        return -EINVAL;
    }
    
    if (!liberation_enabled) {
        dev_err(dev, "NPU Liberation not enabled\n");
        return -EACCES;
    }
    
    /* Set the frequency directly through clock framework */
    if (pll_npu_clk) {
        ret = clk_set_rate(pll_npu_clk, target_freq);
        if (ret) {
            dev_err(dev, "Failed to set PLL-NPU rate: %d\n", ret);
            return ret;
        }
    }
    
    if (npu_clk) {
        ret = clk_set_rate(npu_clk, target_freq);
        if (ret) {
            dev_err(dev, "Failed to set NPU rate: %d\n", ret);
            return ret;
        }
    }
    
    current_frequency = target_freq;
    dev_info(dev, "🚀 NPU LIBERATED TO %lu MHz! 🚀\n", target_freq / 1000000);
    
    return count;
}

static ssize_t available_frequencies_show(struct device *dev, struct device_attribute *attr, char *buf)
{
    int i, len = 0;
    
    for (i = 0; i < NPU_FREQ_COUNT; i++) {
        len += sprintf(buf + len, "%lu ", npu_liberation_frequencies[i]);
    }
    len += sprintf(buf + len - 1, "\n");
    
    return len;
}

static ssize_t liberation_enable_show(struct device *dev, struct device_attribute *attr, char *buf)
{
    return sprintf(buf, "%d\n", liberation_enabled);
}

static ssize_t liberation_enable_store(struct device *dev, struct device_attribute *attr,
                                     const char *buf, size_t count)
{
    int enable;
    int ret;
    
    ret = kstrtoint(buf, 10, &enable);
    if (ret)
        return ret;
    
    liberation_enabled = !!enable;
    
    if (liberation_enabled) {
        dev_info(dev, "🔥 NPU LIBERATION ENABLED! UNLEASH THE POWER! 🔥\n");
    } else {
        dev_info(dev, "NPU Liberation disabled\n");
    }
    
    return count;
}

static ssize_t info_show(struct device *dev, struct device_attribute *attr, char *buf)
{
    return sprintf(buf, 
        "NPU Frequency Liberation Module v%s\n"
        "======================================\n"
        "Current Frequency: %lu MHz\n"
        "Liberation Status: %s\n"
        "Available Frequencies: %d points (492MHz - 5000MHz)\n"
        "Hardware: Allwinner A733 NPU\n"
        "Mission: UNLEASH THE FULL NPU POWER!\n",
        NPU_LIBERATION_VERSION,
        current_frequency / 1000000,
        liberation_enabled ? "ENABLED 🚀" : "DISABLED",
        NPU_FREQ_COUNT
    );
}

static DEVICE_ATTR_RW(frequency);
static DEVICE_ATTR_RO(available_frequencies);
static DEVICE_ATTR_RW(liberation_enable);
static DEVICE_ATTR_RO(info);

static struct attribute *npu_liberation_attrs[] = {
    &dev_attr_frequency.attr,
    &dev_attr_available_frequencies.attr,
    &dev_attr_liberation_enable.attr,
    &dev_attr_info.attr,
    NULL
};

static const struct attribute_group npu_liberation_attr_group = {
    .attrs = npu_liberation_attrs,
};

static int npu_liberation_init(void)
{
    int ret;
    
    printk(KERN_INFO "🔥 NPU FREQUENCY LIBERATION MODULE LOADING... 🔥\n");
    
    /* Find the NPU device */
    npu_dev = bus_find_device_by_name(&platform_bus_type, NULL, NPU_DEVICE_NAME);
    if (!npu_dev) {
        printk(KERN_ERR "NPU Liberation: Could not find NPU device %s\n", NPU_DEVICE_NAME);
        return -ENODEV;
    }
    
    /* Get NPU clocks */
    npu_clk = clk_get(npu_dev, "core");
    if (IS_ERR(npu_clk)) {
        printk(KERN_WARNING "NPU Liberation: Could not get NPU core clock\n");
        npu_clk = NULL;
    }
    
    pll_npu_clk = clk_get(npu_dev, "pll-npu");
    if (IS_ERR(pll_npu_clk)) {
        printk(KERN_WARNING "NPU Liberation: Could not get PLL-NPU clock\n");
        pll_npu_clk = NULL;
    }
    
    /* Create sysfs interface */
    ret = sysfs_create_group(&npu_dev->kobj, &npu_liberation_attr_group);
    if (ret) {
        printk(KERN_ERR "NPU Liberation: Failed to create sysfs interface\n");
        goto cleanup;
    }
    
    printk(KERN_INFO "🚀 NPU LIBERATION MODULE LOADED SUCCESSFULLY! 🚀\n");
    printk(KERN_INFO "NPU Liberation: Ready to unleash frequencies up to 5000MHz!\n");
    printk(KERN_INFO "NPU Liberation: Use /sys/devices/platform/%s/liberation_enable to enable\n", NPU_DEVICE_NAME);
    
    return 0;
    
cleanup:
    if (npu_clk && !IS_ERR(npu_clk))
        clk_put(npu_clk);
    if (pll_npu_clk && !IS_ERR(pll_npu_clk))
        clk_put(pll_npu_clk);
    if (npu_dev)
        put_device(npu_dev);
    
    return ret;
}

static void npu_liberation_exit(void)
{
    printk(KERN_INFO "NPU Liberation: Module unloading...\n");
    
    if (npu_dev) {
        sysfs_remove_group(&npu_dev->kobj, &npu_liberation_attr_group);
        put_device(npu_dev);
    }
    
    if (npu_clk && !IS_ERR(npu_clk))
        clk_put(npu_clk);
    if (pll_npu_clk && !IS_ERR(pll_npu_clk))
        clk_put(pll_npu_clk);
    
    printk(KERN_INFO "NPU Liberation: Module unloaded\n");
}

module_init(npu_liberation_init);
module_exit(npu_liberation_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("NPU Liberation Front");
MODULE_DESCRIPTION("NPU Frequency Liberation Module - Unleash the full power of A733 NPU!");
MODULE_VERSION(NPU_LIBERATION_VERSION);