/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mmu.h
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

#ifndef _NIAGARA2_MMU_H
#define	_NIAGARA2_MMU_H

#pragma ident	"@(#)mmu.h	1.3	07/05/17 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <segments.h>

/*
 * Niagara2 MMU properties
 */
#define	NCTXS	8192
#define	NVABITS	48

#define	PADDR_IO_BIT	39

/*
 * MMU Register Array
 */
#define	MAX_NMRA	8
#define	MRA_ENTRIES	8

/*
 * Only support TSBs for the two hardware TSB page size indexes.
 */
#define	MAX_NTSB	4

/*
 * Support two sets of context registers.
 */
#define	MAX_NCTX_INDEX	1

/*
 * ASI_[DI]MMU registers
 */
#define	MMU_SFSR		0x18
#define	MMU_SFAR		0x20
#define	MMU_TAG_ACCESS		0x30
#define	MMU_TAG_TARGET		0x00
#define	TAGACC_CTX_LSHIFT	(64-13)
#define	TAGTRG_CTX_RSHIFT	48
#define	TAGTRG_VA_LSHIFT	22
#define	MMU_PCONTEXT0		MMU_PCONTEXT
#define	MMU_PCONTEXT1		0x108
#define	MMU_SCONTEXT0		MMU_SCONTEXT
#define	MMU_SCONTEXT1		0x110

/*
 * N2 HWTW
 *
 * RA bits[55:40} must be zero
 */
#define	RA_55_40_SHIFT		40
#define	RA_55_40_MASK		0xffff

/*
 * I-/D-TSB Pointer registers
 */
#define	MMU_ITSB_PTR_0		0x50
#define	MMU_ITSB_PTR_1		0x58
#define	MMU_ITSB_PTR_2		0x60
#define	MMU_ITSB_PTR_3		0x68
#define	MMU_DTSB_PTR_0		0x70
#define	MMU_DTSB_PTR_1		0x78
#define	MMU_DTSB_PTR_2		0x80
#define	MMU_DTSB_PTR_3		0x88

/*
 * ASI_[ID]TSBBASE_CTX*
 */
#define	TSB_SZ0_ENTRIES		512
#define	TSB_SZ0_SHIFT		9	/* LOG2(TSB_SZ0_ENTRIES) */
#define	TSB_MAX_SZCODE		15

/*
 * ASI_[ID]TSB_CONFIG_CTX*
 */
#define	ASI_TSB_CONFIG_PS1_SHIFT	8

#define	ITLB_ENTRIES			64
#define	DTLB_ENTRIES			128

#define	USE_TSB_PRIMARY_CTX		2
#define	USE_TSB_SECONDARY_CTX		1
/*
 * ASI_[DI]MMU_DEMAP
 */
#define	DEMAP_ALL	0x2

/*
 * ASI_TLB_INVALIDATE
 */
#define	I_INVALIDATE	0x0
#define	D_INVALIDATE	0x8

/*
 * ASI_MMU_CFG
 */
#define	HWTW_CFG		0x40
#define	HWTW_BURST_MODE		0x1
#define	HWTW_PREDICT_MODE	0x2

/*
 * ASI_HWTW_RANGE
 */
#define	MMU_REAL_RANGE_0	0x108
#define	MMU_REAL_RANGE_1	0x110
#define	MMU_REAL_RANGE_2	0x118
#define	MMU_REAL_RANGE_3	0x120
#define	REALRANGE_BOUNDS_SHIFT	27
#define	REALRANGE_BASE_SHIFT	0
#define	MMU_PHYS_OFF_0		0x208
#define	MMU_PHYS_OFF_1		0x210
#define	MMU_PHYS_OFF_2		0x218
#define	MMU_PHYS_OFF_3		0x220
#define	PHYSOFF_SHIFT		13

/*
 * ASI_MMU_TSB
 */
#define	TSB_CFG_CTX0_0		0x10
#define	TSB_CFG_CTX0_1		0x18
#define	TSB_CFG_CTX0_2		0x20
#define	TSB_CFG_CTX0_3		0x28
#define	TSB_CFG_CTXN_0		0x30
#define	TSB_CFG_CTXN_1		0x38
#define	TSB_CFG_CTXN_2		0x40
#define	TSB_CFG_CTXN_3		0x48
#define	TSB_CFG_USE_CTX1_SHIFT	61
#define	TSB_CFG_USE_CTX0_SHIFT	62
#define	TSB_CFG_PGSZ_SHIFT	4
#define	TSB_CFG_RA_NOT_PA	0x100

#define	MMU_VALID_FLAGS_MASK	(MAP_ITLB | MAP_DTLB)

/*
 * Check that only valid flags bits are set and that at least
 * one TLB selector is set. If optional flags are added,
 * the simplistic 'brz' will have to be changed.
 */
/* BEGIN CSTYLED */
#define	CHECK_MMU_FLAGS(flags, fail_label)		\
	brz,pn	flags, fail_label			;\
	andncc	flags, MMU_VALID_FLAGS_MASK, %g0	;\
	bnz,pn	%xcc, fail_label			;\
	nop

/*
 * Check the virtual address and context for validity
 * on Niagara2
 */
#define	CHECK_CTX(ctx, fail_label, scr)		\
	set	NCTXS, scr				;\
	cmp	ctx, scr				;\
	bgeu,pn	%xcc, fail_label			;\
	nop
#define	CHECK_VA_CTX(va, ctx, fail_label, scr)		\
	sllx	va, (64 - NVABITS), scr			;\
	srax	scr, (64 - NVABITS), scr		;\
	cmp	va, scr					;\
	bne,pn	%xcc, fail_label			;\
	CHECK_CTX(ctx, fail_label, scr)

#define	SET_TTE_LOCK_BIT(reg, scr)	
#define	CLEAR_TTE_LOCK_BIT(reg, scr)	

/* END CSTYLED */

/*
 * Supported page size encodings for Niagara2
 */
#define	TTE_VALIDSIZEARRAY		\
	    ((1 << 0) |	/* 8K */	\
	    (1 << 1) |	/* 64k */	\
	    (1 << 3) |	/* 4M */	\
	    (1 << 5))	/* 256M */

/* Largest page size is 28bits */
#define	LARGEST_PG_SIZE_BITS    28

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_MMU_H */
