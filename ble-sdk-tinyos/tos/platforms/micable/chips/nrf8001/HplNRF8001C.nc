configuration HplNRF8001PinsC {
  provides {
  	interface Resource as SpiResource;
  	interface FastSpiByte;

    interface GeneralIO as ACTIVE;
    interface GeneralIO as RESET;
    interface GeneralIO as REQN;

    interface Init; //as of 5/20 I have no idea what this does

    interface GpioInterrupt as InterruptRDYN;
  }
}

implementation {

	components Atm128SpiC, MotePlatformC, HplNRF8001SpiP, HplAtm128GeneralIOC as IO;

	Init = Atm128SpiC;

	SpiResource = HplNRF8001SpiP.Resource; 
	HplNRF8001SpiP.SubResource -> Atm128SpiC.Resource[ unique("Atm128SpiC.Resource") ];
	//HplCC2420XSpiP.SS -> IO.PortB0; //No SS for nrf8001
	FastSpiByte = Atm128SpiC;
  
	ACTIVE = IO.PortF2;
	RESET  = IO.PortF3;
	REQN   = IO.PortE5;

	components new Atm128GpioInterruptC() as InterruptRDYNC;
	components HplAtm128InterruptC as Interrupts;
	InterruptRDYN = InterruptRDYNC;
	InterruptRDYNC.Atm128Interrupt -> Interrupts.Int6;

}