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

#ifndef _SUN4V_MMU_H
#define	_SUN4V_MMU_H

#pragma ident	"@(#)mmu.h	1.13	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * sun4v tte tag
 */
#define	TAG_CTX_SHIFT	48
#define	TAG_CTX_MASK	0x1fff
#define	TAG_VA_SHIFT	0
#define	TAG_VA_MASK	0x3fffff /* VA 63:22 */

/*
 * sun4v tte data
 */
#define	TTE_V		0x8000000000000000
#define	TTE_NFO		0x4000000000000000
#define	TTE_RA_SHIFT	13
#define	TTE_IE		0x0000000000001000
#define	TTE_E		0x0000000000000800
#define	TTE_CP		0x0000000000000400
#define	TTE_CV		0x0000000000000200
#define	TTE_P		0x0000000000000100
#define	TTE_X		0x0000000000000080
#define	TTE_W		0x0000000000000040
#define	TTE_SOFT_SHIFT	4
#define	TTE_SOFT_MASK	0x3
#define	TTE_SZ_SHIFT	0
#define	TTE_SZ_MASK	0xf

#define	NPGSZ		8
#define	TSBE_BYTES	16	/* TSB entry bytes */
#define	TSBE_SHIFT	4	/* LOG2(TSBE_BYTES) */

/*
 * sun4v MMU fault status area
 */
#define	MMU_FAULT_AREA_INSTR	0x00
#define	MMU_FAULT_AREA_DATA	0x40

#define	MMU_FAULT_AREA_FT	0x00
#define	MMU_FAULT_AREA_ADDR	0x08
#define	MMU_FAULT_AREA_CTX	0x10

#define	MMU_FAULT_AREA_IFT	MMU_FAULT_AREA_INSTR + MMU_FAULT_AREA_FT
#define	MMU_FAULT_AREA_IADDR	MMU_FAULT_AREA_INSTR + MMU_FAULT_AREA_ADDR
#define	MMU_FAULT_AREA_ICTX	MMU_FAULT_AREA_INSTR + MMU_FAULT_AREA_CTX
#define	MMU_FAULT_AREA_DFT	MMU_FAULT_AREA_DATA + MMU_FAULT_AREA_FT
#define	MMU_FAULT_AREA_DADDR	MMU_FAULT_AREA_DATA + MMU_FAULT_AREA_ADDR
#define	MMU_FAULT_AREA_DCTX	MMU_FAULT_AREA_DATA + MMU_FAULT_AREA_CTX

#define	MMU_FT_FASTMISS		0x1
#define	MMU_FT_FASTPROT		0x2
#define	MMU_FT_MISS		0x3
#define	MMU_FT_INVALIDRA	0x4
#define	MMU_FT_PRIV		0x5 /* access to priv page w/pstate.priv=0 */
#define	MMU_FT_PROT		0x6 /* store to !write, access of !exec */
#define	MMU_FT_NFO		0x7
#define	MMU_FT_SO		0x8
#define	MMU_FT_VARANGE		0x9
#define	MMU_FT_BADASI		0xa
#define	MMU_FT_NCATOMIC		0xb
#define	MMU_FT_PRIVACTION	0xc /* use of priv ASI when pstate.priv=0 */
#define	MMU_FT_WATCHPOINT	0xd
#define	MMU_FT_ALIGN		0xe
#define	MMU_FT_PAGESIZE		0xf
#define	MMU_FT_INVTSBENTRY	0x10
#define	MMU_FT_MULTIERR		-1


/*
 * ASI_MMU registers
 */
#define	MMU_PCONTEXT	0x8	/* primary context */
#define	MMU_SCONTEXT	0x10	/* secondary context */


/*
 * Returns pagesize encoded in tte.  tte not modified.
 * Illegal page sizes are handled without any extra checks.
 *
 * TTE_VALIDSIZEARRAY is defined in the cpu-specific <cpu>/mmu.h
 *
 * Pagesize is (1 << (13 + (n * 3)))
 */
/* BEGIN CSTYLED */
#define	TTE_SIZE(tte, size, scr, faillabel)	\
	mov	TTE_VALIDSIZEARRAY, scr		;\
	and	tte, TTE_SZ_MASK, size		;\
	srlx	scr, size, scr			;\
	btst	1, scr				;\
	bz,pn	%xcc, faillabel			;\
	add	size, size, scr			;\
	add	size, scr, size			;\
	add	size, 13, size			;\
	mov	1, scr				;\
	sllx	scr, size, size
/* END CSTYLED */


/*
 * Returns pageshift encoded in tte.  tte not modified.
 * Illegal page sizes are handled without any extra checks.
 *
 * Pageshift is (13 + (n * 3))
 */
/* BEGIN CSTYLED */
#define	TTE_SHIFT_NOCHECK(tte, shift, scr)	\
	and	tte, TTE_SZ_MASK, shift		;\
	add	shift, shift, scr		;\
	add	shift, scr, shift		;\
	add	shift, 13, shift
/* END CSTYLED */


#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_MMU_H */
