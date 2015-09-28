/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: chipsubr.s
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

	.ident	"@(#)chipsubr.s	1.8	07/05/04 SMI"

/*
 * Routines that are specific to this chipset
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hprivregs.h>
#include <asi.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sparcv9/asi.h>
#include <offsets.h>
#include <guest.h>
#include <abort.h>
#include <util.h>
#include <intr.h>
#include <fpga.h>
#include <debug.h>


/*
 * halt_strand - stop the current running strand while there are
 * no interrupts of any kind pending.
 *
 *	%g7 = return address
 *
 * Clobbers:
 *	%g1
 */

	ENTRY(halt_strand)

	mov	%g7, %g6	! preserve return address
	HALT_STRAND()
	mov	%g6, %g7

	HVRET
	SET_SIZE(halt_strand)


/*
 * hvmondo_send - send a HV mondo to another specified strand
 * NOTE: blocks for the moment
 *
 * %g1 - target strandp
 * %g2 - mondo ptr
 * %g7 - return addr
 *
 * Clobbers:
 * %g1 - %g7
 */
	ENTRY(hvmondo_send)
		/* Try and grab the target mondo mailbox */
	add	%g1, STRAND_XCALL_MBOX + XCMB_COMMAND, %g5
1:
	mov	HXMB_BUSY, %g4
	casxa	[%g5]ASI_P, %g0, %g4
	brnz,pn	%g4, 1b
	  nop
	membar	#StoreStore	/* ensure all our stores are done */

		/* Copy the mondo to the mailbox */
	add	%g1, STRAND_XCALL_MBOX + XCMB_MONDOBUF, %g4

#define	MV(_o)	\
	ldx	[%g2 + (_o)*8], %g3	;\
	stx	%g3, [%g4 + (_o)*8]

	MV(0)
	MV(1)
	MV(2)
	MV(3)
	MV(4)
	MV(5)
	MV(6)
	MV(7)
#undef 	MV
	
		/* signal the MB command */
	mov	HXMB_NEWMONDO, %g3
	stx	%g3, [%g5]

		/* now poke the target strand */
	ldub	[%g1 + STRAND_ID], %g3
	sllx	%g3, INT_VEC_DIS_VCID_SHIFT, %g3
	mov	VECINTR_HVXCALL, %g4
	or	%g3, %g4, %g3
	stxa	%g3, [%g0]ASI_INTR_UDB_W
	HVRET
	SET_SIZE(hvmondo_send)


/*
 * Wrapper around hvmondo_send, so it can be called from C
 * SPARC ABI requries only that g2,g3,g4 are preserved across
 * function calls.
 * %o0 = target strandp
 * %o1 = mondo ptr
 *
 * void c_hvmondo_send(strand_t targetp, hvm_t *msgp)
 */
	ENTRY(c_hvmondo_send)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	mov	%o0, %g1
	mov	%o1, %g2
	HVCALL(hvmondo_send)

	STRAND_POP(%g4, %g6)
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	
	retl
	  nop
	SET_SIZE(c_hvmondo_send)


/*
 * Stall waiting for a hv mondo interrupt.
 * We wait for the X-call interrupt ; not the CMD word
 * A send *must* sent the PYN interrupt bit
 */
	ENTRY(hvmondo_wait)
1:
	membar	#Sync	/* ERRATUM 43 */
	ldxa	[%g0]ASI_INTR_UDB_R, %g1
	brnz,pn	%g1, 2f
	  nop

	mov	%g7, %g6
	HALT_STRAND()
	mov	%g6, %g7

	ba,pt	%xcc, 1b
	  nop
2:
	cmp	%g1, VECINTR_HVXCALL
	beq,pt	%xcc, 4f
	cmp	%g1, VECINTR_DEV
	beq	%xcc, .dev_intr
	cmp	%g1, VECINTR_FPGA
	beq	%xcc, .fpga_intr
	nop		

	/*
	 * Ignore any interrupts that do not
	 * require additional handling.
	 */
#ifdef DEBUG
	mov	%g7, %g2	! print clobbers %g7
	PRINT("hvmondo_wait: ignoring interrupt type 0x")
	PRINTX(%g1)
	PRINT("\r\n")
	mov	%g2, %g7
#endif

	ba,pt	%xcc, 1b
	nop

.dev_intr:
#if defined(CONFIG_PCIE)
	setx	DEV_MONDO_INT, %g4, %g6
	ldx	[%g6 + DEV_MONDO_INT_ABUSY], %g4
	btst	DEV_MONDO_INT_ABUSY_BUSY, %g4
	bz,pn	%xcc, 1b			! Not BUSY .. just ignore
	  nop					! block waiting for next xcall
	stx	%g0, [%g6 + DEV_MONDO_INT_ABUSY]	! Clear BUSY bit
#endif
	ba,pt	%xcc, 1b			! block waiting for next xcall
	  nop


.fpga_intr:
#if CONFIG_FPGA

	!! Disable FPGA interrupts
	!!
	FPGA_MBOX_INT_DISABLE(IRQ_QUEUE_IN|IRQ_QUEUE_OUT|IRQ_LDC_OUT, %g2, %g3)

	CLEAR_INT_CTL_PEND(%g2, %g3)

.chk_fpga_intr_type:
	! check to see the type of interrupt
	setx	FPGA_INTR_BASE, %g3, %g2
	ldub	[%g2 + 	FPGA_MBOX_INTR_STATUS], %g4

	btst	IRQ_QUEUE_IN, %g4
	bz,pt	%xcc, .check_queue_out
	  nop

	! Mark it done
	ROOT_STRUCT(%g5)
	ldx	[%g5 + CONFIG_SVCS], %g5
	ldx	[%g5 + HV_SVC_DATA_RXCHANNEL], %g5
	set	QINTR_ACK, %g4
	stub	%g4, [%g5 + FPGA_Q_STATUS]

	ba,pt	%xcc, .chk_fpga_intr_type
	nop

.check_queue_out:
	btst	IRQ_QUEUE_OUT, %g4
	bz,pt	%xcc, .check_ldc_out
	  nop

	! Mark it done
	ROOT_STRUCT(%g5)
	ldx	[%g5 + CONFIG_SVCS], %g5
	ldx	[%g5 + HV_SVC_DATA_TXCHANNEL], %g5
	ldub	[%g5 + FPGA_Q_STATUS], %g6
	sth	%g0, [%g5 + FPGA_Q_SIZE]	! len = 0
	stub	%g6, [%g5 + FPGA_Q_STATUS]	! clear status
	
	ba,pt	%xcc, .chk_fpga_intr_type
	nop

.check_ldc_out:
	btst	IRQ_LDC_OUT, %g4
	bz,pt	%xcc, .enable_fpga_mbox_intr
	  nop

	FPGA_CLEAR_LDC_INTERRUPTS(%g3, %g5)

	ba,pt	%xcc, .chk_fpga_intr_type
	nop

.enable_fpga_mbox_intr:
	! Enable FPGA interrupts
	setx	FPGA_INTR_BASE, %g2, %g3
	mov	IRQ_QUEUE_IN|IRQ_QUEUE_OUT|IRQ_LDC_OUT, %g2
	stub	%g2, [%g3 + FPGA_MBOX_INTR_ENABLE]

#endif /* } */
	ba,pt	%xcc, 1b			! block waiting for next xcall
	  nop

4:
	HVRET
	SET_SIZE(hvmondo_wait)



/*
 * Should really only call this when you know an interrupt has been
 * delivered. Use hvmondo_wait to block on that event.
 */
/*
 * Semi-busy wait for a HV mondo to turn up.
 * We improve performance of the other strands by turning this one off
 * until the x-call mondo shows up.
 * Uses a subroutine - so g7 also gets clobbered.
 *
 * This macro allows for polling for a x-call mondo. Really this shouldn't
 * happen, but we do it for now until we setup guest0.
 *
 * Other interrupts sources should be disabled before this gets called, but
 * for now we just print warnings.
 *
 * accepts:
 * %g7 - return address
 *
 * returns:
 * %g1 - recv command
 *
 * clobbers:
 * %g1, %g2, %g7
 *
 */
	ENTRY(hvmondo_recv)

	/*
	 * Grab the mondo from the mailbox
	 * then release the mail box - unnecessary extra copying
	 * that all goes away with a LDC style receive queue for this
	 * stuff.
	 */
	STRAND_STRUCT(%g1)

	/*
	 * We'll be paranoid to make sure the command is complete
	 * this shouldn't be necessary, but leave it for now until
	 * a proper Q arrives.
	 */
1:
	membar	#StoreLoad
	ldx	[%g1 + STRAND_XCALL_MBOX + XCMB_COMMAND], %g3
	cmp	%g3, HXMB_BUSY
	be,pn	%xcc, 1b
	cmp	%g3, HXMB_NEWMONDO
	be,pt	%xcc, 2f
	  nop

	HVABORT(-1, "mbox idle or non-mondo command")

2:
	add	%g1, STRAND_XCALL_MBOX + XCMB_MONDOBUF, %g2
	add	%g1, STRAND_HV_RXMONDO, %g4

#define	MV(_o)	\
	ldx	[%g2 + (_o)*8], %g3	;\
	stx	%g3, [%g4 + (_o)*8]

	MV(0)
	MV(1)
	MV(2)
	MV(3)
	MV(4)
	MV(5)
	MV(6)
	MV(7)
#undef 	MV
	
		/* release the mail box for the next on */
	stx	%g0, [%g1 + STRAND_XCALL_MBOX + XCMB_COMMAND]
	add	%g1, STRAND_HV_RXMONDO, %g1	! returns ptr to buffer
	HVRET
	SET_SIZE(hvmondo_recv)
