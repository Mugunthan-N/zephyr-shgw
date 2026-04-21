---
type: skill
scope: project-specific
version: "1.0.0"
domain: dev_testing
agents: [dev_testing]
---

# Dev Testing Skills — zephyr-shgw

## Test Framework Stack

| Component | Technology | Notes |
|-----------|-----------|-------|
| **Framework** | Zephyr Ztest (`ZTEST`, `ZTEST_SUITE`) | Ztest v2 API (not deprecated v1) |
| **Assertions** | `zassert_equal`, `zassert_true`, `zassert_not_null`, `zassert_mem_equal`, etc. | Zephyr built-in assertions |
| **Mocking** | Zephyr FFF (Fake Function Framework) | `DEFINE_FFF_GLOBALS`, `FAKE_VALUE_FUNC`, `FAKE_VOID_FUNC` |
| **Test Runner** | Twister (`west twister`) | `west twister -p native_sim -T app/tests/` |
| **Coverage** | gcov / lcov (native_sim only) | `--enable-coverage` flag with Twister |
| **Primary Target** | `native_sim` | Application logic runs as Linux process |
| **Secondary Target** | Renode | For BLE, UART mock, flash partition tests |

## Test File Location

```
tests/
├── unit/
│   ├── test_rule_engine/
│   │   ├── CMakeLists.txt
│   │   ├── prj.conf
│   │   ├── testcase.yaml
│   │   └── src/
│   │       └── main.c        ← Test source
│   ├── test_shadow_mgr/
│   │   └── ...
│   ├── test_zwave_frame/
│   │   └── ...
│   └── test_<module_name>/
│       └── ...
└── integration/
    ├── test_provisioning_flow/
    └── ...
```

**Each test is a separate Zephyr application** with its own `CMakeLists.txt`, `prj.conf`, and `testcase.yaml`.

## Test Naming Conventions

- **Directory**: `test_<module_name>` (matches module under `src/`)
- **Test suite**: `<module>_tests` — e.g., `rule_engine_tests`, `shadow_mgr_tests`
- **Test cases**: `test_<behavior_under_test>` — e.g., `test_rule_evaluates_eq_true`, `test_shadow_parse_delta_missing_state`

## Test Skeleton (CMakeLists.txt)

```cmake
# tests/unit/test_rule_engine/CMakeLists.txt
cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(test_rule_engine)

target_sources(app PRIVATE src/main.c)

# Include the module under test
target_sources(app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src/rule_engine/rule_engine.c
)

target_include_directories(app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../src
)
```

## Test Skeleton (prj.conf)

```kconfig
# tests/unit/test_rule_engine/prj.conf
CONFIG_ZTEST=y
CONFIG_ZTEST_NEW_API=y
CONFIG_LOG=y
CONFIG_LOG_DEFAULT_LEVEL=3
```

## Test Skeleton (testcase.yaml)

```yaml
# tests/unit/test_rule_engine/testcase.yaml
tests:
  rule_engine.unit:
    platform_allow: native_sim
    tags: unit rule_engine
```

## Test Template (main.c)

```c
/* tests/unit/test_rule_engine/src/main.c */
#include <zephyr/ztest.h>
#include <zephyr/fff.h>
#include "rule_engine/rule_engine.h"

DEFINE_FFF_GLOBALS;

/* ---- Fakes for dependencies ---- */
FAKE_VALUE_FUNC(int, zwave_host_send_cmd, uint8_t, uint8_t, uint8_t, int32_t);

/* ---- Fixtures ---- */
static struct rule test_rule;

static void rule_engine_before(void *fixture)
{
    ARG_UNUSED(fixture);
    RESET_FAKE(zwave_host_send_cmd);
    FFF_RESET_HISTORY();
    memset(&test_rule, 0, sizeof(test_rule));
}

/* ---- Test Suite ---- */
ZTEST_SUITE(rule_engine_tests, NULL, NULL, rule_engine_before, NULL, NULL);

/* ---- Test Cases ---- */
ZTEST(rule_engine_tests, test_rule_evaluates_eq_true)
{
    test_rule.enabled = true;
    test_rule.condition.operator = OP_EQ;
    test_rule.condition.value = 1;
    test_rule.action.device_node_id = 5;

    int32_t current_value = 1;
    bool result = rule_evaluate_condition(&test_rule.condition, current_value);

    zassert_true(result, "EQ condition should match when values are equal");
}

ZTEST(rule_engine_tests, test_rule_evaluates_eq_false)
{
    test_rule.enabled = true;
    test_rule.condition.operator = OP_EQ;
    test_rule.condition.value = 1;

    int32_t current_value = 0;
    bool result = rule_evaluate_condition(&test_rule.condition, current_value);

    zassert_false(result, "EQ condition should not match when values differ");
}

ZTEST(rule_engine_tests, test_disabled_rule_not_evaluated)
{
    test_rule.enabled = false;

    int ret = rule_engine_process_event(5, "binary_switch", 1);

    zassert_equal(zwave_host_send_cmd_fake.call_count, 0,
                  "Disabled rule should not dispatch any command");
}
```

## Mocking Patterns

### Mock a Zephyr Driver Function

```c
/* To mock a function like uart_irq_tx_enable() */
FAKE_VOID_FUNC(uart_irq_tx_enable, const struct device *);

/* In test setup */
RESET_FAKE(uart_irq_tx_enable);
```

### Mock a Module's Public API

```c
/* To mock storage_mgr_write_file() from the storage manager */
FAKE_VALUE_FUNC(int, storage_mgr_write_file, const char *, const char *, size_t);

/* Set return value */
storage_mgr_write_file_fake.return_val = 0;  /* Success */

/* Verify it was called */
zassert_equal(storage_mgr_write_file_fake.call_count, 1);
zassert_str_equal(storage_mgr_write_file_fake.arg0_val, "/lfs/zwave/devices.json");
```

### Mock an ISR / Hardware Callback

For testing code that responds to hardware events, simulate the event:

```c
/* Simulate a UART RX of a Serial API frame */
static void simulate_serial_api_response(const uint8_t *frame, size_t len)
{
    for (size_t i = 0; i < len; i++) {
        /* Call the RX handler directly */
        zwave_uart_rx_handler(frame[i]);
    }
}
```

## Testing Z-Wave Serial API Frames

```c
/* Test frame construction */
ZTEST(zwave_frame_tests, test_build_send_data_frame)
{
    uint8_t frame[32];
    uint8_t params[] = {0x05, 0x03, 0x25, 0x01, 0xFF}; /* Node 5, SWITCH_BINARY SET ON */

    int len = serial_api_build_frame(frame, sizeof(frame),
                                      FUNC_ID_ZW_SEND_DATA, params, sizeof(params));

    zassert_true(len > 0, "Frame build should succeed");
    zassert_equal(frame[0], 0x01, "SOF byte");
    zassert_equal(frame[3], FUNC_ID_ZW_SEND_DATA, "Function ID");
}

/* Test frame parsing */
ZTEST(zwave_frame_tests, test_parse_ack)
{
    uint8_t ack = SERIAL_API_ACK;
    enum frame_parse_result result = serial_api_parse_byte(ack);

    zassert_equal(result, FRAME_RESULT_ACK, "Should parse ACK");
}
```

## Testing JSON Parse/Build

```c
ZTEST(shadow_mgr_tests, test_parse_device_delta)
{
    const char *json = "{\"state\":{\"binary_switch\":true,\"dimmer_level\":75}}";
    struct shadow_delta delta = {0};

    int ret = shadow_parse_delta(json, &delta);

    zassert_equal(ret, 0, "Parse should succeed");
    zassert_true(delta.binary_switch, "Switch should be ON");
    zassert_equal(delta.dimmer_level, 75, "Dimmer should be 75");
}

ZTEST(shadow_mgr_tests, test_parse_invalid_json)
{
    const char *json = "{invalid json}";
    struct shadow_delta delta = {0};

    int ret = shadow_parse_delta(json, &delta);

    zassert_equal(ret, -EINVAL, "Should return EINVAL for invalid JSON");
}
```

## Coverage Thresholds

- **Lines**: 80% target for modules testable on native_sim
- **Branches**: 70% target
- **Functions**: 90% target
- **Modules excluded from coverage**: WiFi driver interaction (requires real hardware), BLE HCI (net core), POFCON ISR (hardware-specific)

## Running Tests

```bash
# All unit tests on native_sim
west twister -p native_sim -T app/tests/unit/

# Specific test
west twister -p native_sim -T app/tests/unit/test_rule_engine/

# With coverage
west twister -p native_sim -T app/tests/ --enable-coverage

# Verbose output
west twister -p native_sim -T app/tests/ -v
```
