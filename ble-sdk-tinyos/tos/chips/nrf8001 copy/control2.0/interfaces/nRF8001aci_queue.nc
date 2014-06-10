#include "hal_aci_tl.h"
#include "aci_queue.h"
#include "ble_assert.h"

interface nRF8001aci_queue
{
	command void init(aci_queue_t *aci_q);
	command bool dequeue(aci_queue_t *aci_q, hal_aci_data_t *p_data);
	command bool dequeue_from_isr(aci_queue_t *aci_q, hal_aci_data_t *p_data);
	command bool enqueue(aci_queue_t *aci_q, hal_aci_data_t *p_data);
	command bool enqueue_from_isr(aci_queue_t *aci_q, hal_aci_data_t *p_data);
	command bool is_empty(aci_queue_t *aci_q);
	command bool is_empty_from_isr(aci_queue_t *aci_q);
	command bool is_full(aci_queue_t *aci_q);
	command bool is_full_from_isr(aci_queue_t *aci_q);
	command bool peek(aci_queue_t *aci_q, hal_aci_data_t *p_data);
	command bool peek_from_isr(aci_queue_t *aci_q, hal_aci_data_t *p_data);

}