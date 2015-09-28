/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ssi.s
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

	.ident	"@(#)ssi.s	1.4	07/06/20 SMI"

	.file	"ssi.s"

#ifdef CONFIG_FPGA

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <asi.h>
#include <offsets.h>
#include <util.h>
#include <fpga.h>
#include <ldc.h>
#include <intr.h>
#include <vdev_ops.h>

	/*
	 * fpga_intr
	 *
	 * %g1 - cpup
	 */
	ENTRY(fpga_intr)

	FPGA_MBOX_INT_DISABLE(IRQ_QUEUE_IN|IRQ_QUEUE_OUT|IRQ_LDC_OUT, %g2, %g3)

#ifdef	CONFIG_FPGA_UART
	mov	DEVOPS_FPGA, %g1
	GUEST_STRUCT(%g4)
	DEVINST2COOKIE(%g4, %g1, %g1, %g5, badtrap)


	HVCALL(fpga_uart_mondo_receive)

	VCPU_STRUCT(%g1)
#endif	/* CONFIG_FPGA_UART */

#ifdef CONFIG_SVC
	ba,pt	%xcc, svc_isr
	nop
#else
	retry	
#endif
	SET_SIZE(fpga_intr)

	/*
	 * Move SSI interrupts from CPU %g1 onto CPU %g2
	 */
	ENTRY(ssi_redistribute_interrupts)

	setx	NCU_BASE, %g3, %g4
	ldx	[%g4 + INT_MAN + INT_MAN_DEV_OFF(NCUDEV_SSIERR)], %g5
	srl	%g5, INTRTGT_DEVSHIFT, %g5
	and	%g5, INTRTGT_CPUMASK, %g5
	! %g5	current interrupt target
	! %g1	CPU in error
	cmp	%g1, %g5
	be,pt	%xcc, 1f
	nop

	/*
	 * The CPU in error does not have any interrupts targetted at 
	 * it so just exit
	 */
	HVRET
1:

	mov	%g2, %g1			! %g1	new interrupt target
	sllx    %g1, 1 * INTRTGT_DEVSHIFT, %g2
        sllx    %g1, 2 * INTRTGT_DEVSHIFT, %g3
        or      %g3, %g2, %g3
	ROOT_STRUCT(%g2)
	stx	%g3, [%g2 + CONFIG_INTRTGT]

	/*
	 * setup the map registers for the SSI
	 * %g1 	intrtgt CPUID array (8-bits per INT_MAN target)
	 * %g4 	NCU Base address
	 */

	/*
	 * SSI Error interrupt
	 */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev1 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_SSIERR, %g3 ! int_man.vecnum
	stx	%g3, [%g4 + INT_MAN + INT_MAN_DEV_OFF(NCUDEV_SSIERR)]

	/*
	 * SSI Interrupt
	 */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev2 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_FPGA, %g3 ! int_man.vecnum
	stx	%g3, [%g4 + INT_MAN + INT_MAN_DEV_OFF(NCUDEV_SSI)]

	HVRET
	SET_SIZE(ssi_redistribute_interrupts)

#define INT_ENABLE(x)			\
        ba	isr_common		;\
	mov	x, %g1

/*
 * Handles the LDC interrupt from the SP.
 */
	ENTRY_NP(svc_ldc_tx_intr)

#ifdef INTR_DEBUG
	PRINT("got LDX TX\r\n")
#endif

	setx	FPGA_LDCIN_BASE, %g3, %g5
	ld	[%g5 + FPGA_LDC_RECV_REG], %g3	! read recv

	! %g3	RECV register
.ldc_recv_intrs:

	! If no more interrupts are pending, exit
	brz,pn	%g3, .svc_ldc_tx_intr_exit
	.empty

	/*
	 * The RECV register bits [30:16] are for data notifications
	 * for the corresponding channel.
	 *
	 * The RECV register bits [14:0] are for space available
	 * notifications for the corresponding channel.
	 *
	 * RECV register bit[31] is for STATE_CHG notification.
	 */

	! Find the first bit set in the RECV register
	neg	%g3, %g4
	xnor	%g3, %g4, %g6
	popc	%g6, %g4
	dec	%g4

	! %g3	RECV register contents
	! %g4	first bit set
	! %g5	FPGA_LDCIN_BASE

	/*
	 * Clear bit %g4 in RECV register (%g3)
	 */
	mov	1, %g6
	sllx	%g6, %g4, %g6
	st	%g6, [%g5 + FPGA_LDC_RECV_REG]	! RW1C

	cmp	%g4, FPGA_LDC_RECV_TX_CHANNELS	! space notification
	bl	%xcc, .ldc_tx_intr
	cmp	%g4, FPGA_LDC_RECV_RX_CHANNELS	! data notification
	bl	%xcc, .ldc_rx_intr
	sub	%g4, FPGA_LDC_RECV_TX_CHANNELS + 1, %g4	! bit 16 -> channel 0 ...

	/* FALLTHRU */

.ldc_reset_intr:

#ifdef INTR_DEBUG
	PRINT("LDX Reset\r\n")
#endif

	HVCALL(svc_ldc_reset_intr)

	setx	FPGA_LDCIN_BASE, %g3, %g5
	ba,pt	%xcc, .ldc_recv_intrs
	ld      [%g5 + FPGA_LDC_RECV_REG], %g3  ! read recv

.ldc_rx_intr:

#ifdef INTR_DEBUG
	PRINT("LDX TX data available\r\n")
#endif

	! %g4	channel number
	HVCALL(svc_ldc_data_available)

	! next notification
	setx	FPGA_LDCIN_BASE, %g3, %g5
	ba,pt	%xcc, .ldc_recv_intrs
	ld      [%g5 + FPGA_LDC_RECV_REG], %g3  ! read recv

.ldc_tx_intr:

#ifdef INTR_DEBUG
	PRINT("LDX TX space available\r\n")
#endif

	! %g4	channel number
	HVCALL(svc_ldc_space_available)

	! next notification
	setx	FPGA_LDCIN_BASE, %g3, %g5
	ba,pt	%xcc, .ldc_recv_intrs
	ld      [%g5 + FPGA_LDC_RECV_REG], %g3  ! read recv

.svc_ldc_tx_intr_exit:

	! back to ISR handling
	INT_ENABLE(IRQ_LDC_OUT)
	/* NOTREACHED */

	SET_SIZE(svc_ldc_tx_intr)


/*
 * Handles the LDC BUSY interrupt from the SP which indicates that the
 * SP has just sent us one or more LDC packets across the SRAM.
 *
 * For guest<->SP connections, we simply check to see if there is
 * any data available on any of the incoming SRAM queues. If so,
 * we send notification to the appropriate guest (if the guest's queue
 * is currently empty).
 *
 * %g4	- channel
 * %g7 	- holds calling pc value.
 */
	ENTRY_NP(svc_ldc_data_available)

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SP_LDCS], %g1	! get SP endpoint array
	mulx	%g4, SP_LDC_ENDPOINT_SIZE, %g2
	add	%g1, %g2, %g1			! pointer to SP endpoint

	! %g1 = SP endpoint which received the notification
	! %g7 = return %pc



	ldub	[%g1 + SP_LDC_IS_LIVE], %g2	! is channel open?
	brz	%g2, .exit_ldc_rx_channel
	  nop

.one_more_ldc_rx_channel:

	! check to see whether there are any packets
	! available on this channel.

	ldx	[ %g1 + SP_LDC_RX_QD_PA ], %g2
	ldub	[ %g2 + SRAM_LDC_HEAD ], %g3
	ldub	[ %g2 + SRAM_LDC_TAIL ], %g4

	cmp	%g3, %g4
	be	%xcc, .exit_ldc_rx_channel	! nothing to pick up
	  nop

	ldub	[ %g1 + SP_LDC_TARGET_TYPE ], %g3
	cmp	%g3, LDC_GUEST_ENDPOINT
	be	.svc_ldc_guest_target
	  nop

	! This is a SP<->HV channel so we must read out each packet
	! and call the appropriate callback routine for each one.

	! NOTE:	There is no need to grab the RX_LOCK in this situation
	! because we are executing with FPGA interrupts off and this
	! is the only routine used for receiving data from the SRAM
	! since it is a SP<->HV channel.

		! %g1 = sp endpoint
		! %g7 = return %pc

	! snapshot queue state into our scratch register area
	! since we will be copying the data in possibly several
	! passes.

	ldx	[ %g1 + SP_LDC_RX_QD_PA ], %g5
	ldub	[ %g5 + SRAM_LDC_HEAD ], %g3
	LDC_SRAM_IDX_TO_OFFSET(%g3)
	stw	%g3, [ %g1 + SP_LDC_RX_SCR_TXHEAD ]	! TX head
	ldub	[ %g5 + SRAM_LDC_TAIL ], %g3
	LDC_SRAM_IDX_TO_OFFSET(%g3)
	stw	%g3, [ %g1 + SP_LDC_RX_SCR_TXTAIL ]	! TX tail
	set	(SRAM_LDC_QENTRY_SIZE * SRAM_LDC_ENTRIES_PER_QUEUE), %g3
	stx	%g3, [ %g1 + SP_LDC_RX_SCR_TXSIZE ]	! TX size

		! %g1 = sp endpoint
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor !CONFIG_SPLIT_SRAM)
		! %g7 = return %pc

.read_more_sram_pkts:

		! %g1 = sp endpoint
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor !CONFIG_SPLIT_SRAM)
		! %g7 = return %pc

	lduw	[ %g1 + SP_LDC_RX_SCR_TXHEAD ], %g2
	lduw	[ %g1 + SP_LDC_RX_SCR_TXTAIL ], %g3
	ldx	[ %g1 + SP_LDC_RX_SCR_TXSIZE ], %g4

	LDC_QUEUE_DATA_AVAILABLE(%g2, %g3, %g4)
	LDC_SRAM_OFFSET_TO_IDX(%g3)

		! %g1 = sp endpoint
		! %g2 = TX head offset
		! %g3 = packets of data to copy
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor !CONFIG_SPLIT_SRAM)
		! %g7 = return %pc

	brlez	%g3, .done_read_sram_pkts
	  nop

#ifdef CONFIG_SPLIT_SRAM
	ldx	[ %g1 + SP_LDC_RX_Q_DATA_PA ], %g5	! queue data PA
#endif

	add	%g2, %g5, %g2			! PA of TX queue data
	add	%g1, SP_LDC_RX_SCR_PKT, %g4	! PA of RX scratch buffer

		! %g1 = sp endpoint
		! %g2 = TX head PA
		! %g4 = payload buffer
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor !CONFIG_SPLIT_SRAM)
		! - or -
		! %g5 = SRAM Queue Data PA (CONFIG_SPLIT_SRAM)
		! %g7 = return %pc

	LDC_COPY_PKT_FROM_SRAM(%g2, %g4, %g3, %g6)

		! %g1 = sp endpoint
		! %g2 = new TX head PA
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor)
		! %g7 = return %pc

	! Now we need to update our scratchpad head pointer
	sub	%g2, %g5, %g2			! New TX head offset
	ldx	[ %g1 + SP_LDC_RX_SCR_TXSIZE ], %g6
	cmp	%g2, %g6
	move	%xcc, 0, %g2			! check for wrap around
	stw	%g2, [ %g1 + SP_LDC_RX_SCR_TXHEAD ]

		! %g1 = sp endpoint
		! %g7 = return %pc

	VCPU_STRUCT(%g3)
	ldx	[%g3 + CPU_ROOT], %g3
	ldx	[%g3 + CONFIG_HV_LDCS], %g3		! get HV endpoint array
	ldx	[%g1 + SP_LDC_TARGET_CHANNEL], %g6 	! and target endpoint
	mulx	%g6, LDC_ENDPOINT_SIZE, %g4
	add	%g3, %g4, %g4				! and its struct

	ldx	[%g4 + LDC_RX_CB], %g6			! get the callback
	brz,pn	%g6, .done_read_sram_pkts		!   if none, drop pkt
	  nop

	STRAND_PUSH(%g1, %g2, %g3)
	STRAND_PUSH(%g7, %g2, %g3)

	add	%g1, SP_LDC_RX_SCR_PKT, %g2		! payload
	ldx	[%g4 + LDC_RX_CBARG], %g1		! load the argument

		! %g1 = call back arg
		! %g2 = payload PA
		! %g6 = callback

 	jmp	%g6					! invoke callback
	  rd	%pc, %g7

		! Assume all %g registers clobbered

	STRAND_POP(%g7, %g2)
	STRAND_POP(%g1, %g2)

#ifndef CONFIG_SPLIT_SRAM
	ldx	[%g1 + SP_LDC_RX_QD_PA], %g5
#endif

		! %g1 = sp endpoint
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor !CONFIG_SPLIT_SRAM)
		! %g7 = return %pc

	ba	.read_more_sram_pkts
	  nop

.done_read_sram_pkts:

		! %g1 = sp endpoint
		! %g5 = SRAM Queue base PA (SRAM Queue Descriptor !CONFIG_SPLIT_SRAM)
		! %g7 = return %pc

	lduw	[ %g1 + SP_LDC_RX_SCR_TXHEAD ], %g3
	LDC_SRAM_OFFSET_TO_IDX(%g3)
#ifdef CONFIG_SPLIT_SRAM
	ldx	[%g1 + SP_LDC_RX_QD_PA], %g5	! queue data PA
#endif
	stb	%g3, [ %g5 + SRAM_LDC_HEAD ]	! commit the new TX head

	STRAND_PUSH(%g1, %g2, %g3)
	! %g1	target endpoint (clobbered)
	LDC_SEND_SP_INTR(%g1, %g3, %g4, SP_LDC_SPACE)
	STRAND_POP(%g1, %g2)

		! %g1 = SP endpoint
		! %g7 = return %pc

	! At this point, since we just updated the SRAM head index, we
	! need re-read the head/tail value from SRAM and make sure no new
	! packets were added while we were processing the last one.
	ba,a	.one_more_ldc_rx_channel
	nop

.svc_ldc_guest_target:

		! %g1 = SP endpoint
		! %g7 = return %pc

	ldx	[ %g1 + SP_LDC_TARGET_GUEST ], %g3
	brz	%g3, .exit_ldc_rx_channel
	  nop

	ldx	[ %g1 + SP_LDC_TARGET_CHANNEL ], %g6
	mulx	%g6, LDC_ENDPOINT_SIZE, %g4
	set	GUEST_LDC_ENDPOINT, %g5
	add	%g5, %g3, %g5
	add	%g4, %g5, %g3

		! %g1 = SP endpoint
		! %g3 = guest endpoint
		! %g7 = return %pc

	! See if we need to send an interrupt to the recipient
	ldx	[ %g3 + LDC_RX_MAPREG + LDC_MAPREG_CPUP ], %g6
	brnz,pt %g6, 1f
	  nop

	! if no target CPU specified, is there a vdev interrupt we
	! need to generate?
	ldx	[ %g3 + LDC_RX_VINTR_COOKIE ], %g6
	brz,pn	%g6, .exit_ldc_rx_channel		! if not, we are done.
	  nop

	STRAND_PUSH(%g7, %g2, %g4)

	mov	%g6, %g1
	HVCALL(vdev_intr_generate)

	STRAND_POP(%g7, %g2)

		! %g1 = SP endpoint
		! %g3 = guest endpoint
		! %g7 = return %pc

	ba	.exit_ldc_rx_channel
	  nop
1:
		! %g1 = SP endpoint
		! %g3 = guest endpoint
		! %g6 = target cpu struct
		! %g7 = return %pc

	! Only need to send notification if guest RX queue is empty.
	! No synchronization issues with respect to lost notification here
	! because the guest's rx_set_qhead routine pulls data from the SRAM
	! after updating the head pointer with the guest specified value.
	lduw	[ %g3 + LDC_RX_QHEAD ], %g4
	lduw	[ %g3 + LDC_RX_QTAIL ], %g5
	cmp	%g4, %g5
	bne	%xcc, .exit_ldc_rx_channel
	  nop

		! %g1 = SP endpoint
		! %g3 = guest endpoint
		! %g6 = target cpu struct
		! %g7 = return %pc
	STRAND_PUSH(%g7, %g2, %g4)
	HVCALL(hv_ldc_cpu_notify)
	STRAND_POP(%g7, %g2)

		! %g7 = return %pc

.exit_ldc_rx_channel:

	HVRET
	SET_SIZE(svc_ldc_data_available)


/*
 * Handles the LDC ACK interrupt from the SP which indicates that the
 * SP has freed up some room in the SRAM LDC queues for us so that we
 * may once again send more packets if needed.
 *
 * %g4	- channel which received the notification
 * %g7 	- holds calling pc value.
 */
	ENTRY_NP(svc_ldc_space_available)

        STRAND_PUSH(%g7, %g1, %g2)

	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SP_LDCS], %g1	! get SP endpoint array
	mulx	%g4, SP_LDC_ENDPOINT_SIZE, %g2
	add	%g1, %g2, %g1			! pointer to SP endpoint
	clr	%g6				! SP notification flag

	! %g1 = SP endpoint which received t henotication
	! %g6 = 0 (notification flag)
	! %g7 = return PC

	ldub	[%g1 + SP_LDC_IS_LIVE], %g2	! is channel open?
	brz	%g2, .exit_ldc_tx_channel
	  nop

	! If this is a SP <-> HV connection (guest ptr==NULL) then
	! there is nothing really to do.
	ldx	[ %g1 + SP_LDC_TARGET_GUEST ], %g3
	brz	%g3, .exit_ldc_tx_channel
	  nop

	! SP <-> Guest channel

	ldx	[ %g1 + SP_LDC_TARGET_CHANNEL ], %g4
	mulx	%g4, LDC_ENDPOINT_SIZE, %g4
	set	GUEST_LDC_ENDPOINT, %g5
	add	%g5, %g3, %g5
	add	%g4, %g5, %g3

		! %g1 = SP endpoint
		! %g3 = guest endpoint
		! %g6 = (notification flag)
		! %g7 = return PC

	! Nothing to send if guest TX queue is empty
	lduw	[ %g3 + LDC_TX_QHEAD ], %g4
	lduw	[ %g3 + LDC_TX_QTAIL ], %g5
	cmp	%g4, %g5
	be	%xcc, .exit_ldc_tx_channel
	  nop

		! %g1 = SP endpoint
		! %g3 = guest endpoint

	mov	%g3, %g2
	mov	%g1, %g3

		! %g2 = guest endpoint
		! %g3 = sp endpoint

	STRAND_PUSH(%g2, %g1, %g4)	! save guest endpoint

	add	%g3, SP_LDC_TX_LOCK, %g5
	SPINLOCK_ENTER(%g5, %g1, %g4)

	HVCALL(sram_ldc_push_data)	! %g3 (sp endpoint) preserved

	add	%g3, SP_LDC_TX_LOCK, %g5
	SPINLOCK_EXIT(%g5)

	mov	%g3, %g1

	clr	%g3
	movrnz	%g2, 1, %g3		! %g2 = send interrupt flag
	or	%g6, %g3, %g6

		! %g1 = sp endpoint
		! %g6 = (notification flag)

	STRAND_POP(%g2, %g3)	! restore guest endpoint

		! %g2 = sender's (guest) endpoint

	! We might need to send a 'queue no longer full' interrupt
	! in certain situations.
	ldub	[ %g2 + LDC_TXQ_FULL ], %g3
	brz,pt	%g3, .exit_ldc_tx_channel
	  nop
	stb	%g0, [ %g2 + LDC_TXQ_FULL ]

	ldx	[%g2 + LDC_RX_VINTR_COOKIE], %g2
	brz	%g2, .exit_ldc_tx_channel
	  nop

	! save off registers
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g6, %g3, %g4)

	mov	%g2, %g1
	HVCALL(vdev_intr_generate)

	! restore registers
	STRAND_POP(%g6, %g3)
	STRAND_POP(%g1, %g3)

.exit_ldc_tx_channel:

	! Done checking all SRAM queues
	btst	1, %g6
	bz	%xcc, 1f	! skip TX notification if flag is clear
	  nop

	! %g1	target endpoint (clobbered)
	LDC_SEND_SP_INTR(%g1, %g6, %g4, SP_LDC_DATA)
1:
        STRAND_POP(%g7, %g5)
	HVRET
	SET_SIZE(svc_ldc_space_available)


/*
 * Called when the SP sends us notification for a channel reset so that
 * we can forward the notification interrupt to a guest if necessary.
 *
 * %g7 - holds calling pc value.
 */
	ENTRY_NP(svc_ldc_reset_intr)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SP_LDC_MAX_CID], %g2
	ldx	[%g1 + CONFIG_SP_LDCS], %g1	! get SP endpoint array

	mulx	%g2, SP_LDC_ENDPOINT_SIZE, %g2
	add	%g1, %g2, %g1			! pointer to last SP endpoint

.one_more_sram_channel:

		! %g1 = SP endpoint

	ldub	[%g1 + SP_LDC_IS_LIVE], %g2	! is channel open?
	brz	%g2, .next_ldc_sram_channel
	  nop

	! check to see whether there is a reset notification pending
	! for this channel.
	ldx	[ %g1 + SP_LDC_TX_QD_PA ], %g2
	ldub	[ %g2 + SRAM_LDC_STATE_NOTIFY ], %g3
	brz,pt	%g3, .next_ldc_sram_channel
	  nop

	! reset notification is pending for this channel
	stb	%g0, [ %g2 + SRAM_LDC_STATE_NOTIFY ]	! clear the flag

	! For SP<->HV connections (guest ptr==NULL), there is nothing to
	! do at this point.
	ldx	[ %g1 + SP_LDC_TARGET_GUEST ], %g3
	brz	%g3, .next_ldc_sram_channel
	  nop

	ldx	[ %g1 + SP_LDC_TARGET_CHANNEL ], %g4
	mulx	%g4, LDC_ENDPOINT_SIZE, %g4
	set	GUEST_LDC_ENDPOINT, %g5
	add	%g5, %g3, %g5
	add	%g4, %g5, %g3

		! %g1 = SP endpoint
		! %g3 = guest endpoint

	! skip notification if no CPU is specified to handle interrupts
	ldx	[ %g3 + LDC_RX_MAPREG + LDC_MAPREG_CPUP ], %g6
	brz,pn %g6, .next_ldc_sram_channel
	  nop

		! %g1 = SP endpoint
		! %g3 = guest endpoint
		! %g6 = target cpu struct
	STRAND_PUSH(%g1, %g2, %g4)
	STRAND_PUSH(%g7, %g2, %g4)
	STRAND_PUSH(%g6, %g2, %g4)
	HVCALL(hv_ldc_cpu_notify)
	STRAND_POP(%g6, %g2)
	STRAND_POP(%g7, %g2)
	STRAND_POP(%g1, %g2)
		! %g1 = SP endpoint

.next_ldc_sram_channel:

	ROOT_STRUCT(%g2)
	ldx	[%g2 + CONFIG_SP_LDCS], %g2	! first SP endpoint
	cmp	%g1, %g2			! did we just process it?
	bgu,pt	%xcc, .one_more_sram_channel
	  sub	%g1, SP_LDC_ENDPOINT_SIZE, %g1

	HVRET
	SET_SIZE(svc_ldc_reset_intr)

#endif	/* CONFIG_FPGA */
