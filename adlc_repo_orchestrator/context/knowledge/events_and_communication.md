---
type: knowledge
scope: project-specific
version: "1.0.0"
domain: events
agents: [all]
---

# zephyr-shgw — Events & Communication

## Overview

The gateway uses Zephyr kernel IPC primitives for all inter-thread communication. There are two communication patterns:

1. **Broadcast events** (`k_event`) — System Manager announces mode transitions to all threads.
2. **Point-to-point messages** (`k_msgq`, `k_fifo`) — typed data between specific producer/consumer pairs.

## System Events (Broadcast)

Defined in `src/common/event_bus.h` using `k_event`:

```c
enum system_event {
    EVENT_WIFI_CONNECTED    = BIT(0),   /* WiFi link up + DHCP complete */
    EVENT_WIFI_DISCONNECTED = BIT(1),   /* WiFi link lost */
    EVENT_WIFI_FAILED       = BIT(2),   /* 5 consecutive WiFi failures */
    EVENT_MQTT_CONNECTED    = BIT(3),   /* MQTT + TLS session established */
    EVENT_MQTT_DISCONNECTED = BIT(4),   /* MQTT session lost */
    EVENT_SHADOW_SYNCED     = BIT(5),   /* Initial shadow sync complete */
    EVENT_SHUTDOWN          = BIT(6),   /* POFCON triggered — save state and halt */
    EVENT_OTA_AVAILABLE     = BIT(7),   /* OTA image URL received in shadow delta */
    EVENT_PROVISIONED       = BIT(8),   /* Credentials saved, ready to connect */
    EVENT_ZWAVE_READY       = BIT(9),   /* Z-Wave Serial API initialized */
};

extern struct k_event sys_events;
```

**Posting** (by System Manager or originating module):
```c
k_event_post(&sys_events, EVENT_WIFI_CONNECTED);
```

**Listening** (by any thread):
```c
uint32_t events = k_event_wait(&sys_events,
    EVENT_WIFI_CONNECTED | EVENT_SHUTDOWN,
    false,  /* wait for any (not all) */
    K_FOREVER);
if (events & EVENT_SHUTDOWN) {
    /* Handle shutdown */
}
```

## Message Queues (Point-to-Point)

### Z-Wave → Shadow Manager (Device State Updates)

```c
struct shadow_update_msg {
    uint8_t  node_id;           /* Z-Wave node that reported state */
    char     property[32];      /* e.g., "binary_switch", "dimmer_level" */
    int32_t  value;             /* New value (integer, scaled) */
    uint32_t timestamp;         /* k_uptime_get_32() at receive time */
};

K_MSGQ_DEFINE(shadow_update_queue, sizeof(struct shadow_update_msg), 16, 4);
```

**Producer**: `zwave_host` thread (after parsing FUNC_ID_APPLICATION_COMMAND_HANDLER)
**Consumer**: `shadow_mgr` thread (builds JSON, publishes to named shadow)

### Shadow Manager → Rule Engine (State Change Events)

```c
struct rule_event_msg {
    uint8_t  node_id;           /* Device whose state changed */
    char     property[32];      /* Changed property */
    int32_t  new_value;         /* New value */
};

K_MSGQ_DEFINE(rule_event_queue, sizeof(struct rule_event_msg), 16, 4);
```

**Producer**: `shadow_mgr` thread (after processing a state change from any source)
**Consumer**: `rule_engine` thread (evaluates IF-THEN rules against new state)

### MQTT → Shadow Manager (Incoming Shadow Deltas)

```c
struct shadow_delta_msg {
    char     shadow_name[32];   /* e.g., "gateway", "zwave-node-5" */
    char     payload[4096];     /* JSON delta payload */
    uint16_t payload_len;
};

K_MSGQ_DEFINE(shadow_delta_queue, sizeof(struct shadow_delta_msg), 4, 4);
```

**Producer**: `mqtt_client` thread (on receiving message on .../delta topic)
**Consumer**: `shadow_mgr` thread (parses JSON, dispatches to module or Z-Wave)

### Shadow Manager → Z-Wave Host (Device Commands)

```c
struct zwave_cmd_msg {
    uint8_t  node_id;           /* Target Z-Wave node */
    uint8_t  command_class;     /* e.g., 0x25 = SWITCH_BINARY */
    uint8_t  command;           /* e.g., SET */
    int32_t  value;             /* Command value */
};

K_MSGQ_DEFINE(zwave_cmd_queue, sizeof(struct zwave_cmd_msg), 8, 4);
```

**Producer**: `shadow_mgr` thread (from cloud delta) or `rule_engine` thread (from local rule)
**Consumer**: `zwave_host` thread (builds Serial API frame, sends to ZGM230S)

## FIFOs (ISR → Thread)

### UART RX (Z-Wave Serial API)

```c
/* Ring buffer for byte-level UART RX from ZGM230S */
static uint8_t rx_ring_buf_data[256];
static struct ring_buf rx_ring_buf;

/* ISR puts bytes into ring buffer, signals thread */
static K_SEM_DEFINE(rx_sem, 0, 1);
```

**ISR**: UARTE1 RX interrupt handler puts received bytes into ring buffer, gives `rx_sem`.
**Thread**: `zwave_host` takes `rx_sem`, reads ring buffer, parses Serial API frames.

## Semaphores (Resource Protection)

| Semaphore | Protects | Used By |
|-----------|----------|---------|
| `lfs_sem` | LittleFS write access (single writer) | `storage_mgr` (taken before write ops) |
| `rx_sem` | UART RX ring buffer availability | ISR gives, `zwave_host` takes |

## Data Flow Diagrams

### Cloud Command Flow (Desired → Device)

```
AWS IoT Core
  │ MQTT delta message on .../shadow/name/zwave-node-5/update/delta
  ▼
mqtt_client thread
  │ k_msgq_put(&shadow_delta_queue, &delta_msg)
  ▼
shadow_mgr thread
  │ Parse JSON delta → extract node_id=5, command_class, value
  │ k_msgq_put(&zwave_cmd_queue, &cmd_msg)
  ▼
zwave_host thread
  │ Build Serial API frame → UART TX to ZGM230S
  │ Wait ACK (1600ms timeout, 3 retries)
  │ On success callback: k_msgq_put(&shadow_update_queue, &reported_msg)
  ▼
shadow_mgr thread
  │ Build reported JSON → mqtt_client publishes to .../shadow/name/zwave-node-5/update
  ▼
AWS IoT Core (reported state matches desired → delta cleared)
```

### Local Rule Flow (Device → Rule → Device)

```
Z-Wave end-device sends state report
  │ UART RX ISR → ring buffer → zwave_host parses frame
  ▼
zwave_host thread
  │ k_msgq_put(&shadow_update_queue, &state_msg) → to shadow_mgr
  ▼
shadow_mgr thread
  │ Updates cached state
  │ k_msgq_put(&rule_event_queue, &event_msg) → to rule_engine
  │ Publishes reported state to cloud (if connected)
  ▼
rule_engine thread
  │ For each enabled rule: evaluate condition against new state
  │ If condition true: k_msgq_put(&zwave_cmd_queue, &action_msg)
  ▼
zwave_host thread
  │ Sends Z-Wave command to target device
  ▼
Target Z-Wave device executes command
```

### Provisioning Flow (BLE → System)

```
Mobile App connects via BLE
  │ Writes WiFi SSID, PSK, AWS certs to GATT characteristics
  │ Writes Provisioning Command = 0x01 (save)
  ▼
ble_mgr thread
  │ Validates all fields present
  │ Calls storage_mgr_write_file() for each credential
  │ Sets NVS provisioned=1
  │ k_event_post(&sys_events, EVENT_PROVISIONED)
  ▼
system_mgr thread
  │ Receives EVENT_PROVISIONED
  │ Transitions from PROVISIONING → CONNECTING
  │ WiFi Manager starts association
  │ ...continues to OPERATIONAL
```
