/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc_common.s
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

	.ident	"@(#)svc_common.s	1.27	07/05/30 SMI"

#ifdef CONFIG_SVC /* { */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <fpga.h>
#include <intr.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <offsets.h>
#include <config.h>
#include <strand.h>
#include <guest.h>
#include <debug.h>
#include <svc.h>
#include <abort.h>
#include <util.h>
#include <ldc.h>
#include <vdev_intr.h>

/*
 * checksum_pkt
 *
 * In
 *  %g1 = buffer
 *  %g2 = len
 * Out
 *  %g1 = checksum
 *  %g3 = scratched
 *  %g4 = scratched
 */
#define addr	%g1
#define len	%g2
#define tmp0	%g3
#define sum	%g4
#define retval	%g1
	ENTRY_NP(checksum_pkt)
	btst	1, len			! len&1 ?
	bz,pt	%xcc, 1f
	  mov	%g0, sum		! sum=0
	subcc	len, 1, len		! decr
	ldub	[addr + len], sum	! preload sum with last byte
	bne,pt	%xcc, 1f		! zero?
	  sub	%g0, 1, tmp0		! this will probably NEVER happen!!
	xor	sum, tmp0, retval	! as this pkt would be too short
	HVRET				! return sum.
1:	lduh	[addr], tmp0
	add	tmp0, sum, sum
	subcc	len, 2, len
	bgt,pt	%xcc, 1b
	  add	addr, 2, addr
2:	srl	sum, 16, tmp0		! get upper 16 bits
	sll	sum, 16, sum
	srl	sum, 16, sum		! chuck upper 16 bits
	brnz,pt	tmp0, 2b
	  add	tmp0, sum, sum
	sub	%g0, 1, len
	srl	len, 16, len		! 0xffff
	xor	sum, len, retval
	HVRET
#undef addr
#undef len
#undef tmp0
#undef sum
#undef retval
	SET_SIZE(checksum_pkt)


/*
 * svc_intr_getstate - return a service's current interrupt state
 *
 * Get the state, mask with the enable bits, or TX and RX with
 * the abort bit, return the result. non-zero means intr pending.
 *
 * %g1 - svc pointer
 * --
 * %g1 - current state
 */
	ENTRY_NP(svc_intr_getstate)
	ld	[%g1 + SVC_CTRL_STATE], %g1
	and	%g1, (SVC_FLAGS_RE | SVC_FLAGS_TE), %g2	! XXX FLAGS MASK
	and	%g1, (SVC_FLAGS_RI | SVC_FLAGS_TI), %g3
	srl	%g2, 1, %g2
	and	%g2, %g3, %g2
	srl	%g2, 2, %g3
	or	%g2, %g3, %g2
	and	%g2, 1, %g2
	srl	%g1, ABORT_SHIFT, %g1		! abort..
	or	%g2, %g1, %g1
	HVRET
	SET_SIZE(svc_intr_getstate)


#if CONFIG_FPGA /* { */

#define FPGA_MBOX_INT_ENABLE(x)				\
	setx	FPGA_INTR_BASE, r_tmp2, r_tmp3		;\
	mov	x, r_tmp2				;\
	stb	r_tmp2, [r_tmp3 + FPGA_MBOX_INTR_ENABLE]

#define r_tmp1	%g1
#define r_tmp2	%g2
#define r_tmp3	%g3
#define r_svc	%g4
#define r_chan	%g5
#define r_root	%g6
#define r_tmp4	%g7

#endif /* } */


/*
 * svc_isr - The mailbox interrupt service routine..
 * we will retry here, as we do not expect to be 'called'
 *
 * r_cpu (%g1) comes from the mondo vector handler.
 *
 * svc_process:
 *	if (intr_status & IRQ_QUEUE_IN) {
 *		goto svc_rx_intr;
 *      }
 *	if (intr_status & IRQ_QUEUE_OUT)
 *		goto svc_tx_intr;
 *	if (intr_status & IRQ_LDC_OUT)
 *		goto svc_ldc_tx_intr;
 *	retry;
 *
 * isr_common:
 *	UNLOCK(lock);
 *	goto svc_process;
 *
 * svc_rx_intr:
 *	...
 *	goto isr_common;
 *
 * svc_tx_intr:
 *	LOCK(lock);
 *	...
 *	goto isr_common;
 */
	ENTRY_NP(svc_isr)

#ifdef CONFIG_FPGA /* { */
	ldx	[%g1 + CPU_ROOT], r_root		! root data
svc_process:
	setx	FPGA_INTR_BASE, r_tmp3, r_tmp2
	ldub	[r_tmp2 + FPGA_MBOX_INTR_STATUS], %g4

	btst	IRQ_QUEUE_IN, %g4
	bnz,pt	%xcc, svc_rx_intr
	  btst	IRQ_QUEUE_OUT, %g4
	bnz,pt	%xcc, svc_tx_intr
	  btst	IRQ_LDC_OUT, %g4
	bnz,pt	%xcc, svc_ldc_tx_intr
	  nop					! more intr srcs here!
	! XXX enable FPGA interrupts.
	FPGA_MBOX_INT_ENABLE(IRQ_QUEUE_IN|IRQ_QUEUE_OUT|IRQ_LDC_OUT)

	/*
	 * Check for a pending non-resumable error. This flag will
	 * be set if the rx handler queued a non-resumable error
	 * to force a guest panic. The non-resumable trap must be
	 * generated only after FPGA interrupts are reenabled, so
	 * it is performed here after the rx processing is complete.
	 */
	STRAND_STRUCT(%g1)
	set	STRAND_NRPENDING, %g2
	ldx	[%g1 + %g2], %g3
	brnz,a,pt %g3, nonresumable_error_trap
	stx	%g0, [%g1 + %g2]

	retry

	ALTENTRY(isr_common)
	/* reload registers */
	VCPU_STRUCT(%g1)
	ROOT_STRUCT(r_root)
	ldx	[r_root + CONFIG_SVCS], r_svc
	ba,a	svc_process			! r_root is ptr to root data
	nop
	SET_SIZE(isr_common)
#endif /* } */

	SET_SIZE(svc_isr)


#if CONFIG_FPGA /* { */

#define INT_ENABLE(x)			\
	ba	isr_common		;\
	  mov	x, %g1

#define	TX_INTR_DONE(x)				\
	VCPU_STRUCT(%g1)			;\
	ROOT_STRUCT(r_root)			;\
	ldx	[r_root + CONFIG_SVCS], r_svc	;\
	UNLOCK(r_svc, HV_SVC_DATA_LOCK)		;\
	INT_ENABLE(x)

#define RX_INTR_DONE(status,r_chan)		\
	mov	status, %g1			;\
	stb	%g1, [r_chan + FPGA_Q_STATUS]   ;\
	INT_ENABLE(IRQ_QUEUE_IN)

	ENTRY_NP(svc_rx_intr)
#ifdef INTR_DEBUG
	PRINT("Got an SSI FPGA RX Interrupt\r\n")
#endif
	ldx	[r_root + CONFIG_SVCS], r_svc
	ldx	[r_svc + HV_SVC_DATA_RXCHANNEL], r_chan	! regs
	lduh	[r_chan + FPGA_Q_SIZE], %g2		! len
	brz,pn	%g2, rxbadpkt
	  ldx	[r_svc + HV_SVC_DATA_RXBASE], %g1	! buffer
	HVCALL(checksum_pkt)
	brnz,pn	%g1, rxbadpkt
	  ldx	[r_root + CONFIG_SVCS], r_svc
	ld	[r_svc + HV_SVC_DATA_NUM_SVCS], r_tmp3	! numsvcs
	ldx	[r_svc + HV_SVC_DATA_RXBASE], r_tmp1	! buffer addr
	add	r_svc, HV_SVC_DATA_SVC, r_svc		! svc base
9:	ld	[r_tmp1 + SVC_PKT_XID], r_tmp2
	ld	[r_svc + SVC_CTRL_XID], r_tmp4	! svc partid
	cmp	r_tmp2, r_tmp4
	bne,pn	%xcc, 1f
	  lduh	[r_tmp1 + SVC_PKT_SID], r_tmp2
	ld	[r_svc + SVC_CTRL_SID], r_tmp4
	cmp	r_tmp2, r_tmp4
	beq,pn	%xcc, rxintr_gotone
1:	  subcc	r_tmp3, 1, r_tmp3			! nsvcs--
	bne,pn	%xcc, 9b
	  add	r_svc, SVC_CTRL_SIZE, r_svc		! next
rxsvc_abort:
	PRINT("Aborted Transport to bad XPID/SVC\r\n")
	RX_INTR_DONE(QINTR_ABORT, r_chan)
rxintr_gotone:
#ifdef INTRDEBUG
	PRINT("Found: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp4	! check config bits
	btst	SVC_CFG_RX, r_tmp4			! can RX ?
	bz,pn	%xcc, rxsvc_abort
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp4
	btst	SVC_FLAGS_RI, r_tmp4			! buffer available?
	bnz,pn	%xcc, rx_busy
	  nop
	! XXX need mutex!!
	lduh	[r_chan + FPGA_Q_SIZE], r_tmp1		! len
	stx	r_tmp1, [r_svc + SVC_CTRL_RECV + SVC_LINK_SIZE] ! len
	ldx	[r_svc + SVC_CTRL_RECV + SVC_LINK_PA], r_tmp3	! dest
	ldx	[r_root + CONFIG_SVCS], r_tmp2
	ldx	[r_tmp2 + HV_SVC_DATA_RXBASE], r_tmp2		! src
	SMALL_COPY_MACRO(r_tmp2, r_tmp1, r_tmp3, r_tmp4)
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp3, r_tmp4)
	ld	[r_svc + SVC_CTRL_STATE], r_tmp4
	btst	SVC_CFG_CALLBACK, r_tmp4
#define r_hvrxcallback r_tmp4
	or	r_tmp4, SVC_FLAGS_RI, r_tmp4
	bnz,pn	%xcc, do_hvrxcallback			! HV callback
	st	r_tmp4, [r_svc + SVC_CTRL_STATE]	! RX pending
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	btst	SVC_FLAGS_RE, r_tmp4			! RECV intr enabled?
	bz,pn	%xcc, 2f
	  ldx	[r_svc + SVC_CTRL_INTR_COOKIE], %g1	! Cookie
	PRINT("XXX - SVC INTR SENDING RX PENDING INTR - XXX\r\n")
	ba	vdev_intr_generate			! deliver??
	  rd	%pc, %g7
2:
	ROOT_STRUCT(r_root)
	ldx	[r_root + CONFIG_SVCS], r_svc
	ldx	[r_svc + HV_SVC_DATA_RXCHANNEL], r_chan	! regs
	RX_INTR_DONE(QINTR_ACK, r_chan)
rx_busy:
	PRINT("SVC Buffer Busy\r\n")
	RX_INTR_DONE(QINTR_BUSY, r_chan)
rxbadpkt:
	PRINT("SVC RX Bad packet: "); PRINTX(%g1); PRINT("\r\n")
	RX_INTR_DONE(QINTR_NACK, r_chan)
	SET_SIZE(svc_rx_intr)


	ENTRY_NP(svc_tx_intr)
#ifdef INTR_DEBUG
	PRINT("Got an SSI FPGA TX Interrupt: ")
	ldx	[%g1 + CPU_ROOT], r_root			! data root
	ldx	[r_root + HV_SVC_DATA_TXCHANNEL], r_chan	! regs
	ldub	[r_chan + FPGA_Q_STATUS], r_tmp3		! status
	PRINTX(r_tmp3)
	PRINT("\r\n")
#endif
	! XXX need mutex!!
	ldx	[%g1 + CPU_ROOT], r_root			! data root
	ldx	[r_root + CONFIG_SVCS], r_root			! svc root

	LOCK(r_root, HV_SVC_DATA_LOCK, r_svc, r_chan)

	ldx	[r_root + HV_SVC_DATA_SENDH], r_svc		! head of tx q
	brz,pn	r_svc, tx_nointr
	  ldx	[r_root + HV_SVC_DATA_TXCHANNEL], r_chan	! regs
	ldub	[r_chan + FPGA_Q_STATUS], r_tmp3		! status
	sth	%g0, [r_chan + FPGA_Q_SIZE]			! len=0
	btst	QINTR_ACK, r_tmp3
	bnz,pt	%xcc, txpacket_ack
	btst	QINTR_NACK, r_tmp3
	bnz,pt	%xcc, txpacket_nack
	btst	QINTR_BUSY, r_tmp3
	bnz,pt	%xcc, txpacket_busy
	btst	QINTR_ABORT, r_tmp3
	bnz,pt	%xcc, txpacket_abort
	nop
#ifdef INTR_DEBUG
	PRINT("XXX unserviced bits in tx status register: ")
	PRINTX(r_tmp3)
	PRINT("\r\n")
#endif
	TX_INTR_DONE(IRQ_QUEUE_OUT)

txpacket_nack:
#ifdef INTR_DEBUG
	PRINT("txSVC NACK!!\r\n")
#endif
	ba	defer_pkt
	  mov	1, %g7					! Nack..

txpacket_abort:
#ifdef INTR_DEBUG
	PRINT("txSVC Abort!!\r\n")
#endif
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp2, r_tmp1)
	ld	[r_svc + SVC_CTRL_STATE], r_tmp2
	andn	r_tmp2, SVC_FLAGS_TP, r_tmp2
	or	r_tmp2, SVC_FLAG_ABORT, r_tmp2
	st	r_tmp2, [r_svc + SVC_CTRL_STATE]
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ba	txintr_done
	  stb	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status

txpacket_busy:
#ifdef INTR_DEBUG
	PRINT("txSVC Busy!!\r\n")
#endif
	mov	0, %g7		! ??? Ack?
	/*FALLTHROUGH*/

defer_pkt:
	!! %g7 = 1=NACK, 0=BUSY  ??? something.
	stb	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status
#ifdef INTR_DEBUG
	PRINT("Deferring..\r\n")
#endif
	ROOT_STRUCT(r_root)
	ldx	[r_root + CONFIG_SVCS], r_root			! svc root
#if 1 /* XXX */
	/*
	 * XXX we should delay and resend later or at least put this
	 * packet on the end of the queue so other packets have a chance.
	 */
	ldx	[r_root + HV_SVC_DATA_SENDH], r_svc		! head of tx q
	SEND_SVC_PACKET(r_root, r_svc, r_tmp1, r_tmp2, r_tmp3, r_tmp4)
	ba	txintr_done
	nop
#else
	/*
	 * Move the current head to the end of the queue:
	 *	if (head->next != NULL) {
	 *		tmp1 = head
	 *		head = tmp1->next
	 *		tmp1->next = NULL
	 *		tail->next = tmp1
	 *		tail = tmp1
	 *	}
	 */
	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp1
	ldx	[r_tmp1 + SVC_CTRL_SEND + SVC_LINK_NEXT], r_tmp2
	brz,pt	r_tmp2, hv_txintr	! only item on list
	nop
	stx	r_tmp2, [r_root + HV_SVC_DATA_SENDH]
	stx	%g0, [r_tmp1 + SVC_CTRL_SEND + SVC_LINK_NEXT]
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp2
	stx	r_tmp1, [r_tmp2 + SVC_CTRL_SEND + SVC_LINK_NEXT]
	stx	r_tmp1, [r_root + HV_SVC_DATA_SENDT]
#ifdef INTR_DEBUG
	PRINT("round-robin\r\n")
#endif
	ba,pt	%xcc, hv_txintr
	nop
#endif

txpacket_ack:
	stb	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp2, r_tmp1)

	/* Mark busy, prevents svc_internal_send from touching fpga */
	mov	-1, r_tmp2
	stw	r_tmp2, [r_root + HV_SVC_DATA_SENDBUSY]

	/* Remove head from list prior to calling the tx callback */
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT], r_tmp2
	stx	r_tmp2, [r_root + HV_SVC_DATA_SENDH]
	brz,a,pt r_tmp2, 1f
	stx	%g0, [r_root + HV_SVC_DATA_SENDT]
1:	stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT]

	ld	[r_svc + SVC_CTRL_STATE], r_tmp2
	andn	r_tmp2, SVC_FLAGS_TP, r_tmp2
	or	r_tmp2, SVC_FLAGS_TI, r_tmp2
	st	r_tmp2, [r_svc + SVC_CTRL_STATE]
	btst	SVC_CFG_CALLBACK, r_tmp2
#define r_hvtxcallback r_tmp2
	bnz,pn	%xcc, do_hvtxcallback				! HV callback
	nop
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	btst	SVC_FLAGS_TE, r_tmp2
	bz,pn	%xcc, hv_txintr
	ldx	[r_svc + SVC_CTRL_INTR_COOKIE], %g1		! Cookie
	ba	vdev_intr_generate				! deliver??
	  rd	%pc, %g7
hv_txintr:
	! rebuild the regs we care about
	VCPU_STRUCT(%g1)
	ROOT_STRUCT(r_root)
	ldx	[r_root + CONFIG_SVCS], r_root			! svc root

	/* clear busy */
	stw	%g0, [r_root + HV_SVC_DATA_SENDBUSY]

	ldx	[r_root + HV_SVC_DATA_SENDH], r_svc		! head of tx q
#ifdef INTR_DEBUG
	PRINT("Next Packet: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	brz,pn	r_svc, txintr_done
	nop
	SEND_SVC_PACKET(r_root, r_svc, r_tmp1, r_tmp2, r_tmp3, r_tmp4)
txintr_done:
	TX_INTR_DONE(IRQ_QUEUE_OUT)

tx_nointr:
	ldub	[r_chan + FPGA_Q_STATUS], r_tmp3		! get status
	stb	r_tmp3, [r_chan + FPGA_Q_STATUS]		! clr status
	TX_INTR_DONE(IRQ_QUEUE_OUT)
	SET_SIZE(svc_tx_intr)
#undef r_tmp1
#if 0
#undef r_tmp3
#undef r_tmp2
#undef r_svc
#undef r_chan
#endif

/*
 * SAVE/RESTORE_SVCREGS - save/restore all registers except %g7 which
 * gets clobbered
 */
#define SAVE_SVCREGS				\
	VCPU_STRUCT(%g7)			;\
	add	%g7, CPU_SVCREGS, %g7		;\
	stx	%g1, [%g7 + 0x00]		;\
	stx	%g2, [%g7 + 0x08]		;\
	stx	%g3, [%g7 + 0x10]		;\
	stx	%g4, [%g7 + 0x18]		;\
	stx	%g5, [%g7 + 0x20]		;\
	stx	%g6, [%g7 + 0x28]		;

#define RESTORE_SVCREGS				\
	VCPU_STRUCT(%g7)			;\
	add	%g7, CPU_SVCREGS, %g7		;\
	ldx	[%g7 + 0x00], %g1		;\
	ldx	[%g7 + 0x08], %g2		;\
	ldx	[%g7 + 0x10], %g3		;\
	ldx	[%g7 + 0x18], %g4		;\
	ldx	[%g7 + 0x20], %g5		;\
	ldx	[%g7 + 0x28], %g6

/*
 * Perform a hypervisor callback for a receive channel
 *
 * The callback cookie is passed in %g1.
 * The svc pointer %g2, state is RI.  If the
 * packet has been successfully processed then the callback
 * routine needs to clear the RI flag.
 */
	ENTRY_NP(do_hvrxcallback)
#ifdef INTRDEBUG
	PRINT("do_hvrxcallback\r\n")
#endif
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_RX], %g7
	brz,pn	%g7, 9f
	  nop
	SAVE_SVCREGS
#ifdef INTRDEBUG
	PRINT("HV RX Callback: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_RX], %g7
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_COOKIE], %g1
	mov	r_svc, %g2
	jmp	%g7
	  rd	%pc, %g7
	RESTORE_SVCREGS
9:	RX_INTR_DONE(QINTR_ACK, r_chan)
	SET_SIZE(do_hvrxcallback)

	ENTRY_NP(do_hvtxcallback)
#ifdef INTRDEBUG
	PRINT("do_hvtxcallback\r\n")
#endif
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_TX], %g1
	brz,pn	%g1, hv_txintr
	  nop
	SAVE_SVCREGS
#ifdef INTRDEBUG
	PRINT("HV TX Callback: "); PRINTX(r_svc); PRINT("\r\n")
#endif
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_TX], %g6
	ldx	[r_svc + SVC_CTRL_CALLBACK + SVC_CALLBACK_COOKIE], %g1
	!! XXX is this useful
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], %g2
	add	%g2, SVC_PKT_SIZE, %g2		! skip header
	jmp	%g6
	  rd	%pc, %g7
	RESTORE_SVCREGS
9:	ba	hv_txintr
	  nop
	SET_SIZE(do_hvtxcallback)
#undef r_tmp3
#undef r_tmp2
#undef r_tmp4
#undef r_svc
#undef r_chan

#endif /* } */
#endif /* } CONFIG_SVC */
