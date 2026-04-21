---
type: rule
scope: project-specific
version: "1.0.0"
domain: platform
agents: [all]
---

# zephyr-shgw — Project Rules

## Embedded / Platform Rules

### R-EM-001: Use Zephyr Kernel APIs Only

- **Severity**: critical
- **Description**: All threading, synchronization, and timing MUST use Zephyr kernel primitives (`k_thread`, `k_msgq`, `k_sem`, `k_event`, `k_timer`, `k_fifo`, `k_sleep`, `k_work`). POSIX threading APIs (`pthread_*`), bare `sleep()`, and direct ARM CMSIS-RTOS calls are forbidden.
- **Bad**:
  ```c
  #include <pthread.h>
  pthread_mutex_lock(&my_mutex);
  sleep(1);
  ```
- **Good**:
  ```c
  #include <zephyr/kernel.h>
  k_mutex_lock(&my_mutex, K_FOREVER);
  k_sleep(K_SECONDS(1));
  ```

### R-EM-002: Static Thread Stack Allocation

- **Severity**: critical
- **Description**: Thread stacks MUST be statically allocated using `K_THREAD_STACK_DEFINE`. Stack sizes are defined at compile time and cannot grow at runtime. Every new thread must have its stack size budgeted in the thread model (see modules.md).
- **Bad**:
  ```c
  void *stack = malloc(4096);
  k_thread_create(&thread, stack, 4096, ...);
  ```
- **Good**:
  ```c
  K_THREAD_STACK_DEFINE(my_stack, 4096);
  k_thread_create(&thread, my_stack, K_THREAD_STACK_SIZEOF(my_stack), ...);
  ```

### R-EM-003: No Dynamic Memory in ISR Context

- **Severity**: critical
- **Description**: Interrupt service routines MUST NOT call `malloc`, `k_malloc`, `k_heap_alloc`, or any allocating function. ISRs must only use statically allocated buffers, FIFOs, or ring buffers.
- **Bad**:
  ```c
  void uart_rx_isr(const struct device *dev, void *data) {
      char *buf = malloc(64);  /* FORBIDDEN in ISR */
      /* ... */
  }
  ```
- **Good**:
  ```c
  static uint8_t rx_ring_buf[256];
  void uart_rx_isr(const struct device *dev, void *data) {
      ring_buf_put(&rx_ring, byte, 1);
      k_sem_give(&rx_sem);
  }
  ```

### R-EM-004: POFCON ISR Must Be Minimal

- **Severity**: critical
- **Description**: The POFCON (power failure) ISR has highest application priority. It MUST only set an event flag and return. All shutdown work (state save, flash flush) happens in the System Manager thread responding to the event.
- **Bad**:
  ```c
  void pofcon_isr(void) {
      fs_sync(&lfs);           /* FORBIDDEN - blocking I/O in ISR */
      nvs_write(&nvs, ...);   /* FORBIDDEN */
  }
  ```
- **Good**:
  ```c
  void pofcon_isr(void) {
      k_event_post(&sys_events, EVENT_SHUTDOWN);
  }
  ```

### R-EM-005: WDT Must Be Fed by System Manager Only

- **Severity**: major
- **Description**: The hardware watchdog (8-second timeout) MUST be fed only by the System Manager thread at the end of each main loop iteration, after confirming health of critical threads. No other thread may feed the WDT.
- **Bad**:
  ```c
  /* In wifi_mgr thread */
  wdt_feed(wdt_dev, wdt_channel);
  ```
- **Good**:
  ```c
  /* In system_mgr thread main loop */
  if (all_threads_healthy()) {
      wdt_feed(wdt_dev, wdt_channel);
  }
  ```

## Error Handling Rules

### R-EH-001: All Zephyr API Return Codes Must Be Checked

- **Severity**: critical
- **Description**: Every Zephyr API call that returns an error code MUST have its return value checked. Silently ignoring errors is forbidden. Log the error with context (operation, parameters, error code) and take appropriate recovery action.
- **Bad**:
  ```c
  k_msgq_put(&my_queue, &msg, K_NO_WAIT);  /* Return value ignored */
  fs_open(&file, path, FS_O_READ);          /* Return value ignored */
  ```
- **Good**:
  ```c
  int ret = k_msgq_put(&my_queue, &msg, K_NO_WAIT);
  if (ret != 0) {
      LOG_ERR("Failed to enqueue message: %d", ret);
      /* Recovery action */
  }
  ```

### R-EH-002: Exponential Backoff for Reconnection

- **Severity**: major
- **Description**: WiFi and MQTT reconnection attempts MUST use exponential backoff. WiFi: 1s→2s→4s→8s→16s→30s max. MQTT: 1s→2s→4s→8s→16s→32s→60s max. After 5 consecutive WiFi failures, post `EVENT_WIFI_FAILED` to System Manager.
- **Bad**:
  ```c
  while (!connected) {
      wifi_connect();
      k_sleep(K_SECONDS(1));  /* Fixed interval */
  }
  ```
- **Good**:
  ```c
  int backoff_ms = 1000;
  while (!connected && attempts < MAX_RETRIES) {
      wifi_connect();
      k_sleep(K_MSEC(backoff_ms));
      backoff_ms = MIN(backoff_ms * 2, 30000);
      attempts++;
  }
  ```

### R-EH-003: Z-Wave Serial API Frame Retry

- **Severity**: major
- **Description**: Z-Wave Serial API TX frames MUST be retried up to 3 times on NAK or timeout (1600 ms response timeout). After 3 failures, reset the ZGM230S via GPIO and re-initialize the Serial API.
- **Bad**:
  ```c
  serial_api_send(frame);
  /* No retry, no timeout check */
  ```
- **Good**:
  ```c
  for (int i = 0; i < 3; i++) {
      int ret = serial_api_send_and_wait_ack(frame, K_MSEC(1600));
      if (ret == 0) break;
      LOG_WRN("Serial API retry %d/3", i + 1);
  }
  if (ret != 0) {
      zwave_module_reset();
  }
  ```

## Security Rules

### R-SC-001: mTLS Required for AWS IoT

- **Severity**: critical
- **Description**: MQTT connections to AWS IoT Core MUST use mutual TLS (mTLS) with device certificate + private key. TLS 1.2 minimum. Cipher suite: TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256. No fallback to unencrypted MQTT or TLS without client auth.

### R-SC-002: Sensitive Data Encrypted at Rest

- **Severity**: critical
- **Description**: Private keys and WiFi PSK stored on LittleFS MUST be encrypted at rest using AES-128-CTR. Key derived via HKDF(SHA-256) from nRF5340 FICR device ID + application salt. Decrypted in RAM only when needed.
- **Bad**:
  ```c
  fs_write(&file, private_key_pem, strlen(private_key_pem));  /* Plaintext */
  ```
- **Good**:
  ```c
  encrypt_for_storage(private_key_pem, encrypted_buf, sizeof(encrypted_buf));
  fs_write(&file, encrypted_buf, encrypted_len);
  ```

### R-SC-003: No Secrets in Logs

- **Severity**: critical
- **Description**: Log statements MUST NOT contain WiFi PSK, private keys, certificates, AWS credentials, or any sensitive data. Log only identifiers (SSID name, thing name) not values (passwords, keys).
- **Bad**:
  ```c
  LOG_INF("WiFi PSK: %s", wifi_config.psk);
  ```
- **Good**:
  ```c
  LOG_INF("WiFi connecting to SSID: %s", wifi_config.ssid);
  ```

### R-SC-004: BLE Encryption Required Before Writes

- **Severity**: critical
- **Description**: All BLE GATT characteristics that accept Write operations MUST require encryption (`BT_GATT_PERM_WRITE_ENCRYPT`). LESC pairing must complete before any provisioning data is accepted.

### R-SC-005: MCUboot Image Signing Required

- **Severity**: critical
- **Description**: All firmware images MUST be signed with ECDSA-P256 + SHA-256. MCUboot MUST validate the signature before jumping to the application. Anti-rollback counter MUST be incremented with each release.

## Code Quality Rules

### R-CQ-001: No TODO/FIXME in Merged Code

- **Severity**: major
- **Description**: Code merged to the main branch MUST NOT contain `TODO`, `FIXME`, `HACK`, or `XXX` comments. All work must be complete.

### R-CQ-002: Functions Must Not Exceed 60 Lines

- **Severity**: minor
- **Description**: Functions SHOULD NOT exceed 60 lines of code (excluding comments and blank lines). Extract helper functions for complex logic.

### R-CQ-003: No Magic Numbers

- **Severity**: major
- **Description**: Numeric constants MUST be defined as `#define` macros or `enum` values with descriptive names. Raw numbers in code are forbidden except for 0, 1, and -1 in obvious contexts.
- **Bad**:
  ```c
  k_sleep(K_MSEC(1600));  /* What is 1600? */
  if (node_count > 32) { ... }
  ```
- **Good**:
  ```c
  #define SERIAL_API_RESPONSE_TIMEOUT_MS 1600
  #define ZWAVE_MAX_NODES 32
  k_sleep(K_MSEC(SERIAL_API_RESPONSE_TIMEOUT_MS));
  if (node_count > ZWAVE_MAX_NODES) { ... }
  ```

### R-CQ-004: Include Guards for All Headers

- **Severity**: major
- **Description**: All header files MUST use `#ifndef`/`#define`/`#endif` include guards. The guard name follows the pattern `<MODULE>_<FILENAME>_H_` in uppercase.
- **Good**:
  ```c
  #ifndef ZWAVE_HOST_FRAME_H_
  #define ZWAVE_HOST_FRAME_H_
  /* ... */
  #endif /* ZWAVE_HOST_FRAME_H_ */
  ```

## Performance Rules

### R-PF-001: No Blocking I/O in High-Priority Threads

- **Severity**: major
- **Description**: Threads with priority ≤ 3 (system_mgr, wifi_mgr, zwave_host, mqtt_client) MUST NOT perform blocking file I/O (LittleFS reads/writes). Defer file operations to the storage_mgr thread via message queue.

### R-PF-002: JSON Parse Buffer Size Limits

- **Severity**: major
- **Description**: Shadow JSON parse buffers MUST NOT exceed 4 KB per parse operation. Shadow documents larger than 4 KB must be parsed in a streaming/chunked fashion or rejected with a log error.

### R-PF-003: Z-Wave Device Table Size Fixed at 32

- **Severity**: critical
- **Description**: The Z-Wave device table is statically allocated for exactly `ZWAVE_MAX_NODES` (32) entries. Code MUST check bounds before adding a device. Attempting to exceed 32 nodes must be rejected with an appropriate error.

## Testing Rules

### R-TS-001: Every Module Must Have Unit Tests

- **Severity**: major
- **Description**: Every module under `src/` MUST have corresponding unit tests under `tests/unit/`. Tests must run on `native_sim` via Twister.

### R-TS-002: Use Ztest Framework

- **Severity**: major
- **Description**: All tests MUST use the Zephyr Ztest framework (`ZTEST`, `ZTEST_SUITE`, `zassert_*`). Do not use custom test frameworks or bare `assert()`.

### R-TS-003: Mock Hardware Dependencies with FFF

- **Severity**: major
- **Description**: Unit tests running on native_sim MUST mock hardware-dependent functions (UART, SPI, GPIO, WiFi driver) using the Zephyr FFF (Fake Function Framework). Tests must not depend on real hardware.

## File System Rules

### R-FS-001: Atomic File Writes via Write-Then-Rename

- **Severity**: critical
- **Description**: Critical file writes (device table, shadow cache, config) MUST use the write-then-rename pattern: write to `<filename>.tmp`, then rename to `<filename>`. This ensures atomicity on power loss.
- **Bad**:
  ```c
  fs_open(&f, "/lfs/zwave/devices.json", FS_O_WRITE | FS_O_CREATE);
  fs_write(&f, data, len);  /* Power loss here = corrupted file */
  fs_close(&f);
  ```
- **Good**:
  ```c
  fs_open(&f, "/lfs/zwave/devices.json.tmp", FS_O_WRITE | FS_O_CREATE);
  fs_write(&f, data, len);
  fs_close(&f);
  fs_rename("/lfs/zwave/devices.json.tmp", "/lfs/zwave/devices.json");
  ```

### R-FS-002: LittleFS Mount Check Before Operations

- **Severity**: major
- **Description**: All file operations MUST verify that LittleFS is mounted before proceeding. If mount failed at boot, the module must operate in RAM-only degraded mode and log a critical error.
