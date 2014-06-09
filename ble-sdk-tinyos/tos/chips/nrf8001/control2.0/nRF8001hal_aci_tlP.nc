/* Copyright (c) 2014, Nordic Semiconductor ASA
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/** @file
@brief Implementation of the ACI transport layer module
*/

//#include <SPI.h>
#include "hal_platform.h"
#include "hal_aci_tl.h"
#include "aci_queue.h"
#include <avr/sleep.h>
#include "printf.h"

module nRF8001hal_aci_tlP
{
  uses
  {
    interface nRF8001aci_queue as aci_queue;


    interface Resource as SpiResource;
    interface BusyWait<TMicro, uint16_t>;
    
    interface FastSpiByte;
    interface nRF8001lib_aci as lib_aci;

    interface GpioInterrupt as InterruptRDYN;

    interface GeneralIO as ACTIVE;
    interface GeneralIO as RESET;
    interface GeneralIO as REQN;
    interface GeneralIO as RDYN;

    interface GeneralIO as SCK;
    interface GeneralIO as MOSI;
    interface GeneralIO as MISO;

    interface Leds;

  }
  provides
  {
    interface nRF8001hal_aci_tl as hal_aci_tl;

    //interface spi; TODO - Fix this
  }
}
implementation
{
  static void m_aci_data_print(hal_aci_data_t *p_data);
  static void m_aci_event_check(void);
  static void m_aci_isr(void);
  static void m_aci_pins_set(aci_pins_t *a_pins_ptr);
  static inline void m_aci_reqn_disable (void);
  static inline void m_aci_reqn_enable (void);
  static void m_aci_q_flush(void);
  static bool m_aci_spi_transfer(hal_aci_data_t * data_to_send, hal_aci_data_t * received_data);

  static uint8_t spi_bitbang(uint8_t);

  static uint8_t        spi_readwrite(uint8_t aci_byte);

  static bool           aci_debug_print = FALSE;

  aci_queue_t    aci_tx_q;
  aci_queue_t    aci_rx_q;

  static aci_pins_t	 *a_pins_local_ptr;

  /*  Function not applicable to Tinyos
  void m_aci_data_print(hal_aci_data_t *p_data)
  {
    const uint8_t length = p_data->buffer[0];
    uint8_t i;
    Serial.print(length, DEC);
    Serial.print(" :");
    for (i=0; i<=length; i++)
    {
      Serial.print(p_data->buffer[i], HEX);
      Serial.print(F(", "));
    }
    Serial.println(F(""));
  }*/

  /*
    Interrupt service routine called when the RDYN line goes low. Runs the SPI transfer.
  */

    static void m_aci_pins_set(aci_pins_t *a_pins_ptr)
	{
  		a_pins_local_ptr = a_pins_ptr;
		
	}	

  static void m_aci_isr(void)
  {
    hal_aci_data_t data_to_send;
    hal_aci_data_t received_data;
    

    // Receive from queue
    if (!( call aci_queue.dequeue_from_isr(&aci_tx_q, &data_to_send)))
    {
      /* queue was empty, nothing to send */
      data_to_send.status_byte = 0;
      data_to_send.buffer[0] = 0;
    }

    // Receive and/or transmit data
    m_aci_spi_transfer(&data_to_send, &received_data);

    if (!(call aci_queue.is_full_from_isr(&aci_rx_q)) && !(call aci_queue.is_empty_from_isr(&aci_tx_q)))
    {
      m_aci_reqn_enable();
    }

    // Check if we received data
    if (received_data.buffer[0] > 0)
    {
      if (!(call aci_queue.enqueue_from_isr(&aci_rx_q, &received_data)))
      {
        /* Receive Buffer full.
           Should never happen.
           Spin in a while loop.
        */
        while(1);
      }

      // Disable ready line interrupt until we have room to store incoming messages
      if (call aci_queue.is_full_from_isr(&aci_rx_q))
      {
        //TODO - Add code to disable interrupts
      }
    }

    return;
  }

  /*
    Checks the RDYN line and runs the SPI transfer if required.
  */
  static void m_aci_event_check(void)
  {
    hal_aci_data_t data_to_send;
    hal_aci_data_t received_data;

    // No room to store incoming messages
    if (call aci_queue.is_full(&aci_rx_q))
    {

      return;
    }
        // If the ready line is disabled and we have pending messages outgoing we enable the request line
    //if (HIGH == digitalRead(a_pins_local_ptr->rdyn_pin)) 

    if(1 == (call RDYN.get()))
    {
      if (!(call aci_queue.is_empty(&aci_tx_q)))
      {
      	 call Leds.led0Toggle();
        m_aci_reqn_enable();
      }
      //call Leds.led0Toggle();

      return;
    }

    // Receive from queue
    if (!(call aci_queue.dequeue(&aci_tx_q, &data_to_send)))
    {
      /* queue was empty, nothing to send */
      data_to_send.status_byte = 0;
      data_to_send.buffer[0] = 0;
    }

    // Receive and/or transmit data
    m_aci_spi_transfer(&data_to_send, &received_data);

    /* If there are messages to transmit, and we can store the reply, we request a new transfer */
    if (!(call aci_queue.is_full(&aci_rx_q)) && !(call aci_queue.is_empty(&aci_tx_q)))
    {
      m_aci_reqn_enable();
    }


    // Check if we received data
    if (received_data.buffer[0] > 0)
    {
    	//call Leds.led2Toggle();
      if (!(call aci_queue.enqueue(&aci_rx_q, &received_data)))
      {

        /* Receive Buffer full.
           Should never happen.
           Spin in a while loop.
        */
        while(1);
      }
    }

    return;
  }

  /** @brief Point the low level library at the ACI pins specified
   *  @details
   *  The ACI pins are specified in the application and a pointer is made available for
   *  the low level library to use
   */


  static inline void m_aci_reqn_disable (void)
  {
    //digitalWrite(a_pins_local_ptr->reqn_pin, 1);
    call REQN.set();  //check this logic to make sure reqn in active high
  }

  static inline void m_aci_reqn_enable (void)
  {
    //digitalWrite(a_pins_local_ptr->reqn_pin, 0);
    call REQN.clr(); //check this logic to make sure reqn in active high
  }
  

  static void m_aci_q_flush(void)
  {
    //noInterrupts(); TODO - figure out how to disable interupts
    /* re-initialize aci cmd queue and aci event queue to flush them*/
    call aci_queue.init(&aci_tx_q);
    call aci_queue.init(&aci_rx_q);
    //interrupts();
  }

  static bool m_aci_spi_transfer(hal_aci_data_t * data_to_send, hal_aci_data_t * received_data)
  {
    uint8_t byte_cnt;
    uint8_t byte_sent_cnt;
    uint8_t max_bytes;

    //printf("SPI\n");

    m_aci_reqn_enable();
    
    // Send length, receive header
    byte_sent_cnt = 0;

    received_data->status_byte = spi_readwrite(data_to_send->buffer[byte_sent_cnt++]);

    // Send first byte, receive length from slave
    received_data->buffer[0] = spi_readwrite(data_to_send->buffer[byte_sent_cnt++]);
    if (0 == data_to_send->buffer[0])
    {
      max_bytes = received_data->buffer[0];
    }
    else
    {
      // Set the maximum to the biggest size. One command byte is already sent
      max_bytes = (received_data->buffer[0] > (data_to_send->buffer[0] - 1))
                                            ? received_data->buffer[0]
                                            : (data_to_send->buffer[0] - 1);
    }

    if (max_bytes > HAL_ACI_MAX_LENGTH)
    {
      max_bytes = HAL_ACI_MAX_LENGTH;
    }

    // Transmit/receive the rest of the packet
    for (byte_cnt = 0; byte_cnt < max_bytes; byte_cnt++)
    {
      received_data->buffer[byte_cnt+1] =  spi_readwrite(data_to_send->buffer[byte_sent_cnt++]);
    }

    // RDYN should follow the REQN line in approx 100ns
    m_aci_reqn_disable();


    return (max_bytes > 0);
  }

  command void hal_aci_tl.debug_print(bool enable)
  {
  	aci_debug_print = enable;
  }

  command void hal_aci_tl.pin_reset(void)
  {
      call RESET.clr();
      call BusyWait.wait(10);
      call RESET.set();
  }

  command bool hal_aci_tl.event_peek(hal_aci_data_t *p_aci_data)
  {
    
    if (!a_pins_local_ptr->interface_is_interrupt)
    {

      m_aci_event_check();

    }

    if (call aci_queue.peek(&aci_rx_q, p_aci_data))
    {
    	
      return TRUE;
    }
    //printf("false peekin\n");
    //printfflush();

    return FALSE;
  }

  command bool hal_aci_tl.event_get(hal_aci_data_t *p_aci_data)
  {
    bool was_full;
    //had issues with this line since interface is interrupt doesn't apply to tiny OS.
    if (!a_pins_local_ptr->interface_is_interrupt && !(call aci_queue.is_full(&aci_rx_q)))
    //if(!(call aci_queue.is_full(&aci_rx_q)))
    { 
      m_aci_event_check();
    }

    was_full = call aci_queue.is_full(&aci_rx_q);

    
    if (call aci_queue.dequeue(&aci_rx_q, p_aci_data))
    {


      if (was_full && a_pins_local_ptr->interface_is_interrupt)
  	  {
        /* Enable RDY line interrupt again */
        //attachInterrupt(a_pins_local_ptr->interrupt_number, m_aci_isr, LOW);
        //TODO - interrupts in Tiny OS
        //call InterruptRDYN.enable();
      }

      /* Attempt to pull REQN LOW since we've made room for new messages */
      if (!(call aci_queue.is_full(&aci_rx_q)) && !(call aci_queue.is_empty(&aci_tx_q)))
      {
        m_aci_reqn_enable();
      }


      return TRUE;
    }

    return FALSE;
  }

  command void hal_aci_tl.init(aci_pins_t *a_pins, bool debug)
  {
  	m_aci_pins_set(a_pins);

    call REQN.makeOutput();
    call RESET.makeOutput();
    //call SCK.makeOutput();

    call MISO.makeInput();
    call RDYN.makeInput();
    call ACTIVE.makeInput();

    call hal_aci_tl.pin_reset();

    call REQN.set();
    call SCK.clr();
    call MOSI.set();

    m_aci_reqn_enable();


    call aci_queue.init(&aci_tx_q);
    call aci_queue.init(&aci_rx_q);


	call BusyWait.wait(50);


    call InterruptRDYN.disable(); //why would we disable the interrupt at start up?

    //call InterruptRDYN.enableRisingEdge();
    return;

  }

  command void hal_aci_tl.board_init(aci_state_t *aci_stat)
  {

  	hal_aci_evt_t *aci_data = NULL;
  	hal_aci_data_t  msg_to_send;
  	aci_data = (hal_aci_evt_t *)&msg_to_send;
      
  	  while (1)
  	  {
  		/*Wait for the command response of the radio reset command.
  		as the nRF8001 will be in either SETUP or STANDBY after the ACI Reset Radio is processed
  		*/
      
  			
    		if (TRUE == (call hal_aci_tl.event_get((hal_aci_data_t *)aci_data)))
    		{
    		  aci_evt_t * aci_evt;      
    		  aci_evt = &(aci_data->evt);
    

    		  if (ACI_EVT_CMD_RSP == aci_evt->evt_opcode)
    		  {

    				if (ACI_STATUS_ERROR_DEVICE_STATE_INVALID == aci_evt->params.cmd_rsp.cmd_status) //in SETUP
    				{
    					printf("Inject a Device Started Event Setup to the ACI Event Queue\n");
    					printfflush();
    					msg_to_send.buffer[0] = 4;    //Length
    					msg_to_send.buffer[1] = 0x81; //Device Started Event
    					msg_to_send.buffer[2] = 0x02; //Setup
    					msg_to_send.buffer[3] = 0;    //Hardware Error -> None
    					msg_to_send.buffer[4] = 2;    //Data Credit Available
    					call aci_queue.enqueue(&aci_rx_q, &msg_to_send);
             			
             			call Leds.set(0x3);
              //while(1);
    				}
    				else if (ACI_STATUS_SUCCESS == aci_evt->params.cmd_rsp.cmd_status) //We are now in STANDBY
    				{
    					//Inject a Device Started Event Standby to the ACI Event Queue
    					msg_to_send.buffer[0] = 4;    //Length
    					msg_to_send.buffer[1] = 0x81; //Device Started Event
    					msg_to_send.buffer[2] = 0x03; //Standby
    					msg_to_send.buffer[3] = 0;    //Hardware Error -> None
    					msg_to_send.buffer[4] = 2;    //Data Credit Available
    					call aci_queue.enqueue(&aci_rx_q, &msg_to_send);
    				}
    				else if (ACI_STATUS_ERROR_CMD_UNKNOWN == aci_evt->params.cmd_rsp.cmd_status) //We are now in TEST
    				{
    					//Inject a Device Started Event Test to the ACI Event Queue
    					msg_to_send.buffer[0] = 4;    //Length
    					msg_to_send.buffer[1] = 0x81; //Device Started Event
    					msg_to_send.buffer[2] = 0x01; //Test
    					msg_to_send.buffer[3] = 0;    //Hardware Error -> None
    					msg_to_send.buffer[4] = 0;    //Data Credit Available
    					call aci_queue.enqueue(&aci_rx_q, &msg_to_send);
    				}
    				
    				//Break out of the while loop
    				break;
    		  }
    		  else
    		  {			
    			//Serial.println(F("Discard any other ACI Events"));
    		  }
    		}
  	}
  return;
  }

  command bool hal_aci_tl.send(hal_aci_data_t *p_aci_cmd)
  {
    const uint8_t length = p_aci_cmd->buffer[0];
    bool ret_val = FALSE;

    if (length > HAL_ACI_MAX_LENGTH)
    {
      //printf("L: %u\n",length);
      //printf("ML: %u\n", HAL_ACI_MAX_LENGTH);
      //printfflush();
      return FALSE;

    }

    ret_val = call aci_queue.enqueue(&aci_tx_q, p_aci_cmd);
    if (ret_val)
    {
      if(!(call aci_queue.is_full(&aci_rx_q)))
      {
        // Lower the REQN only when successfully enqueued
        m_aci_reqn_enable();
      }

    }

    return ret_val;
  }

  inline static uint8_t spi_readwrite(const uint8_t aci_byte)
  {
    uint8_t value;
    //call Leds.led2Toggle();
    //call FastSpiByte.write(aci_byte);
    //value = call FastSpiByte.write(aci_byte); 
     //   	call Leds.led1Toggle();
 	//       	call BusyWait.wait(100);

 	value = spi_bitbang(aci_byte);

    if(value == 0x5)
    {
    	//call Leds.led1Toggle();
    }
    return value;
  }

  inline uint8_t spi_bitbang(uint8_t aci_byte)
  {	
  	uint8_t ret_val=0;
  	uint8_t temp=0;
  	int i=0;
  	//call Leds.led1Toggle();
  	if (aci_byte==0x15)
	{
		//call Leds.set(0x);
	}
	if(aci_byte == 0x01)
	{
		//call Leds.led2Toggle();
	}
  	
  	atomic{
	  	for(i=0; i<8; i++)
	  	{
	  		if((aci_byte & 1) == 1){
	  			call MOSI.set();
	  		}
	  		else
	  		{
	  			call MOSI.clr();
	  		}
	  	
	  		call SCK.set();

	  		temp=call MISO.get();
	  		
	  		temp=temp<<i;
	  	
	  		call BusyWait.wait(2);

	  		call SCK.clr();

	  		
	  		aci_byte= aci_byte>>1;
	  		ret_val=ret_val | temp;
	  		//ret_val = ret_val>>1;

	  	}
 	 }
  	call BusyWait.wait(2);
	//if (ret_val==0x1) call Leds.led2Toggle();
  	return ret_val;

  }

  command bool hal_aci_tl.rx_q_empty (void)
  {
    return call aci_queue.is_empty(&aci_rx_q);
  }

   command bool hal_aci_tl.rx_q_full (void)
  {
    return call aci_queue.is_full(&aci_rx_q);
  }

  command bool hal_aci_tl.tx_q_empty (void)
  {
    return call aci_queue.is_empty(&aci_tx_q);
  }

  command bool hal_aci_tl.tx_q_full (void)
  {
    return call aci_queue.is_full(&aci_tx_q);
  }

  command void hal_aci_tl.q_flush (void)
  {
    m_aci_q_flush();
  }

  async event void InterruptRDYN.fired()
  {
    //Do something
  }

  event void SpiResource.granted()
  {
    //do something
  }
}
