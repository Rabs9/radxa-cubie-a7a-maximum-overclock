#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/sysfs.h>
#include <linux/kobject.h>
#include <linux/pwm.h>
#include <linux/reboot.h>
#include <linux/notifier.h>
#include <linux/delay.h>
#include <linux/thermal.h>
#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/uaccess.h>

#define MODULE_NAME "fan_control"
#define FAN_PWM_PATH "/sys/devices/platform/pwm-fan/hwmon/hwmon8/pwm1"

struct fan_control_data {
    struct kobject *kobj;
    struct notifier_block reboot_notifier;
    int current_speed;
    int max_speed;
    bool thermal_control;
    int temp_threshold_low;
    int temp_threshold_high;
};

static struct fan_control_data *g_fan_data;

// Write to sysfs file helper
static int write_sysfs_int(const char *path, int value) {
    struct file *file;
    char buffer[16];
    ssize_t ret;
    loff_t pos = 0;
    
    file = filp_open(path, O_WRONLY, 0);
    if (IS_ERR(file)) {
        pr_err("FAN_CONTROL: Cannot open %s\n", path);
        return PTR_ERR(file);
    }
    
    snprintf(buffer, sizeof(buffer), "%d", value);
    ret = kernel_write(file, buffer, strlen(buffer), &pos);
    filp_close(file, NULL);
    
    if (ret < 0) {
        pr_err("FAN_CONTROL: Failed to write to %s\n", path);
        return ret;
    }
    
    return 0;
}

// Set fan speed (0-255)
static int set_fan_speed(int speed) {
    int ret;
    
    if (speed < 0) speed = 0;
    if (speed > 255) speed = 255;
    
    ret = write_sysfs_int(FAN_PWM_PATH, speed);
    if (ret == 0) {
        g_fan_data->current_speed = speed;
        pr_info("FAN_CONTROL: Fan speed set to %d (%.1f%%)\n", 
                speed, (speed * 100.0) / 255.0);
    }
    
    return ret;
}

// Shutdown/reboot notifier - ensures fan turns off
static int fan_reboot_notifier(struct notifier_block *nb, unsigned long action, void *data) {
    pr_info("FAN_CONTROL: System %s detected, turning off fan...\n", 
            action == SYS_HALT ? "halt" : 
            action == SYS_POWER_OFF ? "power off" : "reboot");
    
    // Turn off fan before shutdown
    set_fan_speed(0);
    msleep(100); // Give time for fan to stop
    
    pr_info("FAN_CONTROL: Fan turned off for shutdown\n");
    return NOTIFY_OK;
}

// Thermal-based fan control
static int get_cpu_temperature(void) {
    struct thermal_zone_device *tz;
    int temp = 0;
    
    tz = thermal_zone_get_zone_by_name("cpu-thermal");
    if (!IS_ERR(tz)) {
        thermal_zone_get_temp(tz, &temp);
        temp /= 1000; // Convert from millidegrees to degrees
    }
    
    return temp;
}

static void adjust_fan_for_temperature(void) {
    int temp = get_cpu_temperature();
    int new_speed;
    
    if (temp <= 0) return; // Invalid temperature
    
    if (temp < g_fan_data->temp_threshold_low) {
        new_speed = 64;  // 25% - Low speed
    } else if (temp < g_fan_data->temp_threshold_high) {
        // Linear scaling between thresholds
        int temp_range = g_fan_data->temp_threshold_high - g_fan_data->temp_threshold_low;
        int temp_offset = temp - g_fan_data->temp_threshold_low;
        new_speed = 64 + (191 * temp_offset) / temp_range; // 25% to 100%
    } else {
        new_speed = 255; // 100% - Maximum speed
    }
    
    if (new_speed != g_fan_data->current_speed) {
        pr_info("FAN_CONTROL: Temperature %d°C, adjusting fan to %d\n", temp, new_speed);
        set_fan_speed(new_speed);
    }
}

// Sysfs interface for fan control
static ssize_t fan_speed_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf) {
    int temp = get_cpu_temperature();
    return sprintf(buf, "Fan Speed: %d/255 (%.1f%%)\nTemperature: %d°C\nThermal Control: %s\nTemp Thresholds: %d°C - %d°C\nUsage:\n  echo SPEED > fan_speed (0-255)\n  echo thermal > fan_speed (enable thermal control)\n  echo manual > fan_speed (disable thermal control)\n",
           g_fan_data->current_speed, 
           (g_fan_data->current_speed * 100.0) / 255.0,
           temp,
           g_fan_data->thermal_control ? "ON" : "OFF",
           g_fan_data->temp_threshold_low,
           g_fan_data->temp_threshold_high);
}

static ssize_t fan_speed_store(struct kobject *kobj, struct kobj_attribute *attr,
                              const char *buf, size_t count) {
    char command[16];
    int speed;
    int ret;
    
    if (sscanf(buf, "%15s", command) != 1) {
        pr_err("FAN_CONTROL: Invalid input\n");
        return -EINVAL;
    }
    
    if (strcmp(command, "thermal") == 0) {
        g_fan_data->thermal_control = true;
        adjust_fan_for_temperature();
        pr_info("FAN_CONTROL: Thermal control enabled\n");
        return count;
    } else if (strcmp(command, "manual") == 0) {
        g_fan_data->thermal_control = false;
        pr_info("FAN_CONTROL: Manual control enabled\n");
        return count;
    } else if (strcmp(command, "off") == 0) {
        g_fan_data->thermal_control = false;
        set_fan_speed(0);
        return count;
    } else if (strcmp(command, "max") == 0) {
        g_fan_data->thermal_control = false;
        set_fan_speed(255);
        return count;
    }
    
    // Try to parse as number
    ret = kstrtoint(command, 10, &speed);
    if (ret) {
        pr_err("FAN_CONTROL: Invalid speed value\n");
        return ret;
    }
    
    g_fan_data->thermal_control = false;
    ret = set_fan_speed(speed);
    if (ret) return ret;
    
    return count;
}

static struct kobj_attribute fan_speed_attr = __ATTR(fan_speed, 0664, fan_speed_show, fan_speed_store);

static int __init fan_control_init(void) {
    int ret;
    
    pr_info("FAN_CONTROL: Loading advanced fan control module...\n");
    
    g_fan_data = kzalloc(sizeof(*g_fan_data), GFP_KERNEL);
    if (!g_fan_data)
        return -ENOMEM;
    
    // Initialize defaults
    g_fan_data->current_speed = 255; // Start at max
    g_fan_data->max_speed = 255;
    g_fan_data->thermal_control = false;
    g_fan_data->temp_threshold_low = 50;  // 50°C
    g_fan_data->temp_threshold_high = 75; // 75°C
    
    // Register reboot notifier to turn off fan on shutdown
    g_fan_data->reboot_notifier.notifier_call = fan_reboot_notifier;
    ret = register_reboot_notifier(&g_fan_data->reboot_notifier);
    if (ret) {
        pr_err("FAN_CONTROL: Failed to register reboot notifier\n");
        goto err_free;
    }
    
    // Create sysfs interface
    g_fan_data->kobj = kobject_create_and_add("fan_control", kernel_kobj);
    if (!g_fan_data->kobj) {
        ret = -ENOMEM;
        goto err_notifier;
    }
    
    ret = sysfs_create_file(g_fan_data->kobj, &fan_speed_attr.attr);
    if (ret) {
        pr_err("FAN_CONTROL: Failed to create sysfs file\n");
        goto err_kobj;
    }
    
    // Set initial fan speed
    set_fan_speed(255);
    
    pr_info("FAN_CONTROL: Module loaded successfully!\n");
    pr_info("FAN_CONTROL: Control interface at /sys/kernel/fan_control/fan_speed\n");
    pr_info("FAN_CONTROL: Fan will automatically turn off on system shutdown\n");
    pr_info("FAN_CONTROL: Temperature-based control available\n");
    
    return 0;
    
err_kobj:
    kobject_put(g_fan_data->kobj);
err_notifier:
    unregister_reboot_notifier(&g_fan_data->reboot_notifier);
err_free:
    kfree(g_fan_data);
    return ret;
}

static void __exit fan_control_exit(void) {
    pr_info("FAN_CONTROL: Unloading module...\n");
    
    if (g_fan_data) {
        // Turn off fan
        set_fan_speed(0);
        
        if (g_fan_data->kobj) {
            sysfs_remove_file(g_fan_data->kobj, &fan_speed_attr.attr);
            kobject_put(g_fan_data->kobj);
        }
        
        unregister_reboot_notifier(&g_fan_data->reboot_notifier);
        kfree(g_fan_data);
    }
    
    pr_info("FAN_CONTROL: Module unloaded\n");
}

module_init(fan_control_init);
module_exit(fan_control_exit);

MODULE_AUTHOR("Radxa Performance Team");
MODULE_DESCRIPTION("Advanced Fan Control with Shutdown Management");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("1.0");