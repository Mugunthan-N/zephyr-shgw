---
type: knowledge
scope: project-specific
version: "1.0.0"
domain: architecture
agents: [all]
---

# zephyr-shgw — Architecture Overview

## System Overview

The Smart Home Gateway (SHG) is an embedded firmware application running **Zephyr RTOS** on the **Nordic nRF5340** dual-core SoC (nRF7002-DK development board). It serves as the central intelligence hub of a smart home, bridging:

- **Z-Wave 800** end-devices (up to 32 nodes) to the cloud via AWS IoT Core.
- **WiFi** connectivity (nRF7002 companion IC) for cloud/MQTT communication.
- **BLE** for initial device commissioning and provisioning.
- **Local rule execution** (IF-THEN engine) for offline automation continuity.

The gateway manages device state through **AWS IoT Named Shadows** — one per Z-Wave device plus one for gateway configuration and rules.

## Startup / Boot Sequence

```
Power On
  → nRF5340 ROM Secure Boot (validates MCUboot region)
  → MCUboot (48 KB) validates application image (ECDSA-P256 + SHA-256)
  → Checks anti-rollback counter
  → Jumps to application entry point: main()
    → Zephyr kernel init (threads, scheduler, drivers)
    → System Manager thread starts
    → Check NVS: provisioned flag
      ├── provisioned == 0 → STATE_PROVISIONING
      │   → Start BLE advertising ("SHG-XXXX")
      │   → Await WiFi + AWS credentials via BLE GATT or CLI
      │   → Save credentials to LittleFS
      │   → Transition to STATE_CONNECTING
      └── provisioned == 1 → STATE_CONNECTING
          → WiFi Manager: associate + DHCP
          → MQTT Client: TLS handshake to AWS IoT (port 8883, mTLS)
          → Shadow Manager: subscribe to delta topics, sync shadows
          → Z-Wave Host: init Serial API, load device table
          → Rule Engine: load rules from cached shadow
          → Transition to STATE_OPERATIONAL
          → boot_write_img_confirmed() (MCUboot image confirmation)
          → WDT feed begins
```

## Operating Modes (State Machine)

| Mode | Description | Active Subsystems |
|------|-------------|-------------------|
| **BOOT** | MCUboot validates image, kernel init | MCUboot, Kernel |
| **PROVISIONING** | BLE GATT advertising, awaiting credentials | BLE, Shell, LittleFS |
| **CONNECTING** | WiFi + MQTT + Shadow sync | WiFi, MQTT, Shadow Manager |
| **OPERATIONAL** | Steady state, all subsystems active | All |
| **DEGRADED** | Cloud unreachable, local control continues | Z-Wave, Rule Engine, LittleFS |
| **OTA_UPDATE** | Downloading firmware to secondary slot | MQTT, LittleFS, all others |
| **SHUTDOWN** | POFCON triggered, state save to flash | Power Manager, LittleFS |
| **FACTORY_TEST** | Hardware exercise via shell | Shell, all drivers |
| **AGING_TEST** | Long-duration stress test | All, enhanced logging |

## Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    APPLICATION LAYER                         │
│  System Manager │ Shadow Manager │ Rule Engine │ Prov Mgr   │
├─────────────────────────────────────────────────────────────┤
│              EVENT BUS / MESSAGE QUEUES                      │
├─────────────────────────────────────────────────────────────┤
│                    PROTOCOL LAYER                            │
│  MQTT Client    │ Z-Wave Host    │ BLE Manager              │
├─────────────────────────────────────────────────────────────┤
│                    PLATFORM LAYER                            │
│  WiFi Manager   │ UART/SerAPI    │ BT Host (HCI IPC)       │
│  Storage Mgr    │ Power Manager  │ Shell (UART0)            │
├─────────────────────────────────────────────────────────────┤
│                    ZEPHYR RTOS KERNEL                        │
│  Threads │ Scheduler │ IPC │ Timers │ Memory │ Drivers     │
├─────────────────────────────────────────────────────────────┤
│            HARDWARE (nRF5340 + nRF7002 + ZGM230S)           │
└─────────────────────────────────────────────────────────────┘
```

## Inter-Thread Communication

| Mechanism | Usage |
|-----------|-------|
| `k_msgq` (Message Queue) | Z-Wave Host → Shadow Manager (device state); Shadow Manager → Rule Engine (state-change events); MQTT → Shadow Manager (deltas) |
| `k_event` (Event Flags) | System Manager broadcasts mode transitions (OPERATIONAL, DEGRADED, SHUTDOWN) |
| `k_sem` (Semaphore) | LittleFS access serialization (single-writer) |
| `k_fifo` (FIFO) | Serial API UART RX ISR → zwave_host thread |
| Work Queue | Deferred: cert loading, shadow JSON serialization, crash log write |

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| nRF5340 dual-core: app core for application, net core for BLE HCI only | Separation of concerns; net core runs stable `hci_ipc`, app core has full application control |
| Named shadows (1 per Z-Wave device + 1 gateway) | Individual device state tracking; avoids monolithic shadow size limits |
| Z-Wave Serial API (classic binary frames) over UART | ZGM230S runs Silicon Labs controller firmware; host-side implementation gives full control |
| LittleFS on external QSPI flash (6.5 MB) + NVS on internal flash (32 KB) | Large file storage on external flash; small key-value config on fast internal flash |
| MCUboot swap-based dual-slot with secondary on external flash | Maximizes internal flash for application; OTA staging on abundant external flash |
| Mains power with battery/supercap backup (POFCON shutdown) | Gateway is always-on; battery only for graceful shutdown on power loss |
| WiFi + Z-Wave always on, BLE on-demand | WiFi and Z-Wave are primary radios; BLE only needed for provisioning |
| IF-THEN rule engine with local execution | Offline automation continuity when cloud is unreachable |
| JSON serialization for shadows and config | AWS IoT shadow format is JSON; keeps device-side consistent |
| Exponential backoff for WiFi and MQTT reconnect | Prevents thundering herd; respects network recovery time |

## External Integrations

| Integration | Protocol | Details |
|-------------|----------|---------|
| **AWS IoT Core** | MQTT over TLS 1.2 (port 8883, mTLS) | Named shadows, OTA jobs |
| **Z-Wave Network** | Z-Wave Serial API over UART (115200, HW flow control) | Up to 32 end-devices, S2 security |
| **Mobile App** | BLE GATT (custom provisioning service) | One-time commissioning |
| **Debug/Factory** | UART shell (115200, UARTE0) + SEGGER RTT | Logging, CLI commands |

## Memory Map Summary

**Internal Flash (1 MB):** MCUboot 48 KB → Primary Slot 448 KB → Scratch 16 KB → NVS 32 KB → Reserved 32 KB

**External QSPI Flash (8 MB):** MCUboot Secondary 1 MB → LittleFS 6.5 MB → Crash Log 512 KB

**SRAM (512 KB):** Kernel ~40 KB, BLE ~20 KB, WiFi ~80 KB, MQTT+TLS ~60 KB, Z-Wave ~16 KB, Shadow ~24 KB, Rules ~8 KB, LittleFS ~16 KB, Shell ~12 KB, Logging ~8 KB, Thread stacks ~48 KB, Heap ~180 KB
