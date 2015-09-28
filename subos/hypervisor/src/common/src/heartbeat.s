/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: heartbeat.s
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

	.ident	"@(#)heartbeat.s	1.6	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hprivregs.h>
#include <asi.h>
#include <fpga.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <config.h>
#include <guest.h>
#include <strand.h>
#include <offsets.h>
#include <util.h>
#include <abort.h>
#include <debug.h>


/*
 * heartbeat - recurring hypervisor heartbeat
 *
 * %g7:	return address
 */
	ENTRY(heartbeat)
	CPU_PUSH(%g7, %g2, %g3, %g4)

	CONFIG_STRUCT(%g2)
	ldx	[%g2 + CONFIG_HEARTBEAT_CPU], %g3
	cmp	%g3, -1
	be,pn	%xcc, .heartbeat_exit
	nop

	/*
	 * Worker routines
	 */
	HVCALL(heartbeat_watchdog)

	/*
	 * Schedule the next timeout
	 */
	HVCALL(heartbeat_enable)

.heartbeat_exit:
	CPU_POP(%g7, %g2, %g3, %g4)
	HVRET
	SET_SIZE(heartbeat)


/*
 * heartbeat_watchdog - check for guest watchdog timer expirations
 */
	ENTRY_NP(heartbeat_watchdog)
	/*
	 * FIXME: Only update the watchdog timer for the control
	 * domain. Eventually, this will need to be made aware
	 * of multiple guests.
	 */
	CTRL_DOMAIN(%g1, %g2, %g3)
	brz,pn	%g1, 1f
	nop
	!! %g1 = control domain guestp

	set	GUEST_WATCHDOG + WATCHDOG_TICKS, %g2
	add	%g1, %g2, %g2

	ldx	[%g2], %g3
	brz,pt	%g3, 1f		! zero value is disabled
	nop

	/* Decrement counter, new value of zero is watchdog expiry */
	ATOMIC_ADD_64(%g2, -1, %g3, %g4)
	!! %g3 new value
	brnz,pt	%g3, 1f
	nop

	/*
	 * Timeout expired
	 */
#ifdef DEBUG
	mov	%g7, %g5	! %g7 holds the %pc for HVRET
	mov	%g1, %g6
	PRINT_NOTRAP("guest watchdog timer expiry\r\n")
	mov	%g6, %g1
	mov	%g5, %g7	! restore %g7 for HVRET
#endif
#if defined(CONFIG_VBSC_SVC)
	!! %g1 - target guestp
	ba,pt	%xcc, vbsc_guest_wdexpire ! tail call returns to caller
	nop
#endif
	/* only get here when no CONFIG_VBSC_SVC or no expiration */

1:	HVRET
	SET_SIZE(heartbeat_watchdog)


/*
 * heartbeat_enable - schedule the next heartbeat
 */
	ENTRY_NP(heartbeat_enable)
	STRAND_STRUCT(%g6)
	STRAND2CONFIG_STRUCT(%g6, %g5)

	ldub	[%g6 + STRAND_ID], %g3
	stx	%g3, [%g5 + CONFIG_HEARTBEAT_CPU]

	ldx	[%g5 + CONFIG_STICKFREQUENCY], %g1 ! interval: 1sec
	ldx	[%g5 + CONFIG_RELOC], %g4
	setx	heartbeat, %g5, %g2
	sub	%g2, %g4, %g2	! handler: guest_watchdog_handler
	ba,a	cyclic_add_rel	! (void), tail call
	SET_SIZE(heartbeat_enable)


/*
 * heartbeat_disable - cancel pending heartbeats
 */
	ENTRY_NP(heartbeat_disable)
	STRAND_STRUCT(%g1)
	STRAND2CONFIG_STRUCT(%g1, %g2)

	/*
	 * We can only disable the heartbeat on the cpu it's running on.
	 */
	ldub	[%g1 + STRAND_ID], %g3
	ldx	[%g2 + CONFIG_HEARTBEAT_CPU], %g4
	cmp	%g3, %g4
	be,pt	%xcc, 1f
	nop
	HVRET
1:

	/*
	 * Mark that there is no heartbeat cpu
	 */
	mov	-1, %g3
	stx	%g3, [%g2 + CONFIG_HEARTBEAT_CPU]

	/*
	 * Cancel future heartbeats
	 */
	ldx	[%g2 + CONFIG_RELOC], %g1
	setx	heartbeat, %g3, %g2
	sub	%g2, %g1, %g2	! handler: guest_watchdog_handler
	ba,a	cyclic_remove	! tail-call
	SET_SIZE(heartbeat_disable)
