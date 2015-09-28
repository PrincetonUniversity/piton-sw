/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cache.h
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

#ifndef _PLATFORM_CACHE_H
#define	_PLATFORM_CACHE_H

#pragma ident	"@(#)cache.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * I/D/L2 Cache definitions
 */

/*
 * L2 cache index
 */
#define	L2_BANK_SHIFT		6
#define	L2_BANK_MASK		(0x3)
#define	L2_SET_SHIFT		8
#define	L2_SET_MASK		(0x3FF)
#define	L2_WAY_SHIFT		18
#define	L2_WAY_MASK		(0xF)
#define	NO_L2_BANKS		4

#define	L2_LINE_SHIFT		6
#define	L2_LINE_SIZE		(1 << L2_LINE_SHIFT)	/* 64 */
#define	N_LONG_IN_LINE		(L2_LINE_SIZE / SIZEOF_UI64)
#define	L2_NUM_WAYS		12

#define	L2_CSR_BASE		(0xa0 << 32)

/*
 * L2 Control Register definitions (Count 4 Step 64)
 */
#define	L2_CONTROL_REG		(0xa9 << 32)
#define	L2_DIS_SHIFT		0
#define	L2_DIS			(1 << L2_DIS_SHIFT)
#define	L2_DMMODE_SHIFT		1
#define	L2_DMMODE		(1 << L2_DMMODE_SHIFT)
#define	L2_SCRUBENABLE_SHIFT	2
#define	L2_SCRUBENABLE		(1 << L2_SCRUBENABLE_SHIFT)
#define	L2_SCRUBINTERVAL_SHIFT	3
#define	L2_SCRUBINTERVAL_MASK	(0xfff << L2_SCRUBENABLE_SHIFT)
#define	L2_ERRORSTEER_SHIFT	15
#define	L2_ERRORSTEER_MASK	(0x1f << L2_ERRORSTEER_SHIFT)
#define	L2_DBGEN_SHIFT		20
#define	L2_DBGEN		(1 << L2_DBGEN_SHIFT)
#define	L2_DIRCLEAR_SHIFT	21
#define	L2_DIRCLEAR		(1 << L2_DBGEN_SHIFT)

/*
 * L2 Error Enable Register (Count 4 Step 64)
 */
#define	L2_EEN_BA		0xaa
#define	L2_EEN_BASE		(L2_EEN_BA << 32)
#define	L2_EEN_STEP		0x40
#define	DEBUG_TRIG_EN		(1 << 2)	/* Debug Port Trigger enable */

/* BEGIN CSTYLED */
#define	SET_L2_EEN_BASE(reg) \
	mov	L2_EEN_BA, reg;\
	sllx	reg, 32, reg
#define	GET_L2_BANK_EEN(bank, dst, scr1) \
	SET_L2_EEN_BASE(scr1)			/* Error Enable Register */	;\
	sllx	bank, L2_BANK_SHIFT, dst	/* bank offset */		;\
	ldx	[scr1 + dst], dst		/* get current */
#define	BTST_L2_BANK_EEN(bank, bits, scr1, scr2) \
	GET_L2_BANK_EEN(bank, scr1, scr2)	/* get current */	 	;\
	btst	bits, scr1			/* test bit(s) */
#define	BCLR_L2_BANK_EEN(bank, bits, scr1, scr2) \
	.pushlocals								;\
	SET_L2_EEN_BASE(scr2)			/* Error Enable Register */	;\
	sllx	bank, L2_BANK_SHIFT, scr1	/* bank offset */		;\
	add	scr2, scr1, scr2		/* bank address */		;\
	ldx	[scr2], scr1			/* get current */	 	;\
	btst	bits, scr1			/* reset? */			;\
	bz,pn	%xcc, 9f			/*   yes: return cc=z */	;\
	  bclr	bits, scr1			/* reset bit(s) */		;\
	stx	scr1, [scr2]			/* store back */		;\
9:	.poplocals				/* success: cc=nz */
#define	BSET_L2_BANK_EEN(bank, bits, scr1, scr2) \
	SET_L2_EEN_BASE(scr2)			/* Error Enable Register */	;\
	sllx	bank, L2_BANK_SHIFT, scr1	/* bank offset */		;\
	add	scr2, scr1, scr2		/* bank address */		;\
	ldx	[scr2], scr1			/* get current */	 	;\
	bset	bits, scr1			/* set bit(s) */		;\
	stx	scr1, [scr2]			/* store back */
/* END CSTYLED */

/*
 * L2 Error Status Register (Count 4 Step 64)
 */
#define	L2_ESR_BA		0xab
#define	L2_ESR_BASE		(L2_ESR_BA << 32)
#define	L2_ESR_STEP		0x40
#define	L2_BANK_STEP		0x40
#define	L2_ESR_MEU		(1 << 63)
#define	L2_ESR_MEC		(1 << 62)
#define	L2_ESR_RW		(1 << 61)
#define	L2_ESR_MODA		(1 << 59)
#define	L2_ESR_VCID_SHIFT	54
#define	L2_ESR_VCID_MASK	0x1f
#define	L2_ESR_VCID		(L2_ESR_VCID_MASK << L2_ESR_VCID_SHIFT)
#define	L2_ESR_LDAC		(1 << 53)
#define	L2_ESR_LDAU		(1 << 52)
#define	L2_ESR_LDWC		(1 << 51)
#define	L2_ESR_LDWU		(1 << 50)
#define	L2_ESR_LDRC		(1 << 49)
#define	L2_ESR_LDRU		(1 << 48)
#define	L2_ESR_LDSC		(1 << 47)
#define	L2_ESR_LDSU		(1 << 46)
#define	L2_ESR_LTC		(1 << 45)
#define	L2_ESR_LRU		(1 << 44)
#define	L2_ESR_LVU		(1 << 43)
#define	L2_ESR_DAC		(1 << 42)
#define	L2_ESR_DAU		(1 << 41)
#define	L2_ESR_DRC		(1 << 40)
#define	L2_ESR_DRU		(1 << 39)
#define	L2_ESR_DSC		(1 << 38)
#define	L2_ESR_DSU		(1 << 37)
#define	L2_ESR_VEC		(1 << 36)
#define	L2_ESR_VEU		(1 << 35)
#define	L2_ESR_SYND_SHIFT	0
#define	L2_ESR_SYND_MASK	0xffffffff
#define	L2_ESR_SYND		(L2_ESR_SYND_MASK << L2_ESR_SYND_SHIFT)

#define	L2_ERROR_STATUS_CLEAR	0xc03ffff800000000

/*
 * L2 Error Address Register (Count 4 Step 64)
 */
#define	L2_EAR_BA		0xac
#define	L2_EAR_BASE		(L2_EAR_BA << 32)

#ifdef __cplusplus
}
#endif

#endif /* !_PLATFORM_CACHE_H */
