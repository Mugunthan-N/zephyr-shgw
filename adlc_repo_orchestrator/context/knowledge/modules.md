---
type: knowledge
scope: project-specific
version: "1.0.0"
domain: modules
agents: [all]
---

# zephyr-shgw — Module Inventory

## Directory Map

```
zephyr-shgw/                            ← Application repository (west manifest repo)
├── CMakeLists.txt                      ← Top-level CMake build
├── prj.conf                            ← Default Kconfig (production)
├── debug.conf                          ← Debug overlay Kconfig
├── app.overlay                         ← Devicetree overlay (partitions, UART, GPIO)
├── Kconfig                             ← Application-level Kconfig definitions
├── VERSION                             ← Firmware version (semver, read by CMake)
├── west.yml                            ← West manifest
├── keys/
│   └── mcuboot-ec-p256.pem            ← MCUboot signing key (dev only)
├── src/
│   ├── main.c                          ← Entry point, init sequence, System Manager bootstrap
│   ├── system_mgr/                     ← System state machine, WDT feed, health monitor
│   ├── wifi_mgr/                       ← WiFi connection lifecycle, DHCP, reconnect, RSSI
│   ├── mqtt_client/                    ← MQTT connection, TLS/mTLS, pub/sub, reconnect
│   ├── shadow_mgr/                     ← AWS IoT Named Shadow management, JSON, delta handling
│   ├── zwave_host/                     ← Z-Wave Serial API host: framing, commands, device table
│   ├── ble_mgr/                        ← BLE GATT server, advertising, provisioning flow
│   ├── rule_engine/                    ← IF-THEN rule evaluator, action dispatch
│   ├── storage_mgr/                    ← LittleFS + NVS abstraction, file I/O, encryption
│   ├── power_mgr/                      ← POFCON ISR, shutdown sequencing, state save
│   ├── shell/                          ← Custom Zephyr shell commands (production + debug)
│   └── common/
│       ├── event_bus.h                 ← Event type definitions, message queue wrappers
│       └── json_utils.h               ← cJSON wrappers for shadow/config parsing
├── boards/
│   └── nrf7002dk_nrf5340_cpuapp.overlay ← Board-specific devicetree overlay
├── dts/bindings/                       ← Custom devicetree bindings (if needed)
├── tests/
│   ├── unit/                           ← Ztest unit tests per module
│   │   ├── test_rule_engine/
│   │   ├── test_shadow_mgr/
│   │   ├── test_zwave_frame/
│   │   └── ...
│   └── integration/                    ← Integration tests
│       ├── test_provisioning_flow/
│       └── ...
├── scripts/
│   ├── renode/                         ← Renode .resc platform files
│   └── ci/                             ← CI pipeline scripts
├── docs/
│   └── SOFTWARE_SPECIFICATION.md       ← Golden reference specification
├── adlc_repo_orchestrator/             ← ADLC pipeline context and config
│   ├── configs/pipeline.yaml
│   ├── context/                        ← Agent context files
│   └── workspace/                      ← Runtime workspace (gitignored)
└── .github/agents/                     ← ADLC pipeline agent instruction files
```

## Key Files

| File | Purpose |
|------|---------|
| `src/main.c` | Application entry point; initializes kernel, drivers, peripherals; bootstraps System Manager |
| `src/system_mgr/system_mgr.c` | Central state machine (BOOT→PROVISIONING→CONNECTING→OPERATIONAL→DEGRADED→SHUTDOWN); WDT feed; health monitor |
| `src/common/event_bus.h` | Event type enums, message queue type definitions, broadcast macros |
| `src/common/json_utils.h` | cJSON wrapper functions for shadow/config JSON parse/build |
| `prj.conf` | Production Kconfig: kernel, networking, BT, MQTT, TLS, FS, NVS, shell, logging, watchdog, MCUboot |
| `debug.conf` | Debug Kconfig overlay: thread analyzer, extended shell, net shell |
| `app.overlay` | Devicetree: LittleFS partition, crash log partition, UART1 for Z-Wave, ZGM230S reset GPIO |
| `VERSION` | Firmware version file (MAJOR.MINOR.PATCH), read by CMake and MCUboot |
| `keys/mcuboot-ec-p256.pem` | MCUboot ECDSA-P256 signing key (development; CI uses secret) |

## Module Dependency Graph

```
                    ┌──────────────┐
                    │ System       │
                    │ Manager      │ ◄── Orchestrates all modules
                    └──────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼────┐     ┌──────▼─────┐    ┌──────▼──────┐
    │ WiFi    │     │ Z-Wave     │    │ BLE         │
    │ Manager │     │ Host       │    │ Manager     │
    └────┬────┘     └──────┬─────┘    └──────┬──────┘
         │                 │                 │
    ┌────▼────┐     ┌──────▼─────┐          │
    │ MQTT    │     │ Shadow     │◄─────────┘
    │ Client  │     │ Manager    │
    └────┬────┘     └──────┬─────┘
         │                 │
         └────────┐  ┌─────┘
                  │  │
            ┌─────▼──▼──────┐
            │ Rule Engine   │
            └───────────────┘

    All modules depend on:
    ├── Storage Manager (LittleFS + NVS)
    ├── Event Bus (k_msgq, k_event)
    └── Logging subsystem
```

**Dependency rules:**
- System Manager depends on all modules (orchestrator).
- MQTT Client depends on WiFi Manager (WiFi link must be up first).
- Shadow Manager depends on MQTT Client (publishes/subscribes via MQTT).
- Rule Engine depends on Shadow Manager (receives state-change events) and Z-Wave Host (dispatches actions).
- All modules depend on Storage Manager for file I/O and config.
- No circular dependencies allowed.

## Configuration Files

| File | Format | Purpose |
|------|--------|---------|
| `prj.conf` | Kconfig | Zephyr kernel/driver/subsystem configuration for production build |
| `debug.conf` | Kconfig | Overlay for debug builds (additive to prj.conf) |
| `app.overlay` | Devicetree | Hardware description: flash partitions, UART, GPIO assignments |
| `/lfs/config/wifi.json` | JSON | WiFi SSID, encrypted PSK, security type |
| `/lfs/config/aws.json` | JSON | AWS IoT endpoint, thing name, client ID |
| `/lfs/config/system.json` | JSON | Device name, timezone, misc config |
| `/lfs/certs/device.pem.crt` | PEM | X.509 device certificate |
| `/lfs/certs/private.pem.key` | PEM | Device private key (encrypted at rest, AES-128-CTR) |
| `/lfs/certs/root-ca.pem` | PEM | AWS Root CA certificate |
| NVS keys | Key-value | boot_count, provisioned flag, fw_version, device_uuid, wifi_configured, zwave_home_id |

## Thread Model

| Thread | Priority | Stack | Purpose |
|--------|----------|-------|---------|
| `main` | 0 | 4096 B | Init sequence → becomes System Manager |
| `system_mgr` | 1 | 3072 B | State machine, WDT feed, health |
| `wifi_mgr` | 2 | 4096 B | WiFi connection, DHCP, reconnect |
| `mqtt_client` | 3 | 4096 B | MQTT connect, pub/sub, keepalive |
| `shadow_mgr` | 4 | 4096 B | Shadow delta processing, JSON |
| `zwave_host` | 2 | 4096 B | Serial API TX/RX, command dispatch |
| `ble_mgr` | 5 | 2048 B | BLE advertising, GATT, provisioning |
| `rule_engine` | 6 | 2048 B | Rule evaluation on state changes |
| `storage_mgr` | 7 | 2048 B | Deferred file writes, LittleFS ops |
| `shell` | 14 | 3072 B | Interactive CLI (UART) |
| `logging` | 15 | 1024 B | Deferred log processing |
| `sysworkq` | -1 (coop) | 2048 B | Zephyr system work queue |
| `rx_workq` | -2 (coop) | 2048 B | Network RX processing |
