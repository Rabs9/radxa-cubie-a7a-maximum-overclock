#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/clk.h>
#include <linux/clk-provider.h>
#include <linux/cpufreq.h>
#include <linux/sysfs.h>
#include <linux/kobject.h>
#include <linux/cpu.h>
#include <linux/delay.h>
#include <linux/regulator/consumer.h>

#define MODULE_NAME "cpu_overclock"
#define MAX_FREQS 16

struct cpu_overclock_data {
    struct clk *cpu_clk_e;  // Efficiency cores clock
    struct clk *cpu_clk_p;  // Performance cores clock
    struct regulator *cpu_supply;
    struct kobject *kobj;
    unsigned long target_freq_e;
    unsigned long target_freq_p;
    bool overclocked;
};

static struct cpu_overclock_data *g_data;

// Custom frequency tables (beyond OPP limits)
static unsigned long efficiency_freqs[] = {
    1200000000, 1404000000, 1512000000, 1608000000, 1704000000, 1794000000,
    1900000000, 2000000000, 2100000000, 0  // Experimental frequencies
};

static unsigned long performance_freqs[] = {
    1512000000, 1608000000, 1704000000, 1800000000, 1896000000, 2002000000,
    2200000000, 2400000000, 2600000000, 0  // Experimental frequencies
};

// Voltage mapping for overclocking (experimental)
static int get_voltage_for_freq(unsigned long freq_hz) {
    unsigned long freq_mhz = freq_hz / 1000000;
    
    if (freq_mhz <= 1800) return 1100000;      // 1.1V
    else if (freq_mhz <= 2000) return 1150000; // 1.15V
    else if (freq_mhz <= 2200) return 1200000; // 1.2V
    else if (freq_mhz <= 2400) return 1250000; // 1.25V
    else return 1300000;                       // 1.3V (extreme)
}

static int set_cpu_frequency(struct clk *clk, unsigned long freq, const char* cpu_type) {
    int ret;
    unsigned long actual_freq;
    
    if (!clk) {
        pr_err("CPU_OVERCLOCK: %s clock not available\n", cpu_type);
        return -EINVAL;
    }
    
    pr_info("CPU_OVERCLOCK: Setting %s CPU to %lu MHz\n", cpu_type, freq / 1000000);
    
    // Set voltage first if we have regulator
    if (g_data->cpu_supply) {
        int voltage = get_voltage_for_freq(freq);
        ret = regulator_set_voltage(g_data->cpu_supply, voltage, voltage + 50000);
        if (ret) {
            pr_warn("CPU_OVERCLOCK: Failed to set voltage to %duV: %d\n", voltage, ret);
        } else {
            pr_info("CPU_OVERCLOCK: Set voltage to %duV\n", voltage);
            msleep(10); // Allow voltage to stabilize
        }
    }
    
    // Set frequency
    ret = clk_set_rate(clk, freq);
    if (ret) {
        pr_err("CPU_OVERCLOCK: Failed to set %s frequency: %d\n", cpu_type, ret);
        return ret;
    }
    
    actual_freq = clk_get_rate(clk);
    pr_info("CPU_OVERCLOCK: %s CPU frequency set to %lu MHz (requested %lu MHz)\n", 
            cpu_type, actual_freq / 1000000, freq / 1000000);
    
    return 0;
}

// Sysfs interface for frequency control
static ssize_t overclock_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf) {
    unsigned long freq_e = g_data->cpu_clk_e ? clk_get_rate(g_data->cpu_clk_e) : 0;
    unsigned long freq_p = g_data->cpu_clk_p ? clk_get_rate(g_data->cpu_clk_p) : 0;
    
    return sprintf(buf, "CPU_E: %lu MHz\nCPU_P: %lu MHz\nOverclocked: %s\nAvailable E-core freqs: 1200,1404,1512,1608,1704,1794,1900,2000,2100\nAvailable P-core freqs: 1512,1608,1704,1800,1896,2002,2200,2400,2600\nUsage: echo 'E_FREQ,P_FREQ' > overclock (frequencies in MHz)\n",
           freq_e / 1000000, freq_p / 1000000, g_data->overclocked ? "YES" : "NO");
}

static ssize_t overclock_store(struct kobject *kobj, struct kobj_attribute *attr,
                              const char *buf, size_t count) {
    char *input, *token;
    unsigned long freq_e = 0, freq_p = 0;
    int ret;
    
    input = kstrndup(buf, count, GFP_KERNEL);
    if (!input)
        return -ENOMEM;
    
    // Parse "E_FREQ,P_FREQ" format
    token = strsep(&input, ",");
    if (token) {
        ret = kstrtoul(token, 10, &freq_e);
        if (ret) {
            pr_err("CPU_OVERCLOCK: Invalid efficiency core frequency\n");
            kfree(input);
            return ret;
        }
        freq_e *= 1000000; // Convert MHz to Hz
    }
    
    if (input) {
        ret = kstrtoul(input, 10, &freq_p);
        if (ret) {
            pr_err("CPU_OVERCLOCK: Invalid performance core frequency\n");
            kfree(input);
            return ret;
        }
        freq_p *= 1000000; // Convert MHz to Hz
    }
    
    kfree(input);
    
    if (freq_e == 0 && freq_p == 0) {
        pr_err("CPU_OVERCLOCK: No valid frequencies provided\n");
        return -EINVAL;
    }
    
    pr_info("CPU_OVERCLOCK: Attempting to set E-cores to %lu MHz, P-cores to %lu MHz\n",
            freq_e / 1000000, freq_p / 1000000);
    
    // Apply frequencies
    if (freq_e > 0 && g_data->cpu_clk_e) {
        ret = set_cpu_frequency(g_data->cpu_clk_e, freq_e, "Efficiency");
        if (ret) return ret;
        g_data->target_freq_e = freq_e;
    }
    
    if (freq_p > 0 && g_data->cpu_clk_p) {
        ret = set_cpu_frequency(g_data->cpu_clk_p, freq_p, "Performance");
        if (ret) return ret;
        g_data->target_freq_p = freq_p;
    }
    
    g_data->overclocked = (freq_e > 1794000000 || freq_p > 2002000000);
    
    pr_info("CPU_OVERCLOCK: Frequencies applied successfully!\n");
    return count;
}

static struct kobj_attribute overclock_attr = __ATTR(overclock, 0664, overclock_show, overclock_store);

static int __init cpu_overclock_init(void) {
    struct device_node *np;
    int ret;
    
    pr_info("CPU_OVERCLOCK: Loading CPU overclocking module...\n");
    
    g_data = kzalloc(sizeof(*g_data), GFP_KERNEL);
    if (!g_data)
        return -ENOMEM;
    
    // Try to find CPU clock sources
    np = of_find_node_by_path("/cpus/cpu@0");
    if (np) {
        g_data->cpu_clk_e = of_clk_get(np, 0);
        if (IS_ERR(g_data->cpu_clk_e)) {
            pr_warn("CPU_OVERCLOCK: Could not get efficiency core clock\n");
            g_data->cpu_clk_e = NULL;
        } else {
            pr_info("CPU_OVERCLOCK: Found efficiency core clock\n");
        }
        of_node_put(np);
    }
    
    np = of_find_node_by_path("/cpus/cpu@6");
    if (np) {
        g_data->cpu_clk_p = of_clk_get(np, 0);
        if (IS_ERR(g_data->cpu_clk_p)) {
            pr_warn("CPU_OVERCLOCK: Could not get performance core clock\n");
            g_data->cpu_clk_p = NULL;
        } else {
            pr_info("CPU_OVERCLOCK: Found performance core clock\n");
        }
        of_node_put(np);
    }
    
    // Try to get CPU voltage regulator
    g_data->cpu_supply = regulator_get(NULL, "cpu");
    if (IS_ERR(g_data->cpu_supply)) {
        pr_warn("CPU_OVERCLOCK: Could not get CPU regulator\n");
        g_data->cpu_supply = NULL;
    } else {
        pr_info("CPU_OVERCLOCK: Found CPU voltage regulator\n");
    }
    
    if (!g_data->cpu_clk_e && !g_data->cpu_clk_p) {
        pr_err("CPU_OVERCLOCK: No CPU clocks found!\n");
        ret = -ENODEV;
        goto err_free;
    }
    
    // Create sysfs interface
    g_data->kobj = kobject_create_and_add("cpu_overclock", kernel_kobj);
    if (!g_data->kobj) {
        ret = -ENOMEM;
        goto err_clk;
    }
    
    ret = sysfs_create_file(g_data->kobj, &overclock_attr.attr);
    if (ret) {
        pr_err("CPU_OVERCLOCK: Failed to create sysfs file\n");
        goto err_kobj;
    }
    
    pr_info("CPU_OVERCLOCK: Module loaded successfully!\n");
    pr_info("CPU_OVERCLOCK: Control interface at /sys/kernel/cpu_overclock/overclock\n");
    
    return 0;
    
err_kobj:
    kobject_put(g_data->kobj);
err_clk:
    if (g_data->cpu_clk_e) clk_put(g_data->cpu_clk_e);
    if (g_data->cpu_clk_p) clk_put(g_data->cpu_clk_p);
    if (g_data->cpu_supply) regulator_put(g_data->cpu_supply);
err_free:
    kfree(g_data);
    return ret;
}

static void __exit cpu_overclock_exit(void) {
    pr_info("CPU_OVERCLOCK: Unloading module...\n");
    
    if (g_data) {
        if (g_data->kobj) {
            sysfs_remove_file(g_data->kobj, &overclock_attr.attr);
            kobject_put(g_data->kobj);
        }
        
        if (g_data->cpu_clk_e) clk_put(g_data->cpu_clk_e);
        if (g_data->cpu_clk_p) clk_put(g_data->cpu_clk_p);
        if (g_data->cpu_supply) regulator_put(g_data->cpu_supply);
        
        kfree(g_data);
    }
    
    pr_info("CPU_OVERCLOCK: Module unloaded\n");
}

module_init(cpu_overclock_init);
module_exit(cpu_overclock_exit);

MODULE_AUTHOR("Radxa Performance Team");
MODULE_DESCRIPTION("CPU Overclocking Module for A733 SoC");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("1.0");