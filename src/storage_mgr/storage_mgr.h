/* =========================================================================
 * src/storage_mgr/storage_mgr.h — Storage Manager Public API
 * ========================================================================= */
#ifndef STORAGE_MGR_H_
#define STORAGE_MGR_H_

#include <zephyr/kernel.h>
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/* --- NVS Key ID Allocation (Phase 1) --- */
#define NVS_ID_BOOT_COUNT    1
#define NVS_ID_PROVISIONED   2
#define NVS_ID_FW_VERSION    3

/**
 * @brief Initialize LittleFS mount and NVS subsystem.
 *
 * Must be called before any other storage_mgr function.
 * Verifies LittleFS automount at /lfs (or mounts manually as fallback).
 * Initializes NVS on the internal flash storage partition.
 *
 * @return 0 on success, -EALREADY if already initialized,
 *         negative errno on failure.
 */
int storage_mgr_init(void);

/**
 * @brief Write data to a file on LittleFS.
 *
 * Creates the file if it does not exist. Overwrites if it does.
 *
 * @param path   Absolute file path (e.g., "/lfs/test.txt").
 * @param data   Pointer to data buffer.
 * @param len    Number of bytes to write.
 * @return 0 on success, -EINVAL if path or data is NULL,
 *         negative errno on I/O failure.
 */
int storage_mgr_file_write(const char *path, const void *data, size_t len);

/**
 * @brief Read data from a file on LittleFS.
 *
 * @param path       Absolute file path.
 * @param buf        Buffer to read into.
 * @param buf_size   Maximum bytes to read.
 * @param bytes_read [out] Actual bytes read. May be NULL if not needed.
 * @return 0 on success, -ENOENT if file not found, -EINVAL if path or buf
 *         is NULL, negative errno on I/O failure.
 */
int storage_mgr_file_read(const char *path, void *buf, size_t buf_size,
			   size_t *bytes_read);

/**
 * @brief Callback type for directory listing.
 *
 * @param name   Entry name (file or directory).
 * @param is_dir true if the entry is a directory.
 */
typedef void (*storage_mgr_dir_cb_t)(const char *name, bool is_dir);

/**
 * @brief List entries in a directory on LittleFS.
 *
 * @param path     Absolute directory path.
 * @param callback Function called for each entry.
 * @return 0 on success, -ENOENT if path not found,
 *         -EINVAL if path or callback is NULL, negative errno on failure.
 */
int storage_mgr_dir_list(const char *path, storage_mgr_dir_cb_t callback);

/**
 * @brief Write data to an NVS key.
 *
 * @param id   NVS key ID.
 * @param data Pointer to data buffer.
 * @param len  Number of bytes to write.
 * @return 0 on success, negative errno on failure.
 */
int storage_mgr_nvs_write(uint16_t id, const void *data, size_t len);

/**
 * @brief Read data from an NVS key.
 *
 * @param id  NVS key ID.
 * @param buf Buffer to read into.
 * @param len Maximum bytes to read.
 * @return Number of bytes read on success (>=0), -ENOENT if key not found,
 *         negative errno on failure.
 */
int storage_mgr_nvs_read(uint16_t id, void *buf, size_t len);

#ifdef CONFIG_ZTEST
/**
 * @brief Reset storage manager state for testing.
 *
 * Clears the initialized flag so storage_mgr_init() can be called again.
 * Only available in test builds.
 */
void storage_mgr_reset_for_test(void);
#endif

#endif /* STORAGE_MGR_H_ */
