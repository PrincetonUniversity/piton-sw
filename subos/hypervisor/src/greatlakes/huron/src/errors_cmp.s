/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_cmp.s
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

#pragma ident	"@(#)errors_cmp.s	1.4	07/09/11 SMI"

#include <sys/asm_linkage.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <sparcv9/misc.h>
#include <sun4v/traps.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <config.h>

#include <offsets.h>
#include <util.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_asm.h>

	/*
	 * Dump STB diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_store_buffer)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err_stb
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_STB, %g1

	/*
	 * STB index from DFESR[57:55]
	 */
	GET_ERR_DFESR(%g4, %g3)
	srlx	%g4, DFESR_STB_INDEX_SHIFT, %g4
	and	%g4, DFESR_STB_INDEX_MASK, %g3
	sllx	%g3, ASI_STB_ENTRY_SHIFT, %g3

	/*
	 * Store Buffer data
	 */
	or	%g3, ASI_STB_FIELD_DATA, %g5
	ldxa	[%g5]ASI_STB_ACCESS, %g2
	stx	%g2, [%g1 + ERR_STB_DATA]
	/*
	 * Store Buffer data ECC
	 */
	or	%g3, ASI_STB_FIELD_DATA_ECC, %g5
	ldxa	[%g5]ASI_STB_ACCESS, %g2
	stx	%g2, [%g1 + ERR_STB_DATA_ECC]
	/*
	 * Store Buffer control and address parity
	 */
	or	%g3, ASI_STB_FIELD_PARITY, %g5
	ldxa	[%g5]ASI_STB_ACCESS, %g2
	stx	%g2, [%g1 + ERR_STB_PARITY]
	/*
	 * Store Buffer address and byte marks
	 */
	or	%g3, ASI_STB_FIELD_MARKS, %g5
	ldxa	[%g5]ASI_STB_ACCESS, %g2
	stx	%g2, [%g1 + ERR_STB_MARKS]
	/*
	 * Store Buffer current STB pointer
	 */
	or	%g3, ASI_STB_FIELD_CURR_PTR, %g5
	ldxa	[%g5]ASI_STB_ACCESS, %g2
	stx	%g2, [%g1 + ERR_STB_CURR_PTR]

	HVRET

	SET_SIZE(dump_store_buffer)

	/*
	 * Clear a StoreBuffer error
	 * %g7	return address
	 */
	ENTRY(correct_stb)

	membar	#Sync

	HVRET

	SET_SIZE(correct_stb)

	/*
	 * Dump scratchpad diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_scratchpad)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err-scratchpad
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_SCRATCHPAD, %g1

	GET_ERR_DSFAR(%g4, %g3)

	/*
	 * Scratchpad index from D-SFAR[2:0]
	 * %g4 D-SFAR
	 */
	srlx	%g4, DSFAR_SCRATCHPAD_INDEX_SHIFT, %g4
	and	%g4, DSFAR_SCRATCHPAD_INDEX_MASK, %g3
	sllx	%g3, ASI_SCRATCHPAD_INDEX_SHIFT, %g3

	/*
	 * Scratchpad data
	 */
	or	%g3, ASI_SCRATCHPAD_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_SCRATCHPAD_ACCESS, %g2
	stx	%g2, [%g1 + ERR_SCRATCHPAD_DATA]
	/*
	 * Scratchpad ECC
	 */
	or	%g3, ASI_SCRATCHPAD_DATA_NP_ECC, %g5
	ldxa	[%g5]ASI_SCRATCHPAD_ACCESS, %g2
	stx	%g2, [%g1 + ERR_SCRATCHPAD_ECC]

	HVRET

	SET_SIZE(dump_scratchpad)

	/*
	 * Dump trap stack array diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_trapstack)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err_tsa
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_TSA, %g1

	GET_ERR_DSFAR(%g4, %g3)

	/*
	 * Trapstack index from D-SFAR[2:0]
	 * %g4 D-SFAR
	 */
	srlx	%g4, DSFAR_TSA_INDEX_SHIFT, %g4
	and	%g4, DSFAR_TSA_INDEX_MASK, %g3
	sllx	%g3, ASI_TSA_INDEX_SHIFT, %g3

	/*
	 * Trapstack ECC
	 */
	ldxa	[%g3]ASI_TSA_ACCESS, %g2
	stx	%g2, [%g1 + ERR_TSA_ECC]

	/*
	 * We can got the precise internal_processor_error
	 * trap from %tl - 1. Read the trap registers from that
	 * TL and store them. To avoid recursive errors we need to
	 * disable CERER.TSAC/CERER.TSAU
	 */
	mov	CORE_ERR_REPORT_EN, %g3
	ldxa	[%g3]ASI_ERR_EN, %g4
	setx	(ERR_TSAU | ERR_TSAC), %g5, %g6
	andn	%g4, %g6, %g6
	stxa	%g6, [%g3]ASI_ERR_EN

	rdpr	%tl, %g5
	dec	%g5

	stx	%g5, [%g1 + ERR_TSA_TL]
	/*
	 * Note that we could have got the error at TL = 0, (from Legion).
	 * In that case we don't want to decrement TL as
	 * reading the other trap registers with TL = 0 is not allowed.
	 */
	brnz,a,pt	%g5, 1f
	wrpr	%g5, %tl		! delay slot
1:
	rdpr	%tt, %g2
	stx	%g2, [%g1 + ERR_TSA_TT]
	rdpr	%tstate, %g2
	stx	%g2, [%g1 + ERR_TSA_TSTATE]
	rdhpr	%htstate, %g2
	stx	%g2, [%g1 + ERR_TSA_HTSTATE]
	rdpr	%tpc, %g2
	stx	%g2, [%g1 + ERR_TSA_TPC]
	rdpr	%tnpc, %g2
	stx	%g2, [%g1 + ERR_TSA_TNPC]

	/*
	 * Back to correct TL
	 */

	inc	%g5
	wrpr	%g5, %tl
	
	/*
	 * TSA ECC covers mondo queues also
	 */
	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_ERR_RES_QHEAD]
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_ERR_RES_QTAIL]
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_ERR_NONRES_QHEAD]
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_ERR_NONRES_QTAIL]
	mov	CPU_MONDO_QUEUE_HEAD, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_CPU_MONDO_QHEAD]
	mov	CPU_MONDO_QUEUE_TAIL, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_CPU_MONDO_QTAIL]
	mov	DEV_MONDO_QUEUE_HEAD, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_DEV_MONDO_QHEAD]
	mov	DEV_MONDO_QUEUE_TAIL, %g5
	ldxa	[%g5]ASI_QUEUE, %g5
	stx	%g5, [%g1 + ERR_TSA_DEV_MONDO_QTAIL]

	/*
	 * Set CORE_ERR_ENABLE back to original
	 */
	stxa	%g4, [%g3]ASI_ERR_EN

	HVRET

	SET_SIZE(dump_trapstack)

	/*
	 * Fix Trap Stack array ECC errors
	 * args
	 * %g7	return address
	 */
	ENTRY(correct_trapstack)

	GET_ERR_DSFAR(%g4, %g5)
	srlx	%g4, DSFAR_TSA_INDEX_SHIFT, %g5
	and	%g5, DSFAR_TSA_INDEX_MASK, %g5
	! %g5	index
	cmp	%g5, 7		! TSA entry not used
	be	correct_trapstack_exit
	nop

	setx	core_array_ecc_syndrome_table, %g3, %g2
	RELOC_OFFSET(%g6, %g3)
	sub	%g2, %g3, %g2
	! %g2	ecc syndrome table

	srlx	%g4, DSFAR_TSA_EVEN_SYNDROME_SHIFT, %g6
	and	%g6, DSFAR_TSA_SYNDROME_MASK, %g6
	! %g6	syndrome

	mulx	%g6, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g6
	add	%g2, %g6, %g3
	ldub	[%g3], %g3
	! %g3	correction mask for lower 68 bits
	cmp	%g3, ECC_ne
	bne	1f
	nop

	srlx	%g4, DSFAR_TSA_ODD_SYNDROME_SHIFT, %g6
	and	%g6, DSFAR_TSA_SYNDROME_MASK, %g6
	mulx	%g6, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g6
	add	%g2, %g6, %g3
	ldub	[%g3], %g3
	! %g3	correction mask for upper 68 bits
	cmp	%g3, ECC_LAST_BIT
	ble,a	%xcc, 1f		! if the syndrome is for a bit,
	  add	%g3, ECC_LAST_BIT, %g3	! move it up to the top 67 bits
1:

	! %g3	syndrome
	cmp	%g3, ECC_ne		! No error
	be	correct_trapstack_exit
	cmp	%g3, ECC_U		! Uncorrectable double (or 2n) bit error
	be	convert_tsac_to_tsau
	cmp	%g3, ECC_M		! Triple or worse (2n + 1) bit error
	be	convert_tsac_to_tsau

	/*
	 * Disable TSAC errors
	 */
	mov	CORE_ERR_REPORT_EN, %g6
	ldxa	[%g6]ASI_ERR_EN, %g4
	setx	ERR_TSAC, %g2, %g6
	andn	%g4, %g6, %g4
	mov	CORE_ERR_REPORT_EN, %g6
	stxa	%g4, [%g6]ASI_ERR_EN

	! %g5	index
	cmp	%g5, 6		! mondo/dev/error queues
	be	correct_trapstack_queues
	nop

	/*
	 * error is in the trap registers
	 * %g5	index [0 -> 5]
	 * %g3	bit in error
	 *
	 * We use %g3 to determine which of the trap registers is in
	 * error, don't change the order of these checks.
	 */

	cmp	%g3, ECC_C0
	bl	1f
	nop

	/*
	 * Checkbit or unused bit error
	 * read/write any trap register to correct - so we read write them all
	 */
	rdpr	%tl, %g5
	dec	%g5
	CORRECT_TSA_ALL_REGS(%g5, %g4, %g2, correct_trapstack_exit) 
	/* NOTREACHED */

1:
	rdpr	%tl, %g5
	dec	%g5

	/*
	 * We have a single bit error in one of the trap registers
	 * %g3	bit in error
	 * %g5	trap level when error occurred
	 */
	cmp	%g3, TSA_TNPC_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_TNPC_LO_BIT, %g3
	add	%g3, 2, %g3		! bits[45:0] -> TNPC[47:2]
	CORRECT_TSA_PREG(%tnpc, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TPC_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_TPC_LO_BIT, %g3
	add	%g3, 2, %g3		! bits[45:0] -> TPC[47:2]
	CORRECT_TSA_PREG(%tpc, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TT_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_TT_LO_BIT, %g3
	CORRECT_TSA_PREG(%tt, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_CWP_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_TSTATE_CWP_LO_BIT, %g3
	CORRECT_TSA_PREG(%tt, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_HTSTATE_TLZ_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_HTSTATE_TLZ_LO_BIT, %g3
	CORRECT_TSA_HREG(%htstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_IE_HI_BIT 
	bg,a	%xcc, 1f
	mov	9, %g3			!tstate.pstate.ie  bit 9
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_PRIV_HI_BIT
	bg,a	%xcc, 1f
	mov	10, %g3			!tstate.pstate.priv  bit 10
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_AM_HI_BIT
	bg,a	%xcc, 1f
	mov	11, %g3			!tstate.pstate.am bit 11
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_PEF_HI_BIT
	bg,a	%xcc, 1f
	mov	12, %g3			!tstate.pstate.pef bit 12
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_HTSTATE_RED_HI_BIT
	bg,a	%xcc, 1f
	mov	5, %g3			!htstate.red 5
	CORRECT_TSA_HREG(%htstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_HTSTATE_PRIV_HI_BIT
	bg,a	%xcc, 1f
	mov	2, %g3			!htstate.priv bit 2
	CORRECT_TSA_HREG(%htstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_TCT_HI_BIT
	bg,a	%xcc, 1f
	mov	20, %g3			!tstate.pstate.tct bit 20
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_TLE_HI_BIT
	bg,a	%xcc, 1f
	mov	16, %g3			!tstate.pstate.tle bit 16
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_PSTATE_CLE_HI_BIT
	bg,a	%xcc, 1f
	mov	17, %g3			!tstate.pstate.cle bit 17
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_HTSTATE_IBE_HI_BIT
	bg,a	%xcc, 1f
	mov	10, %g3			!htstate.ibe bit 10
	CORRECT_TSA_HREG(%htstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_ASI_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_TSTATE_ASI_LO_BIT, %g3
	add	%g3, 24, %g3		! tstate.asi [31:24}
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	cmp	%g3, TSA_TSTATE_CCR_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_TSTATE_CCR_LO_BIT, %g3
	add	%g3, 32, %g3		! tstate.ccr [39:32]
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
1:
	
	cmp	%g3, TSA_TSTATE_GL_HI_BIT
	bg,a	%xcc, correct_trapstack_error_in_ecc
	sub	%g3, TSA_TSTATE_GL_LO_BIT, %g3
	add	%g3, 40, %g3		! tstate.gl [41:40]
	CORRECT_TSA_PREG(%tstate, %g5, %g3, %g4, %g2, %g6, correct_trapstack_exit) 
	/* NOTREACHED*/

correct_trapstack_error_in_ecc:
	! should not get here ...
	/*
	 * Set CORE_ERR_ENABLE back to original
	 */
	mov	CORE_ERR_REPORT_EN, %g3
	ldxa	[%g3]ASI_ERR_EN, %g4
	setx	ERR_TSAC, %g2, %g6
	or	%g4, %g6, %g4
	stxa	%g4, [%g3]ASI_ERR_EN
	ba	convert_tsac_to_tsau
	nop

correct_trapstack_queues:
	/*
	 * error is in the queue ASI registers
	 * %g3	bit in error
	 *
	 * We use %g3 to determine which of the queue ASI registers is in
	 * error, don't change the order of these checks.
	 */
	cmp	%g3, TSA_NONRES_ERR_QUEUE_TAIL_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_NONRES_ERR_QUEUE_TAIL_LO_BIT, %g3	! bits [21:14] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(ERROR_NONRESUMABLE_QUEUE_TAIL,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_NONRES_ERR_QUEUE_HEAD_HI_BIT 
	bg,a	%xcc, 1f
	sub	%g3, TSA_NONRES_ERR_QUEUE_HEAD_LO_BIT, %g3	! bits [29:22] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(ERROR_NONRESUMABLE_QUEUE_HEAD,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_RES_ERR_QUEUE_TAIL_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_RES_ERR_QUEUE_TAIL_LO_BIT, %g3	! bits [37:20] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(ERROR_RESUMABLE_QUEUE_TAIL,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_RES_ERR_QUEUE_HEAD_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_RES_ERR_QUEUE_HEAD_LO_BIT, %g3	! bits [45:38] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(ERROR_RESUMABLE_QUEUE_HEAD,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_DEV_QUEUE_TAIL_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_DEV_QUEUE_TAIL_LO_BIT, %g3	! bits [67:60] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(DEV_MONDO_QUEUE_TAIL,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_DEV_QUEUE_HEAD_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_DEV_QUEUE_HEAD_LO_BIT, %g3	! bits [75:68] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(DEV_MONDO_QUEUE_HEAD,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_MONDO_QUEUE_TAIL_HI_BIT
	bg,a	%xcc, 1f
	sub	%g3, TSA_MONDO_QUEUE_TAIL_LO_BIT, %g3	! bits [83:76] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(CPU_MONDO_QUEUE_TAIL,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
1:
	cmp	%g3, TSA_MONDO_QUEUE_HEAD_HI_BIT
	bg,a	%xcc, correct_trapstack_error_in_ecc
	sub	%g3, TSA_MONDO_QUEUE_HEAD_LO_BIT, %g3	! bits [91:84] -> [13:6]
	add	%g3, 6, %g3
	CORRECT_TSA_QUEUE(CPU_MONDO_QUEUE_HEAD,
		%g3, %g4, %g2, %g6, correct_trapstack_exit)
	/* NOTREACHED*/

correct_trapstack_exit:
	/*
	 * Set CORE_ERR_ENABLE back to original
	 */
	mov	CORE_ERR_REPORT_EN, %g6
	ldxa	[%g6]ASI_ERR_EN, %g4
	setx	ERR_TSAC, %g2, %g3
	or	%g4, %g3, %g4
	stxa	%g4, [%g6]ASI_ERR_EN

	HVRET

convert_tsac_to_tsau:
	/*
	 * We know that TSAU is (TSAC entry + 1) so
	 * get the error table entry and move it forward
	 * to the TSAU entry
	 */
	CONVERT_CE_TO_UE(-1)
	/* NOTREACHED */

	SET_SIZE(correct_trapstack)

	/*
	 * Dump Tick_compare diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_tick_compare)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err-tca
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_TCA, %g1

	GET_ERR_DSFAR(%g4, %g3)

	/*
	 * TCA index from D-SFAR[2:0]
	 * %g4 D-SFAR
	 */
	srlx	%g4, DSFAR_TCA_INDEX_SHIFT, %g4
	and	%g4, DSFAR_TCA_INDEX_MASK, %g3
	sllx	%g3, ASI_TICK_INDEX_SHIFT, %g3

	/*
	 * TCA data
	 */
	or	%g3, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g2
	stx	%g2, [%g1 + ERR_TCA_DATA]
	/*
	 * TCA ECC
	 */
	or	%g3, ASI_TICK_DATA_NP_ECC, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g2
	stx	%g2, [%g1 + ERR_TCA_ECC]

	HVRET

	SET_SIZE(dump_tick_compare)

	/*
	 * TCCP
	 * Index/syndrome for a precise TCCP error stored in DESR
	 *
	 * %g7		return address
	 */
	ENTRY(correct_tick_tccp)

	GET_ERR_DSFAR(%g4, %g5)
	srlx	%g4, DSFAR_TCA_INDEX_SHIFT, %g5
	and	%g5, DSFAR_TCA_INDEX_MASK, %g5
	! %g5	index

	srlx	%g4, DSFAR_TCA_SYNDROME_SHIFT, %g4
	and	%g4, DSFAR_TCA_SYNDROME_MASK, %g4
	! %g4	syndrome

	ba	correct_tick_compare		! tail call
	nop
	SET_SIZE(correct_tick_tccp)

	/*
	 * TCCD
	 * Index/syndrome for a disrupting TCCD error stored in DESR
	 *
	 * %g7		return address
	 */
	ENTRY(correct_tick_tccd)

	GET_ERR_DESR(%g4, %g5)
	srlx	%g4, DESR_TCA_INDEX_SHIFT, %g5
	and	%g5, DESR_TCA_INDEX_MASK, %g5
	! %g5	index

	srlx	%g4, DESR_TCA_SYNDROME_SHIFT, %g4
	and	%g4, DESR_TCA_SYNDROME_MASK, %g4
	! %g4	syndrome

	ba	correct_tick_compare		! tail call
	nop
	SET_SIZE(correct_tick_tccd)

	/*
	 * Fix tick_compare error
	 *
	 * %g4	syndrome
	 * %g5	index
	 * %g2 - %g5 	clobbered
	 * %g7		return address
	 *
	 * TCA_ECC_ERRATA	The correct value is not returned when we read 
	 *			from the TCA diagnostic registers
	 */
	ENTRY(correct_tick_compare)
	setx	core_array_ecc_syndrome_table, %g2, %g3
	RELOC_OFFSET(%g6, %g2)
	sub	%g3, %g2, %g3
	! %g3	ecc syndrome table

	mulx	%g4, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g4
	add	%g3, %g4, %g3
	ldub	[%g3], %g3
	! %g3	correction mask

	cmp	%g3, ECC_ne		! no error
	be	correct_tick_compare_exit
	cmp	%g3, ECC_U		!  Uncorrectable double (or 2n) bit error
	be	convert_tccp_to_tcup
	cmp	%g3, ECC_M		!  Triple or worse (2n + 1) bit error
	be	convert_tccp_to_tcup
	.empty

	mov	1, %g6
	sllx	%g6, %g3, %g6
	! no correction mask for checkbit errors
	cmp	%g3, ECC_C0
	movge	%xcc, %g0, %g6
	! %g6	correction mask

#ifdef ERRATA_TICK_INDEX
	/*
	 * On precise internal_processor_error traps, the
	 * tick register index from the D-SFAR may be incorrect.
	 * This does not apply to disrupting sw_recoverable_error
	 * traps.
	 */
	rdpr	%tt, %g1
	cmp	%g1, TT_PROCERR
	bne,pt	%xcc, 3f
	nop

	/*
	 * If it's a correction bit error, %g6 == 0, it is safe
	 * to read/write all HSTICK/TICK/STICK CMP registers and
	 * continue as we will get the correct value from the
	 * diagnostic register (without causing an error trap) and
	 * the write of this value will clear the ECC error.
	 */
	brnz,pt	%g6, 1f
	nop

#ifdef TCA_ECC_ERRATA
	/*
	 * We don't have any information on whether interrupts
	 * are enabled for TICK_CMPR, and we can't get valid
	 * data from either the TICKCMPR register or the diagnostic
	 * register, so we clear the error by writing (TICK + delay)
	 * which will also trigger a TICKCMPR interrupt. The guest
	 * will have to figure out whether its a spurious interrupt
	 * or not.
	 */
	set	ERR_TCA_INCREMENT, %g4
	rd	%tick, %g5
	add	%g5, %g4, %g5
	wr	%g5, TICKCMP

	/*
	 * We don't have any information on whether interrupts
	 * are enabled for HSTICK_CMPR, and we can't get valid
	 * data from either the HSTICKCMPR register or the diagnostic
	 * register, so we clear the error by writing (STICK + delay)
	 * which will also trigger a HSTICKCMPR interrupt. The HV
	 * will have to figure out whether its a spurious interrupt
	 * or not.
	 */
	rd	STICK, %g5
	add	%g5, %g4, %g5
	wrhpr	%g5, %hstick_cmpr

	/*
	 * We don't have any information on whether interrupts
	 * are enabled for STICK_CMPR, and we can't get valid
	 * data from either the STICKCMPR register or the diagnostic
	 * register, so we clear the error by writing (STICK + delay)
	 * which will also trigger a STICKCMPR interrupt. The guest
	 * will have to figure out whether its a spurious interrupt
	 * or not.
	 */
	rd	STICK, %g5
	add	%g5, %g4, %g5
	wr	%g5, STICKCMP

#else	/* !TCA_ECC_ERRATA */

	mov	TCA_TICK_CMPR, %g5
	sllx	%g5, ASI_TICK_INDEX_SHIFT, %g5
	or	%g5, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g5
	! %g5	tick_cmpr value
	wr	%g5, TICKCMP

	mov	TCA_STICK_CMPR, %g5
	sllx	%g5, ASI_TICK_INDEX_SHIFT, %g5
	or	%g5, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g5
	! %g5	stick_cmpr value
	wr	%g5, STICKCMP

	mov	TCA_HSTICK_COMPARE, %g5
	sllx	%g5, ASI_TICK_INDEX_SHIFT, %g5
	or	%g5, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g5
	! %g5	hstick_compare value
	wrhpr	%g5, %hstick_cmpr

#endif	/* TCA_ECC_ERRATA */

	ba	correct_tick_compare_exit
	nop

1:
	/*
	 * If the error occurred in hyperprivileged mode, we
	 * know that this was an access to the hstick_cmpr
	 * register as the HV never accesses TICKCMP/STICKCMP registers
	 * (except when using the error injector).
	 */
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz	correct_htick_compare
	mov	TCA_HSTICK_COMPARE, %g5

	/*
	 * This precise trap was caused by an ECC error during a rdasr/rdhpr
	 * access to one of the tick compare registers.  This ECC error will
	 * also cause the h/w comparisons to trigger a disrupting trap with
	 * the correct index set. Check if PSTATE.IE will be enabled after
	 * the RETRY, and if SETER.DE is set. If these conditions are met 
	 * and we delay by at least 128 cycles, we will take the disrupting
	 * trap and be able to correct the ECC error. The instruction which
	 * caused this precise trap will then execute correctly. If either
	 * of these conditions is not satisfied we convert the error into a UE.
	 */

	! PSTATE.IE enabled on RETRY ?
	rdpr	%tstate, %g1
	srlx	%g1, TSTATE_PSTATE_SHIFT, %g1
	and	%g1, PSTATE_IE, %g1
	brz,pn	%g1, 2f
	nop

	! SETER.DE enabled after RETRY ?
	mov	CORE_ERR_TRAP_EN, %g1
	ldxa	[%g1]ASI_ERR_EN, %g1
	setx	ERR_DE, %g2, %g3
	btst	%g1, %g3
	bz,pn	%xcc, 2f
	nop

	/*
	 * We can just return without correcting the error. In which
	 * case we will handle the error as normal, sending a report
	 * to the SP. This will quarantee a sufficient delay.
	 *
	 * We will get a disrupting trap immediately on exiting the
	 * error trap handler via RETRY.
	 *
	 * The Diagnosis Engine will receive two error reports, one for
	 * this precise trap, one for the disrupting trap we expect
	 * on exiting this error handler.
	 */
	ba	correct_tick_compare_exit
	nop

2:
	/*
	 * We don't know which it is - TICKCMP/STICKCMP, and we won't take
	 * a disrupting trap if we retry the instruction, so we clear
	 * TICKCMP/STICKCMP to get rid of the error condition and treat
	 * this as a UE.
	 */
	wr	%g0, TICKCMP
	wr	%g0, STICKCMP		! FIXME ?
	ba	convert_tccp_to_tcup
	nop
3:
#endif /* ERRATA_TICK_INDEX */

	cmp	%g5, TCA_TICK_CMPR
	be	correct_tick_cmpr
	cmp	%g5, TCA_STICK_CMPR
	be	correct_stick_cmpr
	cmp	%g5, TCA_HSTICK_COMPARE
	be	correct_htick_compare
	nop

	! should not get here ...
	/* FALLTHRU */

convert_tccp_to_tcup:
	/*
	 * We know that TCUP/TCUD is (TCCP/TCCD entry + 1) so
	 * get the error table entry and move it forward
	 * to the TCUP entry
	 */
	CONVERT_CE_TO_UE(-1)
	/* NOTREACHED */

correct_tick_cmpr:
#ifdef TCA_ECC_ERRATA
	/*
	 * We don't have any information on whether interrupts
	 * are enabled for TICK_CMPR, and we can't get valid
	 * data from either the TICKCMPR register or the diagnostic
	 * register, so we clear the error by writing (TICK + delay)
	 * which will also trigger a TICKCMPR interrupt. The guest
	 * will have to figure out whether its a spurious interrupt
	 * or not.
	 */
	set	ERR_TCA_INCREMENT, %g4
	rd	%tick, %g5
	add	%g5, %g4, %g5
	wr	%g5, TICKCMP
#else
	/*
	 * read tick_cmpr from diagnostic ASI
	 * get syndrome from D-SFAR, correction code from 
 	 *  core_array_ecc_syndrome_table
	 * xor correction mask with value and write back to ASR
	 */
	sllx	%g5, ASI_TICK_INDEX_SHIFT, %g5
	or	%g5, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g5
	! %g5	tick_cmpr value
	xor	%g5, %g6, %g5
	wr	%g5, TICKCMP
#endif
	ba	correct_tick_compare_exit
	nop

correct_stick_cmpr:
#ifdef TCA_ECC_ERRATA
	/*
	 * We don't have any information on whether interrupts
	 * are enabled for STICK_CMPR, and we can't get valid
	 * data from either the STICKCMPR register or the diagnostic
	 * register, so we clear the error by writing (STICK + delay)
	 * which will also trigger a STICKCMPR interrupt. The guest
	 * will have to figure out whether its a spurious interrupt
	 * or not.
	 */
	set	ERR_TCA_INCREMENT, %g4
	rd	STICK, %g5
	add	%g5, %g4, %g5
	wr	%g5, STICKCMP
#else
	/*
	 * read stick_cmpr from diagnostic ASI
	 * get syndrome from D-SFAR, correction code from 
 	 *  core_array_ecc_syndrome_table
	 * xor correction mask with value and write back to ASR
	 */
	sllx	%g5, ASI_TICK_INDEX_SHIFT, %g5
	or	%g5, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g5
	! %g5	stick_cmpr value
	xor	%g5, %g6, %g5
	wr	%g5, STICKCMP
#endif
	ba	correct_tick_compare_exit
	nop

correct_htick_compare:
#ifdef TCA_ECC_ERRATA
	/*
	 * We don't have any information on whether interrupts
	 * are enabled for HSTICK_CMPR, and we can't get valid
	 * data from either the HSTICKCMPR register or the diagnostic
	 * register, so we clear the error by writing (STICK + delay)
	 * which will also trigger a HSTICKCMPR interrupt. The HV
	 * will have to figure out whether its a spurious interrupt
	 * or not.
	 */
	set	ERR_TCA_INCREMENT, %g4
	rd	STICK, %g5
	add	%g5, %g4, %g5
	wrhpr	%g5, %hstick_cmpr
#else
	/*
	 * read hstick_compare from diagnostic ASI
	 * get syndrome from D-SFAR, correction code from 
 	 *  core_array_ecc_syndrome_table
	 * xor correction mask with value and write back to ASR
	 */
	sllx	%g5, ASI_TICK_INDEX_SHIFT, %g5
	or	%g5, ASI_TICK_DATA_NP_DATA, %g5
	ldxa	[%g5]ASI_TICK_ACCESS, %g5
	! %g5	hstick_compare value
	xor	%g5, %g6, %g5
	wrhpr	%g5, %hstick_cmpr
#endif
	/* FALLTHRU */

correct_tick_compare_exit:
	HVRET

	SET_SIZE(correct_tick_compare)

	/*
	 * Clear UEs from Tick register array
	 */
	ENTRY(clear_tick_compare)

	wr	%g0, TICKCMP
	wr	%g0, STICKCMP
	wrhpr	%g0, %hstick_cmpr
	HVRET

	SET_SIZE(clear_tick_compare)

	/*
	 * Fix scratchpad array error
	 * %g2 - %g5 	clobbered
	 * %g7		return address
	 */
	ENTRY(correct_scac)

	GET_ERR_DSFAR(%g4, %g5)
	srlx	%g4, DSFAR_SCRATCHPAD_INDEX_SHIFT, %g5
	and	%g5, DSFAR_SCRATCHPAD_INDEX_MASK, %g5
	sllx	%g5, ASI_SCRATCHPAD_INDEX_SHIFT, %g5
	! %g5	(scratchpad register * 8) => VA for 	
	!	diagnostic ASI_SCRATCHPAD_ACCESS register access

	/*
	 * If this is a hypervisor scratchpad register it was reloaded
	 * with the correct data. As long as we didn't clobber the globals
	 * we are good to go ...
	 */
	cmp	%g5, HSCRATCH_VCPU_STRUCT
	be,pt	%xcc, 1f
	nop

	cmp	%g5, HSCRATCH_STRAND_STRUCT
	be,pt	%xcc, 1f
	nop

	ba	2f
	nop
1:
	rdpr	%tstate, %g2
	srlx	%g2, TSTATE_GL_SHIFT, %g2
	and	%g2, TSTATE_GL_MASK, %g2
	rdpr	%gl, %g3
	cmp	%g2, %g3
	be,pt	%xcc, convert_scac_to_scau
	nop             

	/*
	 * It's a HV scratchpad register, we haven't clobbered the
	 * globals, the register was corrected in the trap handler,
	 * just return
	 */
	ba,pt	%xcc, correct_scac_exit
	nop

2:
	/*
	 * read scratchpad from diagnostic ASI
	 * get syndrome from D-SFAR, correction code from 
 	 *  core_array_ecc_syndrome_table
	 * xor correction mask with value and write back to ASI
	 */
	srlx	%g4, DSFAR_SCRATCHPAD_SYNDROME_SHIFT, %g4
	and	%g4, DSFAR_SCRATCHPAD_SYNDROME_MASK, %g4
	! %g4	syndrome

	setx	core_array_ecc_syndrome_table, %g2, %g3
	RELOC_OFFSET(%g6, %g2)
	sub	%g3, %g2, %g3
	! %g3	ecc syndrome table

	mulx	%g4, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g4
	add	%g3, %g4, %g3
	ldub	[%g3], %g3
	! %g3	correction mask

	cmp	%g3, ECC_ne		! no error
	be	correct_scac_exit	
	cmp	%g3, ECC_U		!  Uncorrectable double (or 2n) bit error
	be	convert_scac_to_scau
	cmp	%g3, ECC_M		!  Triple or worse (2n + 1) bit error
	be	convert_scac_to_scau
	mov	1, %g4
	sllx	%g4, %g3, %g4
	! no correction mask for checkbit errors
	cmp	%g3, ECC_C0
	movge	%xcc, %g0, %g4
	! %g4	correction mask

	! %g5	scratchpad register VA (index * 8)
	ldxa	[%g5]ASI_SCRATCHPAD_ACCESS, %g6
	! %g6	scratchpad register value

	xor	%g6, %g4, %g6
	stxa	%g6, [%g5]ASI_SCRATCHPAD

correct_scac_exit:
	HVRET

convert_scac_to_scau:
	/*
	 * We know that SCAU is (SCAC entry + 1) so
	 * get the error table entry and move it forward
	 * to the SCAU entry
	 */
	CONVERT_CE_TO_UE(-1)
	/* NOTREACHED */

	SET_SIZE(correct_scac)

	/*
	 * Fix scratchpad array UE if possible
	 * %g2 - %g5 	clobbered
	 * %g7		return address
	 */
	ENTRY(correct_scau)

	GET_ERR_DSFAR(%g4, %g5)
	srlx	%g4, DSFAR_SCRATCHPAD_INDEX_SHIFT, %g5
	and	%g5, DSFAR_SCRATCHPAD_INDEX_MASK, %g5
	sllx	%g5, 3, %g5	
	! %g5	(scratchpad register * 8) => VA for 	
	!	diagnostic ASI_SCRATCHPAD_ACCESS register access


	/*
	 * If this is a hypervisor scratchpad register and we
	 * haven't overwritten the trap globals, we can correct
	 * this.
	 */
	cmp	%g5, HSCRATCH0
	blt	%xcc, correct_scau_exit
	nop
	cmp	%g5, HSCRATCH1
	bgt	%xcc, correct_scau_exit
	nop

	rdpr	%tstate, %g2
	srlx	%g2, TSTATE_GL_SHIFT, %g2
	and	%g2, TSTATE_GL_MASK, %g2
	rdpr	%gl, %g3
	cmp	%g2, %g3
	bne,pt	%xcc, convert_scau_to_scac
	nop             

	/*
	 * Error was corrected on entry to trap handler.
	 * See SCRATCHPAD_ERROR() macro.
	 */
correct_scau_exit:
	HVRET

convert_scau_to_scac:
	/*
	 * We know that SCAC is (SCAU entry - 1) so
	 * get the error table entry and move it back
	 * to the SCAC entry
	 */
	CONVERT_CE_TO_UE(+1)
	/* NOTREACHED */

	SET_SIZE(correct_scau)

	/*
	 * Populate a sun4v ereport packet for STB errors
	 * with invalid real address and size == 8
	 * %g7	return address
	 */
	ENTRY(stb_sun4v_report)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, stb_sun4v_report_exit
	mov	ERR_INVALID_RA, %g3
	stx	%g3, [%g2 + ERR_SUN4V_RPRT_ADDR]
	mov	8, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_SZ]
stb_sun4v_report_exit:
	HVRET

	SET_SIZE(stb_sun4v_report)

	/*
	 * Populate a sun4v ereport packet for SCA errors
	 * ASI == ASI_SCRATCHPAD
	 * VA == SCA index
	 *
	 * %g7	return address
	 */
	ENTRY(sca_sun4v_report)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, sca_sun4v_report_exit
	mov	ASI_SCRATCHPAD, %g3
	stub	%g3, [%g2 + ERR_SUN4V_RPRT_ASI]
	/*
	 * Scratchpad index from D-SFAR[2:0]
	 */
	GET_ERR_DSFAR(%g4, %g3)
	srlx	%g4, DSFAR_SCRATCHPAD_INDEX_SHIFT, %g4
	and	%g4, DSFAR_SCRATCHPAD_INDEX_MASK, %g3
	sllx	%g3, ASI_SCRATCHPAD_INDEX_SHIFT, %g3	! index -> VA
	stx	%g3, [%g2 + ERR_SUN4V_RPRT_ADDR]
	/*
	 * SZ set to 8 bytes for a single ASI
	 */
	mov	8, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_SZ]
sca_sun4v_report_exit:
	HVRET

	SET_SIZE(sca_sun4v_report)

	/*
	 * Populate a sun4v ereport packet for Tick_compare errors
	 * %g7	return address
	 */
	ENTRY(tick_sun4v_report)

	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, tick_sun4v_report_exit
	.empty

	/*
	 * TCA index from D-SFAR[2:0]
	 * 	00   TICK_CMPR
	 * 	01   STICK_CMPR
	 * 	10   HSTICK_COMPARE
	 * 	11   Reserved.
	 *
	 * We only send a guest report for tick/stick_cmpr
	 */
	GET_ERR_DSFAR(%g4, %g3)
	srlx	%g4, DSFAR_TCA_INDEX_SHIFT, %g4
	and	%g4, DSFAR_TCA_INDEX_MASK, %g3
	cmp	%g3, 2			! HSTICK_COMPARE
	blu,pn	%xcc, 1f
	nop

	stx	%g0, [%g2 + ERR_SUN4V_RPRT_ATTR]
	HVRET	

1:
	! ASR 0x17 tick_cmpr, 0x19 STICK_CMPR
	mov	0x17, %g4
	brnz,a,pn	%g3, 2f
	  mov	0x19, %g4
2:
	set	SUN4V_VALID_REG, %g3
	or	%g4, %g3, %g4
	stuh	%g4, [%g2 + ERR_SUN4V_RPRT_REG]

tick_sun4v_report_exit:

	HVRET

	SET_SIZE(tick_sun4v_report)

	/*
	 * Populate a sun4v ereport packet for TrapStack errors
	 * ATTR == PREG
	 * PREG = TPC[rs1]
	 *
	 * %g7	return address
	 */
	ENTRY(tsa_sun4v_report)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, tsa_sun4v_report_exit
	/*
	 * Trapstack index from D-SFAR[2:0]
	 */
	GET_ERR_DSFAR(%g4, %g3)
	srlx	%g4, DSFAR_TSA_INDEX_SHIFT, %g5
	and	%g5, DSFAR_TSA_INDEX_MASK, %g5
	! %g5	index
	! index == 6 -> mondo queues, 7 -> not used
	cmp	%g5, 5
	bgeu,pn	%xcc, 1f
	set	SUN4V_VALID_REG, %g4
	or	%g5, %g4, %g5
	stuh	%g5, [%g2 + ERR_SUN4V_RPRT_REG]
	/*
	 * SZ set to 8 bytes for a single ASI
	 */
	mov	8, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_SZ]
	HVRET
1:
	/*
	 * No guest report
	 */
	stx	%g0, [%g2 + ERR_SUN4V_RPRT_ATTR]

tsa_sun4v_report_exit:
	HVRET

	SET_SIZE(tsa_sun4v_report)

	/*
	 * Dump MAMEM data
	 */
	ENTRY(dump_mamu)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err_mamu
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_MAMU, %g1

	mov	ASI_MAU_CONTROL, %g2
	ldxa	[%g2]ASI_STREAM, %g3
	stx	%g3, [%g1 + ERR_MA_CTL]
	mov	ASI_MAU_MPA, %g2
	ldxa	[%g2]ASI_STREAM, %g3
	stx	%g3, [%g1 + ERR_MA_PA]
	mov	ASI_MAU_NP, %g2
	ldxa	[%g2]ASI_STREAM, %g3
	stx	%g3, [%g1 + ERR_MA_NP]
	mov	ASI_MAU_SYNC, %g2
	ldxa	[%g2]ASI_STREAM, %g3
	stx	%g3, [%g1 + ERR_MA_SYNC]
	mov	ASI_MAU_ADDR, %g2
	ldxa	[%g2]ASI_STREAM, %g3
	stx	%g3, [%g1 + ERR_MA_ADDR]

	HVRET

	SET_SIZE(dump_mamu)

	ENTRY(dump_reg_ecc)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	GET_ERR_DSFSR(%g3, %g2)
	GET_ERR_DSFAR(%g4, %g2)

	/*
	 * get diag_buf->err_reg
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_REG, %g1

	/*
	 * %g3	D-SFSR
	 */
	cmp	%g3, DSFSR_FRFU
	bl	1f
	nop

	/*
	 * FRF index from D-SFAR[5:1]
	 * %g4 D-SFAR
	 */
	and	%g4, DSFAR_FRF_DBL_REG_MASK, %g3
	stx	%g3, [%g1 + ERR_DIAG_BUF_SPARC_DSFAR]

	sllx	%g3, ASI_FRF_ECC_INDEX_SHIFT, %g3
	ldxa	[%g3]ASI_FRF_ECC_REG, %g3
	stx	%g3, [%g1 + ERR_REG_ECC]
	HVRET
1:
	/*
	 * Convert the IRF index to the Sparc V9 equivalent
	 */
	srlx	%g4, DSFAR_IRF_INDEX_SHIFT, %g2
	and	%g2, DSFAR_IRF_INDEX_MASK, %g2
	CONVERT_IRF_INDEX(%g2, %g5)
	andn	%g4, DSFAR_IRF_INDEX_MASK, %g5
	or	%g5, %g2, %g5
	stx	%g5, [%g1 + ERR_DIAG_BUF_SPARC_DSFAR]

	/*
	 * IRF index from D-SFAR[4:0]
	 * %g4 D-SFAR
	 */
	mov	DSFAR_IRF_INDEX_MASK, %g3
	srlx	%g4, DSFAR_IRF_INDEX_SHIFT, %g4
	and	%g4, DSFAR_IRF_INDEX_MASK, %g3
	sllx	%g3, ASI_IRF_ECC_INDEX_SHIFT, %g3

	ldxa	[%g3]ASI_IRF_ECC_REG, %g3
	stx	%g3, [%g1 + ERR_REG_ECC]

	HVRET
	SET_SIZE(dump_reg_ecc)

	/*
	 * Add the integer reg number to the sun4v guest report
	 */
	ENTRY(irf_sun4v_report)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	GET_ERR_DSFAR(%g3, %g5)
	srlx	%g3, DSFAR_IRF_INDEX_SHIFT, %g3
	and	%g3, DSFAR_IRF_INDEX_MASK, %g3

	/*
	 * Convert the IRF index to the Sparc V9 equivalent
	 */
	CONVERT_IRF_INDEX(%g3, %g5)
	set	SUN4V_VALID_REG, %g4
	or	%g3, %g4, %g3
	stub    %g3, [%g2 + ERR_SUN4V_RPRT_ASI]
	HVRET
	SET_SIZE(irf_sun4v_report)

	/*
	 * Add the FP reg number to the sun4v guest report
	 */
	ENTRY(frf_sun4v_report)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	GET_ERR_DSFAR(%g3, %g5)
	srlx	%g3, DSFAR_FRF_INDEX_SHIFT, %g3
	and	%g3, DSFAR_FRF_INDEX_MASK, %g3
	set	SUN4V_VALID_REG, %g4
	or	%g3, %g4, %g3
	stub    %g3, [%g2 + ERR_SUN4V_RPRT_ASI]
	HVRET
	SET_SIZE(frf_sun4v_report)

	/*
	 * Check whether the FRU error is transient or persistent
	 *   or if the floating point register file is failing.
	 * If TL == 1
	 *	clear_frf_ue
	 *	TRANSIENT
	 * if TL > 1 {
	 *	if (D-SFSR.[TL - 1].FRFU && D-SFAR.[TL -1] == D-SFAR) {
	 *		previous trap was identical, 
	 *		PERSISTENT
	 *	}
	 *	if (D-SFSR.[TL - 1].FRFU {
	 *		FAILURE
	 *	}
	 *	clear_frf_ue
	 *	TRANSIENT
	 * }
	 *	
	 */

	ENTRY(correct_frfu)
	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)

	rdpr	%tl, %g2
	cmp	%g2, 1
	bg,pn	%xcc, 1f
	nop

	HVCALL(clear_frf_ue)

	/*
	 * If we get to here we have created a sun4v FRF
	 * precise non-resumable error report and the
	 * FP UE has been cleared.
	 */
	ba	correct_frfu_exit
	nop

1:
	/*
	 * TL > 1
	 * Either we have nested FRF traps, in which case we have a
	 * failed RF and we mark the CPU as bad, or we have a different
	 * trap type at (TL - 1). 
	 */
	STRAND_STRUCT(%g1)
	sub	%g2, 2, %g2		! (TL - 1) - 1 for diag_buf
	mulx	%g2, STRAND_ERR_ESR_INCR, %g2
	add	%g1, %g2, %g3
	add	%g3, STRAND_ERR_DSFSR, %g3
	ldx	[%g3], %g3		! D-SFSR.[TL - 1]
	cmp	%g3, DSFSR_FRFU
	be	%xcc, 2f
	cmp	%g3, DSFSR_FRFC
	be	%xcc, 2f

	/*
	 * Not a nested FRF error, clear it and return
	 */
	HVCALL(clear_frf_ue)

	/*
	 * If we get to here we have created a sun4v FRF
	 * precise non-resumable error report and the
	 * FP UE has been cleared. return
	 */
	ba	correct_frfu_exit
	nop
	
2:
	/*
	 * we have nested FRF errors
	 * mark the CPU as bad and send a CPU Sun4v report
	 */
	SET_CPU_IN_ERROR(%g2, %g3)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	mov	SUN4V_CPU_RPRT, %g3
	mov	1, %g4
	sllx	%g4, %g3, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_ATTR]
	mov	EDESC_UE_RESUMABLE, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_EDESC]

correct_frfu_exit:
	GET_ERR_RETURN_ADDR(%g7, %g1)
	HVRET
	SET_SIZE(correct_frfu)

	/*
	 * clear_frf_ue()	[LEAF function]
	 *
	 * Clear the UE in the floating-point register file
	 * Arguments:
	 *	%g1 - %g4 - scratch
	 *	%g5, %g6 - preserverd
	 *	%g7 - return address
	 */
	ENTRY_NP(clear_frf_ue)
	GET_ERR_DSFAR(%g2, %g4)
	srlx	%g2, DSFAR_FRF_INDEX_SHIFT, %g2
	and	%g2, DSFAR_FRF_INDEX_MASK, %g2
	! %g2	6-bit fpreg index

	! ensure FPRS.FEF is set. PSTATE.PEF is set by the Sparc h/w when 
	! a trap is taken
	rd	%fprs, %g4
	btst	FPRS_FEF, %g4
	bz,a,pn %xcc, 1f                        ! no: set it
          wr    %g4, FPRS_FEF, %fprs            ! yes: annulled
1:

	! Now clear the register in error
	ba	1f
	rd	%pc, %g3			! %g3 = base address

	! an array of instruction blocks indexed by register number to
	! clear the floating-point register reported in error
	! The first 32 entries use single-precision register
	! The next 32 entries clear the double-precision register
	ba	fp_clear_done
	fzeros	%f0				! clear %f0
	ba	fp_clear_done
	fzeros	%f1				! clear %f1
	ba	fp_clear_done
	fzeros	%f2				! clear %f2
	ba	fp_clear_done
	fzeros	%f3				! clear %f3
	ba	fp_clear_done
	fzeros	%f4				! clear %f4
	ba	fp_clear_done
	fzeros	%f5				! clear %f5
	ba	fp_clear_done
	fzeros	%f6				! clear %f6
	ba	fp_clear_done
	fzeros	%f7				! clear %f7
	ba	fp_clear_done
	fzeros	%f8				! clear %f8
	ba	fp_clear_done
	fzeros	%f9				! clear %f9
	ba	fp_clear_done
	fzeros	%f10				! clear %f10
	ba	fp_clear_done
	fzeros	%f11				! clear %f11
	ba	fp_clear_done
	fzeros	%f12				! clear %f12
	ba	fp_clear_done
	fzeros	%f13				! clear %f13
	ba	fp_clear_done
	fzeros	%f14				! clear %f14
	ba	fp_clear_done
	fzeros	%f15				! clear %f15
	ba	fp_clear_done
	fzeros	%f16				! clear %f16
	ba	fp_clear_done
	fzeros	%f17				! clear %f17
	ba	fp_clear_done
	fzeros	%f18				! clear %f18
	ba	fp_clear_done
	fzeros	%f19				! clear %f19
	ba	fp_clear_done
	fzeros	%f20				! clear %f20
	ba	fp_clear_done
	fzeros	%f21				! clear %f21
	ba	fp_clear_done
	fzeros	%f22				! clear %f22
	ba	fp_clear_done
	fzeros	%f23				! clear %f23
	ba	fp_clear_done
	fzeros	%f24				! clear %f24
	ba	fp_clear_done
	fzeros	%f25				! clear %f25
	ba	fp_clear_done
	fzeros	%f26				! clear %f26
	ba	fp_clear_done
	fzeros	%f27				! clear %f27
	ba	fp_clear_done
	fzeros	%f28				! clear %f28
	ba	fp_clear_done
	fzeros	%f29				! clear %f29
	ba	fp_clear_done
	fzeros	%f30				! clear %f30
	ba	fp_clear_done
	fzeros	%f31				! clear %f31
	! double precision register pairs, clear both of them on errors
	ba	fp_clear_done
	fzero	%f32				! clear %f32
	ba	fp_clear_done
	fzero	%f32				! clear %f32
	ba	fp_clear_done
	fzero	%f34				! clear %f34
	ba	fp_clear_done
	fzero	%f34				! clear %f34
	ba	fp_clear_done
	fzero	%f36				! clear %f36
	ba	fp_clear_done
	fzero	%f36				! clear %f36
	ba	fp_clear_done
	fzero	%f38				! clear %f38
	ba	fp_clear_done
	fzero	%f38				! clear %f38
	ba	fp_clear_done
	fzero	%f40				! clear %f40
	ba	fp_clear_done
	fzero	%f40				! clear %f40
	ba	fp_clear_done
	fzero	%f42				! clear %f42
	ba	fp_clear_done
	fzero	%f42				! clear %f42
	ba	fp_clear_done
	fzero	%f44				! clear %f44
	ba	fp_clear_done
	fzero	%f44				! clear %f44
	ba	fp_clear_done
	fzero	%f46				! clear %f46
	ba	fp_clear_done
	fzero	%f46				! clear %f46
	ba	fp_clear_done
	fzero	%f48				! clear %f48
	ba	fp_clear_done
	fzero	%f48				! clear %f48
	ba	fp_clear_done
	fzero	%f50				! clear %f50
	ba	fp_clear_done
	fzero	%f50				! clear %f50
	ba	fp_clear_done
	fzero	%f52				! clear %f52
	ba	fp_clear_done
	fzero	%f52				! clear %f52
	ba	fp_clear_done
	fzero	%f54				! clear %f54
	ba	fp_clear_done
	fzero	%f54				! clear %f54
	ba	fp_clear_done
	fzero	%f56				! clear %f56
	ba	fp_clear_done
	fzero	%f56				! clear %f56
	ba	fp_clear_done
	fzero	%f58				! clear %f58
	ba	fp_clear_done
	fzero	%f58				! clear %f58
	ba	fp_clear_done
	fzero	%f60				! clear %f60
	ba	fp_clear_done
	fzero	%f60				! clear %f60
	ba	fp_clear_done
	fzero	%f62				! clear %f62
	ba	fp_clear_done
	fzero	%f62				! clear %f62
1:
	! %g2 has freg number, %g3 has base address-4
	sllx	%g2, 3, %g2			! offset = freg# * 8
	add	%g3, %g2, %g3			! %g3 = instruction block addr
	jmp	%g3 + SZ_INSTR			! jmp to clear register
	nop

fp_clear_done:
	! reset FPRS.FEF
	wr	%g4, %g0, %fprs
	HVRET					! return to caller
	SET_SIZE(clear_frf_ue)

	/*
	 * Disable Tick_compare correctable errors for a short period
	 * to ensure that performance is not affected if the error
	 * is persistent. Note that this is for h/w compare operations,
	 * (TCCD errors), not ASR reads (TCCP errors).
	 */
	ENTRY(tick_cmp_storm)

	! first verify that storm prevention is enabled
	CHECK_BLACKOUT_INTERVAL(%g4)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	mov	CORE_ERR_REPORT_EN, %g3
	ldxa	[%g3]ASI_ERR_EN, %g4
	setx	(ERR_TCCD), %g5, %g6
	btst	%g6, %g4
	bz,pn	%xcc, 9f		! TCCD already off
	andn	%g4, %g6, %g6
	stxa	%g6, [%g3]ASI_ERR_EN

	/*
	 * Set up a cyclic on this strand to re-enable the TCCP/TCCD bits
	 * after an interval of 6 seconds. Set a flag in the
	 * strand struct to indicate that the cyclic has been set
	 * for this bank.
	 */
	mov	STRAND_ERR_FLAG_TICK_CMP, %g4	
	STRAND_STRUCT(%g6)
	lduw	[%g6 + STRAND_ERR_FLAG], %g2	! installed flags
	btst	%g4, %g2			! handler installed?
	bnz,pn	%xcc, 9f			!   yes
	nop

	STRAND2CONFIG_STRUCT(%g6, %g4)
	ldx	[%g4 + CONFIG_CE_BLACKOUT], %g1
	brz,a,pn %g1, 9f			! zero: blackout disabled
	  nop
	! handler installed, set flag
	STRAND_STRUCT(%g6)
	SET_STRAND_ERR_FLAG(%g6, STRAND_ERR_FLAG_TICK_CMP, %g5)
	setx	cerer_set_error_bits, %g5, %g2
	RELOC_OFFSET(%g3, %g4)
	sub	%g2, %g4, %g2			! g2 = handler address
	setx	ERR_TCCD, %g4, %g3	! g3 = arg 0 : bit(s) to set
	mov	STRAND_ERR_FLAG_TICK_CMP, %g4	! g4 = arg 1 : cpu flags to clear
				        	! g1 = delta tick
	VCPU_STRUCT(%g6)
						! g6 - CPU struct
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
9:
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET
	SET_SIZE(tick_cmp_storm)


	/*
	 * cyclic function used to re-enable CERER bits
	 *
	 * %g1		CERER bits to set
	 * %g2		strand->err_flags to clear
	 * %g7		return address
	 * %g5 - %g6	clobbered
	 */
	ENTRY(cerer_set_error_bits)
	STRAND_STRUCT(%g6)
	CLEAR_STRAND_ERR_FLAG(%g6, %g2, %g5)

	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g4
	or	%g4, %g1, %g4			! enable arg0 flags
	stxa	%g4, [%g5]ASI_ERR_EN

	HVRET

	SET_SIZE(cerer_set_error_bits)

	/*
	 * Check whether the IRFU error is transient or persistent
	 *   or if the integre register file is failing.
	 * If TL == 1
	 *	clear_irf_ue
	 *	TRANSIENT
	 * if TL > 1 {
	 *	if (D-SFSR.[TL - 1].IRFU && D-SFAR.[TL -1] == D-SFAR) {
	 *		previous trap was identical, 
	 *		PERSISTENT
	 *	}
	 *	if (D-SFSR.[TL - 1].IRFU {
	 *		FAILURE
	 *	}
	 *	clear_irf_ue
	 *	TRANSIENT
	 * }
	 *	
	 */
	ENTRY(correct_irfu)
	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)

	rdpr	%tl, %g2
	cmp	%g2, 1
	bg,pn	%xcc, 1f
	nop

	HVCALL(clear_irf_ue)

	/*
	 * If we get to here we have created a sun4v IRF
	 * precise non-resumable error report and the
	 * IRF UE has been cleared.
	 */
	ba	correct_irfu_exit
	nop

1:
	/*
	 * TL > 1
	 * Either we have nested IRF traps, in which case we have a
	 * failed RF and we mark the CPU as bad, or we have a different
	 * trap type at (TL - 1). 
	 */
	STRAND_STRUCT(%g1)
	sub	%g2, 2, %g2		! (TL - 1) - 1 for diag_buf
	mulx	%g2, STRAND_ERR_ESR_INCR, %g2
	add	%g1, %g2, %g3
	add	%g3, STRAND_ERR_DSFSR, %g3
	ldx	[%g3], %g3		! D-SFSR.[TL - 1]
	cmp	%g3, DSFSR_IRFU
	be	%xcc, 2f
	cmp	%g3, DSFSR_IRFC
	be	%xcc, 2f

	/*
	 * Not a nested IRF error, clear it and return
	 */
	HVCALL(clear_irf_ue)

	/*
	 * If we get to here we have created a sun4v IRF
	 * precise non-resumable error report and the
	 * IRF UE has been cleared. return
	 */
	ba	correct_irfu_exit
	nop
	
2:
	/*
	 * we have nested IRF errors
	 * mark the CPU as bad and send a CPU Sun4v report
	 */
	SET_CPU_IN_ERROR(%g2, %g3)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	mov	SUN4V_CPU_RPRT, %g3
	mov	1, %g4
	sllx	%g4, %g3, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_ATTR]
	mov	EDESC_UE_RESUMABLE, %g3
	st	%g3, [%g2 + ERR_SUN4V_RPRT_EDESC]

correct_irfu_exit:
	GET_ERR_RETURN_ADDR(%g7, %g1)
	HVRET
	SET_SIZE(correct_irfu)


	/*
	 * Clear the UE in the integer register file
	 * Arguments:
	 *	%g1-%g4 -scratch
	 *	%g5, %g6 - preserved
	 *	%g7 - return address
	 */
	ENTRY_NP(clear_irf_ue)
	! get the register number within the set
	GET_ERR_DSFAR(%g3, %g2)
	srlx	%g3, DSFAR_IRF_INDEX_SHIFT, %g2
	and	%g2, DSFAR_IRF_INDEX_MASK, %g2

	/*
	 * The index from the D-SFAR does not match the standard Sparc V9 register
	 * index.
	 */
	CONVERT_IRF_INDEX(%g2, %g4)
	cmp	%g2, 8				! is reg# < 8?
	bl	irf_glob_ue			! yes, then global reg
	mov	%g3, %g1

	! Now clear the register in error
	ba	1f				! clear register
	rd	%pc, %g3			! get clear instr base addr

	! an array of instruction blocks indexed by  register number to
	! clear the non-global register reported in error.
	ba	irf_clear_done
	mov	%g0, %o0		! clear %o0
	ba	irf_clear_done
	mov	%g0, %o1		! clear %o1
	ba	irf_clear_done
	mov	%g0, %o2		! clear %o2
	ba	irf_clear_done
	mov	%g0, %o3		! clear %o3
	ba	irf_clear_done
	mov	%g0, %o4		! clear %o4
	ba	irf_clear_done
	mov	%g0, %o5		! clear %o5
	ba	irf_clear_done
	mov	%g0, %o6		! clear %o6
	ba	irf_clear_done
	mov	%g0, %o7		! clear %o7
	ba	irf_clear_done
	mov	%g0, %l0		! clear %l0
	ba	irf_clear_done
	mov	%g0, %l1		! clear %l1
	ba	irf_clear_done
	mov	%g0, %l2		! clear %l2
	ba	irf_clear_done
	mov	%g0, %l3		! clear %l3
	ba	irf_clear_done
	mov	%g0, %l4		! clear %l4
	ba	irf_clear_done
	mov	%g0, %l5		! clear %l5
	ba	irf_clear_done
	mov	%g0, %l6		! clear %l6
	ba	irf_clear_done
	mov	%g0, %l7		! clear %l7
	ba	irf_clear_done
	mov	%g0, %i0		! clear %i0
	ba	irf_clear_done
	mov	%g0, %i1		! clear %i1
	ba	irf_clear_done
	mov	%g0, %i2		! clear %i2
	ba	irf_clear_done
	mov	%g0, %i3		! clear %i3
	ba	irf_clear_done
	mov	%g0, %i4		! clear %i4
	ba	irf_clear_done
	mov	%g0, %i5		! clear %i5
	ba	irf_clear_done
	mov	%g0, %i6		! clear %i6
	ba	irf_clear_done
	mov	%g0, %i7		! clear %i7
1:
	sub	%g2, 8, %g2		! skip globals
	sllx	%g2, 3, %g2		! offset = reg# * 8
	add	%g3, %g2, %g3		! %g3 = instruction block addr
	jmp	%g3 + SZ_INSTR		! jmp to clear register
	nop

	! restore gl from value in %o0, and restore %o0
irf_gl_clear_done:
	wrpr	%o0, %gl		! restore %gl
	mov	%g4, %o0		! restore %o0

irf_clear_done:
	HVRET				! return to caller

	! %g1 has the gl + register number
irf_glob_ue:
	! now re-read the global register in error
	ba	1f
	rd	%pc, %g3		! get clear instr base addr

	! an array of instructions blocks indexed by global register number
	! to clear the global register reported in error.
	! %gl points to the error global set

	ba	irf_gl_clear_done
	mov	%g0, %g0		! clear %g0
	ba	irf_gl_clear_done
	mov	%g0, %g1		! clear %g1
	ba	irf_gl_clear_done
	mov	%g0, %g2		! clear %g2
	ba	irf_gl_clear_done
	mov	%g0, %g3		! clear %g3
	ba	irf_gl_clear_done
	mov	%g0, %g4		! clear %g4
	ba	irf_gl_clear_done
	mov	%g0, %g5		! clear %g5
	ba	irf_gl_clear_done
	mov	%g0, %g6		! clear %g6
	ba	irf_gl_clear_done
	mov	%g0, %g7		! clear %g7
1:
	sllx	%g2, 3, %g2			! offset (2 instrs)
	add	%g3, %g2, %g3			! %g3 = instruction entry
	mov	%o0, %g4			! save %o0 in %g4
	GET_ERR_GL(%o0)				! save %gl in %o0

	! set gl to error global
	srlx	%g1, DSFAR_IRF_GL_SHIFT, %g2	! get global set from SFAR
	and	%g2, DSFAR_IRF_GL_MASK, %g2	! %g2 has %gl value

	jmp	%g3 + SZ_INSTR			! jump to clear global
	wrpr	%g2, %gl			! set gl to error gl

	SET_SIZE(clear_irf_ue)

	/*
	 * Correct an IRF ECC error
	 * %g7		return address
	 * %g1 - %g6	clobbered
	 *
	 * Get register address from D-SFAR[4:0]
	 * Get ECC syndrome from D-SFAR[14:7]
	 * Disable SETER.PSCCE
	 * (Note: could get an error while doing the correction ....
	 *	  and then it all goes horribly horribly wrong !)
	 * Decode ECC syndrome using ecc_table[]
	 *	- if error in data bits, ecc_table[syndrome] = [0 .. 63]
	 *		xor correction mask with data read from IRF
	 *	- write data back to IRF
	 * Enable SETER.PSCCE
	 */
	ENTRY(correct_irfc)

	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	GET_ERR_DSFAR(%g4, %g5)
	srlx	%g4, DSFAR_IRF_SYNDROME_SHIFT, %g5
	and	%g5, DSFAR_IRF_SYNDROME_MASK, %g5
	! ECC syndrome in %g5

	setx	irf_ecc_syndrome_table, %g2, %g3
	RELOC_OFFSET(%g6, %g2)
	sub	%g3, %g2, %g3
	! %g3	ecc syndrome table

	mulx	%g5, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g5
	add	%g3, %g5, %g3
	ldub	[%g3], %g5
	! decoded ECC syndrome in %g5.

	/*
	 * check for multiple bit errors, and no-error
	 */
	cmp	%g5, ECC_ne			! no error
	be,pn	%xcc, correct_irfc_exit
	nop
	cmp	%g5, ECC_U			! Uncorrectable double (or 2n) bit error */
	be,pn	%xcc, convert_irfc_to_irfu
	nop
	cmp	%g5, ECC_M			! Triple or worse (2n + 1) bit error */
	be,pn	%xcc, convert_irfc_to_irfu
	nop

	srlx	%g4, DSFAR_IRF_INDEX_SHIFT, %g4
	and	%g4, DSFAR_IRF_INDEX_MASK, %g4
	! register number in %g4
	! data bit in error is in %g5

	! disable SETER.PSCCE
	setx	ERR_PSCCE, %g3, %g1
	mov     CORE_ERR_TRAP_EN, %g2
	ldxa	[%g2]ASI_ERR_EN, %g3
	andn	%g3, %g1, %g3
	stxa	%g3, [%g2]ASI_ERR_EN
	
	/*
	 * The index from the D-SFAR does not match the standard Sparc V9 register
	 * index.
	 */
	CONVERT_IRF_INDEX(%g4, %g1)

	! reg# < 8 => global register
	cmp	%g4, 8
	bl,pn	%xcc, correct_irfc_gl
	nop

	! %g4	reg#
	! %g5	syndrome

	! Now read the register in error
	ba	1f				! read register
	rd	%pc, %g3			! get read instr base addr

	! an array of instruction blocks indexed by  register number to
	! clear the non-global register reported in error.
	CORRECT_IRFC(%o0, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o1, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o2, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o3, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o4, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o5, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o6, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%o7, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l0, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l1, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l2, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l3, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l4, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l5, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l6, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%l7, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i0, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i1, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i2, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i3, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i4, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i5, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i6, %g1, %g6, correct_irfc_done)
	CORRECT_IRFC(%i7, %g1, %g6, correct_irfc_done)
1:


	/*
	 * The correction mask is generated as a 64-bit vector of 0's with a single
	 * 1 bit by decoding the syndrome (using rf_ecc-syndrome_table[]).
	 * We XOR that vector with the register data.
	 *
	 * (Note if the error is in a check bit the vector is all 0's - no need to
	 * do the XOR).
	 * 
	 * Once we have the corrected data, just write it back to the register. If
	 * the error was in the check bits, hardware will (should) generate the
	 * correct check bits and write both the data and the check bits to the
	 * register file contents.
	 */
	sub	%g4, 8, %g4			! skip globals
	mov	1, %g1
	sllx	%g1, %g5, %g1
	cmp	%g5, ECC_ne			! if syndrome > ECC_ne
	movge	%xcc, %g0, %g1			! no/checkbit error, clear correction mask
	! %g1	correction mask
	mulx	%g4, CORRECT_IRFC_SIZE, %g4	! offset = reg# * CORRECT_IRFC_SIZE
	add	%g3, %g4, %g3			! %g3 = instruction block addr
	jmp	%g3 + SZ_INSTR			! jmp to correct register
	nop

	/*
	 * Error was in a global register
	 */
correct_irfc_gl:

	! %g4		register#
	! %g5		syndrome

	/*
	 * We need a couple of non-globals registers to play with
	 * when we change GL to the value at the time of the erorr
	 */
	mov	%o5, %g1
	mov	%o4, %g2

	! get the base address of the instruction to read the register
	ba	1f
	rd	%pc, %g3

	ba	irf_read_gl_done
	mov	%g0, %o5
	ba	irf_read_gl_done
	mov	%g1, %o5
	ba	irf_read_gl_done
	mov	%g2, %o5
	ba	irf_read_gl_done
	mov	%g3, %o5
	ba	irf_read_gl_done
	mov	%g4, %o5
	ba	irf_read_gl_done
	mov	%g5, %o5
	ba	irf_read_gl_done
	mov	%g6, %o5
	ba	irf_read_gl_done
	mov	%g7, %o5

1:
	sllx	%g4, 3, %g4			! offset (2 instrs)
	add	%g3, %g4, %g3			! %g3 = instruction entry
	GET_ERR_GL(%o4)				! save %gl in %o4

	! set GL to error trap GL
	GET_ERR_DSFAR(%g6, %g7)
	srlx	%g6, DSFAR_IRF_GL_SHIFT, %g6
	and	%g6, DSFAR_IRF_GL_MASK, %g6

	jmp	%g3 + SZ_INSTR			! jump to clear global
	wrpr	%g6, %gl			! set gl to error gl

irf_read_gl_done:
	! %o4	GL
	wrpr	%o4, %gl
	! %g5	syndrome
	! %o5	value
	mov	1, %g6
	sllx	%g6, %g5, %g6
	cmp	%g5, ECC_ne			! if syndrome >= ECC_ne
	movge	%xcc, %g0, %g6			! no/checkbit error, clear correction mask
	xor	%o5, %g6, %o5
	! %o5	corrected data

irf_restore_gl_data:
	! Now restore the register in error
	ba	1f				! restore register
	rd	%pc, %g3			! get restore instr base addr

	ba	irf_restore_gl_done
	mov	%o5, %g0
	ba	irf_restore_gl_done
	mov	%o5, %g1
	ba	irf_restore_gl_done
	mov	%o5, %g2
	ba	irf_restore_gl_done
	mov	%o5, %g3
	ba	irf_restore_gl_done
	mov	%o5, %g4
	ba	irf_restore_gl_done
	mov	%o5, %g5
	ba	irf_restore_gl_done
	mov	%o5, %g6
	ba	irf_restore_gl_done
	mov	%o5, %g7

1:
	add	%g3, %g4, %g3			! %g3 = instruction entry
	GET_ERR_GL(%o4)				! save %gl in %o4

	! set GL to error trap GL
	GET_ERR_DSFAR(%g6, %g5)
	srlx	%g6, DSFAR_IRF_GL_SHIFT, %g6
	and	%g6, DSFAR_IRF_GL_MASK, %g6

	jmp	%g3 + SZ_INSTR			! jump to clear global
	wrpr	%g6, %gl			! set gl to error gl

irf_restore_gl_done:
	wrpr	%o4, %gl
	mov	%g1, %o5
	mov	%g2, %o4

	ba	correct_irfc_done
	nop

convert_irfc_to_irfu:
	CONVERT_CE_TO_UE(1)
	.empty
	/* NOTREACHED */

correct_irfc_done:
	! enable SETER.PSCCE
	setx	ERR_PSCCE, %g3, %g1
	mov     CORE_ERR_TRAP_EN, %g2
	ldxa	[%g2]ASI_ERR_EN, %g3
	or	%g3, %g1, %g3
	stxa	%g3, [%g2]ASI_ERR_EN

correct_irfc_exit:

	GET_ERR_RETURN_ADDR(%g7, %g4)

	HVRET
	SET_SIZE(correct_irfc)

#ifdef TEST_ERRORS
	ENTRY(inject_cmp_errors)

	ba	4f
	nop

	! bit 25, IRF
	set	((1 << 31) | (1 << 25) | 1), %g5	
	membar	#Sync
	stxa	%g5, [%g0]ASI_ERROR_INJECT_REG
	
	! should get an IRFC on this instruction
	mov	7, %o0
	membar	#Sync
	nop
	stxa	%g0, [%g0]ASI_ERROR_INJECT_REG
	cmp	%o0, 7
	be	%xcc, 1f
	nop
	mov	%g7, %g6
	PRINT_NOTRAP("Failed to fix IRFC\r\n")
	PRINTX_NOTRAP(%o0)
	mov	%g6, %g7
	ba	2f
	nop
1:
	mov	%g7, %g6
	PRINT_NOTRAP("Fixed IRFC\r\n")
	PRINTX_NOTRAP(%o0)
	mov	%g6, %g7
2:
	! bit 24, FRF
	rd	%fprs, %g4
	or	%g4, FPRS_FEF, %g3
	wr	%g3, %fprs
	set	((1 << 31) | (1 << 24) | 4), %g5	
	membar	#Sync
	stxa	%g5, [%g0]ASI_ERROR_INJECT_REG
	
	! should get an FRFC on this instruction
	fmovs	%f8, %f2
	fmovs	%f6, %f4
	faddd	%f2, %f4, %f6
	membar	#Sync
	nop
	stxa	%g0, [%g0]ASI_ERROR_INJECT_REG
	wr	%g4, %fprs
3:
	! bit 23, SCA
	set	((1 << 31) | (1 << 23) | 7), %g5
	membar	#Sync
	stxa	%g5, [%g0]ASI_ERROR_INJECT_REG
	
	! should get an SCAC on this instruction
	mov     0, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	add	%g5, 8, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	add	%g5, 8, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	add	%g5, 8, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	mov	0x30, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	add	%g5, 8, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	add	%g5, 8, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	add	%g5, 8, %g5
	ldxa    [%g5]ASI_HSCRATCHPAD, %g5
	membar	#Sync
	nop
	stxa	%g0, [%g0]ASI_ERROR_INJECT_REG
4:
	! bit 21, TSA
	set	((1 << 31) | (1 << 21) | 8), %g5
	membar	#Sync
	stxa	%g5, [%g0]ASI_ERROR_INJECT_REG
	
	! should get an TSAC on this instruction
	rdpr	%tl, %g5
	wrpr	%g5, %tl
	membar	#Sync
	rdpr	%tstate, %g5
	wrpr	%g5, %tstate
	membar	#Sync
	rdpr	%tpc, %g5
	wrpr	%g5, %tpc
	membar	#Sync
	rdpr	%tnpc, %g5
	wrpr	%g5, %tnpc
	membar	#Sync
	rdhpr	%htstate, %g5
	wrhpr	%g5, %htstate
	membar	#Sync
	nop
	stxa	%g0, [%g0]ASI_ERROR_INJECT_REG
	HVRET
	SET_SIZE(inject_cmp_errors)
#endif

	/*
	 * Dump trap registers
	 * %g7 return address
	 */
	ENTRY(dump_dbu_data)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * Store L2 ESR/EAR for the banks into the DIAG_BUF
	 */
	set	(NO_L2_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, 2f)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	stx	%g4, [%g2]		! clear ESR	RW1C
	stx	%g0, [%g2]		! clear ESR	RW

	add	%g1, ERR_DIAG_BUF_L2_CACHE_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_ESR_INCR, %g5
	add	%g2, %g5, %g2
	! %g2	diag_buf->l2_cache.esr
	stx	%g4, [%g2]

	add	%g1, ERR_DIAG_BUF_L2_CACHE_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_EAR_INCR, %g5
	add	%g2, %g5, %g2
	setx	L2_ERROR_ADDRESS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]		! clear L2 EAR
	stx	%g5, [%g2]

2:
	! next bank
	brgz,pt	%g3, 1b
	dec	%g3

	! DIAG_BUF in %g1

	/*
	 * Store DRAM ESR/EAR/ND for the bank in error into the DIAG_BUF
	 */
	set	(NO_DRAM_BANKS - 1), %g3
3:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 4f)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	brz,pt	%g4, 4f		! no error on this bank
	nop

	stx	%g4, [%g2]	! clear DRAM ESR 	RW1C
	stx	%g0, [%g2]	! clear DRAM ESR 	RW
	add	%g1, ERR_DIAG_BUF_DRAM_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_ESR_INCR, %g5
	add	%g2, %g5, %g2
	stx	%g4, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_EAR_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_EAR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM EAR register
	stx	%g0, [%g4]	! and again for erratum 116
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_LOC, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_LOC_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_ELR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM LOC register
	stx	%g0, [%g4]	! and again for erratum 116
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_CTR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_CTR_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_ECR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM COUNTER register
	stx	%g0, [%g4]	! and again for erratum 116
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_FBD, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_FBD_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_FBD_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear FBD syndrome register
	stx	%g0, [%g4]	! and again for erratum 116
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_RETRY, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_RETRY_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_RETRY_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM error retry register
	stx	%g0, [%g4]	! and again for erratum 116
	stx	%g5, [%g2]

4:
	! next bank
	brgz,pt	%g3, 3b
	dec	%g3

	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_TRAP_REGS, %g1
	! %g1	diag-buf->diag_data.err_trap_regs
	rdpr	%tl, %g2
	mov	%g2, %g3
5:
	wrpr	%g3, %tl
	mulx	%g3, ERR_TRAP_REGS_SIZE, %g4
	add	%g4, %g1, %g4	! %g4 diag_buf->diag_data.err_trap_regs[TL]
	rdpr	%tt, %g5
	stx	%g5, [%g4 + ERR_TT]
	rdpr	%tpc, %g5
	stx	%g5, [%g4 + ERR_TPC]
	rdpr	%tnpc, %g5
	stx	%g5, [%g4 + ERR_TNPC]
	rdpr	%tstate, %g5
	stx	%g5, [%g4 + ERR_TSTATE]
	rdhpr	%htstate, %g5
	stx	%g5, [%g4 + ERR_HTSTATE]
	dec	%g3
	brnz,pt	%g3, 5b
	nop

	! restore original trap level
	wrpr	%g2, %tl

	HVRET
	SET_SIZE(dump_dbu_data)


	/*
	 * Algorithm to correct (if possible) FRFC errors:
	 *	- use DSFAR[5:1] to determine the suspect double
	 *	  	floating reg (%f0 - %f62), and read reg data
	 *	- use DSFAR[5:1] to get the ecc bits
	 *	- use data bits[63:32] and ECC bits [13:7] to
	 *	    calculate syndrome for even single reg. 
	 *		- if syndrome indicates data CE then
	 *	  		correct and store back.
	 *		- if syndrome is UE then unrecoverable.
	 *	- use data bits[31:0] and ECC bits [6:0] to calculate
	 *	    syndrome for odd reg. Take same actions as for even reg.
	 *	- if neither indicate UE then write back into double
	 *	    floating pt reg.
	 *
	 * %g1 - %g6	clobbered
	 * %g7		return address
	 *
 	 * STRAND_FP_TMP1 - data from fpreg
	 * STRAND_FP_TMP2 - ecc
	 */
	ENTRY(correct_frfc)

	! make sure FPRS.FEF is set
	rd	%fprs, %g1
        STRAND_PUSH(%g1, %g2, %g3)
	or	%g1, FPRS_FEF, %g3
	wr	%g3, %fprs

	/*
	 * Get the FRF Index and use it to calculate which
	 * freg to read by working out offset into table
	 * below.
	 */
	GET_ERR_DSFAR(%g5, %g4)
	! clear DSFAR[0], use only even numbered double FP registers
	and	%g5, DSFAR_FRF_DBL_REG_MASK, %g5
	sllx	%g5, 2, %g5

	! get start address of table below
	ba	read_fr_start
	rd	%pc, %g4

	ba	read_fr_done
	std %f0, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f2, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f4, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f6, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f8, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f10, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f12, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f14, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f16, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f18, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f20, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f22, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f24, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f26, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f28, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f30, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f32, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f34, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f36, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f38, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f40, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f42, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f44, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f46, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f48, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f50, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f52, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f54, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f56, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f58, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f60, [%g2 + STRAND_FP_TMP1]
	ba	read_fr_done
	std %f62, [%g2 + STRAND_FP_TMP1]

read_fr_start:
	DISABLE_PSCCE(%g1, %g2, %g3)

	STRAND_STRUCT(%g2)
	add	%g4, %g5, %g4
	jmp	%g4 + SZ_INSTR
	nop

read_fr_done:
	ENABLE_PSCCE(%g1, %g3, %g4)

	! %g2	strandp
	! %g5	DSFAR
	! FP register in error in STRAND_FP_TMP1

	/*
	 * Get the ECC data for the freg. 
	 *
	 * %g5 - D-SFAR[5:1] already shifted to VA[7:3] above for
	 * 		table access
	 */
	ldxa	[%g5]ASI_FRF_ECC_REG, %g4
	stx	%g4, [%g2 + STRAND_FP_TMP2]

	! FP register in error in STRAND_FP_TMP1
	! FP register ECC in error in STRAND_FP_TMP2

	/*
	 * Calculate syndrome for 'even' single reg first.
	 */
	lduw	[%g2 + STRAND_FP_TMP1], %g1
	GEN_FRF_CHECK(%g1, %g2, %g3, %g4, %g5, %g6)
	! check bits in %g2

	STRAND_STRUCT(%g3)

	ldx	[%g3 + STRAND_FP_TMP2], %g1		! ecc
	srlx	%g1, ASI_FRF_ECC_EVEN_SHIFT, %g1	! even ecc
	xor	%g1, %g2, %g5				! calculate syndrome
	and	%g5, FRF_SYND5_MASK, %g5		! %g5 - synd{5:0}

	/*
	 * synd{6} is parity over data and ecc and 
	 * is calculated separately from synd{5:0}
	 */
	lduw	[%g3 + STRAND_FP_TMP1], %g1		! even data
	ldx	[%g3 + STRAND_FP_TMP2], %g2		! ecc
	srlx	%g2, ASI_FRF_ECC_EVEN_SHIFT, %g2	! even ecc
	xor	%g1, %g2, %g1

	GEN_PARITY(%g1, %g4)
	! synd{6} in %g4

	/*
	 * Merge the separate syndrome bits together to get
	 * full synd{6:0}.
	 */
	sllx	%g4, FRF_SYND6_SHIFT, %g4
	or	%g5, %g4, %g5			! g5 - synd{6:0}

	/*
	 * FRF errors use the same syndrome table as L2 cache data
	 */
	setx	l2_ecc_syndrome_table, %g2, %g3
	RELOC_OFFSET(%g6, %g2)
	sub	%g3, %g2, %g3 			! %g3 - ecc syndrome table

	mulx	%g5, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g5
	add	%g3, %g5, %g6
	ldub	[%g6], %g5 			! %g5 - decoded ECC syndrome

	/*
	 * Now check error type and correct if possible.
	 */

	! Not-an-error
	cmp	%g5, ECC_ne
	be,pn	%xcc, even_fr_done

	! Uncorrectable error
	cmp	%g5, ECC_U
	be,pn	%xcc, convert_frfc_to_frfu

	! Multiple error
	cmp	%g5, ECC_M
	be,pn	%xcc, convert_frfc_to_frfu

	! NotData/Triple or worse
	cmp	%g5, ECC_N_M
	be,pn	%xcc, convert_frfc_to_frfu

	! Check bit error (will be corrected by HW)
	cmp	%g5, ECC_C0
	bge	%xcc, even_fr_done
	nop

	/*
	 * Only reach this point if we are dealing with a
	 * data bit error, so now correct it.
	 * %g5	data bit in error
	 */
	mov	1, %g1
	sllx	%g1, %g5, %g5
	STRAND_STRUCT(%g2)
	lduw	[%g2 + STRAND_FP_TMP1], %g1	! even data
	xor	%g1, %g5, %g1			! correct bit
	stw	%g1, [%g2 + STRAND_FP_TMP1]

even_fr_done:

	/*
	 * Now calculate syndrome for 'odd' single reg
	 */
	STRAND_STRUCT(%g2)
	lduw	[%g2 + STRAND_FP_TMP1 + 4], %g1
	GEN_FRF_CHECK(%g1, %g2, %g3, %g4, %g5, %g6)
	! check bits in %g2

	STRAND_STRUCT(%g3)
	ldx	[%g3 + STRAND_FP_TMP2], %g1	! ecc
	and	%g1, ASI_FRF_ECC_ODD_MASK, %g1	! odd ecc
	xor	%g1, %g2, %g5			! calculate syndrome
	and	%g5, FRF_SYND5_MASK, %g5	! %g5 - synd{5:0}

	/*
	 * synd{6} is parity over data and ecc
	 * and is calculated separately from synd{5:0}
	 */
	lduw	[%g3 + STRAND_FP_TMP1 + 4], %g1	! odd data
	ldx	[%g3 + STRAND_FP_TMP2], %g2	! ecc
	and	%g2, ASI_FRF_ECC_ODD_MASK, %g2	! odd ecc
	xor	%g1, %g2, %g1

	GEN_PARITY(%g1, %g6)
	! %g6 - synd{6}

	/*
	 * Merge the separate syndrome bits together to get
	 * full synd{6:0}.
	 */
	sllx	%g6, FRF_SYND6_SHIFT, %g6
	or	%g5, %g6, %g5			! %g5 - synd{6:0}

	/*
	 * FRF errors use the same syndrome table as L2 cache data
	 */
	setx	l2_ecc_syndrome_table, %g2, %g3
	RELOC_OFFSET(%g6, %g2)
	sub	%g3, %g2, %g3 			! %g3 - ecc syndrome table

	mulx	%g5, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g5
	add	%g3, %g5, %g6
	ldub	[%g6], %g5 			! %g5 - decoded ECC syndrome

	/*
	 * Now check error type and correct if possible.
	 */
	! Not-an-error
	cmp	%g5, ECC_ne
	be,pn	%xcc, frf_exit

	! Uncorrectable error
	cmp	%g5, ECC_U
	be,pn	%xcc, convert_frfc_to_frfu

	! Multiple error
	cmp	%g5, ECC_M
	be,pn	%xcc, convert_frfc_to_frfu

	! NotData/Triple or worse
	cmp	%g5, ECC_N_M
	be,pn	%xcc, convert_frfc_to_frfu

	! Check bit error (will be corrected by HW)
	cmp	%g5, ECC_C0
	bge	%xcc, frf_exit
	nop

	/*
	 * Only reach this point if we are dealing with a
	 * data bit error, so now correct it.
	 * %g5	data bit in error
	 */
	mov	1, %g1
	sllx	%g1, %g5, %g5
	STRAND_STRUCT(%g2)
	lduw	[%g2 + STRAND_FP_TMP1 + 4], %g1	! odd data
	xor	%g1, %g5, %g1
	ba	frf_exit
	stw	%g1, [%g2 + STRAND_FP_TMP1 + 4]	! store corrected data

convert_frfc_to_frfu:

	! restore FPRS.FEF
	STRAND_POP(%g1, %g2)
	wr	%g1, %fprs

	/*
	 * We know that FRFU is (FRFC entry - 1) so get the
	 * error table entry and move it back to the FRFU entry
	 */
	CONVERT_CE_TO_UE(+1)
	/* NOTREACHED */

frf_exit:
	/*
	 * Write back the corrected data. Note that if it was a check
	 * bit which was in error this will be automatically fixed
	 * by HW during the writeback.
	 */

	/*
	 * Get the FRF Index and use it to calculate which
	 * freg to write by working out offset into table
	 * below.
	 */
	GET_ERR_DSFAR(%g5, %g4)
	and	%g5, DSFAR_FRF_DBL_REG_MASK, %g5
	sllx	%g5, 2, %g5		! each table entry 2 instr in size

	ba	write_fr_start
	rd	%pc, %g4

	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f0
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f2
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f4
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f6
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f8
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f10
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f12
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f14
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f16
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f18
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f20
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f22
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f24
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f26
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f28
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f30
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f32
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f34
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f36
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f38
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f40
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f42
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f44
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f46
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f48
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f50
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f52
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f54
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f56
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f58
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f60
	ba	write_fr_done
	ldd [%g2 + STRAND_FP_TMP1], %f62

write_fr_start:
	DISABLE_PSCCE(%g1, %g2, %g3)

	STRAND_STRUCT(%g2)
	add	%g4, %g5, %g4
	jmp	%g4 + SZ_INSTR
	nop

write_fr_done:
	ENABLE_PSCCE(%g1, %g2, %g3)

	! restore FPRS.FEF
	STRAND_POP(%g1, %g2)
	wr	%g1, %fprs
	HVRET
	SET_SIZE(correct_frfc)
