
configuration nRF8001DriverLayerC{
	provides interface nRF8001hal_aci_tl as hal_aci_tl;
	provides interface nRF8001lib_aci as lib_aci;
	provides interface nRF8001acilib as acil;

}
implementation
{
	components nRF8001aci_queueP as aciqueue,
		nRF8001lib_aciP as lib,
		//nRF8001aci_setupP as aci_setup,
		nRF8001acilibP as acilib,
		nRF8001hal_aci_tlP as hal,
		HplNRF8001C as HplC;



	//MainC.SoftwareInit -> hal_aci_tl.hal_aci_tl_init; //using high level init
	MainC.SoftwareInit -> HplC.Init;  //may not need this


//Bring these to the top level for now so I can use them directly
	hal_aci_tl=hal.hal_aci_tl;
	lib_aci=lib.lib_aci;
	acil=acilib.acil;

//*********Wiring for nRF8001hal_aci_tl**************//
	
	hal.aci_queue -> aciqueue.aci_queue;
	hal.ACTIVE -> HplC.ACTIVE;
	hal.RESET -> HplC.RESET;
	hal.REQN -> HplC.REQN;
	hal.RDYN -> HplC.RDYN;


	//TODO missing busywait wiring
	//TODO missing interrupt wiring 
//	hal_aci_tl.SpiResource -> HplC.SpiResource;
//	hal_aci_tl.FastSpiByte -> HplC;

//*********Wiring for nRF8001lib_aci*****************//

     lib.aci_queue->aciqueue.aci_queue;
     lib.hal_aci_tl -> hal.hal_aci_tl;
	 lib.acil -> acilib.acil;




//    MainC.SoftwareInit -> lib_aci.init;

//**********Wiring for nRF8001aci_setup*************//
//	aci_setup = hal_aci_tl;
//	aci_setup = lib_aci;
	
	}
