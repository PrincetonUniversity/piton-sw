/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traps_common.s
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

	.ident	"@(#)traps_common.s	1.2	07/05/24 SMI"

	.file	"traps_common.s"

#include <sys/asm_linkage.h>
#include <sys/stack.h>
#include <hypervisor.h>
#include <hprivregs.h>
#include <asi.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>

#include <traps.h>
#include <traptable.h>
#include <offsets.h>
#include <util.h>
#include <guest.h>
#include <traptrace.h>
#include <debug.h>
#include <abort.h>
#include <util.h>

/*
 * nonresumable_error_trap - enter a guest on the non-resumable error
 * trap vector.
 *
 * The processor does not detect nrq head != tail, any places
 * that possibly enqueue a nr error queue entry must check head != tail and
 * branch here.
 */
	ENTRY(nonresumable_error_trap)
	! ensure that there is an outbound queue
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_ERRQNR_BASE_RA], %g2	! get q base
	brnz	%g2, 1f				! if base RA is zero, skip
	nop
	! The nonresumable error queue is not allocated/initialized
	HVABORT(-1, "nonresumable_error_trap: nrq missing\r\n")

1:
	REVECTOR(TT_NONRESUMABLE_ERR)
	SET_SIZE(nonresumable_error_trap)

 
/*
 * watchdog - enter a guest on the watchdog trap vector
 */
	ENTRY_NP(watchdog)
	LEGION_GOT_HERE
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bz	1f
	nop

	/* XXX hypervisor_fatal */

1:
	! Disable MMU
	ldxa	[%g0]ASI_LSUCR, %g1
	set	(LSUCR_DM | LSUCR_IM), %g2
	andn	%g1, %g2, %g1	! disable MMU
	stxa	%g1, [%g0]ASI_LSUCR

	! Get real-mode trap table base address
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_RTBA], %g1
	add	%g1, (TT_WDR << TT_OFFSET_SHIFT), %g1
	wrpr	%g1, %tnpc
	done
	SET_SIZE(watchdog)

	/* XXX for now just go to the guest since that tends
	 * to be what we are debugging */

/*
 * xir - enter the guest on the xir trap vector
 *
 * XXX - for now just go to the guest since that tends
 * to be what we are debugging
 */
	ENTRY_NP(xir)
	wrpr	%g0, 1, %tl
	rdhpr	%hpstate, %g7
	wrhpr	%g7, HPSTATE_RED, %hpstate
	LEGION_GOT_HERE

	! Disable MMU
	ldxa	[%g0]ASI_LSUCR, %g1
	set	(LSUCR_DM | LSUCR_IM), %g2
	andn	%g1, %g2, %g1	! disable MMU
	stxa	%g1, [%g0]ASI_LSUCR

	! Get real-mode trap table base address
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_RTBA], %g1
	wrpr	%g1, %tba
	add	%g1, (TT_XIR << TT_OFFSET_SHIFT), %g1
	wrpr	%g1, %tnpc
	done
	SET_SIZE(xir)

	ENTRY_NP(badtrap)
#ifdef DEBUG
	/*
	 * This gives greater visibility into what's happening on debug
	 * hypervisors.
	 */
	ba,a	watchdog_guest
	nop
#endif
	LEGION_GOT_HERE
	ba,pt %xcc, hvabort
	  rdpr	%tpc, %g1
	SET_SIZE(badtrap)
