/* =========================================================================
 * src/main.c — Application entry point (Phase 1)
 * ========================================================================= */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <app_version.h>

#include "storage_mgr/storage_mgr.h"
#include "system_mgr/system_mgr.h"

LOG_MODULE_REGISTER(main, LOG_LEVEL_INF);

int main(void)
{
	int ret;

	/* 1. Initialize storage (LittleFS + NVS) — must be first */
	ret = storage_mgr_init();
	if (ret != 0) {
		LOG_ERR("Storage init failed: %d", ret);
		return ret;
	}

	/* 2. Initialize System Manager (reads NVS, transitions state) */
	ret = system_mgr_init();
	if (ret != 0) {
		LOG_ERR("System Manager init failed: %d", ret);
	}

	/* 3. Increment and persist boot count */
	uint32_t boot_count = 0;

	ret = storage_mgr_nvs_read(NVS_ID_BOOT_COUNT, &boot_count,
				   sizeof(boot_count));
	if (ret < 0) {
		boot_count = 0; /* First boot — key not found */
	}
	boot_count++;

	ret = storage_mgr_nvs_write(NVS_ID_BOOT_COUNT, &boot_count,
				    sizeof(boot_count));
	if (ret != 0) {
		LOG_ERR("Failed to write boot count: %d", ret);
	}

	/* 4. Log boot info */
	LOG_INF("=== Smart Home Gateway ===");
	LOG_INF("Firmware : v%s", APP_VERSION_STRING);
	LOG_INF("Boot count: %u", boot_count);
	LOG_INF("State    : %s",
		system_mgr_state_name(system_mgr_get_state()));

	/* Shell is auto-started by Zephyr shell subsystem.
	 * main() returns and scheduler takes over. */
	return 0;
}
