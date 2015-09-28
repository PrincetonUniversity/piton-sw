/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_common.s
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

#pragma ident	"@(#)errors_common.s	1.5	07/08/01 SMI"

#include <sys/asm_linkage.h>
#include <sun4v/asi.h>
#include <sun4v/traps.h>
#include <sun4v/queue.h>
#include <hypervisor.h>
#include <guest.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <cache.h>
#include <dram.h>
#include <ncu.h>

#include <cmp.h>
#include <abort.h>

#include <offsets.h>
#include <util.h>
#include <legion.h>
#include <errs_common.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_asm.h>

/*
 * Just a short note to document the error handling
 * implementation. Each error type has an error_table entry which
 * mandates how that error is corrected, reported, which guest
 * Queue is used (if any), etc. The trap handler for the error
 * uses the trap-specific array of error entries to identify the
 * individual error which has occurred, passing a table entry to the
 * generic error handler for processing. The error_handler
 * looks at the error_flags/error_functions encoded in the error_table
 * entry to determine how the error is to be dealt with,
 * yanking the error-specific functionality from the table and executing it.
 *
 * The processing is as follows :-
 *	1) Create sun4v guest report 
 *	2) Gather data for SP Diagnosis Engine
 *	3) Perform any error correction
 *	4) Set up storm handler if required
 *	5) Send diagnosis report to SP
 *	6) Queue guest error report
 *	7) Exit
 */


	/*
	 * This is the common entry point for all errors. The various
	 * trap handlers will have determined the error type, located
	 * the error_table_entry for that error and transferred control
	 * to here.
	 *
	 * %g1	&error_table_entry
	 */
	ENTRY(error_handler)

	/*
	 * First we store the address of the error_table-entry
	 * in cpu->cpu_err_table_entry[TL]
	 */
	SET_ERR_TABLE_ENTRY(%g1, %g2, %g3)

	/*
	 * Check if this error requires an immediate warm reset
	 */
	ld	[%g1 + ERR_FLAGS], %g4
	set	ERR_FORCE_SIR, %g3
	btst	%g3, %g4
	bz,pt	%xcc, error_handler_check_io_prot
	nop

	PRINT("Software Reset required after Fatal Error!\r\n")

	! reset the system, an SIR with %o0 = 1 is treated as a fatal reset
	mov	1, %o0
	sir	0

error_handler_check_io_prot:
	/*
	 * Check if this error occurred with strand error protection
	 * enabled. This is only enabled from inside the error handling
	 * code to facilitate checking for stuck-at errors, false error
	 * conditions, etc.
	 */
	STRAND_STRUCT(%g4)
	lduw    [%g4 + STRAND_ERR_FLAG], %g4
	set	STRAND_ERR_FLAG_PROTECTION, %g5
	btst	%g4, %g5 
	bnz,pn	%xcc, 1f
	nop

	/*
	 * If this error occurred during peek/poke operation with
	 * protection set we just complete the instruction. First
	 * check whether this error type supports I/O protection
	 */
	ld	[%g1 + ERR_FLAGS], %g4
	btst	ERR_IO_PROT, %g4
	bz,pn	%xcc, error_handler_sun4v_reporting	! no I/O protection
	nop

	STRAND_STRUCT(%g2)
	set	STRAND_IO_PROT, %g3
	ldx	[%g2 + %g3], %g3	! strand.io_prot
	brz	%g3, error_handler_sun4v_reporting  ! if zero, no error protection
	nop

	/*
	 * Error occurred under i/o error protection
	 * Set the i/o error flag in the strand structure and complete the
	 * instruction
	 */
1:
	STRAND_STRUCT(%g2)
	add	%g2, STRAND_IO_ERROR, %g2
	mov	1, %g3
	stx	%g3, [%g2]  		! strand.io_error = 1

	/*
	 * Do any required error correction
	 */
	ldx	[%g1 + ERR_CORRECT_FCN], %g3
	brz,pn	%g3, 1f
	nop

	HVJMP(%g3, %g7)

	HVCALL(clear_dram_l2c_esr_regs)

	GET_ERR_TABLE_ENTRY(%g1, %g2)
	ld	[%g1 + ERR_FLAGS], %g4
	set	ERR_CLEAR_AMB_ERRORS, %g2
	btst	%g2, %g4
	bz,pn	%xcc, 1f
	nop

	HVCALL(clear_amb_errors)
	GET_ERR_TABLE_ENTRY(%g1, %g2)
	ld	[%g1 + ERR_FLAGS], %g4
1:
	/*
	 * Does the trap handler for this error park the strands ?
	 * If yes, resume them here.
	 */
	btst	ERR_STRANDS_PARKED, %g4
	bz,pn	%xcc, 1f
	nop

	RESUME_ALL_STRANDS(%g2, %g3, %g5, %g6)
1:
	/*
	 * check whether we stored the globals and re-used
	 * at MAXPTL
	 */
	btst	ERR_GL_STORED, %g4
	bz,pt	%xcc, 1f
	nop

	RESTORE_GLOBALS(done)

1:
	/*
	 * All done ..... get out of here
	 */

	done				! complete the instruction

error_handler_sun4v_reporting:

#ifdef DEBUG
	PRINT_ERROR_TABLE_ENTRY()
	GET_ERR_TABLE_ENTRY(%g1, %g2)
#endif


	/*
	 * Do any required SUN4V guest error reporting
	 */
	ldub	[%g1 + ERR_SUN4V_RPRT_TYPE], %g3
	cmp	%g3, SUN4V_NO_REPORT
	be,pn	%xcc, error_handler_diag_reporting
	nop

	HVCALL(error_handler_sun4v_report)

	/*
	 * Must ensure that we get a sun4v report buffer
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz	%g2, error_handler_sun4v_reporting
	nop

	! Note: %g1 preserved across call

	/*
	 * Call the guest error_specific sun4v report function
	 * This function should be used for ASI report types to load
	 * the ASI/RA fields of the sun4v guest report
	 * PCI-E reports will fill in the DESC attributes
	 */
	ldx	[%g1 + ERR_GUEST_REPORT_FCN], %g3
	brz,pn	%g3, error_handler_diag_reporting
	nop

	HVJMP(%g3, %g7)

	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_diag_reporting:
	/*
	 * Do any required SP diagnosis error reporting
	 */
	ldx	[%g1 + ERR_REPORT_FCN], %g3
	brz,pn	%g3, error_handler_correction
	nop

	/*
	 * First set up the generic report
	 */
	HVCALL(error_handler_diag_report)
	GET_ERR_TABLE_ENTRY(%g1, %g2)

	/*
	 * call the error-specific reporting function
	 */
	ldx	[%g1 + ERR_REPORT_FCN], %g3
	HVJMP(%g3, %g7)

	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_correction:
	/*
	 * Do any required error correction
	 */
	ldx	[%g1 + ERR_CORRECT_FCN], %g3
	brz,pn	%g3, error_handler_amb_errors
	nop

	HVJMP(%g3, %g7)

	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_amb_errors:
	ld	[%g1 + ERR_FLAGS], %g4
	set	ERR_CLEAR_AMB_ERRORS, %g2
	btst	%g2, %g4
	bz,pn	%xcc, error_handler_storm
	nop

	HVCALL(clear_amb_errors)
	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_storm:
	/*
	 * If we need to set up any defences against error storms
	 * for this error type, do it now
	 */
	ldx	[%g1 + ERR_STORM_FCN], %g3
	brz,pn	%g3, error_handler_epilog
	nop

	HVJMP(%g3, %g7)

	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_epilog:

#ifdef DEBUG
	/*
	 * dump out Service Error Report (SER)
	 * and diag buf data
	 */
#ifdef DEBUG_LEGION	
	HVCALL(print_diag_ser)
	HVCALL(print_diag_buf)	
#endif
	GET_ERR_TABLE_ENTRY(%g1, %g2)

	/*
	 * The error-specific data now ...
	 */
	ldx	[%g1 + ERR_PRINT_FCN], %g3
	brz,pn	%g3, 1f
	nop

	HVJMP(%g3, %g7)

	GET_ERR_TABLE_ENTRY(%g1, %g2)
1:
#endif
	/*
	 * Does the trap handler for this error park the strands ?
	 * If yes, resume them here.
	 */
	ld	[%g1 + ERR_FLAGS], %g2
	btst	ERR_STRANDS_PARKED, %g2
	bz,pn	%xcc, 1f
	nop

	RESUME_ALL_STRANDS(%g2, %g4, %g5, %g6)
1:
	/*
	 * I have a vision of using an asynchronous cyclic
	 * to send the diagnostic reports to the SP. This cyclic
	 * will trigger and scan through all the err_diag_rprt's
	 * looking for ERR_RPRT_PENDING entries and send them off.
	 * This will cut down the time spent in the error
	 * handler.
	 *
	 * For the moment, this is just a dream, we will just call
	 * the report transmission directly.
	 */
	ldx	[%g1 + ERR_REPORT_FCN], %g3
	brz,pn	%g3, error_handler_resumable
	nop

	/*
	 * send the report to the SP
	 * send_diag_erpt() will clear the in_use flag
	 * %g1	err_diag_rprt	
	 * %g2  err_diag_rprt.err_diag.in_use
	 * %g3  sizeof(err_diag_rprt)
	 */
	GET_ERR_DIAG_BUF(%g1, %g5)
	add	%g1, ERR_DIAG_RPRT_IN_USE, %g2
	add	%g1, ERR_DIAG_RPRT_REPORT_SIZE, %g3
	lduw	[%g3], %g3
        HVCALL(send_diag_erpt)

	! Note: %g1 not preserved across call
	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_resumable:

	/*
	 * Check if this CPU has been marked bad, if so mark the
	 * corresponding strand in error
	 */
	VCPU_STRUCT(%g2)
	ldx	[%g2 + CPU_STATUS], %g2
	cmp	%g2, CPU_STATE_ERROR
	be,pn	%xcc, strand_in_error
	nop

	/*
	 * If this is a FATAL error we will abort the HV now.
	 * No report goes to the guest in this case
	 */
	ld	[%g1 + ERR_FLAGS], %g2
	btst	ERR_FATAL, %g2
	bnz,pn	%xcc, fatal_error
	nop

	/*
	 * For some L2$ errors, if the line was not dirty
	 * we can continue without terminating the guest
	 */
	ld	[%g1 + ERR_FLAGS], %g2
	btst	ERR_CHECK_LINE_STATE, %g2
	bz,pn	%xcc, 1f
	nop

	GET_ERR_DIAG_DATA_BUF(%g4, %g5)
	ldx	[%g4 + ERR_DIAG_L2_LINE_STATE], %g5
	cmp	%g5, L2_LINE_DIRTY
	bne	%xcc, error_handler_erpt_done
	nop
1:

	/*
	 * check if this is a non-resumable error
	 */
	ld	[%g1 + ERR_FLAGS], %g2
	btst	ERR_NON_RESUMABLE, %g2
	bnz,pn	%xcc, error_handler_non_resumable
	nop

	/*
	 * No report to guest if the error occurred in the hypervisor
	 */
	rdpr	%tl, %g2
	brz,pn	%g2, 1f
	nop

	rdhpr   %htstate, %g2
	btst    HTSTATE_HPRIV, %g2
	bnz     %xcc, error_handler_erpt_done
	nop

1:
	
	/*
	 * Send a resumable error report to the guest if
	 * required.
	 */
	ldub	[%g1 + ERR_SUN4V_RPRT_TYPE], %g2
	cmp	%g2, SUN4V_NO_REPORT
	be,pt	%xcc, error_handler_erpt_done
	nop

	/*
	 * If the ATTR field in the sun4v report has been set to
	 * zero, we do not want to send this report. This will have
	 * been done in the error handling code which populates the
	 * report when it is determined that the error occurred
	 * on some hyperprivileged register.
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g3, %g4)
	ld	[%g3 + ERR_SUN4V_RPRT_ATTR], %g4	! attr
	brz,pn	%g4, error_handler_erpt_done
	nop

	/* 
	 * Sun4v guest resumable error interrupt
	 */
#ifdef DEBUG
	PRINT_NOTRAP("queue resumable erpt\r\n");
	GET_ERR_TABLE_ENTRY(%g1, %g2)
#endif
	HVCALL(errors_queue_resumable_erpt)
	GET_ERR_TABLE_ENTRY(%g1, %g2)

error_handler_erpt_done:

	ld	[%g1 + ERR_FLAGS], %g2
	btst	ERR_ISSUE_DONE, %g2
	bnz,pn	%xcc, error_handler_done
	.empty

	/*
	 * fall through to RETRY
	 */

error_handler_retry:

	/*
	 * check whether we stored the globals and re-used
	 * at MAXPTL
	 */
	btst	ERR_GL_STORED, %g2
	bz,pt	%xcc, 1f
	nop

	RESTORE_GLOBALS(retry)
1:
	/*
	 * And back we go
	 */
	retry

error_handler_done:
	/*
	 * check whether we stored the globals and re-used
	 * at MAXPTL
	 */
	btst	ERR_GL_STORED, %g2
	bz,pt	%xcc, 1f
	nop

	RESTORE_GLOBALS(done)

1:
	/*
	 * All done ..... get out of here
	 */
	done

error_handler_non_resumable:
	PRINT_NOTRAP("error_handler_non_resumable\r\n");

	/*
	 * Abort if the error occurred in the hypervisor itself.
	 */
	rdhpr	%htstate, %g2
	btst	HTSTATE_HPRIV, %g2
	bnz	%xcc, hpriv_error
	nop

	/*
	 * queue a report on the non-resumable error queue
	 * and then jump to the guests non-resumable trap
	 * handler function
	 */
	ldub	[%g1 + ERR_SUN4V_RPRT_TYPE], %g2
	cmp	%g2, SUN4V_NO_REPORT
	be,pt	%xcc, abort_bad_guest_err_queue
	nop

	/*
	 * If the ATTR field in the sun4v report has been set to
	 * zero, we do not want to send this report. This will have
	 * been done in the error handling code which populates the
	 * report when it is determined that the error occurred
	 * on some hyperprivileged register.
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g3, %g4)
	ld	[%g3 + ERR_SUN4V_RPRT_ATTR], %g4	! attr
	brz,pn	%g4, hpriv_error
	nop

	ba	nonresumable_guest_trap
	.empty

	SET_SIZE(error_handler)

	/*
	 * allocate a SUN4V report and fill it in.
	 * %g1	&error_table_entry	(preserved)
	 * %g3	Sun4v report attribute
	 * %g7	return address
	 */
	ENTRY(error_handler_sun4v_report)

	/*
	 * Go through the array of err_sun4v_rprt looking
	 * for in_use = 0.
	 */
	setx	err_sun4v_rprt, %g2, %g4
	RELOC_OFFSET(%g2, %g5)
	sub	%g4, %g5, %g4
	add	%g4, ERR_SUN4V_RPRT_IN_USE, %g4
	mov	MAX_ERROR_REPORT_BUFS, %g5
1:
	ldstub	[%g4], %g6			! in_use
	brz,a,pt	%g6, 2f
	  sub	%g4, ERR_SUN4V_RPRT_IN_USE, %g4	! back to &err_sunv_rprt

	/*
	 * This err-sun4v_rprt is in use, go again
	 */
	dec	%g5
	brz,a,pn	%g5, error_handler_sun4v_report_exit
	  clr	%g4				! no buf available
	ba	1b				! try next buffer
	add	%g4, ERR_SUN4V_RPRT_SIZE, %g4

2:
	brz,pn	%g4, error_handler_sun4v_report_exit
	.empty

	/*
	 * First we store the address of the err_sun4v_rprt
	 * in strand->strand_sun4v_rprt_buf[TL]
	 */
	STRAND_STRUCT(%g2)
	rdpr	%tl, %g5
	dec	%g5
	mulx	%g5, STRAND_SUN4V_RPRT_BUF_INCR, %g5
	add	%g5, STRAND_SUN4V_RPRT_BUF, %g5
	stx	%g4, [%g2 + %g5]

	/*
	 * PCI-E or sun4v error report ?
	 */
	cmp	%g3, SUN4V_PCIE_RPRT
	be,pn	%xcc, error_handler_sun4v_pcie_report
	nop

	/*
	 * Attr field in error table entry is the bit position, need to shift
	 * it to the actual value now.
	 */
	mov	1, %g5
	sllx	%g5, %g3, %g3

	/*
	 * Fill in the sun4v guest report 
	 */
	! error_table_entry->err_sun4v_edesc
	ldub	[%g1 + ERR_SUN4V_EDESC], %g5
	srl	%g5, EDESC_TYPE_SHIFT, %g5
	and	%g5, EDESC_TYPE_MASK, %g5
	st	%g5, [%g4 + ERR_SUN4V_RPRT_EDESC]
	! strand->strand-id
	ldub	[%g2 + STRAND_ID], %g5
	stuh	%g5, [%g4 + ERR_SUN4V_RPRT_G_CPUID]
	GENERATE_EHDL(%g6, %g5)
	stx	%g6, [%g4 + ERR_SUN4V_RPRT_G_EHDL]
	GET_ERR_STICK(%g5)
	stx	%g5, [%g4 + ERR_SUN4V_RPRT_G_STICK]

	/*
	 * Set the MODE, bits [25:24] of the ATTR field
	 */
	rdpr	%tstate, %g5
	srlx	%g5, TSTATE_PSTATE_SHIFT, %g5
	and	%g5, PSTATE_PRIV, %g5
	movrz	%g5, ATTR_USER_MODE, %g6	! PSTATE.PRIV == 0, User mode
	movrnz	%g5, ATTR_PRIV_MODE, %g6	! PSTATE.PRIV != 0, Privileged mode
	sllx	%g6, ATTR_MODE_SHIFT, %g6
	or	%g3, %g6, %g3			! %g3 ATTR, %g6 MODE

	st	%g3, [%g4 + ERR_SUN4V_RPRT_ATTR]

	/*
	 * The error-specific data will be filled in later.
	 */
	setx	CPU_ERR_INVALID_RA, %g3, %g5
	stx	%g5, [%g4 + ERR_SUN4V_RPRT_ADDR]
	st	%g0, [%g4 + ERR_SUN4V_RPRT_SZ]
	stub	%g0, [%g4 + ERR_SUN4V_RPRT_ASI]
	ba	error_handler_sun4v_report_exit
	nop

error_handler_sun4v_pcie_report:
	GENERATE_EHDL(%g6, %g5)
	stx	%g6, [%g4 + ERR_SUN4V_PCIE_EHDL]
	GET_ERR_STICK(%g5)
	stx	%g5, [%g4 + ERR_SUN4V_PCIE_STICK]
	stx	%g0, [%g4 + ERR_SUN4V_PCIE_SYSINO]
	st	%g0, [%g4 + ERR_SUN4V_PCIE_DESC]
	st	%g0, [%g4 + ERR_SUN4V_PCIE_SPECIFIC]
	stx	%g0, [%g4 + ERR_SUN4V_PCIE_WORD4]
	stx	%g0, [%g4 + ERR_SUN4V_PCIE_HDR1]
	stx	%g0, [%g4 + ERR_SUN4V_PCIE_HDR2]

error_handler_sun4v_report_exit:

	HVRET
	
	SET_SIZE(error_handler_sun4v_report)

	/*
	 * allocate a DIAG report buffer
	 * fill in common data
	 *
	 * %g1	&error_table_entry (preserved)
	 * %g7	return address
	 */
	ENTRY(error_handler_diag_report)

	/*
	 * Go through the array of err_diag_rprt looking
	 * for in_use = 0.
	 */
	setx	err_diag_rprt, %g2, %g4
	RELOC_OFFSET(%g2, %g5)
	sub	%g4, %g5, %g4
	add	%g4, ERR_DIAG_RPRT_IN_USE, %g4
	mov	MAX_ERROR_REPORT_BUFS, %g5
	setx	ERR_DIAG_RPRT_SIZE, %g3, %g6
1:
	/*
	 * The in_use flag is a 32-bit int to maintain compatibility
	 * with svc_internal_send(). We use only the bottom eight
	 * bits, hence the '+ 3'.
	 */
	ldstub	[%g4 + 3], %g2			! in_use
	brz,a,pt	%g2, 2f			! REPORT_BUF_FREE
	  sub	%g4, ERR_DIAG_RPRT_IN_USE, %g4	! back to &err_diag_rprt

	/*
	 * This err_diag_rprt is in use, go again
	 */
	dec	%g5
	brz,a,pn	%g5, error_handler_diag_report_exit
	  clr	%g4				! no buf available

	ba	1b				! try next buffer
	add	%g4, %g6, %g4

2:
	brz,pn	%g4, error_handler_diag_report_exit
	.empty

	/*
	 * First we store the address of the err_diag_rprt
	 * in strand->strand_err_diag_buf[TL]
	 */
	STRAND_STRUCT(%g2)
	rdpr	%tl, %g3
	dec	%g3
	mulx	%g3, STRAND_DIAG_BUF_INCR, %g5
	add	%g5, STRAND_DIAG_BUF, %g5
	stx	%g4, [%g2 + %g5]

	add	%g4, ERR_DIAG_RPRT_IN_USE, %g3
	mov	REPORT_BUF_PENDING, %g5
	st	%g5, [%g3]

	/*
	 * Fill in the generic SP diagnosis report  data
	 * If we already have an EHDL in the Sun4v report just get
	 * that sequence number
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g5, %g3)
	brz,pt	%g5, 1f
	nop

	ldub	[%g1 + ERR_SUN4V_RPRT_TYPE], %g3
	cmp	%g3, SUN4V_PCIE_RPRT
	mov	ERR_SUN4V_PCIE_EHDL, %g3
	movne	%xcc, ERR_SUN4V_RPRT_G_EHDL, %g3	
	ldx	[%g5 + %g3], %g5
	ba	2f
	nop

1:
	/*
	 * generate a new strand sequence number
	 */
	GENERATE_EHDL(%g5, %g3)
2:
	stx	%g5, [%g4 + ERR_DIAG_RPRT_EHDL]
	mov	ERPT_TYPE_CPU, %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_ERROR_TYPE]
	CONFIG_STRUCT(%g5)
	ldx	[%g5 + CONFIG_TOD], %g5
	brnz,a,pn	%g5, 1f
	  ldx	[%g5], %g5		! aborted if no TOD
1:
        stx     %g5, [%g4 + ERR_DIAG_RPRT_TOD]
	! error report type from error_table entry
	ldub	[%g1 + ERR_SUN4V_EDESC], %g5
	srl	%g5, SER_TYPE_SHIFT, %g5
	and	%g5, SER_TYPE_MASK, %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_REPORT_TYPE]
	! error report size from error_table entry
	lduw	[%g1 + ERR_REPORT_SIZE], %g5
	stuw	%g5, [%g4 + ERR_DIAG_RPRT_REPORT_SIZE]
	GET_ERR_STICK(%g5)
        stx     %g5, [%g4 + ERR_DIAG_RPRT_ERR_STICK]
	rdhpr   %hver, %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_CPUVER]
	setx    NCU_BASE + PROC_SER_NUM, %g5, %g3
	ldx	[%g3], %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_SERIAL]
	ldub	[%g2 + STRAND_ID], %g5
	stuh	%g5, [%g4 + ERR_DIAG_RPRT_CPUID]
	rdpr	%tl, %g5
	stub	%g5, [%g4 + ERR_DIAG_RPRT_TL]
	rdpr	%tt, %g5
	stuh	%g5, [%g4 + ERR_DIAG_RPRT_TT]
	rdpr	%tstate, %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_TSTATE]
	rdhpr	%htstate, %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_HTSTATE]
	rdpr	%tpc, %g5
	stx	%g5, [%g4 + ERR_DIAG_RPRT_TPC]

	/*
	 * Clear the diag_buf ESRs, up to the in_use flag
	 */
	add	%g4, ERR_DIAG_RPRT_ERR_DIAG, %g4

	STRAND_PUSH(%g7, %g1, %g2)
	mov	%g4, %g1
	mov	ERR_DIAG_BUF_RPRT_IN_USE, %g2
	HVCALL(bzero)
	STRAND_POP(%g7, %g1)

	/*
	 * store the DESR
	 */
	GET_ERR_DESR(%g2, %g3)
	stx     %g2, [%g4 + ERR_DIAG_BUF_SPARC_DESR]

	/*
	 * store the DFESR
	 */
	GET_ERR_DFESR(%g2, %g3)
	stx     %g2, [%g4 + ERR_DIAG_BUF_SPARC_DFESR]

	/*
	 * store the D-SFSR/I-SFSR/D-SFAR
	 */
	GET_ERR_DSFSR(%g3, %g5)
	stx     %g3, [%g4 + ERR_DIAG_BUF_SPARC_DSFSR]
	GET_ERR_DSFAR(%g3, %g5)
	stx     %g3, [%g4 + ERR_DIAG_BUF_SPARC_DSFAR]
	GET_ERR_ISFSR(%g3, %g5)
	stx     %g3, [%g4 + ERR_DIAG_BUF_SPARC_ISFSR]

error_handler_diag_report_exit:

	HVRET
	SET_SIZE(error_handler_diag_report)

	/*
	 * Send an error report for diagnosis to the SP
	 *
	 * %g1 - %g6 clobbered
	 * %g7	return address
	 */
	ENTRY(transmit_diag_reports)

	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)

	/*
	 * Go through the array of err_diag_rprt looking
	 * for in_use = REPORT_BUF_PENDING.
	 */
transmit_diag_reports_start:

	setx	err_diag_rprt, %g2, %g4
	RELOC_OFFSET(%g2, %g5)
	sub	%g4, %g5, %g4
	add	%g4, ERR_DIAG_RPRT_IN_USE, %g4
	mov	MAX_ERROR_REPORT_BUFS, %g5
	setx	ERR_DIAG_RPRT_SIZE, %g2, %g6
1:
	/*
	 * The in_use flag is a 32-bit int to maintain compatibility
	 * with svc_internal_send(). We use only the bottom eight
	 * bits, hence the '+ 3'.
	 */
	ldub	[%g4 + 3], %g2			! in_use
	cmp	%g2, REPORT_BUF_IN_USE
	be,a,pt	%xcc, 2f
	  sub	%g4, ERR_DIAG_RPRT_IN_USE, %g4	! back to &err_diag_rprt

	/*
	 * This err_diag_rprt is not ready to be sent to the
	 * SP, go again
	 */
	dec	%g5
	brz,a,pn	%g5, transmit_diag_piu_reports
	  clr	%g4				! no buf available
	ba	1b				! try next buffer
	add	%g4, %g6, %g4

2:
	/*
	 * send the report to the SP
	 * send_diag_erpt() will clear the in_use flag
	 * %g4	diag_buf
	 */
	mov     %g4, %g1
	add	%g1, ERR_DIAG_RPRT_IN_USE, %g2
	add	%g1, ERR_DIAG_RPRT_REPORT_SIZE, %g3
	lduw	[%g3], %g3
        HVCALL(send_diag_erpt_nolock)

	ba	transmit_diag_reports_exit
	nop

transmit_diag_piu_reports:
#ifdef CONFIG_PIU
	/*
	 * Check whether any PIU error reports are waiting to be transmitted
	 */
	setx	piu_dev, %g2, %g4
	RELOC_OFFSET(%g2, %g5)
	sub	%g4, %g5, %g4
	set	NPIUS, %g5
.check_next_piu_dev:
	! each piu_dev has two error reports, DMU and PEU
	! check the 'unsent' flag on each
	! %g4	piu_dev[]
	add	%g4, PIU_COOKIE_DMU_ERPT, %g1
	ldsw	[%g1 + PCI_UNSENT_PKT], %g2
	brnz,pn %g2, .transmit_piu_dev_err
	nop
	add	%g4, PIU_COOKIE_PEU_ERPT, %g1
	ldsw	[%g1 + PCI_UNSENT_PKT], %g2
	brnz,pn %g2, .transmit_piu_dev_err
	dec	%g5
	brnz,pt	%g5, .check_next_piu_dev
	add	%g4, PIU_COOKIE_SIZE, %g4

	! nothing to send
	ba	transmit_diag_reports_exit
	nop

.transmit_piu_dev_err:
	! PIU error ready to go
	! %g1	PIU error report
	add	%g1, PCI_UNSENT_PKT, %g2
	add	%g1, PCI_ERPT_U, %g1
	mov     PCIERPT_SIZE - EPKTSIZE, %g3
	HVCALL(send_diag_erpt_nolock)

#endif	/* CONFIG_PIU */

transmit_diag_reports_exit:

	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET

	SET_SIZE(transmit_diag_reports)

	/*
	 * Jump to the nonresumable_error trap of the privileged code.
	 * Select trap table entry based on TL.
	 */
	ENTRY(nonresumable_guest_trap)

	PRINT_NOTRAP("nonresumable_guest_trap\r\n");
	/*
	 * Put the sun4v ereport onto the non-resumable queue for this
	 * guest
	 *
	 * Note that both precise and deferred non-resumable error
	 * reports will be queued on the guests non-resumable error
	 * queue here.
	 *
	 * Note: We don't care about saving our return address (%g7)
	 *	 here because we are not getting out of here alive.
	 */
	HVCALL(errors_queue_nonresumable_erpt)

	VCPU_STRUCT(%g1) 
	IS_CPU_IN_ERROR(%g1, %g2)
	bne     %xcc, 1f
	nop

	! Mark the corresponding strand in error
	HVCALL(strand_in_error)
1:
	/*
	 * Jump to the nonresumable_error trap of the privileged code.
	 * Select trap table entry based on TL.
	 * Set TT for the guest
	 */
	wrpr    %g0, TT_NONRESUMABLE_ERR, %tt

	/*
	 * ensure that the guest is not entered in an illegal state
	 */
	GET_ERR_GL(%g1)
	cmp	%g1, MAXPGL
	bgu,pn  %xcc, watchdog_guest
	rdpr	%tl, %g1
	cmp	%g1, MAXPTL
	bgu,pn  %xcc, watchdog_guest
	.empty

	/*
	 * Build TSTATE from current state for the trap to the
	 * guests non_resumable_error trap table entry.
	 */
	rdhpr	%hpstate, %g3
	mov	PSTATE_PRIV, %g1
	sllx	%g1, TSTATE_PSTATE_SHIFT, %g4 

	GET_ERR_CWP(%g1)
	sllx	%g1, TSTATE_CWP_SHIFT, %g1 
	or	%g4, %g1, %g4 
	rdpr	%tstate, %g1 
	srlx	%g1, TSTATE_ASI_SHIFT, %g1
	and	%g1, TSTATE_ASI_MASK, %g1
	sllx	%g1, TSTATE_ASI_SHIFT, %g1 
	or	%g4, %g1, %g4 
	rd 	%ccr, %g1 
	sllx	%g1, TSTATE_CCR_SHIFT, %g1 
	or	%g4, %g1, %g4 
	GET_ERR_GL(%g1)
	sllx	%g1, TSTATE_GL_SHIFT, %g1 
	or	%g4, %g1, %g4 
	rdpr	%tba, %g1
	or	%g1, (TT_NONRESUMABLE_ERR << TT_OFFSET_SHIFT), %g1
	rdpr	%tl, %g2
	cmp	%g2, 1
	be,pt	%xcc, 2f                ! if TL - 1 == 0, go to 2
	set	TRAPTABLE_SIZE, %g5     ! set TL bit in trap address
	add	%g5, %g1, %g1           ! add TL for TL > 1
2:
	/*
	 * Cache the err_flags before incrementing TL as
	 * the GET_ERR_TABLE_ENTRY() macro uses TL to find the
	 * error_table entry for this error
	 */
	GET_ERR_TABLE_ENTRY(%g5, %g6)
	ld	[%g5 + ERR_FLAGS], %g5

	! %g1  trap_table address 
	! %g2  TL 
	! %g4  TSTATE 
	! %g5	error_table->err_flags
	inc	%g2 
	wrpr	%g2, %tl 
	wrpr	%g0, TT_NONRESUMABLE_ERR, %tt 
	wrpr	%g1, %tpc 
	add	%g1, 4, %g1 
	wrpr	%g1, %tnpc 
	wrpr	%g4, %tstate 
	wrhpr	%g0, HPSTATE_GUEST, %htstate 

	/* 
	 * After RETRY we will have :- 
	 * %pc          guest non_resumable_error trap table entry 
	 * %npc         guest non_resumable_error trap table entry + 4   
	 * %gl          Current GL which error handler is running at 
	 * %tl          Current TL which error handler is running at 
	 * %tt          TT_NONRESUMABLE_ERR
	 * %tpc         PC of UE precise error trap 
	 */ 

	btst	ERR_GL_STORED, %g5
	bz,pt	%xcc, 1f
	nop

	RESTORE_GLOBALS(retry)

1:
	retry

	SET_SIZE(nonresumable_guest_trap)

	/*
	 * Queue a resumable error report on this CPU
	 *
	 * %g1	&error_table_entry
	 * %g2	sun4v report type
	 * %g7	return address
	 */
	ENTRY_NP(errors_queue_resumable_erpt)

	/*
	 * Before we send a report to the guest, we must make ensure that the
	 * error actually occurred on hardware resources owned by the guest and
	 * that the error trap was not simply steered to a CPU owned by the guest.
	 */
	STRAND_PUSH(%g7, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	STRAND_PUSH(%g1, %g3, %g4)
	HVCALL(errors_check_steering)
	STRAND_POP(%g1, %g3)
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g7, %g3)

	cmp	%g2, SUN4V_PCIE_RPRT
	bne,pt	%xcc, 1f
	nop

	/*
	 * PCI-E error interrupt
	 */
	ba	queue_pcie_erpt
	nop
1:
	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g4)
	add	%g2, ERR_SUN4V_CPU_ERPT, %g2
	HVCALL(queue_resumable_erpt)
	ba	errors_queue_resumable_erpt_done
	nop

queue_pcie_erpt:
	/*
	 * insert a dev_mondo using the PCI-E error packet
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)
	GET_ERR_SUN4V_RPRT_BUF(%g1, %g4)
	add	%g1, ERR_SUN4V_PCIE_ERPT, %g1
	HVCALL(insert_device_mondo_p)

errors_queue_resumable_erpt_done:
	/*
	 * Clear the in_use bit on the sun4v report buffer
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g3, %g4)
	stub	%g0, [%g3 + ERR_SUN4V_RPRT_IN_USE]
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET

	SET_SIZE(errors_queue_resumable_erpt)


	/*
	 * Queue a nonresumable error report on this CPU
	 *
	 * If there is no free entry in the nonresumable error queue
	 * print a message and abort the guest.
	 */
	ENTRY_NP(errors_queue_nonresumable_erpt)

	/*
	 * Before we send a report to the guest, we must make ensure that the
	 * error actually occurred on hardware resources owned by the guest and
	 * that the error trap was not simply steered to a CPU owned by the guest.
	 */
	STRAND_PUSH(%g7, %g3, %g4)
	HVCALL(errors_check_steering)
	STRAND_POP(%g7, %g3)

	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g4)

	/*
	 * If this is a MEM report, set the SZ field here.
	 */
	ld	[%g2 + ERR_SUN4V_RPRT_ATTR], %g4	! attr
	mov	1, %g3
	sllx	%g3, SUN4V_MEM_RPRT, %g3
	and	%g4, %g3, %g4
	brz,pt	%g4, 1f
	mov	ERPT_MEM_SIZE, %g4
	st	%g4, [%g4 + ERR_SUN4V_RPRT_SZ]
1:

	add	%g2, ERR_SUN4V_CPU_ERPT, %g2
	HVCALL(queue_nonresumable_erpt)

#ifdef DEBUG_LEGION
        /*
         * print sun4v erpt data to console
	 */
	HVCALL(print_sun4v_erpt)
#endif	

	/*
	 * Clear the in_use bit on the sun4v report buffer
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g4)
	stub	%g0, [%g2 + ERR_SUN4V_RPRT_IN_USE]
	GET_ERR_RETURN_ADDR(%g7, %g2)

	HVRET
	SET_SIZE(errors_queue_nonresumable_erpt)


	/*
	 * %g2	sun4v error report
	 * %g7	return address
	 * Returns
	 * %g1	0 - success; 1 - failure
	 */
	ENTRY(queue_resumable_erpt)
	VCPU_STRUCT(%g1)

	ldx	[%g1 + CPU_ERRQR_BASE_RA], %g3		! get q base RA
	brnz	%g3, 1f			! if base RA is zero, skip
	nop
	! The resumable error queue is not allocated/initialized
	! simply return. No guest is there to receive it.
queue_resumable_erpt_full:
	mov	1, %g1					! failed to queue
	HVRET

1:
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	ldxa	[%g3]ASI_QUEUE, %g5		! %g5 = rq_tail
	add	%g5, Q_EL_SIZE, %g6		! %g6 = rq_next = rq_tail++
	ldx	[%g1 + CPU_ERRQR_MASK], %g4
	and	%g6, %g4, %g6			! %g6 = rq_next mod
	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g3
	ldxa	[%g3] ASI_QUEUE, %g4		! %g4 = rq_head
	cmp	%g6, %g4			! head = ++tail?
	be	%xcc, queue_resumable_erpt_full
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	stxa	%g6, [%g3] ASI_QUEUE		! new tail = rq_next
	! write up the queue record
	! %g2	sun4v ereport buf
	ldx	[%g1 + CPU_ERRQR_BASE], %g4
	add	%g5, %g4, %g3			! %g3 = base + tail
	ldx	[%g2 + CPU_SUN4V_RPRT_G_EHDL], %g4	! ehdl
	stx	%g4, [%g3 + SUN4V_EHDL_OFFSET]
	ldx	[%g2 + CPU_SUN4V_RPRT_G_STICK], %g4	! stick
	stx	%g4, [%g3 + SUN4V_TICK_OFFSET]
	ld	[%g2 + CPU_SUN4V_RPRT_EDESC], %g4	! edesc
	st	%g4, [%g3 + SUN4V_DESC_OFFSET]
	ld	[%g2 + CPU_SUN4V_RPRT_ATTR], %g4	! attr
	st	%g4, [%g3 + SUN4V_ATTR_OFFSET]
	ldx	[%g2 + CPU_SUN4V_RPRT_ADDR], %g4	! addr
	stx	%g4, [%g3 + SUN4V_ADDR_OFFSET]
	ld	[%g2 + CPU_SUN4V_RPRT_SZ], %g4		! sz
	st	%g4, [%g3 + SUN4V_SZ_OFFSET]
	lduh	[%g2 + CPU_SUN4V_RPRT_G_CPUID], %g4	! cpuid
	stuh	%g4, [%g3 + SUN4V_CPUID_OFFSET]
	lduh	[%g2 + CPU_SUN4V_RPRT_G_SECS], %g4
	stuh	%g4, [%g3 + SUN4V_SECS_OFFSET]		! secs
	ldub	[%g2 + CPU_SUN4V_RPRT_ASI], %g4
	stub	%g4, [%g3 + SUN4V_ASI_OFFSET]		! asi/pad
	lduh	[%g2 + CPU_SUN4V_RPRT_REG], %g4
	stuh	%g4, [%g3 + SUN4V_REG_OFFSET]		! reg
	st	%g0, [%g3 + SUN4V_PAD0_OFFSET]
	stx	%g0, [%g3 + SUN4V_PAD1_OFFSET]		
	stx	%g0, [%g3 + SUN4V_PAD2_OFFSET]		

	clr	%g1					! success
	HVRET

	SET_SIZE(queue_resumable_erpt)


	/*
	 * %g2	sun4v error report
	 * %g7	return address
	 * Returns
	 * %g1	0 - success; 1 - failure
	 */
	ENTRY_NP(queue_nonresumable_erpt)

	! %g1 vcpup
	VCPU_STRUCT(%g1)
	! Get the guest structure this vcpu belongs
	VCPU2GUEST_STRUCT(%g1, %g5)

	! Determine the guest state
	lduw    [%g5 + GUEST_STATE], %g4
	set     GUEST_STATE_SUSPENDED, %g3
	cmp     %g4, %g3
	be,pn   %xcc, .check_vcpu_queues
	set     GUEST_STATE_NORMAL, %g3
	cmp     %g4, %g3
	be,pn   %xcc, .check_vcpu_queues
	set     GUEST_STATE_EXITING, %g3
	cmp     %g4, %g3
	be,pn   %xcc, .drop_nrq_pkt
	set     GUEST_STATE_STOPPED, %g3
	cmp     %g4, %g3
	be,pn   %xcc, .drop_nrq_pkt
	set     GUEST_STATE_UNCONFIGURED, %g3
	cmp     %g4, %g3
	be,pn   %xcc, .drop_nrq_pkt
	nop

.check_vcpu_queues:
	ldx	[%g1 + CPU_ERRQNR_BASE_RA], %g3		! get q base RA
	brz	%g3, abort_missing_guest_err_queue ! if base RA zero, abort
	nop

	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	ldxa	[%g3]ASI_QUEUE, %g5		! %g5 = rq_tail
	add	%g5, Q_EL_SIZE, %g6		! %g6 = rq_next = rq_tail++
	ldx	[%g1 + CPU_ERRQNR_MASK], %g4
	and	%g6, %g4, %g6			! %g6 = rq_next mod
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g3
	ldxa	[%g3] ASI_QUEUE, %g4		! %g4 = rq_head
	cmp	%g6, %g4			! head = ++tail?
	be	%xcc, abort_bad_guest_err_queue
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	stxa	%g6, [%g3] ASI_QUEUE		! new tail = rq_next
	! write up the queue record
	! %g2	sun4v ereport buf
	ldx	[%g1 + CPU_ERRQNR_BASE], %g4
	add	%g5, %g4, %g3			! %g3 = base + tail
	ldx	[%g2 + ERR_SUN4V_RPRT_G_EHDL], %g4	! ehdl
	stx	%g4, [%g3 + SUN4V_EHDL_OFFSET]
	ldx	[%g2 + ERR_SUN4V_RPRT_G_STICK], %g4	! stick
	stx	%g4, [%g3 + SUN4V_TICK_OFFSET]
	ld	[%g2 + ERR_SUN4V_RPRT_EDESC], %g4	! edesc
	st	%g4, [%g3 + SUN4V_DESC_OFFSET]
	ld	[%g2 + ERR_SUN4V_RPRT_ATTR], %g4	! attr
	st	%g4, [%g3 + SUN4V_ATTR_OFFSET]
	ldx	[%g2 + ERR_SUN4V_RPRT_ADDR], %g4	! addr
	stx	%g4, [%g3 + SUN4V_ADDR_OFFSET]
	ld	[%g2 + ERR_SUN4V_RPRT_SZ], %g4		! sz
	st	%g4, [%g3 + SUN4V_SZ_OFFSET]
	lduh	[%g2 + ERR_SUN4V_RPRT_G_CPUID], %g4	! cpuid
	stuh	%g4, [%g3 + SUN4V_CPUID_OFFSET]
	lduh	[%g2 + ERR_SUN4V_RPRT_G_SECS], %g4
	stuh	%g4, [%g3 + SUN4V_SECS_OFFSET]		! secs
	lduh	[%g2 + ERR_SUN4V_RPRT_ASI], %g4
	stuh	%g4, [%g3 + SUN4V_ASI_OFFSET]		! asi/pad
	lduh	[%g2 + ERR_SUN4V_RPRT_REG], %g4
	stuh	%g4, [%g3 + SUN4V_REG_OFFSET]		! reg
	st	%g0, [%g3 + SUN4V_PAD0_OFFSET]
	stx	%g0, [%g3 + SUN4V_PAD1_OFFSET]
	stx	%g0, [%g3 + SUN4V_PAD2_OFFSET]

	clr	%g1					! success
	HVRET

.drop_nrq_pkt:
	/*
	 * The guest is not in the proper state to receive pkts
	 * Drop packet by just returning
	 */
#ifdef DEBUG
	mov     %g7, %g6
	PRINT("no guest to deliver NR error pkt. Dropping it\r\n")
	mov     %g6, %g7
#endif
	mov	1, %g1					! failed to queue
	HVRET

	/*
	 * The nonresumable error queue is full.
	 * Reset the guest
	 */
abort_bad_guest_err_queue:
#ifdef DEBUG
	mov     %g7, %g6
	PRINT("queue_nonresumable_erpt: nrq full - exiting guest\r\n")
	mov     %g6, %g7
#endif
	SET_CPU_IN_ERROR(%g1, %g2)
	ba	queue_resumable_erpt
	nop

abort_missing_guest_err_queue:
#ifdef DEBUG
	mov     %g7, %g6
	PRINT("queue_nonresumable_erpt: q missing - exiting guest\r\n")
	mov     %g6, %g7
#endif
	mov	1, %g1					! failed to queue
	HVRET

	SET_SIZE(queue_nonresumable_erpt)


/*
 * Uncorrectable error in HV
 *
 * Note that the diagnosis report should have been sent to the
 * SP already
 */
hpriv_error:
#ifdef	DEBUG
	PRINT("ABORT ON HV UE!\r\n");
#endif
	HPRIV_ERROR()

fatal_error:
#ifdef	DEBUG
	PRINT("ABORT ON FATAL ERROR!\r\n");
#endif
	FATAL_ERROR()

hvabort_exit:

	/*
	 * make sure any outstanding error reports get sent
	 */
	HVCALL(transmit_diag_reports)

#ifdef CONFIG_VBSC_SVC
	HV_PRINT_NOTRAP(", contacting vbsc\r\n");
	ba,pt   %xcc, vbsc_hv_abort
	  rd	%pc, %g1
#else
	HV_PRINT_NOTRAP(", spinning\r\n");
	LEGION_EXIT(1)
2:	ba,a    2b
	  nop
#endif
