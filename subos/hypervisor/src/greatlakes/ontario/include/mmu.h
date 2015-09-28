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

#ifndef _ONTARIO_MMU_H
#define	_ONTARIO_MMU_H

#pragma ident	"@(#)mmu.h	1.22	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <segments.h>

/*
 * Niagara MMU properties
 */
#define	NCTXS	8192
#define	NVABITS	48

#define	PADDR_IO_BIT	39


/*
 * Only support TSBs for the two hardware TSB page size indexes.
 */
#define	MAX_NTSB	2

/*
 * ASI_[DI]MMU registers
 */
#define	MMU_SFSR	0x18
#define	MMU_SFAR	0x20
#define	MMU_TAG_ACCESS	0x30
#define	MMU_TAG_TARGET	0x00
#define	TAGACC_CTX_LSHIFT	(64-13)
#define	TAGTRG_CTX_RSHIFT	48
#define	TAGTRG_VA_LSHIFT	22

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
#define	DTLB_ENTRIES			64

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
 * Niagara SFSR
 */
#define	MMU_SFSR_FV	(0x1 << 0)
#define	MMU_SFSR_OW	(0x1 << 1)
#define	MMU_SFSR_W	(0x1 << 2)
#define	MMU_SFSR_CT	(0x3 << 4)
#define	MMU_SFSR_E	(0x1 << 6)
#define	MMU_SFSR_FT_MASK	(0x7f)
#define	MMU_SFSR_FT_SHIFT	(7)
#define	MMU_SFSR_FT	(MMU_SFSR_FT_MASK << MMU_SFSR_FT_SHIFT)
#define	MMU_SFSR_ASI_MASK	(0xff)
#define	MMU_SFSR_ASI_SHIFT	(16)
#define	MMU_SFSR_ASI	(MMU_SFSR_ASI_MASK << MMU_SFSR_ASI_SHIFT)

#define	MMU_SFSR_FT_PRIV	(0x01) /* Privilege violation */
#define	MMU_SFSR_FT_SO		(0x02) /* side-effect load from E-page */
#define	MMU_SFSR_FT_ATOMICIO	(0x04) /* atomic access to IO address */
#define	MMU_SFSR_FT_ASI		(0x08) /* illegal ASI/VA/RW/SZ */
#define	MMU_SFSR_FT_NFO		(0x10) /* non-load from NFO page */
#define	MMU_SFSR_FT_VARANGE	(0x20) /* d-mmu, i-mmu branch, call, seq */
#define	MMU_SFSR_FT_VARANGE2	(0x40) /* i-mmu jmpl or return */

/*
 * Native (sun4u) tte format
 */
#define	TTE4U_V		0x8000000000000000
#define	TTE4U_SZL	0x6000000000000000
#define	TTE4U_NFO	0x1000000000000000
#define	TTE4U_IE	0x0800000000000000
#define	TTE4U_SZH	0x0001000000000000
#define	TTE4U_DIAG	0x0000ff0000000000
#define	TTE4U_PA_SHIFT	13
#define	TTE4U_L		0x0000000000000040
#define	TTE4U_CP	0x0000000000000020
#define	TTE4U_CV	0x0000000000000010
#define	TTE4U_E		0x0000000000000008
#define	TTE4U_P		0x0000000000000004
#define	TTE4U_W		0x0000000000000002

/*
 * Niagara's sun4v format - bit 61 is lock, which is a SW bit
 * in the sun4v spec and must be cleared on TTEs passed from guest.
 */
#define	NI_TTE4V_L_SHIFT	61

/* BEGIN CSTYLED */
#define	SET_TTE_LOCK_BIT(reg, scr)			\
	mov	1, scr					;\
	sllx	scr, NI_TTE4V_L_SHIFT, scr		;\
	or	reg, scr, reg

#define	CLEAR_TTE_LOCK_BIT(reg, scr)			\
	mov	1, scr					;\
	sllx	scr, NI_TTE4V_L_SHIFT, scr		;\
	andn	reg, scr, reg

#define	RADDR_IS_IO_XCCNEG(addr, scr1)			\
	sllx    addr, (63 - PADDR_IO_BIT), scr1		;\
	tst     scr1
/* END CSTYLED */

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
 * on Niagara
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
/* END CSTYLED */

/*
 * Supported page size encodings for Niagara
 */
#define	TTE_VALIDSIZEARRAY		\
	    ((1 << 0) |	/* 8K */	\
	    (1 << 1) |	/* 64k */	\
	    (1 << 3) |	/* 4M */	\
	    (1 << 5))	/* 256M */

	/* Largest page size is 28bits */
#define	LARGEST_PG_SIZE_BITS	28

#ifdef __cplusplus
}
#endif

#endif /* _ONTARIO_MMU_H */
