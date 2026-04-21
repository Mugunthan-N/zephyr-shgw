/* =========================================================================
 * src/storage_mgr/storage_mgr.c — Storage Manager Implementation
 * ========================================================================= */
#include "storage_mgr.h"

#include <zephyr/fs/fs.h>
#include <zephyr/fs/littlefs.h>
#include <zephyr/kvss/nvs.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/drivers/flash.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(storage_mgr, CONFIG_STORAGE_MGR_LOG_LEVEL);

/* ----- NVS partition macros ----- */
#define NVS_PARTITION        storage_partition
#define NVS_PARTITION_DEVICE PARTITION_DEVICE(NVS_PARTITION)
#define NVS_PARTITION_OFFSET PARTITION_OFFSET(NVS_PARTITION)
#define NVS_PARTITION_SIZE   PARTITION_SIZE(NVS_PARTITION)

/* ----- LittleFS manual mount fallback ----- */
FS_LITTLEFS_DECLARE_DEFAULT_CONFIG(lfs_data);

static struct fs_mount_t lfs_mnt = {
	.type = FS_LITTLEFS,
	.fs_data = &lfs_data,
	.storage_dev = (void *)PARTITION_ID(lfs1_partition),
	.mnt_point = "/lfs",
};

/* ----- Module state ----- */
static struct {
	bool initialized;
	struct nvs_fs nvs;
} state;

/* ----- Directories to create at init ----- */
static const char *const init_dirs[] = {
	"/lfs/config",
	"/lfs/certs",
	"/lfs/zwave",
	"/lfs/shadow",
};

/* ----- Public API ----- */

int storage_mgr_init(void)
{
	if (state.initialized) {
		LOG_WRN("Already initialized");
		return -EALREADY;
	}

	int ret;

	/* 1. Verify LittleFS is mounted (fstab automount) or mount manually */
	struct fs_statvfs stat;

	ret = fs_statvfs("/lfs", &stat);
	if (ret != 0) {
		LOG_WRN("LittleFS not automounted (%d), attempting manual mount",
			ret);
		ret = fs_mount(&lfs_mnt);
		if (ret != 0) {
			LOG_ERR("LittleFS mount failed: %d", ret);
			return ret;
		}
		LOG_INF("LittleFS mounted manually at /lfs");
	} else {
		LOG_INF("LittleFS automounted at /lfs");
	}

	/* 2. Create base directories (ignore -EEXIST) */
	for (size_t i = 0; i < ARRAY_SIZE(init_dirs); i++) {
		ret = fs_mkdir(init_dirs[i]);
		if (ret != 0 && ret != -EEXIST) {
			LOG_ERR("Failed to create dir %s: %d", init_dirs[i],
				ret);
			return ret;
		}
	}

	/* 3. Initialize NVS */
	state.nvs.flash_device = NVS_PARTITION_DEVICE;
	if (!device_is_ready(state.nvs.flash_device)) {
		LOG_ERR("NVS flash device not ready");
		return -ENODEV;
	}

	state.nvs.offset = NVS_PARTITION_OFFSET;

	struct flash_pages_info info;

	ret = flash_get_page_info_by_offs(state.nvs.flash_device,
					  state.nvs.offset, &info);
	if (ret != 0) {
		LOG_ERR("Failed to get flash page info: %d", ret);
		return ret;
	}

	state.nvs.sector_size = (uint16_t)info.size;
	state.nvs.sector_count = NVS_PARTITION_SIZE / info.size;

	ret = nvs_mount(&state.nvs);
	if (ret != 0) {
		LOG_ERR("NVS mount failed: %d", ret);
		return ret;
	}

	state.initialized = true;
	LOG_INF("Storage manager initialized");
	return 0;
}

int storage_mgr_file_write(const char *path, const void *data, size_t len)
{
	if (!path || !data) {
		LOG_ERR("Invalid params: path=%p data=%p", path, data);
		return -EINVAL;
	}

	if (!state.initialized) {
		LOG_ERR("Storage manager not initialized");
		return -EAGAIN;
	}

	struct fs_file_t file;

	fs_file_t_init(&file);

	int ret = fs_open(&file, path, FS_O_WRITE | FS_O_CREATE);

	if (ret != 0) {
		LOG_ERR("Failed to open %s for write: %d", path, ret);
		return ret;
	}

	ret = fs_write(&file, data, len);

	int close_ret = fs_close(&file);

	if (ret < 0) {
		LOG_ERR("Failed to write %s: %d", path, ret);
		return ret;
	}

	if (ret != (ssize_t)len) {
		LOG_ERR("Partial write to %s: wrote %d of %zu bytes", path, ret,
			len);
		return -EIO;
	}

	if (close_ret != 0) {
		LOG_ERR("Failed to close %s: %d", path, close_ret);
		return close_ret;
	}

	return 0;
}

int storage_mgr_file_read(const char *path, void *buf, size_t buf_size,
			   size_t *bytes_read)
{
	if (!path || !buf) {
		LOG_ERR("Invalid params: path=%p buf=%p", path, buf);
		return -EINVAL;
	}

	if (!state.initialized) {
		LOG_ERR("Storage manager not initialized");
		return -EAGAIN;
	}

	struct fs_file_t file;

	fs_file_t_init(&file);

	int ret = fs_open(&file, path, FS_O_READ);

	if (ret != 0) {
		LOG_ERR("Failed to open %s for read: %d", path, ret);
		return ret;
	}

	ret = fs_read(&file, buf, buf_size);

	int close_ret = fs_close(&file);

	if (ret < 0) {
		LOG_ERR("Failed to read %s: %d", path, ret);
		return ret;
	}

	if (bytes_read) {
		*bytes_read = (size_t)ret;
	}

	if (close_ret != 0) {
		LOG_ERR("Failed to close %s: %d", path, close_ret);
		return close_ret;
	}

	return 0;
}

int storage_mgr_dir_list(const char *path, storage_mgr_dir_cb_t callback)
{
	if (!path || !callback) {
		LOG_ERR("Invalid params: path=%p callback=%p", path, callback);
		return -EINVAL;
	}

	if (!state.initialized) {
		LOG_ERR("Storage manager not initialized");
		return -EAGAIN;
	}

	struct fs_dir_t dir;

	fs_dir_t_init(&dir);

	int ret = fs_opendir(&dir, path);

	if (ret != 0) {
		LOG_ERR("Failed to open dir %s: %d", path, ret);
		return ret;
	}

	struct fs_dirent entry;

	while (true) {
		ret = fs_readdir(&dir, &entry);
		if (ret != 0) {
			LOG_ERR("Failed to read dir %s: %d", path, ret);
			fs_closedir(&dir);
			return ret;
		}

		if (entry.name[0] == '\0') {
			break;
		}

		callback(entry.name, entry.type == FS_DIR_ENTRY_DIR);
	}

	ret = fs_closedir(&dir);
	if (ret != 0) {
		LOG_ERR("Failed to close dir %s: %d", path, ret);
		return ret;
	}

	return 0;
}

int storage_mgr_nvs_write(uint16_t id, const void *data, size_t len)
{
	if (!data) {
		LOG_ERR("Invalid params: data is NULL");
		return -EINVAL;
	}

	if (!state.initialized) {
		LOG_ERR("Storage manager not initialized");
		return -EAGAIN;
	}

	int ret = nvs_write(&state.nvs, id, data, len);

	if (ret < 0) {
		LOG_ERR("NVS write failed (id=%u): %d", id, ret);
		return ret;
	}

	return 0;
}

int storage_mgr_nvs_read(uint16_t id, void *buf, size_t len)
{
	if (!buf) {
		LOG_ERR("Invalid params: buf is NULL");
		return -EINVAL;
	}

	if (!state.initialized) {
		LOG_ERR("Storage manager not initialized");
		return -EAGAIN;
	}

	int ret = nvs_read(&state.nvs, id, buf, len);

	if (ret < 0) {
		LOG_ERR("NVS read failed (id=%u): %d", id, ret);
		return ret;
	}

	return ret; /* Return bytes read on success */
}

#ifdef CONFIG_ZTEST
void storage_mgr_reset_for_test(void)
{
	state.initialized = false;
}
#endif
