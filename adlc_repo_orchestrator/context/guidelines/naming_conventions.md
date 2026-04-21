---
type: guideline
scope: project-specific
version: "1.0.0"
domain: naming
agents: [all]
---

# zephyr-shgw — Naming Conventions

## Variables & Functions
- **Style**: `lower_snake_case`
- **Boolean prefix**: `is_`, `has_`, `can_`, `should_` (e.g., `is_reachable`, `has_credentials`, `is_listening`)
- **Public functions**: prefixed with module name — `wifi_mgr_connect()`, `shadow_mgr_update()`, `zwave_host_send()`
- **Private (static) functions**: no module prefix, descriptive name — `parse_frame()`, `handle_delta()`
- **Callback functions**: suffix `_cb` or `_handler` — `mqtt_evt_handler()`, `wifi_connect_cb()`

## Constants & Macros
- **Style**: `UPPER_SNAKE_CASE`
- **Prefixed by module**: `ZWAVE_MAX_NODES`, `MQTT_KEEPALIVE_SEC`, `WIFI_RECONNECT_MAX_BACKOFF_MS`
- **Config Kconfig**: `CONFIG_<MODULE>_<SETTING>` — `CONFIG_SHG_SHELL_PRODUCTION`, `CONFIG_WIFI_MGR_LOG_LEVEL`

## Enums
- **Type name**: `lower_snake_case` — `enum system_state`, `enum rule_operator`
- **Values**: `UPPER_SNAKE_CASE` with category prefix — `STATE_BOOT`, `STATE_OPERATIONAL`, `OP_EQ`, `OP_GT`

## Structs
- **Type name**: `lower_snake_case` — `struct zwave_device`, `struct rule_condition`, `struct shadow_delta`
- **Field names**: `lower_snake_case` — `node_id`, `device_type`, `last_seen_timestamp`

## Typedefs
- **Suffix `_t` for opaque types only** (Zephyr convention): `k_tid_t`, `k_timeout_t`
- **Do not typedef structs** — use `struct my_struct` directly (Zephyr coding style)

## Files & Directories
- **Source files**: `lower_snake_case.c`, `lower_snake_case.h`
- **Module directories**: `lower_snake_case` matching module name — `src/wifi_mgr/`, `src/zwave_host/`, `src/shadow_mgr/`
- **Test files**: `test_<module_name>/` directory under `tests/unit/` — `tests/unit/test_rule_engine/`
- **Config files on LittleFS**: `lower_snake_case.json` — `wifi.json`, `devices.json`, `gateway_rules.json`
- **Devicetree overlays**: `app.overlay`, `<board>.overlay`
- **Kconfig fragments**: `prj.conf`, `debug.conf`

## Events / Messages
- **Event flag names**: `EVENT_<SUBJECT>_<ACTION>` in `UPPER_SNAKE_CASE` — `EVENT_WIFI_CONNECTED`, `EVENT_SHUTDOWN`, `EVENT_OTA_AVAILABLE`
- **Message queue struct names**: `<purpose>_msg` — `struct shadow_update_msg`, `struct zwave_cmd_msg`

## Zephyr Kernel Objects
- **Message queues**: `<purpose>_queue` — `shadow_update_queue`, `zwave_cmd_queue`
- **Semaphores**: `<resource>_sem` — `lfs_sem`, `rx_sem`
- **Events**: `<scope>_events` — `sys_events`
- **Thread data**: `<name>_thread_data` — `wifi_mgr_thread_data`
- **Thread stacks**: `<name>_stack` — `wifi_mgr_stack`

## Log Module Names
- **Style**: `lower_snake_case`, matching the source module — `wifi_mgr`, `shadow_mgr`, `zwave_host`, `rule_engine`
- Registered with `LOG_MODULE_REGISTER(<name>, CONFIG_<NAME>_LOG_LEVEL)`

## Shell Commands
- **Top-level commands**: short, lowercase — `shg`, `wifi`, `zwave`, `aws`, `cert`, `fs`, `shadow`
- **Subcommands**: lowercase verb — `status`, `connect`, `add`, `remove`, `list`, `dump`, `configure`

## JSON Keys (Shadow & Config)
- **Style**: `lower_snake_case` — `binary_switch`, `dimmer_level`, `device_type`, `is_reachable`, `last_seen`
- Matches the C struct field names where possible.

## AWS IoT Shadow Names
- **Gateway shadow**: `gateway`
- **Device shadows**: `zwave-node-{nodeId}` (kebab-case with node ID) — `zwave-node-5`, `zwave-node-12`

## Branch Naming (Git)
- **Format**: `<ticket_key>_<change_name>` — `SHGW-001_add_wifi_reconnect`, `task-005_fix_shadow_parse`
- **Change name**: `lower_snake_case`, max 50 chars

## Commit Messages
- **Format**: `<ticket_key>: <brief summary>` (max 72 chars first line)
- **Body**: list of changes, wrapped at 72 chars
