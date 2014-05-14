/*
 * Copyright (c) 2010, Vanderbilt University
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE VANDERBILT UNIVERSITY BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE VANDERBILT
 * UNIVERSITY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE VANDERBILT UNIVERSITY SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE VANDERBILT UNIVERSITY HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 * Author: Janos Sallai
 */
 
#ifndef __nrf8001DRIVERLAYER_H__
#define __nrf8001DRIVERLAYER_H__


typedef nx_struct nrf8001_header_t
{
	nxle_uint8_t length;
} nrf8001_header_t;

typedef struct nrf8001_metadata_t
{
	uint8_t lqi;
	union
	{
		uint8_t power;
		uint8_t rssi;
	}; 
} nrf8001_metadata_t; 

enum nrf8001_timing_enums {
	nrf8001_SYMBOL_TIME = 16, // 16us	
	IDLE_2_RX_ON_TIME = 12 * nrf8001_SYMBOL_TIME, 
	PD_2_IDLE_TIME = 860, // .86ms
	STROBE_TO_TX_ON_TIME = 12 * nrf8001_SYMBOL_TIME, 
	// TX SFD delay is computed as follows:
	// a.) STROBE_TO_TX_ON_TIME is required for preamble transmission to 
	// start after TX strobe is issued
	// b.) the SFD byte is the 5th byte transmitted (10 symbol periods)
	// c.) there's approximately a 25us delay between the strobe and reading
	// the timer register
	TX_SFD_DELAY = STROBE_TO_TX_ON_TIME + 10 * nrf8001_SYMBOL_TIME - 25,
	// TX SFD is captured in hardware
	RX_SFD_DELAY = 0,
};

enum nrf8001_reg_access_enums {
	nrf8001_CMD_REGISTER_MASK = 0x3f,
	nrf8001_CMD_REGISTER_READ = 0x40,
	nrf8001_CMD_REGISTER_WRITE = 0x00,
	nrf8001_CMD_TXRAM_WRITE	= 0x80,
};

typedef union nrf8001_status {
	uint16_t value;
	struct {
	  unsigned  reserved0:1;
	  unsigned  rssi_valid:1;
	  unsigned  lock:1;
	  unsigned  tx_active:1;
	  
	  unsigned  enc_busy:1;
	  unsigned  tx_underflow:1;
	  unsigned  xosc16m_stable:1;
	  unsigned  reserved7:1;
	};
} nrf8001_status_t;

typedef union nrf8001_iocfg0 {
	uint16_t value;
	struct {
	  unsigned  fifop_thr:7;
	  unsigned  cca_polarity:1;
	  unsigned  sfd_polarity:1;
	  unsigned  fifop_polarity:1;
	  unsigned  fifo_polarity:1;
	  unsigned  bcn_accept:1;
	  unsigned  reserved:4; // write as 0
	} f;
} nrf8001_iocfg0_t;

// TODO: make sure that we avoid wasting RAM
static const nrf8001_iocfg0_t nrf8001_iocfg0_default = {.f.fifop_thr = 64, .f.cca_polarity = 0, .f.sfd_polarity = 0, .f.fifop_polarity = 0, .f.fifo_polarity = 0, .f.bcn_accept = 0, .f.reserved = 0};

typedef union nrf8001_iocfg1 {
	uint16_t value;
	struct {
	  unsigned  ccamux:5;
	  unsigned  sfdmux:5;
	  unsigned  hssd_src:3;
	  unsigned  reserved:3; // write as 0
	} f;
} nrf8001_iocfg1_t;

static const nrf8001_iocfg1_t nrf8001_iocfg1_default = {.value = 0};

typedef union nrf8001_fsctrl {
	uint16_t value;
	struct {
	  unsigned  freq:10;
	  unsigned  lock_status:1;
	  unsigned  lock_length:1;
	  unsigned  cal_running:1;
	  unsigned  cal_done:1;
	  unsigned  lock_thr:2;
	} f;
} nrf8001_fsctrl_t;

static const nrf8001_fsctrl_t nrf8001_fsctrl_default = {.f.lock_thr = 1, .f.freq = 357, .f.lock_status = 0, .f.lock_length = 0, .f.cal_running = 0, .f.cal_done = 0};

typedef union nrf8001_mdmctrl0 {
	uint16_t value;
	struct {
	  unsigned  preamble_length:4;
	  unsigned  autoack:1;
	  unsigned  autocrc:1;
	  unsigned  cca_mode:2;
	  unsigned  cca_hyst:3;
	  unsigned  adr_decode:1;
	  unsigned  pan_coordinator:1;
	  unsigned  reserved_frame_mode:1;
	  unsigned  reserved:2;
	} f;
} nrf8001_mdmctrl0_t;

static const nrf8001_mdmctrl0_t nrf8001_mdmctrl0_default = {.f.preamble_length = 2, .f.autocrc = 1, .f.cca_mode = 3, .f.cca_hyst = 2, .f.adr_decode = 1};

typedef union nrf8001_txctrl {
	uint16_t value;
	struct {
	  unsigned  pa_level:5;
	  unsigned reserved:1;
	  unsigned pa_current:3;
	  unsigned txmix_current:2;
	  unsigned txmix_caparray:2;
  	  unsigned tx_turnaround:1;
  	  unsigned txmixbuf_cur:2;
	} f;
} nrf8001_txctrl_t;

static const nrf8001_txctrl_t nrf8001_txctrl_default = {.f.pa_level = 31, .f.reserved = 1, .f.pa_current = 3, .f.tx_turnaround = 1, .f.txmixbuf_cur = 2};


#ifndef nrf8001_DEF_CHANNEL
#define nrf8001_DEF_CHANNEL 11
#endif

#ifndef nrf8001_DEF_RFPOWER
#define nrf8001_DEF_RFPOWER 31
#endif

enum {
	nrf8001_TX_PWR_MASK = 0x1f,
	nrf8001_CHANNEL_MASK = 0x1f,
};

enum nrf8001_config_reg_enums {
  nrf8001_SNOP = 0x00,
  nrf8001_SXOSCON = 0x01,
  nrf8001_STXCAL = 0x02,
  nrf8001_SRXON = 0x03,
  nrf8001_STXON = 0x04,
  nrf8001_STXONCCA = 0x05,
  nrf8001_SRFOFF = 0x06,
  nrf8001_SXOSCOFF = 0x07,
  nrf8001_SFLUSHRX = 0x08,
  nrf8001_SFLUSHTX = 0x09,
  nrf8001_SACK = 0x0a,
  nrf8001_SACKPEND = 0x0b,
  nrf8001_SRXDEC = 0x0c,
  nrf8001_STXENC = 0x0d,
  nrf8001_SAES = 0x0e,
  nrf8001_MAIN = 0x10,
  nrf8001_MDMCTRL0 = 0x11,
  nrf8001_MDMCTRL1 = 0x12,
  nrf8001_RSSI = 0x13,
  nrf8001_SYNCWORD = 0x14,
  nrf8001_TXCTRL = 0x15,
  nrf8001_RXCTRL0 = 0x16,
  nrf8001_RXCTRL1 = 0x17,
  nrf8001_FSCTRL = 0x18,
  nrf8001_SECCTRL0 = 0x19,
  nrf8001_SECCTRL1 = 0x1a,
  nrf8001_BATTMON = 0x1b,
  nrf8001_IOCFG0 = 0x1c,
  nrf8001_IOCFG1 = 0x1d,
  nrf8001_MANFIDL = 0x1e,
  nrf8001_MANFIDH = 0x1f,
  nrf8001_FSMTC = 0x20,
  nrf8001_MANAND = 0x21,
  nrf8001_MANOR = 0x22,
  nrf8001_AGCCTRL = 0x23,
  nrf8001_AGCTST0 = 0x24,
  nrf8001_AGCTST1 = 0x25,
  nrf8001_AGCTST2 = 0x26,
  nrf8001_FSTST0 = 0x27,
  nrf8001_FSTST1 = 0x28,
  nrf8001_FSTST2 = 0x29,
  nrf8001_FSTST3 = 0x2a,
  nrf8001_RXBPFTST = 0x2b,
  nrf8001_FSMSTATE = 0x2c,
  nrf8001_ADCTST = 0x2d,
  nrf8001_DACTST = 0x2e,
  nrf8001_TOPTST = 0x2f,
  nrf8001_TXFIFO = 0x3e,
  nrf8001_RXFIFO = 0x3f,
};

enum nrf8001_ram_addr_enums {
  nrf8001_RAM_TXFIFO = 0x000,
  nrf8001_RAM_TXFIFO_END = 0x7f,  
  nrf8001_RAM_RXFIFO = 0x080,
  nrf8001_RAM_KEY0 = 0x100,
  nrf8001_RAM_RXNONCE = 0x110,
  nrf8001_RAM_SABUF = 0x120,
  nrf8001_RAM_KEY1 = 0x130,
  nrf8001_RAM_TXNONCE = 0x140,
  nrf8001_RAM_CBCSTATE = 0x150,
  nrf8001_RAM_IEEEADR = 0x160,
  nrf8001_RAM_PANID = 0x168,
  nrf8001_RAM_SHORTADR = 0x16a,
};


#endif // __nrf8001DRIVERLAYER_H__
