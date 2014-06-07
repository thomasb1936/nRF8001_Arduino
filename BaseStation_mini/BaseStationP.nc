// $Id: BaseStationP.nc,v 1.12 2010-06-29 22:07:14 scipio Exp $

#include "AM.h"
#include "Serial.h"

module BaseStationP @safe()
{
  uses
  {
    interface Boot;
    interface SplitControl  as SerialControl;
    interface AMSend        as UartSend[am_id_t id];
    interface Receive       as UartReceive[am_id_t id];
    interface Packet        as UartPacket;
    interface AMPacket      as UartAMPacket;
    interface Leds;
  }
}

implementation
{
  enum
  {
    UART_QUEUE_LEN = 12
  };

  message_t  uartQueueBufs[UART_QUEUE_LEN];
  message_t  * ONE_NOK uartQueue[UART_QUEUE_LEN];
  uint8_t    uartIn, uartOut;
  bool       uartBusy, uartFull;

  task void uartSendTask();

  void dropBlink()
  {
    call Leds.led2Toggle();
  }

  void failBlink()
  {
    call Leds.led2Toggle();
  }

  event void Boot.booted()
  {
    uint8_t i;

    for (i = 0; i < UART_QUEUE_LEN; i++) uartQueue[i] = &uartQueueBufs[i];

    uartIn = uartOut = 0;
    uartBusy = FALSE;
    uartFull = TRUE;

    if (call SerialControl.start() == EALREADY) uartFull = FALSE;
  }
  
  event void SerialControl.startDone(error_t error)
  {
    if (error == SUCCESS) uartFull = FALSE;
  }

  event void SerialControl.stopDone(error_t error){}

  message_t* ONE receive(message_t* ONE msg, void* payload, uint8_t len);
  
  message_t* receive(message_t *msg, void *payload, uint8_t len)
  {
    message_t *ret = msg;

    atomic if (!uartFull)
    {
        ret = uartQueue[uartIn];
        uartQueue[uartIn] = msg;
        uartIn = (uartIn + 1) % UART_QUEUE_LEN;

      if (uartIn == uartOut) uartFull = TRUE;

      if (!uartBusy)
      {
	      post uartSendTask();
	      uartBusy = TRUE;
	    }

    }
    else
    {
      dropBlink();
    }
    
    return ret;
  }

  uint8_t tmpLen;
  
  task void uartSendTask()
  {
    uint8_t len;
    am_id_t id;
    am_addr_t addr, src;
    message_t* msg;
    am_group_t grp;

    atomic if (uartIn == uartOut && !uartFull)
    {
      uartBusy = FALSE;
      return;
    }

    msg = uartQueue[uartOut];
    call UartPacket.clear(msg);
    call UartAMPacket.setSource(msg, src);
    call UartAMPacket.setGroup(msg, grp);

    if (call UartSend.send[id](addr, uartQueue[uartOut], len) == SUCCESS)
    {
      call Leds.led1Toggle();
    }
    else
    {
      failBlink();
      post uartSendTask();
    }
  }

  event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
    if (error != SUCCESS){
      failBlink();
    }
    else
    atomic
    if (msg == uartQueue[uartOut])
    {
      if (++uartOut >= UART_QUEUE_LEN)
        uartOut = 0;
      if (uartFull)
        uartFull = FALSE;
    }
    post uartSendTask();
  }

  event message_t *UartReceive.receive[am_id_t id](
    message_t *msg,
    void *payload,
		uint8_t len)
  {
    
    message_t *ret = msg;
    bool reflectToken = FALSE;

    if (reflectToken)
    {
      //call UartTokenReceive.ReflectToken(Token);
    }
    
    return ret;
  }

  task void radioSendTask() {
    uint8_t len;
    am_id_t id;
    am_addr_t addr,source;
    message_t* msg;
    
    len = call UartPacket.payloadLength(msg);
    addr = call UartAMPacket.destination(msg);
    source = call UartAMPacket.source(msg);
    id = call UartAMPacket.type(msg);
    call Leds.led0Toggle();
  }

  
}
