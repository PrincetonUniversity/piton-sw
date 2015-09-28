/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_niagara2.s
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

	.ident	"@(#)hcall_niagara2.s	1.1	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <offsets.h>
#include <vcpu.h>
#include <guest.h>
#include <util.h>
#include <cache.h>
#include <dram.h>
#include <debug.h>


	.section ".text"
	.align	32

/*
 * niagara2_getperf
 *
 * arg0 SPARC/DRAM performance register ID (%o0):
 *
 *  %o0(RegId)		Description                RegAddr
 *  ------------------------------------------------------------
 *   0    SPARC Performance Control register    ASR 0x10
 *   1    DRAM Performance Control register 0   DRAM_PERF_CTL0
 *   2    DRAM Performance Counter register 0   DRAM_PERF_COUNT0
 *   3    DRAM Performance Control register 1   DRAM_PERF_CTL1
 *   4    DRAM Performance Counter register 1   DRAM_PERF_COUNT0
 *   5    DRAM Performance Control register 2   DRAM_PERF_CTL2
 *   6    DRAM Performance Counter register 2   DRAM_PERF_COUNT2
 *   7    DRAM Performance Control register 3   DRAM_PERF_CTL3
 *   8    DRAM Performance Counter register 3   DRAM_PERF_COUNT3
 *  ------------------------------------------------------------
 *
 * ret0 status (%o0)
 * ret1 Perf register value (%o1)
 */
	ENTRY_NP(hcall_niagara2_getperf)
	! check if SPARC/DRAM perf registers are accessible
	GUEST_STRUCT(%g1)
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	.empty

	! check if perfreg within range
	cmp	%o0, NIAGARA2_PERFREG_MAX
	bgeu,pn %xcc, herr_inval
	nop

	! read asr reg directly (special case, regId = 0),
	! do the rest by looking up the perf_paddr table
	brnz,a	%o0, 1f
	sub	%o0, 1, %g4			! get table entry pointer

	rd      PERFCNTRCTRL, %o1		! read sparc perf reg
	ba,pt	%xcc, 2f
	nop

1:
	/*
	 * If the required bank is disabled, return 0
	 */
	srlx	%g4, 1, %g5			! bank = (regId-1)/2
	SKIP_DISABLED_DRAM_BANK(%g5, %g3, %g2, 3f)

	set	niagara2_perf_paddr_table - niagara2_getperf_1, %g2
niagara2_getperf_1:
	rd	%pc, %g3
	add	%g2, %g3, %g2
	sllx	%g4, 4, %g4			! table entry offset
	add	%g4, %g2, %g2
	ldx	[%g2], %g3			! get perf reg paddr
	ldx	[%g3], %o1			! read dram perf reg
2:
	HCALL_RET(EOK)
3:
	mov	%g0, %o1	
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara2_getperf)

/*
 * niagara2_setperf
 *
 * arg0 SPARC/DRAM performance register ID (%o0)
 * arg1 perf register value (%o1)
 * ---
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_niagara2_setperf)
	! check if SPARC/DRAM perf registers are accessible
	GUEST_STRUCT(%g1)
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	.empty

	! check if perfreg within range
	cmp	%o0, NIAGARA2_PERFREG_MAX
	bgeu,pn	%xcc, herr_inval
	nop

	! write asr reg directly (special case, regId = 0),
	! do the rest by looking up the perf_paddr table
	brnz,a	%o0, 1f
	sub	%o0, 1, %g4			! get table entry pointer

	/*
	 * guest is allowed to count hpriv events only
	 * if the "perfctrhtaccess" property is set
	 */
	btst	NIAGARA2_PERFCNTRCTL_HT, %o1
	bz,pt	%xcc, 0f
	nop
	set	GUEST_PERFREGHT_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	nop
		
0:	wr      %o1, 0, PERFCNTRCTRL		! write sparc perf reg
	ba,pt	%xcc, 2f
	nop

1:	
	/*
	 * If the required bank is disabled, do nothing
	 */
	srlx	%g4, 1, %g5			! bank = (regId-1)/2
	SKIP_DISABLED_DRAM_BANK(%g5, %g3, %g2, 2f)

	set	niagara2_perf_paddr_table - niagara2_setperf_1, %g2
niagara2_setperf_1:
	rd	%pc, %g3
	add	%g2, %g3, %g2
	sllx	%g4, 4, %g4			! perf table entry offset
	add	%g4, %g2, %g2
	ldx	[%g2], %g3			! get perf reg paddr
	ldx	[%g2+8], %g1			! get perf reg write mask
	and	%g1, %o1, %g1
	stx	%g1, [%g3]			! write perf reg
2:
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara2_setperf)

/*
 * Niagara2 DRAM performance register physical address/mask table
 * (order must match performance RegId assignment, starting with RegId=1)
 */
	.section ".text"
	.align	8
niagara2_perf_paddr_table:
	.xword	DRAM_PERF_CTL0, 0xff
	.xword	DRAM_PERF_COUNT0, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL1, 0xff
	.xword	DRAM_PERF_COUNT1, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL2, 0xff
	.xword	DRAM_PERF_COUNT2, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL3, 0xff
	.xword	DRAM_PERF_COUNT3, 0xffffffffffffffff
