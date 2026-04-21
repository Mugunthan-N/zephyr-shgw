/* =========================================================================
 * tests/unit/test_shell/src/main.c — Shell command unit tests
 * ========================================================================= */
#include <zephyr/ztest.h>
#include <zephyr/shell/shell.h>
#include <zephyr/shell/shell_dummy.h>
#include <string.h>

#include "storage_mgr/storage_mgr.h"
#include "system_mgr/system_mgr.h"

static const struct shell *sh;

static void *shell_test_setup(void)
{
	int ret;

	ret = storage_mgr_init();
	zassert_true(ret == 0 || ret == -EALREADY,
		     "storage_mgr_init failed: %d", ret);

	ret = system_mgr_init();
	zassert_true(ret == 0 || ret == -EALREADY,
		     "system_mgr_init failed: %d", ret);

	sh = shell_backend_dummy_get_ptr();
	zassert_not_null(sh, "Failed to get dummy shell backend");

	/* Wait for shell backend to become active */
	while (!shell_ready(sh)) {
		k_msleep(10);
	}

	return NULL;
}

ZTEST_SUITE(shell_tests, NULL, shell_test_setup, NULL, NULL, NULL);

ZTEST(shell_tests, test_shell_shg_info)
{
	int ret;
	size_t size;

	shell_backend_dummy_clear_output(sh);
	ret = shell_execute_cmd(sh, "shg info");
	zassert_ok(ret, "shg info failed: %d", ret);

	const char *output = shell_backend_dummy_get_output(sh, &size);

	zassert_true(size > 0, "No output from shg info");
	zassert_not_null(strstr(output, "Firmware"),
			 "Version info not found in output:\n%s", output);
}

ZTEST(shell_tests, test_shell_fs_ls)
{
	int ret;

	/* Write a test file so it shows up in listing */
	ret = storage_mgr_file_write("/lfs/ls_test.txt", "data", 4);
	zassert_equal(ret, 0, "file write failed: %d", ret);

	size_t size;

	shell_backend_dummy_clear_output(sh);
	ret = shell_execute_cmd(sh, "fs ls /lfs");
	zassert_ok(ret, "fs ls failed: %d", ret);

	const char *output = shell_backend_dummy_get_output(sh, &size);

	zassert_true(size > 0, "No output from fs ls");
	zassert_not_null(strstr(output, "ls_test.txt"),
			 "ls_test.txt not found in output:\n%s", output);
}

ZTEST(shell_tests, test_shell_fs_cat)
{
	int ret;
	const char *content = "hello from test";

	ret = storage_mgr_file_write("/lfs/cat_test.txt", content,
				     strlen(content));
	zassert_equal(ret, 0, "file write failed: %d", ret);

	size_t size;

	shell_backend_dummy_clear_output(sh);
	ret = shell_execute_cmd(sh, "fs cat /lfs/cat_test.txt");
	zassert_ok(ret, "fs cat failed: %d", ret);

	const char *output = shell_backend_dummy_get_output(sh, &size);

	zassert_true(size > 0, "No output from fs cat");
	zassert_not_null(strstr(output, "hello from test"),
			 "File content not found in output:\n%s", output);
}
