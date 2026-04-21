---
type: skill
scope: project-specific
version: "1.0.0"
domain: planner
agents: [planner]
---

# Planner Skills — zephyr-shgw

## Project Context

This is an embedded firmware project for a Smart Home Gateway running Zephyr RTOS on the nRF5340 SoC (nRF7002-DK board). The gateway bridges Z-Wave devices to AWS IoT via WiFi/MQTT, with BLE provisioning and local rule execution.

## Component Areas

Tasks in this project typically touch one or more of these areas:

| Area | Source Path | Typical Changes |
|------|-----------|-----------------|
| **System Manager** | `src/system_mgr/` | State machine transitions, mode handling, WDT logic |
| **WiFi Manager** | `src/wifi_mgr/` | Connection lifecycle, DHCP, reconnect, RSSI monitoring |
| **MQTT Client** | `src/mqtt_client/` | TLS connection, pub/sub, shadow topic management |
| **Shadow Manager** | `src/shadow_mgr/` | JSON parsing/building, delta handling, offline queue |
| **Z-Wave Host** | `src/zwave_host/` | Serial API framing, command dispatch, device table |
| **BLE Manager** | `src/ble_mgr/` | GATT service, advertising, provisioning flow |
| **Rule Engine** | `src/rule_engine/` | IF-THEN evaluation, action dispatch |
| **Storage Manager** | `src/storage_mgr/` | LittleFS/NVS abstraction, encryption |
| **Power Manager** | `src/power_mgr/` | POFCON, shutdown, state save |
| **Shell Commands** | `src/shell/` | CLI commands for production/debug |
| **Common/Event Bus** | `src/common/` | Event types, JSON utils, shared types |
| **Kconfig/DTS** | `prj.conf`, `app.overlay` | Configuration changes, peripheral assignments |
| **Tests** | `tests/unit/`, `tests/integration/` | Ztest suites for native_sim |

## Task Decomposition Patterns

### Pattern 1: New Module Implementation

When adding a new module (e.g., a new subsystem or protocol handler):

1. **ST-001: Module header + API design** — public interface in `src/<module>/<module>.h`
2. **ST-002: Core implementation** — `src/<module>/<module>.c` with init, thread, message handling
3. **ST-003: Event bus integration** — add event types to `event_bus.h`, connect message queues
4. **ST-004: Kconfig entries** — add `CONFIG_<MODULE>_*` entries for log level, stack size, feature toggles
5. **ST-005: System Manager integration** — init call from `main.c`, state machine hooks
6. **ST-006: Shell commands** — add diagnostic/control commands in `src/shell/`
7. **ST-007: Unit tests** — `tests/unit/test_<module>/` with Ztest + FFF mocks
8. **ST-008: Integration test** — `tests/integration/` if cross-module interaction is involved

### Pattern 2: Protocol/Communication Feature

When adding WiFi, MQTT, Z-Wave, or BLE functionality:

1. **ST-001: Protocol layer implementation** — framing, parsing, state machine
2. **ST-002: Application layer handler** — business logic processing incoming data
3. **ST-003: Shadow/cloud integration** — if the feature touches AWS IoT shadows
4. **ST-004: Offline/degraded mode handling** — what happens when cloud is unreachable
5. **ST-005: Error handling + reconnection** — backoff, retry, fault recovery
6. **ST-006: Shell diagnostics** — status commands, manual trigger commands
7. **ST-007: Unit tests** — mock the hardware/transport layer
8. **ST-008: Renode test** — if UART or BLE simulation is needed

### Pattern 3: Bug Fix / Behavioral Change

1. **ST-001: Root cause analysis** — identify the affected module and code path
2. **ST-002: Fix implementation** — minimal change to fix the issue
3. **ST-003: Regression test** — new test case that would have caught the bug
4. **ST-004: Related impact check** — verify callers and dependents are unaffected

### Pattern 4: Configuration / DTS Change

1. **ST-001: Kconfig/DTS change** — modify `prj.conf`, `app.overlay`, or board overlay
2. **ST-002: Code adaptation** — update code that depends on the changed config
3. **ST-003: Build verification** — verify build for both `native_sim` and `nrf7002dk`

## Decomposition Rules

- **Always include a test subtask** — every code change needs at least one Ztest case
- **Always check Kconfig impact** — if a feature is added, it should be Kconfig-gated
- **Always check thread/memory budget** — new threads need stack allocation, new buffers need RAM budget verification
- **Z-Wave changes require frame-level tests** — Serial API framing must be tested independently
- **Shadow changes require JSON parse tests** — never modify shadow handling without JSON round-trip tests
- **WiFi/MQTT changes must handle DEGRADED mode** — always plan for offline behavior

## Scope Boundaries

- **In scope for this project**: anything in the `zephyr-shgw/` application repo
- **Out of scope**: Zephyr kernel changes, MCUboot source changes, nRF7002 driver changes, mobile app, AWS infra
- **Read-only context**: `zephyr/` SDK code, `modules/` HALs — reference but don't modify

## Risk Assessment Heuristics

| Risk Level | Criteria |
|-----------|----------|
| **Low** | Change is isolated to one module, no cross-thread interaction, no hardware dependency |
| **Medium** | Touches shared modules (`event_bus.h`, `storage_mgr`), modifies message queue schemas, changes thread priority |
| **High** | Cross-cutting (multiple modules), changes ISR behavior, modifies flash partitions, touches security/crypto |
