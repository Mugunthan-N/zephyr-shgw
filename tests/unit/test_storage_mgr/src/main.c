/* =========================================================================
 * tests/unit/test_storage_mgr/src/main.c — Storage Manager unit tests
 * ========================================================================= */
#include <zephyr/ztest.h>
#include "storage_mgr/storage_mgr.h"

static void *storage_mgr_setup(void)
{
	int ret = storage_mgr_init();

	zassert_equal(ret, 0, "storage_mgr_init failed: %d", ret);
	return NULL;
}

ZTEST_SUITE(storage_mgr, NULL, storage_mgr_setup, NULL, NULL, NULL);

ZTEST(storage_mgr, test_storage_mgr_init)
{
	/* Init already called in setup — verify re-init returns -EALREADY */
	int ret = storage_mgr_init();

	zassert_equal(ret, -EALREADY, "Expected -EALREADY, got %d", ret);
}

ZTEST(storage_mgr, test_storage_mgr_file_write_read)
{
	const char *data = "hello";
	int ret = storage_mgr_file_write("/lfs/test.txt", data, 5);

	zassert_equal(ret, 0, "Write failed: %d", ret);

	char buf[32];
	size_t bytes_read;

	ret = storage_mgr_file_read("/lfs/test.txt", buf, sizeof(buf),
				    &bytes_read);
	zassert_equal(ret, 0, "Read failed: %d", ret);
	zassert_equal(bytes_read, 5, "Expected 5 bytes, got %zu", bytes_read);
	zassert_mem_equal(buf, data, 5, "Data mismatch");
}

static bool dir_test_found;

static void dir_list_test_cb(const char *name, bool is_dir)
{
	if (strcmp(name, "dir_test.txt") == 0 && !is_dir) {
		dir_test_found = true;
	}
}

ZTEST(storage_mgr, test_storage_mgr_dir_list)
{
	/* Write a file so it shows up in dir listing */
	storage_mgr_file_write("/lfs/dir_test.txt", "x", 1);

	dir_test_found = false;

	int ret = storage_mgr_dir_list("/lfs", dir_list_test_cb);

	zassert_equal(ret, 0, "Dir list failed: %d", ret);
	zassert_true(dir_test_found, "dir_test.txt not found in listing");
}

ZTEST(storage_mgr, test_storage_mgr_nvs_write_read)
{
	uint32_t write_val = 42;
	int ret = storage_mgr_nvs_write(100, &write_val, sizeof(write_val));

	zassert_equal(ret, 0, "NVS write failed: %d", ret);

	uint32_t read_val = 0;

	ret = storage_mgr_nvs_read(100, &read_val, sizeof(read_val));
	zassert_true(ret >= 0, "NVS read failed: %d", ret);
	zassert_equal(read_val, 42, "NVS data mismatch: got %u", read_val);
}

ZTEST(storage_mgr, test_storage_mgr_read_nonexistent)
{
	char buf[16];
	size_t bytes_read;
	int ret = storage_mgr_file_read("/lfs/no_such_file.txt", buf,
					sizeof(buf), &bytes_read);

	zassert_equal(ret, -ENOENT, "Expected -ENOENT, got %d", ret);
}
