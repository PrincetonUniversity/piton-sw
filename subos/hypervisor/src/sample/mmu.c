/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mmu.c
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

#pragma ident	"@(#)mmu.c	1.5	07/06/07 SMI"
#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <malloc.h>
#include <unistd.h>

#include <sample/sample.h>

extern int hv_mmu_map_addr(uint64_t va, int ctx, uint64_t tte, int flags);
extern int hv_mmu_demap_page(uint64_t va, int ctx, int flags);

/*
 * Sun4V TTE bits
 */
#define	NPABITS		(43)
#define	TTE_WRITABLE	(1 << 6)
#define	TTE_PRIV	(1 << 8)
#define	TTE_EFFECT	(1 << 11)
#define	TTE_CV		(1 << 9)
#define	TTE_CP		(1 << 10)

#define	TTE_64K		(0xa)
#define	TTE_512K	(0xc)
#define	TTE_4M		(0xe)

int
map_addr(uint64_t va, uint64_t ra, uint64_t size, int mmu)
{
	int mode;
	uint64_t sz;
	uint64_t tte;
	if ((int64_t)(ra << (64-NPABITS)) < 0)
		mode = TTE_PRIV|TTE_EFFECT|TTE_WRITABLE;
	else
		mode = TTE_PRIV|TTE_CV|TTE_CP|TTE_WRITABLE;

	switch (size) {
	case K(8):
		sz = 0;
		break;
	case K(64):
		sz = 1ULL;
		break;
	case M(4):
		sz = 3ULL;
		break;
	default:
		printf("Illegal size %x\n", size);
		return (1);
	}
	tte = sz | ra | mode | (1ULL << 63);
#if 0
	printf("mmu map va=%x tte=%x\n", va, tte);
#endif
	return (hv_mmu_map_addr(va, 0, tte, mmu));
}

int
map_iaddr(uint64_t va, uint64_t ra, uint64_t size)
{
	return (map_addr(va, ra, size, 2));
}

int
map_daddr(uint64_t va, uint64_t ra, uint64_t size)
{
	return (map_addr(va, ra, size, 1));
}

int
unmap_addr(uint64_t va, int ctx)
{
	return (hv_mmu_demap_page(va, ctx, 3));
}
