
#include <lib_aci.h>
#include <aci_setup.h>

/**
Put the nRF8001 setup in the RAM of the nRF8001.
*/
#include "services.h"
/**
Include the services_lock.h to put the setup in the OTP memory of the nRF8001.
This would mean that the setup cannot be changed once put in.
However this removes the need to do the setup of the nRF8001 on every reset.
*/


#ifdef SERVICES_PIPE_TYPE_MAPPING_CONTENT
    static services_pipe_type_mapping_t
     services_pipe_type_mapping[NUMBER_OF_PIPES] = SERVICES_PIPE_TYPE_MAPPING_CONTENT;
#else
     #define NUMBER_OF_PIPES 0
     static services_pipe_type_mapping_t * services_pipe_type_mapping = NULL;
#endif

// aci_struct that will contain
// total initial credits
// current credit
// current state of the aci (setup/standby/active/sleep)
// open remote pipe pending
// close remote pipe pending
// Current pipe available bitmap
// Current pipe closed bitmap
// Current connection interval, slave latency and link supervision timeout
// Current State of the the GATT client (Service Discovery)
// Status of the bond (R) Peer addrer

module nRF8001setupP
{
    provides
    {
      interface nRF8001;
      interface aci_setup;
    } 

    uses
    {
      interface GeneralIO as ACTIVE;
      interface GeneralIO as RESET;
      interface GeneralIP as REQN;
      interfave lib_aci;
      interface Resource as SpiResource;
    }

}

implementation
{
  static struct aci_state_t aci_state;

  command void setup(void)
  {
    /**
    Point ACI data structures to the the setup data that the nRFgo studio generated for the nRF8001
    */
    if (NULL != services_pipe_type_mapping)
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

    /*
    Tell the ACI library, the MCU to nRF8001 pin connections.
    The Active pin is optional and can be marked UNUSED
    */
    aci_state.aci_pins.board_name = BOARD_DEFAULT; //See board.h for details REDBEARLAB_SHIELD_V1_1 or BOARD_DEFAULT
    aci_state.aci_pins.reqn_pin   = REQN; Set in HplNRF8001PinC.nc
    aci_state.aci_pins.rdyn_pin   = RDYN; Set in HplNRF8001PinC.nc
    aci_state.aci_pins.mosi_pin   = MOSI;
    aci_state.aci_pins.miso_pin   = MISO;
    aci_state.aci_pins.sck_pin    = SCK;

    aci_state.aci_pins.spi_clock_divider      = SPI_CLOCK_DIV8;//SPI_CLOCK_DIV8  = 2MHz SPI speed
                                                               //SPI_CLOCK_DIV16 = 1MHz SPI speed
    
    aci_state.aci_pins.reset_pin              = 4; //4 for Nordic board, UNUSED for REDBEARLAB_SHIELD_V1_1
    aci_state.aci_pins.active_pin             = UNUSED;
    aci_state.aci_pins.optional_chip_sel_pin  = UNUSED;

    aci_state.aci_pins.interface_is_interrupt = false; //Interrupts still not available in Chipkit
    aci_state.aci_pins.interrupt_number       = 1;

    //We reset the nRF8001 here by toggling the RESET line connected to the nRF8001
    //If the RESET line is not available we call the ACI Radio Reset to soft reset the nRF8001
    //then we initialize the data structures required to setup the nRF8001
    //The second parameter is for turning debug printing on for the ACI Commands and Events so they be printed on the Serial

    lib_aci.init(&aci_state, false);

  }

  // aci_struct that will contain 
  // total initial credits
  // current credit
  // current state of the aci (setup/standby/active/sleep)
  // open remote pipe pending
  // close remote pipe pending
  // Current pipe available bitmap
  // Current pipe closed bitmap
  // Current connection interval, slave latency and link supervision timeout
  // Current State of the the GATT client (Service Discovery status)

  //TODO Deal with this line
  extern hal_aci_data_t msg_to_send;




  /**************************************************************************                */
  /* Utility function to fill the the ACI command queue                                      */
  /* aci_stat               Pointer to the ACI state                                         */
  /* num_cmd_offset(in/out) Offset in the Setup message array to start from                  */
  /*                        offset is updated to the new index after the queue is filled     */
  /*                        or the last message us placed in the queue                       */
  /* Returns                true if at least one message was transferred                     */
  /***************************************************************************/
  static bool aci_setup_fill(aci_state_t *aci_stat, uint8_t *num_cmd_offset)
  {
    bool ret_val = false;
    
    while (*num_cmd_offset < aci_stat->aci_setup_info.num_setup_msgs)
    {
    //Board dependent defines
    #if defined (__AVR__)
      //For Arduino copy the setup ACI message from Flash to RAM.
      memcpy_P(&msg_to_send, &(aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset]), 
            pgm_read_byte_near(&(aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset].buffer[0]))+2); 
    #elif defined(__PIC32MX__)
      //In ChipKit we store the setup messages in RAM
      //Add 2 bytes to the length byte for status byte, length for the total number of bytes
      memcpy(&msg_to_send, &(aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset]), 
            (aci_stat->aci_setup_info.setup_msgs[*num_cmd_offset].buffer[0]+2)); 
    #endif

      //Put the Setup ACI message in the command queue
      if (!hal_aci_tl_send(&msg_to_send))
      {
        //ACI Command Queue is full
        // *num_cmd_offset is now pointing to the index of the Setup command that did not get sent
        return ret_val;
      }
     
      ret_val = true;
      
      (*num_cmd_offset)++;
    }
    
    return ret_val;
  }

  command uint8_t aci_setup.do_aci_setup(aci_state_t *aci_stat)
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
    
    /* Messages in the outgoing queue must be handled before the Setup routine can run.
     * If it is non-empty we return. The user should then process the messages before calling
     * do_aci_setup() again.
     */
    if (!lib_aci_command_queue_empty())
    {
      return SETUP_FAIL_COMMAND_QUEUE_NOT_EMPTY;
    }
    
    /* If there are events pending from the device that are not relevant to setup, we return false
     * so that the user can handle them. At this point we don't care what the event is,
     * as any event is an error.
     */
    if (lib_aci_event_peek(aci_data))
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
      if (i++ > 0xFFFFE)
      {
        return SETUP_FAIL_TIMEOUT;  
      }
      
      if (lib_aci_event_peek(aci_data))
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
         lib_aci_event_get (aci_stat, aci_data);
      }
    }
    
    return SETUP_SUCCESS;
  }
}
