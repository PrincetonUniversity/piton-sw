/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_l1_cache.s
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

#pragma ident	"@(#)errors_l1_cache.s	1.2	07/07/17 SMI"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>

#include <offsets.h>
#include <util.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_asm.h>

	/*
	 * Dump I-Cache diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_icache)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * load the DESR
	 */
	GET_ERR_DESR(%g4, %g3)

	/*
	 * Icache index from DESR[10:0]
	 */
	and	%g4, DESR_ADDRESS_MASK, %g4
	/*
	 * just want the I-Cache index [5:0]
	 */
	and	%g4, ASI_ICACHE_INDEX_MASK, %g4
	sllx	%g4, ASI_ICACHE_INSTR_INDEX_SHIFT, %g4

	/*
	 * get diag_buf->icache
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_ICACHE, %g1

	/*
	 * Dump the icache tag and data information for all ways
	 * DESR[5:0] D-Cache Index
	 */
	mov	(MAX_ICACHE_WAYS - 1) * ERR_ICACHE_WAY_SIZE, %g2
1:
	/*
	 * offset into DIAG_BUF
	 */
	add	%g1, %g2, %g3

	/*
	 * Create ASI_ICACHE_INSTR VA
	 */
	mov	1, %g5
	sllx	%g5, %g2, %g5
	sllx	%g5, ASI_ICACHE_INSTR_WAY_SHIFT, %g5
	or	%g4, %g5, %g5

	/*
	 * read each word and store
	 * word 0
	 */
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	/*
	 * The I-Cache word to be read is identified by ASI_ICACHE_INSTR
	 * bits [5:3]. To build the address we just add ASI_REGISTER_INCR
	 * to get  the first word, then add ASI_REGISTER_INCR
	 *  to get the next 7 addresses
	 */
	add	%g5, 8, %g5	! ASI_ICACHE_INSTR word 1
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	add	%g5, ASI_REGISTER_INCR, %g5	! ASI_ICACHE_INSTR word 2
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	add	%g5, ASI_REGISTER_INCR, %g5	! ASI_ICACHE_INSTR word 3
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	add	%g5, ASI_REGISTER_INCR, %g5	! ASI_ICACHE_INSTR word 4
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	add	%g5, ASI_REGISTER_INCR, %g5	! ASI_ICACHE_INSTR word 5
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	add	%g5, ASI_REGISTER_INCR, %g5	! ASI_ICACHE_INSTR word 6
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3	! next icache_way word
	add	%g5, ASI_REGISTER_INCR, %g5	! ASI_ICACHE_INSTR word 7
	ldxa	[%g5]ASI_ICACHE_INSTR, %g6
	stx	%g6, [%g3]

	/*	
	 * now get the ASI_ICACHE_TAG data
	 */
	add	%g3, ERR_ICACHE_WAY_INSTR_INCR, %g3
	mov	1, %g5
	sllx	%g5, %g2, %g5
	sllx	%g5, ASI_ICACHE_TAG_WAY_SHIFT, %g5
	or	%g4, %g5, %g5
	ldxa	[%g5]ASI_ICACHE_TAG, %g6
	stx	%g6, [%g3]

	/*
	 * next way
	 */
	brgz,pt	%g2, 1b
	sub	%g2, ERR_ICACHE_WAY_SIZE, %g2

	HVRET

	SET_SIZE(dump_icache)

	/*
	 * Dump DCache diagnostic data
	 *
	 * %g7 return address
	 */

	ENTRY(dump_dcache)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * load the DESR
	 */
	GET_ERR_DESR(%g4, %g3)

	/*
	 * D-Cache index from DESR[10:0]
	 */
	and	%g4, DESR_ADDRESS_MASK, %g4
	/*
	 * just want the D-Cache index [6:0]
	 */
	and	%g4, ASI_DCACHE_INDEX_MASK, %g4
	sllx	%g4, ASI_DCACHE_DATA_INDEX_SHIFT, %g4

	/*
	 * get diag_buf->dcache
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_DCACHE, %g1

	/*
	 * Dump the D-Cache tag and data information for all ways
	 */
	mov	(MAX_DCACHE_WAYS - 1) * ERR_DCACHE_WAY_SIZE, %g2
1:
	/*
	 * offset into DIAG_BUF
	 */
	add	%g1, %g2, %g3

	/*
	 * Create ASI_DCACHE_DATA VA
	 */
	mov	1, %g5
	sllx	%g5, %g2, %g5
	sllx	%g5, ASI_DCACHE_DATA_WAY_SHIFT, %g5
	or	%g4, %g5, %g5

	/*
	 * read each word and store
	 * word 0
	 */
	ldxa	[%g5]ASI_DCACHE_DATA, %g6
	stx	%g6, [%g3]

	add	%g3, 8, %g3	! next dcache_way word
	/*
	 * The D-Cache word to be read is identiied by ASI_DCACHE_DATA
	 * bit [3]. To build the address we just add 8 to get the
	 * first word.
	 */
	add	%g5, 8, %g5	! ASI_DCACHE_DATA word 1
	ldxa	[%g5]ASI_DCACHE_DATA, %g6
	stx	%g6, [%g3]

	/*	
	 * now get the ASI_DCACHE_TAG data
	 */
	add	%g3, 8, %g3
	mov	1, %g5
	sllx	%g5, %g2, %g5
	sllx	%g5, ASI_DCACHE_TAG_WAY_SHIFT, %g5
	or	%g4, %g5, %g5
	ldxa	[%g5]ASI_DCACHE_TAG, %g6
	stx	%g6, [%g3]

	/*
	 * next way
	 */
	brgz,a,pt	%g2, 1b
	sub	%g2, ERR_DCACHE_WAY_SIZE, %g2

	HVRET

	SET_SIZE(dump_dcache)

	ENTRY(icache_storm)

	! first verify that storm prevention is enabled
	CHECK_BLACKOUT_INTERVAL(%g4)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	/*
	 * Disable I-cache errors
	 */
	setx	CORE_ICACHE_ERRORS_ENABLE , %g4, %g1
	mov	CORE_ERR_REPORT_EN, %g4
	ldxa	[%g4]ASI_ERR_EN, %g6
	andn	%g6, %g1, %g6
	stxa	%g6, [%g4]ASI_ERR_EN

	/*
	 * Set up a cyclic on this strand to re-enable the CERER bits
	 * after an interval of (default) 6 seconds. Set a flag in the
	 * strand struct to indicate that the cyclic has been set
	 * for these errors.
	 */
	mov	STRAND_ERR_FLAG_ICACHE, %g4	! I-Cache flag
	STRAND_STRUCT(%g6)
	lduw	[%g6 + STRAND_ERR_FLAG], %g3	! installed flags
	btst	%g4, %g3			! handler installed?
	bnz,pn	%xcc, 9f			!   yes

	or	%g3, %g4, %g3			!   no: set it
	STRAND2CONFIG_STRUCT(%g6, %g4)
	ldx	[%g4 + CONFIG_CE_BLACKOUT], %g1
	brz,pn	%g1, 9f				! zero: blackout disabled
	nop
	SET_STRAND_ERR_FLAG(%g6, %g3, %g5)
	mov	STRAND_ERR_FLAG_ICACHE, %g4	! g4 = arg 1, flags to clear
	setx	CORE_ICACHE_ERRORS_ENABLE, %g5, %g3	! g3 = arg 0 : bit(s) to set
	setx	cerer_set_error_bits, %g5, %g2
	RELOC_OFFSET(%g5, %g6)
	sub	%g2, %g6, %g2			! g2 = handler address
				        	! g1 = delta tick
	VCPU_STRUCT(%g6)
						! g6 - CPU struct
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
9:
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET
	SET_SIZE(icache_storm)

	ENTRY(dcache_storm)

	! first verify that storm prevention is enabled
	CHECK_BLACKOUT_INTERVAL(%g4)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	/*
	 * Disable D-Cache errors
	 */
	setx	CORE_DCACHE_ERRORS_ENABLE, %g4, %g1
	mov	CORE_ERR_REPORT_EN, %g4
	ldxa	[%g4]ASI_ERR_EN, %g6
	andn	%g6, %g1, %g6
	stxa	%g6, [%g4]ASI_ERR_EN

	/*
	 * Set up a cyclic on this strand to re-enable the CERER bits
	 * after an interval of (default) 6 seconds. Set a flag in the
	 * strand struct to indicate that the cyclic has been set
	 * for these errors.
	 */
	mov	STRAND_ERR_FLAG_DCACHE, %g4	! D-Cache flag
	STRAND_STRUCT(%g6)
	lduw	[%g6 + STRAND_ERR_FLAG], %g3	! installed flags
	btst	%g4, %g3			! handler installed?
	bnz,pn	%xcc, 9f			!   yes

	or	%g3, %g4, %g3			!   no: set it
	STRAND2CONFIG_STRUCT(%g6, %g4)
	ldx	[%g4 + CONFIG_CE_BLACKOUT], %g1
	brz,pn	%g1, 9f				! zero: blackout disabled
	nop
	SET_STRAND_ERR_FLAG(%g6, %g3, %g5)
	mov	STRAND_ERR_FLAG_DCACHE, %g4	! g4 = arg 1, flags to clear
	setx	CORE_DCACHE_ERRORS_ENABLE, %g5, %g3		! g3 = arg 0 : bit(s) to set
	setx	cerer_set_error_bits, %g5, %g2
	RELOC_OFFSET(%g5, %g6)
	sub	%g2, %g6, %g2			! g2 = handler address
				        	! g1 = delta tick
	VCPU_STRUCT(%g6)
						! g6 - CPU struct
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
9:
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET
	SET_SIZE(dcache_storm)
