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

#ifndef _CACHE_H
#define	_CACHE_H

#pragma ident	"@(#)cache.h	1.8	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <platform/cache.h>

/*
 * L1 icache
 */
#define	ICACHE_MAX_WAYS		4
#define	ICACHE_NUM_OF_WORDS	8

/*
 * L1 Instruction Cache Data Diagnostic Addressing
 */
#define	ICACHE_INSTR_WAY_SHIFT	16
#define	ICACHE_INSTR_WAY_MASK	(0x2 << ICACHE_INSTR_WAY_SHIFT)
#define	ICACHE_INSTR_SET_SHIFT	6
#define	ICACHE_INSTR_SET_MASK	(0x7f << ICACHE_INSTR_SET_SHIFT)
#define	ICACHE_INSTR_WORD_SHIFT	3
#define	ICACHE_INSTR_WORD_MASK	(0x3 << ICACHE_INSTR_WORD_SHIFT)

#define	ICACHE_PA_SET_SHIFT	5
#define	ICACHE_PA_SET_MASK	(0x7f << ICACHE_PA_SET_SHIFT)
#define	ICACHE_PA_WORD_SHIFT	2
#define	ICACHE_PA_WORD_MASK	(0x3 << ICACHE_PA_WORD_SHIFT)

/*
 * L1 Instruction Cache Tag Diagnostic Addressing
 */
#define	ICACHE_TAG_WAY_SHIFT	16
#define	ICACHE_TAG_WAY_MASK	(0x2 << ICACHE_TAG_WAY_SHIFT)
#define	ICACHE_TAG_SET_SHIFT	6
#define	ICACHE_TAG_SET_MASK	(0x7f << ICACHE_TAG_SET_SHIFT)
#define	ICACHE_PA2SET_SHIFT	5
#define	ICACHE_PA2SET_MASK	(0x7f << ICACHE_PA2SET_SHIFT)
#define	ICACHE_SETFROMPA_SHIFT	1
#define	ICACHE_TAG_VALID	34

/*
 * L1 Data Cache Diagnostic Addressing
 */
#define	DCACHE_MAX_WAYS		4
#define	DCACHE_NUM_OF_WORDS	2
#define	DCACHE_WAY_SHIFT	11
#define	DCACHE_SET_MASK		0x7f
#define	DCACHE_SET_SHIFT	4
#define	DCACHE_SET		(DCACHE_SET_MASK << DCACHE_SET_SHIFT)
#define	DCACHE_TAG_MASK		0x3ffffffe
#define	DCACHE_TAG_SHIFT	11
#define	DCACHE_TAG_VALID	1
#define	DCACHE_WORD_MASK	0x1
#define	DCACHE_WORD_SHIFT	3

/*
 * L2 diagnostic tag fields
 */
#define	L2_PA_TAG_SHIFT		18
#ifdef _ASM
#define	L2_PA_TAG_MASK		0xfffffc0000
#else
#define	L2_PA_TAG_MASK		(0x3fffffULL << L2_PA_TAG_SHIFT)
#endif
#define	L2_TAG_SHIFT		6
#ifdef _ASM
#define	L2_TAG_MASK		0xfffffc0
#else
#define	L2_TAG_MASK		(0x3fffffULL << L2_TAG_SHIFT)
#endif
#define	L2_TAG(pa)		((pa & L2_PA_TAG_MASK) >> L2_PA_TAG_SHIFT)

#define	L2_TAG_ECC_SHIFT	0
#define	L2_TAG_ECC_MASK		(0x3fULL << L2_TAG_ECC_SHIFT)

#define	L2_TAG_DIAG_SELECT		0xa4
#define	L2_TAG_DIAG_SELECT_SHIFT	32
#define	L2_INDEX_MASK			(L2_SET_MASK << L2_SET_SHIFT) | \
					(L2_BANK_MASK << L2_BANK_SHIFT)

#ifdef __cplusplus
}
#endif

#endif /* _CACHE_H */
