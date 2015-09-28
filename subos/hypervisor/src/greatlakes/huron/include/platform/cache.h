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

#pragma ident	"@(#)cache.h	1.3	07/06/27 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/htypes.h>

/*
 * L2 cache definitions
 */
#define	L2_LINE_SHIFT		6
#define	L2_LINE_SIZE		(1 << L2_LINE_SHIFT)

#define	L2_BANK_SHIFT		6
#define	L2_BANK_MASK		0x7
#define	L2_SET_SHIFT		9
#define	L2_SET_MASK		0x1ff
#define	L2_WAY_SHIFT		18
#define	L2_WAY_MASK		0xF
#define	NO_L2_BANKS		8
#define	L2_NUM_WAYS		16
#define	N_LONG_IN_LINE		(L2_LINE_SIZE / SIZEOF_UI64)

#define	L2_BANK_SET				\
	((L2_BANK_MASK << L2_BANK_SHIFT) |	\
	    (L2_SET_MASK << L2_SET_SHIFT))

/* L2 Control Register definitions (Count 8 Step 64) */
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
#define	L2_ERRORSTEER_MASK	(0x3f << L2_ERRORSTEER_SHIFT)

/* L2 Error Enable Register definitions (Count 8 Step 64) */
#define	L2_ERR_EN_BASE		(0xaa << 32)
#define	L2_NCEEN		0x2
#define	L2_CEEN			0x1

/*
 * L2 Index Hash Enable Status
 */
#define	L2_IDX_HASH_EN_STATUS		0x8000001038
#define	L2_IDX_HASH_EN_STATUS_MASK	0x1

/*
 * L2 Bank Enable
 */
#define	L2_BANK_ENABLE			0x8000001020
#define	L2_BANK_ENABLE_MASK		0xff
#define	L2_BANK_ENABLE_SHIFT		0

/*
 * L2 Bank Enable Status
 */
#define	L2_BANK_ENABLE_STATUS		0x8000001028
#define	L2_BANK_ENABLE_STATUS_MASK	0xf
#define	L2_BANK_ENABLE_STATUS_SHIFT	0

/*
 * L2 Error Injector
 */
#define	L2_ERROR_INJECTOR		0xad00000000
#define	L2_ERROR_INJECTOR_ENB_HP	(1 << 0)
#define	L2_ERROR_INJECTOR_SDSHOT	(1 << 1)

/*
 * PrefetchICE Address Format
 *
 * +--------------------------------------+
 * | 64:40|39:37|36:22|21:18|17:9| 8:6|5:0|
 * +--------------------------------------+
 * |   -  |  key|  -  |  way| set|bank| - |
 * +--------------------------------------+
 *
 * Note: If only 4 banks are enabled, set is bits [16:8]
 *	 and bank is bits [7:6]. If 2 banks are enabled,
 *	 set is bits [15:7] and bank is bit [6].
 */
#define	PREFETCHICE_KEY			(0x3 << 37)
#define	PREFETCHICE_WAY_SHIFT		18
#define	PREFETCHICE_WAY_MASK		0xf
#define	PREFETCHICE_WAY_MAX		\
	(PREFETCHICE_WAY_MASK << PREFETCHICE_WAY_SHIFT)
#define	PREFETCHICE_SET_SHIFT		9
#define	PREFETCHICE_BANK_SET_MASK	0x1ff
#define	PREFETCHICE_8BANK_SET_MAX	\
	(PREFETCHICE_BANK_SET_MASK << PREFETCHICE_SET_SHIFT)
#define	PREFETCHICE_4BANK_SET_MAX	\
	(PREFETCHICE_BANK_SET_MASK << PREFETCHICE_SET_SHIFT - 1)
#define	PREFETCHICE_2BANK_SET_MAX	\
	(PREFETCHICE_BANK_SET_MASK << PREFETCHICE_SET_SHIFT - 2)
#define	PREFETCHICE_BANK_SHIFT		6
#define	PREFETCHICE_8BANK_MASK		0x7
#define	PREFETCHICE_8BANK_MAX		\
	(PREFETCHICE_8BANK_MASK << PREFETCHICE_BANK_SHIFT)
#define	PREFETCHICE_4BANK_MASK		0x3
#define	PREFETCHICE_4BANK_MAX		\
	(PREFETCHICE_4BANK_MASK << PREFETCHICE_BANK_SHIFT)
#define	PREFETCHICE_2BANK_MASK		0x1
#define	PREFETCHICE_2BANK_MAX		\
	(PREFETCHICE_2BANK_MASK << PREFETCHICE_BANK_SHIFT)

/*
 * The L2 cache cleanser is enabled and controlled by the following
 * two HV MD properties:
 *
 * - L2_CACHE_CLEANSER_INTERVAL: 
 *   controls the interval for the cyclic invocation of the cleanser
 *
 * - L2_CACHE_CLEANSER_ENTRIES:
 *   controls number of L2 entries to be cleansed per each invocation
 *
 * The default setting below will cycle through the entire L2 cache in
 * 1000 seconds, with 10% of entries cleansed per each invocation on 
 * every 100 seconds
 */
#define	L2_CACHE_ENTRIES		0x10000	/* 4Mb / 64b linesize */
#define	L2_CACHE_CLEANSER_INTERVAL	100	/* seconds */
#define	L2_CACHE_CLEANSER_ENTRIES	10

#define	L2_TAG_DIAG_ECC_MASK		0x3f

/*
 * I/D Cache
 */
#define	MAX_ICACHE_WAYS		8
#define	MAX_DCACHE_WAYS		4

/* BEGIN CSTYLED */
#define	SKIP_DISABLED_L2_BANK(bank, reg1, reg2, skip_label)		\
	setx	L2_BANK_ENABLE_STATUS, reg1, reg2			;\
	ldx	[reg2], reg2						;\
	srlx	reg2, L2_BANK_ENABLE_STATUS_SHIFT, reg2			;\
	and	reg2, L2_BANK_ENABLE_STATUS_MASK, reg2			;\
	or	%g0, bank, reg1						;\
	srlx	reg1, 1, reg1						;\
	srlx	reg2, reg1, reg2					;\
	btst	1, reg2							;\
	bz,pn	%xcc, skip_label					;\
	nop								;\

#define	N2_PERFORM_IDX_HASH(addr, lomask, himask)			\
	mov	0x1f, himask						;\
	sllx	himask, 28, himask					;\
									;\
	mov	0x3, lomask						;\
	sllx	lomask, L2_WAY_SHIFT, lomask				;\
									;\
	and	addr, himask, himask					;\
	and	addr, lomask, lomask					;\
									;\
	srlx	himask, 15, himask 					;\
	xor	addr, himask, addr					;\
									;\
	srlx	lomask, 7, lomask					;\
	xor	addr, lomask, addr 

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif	/* _PLATFORM_CACHE_H */
