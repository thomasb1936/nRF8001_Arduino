#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H

enum {
  TIMER_PERIOD_MILLI = 250,
  AM_BLINKTORADIO = 6
};


typedef nx_struct BlinkToRadioMsg {
  nx_uint16_t nodeid;
  nx_uint16_t counter;
}BlinkToRadioMsg;

#endif
