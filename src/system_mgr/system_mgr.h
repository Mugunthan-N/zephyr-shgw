/* =========================================================================
 * src/system_mgr/system_mgr.h — System Manager Public API
 * ========================================================================= */
#ifndef SYSTEM_MGR_H_
#define SYSTEM_MGR_H_

#include <zephyr/kernel.h>

/**
 * @brief System operating states per SHG-SSD-001 §14.3.
 */
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

/**
 * @brief Initialize the System Manager.
 *
 * Reads NVS provisioned flag to determine initial state:
 *   - provisioned == 0 or absent -> STATE_PROVISIONING
 *   - provisioned == 1           -> STATE_CONNECTING
 *
 * Initializes the global sys_events k_event object.
 *
 * @return 0 on success, -EALREADY if already initialized,
 *         negative errno on failure.
 */
int system_mgr_init(void);

/**
 * @brief Get the current system state.
 *
 * Thread-safe: reads an atomic-width value.
 *
 * @return Current enum system_state value.
 */
enum system_state system_mgr_get_state(void);

/**
 * @brief Get string name for a system state.
 *
 * @param s  The state value.
 * @return   Static string (e.g., "BOOT", "OPERATIONAL"). Never NULL.
 */
const char *system_mgr_state_name(enum system_state s);

#ifdef CONFIG_ZTEST
/**
 * @brief Reset system manager state for testing.
 *
 * Clears the initialized flag and resets state to STATE_BOOT.
 * Only available in test builds.
 */
void system_mgr_reset_for_test(void);

/**
 * @brief Attempt a state transition (test-only wrapper).
 *
 * @param new_state Target state.
 * @return 0 on success, -EINVAL if transition is invalid.
 */
int system_mgr_transition(enum system_state new_state);
#endif

#endif /* SYSTEM_MGR_H_ */
