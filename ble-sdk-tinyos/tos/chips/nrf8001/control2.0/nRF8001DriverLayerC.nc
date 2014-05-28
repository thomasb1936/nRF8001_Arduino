
configuration nRF8001DriverLayerC{
	provides{
		//interface nrf8001;
		interface lib_aci;}
}
implementation
{
	components nRF8001aci_queueP as aci_queue,
		nRF8001lib_aciP as lib_aci,
		nRF8001aci_setupP as aci_setup,
		nRF8001acilibP as acil,
		nRF8001hal_aci_tlP as hal_aci_tl,
		HplNRF8001C as HplC;

	//MainC.SoftwareInit -> hal_aci_tl.hal_aci_tl_init; //using high level init
	MainC.SoftwareInit -> HplC.Init;  //may not need this

	//nrf8001=lib_aci;
	lib_aci=lib_aci.lib_aci;

//*********Wiring for nRF8001hal_aci_tl**************//
	hal_aci_tl.ACTIVE -> HplC.ACTIVE;
	hal_aci_tl.RESET -> HplC.RESET;
	hal_aci_tl.REQN -> HplC.REQN;

    hal_aci_tl = aci_queue;

	//TODO missing busywait wiring
	//TODO missing interrupt wiring 
	hal_aci_tl.SpiResource -> HplC.SpiResource;
	hal_aci_tl.FastSpiByte -> HplC;

//*********Wiring for nRF8001lib_aci*****************//

	lib_aci = aci_queue;
    lib_aci = hal_aci_tl;
    lib_aci = acil;

    lib_aci.hal_aci_tl_send->hal_aci_tl.hal_aci_tl_send;
    lib_aci.hal_aci_tl_rx_q_empty->hal_aci_tl.hal_aci_tl_rx_q_empty;

    MainC.SoftwareInit -> lib_aci.lib_aci_init;

//**********Wiring for nRF8001aci_setup*************//
	aci_setup = hal_aci_tl;
	aci_setup = lib_aci;
	
	}
