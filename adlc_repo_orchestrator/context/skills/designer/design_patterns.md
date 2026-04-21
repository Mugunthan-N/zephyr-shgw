---
type: skill
scope: project-specific
version: "1.0.0"
domain: designer
agents: [designer]
---

# Designer Skills — zephyr-shgw

## Project Context

Embedded firmware project: C on Zephyr RTOS (nRF5340). Designs must respect static allocation, fixed thread stacks, ISR constraints, and the layered architecture defined in the spec.

## Module Patterns

### New Module Structure

Every new module follows this file layout:

```
src/<module_name>/
├── <module_name>.h      ← Public API header (include guard, function prototypes)
├── <module_name>.c      ← Core implementation (init, thread entry, message handling)
├── <module_name>_internal.h  ← Private types/functions (optional, for large modules)
└── <module_name>_<aspect>.c  ← Split implementation (optional, e.g., zwave_host_frame.c)
```

### Module Init Pattern

```c
/* Every module provides an init function called from main.c */
int <module>_init(void);  /* Returns 0 on success, -errno on failure */

/* main.c initialization order (dependency-aware): */
storage_mgr_init();     /* Must be first — others depend on file I/O */
system_mgr_init();      /* State machine, WDT setup */
wifi_mgr_init();        /* WiFi driver init (no connect yet) */
mqtt_client_init();     /* MQTT client init (no connect yet) */
shadow_mgr_init();      /* Shadow structures init */
zwave_host_init();      /* Serial API init, UART setup */
ble_mgr_init();         /* BLE stack init */
rule_engine_init();     /* Rule table init */
power_mgr_init();       /* POFCON setup */
shell_cmds_init();      /* Register shell commands */
/* System Manager then drives state transitions to connect */
```

### Thread Design Checklist

When designing a new thread:

| Aspect | Design Decision Required |
|--------|--------------------------|
| **Priority** | Where in the priority map (0–15)? What does it preempt? What preempts it? |
| **Stack size** | Minimum required. Account for local variables, function call depth, and library usage. Start at 2048 B, increase if needed. |
| **IPC input** | What wakes this thread? Message queue, semaphore, event flag, timer? |
| **IPC output** | What does this thread produce? Messages to which queues? Event flags? |
| **Blocking behavior** | Maximum time this thread blocks. Must not exceed WDT timeout (8s) without feeding WDT. |
| **Resource access** | Does it access LittleFS? (Must go through storage_mgr.) Shared memory? (Must use k_mutex.) |

## File Placement Rules

| Content Type | Location |
|-------------|----------|
| Module source | `src/<module_name>/` |
| Module header (public) | `src/<module_name>/<module_name>.h` |
| Shared types and events | `src/common/event_bus.h` |
| JSON utilities | `src/common/json_utils.h` |
| Shell commands | `src/shell/cmd_<category>.c` |
| Unit tests | `tests/unit/test_<module_name>/` |
| Integration tests | `tests/integration/test_<scenario>/` |
| Kconfig definitions | `Kconfig` (application root) |
| Devicetree overlay | `app.overlay` or `boards/<board>.overlay` |
| Renode scripts | `scripts/renode/` |

## Architecture Decision Template

When making a non-trivial design decision, document it in the design.md:

```markdown
### Decision: <Brief Title>

**Context**: What situation or requirement drives this decision?

**Options Considered**:
1. **Option A**: <description> — Pros: ... Cons: ...
2. **Option B**: <description> — Pros: ... Cons: ...

**Chosen**: Option X

**Rationale**: Why this option best fits the constraints (memory, latency, complexity, Zephyr API availability).

**Consequences**: What this means for future development (dependencies, limitations).
```

## Design Patterns Specific to This Project

### Pattern: Shadow-Driven State Sync

For features that sync state between Z-Wave devices and AWS IoT:

```
Z-Wave Device → Serial API Frame → zwave_host parses → 
  k_msgq_put(shadow_update_queue, &msg) → 
  shadow_mgr builds JSON → mqtt_client publishes to shadow/update topic
```

Reverse path (cloud command):
```
AWS shadow delta → MQTT subscription → mqtt_client receives →
  k_msgq_put(shadow_delta_queue, &delta) →
  shadow_mgr parses JSON → identifies target device →
  k_msgq_put(zwave_cmd_queue, &cmd) →
  zwave_host sends Serial API frame to device
```

### Pattern: Offline Queue

When cloud is unreachable, state changes are queued:

```
State change → shadow_mgr checks MQTT connected?
  ├── Yes → publish immediately
  └── No → append to /lfs/shadow/pending.json (FIFO, max 64 entries)
       └── On reconnect: flush pending queue in order
```

### Pattern: Kconfig Feature Gate

Every optional feature must be gated by Kconfig:

```kconfig
# In application Kconfig
config SHG_RULE_ENGINE
    bool "Enable local rule engine"
    default y
    help
      Enables the IF-THEN rule evaluation engine for local
      automation when cloud is unreachable.
```

```c
/* In code */
#ifdef CONFIG_SHG_RULE_ENGINE
    rule_engine_init();
#endif
```

### Pattern: Zephyr UART Device for Serial API

```c
/* Get UART device from devicetree */
static const struct device *uart_dev = DEVICE_DT_GET(DT_NODELABEL(uart1));

/* Verify device is ready */
if (!device_is_ready(uart_dev)) {
    LOG_ERR("UART1 not ready");
    return -ENODEV;
}
```

### Pattern: BLE GATT Service Definition

```c
/* Static GATT service registration */
BT_GATT_SERVICE_DEFINE(prov_svc,
    BT_GATT_PRIMARY_SERVICE(&prov_svc_uuid),
    BT_GATT_CHARACTERISTIC(&wifi_ssid_uuid,
        BT_GATT_CHRC_WRITE,
        BT_GATT_PERM_WRITE_ENCRYPT,
        NULL, write_wifi_ssid, NULL),
    /* ... more characteristics */
);
```

## Cross-Cutting Concerns

| Concern | Design Approach |
|---------|----------------|
| **Power loss safety** | All critical writes use write-then-rename on LittleFS |
| **Thread safety** | Message queues for inter-thread data; k_mutex for shared resources |
| **Memory budgeting** | Account for stack, heap, and buffer allocations in design doc |
| **Testability** | Design interfaces that can be mocked with FFF on native_sim |
| **Configurability** | Use Kconfig for compile-time feature toggles; NVS for runtime config |
