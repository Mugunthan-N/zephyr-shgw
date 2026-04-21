---
type: skill
scope: project-specific
version: "1.0.0"
domain: requirement
agents: [requirement]
---

# Requirement Skills — zephyr-shgw

## Project Context

This is an embedded firmware project (C, Zephyr RTOS, nRF5340). Requirements must account for real-time constraints, resource limits, hardware interfaces, and safety/reliability concerns unique to embedded systems.

## Standard NFRs — Embedded Gateway

These NFR categories MUST be considered for every task:

| Category | Standard Requirement | Source |
|----------|---------------------|--------|
| **Memory** | Implementation must not increase RAM usage beyond the 80% budget ceiling (< 410 KB of 512 KB SRAM) | R-PF-001, spec §15.3 |
| **Flash** | Application image must fit within 448 KB primary slot (target < 400 KB code) | spec §15.1 |
| **Stack Safety** | New threads must have statically allocated stacks with sizes documented in the thread model | R-EM-002 |
| **Latency: Boot** | Boot to OPERATIONAL state < 15 seconds | spec §15.4 |
| **Latency: Cloud Cmd** | Cloud command to Z-Wave TX < 2 seconds | spec §15.4 |
| **Latency: Local Rule** | Local rule state change to Z-Wave TX < 500 ms | spec §15.4 |
| **Latency: Shutdown** | POFCON to state saved < 100 ms | spec §15.4 |
| **Error Handling** | All Zephyr API return codes checked; exponential backoff for reconnection | R-EH-001, R-EH-002 |
| **Power Loss** | Critical file writes must be atomic (write-then-rename) | R-FS-001 |
| **Security: TLS** | mTLS with TLS 1.2, ECDHE-ECDSA cipher, no fallback | R-SC-001 |
| **Security: Storage** | Sensitive data encrypted at rest (AES-128-CTR from FICR key) | R-SC-002 |
| **Security: Logging** | No secrets in log output | R-SC-003 |
| **Testing** | Every module must have Ztest unit tests runnable on native_sim | R-TS-001, R-TS-002 |
| **Offline Mode** | Feature must degrade gracefully when cloud is unreachable (DEGRADED state) | spec §2.4 |
| **Thread Safety** | Shared data accessed from multiple threads must use Zephyr IPC (k_mutex, k_msgq, k_sem) | R-EM-001 |
| **WDT Compliance** | New long-running operations must not block the System Manager WDT feed (8s timeout) | R-EM-005 |

## Acceptance Criteria Patterns

### For Module Implementation

```
- The module MUST initialize successfully by returning 0 from <module>_init()
- The module MUST register a LOG_MODULE with configurable log level via Kconfig
- The module's thread stack MUST be statically allocated with K_THREAD_STACK_DEFINE
- The module MUST handle [specific input] by [specific action] within [latency] ms
- The module MUST return -EINVAL for invalid parameters
- The module MUST log errors at LOG_ERR with context (operation, parameters, error code)
```

### For Communication Features

```
- The feature MUST reconnect with exponential backoff (initial: Ns, max: Ms)
- The feature MUST transition the system to DEGRADED state after N consecutive failures
- The feature MUST queue pending operations to LittleFS when cloud is unreachable (max N entries)
- The feature MUST sync queued operations on reconnection
- The feature MUST publish state changes to the named shadow within N seconds
```

### For Z-Wave Features

```
- The Serial API frame MUST include SOF (0x01), length, type, payload, and XOR checksum
- The host MUST retry TX frames up to 3 times on NAK or timeout (1600 ms)
- The device table MUST enforce the 32-node maximum (ZWAVE_MAX_NODES)
- Device table changes MUST be persisted to /lfs/zwave/devices.json using write-then-rename
- Device state changes MUST be reported to the corresponding named shadow
```

### For BLE Features

```
- GATT characteristics MUST require BT_GATT_PERM_WRITE_ENCRYPT
- BLE advertising MUST use the format "SHG-<last4_MAC>" with 100ms fast / 1000ms slow intervals
- Advertising MUST timeout after 10 minutes with no connection
- Provisioning data MUST be saved to LittleFS before acknowledging completion
```

### For OTA Features

```
- The OTA image MUST be written to the MCUboot secondary slot on external flash
- SHA-256 checksum MUST be verified before calling boot_request_upgrade()
- Image confirmation (boot_write_img_confirmed) MUST occur only after WiFi + MQTT + shadow sync
- If confirmation fails within 120 seconds, WDT must trigger revert
```

## Feature-Type Templates

### Embedded Module Feature

When a task adds a new embedded module, the requirements MUST include:
1. Module initialization and public API (FRs)
2. Thread model: priority, stack size, IPC mechanism (FRs)
3. Memory budget impact assessment (NFR)
4. Error handling for all failure paths (FRs)
5. Shell command for diagnostics (FR)
6. Kconfig feature gate (NFR)
7. Unit test on native_sim (NFR)

### Protocol Integration Feature

When a task adds protocol handling (WiFi, MQTT, Z-Wave, BLE):
1. Protocol state machine with all transitions (FRs)
2. Frame/message format compliance (FRs)
3. Reconnection with backoff (FRs)
4. Offline/degraded mode behavior (FRs)
5. Shadow integration for cloud visibility (FRs)
6. Latency requirements (NFRs)
7. Security requirements: TLS, encryption, auth (NFRs)

### Configuration Change

When a task modifies Kconfig or devicetree:
1. List affected CONFIG_ symbols (FRs)
2. Build verification for native_sim and nrf7002dk (NFRs)
3. RAM/flash impact assessment (NFRs)
4. Backward compatibility with existing NVS/LittleFS data (NFRs)
