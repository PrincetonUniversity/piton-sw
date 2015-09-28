/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mmuinit.s
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

	.ident	"@(#)mmuinit.s	1.8	07/06/07 SMI"

	.file	"mmuinit.s"

#include <sys/privregs.h>
#include <sys/asm_linkage.h>
#include <hypervisor.h>

	.seg	".bss"
	.align	0x100
	.global	mmu_miss_info_area0
mmu_miss_info_area0:
	.skip	0x100
#if defined(lint)
void
mmu_init(uint64_t rabase)
{
}
#else
	ENTRY(mmu_init)
	save	%g0, %g0, %g0

	! %i0 - RAbase
	setx	traptable0, %o1, %i1	! %i1 - VAbase
	sub	%i1, %i0, %i3		! %i3 VA-RA delta

	mov	%i1, %o0		! VA
	mov	%i0, %o1		! RA
	mov	3, %o2			! Size = 4M
	call	setup_itlb_entry
	mov	%g0, %o3		! Mode bits = 0

	mov	%i1, %o0		! VA
	mov	%i0, %o1		! RA
	mov	3, %o2			! Size = 4M
	call	setup_dtlb_entry
	mov	%g0, %o3		! Mode bits = 0

	setx	mmu_miss_info_area0, %o2, %o1	! VA
	sub	%o1, %i3, %o0		! VA->RA
	mov	MMU_FAULT_AREA_CONF, %o5
	ta	FAST_TRAP
	brnz	%o0, 2f
	nop

	setx	1f, %o2, %o1		! VA
	mov	1, %o0
	mov	MMU_ENABLE, %o5
	ta	FAST_TRAP
1:
	brnz	%o0, 2f
	nop
	add	%i7, %i3, %i7		! RA->VA
	ret
	restore
2:
	mov	API_EXIT, %o5
	ta	CORE_TRAP
	SET_SIZE(mmu_init)
#endif /* lint */


#if defined(lint)
void
setup_itlb_entry(uint64_t va, uint64_t pa, uint64_t size, uint64_t tte_mode)
{
}
#else
#define NPABITS		(43)
#define TTE_WRITABLE	(1 << 6)
#define TTE_PRIV	(1 << 8)
#define TTE_EFFECT	(1 << 11)
#define TTE_CV		(1 << 9)
#define TTE_CP		(1 << 10)

#define TTE_64K		(0xa)
#define TTE_512K	(0xc)
#define TTE_4M		(0xe)
	! %o0 = VA
	! %o1 = PA
	! %o2 = Size 0 = 8K, 1 = 64K , 3 = 4M , 5 = 256M
	! %o3 = TTE Mode bits
	ENTRY(setup_itlb_entry)
	sllx	%o1, 64-NPABITS, %o5
	subcc	%o5,%g0,%g0
	bpos	0f
	or	%o1, TTE_PRIV+TTE_CV+TTE_CP+TTE_WRITABLE, %o5	! P,CP,CV,W
	or	%o1, TTE_PRIV+TTE_EFFECT+TTE_WRITABLE, %o5	! P,E,W
0:
	
	or	%o5, %o3, %o1					! Other bits
	mov	%g0, %o3					! all this
	or	%o3, 1, %o3					! to set 
	sllx	%o3, 63, %o3					! the V bit
	
	or	%o2, %o1, %o2					! %o2 = TTE
	or	%o2, %o3, %o2					! set V bit 
	mov	%g0, %o1
	add	%g0, 2, %o3
	! %o0 = Virt
	! %o1 = context
	! %o2 = TTE
	! %o3 = ITLB
	add	%g0, MMU_MAP_PERM_ADDR,  %o5
	ta	FAST_TRAP
	brnz	%o0, 1f
	nop
	retl
	nop
1:
	mov	API_EXIT, %o5
	ta	CORE_TRAP
	SET_SIZE(setup_itlb_entry)

	! %o0 = VA
	! %o1 = PA
	! %o2 = Size 0 = 8K, 1 = 64K , 3 = 4M , 5 = 256M
	! %o3 = TTE Mode bits
	ENTRY(setup_dtlb_entry)
	sllx	%o1, 64-NPABITS, %o5
	subcc	%o5,%g0,%g0
	bpos	0f
	or	%o1, TTE_PRIV+TTE_CV+TTE_CP+TTE_WRITABLE, %o5	! P,CP,CV,W
	or	%o1, TTE_PRIV+TTE_EFFECT+TTE_WRITABLE, %o5	! P,E,W
0:
	or	%o5, %o3, %o1					! Other bits
	mov	%g0, %o3					! All this
	or	%o3, 1, %o3					! to set
	sllx	%o3, 63, %o3					! the V bit

	or	%o2, %o1, %o2					! %o2 = TTE
	or	%o2, %o3, %o2					! set V bit 
	mov	%g0, %o1
	add	%g0, 1, %o3
	! %o0 = Virt
	! %o1 = context
	! %o2 = TTE
	! %o3 = DTLB
	add	%g0, MMU_MAP_PERM_ADDR,  %o5
	ta	FAST_TRAP
	brnz	%o0, 1f
	nop
	retl
	nop
1:
	mov	API_EXIT, %o5
	ta	CORE_TRAP
	SET_SIZE(setup_dtlb_entry)
#endif /* lint */
