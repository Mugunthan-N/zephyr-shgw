---
type: guideline
scope: project-specific
version: "1.0.0"
domain: coding-patterns
agents: [all]
---

# zephyr-shgw — Coding Patterns

## Module Structure Pattern

Every module under `src/<module>/` follows this structure:

```c
/* src/<module>/<module>.h — Public API header */
#ifndef <MODULE>_H_
#define <MODULE>_H_

#include <zephyr/kernel.h>

/** @brief Initialize the module. Called once from main(). */
int <module>_init(void);

/** @brief Public API functions */
int <module>_do_something(uint8_t param);

#endif /* <MODULE>_H_ */
```

```c
/* src/<module>/<module>.c — Implementation */
#include "<module>.h"
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(<module>, CONFIG_<MODULE>_LOG_LEVEL);

/* Private state — file-scoped static */
static struct {
    bool initialized;
    /* module state fields */
} state;

/* Private helpers — static functions */
static int internal_helper(void) { ... }

/* Public API */
int <module>_init(void) {
    if (state.initialized) {
        LOG_WRN("Already initialized");
        return -EALREADY;
    }
    /* init work */
    state.initialized = true;
    LOG_INF("Initialized");
    return 0;
}
```

**Key conventions:**
- One `.h` and one `.c` per module (split into multiple `.c` files only for large modules like `zwave_host`).
- Module state is a file-scoped `static struct`.
- All public functions prefixed with module name: `wifi_mgr_connect()`, `shadow_mgr_update()`.
- Module init returns `int` (0 on success, negative errno on failure).

## Error Handling Pattern

Use Zephyr-style negative errno return codes consistently:

```c
int wifi_mgr_connect(const char *ssid, const char *psk)
{
    if (!ssid || !psk) {
        LOG_ERR("Invalid params: ssid=%p psk=%p", ssid, psk);
        return -EINVAL;
    }

    int ret = net_mgmt(NET_REQUEST_WIFI_CONNECT, iface, &params, sizeof(params));
    if (ret < 0) {
        LOG_ERR("WiFi connect failed: %d", ret);
        return ret;
    }

    return 0;
}
```

**Conventions:**
- Return `0` for success, negative errno for failure (`-EINVAL`, `-ENOMEM`, `-ETIMEDOUT`, `-EIO`, `-ENOENT`).
- Log at `LOG_ERR` for failures, `LOG_WRN` for recoverable issues, `LOG_INF` for normal operations, `LOG_DBG` for debug tracing.
- Include operation context in error messages: what was attempted, with what parameters.
- Use early returns for parameter validation.

## Thread Pattern

Each module that runs its own thread follows this pattern:

```c
#define MY_THREAD_STACK_SIZE 4096
#define MY_THREAD_PRIORITY   2

K_THREAD_STACK_DEFINE(my_stack, MY_THREAD_STACK_SIZE);
static struct k_thread my_thread_data;
static k_tid_t my_tid;

static void my_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1); ARG_UNUSED(p2); ARG_UNUSED(p3);

    LOG_INF("Thread started");

    while (true) {
        /* Wait for work (message queue, event, semaphore) */
        struct my_msg msg;
        int ret = k_msgq_get(&my_msgq, &msg, K_FOREVER);
        if (ret != 0) {
            continue;
        }

        /* Process message */
        handle_message(&msg);
    }
}

int my_module_init(void)
{
    my_tid = k_thread_create(&my_thread_data, my_stack,
                             K_THREAD_STACK_SIZEOF(my_stack),
                             my_thread_entry, NULL, NULL, NULL,
                             MY_THREAD_PRIORITY, 0, K_NO_WAIT);
    k_thread_name_set(my_tid, "my_module");
    return 0;
}
```

**Conventions:**
- Thread entry function takes `(void *p1, void *p2, void *p3)` with `ARG_UNUSED`.
- Thread loops forever, blocked on an IPC primitive (never busy-wait).
- Thread has a descriptive name set via `k_thread_name_set`.
- Stack size and priority are `#define` constants at the top of the file.

## Event Bus Pattern

Cross-module communication uses message queues and event flags:

```c
/* src/common/event_bus.h */
enum system_event {
    EVENT_WIFI_CONNECTED    = BIT(0),
    EVENT_WIFI_DISCONNECTED = BIT(1),
    EVENT_MQTT_CONNECTED    = BIT(2),
    EVENT_MQTT_DISCONNECTED = BIT(3),
    EVENT_SHUTDOWN          = BIT(4),
    EVENT_WIFI_FAILED       = BIT(5),
    EVENT_OTA_AVAILABLE     = BIT(6),
};

/* Broadcast: System Manager posts, all threads listen */
extern struct k_event sys_events;

/* Point-to-point: typed message queues between specific modules */
struct shadow_update_msg {
    uint8_t node_id;
    char    property[32];
    int32_t value;
};
extern struct k_msgq shadow_update_queue;
```

**Conventions:**
- Broadcast events use `k_event` (bit flags) — posted by System Manager.
- Point-to-point messages use `k_msgq` — typed structs between specific producer/consumer pairs.
- Event enum values use `BIT(n)` macros for flag composition.
- Queue and event objects are declared `extern` in headers, defined in the owning module's `.c`.

## Logging Pattern

Use Zephyr's logging subsystem with per-module log levels:

```c
#include <zephyr/logging/log.h>
LOG_MODULE_REGISTER(wifi_mgr, CONFIG_WIFI_MGR_LOG_LEVEL);

/* Usage */
LOG_INF("WiFi connected to %s, IP: %s", ssid, ip_str);
LOG_WRN("RSSI low: %d dBm", rssi);
LOG_ERR("DHCP failed: %d", ret);
LOG_DBG("Scan result: channel=%d rssi=%d", chan, rssi);
```

**Conventions:**
- Every `.c` file registers its own log module with `LOG_MODULE_REGISTER`.
- Log level is controlled via Kconfig: `CONFIG_<MODULE>_LOG_LEVEL`.
- Use deferred logging mode (`CONFIG_LOG_MODE_DEFERRED`) — never block in logging.
- Never log sensitive data (passwords, keys, certificates).

## LittleFS File I/O Pattern

```c
#include <zephyr/fs/fs.h>

int storage_write_json(const char *path, const char *json_str)
{
    char tmp_path[64];
    snprintf(tmp_path, sizeof(tmp_path), "%s.tmp", path);

    struct fs_file_t file;
    fs_file_t_init(&file);

    int ret = fs_open(&file, tmp_path, FS_O_WRITE | FS_O_CREATE);
    if (ret < 0) {
        LOG_ERR("Failed to open %s: %d", tmp_path, ret);
        return ret;
    }

    ret = fs_write(&file, json_str, strlen(json_str));
    fs_close(&file);

    if (ret < 0) {
        LOG_ERR("Failed to write %s: %d", tmp_path, ret);
        return ret;
    }

    ret = fs_rename(tmp_path, path);
    if (ret < 0) {
        LOG_ERR("Failed to rename %s -> %s: %d", tmp_path, path, ret);
    }
    return ret;
}
```

**Conventions:**
- Always use write-then-rename for critical files (atomic on power loss).
- Always call `fs_file_t_init()` before first use.
- Always check return codes from `fs_open`, `fs_write`, `fs_close`, `fs_rename`.
- File paths use the mount point `/lfs/` prefix.

## JSON Pattern (cJSON)

```c
#include "common/json_utils.h"  /* Project's cJSON wrappers */

int shadow_parse_delta(const char *json_str, struct shadow_delta *delta)
{
    cJSON *root = cJSON_Parse(json_str);
    if (!root) {
        LOG_ERR("JSON parse failed");
        return -EINVAL;
    }

    cJSON *state = cJSON_GetObjectItem(root, "state");
    if (!state) {
        cJSON_Delete(root);
        return -ENOENT;
    }

    /* Extract fields */
    cJSON *val = cJSON_GetObjectItem(state, "binary_switch");
    if (cJSON_IsBool(val)) {
        delta->binary_switch = cJSON_IsTrue(val);
    }

    cJSON_Delete(root);  /* ALWAYS free */
    return 0;
}
```

**Conventions:**
- Always `cJSON_Delete(root)` to free parsed JSON (avoid memory leaks).
- Check `cJSON_Parse` return for NULL.
- Check `cJSON_GetObjectItem` return before accessing.
- Use project wrappers in `json_utils.h` for common operations.
- Parse buffers must not exceed 4 KB (rule R-PF-002).

## Configuration Loading Pattern

Config is loaded from LittleFS JSON files and NVS at boot:

```c
/* LittleFS JSON config */
int config_load_wifi(struct wifi_config *cfg)
{
    char buf[256];
    int ret = storage_read_file("/lfs/config/wifi.json", buf, sizeof(buf));
    if (ret < 0) return ret;

    return wifi_config_parse_json(buf, cfg);
}

/* NVS key-value config */
int config_get_provisioned(bool *provisioned)
{
    uint8_t val;
    int ret = nvs_read(&nvs_fs, NVS_ID_PROVISIONED, &val, sizeof(val));
    if (ret < 0) {
        *provisioned = false;
        return 0;  /* Default to not provisioned */
    }
    *provisioned = (val == 1);
    return 0;
}
```
