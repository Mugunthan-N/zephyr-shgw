---
type: knowledge
scope: project-specific
version: "1.0.0"
domain: tech-stack
agents: [all]
---

# zephyr-shgw — Tech Stack

## Runtime

- **Language**: C (C11 standard, Zephyr-compatible subset)
- **RTOS**: Zephyr RTOS (latest LTS from west manifest)
- **Target SoC**: Nordic nRF5340 (dual-core Cortex-M33, 128 MHz app core / 64 MHz net core)
- **Target Board**: nRF7002-DK (`nrf7002dk/nrf5340/cpuapp` for app core, `nrf7002dk/nrf5340/cpunet` for net core)
- **Emulation**: native_sim (Zephyr's Linux-hosted POSIX target), Renode (hardware emulation)
- **Build System**: CMake + Ninja (via `west build`)
- **Package/Manifest Manager**: West (Zephyr's meta-tool for workspace and manifest management)

## Hardware Components

| Component | Role | Interface |
|-----------|------|-----------|
| nRF5340 App Core | Main application processor | — |
| nRF5340 Net Core | BLE HCI controller (`hci_ipc`) | IPC |
| nRF7002 | WiFi 6 companion IC (2.4 GHz) | QSPI (shared bus) |
| MX25R6435F | 8 MB external QSPI NOR flash | QSPI (shared bus, separate CS) |
| ZGM230S | Z-Wave 800 series controller (Serial API firmware) | UARTE1 (115200, HW flow control) |
| CryptoCell CC312 | Hardware crypto acceleration (AES, SHA, ECC, RNG) | On-SoC peripheral |

## Frameworks & Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| Zephyr RTOS | LTS (from west.yml) | Kernel, drivers, networking, BT, shell, logging |
| MCUboot | From west manifest | Secure bootloader, image swap, anti-rollback |
| Mbed TLS | Bundled with Zephyr | TLS 1.2, mTLS, X.509, ECDHE-ECDSA |
| LittleFS | Bundled with Zephyr | Power-loss resilient filesystem on NOR flash |
| cJSON | Vendored or Zephyr module | JSON parse/build for shadow/config documents |
| nRF7002 WiFi driver | Nordic HAL (hal_nordic) | WiFi MAC offload, IP on nRF5340 |
| Zephyr MQTT | Built-in (`CONFIG_MQTT_LIB`) | MQTT 3.1.1 client |
| Zephyr Bluetooth Host | Built-in (`CONFIG_BT`) | BLE GATT server, peripheral mode |
| Zephyr NVS | Built-in (`CONFIG_NVS`) | Non-volatile key-value storage |
| Zephyr Shell | Built-in (`CONFIG_SHELL`) | UART-based interactive CLI |
| FFF (Fake Function Framework) | Bundled with Zephyr | Test mocking/stubbing |

## Build Tools

- **Build**: `west build` (CMake + Ninja backend)
- **Flash**: `west flash` (via SEGGER J-Link)
- **Sign**: `west sign -t imgtool` (MCUboot image signing, ECDSA-P256)
- **Debug**: SEGGER J-Link + GDB, SEGGER RTT for logging
- **Static Analysis**: Zephyr `checkpatch.py`, optional MISRA-C checks
- **Lint**: Zephyr coding style checks via CI

## Build Commands

```bash
# Production build for nRF7002-DK
west build -b nrf7002dk/nrf5340/cpuapp app -- -DOVERLAY_CONFIG=prj.conf

# Debug build
west build -b nrf7002dk/nrf5340/cpuapp app -- -DOVERLAY_CONFIG="prj.conf;debug.conf"

# native_sim build (for testing)
west build -b native_sim app

# Run unit tests
west twister -p native_sim -T app/tests/

# Flash to hardware
west flash

# Sign image for OTA
west sign -t imgtool -- --key app/keys/mcuboot-ec-p256.pem --version 1.0.0

# Build net core BLE controller
west build -b nrf7002dk/nrf5340/cpunet -d build_netcore zephyr/samples/bluetooth/hci_ipc
```

## Testing Stack

- **Framework**: Zephyr Ztest (`ztest_test_suite`, `ZTEST`, `ZTEST_SUITE`)
- **Test Runner**: Twister (`west twister`)
- **Mocking**: Zephyr FFF (Fake Function Framework) for driver/subsystem mocks
- **Coverage**: gcov/lcov on native_sim builds
- **Emulation Layers**:
  - Level 1: native_sim — application logic, JSON parsing, state machines, rule engine
  - Level 2: Renode — BLE simulation, virtual UART (Z-Wave mock), flash partitions
  - Level 3: Real hardware — full end-to-end (nRF7002-DK + ZGM230S + real Z-Wave devices)
- **Thresholds**: Target 80% line coverage on native_sim testable modules

## CI/CD

- **Pipeline**: GitHub Actions (or equivalent CI)
- **Stages**: Build (native_sim + nrf7002dk + debug + release) → Test (Twister native_sim + Renode) → Static Analysis → Sign & Artifact
- **Artifacts**: Signed OTA image (hex), build logs, test reports, coverage reports

## Key Constraints

| Constraint | Detail |
|------------|--------|
| **Internal Flash** | 448 KB primary slot for application (target < 400 KB code) |
| **SRAM** | 512 KB total, target < 80% utilization (< 410 KB) |
| **External Flash** | 8 MB: 1 MB OTA secondary, 6.5 MB LittleFS, 512 KB crash log |
| **Max Z-Wave devices** | 32 nodes |
| **Max rules** | 16 IF-THEN rules |
| **MQTT QoS** | QoS 1 for shadow updates, QoS 0 for telemetry |
| **TLS** | TLS 1.2 minimum, ECDHE-ECDSA cipher suite, mTLS |
| **Boot to operational** | < 15 seconds |
| **Z-Wave cloud command latency** | < 2 seconds (shadow delta → Z-Wave TX) |
| **Z-Wave local rule latency** | < 500 ms (state change → Z-Wave TX) |
| **Graceful shutdown** | < 100 ms (POFCON → state saved → halt) |
| **WDT timeout** | 8 seconds |
| **No dynamic memory after init** | Prefer static allocation; heap only for JSON parse buffers |
| **No POSIX APIs** | Use Zephyr kernel APIs only (k_thread, k_msgq, k_sem, k_event, etc.) |
| **No floating point in hot paths** | nRF5340 has FPU but avoid in ISRs and high-priority threads |
| **Thread stack sizes are fixed** | Defined at compile time, cannot grow at runtime |
