/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_niagara.s
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

	.ident	"@(#)hcall_niagara.s	1.97	07/04/18 SMI"

/*
 * Niagara API calls
 */

#include <sys/asm_linkage.h>
#include <asi.h>
#include <dram.h>
#include <jbi_regs.h>
#include <offsets.h>
#include <guest.h>
#include <util.h>

/*
 * niagara_getperf
 *
 * arg0 JBUS/DRAM performance register ID (%o0)
 * --
 * ret0 status (%o0)
 * ret1 Perf register value (%o1)
 */
	ENTRY_NP(hcall_niagara_getperf)
	! check if JBUS/DRAM perf registers are accessible
	GUEST_STRUCT(%g1)
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	.empty

	! check if perfreg within range
	cmp	%o0, NIAGARA_PERFREG_MAX
	bgeu,pn %xcc, herr_inval
	.empty

	set	niagara_perf_paddr_table - niagara_getperf_1, %g2
niagara_getperf_1:
	rd	%pc, %g3
	add	%g2, %g3, %g2
	sllx	%o0, 4, %o0			! table entry offset
	add	%o0, %g2, %g2
	ldx	[%g2], %g3			! get perf reg paddr
	ldx	[%g3], %o1			! read perf reg
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_getperf)

/*
 * niagara_setperf
 *
 * arg0 JBUS/DRAM performance register ID (%o0)
 * arg1 perf register value (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_niagara_setperf)
	! check if JBUS/DRAM perf registers are accessible
	GUEST_STRUCT(%g1)
	set	GUEST_PERFREG_ACCESSIBLE, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	.empty

	! check if perfreg within range
	cmp	%o0, NIAGARA_PERFREG_MAX
	bgeu,pn	%xcc, herr_inval
	.empty

	set	niagara_perf_paddr_table - niagara_setperf_1, %g2
niagara_setperf_1:
	rd	%pc, %g3
	add	%g2, %g3, %g2
	sllx	%o0, 4, %o0			! table entry offset
	add	%o0, %g2, %g2
	ldx	[%g2], %g3			! get perf reg paddr
	ldx	[%g2+8], %g1			! get perf reg write mask
	and	%g1, %o1, %g1
	stx	%g1, [%g3]			! write perf reg
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_setperf)

/*
 * Niagara JBUS/DRAM performance register physical address/mask table
 * (order must match performance register ID assignment)
 */
	.section ".text"
	.align	8
niagara_perf_paddr_table:
	.xword	JBI_PERF_CTL, 0xff
	.xword	JBI_PERF_COUNT, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL0, 0xff
	.xword	DRAM_PERF_COUNT0, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL1, 0xff
	.xword	DRAM_PERF_COUNT1, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL2, 0xff
	.xword	DRAM_PERF_COUNT2, 0xffffffffffffffff
	.xword	DRAM_PERF_CTL3, 0xff
	.xword	DRAM_PERF_COUNT3, 0xffffffffffffffff
