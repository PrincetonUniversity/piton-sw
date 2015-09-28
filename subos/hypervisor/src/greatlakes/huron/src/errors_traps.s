/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_traps.s
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

#pragma ident	"@(#)errors_traps.s	1.7	07/08/17 SMI"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <sun4v/traps.h>

#include <offsets.h>
#include <util.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_asm.h>
#include <error_soc.h>
#include <error_ssi.h>
#include <cmp.h>


	/*
	 * %g1	I-SFSR
	 */
	ENTRY(instruction_access_MMU_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	SAVE_GLOBALS(%g1)

	PARK_ALL_STRANDS(%g2, %g3, %g4, %g5)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	/*
	 * Identify the error from the I-SFSR and get the
	 * instruction_access_MMU_errors[] entry for that error
	 */
	mov	MMU_SFAR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFAR(%g1, %g3, %g4)
	mov	MMU_SFSR, %g2
	ldxa	[%g2]ASI_IMMU, %g1
	STORE_ERR_ISFSR(%g1, %g3, %g4)
	stxa	%g0, [%g2]ASI_IMMU

	and	%g1, ISFSR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	setx	instruction_access_MMU_errors, %g2, %g3
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

	SET_SIZE(instruction_access_MMU_error)

	/*
	 * %g1	D-SFSR
	 */
	ENTRY(data_access_MMU_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	SAVE_GLOBALS(%g1)

	PARK_ALL_STRANDS(%g2, %g3, %g4, %g5)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	/*
	 * Identify the error from the D-SFSR and get the
	 * data_access_MMU_errors[] entry for that error
	 */
	mov	MMU_SFAR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFAR(%g1, %g3, %g4)
	mov	MMU_SFSR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFSR(%g1, %g3, %g4)
	stxa	%g0, [%g2]ASI_DMMU

	and	%g1, DSFSR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	setx	data_access_MMU_errors, %g2, %g3
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

	SET_SIZE(data_access_MMU_error)

	/*
	 * No args
	 */
	ENTRY(internal_processor_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	SAVE_GLOBALS(%g1)

	SCRATCHPAD_ERROR()

	PARK_ALL_STRANDS(%g2, %g3, %g4, %g5)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	mov	MMU_SFAR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFAR(%g1, %g3, %g4)
	mov	MMU_SFSR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFSR(%g1, %g3, %g4)
	stxa	%g0, [%g2]ASI_DMMU

	/*
	 * Identify the error from the D-SFSR and get the
	 * internal_processor_errors[] entry for that error
	 */
	and	%g1, DSFSR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	setx	internal_processor_errors, %g2, %g3
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

	SET_SIZE(internal_processor_error)

	/*
	 * Common routine for both hw_corrected and
	 * sw_recoverable traps.
	 *
	 * No args
	 */
	ENTRY(hw_corrected_error)
	ALTENTRY(sw_recoverable_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	/*
	 * Identify the error from the DESR and get the
	 * correct errors table[] entry for that error
	 */
	mov	DESR_VA, %g1
	ldxa	[%g1]ASI_DESR, %g1

	/*
	 * Note: Reading the DESR will clear the register. We need
	 * to store it for later use by the error handler.
	 */
	STORE_ERR_DESR(%g1, %g3, %g4)

	setx	DESR_S, %g2, %g3
	btst	%g3, %g1
	bz	%xcc, 1f
	nop

	setx	sw_recoverable_errors, %g2, %g3
	ba	2f
	nop
1:
	setx	hw_corrected_errors, %g2, %g3
2:
	srlx	%g1, DESR_ERRTYPE_SHIFT, %g1
	and	%g1, DESR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1

	ba	common_correctable_errors
	nop
	
	SET_SIZE(sw_recoverable_error)
	SET_SIZE(hw_corrected_error)

	! %g1	error table entry
	ENTRY(common_correctable_errors)

	/*
	 * Check if we need to differentiate between L2 Cache and DRAM
	 * uncorrectable/correctable errors for this error type.
	 * Check if this is an L2$ error and we need to use
	 * the L2 error table
	 */
	ld	[%g1 + ERR_FLAGS], %g2
	set	ERR_CHECK_DAU_TYPE, %g3
	btst	%g3, %g2
	bnz,pn	%xcc, common_l2u_errors
	.empty	
	btst	ERR_USE_L2_CACHE_TABLE, %g2
	bnz,pn	%xcc, 0f 
	nop
	btst	ERR_USE_SOC_TABLE, %g2
	bnz,pn	%xcc, 3f 
	nop
	set	ERR_USE_DRAM_TABLE, %g3
	btst	%g3, %g2
	bnz,pn	%xcc, 4f 
	nop

	ba,pt	%xcc, error_handler
	nop

	! check L2 ESRs
0:
	/*
	 * Find the bank/ESR in error
	 */
	setx	(L2_ESR_VEU | L2_ESR_VEC | L2_ESR_DSC | L2_ESR_DSU), %g3, %g2
	set	(NO_L2_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, 2f)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	btst	%g2, %g5
	bz,pt	%xcc, 2f		! no valid error on this bank
	nop

	setx	L2_ESR_ERRORS, %g4, %g6
	and	%g5, %g6, %g5
	brz,pt	%g5, 2f			! no error bit set on this bank

	/*
	 * find first bit set in L2 ESR
	 */
	srlx	%g5, L2_ESR_ERROR_SHIFT, %g5
	neg	%g5, %g4
	xnor	%g5, %g4, %g6
	popc	%g6, %g4
	dec	%g4
	movrz	%g5, %g0, %g4
	mulx	%g4, ERROR_TABLE_ENTRY_SIZE, %g4
	setx	l2c_errors, %g2, %g3
	add	%g4, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1

	! some L2C errors are DRAM errors ...
	setx	ERR_USE_DRAM_TABLE, %g4, %g5
	ld	[%g1 + ERR_FLAGS], %g2
	btst	%g5, %g2
	bnz,pn	%xcc, 4f		! check DRAM ESRs
	nop

	ba	error_handler
	nop
2:
	brgz,pt	%g3, 1b
	dec	%g3

3:
	/*
	 * Check if this is an SOC error and we need to use
	 * the SOC error table
	 */
	setx	SOC_PENDING_ERROR_STATUS_REG, %g4, %g5
	ldx	[%g5], %g5
	brz,pn	%g5, 4f
	nop

	/*
	 * find first bit set in SOC ESR
	 */
	neg	%g5, %g4
	xnor	%g5, %g4, %g6
	popc	%g6, %g4
	dec	%g4
	movrz	%g5, %g0, %g4
	mulx	%g4, ERROR_TABLE_ENTRY_SIZE, %g4
	setx	soc_errors, %g2, %g3
	add	%g4, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop	

	! check DRAM errors
4:
	set	(NO_DRAM_BANKS - 1), %g3
5:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 6f)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g5, %g2, %g5
	ldx	[%g5], %g5
	brz,pt	%g5, 6f		! no error on this bank
	nop

	/*
	 * find first bit set in DRAM ESR
	 */
	srlx	%g5, DRAM_ESR_ERROR_SHIFT, %g5
	neg	%g5, %g4
	xnor	%g5, %g4, %g6
	popc	%g6, %g4
	dec	%g4
	movrz	%g5, %g0, %g4
	mulx	%g4, ERROR_TABLE_ENTRY_SIZE, %g4
	setx	dram_errors, %g2, %g3
	add	%g4, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop
6:

	brgz,pt	%g3, 5b
	dec	%g3

	! No error found - we cleared the L2 ESR out on an earlier trap
	retry

	SET_SIZE(common_correctable_errors)

	ENTRY(data_access_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	SAVE_GLOBALS(%g2)

	PARK_ALL_STRANDS(%g2, %g3, %g4, %g5)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	/*
	 * First check for DBU errors
	 */
	setx	DRAM_ESR_BASE, %g4, %g5
	setx	DRAM_ESR_DBU, %g4, %g2
	set	(NO_DRAM_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g6, 2f)

	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g4
	btst	%g2, %g4	! check for DBU
	bz,pt	%xcc, 2f
	nop

	setx	dbu_errors, %g2, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop
2:

	brgz,pt	%g3, 1b
	dec	%g3

        /*
         * Identify the error from the D-SFSR and get the
         * data_access_errors[] entry for that error
         */
	mov	MMU_SFAR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFAR(%g1, %g3, %g4)
	mov	MMU_SFSR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFSR(%g1, %g3, %g4)
	stxa	%g0, [%g2]ASI_DMMU

	and	%g1, DSFSR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	setx	data_access_errors, %g2, %g3
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1

	ld	[%g1 + ERR_FLAGS], %g2
	set	ERR_CHECK_DAU_TYPE, %g3
	btst	%g3, %g2
	bnz,pn	%xcc, common_l2u_errors
	nop

	ba	error_handler
	nop	
	
	SET_SIZE(data_access_error)

	/*
	 * deferred store_error trap
	 */
	ENTRY(store_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	SAVE_GLOBALS(%g1)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	/*
	 * Identify the error from the DFESR and get the
	 * store_errors[] entry for that error
	 */
	mov	DFESR_VA, %g1
	ldxa	[%g1]ASI_DFESR, %g1

	/*
	 * Note: Reading the DFESR will clear the register. We need
	 * to store it for later use by the error handler.
	 */
	STORE_ERR_DFESR(%g1, %g3, %g4)

	srlx	%g1, DFESR_ERRTYPE_SHIFT, %g1
	and	%g1, DFESR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	setx	store_errors, %g2, %g3
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

	SET_SIZE(store_error)

	/*
	 * %g1	I-SFSR
	 */
	ENTRY(instruction_access_error)

	CLEAR_SOC_INJECTOR_REG(%g2, %g3)

	SAVE_GLOBALS(%g2)

	PARK_ALL_STRANDS(%g2, %g3, %g4, %g5)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	/*
	 * First check for DBU errors
	 */
	setx	DRAM_ESR_DBU, %g4, %g2
	set	(NO_DRAM_BANKS - 1), %g3
	setx	DRAM_ESR_BASE, %g4, %g5
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g6, 2f)

	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g4
	btst	%g2, %g4	! check for DBU
	bz,pt	%xcc, 2f
	nop

	setx	dbu_errors, %g2, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop
2:

	brgz,pt	%g3, 1b
	dec	%g3

	mov	MMU_SFAR, %g2
	ldxa	[%g2]ASI_DMMU, %g1
	STORE_ERR_DSFAR(%g1, %g3, %g4)
	mov	MMU_SFSR, %g2
	ldxa	[%g2]ASI_IMMU, %g1
	STORE_ERR_ISFSR(%g1, %g3, %g4)
	stxa	%g0, [%g2]ASI_IMMU

	and	%g1, ISFSR_ERRTYPE_MASK, %g1
	mulx	%g1, ERROR_TABLE_ENTRY_SIZE, %g1
	setx	instruction_access_errors, %g4, %g3
	add	%g1, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1

	ld	[%g1 + ERR_FLAGS], %g2
	set	ERR_CHECK_DAU_TYPE, %g3
	btst	%g3, %g2
	bnz,pn	%xcc, common_l2u_errors
	nop

	ba	error_handler
	nop
	
	SET_SIZE(instruction_access_error)

	/*
	 * SSI error interrupt handler
	 */
	ENTRY(ssi_mondo)

	! clear cached copy of ESRs from strand struct
	STORE_ERR_DESR(%g0, %g3, %g4)
	STORE_ERR_DFESR(%g0, %g3, %g4)
	STORE_ERR_DSFSR(%g0, %g3, %g4)
	STORE_ERR_DSFAR(%g0, %g3, %g4)
	STORE_ERR_ISFSR(%g0, %g3, %g4)

	setx	SSI_LOG, %g2, %g1
	ldx	[%g1], %g1
	and	%g1, SSI_LOG_MASK, %g1
	brnz,pn	%g1, 1f
	nop

	! no error bits set

	retry

1:

	/*
	 * find first bit set in SSI LOG
	 */
	neg	%g1, %g2
	xnor	%g1, %g2, %g6
	popc	%g6, %g2
	dec	%g2
	movrz	%g1, %g0, %g2
	mulx	%g2, ERROR_TABLE_ENTRY_SIZE, %g2
	setx	ssi_errors, %g4, %g3
	add	%g2, %g3, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

	SET_SIZE(ssi_mondo)

	/*
	 * Check if this is an LDAU or DAU error
	 * %g1	error table entry
	 */
	ENTRY(common_l2u_errors)

	/*
	 * Find the bank/ESR in error
	 */
	setx	L2_ESR_LDAU, %g3, %g2
	set	(NO_L2_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, 4f)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g5, %g4, %g5
	ldx	[%g5], %g5

	btst	%g2, %g5
	bz,pt	%xcc, 4f		! no valid LDAU error on this bank
	nop

	rdpr	%tt, %g2
	cmp	%g2, TT_ASYNCERR
	bne	%xcc, 2f
	nop

	setx	disrupting_ldau_errors, %g2, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

2:
	setx	precise_ldau_errors, %g2, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop
4:
	brgz,pt	%g3, 1b
	dec	%g3

	/*
	 * Check if this is an DAU error 
	 */
	setx	DRAM_ESR_DAU, %g3, %g2
	set	(NO_DRAM_BANKS - 1), %g3
5:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 7f)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g5
	ldx	[%g5], %g5

	btst	%g2, %g5
	bz	%xcc, 7f
	nop

	rdpr	%tt, %g2
	cmp	%g2, TT_ASYNCERR
	bne	%xcc, 6f
	nop

	setx	disrupting_dau_errors, %g2, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop

6:
	setx	precise_dau_errors, %g2, %g1
	RELOC_OFFSET(%g6, %g5)
	sub	%g1, %g5, %g1
	ba	error_handler
	nop
7:

	brgz,pt	%g3, 5b
	dec	%g3

	ba	error_handler
	nop

	SET_SIZE(common_l2u_errors)
