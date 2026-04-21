/* =========================================================================
 * src/shell/shell_fs.c — 'fs' filesystem shell commands
 * ========================================================================= */
#include <zephyr/shell/shell.h>
#include <zephyr/fs/fs.h>
#include <zephyr/logging/log.h>

#include "storage_mgr/storage_mgr.h"

LOG_MODULE_REGISTER(shell_fs, LOG_LEVEL_INF);

#ifdef CONFIG_SHG_SHELL_PRODUCTION

/* ----- Constants ----- */
#define FS_CAT_BUF_SIZE 256

/* ----- fs ls ----- */

static int cmd_fs_ls(const struct shell *sh, size_t argc, char **argv)
{
	const char *path = (argc >= 2) ? argv[1] : "/lfs";

	struct fs_dir_t dir;

	fs_dir_t_init(&dir);

	int ret = fs_opendir(&dir, path);

	if (ret != 0) {
		shell_error(sh, "Cannot open directory %s: %d", path, ret);
		return ret;
	}

	struct fs_dirent entry;

	while (true) {
		ret = fs_readdir(&dir, &entry);
		if (ret != 0) {
			shell_error(sh, "Read error: %d", ret);
			fs_closedir(&dir);
			return ret;
		}

		if (entry.name[0] == '\0') {
			break;
		}

		if (entry.type == FS_DIR_ENTRY_DIR) {
			shell_print(sh, "[DIR]  %s", entry.name);
		} else {
			shell_print(sh, "[FILE] %s (%zu bytes)",
				    entry.name, entry.size);
		}
	}

	ret = fs_closedir(&dir);
	if (ret != 0) {
		shell_error(sh, "Close error: %d", ret);
		return ret;
	}

	return 0;
}

/* ----- fs cat ----- */

static int cmd_fs_cat(const struct shell *sh, size_t argc, char **argv)
{
	if (argc < 2) {
		shell_error(sh, "Usage: fs cat <path>");
		return -EINVAL;
	}

	const char *path = argv[1];
	char buf[FS_CAT_BUF_SIZE];
	size_t bytes_read;

	int ret = storage_mgr_file_read(path, buf, sizeof(buf) - 1,
					&bytes_read);
	if (ret == -ENOENT) {
		shell_error(sh, "File not found: %s", path);
		return ret;
	}
	if (ret < 0) {
		shell_error(sh, "Read error: %d", ret);
		return ret;
	}

	buf[bytes_read] = '\0';
	shell_print(sh, "%s", buf);
	return 0;
}

SHELL_STATIC_SUBCMD_SET_CREATE(sub_fs,
	SHELL_CMD_ARG(ls, NULL, "List directory: fs ls [path]",
		      cmd_fs_ls, 1, 1),
	SHELL_CMD_ARG(cat, NULL, "Print file: fs cat <path>",
		      cmd_fs_cat, 2, 0),
	SHELL_SUBCMD_SET_END
);

SHELL_CMD_REGISTER(fs, &sub_fs, "Filesystem commands", NULL);

#endif /* CONFIG_SHG_SHELL_PRODUCTION */
