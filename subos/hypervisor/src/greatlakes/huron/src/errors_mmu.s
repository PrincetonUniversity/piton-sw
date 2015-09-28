/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_mmu.s
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

#pragma ident	"@(#)errors_mmu.s	1.3	07/07/19 SMI"

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
#include <debug.h>

	ENTRY(dtlb_dump)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * Avoid causing errors when reading the TLB registers
	 */
	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g3
	setx	(ERR_DTDP | ERR_DTTM | ERR_DTTP | ERR_HWTWMU), %g4, %g6
	andn	%g3, %g6, %g3
	stxa	%g3, [%g5]ASI_ERR_EN

	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_DTLB, %g1
	/*
	 * now store the DTLB tag/data entries
	 */
	set	0, %g3				/* TLB entry = 0 */
1:	ldxa	[%g3] ASI_DTLB_TAG, %g6		/* Tag */
	stx	%g6, [%g1 + ERR_TLB_TAG] /* save tag */	
	ldxa	[%g3] ASI_DTLB_DATA_ACC, %g6		/* Tag */
	stx	%g6, [%g1 + ERR_TLB_DATA]	
	add	%g3, 0x8, %g3			/* entry++ */
	cmp	%g3, 0x400			/* done? */
	bnz	1b				/* loop back */
	add	%g1, ERR_DIAG_DATA_DTLB_INCR, %g1 	/* increment */	

	/*
	 * Re-enable TLB errors
	 */
	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g3
	setx	(ERR_DTDP | ERR_DTTM | ERR_DTTP | ERR_HWTWMU), %g4, %g6
	or	%g3, %g6, %g3
	stxa	%g3, [%g5]ASI_ERR_EN

	HVRET
	SET_SIZE(dtlb_dump)

	ENTRY(dtlb_demap_all)

	set	TLB_DEMAP_ALL_TYPE, %g3
	stxa	%g0, [%g3]ASI_DMMU_DEMAP

	HVRET
	SET_SIZE(dtlb_demap_all)

	ENTRY(itlb_dump)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * Avoid causing errors when reading the TLB registers
	 */
	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g3
	setx	(ERR_ITDP | ERR_ITTM | ERR_ITTP | ERR_HWTWMU), %g4, %g6
	andn	%g3, %g6, %g3
	stxa	%g3, [%g5]ASI_ERR_EN

	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_ITLB, %g1

	set	0, %g3				/* TLB entry = 0 */
1:	ldxa	[%g3] ASI_ITLB_TAG, %g6		/* Tag */
	stx	%g6, [%g1 + ERR_TLB_TAG] /* save tag */	
	ldxa	[%g3] ASI_ITLB_DATA_ACC, %g6		/* Tag */
	stx	%g6, [%g1 + ERR_TLB_DATA]	
	add	%g3, 0x8, %g3			/* entry++ */
	cmp	%g3, 0x200			/* done? */
	bnz	1b				/* loop back */
	add	%g1, ERR_DIAG_DATA_ITLB_INCR, %g1 	/* increment */	

	/*
	 * Re-enable TLB errors
	 */
	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g3
	setx	(ERR_ITDP | ERR_ITTM | ERR_ITTP | ERR_HWTWMU), %g4, %g6
	or	%g3, %g6, %g3
	stxa	%g3, [%g5]ASI_ERR_EN

	HVRET

	SET_SIZE(itlb_dump)

	ENTRY(itlb_demap_all)
	set	TLB_DEMAP_ALL_TYPE, %g3
	stxa	%g0, [%g3]ASI_IMMU_DEMAP

	HVRET
	SET_SIZE(itlb_demap_all)

	/*
	 * Dump MRA diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_mra)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	brz,pn	%g1, dump_mra_exit_nocerer
	.empty

	GET_ERR_DSFAR(%g4, %g5)

	/*
	 * get diag_buf->err_mmu_regs
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_MMU_REGS, %g1

	/*
	 * get MRA index from D-SFAR[2:0]
	 */
	srlx	%g4, DSFAR_MRA_INDEX_SHIFT, %g4
	and	%g4, DSFAR_MRA_INDEX_MASK, %g4

	/*
	 * Avoid causing errors when reading the MMU registers
	 * by disabling CERER.MRAU
	 */
	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g3
	setx	ERR_MRAU, %g2, %g6
	andn	%g3, %g6, %g3
	stxa	%g3, [%g5]ASI_ERR_EN

	/*
	 * get MRA Parity
	 */	
	sllx    %g4, ASI_MRA_INDEX_SHIFT, %g3	
	ldxa    [%g3]ASI_MRA_ACCESS, %g3
	and     %g3, MRA_PARITY_MASK, %g3

	/*
	 * store MRA parity
	 */
	add	%g1, ERR_MMU_PARITY, %g2
	mulx	%g4, ERR_MMU_PARITY_INCR, %g4	
	stub	%g3, [%g2 + %g4]	

	/*
	 * store MMU registers
	 */
	mov	TSB_CFG_CTX0_0, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 0)]
	mov	TSB_CFG_CTX0_1, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 1)]
	mov	TSB_CFG_CTX0_2, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 2)]
	mov	TSB_CFG_CTX0_3, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 3)]
	mov	TSB_CFG_CTXN_0, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 0)]
	mov	TSB_CFG_CTXN_1, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 1)]
	mov	TSB_CFG_CTXN_2, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 2)]
	mov	TSB_CFG_CTXN_3, %g4
	ldxa	[%g4]ASI_MMU_TSB, %g4
	stx	%g4, [%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 3)]
	mov	MMU_REAL_RANGE_0, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 0)]
	mov	MMU_REAL_RANGE_1, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 1)]
	mov	MMU_REAL_RANGE_2, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 2)]
	mov	MMU_REAL_RANGE_3, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 3)]
	mov	MMU_PHYS_OFF_0, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 0)]
	mov	MMU_PHYS_OFF_1, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 1)]
	mov	MMU_PHYS_OFF_2, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 2)]
	mov	MMU_PHYS_OFF_3, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g4
	stx	%g4, [%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 3)]

	/*
	 * reenable CERER.MRAU
	 */
	mov	CORE_ERR_REPORT_EN, %g5
	ldxa	[%g5]ASI_ERR_EN, %g3
	setx	ERR_MRAU, %g4, %g6
	or	%g3, %g6, %g3
	stxa	%g3, [%g5]ASI_ERR_EN

dump_mra_exit_nocerer:

	HVRET

	SET_SIZE(dump_mra)

	/*
	 * Fix MMU register array parity errors
	 * %g7	return address
	 */
	ENTRY(correct_imra)
	ba	correct_mra_common
	nop
	SET_SIZE(correct_imra)

	ENTRY(correct_dmra)
	ba	correct_mra_common
	nop
	SET_SIZE(correct_dmra)

	ENTRY(correct_mra_common)
	/*
	 * Disable MRA errors
	 */
	mov	CORE_ERR_REPORT_EN, %g3
	ldxa	[%g3]ASI_ERR_EN, %g4
	setx	ERR_MRAU, %g5, %g6
	andn	%g4, %g6, %g6
	stxa	%g6, [%g3]ASI_ERR_EN
	
	/*
	 * Get error MRA index from D-SFAR[2:0]
	 * %g2: MRA error index 0->7
	 */
	GET_ERR_DSFAR(%g2, %g3)
	srlx	%g2, DSFAR_MRA_INDEX_SHIFT, %g2
	and	%g2, DSFAR_MRA_INDEX_MASK, %g2
	
	/*
	 * Reload the error MRA register with the clean MRA data.
	 *
	 * Since there are 8 MRA entries with their clean data 
	 * stored in 16 arrays in the strand struct (strand.mra[0->15]),
	 * to reload 2 registers for each MRA entry 0->7, we loop
	 * through index 0->15 twice, first looping on the even 
         * indices, then the odd ones for the second round.
	 *
	 *   %g3: strand.mra index 0->15
	 *   %g4: clean copy from strand.mra	 	  
	 *
	 */
	STRAND_STRUCT(%g1)
	mulx	%g2, 2, %g3		! start with an even index
1:
	/*
	 * MRA index 0->3: MMU z/nz_tsb_cfg 
	 * MRA index 4->7: MMU real_range/physical_offset 
	 */
	cmp	%g3, 7
	bg	2f
	nop

        mulx	%g3, STRAND_MRA_INCR, %g5
        add	%g5, STRAND_MRA, %g5
        ldx     [%g1 + %g5], %g4

	cmp	%g3, 0
	move	%xcc, TSB_CFG_CTX0_0, %g5
	cmp	%g3, 1
	move	%xcc, TSB_CFG_CTX0_1, %g5
	cmp	%g3, 2
	move	%xcc, TSB_CFG_CTX0_2, %g5
	cmp	%g3, 3
	move	%xcc, TSB_CFG_CTX0_3, %g5
	cmp	%g3, 4
	move	%xcc, TSB_CFG_CTXN_0, %g5
	cmp	%g3, 5
	move	%xcc, TSB_CFG_CTXN_1, %g5
	cmp	%g3, 6
	move	%xcc, TSB_CFG_CTXN_2, %g5
	cmp	%g3, 7
	move	%xcc, TSB_CFG_CTXN_3, %g5
	stxa	%g4, [%g5]ASI_MMU_TSB
	btst	1, %g3			! index&1 ?
	bz,pt 	%icc, 1b		
	  add	%g3, 1, %g3		! loop back on odd indices

	ba	correct_mra_exit
	nop
2:	
	/*
	 * For errors in the MMU Real Range/Offset registers we just
	 * clear the Real Range register. Then we will take an
	 * invalid_TSB_entry trap and refill the registers
	 */
	cmp	%g3, 8
	move	%xcc, MMU_REAL_RANGE_0, %g5
	cmp	%g3, 9		! PHYS_OFFSET_0
	move	%xcc, MMU_REAL_RANGE_0, %g5
	cmp	%g3, 10
	move	%xcc, MMU_REAL_RANGE_1, %g5
	cmp	%g3, 11		! PHYS_OFFSET_1
	move	%xcc, MMU_REAL_RANGE_1, %g5
	cmp	%g3, 12
	move	%xcc, MMU_REAL_RANGE_2, %g5
	cmp	%g3, 13		! PHYS_OFFSET_2
	move	%xcc, MMU_REAL_RANGE_2, %g5
	cmp	%g3, 14
	move	%xcc, MMU_REAL_RANGE_3, %g5
	cmp	%g3, 15		! PHYS_OFFSET_3
	move	%xcc, MMU_REAL_RANGE_3, %g5
	stxa	%g0, [%g5]ASI_MMU_HWTW
	btst	1, %g3			! index&1 ?
	bz,pt 	%icc, 1b 
	  add	%g3, 1, %g3		! loop back on odd indices
	
correct_mra_exit:	
        /*
         * Set CORE_ERR_ENABLE back to original
         */
	mov	CORE_ERR_REPORT_EN, %g3
	ldxa	[%g3]ASI_ERR_EN, %g4
	setx	ERR_MRAU, %g5, %g6
	or	%g4, %g6, %g4
	stxa	%g4, [%g3]ASI_ERR_EN
		
	HVRET
	SET_SIZE(correct_mra_common)

	/*
	 * print the contents of the diag-buf I-TLB
	 * %g7	return address
	 */
	ENTRY(itlb_print)
#ifdef DEBUG_LEGION
	mov	%g7, %g6
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_ITLB, %g1
	mov	0, %g3
1:
	PRINT("I-TLB entry: 0x");
	srlx	%g3, 3, %g4
	PRINTX(%g4)
	PRINT(" : TAG : 0x")
	ldx	[%g1 + ERR_TLB_TAG], %g4
	PRINTX(%g4)
	PRINT(" : DATA : 0x")
	ldx	[%g1 + ERR_TLB_DATA], %g4	
	PRINTX(%g4)
	PRINT("\r\n")
	add	%g3, 0x8, %g3			/* entry++ */
	cmp	%g3, 0x200			/* done? */
	bnz	1b				/* loop back */
	add	%g1, ERR_DIAG_DATA_ITLB_INCR, %g1 	/* increment */	

	mov	%g6, %g7
#endif	/* DEBUG */

	HVRET
	SET_SIZE(itlb_print)

	/*
	 * print the contents of the diag-buf D-TLB
	 * %g7	return address
	 */
	ENTRY(dtlb_print)
#ifdef DEBUG_LEGION
	mov	%g7, %g6
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_DTLB, %g1
	mov	0, %g3
1:
	PRINT("D-TLB entry: 0x");
	srlx	%g3, 3, %g4
	PRINTX(%g4)
	PRINT(" : TAG : 0x")
	ldx	[%g1 + ERR_TLB_TAG], %g4
	PRINTX(%g4)
	PRINT(" : DATA : 0x")
	ldx	[%g1 + ERR_TLB_DATA], %g4	
	PRINTX(%g4)
	PRINT("\r\n")
	add	%g3, 0x8, %g3			/* entry++ */
	cmp	%g3, 0x400			/* done? */
	bnz	1b				/* loop back */
	add	%g1, ERR_DIAG_DATA_DTLB_INCR, %g1 	/* increment */	

	mov	%g6, %g7
#endif	/* DEBUG */

	HVRET
	SET_SIZE(dtlb_print)

	/*
	 * print the failing MRA data
	 * %g7	return address
	 */
	ENTRY(mra_print)
#ifdef DEBUG_LEGION
	mov	%g7, %g6
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err_mmu_regs
	 */	
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_MMU_REGS, %g1

	PRINT("PARITY 0:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("PARITY 1:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("PARITY 2:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("PARITY 3:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("PARITY 4:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 4)], %g2
	PRINTX(%g2)
	PRINT("PARITY 5:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 5)], %g2
	PRINTX(%g2)
	PRINT("PARITY 6:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 6)], %g2
	PRINTX(%g2)
	PRINT("PARITY 7:	0x")
	ldub	[%g1 + ERR_MMU_PARITY + (ERR_MMU_PARITY_INCR * 7)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTX0_0: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTX0_1: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTX0_2: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTX0_3: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTX0 + (ERR_MMU_TSB_CFG_CTX0_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTXNZ_0: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTXNZ_1: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTXNZ_2: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\nTSB_CFG_CTXNZ_3: 0x")
	ldx	[%g1 + ERR_MMU_TSB_CFG_CTXNZ + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\nREAL_RANGE_0: 0x")
	ldx	[%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\nREAL_RANGE_1: 0x")
	ldx	[%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\nREAL_RANGE_2: 0x")
	ldx	[%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_REAL_RANGE_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\nREAL_RANGE_3: 0x")
	ldx	[%g1 + ERR_MMU_REAL_RANGE + (ERR_MMU_TSB_CFG_CTXNZ_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\nPHYS_OFFSET_0: 0x")
	ldx	[%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\nPHYS_OFFSET_1: 0x")
	ldx	[%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\nPHYS_OFFSET_2: 0x")
	ldx	[%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\nPHYS_OFFSET_3: 0x")
	ldx	[%g1 + ERR_MMU_PHYS_OFFSET + (ERR_MMU_PHYS_OFFSET_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\n")

	mov	%g6, %g7
#endif	/* DEBUG */

	HVRET
	SET_SIZE(mra_print)

