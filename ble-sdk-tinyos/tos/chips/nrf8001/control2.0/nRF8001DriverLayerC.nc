
configuration nRF8001DriverLayer{
provides{
	interface nrf8001;
}

}
implementation
{
	componentes nRF8001aci_queueP as aci_queue,
		nRF8001lib_aciP as lib_aci,
		nRF8001aci_setupP as aci_setup,
		nRF8001acilibP as acil,
		nRF8001hal_aci_tlP as hal_aci_tl,
		//Missing hpl component;

	//MainC.SoftwareInit -> hal_aci_tl.hal_aci_tl_init; //using high level init
	MainC.SoftwareInit -> HplC.Init;  //may not need this


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

    MainC.SoftwareInit -> lib_aci.lib_aci_init;

//**********Wiring for nRF8001aci_setup*************//
	aci_setup = hal_aci_tl;
	aci_setup = lib_aci;
	
	}
