/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: subr.s
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

	.ident	"@(#)subr.s	1.30	07/09/11 SMI"

/*
 * Various support routines
 */

#include <sys/asm_linkage.h>
#include <devices/pc16550.h>
#include <sys/htypes.h>
#include <hprivregs.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <asi.h>
#include <offsets.h>
#include <strand.h>
#include <util.h>
#include <abort.h>
#include <debug.h>
#include <fpga.h>


/*
 * memscrub - zero memory using Niagara blk-init stores
 * Assumes cache-line alignment and counts
 *
 * %g1 address
 * %g2 length
 *
 * Note that the block initializing store only zeros the
 * whole cacheline if the address is at the start of the
 * cacheline and the line is not in the L2 cache. Otherwise
 * the existing cacheline contents are retained other
 * than the specifically stored value.
 */
	ENTRY_NP(memscrub)
#if defined(CONFIG_FPGA) || defined(T1_FPGA) /* running on real hardware */
#ifndef T1_FPGA_MEMORY_PREINIT
	brz	%g2, 2f
	add	%g1, %g2, %g2
	mov	ASI_BLK_INIT_P, %asi
1:
	stxa	%g0, [%g1 + 0x00]%asi
	stxa	%g0, [%g1 + 0x08]%asi
	stxa	%g0, [%g1 + 0x10]%asi
	stxa	%g0, [%g1 + 0x18]%asi
	stxa	%g0, [%g1 + 0x20]%asi
	stxa	%g0, [%g1 + 0x28]%asi
	stxa	%g0, [%g1 + 0x30]%asi
	stxa	%g0, [%g1 + 0x38]%asi
	inc	0x40, %g1

	cmp	%g1, %g2
	blu,pt	%xcc, 1b
	nop
2:	
	membar	#Sync
#endif /* ifndef T1_FPGA_MEMORY_PREINIT */
#endif /* if defined(CONFIG_FPGA) || defined(T1_FPGA) */
	jmp	%g7 + 4
	nop
	SET_SIZE(memscrub)


/*
 * xcopy - copy xwords
 * Assumes 8-byte alignment and counts
 *
 * %g1 source (clobbered)
 * %g2 dest (clobbered)
 * %g3 size (clobbered)
 * %g4 temp (clobbered)
 * %g7 return address
 */
	ENTRY_NP(xcopy)
#ifdef CONFIG_LEGIONBCOPY
	/*
	 * Use a legion magic-trap to do the copy
	 * do alignment test to catch programming errors
	 */
	or	%g1, %g2, %g4
	or	%g4, %g3, %g4
	btst	7, %g4
	bnz,pt	%xcc, 1f
	nop
	ta	%xcc, LEGION_MAGICTRAP_PABCOPY
	brz	%g4, 2f		! %g4 == 0 successful
	nop
1:
#endif
	sub	%g1, %g2, %g1
1:
	ldx	[%g1 + %g2], %g4
	deccc	8, %g3
	stx	%g4, [%g2]
	bgu,pt	%xcc, 1b
	inc	8, %g2
#ifdef CONFIG_LEGIONBCOPY
2:
#endif
	jmp	%g7 + 4
	nop
	SET_SIZE(xcopy)


/*
 * bcopy - short byte-aligned copies
 *
 * %g1 source (clobbered)
 * %g2 dest (clobbered)
 * %g3 size (clobbered)
 * %g4 temp (clobbered)
 * %g7 return address
 */
	ENTRY_NP(bcopy)
	! alignment test
	or	%g1, %g2, %g4
	or	%g4, %g3, %g4
	btst	7, %g4
	bz,pt	%xcc, xcopy
	nop

#ifdef CONFIG_LEGIONBCOPY
	/*
	 * Use a legion magic-trap to do the copy
	 */
	ta	%xcc, LEGION_MAGICTRAP_PABCOPY
	brz	%g4, 2f		! %g4 == 0 successful
	nop
#endif
	sub	%g1, %g2, %g1
1:
	ldub	[%g1 + %g2], %g4
	deccc	%g3
	stb	%g4, [%g2]
	bgu,pt	%xcc, 1b
	inc	%g2
#ifdef CONFIG_LEGIONBCOPY
2:
#endif
	jmp	%g7 + 4
	nop
	SET_SIZE(bcopy)



/*
 * bzero - short byte-aligned zero operations
 *
 * NOTE: If we ever need to bzero larger chunks of memory
 * we need to adapt this to do a more optimized bzero operation
 *
 * %g1 dest (clobbered)
 * %g2 size (clobbered)
 * %g7 return address
 */

	ENTRY_NP(bzero)

	SMALL_ZERO_MACRO(%g1, %g2)

	HVRET
	SET_SIZE(bzero)



/*
 * Puts - print a string on the debug uart
 *
 * %g1 string (clobbered)
 * %g7 return address
 *
 * %g2-%g4 clobbered
 */
	ENTRY_NP(puts)

#ifdef CONFIG_VBSC_SVC

	/*
	 * Check if enough initialization has
	 * taken place to send the message to
	 * the vbsc hypervisor console.
	 */
	STRAND_STRUCT(%g2)
	brz,pn	%g2, .puts_try_hvuart
	nop
	STRAND_PUSH(%g7, %g2, %g3)

	HVCALL(vbsc_puts)

	STRAND_POP(%g7, %g2)

	ba,a	.puts_done
	  nop

.puts_try_hvuart:

#endif

#ifdef CONFIG_HVUART

	setx	FPGA_UART_BASE, %g3, %g2
1:
	ldub	[%g2 + LSR_ADDR], %g3
	btst	LSR_THRE, %g3
	bz	1b
	nop

1:
	ldub	[%g1], %g3
	cmp	%g3, 0
	inc	%g1
	bne,a,pt %icc, 2f
	  stb	%g3, [%g2]
	ba,a	.puts_done
	  nop
2:
	ldub	[%g2 + LSR_ADDR], %g3
	btst	LSR_TEMT, %g3
	bz	2b
	nop
	ba,a	1b
	  nop
#endif

.puts_done:

	jmp	%g7 + 4
	nop
	SET_SIZE(puts)


/*
 * putx - print a 64-bit xword on the debug uart
 * %g1 value (clobbered)
 * %g7 return address
 *
 * %g2-%g5 clobbered
 */
	ENTRY_NP(putx)

#ifdef CONFIG_VBSC_SVC

	/*
	 * Check if enough initialization has
	 * taken place to send the message to
	 * the vbsc hypervisor console.
	 */
	STRAND_STRUCT(%g2)
	brz,pn	%g2, .putx_try_hvuart
	nop

	STRAND_PUSH(%g7, %g2, %g3)
	STRAND_PUSH(%g6, %g2, %g3)

	HVCALL(vbsc_putx)

	STRAND_POP(%g6, %g2)
	STRAND_POP(%g7, %g2)

	ba,a	.putx_done
	  nop

.putx_try_hvuart:

#endif

#ifdef CONFIG_HVUART

	setx	FPGA_UART_BASE, %g3, %g2
1:	
	ldub	[%g2 + LSR_ADDR], %g4
	btst	LSR_THRE, %g4
	bz	1b
	nop
	
	mov	60, %g3
	ba	2f
	  rd	%pc, %g4
	.ascii	"0123456789abcdef"
	.align	4
2:
	add	%g4, 4, %g4
4:
	srlx	%g1, %g3, %g5
	andcc	%g5, 0xf, %g5
	bne	%xcc, 3f
	nop
	subcc	%g3, 4, %g3
	bne	%xcc, 4b
	nop
	! fall thru
1:
	srlx	%g1, %g3, %g5
	and	%g5, 0xf, %g5
3:
	ldub	[%g4 + %g5], %g5
	stb	%g5, [%g2]
	subcc	%g3, 4, %g3
	bge	2f
	nop
	
	ba,a	.putx_done
	  nop
2:
	ldub	[%g2 + LSR_ADDR], %g5
	btst	LSR_TEMT, %g5
	bz	2b
	nop
	ba,a	1b
	  nop
#endif

.putx_done:

	jmp	%g7 + 4
	  nop
	SET_SIZE(putx)



#ifdef CONFIG_HVUART
/*
 * uart_init - initialize the debug uart
 * Supports only 16550 UART
 *
 * %g1 is UART base address
 * %g2,%g3 clobbered
 * %g7 return address
 */
	ENTRY_NP(uart_init)
	ldub	[%g1 + LSR_ADDR], %g2	! read LSR
	stb	%g0, [%g1 + IER_ADDR] 	! clear IER
	stb	%g0, [%g1 + FCR_ADDR] 	! clear FCR, disable FIFO
	mov	(FCR_XMIT_RESET | FCR_RCVR_RESET),  %g3
	stb	%g3, [%g1 + FCR_ADDR] 	! reset FIFOs in FCR
	mov	FCR_FIFO_ENABLE,  %g3
	stb	%g3, [%g1 + FCR_ADDR] 	! FCR enable FIFO
	mov	(LCR_DLAB | LCR_8N1), %g3
	stb	%g3, [%g1 + LCR_ADDR] 	! set LCR for 8-n-1, set DLAB
	! DLAB = 1
	mov	DLL_9600, %g3
#ifdef UART_CLOCK_MULTIPLIER
	mulx	%g3, UART_CLOCK_MULTIPLIER, %g3
#endif
	stb	%g3, [%g1 + DLL_ADDR] 	! set baud rate = 9600
	stb	%g0, [%g1 + DLM_ADDR] 	! set MS = 0
	! disable DLAB
	mov	LCR_8N1, %g3		! set LCR for 8-n-1, unset DLAB
	jmp	%g7 + 4
	stb	%g3, [%g1 + LCR_ADDR] 	! set LCR for 8-n-1, unset DLAB
	SET_SIZE(uart_init)
#endif /* CONFIG_HVUART */



/*
 * These routines are called from softtrap handlers.
 *
 * We do this so that debug printing does not trample all over
 * the registers you are using.
 */
	ENTRY_NP(hprint)
	mov	%o0, %g1
	ba	puts
	rd	%pc, %g7
	done
	SET_SIZE(hprint)

	ENTRY_NP(hprintx)
	mov	%o0, %g1
	ba	putx
	rd	%pc, %g7
	done
	SET_SIZE(hprintx)


/*
 * Save the state of a virtual cpu into a save area
 *
 * FIXME: To be done:
 * * Move this code into platform specific area - or at least a
 *	portion of it. Platform specific CPUs may have additional state
 *	that requires saving.
 *
 * * Clobber tick interrupts - don't care about tick_cmr register.
 *
 * * Handle stick interrupts .. a stick interrupt may have retired while
 *	state was saved - in which case we must manually create the
 *	interrupt in softint.
 *
 * * Save and restore the floating point registers .. dont forget to
 *	to look and see if pstate.pef etc are enabled ...
 *	... capture any deferred traps if there are any on a given cpu.
 *
 * * Save and restore graphics status.
 *
 * * Save and restore the 4v queue registers.
 *
 * * Fix to save all the G's and trap stack registers from tl=0 to maxptl
 *
 * clobbers: Everything - returns back with TL & GL=0 and
 * a clean slate.
 */
	ENTRY_NP(vcpu_state_save)

	VCPU_STRUCT(%g6)

	! save vcpu state
	set	CPU_STATE_SAVE_AREA, %g1
	add	%g6, %g1, %g1

	!! %g1 = vcpu save area

	rdpr	%tl, %g3
	stx	%g3, [%g1 + VS_TL]
	
	! First step - save trap stack and registers
	add	%g1, VS_TRAPSTACK, %g2
1:
	wrpr	%g3, 0, %tl
	brz,pn	%g3, 2f
	nop
	sub	%g3, 1, %g3
	mulx	%g3, VCPUTRAPSTATE_SIZE, %g4
	add	%g4, %g2, %g4

	rdpr	%tpc, %g5
	stx	%g5, [%g4 + VCTS_TPC]
	rdpr	%tnpc, %g5
	stx	%g5, [%g4 + VCTS_TNPC]
	rdpr	%tstate, %g5
	stx	%g5, [%g4 + VCTS_TSTATE]
	rdpr	%tt, %g5
	stx	%g5, [%g4 + VCTS_TT]
	rdhpr	%htstate, %g5
	stx	%g5, [%g4 + VCTS_HTSTATE]
	ba,pt	%xcc, 1b
	nop
2:
	ldx	[%g1 + VS_TL], %g4
	wrpr	%g4, %tl		!??!!

	! Save the misc state
	rdpr	%tba, %g2
	stx	%g2, [%g1 + VS_TBA]
	rd	%y, %g2
	stx	%g2, [%g1 + VS_Y]
	rd	%asi, %g2
	stx	%g2, [%g1 + VS_ASI]
#if 0 /* { FIXME: workaround fp-diabled trap */
	rd	%gsr, %g2
	stx	%g2, [%g1 + VS_GSR]
#endif /* } */
	rdpr	%pil, %g2
	stx	%g2, [%g1 + VS_PIL]

	! Timer state
	rd	%tick, %g2
	stx	%g2, [%g1 + VS_TICK]
	rd	STICK, %g2
	stx	%g2, [%g1 + VS_STICK]
	rd	STICKCMP, %g2
	stx	%g2, [%g1 + VS_STICKCOMPARE]

	! IMPORTANT: We save softint last just incase a tick compare
	! got triggered between when we saved stick and stick compare
	rd	%softint, %g2
	stx	%g2, [%g1 + VS_SOFTINT]

	! Save scratchpads
#define	STORESCRATCH(regnum)					\
	mov	((regnum) * 8), %g3				;\
	ldxa	[%g3]ASI_SCRATCHPAD, %g2			;\
	stx	%g2, [%g1 + VS_SCRATCHPAD + ((regnum) * 8)]

	STORESCRATCH(0)
	STORESCRATCH(1)
	STORESCRATCH(2)
	STORESCRATCH(3)
		! scratchpads 4 & 5 dont exist for a Niagara
	STORESCRATCH(6)
	STORESCRATCH(7)

#undef	STORESCRATCH


	/*
	 * NOTE: FIXME saving and restoring the Q registers is postoned until
	 * we actually want to context switch. The reason is simply that
	 * the current LDC and x-call code deliver their mondos by
	 * manipulating the head and tail registers of the local strand
	 * and if we end up sending a message to ourselves (say in the
	 * hvctl code) then we end up restoring the old Q values and not
	 * the updated ones.
	 * So for now the Q values stay on the chip until the mondo
	 * delivery schemes (LDC x-call etc.) have been modified
	 * accordingly.
	 */

#if 0 /* { FIXME: */
	! Save the queue registers

	! Now we restore the queue registers
#define	STOREQ(_name)	\
	set	_name/**/_QUEUE_HEAD,	%g2		;\
	ldxa	[%g2]ASI_QUEUE, %g2			;\
	sth	%g2, [%g1 + VS_/**/_name/**/_HEAD]	;\
	set	_name/**/_QUEUE_TAIL,	%g2		;\
	ldxa	[%g2]ASI_QUEUE, %g2			;\
	sth	%g2, [%g1 + VS_/**/_name/**/_TAIL]

	STOREQ(CPU_MONDO)
	STOREQ(DEV_MONDO)
	STOREQ(ERROR_RESUMABLE)
	STOREQ(ERROR_NONRESUMABLE)

#undef	STOREQ
#endif /* } */

	! Save the window state
	rdpr	%wstate, %g2
	stx	%g2, [%g1 + VS_WSTATE]
	rdpr	%cansave, %g2
	stx	%g2, [%g1 + VS_CANSAVE]
	rdpr	%canrestore, %g2
	stx	%g2, [%g1 + VS_CANRESTORE]
	rdpr	%otherwin, %g2
	stx	%g2, [%g1 + VS_OTHERWIN]
	rdpr	%cleanwin, %g2
	stx	%g2, [%g1 + VS_CLEANWIN]

	rdpr	%cwp, %g2
	stx	%g2, [%g1 + VS_CWP]

	! Save the windows

	add	%g1, VS_WINS, %g3
	mov	0, %g4
1:	wrpr	%g4, %cwp
	stx	%i0, [%g3 + (0 * 8)]
	stx	%i1, [%g3 + (1 * 8)]
	stx	%i2, [%g3 + (2 * 8)]
	stx	%i3, [%g3 + (3 * 8)]
	stx	%i4, [%g3 + (4 * 8)]
	stx	%i5, [%g3 + (5 * 8)]
	stx	%i6, [%g3 + (6 * 8)]
	stx	%i7, [%g3 + (7 * 8)]
	stx	%l0, [%g3 + (8 * 8)]
	stx	%l1, [%g3 + (9 * 8)]
	stx	%l2, [%g3 + (10 * 8)]
	stx	%l3, [%g3 + (11 * 8)]
	stx	%l4, [%g3 + (12 * 8)]
	stx	%l5, [%g3 + (13 * 8)]
	stx	%l6, [%g3 + (14 * 8)]
	stx	%l7, [%g3 + (15 * 8)]
	add	%g3, RWINDOW_SIZE, %g3
	inc	%g4
	cmp	%g4, NWINDOWS
	bne,pt	%xcc, 1b
	nop

	! restore %cwp
	ldx	[%g1 + VS_CWP], %g2
	wrpr	%g2, %cwp

	mov	%g7, %l1		! preserve callers return address

	rdpr	%gl, %l2		! preserve original %gl
	stx	%l2, [%g1+VS_GL]

	! Stash all the globals except the current ones
	add	%g1, VS_GLOBALS, %l4
	mov	0, %l3
1:
	wrpr	%l3, %gl
	cmp	%l3, %l2
	be,pn	%xcc, 2f
	nop
	stx	%g1, [%l4 + (0 * 8)]
	stx	%g2, [%l4 + (1 * 8)]
	stx	%g3, [%l4 + (2 * 8)]
	stx	%g4, [%l4 + (3 * 8)]
	stx	%g5, [%l4 + (4 * 8)]
	stx	%g6, [%l4 + (5 * 8)]
	stx	%g7, [%l4 + (6 * 8)]
	inc	%l3
	add	%l4, VCPU_GLOBALS_SIZE, %l4
	ba,pt	%xcc, 1b
	nop
2:

	wrpr	%g0, %gl
	wrpr	%g0, %tl

	! Return to the caller
	mov	%l1, %g7
	HVRET
	SET_SIZE(vcpu_state_save)



/*
 * Restore guest partition from save area
 *
 * clobbers: Everything ..
 *
 * We retore in the reverse order to the save, and
 * We return back to the caller using the address in %g7
 * This function changes gl and tl back to the values
 * stored in the vcpus save area.
 *
 * We enter with the pointer to the vcpu to be restored
 * in the vcpu hscratch register - the assumption is that that
 * has already been set correctly.
 */
	ENTRY_NP(vcpu_state_restore)

	VCPU_STRUCT(%l0)
	set	CPU_STATE_SAVE_AREA, %l1
	add	%l0, %l1, %l1
	mov	%g7, %l7

	!! %l0 = vcpu
	!! %l1 = vcpu save area
	!! %l7 = return address

	! Restore all the globals up to but NOT including the save GL
	mov	0, %l3
	add	%l1, VS_GLOBALS, %l4
	ldx	[%l1 + VS_GL], %l2
1:
	wrpr	%l3, %gl
	cmp	%l3, %l2
	be,pn	%xcc, 2f
	nop
	ldx	[%l4 + (0 * 8)], %g1
	ldx	[%l4 + (1 * 8)], %g2
	ldx	[%l4 + (2 * 8)], %g3
	ldx	[%l4 + (3 * 8)], %g4
	ldx	[%l4 + (4 * 8)], %g5
	ldx	[%l4 + (5 * 8)], %g6
	ldx	[%l4 + (6 * 8)], %g7
	inc	%l3
	add	%l4, VCPU_GLOBALS_SIZE, %l4
	ba,pt	%xcc, 1b
	nop
2:

	! We land here with the globals restored
	! and gl set to the hypervisors Gs above
	! the vcpu context - move all the register
	! values from locals back to Gs.

	mov	%l7, %g7	! return address
	mov	%l0, %g6	! vcpu struct
	mov	%l1, %g1	! vcpu struct save area

	! Now restore all the register windows

	add	%g1, VS_WINS, %g3
	mov	0, %g4
1:	wrpr	%g4, %cwp
	ldx	[%g3 + (0 * 8)], %i0
	ldx	[%g3 + (1 * 8)], %i1
	ldx	[%g3 + (2 * 8)], %i2
	ldx	[%g3 + (3 * 8)], %i3
	ldx	[%g3 + (4 * 8)], %i4
	ldx	[%g3 + (5 * 8)], %i5
	ldx	[%g3 + (6 * 8)], %i6
	ldx	[%g3 + (7 * 8)], %i7
	ldx	[%g3 + (8 * 8)], %l0
	ldx	[%g3 + (9 * 8)], %l1
	ldx	[%g3 + (10 * 8)], %l2
	ldx	[%g3 + (11 * 8)], %l3
	ldx	[%g3 + (12 * 8)], %l4
	ldx	[%g3 + (13 * 8)], %l5
	ldx	[%g3 + (14 * 8)], %l6
	ldx	[%g3 + (15 * 8)], %l7
	add	%g3, RWINDOW_SIZE, %g3
	inc	%g4
	cmp	%g4, NWINDOWS
	bne,pt	%xcc, 1b
	nop

	! restore the window management registers
	ldx	[%g1 + VS_CWP], %g2
	wrpr	%g2, %cwp

	ldx	[%g1 + VS_CLEANWIN], %g2
	wrpr	%g2, %cleanwin
	ldx	[%g1 + VS_OTHERWIN], %g2
	wrpr	%g2, %otherwin
	ldx	[%g1 + VS_CANRESTORE], %g2
	wrpr	%g2, %canrestore
	ldx	[%g1 + VS_CANSAVE], %g2
	wrpr	%g2, %cansave
	ldx	[%g1 + VS_WSTATE], %g2
	wrpr	%g2, %wstate

#if 0 /* { FIXME: See note in state_save about Q registers */

	! Now we restore the queue registers
#define	RESTOREQ(_name)	\
	lduh	[%g1 + VS_/**/_name/**/_HEAD], %g2	;\
	set	_name/**/_QUEUE_HEAD,	%g3		;\
	stxa	%g2, [%g3]ASI_QUEUE			;\
	lduh	[%g1 + VS_/**/_name/**/_TAIL], %g2	;\
	set	_name/**/_QUEUE_TAIL,	%g3		;\
	stxa	%g2, [%g3]ASI_QUEUE

	RESTOREQ(CPU_MONDO)
	RESTOREQ(DEV_MONDO)
	RESTOREQ(ERROR_RESUMABLE)
	RESTOREQ(ERROR_NONRESUMABLE)

#undef	RESTOREQ
#endif /* } */

	! Restore the scratchpads
#define	RESTORESCRATCH(regnum)					\
	ldx	[%g1 + VS_SCRATCHPAD + ((regnum) * 8)], %g2	;\
	mov	((regnum) * 8), %g3				;\
	stxa	%g2, [%g3]ASI_SCRATCHPAD

	RESTORESCRATCH(0)
	RESTORESCRATCH(1)
	RESTORESCRATCH(2)
	RESTORESCRATCH(3)
		! scratchpads 4 & 5 dont exist for a Niagara
	RESTORESCRATCH(6)
	RESTORESCRATCH(7)

#undef	RESTORESCRATCH

	! Restore the misc state
	ldx	[%g1 + VS_TBA], %g2
	wrpr	%g2, %tba
	ldx	[%g1 + VS_Y], %g2
	wr	%g2, %y
	ldx	[%g1 + VS_ASI], %g2
	wr	%g2, %asi
#if 0 /* { FIXME: workaround fp disabled trap */
	ldx	[%g1 + VS_GSR], %g2
	wr	%g2, %gsr
#endif /* } */
	ldx	[%g1 + VS_SOFTINT], %g2
	wr	%g2, %softint
	ldx	[%g1 + VS_PIL], %g2
	wrpr	%g2, %pil

	! Timer state
	ldx	[%g1 + VS_STICKCOMPARE], %g2	! FIXME: check me
	wr	%g2, STICKCMP

	! restoration has side effects ... if stick has passed stick compare
	! since we saved, then we manually set the softint bit, since
	! the HW will have missed the event while the vcpu was
	! descheduled.
	!
	! NOTE softint has to already be setup first
	!
	! NOTE stick compare is already setup so we get a match while were
	! fiddling with this, the HW will set the match bit for us
	!
	! We ignore tick_cmpr since it's not part of the sun4v
	! architecture

	! If stick cmp int_dis is 1 then stick interrupts are
	! disabled, so no further action is necessary
	brlz	%g2, 1f		! int_dis is bit 63 (sign bit)
	nop

	! Nothing to do if stick had already passed stick_cmpr
	ldx	[%g1 + VS_STICK], %g3
	sllx	%g3, 1, %g3
	srlx	%g3, 1, %g3	! ignore the npt bit
	cmp	%g3, %g2
	bg,pt	%xcc, 1f
	nop

	! Nothing to do if stick hasn't reached stick_cmpr yet
	rd	STICK, %g3
	sllx	%g3, 1 ,%g3
	srlx	%g3, 1 ,%g3
	cmp	%g3, %g2
	bl,pt	%xcc, 1f
	nop

	! Set bit 16 in softint
	sethi	%hi(SOFTINT_SM_BIT), %g4
	wr	%g4, SOFTINT_SET
1:

	! Now we restore the trapstack back up to TL

	mov	0, %g4
	ldx	[%g1 + VS_TL], %g2
	brz,pt	%g2, 2f
	nop
	add	%g1, VS_TRAPSTACK, %g3
1:
	add	%g4, 1, %g4
	wrpr	%g4, %tl
	ldx	[%g3 + VCTS_TPC], %g5
	wrpr	%g5, %tpc
	ldx	[%g3 + VCTS_TNPC], %g5
	wrpr	%g5, %tnpc
	ldx	[%g3 + VCTS_TSTATE], %g5
	wrpr	%g5, %tstate
	ldx	[%g3 + VCTS_TT], %g5
	wrpr	%g5, %tt
	ldx	[%g3 + VCTS_HTSTATE], %g5
	wrhpr	%g5, %htstate
	add	%g3, VCPUTRAPSTATE_SIZE, %g3
	cmp	%g4, %g2
	bne,pt	%xcc, 1b
	nop
2:

	ldx	[%g1 + VS_TL], %g4
	wrpr	%g4, %tl

		!wait for changes to take effect
	membar	#Sync

	HVRET
	SET_SIZE(vcpu_state_restore)


/*
 * Print contents of important registers.
 */
	ENTRY_NP(dump_regs)
	mov	%g7, %g6
	PRINT("tl 0x");		rdpr	%tl, %g1;	PRINTX(%g1)
	PRINT(" gl 0x");	rdpr	%gl, %g1;	PRINTX(%g1)
	PRINT(" tt 0x");	rdpr	%tt, %g1;	PRINTX(%g1)
	PRINT(" tpc 0x");	rdpr	%tpc, %g1;	PRINTX(%g1)
	PRINT(" tnpc 0x");	rdpr	%tnpc, %g1;	PRINTX(%g1)
	PRINT(" tstate 0x");	rdpr	%tstate, %g1;	PRINTX(%g1)
	PRINT(" htstate 0x");	rdhpr	%htstate, %g1;	PRINTX(%g1)
	PRINT("\r\n");
	PRINT(" wstate 0x");	rdpr	%wstate, %g1;	PRINTX(%g1)
	PRINT(" cansave 0x");	rdpr	%cansave, %g1;	PRINTX(%g1)
	PRINT(" canrestore 0x");rdpr	%canrestore, %g1;PRINTX(%g1)
	PRINT(" otherwin 0x");	rdpr	%otherwin, %g1;	PRINTX(%g1)
	PRINT(" cleanwin 0x");	rdpr	%cleanwin, %g1;	PRINTX(%g1)
	PRINT(" cwp 0x");	rdpr	%cwp, %g1;	PRINTX(%g1)
	PRINT("\r\n");
	PRINT(" tba 0x");	rdpr	%tba, %g1;	PRINTX(%g1)
	PRINT(" y 0x");		rd	%y, %g1;	PRINTX(%g1)
	PRINT(" asi 0x");	rd	%asi, %g1;	PRINTX(%g1)
#if 0 /* { FIXME: work around fp disabled trap*/
	PRINT(" gsr 0x");	rd	%gsr, %g1;	PRINTX(%g1)
#endif /* } */
	PRINT(" pil 0x");	rdpr	%pil, %g1;	PRINTX(%g1)
	PRINT(" stickcmp 0x");	rd	STICKCMP, %g1;	PRINTX(%g1)
	PRINT(" softint 0x");	rd	%softint, %g1;	PRINTX(%g1)
	PRINT("\r\n");
	PRINT(" sc0 0x"); mov (0*8),%g1;ldxa [%g1]ASI_SCRATCHPAD,%g1;PRINTX(%g1)
	PRINT(" sc1 0x"); mov (1*8),%g1;ldxa [%g1]ASI_SCRATCHPAD,%g1;PRINTX(%g1)
	PRINT(" sc2 0x"); mov (2*8),%g1;ldxa [%g1]ASI_SCRATCHPAD,%g1;PRINTX(%g1)
	PRINT(" sc3 0x"); mov (3*8),%g1;ldxa [%g1]ASI_SCRATCHPAD,%g1;PRINTX(%g1)
	PRINT(" sc6 0x"); mov (6*8),%g1;ldxa [%g1]ASI_SCRATCHPAD,%g1;PRINTX(%g1)
	PRINT(" sc7 0x"); mov (7*8),%g1;ldxa [%g1]ASI_SCRATCHPAD,%g1;PRINTX(%g1)

	rdpr	%cwp, %g3	! preserve
	mov	0, %g2
1:
	PRINT("Window 0x");	PRINTX(%g2);	PRINT("\r\n");
	wrpr	%g2, %cwp
	PRINT("i0 0x"); PRINTX(%i0); PRINT("  ")
	PRINT("i1 0x"); PRINTX(%i1); PRINT("  ")
	PRINT("i2 0x"); PRINTX(%i2); PRINT("  ")
	PRINT("i3 0x"); PRINTX(%i3); PRINT("  ")
	PRINT("i4 0x"); PRINTX(%i4); PRINT("  ")
	PRINT("i5 0x"); PRINTX(%i5); PRINT("  ")
	PRINT("i6 0x"); PRINTX(%i6); PRINT("  ")
	PRINT("i7 0x"); PRINTX(%i7); PRINT("  ")
	PRINT("\r\n");

	PRINT("l0 0x"); PRINTX(%l0); PRINT("  ")
	PRINT("l1 0x"); PRINTX(%l1); PRINT("  ")
	PRINT("l2 0x"); PRINTX(%l2); PRINT("  ")
	PRINT("l3 0x"); PRINTX(%l3); PRINT("  ")
	PRINT("l4 0x"); PRINTX(%l4); PRINT("  ")
	PRINT("l5 0x"); PRINTX(%l5); PRINT("  ")
	PRINT("l6 0x"); PRINTX(%l6); PRINT("  ")
	PRINT("l7 0x"); PRINTX(%l7); PRINT("  ")
	PRINT("\r\n");
	inc	%g2
	cmp	%g2, 8
	bne,pt	%xcc, 1b
	nop
	
	wrpr	%g3, %cwp

	mov	%g6, %g7
	HVRET
	SET_SIZE(dump_regs)

	
	/*
	 * spinlock_enter(uint64_t *lock)
	 * For calling from C code. In asm code use the SPINLOCK_ENTER macro.
	 */
	ENTRY_NP(spinlock_enter)
	STRAND_STRUCT(%o1)
	ldub	[%o1 + STRAND_ID], %o2
	inc	%o2
1:	mov	%o2, %o1
	casx	[%o0], %g0, %o1
	brnz,pn	%o1, 1b
	nop
	MEMBAR_ENTER
	retl
	nop
	SET_SIZE(spinlock_enter)

	
	/*
	 * spinlock_exit(uint64_t *lock)
	 * For calling from C code. In asm code use the SPINLOCK_EXIT macro.
	 */
	ENTRY_NP(spinlock_exit)
	MEMBAR_EXIT
	stx	%g0, [%o0]
	retl
	nop
	SET_SIZE(spinlock_exit)


	/*
	 * Get the stick value from the current strand
	 */
	ENTRY(c_get_stick)
	retl
	rd	STICK, %o0
	SET_SIZE(c_get_stick)
