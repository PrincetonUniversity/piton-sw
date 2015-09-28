/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_ncs.s
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

	.ident	"@(#)hcall_ncs.s	1.13	07/09/12 SMI"

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
#include <md.h>
#include <abort.h>
#include <offsets.h>
#include <ncs.h>
#include <util.h>
#include <mau.h>

/*
 *-----------------------------------------------------------
 * Function: setup_mau
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
 *		%g1 - &config.maus[mau-id] or NULL (0) if error.
 *
 *	Uses:	%g1-%g6,%l3
 *-----------------------------------------------------------
 */

	ENTRY_NP(setup_mau)

	ldx	[%g1 + CPU_MAU], %g3
	brz,pn %g3, 1f
	 nop
	ldx	[%g3 + MAU_PID], %g6
	cmp	%g6, NMAUS
	bgeu,a,pn %xcc, 1f
	 mov	%g0, %g3

	VCPU2STRAND_STRUCT(%g1, %g5)
	ldub	[%g5 + STRAND_ID], %g5
	and	%g5, NSTRANDS_PER_MAU_MASK, %g5	! %g5 = hw thread-id
	mov	1, %g4
	sllx	%g4, %g5, %g4
	ldx	[%g3 + MAU_CPUSET], %g6
	btst	%g4, %g6
	bnz,pn  %xcc, 1f
	 nop
	bset	%g4, %g6
	stx	%g6, [%g3 + MAU_CPUSET]

	add	%g5, MAU_CPU_ACTIVE, %g5
	mov	-1, %g6
	stb	%g6, [%g3 + %g5]

	ldx	[%g3 + MAU_CPUSET], %g5
	cmp	%g4, %g5			! 1st (only) cpu?
	bne,pt  %xcc, 1f
	 nop

	ldx	[%g3 + MAU_PID], %g6
	ID2HANDLE(%g6, MAU_HANDLE_SIG, %g6)
	stx	%g6, [%g3 + MAU_HANDLE]
	stx	%g2, [%g3 + MAU_INO]
	/*
	 * Now set up mau queue.
	 */
	MAU_CLEAR_QSTATE(%g3)
	/*
	 * Now set up interrupt stuff.
	 */
	ldx	[%g1 + CPU_GUEST], %g1
	LABEL_ADDRESS(mau_intr_getstate, %g4)
	mov	%g0, %g5
	!!
	!! %g1 = guestp
	!! %g2 = ino
	!! %g3 = &config.maus[mau-id]
	!! %g4 = mau_intr_getstate
	!! %g5 = NULL (no setstate callback)`
	!! %g7 = return pc (set up in setup_cpu())
	!!
	/*
	 * Note that vdev_intr_register() clobbers %g1,%g3,%g5-%g7.
	 */
	mov	%g7, %l3			! save return pc
	HVCALL(vdev_intr_register)
	stx	%g1, [%g3 + MAU_IHDLR + CI_COOKIE]

	mov	MAU_STATE_RUNNING, %g2
	stx	%g2, [%g3 + MAU_STATE]

	mov	%l3, %g7			! restore return pc
1:
	mov	%g3, %g1			! return &maus[mau-id]
	HVRET

	SET_SIZE(setup_mau)

/*
 * Wrapper around setup_mau, so it can be called from C
 * SPARC ABI requries only that g2,g3,g4 are preserved across
 * function calls.
 *		%g1 - cpu struct
 *		%g2 - ino
 *		%g3 - config
 *	Output:
 *		%g1 - &config.maus[mau-id] or NULL (0) if error.
 *
 * maup = c_setup_mau(vcpup, ino, &config); 
 *
 */

	ENTRY(c_setup_mau)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	mov	%o0, %g1
	mov	%o1, %g2
	mov	%o2, %g3
	HVCALL(setup_mau)
	mov	%g1, %o0
	
	STRAND_POP(%g4, %g6)
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	
	retl
	  nop
	SET_SIZE(c_setup_mau)

/*
 *-----------------------------------------------------------
 * Function: stop_crypto()
 *
 *	This routines needs to execute ON the the core
 *	containing the desired MAU to be stopped.  This
 *	is accomplished by being called during stop_vcpu_cmd.
 *
 *	We wait for the MAU to stop by doing a sync-load.
 *	If the MAU is currently busy running a job on behalf
 *	of the current strand (cpu) being stopped then the
 *	sync-load will wait for it to complete.  If the MAU
 *	is busy running a job for a different strand (cpu)
 *	then the sync-load will immediately return.  Since
 *	the job being executed is on behalf of a different
 *	cpu then the immediate return is okay since we only
 *	care about the local cpu being stopped.
 *
 *	Note that we have to enable interrupts while doing
 *	this load to ensure the MAU can complete the operation
 *	including possibly handling an interrupt.
 *
 *	Since we are stopping the current cpu we can be
 *	assured that any new MAU jobs will not be issued
 *	on this strand (cpu).  Any subsequent MAU jobs will
 *	be issued from some other strand.
 *
 * Arguments:
 *	Input:
 *		%g1 - cpu struct
 *		%g2 - guest struct
 *		%g7 - return address
 *-----------------------------------------------------------
 */
	ENTRY_NP(stop_crypto)

	ldx	[%g1 + CPU_MAU], %g3
	brz,pn	%g3, 1f
	nop

	VCPU2STRAND_STRUCT(%g1, %g5)
	ldub	[%g5 + STRAND_ID], %g5
	and	%g5, NSTRANDS_PER_CORE_MASK, %g5	! %g5 = hw thread-id
	add	%g3, %g5, %g3
	ldub	[%g3 + MAU_CPU_ACTIVE], %g4
	brz,pn	%g4, 1f
	nop

	CRYPTO_STOP(%g4, %g5)

	stb	%g0, [%g3 + MAU_CPU_ACTIVE]
1:
	HVRET

	SET_SIZE(stop_crypto)


/*
 *-----------------------------------------------------------
 * Function: start_crypto()
 *
 *	All we have to do here is set the MAU_CPU_ACTIVE word.
 *
 * Arguments:
 *	Input:
 *		%g1 - cpu struct
 *		%g2 - guest struct
 *		%g7 - return address
 * Uses: %g3, %g4
 *-----------------------------------------------------------
 */
	ENTRY_NP(start_crypto)

	ldx	[%g1 + CPU_MAU], %g3
	brz,pn	%g3, 1f
	nop

	VCPU2STRAND_STRUCT(%g1, %g4)
	ldub	[%g4 + STRAND_ID], %g4
	and	%g4, NSTRANDS_PER_CORE_MASK, %g4	! %g4 = hw thread-id
	add	%g3, %g4, %g3
	mov	-1, %g4
	stb	%g4, [%g3 + MAU_CPU_ACTIVE]
1:
	HVRET

	SET_SIZE(start_crypto)

/*
 *-----------------------------------------------------------
 * Function: mau_intr()
 *	Called from within trap context.
 *	Changes MQ_HEAD only.
 * Arguments:
 *	Input:
 *		%g1 - cpu struct
 *	Output:
 *-----------------------------------------------------------
 */
	ENTRY_NP(mau_intr)

	ldx	[%g1 + CPU_MAU], %g2
	brz,pn	%g2, .mi_exit_nolock
	 nop

	MAU_LOCK_ENTER(%g2, %g5, %g3, %g6)

	ldx	[%g2 + MAU_STATE], %g3
	cmp	%g3, MAU_STATE_RUNNING
	bne,pn	%xcc, .mi_exit
	 nop

	VCPU2STRAND_STRUCT(%g1, %g7)
	ldub	[%g7 + STRAND_ID], %g7
	and	%g7, NSTRANDS_PER_MAU_MASK, %g7	! %g7 = hw thread-id
	add	%g2, %g7, %g4
	ldub	[%g4 + MAU_CPU_ACTIVE], %g4
	brz,pn	%g4, .mi_exit
	 nop

#ifdef	ERRATA_192
	ldx	[%g2 + MAU_STORE_IN_PROGR], %g3
	sub	%g3, 1, %g3
	brnz,pn	%g3, .mi_no_stpr
	 nop
	stx	%g0, [%g2 + MAU_STORE_IN_PROGR]
	ldx	[%g2 + MAU_ENABLE_CWQ], %g3
	brz,pn	%g3, .mi_no_stpr
	 nop
	mov	ASI_SPU_CWQ_CSR_ENABLE, %g4
	mov	CWQ_CSR_ENABLED, %g3
	stxa	%g3, [%g4]ASI_STREAM	! re-enable the cwq
.mi_no_stpr:
#endif
	ldx	[%g2 + MAU_QUEUE + MQ_HEAD], %g3
	ldx	[%g2 + MAU_QUEUE + MQ_TAIL], %g4

	mov	%g0, %g6			! do_intr flag

.mi_chknext:
	cmp	%g3, %g4			! queue empty?
	be,a,pn	%xcc, .mi_chkintr
	 st	%g0, [%g2 + MAU_QUEUE + MQ_BUSY]
	ldx	[%g3 + NHD_STATE], %g4
	/*
	 * If the descriptor is Pending, then we
	 * mark it Busy and start the job on the MA.
	 * There is no interrupt to the guest since
	 * obviously the job is not complete yet.
	 */
	cmp	%g4, ND_STATE_PENDING
	bne,pt	%xcc, .mi_chkbusy
	 nop
	mov	ND_STATE_BUSY, %g4
	stx	%g4, [%g3 + NHD_STATE]
	add	%g3, NHD_REGS, %g3
	/*
	 * Load up the MAU registers and start the job.
	 * Note that we force the Interrupt bit to be on.
	 * We can assume given the fact that we arrived in
	 * this code from an interrupt, so all subsequent
	 * jobs must have it set.
	 *
	 * We are out of registers, so we hide our do_intr flag
	 * in %g2 which we know is a 8-byte aligned address and
	 * thus not using bit0.
	 */
	or	%g2, %g6, %g2
	!!
	!! %g3 = ncs_hvdesc.nhd_regs
	!! %g7 = hw-thread-id
	!!

#ifdef ERRATA_192
	MAU_LOAD1(%g2, %g3, %g7, %g1, 1, .mi_addr_err, .mi_chkrv, %g4, %g5, %g6)
#else
	MAU_LOAD(%g3, %g7, %g1, 1, .mi_addr_err, .mi_chkrv, %g4, %g5, %g6)
#endif

	!!
	!! %g1 = return value (errno)
	!!
	and	%g2, 1, %g6			! get hidden do_intr flag
	ba	.mi_chkintr
	 andn	%g2, 1, %g2			! restore placeholder

.mi_addr_err:
	mov	ENORADDR, %g1

.mi_chkrv:
	brnz,a,pn %g1, .mi_set_state
	 mov	ND_STATE_ERROR, %g1
	mov	ND_STATE_DONE, %g1

.mi_set_state:
	sub	%g3, NHD_REGS, %g3
	stx	%g1, [%g3 + NHD_STATE]

	ldx	[%g3 + NHD_TYPE], %g4
	and	%g4, ND_TYPE_END, %g5
	!!
	!! %g5 = non-zero == END
	!!
	movrnz	%g5, 1, %g6

	add	%g3, NCS_HVDESC_SIZE, %g3	! mq_head++
	ldx	[%g2 + MAU_QUEUE + MQ_END], %g4
	cmp	%g3, %g4			! mq_head == mq_end?
	bgeu,a,pn %xcc, .mi_qwrap
	 ldx	[%g2 + MAU_QUEUE + MQ_BASE], %g3	! mq_head = mq_base
.mi_qwrap:
	stx	%g3, [%g2 + MAU_QUEUE + MQ_HEAD]
	ldx	[%g2 + MAU_QUEUE + MQ_TAIL], %g4
	cmp	%g3, %g4
	move	%xcc, 1, %g6
	/*
	 * If previous descriptor was not in error or was the
	 * last one in a job, then check the next descriptor
	 * for normal processing.
	 */
	brnz,pn	%g5, .mi_chknext
	 cmp	%g1, ND_STATE_ERROR
	bne,pt	%xcc, .mi_chknext
	 nop
	/*
	 * If we reach here then we encountered an
	 * error on a descriptor within the middle
	 * of a job.  Need to pop the entire job
	 * off the queue.  We stop popping descriptors
	 * off until we either hit the Last one or
	 * hit the Tail of the queue.
	 * Note that we set state in all remaining
	 * descriptors in job to Error (ND_STATE_ERROR).
	 */
	!!
	!! %g1 = ND_STATE_ERROR
	!!
	cmp	%g3, %g4			! queue empty?
	be,a,pn	%xcc, .mi_genintr
	 st	%g0, [%g2 + MAU_QUEUE + MQ_BUSY]
	ba	.mi_set_state
	 add	%g3, NHD_REGS, %g3

.mi_chkbusy:
	/*
	 * If the descriptor is Busy, then we have
	 * been interrupted for the completion of
	 * this particular descriptor.  If it is
	 * the End (last) descriptor in the job or
	 * the last descriptor in our queue, then we'll
	 * generate an interrupt to the guest.
	 */
	cmp	%g4, ND_STATE_BUSY
	bne,pn	%xcc, .mi_chkintr
	 nop

	MAU_CHECK_ERR(%g1, %g4, %g5)
	stx	%g1, [%g3 + NHD_ERRSTATUS]

	ba	.mi_chkrv
	 add	%g3, NHD_REGS, %g3

.mi_chkintr:
	brz,pt	%g6, .mi_exit
	 nop

.mi_genintr:
	/*
	 * This is the time we would store something
	 * into maus[].MAU_INTR.CI_DATA if we wanted,
	 * however it is currently unused.
	 */
	ldx	[%g2 + MAU_IHDLR + CI_COOKIE], %g1
	brz,pn	%g1, .mi_exit
	 nop

	MAU_LOCK_EXIT(%g2, %g5)

	HVCALL(vdev_intr_generate)

.mi_exit_nolock:
	retry

.mi_exit:

	MAU_LOCK_EXIT(%g2, %g5)

	retry

	SET_SIZE(mau_intr)

/*
 *-----------------------------------------------------------
 * Function: mau_intr_getstate()
 * Arguments:
 *	Input:
 *		%g1 - maus[] struct
 *		%g7 - return pc
 *	Output:
 *-----------------------------------------------------------
 */
	ENTRY_NP(mau_intr_getstate)

	mov	%g0, %g2
	ldx	[%g1 + MAU_QUEUE + MQ_HEAD], %g3
	ldx	[%g1 + MAU_QUEUE + MQ_HEAD_MARKER], %g4
	cmp	%g3, %g4
	movne	%xcc, 1, %g2
	jmp	%g7 + SZ_INSTR
	mov	%g2, %g1

	SET_SIZE(mau_intr_getstate)

/*
 *-----------------------------------------------------------
 * Function: hcall_ncs_request(int cmd, uint64_t arg, size_t sz)
 * Arguments:
 *	Input:
 *		%o5 - hcall function number
 *		%o0 - NCS sub-function
 *		%o1 - Real address of 'arg' data structure
 *		%o2 - Size of data structure at 'arg'.
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR, EBADALIGN, EWOULDBLOCK (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_request)

	btst	NCS_PTR_ALIGN - 1, %o1
	bnz,pn	%xcc, herr_badalign
	 nop
	/*
	 * convert %o1 to physaddr for calls below,
	 */
	GUEST_STRUCT(%g2)
	RA2PA_RANGE_CONV_UNK_SIZE(%g2, %o1, %o2, herr_noraddr, %g3, %g4)

	cmp	%o0, NCS_V10_QTAIL_UPDATE
	be	%xcc, ncs_v10_qtail_update
	 nop

	cmp	%o0, NCS_V10_QCONF
	be	%xcc, ncs_v10_qconf
	 nop

	HCALL_RET(EINVAL)

	SET_SIZE(hcall_ncs_request)

/*
 *-----------------------------------------------------------
 * Function: ncs_v10_qtail_update(int unused, ncs_qtail_update_arg_t *arg, size_t sz)
 * Arguments:
 *	Input:
 *		%o5 - hcall function number
 *		%o0 - NCS sub-function
 *		%o1 - ncs_qtail_update_arg_t *
 *		%o2 - sizeof (ncs_qtail_update_arg_t)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR, EWOULDBLOCK, EIO (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(ncs_v10_qtail_update)

	cmp	%o2, NCS_QTAIL_UPDATE_ARG_SIZE
	bne,pn	%xcc, herr_inval
	nop

	VCPU_GUEST_STRUCT(%g7, %g4)

	/*
	 * Ignore the MID that the guest passes. We use vMID's now
	 * so whatever it passes is likely wrong, just calculate the MID
	 * from the strand ID.
	 */
	VCPU2STRAND_STRUCT(%g7, %g2)
	ldub	[%g2 + STRAND_ID], %g2
	srlx	%g2, STRANDID_2_COREID_SHIFT, %g2

	cmp	%g2, NMAUS
	bgeu,pn	%xcc, herr_inval
	nop

	GUEST_MID_GETMAU(%g4, %g2, %o2)
	brz,pn	%o2, herr_inval
	nop

	add	%o2, MAU_QUEUE, %g1
	!!
	!! %g1 = maus[mid].mau_queue
	!!
	/*
	 * Make sure the tail index the caller
	 * gave us is a valid one for our queue,
	 * i.e. ASSERT(mq_nentries > nu_tail).
	 */
	ldx	[%g1 + MQ_NENTRIES], %g3
	/*
	 * Error if queue not configured,
	 * i.e. MQ_NENTRIES == 0
	 */
	brz,pn	%g3, herr_inval
	nop
	ldx	[%o1 + NU_TAIL], %g2
	!!
	!! %g3 = mau.mau_queue.mq_nentries
	!! %g2 = ncs_qtail_update_arg.nu_tail
	!!
	cmp	%g3, %g2
	bleu,pn	%xcc, herr_inval
	 nop

	ldx	[%o1 + NU_SYNCFLAG], %g6
	movrnz	%g6, 1, %g6

	mov	%g4, %o1		! %o1 = guest struct
	/*
	 * Turn tail index passed in by caller into
	 * actual pointer into queue.
	 */
	sllx	%g2, NCS_HVDESC_SHIFT, %g3
	ldx	[%g1 + MQ_BASE], %g4
	add	%g3, %g4, %g3
	!!
	!! %g3 = &mau_queue.mq_base[nu_tail] (new mq_tail)
	!!
	stx	%g3, [%g1 + MQ_TAIL]

.v1_qtail_dowork:
	sub	%g0, 1, %g2
	st	%g2, [%g1 + MQ_BUSY]

	ldx	[%g1 + MQ_HEAD], %g2
	ldx	[%g1 + MQ_END], %g5
	!!
	!! %g2 = mq_head
	!! %g3 = mq_tail
	!! %g5 = mq_end
	!!
	/*
	 * Need hw-thread-id for MA_CTL register.
	 * Start at mq_head and keep looking for work
	 * until we run into mq_tail.
	 */
	VCPU2STRAND_STRUCT(%g7, %g7)
	ldub	[%g7 + STRAND_ID], %g7		! %g7 = physical cpuid
	and	%g7, NSTRANDS_PER_MAU_MASK, %g7	! phys cpuid -> hw threadid
	!!
	!! %o1 = guest struct
	!! %g7 = hw-thread-id
	!!

.v1_qtail_loop:
	cmp	%g2, %g3			! mq_head == mq_tail?
	be,a,pn	%xcc, .v1_qtail_done
	 stx	%g2, [%g1 + MQ_HEAD]
	/*
	 * Mark current descriptor busy.
	 */
	mov	ND_STATE_BUSY, %o0
	stx	%o0, [%g2 + NHD_STATE]		! nhd_state = BUSY
	add	%g2, NHD_REGS, %g2
	!!
	!! %g2 = ncs_hvdesc.nhd_regs
	!! %g7 = hw-thread-id
	!!
	MAU_LOAD(%g2, %g7, %o0, %g6, .v1_qtail_addr_err, .v1_qtail_chk_rv, %o1, %o2, %g4)

	/*
	 * If this was an asynchronous descriptor then
	 * we're done!  Leave MQ_BUSY set.
	 */
	brnz,pt	%g6, .v1_qtail_done_async
	 nop

	/*
	 * In Niagara2 the Load value from the Sync
	 * register simply indicates whether the MAU
	 * was busy (1 = yes, 0 = no) at the time we
	 * issued the Load.  It does not indicate a
	 * success or failure of the MAU operation.
	 * So, we effectively ignore the Load value and
	 * check for errors in the HWE/INVOP bits in
	 * the Control register.
	 */
	mov	ASI_MAU_SYNC, %g4
	ldxa	[%g4]ASI_STREAM, %g0
	/*
	 * Check error bits in Control register.
	 */
	MAU_CHECK_ERR(%o0, %o1, %g4)

.v1_qtail_chk_rv:
	/*
	 * Determine appropriate state to set
	 * descriptor to.
	 */
	brnz,a,pn  %o0, .v1_qtail_set_state
	 mov	ND_STATE_ERROR, %o2
	mov	ND_STATE_DONE, %o2
.v1_qtail_set_state:
	sub	%g2, NHD_REGS, %g2
	!!
	!! %g2 = &ncs_hvdesc
	!!
	stx	%o2, [%g2 + NHD_STATE]
	brnz,a,pn  %o0, .v1_qtail_err
	 stx	%g2, [%g1 + MQ_HEAD]

	ldx	[%g1 + MQ_BASE], %g4
	add	%g2, NCS_HVDESC_SIZE, %g2	! mq_head++
	cmp	%g2, %g5			! mq_head == mq_end?
	ba,pt	%xcc, .v1_qtail_loop
	 movgeu	%xcc, %g4, %g2			! mq_head = mq_base

.v1_qtail_done:
	ba	hret_ok
	 st	%g0, [%g1 + MQ_BUSY]

.v1_qtail_done_async:
	ba	hret_ok
	 nop

.v1_qtail_addr_err:
	ba	.v1_qtail_chk_rv
	 mov	ENORADDR, %o0

.v1_qtail_err:
	!!
	!! %o0 = EWOULDBLOCK, EINVAL, ENORADDR, EIO
	!!
	st	%g0, [%g1 + MQ_BUSY]

	HCALL_RET(%o0)

	SET_SIZE(ncs_v10_qtail_update)

/*
 *-----------------------------------------------------------
 * Function: ncs_v10_qconf(int unused, ncs_qconf_arg_t *arg, size_t sz)
 * Arguments:
 *	Input:
 *		%o5 - hcall function number
 *		%o0 - NCS sub-function
 *		%o1 - ncs_qconf_arg_t *
 *		%o2 - sizeof (ncs_qconf_arg_t)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EBADALIGN, ENORADDR, EINVAL (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(ncs_v10_qconf)

	cmp	%o2, NCS_QCONF_ARG_SIZE
	bne,pn	%xcc, herr_inval
	 nop

	ldx	[%o1 + NQ_MID], %g2		! %g2 = mid
	cmp	%g2, NMAUS
	bgeu,pn	%xcc, herr_inval
	 nop

	GUEST_STRUCT(%g1)
	/*
	 * Recall that the driver code simply increments
	 * through all the possible vMIDs when doing a qconf,
	 * regardless of whether they are actually present
	 * or not.  As a result, it is possible for
	 * the following macro to return null if the guest
	 * does not have access to that MAU.  This is not a
	 * critical error since the driver code will never
	 * attempt to use a non-present mau, however the
	 * driver code cannot currently handle a "no mau"
	 * error return from this HV call and since the driver
	 * code is at present off-limit for repair, we have
	 * to fake success.
	 */
	/*
	 * Guests calculate the MAUID based on cpu id, which are 
	 * virtual ids. But firmware uses physical MIDs. So we need
	 * to translate the guest's vMID to a physical MID.
	 * Loop through the ROOT MID array and add 1 to the vMID for
	 * each unconfigured MAU we find.
	 */

	mov	0, %g4
0:
	cmp	%g4, NMAUS
	bgeu,pn	%xcc, hret_ok
	nop
	GUEST_MID_GETMAU(%g1, %g4, %g3)
	brz,pn	%g3, 1f
	cmp	%g2, %g4
	be	%xcc, 2f
	nop
	ba	0b
1:	inc	%g4
	ba	0b
	inc	%g2
2:

	add	%g3, MAU_QUEUE, %g1	! %g1 = &maus[mid].mau_queue

	ldx	[%o1 + NQ_BASE], %g2
	brnz,a,pt %g2, .v1_qconf_config
	 ldx	[%o1 + NQ_END], %g3
	/*
	 * Caller wishes to unconfigure the mau_queue entry
	 * for the given MAU.
	 */
	ld	[%g1 + MQ_BUSY], %g4
	brnz,pn	%g4, herr_wouldblock
	 nop
	stx	%g0, [%g1 + MQ_BASE]
	stx	%g0, [%g1 + MQ_END]
	stx	%g0, [%g1 + MQ_HEAD]
	stx	%g0, [%g1 + MQ_TAIL]
	stx	%g0, [%g1 + MQ_NENTRIES]

	HCALL_RET(EOK)

.v1_qconf_config:
	/*
	 * %g2 = nq_base
	 * %g3 = nq_end
	 */
	or	%g2, %g3, %g5
	btst	NCS_PTR_ALIGN - 1, %g5
	bnz,pn	%xcc, herr_badalign
	 nop

	sub	%g3, %g2, %g5			! %g5 = queue size (end-base)
	/*
	 * %g2 (RA(nq_base) -> PA(nq_base))
	 */
	GUEST_STRUCT(%g4)
	RA2PA_RANGE_CONV_UNK_SIZE(%g4, %g2, %g5, herr_noraddr, %g6, %g7)
	mov     %g7, %g2
	/*
	 * %g3 (RA(nq_end) -> PA(nq_end))
	 */
	RA2PA_RANGE_CONV(%g4, %g3, 8, herr_noraddr, %g6, %g7)
	mov     %g7, %g3

	/*
	 * Verify that the queue size is what
	 * we would expect, i.e. (nq_nentries << NCS_HVDESC_SHIFT)
	 */
	ldx	[%o1 + NQ_NENTRIES], %g6
	sllx	%g6, NCS_HVDESC_SHIFT, %g7
	cmp	%g5, %g7
	bne,pn	%xcc, herr_inval
	 nop

	stx	%g2, [%g1 + MQ_BASE]
	/*
	 * Head and Tail initially point to Base.
	 */
	stx	%g2, [%g1 + MQ_HEAD]
	stx	%g2, [%g1 + MQ_TAIL]

	stx	%g3, [%g1 + MQ_END]
	stx	%g6, [%g1 + MQ_NENTRIES]

	HCALL_RET(EOK)

	SET_SIZE(ncs_v10_qconf)

/*
 *-----------------------------------------------------------
 * Function: ncs_qconf(uint64_t qtype, uint64_t baseaddr, uint64_t nentries)
 * Arguments:
 *	Input:
 *		%o0 - queue type
 *		%o1 - base real address of queue or queue handle if
 *		      unconfiguring a queue.
 *		%o2 - number of entries in queue
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENOACCESS, EBADALIGN,
 *		      ENORADDR (on failure)
 *		%o1 - queue handle for respective queue.
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_qconf)

	VCPU_GUEST_STRUCT(%g2, %g1)

	cmp	%o0, NCS_QTYPE_MAU
	be	ncs_qconf_mau
	 nop
	
	IS_NCS_QTYPE_CWQ(%o0, NCS_QTYPE_CWQ, ncs_qconf_cwq)

	HCALL_RET(EINVAL)

	SET_SIZE(hcall_ncs_qconf)

/*
 *-----------------------------------------------------------
 * Function: ncs_qconf_mau
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
	ENTRY_NP(ncs_qconf_mau)

	VCPU_GUEST_STRUCT(%g2, %g1)
	brz,pn	%o2, .m_qconf_unconfig
	 nop

	cmp	%o2, NCS_MIN_MAU_NENTRIES
	blu,pn	%xcc, herr_inval
	 nop
	/*
	 * Check that #entries is a power of two.
	 */
	sub	%o2, 1, %g3
	andcc	%o2, %g3, %g0
	bnz,pn	%xcc, herr_inval
	 nop

	ldx	[%g2 + CPU_MAU], %g3
	brz,pn	%g3, herr_noaccess
	 nop
	/*
	 * The cpu that does the queue configure will also
	 * be the one targeted for all the interrupts for
	 * this mau.  We need to effectively single thread
	 * the interrupts per-mau because the interrupt handler
	 * updates global per-mau data structures.
	 */
	VCPU2STRAND_STRUCT(%g2, %g7)
	ldub	[%g7 + STRAND_ID], %o0
	/*
	 * Make sure base address is size aligned.
	 */
	sllx	%o2, NCS_HVDESC_SHIFT, %g4
	sub	%g4, 1, %g2
	btst	%g2, %o1
	bnz,pn	%xcc, herr_badalign
	 nop

	MAU_LOCK_ENTER(%g3, %g5, %g2, %g6)
	/*
	 * Translate base address from real to physical.
	 */
	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o1, %g4, .m_qconf_noraddr, %g6, %g2)

	stx	%o0, [%g3 + MAU_QUEUE + MQ_CPU_PID]
	stx	%o1, [%g3 + MAU_QUEUE + MQ_BASE_RA]
	stx	%g2, [%g3 + MAU_QUEUE + MQ_BASE]
	stx	%g2, [%g3 + MAU_QUEUE + MQ_HEAD]
	stx	%g2, [%g3 + MAU_QUEUE + MQ_TAIL]
	add	%g2, %g4, %g2
	stx	%g2, [%g3 + MAU_QUEUE + MQ_END]
	stx	%o2, [%g3 + MAU_QUEUE + MQ_NENTRIES]
	st	%g0, [%g3 + MAU_QUEUE + MQ_BUSY]
	stx	%g0, [%g3 + MAU_QUEUE + MQ_HEAD_MARKER]
	mov	NCS_QSTATE_CONFIGURED, %g1
	st	%g1, [%g3 + MAU_QUEUE + MQ_STATE]

	ldx	[%g3 + MAU_HANDLE], %o1

	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

.m_qconf_noraddr:
	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(ENORADDR)

.m_qconf_unconfig:

	MAU_HANDLE2ID_VERIFY(%o1, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_noaccess
	 nop

	MAU_LOCK_ENTER(%g3, %g5, %g1, %g6)

	ld	[%g3 + MAU_QUEUE + MQ_BUSY], %g4
	brnz,pn	%g4, .m_qconf_wouldblock
	 nop

	MAU_CLEAR_QSTATE(%g3)
	mov	NCS_QSTATE_UNCONFIGURED, %g1
	st	%g1, [%g3 + MAU_QUEUE + MQ_STATE]

	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

.m_qconf_wouldblock:
	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EWOULDBLOCK)

	SET_SIZE(ncs_qconf_mau)

/*
 *-----------------------------------------------------------
 * Function: ncs_qinfo(uint64_t qhandle)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL (on failure)
 *		%o1 - queue type
 *		%o2 - queue base real address
 *		%o3 - number of queue entries
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_qinfo)

	GUEST_STRUCT(%g1)

	HANDLE_IS_MAU(%o0, %g2)
	bne	%xcc, 0f
	 nop

	MAU_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop

	MAU_LOCK_ENTER(%g3, %g2, %g5, %g6)

	mov	NCS_QTYPE_MAU, %o1
	ldx	[%g3 + MAU_QUEUE + MQ_BASE_RA], %o2
	ldx	[%g3 + MAU_QUEUE + MQ_NENTRIES], %o3

	MAU_LOCK_EXIT_L(%g2)

	HCALL_RET(EOK)

0:
	HCALL_NCS_QINFO_CWQ()

	SET_SIZE(hcall_ncs_qinfo)

/*
 *-----------------------------------------------------------
 * Function: ncs_gethead(uint64_t qhandle)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL (on failure)
 *		%o1 - queue head offset
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_gethead)

	VCPU_GUEST_STRUCT(%g7, %g1)

	HANDLE_IS_MAU(%o0, %g2)
	bne	%xcc, 0f
	 nop

	MAU_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop

	MAU_LOCK_ENTER(%g3, %g5, %g2, %g6)

	ldx	[%g3 + MAU_QUEUE + MQ_BASE], %g1
	ldx	[%g3 + MAU_QUEUE + MQ_HEAD], %g2
	sub	%g2, %g1, %o1

	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

0:

	HCALL_NCS_GETHEAD_CWQ()

	SET_SIZE(hcall_ncs_gethead)

/*
 *-----------------------------------------------------------
 * Function: ncs_gettail(uint64_t qhandle)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL (on failure)
 *		%o1 - queue tail offset
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_gettail)

	VCPU_GUEST_STRUCT(%g7, %g1)

	HANDLE_IS_MAU(%o0, %g2)
	bne	%xcc, 0f
	 nop

	MAU_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop

	MAU_LOCK_ENTER(%g3, %g5, %g2, %g6)

	ldx	[%g3 + MAU_QUEUE + MQ_BASE], %g1
	ldx	[%g3 + MAU_QUEUE + MQ_TAIL], %g2
	sub	%g2, %g1, %o1

	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

0:

	HCALL_NCS_GETTAIL_CWQ()

	SET_SIZE(hcall_ncs_gettail)

/*
 *-----------------------------------------------------------
 * Function: ncs_qhandle_to_devino(uint64_t qhandle)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL (on failure)
 *		%o1 - devino
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_qhandle_to_devino)

	GUEST_STRUCT(%g1)

	HANDLE_IS_MAU(%o0, %g2)
	bne	%xcc, 0f
	 nop

	MAU_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop

	ldx	[%g3 + MAU_INO], %o1

	HCALL_RET(EOK)

0:
	HCALL_NCS_QHANDLE_TO_DEVINO_CWQ()

	SET_SIZE(hcall_ncs_qhandle_to_devino)

/*
 *-----------------------------------------------------------
 * Function: ncs_sethead_marker(uint64_t qhandle, uint64_t new_headoffset)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *		%o1 - new head offset
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_sethead_marker)

	GUEST_STRUCT(%g1)

	HANDLE_IS_MAU(%o0, %g2)
	bne	%xcc, 0f
	 nop

	MAU_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop

	btst	NCS_HVDESC_SIZE - 1, %o1
	bnz,a,pn %xcc, herr_inval
	 nop

	MAU_LOCK_ENTER(%g3, %g5, %g2, %g6)

	ldx	[%g3 + MAU_QUEUE + MQ_BASE], %g1
	add	%g1, %o1, %g1
	ldx	[%g3 + MAU_QUEUE + MQ_END], %g2
	cmp	%g1, %g2
	blu,a,pn %xcc, 1f
	 stx	%g1, [%g3 + MAU_QUEUE + MQ_HEAD_MARKER]

	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EINVAL)

1:
	MAU_LOCK_EXIT_L(%g5)

	HCALL_RET(EOK)

0:
	HCALL_NCS_SETHEAD_MARKER_CWQ()

	SET_SIZE(hcall_ncs_sethead_marker)

/*
 *-----------------------------------------------------------
 * Function: ncs_settail(uint64_t qhandle, uint64_t new_tailoffset)
 * Arguments:
 *	Input:
 *		%o0 - queue handle
 *		%o1 - new tail offset
 *	Output:
 *		%o0 - EOK (on success),
 *		      EINVAL, ENORADDR (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_ncs_settail)

	VCPU_GUEST_STRUCT(%g7, %g1)

	HANDLE_IS_MAU(%o0, %g2)
	be	%xcc, ncs_settail_mau
	 nop

	HANDLE_IS_CWQ_BRANCH(%o0, %g2, ncs_settail_cwq)

	HCALL_RET(EINVAL)

	SET_SIZE(hcall_ncs_settail)

/*
 *-----------------------------------------------------------
 * Function: ncs_settail_mau(uint64_t qhandle, uint64_t new_tailoffset)
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
	ENTRY_NP(ncs_settail_mau)

	MAU_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)
	GUEST_MID_GETMAU(%g1, %g2, %g3)
	brz,pn	%g3, herr_inval
	 nop
	/*
	 * Verify that we're on the MAU that the
	 * caller specified.
	 */
	ldx	[%g7 + CPU_MAU], %g4
	cmp	%g4, %g3
	bne,pn	%xcc, herr_inval
	 nop

	btst	NCS_HVDESC_SIZE - 1, %o1
	bnz,a,pn %xcc, herr_inval
	 nop

	ldx	[%g3 + MAU_QUEUE + MQ_BASE], %g1
	add	%g1, %o1, %g1
	ldx	[%g3 + MAU_QUEUE + MQ_END], %g2
	cmp	%g1, %g2
	bgeu,pn	%xcc, herr_inval
	 nop

	MAU_LOCK_ENTER(%g3, %g5, %g4, %g6)

	/*
	 * Update MQ_BUSY to indicate we're going to have work
	 * pending.  If the current MQ_BUSY is non-zero then
	 * that indicates that queue has jobs and is being
	 * managed asynchronously (via mau_intr).
	 */
	mov	-1, %g4
	ld	[%g3 + MAU_QUEUE + MQ_BUSY], %g2
	st	%g4, [%g3 + MAU_QUEUE + MQ_BUSY]
	brz,pt	%g2, .st_mau_dowork
	 ldx	[%g3 + MAU_QUEUE + MQ_HEAD], %g2
	/*
	 * Queue already busy indicating queue is being
	 * actively managed by interrupt handler.  So,
	 * all we have to do is insert job at tail and
	 * we're done.
	 */
	ldx	[%g3 + MAU_QUEUE + MQ_TAIL], %g4
	cmp	%g2, %g4
	be	%xcc, .st_mau_dowork
	 nop

	stx	%g1, [%g3 + MAU_QUEUE + MQ_TAIL]
	MAU_LOCK_EXIT_L(%g5)
	ba	hret_ok
	 nop

.st_mau_dowork:

	stx	%g1, [%g3 + MAU_QUEUE + MQ_TAIL]
	!!
	!! %g2 = mq_head
	!! %g1 = mq_tail
	!!
	/*
	 * Use the per-cwq assigned cpu as target
	 * for interrupts for this job.
	 */
	ldx	[%g3 + MAU_QUEUE + MQ_CPU_PID], %g7
	and	%g7, NSTRANDS_PER_MAU_MASK, %g7	! pid -> hw tid
	!!
	!! %g7 = hw thread-id
	!!

.st_mau_loop:
	cmp	%g2, %g1			! mq_head == mq_tail?
	be,pn	%xcc, .st_mau_done
	 nop
	/*
	 * Mark current descriptor busy.
	 */
	mov	ND_STATE_BUSY, %o0
	stx	%o0, [%g2 + NHD_STATE]		! nhd_state = BUSY
	add	%g2, NHD_REGS, %g2
	!!
	!! %g2 = ncs_hvdesc.nhd_regs
	!! $g7 = hw thread-id
	!!
	MAU_LOAD(%g2, %g7, %o0, 1, .st_mau_addr_err, .st_mau_chk_rv, %o1, %o5, %g4)
	/*
	 * We're done.  The rest will be handled by MAU
	 * interrupt handler.  Leave MQ_BUSY set.
	 */
	MAU_LOCK_EXIT(%g3, %g5)
	
	ba	hret_ok
	 nop

.st_mau_chk_rv:
	/*
	 * Determine appropriate state to set descriptor to.
	 */
	mov	ND_STATE_DONE, %o5
	movrnz	%o0, ND_STATE_ERROR, %o5

.st_mau_set_state:
	sub	%g2, NHD_REGS, %g2
	!!
	!! %g2 = &ncs_hvdesc
	!!
	stx	%o5, [%g2 + NHD_STATE]

	ldx	[%g2 + NHD_TYPE], %o1
	and	%o1, ND_TYPE_END, %o1

	add	%g2, NCS_HVDESC_SIZE, %g2	! mq_head++
	ldx	[%g3 + MAU_QUEUE + MQ_END], %g5
	ldx	[%g3 + MAU_QUEUE + MQ_BASE], %g4
	cmp	%g2, %g5			! mq_head == mq_end?
	movgeu	%xcc, %g4, %g2			! mq_head = mq_base
	stx	%g2, [%g3 + MAU_QUEUE + MQ_HEAD]
	/*
	 * If previous descriptor was not in error or was the
	 * last one in a job, then check the next descriptor
	 * for normal processing.
	 */
	brnz,pn	%o1, .st_mau_loop		! last descriptor?
	 cmp	%o5, ND_STATE_ERROR
	bne,pn	%xcc, .st_mau_loop
	 nop
	/*
	 * If we reach here then we encountered an
	 * error on a descriptor within the middle
	 * of a job.  Need to pop the entire job
	 * off the queue.  We stop popping descriptors
	 * off until we either hit the Last one or
	 * hit the Tail of the queue.
	 * Note that we set state in all remaining
	 * descriptors in job to Error (ND_STATE_ERROR).
	 */
	!!
	!! %o5 = ND_STATE_ERROR
	!!
	cmp	%g2, %g1			! queue empty?
	bne,pt	%xcc, .st_mau_set_state
	 add	%g2, NHD_REGS, %g2

.st_mau_done:
	st	%g0, [%g3 + MAU_QUEUE + MQ_BUSY]

	MAU_LOCK_EXIT(%g3, %g5)

	ba	hret_ok
	 nop

.st_mau_addr_err:
	ba	.st_mau_chk_rv
	 mov	ENORADDR, %o0

	SET_SIZE(ncs_settail_mau)
