/* =========================================================================
 * src/system_mgr/system_mgr.c — System Manager Implementation
 * ========================================================================= */
#include "system_mgr.h"
#include "common/event_bus.h"
#include "storage_mgr/storage_mgr.h"

#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(system_mgr, CONFIG_SYSTEM_MGR_LOG_LEVEL);

/* ----- Global event bus object (declared extern in event_bus.h) ----- */
K_EVENT_DEFINE(sys_events);

/* ----- State name lookup table ----- */
static const char *const state_names[] = {
	[STATE_BOOT]         = "BOOT",
	[STATE_PROVISIONING] = "PROVISIONING",
	[STATE_CONNECTING]   = "CONNECTING",
	[STATE_OPERATIONAL]  = "OPERATIONAL",
	[STATE_DEGRADED]     = "DEGRADED",
	[STATE_OTA_UPDATE]   = "OTA_UPDATE",
	[STATE_SHUTDOWN]     = "SHUTDOWN",
	[STATE_FACTORY_TEST] = "FACTORY_TEST",
	[STATE_AGING_TEST]   = "AGING_TEST",
};

#define STATE_COUNT ARRAY_SIZE(state_names)

/* ----- Module state ----- */
static struct {
	bool initialized;
	enum system_state current_state;
} state;

/* ----- Private functions ----- */

static bool is_valid_transition(enum system_state from,
				enum system_state to)
{
	switch (from) {
	case STATE_BOOT:
		return (to == STATE_PROVISIONING ||
			to == STATE_CONNECTING ||
			to == STATE_FACTORY_TEST ||
			to == STATE_AGING_TEST);
	case STATE_PROVISIONING:
		return (to == STATE_CONNECTING ||
			to == STATE_SHUTDOWN);
	case STATE_CONNECTING:
		return (to == STATE_OPERATIONAL ||
			to == STATE_DEGRADED ||
			to == STATE_PROVISIONING ||
			to == STATE_SHUTDOWN);
	case STATE_OPERATIONAL:
		return (to == STATE_DEGRADED ||
			to == STATE_OTA_UPDATE ||
			to == STATE_SHUTDOWN);
	case STATE_DEGRADED:
		return (to == STATE_OPERATIONAL ||
			to == STATE_SHUTDOWN);
	case STATE_OTA_UPDATE:
		return (to == STATE_BOOT);
	case STATE_SHUTDOWN:
		return false; /* Terminal state */
	case STATE_FACTORY_TEST:
		return (to == STATE_BOOT ||
			to == STATE_SHUTDOWN);
	case STATE_AGING_TEST:
		return (to == STATE_BOOT ||
			to == STATE_SHUTDOWN);
	default:
		return false;
	}
}

static int transition_to(enum system_state new_state)
{
	if (!is_valid_transition(state.current_state, new_state)) {
		LOG_WRN("Invalid transition: %s -> %s",
			system_mgr_state_name(state.current_state),
			system_mgr_state_name(new_state));
		return -EINVAL;
	}

	LOG_INF("State transition: %s -> %s",
		system_mgr_state_name(state.current_state),
		system_mgr_state_name(new_state));

	state.current_state = new_state;
	return 0;
}

/* ----- Public API ----- */

int system_mgr_init(void)
{
	if (state.initialized) {
		LOG_WRN("Already initialized");
		return -EALREADY;
	}

	state.current_state = STATE_BOOT;

	/* Read NVS provisioned flag */
	uint8_t provisioned = 0;
	int ret = storage_mgr_nvs_read(NVS_ID_PROVISIONED, &provisioned,
				       sizeof(provisioned));
	if (ret < 0) {
		/* Key not found or read error — default to not provisioned */
		provisioned = 0;
	}

	if (provisioned == 1) {
		ret = transition_to(STATE_CONNECTING);
	} else {
		ret = transition_to(STATE_PROVISIONING);
	}

	if (ret != 0) {
		LOG_ERR("Initial state transition failed: %d", ret);
		return ret;
	}

	state.initialized = true;
	LOG_INF("System manager initialized");
	return 0;
}

enum system_state system_mgr_get_state(void)
{
	return state.current_state;
}

const char *system_mgr_state_name(enum system_state s)
{
	if ((unsigned int)s >= STATE_COUNT) {
		return "UNKNOWN";
	}
	return state_names[s];
}

#ifdef CONFIG_ZTEST
void system_mgr_reset_for_test(void)
{
	state.initialized = false;
	state.current_state = STATE_BOOT;
}

int system_mgr_transition(enum system_state new_state)
{
	return transition_to(new_state);
}
#endif
