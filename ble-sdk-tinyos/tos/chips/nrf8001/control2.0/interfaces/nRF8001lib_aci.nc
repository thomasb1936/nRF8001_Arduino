

#include "hal_platform.h"
#include "aci.h"
#include "aci_cmds.h"
#include "aci_evts.h"
#include "aci_protocol_defines.h"
#include "acilib_defs.h"
#include "acilib_if.h"
#include "hal_aci_tl.h"
#include "aci_queue.h"
#include "lib_aci.h"

interface nRF8001lib_aci
{

	command bool aci_init();
	command bool is_pipe_available(aci_state_t *aci_stat, uint8_t pipe);
	command bool is_pipe_closed(aci_state_t *aci_stat, uint8_t pipe);
	command bool is_discovery_finished(aci_state_t *aci_stat);
	command void board_init(aci_state_t *aci_stat);
	command void init(aci_state_t *aci_stat, bool debug);
	command uint8_t get_nb_available_credits(aci_state_t *aci_stat);
	command uint16_t get_cx_interval_ms(aci_state_t *aci_stat);
	command uint16_t get_cx_interval(aci_state_t *aci_stat);
	command uint16_t get_slave_latency(aci_state_t *aci_stat);
	command bool set_app_latency(uint16_t latency, aci_app_latency_mode_t latency_mode);
	command bool test(aci_test_mode_change_t enter_exit_test_mode);
	command bool sleep();
	command bool radio_reset();
	command bool direct_connect();
	command bool device_version();
	command bool set_local_data(aci_state_t *aci_stat, uint8_t pipe, uint8_t *p_value, uint8_t size);
	command bool connect(uint16_t run_timeout, uint16_t adv_interval);
	command bool disconnect(aci_state_t *aci_stat, aci_disconnect_reason_t reason);
	command bool bond(uint16_t run_timeout, uint16_t adv_interval);
	command bool wakeup();
	command bool set_tx_power(aci_device_output_power_t tx_power);
	command bool get_address();
	command bool get_temperature();
	command bool get_battery_level();
	command bool send_data(uint8_t pipe, uint8_t *p_value, uint8_t size);
	command bool request_data(aci_state_t *aci_stat, uint8_t pipe);
	command bool change_timing(uint16_t minimun_cx_interval, uint16_t maximum_cx_interval, uint16_t slave_latency, uint16_t timeout);
	command bool change_timing_GAP_PPCP();
	command bool open_remote_pipe(aci_state_t *aci_stat, uint8_t pipe);
	command bool close_remote_pipe(aci_state_t *aci_stat, uint8_t pipe);
	command bool set_key(aci_key_type_t key_rsp_type, uint8_t *key, uint8_t len);
	command bool echo_msg(uint8_t msg_size, uint8_t *p_msg_data);
	command bool bond_request();
	command bool event_peek(hal_aci_evt_t *p_aci_evt_data);
	command bool event_get(aci_state_t *aci_stat, hal_aci_evt_t *p_aci_evt_data);
	command bool send_ack(aci_state_t *aci_stat, const uint8_t pipe);
	command bool send_nack(aci_state_t *aci_stat, const uint8_t pipe, const uint8_t error_code);
	command bool broadcast(const uint16_t timeout, const uint16_t adv_interval);
	command bool open_adv_pipes(const uint8_t * const adv_service_data_pipes);
	command bool open_adv_pipe(const uint8_t pipe);
	command bool read_dynamic_data();
	command bool write_dynamic_data(uint8_t sequence_number, uint8_t* dynamic_data, uint8_t length);
	command bool dtm_command(uint8_t dtm_command_msbyte, uint8_t dtm_command_lsbyte);
	command void flush(void);
	command void debug_print(bool enable);
	command void pin_reset(void);
	command bool event_queue_empty(void);
	command bool event_queue_full(void);
	command bool command_queue_empty(void);
	command bool command_queue_full(void);

}