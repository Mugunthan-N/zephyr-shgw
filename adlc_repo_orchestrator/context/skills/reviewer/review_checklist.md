---
type: skill
scope: project-specific
version: "1.0.0"
domain: reviewer
agents: [reviewer]
---

# Reviewer Skills — zephyr-shgw

## Project-Specific Review Checklist

### Embedded / Platform Rules (Critical)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-EM-001 | Zephyr kernel APIs only (no POSIX) | `grep_search` for `pthread_`, `sleep(`, `usleep(` in changed files |
| R-EM-002 | Thread stacks statically allocated | Verify `K_THREAD_STACK_DEFINE` used for every new thread |
| R-EM-003 | No dynamic memory in ISR | Check ISR functions for `malloc`, `k_malloc`, `k_heap_alloc` |
| R-EM-004 | POFCON ISR is minimal | Verify ISR only sets event flag, no blocking calls |
| R-EM-005 | WDT fed by System Manager only | `grep_search` for `wdt_feed` — should only appear in system_mgr |

### Error Handling (Critical/Major)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-EH-001 | All API return codes checked | Review every Zephyr API call; look for unchecked returns |
| R-EH-002 | Exponential backoff for reconnection | Verify WiFi/MQTT reconnect uses increasing delay with cap |
| R-EH-003 | Serial API retry (3× with 1600ms timeout) | Check zwave_host TX path for retry loop |

### Security (Critical)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-SC-001 | mTLS for AWS IoT | Verify TLS config includes client cert + key, TLS 1.2 minimum |
| R-SC-002 | Sensitive data encrypted at rest | Check private key and PSK writes use encryption wrapper |
| R-SC-003 | No secrets in logs | `grep_search` for `LOG_` statements near credential variables |
| R-SC-004 | BLE write encryption | Verify `BT_GATT_PERM_WRITE_ENCRYPT` on all writable characteristics |
| R-SC-005 | MCUboot image signing | Verify build system includes signing step |

### Code Quality (Major/Minor)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-CQ-001 | No TODO/FIXME | `grep_search` for `TODO`, `FIXME`, `HACK`, `XXX` in changed files |
| R-CQ-002 | Functions ≤ 60 lines | Manual review of new/modified functions |
| R-CQ-003 | No magic numbers | Look for raw numeric literals (except 0, 1, -1) |
| R-CQ-004 | Include guards on all headers | Verify `#ifndef`/`#define`/`#endif` pattern |

### Performance (Major)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-PF-001 | No blocking I/O in high-priority threads | Check threads with priority ≤ 3 for `fs_*` calls |
| R-PF-002 | JSON parse buffer ≤ 4 KB | Verify buffer sizes in shadow/JSON operations |
| R-PF-003 | Device table bounded at 32 | Check for bounds checks before device table insertion |

### File System (Critical/Major)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-FS-001 | Atomic writes (write-then-rename) | Verify critical file writes use `.tmp` + rename pattern |
| R-FS-002 | LittleFS mount check | Verify `fs_mount` return checked before file operations |

### Testing (Major)

| Rule ID | Check | How to Verify |
|---------|-------|---------------|
| R-TS-001 | Unit tests for every module | Check that new modules have corresponding `tests/unit/test_<module>/` |
| R-TS-002 | Ztest framework used | Verify `ZTEST`, `ZTEST_SUITE`, `zassert_*` APIs |
| R-TS-003 | Hardware mocked with FFF | Verify `FAKE_VALUE_FUNC`/`FAKE_VOID_FUNC` for hardware dependencies |

## Additional Review Dimensions

### Naming Convention Compliance

| Check | Expected Pattern |
|-------|-----------------|
| Function names | `<module>_<action>()` in `lower_snake_case` |
| Constants/macros | `UPPER_SNAKE_CASE` with module prefix |
| Struct fields | `lower_snake_case` |
| File names | `lower_snake_case.c/.h` |
| Log module | `LOG_MODULE_REGISTER(<module>, CONFIG_<MODULE>_LOG_LEVEL)` |

### Zephyr-Specific Checks

| Check | Detail |
|-------|--------|
| `device_is_ready()` check | Every `DEVICE_DT_GET()` must be followed by a readiness check |
| `k_msgq` message alignment | Message structs must have natural alignment (4-byte for ARM) |
| Thread name set | `k_thread_name_set()` called after `k_thread_create()` |
| `ARG_UNUSED` for unused parameters | Thread entry function, callback parameters |
| Correct Kconfig dependencies | New `CONFIG_SHG_*` entries have proper `depends on` |

### Memory Budget Review

When reviewing changes that add threads, buffers, or data structures:

| Metric | Budget | How to Check |
|--------|--------|-------------|
| SRAM total | < 410 KB (80% of 512 KB) | `west build --cmake-only && west sram_report` |
| Flash (code) | < 400 KB (of 448 KB slot) | `west build && west flash_report` |
| Thread stacks | Must match thread model table | Sum of `K_THREAD_STACK_DEFINE` sizes |
| Heap usage | JSON parse buffers only, bounded | Check `k_heap_alloc` calls have size limits |

## Severity Levels

| Severity | Impact | Examples |
|----------|--------|---------|
| **Critical (P0)** | Must fix. Blocks merge. Security vulnerability, data corruption, crash, rule violation (critical). | No mTLS, unchecked return causing crash, POSIX API usage, ISR with malloc |
| **Major (P1)** | Should fix. Blocks merge. Functionality broken, rule violation (major), significant defect. | Missing backoff, no bounds check on device table, missing unit tests, magic numbers |
| **Minor (P2)** | Nice to fix. Does not block. Style issue, missing optimization, guidelines divergence. | Function > 60 lines, missing thread name, excessive nesting |
| **Info (P3)** | Suggestion only. | Alternative approaches, potential future improvement |

## Forbidden Patterns — Quick Grep Scan

Run these `grep_search` patterns on every changed file:

```
pthread_          → R-EM-001 violation
sleep(            → R-EM-001 violation (if not k_sleep)
usleep(           → R-EM-001 violation
printf(           → Use LOG_* instead
fprintf(          → Use LOG_* instead
malloc(           → Check context (ISR = critical, thread = verify bounded)
free(             → Verify paired with malloc, not in ISR
assert(           → Use __ASSERT or zassert_* instead
TODO              → R-CQ-001 violation
FIXME             → R-CQ-001 violation
HACK              → R-CQ-001 violation
password          → Check no credential values in code/logs
private_key       → Check no key material in code/logs
```
