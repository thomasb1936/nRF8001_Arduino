// $Id: BaseStationC.nc,v 1.7 2010-06-29 22:07:13 scipio Exp $


configuration BaseStationC {
}

implementation {
  components MainC;
  components BaseStationP;
  components LedsC;
  components SerialActiveMessageC as Serial;
  
  MainC.Boot <- BaseStationP;

  BaseStationP.SerialControl -> Serial;
  BaseStationP.UartSend -> Serial;
  BaseStationP.UartReceive -> Serial.Receive;
  BaseStationP.UartPacket -> Serial;
  BaseStationP.UartAMPacket -> Serial;
  BaseStationP.Leds -> LedsC;
}
