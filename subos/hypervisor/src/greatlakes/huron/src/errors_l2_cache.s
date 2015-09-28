/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_l2_cache.s
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

#pragma ident	"@(#)errors_l2_cache.s	1.12	07/09/18 SMI"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <vcpu.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <dram.h>
#include <abort.h>

#include <offsets.h>
#include <util.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_asm.h>
#include <cmp.h>
#include <traps.h>

	/*
	 * Clear and correct L2 cache LDAU/LDAC error
	 */
	ENTRY(correct_l2_ildau)
	ba	correct_l2_lda_common
	nop
	SET_SIZE(correct_l2_ildau)

	ENTRY(correct_l2_dldac)
	ALTENTRY(correct_l2_dldau)
	ba	correct_l2_lda_common
	nop
	SET_SIZE(correct_l2_dldac)
	SET_SIZE(correct_l2_dldau)

	ENTRY(correct_l2_lda_common)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	brz,pn	%g1, .correct_lda_exit
	nop

	/*
	 * Find the bank/PA in error
	 */
	set	(NO_L2_BANKS - 1), %g3
.correct_lda_next_bank:
	add	%g1, ERR_DIAG_BUF_L2_CACHE_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_ESR_INCR, %g5
	add	%g2, %g5, %g2
	ldx	[%g2], %g5
	brz,pn	%g5, .correct_lda_next_ear	! no error on this bank
	nop

	add	%g1, ERR_DIAG_BUF_L2_CACHE_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_EAR_INCR, %g5
	add	%g2, %g5, %g2
	ldx	[%g2], %g6

	! %g3	bank
	! %g6	PA

	/*
	 * Check if L2 cache index hashing is enabled
	 */
	setx	L2_IDX_HASH_EN_STATUS, %g5, %g4
	ldx	[%g4], %g4
	btst	L2_IDX_HASH_EN_STATUS_MASK, %g4
	bz,pt	%xcc, .correct_lda_no_idx_hashing
	nop

	N2_PERFORM_IDX_HASH(%g6, %g2, %g4)	! %g6 = IDX'd flush addr
.correct_lda_no_idx_hashing:
	prefetch	[%g6], INVALIDATE_CACHE_LINE
.correct_lda_next_ear:
	brgz,pt	%g3, .correct_lda_next_bank
	dec	%g3
.correct_lda_exit:
	HVRET

	SET_SIZE(correct_l2_lda_common)


	/*
	 * Dump L2 cache diagnostic data for all L2 errors
	 * %g7 return address
	 *
	 * Note: Erratum 116 requires FBD Syndrome register to be written
	 *	 twice to clear the value. Recommended to do this for all
	 *	 DRAM ESRs.
	 */
	ENTRY(dump_l2_cache)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g3, %g4)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * Store L2 ESR/EAR/ND for the bank in error into the DIAG_BUF
	 */
	set	(NO_L2_BANKS - 1), %g3
.dump_l2c_l2_banks:
	STRAND_PUSH(%g3, %g4, %g5)

	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, .dump_l2c_no_l2_error)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	setx	(L2_ESR_VEU | L2_ESR_VEC | L2_ESR_DSC | L2_ESR_DSU), %g5, %g6
	btst	%g6, %g4
	stx	%g4, [%g2]		! clear ESR	RW1C
	stx	%g0, [%g2]		! clear ESR	RW

	add	%g1, ERR_DIAG_BUF_L2_CACHE_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_ESR_INCR, %g5
	add	%g2, %g5, %g2
	! %g2	diag_buf->l2_cache.esr
	bz,pt	%xcc, 0f
	stx	%g4, [%g2]

	! don't save the bank number if CEEN already off,
	! this bank did not generate the trap
	setx	L2_ERROR_ENABLE_REG, %g5, %g6
	sllx	%g3, L2_BANK_SHIFT, %g5
	or	%g6, %g5, %g6
	ldx	[%g6], %g5
	btst	L2_CEEN, %g5
	! save the bank number
	bnz,a,pn	%xcc, 0f		! CEEN on, store bank in delay slot
	  stx	%g3, [%g1 + ERR_DIAG_L2_BANK]
0:

	! No L2 data encoded for DSC/DSU
	! %g4	ESR
	setx	(L2_ESR_DSC | L2_ESR_DSU), %g5, %g6
	btst	%g6, %g4
	bnz	%xcc, .dump_l2c_no_l2_error
	nop

	add	%g1, ERR_DIAG_BUF_L2_CACHE_ND, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_ND_INCR, %g5
	add	%g2, %g5, %g2
	setx	L2_ERROR_NOTDATA_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g4]		! clear NDESR	RW1C
	stx	%g0, [%g4]		! clear NDESR	RW
	stx	%g5, [%g2]

	brnz,a,pt	%g5, 1f		! store bank info in delay slot
	stx	%g3, [%g1 + ERR_DIAG_L2_BANK]
1:
	add	%g1, ERR_DIAG_BUF_L2_CACHE_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_EAR_INCR, %g5
	add	%g2, %g5, %g2
	setx	L2_ERROR_ADDRESS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]		! clear L2 EAR
	stx	%g5, [%g2]

	! %g5	PA
	brz,pt	%g5, .dump_l2c_no_l2_error
	stx	%g5, [%g1 + ERR_DIAG_L2_PA]	! delay slot

	/*
	 * get line state
	 * %g1	PA
	 * %g4	return value
	 */
	mov	%g5, %g1
	HVCALL(check_l2_state)
	! %g4 == line_state
	GET_ERR_DIAG_DATA_BUF(%g3, %g2)
	stx	%g4, [%g3 + ERR_DIAG_L2_LINE_STATE]

	/*
	 * dump L2 tag/data
	 * %g1	physical address
	 * %g2	dump area
	 * %g7	return address
	 * %g3-%g6 clobbered
	 */
	ldx	[%g3 + ERR_DIAG_L2_PA], %g1
	add     %g3, ERR_DIAG_BUF_DIAG_DATA, %g3
	add	%g3, ERR_DIAG_DATA_L2_CACHE, %g2
	HVCALL(dump_l2_set_tag_data_ecc)
	
	/*
	 * Dump the contents of DRAM into the diag buf
	 */
	GET_ERR_DIAG_DATA_BUF(%g3, %g2)
	ldx	[%g3 + ERR_DIAG_L2_PA], %g4
	! %g4	PA
	add     %g3, ERR_DIAG_BUF_DIAG_DATA, %g3	! err_diag_buf.err_diag_data
	add	%g3, ERR_DIAG_DATA_L2_CACHE, %g3	! err_diag_buf.err_diag_data.err_l2_cache
	add	%g3, ERR_DRAM_CONTENTS, %g2		! err_diag_buf.err_diag_data.err_l2_cache.dram_contents
	add	%g4, L2_LINE_SIZE, %g4		! align PA
	andn	%g4, L2_LINE_SIZE, %g4		!  ...
	ldx	[%g4 + (0 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 0]  
	ldx	[%g4 + (1 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 1]
	ldx	[%g4 + (0 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 2]
	ldx	[%g4 + (3 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 3]
	ldx	[%g4 + (4 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 4]
	ldx	[%g4 + (5 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 5]
	ldx	[%g4 + (6 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 6]
	ldx	[%g4 + (7 * SIZEOF_UI64)], %g3
        stx     %g3, [%g2 + ERR_DRAM_CONTENTS_INCR * 7]
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
.dump_l2c_no_l2_error:
	! next bank
	STRAND_POP(%g3, %g4)
	brgz,pt	%g3, .dump_l2c_l2_banks
	dec	%g3

	! fallthrough

dump_l2_cache_dram_esrs:

	! check whether this error requires the DRAM data to be dumped/cleared
	GET_ERR_TABLE_ENTRY(%g1, %g2)
	ld	[%g1 + ERR_FLAGS], %g1
	set	ERR_NO_DRAM_DUMP, %g2
	btst	%g1, %g2
	bnz,pn	%xcc, dump_l2_cache_exit
	nop

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	! DIAG_BUF in %g1

	/*
	 * Store DRAM ESR/EAR/ND for the bank in error into the DIAG_BUF
	 */
	set	(NO_DRAM_BANKS - 1), %g3
.dump_l2c_dram_banks:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, .dump_l2c_no_dram_error)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	brz,pt	%g4, .dump_l2c_no_dram_error	! no error on this bank
	nop

	stx	%g4, [%g2]	! clear DRAM ESR 	RW1C
	stx	%g0, [%g2]	! clear DRAM ESR 	RW
	add	%g1, ERR_DIAG_BUF_DRAM_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_ESR_INCR, %g5
	add	%g2, %g5, %g2

	stx	%g4, [%g2]	! store DRAM ESR

	add	%g1, ERR_DIAG_BUF_DRAM_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_EAR_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_EAR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM EAR register
	stx	%g0, [%g4]
	! %g5	PA
	stx	%g5, [%g2]
	stx	%g5, [%g1 + ERR_DIAG_L2_PA]

	add	%g1, ERR_DIAG_BUF_DRAM_LOC, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_LOC_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_ELR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM LOC register
	stx	%g0, [%g4]
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_CTR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_CTR_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_ECR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM COUNTER register
	stx	%g0, [%g4]
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_FBD, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_FBD_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_FBD_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear FBD syndrome register
	stx	%g0, [%g4]
	stx	%g5, [%g2]

	add	%g1, ERR_DIAG_BUF_DRAM_RETRY, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_RETRY_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_RETRY_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g0, [%g4]	! clear DRAM error retry register
	stx	%g0, [%g4]
	stx	%g5, [%g2]

.dump_l2c_no_dram_error:
	! next bank
	brgz,pt	%g3, .dump_l2c_dram_banks
	dec	%g3

dump_l2_cache_exit:

	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, .dump_l2c_no_l2_guest_report
	GET_ERR_DIAG_DATA_BUF(%g4, %g5)
	brz,pn	%g4, .dump_l2c_no_l2_guest_report
	nop
	ldx	[%g4 + ERR_DIAG_L2_PA], %g5
	VCPU_STRUCT(%g1)
	CPU_ERR_PA_TO_RA(%g1, %g5, %g4, %g3, %g6)
	stx	%g4, [%g2 + ERR_SUN4V_RPRT_ADDR]
.dump_l2c_no_l2_guest_report:
	! all done
	GET_ERR_RETURN_ADDR(%g7, %g2)

	HVRET

	SET_SIZE(dump_l2_cache)

	/*
	 * Populate a sun4v ereport packet for L2$ errors
	 * SZ == ERPT_MEM_SIZE
	 *
	 * We don't have the L2 EAR data yet. Fill it in in dump_l2_cache above
	 *
	 * %g7	return address
	 */
	ENTRY(l2_sun4v_report)

	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, l2_sun4v_report_exit
	mov	ERPT_MEM_SIZE, %g5
	stx	%g5, [%g2 + ERR_SUN4V_RPRT_SZ]
l2_sun4v_report_exit:
	HVRET

	SET_SIZE(l2_sun4v_report)


	ENTRY(correct_l2_dac)
	HVRET
	SET_SIZE(correct_l2_dac)
	ENTRY(correct_l2_drc)
	HVRET
	SET_SIZE(correct_l2_drc)

	ENTRY(l2_ce_storm)

	! first verify that storm prevention is enabled
	CHECK_BLACKOUT_INTERVAL(%g4)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	/*
	 * bank in error
	 */
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	ldx	[%g1 + ERR_DIAG_L2_BANK], %g2
	and	%g2, (NO_L2_BANKS - 1), %g2

	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g2, %g4, %g5, 9f)

	setx	L2_ERROR_ENABLE_REG, %g4, %g5
	sllx	%g2, L2_BANK_SHIFT, %g3
	add	%g5, %g3, %g5
	ldx	[%g5], %g3
	btst	L2_CEEN, %g3
	bz,pn	%xcc, 9f		! CEEN already off
	andn	%g3, L2_CEEN, %g3
	stx	%g3, [%g5]		! disable CEEN

	/*
	 * Set up a cyclic on this strand to re-enable the CEEN bit
	 * after an interval of 6 seconds. Set a flag in the
	 * strand struct to indicate that the cyclic has been set
	 * for this bank.
	 */
	mov	STRAND_ERR_FLAG_L2DRAM, %g4	! L2DRAM flag
	sllx	%g4, %g2, %g4			! << bank#
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
	mov	%g2, %g4			! g4 = arg 1 : B5-0: bank #
	setx	l2_set_err_bits, %g5, %g2
	RELOC_OFFSET(%g3, %g5)
	sub	%g2, %g5, %g2			! g2 = handler address
	mov	L2_CEEN, %g3			! g3 = arg 0 : bit(s) to set
				        	! g1 = delta tick
	VCPU_STRUCT(%g6)
						! g6 - CPU struct
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
9:
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET
	SET_SIZE(l2_ce_storm)

	/*
	 * Callback from interrupt:
	 *
	 * Entry Data:
	 *   %g1: bit(s) to set
	 *   %g2: B:5-0 = bank #
	 *
	 * Return Data:
	 *    none
	 *
	 * Registers modified:
	 *   %g1-6
	 */
	ENTRY(l2_set_err_bits)
	mov	%g1, %g5			! bits
	and	%g2, NO_L2_BANKS - 1, %g6	! bank #
	!! %g5 = bits to set
	!! %g6 = bank#

	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g6, %g4, %g2, 9f)

	setx	DRAM_ESR_CE_BITS | DRAM_ESR_MEC, %g1, %g2
	setx	DRAM_ESR_BASE, %g1, %g3		! DRAM base
	srlx	%g6, 1, %g1			! L2 bank -> DRAM bank
	sllx	%g1, DRAM_BANK_SHIFT, %g4	!  + bank offset
	ldx	[%g3 + %g4], %g1		! get ESR[bank]
	and	%g1, %g2, %g1			! reset CE bits only (W1C)
	stx	%g1, [%g3 + %g4]

	!! %g6 = bank#
	setx	L2_ESR_CE_ERRORS, %g1, %g2
	setx	L2_ERROR_STATUS_REG, %g1, %g3
	sllx	%g6, L2_BANK_SHIFT, %g4		!  + bank offset
	ldx	[%g3 + %g4], %g1		! get ESR[bank]
	and	%g1, %g2, %g1			! reset CE bits only (W1C)
	stx	%g1, [%g3 + %g4]

	! clear FBD Error Syndrome register for this bank
	setx	DRAM_FBD_BASE, %g1, %g3
	sllx	%g6, DRAM_BANK_SHIFT, %g4
	stx	%g0, [%g3 + %g4]		! clear DRAM FBD SYND	RW
	stx	%g0, [%g3 + %g4]

	!! %g6 = bank#
	STRAND_STRUCT(%g3)				! %g3->cpu
	mov	STRAND_ERR_FLAG_L2DRAM, %g1	! L2DRAM flag
	sllx	%g1, %g6, %g1			! << bank#
	CLEAR_STRAND_ERR_FLAG(%g3, %g1, %g4)

	!! %g6 = bank#
	setx	L2_ERROR_ENABLE_REG, %g4, %g5
	sllx	%g6, L2_BANK_SHIFT, %g3
	or	%g5, %g3, %g5
	ldx	[%g5], %g3
	or	%g3, L2_CEEN, %g3
	stx	%g3, [%g5]			! enable CEEN
9:
	HVRET
	SET_SIZE(l2_set_err_bits)

	ENTRY(dram_storm)

	! first verify that storm prevention is enabled
	CHECK_BLACKOUT_INTERVAL(%g4)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	/*
	 * Disable DRAM errors
	 */
	setx	CORE_DRAM_ERRORS_ENABLE , %g4, %g1
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
	setx	STRAND_ERR_FLAG_DRAM, %g6, %g4
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
	setx	STRAND_ERR_FLAG_DRAM, %g5, %g4		! g4 = arg 1, flags to clear
	setx	CORE_DRAM_ERRORS_ENABLE, %g5, %g3	! g3 = arg 0 : bit(s) to set
	setx	cerer_set_error_bits, %g5, %g2
	RELOC_OFFSET(%g6, %g5)
	sub	%g2, %g5, %g2			! g2 = handler address
				        	! g1 = delta tick
	VCPU_STRUCT(%g6)
						! g6 - CPU struct
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
9:
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET
	SET_SIZE(dram_storm)

	/*
	 * print the bank and PA in error
	 * and the diag-buf L2 cache 
	 * %g7	return address
	 */
	ENTRY(l2_cache_print)
#ifdef DEBUG_LEGION
	mov	%g7, %g6
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	PRINT("L2 BANK: 0x");
	ldx	[%g1 + ERR_DIAG_L2_BANK], %g4	
	PRINTX(%g4)
	PRINT("\r\n")
	PRINT("L2 PA: 0x");
	ldx	[%g1 + ERR_DIAG_L2_PA], %g4
	PRINTX(%g4)	
	PRINT("\r\n")

	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_L2_CACHE, %g1

	PRINT("L2 VDBITS: 0x");			
	ldx	[%g1 + ERR_L2_VDBITS], %g4
	PRINTX(%g4)	
	PRINT("\r\n")
	PRINT("L2 UABITS: 0x");			
	ldx	[%g1 + ERR_L2_UABITS], %g4
	PRINTX(%g4)	
	PRINT("\r\n")

	/*
	 * DIAG_BUF for L2 ways in %g1
	 */
	add	%g1, ERR_L2_WAYS, %g1
	mov	0, %g2
1:	
	PRINT("L2 WAYS:	0x");
	srlx	%g2, 3, %g4
	PRINTX(%g4)
	PRINT(" : TAG ECC: 0x")
	ldx	[%g1 + ERR_WAY_TAG_AND_ECC], %g4
	PRINTX(%g4)
	PRINT("\r\n")	

	/*
	 * for each L2 way, print each data ecc, starting from word 0
	 */
	add	%g1, ERR_WAY_DATA_AND_ECC, %g1	
	mov	0, %g3	
2:			
	PRINT("DATA ECC: 0x");
	srlx	%g3, 3, %g4
	PRINTX(%g4)
	PRINT(" :  0x")
	ldx	[%g1], %g4
	PRINTX(%g4)
	PRINT("\r\n")
	add	%g3, 0x8, %g3
	cmp	%g3, L2_NUM_WAYS * 8
	bnz	2b
	add	%g1, ERR_WAY_DATA_AND_ECC_INCR, %g1

	/*
	 * next L2 way
	 */
	add	%g2, 0x8, %g2
	cmp	%g2, L2_NUM_WAYS * 8
	bnz	1b
	add	%g1, ERR_L2_WAYS_INCR, %g1	/* increment */
	
	mov	%g6, %g7
#endif	/* DEBUG */

	HVRET
	SET_SIZE(l2_cache_print)

	/*
	 * FBDIMM bug around FBRs (fbdimm serdes corrrectable errors).
	 * Metrax id is 125737
	 * 
	 * There is an interaction between the scrub logic and the retry
	 * logic for link CRC errors. The SW visible symptom is a DSU
	 * (scrub uncorrectable error) sent to the error steering thread.
	 * It will log a DSU with valid address and 0xffff syndrome
	 * (address parity error). The error is totally bogus and should
	 * be ignored (data in DRAM is perfectly correct).
	 *
	 * This function will read the DSU error address from the bank
	 * in error under protection. If another error occurs this is a
	 * valid DSU. If not, this is a bogus error and we just exit
	 * error handling with a RETRY.
	 */
	ENTRY_NP(verify_dsu_error)

	STRAND_PUSH(%g7, %g2, %g3)

#ifdef DEBUG
	HV_PRINT_NOTRAP("VERIFY DSU\r\n")
#endif

	/*
	 * Find the DRAM bank which got the DSU
	 */
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	brz,pn	%g1, .dsu_genuine_error		! nothing to do
	nop

	set	(NO_DRAM_BANKS - 1), %g3
	add	%g1, ERR_DIAG_BUF_DRAM_ESR, %g2
	setx	DRAM_ESR_DSU, %g5, %g4
	set	DRAM_ESR_SYND_MASK, %g6
.verify_dsu_dram_banks:
	mulx	%g3, ERR_DIAG_BUF_DRAM_ESR_INCR, %g5
	add	%g5, %g2, %g5
	ldx	[%g5], %g5		! DRAM ESR

#ifdef DEBUG
	STRAND_PUSH(%g1, %g6, %g7)
	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	mov	%g5, %g6
	HV_PRINT_NOTRAP("ESR 0x")
	HV_PRINTX_NOTRAP(%g6)
	HV_PRINT_NOTRAP("\r\n")
	mov	%g6, %g5
	setx    DRAM_ESR_DSU, %g6, %g4
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	STRAND_POP(%g1, %g6)
	set     DRAM_ESR_SYND_MASK, %g6
#endif
	
	btst	%g5, %g4		! DSU on this bank ?
	bz,pt	%xcc, .verify_dsu_dram_banks_loop
	nop

	/*
	 * DRAM_ESR.DSU, look for syndrome 0xffff
	 */
	and	%g5, %g6, %g5
	cmp	%g5, %g6	! syndrome == 0xffff ?
	bne,pt	%xcc, .verify_dsu_dram_banks_loop
	nop

	/*
	 * DSU on this bank, read the address
	 * If there is an error at this location we should get
	 * a precise data_access_error trap for critical load
	 * data delivered before linefill.
	 */
	add	%g1, ERR_DIAG_BUF_DRAM_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_EAR_INCR, %g5
	add	%g5, %g2, %g5
	ldx	[%g5], %g4
#ifdef DEBUG
	STRAND_PUSH(%g1, %g6, %g7)
	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	mov	%g4, %g6
	HV_PRINT_NOTRAP("EAR 0x")
	HV_PRINTX_NOTRAP(%g6)
	HV_PRINT_NOTRAP("\r\n")
	mov	%g6, %g4
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	STRAND_POP(%g1, %g6)
#endif
	andn	%g4, 0xf, %g4		! force alignment
	! %g4	PA of DSU error

	setx	L2_IDX_HASH_EN_STATUS, %g3, %g5
	ldx	[%g5], %g5
	and	%g5, L2_IDX_HASH_EN_STATUS_MASK, %g5
	brz,pn	%g5, .verify_dsu_no_idx_hashing		! no index hashing
	nop

	N2_PERFORM_IDX_HASH(%g4, %g3, %g5)
.verify_dsu_no_idx_hashing:
	! %g4	PA
	STRAND_STRUCT(%g2)
	set	STRAND_ERR_FLAG_PROTECTION, %g5
	SET_STRAND_ERR_FLAG(%g2, %g5, %g3)

	ldx	[%g4], %g0
	ldx	[%g4 + 8], %g0

	CLEAR_STRAND_ERR_FLAG(%g2, %g5, %g3)

	/*
	 * If this is a genuine DSU error, the IO_ERROR flag should be
	 * set now.
	 */

	add	%g2, STRAND_IO_ERROR, %g2
	ldx	[%g2], %g3
	brnz,a,pt %g3, .dsu_genuine_error
	  stx	%g0, [%g2]		! clear strand.io_error if set

	/*
	 * No error on access to DSU PA so we consider this a bogus error
	 */
	ba	.dsu_bogus_error
	nop

.verify_dsu_dram_banks_loop:
	! check next DRAM bank
	brgz,pt	%g3, .verify_dsu_dram_banks
	dec	%g3

	/*
	 * Nothing found in the DRAM ESRs, fall through and allow
	 * standard error handling to proceed
	 */

.dsu_genuine_error:
	/*
	 * strand.io_error was set, so the access to the DSU EAR caused
	 * another error, so this is a genuine DSU, (or no ESR.DSU bit
	 * set), so continue standard error processing
	 */
	STRAND_POP(%g7, %g2)
	ba,a	correct_l2_lda_common ! tail call
	.empty

.dsu_bogus_error:
	/*
	 * strand.io_error was not set, so the access to the DSU EAR
	 * did not cause another error, this is a bogus DSU, clean up and get out !
	 */
#ifdef DEBUG
	HV_PRINT_NOTRAP("Bogus DSU\r\n")
#endif

	/*
	 * Find the DRAM bank which got the DSU
	 */

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	set	(NO_DRAM_BANKS - 1), %g3
	add	%g1, ERR_DIAG_BUF_DRAM_ESR, %g2
	setx	(DRAM_ESR_MEU | DRAM_ESR_MEC | DRAM_ESR_DSU), %g5, %g4
0:
	mulx	%g3, ERR_DIAG_BUF_DRAM_ESR_INCR, %g5
	add	%g5, %g2, %g7
	ldx	[%g7], %g5		! DRAM ESR
	brz,pt	%g5, 1f
	andn	%g5, %g4, %g6		! clear out DSU/ME bits
	brz,pt	%g6, .dsu_bogus_single_error
	nop
	! multiple errors seen, DSU is bogus, clear DSU bit from ESR and
	! continue processing the error
	setx	DRAM_ESR_DSU, %g2, %g4
	andn	%g5, %g4, %g5
	stx	%g5, [%g7]
	STRAND_POP(%g7, %g2)
	HVRET
1:
	brz,pt	%g3, 0b
	dec	%g3


	/* NOTREACHED */

.dsu_bogus_single_error:

	HVCALL(clear_dram_l2c_esr_regs)

	/*
	 * Clear the error report in_use field
	 */
	GET_ERR_DIAG_BUF(%g4, %g5)
	brnz,a,pt	%g4, 1f
	  stub	%g0, [%g4 + ERR_DIAG_RPRT_IN_USE]
1:
	/*
	 * Clear the sun4v report in_use field
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g4, %g5)
	brnz,a,pt	%g4, 1f
	  stub	%g0, [%g4 + ERR_SUN4V_RPRT_IN_USE]
1:
	/*
	 * Does the trap handler for this error park the strands ?
	 * If yes, resume them here.
	 */
	GET_ERR_TABLE_ENTRY(%g1, %g2)
	ld	[%g1 + ERR_FLAGS], %g6
	btst	ERR_STRANDS_PARKED, %g6
	bz,pn	%xcc, 1f
	nop

	RESUME_ALL_STRANDS(%g2, %g3, %g5, %g4)
1:
	/*
	 * check whether we stored the globals and re-used
	 * at MAXPTL
	 */
	btst	ERR_GL_STORED, %g6
	bz,pt	%xcc, 1f
	nop

	RESTORE_GLOBALS(retry)
1:
	retry

	/* NOTREACHED */

	SET_SIZE(verify_dsu_error)


	/*
	 * DRAM / L2 ESR registers must be cleared after an error which
	 * occurred under protection as we will not go through the full
	 * error handling sequence for these errors. If the errors
	 * are not cleared further errors are blocked.
	 *
	 * Note: Erratum 116 requires FBD Syndrome register to be written
	 *	 twice to clear the value. Recommended to do this for all
	 *	 DRAM ESRs.
	 */
	ENTRY_NP(clear_dram_l2c_esr_regs)

	set	(NO_L2_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g6, 2f)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	ldx	[%g5 + %g4], %g6
	stx	%g6, [%g5 + %g4]	! L2 ESR RW1C
	stx	%g0, [%g5 + %g4]	! L2 ESR RW

	setx	L2_ERROR_ADDRESS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	stx	%g0, [%g5 + %g4]
2:
	brgz,pt	%g3, 1b
	dec	%g3

	set	(NO_DRAM_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g6, 2f)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	ldx	[%g5 + %g4], %g6
	stx	%g6, [%g5 + %g4]
	stx	%g6, [%g5 + %g4]		! DRAM ESR RW1C
	stx	%g0, [%g5 + %g4]
	stx	%g0, [%g5 + %g4]

	setx	DRAM_EAR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	stx	%g0, [%g5 + %g4]		! clear DRAM EAR RW
	stx	%g0, [%g5 + %g4]

	setx	DRAM_ELR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	stx	%g0, [%g5 + %g4]		! clear DRAM LOC RW
	stx	%g0, [%g5 + %g4]

	setx	DRAM_FBD_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	stx	%g0, [%g5 + %g4]		! clear FBD Syndrome register
	stx	%g0, [%g5 + %g4]
2:
	brgz,pt	%g3, 1b
	dec	%g3

	HVRET
	SET_SIZE(clear_dram_l2c_esr_regs)


#ifdef CONFIG_CLEANSER

	/*
	 * L2 cache cleanser
	 *
	 * %g1		next cache entry to clean (clobbered)
	 * %g2 - %g6	clobbered
	 * %g7		return address
	 */
	ENTRY(l2_cache_cleanser)

	STRAND_STRUCT(%g6)	
	STRAND2CONFIG_STRUCT(%g6, %g6)	
	ldx     [%g6 + CONFIG_L2SCRUB_ENTRIES], %g6	! config->l2scrub_entries
	brnz,pn	%g6, 1f
	srl	%g6, 0, %g6		! keep it sane, max number of lines

	! if #entries is 0, cleanser is disabled
	HVRET
	
1:
	STRAND_PUSH(%g7, %g2, %g3)	! save return address

	/*
	 * key:way:set:bank is only initialised if we enter with %g1 == 0.
	 * otherwise, %g1 is the index of the next entry to be cleansed
	 * and we continue from there.
	 */
	brnz,pn	%g1, l2_cache_cleanser_start
	mov	%g0, %g4

	! %g1 == 0, initialise L2 Cache PA

	setx	PREFETCHICE_KEY, %g2, %g1
	setx	PREFETCHICE_WAY_MAX, %g2, %g3
	or	%g1, %g3, %g1
	! %g1	key[39:37]:rsvd[36:22]:way[21:18]
	! rsvd is 0, no effect on index hashing

	/*
	 * Check which L2 cache banks are enabled
	 * Note: We need this value for the loop end calculation
	 *	 so we stash it in the top 32 bits of %g6, (the 
	 *	 scrub entries value).
	 */
	setx	L2_BANK_ENABLE, %g4, %g5
	ldx	[%g5], %g5
	srlx	%g5, L2_BANK_ENABLE_SHIFT, %g5
	and	%g5, L2_BANK_ENABLE_MASK, %g5

#define	STASH_BANK_ENABLE_MODE_SHIFT	32

	sllx	%g5, STASH_BANK_ENABLE_MODE_SHIFT, %g4
	or	%g6, %g4, %g6

	cmp	%g5, 0xff		! 8-bank mode
	be	%xcc, l2_cache_cleanser_8banks
	cmp	%g5, 0xf0		! 4-bank mode
	be	%xcc, l2_cache_cleanser_4banks
	cmp	%g5, 0xcc		! 4-bank mode
	be	%xcc, l2_cache_cleanser_4banks
	cmp	%g5, 0xc3		! 4-bank mode
	be	%xcc, l2_cache_cleanser_4banks
	cmp	%g5, 0x3c		! 4-bank mode
	be	%xcc, l2_cache_cleanser_4banks
	cmp	%g5, 0x33		! 4-bank mode
	be	%xcc, l2_cache_cleanser_4banks
	cmp	%g5, 0xf		! 4-bank mode
	be	%xcc, l2_cache_cleanser_4banks
	nop
	ba	l2_cache_cleanser_2banks
	.empty

l2_cache_cleanser_8banks:
	setx	PREFETCHICE_8BANK_SET_MAX, %g2, %g3
	! %g3	set[17:9]
	setx	PREFETCHICE_8BANK_MAX, %g2, %g4
	! %g4	bank[8:6]
	ba	l2_cache_cleanser_start
	or	%g4, %g3, %g4
	! %g4	set[17:9]:bank[8:6]

l2_cache_cleanser_4banks:
	setx	PREFETCHICE_4BANK_SET_MAX, %g2, %g3
	! %g3	set[16:8]
	setx	PREFETCHICE_4BANK_MAX, %g2, %g4
	! %g4	bank[7:6]
	ba	l2_cache_cleanser_start
	or	%g4, %g3, %g4
	! %g4	set[16:8]:bank[7:6]
	
l2_cache_cleanser_2banks:
	setx	PREFETCHICE_2BANK_SET_MAX, %g2, %g3
	! %g3	set[15:7]
	setx	PREFETCHICE_2BANK_MAX, %g2, %g4
	! %g4	bank[6]
	or	%g4, %g3, %g4
	! %g4	set[15:7]:bank[6]
	/* FALLTHRU */

l2_cache_cleanser_start:
	or	%g1, %g4, %g1		! %g1 key[39:37]:way[21:18]:set[17:9]:bank[8:6]

	! Check if L2 cache index hash enabled
	setx	L2_IDX_HASH_EN_STATUS, %g3, %g4
	ldx	[%g4], %g4
	and	%g4, L2_IDX_HASH_EN_STATUS_MASK, %g4

	! %g1	L2 Cache Entry	key:way:set:bank
	! %g4	Set if L2 index hashing is enabled
	! %g6	Number of entries to be cleansed

l2_cache_cleanser_check_ECC:
	/*
	 * Check ECC here. If there is a multi-bit
	 * error, generate an error report now and abort.
	 *
	 * use %g2, %g3, %g5, %g7 only
	 */
	set	L2_TAG_DIAG_SELECT, %g3
	sllx	%g3, L2_TAG_DIAG_SELECT_SHIFT, %g3
	! %g3	L2 Tag Diag Select

	! get way:set:bank bits[21:6] from %g1
	setx	L2_BANK_SET | (L2_WAY_MASK << L2_WAY_SHIFT), %g5, %g2
	and	%g1, %g2, %g2

	or	%g3, %g2, %g3	! %g3	select:way:set:bank
	ldx	[%g3], %g3	! %g3	tag[27:6]:ecc[5:0]

	/*
	 * Need to save the ECC bits for later, but we don't have a
	 * spare register. We know that %g4 has a single bit set,
	 * L2_IDX_HASH_EN_STATUS, so we will use a few of it's high
	 * bits.
	 */
#define	STASH_ECC_BITS_SHIFT		9

	and	%g3, L2_TAG_DIAG_ECC_MASK, %g7	! ecc
	sllx	%g7, STASH_ECC_BITS_SHIFT, %g7
	or	%g4, %g7, %g4

	! clear tag bits (63:28)
	set	L2_TAG_MASK, %g5
	and	%g3, %g5, %g3
	srlx	%g3, L2_TAG_SHIFT, %g3		! lose ecc bits[5:0], %g3 = tag

	/*
	 * return the checkbits for an integer 'tag'
	 * ('tag' is the tag bits, right-justified; unused high-order bits are zero)
	 *
	 *	uint64_t
	 *	calc_ecc(uint64_t tag)
	 *	{
	 *		ecc_syndrome_table_entry *ep;
	 *		uint64_t ecc;
	 *	
	 *		for (ep = &l2_tag_ecc_table[0], ecc = 0;
	 *		    tag != 0; ep++, x >>= 1) {
	 *			if (tag & 1)
	 *				ecc ^= *ep;
	 *		}
	 *		return (ecc);
	 *	}
	 */

	setx	l2_tag_ecc_table, %g7, %g5
	RELOC_ADDR(%g5, %g7)		! %g5   ep = &l2_tag_ecc_table[0]
	mov	%g0, %g7		! %g7	ecc = 0
1:
	btst	1, %g3			! if (tag & 1)
	bz,pn	%xcc, 2f
	nop
	ldub	[%g5], %g2		! %g2 	*ep
	xor	%g7, %g2, %g7		! ecc ^= *ep

2:
	srlx	%g3, 1, %g3		! tag >> 1
	brnz,pt	%g3, 1b			!  tag != 0
	add	%g5, ECC_SYNDROME_TABLE_ENTRY_SIZE, %g5		! ep++

	! %g7	calculated ECC

	! get the ECC from the diagnostic register
	! from where we stashed it in (%g4 << STASH_ECC_BITS_SHIFT)
	srlx	%g4, STASH_ECC_BITS_SHIFT, %g3		! ecc from diag reg
	and	%g3, L2_TAG_DIAG_ECC_MASK, %g3


	! %g3	ECC from diagnostic register
	! %g7	calculated ECC
	xor	%g7, %g3, %g7
	brz,pt	%g7, l2_cache_cleanser_ECC_OK	! no error
	.empty	

	/*
	 * single-bit or check-bit error. PrefetchICE should
	 * clean it out.
	 */
	! %g4	L2 cache index hashing if set
	and	%g4, L2_IDX_HASH_EN_STATUS_MASK, %g4	! restore %g4
	brz,pn	%g4, l2_cache_cleanser_prefetch
	mov	%g1, %g5

	/*
	 * index hashing is enabled
	 * PA[17:11] = PA[32:28] XOR PA[17:13] | PA[19:18] XOR PA[12:11]
	 */
	N2_PERFORM_IDX_HASH(%g5, %g2, %g3)
	
l2_cache_cleanser_prefetch:

	/*
	 * Invalidate the cache entry (%g5)
	 */
        prefetch [%g5], INVALIDATE_CACHE_LINE

l2_cache_cleanser_ECC_OK:

	/*
	 * To simplify matters, we will abort the loop when %g1,
	 * the last cache index cleaned, is 0. This will restart
	 * the cleanser with (index == 0) which will
	 * re-initialise everything cleanly for us.
	 */
	setx	PREFETCHICE_KEY, %g3, %g7
	andn	%g5, %g7, %g7
	brz,a,pn	%g7, l2_cache_cleanser_exit
	  mov	%g0, %g1
	dec	L2_LINE_SIZE, %g1		! %g1	next cache index

	! remember we stashed the bank enable value in the top
	! STASH_BANK_ENABLE_MODE_SHIFT (32) bits of %g6
	! so we need to clear it before checking (l2scrub_entries-- == 0)
	srl	%g6, 0, %g3
	brz,pn %g3, l2_cache_cleanser_exit	! %g3 	l2scrub_entries
	dec	%g6				! %g6	(bank_enable << 32 | l2scrub_entries)

	! fix up the set:bank
	! again, remember we stashed the bank enable value in the top
	! STASH_BANK_ENABLE_MODE_SHIFT (32) bits of %g6
	srlx	%g6, STASH_BANK_ENABLE_MODE_SHIFT, %g3		! bank enable mode
	cmp	%g3, 0xff			! 8-bank mode
	be	%xcc, 1f
	cmp	%g3, 0xf0			! 4-bank mode
	be	%xcc, 2f
	cmp	%g3, 0xcc			! 4-bank mode
	be	%xcc, 2f
	cmp	%g3, 0xc3			! 4-bank mode
	be	%xcc, 2f
	cmp	%g3, 0x3c			! 4-bank mode
	be	%xcc, 2f
	cmp	%g3, 0x33			! 4-bank mode
	be	%xcc, 2f
	cmp	%g3, 0xf			! 4-bank mode
	be	%xcc, 2f
	nop
	ba	3f
	.empty
1:
	setx	PREFETCHICE_8BANK_SET_MAX, %g2, %g3
	! %g3	set[17:9]
	setx	PREFETCHICE_8BANK_MAX, %g2, %g7
	! %g7	bank[8:6]
	ba	4f
	or	%g7, %g3, %g7
	! %g7	set[17:9]:bank[8:6]

2:
	setx	PREFETCHICE_4BANK_SET_MAX, %g2, %g3
	! %g3	set[16:8]
	setx	PREFETCHICE_4BANK_MAX, %g2, %g7
	! %g7	bank[7:6]
	ba	4f
	or	%g7, %g3, %g7
	! %g7	set[16:8]:bank[7:6]
	
3:
	setx	PREFETCHICE_2BANK_SET_MAX, %g2, %g3
	! %g3	set[15:7]
	setx	PREFETCHICE_2BANK_MAX, %g2, %g7
	! %g7	bank[6]
	or	%g7, %g3, %g7
	! %g7	set[15:7]:bank[6]

4:
	! clean up %g1 (key:way:set:bank)
	! with bank mode enabled mask (%g7 set:bank mask)
	setx	PREFETCHICE_WAY_MAX, %g2, %g3
	or	%g7, %g3, %g7		! way:set:bank mask for bank mode enabled
	setx	PREFETCHICE_KEY, %g2, %g3
	or	%g7, %g3, %g7		! key:way:set:bank mask for bank mode enabled

	and	%g1, %g7, %g1		! %g1	key:way:set:bank

	! next line
	ba	l2_cache_cleanser_check_ECC
	nop

l2_cache_cleanser_exit:

	STRAND_POP(%g7, %g2)		! reload return address
	! set up cyclic for next invocation
	! %g1	next entry to be cleaned
	ba	l2_cache_cleanser_setup
	nop
	/*NOTREACHED*/

	SET_SIZE(l2_cache_cleanser)

	/*
	 * This function initialises the L2 cache cleanser at startup,
	 * and also rearms the cyclic after each invocation, (see
	 * l2_cache_cleanser() above).
	 *
	 * %g1		last entry cleaned (clobbered)
	 * %g2 - %g6	clobbered
	 * %g7		return address
	 */
	ENTRY(l2_cache_cleanser_setup)
	STRAND_STRUCT(%g6)				! %g6 strand struct
	brz,pn	%g6, 1f
	nop
	STRAND2CONFIG_STRUCT(%g6, %g5)
	brz,pn	%g5, 1f
	nop
	ldx     [%g5 + CONFIG_L2SCRUB_INTERVAL], %g5
	! if interval is 0, cleanser is disabled
	brz,pn	%g5, 1f
	nop
	setx	l2_cache_cleanser, %g4, %g2
	RELOC_ADDR(%g2, %g4)			! %g2 = handler address
	mov	%g1, %g3			! %g3 = arg 0 : last entry cleaned
	VCPU_STRUCT(%g6)
	ba	cyclic_add_rel			! tail call
	mov	%g5, %g1			! %g1 = delta tick
	/* NOTREACHED*/
1:
	HVRET
	SET_SIZE(l2_cache_cleanser_setup)

#endif /* CONFIG_CLEANSER */

#ifdef TEST_ERRORS
	/*
	 * Inject errors
	 */
	ENTRY(inject_l2_errors)
	STORE_ERR_RETURN_ADDR(%g7, %g3, %g4)
	set	(NO_L2_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, 2f)

	mov	%g3, %g6
	PRINT_NOTRAP("Active Bank : ");
	mov	%g6, %g3
	PRINTX(%g3)
	PRINT_NOTRAP("\r\n");
	mov	%g6, %g3

	! L2 Cache LRF error
	! will cause a non-resumable error report to guest

	setx	L2_ERROR_INJECTOR, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g5, %g4, %g5
	set	(L2_ERROR_INJECTOR_ENB_HP), %g4
	stx	%g4, [%g5]
2:
	brgz,pt	%g3, 1b
	dec	%g3

	set	(NO_DRAM_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 2f)

	! cause DAC and resumable error report to guest
	setx	DRAM_EIR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g5
	set	((1 << 31) | 1), %g4
	stx	%g4, [%g5]
2:
	brgz,pt	%g3, 1b
	dec	%g3

	GET_ERR_RETURN_ADDR(%g7, %g3, %g4)
	HVRET

	SET_SIZE(inject_l2_errors)
#endif /* TEST_ERRORS */
