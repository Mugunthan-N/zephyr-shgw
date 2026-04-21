# Smart Home Gateway - Software Specification Document

| Field | Value |
|-------|-------|
| **Document ID** | SHG-SSD-001 |
| **Version** | 0.1.0 (Draft) |
| **Date** | 2026-04-21 |
| **Status** | Initial Draft - Pending Review |
| **Classification** | Internal / Confidential |

---

## Change History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1.0 | 2026-04-21 | - | Initial draft based on architectural decisions Q1–Q32 |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Overview](#2-system-overview)
3. [Hardware Abstraction & Platform](#3-hardware-abstraction--platform)
4. [Zephyr RTOS Configuration](#4-zephyr-rtos-configuration)
5. [Connectivity - WiFi](#5-connectivity--wifi)
6. [Connectivity - Z-Wave](#6-connectivity--z-wave)
7. [Connectivity - BLE](#7-connectivity--ble)
8. [Cloud & IoT Integration](#8-cloud--iot-integration)
9. [Local Intelligence](#9-local-intelligence)
10. [File System & Persistent Storage](#10-file-system--persistent-storage)
11. [Security](#11-security)
12. [Bootloader & OTA Update](#12-bootloader--ota-update)
13. [Serial Port / Debug / Test Interfaces](#13-serial-port--debug--test-interfaces)
14. [Application Architecture](#14-application-architecture)
15. [Performance & Resource Budgets](#15-performance--resource-budgets)
16. [Testing & Validation Strategy](#16-testing--validation-strategy)
17. [Build System & Toolchain](#17-build-system--toolchain)
18. [Appendices](#18-appendices)

---

## 1. Introduction

### 1.1 Purpose & Scope

This document is the **golden reference specification** for the Smart Home Gateway (SHG) firmware. It defines the complete software architecture, subsystem design, resource budgets, interfaces, and testing strategy for an embedded gateway running **Zephyr RTOS** on the **Nordic nRF5340** SoC.

The gateway serves as the central intelligence hub of a smart home, bridging:

- **Z-Wave 800** end-devices (up to 32) to the cloud via **AWS IoT Core**.
- **WiFi** connectivity for cloud/MQTT communication.
- **BLE** for initial device commissioning and provisioning.
- **Local rule execution** for offline automation continuity.

**In Scope:**

- Firmware running on the nRF5340 application core.
- BLE controller firmware on the nRF5340 network core (`hci_ipc`).
- Interaction with the nRF7002 WiFi companion (via QSPI).
- Interaction with the ZGM230S Z-Wave module (via Serial API / UART).
- MCUboot bootloader integration.
- Emulation and testing strategy (native_sim, Renode, hardware).
- AWS IoT Device Shadow integration (named shadows).

**Out of Scope:**

- Mobile companion app development (only the BLE GATT interface is specified).
- AWS cloud-side infrastructure (Lambda, IoT rules, DynamoDB) - only device-side MQTT/Shadow behavior is defined.
- Z-Wave end-device firmware.
- Production PCB design (uses nRF7002-DK for development).

### 1.2 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|------|-----------|
| **SHG** | Smart Home Gateway - the product described in this document |
| **App Core** | nRF5340 application processor (Cortex-M33, 128 MHz, 1 MB Flash, 512 KB SRAM) |
| **Net Core** | nRF5340 network processor (Cortex-M33, 64 MHz, 256 KB Flash, 64 KB SRAM) |
| **nRF7002** | Nordic Wi-Fi 6 companion IC |
| **ZGM230S** | Silicon Labs Z-Wave 800 series SoC (runs Serial API firmware) |
| **Serial API** | Silicon Labs Z-Wave host communication protocol (binary frames, ACK/NAK/CAN) |
| **Device Shadow** | AWS IoT mechanism for storing and syncing device state (desired/reported JSON) |
| **Named Shadow** | An individually addressable shadow instance for a specific logical entity |
| **MCUboot** | Open-source secure bootloader for 32-bit MCUs |
| **LittleFS** | Power-loss resilient file system for NOR flash |
| **POFCON** | nRF5340 power-failure comparator - generates interrupt on voltage drop |
| **GATT** | Generic Attribute Profile (BLE data exchange protocol) |
| **RTT** | SEGGER Real-Time Transfer - non-intrusive debug logging via SWD |
| **DTS/DT** | Devicetree / Devicetree Source - hardware description used by Zephyr |
| **Kconfig** | Zephyr's kernel configuration system (based on Linux Kconfig) |
| **NVS** | Zephyr Non-Volatile Storage - key-value store on flash |
| **OTA** | Over-The-Air firmware update |
| **mTLS** | Mutual TLS - both client and server present certificates |

### 1.3 References & Applicable Standards

| ID | Reference |
|----|-----------|
| [REF-01] | Zephyr Project Documentation - https://docs.zephyrproject.org |
| [REF-02] | Nordic nRF5340 Product Specification v1.3 |
| [REF-03] | Nordic nRF7002 Product Specification |
| [REF-04] | Nordic nRF7002-DK Hardware Guide |
| [REF-05] | Silicon Labs Z-Wave 800 Series (ZGM230S) Data Sheet |
| [REF-06] | Silicon Labs INS14259 - Z-Wave Serial API Host Application Programming Guide |
| [REF-07] | AWS IoT Core Developer Guide - Device Shadow Service |
| [REF-08] | MCUboot Documentation - https://docs.mcuboot.com |
| [REF-09] | Bluetooth Core Specification v5.3 |
| [REF-10] | Z-Wave Specification (ITU-T G.9959) |
| [REF-11] | LittleFS Design Documentation - https://github.com/littlefs-project/littlefs |
| [REF-12] | MQTT v3.1.1 Specification (OASIS Standard) |
| [REF-13] | Renode Documentation - https://renode.readthedocs.io |

### 1.4 Document Versioning & Change Control

- This document follows **Semantic Versioning** (MAJOR.MINOR.PATCH).
- MAJOR: Architectural changes that invalidate prior sections.
- MINOR: New sections or significant detail additions.
- PATCH: Clarifications, typo fixes, constraint updates.
- All changes must be recorded in the Change History table.
- Each released firmware version SHALL reference a specific version of this document.

---

## 2. System Overview

### 2.1 High-Level System Context

```
                        ┌──────────────┐
                        │  AWS IoT     │
                        │  Core        │
                        │  (Shadows,   │
                        │   Jobs)      │
                        └──────┬───────┘
                               │ MQTT over TLS (port 8883)
                               │
                        ┌──────▼───────┐
    ┌───────────┐       │              │       ┌───────────┐
    │ Mobile    │◄─BLE─►│  Smart Home  │◄─────►│ Z-Wave    │
    │ App       │       │  Gateway     │Z-Wave │ End       │
    │ (Commis-  │       │  (nRF7002-DK)│SerAPI │ Devices   │
    │  sioning) │       │              │ UART  │ (≤32)     │
    └───────────┘       └──────────────┘       └───────────┘
                               │
                          WiFi (nRF7002)
                               │
                        ┌──────▼───────┐
                        │ WiFi Access  │
                        │ Point/Router │
                        └──────────────┘
```

### 2.2 Functional Block Diagram

```
┌─────────────────────────────── nRF5340 App Core ────────────────────────────────┐
│                                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ System      │  │ Provisioning│  │ WiFi Manager │  │ Z-Wave Host          │  │
│  │ Manager     │  │ Manager     │  │              │  │ (Serial API Client)  │  │
│  │ (State      │  │ (BLE GATT + │  │ (nRF7002     │  │                      │  │
│  │  Machine)   │  │  CLI)       │  │  Driver,     │  │ - Frame Parser       │  │
│  │             │  │             │  │  DHCP,       │  │ - Command Classes    │  │
│  │ - Boot      │  │ - WiFi cred │  │  Reconnect)  │  │ - Network Mgmt      │  │
│  │ - Provision │  │ - AWS certs │  │              │  │ - Device Table (≤32) │  │
│  │ - Operate   │  │ - Device ID │  │              │  │                      │  │
│  │ - Shutdown  │  │             │  │              │  │                      │  │
│  └──────┬──────┘  └─────────────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                                  │                     │              │
│  ┌──────▼──────────────────────────────────▼─────────────────────▼───────────┐  │
│  │                         Event Bus / Message Queues                        │  │
│  └──────┬──────────────────────────────────┬─────────────────────┬───────────┘  │
│         │                                  │                     │              │
│  ┌──────▼──────┐  ┌───────────────────┐  ┌▼──────────────┐  ┌───▼───────────┐  │
│  │ Rule Engine │  │ Shadow Manager    │  │ MQTT Client   │  │ Storage       │  │
│  │             │  │                   │  │               │  │ Manager       │  │
│  │ - IF-THEN   │  │ - Gateway Shadow  │  │ - Zephyr MQTT │  │               │  │
│  │ - Evaluate  │  │   (config+rules)  │  │ - TLS/mTLS   │  │ - LittleFS    │  │
│  │ - Dispatch  │  │ - Device Shadows  │  │ - Reconnect   │  │ - Crash Logs  │  │
│  │             │  │   (×32 named)     │  │ - Pub/Sub     │  │ - Cert Store  │  │
│  │             │  │ - Delta handling  │  │               │  │               │  │
│  └─────────────┘  └───────────────────┘  └───────────────┘  └───────────────┘  │
│                                                                                  │
│  ┌───────────────┐  ┌────────────────┐  ┌────────────────────────────────────┐  │
│  │ Shell / CLI   │  │ Power Manager  │  │ Logging (UART + RTT)              │  │
│  │ (Kconfig:     │  │ (POFCON ISR,   │  │                                    │  │
│  │  debug/prod)  │  │  state save)   │  │                                    │  │
│  └───────────────┘  └────────────────┘  └────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────────────┘
         │ IPC                    │ QSPI                  │ UARTE1 (RTS/CTS)
         ▼                        ▼                        ▼
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ nRF5340      │         │ nRF7002      │         │ ZGM230S      │
│ Net Core     │         │ WiFi 6       │         │ Z-Wave 800   │
│ (hci_ipc)    │         │              │         │ Serial API   │
└──────────────┘         └──────────────┘         └──────────────┘
```

### 2.3 Key Stakeholders & Use-Case Summary

| Stakeholder | Use Cases |
|-------------|-----------|
| **End User** | Commission gateway via mobile app (BLE); add/remove Z-Wave devices; control devices via cloud; define automation rules via cloud dashboard |
| **Installer / Technician** | Factory provisioning via serial CLI; production testing; aging test execution |
| **Cloud Platform (AWS)** | Push desired state to device shadows; receive reported state; dispatch OTA jobs; push rule updates |
| **Developer** | Debug via RTT/UART shell; emulation testing (native_sim, Renode); OTA development builds |

### 2.4 Operating Modes

The system operates in the following mutually exclusive or overlapping modes:

| Mode | Description | Active Subsystems |
|------|-------------|-------------------|
| **BOOT** | MCUboot validates image, jumps to app. System initializes kernel, drivers, peripherals. | MCUboot, Kernel init |
| **PROVISIONING** | First boot or factory reset. Gateway advertises BLE GATT provisioning service. Awaits WiFi + AWS credentials. Serial CLI also active. | BLE Peripheral, Shell, LittleFS |
| **CONNECTING** | WiFi association + DHCP, TLS handshake to AWS IoT, shadow sync. | WiFi, MQTT, Shadow Manager |
| **OPERATIONAL** | Steady state. All subsystems active. Cloud connected. Z-Wave network operational. Rules executing. | WiFi, MQTT, Z-Wave, Rule Engine, Shadow Mgr |
| **DEGRADED** | Cloud unreachable. Local Z-Wave control + rule execution continues. Shadow deltas queued. | Z-Wave, Rule Engine, LittleFS (queue) |
| **OTA_UPDATE** | OTA image downloading to secondary slot. Normal operation continues. | MQTT (download), LittleFS (staging), all others |
| **SHUTDOWN** | POFCON triggered. Critical state saved to flash. Safe halt. | Power Manager, LittleFS (state flush) |
| **FACTORY_TEST** | Entered via shell command or GPIO strap. Exercises all hardware: radios, flash, GPIOs. | Shell, all drivers in test mode |
| **AGING_TEST** | Long-duration stress test. Cycles connectivity, Z-Wave commands, flash writes. Logs metrics. | All subsystems, enhanced logging |

**State Machine:**

```
           ┌────────┐
           │  BOOT  │
           └───┬────┘
               │ Image valid
               ▼
        ┌──────────────┐  Credentials exist?
        │  Check NVS / │──── Yes ──► CONNECTING
        │  LittleFS    │
        └──────┬───────┘
               │ No
               ▼
        ┌──────────────┐           ┌──────────────┐
        │ PROVISIONING │──creds──►│  CONNECTING   │
        └──────────────┘  saved    └──────┬───────┘
                                          │ Connected
                                          ▼
                                   ┌──────────────┐
                              ┌───►│ OPERATIONAL  │◄───┐
                              │    └──┬───┬───┬───┘    │
                              │       │   │   │        │
                    Cloud     │  POFCON│  OTA  │Cloud   │Reconnected
                    restored  │       │  Job  │Lost    │
                              │       ▼   ▼   ▼        │
                              │  ┌────┐ ┌───┐ ┌───────┐│
                              │  │SHUT│ │OTA│ │DEGRADED├┘
                              │  │DOWN│ │   │ └───────┘
                              │  └────┘ └─┬─┘
                              │           │ Reboot after swap
                              │           ▼
                              │       ┌──────┐
                              └───────│ BOOT │
                                      └──────┘
```

---

## 3. Hardware Abstraction & Platform

### 3.1 Target SoC: Nordic nRF5340

| Parameter | App Core | Net Core |
|-----------|----------|----------|
| **CPU** | Arm Cortex-M33 | Arm Cortex-M33 |
| **Clock** | 128 MHz | 64 MHz |
| **Flash** | 1 MB | 256 KB |
| **SRAM** | 512 KB | 64 KB |
| **FPU** | Yes (single precision) | Yes |
| **DSP** | Yes | Yes |
| **TrustZone** | Yes (optional) | No |
| **CryptoCell** | CC312 (AES, SHA, ECC, RNG) | - |
| **QSPI** | 1× (shared: nRF7002 + MX25R) | - |
| **UARTE** | 4× instances | 1× instance |
| **SPI/I2C** | 4× SPIM/TWIM | - |
| **GPIO** | 2× ports (P0, P1), 48 GPIOs | - |
| **ADC** | 1× SAADC (8 channels) | - |
| **POFCON** | Power-failure comparator | - |

### 3.2 Development Board: nRF7002-DK

**Board identifier in Zephyr:** `nrf7002dk/nrf5340/cpuapp` (app core), `nrf7002dk/nrf5340/cpunet` (net core).

The nRF7002-DK provides:

- nRF5340 SoC (app + net cores).
- nRF7002 WiFi 6 companion IC (QSPI interface).
- MX25R6435F 8 MB QSPI NOR flash (shared QSPI bus with nRF7002, separate chip-select).
- On-board SEGGER J-Link debugger (SWD + RTT).
- 2× UART via USB (one for app core logging, one configurable).
- 4× buttons, 2× LEDs.
- Arduino-compatible headers for shield expansion.

### 3.3 Memory Map

#### 3.3.1 Internal Flash (1 MB - App Core)

```
Address         Size        Purpose
──────────────────────────────────────────────
0x0000_0000     48 KB       MCUboot bootloader
0x0000_C000     448 KB      Application image (primary slot)
0x0007_C000     16 KB       MCUboot scratch area (swap status)
0x0008_0000     448 KB      [UNUSED - secondary slot on external flash]
0x000F_0000     32 KB       NVS (runtime config, WiFi creds, device ID)
0x000F_8000     32 KB       Reserved (future use / manufacturing data)
──────────────────────────────────────────────
Total: 1 MB (1,024 KB)
```

> **Note:** The MCUboot secondary slot is located on external QSPI flash, not internal. This maximizes internal flash for the application image.

#### 3.3.2 External QSPI NOR Flash (8 MB - MX25R6435F)

```
Offset          Size        Purpose
──────────────────────────────────────────────
0x000_0000      1 MB        MCUboot secondary slot (OTA staging)
0x010_0000      6.5 MB      LittleFS data partition
0x078_0000      512 KB      Crash log / core dump partition
──────────────────────────────────────────────
Total: 8 MB (8,192 KB)
```

#### 3.3.3 SRAM (512 KB - App Core)

| Subsystem | Estimated Allocation | Notes |
|-----------|---------------------|-------|
| Zephyr kernel + stacks | ~40 KB | Kernel objects, idle/ISR stacks |
| BLE Host buffers | ~20 KB | ACL buffers, ATT MTU, GATT DB |
| WiFi driver buffers | ~80 KB | nRF7002 TX/RX buffers, management frames |
| MQTT + TLS (Mbed TLS) | ~60 KB | TLS session, MQTT buffers, Mbed TLS heap |
| Z-Wave Serial API | ~16 KB | TX/RX frame buffers, device table (32 entries) |
| Shadow Manager | ~24 KB | JSON parse buffers, shadow document cache |
| Rule Engine | ~8 KB | Rule table, evaluation workspace |
| LittleFS cache | ~16 KB | Read/prog cache, lookahead buffer |
| Shell subsystem | ~12 KB | Command buffers, history |
| Logging buffers | ~8 KB | Deferred log processing |
| Application threads | ~48 KB | Thread stacks (see §4.2) |
| **Heap / remaining** | **~180 KB** | Dynamic allocations, safety margin |
| **Total** | **512 KB** | |

> These are estimates. Precise values will be determined after Phase 1 build and `ram_report` analysis.

### 3.4 Peripheral Allocation Table

| Peripheral | Instance | Assignment | Pins (nRF7002-DK) | Notes |
|------------|----------|------------|--------------------|-------|
| UARTE | 0 | Debug console / Shell | P1.00 (TX), P1.01 (RX) | Via on-board J-Link USB |
| UARTE | 1 | Z-Wave Serial API | P1.02 (TX), P1.03 (RX), P1.04 (RTS), P1.05 (CTS) | To ZGM230S module; HW flow control |
| QSPI | 0 | nRF7002 + MX25R6435F | P0.17–P0.22 (CLK, CSn, IO0–3), P0.12 (nRF7002 CSn) | Shared bus, separate CS lines |
| GPIO | - | nRF7002 enable/IRQ | P0.12 (IOVDD_CTRL), P0.23 (HOST_IRQ), P0.24 (COEX_REQ) | Per nRF7002-DK schematic |
| GPIO | - | ZGM230S RESET | P1.06 | Active-low reset to Z-Wave module |
| GPIO | - | Power-fail detect (POFCON) | Internal | POFCON comparator, threshold configurable in software |
| GPIO | - | LEDs | P1.06 (LED1), P1.07 (LED2) | Status indication |
| GPIO | - | Buttons | P1.08–P1.11 | User button(s), factory reset |
| SWD | - | Debug / RTT | - | Via on-board J-Link |

> **Note:** Exact pin assignments for the ZGM230S interface depend on the external wiring. The above are representative allocations on available Arduino header pins. A devicetree overlay will formalize this.

### 3.5 Power Architecture

```
┌──────────────┐
│ DC Input     │───►┌──────────┐───► 3.3V rail ───► nRF5340
│ (5V USB /    │    │ Voltage  │                     nRF7002
│  AC adapter) │    │ Regulator│───► ZGM230S VCC     MX25R6435F
└──────┬───────┘    └──────────┘
       │                │
       │           ┌────▼─────┐
       └──────────►│ Supercap │ (or small LiPo)
                   │ / Battery│
                   │ Backup   │
                   └──────────┘
                        │
                   Provides ~100 ms–1 s hold-up
                   for POFCON → state save → halt
```

**POFCON Configuration:**

- Threshold: Set to trigger at ~2.8V (below 3.3V nominal, above brown-out reset ~1.7V).
- ISR priority: Highest application priority (preempts all except kernel faults).
- Action: Signal shutdown event to System Manager → flush pending writes → halt.

### 3.6 Clock Tree

| Clock Source | Frequency | Consumer |
|-------------|-----------|----------|
| HFCLK (external XTAL) | 32 MHz | CPU (PLL to 128/64 MHz), QSPI, UARTE |
| LFCLK (external 32.768 kHz XTAL) | 32.768 kHz | RTC, kernel tick (if tickless idle used) |
| HFCLK (internal RC) | 64 MHz | Fallback, initial boot |

### 3.7 Hardware Watchdog

- **WDT0** enabled with a timeout of **8 seconds** (configurable via Kconfig).
- Fed by the System Manager thread at the end of each main loop iteration.
- If any critical thread deadlocks and System Manager cannot confirm health, WDT fires a system reset.
- MCUboot image confirmation must happen **after** successful boot and shadow sync to prevent confirming a broken OTA image.

---

## 4. Zephyr RTOS Configuration

### 4.1 Key Kconfig Selections

```kconfig
# Core
CONFIG_SOC_NRF5340_CPUAPP=y
CONFIG_BOARD_NRF7002DK_NRF5340_CPUAPP=y

# Kernel
CONFIG_MULTITHREADING=y
CONFIG_TIMESLICING=y
CONFIG_NUM_PREEMPT_PRIORITIES=16
CONFIG_NUM_COOP_PRIORITIES=16
CONFIG_MAIN_STACK_SIZE=4096
CONFIG_SYSTEM_WORKQUEUE_STACK_SIZE=2048
CONFIG_ISR_STACK_SIZE=2048
CONFIG_IDLE_STACK_SIZE=512

# Memory
CONFIG_HEAP_MEM_POOL_SIZE=32768
CONFIG_KERNEL_MEM_POOL=y

# Networking
CONFIG_NETWORKING=y
CONFIG_NET_IPV4=y
CONFIG_NET_TCP=y
CONFIG_NET_SOCKETS=y
CONFIG_NET_DHCPV4=y
CONFIG_DNS_RESOLVER=y
CONFIG_WIFI=y
CONFIG_WIFI_NRF700X=y

# Bluetooth
CONFIG_BT=y
CONFIG_BT_HCI_IPC=y
CONFIG_BT_PERIPHERAL=y
CONFIG_BT_CENTRAL=y
CONFIG_BT_SMP=y
CONFIG_BT_GATT_DYNAMIC_DB=y

# MQTT
CONFIG_MQTT_LIB=y
CONFIG_MQTT_KEEPALIVE=60

# TLS
CONFIG_MBEDTLS=y
CONFIG_MBEDTLS_TLS_VERSION_1_2=y
CONFIG_MBEDTLS_KEY_EXCHANGE_ECDHE_ECDSA_ENABLED=y
CONFIG_MBEDTLS_ECP_DP_SECP256R1_ENABLED=y
CONFIG_NET_SOCKETS_SOCKOPT_TLS=y
CONFIG_TLS_CREDENTIAL_FILENAMES=y

# File System
CONFIG_FILE_SYSTEM=y
CONFIG_FILE_SYSTEM_LITTLEFS=y
CONFIG_FLASH=y
CONFIG_FLASH_MAP=y
CONFIG_FLASH_PAGE_LAYOUT=y
CONFIG_SPI_NOR=y

# NVS
CONFIG_NVS=y
CONFIG_SETTINGS=y
CONFIG_SETTINGS_NVS=y

# Shell
CONFIG_SHELL=y
CONFIG_SHELL_BACKEND_SERIAL=y
CONFIG_SHELL_LOG_BACKEND=y

# Logging
CONFIG_LOG=y
CONFIG_LOG_MODE_DEFERRED=y
CONFIG_LOG_BACKEND_UART=y
CONFIG_LOG_BACKEND_RTT=y
CONFIG_USE_SEGGER_RTT=y

# Watchdog
CONFIG_WATCHDOG=y
CONFIG_WDT_NRFX=y

# MCUboot
CONFIG_BOOTLOADER_MCUBOOT=y
CONFIG_MCUBOOT_IMG_MANAGER=y
CONFIG_IMG_MANAGER=y

# Power Management
CONFIG_PM=y
CONFIG_NRFX_POWER=y
```

> Debug-build additions (controlled by overlay `debug.conf`):
> ```kconfig
> CONFIG_THREAD_ANALYZER=y
> CONFIG_THREAD_NAME=y
> CONFIG_SHELL_CMDS_RESIZE=y
> # Extended shell commands (Q32: option C additions)
> CONFIG_NET_SHELL=y
> CONFIG_SENSOR_SHELL=y
> ```

### 4.2 Thread Model & Priority Map

| Thread | Priority | Stack (bytes) | Type | Purpose |
|--------|----------|---------------|------|---------|
| `main` | 0 (preempt) | 4096 | Startup | Initialization sequence, then becomes System Manager |
| `system_mgr` | 1 | 3072 | Preempt | State machine, WDT feed, health monitor |
| `wifi_mgr` | 2 | 4096 | Preempt | WiFi connection management, DHCP, reconnect |
| `mqtt_client` | 3 | 4096 | Preempt | MQTT connect, publish, subscribe, keepalive |
| `shadow_mgr` | 4 | 4096 | Preempt | Shadow delta processing, JSON parse/serialize |
| `zwave_host` | 2 | 4096 | Preempt | Serial API TX/RX, command dispatch, device table |
| `rule_engine` | 6 | 2048 | Preempt | Rule evaluation on state-change events |
| `ble_mgr` | 5 | 2048 | Preempt | BLE advertising, GATT server, provisioning flow |
| `storage_mgr` | 7 | 2048 | Preempt | Deferred file writes, LittleFS operations |
| `shell` | 14 | 3072 | Preempt | Interactive CLI (UART) |
| `logging` | 15 | 1024 | Preempt | Deferred log processing |
| `sysworkq` | -1 (coop) | 2048 | Coop | Zephyr system work queue (deferred ISR work) |
| `rx_workq` | -2 (coop) | 2048 | Coop | Network RX processing |

**Total thread stack allocation:** ~39 KB

**Priority design rationale:**

- Z-Wave and WiFi at same priority (2) - they operate on independent interfaces and rarely contend.
- MQTT below WiFi (3) - WiFi link must be stable before MQTT can operate.
- BLE (5) is medium priority - only active during provisioning, not latency-critical.
- Rule engine (6) runs after shadow updates are processed.
- Shell and logging are lowest priority - they must never starve real-time operations.

### 4.3 Inter-Thread Communication

| Mechanism | Usage |
|-----------|-------|
| **Message Queue** (`k_msgq`) | Z-Wave Host → Shadow Manager (device state updates); Shadow Manager → Rule Engine (state-change events); MQTT Client → Shadow Manager (incoming deltas) |
| **Event Flags** (`k_event`) | System Manager broadcasts mode transitions (OPERATIONAL, DEGRADED, SHUTDOWN) to all threads |
| **Semaphore** (`k_sem`) | LittleFS access serialization (single-writer) |
| **FIFO** (`k_fifo`) | Serial API RX byte stream buffering (ISR → zwave_host thread) |
| **Work Queue** | Deferred operations: certificate loading, shadow JSON serialization, crash log write |

### 4.4 Interrupt Architecture

| IRQ Source | Priority | Handler |
|-----------|----------|---------|
| POFCON (power fail) | 0 (highest) | Set shutdown event flag, minimal work |
| UARTE1 RX (Z-Wave) | 1 | Byte into FIFO ring buffer, signal zwave_host |
| QSPI (nRF7002 + flash) | 2 | Handled by nRF7002 WiFi driver / flash driver |
| BLE (via IPC from net core) | 2 | Zephyr BT HCI driver |
| UARTE0 RX (shell) | 3 | Shell UART backend |
| RTC / kernel tick | 4 | System tick (if not tickless) |
| WDT | NMI | Hard reset |

### 4.5 Devicetree Overlay Strategy

A custom overlay file `app.overlay` will be created to:

1. Define the LittleFS partition on external flash.
2. Define the crash log partition on external flash.
3. Assign UARTE1 to Z-Wave with flow control pins.
4. Configure the ZGM230S reset GPIO.
5. Refine QSPI pin configuration if needed.

```dts
/* Skeleton - to be refined in Phase 1 */

/ {
    chosen {
        zephyr,console = &uart0;
        zephyr,shell-uart = &uart0;
    };
};

&uart1 {
    status = "okay";
    current-speed = <115200>;
    hw-flow-control;
    /* pinctrl defined in board DTS; override if needed */
};

/ {
    zwave_module {
        compatible = "gpio-keys";
        zwave_reset: zwave_reset {
            gpios = <&gpio1 6 GPIO_ACTIVE_LOW>;
            label = "Z-Wave Module Reset";
        };
    };
};

/ {
    fstab {
        compatible = "zephyr,fstab";
        lfs1: lfs1 {
            compatible = "zephyr,fstab,littlefs";
            mount-point = "/lfs";
            partition = <&lfs1_partition>;
            automount;
            read-size = <256>;
            prog-size = <256>;
            cache-size = <4096>;
            lookahead-size = <256>;
            block-cycles = <512>;
        };
    };
};

&mx25r64 {
    partitions {
        compatible = "fixed-partitions";
        #address-cells = <1>;
        #size-cells = <1>;

        mcuboot_secondary_partition: partition@0 {
            label = "mcuboot-secondary";
            reg = <0x00000000 0x00100000>;  /* 1 MB */
        };
        lfs1_partition: partition@100000 {
            label = "littlefs-storage";
            reg = <0x00100000 0x00680000>;  /* 6.5 MB */
        };
        crash_partition: partition@780000 {
            label = "crash-log";
            reg = <0x00780000 0x00080000>;  /* 512 KB */
        };
    };
};
```

---

## 5. Connectivity - WiFi

### 5.1 Module: nRF7002

- **Interface:** QSPI (shared bus with MX25R6435F, separate chip-select).
- **Protocol:** WiFi 6 (802.11ax), 2.4 GHz band.
- **Driver:** `CONFIG_WIFI_NRF700X=y` - Zephyr native WiFi driver, MAC offload to nRF7002, IP stack on nRF5340.
- **Zephyr network stack:** Full native Zephyr networking (BSD sockets API, TCP/IP, DHCP, DNS).

### 5.2 WiFi Connection Lifecycle

```
INIT ──► SCAN (if SSID unknown) ──► ASSOCIATE ──► DHCP ──► CONNECTED
                                                               │
                                                    ┌──────────┤
                                                    │  Periodic │
                                                    │  RSSI     │
                                                    │  Monitor  │
                                                    │          │
                                              DISCONNECTED ◄───┘
                                                    │
                                              Backoff retry
                                              (1s, 2s, 4s, 8s, 16s, 30s max)
                                                    │
                                              ASSOCIATE ──► ...
```

### 5.3 WiFi Manager Responsibilities

1. **Credential retrieval:** Read SSID and PSK from LittleFS (`/lfs/config/wifi.json`).
2. **Connection:** `net_mgmt(NET_REQUEST_WIFI_CONNECT, ...)` with stored credentials.
3. **DHCP:** Automatic via `CONFIG_NET_DHCPV4=y`.
4. **Monitoring:** Register `NET_EVENT_WIFI_CONNECT_RESULT`, `NET_EVENT_WIFI_DISCONNECT` callbacks.
5. **Reconnection:** Exponential backoff (1s → 30s cap). After 5 consecutive failures, post `EVENT_WIFI_FAILED` to System Manager.
6. **Signal quality:** Periodic RSSI query (every 60s). Log warning if RSSI < -75 dBm.
7. **Power save:** Enable WiFi power save mode (TWT if AP supports it) when on mains power (balances latency vs. nRF7002 power draw for thermal reasons).

### 5.4 WiFi Configuration Data

Stored at `/lfs/config/wifi.json`:

```json
{
    "ssid": "HomeNetwork",
    "psk": "encrypted_base64_string",
    "security": "WPA2-PSK",
    "band": "2.4GHz",
    "channel": 0
}
```

> The PSK is encrypted at rest using a key derived from the device unique ID (see §11.5). Decrypted in RAM only when needed for association.

---

## 6. Connectivity - Z-Wave

### 6.1 Module: Silicon Labs ZGM230S (Z-Wave 800)

| Parameter | Value |
|-----------|-------|
| **IC** | ZGM230S (EFR32ZG23 based) |
| **Protocol** | Z-Wave (ITU-T G.9959), Z-Wave Long Range |
| **Frequency** | Regional: 908.42 MHz (US), 868.42 MHz (EU), etc. |
| **Interface to host** | UART (Serial API), 115200 baud, 8N1, HW flow control |
| **Reset** | Active-low GPIO from nRF5340 |
| **Firmware** | Silicon Labs Z-Wave Serial API controller firmware |

### 6.2 Serial API Host Implementation

The nRF5340 app core runs a **Z-Wave Serial API host** that communicates with the ZGM230S over UARTE1.

#### 6.2.1 Frame Format (Classic Serial API)

```
┌──────┬────────┬──────┬──────────────────┬──────────┐
│ SOF  │ Length │ Type │ Payload          │ Checksum │
│ 0x01 │ 1 byte │ REQ/ │ Function ID +    │ XOR of   │
│      │        │ RES  │ parameters       │ all bytes│
└──────┴────────┴──────┴──────────────────┴──────────┘

ACK = 0x06, NAK = 0x15, CAN = 0x18
```

#### 6.2.2 Host-Side Architecture

```
┌──────────────────────────────────────────────┐
│                zwave_host Thread              │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │ Frame Layer                          │    │
│  │ - UART RX ISR → ring buffer → parse │    │
│  │ - Frame assembly, checksum, ACK/NAK │    │
│  │ - TX frame queue with retry (3×)    │    │
│  │ - Response timeout: 1600 ms         │    │
│  └──────────────┬───────────────────────┘    │
│                 │                             │
│  ┌──────────────▼───────────────────────┐    │
│  │ Command Layer                        │    │
│  │ - Function dispatch table            │    │
│  │ - Callback registration              │    │
│  │ - Async command/response correlation │    │
│  └──────────────┬───────────────────────┘    │
│                 │                             │
│  ┌──────────────▼───────────────────────┐    │
│  │ Application Layer                    │    │
│  │ - Network management (add/remove)    │    │
│  │ - Device table (≤32 nodes)          │    │
│  │ - Command class handlers             │    │
│  │ - State change → event bus           │    │
│  └──────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

#### 6.2.3 Supported Serial API Functions

| Function ID | Name | Purpose |
|------------|------|---------|
| 0x04 | `FUNC_ID_APPLICATION_COMMAND_HANDLER` | Receive commands from end-devices |
| 0x05 | `FUNC_ID_ZW_GET_CONTROLLER_CAPABILITIES` | Query controller type |
| 0x07 | `FUNC_ID_SERIAL_API_GET_INIT_DATA` | Get node list at startup |
| 0x13 | `FUNC_ID_ZW_SEND_DATA` | Send command to a node |
| 0x41 | `FUNC_ID_ZW_GET_NODE_PROTOCOL_INFO` | Get node type/capability |
| 0x4A | `FUNC_ID_ZW_ADD_NODE_TO_NETWORK` | Inclusion mode |
| 0x4B | `FUNC_ID_ZW_REMOVE_NODE_FROM_NETWORK` | Exclusion mode |
| 0x80 | `FUNC_ID_ZW_GET_NETWORK_STATS` | Network statistics |

> Full function table in Appendix D.

### 6.3 Z-Wave Device Table

An in-RAM table of up to 32 Z-Wave nodes:

```c
#define ZWAVE_MAX_NODES 32

struct zwave_device {
    uint8_t  node_id;                  /* Z-Wave node ID (1–232) */
    uint8_t  device_type;              /* Generic + specific device class */
    uint8_t  command_classes[16];       /* Supported CCs */
    uint8_t  cc_count;
    uint8_t  security_level;           /* None, S0, S2 */
    uint8_t  endpoint_count;           /* Multi-channel endpoints */
    bool     is_listening;             /* Always-on vs. sleeping */
    bool     is_reachable;             /* Last communication success */
    uint32_t last_seen_timestamp;      /* Uptime tick of last message */
    char     name[32];                 /* User-assigned friendly name */
};

static struct zwave_device device_table[ZWAVE_MAX_NODES];
```

This table is:

- **Loaded** from LittleFS (`/lfs/zwave/devices.json`) at boot.
- **Updated** in RAM on inclusion/exclusion events and state reports.
- **Persisted** to LittleFS on changes (debounced, max every 5 seconds).
- **Mirrored** to named shadows on change (one shadow per device).

### 6.4 Z-Wave Network Management

| Operation | Trigger | Flow |
|-----------|---------|------|
| **Inclusion** | Shell command `zwave add` or cloud command via shadow | Enter inclusion mode → wait for node → interview (get CCs) → add to table → persist → create named shadow |
| **Exclusion** | Shell command `zwave remove <id>` or cloud command | Enter exclusion mode → wait for node → remove from table → persist → delete named shadow |
| **Heal** | Shell command `zwave heal` or periodic (weekly) | Re-assign routes for all nodes - improves mesh reliability |
| **Factory reset** | Shell command `zwave reset` | Send reset to ZGM230S → clear device table → clear all device shadows |

### 6.5 Z-Wave S2 Security

- The ZGM230S Serial API firmware handles S2 key exchange internally.
- The host (nRF5340) receives the S2 inclusion request callback and must provide the DSK (Device Specific Key) if prompted.
- For gateway inclusion: DSK can be entered via BLE provisioning flow or shell.
- S2 security class selection (S2 Unauthenticated, S2 Authenticated, S2 Access Control) is passed from the host to the Z-Wave module during inclusion.

---

## 7. Connectivity - BLE

### 7.1 Stack Configuration

- **Controller:** `hci_ipc` running on nRF5340 net core.
- **Host:** Zephyr Bluetooth Host running on app core.
- **Modes:** Peripheral (provisioning) + Central (optional scanning for BLE sensors in future).
- **Concurrent Central + Peripheral:** Supported by Zephyr BT host with `CONFIG_BT_CENTRAL=y` and `CONFIG_BT_PERIPHERAL=y`.
- **BLE power policy:** BLE advertising starts on entry to PROVISIONING mode. In OPERATIONAL mode, BLE is **disabled** (radio powered down) unless explicitly re-enabled via shell or cloud command.

### 7.2 Peripheral Mode - Commissioning GATT Service

#### 7.2.1 Service Definition

| Field | Value |
|-------|-------|
| **Service UUID** | `A1B2C3D4-E5F6-7890-ABCD-EF1234567890` (128-bit custom) |
| **Service Name** | SHG Provisioning Service |

#### 7.2.2 Characteristics

| Characteristic | UUID (short) | Properties | Max Length | Purpose |
|---------------|-------------|------------|-----------|---------|
| WiFi SSID | `0001` | Write | 32 bytes | Receive WiFi network name |
| WiFi PSK | `0002` | Write | 64 bytes | Receive WiFi password (encrypted in transit via BLE pairing) |
| WiFi Status | `0003` | Read, Notify | 1 byte | 0=disconnected, 1=connecting, 2=connected, 3=failed |
| AWS Endpoint | `0004` | Write | 128 bytes | AWS IoT endpoint URL |
| AWS Client ID | `0005` | Write | 64 bytes | AWS IoT thing name |
| Device Certificate | `0006` | Write | 2048 bytes | X.509 device cert (PEM, chunked writes) |
| Private Key | `0007` | Write | 2048 bytes | Device private key (PEM, chunked writes) |
| Root CA | `0008` | Write | 2048 bytes | AWS Root CA cert (PEM, chunked writes) |
| Provisioning Command | `0009` | Write | 1 byte | 0x01=save & connect, 0x02=reset, 0x03=status query |
| Provisioning Status | `000A` | Read, Notify | 1 byte | Overall status: 0=idle, 1=saving, 2=connecting, 3=success, 4=error |

#### 7.2.3 BLE Advertising

- **Name:** `SHG-<last4_of_MAC>` (e.g., `SHG-A1B2`)
- **Advertising interval:** 100 ms (fast) for first 30 seconds, then 1000 ms (slow).
- **Advertising data:** Flags + Complete Local Name + Service UUID.
- **Connectable:** Yes, undirected.
- **Timeout:** 10 minutes of advertising with no connection → stop advertising, retry on button press.

#### 7.2.4 BLE Security

- **Pairing:** LE Secure Connections (LESC) with Just Works or Numeric Comparison.
- **Bonding:** Not required for provisioning (one-time setup).
- **Encryption:** Required before any characteristic write is accepted (enforced via BT_GATT_PERM_WRITE_ENCRYPT).
- **MITM protection:** Numeric Comparison recommended if mobile app supports it.

### 7.3 Provisioning Flow

```
Mobile App                           Gateway (BLE Peripheral)
    │                                      │
    │──── BLE Scan ────────────────────────►│ (Advertising "SHG-XXXX")
    │◄─── Adv Response ───────────────────│
    │                                      │
    │──── Connect ─────────────────────────►│
    │──── Pair (LESC) ─────────────────────►│
    │◄─── Pairing complete ─────────────── │
    │                                      │
    │──── Write WiFi SSID ─────────────────►│
    │──── Write WiFi PSK ──────────────────►│
    │──── Write AWS Endpoint ──────────────►│
    │──── Write AWS Client ID ─────────────►│
    │──── Write Device Cert (chunked) ─────►│
    │──── Write Private Key (chunked) ─────►│
    │──── Write Root CA (chunked) ──────────►│
    │                                      │
    │──── Write Prov Cmd = 0x01 (save) ────►│
    │                                      │ ── Save to LittleFS
    │                                      │ ── Attempt WiFi connect
    │◄─── Notify WiFi Status = 1 ──────── │ (connecting)
    │                                      │ ── WiFi connected
    │◄─── Notify WiFi Status = 2 ──────── │ (connected)
    │                                      │ ── Attempt MQTT connect
    │◄─── Notify Prov Status = 3 ──────── │ (success)
    │                                      │
    │──── Disconnect ──────────────────────►│
    │                                      │ ── Disable BLE advertising
    │                                      │ ── Transition to OPERATIONAL
```

---

## 8. Cloud & IoT Integration

### 8.1 MQTT Client Architecture

- **Library:** Zephyr built-in MQTT (`CONFIG_MQTT_LIB=y`).
- **Transport:** TLS 1.2 over TCP (port 8883).
- **Authentication:** Mutual TLS (mTLS) - device cert + private key.
- **Keep-alive:** 60 seconds (`CONFIG_MQTT_KEEPALIVE=60`).
- **QoS:** QoS 1 (at least once) for shadow updates. QoS 0 for telemetry/logs.
- **Clean session:** `false` (persistent session - AWS IoT Core queues messages during disconnect, up to 1 hour).

### 8.2 AWS IoT Connection

| Parameter | Value |
|-----------|-------|
| **Endpoint** | Stored in `/lfs/config/aws.json` (provisioned via BLE) |
| **Client ID** | AWS IoT Thing Name (stored in `/lfs/config/aws.json`) |
| **Port** | 8883 (MQTT over TLS) |
| **Certificates** | Device cert: `/lfs/certs/device.pem.crt`, Private key: `/lfs/certs/private.pem.key`, Root CA: `/lfs/certs/root-ca.pem` |
| **Reconnect** | Exponential backoff: 1s, 2s, 4s, 8s, 16s, 32s, 60s max |
| **Session** | Persistent (clean_session=0) |

### 8.3 MQTT Topic Structure

Let `{thingName}` be the gateway's AWS IoT Thing Name.

#### 8.3.1 Gateway Shadow Topics

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `$aws/things/{thingName}/shadow/name/gateway/update` | Publish | Report gateway state + update rules |
| `$aws/things/{thingName}/shadow/name/gateway/update/delta` | Subscribe | Receive desired state changes (config, rules) |
| `$aws/things/{thingName}/shadow/name/gateway/update/accepted` | Subscribe | Confirm shadow update accepted |
| `$aws/things/{thingName}/shadow/name/gateway/update/rejected` | Subscribe | Handle rejected updates |
| `$aws/things/{thingName}/shadow/name/gateway/get` | Publish | Request full shadow document |
| `$aws/things/{thingName}/shadow/name/gateway/get/accepted` | Subscribe | Receive full shadow on request |

#### 8.3.2 Z-Wave Device Shadow Topics (per device)

For each Z-Wave device with shadow name `zwave-node-{nodeId}`:

| Topic | Direction | Purpose |
|-------|-----------|---------|
| `$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/update` | Publish | Report device state |
| `$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/update/delta` | Subscribe | Receive desired state (commands) |
| `$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/update/accepted` | Subscribe | Confirm accepted |
| `$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/get` | Publish | Request full device shadow |
| `$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/get/accepted` | Subscribe | Receive full device shadow |

> Topic subscriptions use wildcards where possible:
> `$aws/things/{thingName}/shadow/name/+/update/delta` - single subscription for all named shadow deltas.

### 8.4 Shadow Document Schemas

#### 8.4.1 Gateway Shadow (`gateway`)

```json
{
    "state": {
        "desired": {
            "config": {
                "wifi_power_save": true,
                "zwave_heal_interval_hours": 168,
                "log_level": "INF",
                "ble_on_demand": true
            },
            "rules": [
                {
                    "id": "rule_001",
                    "enabled": true,
                    "condition": {
                        "device_node_id": 5,
                        "property": "binary_switch",
                        "operator": "==",
                        "value": true
                    },
                    "action": {
                        "device_node_id": 8,
                        "command_class": "SWITCH_BINARY",
                        "command": "SET",
                        "value": true
                    }
                }
            ],
            "ota": {
                "version": "1.2.0",
                "url": "https://...",
                "checksum": "sha256:abcdef..."
            }
        },
        "reported": {
            "firmware_version": "1.1.0",
            "uptime_seconds": 86400,
            "wifi_rssi": -52,
            "wifi_ip": "192.168.1.100",
            "zwave_node_count": 5,
            "zwave_home_id": "0xFA12B3C4",
            "free_heap_bytes": 102400,
            "fs_free_bytes": 5242880,
            "battery_backup": "mains_ok",
            "rules_loaded": 3,
            "last_cloud_sync": "2026-04-21T10:30:00Z"
        }
    }
}
```

#### 8.4.2 Z-Wave Device Shadow (`zwave-node-{nodeId}`)

```json
{
    "state": {
        "desired": {
            "binary_switch": true,
            "dimmer_level": 75
        },
        "reported": {
            "binary_switch": false,
            "dimmer_level": 50,
            "battery_level": 85,
            "device_type": "SWITCH_BINARY",
            "name": "Living Room Light",
            "security": "S2_UNAUTHENTICATED",
            "is_reachable": true,
            "last_seen": "2026-04-21T10:28:00Z"
        }
    }
}
```

### 8.5 Shadow Delta Processing Flow

```
AWS IoT Core                    Gateway
    │                              │
    │── Shadow delta ─────────────►│ (MQTT message on .../delta topic)
    │   (desired != reported)      │
    │                              │── Parse JSON delta
    │                              │── Identify target:
    │                              │     Gateway config? → Apply config
    │                              │     Gateway rules?  → Update rule table
    │                              │     Device command?  → Dispatch to Z-Wave
    │                              │
    │                              │── [If device command]:
    │                              │     Z-Wave SEND_DATA to node
    │                              │     Wait for status callback
    │                              │
    │                              │── Update reported state
    │◄── Shadow update (reported) ─│
    │                              │
```

### 8.6 Offline Buffering

When WiFi or MQTT is disconnected:

1. **Z-Wave state changes** continue to be received and processed locally.
2. State changes are written to a **pending queue file** (`/lfs/shadow/pending.json`) - max 64 entries, FIFO eviction.
3. Rules continue to execute locally against the in-RAM device state.
4. On reconnection, the Shadow Manager:
   - Publishes all pending reported state updates.
   - Requests full gateway shadow (`get`) to sync any missed desired changes.
   - Reconciles and applies missed deltas.

### 8.7 OTA Update via Shadow

OTA updates are triggered via the gateway shadow's `desired.ota` field:

1. Shadow delta contains `desired.ota` with `version`, `url`, `checksum`.
2. Shadow Manager posts event to System Manager → enter OTA_UPDATE mode.
3. MQTT client downloads image from provided URL (HTTPS GET, chunked) or via a secondary MQTT topic.
4. Image written to MCUboot secondary slot (external flash, 1 MB).
5. SHA-256 checksum verified against `desired.ota.checksum`.
6. If valid, `boot_request_upgrade(BOOT_UPGRADE_TEST)` - marks secondary slot for swap.
7. Report `reported.ota.status = "pending_reboot"`.
8. System Manager initiates controlled reboot.
9. MCUboot swaps images on next boot. Application confirms image via `boot_write_img_confirmed()` after successful shadow sync.
10. If confirmation fails (boot loop), MCUboot reverts to previous image on next reset.

---

## 9. Local Intelligence

### 9.1 Rule Engine Architecture

The rule engine is a lightweight **IF-THEN evaluator** that:

- Loads rules from the gateway's named shadow (`desired.rules` array).
- Subscribes to device state-change events via the internal event bus.
- Evaluates conditions against current device state.
- Dispatches actions to the Z-Wave host.
- Operates independently of cloud connectivity (local execution guarantee).

### 9.2 Rule Data Model

```c
#define MAX_RULES 16
#define RULE_ID_LEN 16

struct rule_condition {
    uint8_t  device_node_id;    /* Z-Wave node ID to monitor */
    char     property[32];       /* e.g., "binary_switch", "temperature" */
    enum {
        OP_EQ,    /* == */
        OP_NE,    /* != */
        OP_GT,    /* >  */
        OP_LT,    /* <  */
        OP_GTE,   /* >= */
        OP_LTE    /* <= */
    } operator;
    int32_t  value;              /* Comparison value (integer, scaled) */
};

struct rule_action {
    uint8_t  device_node_id;    /* Z-Wave node ID to command */
    uint8_t  command_class;      /* Z-Wave CC (e.g., 0x25 = SWITCH_BINARY) */
    uint8_t  command;            /* CC command (e.g., SET) */
    int32_t  value;              /* Command value */
};

struct rule {
    char     id[RULE_ID_LEN];   /* Unique rule identifier */
    bool     enabled;
    struct rule_condition condition;
    struct rule_action action;
};

static struct rule rule_table[MAX_RULES];
static int rule_count;
```

### 9.3 Rule Evaluation Flow

```
Device State Change Event (from Z-Wave host or Shadow delta)
    │
    ▼
┌───────────────────────────────┐
│ For each enabled rule:        │
│   Does condition.device_node  │
│   match the changed device?   │
│     │ No → skip               │
│     │ Yes ↓                   │
│   Does condition.property     │
│   match the changed property? │
│     │ No → skip               │
│     │ Yes ↓                   │
│   Evaluate: current_value     │
│   <operator> condition.value  │
│     │ False → skip            │
│     │ True ↓                  │
│   Execute action:             │
│   Send Z-Wave command to      │
│   action.device_node_id       │
│                               │
│ Throttle: max 1 action per    │
│ rule per 2 seconds (debounce) │
└───────────────────────────────┘
```

### 9.4 Rule Persistence

- Rules arrive as part of the gateway shadow `desired.rules` array.
- Parsed from JSON and loaded into `rule_table[]`.
- Cached in LittleFS (`/lfs/shadow/gateway_rules.json`) for offline access.
- On boot, rules are loaded from the LittleFS cache. On shadow sync, the cache is refreshed.

---

## 10. File System & Persistent Storage

### 10.1 LittleFS Configuration

- **Partition:** 6.5 MB on external QSPI NOR flash (MX25R6435F).
- **Block size:** 4 KB (matches flash erase sector size).
- **Read/Prog size:** 256 bytes.
- **Cache size:** 4 KB (1 block).
- **Lookahead size:** 256 bytes (covers 256 × 8 × 4 KB = 8 MB).
- **Block cycles:** 512 (wear leveling target before moving data).
- **Mount point:** `/lfs`.

### 10.2 Directory Structure

```
/lfs/
├── config/
│   ├── wifi.json           # WiFi SSID, encrypted PSK, security type
│   ├── aws.json            # AWS endpoint, thing name, client ID
│   └── system.json         # Device name, timezone, misc config
├── certs/
│   ├── device.pem.crt      # X.509 device certificate
│   ├── private.pem.key     # Device private key (encrypted at rest)
│   └── root-ca.pem         # AWS Root CA certificate
├── zwave/
│   ├── devices.json         # Device table (≤32 entries)
│   └── network.json         # Home ID, SUC ID, network keys
├── shadow/
│   ├── gateway.json         # Last known gateway shadow (cache)
│   ├── gateway_rules.json   # Cached rules from shadow
│   ├── pending.json         # Queued updates for cloud (offline buffer)
│   └── devices/
│       ├── node_02.json     # Cached shadow for Z-Wave node 2
│       ├── node_05.json     # Cached shadow for Z-Wave node 5
│       └── ...
└── logs/
    └── crash_count.json     # Boot count, last crash info
```

### 10.3 NVS Usage

NVS (on internal flash, 32 KB partition) stores small, frequently accessed key-value items:

| NVS ID | Key | Value | Purpose |
|--------|-----|-------|---------|
| 1 | `boot_count` | uint32_t | Total boot count (for diagnostics) |
| 2 | `provisioned` | uint8_t (0/1) | Whether device has been provisioned |
| 3 | `fw_version` | string | Current firmware version |
| 4 | `ota_pending` | uint8_t (0/1) | OTA reboot pending flag |
| 5 | `device_uuid` | uint8_t[16] | Unique device identifier (generated once) |
| 6 | `wifi_configured` | uint8_t (0/1) | WiFi credentials present flag |
| 7 | `zwave_home_id` | uint32_t | Z-Wave network home ID |

### 10.4 Power-Loss Resilience

- **LittleFS** provides atomic file updates with copy-on-write semantics. Power loss during a write results in either the old or new file - never a corrupt file.
- **Critical writes** (device table, shadow cache) use a write-then-rename pattern:
  1. Write to `<filename>.tmp`
  2. Rename `<filename>.tmp` → `<filename>`
  3. LittleFS ensures rename is atomic.
- **NVS** is inherently power-loss safe (append-only log with garbage collection).

---

## 11. Security

### 11.1 Threat Model & Attack Surface

| Attack Surface | Threats | Mitigation |
|---------------|---------|------------|
| **BLE (provisioning)** | Eavesdropping, unauthorized commissioning, MITM | LESC pairing, encrypted characteristics, 10-minute advertising timeout |
| **WiFi** | Credential theft, rogue AP | WPA2/WPA3-PSK, encrypted PSK storage, server cert validation |
| **MQTT/TLS** | Man-in-the-middle, replay | mTLS with device cert, server cert pinning, TLS 1.2, no fallback |
| **Z-Wave** | Eavesdropping, replay, injection | Z-Wave S2 security (AES-128 CCM), S2 Authenticated minimum |
| **UART (debug)** | Unauthorized access to shell | Shell disabled in production unless GPIO strap present; password-protected in production build |
| **OTA** | Malicious firmware, downgrade | MCUboot signed images (ECDSA-P256), anti-rollback (monotonic counter) |
| **Flash storage** | Physical readout of credentials | Sensitive data encrypted at rest (AES-128, key from device unique ID + CryptoCell) |
| **Physical** | JTAG/SWD debug | APPROTECT enabled in production (disables debug port) |

### 11.2 Secure Boot Chain

```
Power On
   │
   ▼
┌──────────────┐
│ nRF5340 ROM  │  Fixed boot ROM validates MCUboot region
│ Secure Boot  │  (if APPROTECT + Secure Boot enabled)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ MCUboot      │  Validates application image signature
│ (48 KB)      │  ECDSA-P256 with SHA-256
│              │  Checks anti-rollback counter
└──────┬───────┘
       │ Signature valid
       ▼
┌──────────────┐
│ Application  │  Self-checks, initializes subsystems
│ (448 KB max) │  Confirms image after successful boot
└──────────────┘
```

### 11.3 MCUboot Image Signing

- **Algorithm:** ECDSA-P256 (secp256r1) with SHA-256.
- **Key management:** Signing key pair generated offline. Public key embedded in MCUboot. Private key stored securely in CI/CD secrets or HSM.
- **Build integration:** `west sign` command in CI pipeline.
- **Anti-rollback:** MCUboot security counter incremented with each release. Images with a lower counter are rejected.

### 11.4 TLS Configuration

| Parameter | Value |
|-----------|-------|
| **Library** | Mbed TLS (Zephyr built-in) |
| **Protocol** | TLS 1.2 (minimum; TLS 1.3 when Zephyr Mbed TLS supports it) |
| **Cipher suites** | TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 (primary) |
| **Key exchange** | ECDHE (Elliptic Curve Diffie-Hellman Ephemeral) |
| **Certificate type** | X.509 v3, RSA-2048 or ECDSA-P256 (per AWS IoT requirements) |
| **Server validation** | Root CA pinning (Amazon Root CA 1) |
| **OCSP/CRL** | Not supported on-device (resource constrained) - rely on short-lived certs or AWS IoT cert rotation |

### 11.5 Credential Encryption at Rest

Sensitive files stored on LittleFS (private keys, WiFi PSK) are encrypted:

- **Algorithm:** AES-128-CTR.
- **Key derivation:** HKDF(SHA-256) with:
  - Input key material: nRF5340 FICR (Factory Information Configuration Registers) device ID (unique per chip).
  - Salt: Fixed application salt (compiled in).
  - Info: File path string.
- **Implementation:** nRF5340 CryptoCell CC312 hardware acceleration.
- **Limitation:** If an attacker has physical access AND can read FICR, they can derive the key. For higher security, a hardware secure element (Q19 option D) can be revisited.

---

## 12. Bootloader & OTA Update

### 12.1 MCUboot Configuration

```kconfig
CONFIG_BOOTLOADER_MCUBOOT=y
CONFIG_MCUBOOT_SIGNATURE_KEY_FILE="keys/mcuboot-ec-p256.pem"
CONFIG_BOOT_SWAP_USING_MOVE=y           # Swap with move (more efficient than scratch)
CONFIG_BOOT_MAX_IMG_SECTORS=256          # Supports up to 1 MB images (256 × 4 KB)
CONFIG_MCUBOOT_IMGTOOL_SIGN_VERSION="0.0.0+0"  # Overridden by CI
CONFIG_BOOT_UPGRADE_ONLY=n              # Allow revert (not overwrite-only)
CONFIG_MCUBOOT_DOWNGRADE_PREVENTION=y   # Anti-rollback
```

### 12.2 Flash Slot Layout

```
┌───────────────────────────── Internal Flash (1 MB) ───────┐
│ MCUboot (48 KB) │ Primary Slot (448 KB) │ Scratch │ NVS   │
│ 0x00000–0x0BFFF │ 0x0C000–0x7BFFF       │ 16 KB   │ 32 KB │
└─────────────────┴───────────────────────┴─────────┴───────┘

┌───────────────── External QSPI Flash (8 MB) ─────────────┐
│ Secondary Slot (1 MB) │ LittleFS (6.5 MB) │ Crash (512K) │
│ 0x000000–0x0FFFFF     │ 0x100000–0x77FFFF │ 0x780000–end │
└───────────────────────┴───────────────────┴──────────────┘
```

### 12.3 OTA Update Sequence

```
1. Gateway receives desired.ota in shadow delta
2. Validate version > current (anti-rollback)
3. Begin HTTP(S) download of image from URL
   └─ Or: receive image chunks via dedicated MQTT topic
4. Write chunks to secondary slot (external flash)
   └─ Progress reported: desired.ota.progress = N%
5. Verify SHA-256 checksum of complete image
6. Call boot_request_upgrade(BOOT_UPGRADE_TEST)
7. Report: reported.ota.status = "pending_reboot"
8. System Manager initiates graceful reboot
9. MCUboot validates secondary image signature
10. MCUboot swaps primary ↔ secondary
11. New application boots
12. Application calls boot_write_img_confirmed() after:
    - WiFi connected
    - MQTT connected
    - Shadow sync successful
    - All subsystems initialized without error
13. If confirmation not called within 120 seconds → WDT resets
14. MCUboot reverts to previous image on next boot (swap back)
```

---

## 13. Serial Port / Debug / Test Interfaces

### 13.1 UART Allocation

| UART Instance | Baud Rate | Flow Control | Purpose |
|--------------|-----------|-------------|---------|
| UARTE0 | 115200 | None | Debug console, Zephyr shell, logging |
| UARTE1 | 115200 | RTS/CTS | Z-Wave Serial API to ZGM230S |

### 13.2 Zephyr Shell Commands

#### 13.2.1 Production Build Commands (Kconfig: `CONFIG_SHG_SHELL_PRODUCTION=y`)

| Command | Subcommand | Description |
|---------|-----------|-------------|
| `shg` | `info` | Print firmware version, device ID, uptime, build date |
| `shg` | `reboot` | Controlled reboot |
| `shg` | `factory_reset` | Erase all config, certs, device table. Reboot into PROVISIONING. |
| `wifi` | `status` | Print WiFi SSID, IP, RSSI, connection state |
| `wifi` | `connect <ssid> <psk>` | Manual WiFi credential entry (factory provisioning) |
| `wifi` | `disconnect` | Disconnect WiFi |
| `zwave` | `status` | Print Z-Wave home ID, node count, controller status |
| `zwave` | `list` | List all devices in device table |
| `zwave` | `add` | Enter inclusion mode (30-second timeout) |
| `zwave` | `remove` | Enter exclusion mode |
| `aws` | `status` | Print MQTT connection state, shadow sync time |
| `aws` | `configure <endpoint> <thing_name>` | Set AWS IoT endpoint |
| `cert` | `load <type> <path>` | Load certificate from host (via UART XMODEM or paste PEM) |
| `fs` | `ls <path>` | List directory |
| `fs` | `cat <path>` | Print file contents |
| `fs` | `rm <path>` | Delete file |
| `shadow` | `dump <name>` | Print cached shadow document |

#### 13.2.2 Debug Build Additions (Kconfig: `CONFIG_SHG_SHELL_DEBUG=y`)

| Command | Subcommand | Description |
|---------|-----------|-------------|
| `mqtt` | `pub <topic> <payload>` | Manual MQTT publish |
| `mqtt` | `sub <topic>` | Manual MQTT subscribe |
| `ble` | `scan` | Start BLE scan (Central mode), print results |
| `ble` | `adv start` | Restart BLE advertising |
| `rule` | `list` | Print loaded rules |
| `rule` | `eval` | Force rule evaluation cycle |
| `rule` | `inject <json>` | Inject a test rule |
| `mem` | `stats` | Print heap usage, thread stack high watermarks |
| `thread` | `list` | Print all threads, priorities, CPU time |
| `log` | `level <module> <level>` | Set runtime log level per module |
| `pwr` | `status` | Print power state (mains/battery), POFCON threshold |
| `crash` | `dump` | Print last crash log |
| `crash` | `trigger` | Force a fault (for testing crash dump) |

### 13.3 Production Test Protocol

A structured test sequence executed via shell commands:

```
1. shg info              → Verify firmware version, device ID
2. wifi connect <ssid>   → Test WiFi radio + association
3. wifi status           → Verify IP address assigned
4. zwave status          → Verify Z-Wave module responds (Serial API FUNC_ID_SERIAL_API_GET_INIT_DATA)
5. ble adv start         → Verify BLE advertising starts
6. fs ls /lfs            → Verify LittleFS mounted
7. mem stats             → Verify no memory leaks (baseline)
8. shg reboot            → Verify clean reboot cycle
```

Exit code / pass criteria printed as structured output for automated test harness parsing.

### 13.4 Aging Test Framework

An automated long-duration stress test:

```
shg aging start <duration_hours>
```

Cycles through:

1. WiFi disconnect → reconnect (every 10 minutes).
2. MQTT disconnect → reconnect (every 15 minutes).
3. Z-Wave SEND_DATA to each node (every 5 minutes, if nodes present).
4. LittleFS write + read + verify (every 1 minute, 4 KB file).
5. Shadow update publish (every 5 minutes).
6. Rule evaluation cycle (every 30 seconds).

Metrics logged to `/lfs/logs/aging_<timestamp>.json`:

- WiFi reconnect count, failures, avg reconnect time.
- MQTT reconnect count, failures.
- Z-Wave TX count, failures, avg round-trip.
- LittleFS write count, verify failures.
- Heap high-watermark, stack high-watermarks.
- Uptime, CPU load (if measurable).

---

## 14. Application Architecture

### 14.1 Software Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                         │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌──────────────┐  │
│  │ System   │ │ Shadow   │ │ Rule      │ │ Provisioning │  │
│  │ Manager  │ │ Manager  │ │ Engine    │ │ Manager      │  │
│  └────┬─────┘ └────┬─────┘ └─────┬─────┘ └──────┬───────┘  │
│       └──────┬─────┴──────┬──────┴───────┬───────┘          │
│              │            │              │                    │
│       ┌──────▼────────────▼──────────────▼────────────┐     │
│       │            EVENT BUS / MESSAGE QUEUES          │     │
│       └──────┬────────────┬──────────────┬────────────┘     │
│              │            │              │                    │
├──────────────┼────────────┼──────────────┼──────────────────┤
│              │   PROTOCOL LAYER          │                    │
│  ┌───────────▼──┐ ┌──────▼─────┐ ┌──────▼──────┐           │
│  │ MQTT Client  │ │ Z-Wave Host│ │ BLE Manager │           │
│  └───────┬──────┘ └──────┬─────┘ └──────┬──────┘           │
│          │               │               │                    │
├──────────┼───────────────┼───────────────┼──────────────────┤
│          │   PLATFORM LAYER              │                    │
│  ┌───────▼──────┐ ┌──────▼─────┐ ┌──────▼──────┐           │
│  │ WiFi Manager │ │ UART/SerAPI│ │ BT Host     │           │
│  │ (nRF7002)    │ │ (UARTE1)   │ │ (HCI IPC)   │           │
│  └───────┬──────┘ └──────┬─────┘ └──────┬──────┘           │
│          │               │               │                    │
│  ┌───────▼──────┐  ┌─────▼─────┐  ┌─────▼──────┐           │
│  │ Storage Mgr  │  │ Power Mgr │  │ Shell      │           │
│  │ (LittleFS+   │  │ (POFCON)  │  │ (UART0)    │           │
│  │  NVS)        │  │           │  │            │           │
│  └──────────────┘  └───────────┘  └────────────┘           │
│                                                              │
├──────────────────────────────────────────────────────────────┤
│                    ZEPHYR RTOS KERNEL                         │
│  Threads │ Schedulers │ IPC │ Timers │ Memory │ Drivers     │
├──────────────────────────────────────────────────────────────┤
│               HARDWARE (nRF5340 + nRF7002 + ZGM230S)         │
└──────────────────────────────────────────────────────────────┘
```

### 14.2 Module Decomposition

| Module | Source Path | Responsibility | Dependencies |
|--------|-----------|---------------|-------------|
| `system_mgr` | `src/system_mgr/` | System state machine, WDT, health monitor, mode transitions | All modules (orchestrator) |
| `wifi_mgr` | `src/wifi_mgr/` | WiFi connection lifecycle, DHCP, reconnect, RSSI monitor | Zephyr WiFi API, storage_mgr |
| `mqtt_client` | `src/mqtt_client/` | MQTT connection, TLS, pub/sub, reconnect | Zephyr MQTT, wifi_mgr, storage_mgr |
| `shadow_mgr` | `src/shadow_mgr/` | Shadow document management, JSON parse/build, delta handling | mqtt_client, storage_mgr |
| `zwave_host` | `src/zwave_host/` | Serial API framing, command dispatch, device table | UART driver, storage_mgr |
| `ble_mgr` | `src/ble_mgr/` | BLE GATT server, advertising, provisioning flow | Zephyr BT Host, storage_mgr |
| `rule_engine` | `src/rule_engine/` | IF-THEN rule evaluation, action dispatch | shadow_mgr, zwave_host |
| `storage_mgr` | `src/storage_mgr/` | LittleFS + NVS abstraction, file I/O, encryption | Zephyr FS API, CryptoCell |
| `power_mgr` | `src/power_mgr/` | POFCON ISR, shutdown sequencing, state save | storage_mgr, system_mgr |
| `shell_cmds` | `src/shell/` | All custom shell commands | All modules |
| `event_bus` | `src/common/event_bus.h` | Event type definitions, message queue wrappers | Zephyr kernel |
| `json_utils` | `src/common/json_utils.h` | cJSON wrappers for shadow/config parsing | cJSON library |

### 14.3 System State Machine

```c
enum system_state {
    STATE_BOOT,
    STATE_PROVISIONING,
    STATE_CONNECTING,
    STATE_OPERATIONAL,
    STATE_DEGRADED,
    STATE_OTA_UPDATE,
    STATE_SHUTDOWN,
    STATE_FACTORY_TEST,
    STATE_AGING_TEST,
};
```

**Transition table:**

| From | To | Trigger |
|------|----|---------|
| BOOT | PROVISIONING | NVS `provisioned` == 0 |
| BOOT | CONNECTING | NVS `provisioned` == 1 |
| PROVISIONING | CONNECTING | Credentials saved via BLE or CLI |
| CONNECTING | OPERATIONAL | WiFi + MQTT connected, shadow synced |
| CONNECTING | DEGRADED | WiFi connect timeout (5 attempts) |
| OPERATIONAL | DEGRADED | WiFi or MQTT disconnected |
| OPERATIONAL | OTA_UPDATE | Shadow delta contains `desired.ota` |
| OPERATIONAL | SHUTDOWN | POFCON interrupt |
| DEGRADED | CONNECTING | Reconnect backoff timer fires |
| DEGRADED | SHUTDOWN | POFCON interrupt |
| OTA_UPDATE | BOOT | Reboot after image staging |
| ANY | SHUTDOWN | POFCON interrupt (highest priority) |
| ANY | FACTORY_TEST | CLI command `shg factory_test` |
| ANY | AGING_TEST | CLI command `shg aging start` |

### 14.4 Error Handling & Fault Recovery

| Error Category | Detection | Recovery |
|---------------|-----------|----------|
| **WiFi disconnect** | `NET_EVENT_WIFI_DISCONNECT` callback | Automatic reconnect with backoff; transition to DEGRADED after 5 failures |
| **MQTT disconnect** | MQTT DISCONNECT event or keepalive timeout | Automatic reconnect; re-subscribe to shadow topics |
| **Z-Wave Serial API timeout** | No ACK within 1600 ms | Retry frame 3×; if persistent, reset ZGM230S via GPIO; re-init Serial API |
| **Z-Wave node unreachable** | SEND_DATA callback with transmit_fail | Mark `is_reachable = false` in device table; report via shadow; retry on next command |
| **LittleFS mount fail** | `fs_mount()` returns error | Attempt format + remount; if still fails, operate in RAM-only degraded mode, log critical error |
| **LittleFS write fail** | `fs_write()` returns error | Retry once; if flash sector bad, LittleFS handles transparently; log error |
| **TLS handshake fail** | Mbed TLS error code | Retry with backoff; if cert-related, log specific error for diagnostics |
| **OTA checksum mismatch** | SHA-256 comparison fails | Erase secondary slot; report `reported.ota.status = "checksum_failed"`; stay on current image |
| **Stack overflow** | MPU fault (Zephyr HW stack protection) | System reset via fault handler; crash info saved if POFCON allows |
| **Hard fault** | Cortex-M fault handler | Crash dump to crash partition; WDT resets system; MCUboot may revert if OTA just applied |
| **WDT timeout** | WDT NMI/reset | Immediate HW reset; MCUboot decides: revert if image unconfirmed, else boot same image |

---

## 15. Performance & Resource Budgets

### 15.1 Flash Budget (Internal - 1 MB)

| Component | Budget | Notes |
|-----------|--------|-------|
| MCUboot | 48 KB | Bootloader + signing verification |
| Application code | 400 KB | All modules, Zephyr kernel, drivers, stacks |
| Application headroom | 48 KB | Growth margin within 448 KB primary slot |
| MCUboot scratch | 16 KB | Swap status tracking |
| NVS | 32 KB | Key-value runtime config |
| Reserved | 32 KB | Manufacturing data, future |
| **Total** | **576 KB used / 1024 KB** | **448 KB available for app** |

> The remaining ~448 KB internal flash not mapped (secondary slot is external) provides safety margin.

### 15.2 Flash Budget (External - 8 MB)

| Partition | Size | Purpose |
|-----------|------|---------|
| MCUboot secondary | 1 MB | OTA staging (matches primary slot) |
| LittleFS | 6.5 MB | Application data |
| Crash log | 512 KB | Post-mortem diagnostics |
| **Total** | **8 MB** | |

### 15.3 RAM Budget (512 KB)

See §3.3.3 for detailed subsystem allocations. Target: **< 80% utilization** (< 410 KB), leaving 100+ KB for heap and growth.

### 15.4 Latency Requirements

| Operation | Target | Measurement Point |
|-----------|--------|-------------------|
| Boot to OPERATIONAL | < 15 seconds | Power-on to MQTT connected + shadow synced |
| Z-Wave command (cloud → device) | < 2 seconds | Shadow delta received → Z-Wave TX complete |
| Z-Wave command (local rule) | < 500 ms | State change event → Z-Wave TX complete |
| Shadow reported update | < 1 second | Z-Wave state change → MQTT publish sent |
| BLE provisioning (complete flow) | < 60 seconds | BLE connect → MQTT connected |
| OTA download (1 MB image) | < 5 minutes | OTA start → image verified on flash |
| Graceful shutdown (POFCON) | < 100 ms | POFCON interrupt → state saved + halt |

### 15.5 Power Budget

| State | Estimated Current (3.3V) | Notes |
|-------|-------------------------|-------|
| OPERATIONAL (WiFi active, Z-Wave idle) | ~80–120 mA | nRF7002 WiFi RX + nRF5340 active + ZGM230S idle |
| OPERATIONAL (WiFi TX burst) | ~200–300 mA peak | nRF7002 WiFi TX |
| DEGRADED (WiFi off) | ~20–40 mA | nRF5340 + ZGM230S only |
| SHUTDOWN (saving state) | ~15 mA for ~50–100 ms | Flash write + CPU active |

> For graceful shutdown with 100 ms hold-up: energy needed = 300 mA × 100 ms = 30 mC (worst case with WiFi TX). A 1 F supercap charged to 3.3V provides ~3.3C, which is vastly sufficient. A 100 mF supercap provides 330 mC - still sufficient with margin.

---

## 16. Testing & Validation Strategy

### 16.1 Development Phases

#### Phase 1: Bare OS + Emulation Foundation

**Duration:** Milestone 1
**Environment:** native_sim (primary), Renode (validation)

| Deliverable | Description |
|-------------|-------------|
| Zephyr project scaffolding | West workspace, CMakeLists.txt, Kconfig, prj.conf, app.overlay |
| Board configuration | `nrf7002dk/nrf5340/cpuapp` build target verified |
| LittleFS on native_sim | File system mount, read, write, directory operations |
| NVS on native_sim | Key-value store read/write |
| Shell framework | UART shell with `shg info`, `fs ls`, `fs cat` commands |
| System Manager skeleton | State machine with BOOT → PROVISIONING / CONNECTING transitions |
| Logging (UART) | Deferred logging operational |
| Build system | CMake build verified for native_sim + nrf7002dk targets |
| Renode platform file | nRF5340 machine definition for Renode, basic boot test |

**Exit criteria:** `twister` passes all unit tests on native_sim; Renode boots to shell prompt.

#### Phase 2: Storage + Shell + BLE

**Duration:** Milestone 2
**Environment:** native_sim (logic), Renode (BLE simulation), nRF7002-DK (BLE real)

| Deliverable | Description |
|-------------|-------------|
| Storage Manager module | LittleFS + NVS abstraction API, file encryption for sensitive data |
| Directory structure | All `/lfs/config/`, `/lfs/certs/`, `/lfs/zwave/`, `/lfs/shadow/` paths initialized |
| BLE GATT service | Custom provisioning service with all characteristics (§7.2.2) |
| BLE security | LESC pairing with encrypted characteristics |
| BLE provisioning flow | Receive WiFi + AWS credentials via BLE, save to LittleFS |
| Provisioning Manager | Full provisioning state machine |
| Shell: production commands | `wifi connect`, `cert load`, `aws configure` |
| Crash log partition | Crash dump write + read infrastructure |

**Exit criteria:** BLE provisioning flow tested end-to-end on nRF7002-DK with nRF Connect mobile app; credentials stored and retrievable; unit tests pass on native_sim.

#### Phase 3: WiFi + MQTT + Shadow

**Duration:** Milestone 3
**Environment:** native_sim (MQTT against local broker), Renode (networking), nRF7002-DK (real WiFi + AWS)

| Deliverable | Description |
|-------------|-------------|
| WiFi Manager | Connection, DHCP, reconnect with backoff, RSSI monitoring |
| MQTT Client | TLS/mTLS connection to AWS IoT, persistent session |
| Shadow Manager | Gateway named shadow: subscribe, delta processing, reported updates |
| Device shadows | Per-device named shadow create/update/delete |
| JSON utilities | Parse/build shadow documents using cJSON |
| Offline buffering | Pending queue file (`/lfs/shadow/pending.json`) with sync-on-reconnect |
| OPERATIONAL + DEGRADED states | System Manager transitions between connected/disconnected modes |
| Shell: `aws status`, `shadow dump` | |

**Exit criteria:** Gateway connects to AWS IoT Core; gateway shadow created/synced; device shadows created for mock devices; offline queue tested by disconnecting WiFi; all unit/integration tests pass.

#### Phase 4: Z-Wave Integration

**Duration:** Milestone 4
**Environment:** Renode (Z-Wave UART mock), nRF7002-DK + ZGM230S hardware

| Deliverable | Description |
|-------------|-------------|
| Z-Wave Host: Frame Layer | Serial API frame parser, ACK/NAK/CAN handling, TX retry |
| Z-Wave Host: Command Layer | Function dispatch, async callback correlation |
| Z-Wave Host: Application Layer | Inclusion, exclusion, device table, state tracking |
| Device table persistence | `/lfs/zwave/devices.json` save/load |
| Shadow integration | Z-Wave state changes → device shadow reported updates |
| Cloud → Z-Wave commands | Shadow delta (desired) → Z-Wave SEND_DATA |
| S2 security | S2 inclusion flow via Serial API |
| Shell: `zwave add`, `zwave remove`, `zwave list`, `zwave status` | |

**Exit criteria:** Include/exclude real Z-Wave devices; control devices via AWS IoT shadow; device state reported to cloud; Renode UART mock tests pass.

#### Phase 5: Rules + OTA + Production Hardening

**Duration:** Milestone 5
**Environment:** Full stack on nRF7002-DK + ZGM230S

| Deliverable | Description |
|-------------|-------------|
| Rule Engine | IF-THEN evaluation, loading from gateway shadow, local execution |
| OTA pipeline | Shadow-triggered OTA download, MCUboot swap, image confirmation, rollback |
| Power Manager | POFCON ISR, graceful shutdown, state save |
| MCUboot anti-rollback | Monotonic security counter |
| Image signing | CI/CD integration with `west sign` |
| Production shell | Kconfig-controlled command set (production vs. debug) |
| Production test sequence | Scripted factory test via shell |
| Aging test framework | Automated stress test with metrics logging |
| Security hardening | APPROTECT enable, credential encryption, shell access control |
| Full system integration | All subsystems running simultaneously |
| Performance benchmarks | Boot time, command latency, memory usage, flash usage |

**Exit criteria:** OTA update end-to-end (download → reboot → confirm → rollback test); rules execute locally during cloud disconnect; aging test passes 72 hours; production test script passes; all resource budgets met.

### 16.2 Emulation Environment

#### 16.2.1 native_sim (Level 1 - Logic Testing)

- **Target:** `native_sim` - Zephyr runs as a Linux process.
- **Use:** Application logic, JSON parsing, rule engine, state machines, event bus, file system (POSIX backed).
- **Networking:** Uses host Linux network stack - can connect to a real or local MQTT broker.
- **Limitation:** No BLE, no WiFi driver, no Z-Wave UART - these are stubbed/mocked.
- **Test runner:** Zephyr Twister (`west twister -p native_sim`).

#### 16.2.2 Renode (Level 2 - Hardware Integration)

- **Platform:** nRF5340 model (dual-core, peripheral emulation).
- **Use:** BLE testing (Renode BLE model), UART Serial API testing (virtual UART), flash partition testing.
- **Z-Wave mock:** A Python Renode script acts as a virtual ZGM230S, responding to Serial API frames on a virtual UART.
- **WiFi:** Limited - nRF7002 not fully modeled in Renode. WiFi Manager tested via native_sim or real HW.
- **Test runner:** Renode `.resc` scripts integrated with Twister or standalone.

#### 16.2.3 Real Hardware (Level 3 - Full Validation)

- **Board:** nRF7002-DK + ZGM230S development board (wired via Arduino headers or jumper wires).
- **Use:** Full end-to-end testing, WiFi with real AP, BLE with real mobile app, Z-Wave with real devices.
- **Debug:** SEGGER J-Link + RTT + UART shell.
- **CI integration:** Hardware-in-the-loop (HIL) test farm (if available) or manual test execution.

### 16.3 Test Framework

- **Unit tests:** Zephyr Ztest framework (`ztest_test_suite`).
- **Build/test runner:** Twister (`west twister`).
- **Mocks:** Zephyr FFF (Fake Function Framework) for mocking drivers and subsystems.
- **Coverage:** gcov/lcov for native_sim builds.
- **Static analysis:** Zephyr's built-in MISRA-C checks (optional), `checkpatch.py`.

### 16.4 Test Cases (Summary per Phase)

| Phase | Test Category | Example Test Cases |
|-------|-------------|-------------------|
| 1 | FS / NVS | Mount LittleFS, write/read file, NVS set/get, power-loss simulation |
| 1 | Shell | Parse commands, execute `shg info`, verify output format |
| 1 | State machine | Boot sequence, state transitions, invalid transition rejection |
| 2 | BLE | GATT service registration, characteristic write/read, pairing, provisioning flow |
| 2 | Storage | Encrypt/decrypt credential, directory creation, file write-rename pattern |
| 3 | WiFi | Connect, reconnect backoff, RSSI query, disconnect handling |
| 3 | MQTT | Connect with TLS, subscribe, publish, keepalive, reconnect |
| 3 | Shadow | Delta parse, reported update build, offline queue, sync-on-reconnect |
| 4 | Z-Wave | Frame parse, ACK/NAK, TX retry, inclusion flow, device table CRUD |
| 4 | Integration | Cloud command → Z-Wave → device → state → shadow report |
| 5 | Rules | Rule parse, condition evaluate, action dispatch, throttle |
| 5 | OTA | Download, checksum, swap request, confirm, rollback |
| 5 | Power | POFCON trigger, state save timing, halt |
| 5 | Aging | 72-hour run, metrics within bounds |

---

## 17. Build System & Toolchain

### 17.1 West Workspace Structure

```
zephyrproject/                  # West topdir
├── .west/
│   └── config                  # [manifest] path = app
├── app/                         # Application repository (manifest repo)
│   ├── west.yml                 # West manifest
│   ├── CMakeLists.txt
│   ├── prj.conf                 # Default Kconfig
│   ├── debug.conf               # Debug overlay Kconfig
│   ├── app.overlay              # Devicetree overlay
│   ├── Kconfig                  # Application Kconfig definitions
│   ├── VERSION                  # Firmware version file
│   ├── keys/
│   │   └── mcuboot-ec-p256.pem # MCUboot signing key (dev only; CI uses secret)
│   ├── src/
│   │   ├── main.c
│   │   ├── system_mgr/
│   │   ├── wifi_mgr/
│   │   ├── mqtt_client/
│   │   ├── shadow_mgr/
│   │   ├── zwave_host/
│   │   ├── ble_mgr/
│   │   ├── rule_engine/
│   │   ├── storage_mgr/
│   │   ├── power_mgr/
│   │   ├── shell/
│   │   └── common/
│   │       ├── event_bus.h
│   │       └── json_utils.h
│   ├── boards/
│   │   └── nrf7002dk_nrf5340_cpuapp.overlay  # Board-specific overlay (if needed)
│   ├── dts/bindings/           # Custom DT bindings (if needed)
│   ├── tests/
│   │   ├── unit/
│   │   │   ├── test_rule_engine/
│   │   │   ├── test_shadow_mgr/
│   │   │   ├── test_zwave_frame/
│   │   │   └── ...
│   │   └── integration/
│   │       ├── test_provisioning_flow/
│   │       └── ...
│   ├── scripts/
│   │   ├── renode/             # Renode .resc platform files
│   │   └── ci/                 # CI pipeline scripts
│   └── docs/
│       └── SOFTWARE_SPECIFICATION.md  # This document
├── bootloader/mcuboot/
├── zephyr/
├── modules/
└── tools/
```

### 17.2 Build Commands

```bash
# Configure + build for nRF7002-DK (production)
west build -b nrf7002dk/nrf5340/cpuapp app -- -DOVERLAY_CONFIG=prj.conf

# Configure + build for nRF7002-DK (debug)
west build -b nrf7002dk/nrf5340/cpuapp app -- -DOVERLAY_CONFIG="prj.conf;debug.conf"

# Build for native_sim (testing)
west build -b native_sim app

# Flash
west flash

# Run tests
west twister -p native_sim -T app/tests/

# Sign image for OTA
west sign -t imgtool -- --key app/keys/mcuboot-ec-p256.pem --version 1.0.0

# Build net core (BLE controller)
west build -b nrf7002dk/nrf5340/cpunet -d build_netcore zephyr/samples/bluetooth/hci_ipc
```

### 17.3 Multi-Image Build

The system requires two images:

1. **App core image:** Application firmware (this project).
2. **Net core image:** BLE HCI controller (`hci_ipc` from Zephyr samples).

Nordic's sysbuild (or child image) mechanism builds both images together:

```kconfig
# In app's sysbuild.conf or via west build flags
SB_CONFIG_NETCORE_HCI_IPC=y
```

MCUboot handles the app core image only. The net core image is flashed separately (not OTA-updatable in this design - net core firmware is stable).

### 17.4 CI/CD Pipeline

```
┌──────────┐    ┌────────────┐    ┌──────────────┐    ┌──────────┐
│ Git Push │───►│ Build      │───►│ Test          │───►│ Sign &   │
│          │    │            │    │               │    │ Artifact │
│          │    │ - native_sim│   │ - Twister     │    │          │
│          │    │ - nrf7002dk│    │   (native_sim)│    │ - OTA    │
│          │    │ - debug    │    │ - Renode      │    │   image  │
│          │    │ - release  │    │   (scripted)  │    │ - Signed │
│          │    │            │    │ - Static      │    │   hex    │
│          │    │            │    │   analysis    │    │          │
└──────────┘    └────────────┘    └──────────────┘    └──────────┘
```

### 17.5 Versioning

- Firmware version follows **Semantic Versioning** (`MAJOR.MINOR.PATCH`).
- Defined in `app/VERSION` file, read by CMake.
- MCUboot image header includes version for anti-rollback.
- Version reported in shell (`shg info`) and gateway shadow (`reported.firmware_version`).

---

## 18. Appendices

### Appendix A: Full Kconfig Symbol Reference

> To be generated from actual build during Phase 1. Will contain the complete list of Kconfig symbols with their values for both production and debug configurations.

### Appendix B: Devicetree Overlay Reference

> Complete `app.overlay` to be finalized during Phase 1 when hardware wiring is confirmed. Skeleton provided in §4.5.

### Appendix C: MQTT Topic & Payload Schema

See §8.3 for topic structure and §8.4 for JSON payload schemas. The complete topic list:

```
# Gateway shadow
$aws/things/{thingName}/shadow/name/gateway/update
$aws/things/{thingName}/shadow/name/gateway/update/delta
$aws/things/{thingName}/shadow/name/gateway/update/accepted
$aws/things/{thingName}/shadow/name/gateway/update/rejected
$aws/things/{thingName}/shadow/name/gateway/get
$aws/things/{thingName}/shadow/name/gateway/get/accepted

# Per-device shadows (for each node_id from 1 to 32)
$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/update
$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/update/delta
$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/update/accepted
$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/get
$aws/things/{thingName}/shadow/name/zwave-node-{nodeId}/get/accepted

# Wildcard subscription (for all device shadow deltas)
$aws/things/{thingName}/shadow/name/+/update/delta
```

### Appendix D: Z-Wave Serial API Function Table

| Function ID | Name | Direction | Description |
|------------|------|-----------|-------------|
| 0x01 | SERIAL_API_GET_CAPABILITIES | REQ/RES | Get Serial API capabilities |
| 0x04 | APPLICATION_COMMAND_HANDLER | RES (unsolicited) | Received command from a node |
| 0x05 | ZW_GET_CONTROLLER_CAPABILITIES | REQ/RES | Controller type query |
| 0x07 | SERIAL_API_GET_INIT_DATA | REQ/RES | Get node list, chip info |
| 0x08 | SERIAL_API_APPL_NODE_INFORMATION | REQ | Set application NIF |
| 0x10 | ZW_SET_RF_RECEIVE_MODE | REQ/RES | Enable/disable RF |
| 0x12 | ZW_SEND_NODE_INFORMATION | REQ/RES | Send Node Information Frame |
| 0x13 | ZW_SEND_DATA | REQ/RES+CB | Send data to a node |
| 0x15 | ZW_GET_VERSION | REQ/RES | Get Z-Wave library version |
| 0x20 | MEMORY_GET_ID | REQ/RES | Get Home ID and Node ID |
| 0x41 | ZW_GET_NODE_PROTOCOL_INFO | REQ/RES | Get node capabilities |
| 0x42 | ZW_SET_DEFAULT | REQ/CB | Factory reset Z-Wave network |
| 0x4A | ZW_ADD_NODE_TO_NETWORK | REQ/CB | Start inclusion |
| 0x4B | ZW_REMOVE_NODE_FROM_NETWORK | REQ/CB | Start exclusion |
| 0x56 | ZW_REQUEST_NODE_NEIGHBOR_UPDATE | REQ/CB | Heal routes for a node |
| 0x60 | ZW_REQUEST_NODE_INFO | REQ/RES+CB | Request NIF from a node |
| 0x80 | ZW_GET_NETWORK_STATS | REQ/RES | TX/RX counters |

> Full function list per INS14259 [REF-06].

### Appendix E: BLE GATT Service/Characteristic Table

See §7.2.2.

| Characteristic | UUID | Properties | Max Size | Description |
|---------------|------|------------|----------|-------------|
| WiFi SSID | `{base}0001` | W | 32 B | Network name |
| WiFi PSK | `{base}0002` | W | 64 B | Network password |
| WiFi Status | `{base}0003` | R, N | 1 B | Connection state |
| AWS Endpoint | `{base}0004` | W | 128 B | IoT Core URL |
| AWS Client ID | `{base}0005` | W | 64 B | Thing name |
| Device Cert | `{base}0006` | W | 2048 B | X.509 PEM (chunked) |
| Private Key | `{base}0007` | W | 2048 B | PEM (chunked) |
| Root CA | `{base}0008` | W | 2048 B | PEM (chunked) |
| Prov Command | `{base}0009` | W | 1 B | Control byte |
| Prov Status | `{base}000A` | R, N | 1 B | Overall status |

Base Service UUID: `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`

### Appendix F: Flash Partition Map

```
INTERNAL FLASH (0x0000_0000 - 0x000F_FFFF, 1 MB)
┌─────────────────────────────────────────────────────┐
│ 0x0000_0000 │ MCUboot Bootloader          │  48 KB  │
│ 0x0000_C000 │ Primary Slot (Application)  │ 448 KB  │
│ 0x0007_C000 │ MCUboot Scratch / Status     │  16 KB  │
│ 0x0008_0000 │ (Unmapped / Reserved)        │ 448 KB  │
│ 0x000F_0000 │ NVS Partition                │  32 KB  │
│ 0x000F_8000 │ Manufacturing / Reserved     │  32 KB  │
└─────────────────────────────────────────────────────┘

EXTERNAL QSPI FLASH (0x00_0000 - 0x7F_FFFF, 8 MB)
┌─────────────────────────────────────────────────────┐
│ 0x00_0000   │ MCUboot Secondary Slot (OTA) │  1 MB   │
│ 0x10_0000   │ LittleFS Data Partition      │ 6.5 MB  │
│ 0x78_0000   │ Crash Log Partition           │ 512 KB  │
└─────────────────────────────────────────────────────┘
```

### Appendix G: Glossary

| Term | Definition |
|------|-----------|
| Commissioning | Process of initial device setup: connecting to WiFi, registering with AWS IoT |
| Delta | The difference between the `desired` and `reported` sections of a device shadow |
| Inclusion | Z-Wave process of adding a new device to the network |
| Exclusion | Z-Wave process of removing a device from the network |
| Heal | Z-Wave network optimization process (route recalculation) |
| Named Shadow | An AWS IoT shadow identified by a name, allowing multiple shadows per thing |
| Primary Slot | MCUboot flash region holding the currently running firmware image |
| Secondary Slot | MCUboot flash region for staging a new firmware image before swap |
| Swap | MCUboot process of exchanging primary and secondary slot contents at boot |
| Thing | An AWS IoT representation of a physical device |

---

*End of Document*
