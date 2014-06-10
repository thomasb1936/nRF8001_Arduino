
#include "hal_platform.h"
#include "aci.h"
#include "aci_cmds.h"
#include "aci_evts.h"
#include "acilib.h"
#include "aci_protocol_defines.h"
#include "acilib_defs.h"
#include "acilib_if.h"
#include "acilib_types.h"


interface nRF8001acilib
{
    command void encode_cmd_set_test_mode(uint8_t *buffer, aci_cmd_params_test_t *p_aci_cmd_params_test);
    command void encode_cmd_sleep(uint8_t *buffer);
    command void encode_cmd_get_device_version(uint8_t *buffer);
    command void encode_cmd_set_local_data(uint8_t *buffer, aci_cmd_params_set_local_data_t *p_aci_cmd_params_set_local_data, uint8_t data_size);
    command void encode_cmd_connect(uint8_t *buffer, aci_cmd_params_connect_t *p_aci_cmd_params_connect);
    command void encode_cmd_bond(uint8_t *buffer, aci_cmd_params_bond_t *p_aci_cmd_params_bond);
    command void encode_cmd_disconnect(uint8_t *buffer, aci_cmd_params_disconnect_t *p_aci_cmd_params_disconnect);
    command void encode_baseband_reset(uint8_t *buffer);
    command void encode_direct_connect(uint8_t *buffer);
    command void encode_cmd_wakeup(uint8_t *buffer);
    command void encode_cmd_set_radio_tx_power(uint8_t *buffer, aci_cmd_params_set_tx_power_t *p_aci_cmd_params_set_tx_power);
    command void encode_cmd_get_address(uint8_t *buffer);
    command void encode_cmd_send_data(uint8_t *buffer, aci_cmd_params_send_data_t *p_aci_cmd_params_send_data_t, uint8_t data_size);
    command void encode_cmd_request_data(uint8_t *buffer, aci_cmd_params_request_data_t *p_aci_cmd_params_request_data);
    command void encode_cmd_open_remote_pipe(uint8_t *buffer, aci_cmd_params_open_remote_pipe_t *p_aci_cmd_params_open_remote_pipe);
    command void encode_cmd_close_remote_pipe(uint8_t *buffer, aci_cmd_params_close_remote_pipe_t *p_aci_cmd_params_close_remote_pipe);
    command void encode_cmd_echo_msg(uint8_t *buffer, aci_cmd_params_echo_t *p_cmd_params_echo, uint8_t msg_size);
    command void encode_cmd_battery_level(uint8_t *buffer);
    command void encode_cmd_temparature(uint8_t *buffer);
    command void encode_cmd_read_dynamic_data(uint8_t *buffer);
    command void encode_cmd_write_dynamic_data(uint8_t *buffer, uint8_t seq_no, uint8_t* dynamic_data, uint8_t dynamic_data_size);
    command void encode_cmd_change_timing_req(uint8_t *buffer, aci_cmd_params_change_timing_t *p_aci_cmd_params_change_timing);
    command void encode_cmd_set_app_latency(uint8_t *buffer, aci_cmd_params_set_app_latency_t *p_aci_cmd_params_set_app_latency);
    command void encode_cmd_change_timing_req_GAP_PPCP(uint8_t *buffer);
    command void encode_cmd_setup(uint8_t *buffer, aci_cmd_params_setup_t *p_aci_cmd_params_setup, uint8_t setup_data_size);
    command void encode_cmd_dtm_cmd(uint8_t *buffer, aci_cmd_params_dtm_cmd_t *p_aci_cmd_params_dtm_cmd);
    command void encode_cmd_send_data_ack(uint8_t *buffer, const uint8_t pipe_number );
    command void encode_cmd_send_data_nack(uint8_t *buffer, const uint8_t pipe_number, const uint8_t err_code );
    command void encode_cmd_bond_security_request(uint8_t *buffer);
    command void encode_cmd_broadcast(uint8_t *buffer, aci_cmd_params_broadcast_t * p_aci_cmd_params_broadcast);
    command void encode_cmd_open_adv_pipes(uint8_t *buffer, aci_cmd_params_open_adv_pipe_t * p_aci_cmd_params_open_adv_pipe);
    command void encode_cmd_set_key(uint8_t *buffer, aci_cmd_params_set_key_t *p_aci_cmd_params_set_key);
    command bool encode_cmd(uint8_t *buffer, aci_cmd_t *p_aci_cmd);
    command void decode_evt_command_response(uint8_t *buffer_in, aci_evt_params_cmd_rsp_t *p_evt_params_cmd_rsp);
    command void decode_evt_device_started(uint8_t *buffer_in, aci_evt_params_device_started_t *p_evt_params_device_started);
    command void decode_evt_pipe_status(uint8_t *buffer_in, aci_evt_params_pipe_status_t *p_aci_evt_params_pipe_status);
    command void decode_evt_disconnected(uint8_t *buffer_in, aci_evt_params_disconnected_t *p_aci_evt_params_disconnected);
    command void decode_evt_bond_status(uint8_t *buffer_in, aci_evt_params_bond_status_t *p_aci_evt_params_bond_status);
    command uint8_t decode_evt_data_received(uint8_t *buffer_in, aci_evt_params_data_received_t *p_evt_params_data_received);
    command void decode_evt_data_ack(uint8_t *buffer_in, aci_evt_params_data_ack_t *p_evt_params_data_ack);
    command uint8_t decode_evt_hw_error(uint8_t *buffer_in, aci_evt_params_hw_error_t *p_aci_evt_params_hw_error);
    command void decode_evt_credit(uint8_t *buffer_in, aci_evt_params_data_credit_t *p_evt_params_data_credit);
    command void decode_evt_connected(uint8_t *buffer_in, aci_evt_params_connected_t *p_aci_evt_params_connected);
    command void decode_evt_timing(uint8_t *buffer_in, aci_evt_params_timing_t *p_evt_params_timing);
    command void decode_evt_pipe_error(uint8_t *buffer_in, aci_evt_params_pipe_error_t *p_evt_params_pipe_error);
    command void decode_evt_key_request(uint8_t *buffer_in, aci_evt_params_key_request_t *p_evt_params_key_request);
    command uint8_t decode_evt_echo(uint8_t *buffer_in, aci_evt_params_echo_t *aci_evt_params_echo);
    command void decode_evt_display_passkey(uint8_t *buffer_in, aci_evt_params_display_passkey_t *p_aci_evt_params_display_passkey);
    command bool decode_evt(uint8_t *buffer_in, aci_evt_t *p_aci_evt);
}