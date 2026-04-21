/* =========================================================================
 * tests/unit/test_system_mgr/src/main.c — System Manager unit tests
 * ========================================================================= */
#include <zephyr/ztest.h>
#include "system_mgr/system_mgr.h"
#include "storage_mgr/storage_mgr.h"

static void *system_mgr_setup(void)
{
	int ret = storage_mgr_init();

	/* Allow -EALREADY in case prior suite already initialized */
	zassert_true(ret == 0 || ret == -EALREADY,
		     "storage_mgr_init failed: %d", ret);
	return NULL;
}

static void system_mgr_before(void *fixture)
{
	ARG_UNUSED(fixture);
	system_mgr_reset_for_test();
}

ZTEST_SUITE(system_mgr, NULL, system_mgr_setup, system_mgr_before,
	    NULL, NULL);

ZTEST(system_mgr, test_system_mgr_init_provisioning)
{
	/* NVS provisioned key is absent → should go to PROVISIONING */
	int ret = system_mgr_init();

	zassert_equal(ret, 0, "system_mgr_init failed: %d", ret);
	zassert_equal(system_mgr_get_state(), STATE_PROVISIONING,
		      "Expected STATE_PROVISIONING, got %s",
		      system_mgr_state_name(system_mgr_get_state()));
}

ZTEST(system_mgr, test_system_mgr_init_connecting)
{
	/* Write provisioned=1 to NVS, then init */
	uint8_t prov = 1;
	int ret = storage_mgr_nvs_write(NVS_ID_PROVISIONED, &prov,
					sizeof(prov));

	zassert_equal(ret, 0, "NVS write failed: %d", ret);

	ret = system_mgr_init();
	zassert_equal(ret, 0, "system_mgr_init failed: %d", ret);
	zassert_equal(system_mgr_get_state(), STATE_CONNECTING,
		      "Expected STATE_CONNECTING, got %s",
		      system_mgr_state_name(system_mgr_get_state()));

	/* Clean up: delete the provisioned key for other tests */
	uint8_t zero = 0;

	storage_mgr_nvs_write(NVS_ID_PROVISIONED, &zero, sizeof(zero));
}

ZTEST(system_mgr, test_system_mgr_get_state)
{
	int ret = system_mgr_init();

	zassert_equal(ret, 0, "system_mgr_init failed: %d", ret);

	enum system_state s = system_mgr_get_state();

	/* Should be PROVISIONING or CONNECTING depending on NVS */
	zassert_true(s == STATE_PROVISIONING || s == STATE_CONNECTING,
		     "Unexpected state: %s", system_mgr_state_name(s));
}

ZTEST(system_mgr, test_system_mgr_invalid_transition)
{
	int ret = system_mgr_init();

	zassert_equal(ret, 0, "system_mgr_init failed: %d", ret);

	/* From PROVISIONING, transition to OPERATIONAL is invalid */
	ret = system_mgr_transition(STATE_OPERATIONAL);
	zassert_equal(ret, -EINVAL,
		      "Expected -EINVAL for invalid transition, got %d", ret);
}
