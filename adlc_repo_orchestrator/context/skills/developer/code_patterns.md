---
type: skill
scope: project-specific
version: "1.0.0"
domain: developer
agents: [developer]
---

# Developer Skills — zephyr-shgw

## Runtime Constraints

### Language & Standard
- **C11** (Zephyr-compatible subset). No C++ unless a Zephyr module requires it.
- **No POSIX APIs**: Use Zephyr kernel APIs exclusively (`k_thread`, `k_msgq`, `k_sem`, `k_event`, `k_timer`, `k_work`, `k_fifo`).
- **No `malloc` in ISRs**: ISR context must use only static buffers, ring buffers, or FIFOs.
- **No floating point in ISRs or high-priority threads**: Use integer math with scaling.

### Prohibited Patterns
- `pthread_*` — use `k_thread`, `k_mutex`, `k_sem` instead
- `sleep()` / `usleep()` — use `k_sleep(K_MSEC(...))` instead
- `printf` / `fprintf` — use `LOG_INF`, `LOG_ERR`, `LOG_WRN`, `LOG_DBG` instead
- `assert()` in production code — use `__ASSERT` (Zephyr, debug only) or proper error returns
- `malloc` / `free` in thread context — prefer static allocation; use `k_heap_alloc` only for JSON parse buffers with bounded size
- Busy-wait loops (`while (!ready) {}`) — use `k_sem_take`, `k_event_wait`, or `k_msgq_get` with timeout

### Required Wrappers
- **File I/O**: Use `storage_mgr` API for all LittleFS and NVS operations. Do not call `fs_open`/`fs_write` directly from application modules (except within `storage_mgr` itself).
- **JSON**: Use `json_utils.h` wrappers for cJSON. Always call `cJSON_Delete()` after parsing.
- **Events**: Use `event_bus.h` macros/types for cross-module events. Do not create ad-hoc global variables.

## Module Template

```c
/* =========================================================================
 * src/<module>/<module>.h — Public API
 * ========================================================================= */
#ifndef <MODULE>_H_
#define <MODULE>_H_

#include <zephyr/kernel.h>
#include <stdint.h>
#include <stdbool.h>

/**
 * @brief Initialize the <module> subsystem.
 * @return 0 on success, negative errno on failure.
 */
int <module>_init(void);

/* Public API functions — all prefixed with <module>_ */

#endif /* <MODULE>_H_ */
```

```c
/* =========================================================================
 * src/<module>/<module>.c — Implementation
 * ========================================================================= */
#include "<module>.h"
#include "common/event_bus.h"
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(<module>, CONFIG_<MODULE>_LOG_LEVEL);

/* ----- Constants ----- */
#define <MODULE>_THREAD_STACK_SIZE  4096
#define <MODULE>_THREAD_PRIORITY   2

/* ----- Private state ----- */
static struct {
    bool initialized;
    /* other module state */
} state;

/* ----- Thread ----- */
K_THREAD_STACK_DEFINE(<module>_stack, <MODULE>_THREAD_STACK_SIZE);
static struct k_thread <module>_thread_data;

/* ----- Message queue (if needed) ----- */
K_MSGQ_DEFINE(<module>_msgq, sizeof(struct <module>_msg), 8, 4);

/* ----- Private functions ----- */
static void <module>_thread_entry(void *p1, void *p2, void *p3)
{
    ARG_UNUSED(p1); ARG_UNUSED(p2); ARG_UNUSED(p3);
    LOG_INF("Thread started");

    while (true) {
        struct <module>_msg msg;
        int ret = k_msgq_get(&<module>_msgq, &msg, K_FOREVER);
        if (ret != 0) {
            LOG_WRN("msgq get failed: %d", ret);
            continue;
        }
        /* Process message */
    }
}

/* ----- Public API ----- */
int <module>_init(void)
{
    if (state.initialized) {
        LOG_WRN("Already initialized");
        return -EALREADY;
    }

    /* Module-specific initialization */

    k_tid_t tid = k_thread_create(
        &<module>_thread_data, <module>_stack,
        K_THREAD_STACK_SIZEOF(<module>_stack),
        <module>_thread_entry, NULL, NULL, NULL,
        <MODULE>_THREAD_PRIORITY, 0, K_NO_WAIT);
    k_thread_name_set(tid, "<module>");

    state.initialized = true;
    LOG_INF("Initialized");
    return 0;
}
```

## Z-Wave Serial API Frame Construction

```c
/* Serial API frame format:
 * SOF (0x01) | Length | Type (REQ=0x00/RES=0x01) | FuncID | Params... | Checksum (XOR)
 */
#define SERIAL_API_SOF  0x01
#define SERIAL_API_ACK  0x06
#define SERIAL_API_NAK  0x15
#define SERIAL_API_CAN  0x18

#define SERIAL_API_REQ  0x00
#define SERIAL_API_RES  0x01

static uint8_t serial_api_checksum(const uint8_t *buf, size_t len)
{
    uint8_t checksum = 0xFF;
    for (size_t i = 0; i < len; i++) {
        checksum ^= buf[i];
    }
    return checksum;
}

static int serial_api_build_frame(uint8_t *frame, size_t frame_size,
                                   uint8_t func_id, const uint8_t *params,
                                   size_t param_len)
{
    size_t total = 3 + param_len + 1; /* length + type + funcid + params + checksum */
    if (total + 1 > frame_size) return -ENOMEM;

    frame[0] = SERIAL_API_SOF;
    frame[1] = (uint8_t)(param_len + 3); /* length: type + funcid + params + checksum */
    frame[2] = SERIAL_API_REQ;
    frame[3] = func_id;
    if (param_len > 0) {
        memcpy(&frame[4], params, param_len);
    }
    frame[4 + param_len] = serial_api_checksum(&frame[1], 3 + param_len);
    return (int)(5 + param_len);
}
```

## Shadow JSON Construction

```c
/* Build a reported state update for a Z-Wave device shadow */
static int shadow_build_device_reported(uint8_t node_id,
                                         const struct zwave_device *dev,
                                         char *buf, size_t buf_size)
{
    cJSON *root = cJSON_CreateObject();
    cJSON *state = cJSON_AddObjectToObject(root, "state");
    cJSON *reported = cJSON_AddObjectToObject(state, "reported");

    cJSON_AddBoolToObject(reported, "binary_switch", dev->switch_on);
    cJSON_AddNumberToObject(reported, "dimmer_level", dev->dimmer_level);
    cJSON_AddStringToObject(reported, "device_type", dev->type_str);
    cJSON_AddStringToObject(reported, "name", dev->name);
    cJSON_AddBoolToObject(reported, "is_reachable", dev->is_reachable);

    char *json_str = cJSON_PrintUnformatted(root);
    if (!json_str) {
        cJSON_Delete(root);
        return -ENOMEM;
    }

    int len = snprintf(buf, buf_size, "%s", json_str);
    cJSON_free(json_str);
    cJSON_Delete(root);

    return (len < (int)buf_size) ? 0 : -ENOSPC;
}
```

## MQTT Topic Construction

```c
/* Shadow topic patterns */
#define SHADOW_TOPIC_FMT "$aws/things/%s/shadow/name/%s/%s"

static int mqtt_build_shadow_topic(char *buf, size_t buf_size,
                                    const char *thing_name,
                                    const char *shadow_name,
                                    const char *action)
{
    int len = snprintf(buf, buf_size, SHADOW_TOPIC_FMT,
                       thing_name, shadow_name, action);
    return (len > 0 && len < (int)buf_size) ? 0 : -ENOSPC;
}
```

## BLE GATT Service Pattern

```c
/* Define provisioning service UUID and characteristics */
#define PROV_SVC_UUID BT_UUID_DECLARE_128(BT_UUID_128_ENCODE( \
    0xA1B2C3D4, 0xE5F6, 0x7890, 0xABCD, 0xEF1234567890))

/* Write handler with encryption requirement */
static ssize_t write_wifi_ssid(struct bt_conn *conn,
                                const struct bt_gatt_attr *attr,
                                const void *buf, uint16_t len,
                                uint16_t offset, uint8_t flags)
{
    if (len > WIFI_SSID_MAX_LEN) {
        return BT_GATT_ERR(BT_ATT_ERR_INVALID_ATTRIBUTE_LEN);
    }
    memcpy(prov_data.ssid, buf, len);
    prov_data.ssid[len] = '\0';
    prov_data.ssid_set = true;
    return len;
}

/* Service registration — encryption required */
BT_GATT_SERVICE_DEFINE(prov_svc,
    BT_GATT_PRIMARY_SERVICE(PROV_SVC_UUID),
    BT_GATT_CHARACTERISTIC(/* uuid */, BT_GATT_CHRC_WRITE,
        BT_GATT_PERM_WRITE_ENCRYPT,
        NULL, write_wifi_ssid, NULL),
);
```

## Shell Command Pattern

```c
#include <zephyr/shell/shell.h>

static int cmd_shg_info(const struct shell *sh, size_t argc, char **argv)
{
    ARG_UNUSED(argc); ARG_UNUSED(argv);

    shell_print(sh, "Firmware: %s", CONFIG_SHG_VERSION_STRING);
    shell_print(sh, "Board: %s", CONFIG_BOARD);
    shell_print(sh, "Uptime: %lld ms", k_uptime_get());
    return 0;
}

static int cmd_wifi_status(const struct shell *sh, size_t argc, char **argv)
{
    ARG_UNUSED(argc); ARG_UNUSED(argv);

    struct wifi_status status;
    wifi_mgr_get_status(&status);
    shell_print(sh, "SSID: %s", status.ssid);
    shell_print(sh, "IP: %s", status.ip);
    shell_print(sh, "RSSI: %d dBm", status.rssi);
    shell_print(sh, "State: %s", wifi_state_str(status.state));
    return 0;
}

SHELL_STATIC_SUBCMD_SET_CREATE(sub_shg,
    SHELL_CMD(info, NULL, "Print firmware info", cmd_shg_info),
    SHELL_CMD(reboot, NULL, "Reboot system", cmd_shg_reboot),
    SHELL_SUBCMD_SET_END
);
SHELL_CMD_REGISTER(shg, &sub_shg, "SHG commands", NULL);
```

## Kconfig Entry Pattern

```kconfig
# Application Kconfig
menuconfig SHG_WIFI_MGR
    bool "WiFi Manager"
    default y
    depends on WIFI && WIFI_NRF700X
    help
      WiFi connection manager with DHCP, reconnect,
      and RSSI monitoring.

if SHG_WIFI_MGR

config WIFI_MGR_LOG_LEVEL
    int "WiFi Manager log level"
    default 3
    range 0 4
    help
      0=OFF, 1=ERR, 2=WRN, 3=INF, 4=DBG

config WIFI_MGR_RECONNECT_MAX_BACKOFF_MS
    int "Max reconnect backoff (ms)"
    default 30000

endif # SHG_WIFI_MGR
```

## Error Return Code Conventions

<!-- Healed from task task-001: Developer missed init guards on 5 public APIs (F-001) and LOG_MODULE_REGISTER on shell files (F-004) -->

### Init Guards — Mandatory for All Public API Functions

Every public function in a module (except `_init()` itself) **MUST** include an init-guard check:

```c
if (!state.initialized) {
    LOG_ERR("<module> not initialized");
    return -EAGAIN;
}
```

Place this check **after** parameter validation but **before** any subsystem operations. This applies to ALL modules — storage_mgr, system_mgr, shell helpers, and any future modules. See `context/guidelines/coding_patterns.md` for the full pattern.

### LOG_MODULE_REGISTER — Required in ALL .c Files

**Every** `.c` file under `src/` must have `LOG_MODULE_REGISTER()`, including:
- Module implementation files (`storage_mgr.c`, `system_mgr.c`)
- Shell command files (`shell_shg.c`, `shell_fs.c`)
- Utility files, helpers, or any `.c` file that could produce log output

Shell files use the pattern: `LOG_MODULE_REGISTER(shell_shg, LOG_LEVEL_INF);` (or a Kconfig-controlled level).

| Return | Meaning | When |
|--------|---------|------|
| `0` | Success | Operation completed |
| `-EINVAL` | Invalid parameter | NULL pointer, out-of-range value |
| `-ENOMEM` | Out of memory | Buffer too small, heap exhausted |
| `-ETIMEDOUT` | Timeout | No response within deadline |
| `-EIO` | I/O error | UART, SPI, flash operation failed |
| `-ENOENT` | Not found | File missing, shadow not found |
| `-EALREADY` | Already done | Module already initialized, already connected |
| `-ENODEV` | Device not ready | Hardware device not initialized |
| `-ENOSPC` | No space | LittleFS full, buffer full, device table full |
| `-EBUSY` | Resource busy | Currently processing, try again later |
