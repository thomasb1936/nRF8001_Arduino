
configuration nRF8001DriverLayer{

}
implementation
{
	componentes nRF8001aci_queueP as aci_queue,
		nRF8001lib_aciP as lib_aci,
		nRF8001aci_setupP as aci_setup,
		nRF8001acilibP as acil,
		nRF8001hal_aci_tlP as hal_aci_tl;

	MainC.SoftwareInit -> hal_aci_tl.hal_aci_tl_init;
	
	//MainC.SoftwareInit -> HplC.Init;


//*********Wiring for nRF8001hal_aci_tl**************//
	hal_aci_tl.ACTIVE -> HplC.ACTIVE;
	hal_aci_tl.RESET -> HplC.RESET;
	hal_aci_tl.REQN -> HplC.REQN;

    hal_aci_tl.aci_queue_dequeue_from_isr -> aci_queue.aci_queue_dequeue_from_isr;
    hal_aci_tl.aci_queue_is_full_from_isr -> aci_queue.aci_queue_is_full_from_isr;
    hal_aci_tl.aci_queue_is_full ->  aci_queue.aci_queue_is_full;
    hal_aci_tl.aci_queue_is_empty -> aci_queue.aci_queue_is_empty;
    hal_aci_tl.aci_queue_dequeue -> aci_queue.aci_queue_dequeue;
    hal_aci_tl.aci_queue_enqueue -> aci_queue.aci_queue_enqueue;
    hal_aci_tl.aci_queue_init -> aci_queue.aci_queue_init;
    hal_aci_tl.aci_queue_peek -> aci_queue.aci_queue_peek;


	//TODO missing busywait wiring
	//TODO missing interrupt wiring 
	hal_aci_tl.SpiResource -> HplC.SpiResource;
	hal_aci_tl.FastSpiByte -> HplC;

//*********Wiring for nRF8001lib_aci*****************//

	lib_aci = aci_queue;

    lib_aci = hal_aci_tl;

    lib_aci.acil_encode_cmd_set_app_latency -> acil.acil_encode_cmd_set_app_latency;
    lib_aci.acil_encode_cmd_set_test_mode -> acil.acil_encode_cmd_set_test_mode;
    lib_aci.acil_encode_cmd_sleep -> acil.acil_encode_cmd_sleep;
    lib_aci.acil_encode_baseband_reset -> acil.acil_encode_baseband_reset;
    lib_aci.acil_encode_direct_connect -> acil.acil_encode_direct_connect;
    lib_aci.acil_encode_cmd_set_local_data -> acil.acil_encode_cmd_set_local_data;
    lib_aci.acil_encode_cmd_connect -> acil.acil_encode_cmd_connect;
    lib_aci.acil_encode_cmd_disconnect -> acil.acil_encode_cmd_disconnect;
    lib_aci.acil_encode_cmd_bond -> acil.acil_encode_cmd_bond;
    lib_aci.acil_encode_cmd_wakeup -> acil.acil_encode_cmd_wakeup;
    lib_aci.acil_encode_cmd_get_address -> acil.acil_encode_cmd_get_address;
    lib_aci.acil_encode_cmd_temparature -> acil.acil_encode_cmd_temparature;
    lib_aci.acil_encode_cmd_send_data -> acil.acil_encode_cmd_send_data;
    lib_aci.acil_encode_cmd_request_data -> acil.acil_encode_cmd_request_data;
    lib_aci.acil_encode_cmd_change_timing_req -> acil.acil_encode_cmd_change_timing_req;
    lib_aci.acil_encode_cmd_change_timing_req_GAP_PPCP -> acil.acil_encode_cmd_change_timing_req_GAP_PPCP;
    lib_aci.acil_encode_cmd_open_remote_pipe -> acil.acil_encode_cmd_open_remote_pipe;
    lib_aci.acil_encode_cmd_close_remote_pipe -> acil.acil_encode_cmd_close_remote_pipe;
    lib_aci.acil_encode_cmd_set_key -> acil.acil_encode_cmd_set_key;
    lib_aci.acil_encode_cmd_echo_msg -> acil.acil_encode_cmd_echo_msg;
    lib_aci.acil_encode_cmd_bond_security_request -> acil.acil_encode_cmd_bond_security_request;
    lib_aci.acil_encode_cmd_send_data_ack -> acil.acil_encode_cmd_send_data_ack;
    lib_aci.acil_encode_cmd_send_data_nack -> acil.acil_encode_cmd_send_data_nack;
    lib_aci.acil_encode_cmd_broadcast -> acil.acil_encode_cmd_broadcast;
    lib_aci.acil_encode_cmd_open_adv_pipes -> acil.acil_encode_cmd_open_adv_pipes;
    lib_aci.acil_encode_cmd_read_dynamic_data -> acil.acil_encode_cmd_read_dynamic_data;
    lib_aci.acil_encode_cmd_write_dynamic_data -> acil.acil_encode_cmd_write_dynamic_data;
    lib_aci.acil_encode_cmd_dtm_cmd -> acil.acil_encode_cmd_dtm_cmd;

	
	}
