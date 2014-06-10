#include "hal_platform.h"
#include "hal_aci_tl.h"
#include "aci_queue.h"
#include <avr/sleep.h>

interface nRF8001hal_aci_tl
{
 	command void debug_print(bool enable);
 	command void pin_reset(void);
 	command bool event_peek(hal_aci_data_t *p_aci_data);
 	command bool event_get(hal_aci_data_t *p_aci_data);
 	command void init(aci_pins_t *a_pins, bool debug);
 	command bool send(hal_aci_data_t *p_aci_cmd);
 	command bool rx_q_empty (void);
	command bool rx_q_full();
	command bool tx_q_empty (void);
	command bool tx_q_full (void);
	command void q_flush (void);
	command void board_init(aci_state_t *aci_stat);
}