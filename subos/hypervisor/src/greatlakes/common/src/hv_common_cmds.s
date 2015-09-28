/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hv_common_cmds.s
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

	.ident	"@(#)hv_common_cmds.s	1.3	07/05/03 SMI"

/*
 * Niagara-family common startup code
 */

#include <sys/asm_linkage.h>
#include <sys/stack.h>		/* For C environ : FIXME */
#include <sys/htypes.h>
#include <hprivregs.h>
#include <sun4v/traps.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <hypervisor.h>
#include <guest.h>
#include <errs_common.h>
#include <offsets.h>
#include <vcpu.h>
#include <sun4v/errs_defs.h>
#include <debug.h>
#include <util.h>
#include <abort.h>
#include <hvctl.h>


/*
 * This function handles the receipt of a command mondo from another
 * strand. Should only get here if we know that a mondo is waiting.
 */
	ENTRY(handle_hvmondo)

	/* Collect the pending mondo */
	HVCALL(hvmondo_recv)
	mov	%g1, %g2	! ptr to mondo
	STRAND_STRUCT(%g1)

	ldx	[%g2 + HVM_CMD], %g3
	cmp	%g3, HXCMD_SCHED_VCPU
	be,pn	%xcc, schedule_vcpu_cmd
	cmp	%g3, HXCMD_DESCHED_VCPU
	be,pn	%xcc, deschedule_vcpu_cmd
	cmp	%g3, HXCMD_STOP_VCPU
	be,pn	%xcc, stop_vcpu_cmd
	cmp	%g3, HXCMD_GUEST_SHUTDOWN
	be,pt	%xcc, shutdown_guest_cmd
	cmp	%g3, HXCMD_GUEST_PANIC
	be,pt	%xcc, panic_guest_cmd
	cmp	%g3, HXCMD_STOP_GUEST
	be,pt	%xcc, stop_guest_cmd
	nop

	HVABORT(-1, "Unknown HV mondo command")

	SET_SIZE(handle_hvmondo)

/*
 * shutdown_guest_cmd
 *
 * Handler for the HV xcall to send a shutdown request to
 * a particular vcpu. This does not return to the caller.
 *
 * %g1 = ptr to strand
 * %g2 = ptr to command mondo
 */
	ENTRY_NP(shutdown_guest_cmd)

#ifdef DEBUG
	PRINT("shutdown_guest_cmd: strand=0x")
	ldub	[%g1 + STRAND_ID], %g3
	PRINTX(%g3)
	PRINT("\r\n")
#endif /* DEBUG */

	/*
	 * Processing of the shutdown request will occur
	 * on the vcpu specified in the mondo structure.
	 *
	 * By bypassing the strand work wheel and restoring
	 * the vcpu state directly, this assumes a one to
	 * one mapping between strands and vcpus. This will
	 * have to be fixed once multiple vcpus can be
	 * scheduled on the same strand.
	 */
	ldx	[%g2 + HVM_ARGS + HVM_GUESTCMD_VCPUP], %g3
	SET_VCPU_STRUCT(%g3, %g4)

	/*
	 * Restore the vcpu state. Since this will result
	 * in the loss of current register state, save the
	 * mondo arg into the strand structure.
	 */
	STRAND_PUSH(%g2, %g3, %g4)
	HVCALL(vcpu_state_restore)
	STRAND_POP(%g2, %g3)

	! load the grace period timeout
	ldx	[%g2 + HVM_ARGS + HVM_GUESTCMD_ARG], %g1
	HVCALL(guest_shutdown)
	retry

	SET_SIZE(shutdown_guest_cmd)


/*
 * panic_guest_cmd
 *
 * Handler for the HV xcall to send a panic request to a
 * particular vcpu. This does not return to the caller.
 *
 * %g1 = ptr to strand
 * %g2 = ptr to command mondo
 */
	ENTRY_NP(panic_guest_cmd)

#ifdef DEBUG
	PRINT("panic_guest_cmd: strand=0x")
	ldub	[%g1 + STRAND_ID], %g3
	PRINTX(%g3)
	PRINT("\r\n")
#endif /* DEBUG */

	/*
	 * Processing of the panic request will occur on
	 * the vcpu specified in the mondo structure.
	 *
	 * By bypassing the strand work wheel and restoring
	 * the vcpu state directly, this assumes a one to
	 * one mapping between strands and vcpus. This will
	 * have to be fixed once multiple vcpus can be
	 * scheduled on the same strand.
	 */
	ldx	[%g2 + HVM_ARGS + HVM_SCHED_VCPUP], %g3

	! restore the vcpu state
	SET_VCPU_STRUCT(%g3, %g4)
	HVCALL(vcpu_state_restore)

	HVCALL(guest_panic)

	/*
	 * Send the trap to the guest. Clear the pending
	 * flag on the way out.
	 */
	STRAND_STRUCT(%g1)
	set	STRAND_NRPENDING, %g2
	ba	nonresumable_error_trap
	  stx	%g0, [%g1 + %g2]

	/*NOTREACHED*/
	SET_SIZE(panic_guest_cmd)


/*
 * guest_shutdown
 *
 * Queue up a resumable error packet on the current vcpu,
 * requesting that the guest perform an orderly shutdown.
 *
 * %g1 = grace period for shutdown (seconds)
 */
	ENTRY_NP(guest_shutdown)

	ba,pt	%xcc, 1f
	rd	%pc, %g2
	.align	8
	.skip	Q_EL_SIZE
1:	inc	4 + (8 - 1), %g2
	andn	%g2, 0x7, %g2	! align

	!! %g2 = sun4v erpt buffer

	/*
	 * Fill in the only additional data in this erpt,
	 * the grace period before shutdown (seconds).
	 */
	sth	%g1, [%g2 + ESUN4V_G_SECS]

	/*
	 * Fill in the generic parts of the erpt.
	 */
	GEN_SEQ_NUMBER(%g4, %g5)
	stx	%g4, [%g2 + ESUN4V_G_EHDL]

	rd	STICK, %g4
	stx	%g4, [%g2 + ESUN4V_G_STICK]

	set	EDESC_WARN_RESUMABLE, %g4
	stw	%g4, [%g2 + ESUN4V_EDESC]

	set	(ERR_ATTR_MODE(ERR_MODE_UNKNOWN) | EATTR_SECS), %g4
	stw	%g4, [%g2 + ESUN4V_ATTR]

	stx	%g0, [%g2 + ESUN4V_ADDR]
	stw	%g0, [%g2 + ESUN4V_SZ]
	sth	%g0, [%g2 + ESUN4V_G_CPUID]

	STRAND_PUSH(%g7, %g3, %g4)
	HVCALL(queue_resumable_erpt)
	STRAND_POP(%g7, %g3)

	HVRET
	SET_SIZE(guest_shutdown)


/*
 * guest_panic
 *
 * Queue up a non-resumable error packet on the current
 * vcpu, requesting that the guest panic immediately.
 */
	ENTRY_NP(guest_panic)

	ba,pt	%xcc, 1f
	rd	%pc, %g2
	.align	8
	.skip	Q_EL_SIZE
1:	inc	4 + (8 - 1), %g2
	andn	%g2, 0x7, %g2	! align

	!! %g2 = sun4v erpt buffer

	/*
	 * Fill in the generic parts of the erpt
	 */
	GEN_SEQ_NUMBER(%g4, %g5)
	stx	%g4, [%g2 + ESUN4V_G_EHDL]

	rd	STICK, %g4
	stx	%g4, [%g2 + ESUN4V_G_STICK]

	set	EDESC_FORCED_PANIC, %g4
	stw	%g4, [%g2 + ESUN4V_EDESC]

	set	(ERR_ATTR_MODE(ERR_MODE_UNKNOWN)), %g4
	stw	%g4, [%g2 + ESUN4V_ATTR]

	stx	%g0, [%g2 + ESUN4V_ADDR]
	stw	%g0, [%g2 + ESUN4V_SZ]
	sth	%g0, [%g2 + ESUN4V_G_CPUID]

	STRAND_PUSH(%g7, %g3, %g4)
	HVCALL(queue_nonresumable_erpt)
	STRAND_POP(%g7, %g3)

	/*
	 * Set the pending flag used when the vbsc_rx
	 * handler calls this directly, i.e. when a HV
	 * xcall is not required.
	 */
	STRAND_STRUCT(%g1)
	set	STRAND_NRPENDING, %g3
	mov	1, %g4
	stx	%g4, [%g1 + %g3]

	HVRET
	SET_SIZE(guest_panic)


/*
 * We get here as a HV mondo X-call
 * Our working assumption is that the currently running vcpu state
 * (if any) has been stashed back into its vcpu structure, and so at
 * the end of this operation we bail back to start_work.
 *
 * The argument in the strand x-call mail box is the pointer
 * to the vcpu to schedule. Plus a set of optional parameters
 * to setup in the vcpu struct. FIXME: these parameters should
 * be being set by the sender not us...
 *
 * %g1 = ptr to strand
 * %g2 = ptr to command mondo
 */
	ENTRY(schedule_vcpu_cmd)
	add	%g2, HVM_ARGS, %g3

		/* FIXME: validate args ! */
	ldx	[%g3 + HVM_SCHED_VCPUP], %g4		! vcpu ptr
		! assert vcpup->strand == %g1
	ldub	[%g4 + CPU_STRAND_SLOT], %g5

#if DBG_SCHEDULE /* { */
	PRINT("schedule vcpu @ 0x")
	PRINTX(%g4)
	PRINT(" id = 0x")
	lduw	[%g4 + CPU_RES_ID], %g6
	PRINTX(%g6)
	PRINT(" vid = 0x")
	ldub	[%g4 + CPU_VID], %g6
	PRINTX(%g6)
	PRINT(" in slot 0x")
	PRINTX(%g5)
	PRINT("\r\n")
#endif /* } */
	mulx	%g5, SCHED_SLOT_SIZE, %g3
	add	%g1, STRAND_SLOT, %g1
	add	%g1, %g3, %g3
	stx	%g4, [%g3 + SCHED_SLOT_ARG]
	mov	SLOT_ACTION_RUN_VCPU, %g2
	stx	%g2, [%g3 + SCHED_SLOT_ACTION]
	ba	start_work
	  nop
	SET_SIZE(schedule_vcpu_cmd)


/*
 * We get here as a HV mondo X-call
 * Our working assumption is that the currently running vcpu state
 * (if any) has been stashed back into its vcpu structure, and so
 * at the end of this operation we bail back to start_work.
 *
 * The argument in the strand x-call mail box is the pointer
 * to the vcpu to deschedule.
 *
 * %g1 = ptr to strand
 * %g2 = ptr to command mondo
 */
	ENTRY(deschedule_vcpu_cmd)
	add	%g2, HVM_ARGS, %g3
	ldx	[%g3 + HVM_SCHED_VCPUP], %g4
	HVCALL(deschedule_vcpu)
	ba,a,pt	%xcc, start_work
	SET_SIZE(deschedule_vcpu_cmd)


/*
 * %g4 - vcpup
 * Assumes running on localstrand to vcpu
 * NOTE: called from deschedule_vcpu_cmd and hcall_mach_exit
 */
	ENTRY(deschedule_vcpu)
	STRAND_STRUCT(%g1)
#if DEBUG /* { */
		/* validate arg; vcpup->strand == this strand */
	ldx	[%g4 + CPU_STRAND], %g5
	cmp	%g5, %g1
	beq,pt	%xcc, 1f
	  nop

	HVABORT(-1, "deschedule cpu - vcpu not scheduled on my strand")
1:
#endif /* } */

	ldub	[%g4 + CPU_STRAND_SLOT], %g5
#if DBG_DESCHEDULE /* { */
	mov	%g7, %g3		/* preserve return addr */
	PRINT("deschedule vcpu @ 0x")
	PRINTX(%g4)
	PRINT(" id = 0x")
	lduw	[%g4 + CPU_RES_ID], %g6
	PRINTX(%g6)
	PRINT(" vid = 0x")
	ldub	[%g4 + CPU_VID], %g6
	PRINTX(%g6)
	PRINT(" from slot 0x")
	PRINTX(%g5)
	PRINT("\r\n")
	mov	%g3, %g7		/* restore return addr */
#endif /* } */
	mulx	%g5, SCHED_SLOT_SIZE, %g3
	add	%g1, STRAND_SLOT, %g1
	add	%g1, %g3, %g3
	set	SLOT_ACTION_NOP, %g2
	stx	%g2, [%g3 + SCHED_SLOT_ACTION]
	mov	1, %g2	! force alignment trap
	stx	%g2, [%g3 + SCHED_SLOT_ARG]

	HVRET
	SET_SIZE(deschedule_vcpu)


/*
 * This operation terminates the execution of the specified vcpu.
 *
 * Our working assumption is that the currently
 * running vcpu state (if any) has been stashed back into
 * its vcpu structure, and so at the end of this operation
 * we bail back to start_work.
 *
 * The argument in the strand x-call mail box is the pointer
 * to the vcpu to deschedule.
 *
 * %g1 = ptr to strand
 * %g2 = ptr to command mondo
 */
	ENTRY(stop_vcpu_cmd)
	add	%g2, HVM_ARGS, %g3

	mov	%g1, %g2
	ldx	[%g3 + HVM_SCHED_VCPUP], %g1

	HVCALL(desched_n_stop_vcpu)

	/*
	 * We dont care about the current running state.
	 * It's over with. Just set the vcpu state and
	 * go and get more work.
	 */
	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl

	mov	1, %g1
	SET_VCPU_STRUCT(%g1, %g2)	/* force a alignment trap */

#if	DBG_STOP
	DEBUG_SPINLOCK_ENTER(%g1, %g2, %g3)
	PRINT("Back to work\r\n")
	DEBUG_SPINLOCK_EXIT(%g1)
#endif
	ba	start_work
	nop
	SET_SIZE(stop_vcpu_cmd)


/*
 * desched_n_stop_vcpu
 *
 * Removes a vcpu from the corresponding strand slot. It then
 * calls stop_vcpu to stop a virtual cpu an clear out associated
 * state.
 *
 * Expects:
 *	%g1 : vcpu pointer 
 *	%g2 : strand pointer 
 * Returns:
 *	%g1 : vcpu pointer
 * Register Usage:
 *	%g1..%g6
 *	%g7 return address
 */	
	ENTRY_NP(desched_n_stop_vcpu)

	STRAND_PUSH(%g7, %g3, %g4)		! save return address

	ldub	[%g1 + CPU_STRAND_SLOT], %g4
	mulx	%g4, SCHED_SLOT_SIZE, %g3
	add	%g2, STRAND_SLOT, %g5
	add	%g5, %g3, %g3
	set	SLOT_ACTION_NOP, %g2
	stx	%g2, [%g3 + SCHED_SLOT_ACTION]
	mov	1, %g2	! force alignment trap
	stx	%g2, [%g3 + SCHED_SLOT_ARG]

#ifdef CONFIG_CRYPTO
	/*
	 * Stop crypto
	 */
	VCPU2GUEST_STRUCT(%g1, %g2)	

	! %g1 = cpu struct
	! %g2 = guest struct
	!
	HVCALL(stop_crypto)
#endif /* CONFIG_CRYPTO */

	/*
	 * Clean up the (active) running state
	 */
	HVCALL(stop_vcpu)	

	! %g1 - vcpu
	! Default setup entry point for next time we start cpu
	! Strictly speaking we should not need to do this here since
	! there are only two ways a cpu can start from stopped
	! 1. as the boot cpu in which case we force the start address
	! 2. via a cpu_start API call in which case the start address
	!	is set there.

	ldx	[%g1 + CPU_RTBA], %g3
	inc	(TT_POR * TRAPTABLE_ENTRY_SIZE), %g3 ! Power-on-reset vector
	stx	%g3, [%g1 + CPU_START_PC]

	STRAND_POP(%g7, %g2)			! retrieve return address
	HVRET

	SET_SIZE(desched_n_stop_vcpu)


/*
 * c_desched_n_stop_vcpu
 *
 * C Wrapper around desched_n_stop_vcpu(). Deschedules and
 * stops the vcpu passed in as a parameter.
 *
 * Expects:
 *	%o0 : vcpu pointer
 * Returns:
 *	nothing
 */
	ENTRY(c_desched_n_stop_vcpu)
	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	mov	%o0, %g1
	VCPU2STRAND_STRUCT(%g1, %g2)
	HVCALL(desched_n_stop_vcpu)

	STRAND_POP(%g4, %g6)
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)

	retl
	nop
	SET_SIZE(c_desched_n_stop_vcpu)


/*
 * stop_guest_cmd
 *
 * Called from xcall context usually from the control domain
 * to exit a guest remotely. Assumes any running vcpu assigned
 * to this strand already had its state saved so we can clobber
 * all the registers.
 *
 * %g1 - pointer to the current strand
 * %g2 - HV xcall command mondo pointer
 */
	ENTRY(stop_guest_cmd)
	ldx	[%g2 + HVM_ARGS + HVM_STOPGUEST_GUESTP], %g2

	/*
	 * Save the guest parameter because all registers
	 * get clobbered when setting up the C environment.
	 */
	STRAND_PUSH(%g2, %g3, %g4)

	wrpr	%g0, 0, %gl
	wrpr	%g0, 0, %tl
	HVCALL(setup_c_environ)

	! retrieve the pointer to the guest to stop
	STRAND_POP(%o0, %g3)

	call	c_guest_exit
	mov	GUEST_EXIT_MACH_EXIT, %o1

	ba,pt	%xcc, start_work
	nop

	SET_SIZE(stop_guest_cmd)


	/*
	 * Configures a basic C compatible environment
	 * based on the current vcpu setup.
	 * The only working assumption here is that coming in
	 * the caller has already set gl and tl to 0, so we do not
	 * have to worry about preserving the parameters.
	 */
	ENTRY(setup_c_environ)
	wrpr	%g0, NWINDOWS-2, %cansave
	wrpr	%g0, NWINDOWS-1, %cleanwin
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %cwp
	wrpr	%g0, 0, %wstate
	wr	%g0, %y
	wrpr	%g0, 0xf, %pil

	! Other stuff here ... pstate, gis etc. FIXME

	! Setup up the C stack
	STRAND_STRUCT(%g1)
	set	STRAND_STACK, %g2
	add	%g1, %g2, %g1
	set	STRAND_STACK_SIZE - STACK_BIAS, %g2
	add	%g1, %g2, %g1

	mov	%g0, %i6
	mov	%g0, %i7
	mov	%g0, %o6
	mov	%g0, %o7
	add	%g1, -SA(MINFRAME), %sp
	HVRET
	SET_SIZE(setup_c_environ)


	ENTRY(c_puts)
	mov	%o0, %g1
	ba	puts
	rd	%pc, %g7
	retl
	nop
	SET_SIZE(c_puts)


	! basic compare and swap
	! %o0 = address of 32 bit value
	! %o1 = value to compare against
	! %o2 = value to store
	! - returns:
	! %o0 = value stored in location

	ENTRY(c_cas32)
	casa	[%o0]ASI_P, %o1, %o2
	retl
	mov	%o2, %o0
	SET_SIZE(c_cas32)


	! basic compare and swap
	! %o0 = address of 64 bit value
	! %o1 = value to compare against
	! %o2 = value to store
	! - returns:
	! %o0 = value stored in location

	ENTRY(c_cas64)
	casxa	[%o0]ASI_P, %o1, %o2
	retl
	mov	%o2, %o0
	SET_SIZE(c_cas64)


	! atomic swap ... compare and swap until we succeed.
	! %o0 = address of 64 bit value
	! %o1 = value to store
	! - returns:
	! %o0 = value stored in location

	ENTRY(c_atomic_swap64)
1:
	mov	%o1, %o3
	ldx	[%o0], %o2
	casxa	[%o0]ASI_P, %o2, %o3
	cmp	%o2, %o3
	bne,pn	%xcc, 1b
	nop
	retl
	mov	%o3, %o0
	SET_SIZE(c_atomic_swap64)


	! Returns a pointer to the strand_t struct
	! for the strand we are currently executing on
	! %o0 = strand struct
	ENTRY(c_mystrand)
	STRAND_STRUCT(%o0)
	retl
	nop
	SET_SIZE(c_mystrand)
