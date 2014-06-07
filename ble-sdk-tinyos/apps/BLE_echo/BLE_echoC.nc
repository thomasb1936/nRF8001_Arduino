// $Id: BlinkC.nc,v 1.6 2010-06-29 22:07:16 scipio Exp $

/*									tab:4
 * Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/**
 * Implementation for Blink application.  Toggle the red LED when a
 * Timer fires.
 **/

#include "Timer.h"
#include <lib_aci.h>
#include <aci_setup.h>
#include "uart_over_ble.h"

/**
Put the nRF8001 setup in the RAM of the nRF8001.
*/
#include "services.h"
/**
Include the services_lock.h to put the setup in the OTP memory of the nRF8001.
This would mean that the setup cannot be changed once put in.
However this removes the need to do the setup of the nRF8001 on every reset.
*/

module BLE_echoC @safe()
{
  uses interface Timer<TMilli> as Timer0;
  uses interface nRF8001lib_aci as lib_aci;
  uses interface nRF8001hal_aci_tl as hal_aci_tl;
  uses interface Leds;
  uses interface Boot;
}

#include "printf.h"
implementation
{

  #ifdef SERVICES_PIPE_TYPE_MAPPING_CONTENT
      static services_pipe_type_mapping_t
          services_pipe_type_mapping[NUMBER_OF_PIPES] = SERVICES_PIPE_TYPE_MAPPING_CONTENT;
  #else
      #define NUMBER_OF_PIPES 0
      static services_pipe_type_mapping_t * services_pipe_type_mapping = NULL;
  #endif

  hal_aci_data_t setup[NB_SETUP_MESSAGES] = SETUP_MESSAGES_CONTENT;

  

    /*
  Temporary buffers for sending ACI commands
  */
  static hal_aci_evt_t  aci_data;
  hal_aci_data_t  msg_to_send;
  //static hal_aci_data_t aci_cmd;

  /*
  Timing change state variable
  */
  static bool timing_change_done          = FALSE;

  /*
  Used to test the UART TX characteristic notification
  */
  static uart_over_ble_t uart_over_ble;
  static uint8_t         uart_buffer[20];
  static uint8_t         uart_buffer_len = 0;
  static uint8_t         dummychar = 0;

  bool stringComplete = FALSE;  // whether the string is complete
  uint8_t stringIndex = 0;      //Initialize the index to store incoming chars

  void aci_loop(void);
  void uart_over_ble_init(void);
  bool uart_tx(uint8_t *buffer, uint8_t buffer_len);
  bool uart_process_control_point_rx(uint8_t *byte, uint8_t length);
    //uint8_t do_aci_setup(aci_state_t *aci_stat);
  
static struct aci_state_t aci_state;
  event void Boot.booted()
  {
    
    call Timer0.startPeriodic(1000);

    printf("begin Boot Code\n");
    

    if (NULL != services_pipe_type_mapping)
    {
      aci_state.aci_setup_info.services_pipe_type_mapping = &services_pipe_type_mapping[0];
    }
    else
    {
      aci_state.aci_setup_info.services_pipe_type_mapping = NULL;
    }
    aci_state.aci_setup_info.number_of_pipes    = NUMBER_OF_PIPES;

   // for(i=0; i<4;i++)
    //{
   // 	aci_state.aci_setup_info.setup_msgs[i] = setup[i];
    //}
    aci_state.aci_setup_info.setup_msgs = setup;
    /*atomic{
    for(i=0;i<1;i++)
    {
      for(j=0; j<2;j++)
      {
        aci_state.aci_setup_info.setup_msgs[i].buffer[j]= setup[i].buffer[j];
      }
      if(i==0) call Leds.led2Toggle();
      //printfflush();
    }
  }*/
    //aci_state.aci_setup_info.setup_msgs[0].buffer[0]= setup_msgs[0].buffer[0];
    aci_state.aci_setup_info.num_setup_msgs     = NB_SETUP_MESSAGES;

    //We reset the nRF8001 here by toggling the RESET line connected to the nRF8001
    //If the RESET line is not available we call the ACI Radio Reset to soft reset the nRF8001
    //then we initialize the data structures required to setup the nRF8001
    //The second parameter is for turning debug printing on for the ACI Commands and Events so they be printed on the Serial
    //printf("address: %u\n", (aci_state.aci_setup_info.setup_msgs[0]));
   // printf("address %u\n", setup[0]);
    //aci_state.aci_setup_info.setup_msgs[0].buffer[0]=setup_msgs[0].buffer[0];
    //printf("buffer[0]: %u\n", aci_state.aci_setup_info.setup_msgs[19].buffer[0]);
    //printf("buffer[0]: %u\n", setup[19].buffer[0]);
    //printf("i %u\n", i);
    call lib_aci.init(&aci_state, FALSE); 
    
    printf("End Boot code\n");
    printfflush();
  }

  event void Timer0.fired()
  {
    //uint8_t msg_size = 1;
    //uint8_t msg = 0x5;
    //uint8_t *p_msg_data;
    //p_msg_data = &msg;



//call lib_aci.echo_msg(msg_size, p_msg_data);
    //dbg("BlinkC", "Timer 0 fired @ %s.\n", sim_time_string());
  

    //printf("\ntimer 0 fired\n");
    //printfflush();
    aci_loop();
    //if (!(call lib_aci.send_data(PIPE_UART_OVER_BTLE_UART_TX_TX, uart_buffer, uart_buffer_len)))
    //{
     // printf("Serial input dropped\n");
    //}

    // clear the uart_buffer:
    for (stringIndex = 0; stringIndex < 20; stringIndex++)
    {
      uart_buffer[stringIndex] = ' ';
    }

    // reset the flag and the index in order to receive more data
    stringIndex    = 0;
    stringComplete = FALSE;
  }

void uart_over_ble_init(void)
{
  uart_over_ble.uart_rts_local = TRUE;
}

bool uart_tx(uint8_t *buffer, uint8_t buffer_len)
{
  bool status = FALSE;
  printf("sending 2\n");
  printfflush();

  if ((call lib_aci.is_pipe_available(&aci_state, PIPE_UART_OVER_BTLE_UART_TX_TX)) &&
      (aci_state.data_credit_available >= 1))
  {
  	  printf("sending 3\n");
 	 printfflush();
    status = (call lib_aci.send_data(PIPE_UART_OVER_BTLE_UART_TX_TX, buffer, buffer_len));
    if (status)
    {
    	  	  printf("sending 4\n");
 	 printfflush();
      aci_state.data_credit_available--;
    }
  }

  return status;
}

bool uart_process_control_point_rx(uint8_t *byte, uint8_t length)
{
  bool status = FALSE;
  aci_ll_conn_params_t *conn_params;

  if (call lib_aci.is_pipe_available(&aci_state, PIPE_UART_OVER_BTLE_UART_CONTROL_POINT_TX) )
  {
    //Serial.println(*byte, HEX);
    switch(*byte)
    {
      /*
      Queues a ACI Disconnect to the nRF8001 when this packet is received.
      May cause some of the UART packets being sent to be dropped
      */
      case UART_OVER_BLE_DISCONNECT:
        /*
        Parameters:
        None
        */
        call lib_aci.disconnect(&aci_state, ACI_REASON_TERMINATE);
        status = TRUE;
        break;


      /*
      Queues an ACI Change Timing to the nRF8001
      */
      case UART_OVER_BLE_LINK_TIMING_REQ:
        /*
        Parameters:
        Connection interval min: 2 bytes
        Connection interval max: 2 bytes
        Slave latency:           2 bytes
        Timeout:                 2 bytes
        Same format as Peripheral Preferred Connection Parameters (See nRFgo studio -> nRF8001 Configuration -> GAP Settings
        Refer to the ACI Change Timing Request in the nRF8001 Product Specifications
        */
        conn_params = (aci_ll_conn_params_t *)(byte+1);
        call lib_aci.change_timing( conn_params->min_conn_interval,
                                conn_params->max_conn_interval,
                                conn_params->slave_latency,
                                conn_params->timeout_mult);
        status = TRUE;
        break;

      /*
      Clears the RTS of the UART over BLE
      */
      case UART_OVER_BLE_TRANSMIT_STOP:
        /*
        Parameters:
        None
        */
        uart_over_ble.uart_rts_local = FALSE;
        status = TRUE;
        break;


      /*
      Set the RTS of the UART over BLE
      */
      case UART_OVER_BLE_TRANSMIT_OK:
        /*
        Parameters:
        None
        */
        uart_over_ble.uart_rts_local = TRUE;
        status = TRUE;
        break;
    }
  }

  return status;
}

void aci_loop()
{
  static bool setup_required = FALSE;
  int i;
  char hello[18]="Hello World, works";
  uint8_t counter;
  //printf("enter aci loop\n");
  //printfflush();

  // We enter the if statement only when there is a ACI event available to be processed
  if (call lib_aci.event_get(&aci_state, &aci_data))
  {


    aci_evt_t * aci_evt;
    aci_evt = &aci_data.evt;
    

    switch(aci_evt->evt_opcode)
    {
      /**
      As soon as you reset the nRF8001 you will get an ACI Device Started Event
      */
      case ACI_EVT_DEVICE_STARTED:
      {
        aci_state.data_credit_total = aci_evt->params.device_started.credit_available;
        switch(aci_evt->params.device_started.device_mode)
        {
          case ACI_DEVICE_SETUP:
            /**
            When the device is in the setup mode
            */
            printf("Evt Device Started: Setup\n");
            //printfflush();
            setup_required = TRUE;
            break;

          case ACI_DEVICE_STANDBY:
            printf("Evt Device Started: Standby\n");
            //Looking for an iPhone by sending radio advertisements
            //When an iPhone connects to us we will get an ACI_EVT_CONNECTED event from the nRF8001
            if (aci_evt->params.device_started.hw_error)
            {
              //delay(20); //Handle the HW error event correctly.
            }
            else
            {
              call lib_aci.connect(0/* in seconds : 0 means forever */, 0x0050 /* advertising interval 50ms*/);
              printf("Advertising started : Tap Connect on the nRF UART app\n");
              printfflush();
            }

            break;
        }
      }
      break; //ACI Device Started Event

      case ACI_EVT_CMD_RSP:

        //If an ACI command response event comes with an error -> stop
        if (ACI_STATUS_SUCCESS != aci_evt->params.cmd_rsp.cmd_status)
        {
          //ACI ReadDynamicData and ACI WriteDynamicData will have status codes of
          //TRANSACTION_CONTINUE and TRANSACTION_COMPLETE
          //all other ACI commands will have status code of ACI_STATUS_SCUCCESS for a successful command
          printf("ACI Command: %u\n",aci_evt->params.cmd_rsp.cmd_opcode);
          printf("Evt Cmd respone: Status: %u\n",aci_evt->params.cmd_rsp.cmd_status);
          //printfflush();

        }

        if (ACI_CMD_GET_DEVICE_VERSION == aci_evt->params.cmd_rsp.cmd_opcode)
        {

          //Store the version and configuration information of the nRF8001 in the Hardware Revision String Characteristic
          call lib_aci.set_local_data(&aci_state, PIPE_DEVICE_INFORMATION_HARDWARE_REVISION_STRING_SET,
            (uint8_t *)&(aci_evt->params.cmd_rsp.params.get_device_version), sizeof(aci_evt_cmd_rsp_params_get_device_version_t));
        }
        break;

      case ACI_EVT_CONNECTED:

        printf("Evt Connected\n");
        printfflush();

        uart_over_ble_init();
        timing_change_done              = FALSE;
        aci_state.data_credit_available = aci_state.data_credit_total;

        /*
        Get the device version of the nRF8001 and store it in the Hardware Revision String
        */

        call lib_aci.device_version();
        break;

      case ACI_EVT_PIPE_STATUS:

        printf("Evt Pipe Status\n");
        printfflush();
        if (call lib_aci.is_pipe_available(&aci_state, PIPE_UART_OVER_BTLE_UART_TX_TX) && (FALSE == timing_change_done))
        {
          call lib_aci.change_timing_GAP_PPCP(); // change the timing on the link as specified in the nRFgo studio -> nRF8001 conf. -> GAP.
                                            // Used to increase or decrease bandwidth
          timing_change_done = TRUE;

        
          uart_tx((uint8_t *)&hello[0], 18);
          printf("Sending :\n");
          printfflush();
          //Serial.println(hello);
        }
        break;

      case ACI_EVT_TIMING:
        printf("Evt link connection interval changed\n");
        call lib_aci.set_local_data(&aci_state,
                                PIPE_UART_OVER_BTLE_UART_LINK_TIMING_CURRENT_SET,
                                (uint8_t *)&(aci_evt->params.timing.conn_rf_interval), /* Byte aligned */
                                PIPE_UART_OVER_BTLE_UART_LINK_TIMING_CURRENT_SET_MAX_SIZE);
        break;

      case ACI_EVT_DISCONNECTED:

        printf("Evt Disconnected/Advertising timed out\n");
        call lib_aci.connect(0/* in seconds  : 0 means forever */, 0x0050 /* advertising interval 50ms*/);
        printf("Advertising started. Tap Connect on the nRF UART app\n");
        break;

      case ACI_EVT_DATA_RECEIVED:

        printf("Pipe Number: \n");
        //Serial.println(aci_evt->params.data_received.rx_data.pipe_number, DEC);

        if (PIPE_UART_OVER_BTLE_UART_RX_RX == aci_evt->params.data_received.rx_data.pipe_number)
          {

            printf(" Data(Hex) : \n");
            printfflush();
            for(i=0; i<aci_evt->len - 2; i++)
            {
              printf("%u\n", (char)aci_evt->params.data_received.rx_data.aci_data[i]);
              uart_buffer[i] = aci_evt->params.data_received.rx_data.aci_data[i];
              printf(" \n");
              printfflush();
            }
            uart_buffer_len = aci_evt->len - 2;
            printf("\n");
            if (call lib_aci.is_pipe_available(&aci_state, PIPE_UART_OVER_BTLE_UART_TX_TX))
            {
              /*Do this to test the loopback otherwise comment it out*/
              /*
              if (!uart_tx(&uart_buffer[0], aci_evt->len - 2))
              {
                Serial.println(F("UART loopback failed\n");
              }
              else
              {
                Serial.println(F("UART loopback OK\n");
              }
              */
            }
        }
        if (PIPE_UART_OVER_BTLE_UART_CONTROL_POINT_RX == aci_evt->params.data_received.rx_data.pipe_number)
        {
          uart_process_control_point_rx(&aci_evt->params.data_received.rx_data.aci_data[0], aci_evt->len - 2); //Subtract for Opcode and Pipe number
        }

        break;

      case ACI_EVT_DATA_CREDIT:
        aci_state.data_credit_available = aci_state.data_credit_available + aci_evt->params.data_credit.credit;
        break;

      case ACI_EVT_PIPE_ERROR:
        //See the appendix in the nRF8001 Product Specication for details on the error codes
        printf("ACI Evt Pipe Error: Pipe #:\n");
        //Serial.print(aci_evt->params.pipe_error.pipe_number, DEC);
        printf("  Pipe Error Code: 0x\n");
        //Serial.println(aci_evt->params.pipe_error.error_code, HEX);

        //Increment the credit available as the data packet was not sent.
        //The pipe error also represents the Attribute protocol Error Response sent from the peer and that should not be counted
        //for the credit.
        if (ACI_STATUS_ERROR_PEER_ATT_ERROR != aci_evt->params.pipe_error.error_code)
        {
          aci_state.data_credit_available++;
        }
        break;

      case ACI_EVT_HW_ERROR:
        printf("HW error: \n");
        //Serial.println(aci_evt->params.hw_error.line_num, DEC);

        for(counter = 0; counter <= (aci_evt->len - 3); counter++)
        {
          //Serial.write(aci_evt->params.hw_error.file_name[counter]); //uint8_t file_name[20];
        }
        //Serial.println();
        call lib_aci.connect(0/* in seconds, 0 means forever */, 0x0050 /* advertising interval 50ms*/);
        printf("Advertising started. Tap Connect on the nRF UART app\n");
        break;

    }
  }
  else
  {
    //printf("No ACI Events available\n");
    //printfflush();
    // No event in the ACI Event queue and if there is no event in the ACI command queue the arduino can go to sleep
    // Arduino can go to sleep now
    // Wakeup from sleep from the RDYN line
  }

  /* setup_required is set to true when the device starts up and enters setup mode.
   * It indicates that do_aci_setup() should be called. The flag should be cleared if
   * do_aci_setup() returns ACI_STATUS_TRANSACTION_COMPLETE.
   */
   
  if(setup_required)
  {
    if (SETUP_SUCCESS == (call lib_aci.do_aci_setup(&aci_state)))
    {
      printf("ACI Setup success\n");
      printfflush();
      setup_required = FALSE;
    }
  }
}

}

