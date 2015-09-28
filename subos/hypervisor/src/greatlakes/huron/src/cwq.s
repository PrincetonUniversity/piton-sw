/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cwq.s
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

	.ident	"@(#)cwq.s	1.2	07/05/21 SMI"

	.file	"cwq.s"

/*
 * Niagara2 CWQ support
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>

#include <debug.h>
#include <config.h>
#include <guest.h>
#include <cwq.h>
#include <mau.h>
#include <md.h>
#include <abort.h>
#include <offsets.h>
#include <ncs.h>
#include <util.h>

/*
 *-----------------------------------------------------------
 * Function: setup_cwq
 *	Called via setup_cpu() if the given cpu has access
 *	to a mau.  If the handle is non-NULL then the mau
 *	struct has already been initialized.
 * Arguments:
 *	Input:
 *		%i0 - CONFIG
 *		%g1 - cpu struct
 *		%g2 - ino
 *		%g7 - return address
 *	Output:
 *		%g1 - &config.cwqs[cwq-id] or NULL (0) if error.
 *
 *	Uses:	%g1-%g6,%l3
 *-----------------------------------------------------------
 */

	ENTRY_NP(setup_cwq)

	ldx	[%g1 + CPU_CWQ], %g3
	brz,pn  %g3, 1f
	 nop
	ldx	[%g3 + CWQ_PID], %g6
	cmp	%g6, NCWQS
	bgeu,a,pn %xcc, 1f
	  mov	%g0, %g3

	VCPU2STRAND_STRUCT(%g1, %g5)
	ldub	[%g5 + STRAND_ID], %g5
	and	%g5, NSTRANDS_PER_CWQ_MASK, %g5	! %g5 = hw thread-id
	mov	1, %g4
	sllx	%g4, %g5, %g4
	ldx	[%g3 + CWQ_CPUSET], %g6
	btst	%g4, %g6
	bnz,pn  %xcc, 1f
	 nop
	bset	%g4, %g6
	stx	%g6, [%g3 + CWQ_CPUSET]

	add	%g5, CWQ_CPU_ACTIVE, %g5
	mov	-1, %g6
	stb	%g6, [%g3 + %g5]

	ldx	[%g3 + CWQ_CPUSET], %g5
	cmp	%g4, %g5			! 1st (only) cpu?
	bne,pt  %xcc, 1f
	 nop

	ldx	[%g3 + CWQ_PID], %g6
	ID2HANDLE(%g6, CWQ_HANDLE_SIG, %g6)
	stx	%g6, [%g3 + CWQ_HANDLE]
	stx	%g2, [%g3 + CWQ_INO]
	/*
	 * Now set up cwq queue.
	 */
	CWQ_CLEAR_QSTATE(%g3)
	/*
	 * Now set up interrupt stuff.
	 */
	ldx	[%g1 + CPU_GUEST], %g1
	LABEL_ADDRESS(cwq_intr_getstate, %g4)
	mov	%g0, %g5
	!!
	!! %g1 = guestp
	!! %g2 = ino
	!! %g3 = &config.cwqs[cwq-id]
	!! %g4 = cwq_intr_getstate
	!! %g5 = NULL (no setstate callback)
	!! %g7 = return pc (set up in setup_cpu())
	!!
	/*
	 * Note that vdev_intr_register() clobbers %g1,%g3,%g5-%g7.
	 */
	mov	%g7, %l3			! save return pc
	HVCALL(vdev_intr_register)
	stx	%g1, [%g3 + CWQ_IHDLR + CI_COOKIE]

	mov	CWQ_STATE_RUNNING, %g2
	stx	%g2, [%g3 + CWQ_STATE]

	mov	%l3, %g7			! restore return pc
1:
	mov	%g3, %g1			! return &cwqs[cwq-id]
	HVRET

	SET_SIZE(setup_cwq)

/*
 * Wrapper around setup_cwq, so it can be called from C
 * SPARC ABI requries only that g2,g3,g4 are preserved across
 * function calls.
 *		%g1 - cpu struct
 *		%g2 - ino
 *		%g3 - config
 *	Output:
 *		%g1 - &config.cwqs[cwq-id] or NULL (0) if error.
 *
 * cwqp = c_setup_cwq(vcpup, ino, &config); 
 *
 */

	ENTRY(c_setup_cwq)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	mov	%o0, %g1
	mov	%o1, %g2
	mov	%o2, %g3
	HVCALL(setup_cwq)
	mov	%g1, %o0
	
	STRAND_POP(%g4, %g6)
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	
	retl
	  nop
	SET_SIZE(c_setup_cwq)

/*
 *-----------------------------------------------------------
 * Function: cwq_intr()
 *	Called from within trap context.
 * Arguments:
 *	Input:
 *		%g1 - cpu struct
 *	Output:
 *-----------------------------------------------------------
 */
	ENTRY_NP(cwq_intr)

	ldx	[%g1 + CPU_CWQ], %g2
	brz,pn	%g2, .ci_exit_nolock
	 nop

	CWQ_LOCK_ENTER(%g2, %g5, %g4, %g6)
	
	ldx	[%g2 + CWQ_STATE], %g3
	cmp	%g3, CWQ_STATE_RUNNING
	bne,pn	%xcc, .ci_exit
	 nop

	/*
	 * Read CSR (contains error info) and check for errors.
	 * If there were no errors, set bit 50 of all finished
	 * Control Words to 1 indicating that the hardware has finished
	 * processing of these Control Words.
	 * If there were errors we'll need to do some work.
	 * We set bit 50 to 1, and copy the CSR error indicator
	 * bits hwe and protocolerror to bits 52 and 51, resp.
	 * of the Control Word causing the error and each following
	 * Control Word of the Control Word Block it belongs to.
	 */

	mov	ASI_SPU_CWQ_CSR, %g4
	ldxa	[%g4]ASI_STREAM, %g7
	mov	ASI_SPU_CWQ_HEAD, %g4
	ldxa	[%g4]ASI_STREAM, %g3


	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HEAD], %g4
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g6
	sub	%g4, %g6, %g5
	cmp	%g5, %g3
	be,pn	%xcc, .ci_exit		! phantom interrupt, we already
	 nop				! processed this CW

	andcc	%g7, CWQ_CSR_ERROR, %g7
	bz,pt	%xcc, .ci_no_error
	 nop

.ci_still_good_loop:
	/*
	 * %g7 interrupt bits
	 * %g4 driver's first non-processed CW entry
	 * %g3 HV's CWQ head
	 */
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g6
	sub	%g4, %g6, %g6
	cmp	%g6, %g3
	be,pn	%xcc, .ci_error
	 nop
	
	ldx	[%g4], %g5
	mov	1, %g6
	sllx	%g6, CW_RES_SHIFT, %g6
	or	%g6, %g5, %g5
	stx	%g5, [%g4]

	add	%g4, CWQ_CW_SIZE, %g5
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_LAST], %g6
	cmp	%g5, %g6			! next == Last?
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_BASE], %g6
	movgu	%xcc, %g6, %g5			! next = First
	ba	.ci_still_good_loop
	 mov	%g5, %g4

.ci_error:

	/*
	 * at this point, we have processed everything up to
	 * cwq[head - 1]. and have an error at cwq[head]
	 */

	mov	%g5, %g3
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g5
	mov	ASI_SPU_CWQ_TAIL, %g4
	ldxa	[%g4]ASI_STREAM, %g4
	add	%g4, %g5, %g4
	stx	%g4, [%g2 + CWQ_QUEUE + CQ_DR_TAIL]	! tail

	/*
	 * CWQ state will be:
	 *	- Head = CW in error (within CW Block)
	 *	- CWQ = disabled
	 * We'll mark all remaining CWs in this CW Block
	 * with the error bit then move Head to next
	 * CW Block and reenable CWQ.  Note that we will
	 * not move the Head beyond the Tail.  In theory this
	 * should never happen, but since we rely on software
	 * to properly set the EOB bit we have to guard against
	 * it not being set and this code being stuck in an
	 * infinite loop.
	 */

	srl	%g7, CWQ_CSR_ERROR_SHIFT - 1, %g6
	or	%g6, 1, %g6

	ldx	[%g3], %g5
	

.ci_chkeob:
	sllx	%g6, CW_RES_SHIFT, %g7
	or	%g5, %g7, %g5
	stx	%g5, [%g3]

	srlx	%g5, CW_EOB_SHIFT, %g5
	btst	CW_EOB_MASK, %g5
	bnz,pt	%xcc, .ci_finalcw
	 nop

	add	%g3, CWQ_CW_SIZE, %g3
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_LAST], %g7
	cmp	%g3, %g7			! current == Last?
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_BASE], %g7
	movgu	%xcc, %g7, %g3			! current = First
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_TAIL], %g7
	cmp	%g3, %g7			! current == Tail?
	bne,pt	%xcc, .ci_chkeob
	 ldx	[%g3], %g5

.ci_finalcw:
	/*
	 * Move the Head to the next CW.
	 */
	add	%g3, CWQ_CW_SIZE, %g3
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_LAST], %g7
	cmp	%g3, %g7
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_BASE], %g7
	movgu	%xcc, %g7, %g3
	stx	%g3, [%g2 + CWQ_QUEUE + CQ_DR_HEAD]
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g5
	sub	%g3, %g5, %g3
	mov	ASI_SPU_CWQ_HEAD, %g4
	stxa	%g3, [%g4]ASI_STREAM
	stx	%g3, [%g2 + CWQ_QUEUE + CQ_HEAD]

	/*
	 * Clear the CWQ state and reenable the CWQ.
	 */

#ifdef ERRATA_192
	ldx	[%g1 + CPU_MAU], %g6
	MAU_LOCK_ENTER(%g6, %g1, %g4, %o0)
	ldx	[%g6 + MAU_STORE_IN_PROGR], %g4
	sub	%g4, 1, %g4
	brnz,pt	%g4, .ci_do_enable
	 nop
	mov	1, %g4
	stx	%g4, [%g6 + MAU_ENABLE_CWQ]
	ba	.ci_cwq_enable_done
	 nop
.ci_do_enable:	
#endif

	mov	ASI_SPU_CWQ_CSR, %g4
	mov	CWQ_CSR_ENABLED, %g6
	stxa	%g6, [%g4]ASI_STREAM

#ifdef ERRATA_192
.ci_cwq_enable_done:	
	MAU_LOCK_EXIT_L(%g1)
#endif

	ba	.ci_finish
	 nop
	
.ci_no_error:
	andcc	 %g6, CWQ_CSR_BUSY, %g6
	bz,pt	%xcc, .ci_no_error_loop
	 mov	%g0, %g7	! collect interrupt bits in %g7

	/*
	 * if the busy bit was set in the CSR, we leave the last entry for
	 * the next invocation of the interrupt handler, as the result of
	 * the last CW might not be globally visible yet
	 */
	sub	%g3, CWQ_CW_SIZE, %g3
	ldx	[%g2 + CWQ_QUEUE + CQ_BASE], %g6
	cmp	%g6, %g3			! previous < First?
	ldx	[%g2 + CWQ_QUEUE + CQ_LAST], %g6
	movgu	%xcc, %g6, %g3			! pervious = Last

.ci_no_error_loop:
	/*
	 * %g7 interrupt bits
	 * %g4 driver's first non-processed CW entry
	 * %g3 HV's CWQ head
	 */
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g6
	sub	%g4, %g6, %g6
	cmp	%g6, %g3
	be,pn	%xcc, .ci_no_error_done
	 nop
	
	ldx	[%g4], %g5
	or	%g5, %g7, %g7		!collecting the intr bits
	mov	1, %g6
	sllx	%g6, CW_RES_SHIFT, %g6
	or	%g6, %g5, %g5
	stx	%g5, [%g4]

	add	%g4, CWQ_CW_SIZE, %g5
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_LAST], %g6
	cmp	%g5, %g6			! next == Last?
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_BASE], %g6
	movgu	%xcc, %g6, %g5			! next = First
	ba	.ci_no_error_loop
	 mov	%g5, %g4

.ci_no_error_done:

	stx	%g4, [%g2 + CWQ_QUEUE + CQ_DR_HEAD]
	ldx	[%g2 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g3
	sub	%g4, %g3, %g3
	stx	%g3, [%g2 + CWQ_QUEUE + CQ_HEAD]
	mov	%g7, %g5	
	
.ci_finish:	
	srlx	%g7, CW_INTR_SHIFT, %g7
	and	%g7, CW_INTR_MASK, %g7

	ldx	[%g2 + CWQ_IHDLR + CI_COOKIE], %g1
	brz,pn	%g1, .ci_exit
	 nop

	CWQ_LOCK_EXIT(%g2, %g6)

	brz,pt	%g7, .ci_exit_nolock		! don't generate interrupt
	 nop

	HVCALL(vdev_intr_generate)
	retry

.ci_exit:
	CWQ_LOCK_EXIT(%g2, %g5)

.ci_exit_nolock:
	retry

	SET_SIZE(cwq_intr)


/*
 *-----------------------------------------------------------
 * Function: cwq_intr_getstate()
 * Arguments:
 *	Input:
 *		%g1 - cwqs[] struct
 *		%g7 - return pc
 *	Output:
 *-----------------------------------------------------------
 */
	ENTRY_NP(cwq_intr_getstate)

	/*
	 * Note that ideally we would get the actual Head
	 * from the hardware, however there is no guarantee
	 * that this routine will be called on the target
	 * core/cwq, so we have to rely on the Head being
	 * captured during cwq_intr time.
	 */
	mov	%g0, %g2
	ldx	[%g1 + CWQ_QUEUE + CQ_HEAD], %g3
	ldx	[%g1 + CWQ_QUEUE + CQ_HEAD_MARKER], %g4
	cmp	%g3, %g4
	movne	%xcc, 1, %g2
	jmp	%g7 + SZ_INSTR
	mov	%g2, %g1

	SET_SIZE(cwq_intr_getstate)

/*
 *-----------------------------------------------------------
 * Function: ncs_qconf_cwq
 * Arguments:
 *	Input:
 *		%o1 - base real address of queue or queue handle if
 *		      unconfiguring a queue.
 *		%o2 - number of entries in queue.
 *		%g1 - guest struct
 *		%g2 - cpu struct
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENOACCESS, EBADALIGN,
 *		      ENORADDR, EWOULDBLOCK (on failure)
 *		%o1 - queue handle for respective queue.
 *-----------------------------------------------------------
 */
	ENTRY_NP(ncs_qconf_cwq)

	VCPU_GUEST_STRUCT(%g2, %g1)

	ldx	[%g2 + CPU_CWQ], %g3
#ifdef ERRATA_192
	ldx	[%g2 + CPU_MAU], %g7
#endif
	brz,pn	%o2, .c_qconf_unconfig
	 nop

	cmp	%o2, NCS_MIN_CWQ_NENTRIES
	blu,pn	%xcc, herr_inval
	 nop
	cmp	%o2, NCS_MAX_CWQ_NENTRIES
	bgu,pn	%xcc, herr_inval
	 nop
	/*
	 * Check that #entries is a power of two.
	 */
	sub	%o2, 1, %g4
	andcc	%o2, %g4, %g0
	bnz,pn	%xcc, herr_inval
	 nop

	brz,pn	%g3, herr_noaccess
	 nop
	/*
	 * The cpu that does the queue configure will also
	 * be the one targeted for all the interrupts for
	 * this cwq.  We need to effectively single thread
	 * the interrupts per-cwq because the interrupt handler
	 * updates global per-cwq data structures.
	 */
	VCPU2STRAND_STRUCT(%g2, %o0)
	ldub	[%o0 + STRAND_ID], %o0
	/*
	 * Make sure base address is size aligned.
	 */
	sllx	%o2, CWQ_CW_SHIFT, %g4
	sub	%g4, 1, %g2
	btst	%g2, %o1
	bnz,pn	%xcc, herr_badalign
	 nop

	CWQ_LOCK_ENTER(%g3, %g5, %g2, %g6)
	/*
	 * Translate base address from real to physical.
	 */
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %g4, .c_qconf_noraddr, %g2, %g6)

	stx	%o0, [%g3 + CWQ_QUEUE + CQ_CPU_PID]
	stx	%o1, [%g3 + CWQ_QUEUE + CQ_DR_BASE_RA]
	stx	%g6, [%g3 + CWQ_QUEUE + CQ_DR_BASE]
	stx	%g6, [%g3 + CWQ_QUEUE + CQ_DR_HEAD]
	add	%g3, CWQ_QUEUE + CQ_HV_CWS + CWQ_CW_SIZE - 1, %g2
	and	%g2, -CWQ_CW_SIZE, %g2
	stx	%g2, [%g3 + CWQ_QUEUE + CQ_BASE]
	stx	%g2, [%g3 + CWQ_QUEUE + CQ_HEAD]
	sub	%g6, %g2, %g6
	stx	%g6, [%g3 + CWQ_QUEUE + CQ_DR_HV_OFFSET]
	add	%g2, %g4, %g6
	sub	%g6, CWQ_CW_SIZE, %g6
	stx	%g6, [%g3 + CWQ_QUEUE + CQ_LAST]
	ldx	[%g3 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %g4
	add	%g6, %g4, %g4
	stx	%g4, [%g3 + CWQ_QUEUE + CQ_DR_LAST]	
	stx	%o2, [%g3 + CWQ_QUEUE + CQ_NENTRIES]
	st	%g0, [%g3 + CWQ_QUEUE + CQ_BUSY]
	stx	%g0, [%g3 + CWQ_QUEUE + CQ_HEAD_MARKER]
	!!
	!! %g2 = base
	!! %g6 = (end - [1 cwq entry]) (last valid entry)
	!!
	/*
	 * Clear any errors and disable the CWQ.
	 */
	
#ifdef ERRATA_192
	MAU_LOCK_ENTER(%g7, %g1, %g4, %o0)
#endif

	mov	ASI_SPU_CWQ_CSR, %g4
	stxa	%g0, [%g4]ASI_STREAM
	/*
	 * Load up CWQ pointers.
	 *	first = head = tail = %g2 (base)
	 *	last = %g6 (end-1)
	 */
	mov	ASI_SPU_CWQ_FIRST, %g4
	stxa	%g2, [%g4]ASI_STREAM

	mov	ASI_SPU_CWQ_LAST, %g4
	stxa	%g6, [%g4]ASI_STREAM

	mov	ASI_SPU_CWQ_HEAD, %g4
	stxa	%g2, [%g4]ASI_STREAM

	mov	ASI_SPU_CWQ_TAIL, %g4
	stxa	%g2, [%g4]ASI_STREAM

	/*
	 * First and Last have been set.  Now ready to
	 * enable the SPU.
	 */

#ifdef ERRATA_192
	ldx	[%g7 + MAU_STORE_IN_PROGR], %g4
	sub	%g4, 1, %g4
	brnz,pt	%g4, .c_qconf_do_enable
	 nop
	mov	1, %g4
	stx	%g4, [%g7 + MAU_ENABLE_CWQ]
	ba	.c_qconf_done
	 nop
.c_qconf_do_enable:	
#endif

	mov	CWQ_CSR_ENABLED, %o0
	mov	ASI_SPU_CWQ_CSR_ENABLE, %g4
	stxa	%o0, [%g4]ASI_STREAM

#ifdef ERRATA_192
.c_qconf_done:	
	MAU_LOCK_EXIT_L(%g1)
#endif

	mov	NCS_QSTATE_CONFIGURED, %g1
	st	%g1, [%g3 + CWQ_QUEUE + CQ_STATE]

	ldx	[%g3 + CWQ_HANDLE], %o1

	CWQ_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

.c_qconf_noraddr:
	CWQ_LOCK_EXIT_L(%g5)

	HCALL_RET(ENORADDR)

.c_qconf_unconfig:

	CWQ_HANDLE2ID_VERIFY(%o1, herr_inval, %g2)
	GUEST_CID_GETCWQ(%g1, %g2, %g3)
	brz,pn	%g3, herr_noaccess
	 nop

	CWQ_LOCK_ENTER(%g3, %g5, %g1, %g6)

	ld	[%g3 + CWQ_QUEUE + CQ_BUSY], %g4
	brnz,pn	%g4, .c_qconf_wouldblock
	 nop
	/*
	 * Clear any errors and disable CWQ,
	 * then do a synchronous load to wait
	 * for any outstanding ops.
	 */

#ifdef ERRATA_192
	MAU_LOCK_ENTER(%g7, %g1, %g4, %o0)
	stx	%g0, [%g7 + MAU_ENABLE_CWQ]
#endif

	mov	ASI_SPU_CWQ_CSR, %g4
	stxa	%g0, [%g4]ASI_STREAM
	/*
	 * Wait for SPU to drain.
	 */
	mov	ASI_SPU_CWQ_SYNC, %g4
	ldxa	[%g4]ASI_STREAM, %g0

#ifdef ERRATA_192
	MAU_LOCK_EXIT_L(%g1)
#endif

	CWQ_CLEAR_QSTATE(%g3)
	mov	NCS_QSTATE_UNCONFIGURED, %g1
	st	%g1, [%g3 + CWQ_QUEUE + CQ_STATE]

	CWQ_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

.c_qconf_wouldblock:
	CWQ_LOCK_EXIT_L(%g5)

	HCALL_RET(EWOULDBLOCK)

	SET_SIZE(ncs_qconf_cwq)

/*
 *-----------------------------------------------------------
 * Function: ncs_settail_cwq(uint64_t qhandle, uint64_t new_tailoffset)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *		%o1 - new tail offset
 *		%g1 - guest struct
 *		%g7 - cpu struct
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(ncs_settail_cwq)

	CWQ_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_CID_GETCWQ(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop

	/*
	 * Verify that we're on the CWQ that the
	 * caller specified.
	 */
	ldx	[%g7 + CPU_CWQ], %g4
	cmp	%g4, %g3
	bne,pn	%xcc, herr_inval
	 nop

	btst	CWQ_CW_SIZE - 1, %o1
	bnz,a,pn %xcc, herr_inval
	 nop

	mov	%g1, %o0			! %o0 = guest struct

	ldx	[%g3 + CWQ_QUEUE + CQ_BASE], %g1
	add	%g1, %o1, %g1
	ldx	[%g3 + CWQ_QUEUE + CQ_LAST], %g2
	cmp	%g1, %g2
	bgu,pn	%xcc, herr_inval
	 nop

	CWQ_LOCK_ENTER(%g3, %o5, %g4, %g6)
	stx	%o1, [%g3 + CWQ_QUEUE + CQ_SCR1]
	stx	%o2, [%g3 + CWQ_QUEUE + CQ_SCR2]
	stx	%o3, [%g3 + CWQ_QUEUE + CQ_SCR3]
	/*
	 * Use the per-cwq assigned cpu as target
	 * for interrupts for this job.
	 */
	ldx	[%g3 + CWQ_QUEUE + CQ_DR_HV_OFFSET], %o2
	ldx	[%g3 + CWQ_QUEUE + CQ_CPU_PID], %o1
	and	%o1, NSTRANDS_PER_CWQ_MASK, %o1	! hw-thread-id
	sllx	%o1, CW_STRAND_ID_SHIFT, %g4	! prep for CW conrol reg

	mov	ASI_SPU_CWQ_TAIL, %g5
	ldxa	[%g5]ASI_STREAM, %g2
	brz,a,pn %g2, .st_cwq_return
	 mov	EINVAL, %o0
	mov	ASI_SPU_CWQ_FIRST, %g5
	ldxa	[%g5]ASI_STREAM, %g3
	brz,a,pn %g3, .st_cwq_return
	 mov	EINVAL, %o0
	mov	ASI_SPU_CWQ_LAST, %g5
	ldxa	[%g5]ASI_STREAM, %g5
	brz,a,pn %g5, .st_cwq_return
	 mov	EINVAL, %o0
	!!
	!! %g1 = New Tail
	!! %g2 = Current Tail
	!! %g3 = First
	!!
	!! %g4 = hw-thread-id shifted over for CTLBITS.
	!!
	mov	%g2, %g5
	mov	%g2, %g6
	/*
	 * %g5 = current CW that we're working on.
	 * %o2 = driver queue - HV queue offset.
	 */
.st_cwq_trans:
	cmp	%g5, %g1
	be,a,pn	%xcc, .st_cwq_trans_done
	 nop
	add	%g5, %o2, %g6
	ldx	[%g6 + CW_CTLBITS], %g6

	mov	CW_SOB_MASK, %g7
	sllx	%g7, CW_SOB_SHIFT, %g7
	andcc	%g7, %g6, %g7
	bz,pn	%xcc, .st_cwq_storectl
	 nop

	/*
	 * Fill in the CW_STRAND_ID field with the
	 * physical hwthread-id that we're on.
	 */
	mov	CW_STRAND_ID_MASK, %g7
	sllx	%g7, CW_STRAND_ID_SHIFT, %g7
	andn	%g6, %g7, %g6
	or	%g6, %g4, %g6
	/*
	 * Force the interrupt bit to be on 
	 */
	mov	CW_INTR_MASK, %g7
	sllx	%g7, CW_INTR_SHIFT, %g7
	or	%g6, %g7, %g6

.st_cwq_storectl:
	stx	%g6, [%g5 + CW_CTLBITS]

	setx	CW_LENGTH_MASK, %g2, %g7
	and	%g6, %g7, %g7			! %g7 = cw_length
	add	%g7, 1, %g7
	srlx	%g6, CW_HMAC_KEYLEN_SHIFT, %g6
	and	%g6, CW_HMAC_KEYLEN_MASK, %g6	! %g6 = cw_hmac_keylen
	add	%g6, 1, %g6
	/*
	 * Source address should never be NULL.
	 */
	add	%g5, %o2, %g2
	ldx	[%g2 + CW_SRC_ADDR], %g2
	brz,a,pn %g2, .st_cwq_return
	 mov	EINVAL, %o0
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %g7, .st_cwq_noraddr, %o5, %o1)
	stx	%o1, [%g5 + CW_SRC_ADDR]
	
	add	%g5, %o2, %g2
	ldx	[%g2 + CW_AUTH_KEY_ADDR], %g2
	brz,pn	%g2, .st_cwq_chk_authkey
	 mov	%g2, %o1
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %g6, .st_cwq_noraddr, %o5, %o1)
.st_cwq_chk_authkey:
	stx	%o1, [%g5 + CW_AUTH_KEY_ADDR]

	add	%g5, %o2, %g2
	ldx	[%g2 + CW_AUTH_IV_ADDR], %g2
	brz,pn	%g2, .st_cwq_chk_authiv
	 mov	%g2, %o1
	mov 	MAX_IV_LENGTH, %o3
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %o3, .st_cwq_noraddr, %o5, %o1)
.st_cwq_chk_authiv:
	stx	%o1, [%g5 + CW_AUTH_IV_ADDR]

	add	%g5, %o2, %g2
	ldx	[%g2 + CW_FINAL_AUTH_STATE_ADDR], %g2
	brz,pn	%g2, .st_cwq_chk_authst
	 mov	%g2, %o1
	mov	MAX_AUTHSTATE_LENGTH, %o3
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %o3, .st_cwq_noraddr, %o5, %o1)
.st_cwq_chk_authst:
	stx	%o1, [%g5 + CW_FINAL_AUTH_STATE_ADDR]

	add	%g5, %o2, %g2
	ldx	[%g2 + CW_ENC_KEY_ADDR], %g2
	brz,pn	%g2,  .st_cwq_chk_key
	 mov	%g2, %o1
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %g6, .st_cwq_noraddr, %o5, %o1)
.st_cwq_chk_key:
	stx	%o1, [%g5 + CW_ENC_KEY_ADDR]

	add	%g5, %o2, %g2
	ldx	[%g2 + CW_ENC_IV_ADDR], %g2
	brz,pn	%g2, .st_cwq_chk_iv
	 mov	%g2, %o1
	mov	MAX_IV_LENGTH, %o3
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %o3, .st_cwq_noraddr, %o5, %o1)
.st_cwq_chk_iv:
	stx	%o1, [%g5 + CW_ENC_IV_ADDR]

	add	%g5, %o2, %g2
	ldx	[%g2 + CW_DST_ADDR], %g2
	brz,pn	%g2, .st_cwq_chk_dst
	 mov	%g2, %o1
	RA2PA_RANGE_CONV_UNK_SIZE(%o0, %g2, %g7, .st_cwq_noraddr, %o5, %o1)
.st_cwq_chk_dst:
	stx	%o1, [%g5 + CW_DST_ADDR]

	mov	ASI_SPU_CWQ_LAST, %o1
	ldxa	[%o1]ASI_STREAM, %o1
	mov	%g5, %g6			! save the last
	add	%g5, CWQ_CW_SIZE, %g5
	cmp	%g5, %o1			! current == Last?
	ba,pt	%xcc, .st_cwq_trans
	 movgu	%xcc, %g3, %g5			! current = First

.st_cwq_trans_done:
	mov	CW_EOB_MASK, %g5	! force set the EOB bit on the last
	sllx	%g5, CW_EOB_SHIFT, %g5	! CWQ submitted
	ldx	[%g6], %g3
	or	%g3, %g5, %g3
	stx	%g3, [%g6]
	membar	#Sync

	/*
	 * Update our local copy of the Head pointer.
	 * This will ensure that CQ_HEAD is non-zero
	 * for cwq_intr_getstate().
	 */
	VCPU_STRUCT(%g7)
	ldx	[%g7 + CPU_CWQ], %g3
	/*
	 * If the cq_head is non-zero then that indicates
	 * it is effectively being managed via sethead,
	 * so we don't want/need to update it here.
	 */
	ldx	[%g3 + CWQ_QUEUE + CQ_HEAD], %g2
	brnz,pt	%g2, .st_cwq_tailonly
	 nop
	/*
	 * Our first time installing a job on this queue,
	 * so go ahead and initialize cq_head.
	 */
	mov	ASI_SPU_CWQ_HEAD, %g4
	ldxa	[%g4]ASI_STREAM, %g2
	stx	%g2, [%g3 + CWQ_QUEUE + CQ_HEAD]

.st_cwq_tailonly:
	/*
	 * Update HW's copy of Tail with new Tail.
	 */
	mov	ASI_SPU_CWQ_TAIL, %g5
	stxa	%g1, [%g5]ASI_STREAM
	stx	%g1, [%g3 + CWQ_QUEUE + CQ_TAIL]
	ba,pt	%xcc, .st_cwq_return
	 mov	EOK, %o0

.st_cwq_noraddr:
	mov	ENORADDR, %o0
	/*FALLTHROUGH*/

.st_cwq_return:
	VCPU_STRUCT(%g7)
	ldx	[%g7 + CPU_CWQ], %g3
	ldx	[%g3 + CWQ_QUEUE + CQ_SCR1], %o1
	ldx	[%g3 + CWQ_QUEUE + CQ_SCR2], %o2
	ldx	[%g3 + CWQ_QUEUE + CQ_SCR3], %o3

	CWQ_LOCK_EXIT(%g3, %o5)

	HCALL_RET(%o0)

	SET_SIZE(ncs_settail_cwq)
