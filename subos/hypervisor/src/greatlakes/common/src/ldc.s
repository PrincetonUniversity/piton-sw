/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ldc.s
* 
* Copyright (c) 2006 Sun Microsystems, Inc. All Rights Reserved.
* 
*  - Do no alter or remove copyright notices
* 
*  - Redistribution and use of this software in source and binary forms, with 
*    or without modification, are permitted provided that the following 
*    conditions are met: 
* 
*  - Redistribution of source code must retain the above copyright notice, 
*    this list of conditions and the following disclaimer.
* 
*  - Redistribution in binary form must reproduce the above copyright notice,
*    this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution. 
* 
*    Neither the name of Sun Microsystems, Inc. or the names of contributors 
* may be used to endorse or promote products derived from this software 
* without specific prior written permission. 
* 
*     This software is provided "AS IS," without a warranty of any kind. 
* ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, 
* INCLUDING ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
* PARTICULAR PURPOSE OR NON-INFRINGEMENT, ARE HEREBY EXCLUDED. SUN 
* MICROSYSTEMS, INC. ("SUN") AND ITS LICENSORS SHALL NOT BE LIABLE FOR 
* ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR 
* DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES. IN NO EVENT WILL SUN 
* OR ITS LICENSORS BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR 
* FOR DIRECT, INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE 
* DAMAGES, HOWEVER CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, 
* ARISING OUT OF THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF 
* SUN HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
* 
* You acknowledge that this software is not designed, licensed or
* intended for use in the design, construction, operation or maintenance of
* any nuclear facility. 
* 
* ========== Copyright Header End ============================================
*/
/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)ldc.s	1.14	07/07/17 SMI"

/*
 * LDC support functions
 */

#include "config.h"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <hprivregs.h>
#include <sun4v/mmu.h>
#include <sun4v/intr.h>
#include <mmu.h>
#ifdef CONFIG_FPGA
#include <fpga.h>
#endif
#include <md.h>
#include <debug.h>
#include <offsets.h>
#include <util.h>
#include <ldc.h>
#include <hvctl.h>
#include <abort.h>

/*
 * Common block of code executed by all LDC package API
 * calls to verify input value and fetch the pointer to
 * the LDC endpoint.
 *
 * Input registers:
 *  ch_id	(unmodified) - channel ID of LDC
 *  scr		(modified)   - scratch register
 *
 * Output registers:
 *  guest	(modified)   - returns current guest pointer
 *  endpoint	(modified)   - returns the ldc_endpoint pointer
 *
 */
#define GET_LDC_ENDPOINT(ch_id, scr, guest, endpoint)			\
	GUEST_STRUCT(guest)						;\
	set	GUEST_LDC_MAX_CHANNEL_IDX, endpoint			;\
	ldx	[guest + endpoint], endpoint				;\
	cmp	ch_id, endpoint						;\
	bgeu,pn	%xcc, herr_invalchan	/* is channel legit? */		;\
	  nop								;\
	mulx	ch_id, LDC_ENDPOINT_SIZE, endpoint			;\
	set	GUEST_LDC_ENDPOINT, scr					;\
	add	endpoint, scr, endpoint					;\
	add	endpoint, guest, endpoint				;\
	ldub	[endpoint + LDC_IS_LIVE], scr				;\
	brz,pn	scr, herr_invalchan	/* is channel live */		;\
	  ldub	[endpoint + LDC_IS_PRIVATE], scr			;\
	brnz,pn	scr, herr_invalchan	/* is channel live */		;\
	  nop

/*
 * Macro to calculate channel status for the target in a
 * guest<->guest LDC link.
 *
 * Parameters:
 *  guest_endpt	(unmodified)	- guest endpoint stuct pointer
 *  status	(return value)	- Output: status of channel
 *  scr		(modified)	- scratch register
 */
#define	GET_GUEST_QUEUE_STATUS(guest_endpt, status, scr)		\
	.pushlocals							;\
	ldx	[guest_endpt + LDC_TARGET_GUEST], status		;\
	ldx	[guest_endpt + LDC_TARGET_CHANNEL], scr			;\
	mulx	scr, LDC_ENDPOINT_SIZE, scr				;\
	add	status, scr, status					;\
	set	GUEST_LDC_ENDPOINT, scr					;\
	add	scr, status, status		/* target endpoint   */	;\
									;\
	ldub	[status + LDC_RX_UPDATED], scr				;\
	brnz,a	scr, 1f				/* if flag is set... */	;\
	  stb	%g0, [status + LDC_RX_UPDATED]	/* then clear it     */	;\
1:									;\
	ldx	[status + LDC_RX_QSIZE], status	/* if qsize==0 then  */	;\
	brz,a	status, 0f			/* status is DOWN    */	;\
	  mov	LDC_CHANNEL_DOWN, status				;\
	brz,a	scr, 0f			/* if qsize!=0 && updated=0  */	;\
	  mov	LDC_CHANNEL_UP, status		/*  then UP          */	;\
	mov	LDC_CHANNEL_RESET, status	/*  else RESET       */	;\
0:									;\
	.poplocals

/*
 * Macro to calculate channel status for the target in a
 * guest<->SP LDC link.
 *
 * Parameters:
 *  guest_endpt	(unmodified)	- guest endpoint stuct pointer
 *  status	(return value)	- Output: status of channel
 *  scr		(modified)	- scratch register
 */
#define	GET_SP_QUEUE_STATUS(guest_endpt, status, scr)			\
	.pushlocals							;\
	ROOT_STRUCT(status)						;\
	ldx	[status + CONFIG_SP_LDCS], status			;\
	ldx	[guest_endpt + LDC_TARGET_CHANNEL], scr			;\
	mulx	scr, SP_LDC_ENDPOINT_SIZE, scr				;\
	add	status, scr, status		/* target endpoint   */	;\
	ldx	[status + SP_LDC_TX_QD_PA], status /* QD ptr to SRAM */	;\
									;\
	ldub	[status + SRAM_LDC_STATE_UPDATED], scr			;\
	brnz,a	scr, 1f				/* if flag set, then */	;\
	  stb	%g0, [status + SRAM_LDC_STATE_UPDATED]	/* clear it  */	;\
1:									;\
	ldub	[status + SRAM_LDC_STATE], status	/* status    */	;\
	brz,a	status, 0f			/* DOWN = 0, UP = 1  */	;\
	  mov	LDC_CHANNEL_DOWN, status				;\
	brz,a	scr, 0f			/* if status=UP && updated=0 */	;\
	  mov	LDC_CHANNEL_UP, status		/*  then UP          */	;\
	mov	LDC_CHANNEL_RESET, status	/*  else RESET */	;\
0:									;\
	.poplocals

/*
 * hv_ldc_chk_pkts - Check channel for pending pkts
 *
 * Check if the specified endpoint has any pkts available
 * in either its Rx queue or peer's Tx queue. If pending,
 * deliver an mondo to the CPU associated with this endpt.
 * Used by ldc_vintr_setstate and ldc_vintr_setvalid to
 * to notify guest when interrupts are enabled.
 *
 * Parameters:
 *   %g1 endpoint being checked (modified)
 *   %g2 - %g6 scratch (modified)
 */
	ENTRY_NP(hv_ldc_chk_pkts)

	lduw	[%g1 + LDC_RX_QHEAD], %g2
	lduw	[%g1 + LDC_RX_QTAIL], %g3
	cmp	%g2, %g3			! if queue empty (head==tail)
	bne	%xcc, .notify_guest		!   check the transmit side
	nop

	ldub	[%g1 + LDC_TARGET_TYPE], %g2
	cmp	%g2, LDC_GUEST_ENDPOINT
	be,pt	%xcc, .peer_is_guest
	cmp	%g2, LDC_SP_ENDPOINT
	bne,pt	%xcc, .no_notification
	nop

	! Target is a SP endpoint
	! Read and compare the SRAM head and tail
	ROOT_STRUCT(%g2)
	ldx	[%g2 + CONFIG_SP_LDCS], %g2		! get SP endpoint array
	ldx	[%g1 + LDC_TARGET_CHANNEL], %g3		! and target endpoint
	mulx	%g3, SP_LDC_ENDPOINT_SIZE, %g3
	add	%g2, %g3, %g2				! and its struct

	!! %g2 sp endpoint
	! quick check to see whether there are any packets
	! to grab on this channel.
	ldx	[%g2 + SP_LDC_RX_QD_PA], %g2
	ldub	[%g2 + SRAM_LDC_HEAD], %g3
	ldub	[%g2 + SRAM_LDC_TAIL], %g4
	cmp	%g3, %g4
	bne,pn	%xcc, .notify_guest
	nop

	HVRET
	/*NOTREACHED*/

.peer_is_guest:
	! Target is a guest endpoint
	ldx	[%g1 + LDC_TARGET_GUEST], %g2		! find target guest
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g2
	ldx	[%g1 + LDC_TARGET_CHANNEL], %g3		! and it's endpoint
	mulx	%g3, LDC_ENDPOINT_SIZE, %g3
	add	%g2, %g3, %g2				! target endpt struct

	lduw	[%g2 + LDC_TX_QHEAD], %g3		! check if src has
	lduw	[%g2 + LDC_TX_QTAIL], %g4		!   anything pending for
	cmp	%g3, %g4				!   transmit
	beq,pt	%xcc, .no_notification
	nop

.notify_guest:
	!! %g1 endpoint to deliver interrupt
	add	%g1, LDC_RX_MAPREG + LDC_MAPREG_STATE, %g4
	set	INTR_DELIVERED, %g5
	set	INTR_IDLE, %g6
	casa	[%g4]ASI_P, %g6, %g5
	cmp	%g5, INTR_IDLE
	bne,a,pn %xcc, .no_notification
	nop

	ldx	[%g1 + LDC_RX_MAPREG + LDC_MAPREG_COOKIE], %g3
	ldx	[%g1 + LDC_RX_MAPREG + LDC_MAPREG_CPUP], %g1
	brz,pn 	%g1, .no_notification
	nop
	!! %g1 target cpup
	!! %g2 flag (1 = mondo)
	!! %g3 data (cookie)
	!! %g2 - %g6 trashed
	ba 	send_dev_mondo			! tail call, returns to caller
	mov	1, %g2

.no_notification:
	HVRET
	SET_SIZE(hv_ldc_chk_pkts)


/*
 * ldc_tx_qconf
 *
 * arg0 channel		(%o0)
 * arg1 q base raddr	(%o1) - must be aligned to size of queue
 * arg2 size (#entries)	(%o2) - must be power of 2 (or 0 to unconfigure queue)
 * --
 * ret0 status		(%o0)
 *
 * Configure transmit queue for LDC endpoint.
 * -
 */
	ENTRY_NP(hcall_ldc_tx_qconf)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	!! %g1 guest
	!! %g2 endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)

	brz,pn	%o2, 2f	! size of 0 unconfigures queue
	  nop

	! number of entries must be a power of 2
	sub	%o2, 1, %g3
	and	%o2, %g3, %g3
	brnz,pn	%g3, herr_inval
	  nop

	sllx    %o2, Q_EL_SIZE_SHIFT, %g4       ! convert #entries to bytes

	! queue raddr must be aligned to size of queue
	sub	%g4, 1, %g5
	btst	%g5, %o1
	bnz,pn	%xcc, herr_badalign		! base addr not aligned ?
	  nop

	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %g4, herr_noraddr, %g6, %g5)

	! Note:	 The guest can flush a TX queue by (re)configuring it.
	! If this happens, we still want to make sure that the the
	! head/tail pointer consistency is maintained between the two
	! guests and so we mark the queue empty without moving the
	! tail pointer. Note that the tail pointer is set to zero at
	! start of day.
	!
	! We do, however, need to make sure the new tail value is not
	! larger than the size of the queue in case the guest is switching
	! to a smaller queue.

	stx	%o1, [%g2 + LDC_TX_QBASE_RA]
	stx	%g5, [%g2 + LDC_TX_QBASE_PA]
	lduw	[%g2 + LDC_TX_QTAIL], %g6	! read existing tail
	sub	%g4, Q_EL_SIZE, %g5
	sub	%g5, %g6, %g5			! bigger than qsize?
	movrlz	%g5, %g0, %g6			! if so, we have to zero
	brlz,a	%g5, 1f				! the head and tail pointer
	  stw	%g6, [%g2 + LDC_TX_QTAIL]
1:
	stw	%g6, [%g2 + LDC_TX_QHEAD]

	! set queue size last if queue is being configured
	stx	%g4, [%g2 + LDC_TX_QSIZE]

	HCALL_RET(EOK)

2:
	! All we need to do is set the qsize to zero if the queue is
	! being unconfigured.
	!
	! Note: we specifically no NOT clear the LDC_TX_QBASE_PA field
	! because doing so could introduce a security hole.
	stx	%g0, [%g2 + LDC_TX_QSIZE]

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_tx_qconf)

/*
 * ldc_tx_qinfo
 *
 * arg0 channel		(%o0)
 * --
 * ret0 status		(%o0)
 * ret1 q base raddr	(%o1)
 * ret2 size (#entries)	(%o2)
 *
 * Return information about the LDC endpoint's transmit queue.
 */
	ENTRY_NP(hcall_ldc_tx_qinfo)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	!! %g1 guest
	!! %g2 endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)

	ldx	[%g2 + LDC_TX_QBASE_RA], %o1
	ldx	[%g2 + LDC_TX_QSIZE], %g4
	srlx	%g4, Q_EL_SIZE_SHIFT, %o2
	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_tx_qinfo)

/*
 * ldc_tx_get_state
 *
 * arg0 channel		(%o0)
 * --
 * ret0 status		(%o0)
 * ret1 head offset	(%o1)
 * ret2 tail offset	(%o2)
 * ret3 channel state	(%o3)
 *
 * Return information about the current state of the queue.
 */
	ENTRY_NP(hcall_ldc_tx_get_state)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	!! %g1 guest
	!! %g2 endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)

	ldx	[%g2 + LDC_TX_QSIZE], %g3	! no Q configured ?
	brz,pn	%g3, herr_inval
	  nop

	lduw	[%g2 + LDC_TX_QHEAD], %o1
	lduw	[%g2 + LDC_TX_QTAIL], %o2

	ldub	[%g2 + LDC_TARGET_TYPE], %g1	! is this endpoint connected to
	cmp	%g1, LDC_HV_ENDPOINT		! the a hypervisor endpoint?
	be,a	%xcc, 3f			! if so, assume channel is up
	  mov	LDC_CHANNEL_UP, %o3

	cmp	%g1, LDC_GUEST_ENDPOINT		! is this endpoint connected to
	be	%xcc, 2f			! another guest endpoint?
	  nop

	! must be a guest<->sp connection
	GET_SP_QUEUE_STATUS(%g2, %o3, %g1)
	ba,a	3f
2:
	GET_GUEST_QUEUE_STATUS(%g2, %o3, %g1)
3:
	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_tx_get_state)

/*
 * guest_to_guest_tx_set_tail
 *
 * %g1 - new tail value
 * %g2 - sender's endpoint
 *
 * Incriments the guest TX tail pointer and sends notification to the RX
 * guest if necessary.
 *
 * Note: It is important that the caller has already verifed that the
 * new tail value is valid given the current state of the queue.
 *
 */
	ENTRY_NP(guest_to_guest_tx_set_tail)

	!! %g1 new tail value
	!! %g2 sender's endpoint
	stw	%g1, [%g2 + LDC_TX_QTAIL]

	ldx	[%g2 + LDC_TARGET_GUEST], %g5		! find target guest
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g3	! end it's endpoint
	mulx	%g3, LDC_ENDPOINT_SIZE, %g4
	add	%g5, %g4, %g4
	set	GUEST_LDC_ENDPOINT, %g6
	add	%g6, %g4, %g4
	ldx	[%g4 + LDC_RX_QSIZE], %g6		! no Q configured ?
	brz,pn	%g6, .tx_set_tail_done			! no notification
	 nop

	! Just leave the data in our transmit queue for now. The recipient
	! will be responsible for pulling over the data into its receive
	! queue when the guest on that end makes a call to check its
	! receive queue head/tail pointers.

	lduw	[%g4 + LDC_RX_QHEAD], %g6
	lduw	[%g4 + LDC_RX_QTAIL], %g3
	cmp	%g6, %g3			! only send and interrupt
	bne	%xcc, .tx_set_tail_done		! if the RX queue is empty.
	  nop

	! now see if we need to send an interrupt to the recipient
	ldx	[%g4 + LDC_RX_MAPREG + LDC_MAPREG_CPUP], %g5
	brnz,pn	%g5, 1f
	  nop

	! if no target CPU specified, is there a vdev interrupt we
	! need to generate?
	ldx	[%g4 + LDC_RX_VINTR_COOKIE], %g5
	brz,pn	%g5, .tx_set_tail_done		! if not, we are done.
	  nop

	mov	%g5, %g1
	STRAND_PUSH(%g7, %g5, %g6)
	HVCALL(vdev_intr_generate)
	STRAND_POP(%g7, %g5)

	ba,a	.tx_set_tail_done
1:
	!! %g4 recipient's endpoint
	mov	%g4, %g3

	STRAND_PUSH(%g7, %g5, %g6)
	HVCALL(hv_ldc_cpu_notify)
	STRAND_POP(%g7, %g5)

.tx_set_tail_done:

	HVRET
	SET_SIZE(guest_to_guest_tx_set_tail)


/*
 * ldc_tx_set_qtail
 *
 * arg0 channel		(%o0)
 * arg1 tail offset	(%o1)
 * --
 * ret0 status		(%o0)
 *
 * Used by the guest to send data packets down the channel.
 */
	ENTRY_NP(hcall_ldc_tx_set_qtail)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	!! %g1 guest
	!! %g2 endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)

	! new tail offset must be aligned properly
	andcc	%o1, Q_EL_SIZE-1, %g0
	bnz,pn	%xcc, herr_badalign
	  nop

	! Transmit queue configured?
	ldx	[%g2 + LDC_TX_QSIZE], %g3
	brz,pn	%g3, herr_inval
	  nop

	! new tail offset must be within range
	cmp	%g3, %o1
	bleu,pn	%xcc, herr_inval	! offset bigger than Q or less than 0?
	  nop

	! verify new tail value makes sense with respect to the old head/tail
	lduw	[%g2 + LDC_TX_QHEAD], %g3
	lduw	[%g2 + LDC_TX_QTAIL], %g4
	ldx	[%g2 + LDC_TX_QBASE_PA], %g7		! save this off for now
	cmp	%g4, %g3
	bl	%xcc, 1f
	  nop

	! tail >= head i.e queue data not yet wrapped or queue empty
	! verify ((new_tail > tail) || (new_tail < head))
	cmp	%o1, %g4
	bg	%xcc, 2f
	cmp	%o1, %g3
	bl	%xcc, 2f
	  nop
	ba	herr_inval	! invalid tail value
	  nop
1:
	! tail < head  i.e. queue data currently wraps around end of queue
	! verify ((new_tail > tail) && (new_tail < head))
	cmp	%o1, %g4
	ble,pn	%xcc, herr_inval
	cmp	%o1, %g3
	bge,pn	%xcc, herr_inval
	  nop

2:	! input values verified

	!! %g1 guest
	!! %g2 endpoint
	!! %g3 tx qhead
	!! %g7 tx qbase PA

	! Check to see if the target is a
	! Guest domain or endpoint in HV or SP

	ldub	[%g2 + LDC_TARGET_TYPE], %g4
	cmp	%g4, LDC_GUEST_ENDPOINT
	be,pt	%xcc, .guest_target	! guest <-> guest connection
	  cmp	%g4, LDC_HV_ENDPOINT
	be,pt	%xcc, .hv_target	! guest <-> hypervisor connection
	  nop

	/*
	 * guest <-> SP connection
	 */
	mov	%o1, %g1

		!! %g1 new tail value
		!! %g2 sender's endpoint

	HVCALL(guest_to_sp_tx_set_tail)	! clobbers all %g1,%g3-%g7

	ba	.ldc_tx_set_qtail_done
	  nop

.hv_target:

	!
	! guest <-> hypervisor connection
	!

	! update tail pointer and invoke callback to process data

	stw	%o1, [%g2 + LDC_TX_QTAIL]

.ldc_tx_set_qtail_hv:

	!! %g1 guest
	!! %g2 endpoint
	!! %g3 tx qhead
	!! %g7 tx qbase PA

	ROOT_STRUCT(%g4)
	ldx	[%g4 + CONFIG_HV_LDCS], %g4		! get HV endpoint array
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g1 	! and target endpoint
	mulx	%g1, LDC_ENDPOINT_SIZE, %g5
	add	%g4, %g5, %g5				! and its struct

	ldx	[%g5 + LDC_RX_CB], %g6			! get the callback
	brz,pn	%g6, .ldc_tx_set_qtail_done		!   if none, drop pkt
	  nop
	ldx	[%g5 + LDC_RX_CBARG], %g1		! load the argument

	add	%g3, %g7, %g7				! PA of the payload

	ldx	[%g2 + LDC_TX_QSIZE], %g5	! each time we invoke the
	dec	Q_EL_SIZE, %g5			! callback, it will consume one
	add	%g3, Q_EL_SIZE, %g3		! element from the Q so we
	and	%g3, %g5, %g5			! update the head pointer by
	stw	%g5, [%g2 + LDC_TX_QHEAD]	! one and store the new value.
	mov	%g7, %g2

		!! %g1 call back arg
		!! %g2 payload PA
		!! %g6 callback
		!! %g7 return addr

 	jmp	%g6					! invoke callback
	  rd	%pc, %g7

	! Guest may have incrimented the tail pointer by more than one
	! element and so now we must check to see whether the queue is
	! empty. If not, we will have to invoke the callback again.

	GUEST_STRUCT(%g1)
	mulx	%o0, LDC_ENDPOINT_SIZE, %g2
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g2
	add	%g2, %g1, %g2

	!! %g1 guest
	!! %g2 endpoint

	lduw	[%g2 + LDC_TX_QHEAD], %g3
	lduw	[%g2 + LDC_TX_QTAIL], %g4
	ldx	[%g2 + LDC_TX_QBASE_PA], %g7	! save this off for now
	cmp	%g3, %g4			! Is Q empty now?
	bne,pn	%xcc, .ldc_tx_set_qtail_hv
	  nop

	! If Q is empty, we are done.
	ba	.ldc_tx_set_qtail_done
	  nop

.guest_target:

	!
	! guest <-> guest connection
	!

	mov	%o1, %g1

		!! %g1 new tail value
		!! %g2 sender's endpoint

	HVCALL(guest_to_guest_tx_set_tail)	! clobbers all %g1,%g3-%g7

		!! %g2 sender's endpoint

.ldc_tx_set_qtail_done:

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_tx_set_qtail)

/*
 * ldc_rx_qconf
 *
 * arg0 channel		(%o0)
 * arg1 q base raddr	(%o1) - must be aligned to size of queue
 * arg2 size (#entries)	(%o2) - must be power of 2 (or 0 to unconfigure queue)
 * --
 * ret0 status		(%o0)
 *
 * Configure receive queue for LDC endpoint.
 */
	ENTRY_NP(hcall_ldc_rx_qconf)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)	! %g1 guest, %g2 endpoint

	brz,pn	%o2, 2f	! size of 0 unconfigures queue
	  nop

	! number of entries must be a power of 2
	sub	%o2, 1, %g3
	and	%o2, %g3, %g3
	brnz,pn	%g3, herr_inval
	  nop

	sllx    %o2, Q_EL_SIZE_SHIFT, %g4       ! convert #entries to bytes

	! queue raddr must be aligned to size of queue
	sub	%g4, 1, %g5
	btst	%g5, %o1
	bnz,pn	%xcc, herr_badalign		! base addr not aligned ?
	  nop

	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %g4, herr_noraddr, %g6, %g5)

	! Note:	 The guest can flush a RX queue by (re)configuring it.
	! If this happens, we still want to make sure that the the
	! head/tail pointer consistency is maintained between the two
	! guests and so we mark the queue empty without moving the
	! tail pointer. Note that the tail pointer is set to zero at
	! start of day.
	!
	! We do, however, need to make sure the new tail value is not
	! larger than the size of the queue in case the guest is switching
	! to a smaller queue.

	stx	%o1, [%g2 + LDC_RX_QBASE_RA]
	stx	%g5, [%g2 + LDC_RX_QBASE_PA]
	lduw	[%g2 + LDC_RX_QTAIL], %g6	! read existing tail
	sub	%g4, Q_EL_SIZE, %g5
	sub	%g5, %g6, %g5			! bigger than qsize?
	movrlz	%g5, %g0, %g6			! if so, we have to zero
	brlz,a	%g5, 1f				! the head and tail pointer
	  stw	%g6, [%g2 + LDC_RX_QTAIL]
1:
	stw	%g6, [%g2 + LDC_RX_QHEAD]
2:

	ldub	[%g2 + LDC_TARGET_TYPE], %g3
	cmp	%g3, LDC_SP_ENDPOINT

#ifdef CONFIG_FPGA
	! args:
	!! %o0 - arg0 channel
	!! %o1 - arg1 q base raddr
	!! %o2 - arg2 size (#entries)
	!! %g2 - endpoint
	!! %g4 - new RX_QSIZE value if arg2 != 0
	be,pn	%xcc, sp_ldc_update_link_status	! returns directly to guest
	  nop
#else
	be,pn	%xcc, herr_inval		! should't be using SRAM LDC
	  nop
#endif

	brz,pn	%o2, 3f	! new qsize of 0 unconfigures queue
	  nop

	mov	1, %g5
	ldx	[%g2 + LDC_RX_QSIZE], %g6	! read existing size
	brnz,a	%g6, 2f
	  stb	%g5, [%g2 + LDC_RX_UPDATED]	! if size not zero, set updated
2:
	stx	%g4, [%g2 + LDC_RX_QSIZE]	! set last if Q being configured

	ba	4f				! notify
	  nop
3:
	! All we need to do is set the qsize to zero if the queue is
	! being un-configured.
	!
	! Note: we specifically no NOT clear the LDC_RX_QBASE_PA field
	! because doing so could introduce a security hole.

	ldx	[%g2 + LDC_RX_QSIZE], %g6	! read existing size
	stx	%g0, [%g2 + LDC_RX_QSIZE]
	brz,pn	%g6, 5f				! if existing size=0, return
	  nop

	mov	1, %g5
	stb	%g5, [%g2 + LDC_RX_UPDATED]	! else set updated, & notify
4:
	ldub	[%g2 + LDC_TARGET_TYPE], %g3
	cmp	%g3, LDC_GUEST_ENDPOINT
	bne,pt	%xcc, 5f
	  nop

	ldx	[%g2 + LDC_TARGET_GUEST], %g4
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g3
	mulx	%g3, LDC_ENDPOINT_SIZE, %g3
	add	%g3, %g4, %g3
	set	GUEST_LDC_ENDPOINT, %g6
	add	%g6, %g3, %g3			! Target endpt struct

	ldx	[%g3 + LDC_RX_MAPREG + LDC_MAPREG_CPUP], %g4
	brz,pn	%g4, 5f
	  nop

	!! %g2 - this endpoint struct
	!! %g3 - target endpoint struct
	!! %g4 - target CPU
	!! %g5 - scratch
	!! %g6 - scratch
	!
	! Notify the other end that this endpoint's
	! Rx queue was reconfigured
	!
	HVCALL(hv_ldc_cpu_notify)
5:
	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_rx_qconf)

/*
 * ldc_rx_qinfo
 *
 * arg0 channel		(%o0)
 * --
 * ret0 status		(%o0)
 * ret1 q base raddr	(%o1)
 * ret2 size (#entries)	(%o2)
 *
 * Return information about the LDC endpoint's receive queue.
 */
	ENTRY_NP(hcall_ldc_rx_qinfo)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)	! %g1 guest, %g2 endpoint

	ldx	[%g2 + LDC_RX_QBASE_RA], %o1
	ldx	[%g2 + LDC_RX_QSIZE], %g4
	srlx	%g4, Q_EL_SIZE_SHIFT, %o2
	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_rx_qinfo)

/*
 * guest_to_guest_pull_data
 *
 * Input:
 *    %g2 - receiver's endpoint (preserved)
 *
 * Clobbers:
 *    %g1, %g3-7
 *
 * Pulls queue data (if available) from the target endpoint's TX queue
 * into this specified endpoint's RX queue.
 *
 */
	ENTRY_NP(guest_to_guest_pull_data)

		!! %g2 our endpoint

	! We will need to clobber some additional registers so save them
	STRAND_PUSH(%g7, %g3, %g4)
	STRAND_PUSH(%o1, %g3, %g4)
	STRAND_PUSH(%o2, %g3, %g4)
	STRAND_PUSH(%o3, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)

	ldx	[%g2 + LDC_TARGET_GUEST], %g1		! find sender's guest
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g3	! and it's endpoint
	mulx	%g3, LDC_ENDPOINT_SIZE, %g4
	add	%g1, %g4, %g1
	set	GUEST_LDC_ENDPOINT, %g6
	add	%g6, %g1, %g1
	ldx	[%g1 + LDC_TX_QSIZE], %g6	! no TX Q configured ? Then
	brz,pn	%g6, .done_copying_data		! there is no data to pull over
	  nop

	! limit each call to copying a certain number of packets so as to
	! not keep the CPU stuck in the hypervisor for too long.
	set	(LDC_MAX_PKT_COPY * Q_EL_SIZE), %g7

.copy_more_data:

	! make sure we are not trying to send more packets than
	! allowed per hcall.
	brlez	%g7, .done_copying_data
	  nop

	!! %g1 sender's endpoint
	!! %g2 our endpoint

	lduw	[%g1 + LDC_TX_QHEAD], %g3
	lduw	[%g1 + LDC_TX_QTAIL], %g4

	sub	%g4, %g3, %g4			! check (tail - head) value.
	brz	%g4, .done_copying_data		! if zero, nothing to copy
	  nop					! since TX Q is empty.

	brgz	%g4, 1f				! If non-negative, then that's
	  nop					! how many bytes we need to
						! copy from the TX Q.

	ldx	[%g1 + LDC_TX_QSIZE], %g5	! Else, we need to copy
	sub	%g5, %g3, %g4			! (size - head) bytes from TX Q

1:
	!! %g1 sender's endpoint
	!! %g2 our endpoint
	!! %g3 sender's head pointer
	!! %g4 bytes of data to copy

	lduw	[%g2 + LDC_RX_QHEAD], %o1
	lduw	[%g2 + LDC_RX_QTAIL], %g6

	sub	%o1, %g6, %g5
	sub	%g5, Q_EL_SIZE, %g5
	brgez	%g5, 1f				! If non-negative, then that's
	  nop					! how many bytes we are able
						! to copy into our RX Q.

	ldx	[%g2 + LDC_RX_QSIZE], %g5	! our current RX Q size
	sub	%g5, %g6, %g5
	brnz	%o1, 1f				! but we can't fill our Q
	  nop					! completely so we must
	sub	%g5, Q_EL_SIZE, %g5		! subtract if head is zero.
1:
	brz	%g5, .done_copying_data		! if zero, nothing to copy
	  nop					! since our RX Q is full.

	!! %g1 sender's endpoint
	!! %g2 our endpoint
	!! %g3 sender's head pointer
	!! %g4 bytes of data to copy (sender)
	!! %g5 bytes of data to copy (receiver)
	!! %g6 our tail pointer

	! find the lesser of the two copy size values
	sub	%g4, %g5, %o1
	movrgez	%o1, %g5, %g4

	! make sure we don't copy more packets than allowed per hcall
	sub	%g7, %g4, %g5
	brgz,a	%g5, 1f		! if we haven't yet sent the max allowed pkts,
	  mov	%g5, %g7	! then simply update our counter and continue.

	! trying to copy more packets than (or exactly as many packets as)
	! allowed per hcall.
	mov	%g7, %g4	! limit the number of bytes about to be copied
	clr	%g7		! update our counter
1:
	mov	%g3, %o2	! save off the original tx head
	mov	%g6, %o3	! and rx tail values.

	ldx	[%g1 + LDC_TX_QBASE_PA], %o1
	add	%g3, %o1, %g3
	ldx	[%g2 + LDC_RX_QBASE_PA], %o1
	add	%g6, %o1, %g6

	sub	%g4, 8, %o1			! use as loop index

1:
	ldx	[%g3], %g5			! read data from TX Q head
	stx	%g5, [%g6]			! write data to RX Q tail
	add	%g3, 8, %g3			! incriment head pointer
	sub	%o1, 8, %o1
	brgez,pt %o1, 1b			! loop until done.
	  add	%g6, 8, %g6			! incriment tail pointer

	! Now we need to update our head and tail pointers
	ldx	[%g2 + LDC_RX_QSIZE], %g5
	dec	Q_EL_SIZE, %g5
	add	%o3, %g4, %o3
	and	%o3, %g5, %g5
	stw	%g5, [%g2 + LDC_RX_QTAIL]

	ldx	[%g1 + LDC_TX_QSIZE], %g5
	dec	Q_EL_SIZE, %g5
	add	%o2, %g4, %o2
	and	%o2, %g5, %g5
	stw	%g5, [%g1 + LDC_TX_QHEAD]

	!! %g1 sender's endpoint
	!! %g2 our endpoint
	!! %g4 bytes of data that were copied

	ba,a	.copy_more_data

.done_copying_data:

		!! %g1 sender's endpoint
		!! %g2 our endpoint

	! We might need to send a 'queue no longer full' interrupt
	! in certain situations.
	ldub	[%g1 + LDC_TXQ_FULL], %g3
	brz,pt	%g3, 1f
	  nop
	stb	%g0, [%g1 + LDC_TXQ_FULL]

	ldx	[%g1 + LDC_RX_VINTR_COOKIE], %g1
	brz	%g1, 1f
	  nop

	HVCALL(vdev_intr_generate)
1:
	! Restore registers we were not supposed to clobber.
	STRAND_POP(%g2, %g3)
	STRAND_POP(%o3, %g3)
	STRAND_POP(%o2, %g3)
	STRAND_POP(%o1, %g3)
	STRAND_POP(%g7, %g3)

	HVRET
	SET_SIZE(guest_to_guest_pull_data)

/*
 * ldc_rx_get_state
 *
 * arg0 channel		(%o0)
 * --
 * ret0 status		(%o0)
 * ret1 head offset	(%o1)
 * ret2 tail offset	(%o2)
 * ret3 channel state	(%o3)
 *
 * Return information about the current state of the queue.
 */
	ENTRY_NP(hcall_ldc_rx_get_state)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)	! %g1 guest, %g2 endpoint

	ldx	[%g2 + LDC_RX_QSIZE], %g3	! no Q configured ?
	brz,pn	%g3, herr_inval
	  nop

	! At this point (if the other end is a guest or SP) we want to go
	! and check the other transmit queue and see if there is any data
	! to pull into our recieve queue.

	ldub	[%g2 + LDC_TARGET_TYPE], %g3
	cmp	%g3, LDC_HV_ENDPOINT
	be,a,pn	%xcc, 3f
	  mov	LDC_CHANNEL_UP, %o3
	cmp	%g3, LDC_SP_ENDPOINT
	be	%xcc, 2f
	  nop

	!! %g2 guest endpoint (preserved)
	HVCALL(guest_to_guest_pull_data)	! clobbers all %g1,%g3-%g7

	GET_GUEST_QUEUE_STATUS(%g2, %o3, %g1)
	ba	3f
	  nop
2:
	!! %g2 guest endpoint (preserved)
	HVCALL(sp_to_guest_pull_data)		! clobbers all %g1,%g3-%g7

	GET_SP_QUEUE_STATUS(%g2, %o3, %g4)

3:
	lduw	[%g2 + LDC_RX_QHEAD], %o1
	lduw	[%g2 + LDC_RX_QTAIL], %o2

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_rx_get_state)


/*
 * ldc_rx_set_qhead
 *
 * arg0 channel		(%o0)
 * arg1 head offset	(%o1)
 * --
 * ret0 status		(%o0)
 *
 * Used by the guest to indicate that it has received the packet(s).
 */
	ENTRY_NP(hcall_ldc_rx_set_qhead)

	! verifies channel ID, returns pointers to guest and ldc_endpoint
	!! %g1 guest
	!! %g2 endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g2)

	! new head offset must be aligned properly
	andcc	%o1, Q_EL_SIZE-1, %g0
	bnz,pn	%xcc, herr_badalign
	  nop

	! Receive queue configured?
	ldx	[%g2 + LDC_RX_QSIZE], %g3
	brz,pn	%g3, herr_inval
	  nop

	! new head offset must be within range
	cmp	%g3, %o1
	bleu,pn	%xcc, herr_inval	! offset bigger than Q or less than 0?
	  nop

	!! %g1 guest
	!! %g2 our endpoint
	!! %g3 our Q size

	! verify new head value makes sense with respect to the old head/tail
	lduw	[%g2 + LDC_RX_QHEAD], %g3
	lduw	[%g2 + LDC_RX_QTAIL], %g4
	cmp	%g3, %g4
	bl	%xcc, 1f
	  nop

	! head > tail i.e queue data currently wraps around end of queue
	! verify ((new_head > head) || (new_head <= tail))
	cmp	%o1, %g3
	bg	%xcc, 2f
	cmp	%o1, %g4
	ble	%xcc, 2f
	  nop
	ba	herr_inval	! invalid head value
	  nop

1:	! tail >= head  i.e. queue data not yet wrapped or queue empty
	! verify ((new_head > head) && (new_head <= tail))
	cmp	%o1, %g3
	ble,pn	%xcc, herr_inval
	cmp	%o1, %g4
	bg,pn	%xcc, herr_inval
	  nop

2:	! input values verified

	!! %g1 guest
	!! %g2 our endpoint
	!! %g3 initial head

	stw	%o1, [%g2 + LDC_RX_QHEAD]

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_rx_set_qhead)


#ifdef CONFIG_FPGA

/*
 * sp_ldc_update_link_status
 *
 * arg0 channel		(%o0)
 * arg1 q base raddr	(%o1)
 * arg2 size (#entries)	(%o2)
 * --
 * ret0 status		(%o0)
 *
 * Additionally, we are passed the following arguments:
 *
 *   %g2 endpoint
 *   %g4 new RX_QSIZE value if arg2 != 0
 *
 * Called by the rx_qconf API routine for guest<->sp connections. The guest's
 * head/tail pointers have already been updated at this point. The only
 * things left to do here is:
 *
 *  - update the rx_qsize field for this endpoint based on %o2/%g4
 *  - update the SRAM link status fields and possibly send interrupt to SP
 *  - return directly to guest
 *
 * N.B. It is important that we return directly to the guest from this
 * routine (using HCALL_RET or the like). %g7 does not contain a return
 * value to which we can branch.
 */
	ENTRY_NP(sp_ldc_update_link_status)

	!! %g2 guest endpoint
	!! %g4 new rx_qsize value

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SP_LDCS], %g1
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g3
	mulx	%g3, SP_LDC_ENDPOINT_SIZE, %g3
	add	%g1, %g3, %g1			! target endpoint
	ldx	[%g1 + SP_LDC_RX_QD_PA], %g1	! QD ptr to SRAM

	!! %g1 SRAM QD
	!! %g2 guest endpoint
	!! %g4 new rx_qsize value

	brz,pn	%o2, 2f	! was guest trying to un-configure the queue?
	  nop

	mov	1, %g3
	ldx	[%g2 + LDC_RX_QSIZE], %g6	! reflects our link status
	brnz,a	%g6, 1f				! if status is not DOWN
	  stb	%g3, [%g1 + SRAM_LDC_STATE_UPDATED] ! then set "updated" flag
1:
	stx	%g4, [%g2 + LDC_RX_QSIZE]	! Store the new qsize value
	stb	%g3, [%g1 + SRAM_LDC_STATE]	! link status = UP

	ba	3f				! send notification to SP
	  nop
2:
	! All we need to do is set the qsize to zero if the queue is
	! being un-configured.
	!
	! Note: we specifically no NOT clear the LDC_RX_QBASE_PA field
	! because doing so could introduce a security hole.

	ldx	[%g2 + LDC_RX_QSIZE], %g3	! read existing size
	stb	%g0, [%g1 + SRAM_LDC_STATE]	! link status = DOWN
	stx	%g0, [%g2 + LDC_RX_QSIZE]
	brz,pn	%g3, 5f				! if existing size=0, return
	  nop					! without sending interrupt

	mov	1, %g3				! set the "updated" flag
	stb	%g3, [%g1 + SRAM_LDC_STATE_UPDATED]

3:
	!! %g1 SRAM QD
	!! %g2 guest endpoint
	!! %g3 1

	stb	%g3, [%g1 + SRAM_LDC_STATE_NOTIFY]

	! Send notification interrupt to the SP
	! %g2	target endpoint (clobbered)
	LDC_SEND_SP_INTR(%g2, %g3, %g4, SP_LDC_STATE_CHG)
5:
	HCALL_RET(EOK)
	SET_SIZE(sp_ldc_update_link_status)


/*
 * guest_to_sp_tx_set_tail
 *
 * %g1 new tail value
 * %g2 sender's endpoint
 *
 * Increments the guest TX tail pointer and sends notification to the
 * SP if necessary.
 *
 * Note: It is important that the caller has already verifed that the
 * new tail value is valid given the current state of the queue.
 *
 */
	ENTRY_NP(guest_to_sp_tx_set_tail)

		!! %g1 new tail value
		!! %g2 sender's endpoint

	ROOT_STRUCT(%g3)
	ldx	[%g3 + CONFIG_SP_LDCS], %g3		! get SP endpoint array
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g4 	! and target endpoint
	mulx	%g4, SP_LDC_ENDPOINT_SIZE, %g5
	add	%g3, %g5, %g3				! and its struct

	stw	%g1, [%g2 + LDC_TX_QTAIL]		! update the tail

	STRAND_PUSH(%g2, %g4, %g5)			! save off pointer

		!! %g2 guest endpoint
		!! %g3 sp endpoint

	add	%g3, SP_LDC_TX_LOCK, %g5
	SPINLOCK_ENTER(%g5, %g6, %g4)

        STRAND_PUSH(%g7, %g4, %g5)
	HVCALL(sram_ldc_push_data)	!! %g3 (sp endpoint) preserved
        STRAND_POP(%g7, %g5)

	add	%g3, SP_LDC_TX_LOCK, %g5
	SPINLOCK_EXIT(%g5)

	!! %g2 send interrupt flag
	!! %g3 sp endpoint

	brz	%g2, 1f		! skip notification if flag is clear
	  nop

	! %g3	target endpoint (clobbered)
	LDC_SEND_SP_INTR(%g3, %g1, %g4, SP_LDC_DATA)
1:

	STRAND_POP(%g2, %g4)				! restore pointer

	!! %g2 sender's endpoint

	HVRET
	SET_SIZE(guest_to_sp_tx_set_tail)


/*
 * sp_to_guest_pull_data
 *
 * Input:
 *    %g2 guest (receiver) endpoint (preserved)
 *
 * Clobbers:
 *    %g1, %g3-7
 *
 * Pulls queue data (if available) from the target SP endpoint's TX queue
 * into the specified guest endpoint's RX queue.
 *
 */
	ENTRY_NP(sp_to_guest_pull_data)

	!! %g2 guest endpoint

	! save off our return %pc value
	STRAND_PUSH(%g7, %g3, %g4)

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SP_LDCS], %g1		! get SP endpoint array
	ldx	[%g2 + LDC_TARGET_CHANNEL], %g4 	! and target endpoint
	mulx	%g4, SP_LDC_ENDPOINT_SIZE, %g5
	add	%g1, %g5, %g1				! and its struct

	!! %g1 sp endpoint
	!! %g2 guest endpoint

	! quick check to see whether there are any packets
	! to grab on this channel.

	ldx	[%g1 + SP_LDC_RX_QD_PA], %g3
	ldub	[%g3 + SRAM_LDC_HEAD], %g4
	ldub	[%g3 + SRAM_LDC_TAIL], %g5
	cmp	%g4, %g5
	be	%xcc, 2f
	  nop

	clr	%g6					! "send ACK" flag

	!! %g1 sp endpoint
	!! %g2 guest endpoint
	!! %g6 "send ACK" flag

	add	%g1, SP_LDC_RX_LOCK, %g3		! PA of endpoint lock
	SPINLOCK_ENTER(%g3, %g4, %g5)

	! snapshot queue state into our scratch register area
	! since we will be copying the data in possibly several
	! passes and we want to ensure the guest cannot cause any
	! HV corruption by reconfiguring the queue while we are
	! executing this routine.

	ldx	[%g1 + SP_LDC_RX_QD_PA], %g5
	ldub	[%g5 + SRAM_LDC_HEAD], %g3
	LDC_SRAM_IDX_TO_OFFSET(%g3)
	stw	%g3, [%g1 + SP_LDC_RX_SCR_TXHEAD]	! TX head
	ldub	[%g5 + SRAM_LDC_TAIL], %g3
	LDC_SRAM_IDX_TO_OFFSET(%g3)
	stw	%g3, [%g1 + SP_LDC_RX_SCR_TXTAIL]	! TX tail
	set	(SRAM_LDC_QENTRY_SIZE * SRAM_LDC_ENTRIES_PER_QUEUE), %g3
	stx	%g3, [ %g1 + SP_LDC_RX_SCR_TXSIZE ]	! TX size
#ifdef CONFIG_SPLIT_SRAM
	stx	%g5, [ %g1 + SP_LDC_RX_SCR_TX_QDPA ]	! TX queue data PA
	ldx	[ %g1 + SP_LDC_RX_Q_DATA_PA ], %g5
#endif
	stx	%g5, [ %g1 + SP_LDC_RX_SCR_TX_QPA ]	! TX queue base PA

	!! %g1 SP endpoint
	!! %g2 guest endpoint

	stx	%g2, [%g1 + SP_LDC_RX_SCR_TARGET]

	lduw	[%g2 + LDC_RX_QTAIL], %g4
	stw	%g4, [%g1 + SP_LDC_RX_SCR_RXTAIL]	! RX tail
	lduw	[%g2 + LDC_RX_QHEAD], %g4
	stw	%g4, [%g1 + SP_LDC_RX_SCR_RXHEAD]	! RX head
	ldx	[%g2 + LDC_RX_QSIZE], %g4
	stx	%g4, [%g1 + SP_LDC_RX_SCR_RXSIZE]	! RX size
	ldx	[%g2 + LDC_RX_QBASE_PA], %g4
	stx	%g4, [%g1 + SP_LDC_RX_SCR_RX_QPA]	! RX queue base PA

.copy_more_from_sram:

	!! %g1 sp endpoint

	lduw	[%g1 + SP_LDC_RX_SCR_TXHEAD], %g2
	lduw	[%g1 + SP_LDC_RX_SCR_TXTAIL], %g3
	ldx	[%g1 + SP_LDC_RX_SCR_TXSIZE], %g4
	LDC_QUEUE_DATA_AVAILABLE(%g2, %g3, %g4)
	LDC_SRAM_OFFSET_TO_IDX(%g3)

	!! %g1 sp endpoint
	!! %g2 TX head offset
	!! %g3 packets of data to copy

	lduw	[%g1 + SP_LDC_RX_SCR_RXHEAD], %g4
	lduw	[%g1 + SP_LDC_RX_SCR_RXTAIL], %g5
	ldx	[%g1 + SP_LDC_RX_SCR_RXSIZE], %g7
	LDC_QUEUE_SPACE_AVAILABLE(%g4, %g5, %g7, Q_EL_SIZE)
	LDC_OFFSET_TO_IDX(%g4)

	!! %g1 sp endpoint
	!! %g2 TX head offset
	!! %g3 packets of data to copy
	!! %g4 packets of available space
	!! %g5 RX tail offset

	! find the lesser of the two copy size values
	sub	%g3, %g4, %g7
	movrgez	%g7, %g4, %g3

	! must have at least one LDC packet to copy, otherwise we are done.
	brlez	%g3, .done_copy_from_sram
	  nop

	mov	1, %g6				! "send ACK" flag

	!! %g1 sp endpoint
	!! %g2 TX head offset
	!! %g3 packets of data to copy
	!! %g5 RX tail offset

	ldx	[%g1 + SP_LDC_RX_SCR_TX_QPA], %g4
	add	%g2, %g4, %g2			! PA of TX queue data
	ldx	[%g1 + SP_LDC_RX_SCR_RX_QPA], %g4
	add	%g5, %g4, %g5			! PA of RX queue tail

	!! %g1 sp endpoint
	!! %g2 TX head PA
	!! %g3 packets of data to copy
	!! %g5 RX tail PA

	sub	%g3, 1, %g3			! use as loop index
1:
	LDC_COPY_PKT_FROM_SRAM(%g2, %g5, %g4, %g7)
	brgz	%g3, 1b
	  dec	%g3

	!! %g1 sp endpoint
	!! %g2 new TX head PA
	!! %g5 new RX tail PA

	! Now we need to update our scratchpad head and tail pointers
	ldx	[%g1 + SP_LDC_RX_SCR_TX_QPA], %g7
	sub	%g2, %g7, %g2			! New TX head offset
	ldx	[%g1 + SP_LDC_RX_SCR_TXSIZE], %g7
	cmp	%g2, %g7
	move	%xcc, 0, %g2			! check for wrap around
	stw	%g2, [%g1 + SP_LDC_RX_SCR_TXHEAD]

	ldx	[%g1 + SP_LDC_RX_SCR_RX_QPA], %g7
	sub	%g5, %g7, %g5			! New RX tail offset
	ldx	[%g1 + SP_LDC_RX_SCR_RXSIZE], %g7
	cmp	%g5, %g7
	move	%xcc, 0, %g5			! check for wrap around
	stw	%g5, [%g1 + SP_LDC_RX_SCR_RXTAIL]

	!! %g1 sp endpoint

	ba	.copy_more_from_sram
	  nop

.done_copy_from_sram:

	!! %g1 sp endpoint

#ifdef CONFIG_SPLIT_SRAM
	ldx	[ %g1 + SP_LDC_RX_SCR_TX_QDPA ], %g4	! queue data PA
#else
	ldx	[ %g1 + SP_LDC_RX_SCR_TX_QPA ], %g4	! queue base PA
#endif
	lduw	[ %g1 + SP_LDC_RX_SCR_TXHEAD ], %g3
	LDC_SRAM_OFFSET_TO_IDX(%g3)
	stb	%g3, [%g4 + SRAM_LDC_HEAD]	! commit the new TX head

	ldx	[%g1 + SP_LDC_RX_SCR_TARGET], %g2
	lduw	[%g1 + SP_LDC_RX_SCR_RXTAIL], %g5
	stw	%g5, [%g2 + LDC_RX_QTAIL]	! commit the new RX tail

	add	%g1, SP_LDC_RX_LOCK, %g5		! PA of endpoint lock
	SPINLOCK_EXIT(%g5)

	! Send the SP an ACK if we have pulled data from the SRAM
	brz	%g6, 2f
	  nop

	mov	%g1, %g6
	! %g6	target endpoint (clobbered)
	LDC_SEND_SP_INTR(%g6, %g3, %g4, SP_LDC_SPACE)

2:
		!! %g1 sender's (sp) endpoint
		!! %g2 our endpoint

	! restore our return %pc value
	STRAND_POP(%g7, %g3)

	HVRET
	SET_SIZE(sp_to_guest_pull_data)

/*
 * sram_ldc_push_data
 *
 * Routine to send as much data as possible from a guest's TX queue
 * into the corresponding SRAM RX queue.
 *
 * NOTE: caller must own the SP endpoint TX lock before calling this
 *       routine
 *
 * Inputs:
 *    %g2 guest endpoint (modified)
 *    %g3 sp endpoint (unmodified)
 *    %g7 return %pc value (unmodified)
 *
 * Output:
 *    %g2 '1' if interrupt notification is required, 0 otherwise.
 *
 * Clobbers all globals except %g3 and %g7
*/
	ENTRY_NP(sram_ldc_push_data)

	!! %g2 guest endpoint
	!! %g3 sp endpoint

	lduw	[%g2 + LDC_TX_QTAIL], %g4
	stw	%g4, [%g3 + SP_LDC_TX_SCR_TXTAIL]	! TX tail
	lduw	[%g2 + LDC_TX_QHEAD], %g4
 	stw	%g4, [%g3 + SP_LDC_TX_SCR_TXHEAD]	! TX head
	ldx	[%g2 + LDC_TX_QSIZE], %g4
	stx	%g4, [%g3 + SP_LDC_TX_SCR_TXSIZE]	! TX size
	ldx	[%g2 + LDC_TX_QBASE_PA], %g4
	stx	%g4, [%g3 + SP_LDC_TX_SCR_TX_QPA]	! TX q base PA
	ldx	[%g3 + SP_LDC_TX_QD_PA], %g4
	ldub	[%g4 + SRAM_LDC_HEAD], %g5
	LDC_SRAM_IDX_TO_OFFSET(%g5)
	stw	%g5, [%g3 + SP_LDC_TX_SCR_RXHEAD]	! RX head
	ldub	[%g4 + SRAM_LDC_TAIL], %g5
	LDC_SRAM_IDX_TO_OFFSET(%g5)
	stw	%g5, [%g3 + SP_LDC_TX_SCR_RXTAIL]	! RX tail
	set	(SRAM_LDC_QENTRY_SIZE*SRAM_LDC_ENTRIES_PER_QUEUE), %g5
	stx	%g5, [ %g3 + SP_LDC_TX_SCR_RXSIZE ]	! RX size
#ifdef CONFIG_SPLIT_SRAM
	stx	%g4, [ %g3 + SP_LDC_TX_SCR_RX_QDPA ]	! RX qd data PA
	ldx	[ %g3 + SP_LDC_TX_Q_DATA_PA ], %g4
#endif
	stx	%g4, [ %g3 + SP_LDC_TX_SCR_RX_QPA ]	! RX q base PA
	stx	%g2, [ %g3 + SP_LDC_TX_SCR_TARGET ]
1:
	!! %g3 sp endpoint

	lduw	[%g3 + SP_LDC_TX_SCR_TXHEAD], %g4
	lduw	[%g3 + SP_LDC_TX_SCR_TXTAIL], %g6
	ldx	[%g3 + SP_LDC_TX_SCR_TXSIZE], %g2
	LDC_QUEUE_DATA_AVAILABLE(%g4, %g6, %g2)
	LDC_OFFSET_TO_IDX(%g6)

	!! %g3 sp endpoint
	!! %g4 TX head pointer
	!! %g6 packets of data to copy

	lduw	[%g3 + SP_LDC_TX_SCR_RXHEAD], %g5
	lduw	[%g3 + SP_LDC_TX_SCR_RXTAIL], %g1
	ldx	[%g3 + SP_LDC_TX_SCR_RXSIZE], %g2
	LDC_QUEUE_SPACE_AVAILABLE(%g5, %g1, %g2, SRAM_LDC_QENTRY_SIZE)
	LDC_SRAM_OFFSET_TO_IDX(%g5)

	!! %g1 RX tail pointer
	!! %g3 sp endpoint
	!! %g4 TX head pointer
	!! %g5 packets of space available
	!! %g6 packets of data to copy

	/*
	 * find the lesser of the two copy size values
	 */
	sub	%g6, %g5, %g2
	movrgez	%g2, %g5, %g6

	/*
	 * must have at least one LDC packet to copy,
	 * otherwise we are done.
	 */
	brlez	%g6, 3f
	nop
	ldx	[%g3 + SP_LDC_TX_SCR_TX_QPA], %g5
	add	%g4, %g5, %g4				! PA of TX queue data
	ldx	[%g3 + SP_LDC_TX_SCR_RX_QPA], %g5
	add	%g1, %g5, %g1				! PA of RX queue tail

	!! %g1 RX tail PA
	!! %g3 sp endpoint
	!! %g4 TX head PA
	!! %g6 packets of data to copy
	sub	%g6, 1, %g6				! use as loop index
2:
	LDC_COPY_PKT_TO_SRAM(%g4, %g1, %g5, %g2)	! moves pointers
	brgz	%g6, 2b
	dec	%g6

	!! %g1 new RX tail PA
	!! %g3 sp endpoint
	!! %g4 new TX head PA

	/*
	 * Now we need to update our scratchpad head/tail pointers
	 */
	ldx	[%g3 + SP_LDC_TX_SCR_TX_QPA], %g5
	sub	%g4, %g5, %g4			! New TX head offset
	ldx	[%g3 + SP_LDC_TX_SCR_TXSIZE], %g5
	cmp	%g4, %g5
	move	%xcc, 0, %g4			! check for wrap around
	stw	%g4, [%g3 + SP_LDC_TX_SCR_TXHEAD]
	ldx	[%g3 + SP_LDC_TX_SCR_RX_QPA], %g5
	sub	%g1, %g5, %g1			!  New RX tail offset
	ldx	[%g3 + SP_LDC_TX_SCR_RXSIZE], %g5
	cmp	%g1, %g5
	move	%xcc, 0, %g1			! check for wrap around
	stw	%g1, [%g3 + SP_LDC_TX_SCR_RXTAIL]

	ba	1b
	nop
3:
	ldx	[%g3 + SP_LDC_TX_SCR_TARGET], %g2

	!! %g2 guest endpoint
	!! %g3 sp endpoint

	/*
	 * Write new TX head and RX tail values and see whether we
	 * need to send the SP notification
	 * We only send notification if the RX queue was empty. The
	 * algorithm we use to avoid missed interrupts is as
	 *  follows:
	 * Read orig RX head (orig_rx_hd)
	 * Read orig RX tail (orig_rx_tl)
	 * Write new RX tail value
	 * Read (possibly) new RX head (new_rx_hd)
	 * if ((orig_rx_hd==orig_rx_tl)||(new_rx_hd==orig_rx_tl)) {
	 *	notify SP
	 * }
	 */
	lduw	[ %g3 + SP_LDC_TX_SCR_TXHEAD ], %g6
	stw	%g6, [ %g2 + LDC_TX_QHEAD ]	! commit new TX head
#ifdef CONFIG_SPLIT_SRAM
	ldx	[ %g3 + SP_LDC_TX_SCR_RX_QDPA ], %g4	! queue data PA
#else
	ldx	[ %g3 + SP_LDC_TX_SCR_RX_QPA ], %g4	! queue base PA
#endif
	ldub	[ %g4 + SRAM_LDC_HEAD ], %g5
	LDC_SRAM_IDX_TO_OFFSET(%g5)
	ldub	[%g4 + SRAM_LDC_TAIL], %g1
	LDC_SRAM_IDX_TO_OFFSET(%g1)

	!! %g1 old RX tail
	!! %g3 sp endpoint
	!! %g4 RX queue descriptor
	!! %g5 old RX head

	lduw	[%g3 + SP_LDC_TX_SCR_RXTAIL], %g6
	LDC_SRAM_OFFSET_TO_IDX(%g6)
	stb	%g6, [%g4 + SRAM_LDC_TAIL]	! commit new RX tail
	ldub	[%g4 + SRAM_LDC_HEAD], %g4
	LDC_SRAM_IDX_TO_OFFSET(%g4)

	!! %g1 old RX tail
	!! %g3 sp endpoint
	!! %g4 new RX head
	!! %g5 old RX head
	!! %g6 new RX tail

	clr	%g2
	cmp	%g1, %g5	! (orig_rx_tl == orig_rx_hd) ?
	move	%xcc, 1, %g2
	cmp	%g1, %g4	! (orig_rx_tl == new_rx_hd) ?
	move	%xcc, 1, %g2
	cmp	%g1, %g6	! if old rx tail == new rx tail...
	move	%xcc, %g0, %g2	! ...don't sent intr (no data sent)

	!! %g2 send interrupt flag
	!! %g3 sp endpoint

	HVRET
	SET_SIZE(sram_ldc_push_data)


#else	/* CONFIG_FPGA */

	ENTRY_NP(sp_to_guest_pull_data)
	! Should never be invoked if this hypervisor is compiled
	! without the FPGA support.
	ba	herr_inval
	  nop
	SET_SIZE(sp_to_guest_pull_data)

	ENTRY_NP(guest_to_sp_tx_set_tail)
	! Should never be invoked if this hypervisor is compiled
	! without the FPGA support.
	ba	herr_inval
	  nop
	SET_SIZE(guest_to_sp_tx_set_tail)
#endif	/* CONFIG_FPGA */


	/*
	 * LDC set map table
	 * Binds the identified table with the given LDC
	 *
	 *	int ldc_set_map_table(uint64_t channel, uint64_t table_ra,
	 *				uint64_t table_entries);
	 *
	 *	%o0 channel
	 *	%o1 table_ra (0 disables mapping for given channel)
	 *	%o2 table_entries
	 *
	 *	EINVAL		- illegal map table ra
	 *	ECHANNEL	- illegal channel
	 *
	 */
	ENTRY_NP(hcall_ldc_set_map_table)

	btst	(64 - 1), %o1
	bnz,pn	%xcc, herr_badalign		! base addr not aligned ?
	  nop

	! Is Channel legit ?
	GUEST_STRUCT(%g1)
	set	GUEST_LDC_MAX_CHANNEL_IDX, %g2
	ldx	[%g1 + %g2], %g2
	cmp	%o0, %g2
	bgeu,pn	%xcc, herr_invalchan
	  nop

	!! %g1 guest struct

	mulx	%o0, LDC_ENDPOINT_SIZE, %g2
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g2
	add	%g2, %g1, %g2
	ldub	[%g2 + LDC_IS_LIVE], %g3
	brz,pn	%g3, herr_invalchan
	  ldub	[%g2 + LDC_IS_PRIVATE], %g3
	brnz,pn	%g3, herr_invalchan
	  nop

	brz,pn	%o2, 1f				! size of 0 unconfigures table
	  nop

	cmp	%o2, LDC_MIN_MAP_TABLE_ENTRIES	! Table smaller than min size
	blt,pn	%xcc, herr_inval
	  nop

	set	LDC_MAX_MAP_TABLE_ENTRIES, %g4	! Table size bigger than
	cmp	%o2, %g4			! largest index we can store?
	bge,pn	%xcc, herr_inval		! invalid size
	  nop

	sub	%o2, 1, %g4			! Table size is not a ^2
	andcc	%o2, %g4, %g0
	bne,pn	%xcc, herr_inval
	  nop

	sllx	%o2, LDC_MTE_SHIFT, %g4		! convert #entries to bytes
	sub	%g4, 1, %g5

	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %g4, herr_noraddr, %g6, %g5)

	stx	%o1, [%g2 + LDC_MAP_TABLE_RA]
	stx	%g5, [%g2 + LDC_MAP_TABLE_PA]
	stx	%o2, [%g2 + LDC_MAP_TABLE_NENTRIES]
	stx	%g4, [%g2 + LDC_MAP_TABLE_SZ]	! set last - tbl configured

	HCALL_RET(EOK)


1:
	! Remove the map table
	stx	%g0, [%g2 + LDC_MAP_TABLE_SZ]	! set first - tbl unconfigured
	stx	%g0, [%g2 + LDC_MAP_TABLE_NENTRIES]
	stx	%g0, [%g2 + LDC_MAP_TABLE_RA]
	stx	%g0, [%g2 + LDC_MAP_TABLE_PA]

	HCALL_RET(EOK)

	SET_SIZE(hcall_ldc_set_map_table)


/*
 * LDC get map table
 * Returns the map table infor for the given channel number
 *
 *	int ldc_get_map_table(uint64_t channel);
 *
 *	%o0 channel
 *
 *	%o0 status
 *	%o1 base ra
 *	%o2 num entries
 *
 *	ECHANNEL	- illegal channel
 *
 */
	ENTRY_NP(hcall_ldc_get_map_table)

	! Is Channel legit ?
	GUEST_STRUCT(%g1)
	set	GUEST_LDC_MAX_CHANNEL_IDX, %g2
	ldx	[%g1 + %g2], %g2
	cmp	%o0, %g2
	bgeu,pn	%xcc, herr_invalchan
	  nop

	!! %g1 guest struct

	mulx	%o0, LDC_ENDPOINT_SIZE, %g2
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g2
	add	%g2, %g1, %g2
	ldub	[%g2 + LDC_IS_LIVE], %g3
	brz,pn	%g3, herr_invalchan
	  ldub	[%g2 + LDC_IS_PRIVATE], %g3
	brnz,pn	%g3, herr_invalchan
	  nop

	ldx	[%g2 + LDC_MAP_TABLE_NENTRIES], %o2
	ldx	[%g2 + LDC_MAP_TABLE_RA], %o1

	HCALL_RET(EOK)

	SET_SIZE(hcall_ldc_get_map_table)



/*
 * Copy in/out the data from the given cookie_addr
 * for length bytes (multiple of 8) to/from the
 * real address given.
 * flags=0 for copyin (remote cookie buffer to local real),
 * flags=1 for copyout (local real to remote cookie buffer)
 * For EOK actual length copied is returned.
 *
 *	int ldc_copy(ldc_channel_t chan,
 *		uint64_t flags,
 *		uint64_t cookie_addr,
 *		uint64_t raddr,
 *		uint64_t length,
 *		uint64_t * lengthp);
 *
 *	%o0 channel
 *	%o1 flags
 *	%o2 cookieaddr
 *	%o3 raddr
 *	%o4 length
 *
 *	On EOK length copied is in %o1
 *
 *	ECHANNEL	- illegal channel
 *	ENOMAP		- illegal / invalid cookie addr
 *	ENORADDR	- illegal raddr to raddr+length
 *	EBADALIGN	- badly aligned raddr or cookie_addr or length
 *	EINVAL		- illegal flags etc., no map table assigned
 *	EBADPGSZ	- page size does not match
 *
 *
 * FIXME: Items to clean up with this block are:
 *	1. Careful access to a MTE mapping with a quadd load
 *	2. Better bcopy loop / legion version ..
 *	2b. Possibly restrict alignment to either block or page
 *		size to enable allocating block stores.
 *	3. Enable tracking of in progress copies so
 *		mapping tables can be dempaped or allocated to other
 *		channels
 *	4. Reference count for channels using these tables.
 */
	ENTRY_NP(hcall_ldc_copy)

	! Enforce 8 byte alignment early
	or	%o2, %o3, %g1
	or	%g1, %o4, %g1
	andcc	%g1, 7, %g0
	bne	herr_badalign
	  nop

	! Copy direction is either 0 or 1 : in or out
	cmp	%o1, LDC_COPY_OUT
	bg,pn	%xcc, herr_inval
	  nop

	! length <=0 error
	cmp	%o4, 0
	ble,pn	%xcc, herr_inval
	  nop

	! ch_id, scr, guest, endpoint
	GET_LDC_ENDPOINT(%o0, %g3, %g1, %g7)

	!! %g1 guest struct
	!! %g7 endpoint

	! Check the RA range we've been given
	! hstruct, raddr, size, fail_label, scr
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o3, %o4, herr_noraddr, %g4, %g3)

	! Check endpoint connection type
	ldub	[%g7 + LDC_TARGET_TYPE], %g3	! if type=0, target is guest
	brz,pt	%g3, .guest_copy		!     else copying directly
	  nop					!     to a HV PA (hvctl)

	! Copy data from HV memory to guest RA
	!! %o2 PA of address in HV
	! no need for table lookup

	! FIXME: we need a way to verify if the PA is
	! valid.
	! Must check against the currently valid ranges of phys mem

	! Limit length to the end of a page

	sethi	%hi(8192), %g4
	sub	%g4, 1, %g5
	and	%o2, %g5, %g5			! offset into remote page

	sub	%g4, %g5, %g4			! distance to end of page
	cmp	%g4, %o4			! distance <= length
	movl	%xcc, %g4, %o4			! clamp to end of page

	ba,pt	%xcc, .copy_data
	  nop

.guest_copy:
	! Find the corresponding endpoint at the recipient ..
	ldx	[%g7 + LDC_TARGET_GUEST], %g2
	ldx	[%g7 + LDC_TARGET_CHANNEL], %g5
	mulx	%g5, LDC_ENDPOINT_SIZE, %g5
	set	GUEST_LDC_ENDPOINT, %g6
	add	%g2, %g5, %g4
	add	%g4, %g6, %g4			! g4 is the target endpoint
	ldub	[%g4 + LDC_IS_LIVE], %g3
	brz,pn	%g3, herr_invalchan
	  ldub	[%g4 + LDC_IS_PRIVATE], %g3
	brnz,pn	%g3, herr_invalchan
	  nop

	! Find our map table PA from endpoint
	ldx	[%g4 + LDC_MAP_TABLE_PA], %g3
	brz,pn	%g3, herr_nomap
	  nop

	!! %g1 guest
	!! %g2 target guest
	!! %g3 map table pa
	!! %g4 ldc struct

	srlx	%o2, 60, %g6				! extract page size
	brnz,pn	%g6, herr_badpgsz			! only 8K for now
	  nop

	sllx	%o2, 8, %g6				! Extract cookie idx
	srlx	%g6, 13+8, %g6				! Bits: 56-pg_size_bits

	ldx	[%g4 + LDC_MAP_TABLE_NENTRIES], %g5	! table entries
	cmp	%g6, %g5
	bge,pn	%xcc, herr_nomap			! off end of table ?
	  nop

	sllx	%g6, LDC_MTE_SHIFT, %g6		! Size of MTE
	ldx	[%g3 + %g6], %g3		! MTE itself

	srlx    %g3, LDC_MTE_PERM_CPRD_BIT, %g5
	srlx    %g5, %o1, %g5
	andcc   %g5, 1, %g0
        bz,pn   %xcc, herr_noaccess             ! error for invalid MTE? FIXME
          nop

	mov	1, %g5
	sllx	%g5, 56, %g6
	sub	%g6, 1, %g6

	sllx	%g5, 13, %g5		! Currently assume 8K pages
	sub	%g5, 1, %g5

	andn	%g6, %g5, %g6		! Create a Rpfn mask
	and	%g3, %g6, %g3		! Extract target real pfn
	and	%o2, %g5, %g5		! Extract page offset
	or	%g3, %g5, %g3		! Target RA

	! Limit the copy to the map page size
	add	%g5, %o4, %g4		! Length of copy + offset
	sethi	%hi(8192), %g6
	cmp	%g6, %g4
	sub	%g6, %g5, %g6
	movl	%xcc, %g6, %o4		! Limit copy to end of page


	! Check that we are in range
	! get the PA for the exported page
	RA2PA_RANGE_CONV_UNK_SIZE(%g2, %g3, %o4, herr_noraddr, %g6, %o2)

	! Copy the data from one page to another
	!! %o1 direction of copy
	!! %o2 phys addr of remote buffer
	!! %o3 checked RA of local buffer
	!! %o4 copy length
	!! %g1 guest struct
.copy_data:
	RA2PA_CONV(%g1, %o3, %g5, %g6)

	!! %g5 PA of local buffer

	sethi	%hi(8192), %g2
	sub	%g2, 1, %g3

	! Clamp if closer to end of local page than remote buffer
	and	%g5, %g3, %g3
	sub	%g2, %g3, %g3		! Number of bytes to end of page
	cmp	%g3, %o4		! if < copy len, clamp copy len
	movl	%xcc, %g3, %o4

	mov	%g0, %g1		! copy idx

	! See if it is a LDC_COPY_IN
	brz,pn	%o1, 0f
	  nop


	! FIXME: Use an optimized block allocating copy !
	! Copy out
1:
	ldx	[%g5 + %g1], %g7
	stx	%g7, [%o2 + %g1]
	add	%g1, 8, %g1
	cmp	%g1, %o4
	bne,pt	%xcc, 1b
	  nop

	ba,pt	%xcc, 2f
	  nop

0:	! Copy in
1:
	ldx	[%o2 + %g1], %g7
	stx	%g7, [%g5 + %g1]
	add	%g1, 8, %g1
	cmp	%g1, %o4
	bne,pt	%xcc, 1b
	  nop

2:

	! Cleanup before return
	mov	%o4, %o1
	mov	%g0, %o2
	mov	%g0, %o3
	mov	%g0, %o4

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_copy)


/*
 * Map in function ...
 *
 * Allocate hypervisor map table entry for given cookie
 * so that we can track usage model.
 *
 * Returns a RA that identifies the tracking slot.
 *
 * int hv_ldc_mapin(int channel, uint64_t cookie)
 *
 * inputs:
 *	%o0 channel
 *	%o1 cookie
 *
 * returns:
 *	%o0 status
 *	%o1 raddr
 *	%o2 perms
 *
 *	ECHANNEL	- illegal channel
 *	ENOMAP		- illegal / invalid cookie addr
 *	ENORADDR	- illegal raddr to raddr+length
 *	EBADALIGN	- badly aligned raddr or cookie_addr or length
 *	EINVAL		- illegal flags etc., no map table assigned
 *	EBADPGSZ	- page size does not match
 */
	ENTRY_NP(hcall_ldc_mapin)

	! Stash the args into the cpu struct scratch area
	! so we can retrieve later (7 g regs arent enough)
	! FIXME: could use cpu push/pop
	VCPU_STRUCT(%g1)
	stx	%o0, [%g1 + CPU_SCR0]
	stx	%o1, [%g1 + CPU_SCR1]

	GET_LDC_ENDPOINT( %o0, %g7, %g1, %g2 )	!! %g1=guest, %g2=endpoint

	! FIXME: Workaround to disable mapin support if
	! HV MD does not have RA range in guest MDs
	! to be deleted later ...
	set	GUEST_LDC_MAPIN_BASERA, %g3
	ldx	[%g1 + %g3], %g3
	brz,pn	%g3, herr_notsupported
	  nop


	ldub	[%g2 + LDC_TARGET_TYPE], %g3	! if type=0, target is guest
	brnz,pt	%g3, herr_inval			!     we're ok - fail HV
	  nop					!     connected channels

		! Find the target endpoint ...
	ldx     [%g2 + LDC_TARGET_GUEST], %g3
	ldx     [%g2 + LDC_TARGET_CHANNEL], %g4
	mulx    %g4, LDC_ENDPOINT_SIZE, %g4
	set     GUEST_LDC_ENDPOINT, %g5
	add     %g3, %g5, %g5
	add     %g5, %g4, %g4                   ! g4 is the target endpoint
	ldub    [%g4 + LDC_IS_LIVE], %g5
	brz,pn  %g5, herr_invalchan
	  ldub    [%g4 + LDC_IS_PRIVATE], %g5
	brnz,pn  %g5, herr_invalchan
	  nop

	!! %g1 my guest
	!! %g3 target guest
	!! %g4 target endpoint

	! Find table index after page size
	srlx	%o1, LDC_COOKIE_PGSZC_SHIFT, %g2	! extract pg size

	! If its not a valid page size assume cookie is bogus
	set	TTE_VALIDSIZEARRAY, %g5
	srlx	%g5, %g2, %g5
	btst	1, %g5
	bz,pn	%xcc, herr_badpgsz
	  nop


	sllx	%o1, 64-LDC_COOKIE_PGSZC_SHIFT, %g6	! shift off pg size
	mulx	%g2, 3, %g5
	add	%g5, 13 + (64-LDC_COOKIE_PGSZC_SHIFT), %g5 ! shift for index
	srlx	%g6, %g5, %g5				! get index

	!! %g1 my guest
	!! %g2 page_size
	!! %g3 target guest
	!! %g4 target endpoint
	!! %g5 table idx

	! Check index to see if it is in range
	ldx	[%g4 + LDC_MAP_TABLE_NENTRIES], %g6
	cmp	%g5, %g6
	bge,pn	%xcc, herr_nomap
	  nop

	! Find remote map table PA from endpoint
	ldx	[%g4 + LDC_MAP_TABLE_PA], %g6
	brz,pn	%g6, herr_nomap
	  nop

	!! %g1 my guest struct
	!! %g2 page_size
	!! %g3 target guest
	!! %g4 target endpoint
	!! %g5 table idx
	!! %g6 maptable pa

	! Pull map table entry
	sllx	%g5, LDC_MTE_SHIFT, %g7
	ldx	[%g6 + %g7], %g7

	! Check we have permission for something ... (ie valid)
	! We ignore the copyin/copyout flags
	srlx	%g7, LDC_MTE_PERM_SHIFT, %o0
	and	%o0, LDC_MTE_PERM_MASK, %o0
	andcc	%o0, LDC_MAPIN_MASK, %g0
	beq,pn	%xcc, herr_noaccess
	  nop

	! NOTE: We already checked the cookie against the list of
	! legit page sizes, so if this matches we dont need
	! to check if MTE page size is legal.
	! Match page size ....

	srlx	%g7, LDC_MTE_PGSZ_SHIFT, %o0
	and	%o0, LDC_MTE_PGSZ_MASK, %o0
	xorcc	%o0, %g2, %g0
	bne,pn	%xcc, herr_badpgsz
	  nop

	!! %g1 my guest struct
	!! %g2 page_size
	!! %g3 target guest
	!! %g4 target endpoint
	!! %g5 table idx
	!! %g6 maptable pa
	!! %g7 maptable entry

	! sacrifice %g2 and %g4 in here...

	! Check if the entry has a legit RA range for the
	! other guest

	mulx	%g2, 3, %o0
	add	%o0, 13, %o0
	mov	1, %o1
	sllx	%o1, %o0, %o1
	sub	%o1, 1, %o1	!! %o1 size of page

	! Extract the RA & check for alignment
	sllx	%g7, LDC_MTE_RSVD_BITS, %g2
	srlx	%g2, 13+LDC_MTE_RSVD_BITS, %g2
	sllx	%g2, 13, %o0
	btst	%o0, %o1
	bne,pn	%xcc, herr_badalign	! page not aligned
	  nop

	! Is this a legit RA for the other guest
	RA2PA_RANGE_CONV_UNK_SIZE(%g3, %o0, %o1, herr_noraddr, %g4, %g2)

	! Finally everything checks out
	! Let's allocate a mapin entry - fill in the details
	! and return.

	! Picking a mapin entry has to be atomic in case we're in
	! a race with another map-in

	set	GUEST_LDC_MAPIN_FREE_IDX, %o0
	add	%g1, %o0, %o0
1:
	ldx	[%o0], %o1			! -1 == No more free available
	brlz	%o1, herr_toomany
	  nop

	mulx	%o1, LDC_MAPIN_SIZE, %g2	! Extract next idx from free
	set	GUEST_LDC_MAPIN, %g4
	add	%g1, %g4, %g4
	add	%g4, %g2, %g2
	ldx	[%g2 + LDC_MI_NEXT_IDX], %g4

	casxa	[%o0]ASI_P, %o1, %g4
	cmp	%g4, %o1
	bne,pn	%xcc, 1b
	  nop

	! Fill in the mapin entry values
	!
	!! %o1 index of mapin entry
	!! %g1 my guest struct
	!! %g2 address of mapin entry
	!! %g3 target guest
	!! %g5 table idx
	!! %g6 maptable pa
	!! %g7 maptable entry

	! Stash away remainding O regs for space.

	VCPU_STRUCT(%o0)
	ldx	[%o0 + CPU_SCR0], %g4
	sth	%g4, [%g2 + LDC_MI_LOCAL_ENDPOINT]

	stw	%g5, [%g2 + LDC_MI_MAP_TABLE_IDX]

	! g4 and g5 now available

	srlx	%g7, LDC_MTE_PERM_SHIFT, %g4
	and	%g4, LDC_MTE_PERM_MASK, %o2	! Return perms
	and	%g4, LDC_MAPIN_MASK, %g4
	stb	%g4, [%g2 + LDC_MI_PERMS]

	! Extract the RA again
	sllx	%g7, LDC_MTE_RSVD_BITS, %g4
	srlx	%g4, 13+LDC_MTE_RSVD_BITS, %g4
	sllx	%g4, 13, %g4

	RA2PA_CONV(%g3, %g4, %g4, %g5)

	! RA was already checked for alignment, so
	! PA must also be aligned - no check required
	stx	%g4, [%g2 + LDC_MI_PA]

	! Extract the page size again
	srlx	%g7, LDC_MTE_PGSZ_SHIFT, %g4
	and	%g4, LDC_MTE_PGSZ_MASK, %g4
	stb	%g4, [%g2 + LDC_MI_PG_SIZE]

	! Use it to figure out the RA offset from the
	! cookie we were given.

	mulx	%g4, 3, %g4
	add	%g4, 13, %g4
	mov	1, %o0
	sllx	%o0, %g4, %o0
	sub	%o0, 1, %o0

	! Clear everything else
	stx	%g0, [%g2 + LDC_MI_VA]
	sth	%g0, [%g2 + LDC_MI_VA_CTX]
	stx	%g0, [%g2 + LDC_MI_IO_VA]
	stx	%g0, [%g2 + LDC_MI_MMU_MAP]

#if	(LARGEST_PG_SIZE_BITS+LDC_NUM_MAPINS_BITS) > 55
#error	Sanity check failed: too many mapin entries to encode in RA
#endif
	sllx	%o1, LARGEST_PG_SIZE_BITS, %o1
	set	GUEST_LDC_MAPIN_BASERA, %g4
	ldx	[%g1 + %g4], %g4
	add	%g4, %o1, %o1

	! scrap g1 and replace with cpu struct
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_SCR1], %g1

	and	%g1, %o0, %o0
	or	%o0, %o1, %o1

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_mapin)

	/*
	 * Simple support function to release and clear a mapin entry
	 * that is no longer in use
	 *
	 * %g1 guest struct
	 * %g2 index of mapin entry
	 * %g3 scratch
	 * %g4 scratch
	 * %g5 scratch
	 * %g7 return addr
	 */

	ENTRY_NP(mapin_free)
	set	GUEST_LDC_MAPIN_FREE_IDX, %g3
	add	%g1, %g3, %g3		! Address of free idx

	set	GUEST_LDC_MAPIN, %g4
	add	%g1, %g4, %g4
	mulx	%g2, LDC_MAPIN_SIZE, %g1
	add	%g1, %g4, %g1		! Address of mapin entry

	! Perms are used to determine liveness
	stb	%g0, [%g1 + LDC_MI_PERMS]

1:
	ldx	[%g3], %g4
	stx	%g4, [%g1 + LDC_MI_NEXT_IDX]	! do first so link-in is atomic

	mov	%g2, %g5
	casxa	[%g3]ASI_P, %g4, %g5
	cmp	%g5, %g4
	bne,pn	%xcc, 1b
	  nop

	HVRET
	SET_SIZE(mapin_free)


/*
 * callback for console input
 *
 * %g1 callback arg (guest struct)
 * %g2 payload
 * %g7 return address
 */
	ENTRY_NP(cons_ldc_callback)

	! get the console struct for this endpt
	set	GUEST_CONSOLE, %g5
	add	%g1, %g5, %g1

	ldub	[%g1 + CONS_STATUS], %g4	! chk if console is ready
	andcc	%g4, LDC_CONS_READY, %g0
	bz,pn	%xcc, 1f
	  nop

	ldub	[%g2], %g6			! get the packet type
	cmp	%g6, LDC_CONSOLE_DATA
	beq,pt	%xcc, .console_data
	  nop

	cmp	%g6, LDC_CONSOLE_CONTROL	! check if control pkt
	bne,pt	%xcc, 1f			!   else drop pkt and return
	  nop

	ldub	[%g1 + CONS_STATUS], %g4	! get console status
	or	%g4, LDC_CONS_BREAK, %g4	! set the break bit

	lduw	[%g2 + LDC_CONS_CTRL_MSG], %g6	! get control message
	set	CONS_BREAK, %g5
	cmp	%g6, %g5			!   chk it is a break
	beq,a,pn %xcc, 1f
	  stb	%g4, [%g1 + CONS_STATUS]

	ldub	[%g1 + CONS_STATUS], %g4	! get console status
	or	%g4, LDC_CONS_HUP, %g4		! set the hup bit

	lduw	[%g2 + LDC_CONS_CTRL_MSG], %g6	! get control message
	set	CONS_HUP, %g5
	cmp	%g6, %g5			!   chk it is a hangup
	beq,a,pn %xcc, 1f
	  stb	%g4, [%g1 + CONS_STATUS]

	ba	1f				! invalid control message
	  nop					!   drop it

.console_data:
	ldx	[%g1 + CONS_INTAIL], %g4	! get current tail
	ldub	[%g2 + LDC_CONS_SIZE], %g3	! get num chars
 	add	%g2, LDC_CONS_PAYLOAD, %g2	! start from second word
2:
	add	%g1, CONS_INBUF, %g5		! incoming buffer
	add	%g5, %g4, %g5			! dest buf offset loc
	ldub	[%g2], %g6
	stb	%g6, [%g5]
	inc	%g2				! inc src addr
	inc	%g4				! inc inbuf tail
	and	%g4, (CONS_INBUF_SIZE - 1), %g4	!   and wrap
	deccc	%g3				! dec size
	bnz,pn	%xcc, 2b			! if not zero, copy next byte
	  nop
	stx	%g4, [%g1 + CONS_INTAIL]	! store the new tail

1:
	jmp	%g7 + 4
	  nop

	SET_SIZE(cons_ldc_callback)



	! Real address access
	!! %g1 guest struct
	!! %g2 real address to be mapped
	!! %g3 mapin base RA
	!! %g4 offset in mapin RA region

	! XXX - Need to check that bits between LARGEST_PG_SIZE_BITS and
	!	actual page size are zero toprevent aliasing.

	ENTRY_NP(ldc_dmmu_mapin_ra)
	.global	rdmmu_miss_not_found2
	GET_MAPIN_ENTRY(%g1, %g4, %g5)
	ldub	[%g5 + LDC_MI_PERMS], %g6
	andcc	%g6, LDC_MAP_R|LDC_MAP_W, %g0
	beq,pn	%xcc, rdmmu_miss_not_found2
	  nop

	! OK have a mapable RA with some permissions
	! stuff the DTLB with the right info.
	! FIXME: cant support write only with N1s TLB
	ldub	[%g5 + LDC_MI_PG_SIZE], %g4
	ldx	[%g5 + LDC_MI_PA], %g3
	or	%g4, %g3, %g3
	andcc	%g6, LDC_MAP_W, %g0

	mov	0, %g6
	movne	%xcc, TTE_W, %g6
	or	%g6, TTE_CP|TTE_P, %g6	! TTE_CP wont fit cmov

	or	%g6, %g3, %g3
	mov	1, %g6
	sllx	%g6, 63, %g6	! valid bit
	or	%g6, %g3, %g3

		! TAG register is still configured for us
	mov	TLB_IN_REAL|TLB_IN_4V_FORMAT, %g2
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN

		! Now the expensive bit - track the MMU usage
	STRAND_STRUCT(%g1)
	ldub	[%g1 + STRAND_ID], %g1	/* FIXME: use asr26? */
	srlx	%g1, 2, %g1
	add	%g1, MIE_RA_MMU_SHIFT, %g1
	mov	1, %g2
	sllx	%g2, %g1, %g1
	add	%g5, LDC_MI_MMU_MAP, %g5		!!!
	ATOMIC_OR_64(%g5, %g1, %g2, %g3)

	retry
	SET_SIZE(ldc_dmmu_mapin_ra)


	!
	! FIXME: need equivalent for immu of dmmu_mapin_ra
	!


        !! %g1 cpu struct
        !! %g2 --
        !! %g3 raddr
        !! %g4 page size (bytes)
        !! %g5 offset into mapin region
        !! %g6 guest struct
        !! %g7 TTE ready for pa
	!
	! FIXME: need to cross leverage with ldc_dmmu_mapin_ra
	! FIXME: Need to check that bits between LARGEST_PG_SIZE_BITS and
	!	actual page size are zero toprevent aliasing.

	ENTRY_NP(ldc_dtsb_hit)
	.global revec_dax

	GET_MAPIN_ENTRY(%g6, %g5, %g2)

	ldub	[%g2 + LDC_MI_PERMS], %g6
	andcc	%g6, LDC_MAP_R|LDC_MAP_W, %g0
	beq,pn	%xcc, .inval_ra
	  nop

	! OK have a mapable RA with some permissions
	! stuff the DTLB with the right info.
	! FIXME: cant support write only with N1s TLB

	! Fail page size mis-match otherwise our demap doesnt work
	and	%g7, TTE_SZ_MASK, %g4
	ldub	[%g2 + LDC_MI_PG_SIZE], %g5
	cmp	%g4, %g5
	bne,pn	%xcc, .inval_pgsz
	  nop

	ldx	[%g2 + LDC_MI_PA], %g5
	or	%g7, %g5, %g5

	andcc	%g6, LDC_MAP_W, %g0
	mov	0, %g6
	move	%xcc, TTE_W, %g6

	andn	%g5, %g6, %g5	! clear w bit if no write permission

	CLEAR_TTE_LOCK_BIT(%g5, %g6)	! %g5 tte (force clear lock bit)

	! TAG register is still configured for us
	mov	TLB_IN_4V_FORMAT, %g6
	stxa	%g5, [%g6]ASI_DTLB_DATA_IN

	! Pull the fault address and context, save it
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3
	set	(NCTXS-1), %g4
	and	%g3, %g4, %g5	! context
	sth	%g5, [%g2 + LDC_MI_VA_CTX]
	andn	%g3, %g4, %g3	! vaddr
	stx	%g3, [%g2 + LDC_MI_VA]

	! Now the expensive bit - track the MMU usage
	VCPU2STRAND_STRUCT(%g1, %g1)
	ldub	[%g1 + STRAND_ID], %g1
	srlx	%g1, 2, %g1
	add	%g1, MIE_VA_MMU_SHIFT, %g1
	mov	1, %g5
	sllx	%g5, %g1, %g1
	add	%g2, LDC_MI_MMU_MAP, %g2
	ATOMIC_OR_64(%g2, %g1, %g5, %g3)

	retry

.inval_pgsz:
	ba,pt	%xcc, .revec
	  mov	MMU_FT_PAGESIZE, %g1

.inval_ra:
	ba,pt	%xcc, .revec
	  mov	MMU_FT_INVALIDRA, %g1

.revec:
	! Pull the fault address and context again
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3
	set	(NCTXS-1), %g2
	and	%g3, %g2, %g5	! context
	andn	%g3, %g2, %g3	! addr
	ba,pt	%xcc, revec_dax
	  nop

	SET_SIZE(ldc_dtsb_hit)

	!! %g1 cpu struct
	!! %g2 real address
	!! %g3 TTE without PA/RA field
	!! %g4 --
	!! %g5 offset into mapin region
	!! %g6 guest struct
	!! %g7 --
	!! %o0 vaddr
	!! %o1 ctx
	!! %o2 tte
	!! %o3 flags

	!
	! FIXME: need to cross leverage with ldc_dmmu_mapin_ra
	! FIXME: Need to check that bits between LARGEST_PG_SIZE_BITS and
	!	actual page size are zero toprevent aliasing.

	ENTRY_NP(ldc_map_addr_api)
	.global hcall_mmu_map_addr_ra_not_found

	GET_MAPIN_ENTRY(%g6, %g5, %g2)

	! If we ask for an I mapping, make sure we have MAP_X
	! If we ask for a D mapping, make sure we have at least MAP_R
	! .. we require MAP_W if the TTE has WPERM and we ask for D mapping

	btst	MAP_DTLB, %o3
	movne	%xcc, LDC_MAP_R, %g4
	btst	MAP_ITLB, %o3
	movne	%xcc, LDC_MAP_X, %g7
	or	%g4, %g7, %g4
	btst	TTE_W, %g3
	movne	%xcc, LDC_MAP_W, %g7
	or	%g4, %g7, %g7

	ldub	[%g2 + LDC_MI_PERMS], %g4
	and	%g4, %g7, %g4
	brz,pn	%g4, herr_inval
	  nop

	ldub	[%g2 + LDC_MI_VA_MMU_MAP], %g7
	brz,pt	%g7, 1f
	  nop
	ldx	[%g2 + LDC_MI_VA], %g7
	cmp	%g7, %o0
	bne,pn	%xcc, herr_inval
	  nop
	lduh	[%g2 + LDC_MI_VA_CTX], %g7
	cmp	%g7, %o1
	bne,pn	%xcc, herr_inval
	  nop
1:

	andcc	%g4, LDC_MAP_W, %g0
	mov	%g0, %g4
	move	%xcc, TTE_W, %g4	! if !=0 move correct value in
	andn	%g3, %g4, %g3		! clear w bit if no write permission

	! OK have a mapable RA with some permissions
	! stuff the DTLB with the right info.
	! FIXME: cant support write only with N1s TLB

	! Fail page size mis-match otherwise our demap doesnt work
	and	%g3, TTE_SZ_MASK, %g4
	ldub	[%g2 + LDC_MI_PG_SIZE], %g7
	cmp	%g4, %g7
	bne,pn	%xcc, hcall_mmu_map_addr_ra_not_found
	  nop

	ldx	[%g2 + LDC_MI_PA], %g7
	or	%g3, %g7, %g3		! start building TTE

	CLEAR_TTE_LOCK_BIT(%g3, %g7) 	! %g3 tte (force clear lock bit)

#ifndef STRICT_API
	set	(NCTXS - 1), %g7
	and	%o1, %g7, %o1
	andn	%o0, %g7, %o0
#endif /* STRICT_API */
	or	%o0, %o1, %g4	!! %g4 tag

	mov	MMU_TAG_ACCESS, %g7
	mov	TLB_IN_4V_FORMAT, %g6

	btst	MAP_DTLB, %o3
	be	%xcc, 2f
	  btst	MAP_ITLB, %o3	! Test in delay slot to setup xcc

	stxa	%g4, [%g7]ASI_DMMU
	membar	#Sync
	stxa	%g3, [%g6]ASI_DTLB_DATA_IN
	bz,pn	%xcc, 1f
	  nop

2:
	stxa	%g4, [%g7]ASI_IMMU
	membar	#Sync
	stxa	%g3, [%g6]ASI_ITLB_DATA_IN

1:
	stx	%o0, [%g2 + LDC_MI_VA]
	sth	%o1, [%g2 + LDC_MI_VA_CTX]
		! Now the expensive bit - track the MMU usage
	VCPU2STRAND_STRUCT(%g1, %g1)
	ldub	[%g1 + STRAND_ID], %g1
	srlx	%g1, 2, %g1
	add	%g1, MIE_VA_MMU_SHIFT, %g1
	mov	1, %g5
	sllx	%g5, %g1, %g1
	add	%g2, LDC_MI_MMU_MAP, %g2
	ATOMIC_OR_64(%g2, %g1, %g5, %g3)

	HCALL_RET(EOK)

	SET_SIZE(ldc_map_addr_api)


/*
 * ldc_unmap
 *
 * Unmaps the page mapped at RA from the local guest.
 *
 * FIXME: We assume for the moment the guest has done the right
 *	demap clean up - so all we have to do here is free up the
 *	internal structure associated with the map table entry.
 *	This is currently a big security hole, but not a functional
 *	gap for the moment, since the only guest we have (Solaris) is
 *	well behaved. So we have to fix this eventually.
 * FIXME: Check that unused raddr bits are zero in case of aliasing
 *
 * arg0 raddr (%o0)
 * --
 * ret0 status (%o0)
 *
 */
	ENTRY_NP(hcall_ldc_unmap)

	GUEST_STRUCT(%g1)

	set	GUEST_LDC_MAPIN_BASERA, %g4
	ldx	[%g1 + %g4], %g4
	subcc	%o0, %g4, %g5
	bneg,pn	%xcc, herr_noraddr
	nop
	set	GUEST_LDC_MAPIN_SIZE, %g4
	ldx	[%g1 + %g4], %g4
	subcc	%g5, %g4, %g4
	brgez,pn %g4, herr_noraddr
	nop

	srlx	%g5, LARGEST_PG_SIZE_BITS, %g2		! mapin idx
	mulx	%g2, LDC_MAPIN_SIZE, %g5
	set	GUEST_LDC_MAPIN, %g6
	add	%g5, %g6, %g5
	add	%g1, %g5, %g5	! addr of mapin entry
	ldub	[%g5 + LDC_MI_PERMS], %g6
	brz,pn	%g6, herr_nomap
	  nop

	HVCALL(mapin_free)

	HCALL_RET(EOK)
	SET_SIZE(hcall_ldc_unmap)


/*
 * ldc_revoke
 *
 * FIXME: Currently not used, so fault in when we have a guest that
 *	requires it.
 *
 * arg0 channel (%o0)
 * arg1 cookie (%o1)
 * arg2 revoke_cookie (%o2)
 * --
 * ret0 status (%o0)
 *
 */
	ENTRY_NP(hcall_ldc_revoke)
	HCALL_RET(ENOTSUPPORTED)
	SET_SIZE(hcall_ldc_revoke)



/*
 * ldc_vintr_getcookie
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 cookie (%o1)
 */
	ENTRY_NP(ldc_vintr_getcookie)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, get_cookie_fail
	nop

	GUEST_STRUCT(%g1)
	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g1
	brz,pn	%g1, get_target_fail
	nop

	! load the cookie from the target endpoint structure mapreg
	ldx	[%g1 + LDC_MAPREG_COOKIE], %o1
	HCALL_RET(EOK)

get_cookie_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_getcookie)

/*
 * ldc_vintr_setcookie
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * arg2 cookie (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(ldc_vintr_setcookie)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, set_cookie_fail
	nop

	GUEST_STRUCT(%g1)
	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g1
	brz,pn	%g1, set_cookie_fail
	nop

	! store the cookie to the target endpoint structure mapreg
	stx	%o2, [%g1 + LDC_MAPREG_COOKIE]
	HCALL_RET(EOK)

set_cookie_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_setcookie)

/*
 * ldc_vintr_getvalid
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(ldc_vintr_getvalid)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, get_valid_fail
	nop

	GUEST_STRUCT(%g1)

	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g1
	brz,pn	%g1, get_valid_fail
	nop

	!! %g1 mapreg
	ldub	[%g1 + LDC_MAPREG_VALID], %o1
	HCALL_RET(EOK)

get_valid_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_getvalid)

/*
 * ldc_vintr_setvalid
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * arg2 intr valid state (%o2) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(ldc_vintr_setvalid)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, set_valid_fail
	nop

	GUEST_STRUCT(%g1)

	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g2
	brz,pn	%g2, set_valid_fail
	ldx	[%g1 + LDC_I2E_ENDPOINT], %g1

	!! %g1 endpoint
	!! %g2 mapreg

	! for valid RX interrupts only, if state is IDLE check if we need
	! to send interrupt
	brz,pn	%o2, 1f				! interrupt VALID?
	stb	%o2, [%g2 + LDC_MAPREG_VALID]	! regardless, fill in status
	add	%g1, LDC_RX_MAPREG, %g3
	cmp	%g2, %g3			! RX or TX
	bne,pn	%xcc, 1f

	ld	[%g2 + LDC_MAPREG_STATE], %g3	! only bother if interrupt
	cmp	%g3, INTR_IDLE			!   IDLE
	bne,pn	%xcc, 1f
	nop

	! check if there are pending pkts, if any, notify guest
	HVCALL(hv_ldc_chk_pkts)
1:
	HCALL_RET(EOK)

set_valid_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_setvalid)

/*
 * ldc_vintr_gettarget
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(ldc_vintr_gettarget)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, get_target_fail
	nop

	GUEST_STRUCT(%g1)

	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g1
	brz,pn	%g1, get_target_fail
	nop

	! load the cpup from the target endpoint structure mapreg
	!  and grab vcpuid
	ldx	[%g1 + LDC_MAPREG_CPUP], %g1
	ldub	[%g1 + CPU_VID], %o1

	HCALL_RET(EOK)

get_target_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_gettarget)

/*
 * ldc_vintr_settarget
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * arg2 cpuid (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(ldc_vintr_settarget)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, set_target_fail
	nop

	GUEST_STRUCT(%g1)

	! convert vcpuid to pcpup
	VCPUID2CPUP(%g1, %o2, %o2, herr_nocpu, %g2)

	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g1
	brz,pn	%g1, set_target_fail
	nop

	! store cpup to target endpoint structure mapreg
	stx	%o2, [%g1 + LDC_MAPREG_CPUP]
	HCALL_RET(EOK)

set_target_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_settarget)

/*
 * ldc_vintr_getstate
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 0: idle 1: received 2: delivered
 */
	ENTRY_NP(ldc_vintr_getstate)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, get_state_fail
	nop

	GUEST_STRUCT(%g1)

	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g1
	brz,pn	%g1, get_state_fail
	nop

	!! %g1 mapreg
	ld	[%g1 + LDC_MAPREG_STATE], %o1
	HCALL_RET(EOK)

get_state_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_getstate)

/*
 * ldc_vintr_setstate
 *
 * arg0 devhandle (%o0)
 * arg1 devino (%o1)
 * arg2 (%o2) 0: idle 1: received 2: delivered
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(ldc_vintr_setstate)

	cmp	%o1, MAX_LDC_INOS
	bgeu,pn	%xcc, set_state_fail
	nop
	brlz,pn	%o2, set_state_fail
	cmp	%o2, INTR_DELIVERED
	bgu,pn	%xcc, set_state_fail
	nop

	GUEST_STRUCT(%g1)

	set	GUEST_LDC_I2E, %g2
	add	%g1, %g2, %g1
	mulx	%o1, LDC_I2E_SIZE, %g2
	add	%g1, %g2, %g1
	ldx	[%g1 + LDC_I2E_MAPREG], %g2
	brz,pn	%g2, set_state_fail
	ldx	[%g1 + LDC_I2E_ENDPOINT], %g1

	!! %g1 endpoint
	!! %g2 mapreg

	! for valid RX interrupts only, if state is IDLE check if we need
	! to send interrupt
	cmp	%o2, INTR_IDLE			! interrrupt IDLE?
	bne,pn	%xcc, 1f
	st	%o2, [%g2 + LDC_MAPREG_STATE]	! regardless, fill in state

	add	%g1, LDC_RX_MAPREG, %g3
	cmp	%g2, %g3			! RX or TX?
	bne,pn	%xcc, 1f
	ldub	[%g2 + LDC_MAPREG_VALID], %g3	! only bother if interrupt
	brz,pn	%g3, 1f				!   VALID
	nop

	! check if there are pending pkts, if any, notify guest
	HVCALL(hv_ldc_chk_pkts)
1:
	HCALL_RET(EOK)

set_state_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(ldc_vintr_setstate)

/*
 * Wrapper around hv_ldc_send_pkt, so it can be called from C
 * SPARC ABI requries only that g2,g3,g4 are preserved across
 * function calls.
 * %o0 in-HV channel idx
 * %o1 payload paddr
 *
 * void c_hvldc_send(int hv_endpt, void *payload)
 */
        ENTRY(c_hvldc_send)

        STRAND_PUSH(%g2, %g6, %g7)
        STRAND_PUSH(%g3, %g6, %g7)
        STRAND_PUSH(%g4, %g6, %g7)

	mov     %o0, %g1
        mov     %o1, %g2
        HVCALL(hv_ldc_send_pkt)

        STRAND_POP(%g4, %g6)
        STRAND_POP(%g3, %g6)
        STRAND_POP(%g2, %g6)

        retl
          nop
        SET_SIZE(c_hvldc_send)

/*
 * Internal function to send a 64-byte LDC pkt to a guest.
 *
 * hv_ldc_send_pkt(channel, paddr)
 *
 * In:
 *	%g1 in-HV channel idx
 *	%g2 payload paddr
 * Out:
 *	%g1 0 if success, else error value
 * Misc:
 *	clobbers everything
 *	(g7 is return address from caller)
 */
	ENTRY_NP(hv_ldc_send_pkt)

	ROOT_STRUCT(%g4)

	ldx	[%g4 + CONFIG_HV_LDCS], %g4
	mulx	%g1, LDC_ENDPOINT_SIZE, %g5
	add	%g4, %g5, %g4

	ldub	[%g4 + LDC_IS_LIVE], %g5
	brz,a,pn %g5, .ldc_send_ret
	  mov	ECHANNEL, %g1

	/*
	 * Packet going to guest
	 *
	 * %g2 payload PA
	 * %g4 hv channel ptr
	 *
	 * find target guest and LDC target idx
	 */
	ldx	[%g4 + LDC_TARGET_GUEST], %g3
	ldx	[%g4 + LDC_TARGET_CHANNEL], %g4
	setx	GUEST_LDC_ENDPOINT, %g5, %g1
	mulx	%g4, LDC_ENDPOINT_SIZE, %g5
	add	%g3, %g5, %g5
	add	%g1, %g5, %g5

	/* no Q configured ? */
	ldx	[%g5 + LDC_RX_QSIZE], %g1
	brz,a,pn %g1, .ldc_send_ret
	  mov	EIO, %g1

	/*
	 * check if the target q is full
	 * if queue is full, wait until pkts
	 * get read from the queue
	 */
	ldx	[%g5 + LDC_RX_QSIZE], %g1
	lduw	[%g5 + LDC_RX_QTAIL], %g6
	dec	Q_EL_SIZE, %g1
	add	%g6, Q_EL_SIZE, %g6
	and	%g6, %g1, %g1
	lduw	[%g5 +  LDC_RX_QHEAD], %g6
	cmp	%g1, %g6
	be,a,pn	%xcc, .ldc_send_ret
	  mov	EWOULDBLOCK, %g1

	/*
	 * %g1 scratch
	 * %g2 payload PA (modified)
	 * %g3 target cpu ptr (modified)
	 * %g4 target channel idx (modified)
	 * %g5 endpoint ptr (modified)
	 * %g6 scratch (modified)
	 * ---
	 * %g1 0=success, else error value
	 */
	/*
	 * append data to the tail of an LDC RX queue and
	 * send cross call notification if necessary
	 *
	 * NOTE: prior to calling this macro, you must already have
	 * verified that there is indeed room available in the RX queue
	 * since this macro does not check for that.
	 */

	lduw	[%g5 + LDC_RX_QTAIL], %g6
	ldx	[%g5 + LDC_RX_QBASE_PA], %g1
	add	%g6, %g1, %g6
	ldx	[%g2 + 0], %g1
	stx	%g1, [%g6 + 0]
	ldx	[%g2 + 8], %g1
	stx	%g1, [%g6 + 8]
	ldx	[%g2 + 16], %g1
	stx	%g1, [%g6 + 16]
	ldx	[%g2 + 24], %g1
	stx	%g1, [%g6 + 24]
	ldx	[%g2 + 32], %g1
	stx	%g1, [%g6 + 32]
	ldx	[%g2 + 40], %g1
	stx	%g1, [%g6 + 40]
	ldx	[%g2 + 48], %g1
	stx	%g1, [%g6 + 48]
	ldx	[%g2 + 56], %g1
	stx	%g1, [%g6 + 56]

	lduw	[%g5 + LDC_RX_QTAIL], %g2
	ldx	[%g5 + LDC_RX_QSIZE], %g1
	dec	Q_EL_SIZE, %g1
	add	%g2, Q_EL_SIZE, %g6
	and	%g6, %g1, %g1
	lduw	[%g5 + LDC_RX_QHEAD], %g6
	stw	%g1, [%g5 + LDC_RX_QTAIL]
	cmp	%g2, %g6
	bne,pn	%xcc, .ldc_send_ret_ok	! if queue was non-empty, then we
	nop				! don't need to send notification.

	STRAND_PUSH(%g7, %g2, %g1)
	mov	%g5, %g3
	HVCALL(hv_ldc_cpu_notify)
	STRAND_POP(%g7, %g2)

.ldc_send_ret_ok:
	mov	%g0, %g1
.ldc_send_ret:
	HVRET
	SET_SIZE(hv_ldc_send_pkt)

	/*
	 * %g3 Rx endpoint
	 * %g1-%g6 clobbered
	 */

	ENTRY(hv_ldc_cpu_notify)

	ldx	[%g3 + LDC_RX_MAPREG + LDC_MAPREG_CPUP], %g1
	brz,pn 	%g1, 2f
	nop

	ldub	[%g3 + LDC_RX_MAPREG + LDC_MAPREG_VALID], %g5
	brz,pn	%g5, 2f		/* interrupt VALID? */
	nop

	ld	[%g3 + LDC_RX_MAPREG + LDC_MAPREG_STATE], %g5
	cmp	%g5, INTR_IDLE		/* interrupt IDLE? */
	bne,pn %xcc, 2f
	nop


	add	%g3, LDC_RX_MAPREG + LDC_MAPREG_STATE, %g4
	set	INTR_DELIVERED, %g5
	set	INTR_IDLE, %g6
	casa	[%g4]ASI_P, %g6, %g5
	cmp	%g5, INTR_IDLE
	bne,a,pn %xcc, 2f
	nop

	ldx	[%g3 + LDC_RX_MAPREG + LDC_MAPREG_COOKIE], %g5
	mov	%g5, %g3
	ba 	send_dev_mondo
	mov	1, %g2
2:

	HVRET
	SET_SIZE(hv_ldc_cpu_notify)
/*
 * Wrapper around hv_ldc_cpu_notify so it can be called from C
 * SPARC ABI requries only that g2,g3,g4 are preserved across
 * function calls.
 *
 * %o0 target ldc endpt
 *
 * void c_ldc_cpu_notify(ldc_endpoint_t *t_endpt)
 */
        ENTRY(c_ldc_cpu_notify)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

        mov     %o0, %g3
	HVCALL(hv_ldc_cpu_notify)

        STRAND_POP(%g4, %g6)
        STRAND_POP(%g3, %g6)
        STRAND_POP(%g2, %g6)

        retl
          nop
        SET_SIZE(c_ldc_cpu_notify)


#if CONFIG_FPGA /* { Support for LDC over the FPGA mailbox */

/*
 * Wrapper around LDC_SEND_SP_INTR so it can be called from C
 * SPARC ABI requries only that %g2,%g3,%g4 are preserved across
 * function calls and we don't use any of these registers here.
 *
 * %o0 = target endpoint
 * %o1 = reason for interrupt
 *
 * void c_ldc_send_sp_intr(stuct *ldc_endpoint target, endpoint, int reason)
 */
        ENTRY(c_ldc_send_sp_intr)

	mov	%o0, %g5
        mov     %o1, %g6

	! %g5	target endpoint
	! %g1 = scratch
	! %g7 = scratch
	! %g6 = reason
        LDC_SEND_SP_INTR(%g5, %g1, %g7, %g6)

        retl
          nop
        SET_SIZE(c_ldc_send_sp_intr)


#endif /* } */
