/* =========================================================================
 * src/common/event_bus.h — System-wide event definitions
 * ========================================================================= */
#ifndef EVENT_BUS_H_
#define EVENT_BUS_H_

#include <zephyr/kernel.h>

/**
 * @brief System-wide broadcast events.
 *
 * Posted via k_event_post(&sys_events, EVENT_xxx).
 * Consumed via k_event_wait(&sys_events, mask, ...).
 */
enum system_event {
	EVENT_WIFI_CONNECTED    = BIT(0),
	EVENT_WIFI_DISCONNECTED = BIT(1),
	EVENT_WIFI_FAILED       = BIT(2),
	EVENT_MQTT_CONNECTED    = BIT(3),
	EVENT_MQTT_DISCONNECTED = BIT(4),
	EVENT_SHADOW_SYNCED     = BIT(5),
	EVENT_SHUTDOWN          = BIT(6),
	EVENT_OTA_AVAILABLE     = BIT(7),
	EVENT_PROVISIONED       = BIT(8),
	EVENT_ZWAVE_READY       = BIT(9),
};

/** Global system event object. Defined in system_mgr.c. */
extern struct k_event sys_events;

#endif /* EVENT_BUS_H_ */
