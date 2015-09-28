/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cyclic.s
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
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)cyclic.s	1.9	07/03/23 SMI"

	.file	"cyclic.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <asi.h>
#include <hprivregs.h>
#include <sun4v/asi.h>
#include <offsets.h>
#include <cyclic.h>
#include <util.h>


	/*
	 * Function: cyclic_add_rel & cyclic_add_abs
	 *
	 * These functions register a handler to be called at a time
	 * specified by relative or absolute ticks.
	 *
	 * The maximum real time for the counter depends on the core frequency.
	 * Assuming a 1.0 GHz tick, the rollover will occur in ~292 yrs.
	 * Since this opens the door for unrealistic timeout values, we shall,
	 * by default, limit the input delta to a more realistic value. This
	 * value, in days, is set by default to one year plus one day (367).
	 * It is then converted to system ticks in the function start_master.
	 *
	 * A handler is automatically removed from the queue when the
	 * interrupt is serviced.
	 *
	 * Input Arguments:
	 *   %g1: tick time (relative or absolute)
	 *   %g2: handler address
	 *   %g3: handler arg0
	 *   %g4: handler arg1
	 *   %g5: scratch
	 *
	 * Return:
	 *   %g1: status (0=success, 1=full)
	 *
	 * Function: cyclic_add_rel
	 *
	 * This entry registers a handler to be called after a delay
	 * specified in ticks.
	 */
	ENTRY_NP(cyclic_add_rel)
	rd	STICK, %g5			! current time
	add	%g1, %g5, %g1			!   + delta = abs time
	/* Fall thru into cyclic_add_abs() */


	/*
	 * Function: cyclic_add_abs
	 *
	 * This entry  registers a handler to be called at a time
	 * specified in ticks.
	 */
	ENTRY_NP(cyclic_add_abs)
	/* Fall thru into cyclic_add() core function*/


	/* This is the core function cyclic_add() */
	STRAND_STRUCT(%g6)
	stx	%g2, [%g6 + STRAND_CY_HANDLER]	! save handler address
	stx	%g3, [%g6 + STRAND_CY_ARG0]	! save handler args
	stx	%g4, [%g6 + STRAND_CY_ARG1]	! save handler args

	/*
	 * Check if array full:
	 */
	ldx	[%g6 + STRAND_CY_CB_LAST_TICK], %g2
	brnz,a	%g2, .cya_ret			! full: return error
	  mov	1, %g1				! status = 1

	STRAND2CONFIG_STRUCT(%g6, %g5)		! ->config
	ldx	[%g6 + STRAND_CY_CB_TICK], %g2	! first tick
	brnz,pt	%g2, .cya_1			! not empty: continue
	  rd	STICK, %g3			! get current time
	stx	%g3, [%g6 + STRAND_CY_T0]	! empty: set t0
.cya_1:
	wrhpr	%g0, -1, %hstick_cmpr		! inhibit the compare interrupt

	ldx	[%g5 + CONFIG_CYCLIC_MAXD], %g5	! max delta
	subcc	%g1, %g5, %g2			! delta
	bleu	%xcc, .cya_3			! in the past, let t0 check fix
	  cmp	%g2, %g5			! input within range?
	bgu,a	%xcc, .cya_3			!   yes: anul next
	  add	%g3, %g5, %g1			!   no: use max value!
.cya_3:
	/* g1=abs_tick */
	ldx	[%g6 + STRAND_CY_T0], %g4	! normalize input to T0
	subcc	%g1, %g4, %g1			!     ..
	movlu	%xcc, %g0, %g1			! reverse - set to minimum
	/* g1=delta_tick */
	add	%g6, STRAND_CY_CB, %g4		! ->cb[0]
	add	%g4, CB_LAST, %g5		! ->cb[last]
	dec	CB_SIZE, %g4			! annul next inc
.cya_4:
	inc	CB_SIZE, %g4			! next
	ldx	[%g4 + CB_HANDLER], %g3		! cb[i].handler
	ldx	[%g4 + CB_TICK], %g2		! cb[i].tick
	brz,pn	%g3, .cya_7			! empty: store here
	  cmp	%g1, %g2			! input less than delta?
	bge,a	%xcc, .cya_4			!   no: check next
	  sub	%g1, %g2, %g1			!        adjust input
	/*
	 * Insert at %g4:
	 */
	sub	%g2, %g1, %g2			! adjust current for insert
	stx	%g2, [%g4 + CB_TICK]		! store
.cya_5:						! shift remaining up
	ldx	[%g5 + CB_HANDLER], %g2		! next handler
	brz,a,pt %g2, .cya_6			! open slot: skip
	  cmp	%g4, %g5			!   (at cb[i]?)
						! move this one up:
	ldx	[%g5 + CB_TICK], %g3		!   tick
	stx	%g2, [%g5 + CB_SIZE + CB_HANDLER]
	ldx	[%g5 + CB_ARG0], %g2		!   arg0
	stx	%g3, [%g5 + CB_SIZE + CB_TICK]
	ldx	[%g5 + CB_ARG1], %g3		!   arg1
	stx	%g2, [%g5 + CB_SIZE + CB_ARG0]
	stx	%g3, [%g5 + CB_SIZE + CB_ARG1]	!	..
	cmp	%g4, %g5			! at cb[i]?
.cya_6:
	bnz,a,pt %xcc, .cya_5			!   no
	  dec	CB_SIZE, %g5			!     check next

	/*
	 * Store new entry at %g4:
	 */
.cya_7:
	stx	%g1, [%g4 + CB_TICK]		! store tick
	ldx	[%g6 + STRAND_CY_HANDLER],%g2	! saved handler
	stx	%g2, [%g4 + CB_HANDLER]		!   store
	ldx	[%g6 + STRAND_CY_ARG0], %g2	! saved arg0
	stx	%g2, [%g4 + CB_ARG0]		!   store
	ldx	[%g6 + STRAND_CY_ARG1], %g2	! saved arg1
	stx	%g2, [%g4 + CB_ARG1]		!   store
	/*
	 * Setup new timer interrupt:
	 */
	ldx	[%g6 + STRAND_CY_T0], %g1	! T0 (abs base for cyclic[].tick)
	ldx	[%g6 + STRAND_CY_CB_TICK], %g2	! Td (next delta time)
	add	%g1, %g2, %g4			! Tn = T0 + Td (next int time)

	set	EXIT_NTICK, %g5			! #tick needed to exit
	rd	STICK, %g3			! current time
	add	%g3, %g5, %g3			! Tm (minimum int time)

	cmp	%g3, %g4			! Tn = max(Tn, Tm)
	movgu	%xcc, %g3, %g4

	wrhpr	%g4, %hstick_cmpr		! start the clock running

	clr	%g1				! return status = success
.cya_ret:
	HVRET
	SET_SIZE(cyclic_add_abs)
	SET_SIZE(cyclic_add_rel)


	/*
	 * Function: cyclic_remove
	 *
	 * This function removes an entry from the cyclic timer
	 * queue.
	 *
	 * input: %g2 = handler address, if zero - remove head entry
	 *
	 * scratch: %g3-4
	 *
	 * ToDo: ???? if first entry: disable int
	 */
	ENTRY_NP(cyclic_remove)
	STRAND_STRUCT(%g4)
	add	%g4, STRAND_CY_CB, %g4			! ->cb[0]
	brz,pt	%g2, .cyr_2				! input == 0: do head
.cyr_1:
	  ldx	[%g4 + CB_HANDLER], %g3			! address
	brz	%g3, .cyr_9				! null: input not found!
	  cmp	%g2, %g3				! match input?
	bnz,a	%xcc, .cyr_1				!   no: keep looking
	  inc	CB_SIZE, %g4				!        => next entry
	ldx	[%g4 + CB_TICK], %g3			! Td of entry removed
	ldx	[%g4 + CB_SIZE + CB_TICK], %g2		! Td of next entry
	add	%g3, %g2, %g3				! adjust next time
	stx	%g3, [%g4 + CB_SIZE + CB_TICK]		!	..
.cyr_2:							!
	ldx	[%g4 + CB_SIZE + CB_HANDLER], %g2	! shift remainder down
	ldx	[%g4 + CB_SIZE + CB_TICK], %g3		!	..
	stx	%g2, [%g4 + CB_HANDLER]			!	..
	brz,a,pn %g2, .cyr_8				! (done: addr==0, tick=0)
	  stx	%g0, [%g4 + CB_TICK]			!	..
	ldx	[%g4 + CB_SIZE + CB_ARG0], %g2		!	..
	stx	%g3, [%g4 + CB_TICK]			!	..
	ldx	[%g4 + CB_SIZE + CB_ARG1], %g3		!	..
	stx	%g2, [%g4 + CB_ARG0]			!	..
	stx	%g3, [%g4 + CB_ARG1]			!	..
	ba	.cyr_2					! do next
	  inc	CB_SIZE, %g4
.cyr_8:
	stx	%g0, [%g4 + CB_ARG0]			! zero arg0
	stx	%g0, [%g4 + CB_ARG1]			! zero arg1
.cyr_9:
	HVRET
	SET_SIZE(cyclic_remove)


	/*
	 * Function: cyclic_handler_pop
	 *
	 * This function pops first element off the queue. It uses the
	 * handler address as a valid flag. Time Zero (T0) is updated
	 * to the next time base (T0 + cyclic_tick[0]).
	 *
	 * return:
	 *   g1  arg0
	 *   g2  arg1
	 *   g3  t0
	 *   g4  handler address
	 *   g5-6 clobbered
	 */
	ENTRY_NP(cyclic_handler_pop)

	STRAND_STRUCT(%g6)				! ->strand
	add	%g6, STRAND_CY_CB, %g5			! ->cb[0]

	ldx	[%g5 + CB_HANDLER], %g4			! cb[0].handler
	brz,a,pn %g4, .cyp_9				! null: return g4=null
	  clrx	[%g6 + STRAND_CY_T0]			!       reset time basis
	/*
	 * Update time basis:
	 */
	ldx	[%g6 + STRAND_CY_T0], %g3		! T0
	ldx	[%g5 + CB_TICK], %g2			! cb[0].tick
	add	%g3, %g2, %g3				! next T0
	stx	%g3, [%g6 + STRAND_CY_T0]

	ldx	[%g5 + CB_ARG0], %g1			! cb[0].arg0
	ldx	[%g5 + CB_ARG1], %g2			! cb[0].arg1
.cyp_2:
	ldx	[%g5 + CB_SIZE + CB_HANDLER], %g6	! shift rest down
	stx	%g6, [%g5 + CB_HANDLER]			!	..
	brz,a	%g6, .cyp_8				!   done: addr, tick = 0
	  clrx	[%g5 + CB_TICK]				!       ..
	ldx	[%g5 + CB_SIZE + CB_TICK], %g6		!	..
	stx	%g6, [%g5 + CB_TICK]			!	..
	ldx	[%g5 + CB_SIZE + CB_ARG0], %g6		!	..
	stx	%g6, [%g5 + CB_ARG0]			!	..
	ldx	[%g5 + CB_SIZE + CB_ARG1], %g6		!	..
	stx	%g6, [%g5 + CB_ARG1]			!	..
	ba	.cyp_2					! do next
	  inc	CB_SIZE, %g5
.cyp_8:
	clrx	[%g5 + CB_ARG0]			! zero arg0
	clrx	[%g5 + CB_ARG1]			! zero arg1
.cyp_9:
	HVRET
	SET_SIZE(cyclic_handler_pop)


	/*
	 * hstick_intr
	 *
	 * Hstick interrupt service routine.
	 * This function is called when the compare interrupt fires.
	 *
	 * Note that %hstick_cmpr has been disabled in the trap handler.
	 */
	ENTRY_NP(hstick_intr)

	HVCALL(cyclic_handler_pop)		! %g1-4: arg0, arg1, t0, handler
						! %g5-6: clobbered
	brz,a,pn %g4, .hsi_8			! no cyclic: return
	  nop

	jmp	%g4				! call handler(arg0, arg1, t0)
	  rd	%pc, %g7			! assume all regs are clobbered!!

	/*
	 * This test should (must) fail, if not there is a logic error.
	 * It is here as a fail-safe - add 'warning' code later
	 */
	rdhpr	%hstick_cmpr, %g1		! did callback re-enable?
	brgez	%g1, .hsi_8			!   yes: clear int & return
	  nop
	STRAND_STRUCT(%g6) 			! ->strand
	ldx	[%g6 + STRAND_CY_CB_HANDLER], %g2	! first handler
	brz,a	%g2, .hsi_8			! empty: clear int & return
	  nop
	ldx	[%g6 + STRAND_CY_CB_TICK], %g2	! Td (next delta time)
	ldx	[%g6 + STRAND_CY_T0], %g4	! T0 (abs base for cyclic[].tick)

	rd	STICK, %g3			! Tc = current time
	mov	HSTICK_RET, %g1			! Tr = #tick needed to Retry
	add	%g3, %g1, %g3			! Tint_min = Tc + Tr

	add	%g4, %g2, %g4			! Tint_next = T0 + Td

	cmp	%g3, %g4			! is Tint_min > Tint_next ?
	movgu	%xcc, %g3, %g4			!   yes: Tn = Tint_min
	wrhpr	%g4, %hstick_cmpr		! set the clock

.hsi_8:
	/*
	 * Reenable our interrupt. Clear hintp:HSP
	 */
	wrhpr	%g0, %hintp

	retry
	SET_SIZE(hstick_intr)


#if 0
	/*
	 * cyclic_callback_template
	 *
	 * Hstick interrupt callback function template:
	 *
	 * Called to get actual handler callback address (avoid relocation problems)
	 *
	 * Entry Data:
	 *   none
	 *
	 * Return Data:
	 *   %g2: handler address
	 *
	 * Registers modified:
	 *   %g2
	 */
	ENTRY_NP(cyclic_callback_template)
	RETURN_HANDLER_ADDRESS(%g2)		! in %g2

	/*
	 * Callback from interrupt:
	 *
	 * Entry Data:
	 *   %g1: arg0
	 *   %g2: arg1
	 *   %g3: t0 - interrupt tick time
	 *
	 * Return Data:
	 *    none
	 *
	 * Registers modified:
	 *   %g1-6
	 */
.callback_entry:		/* This is the actual function entry */
	nop	! insert code here.

	HVRET
	SET_SIZE(cyclic_callback_template)
#endif /* 0/1 */
