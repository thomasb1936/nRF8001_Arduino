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
        m_aci_reqn_enable();
      }

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
      call RESET.set();
      call BusyWait.wait(50);
      call RESET.clr();
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

    return FALSE;
  }

  command bool hal_aci_tl.event_get(hal_aci_data_t *p_aci_data)
  {
    bool was_full;

    if (!a_pins_local_ptr->interface_is_interrupt && !(call aci_queue.is_full(&aci_rx_q)))
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

    call ACTIVE.makeOutput();
    call REQN.makeOutput();
    call RESET.makeOutput();

    call InterruptRDYN.disable(); //why would we disable the interrupt at start up?

    call aci_queue.init(&aci_tx_q);
    call aci_queue.init(&aci_rx_q);

    call hal_aci_tl.pin_reset();

    call BusyWait.wait(50);
    call InterruptRDYN.enableRisingEdge();

  }

  command bool hal_aci_tl.send(hal_aci_data_t *p_aci_cmd)
  {
    const uint8_t length = p_aci_cmd->buffer[0];
    bool ret_val = FALSE;

    if (length > HAL_ACI_MAX_LENGTH)
    {
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

     // if (aci_debug_print)
      //{
       // Serial.print("C"); //ACI Command
        //m_aci_data_print(p_aci_cmd);
      //}
    }

    return ret_val;
  }

  inline static uint8_t spi_readwrite(const uint8_t aci_byte)
  {
    uint8_t value;
    call FastSpiByte.splitWrite(aci_byte);
    value = call FastSpiByte.splitRead(); 

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
