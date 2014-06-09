

/** @file
  @brief Implementation of the ACI library.
 */

#include "hal_platform.h"
#include "aci.h"
#include "aci_cmds.h"
#include "aci_evts.h"
#include "aci_protocol_defines.h"
#include "acilib_defs.h"
#include "acilib_if.h"
#include "hal_aci_tl.h"
#include "aci_queue.h"
#include "lib_aci.h"
#include <aci_setup.h>

#include "services.h"
#include "AM.h"
#include "printf.h"







//TODO deal with this
#define LIB_ACI_DEFAULT_CREDIT_NUMBER   1

/*
Global additionally used used in aci_setup 
*/

module nRF8001lib_aciP 
{
  uses
  {
    interface nRF8001aci_queue as aci_queue;
    interface nRF8001hal_aci_tl as hal_aci_tl;
    interface nRF8001acilib as acil;
    interface Leds;
    interface AMSend as UartSend[am_id_t id];
  }
  provides
  {
    interface nRF8001lib_aci as lib_aci;
    //interface Init as aci_init;
  }
}

implementation
{
/*
  #ifdef SERVICES_PIPE_TYPE_MAPPING_CONTENT
      static services_pipe_type_mapping_t
          services_pipe_type_mapping[NUMBER_OF_PIPES] = SERVICES_PIPE_TYPE_MAPPING_CONTENT;
  #else
      #define NUMBER_OF_PIPES 0
      static services_pipe_type_mapping_t * services_pipe_type_mapping = NULL;
  #endif

  static hal_aci_data_t setup_msgs[NB_SETUP_MESSAGES] PROGMEM = SETUP_MESSAGES_CONTENT;

  

  static struct aci_state_t aci_state;
*/
  hal_aci_data_t  msg_to_send;


  static services_pipe_type_mapping_t * p_services_pipe_type_map;
  static hal_aci_data_t *               p_setup_msgs;


  static bool is_request_operation_pending;
  static bool is_indicate_operation_pending;
  static bool is_open_remote_pipe_pending;
  static bool is_close_remote_pipe_pending;

  static uint8_t request_operation_pipe = 0;
  static uint8_t indicate_operation_pipe = 0;


  // The following structure (aci_cmd_params_open_adv_pipe) will be used to store the complete command 
  // including the pipes to be opened. 
  static aci_cmd_params_open_adv_pipe_t aci_cmd_params_open_adv_pipe; 

  static bool aci_setup_fill(aci_state_t *aci_stat, uint8_t *num_cmd_offset);


  //static aci_queue_t    aci_rx_q;
  //static aci_queue_t    aci_tx_q;

  command bool lib_aci.aci_init()
  {
   /* if (NULL != services_pipe_type_mapping)
    {
      aci_state.aci_setup_info.services_pipe_type_mapping = &services_pipe_type_mapping[0];
    }
    else
    {
      aci_state.aci_setup_info.services_pipe_type_mapping = NULL;
    }
    aci_state.aci_setup_info.number_of_pipes    = NUMBER_OF_PIPES;
    aci_state.aci_setup_info.setup_msgs         = setup_msgs;
    aci_state.aci_setup_info.num_setup_msgs     = NB_SETUP_MESSAGES;

    //We reset the nRF8001 here by toggling the RESET line connected to the nRF8001
    //If the RESET line is not available we call the ACI Radio Reset to soft reset the nRF8001
    //then we initialize the data structures required to setup the nRF8001
    //The second parameter is for turning debug printing on for the ACI Commands and Events so they be printed on the Serial
    call lib_aci.init(&aci_state, FALSE);  */


    return TRUE;
  }

 /* **************************************************************************                */
/* Utility function to fill the the ACI command queue                                      */
/* aci_stat               Pointer to the ACI state                                         */
/* num_cmd_offset(in/out) Offset in the Setup message array to start from                  */
/*                        offset is updated to the new index after the queue is filled     */
/*                        or the last message us placed in the queue                       */
/* Returns                TRUE if at least one message was transferred                     */
/***************************************************************************/

event void UartSend.sendDone[am_id_t id](message_t* msg, error_t error) {
 // if (error != SUCCESS)
 //   failBlink();
  //else
  //  atomic
//if (msg == uartQueue[uartOut])
 // {
  //  if (++uartOut >= UART_QUEUE_LEN)
  //    uartOut = 0;
  //  if (uartFull)
  //    uartFull = FALSE;
  //}
  //post uartSendTask();
  }


  command bool lib_aci.is_pipe_available(aci_state_t *aci_stat, uint8_t pipe)
  {
    uint8_t byte_idx;

    byte_idx = pipe / 8;
    if (aci_stat->pipes_open_bitmap[byte_idx] & (0x01 << (pipe % 8)))
    {
      return(TRUE);
    }
    return(FALSE);
  }


  command bool lib_aci.is_pipe_closed(aci_state_t *aci_stat, uint8_t pipe)
  {
    uint8_t byte_idx;

    byte_idx = pipe / 8;
    if (aci_stat->pipes_closed_bitmap[byte_idx] & (0x01 << (pipe % 8)))
    {
      return(TRUE);
    }
    return(FALSE);
  }


  command bool lib_aci.is_discovery_finished(aci_state_t *aci_stat)
  {
    return(aci_stat->pipes_open_bitmap[0]&0x01);
  }

command uint8_t lib_aci.do_aci_setup(aci_state_t *aci_stat)
{
  uint8_t setup_offset         = 0;
  uint32_t i                   = 0x0000;
  aci_evt_t * aci_evt          = NULL;
  aci_status_code_t cmd_status = ACI_STATUS_ERROR_CRC_MISMATCH;

  
  /*
  We are using the same buffer since we are copying the contents of the buffer 
  when queuing and immediately processing the buffer when receiving
  */
  hal_aci_evt_t  *aci_data = (hal_aci_evt_t *)&msg_to_send;

  //call Leds.set(0x7);
 printf("begin ACI setup\n");
 printfflush();
  
  /* Messages in the outgoing queue must be handled before the Setup routine can run.
   * If it is non-empty we return. The user should then process the messages before calling
   * do_aci_setup() again.
   */
  if (!(call lib_aci.command_queue_empty()))
  {
    return SETUP_FAIL_COMMAND_QUEUE_NOT_EMPTY;
  }
  
  /* If there are events pending from the device that are not relevant to setup, we return FALSE
   * so that the user can handle them. At this point we don't care what the event is,
   * as any event is an error.
   */
  if (call lib_aci.event_peek(aci_data))
  {
    return SETUP_FAIL_EVENT_QUEUE_NOT_EMPTY;
    
  }
  
  /* Fill the ACI command queue with as many Setup messages as it will hold. */
  aci_setup_fill(aci_stat, &setup_offset);


  
  while (cmd_status != ACI_STATUS_TRANSACTION_COMPLETE)
  {
     
    /* This counter is used to ensure that this function does not loop forever. When the device
     * returns a valid response, we reset the counter.
     */
    if (i > 10000)
    {
      printf("ACI Setup Fail Timeout\n");
      return SETUP_FAIL_TIMEOUT;  

    }
    
    if (call lib_aci.event_peek(aci_data))
    {
     

      aci_evt = &(aci_data->evt);
      
      if (ACI_EVT_CMD_RSP != aci_evt->evt_opcode)
      {
        //Receiving something other than a Command Response Event is an error.
        return SETUP_FAIL_NOT_COMMAND_RESPONSE;
      }
      
      cmd_status = (aci_status_code_t) aci_evt->params.cmd_rsp.cmd_status;
      switch (cmd_status)
      {
        case ACI_STATUS_TRANSACTION_CONTINUE:
          //As the device is responding, reset guard counter
          i = 0;
          
          /* As the device has processed the Setup messages we put in the command queue earlier,
           * we can proceed to fill the queue with new messages
           */

          aci_setup_fill(aci_stat, &setup_offset);
          break;
        
        case ACI_STATUS_TRANSACTION_COMPLETE:
          //Break out of the while loop when this status code appears

          break;
        
        default:
          //An event with any other status code should be handled by the application
          return SETUP_FAIL_NOT_SETUP_EVENT;

      }
      
      
      /* If we haven't returned at this point, the event was either ACI_STATUS_TRANSACTION_CONTINUE
       * or ACI_STATUS_TRANSACTION_COMPLETE. We don't need the event itself, so we simply
       * remove it from the queue.
       */
       call lib_aci.event_get (aci_stat, aci_data);
    }
    i=i++;
  }
         
 
  return SETUP_SUCCESS;
}

inline static bool aci_setup_fill(aci_state_t *aci_stat, uint8_t *num_cmd_offset)
{
  bool ret_val = FALSE;
  //printf("offset: %u\n",*num_cmd_offset);
  //printf("buffer[0] %u\n", aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset].buffer[0]);
  //printfflush();
  
  //Begin quick and dirty fix
  /*
  while (*num_cmd_offset < aci_stat->aci_setup_info.num_setup_msgs)
  {
    memcpy(&msg_to_send, &(setup_msgs[*num_cmd_offset]), (setup_msgs[*num_cmd_offset].buffer[0]+2)); 
    //Put the Setup ACI message in the command queue
    printf("buffer[0] %u\n", msg_to_send.status_byte);
    if (!(call hal_aci_tl.send(&msg_to_send)))
    {

      printf("ACI Command Queue is full\n");
      printfflush();
      // *num_cmd_offset is now pointing to the index of the Setup command that did not get sent
      return ret_val;
    }
   
    ret_val = TRUE;
    
    (*num_cmd_offset)++;
  }
  */
  
  while (*num_cmd_offset < aci_stat->aci_setup_info.num_setup_msgs)
  {
    memcpy(&msg_to_send, &(aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset]), (aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset].buffer[0]+2)); 
    //Put the Setup ACI message in the command queue
    //printf("status %u\n", msg_to_send.status_byte);
    if (!(call hal_aci_tl.send(&msg_to_send)))
    {

      //printf("ACI Command Queue is full\n");
      //printfflush();
      // *num_cmd_offset is now pointing to the index of the Setup command that did not get sent
      return ret_val;
    }
   
    ret_val = TRUE;
    
    (*num_cmd_offset)++;
  }
  
  
  return ret_val;
}

  command void lib_aci.init(aci_state_t *aci_stat, bool debug)
  {
    uint8_t i;
    //uint8_t return_val;
    am_id_t id;
    id=1;

    for (i = 0; i < PIPES_ARRAY_SIZE; i++)
    {
      aci_stat->pipes_open_bitmap[i]          = 0;
      aci_stat->pipes_closed_bitmap[i]        = 0;
      aci_cmd_params_open_adv_pipe.pipes[i]   = 0;
    }
    
    is_request_operation_pending     = FALSE;
    is_indicate_operation_pending    = FALSE; 
    is_open_remote_pipe_pending      = FALSE;
    is_close_remote_pipe_pending     = FALSE;
    
    request_operation_pipe           = 0;
    indicate_operation_pipe          = 0;
    
    p_services_pipe_type_map = aci_stat->aci_setup_info.services_pipe_type_mapping;
    
    p_setup_msgs             = aci_stat->aci_setup_info.setup_msgs;

    aci_stat->aci_pins.interface_is_interrupt = FALSE;
    
    //call UartSend.send[id](1,"Hello World",10);

    


    call hal_aci_tl.init(&aci_stat->aci_pins, debug);
    
    call lib_aci.radio_reset(); //soft reset

    call hal_aci_tl.board_init(aci_stat);

    //return_val = do_aci_setup(aci_stat);
    return;

  }


  command uint8_t lib_aci.get_nb_available_credits(aci_state_t *aci_stat)
  {
    return aci_stat->data_credit_available;
  }

  command uint16_t lib_aci.get_cx_interval_ms(aci_state_t *aci_stat)
  {
    uint32_t cx_rf_interval_ms_32bits;
    uint16_t cx_rf_interval_ms;
    
    cx_rf_interval_ms_32bits  = aci_stat->connection_interval;
    cx_rf_interval_ms_32bits *= 125;                      // the connection interval is given in multiples of 0.125 milliseconds
    cx_rf_interval_ms         = cx_rf_interval_ms_32bits / 100;
    
    return cx_rf_interval_ms;
  }


  command uint16_t lib_aci.get_cx_interval(aci_state_t *aci_stat)
  {
    return aci_stat->connection_interval;
  }


  command uint16_t lib_aci.get_slave_latency(aci_state_t *aci_stat)
  {
    return aci_stat->slave_latency;
  }


  command bool lib_aci.set_app_latency(uint16_t latency, aci_app_latency_mode_t latency_mode)
  {
    aci_cmd_params_set_app_latency_t aci_set_app_latency;
    
    aci_set_app_latency.mode    = latency_mode;
    aci_set_app_latency.latency = latency;  
    call acil.encode_cmd_set_app_latency(&(msg_to_send.buffer[0]), &aci_set_app_latency);
    
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.test(aci_test_mode_change_t enter_exit_test_mode)
  {
    aci_cmd_params_test_t aci_cmd_params_test;
    aci_cmd_params_test.test_mode_change = enter_exit_test_mode;
    call acil.encode_cmd_set_test_mode(&(msg_to_send.buffer[0]), &aci_cmd_params_test);
    return (call hal_aci_tl.send(&msg_to_send));
  }


  command bool lib_aci.sleep()
  {
    call acil.encode_cmd_sleep(&(msg_to_send.buffer[0]));
    return (call hal_aci_tl.send(&msg_to_send));
  }


  command bool lib_aci.radio_reset()
  {
    call acil.encode_baseband_reset(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.direct_connect()
  {
    call acil.encode_direct_connect(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.device_version()
  {
    call acil.encode_cmd_get_device_version(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.set_local_data(aci_state_t *aci_stat, uint8_t pipe, uint8_t *p_value, uint8_t size)
  {
    aci_cmd_params_set_local_data_t aci_cmd_params_set_local_data;
    
    if ((p_services_pipe_type_map[pipe-1].location != ACI_STORE_LOCAL)
        ||
        (size > ACI_PIPE_TX_DATA_MAX_LEN))
    {
      return FALSE;
    }

    aci_cmd_params_set_local_data.tx_data.pipe_number = pipe;
    memcpy(&(aci_cmd_params_set_local_data.tx_data.aci_data[0]), p_value, size);
    call acil.encode_cmd_set_local_data(&(msg_to_send.buffer[0]), &aci_cmd_params_set_local_data, size);
    return call hal_aci_tl.send(&msg_to_send);
  }

  command bool lib_aci.connect(uint16_t run_timeout, uint16_t adv_interval)
  {
    aci_cmd_params_connect_t aci_cmd_params_connect;
    aci_cmd_params_connect.timeout      = run_timeout;
    aci_cmd_params_connect.adv_interval = adv_interval;
    call acil.encode_cmd_connect(&(msg_to_send.buffer[0]), &aci_cmd_params_connect);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.disconnect(aci_state_t *aci_stat, aci_disconnect_reason_t reason)
  {
    bool ret_val;
    uint8_t i;
    aci_cmd_params_disconnect_t aci_cmd_params_disconnect;
    aci_cmd_params_disconnect.reason = reason;
    call acil.encode_cmd_disconnect(&(msg_to_send.buffer[0]), &aci_cmd_params_disconnect);
    ret_val = call hal_aci_tl.send(&msg_to_send);
    // If we have actually sent the disconnect
    if (ret_val)
    {
      // Update pipes immediately so that while the disconnect is happening,
      // the application can't attempt sending another message
      // If the application sends another message before we updated this
      //    a ACI Pipe Error Event will be received from nRF8001
      for (i=0; i < PIPES_ARRAY_SIZE; i++)
      {
        aci_stat->pipes_open_bitmap[i] = 0;
        aci_stat->pipes_closed_bitmap[i] = 0;
      }
    }
    return ret_val;
  }


  command bool lib_aci.bond(uint16_t run_timeout, uint16_t adv_interval)
  {
    aci_cmd_params_bond_t aci_cmd_params_bond;
    aci_cmd_params_bond.timeout = run_timeout;
    aci_cmd_params_bond.adv_interval = adv_interval;
    call acil.encode_cmd_bond(&(msg_to_send.buffer[0]), &aci_cmd_params_bond);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.wakeup()
  {
    call acil.encode_cmd_wakeup(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.set_tx_power(aci_device_output_power_t tx_power)
  {
    aci_cmd_params_set_tx_power_t aci_cmd_params_set_tx_power;
    aci_cmd_params_set_tx_power.device_power = tx_power;
    call acil.encode_cmd_set_radio_tx_power(&(msg_to_send.buffer[0]), &aci_cmd_params_set_tx_power);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.get_address()
  {
    call acil.encode_cmd_get_address(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.get_temperature()
  {
    call acil.encode_cmd_temparature(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.get_battery_level()
  {
    call acil.encode_cmd_battery_level(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.send_data(uint8_t pipe, uint8_t *p_value, uint8_t size)
  {
    bool ret_val = FALSE;
    aci_cmd_params_send_data_t aci_cmd_params_send_data;

    
    if(!((p_services_pipe_type_map[pipe-1].pipe_type == ACI_TX) ||
        (p_services_pipe_type_map[pipe-1].pipe_type == ACI_TX_ACK)))
    {

      return FALSE;
    }

    if (size > ACI_PIPE_TX_DATA_MAX_LEN)
    {
      printf("false\n");
      printfflush();
      return FALSE;
    }
    {
        aci_cmd_params_send_data.tx_data.pipe_number = pipe;
        memcpy(&(aci_cmd_params_send_data.tx_data.aci_data[0]), p_value, size);
        call acil.encode_cmd_send_data(&(msg_to_send.buffer[0]), &aci_cmd_params_send_data, size);
        
        ret_val = call hal_aci_tl.send(&msg_to_send);          
    }
    return ret_val;
  }


  command bool lib_aci.request_data(aci_state_t *aci_stat, uint8_t pipe)
  {
    bool ret_val = FALSE;
    aci_cmd_params_request_data_t aci_cmd_params_request_data;

    if(!((p_services_pipe_type_map[pipe-1].location == ACI_STORE_REMOTE)&&(p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX_REQ)))
    {
      return FALSE;
    }


    {

      {



        aci_cmd_params_request_data.pipe_number = pipe;
        call acil.encode_cmd_request_data(&(msg_to_send.buffer[0]), &aci_cmd_params_request_data);

        ret_val = call hal_aci_tl.send(&msg_to_send);
      }
    }
    return ret_val;
  }


  command bool lib_aci.change_timing(uint16_t minimun_cx_interval, uint16_t maximum_cx_interval, uint16_t slave_latency, uint16_t timeout)
  {
    aci_cmd_params_change_timing_t aci_cmd_params_change_timing;
    aci_cmd_params_change_timing.conn_params.min_conn_interval = minimun_cx_interval;
    aci_cmd_params_change_timing.conn_params.max_conn_interval = maximum_cx_interval;
    aci_cmd_params_change_timing.conn_params.slave_latency     = slave_latency;    
    aci_cmd_params_change_timing.conn_params.timeout_mult      = timeout;     
    call acil.encode_cmd_change_timing_req(&(msg_to_send.buffer[0]), &aci_cmd_params_change_timing);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.change_timing_GAP_PPCP()
  {
    call acil.encode_cmd_change_timing_req_GAP_PPCP(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.open_remote_pipe(aci_state_t *aci_stat, uint8_t pipe)
  {
    bool ret_val = FALSE;
    aci_cmd_params_open_remote_pipe_t aci_cmd_params_open_remote_pipe;

    if(!((p_services_pipe_type_map[pipe-1].location == ACI_STORE_REMOTE)&&
                  ((p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX)||
                  (p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX_ACK_AUTO)||
                  (p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX_ACK))))
    {
      return FALSE;
    }

    
    {

      is_request_operation_pending = TRUE;
      is_open_remote_pipe_pending = TRUE;
      request_operation_pipe = pipe;
      aci_cmd_params_open_remote_pipe.pipe_number = pipe;
      call acil.encode_cmd_open_remote_pipe(&(msg_to_send.buffer[0]), &aci_cmd_params_open_remote_pipe);
      ret_val = call hal_aci_tl.send(&msg_to_send);
    }
    return ret_val;
  }


  command bool lib_aci.close_remote_pipe(aci_state_t *aci_stat, uint8_t pipe)
  {
    bool ret_val = FALSE;
    aci_cmd_params_close_remote_pipe_t aci_cmd_params_close_remote_pipe;

    if((p_services_pipe_type_map[pipe-1].location == ACI_STORE_REMOTE)&&
          ((p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX)||
           (p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX_ACK_AUTO)||
           (p_services_pipe_type_map[pipe-1].pipe_type == ACI_RX_ACK)))
    {
      return FALSE;
    }  


    {

      is_request_operation_pending = TRUE;
      is_close_remote_pipe_pending = TRUE;
      request_operation_pipe = pipe;
      aci_cmd_params_close_remote_pipe.pipe_number = pipe;
      call acil.encode_cmd_close_remote_pipe(&(msg_to_send.buffer[0]), &aci_cmd_params_close_remote_pipe);
      ret_val = call hal_aci_tl.send(&msg_to_send);
    }
    return ret_val;
  }


  command bool lib_aci.set_key(aci_key_type_t key_rsp_type, uint8_t *key, uint8_t len)
  {
    aci_cmd_params_set_key_t aci_cmd_params_set_key;
    aci_cmd_params_set_key.key_type = key_rsp_type;
    memcpy((uint8_t*)&(aci_cmd_params_set_key.key), key, len);
    call acil.encode_cmd_set_key(&(msg_to_send.buffer[0]), &aci_cmd_params_set_key);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.echo_msg(uint8_t msg_size, uint8_t *p_msg_data)
  {
    aci_cmd_params_echo_t aci_cmd_params_echo;
    if(msg_size > (ACI_ECHO_DATA_MAX_LEN))
    {
      return FALSE;
    }

    if (msg_size > (ACI_ECHO_DATA_MAX_LEN))
    {
      msg_size = ACI_ECHO_DATA_MAX_LEN;
    }

    memcpy(&(aci_cmd_params_echo.echo_data[0]), p_msg_data, msg_size);
    call acil.encode_cmd_echo_msg(&(msg_to_send.buffer[0]), &aci_cmd_params_echo, msg_size);

    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.bond_request()
  {
    call acil.encode_cmd_bond_security_request(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }

  command bool lib_aci.event_peek(hal_aci_evt_t *p_aci_evt_data)
  {
    return (call hal_aci_tl.event_peek((hal_aci_data_t *)p_aci_evt_data));
  }

  command bool lib_aci.event_get(aci_state_t *aci_stat, hal_aci_evt_t *p_aci_evt_data)
  {
    bool status = FALSE;

    
    status = call hal_aci_tl.event_get((hal_aci_data_t *)p_aci_evt_data);
    /**
    Update the state of the ACI with the 
    ACI Events -> Pipe Status, Disconnected, Connected, Bond Status, Pipe Error
    */
    if (TRUE == status)
    {
      aci_evt_t * aci_evt;
      
      aci_evt = &p_aci_evt_data->evt; 

      
      switch(aci_evt->evt_opcode)
      {
          case ACI_EVT_PIPE_STATUS:
              {
                  uint8_t i=0;
                  
                  for (i=0; i < PIPES_ARRAY_SIZE; i++)
                  {
                    aci_stat->pipes_open_bitmap[i]   = aci_evt->params.pipe_status.pipes_open_bitmap[i];
                    aci_stat->pipes_closed_bitmap[i] = aci_evt->params.pipe_status.pipes_closed_bitmap[i];
                  }
              }
              break;
          
          case ACI_EVT_DISCONNECTED:
              {
                  uint8_t i=0;
                  
                  for (i=0; i < PIPES_ARRAY_SIZE; i++)
                  {
                    aci_stat->pipes_open_bitmap[i] = 0;
                    aci_stat->pipes_closed_bitmap[i] = 0;
                  }
                  aci_stat->confirmation_pending = FALSE;
                  aci_stat->data_credit_available = aci_stat->data_credit_total;
                  
              }
              break;
              
          case ACI_EVT_TIMING:            
                  aci_stat->connection_interval = aci_evt->params.timing.conn_rf_interval;
                  aci_stat->slave_latency       = aci_evt->params.timing.conn_slave_rf_latency;
                  aci_stat->supervision_timeout = aci_evt->params.timing.conn_rf_timeout;
              break;

          default:
              /* Need default case to avoid compiler warnings about missing enum
               * values on some platforms.
               */
              break;

  			
  			
      }
    }
    return status;
  }


  command bool lib_aci.send_ack(aci_state_t *aci_stat, const uint8_t pipe)
  {
    bool ret_val = FALSE;
    {
      call acil.encode_cmd_send_data_ack(&(msg_to_send.buffer[0]), pipe);
      
      ret_val = call hal_aci_tl.send(&msg_to_send);
    }
    return ret_val;
  }


  command bool lib_aci.send_nack(aci_state_t *aci_stat, const uint8_t pipe, const uint8_t error_code)
  {
    bool ret_val = FALSE;
    
    {
      
      call acil.encode_cmd_send_data_nack(&(msg_to_send.buffer[0]), pipe, error_code);
      ret_val = call hal_aci_tl.send(&msg_to_send);
    }
    return ret_val;
  }


  command bool lib_aci.broadcast(const uint16_t timeout, const uint16_t adv_interval)
  {
    aci_cmd_params_broadcast_t aci_cmd_params_broadcast;
    if (timeout > 16383)
    {
      return FALSE;
    }  
    
    // The adv_interval should be between 160 and 16384 (which translates to the advertisement 
    // interval values 100 ms and 10.24 s.
    if ((160 > adv_interval) || (adv_interval > 16384))
    {
      return FALSE;
    }

    aci_cmd_params_broadcast.timeout = timeout;
    aci_cmd_params_broadcast.adv_interval = adv_interval;
    call acil.encode_cmd_broadcast(&(msg_to_send.buffer[0]), &aci_cmd_params_broadcast);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.open_adv_pipes(const uint8_t * const adv_service_data_pipes)
  {
    uint8_t i;
      
    for (i = 0; i < PIPES_ARRAY_SIZE; i++)
    {
      aci_cmd_params_open_adv_pipe.pipes[i] = adv_service_data_pipes[i];
    }

    call acil.encode_cmd_open_adv_pipes(&(msg_to_send.buffer[0]), &aci_cmd_params_open_adv_pipe);
    return call hal_aci_tl.send(&msg_to_send);
  }

  command bool lib_aci.open_adv_pipe(const uint8_t pipe)
  {
    uint8_t byte_idx = pipe / 8;
    
    aci_cmd_params_open_adv_pipe.pipes[byte_idx] |= (0x01 << (pipe % 8));
    call acil.encode_cmd_open_adv_pipes(&(msg_to_send.buffer[0]), &aci_cmd_params_open_adv_pipe);
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.read_dynamic_data()
  {
    call acil.encode_cmd_read_dynamic_data(&(msg_to_send.buffer[0]));
    return call hal_aci_tl.send(&msg_to_send);
  }


  command bool lib_aci.write_dynamic_data(uint8_t sequence_number, uint8_t* dynamic_data, uint8_t length)
  {
    call acil.encode_cmd_write_dynamic_data(&(msg_to_send.buffer[0]), sequence_number, dynamic_data, length);
    return call hal_aci_tl.send(&msg_to_send);
  }

  command bool lib_aci.dtm_command(uint8_t dtm_command_msbyte, uint8_t dtm_command_lsbyte)
  {
    aci_cmd_params_dtm_cmd_t aci_cmd_params_dtm_cmd;
    aci_cmd_params_dtm_cmd.cmd_msb = dtm_command_msbyte;
    aci_cmd_params_dtm_cmd.cmd_lsb = dtm_command_lsbyte;
    call acil.encode_cmd_dtm_cmd(&(msg_to_send.buffer[0]), &aci_cmd_params_dtm_cmd);
    return call hal_aci_tl.send(&msg_to_send);
  }

  command void lib_aci.flush(void)
  {
    call hal_aci_tl.q_flush();
  }

  command void lib_aci.debug_print(bool enable)
  {
    call hal_aci_tl.debug_print(enable);

  }

  command void lib_aci.pin_reset(void)
  {
      call hal_aci_tl.pin_reset();
  }

  command bool lib_aci.event_queue_empty(void)
  {
    return call hal_aci_tl.rx_q_empty();
  }

  command bool lib_aci.event_queue_full(void)
  {
    return call hal_aci_tl.rx_q_full();
  }

  command bool lib_aci.command_queue_empty(void)
  {
    return call hal_aci_tl.tx_q_empty();
  }

  command bool lib_aci.command_queue_full(void)
  {
    return call hal_aci_tl.tx_q_full();
  }
}