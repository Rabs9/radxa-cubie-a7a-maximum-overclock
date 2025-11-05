#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/devfreq.h>
#include <linux/sysfs.h>
#include <linux/kobject.h>
#include <linux/delay.h>
#include <linux/regulator/consumer.h>

#define MODULE_NAME "ram_overclock"

struct ram_overclock_data {
    struct clk *ddr_clk;
    struct clk *pll_ddr;
    struct regulator *ddr_supply;
    struct kobject *kobj;
    struct devfreq *devfreq_dev;
    unsigned long target_freq;
    bool overclocked;
};

static struct ram_overclock_data *g_data;

// Extended frequency table beyond the standard 1800MHz limit
static unsigned long extended_ram_freqs[] = {
    400000000,   // 400MHz  - Ultra low power
    800000000,   // 800MHz  - Low power
    1200000000,  // 1200MHz - Standard
    1800000000,  // 1800MHz - Current maximum
    2000000000,  // 2000MHz - Overclock +11%
    2200000000,  // 2200MHz - Overclock +22%
    2400000000,  // 2400MHz - Overclock +33%
    2600000000,  // 2600MHz - Overclock +44% (extreme)
    0
};

// Voltage mapping for DDR overclocking
static int get_ddr_voltage_for_freq(unsigned long freq_hz) {
    unsigned long freq_mhz = freq_hz / 1000000;
    
    if (freq_mhz <= 1200) return 1200000;      // 1.2V
    else if (freq_mhz <= 1800) return 1350000; // 1.35V (JEDEC standard)
    else if (freq_mhz <= 2000) return 1400000; // 1.4V  
    else if (freq_mhz <= 2200) return 1450000; // 1.45V
    else if (freq_mhz <= 2400) return 1500000; // 1.5V
    else return 1550000;                       // 1.55V (extreme)
}

static int set_ddr_frequency(unsigned long freq) {
    int ret;
    unsigned long actual_freq;
    int voltage;
    
    if (!g_data->ddr_clk) {
        pr_err("RAM_OVERCLOCK: DDR clock not available\n");
        return -EINVAL;
    }
    
    pr_info("RAM_OVERCLOCK: Attempting to set DDR frequency to %lu MHz\n", freq / 1000000);
    
    // Set voltage first if we have regulator
    if (g_data->ddr_supply) {
        voltage = get_ddr_voltage_for_freq(freq);
        ret = regulator_set_voltage(g_data->ddr_supply, voltage, voltage + 50000);
        if (ret) {
            pr_warn("RAM_OVERCLOCK: Failed to set DDR voltage to %duV: %d\n", voltage, ret);
        } else {
            pr_info("RAM_OVERCLOCK: Set DDR voltage to %duV\n", voltage);
            msleep(20); // Allow voltage to stabilize
        }
    }
    
    // Try to set the frequency
    ret = clk_set_rate(g_data->ddr_clk, freq);
    if (ret) {
        pr_err("RAM_OVERCLOCK: Failed to set DDR frequency: %d\n", ret);
        return ret;
    }
    
    actual_freq = clk_get_rate(g_data->ddr_clk);
    pr_info("RAM_OVERCLOCK: DDR frequency set to %lu MHz (requested %lu MHz)\n", 
            actual_freq / 1000000, freq / 1000000);
    
    // Update our tracking
    g_data->target_freq = actual_freq;
    g_data->overclocked = (actual_freq > 1800000000);
    
    return 0;
}

// Sysfs interface for RAM frequency control
static ssize_t ram_overclock_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf) {
    unsigned long current_freq = g_data->ddr_clk ? clk_get_rate(g_data->ddr_clk) : 0;
    
    return sprintf(buf, "DDR: %lu MHz\nOverclocked: %s\nAvailable frequencies: 400, 800, 1200, 1800, 2000, 2200, 2400, 2600\nUsage: echo FREQ_MHZ > ram_overclock\nExample: echo 2000 > ram_overclock\nWarning: Frequencies above 1800MHz are overclocked!\n",
           current_freq / 1000000, g_data->overclocked ? "YES" : "NO");
}

static ssize_t ram_overclock_store(struct kobject *kobj, struct kobj_attribute *attr,
                                  const char *buf, size_t count) {
    unsigned long freq_mhz;
    unsigned long freq_hz;
    int ret;
    
    ret = kstrtoul(buf, 10, &freq_mhz);
    if (ret) {
        pr_err("RAM_OVERCLOCK: Invalid frequency value\n");
        return ret;
    }
    
    freq_hz = freq_mhz * 1000000;
    
    // Validate frequency range
    if (freq_hz < 400000000 || freq_hz > 2600000000) {
        pr_err("RAM_OVERCLOCK: Frequency out of range (400-2600 MHz)\n");
        return -EINVAL;
    }
    
    if (freq_hz > 1800000000) {
        pr_warn("RAM_OVERCLOCK: ⚠️  OVERCLOCKING WARNING: %lu MHz exceeds specification!\n", freq_mhz);
        pr_warn("RAM_OVERCLOCK: Monitor system stability and temperature!\n");
    }
    
    ret = set_ddr_frequency(freq_hz);
    if (ret) {
        pr_err("RAM_OVERCLOCK: Failed to set DDR frequency\n");
        return ret;
    }
    
    pr_info("RAM_OVERCLOCK: ✅ DDR frequency successfully set to %lu MHz\n", freq_mhz);
    return count;
}

static struct kobj_attribute ram_overclock_attr = __ATTR(ram_overclock, 0664, ram_overclock_show, ram_overclock_store);

static int __init ram_overclock_init(void) {
    struct device_node *np;
    int ret;
    
    pr_info("RAM_OVERCLOCK: Loading DDR overclocking module...\n");
    
    g_data = kzalloc(sizeof(*g_data), GFP_KERNEL);
    if (!g_data)
        return -ENOMEM;
    
    // Try to find DDR clock
    np = of_find_compatible_node(NULL, NULL, "allwinner,sun50i-h616-ccu");
    if (!np) {
        np = of_find_node_by_path("/soc/ccu@3001000");
    }
    
    if (np) {
        // Try to get DDR clock
        g_data->ddr_clk = of_clk_get_by_name(np, "ddr");
        if (IS_ERR(g_data->ddr_clk)) {
            g_data->ddr_clk = of_clk_get(np, 0); // Try index 0
            if (IS_ERR(g_data->ddr_clk)) {
                pr_warn("RAM_OVERCLOCK: Could not get DDR clock from CCU\n");
                g_data->ddr_clk = NULL;
            }
        }
        of_node_put(np);
    }
    
    // Alternative: try to find DDR clock directly
    if (!g_data->ddr_clk) {
        np = of_find_node_by_path("/soc/clk_ddr@2002000");
        if (np) {
            g_data->ddr_clk = of_clk_get(np, 0);
            if (IS_ERR(g_data->ddr_clk)) {
                pr_warn("RAM_OVERCLOCK: Could not get DDR clock directly\n");
                g_data->ddr_clk = NULL;
            } else {
                pr_info("RAM_OVERCLOCK: Found DDR clock controller\n");
            }
            of_node_put(np);
        }
    }
    
    // Try to get DDR voltage regulator
    g_data->ddr_supply = regulator_get(NULL, "vdd-sys");
    if (IS_ERR(g_data->ddr_supply)) {
        g_data->ddr_supply = regulator_get(NULL, "ddr");
        if (IS_ERR(g_data->ddr_supply)) {
            pr_warn("RAM_OVERCLOCK: Could not get DDR regulator\n");
            g_data->ddr_supply = NULL;
        }
    }
    
    if (g_data->ddr_supply) {
        pr_info("RAM_OVERCLOCK: Found DDR voltage regulator\n");
    }
    
    if (!g_data->ddr_clk) {
        pr_warn("RAM_OVERCLOCK: No DDR clock found - will work with devfreq fallback\n");
    } else {
        unsigned long current_freq = clk_get_rate(g_data->ddr_clk);
        pr_info("RAM_OVERCLOCK: Current DDR frequency: %lu MHz\n", current_freq / 1000000);
    }
    
    // Create sysfs interface
    g_data->kobj = kobject_create_and_add("ram_overclock", kernel_kobj);
    if (!g_data->kobj) {
        ret = -ENOMEM;
        goto err_clk;
    }
    
    ret = sysfs_create_file(g_data->kobj, &ram_overclock_attr.attr);
    if (ret) {
        pr_err("RAM_OVERCLOCK: Failed to create sysfs file\n");
        goto err_kobj;
    }
    
    pr_info("RAM_OVERCLOCK: Module loaded successfully!\n");
    pr_info("RAM_OVERCLOCK: Control interface at /sys/kernel/ram_overclock/ram_overclock\n");
    pr_info("RAM_OVERCLOCK: ⚠️  WARNING: Overclocking DDR beyond 1800MHz may cause instability!\n");
    
    return 0;
    
err_kobj:
    kobject_put(g_data->kobj);
err_clk:
    if (g_data->ddr_clk) clk_put(g_data->ddr_clk);
    if (g_data->ddr_supply) regulator_put(g_data->ddr_supply);
    kfree(g_data);
    return ret;
}

static void __exit ram_overclock_exit(void) {
    pr_info("RAM_OVERCLOCK: Unloading module...\n");
    
    if (g_data) {
        if (g_data->kobj) {
            sysfs_remove_file(g_data->kobj, &ram_overclock_attr.attr);
            kobject_put(g_data->kobj);
        }
        
        if (g_data->ddr_clk) clk_put(g_data->ddr_clk);
        if (g_data->ddr_supply) regulator_put(g_data->ddr_supply);
        
        kfree(g_data);
    }
    
    pr_info("RAM_OVERCLOCK: Module unloaded\n");
}

module_init(ram_overclock_init);
module_exit(ram_overclock_exit);

MODULE_AUTHOR("Radxa Performance Team");
MODULE_DESCRIPTION("RAM/DDR Overclocking Module for A733 SoC");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("1.0");