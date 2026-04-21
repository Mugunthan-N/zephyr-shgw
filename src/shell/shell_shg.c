/* =========================================================================
 * src/shell/shell_shg.c — 'shg' shell commands
 * ========================================================================= */
#include <zephyr/shell/shell.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <app_version.h>

#include "system_mgr/system_mgr.h"

LOG_MODULE_REGISTER(shell_shg, LOG_LEVEL_INF);

#ifdef CONFIG_SHG_SHELL_PRODUCTION

static int cmd_shg_info(const struct shell *sh, size_t argc, char **argv)
{
	ARG_UNUSED(argc);
	ARG_UNUSED(argv);

	shell_print(sh, "Firmware : %s", APP_VERSION_STRING);
	shell_print(sh, "Uptime   : %lld ms", k_uptime_get());
	shell_print(sh, "State    : %s",
		    system_mgr_state_name(system_mgr_get_state()));
	return 0;
}

SHELL_STATIC_SUBCMD_SET_CREATE(sub_shg,
	SHELL_CMD(info, NULL, "Print firmware info", cmd_shg_info),
	SHELL_SUBCMD_SET_END
);

SHELL_CMD_REGISTER(shg, &sub_shg, "Smart Home Gateway commands", NULL);

#endif /* CONFIG_SHG_SHELL_PRODUCTION */
