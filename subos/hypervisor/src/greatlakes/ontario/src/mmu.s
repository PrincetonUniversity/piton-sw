/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mmu.s
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

	.ident	"@(#)mmu.s	1.45	07/05/03 SMI"

/*
 * Niagara mmu code
 */

#include <sys/asm_linkage.h>
#include <hprivregs.h>
#include <asi.h>
#include <traps.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <mmustat.h>
#include <cpu_errs.h>

#include <guest.h>
#include <offsets.h>
#include <debug.h>
#include <util.h>

	! %g1	vcpup
	! %g2	8k-aligned real addr from tag access
	ENTRY_NP(rdmmu_miss)
	! offset handling
	! XXX if hypervisor access then panic instead of watchdog_guest
	VCPU2GUEST_STRUCT(%g1, %g7)
	set	8 KB, %g5
	RA2PA_RANGE_CONV(%g7, %g2, %g5, 1f, %g4, %g3)
	!	%g3	PA

	! tte valid, cp, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE4U_CP | TTE4U_P | TTE4U_W, %g2
	or	%g3, %g2, %g3
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN
	retry

1:
	GUEST_STRUCT(%g1)
	set	8192, %g6
	RANGE_CHECK_IO(%g1, %g2, %g6, .rdmmu_miss_found, .rdmmu_miss_not_found,
	    %g3, %g4)
.rdmmu_miss_found:
	mov	%g2, %g3

	! tte valid, e, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE4U_E | TTE4U_P | TTE4U_W, %g2
	or	%g3, %g2, %g3
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN
	retry

	
.rdmmu_miss_not_found:
1:
	! FIXME: This test to be subsumed when we fix the RA mappings
	! for multiple RA blocks
	! %g1 guest struct
	! %g2 real address
	set	GUEST_LDC_MAPIN_BASERA, %g7
	ldx	[ %g1 + %g7 ], %g3
	subcc	%g2, %g3, %g4
	bneg,pn	%xcc, 2f
	  nop
	set	GUEST_LDC_MAPIN_SIZE, %g5
	ldx	[ %g1 + %g5 ], %g6
	subcc	%g4, %g6, %g0
		! check regs passed in to mapin_ra:
	bneg,pt %xcc, ldc_dmmu_mapin_ra
	  nop

	ENTRY_NP(rdmmu_miss_not_found2)
2:
	LEGION_GOT_HERE
	mov	MMU_FT_INVALIDRA, %g1
	ba,pt	%xcc, revec_dax	! (%g1=ft, %g2=addr, %g3=ctx)
	mov	0, %g3
	SET_SIZE(rdmmu_miss)

	!
	! %g1 = vcpup
	!
	ENTRY_NP(rimmu_miss)
	mov	MMU_TAG_ACCESS, %g2
	ldxa	[%g2]ASI_IMMU, %g2	/* tag access */
	set	((1 << 13) - 1), %g3
	andn	%g2, %g3, %g2

	VCPU2GUEST_STRUCT(%g1, %g3)
	RA2PA_RANGE_CONV(%g3, %g2, %g0, 1f, %g4, %g1)
	! %g1	PA

	! tte valid, cp, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE4U_CP | TTE4U_P | TTE4U_W, %g2
	or	%g1, %g2, %g1
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g1, [%g2]ASI_ITLB_DATA_IN
	retry

1:
	! %g2 real address
	LEGION_GOT_HERE
	mov	MMU_FT_INVALIDRA, %g1
	ba,pt	%xcc, revec_iax	! (%g1=ft, %g2=addr, %g3=ctx)
	mov	0, %g3
	SET_SIZE(rimmu_miss)


	/*
	 * Normal tlb miss handlers
	 *
	 * Guest miss area:
	 *
	 * NB:	 If it's possible to context switch a guest then
	 * the tag access register (tag target too?) needs to
	 * be saved/restored.
	 */

	/* %g1 contains per CPU area */
	ENTRY_NP(immu_miss)
	rd	%tick, %g2
	stx	%g2, [%g1 + CPU_SCR0]
	ldxa	[%g0]ASI_IMMU, %g3	/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */

	! %g1 = CPU pointer
	! %g3 = tag target
	! %g4 = ctx

.checkitsb0:
	! for context != 0 and unshared TSB, that ctx == TSB ctx
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_IMMU_TSB_PS0, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	! e.g. for shared TSBs in S9 xor value is ctx << 4
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .checkitsb1	! tag mismatch
	nop
	brlz,pt %g7, .itsbhit		! TTE valid
	nop

.checkitsb1:
	! repeat check for second TSB
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_BYTES + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_IMMU_TSB_PS1, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .checkipermmaps	! tag mismatch
	nop
	brgez,pn %g7, .checkipermmaps	! TTE valid?
	nop

.itsbhit:
	! extract sz from tte
	TTE_SIZE(%g7, %g4, %g3, .itsb_inv_pgsz)
	btst	TTE_X, %g7	! must check X bit for IMMU
	bz,pn	%icc, .itsbmiss
	sub	%g4, 1, %g5	! %g5 page mask

	! extract ra from tte
	sllx	%g7, 64 - 40, %g3
	srlx	%g3, 64 - 40 + 13, %g3
	sllx	%g3, 13, %g3	! %g3 real address
	xor	%g7, %g3, %g7	! %g7 orig tte with ra field zeroed
	andn	%g3, %g5, %g3

	VCPU2GUEST_STRUCT(%g1, %g6)
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g3, %g4, .itsb_ra_range, %g5, %g1) ! XXX fault not just a miss
	mov	%g1, %g3
	VCPU_STRUCT(%g1)		! restore vcpu

	or	%g7, %g3, %g7	! %g7 new tte with pa

	CLEAR_TTE_LOCK_BIT(%g7, %g5)

	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection
	stxa	%g7, [%g5]ASI_ITLB_DATA_IN
	!
	! %g1 = CPU pointer
	! %g7 = TTE
	!
	ldx	[%g1 + CPU_MMUSTAT_AREA], %g6
	brnz,pn	%g6, 1f
	nop

	retry

1:
	rd	%tick, %g2
	ldx	[%g1 + CPU_SCR0], %g1
	sub	%g2, %g1, %g5
	!
	! %g5 = %tick delta
	! %g6 = MMU statistics area
	! %g7 = TTE
	!
	inc	MMUSTAT_I, %g6			/* stats + i */
	ldxa	[%g0]ASI_IMMU, %g3		/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */
	mov	MMUSTAT_CTX0, %g1
	movrnz	%g4, MMUSTAT_CTXNON0, %g1
	add	%g6, %g1, %g6			/* stats + i + ctx */
	and	%g7, TTE_SZ_MASK, %g7
	sllx	%g7, MMUSTAT_ENTRY_SZ_SHIFT, %g7
	add	%g6, %g7, %g6			/* stats + i + ctx + pgsz */
	ldx	[%g6 + MMUSTAT_TICK], %g3
	add	%g3, %g5, %g3
	stx	%g3, [%g6 + MMUSTAT_TICK]
	ldx	[%g6 + MMUSTAT_HIT], %g3
	inc	%g3
	stx	%g3, [%g6 + MMUSTAT_HIT]
	retry

	! %g1 = CPU struct
	! %g4 = context
.checkipermmaps:
	brnz,pt	%g4, .itsbmiss		! only context zero has perm mappings
	  nop
	VCPU2GUEST_STRUCT(%g1, %g2)
	mov	GUEST_PERM_MAPPINGS_INCR*(NPERMMAPPINGS-1), %g3
	add	%g3, GUEST_PERM_MAPPINGS, %g3
	add	%g2, %g3, %g2
	mov	-(GUEST_PERM_MAPPINGS_INCR*(NPERMMAPPINGS-1)), %g3
	rdpr	%tpc, %g4
1:
	ldda	[ %g2 + %g3 ] ASI_QUAD_LDD, %g6		! Ld TTE (g7) + Tag (g6)

	! Figure page size match mask
	! FIXME: Could speed this by storing the mask ... but
	! atomicity problems with storage. Other option is
	! store pre-computed page size shift in tag bits 0-13
	brgez,pn %g7, 2f
	and	%g7, TTE_SZ_MASK, %g5
	add	%g5, %g5, %g1
	add	%g5, %g1, %g1		! Mult size by 3
	add	%g1, 13, %g1		! Add 13
	mov	1, %g5
	sllx	%g5, %g1, %g5		! Compute bytes per page
	sub	%g5, 1, %g5		! Page mask for TTE retrieved
	
	xor	%g6, %g4, %g6
	andncc	%g6, %g5, %g0		! Check for tag match

	beq,pt %xcc, 3f
	  nop

2:
	brlz,pt %g3, 1b
	  add	%g3, GUEST_PERM_MAPPINGS_INCR, %g3

	VCPU_STRUCT(%g1)
	ba,pt	%xcc, .itsbmiss
	  mov	%g0, %g4

3:
	! Found a matching entry - can we load it into the ITLB
	VCPU_STRUCT(%g1)
	add	%g2, %g3, %g2	! Ptr to map entry

	! Calculate index into perm bit set
	ldub	[%g1 + CPU_VID], %g3
	and	%g3, MAPPING_XWORD_MASK, %g4
	mov	1, %g5
	sllx	%g5, %g4, %g4	! Bit in mask
	srlx	%g3, MAPPING_XWORD_SHIFT, %g3
	sllx	%g3, MAPPING_XWORD_BYTE_SHIFT_BITS, %g3
	add	%g2, %g3, %g2

	ldx	[%g2 + MAPPING_ICPUSET], %g3
	btst	%g3, %g4
	bz,pn	%xcc, .itsbmiss
	  mov	%g0, %g4

	! Stuff entry - it's already been swizzled
	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection
	stxa	%g7, [%g5]ASI_ITLB_DATA_IN

	retry

.itsbmiss:
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest
	.empty

	! %g1 is CPU pointer
	! %g2 is MMU Fault Status Area
	! %g4 is context (possibly shifted - still OK for zero test)
	/* if ctx == 0 and ctx0 set TSBs used, take slow trap */
	/* if ctx != 0 and ctxnon0 set TSBs used, take slow trap */
	mov	CPU_NTSBS_CTXN, %g7
	movrz	%g4, CPU_NTSBS_CTX0, %g7
	ldx	[%g1 + %g7], %g7
	brnz,pn	%g7, .islowmiss
	nop

.ifastmiss:
	/*
	 * Update MMU_FAULT_AREA_INSTR
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_IMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_ICTX]
	/* fast misses do not update MMU_FAULT_AREA_IFT with MMU_FT_FASTMISS */
	! wrpr	%g0, TT_FAST_IMMU_MISS, %tt	/* already set */
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (TT_FAST_IMMU_MISS << TT_OFFSET_SHIFT), %g3
7:
	rdpr	%tl, %g2
	cmp	%g2, 1	/* trap happened at tl=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	add	%g5, %g3, %g3

1:
	mov	HPSTATE_GUEST, %g5		! set ENB bit
	jmp	%g3
	wrhpr	%g5, %hpstate

.islowmiss:
	/*
	 * Update MMU_FAULT_AREA_INSTR
	 */
	mov	MMU_TAG_TARGET, %g3
	ldxa	[%g3]ASI_IMMU, %g3	/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g3
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
	rdpr	%tpc, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
	mov	MMU_FT_MISS, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IFT]
	wrpr	%g0, TT_IMMU_MISS, %tt
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (TT_IMMU_MISS << TT_OFFSET_SHIFT), %g3
	ba,a	7b
	.empty

.itsb_inv_pgsz:
	/* IAX with FT=Invalid Page Size (15), VA, CTX */
	ba,pt	%xcc, .itsb_iax
	mov	MMU_FT_PAGESIZE, %g3

.itsb_ra_range:
	/* IAX with FT=Invalid TSB Entry (16), VA, CTX */
	mov	MMU_FT_INVTSBENTRY, %g3
	/*FALLTHROUGH*/

.itsb_iax:
	!! %g1 = cpup
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest		! Nothing we can do about this
	nop
	stx	%g3, [%g2 + MMU_FAULT_AREA_IFT]
	mov	MMU_TAG_TARGET, %g3
	ldxa	[%g3]ASI_IMMU, %g3	/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g3
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
	rdpr	%tpc, %g3
	stx	%g3, [%g2 + MMU_FAULT_AREA_IADDR]
	REVECTOR(TT_IAX)
	SET_SIZE(immu_miss)


	/* %g1 contains per CPU area */
	ENTRY_NP(dmmu_miss)
	rd	%tick, %g2
	stx	%g2, [%g1 + CPU_SCR0]
	ldxa	[%g0]ASI_DMMU, %g3	/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */

	! %g1 = CPU pointer
	! %g3 = tag target
	! %g4 = ctx

.checkdtsb0:
	! for context != 0 and unshared TSB, that ctx == TSB ctx
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_DMMU_TSB_PS0, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	! e.g. for shared TSBs in S9 xor value is ctx << 4
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .checkdtsb1	! tag mismatch
	nop
	brlz,pt %g7, .dtsbhit		! TTE valid
	nop

.checkdtsb1:
	! repeat check for second TSB
	brz,pn	%g4, 1f
	mov	%g3, %g2
	ld	[%g1 + CPU_TSBDS_CTXN + TSBD_BYTES + TSBD_CTX_INDEX], %g5
	cmp	%g5, -1
	be,pn	%icc, 1f
	nop
	! if TSB not shared, zero out context for match
	sllx	%g3, TAGTRG_VA_LSHIFT, %g2
	srlx	%g2, TAGTRG_VA_LSHIFT, %g2	! clear context
1:
	ldxa	[%g0]ASI_DMMU_TSB_PS1, %g5
	! if TSB desc. specifies xor of TSB index, do it here
	ldda	[%g5]ASI_QUAD_LDD, %g6	/* g6 = tag, g7 = data */
	cmp	%g6, %g2
	bne,pn	%xcc, .checkdpermmaps		! tag mismatch
	nop
	brgez,pn %g7, .checkdpermmaps		! TTE valid
	nop

.dtsbhit:
	! extract sz from tte
	TTE_SIZE(%g7, %g4, %g3, .dtsb_inv_pgsz)
	sub	%g4, 1, %g5	! %g5 page mask

	! extract ra from tte
	sllx	%g7, 64 - 40, %g3
	srlx	%g3, 64 - 40 + 13, %g3
	sllx	%g3, 13, %g3	! %g3 real address
	xor	%g7, %g3, %g7	! %g7 orig tte with ra field zeroed
	andn	%g3, %g5, %g3
	ldx	[%g1 + CPU_GUEST], %g6


	! %g1 cpu struct
	! %g2 --
	! %g3 raddr
	! %g4 page size
	! %g5 --
	! %g6 guest struct
	! %g7 TTE ready for pa
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g3, %g4, 3f, %g5, %g2)
	mov	%g2, %g3		! %g3	PA
4:
	! %g1 cpu struct
	! %g3 paddr
	! %g7 TTE ready for pa
	or	%g7, %g3, %g7	! %g7 new tte with pa

	CLEAR_TTE_LOCK_BIT(%g7, %g5)

	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection
	stxa	%g7, [%g5]ASI_DTLB_DATA_IN
	!
	! %g1 = CPU pointer
	! %g7 = TTE
	!
	ldx	[%g1 + CPU_MMUSTAT_AREA], %g6
	brnz,pn	%g6, 1f
	nop

	retry

1:
	rd	%tick, %g2
	ldx	[%g1 + CPU_SCR0], %g1
	sub	%g2, %g1, %g5
	!
	! %g5 = %tick delta
	! %g6 = MMU statistics area
	! %g7 = TTE
	!
	inc	MMUSTAT_D, %g6			/* stats + d */
	ldxa	[%g0]ASI_DMMU, %g3		/* tag target */
	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */
	mov	MMUSTAT_CTX0, %g1
	movrnz	%g4, MMUSTAT_CTXNON0, %g1
	add	%g6, %g1, %g6			/* stats + d + ctx */
	and	%g7, TTE_SZ_MASK, %g7
	sllx	%g7, MMUSTAT_ENTRY_SZ_SHIFT, %g7
	add	%g6, %g7, %g6			/* stats + d + ctx + pgsz */
	ldx	[%g6 + MMUSTAT_TICK], %g3
	add	%g3, %g5, %g3
	stx	%g3, [%g6 + MMUSTAT_TICK]
	ldx	[%g6 + MMUSTAT_HIT], %g3
	inc	%g3
	stx	%g3, [%g6 + MMUSTAT_HIT]
	retry


3:
	! %g1 cpu struct
	! %g2 --
	! %g3 raddr
	! %g4 page size
	! %g5 --
	! %g6 guest struct
	! %g7 TTE ready for pa
	! check for IO address
	! branch back to 4b with pa in %g3
	! must preserve %g1 and %g7
	RANGE_CHECK_IO(%g6, %g3, %g4, .dmmu_miss_io_found,
	    .dmmu_miss_io_not_found, %g2, %g5)
.dmmu_miss_io_found:
	ba,a	4b
	  nop

	! %g1 cpu struct
	! %g2 --
	! %g3 raddr
	! %g4 page size
	! %g5 --
	! %g6 guest struct
	! %g7 TTE ready for pa
.dmmu_miss_io_not_found:
	! Last chance - check the LDC mapin area
	ldx	[ %g6 + GUEST_LDC_MAPIN_BASERA ], %g5
	subcc	%g3, %g5, %g5
	bneg,pn	%xcc, .dtsb_ra_range
	  nop
	ldx	[ %g6 + GUEST_LDC_MAPIN_SIZE ], %g2
	subcc	%g5, %g2, %g0
	bneg,pt	%xcc, ldc_dtsb_hit
	  nop

		/* fall thru */

	ENTRY_NP(dtsb_miss)

	! %g1 = CPU struct
	! %g4 = context
.checkdpermmaps:
	brnz,pt	%g4, .dtsbmiss		! only context zero has perm mappings
	  nop
	VCPU2GUEST_STRUCT(%g1, %g2)
	mov	GUEST_PERM_MAPPINGS_INCR*(NPERMMAPPINGS-1), %g3
	add	%g3, GUEST_PERM_MAPPINGS, %g3
	add	%g2, %g3, %g2
	mov	-(GUEST_PERM_MAPPINGS_INCR*(NPERMMAPPINGS-1)), %g3

	mov	MMU_TAG_ACCESS, %g4
	ldxa	[%g4]ASI_DMMU, %g4	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g4, %g5, %g4

1:
	ldda	[ %g2 + %g3 ] ASI_QUAD_LDD, %g6		! Ld TTE (g7) + Tag (g6)

	! Figure page size match mask
	! FIXME: Could speed this by storing the mask ... but
	! atomicity problems with storage. Other option is
	! store pre-computed page size shift in tag bits 0-13
	brgez,pn %g7, 2f
	and	%g7, TTE_SZ_MASK, %g5
	add	%g5, %g5, %g1
	add	%g5, %g1, %g1		! Mult size by 3
	add	%g1, 13, %g1		! Add 13
	mov	1, %g5
	sllx	%g5, %g1, %g5		! Compute bytes per page
	sub	%g5, 1, %g5		! Page mask for TTE retrieved
	
	xor	%g6, %g4, %g6
	andncc	%g6, %g5, %g0		! Check for tag match

	beq,pt %xcc, 3f
	  nop

2:
	brlz,pt %g3, 1b
	  add	%g3, GUEST_PERM_MAPPINGS_INCR, %g3

	VCPU_STRUCT(%g1)
	ba,pt	%xcc, .dtsbmiss
	  mov	%g0, %g4

3:
	! Found a matching entry - can we load it into the DTLB
	VCPU_STRUCT(%g1)
	add	%g2, %g3, %g2	! Ptr to map entry

	! Calculate index into perm bit set
	ldub	[%g1 + CPU_VID], %g3
	and	%g3, MAPPING_XWORD_MASK, %g4
	mov	1, %g5
	sllx	%g5, %g4, %g4	! Bit in mask
	srlx	%g3, MAPPING_XWORD_SHIFT, %g3
	sllx	%g3, MAPPING_XWORD_BYTE_SHIFT_BITS, %g3
	add	%g2, %g3, %g2

	ldx	[%g2 + MAPPING_DCPUSET], %g3
	btst	%g3, %g4
	bz,pn	%xcc, .dtsbmiss
	  mov	%g0, %g4

	! Stuff entry - it's already been swizzled
	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection
	stxa	%g7, [%g5]ASI_DTLB_DATA_IN

	retry

.dtsbmiss:
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest
	.empty

	! %g1 is CPU pointer
	! %g2 is MMU Fault Status Area
	! %g4 is context (possibly shifted - still OK for zero test)
	/* if ctx == 0 and ctx0 set TSBs used, take slow trap */
	/* if ctx != 0 and ctxnon0 set TSBs used, take slow trap */
	mov	CPU_NTSBS_CTXN, %g7
	movrz	%g4, CPU_NTSBS_CTX0, %g7
	ldx	[%g1 + %g7], %g7
	brnz,pn	%g7, .dslowmiss
	nop

.dfastmiss:
	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	/* fast misses do not update MMU_FAULT_AREA_DFT with MMU_FT_FASTMISS */
	! wrpr	%g0, TT_FAST_DMMU_MISS, %tt	/* already set */
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (TT_FAST_DMMU_MISS << TT_OFFSET_SHIFT), %g3
7:
	rdpr	%tl, %g2
	cmp	%g2, 1 /* trap happened at tl=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	add	%g5, %g3, %g3

1:
	mov	HPSTATE_GUEST, %g5	! set ENB bit
	jmp	%g3
	wrhpr	%g5, %hpstate

.dslowmiss:
	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	mov	MMU_FT_MISS, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_DFT]
	wrpr	%g0, TT_DMMU_MISS, %tt
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (TT_DMMU_MISS << TT_OFFSET_SHIFT), %g3
	ba,a	7b
	.empty

.dtsb_inv_pgsz:
	/* DAX with FT=Invalid Page Size (15), VA, CTX */
	ba,pt	%xcc, .dtsb_dax
	mov	MMU_FT_PAGESIZE, %g3

.dtsb_ra_range:
	/* DAX with FT=Invalid TSB Entry (16), VA, CTX */
	mov	MMU_FT_INVTSBENTRY, %g3
	/*FALLTHROUGH*/

.dtsb_dax:
	!! %g1 = cpup
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest		! Nothing we can do about this
	nop
	stx	%g3, [%g2 + MMU_FAULT_AREA_DFT]
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	REVECTOR(TT_DAX)
	SET_SIZE(dmmu_miss)

	/* %g2 contains guest's miss info pointer (hv phys addr) */
	ENTRY_NP(dmmu_prot)
	/*
	 * TLB parity errors can cause normal MMU traps (N1 PRM
	 * section 12.3.3 and 12.3.4).  Check here for an outstanding
	 * parity error and have ue_err handle it instead.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC err reg
	set	(SPARC_ESR_DMDU | SPARC_ESR_DMSU), %g3	! is it a dmdu/dmsu err
	btst	%g3, %g1
	bnz	%xcc, ue_err			! err handler takes care of it
	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3	/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	/* fast misses do not update MMU_FAULT_AREA_DFT with MMU_FT_FASTPROT */
	wrpr	%g0, TT_FAST_DMMU_PROT, %tt	/* already set? XXXQ */
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (TT_FAST_DMMU_PROT << TT_OFFSET_SHIFT), %g3

	rdpr	%tl, %g2
	cmp	%g2, 1 /* trap happened at tl=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	add	%g5, %g3, %g3

1:
	mov	HPSTATE_GUEST, %g5	! set ENB bit
	jmp	%g3
	wrhpr	%g5, %hpstate
	SET_SIZE(dmmu_prot)


/*
 * set all TSB base registers to dummy
 * call sequence:
 * in:
 *	%g7 return address
 *
 * volatile:
 *	%g1
 */
	ENTRY_NP(set_dummytsb_ctx0)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DUMMYTSB], %g1

	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS0
	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS1

	stxa	%g0, [%g0]ASI_DTSB_CONFIG_CTX0
	jmp	%g7 + 4
	stxa	%g0, [%g0]ASI_ITSB_CONFIG_CTX0
	SET_SIZE(set_dummytsb_ctx0)

	ENTRY_NP(set_dummytsb_ctxN)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DUMMYTSB], %g1

	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS0
	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS1

	stxa	%g0, [%g0]ASI_DTSB_CONFIG_CTXN
	jmp	%g7 + 4
	stxa	%g0, [%g0]ASI_ITSB_CONFIG_CTXN
	SET_SIZE(set_dummytsb_ctxN)


	ENTRY_NP(dmmu_err)
	/*
	 * TLB parity errors can cause normal MMU traps (N1 PRM
	 * section 12.3.3 and 12.3.4).  Check here for an outstanding
	 * parity error and have ue_err handle it instead.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC err reg
	set	(SPARC_ESR_DMDU | SPARC_ESR_DMSU), %g2	! is it a dmdu/dmsu err
	btst	%g2, %g1
	bnz	%xcc, ue_err			! err handler takes care of it
	.empty

	VCPU_STRUCT(%g3)
	ldx	[%g3 + CPU_MMU_AREA], %g3
	brz,pn	%g3, watchdog_guest		! Nothing we can do about this
	.empty
	! %g3 - MMU_FAULT_AREA

	/*
	 * Update MMU_FAULT_AREA_DATA
	 */
	mov	MMU_SFAR, %g4
	ldxa	[%g4]ASI_DMMU, %g4
	stx	%g4, [%g3 + MMU_FAULT_AREA_DADDR]
	mov	MMU_SFSR, %g5
	ldxa	[%g5]ASI_DMMU, %g4 ! Capture SFSR
	stxa	%g0, [%g5]ASI_DMMU ! Clear SFSR

	mov	MMU_TAG_ACCESS, %g5
	ldxa	[%g5]ASI_DMMU, %g5
	set	(NCTXS - 1), %g6
	and	%g5, %g6, %g5
	stx	%g5, [%g3 + MMU_FAULT_AREA_DCTX]

	rdpr	%tt, %g1
	cmp	%g1, TT_DAX
	bne,pn	%xcc, 3f
	mov	MMU_FT_MULTIERR, %g6 ! unknown FT or multiple bits

	! %g4 - sfsr
	srlx	%g4, MMU_SFSR_FT_SHIFT, %g5
	andcc	%g5, MMU_SFSR_FT_MASK, %g5
	bz,pn	%xcc, 2f
	nop
	! %g5 - fault type
	! %g6 - sun4v ft
	andncc	%g5, MMU_SFSR_FT_PRIV, %g0
	movz	%xcc, MMU_FT_PRIV, %g6 ! priv is only bit set
	andncc	%g5, MMU_SFSR_FT_SO, %g0
	movz	%xcc, MMU_FT_SO, %g6	! so is only bit set
	andncc	%g5, MMU_SFSR_FT_ATOMICIO, %g0
	movz	%xcc, MMU_FT_NCATOMIC, %g6 ! atomicio is only bit set
	andncc	%g5, MMU_SFSR_FT_ASI, %g0
	movz	%xcc, MMU_FT_BADASI, %g6 ! badasi is only bit set
	andncc	%g5, MMU_SFSR_FT_NFO, %g0
	movz	%xcc, MMU_FT_NFO, %g6	! nfo is only bit set
	andncc	%g5, (MMU_SFSR_FT_VARANGE | MMU_SFSR_FT_VARANGE2), %g0
	movz	%xcc, MMU_FT_VARANGE, %g6 ! varange are only bits set
2:	stx	%g6, [%g3 + MMU_FAULT_AREA_DFT]
3:	REVECTOR(%g1)
	SET_SIZE(dmmu_err)


	ENTRY_NP(immu_err)
	/*
	 * TLB parity errors can cause normal MMU traps (N1 PRM
	 * section 12.3.1.  Check here for an outstanding
	 * parity error and have ue_err handle it instead.
	 */
	ldxa	[%g0]ASI_SPARC_ERR_STATUS, %g1	! SPARC err reg
	set	SPARC_ESR_IMDU, %g2		! is it a imdu err
	btst	%g2, %g1
	bnz	%xcc, ue_err			! err handler takes care of it
	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	.empty

	VCPU_STRUCT(%g3)
	ldx	[%g3 + CPU_MMU_AREA], %g3
	brz,pn	%g3, watchdog_guest	! Nothing we can do about this
	nop

	! %g3 - MMU_FAULT_AREA
	/* decode sfsr, update MMU_FAULT_AREA_INSTR */
	rdpr	%tpc, %g4
	stx	%g4, [%g3 + MMU_FAULT_AREA_IADDR]

	mov	MMU_PCONTEXT, %g5
	ldxa	[%g5]ASI_MMU, %g5
	movrnz	%g2, 0, %g5 ! primary ctx for TL=0, nucleus ctx for TL>0
	stx	%g5, [%g3 + MMU_FAULT_AREA_ICTX]

	! %g6 - sun4v ft
	mov	MMU_FT_MULTIERR, %g6 ! unknown FT or multiple bits

	mov	MMU_SFSR, %g5
	ldxa	[%g5]ASI_IMMU, %g4 ! Capture SFSR
	stxa	%g0, [%g5]ASI_IMMU ! Clear SFSR
	! %g4 - sfsr
	srlx	%g4, MMU_SFSR_FT_SHIFT, %g5
	andcc	%g5, MMU_SFSR_FT_MASK, %g5
	bz,pn	%xcc, 1f
	nop
	! %g5 - fault type
	andncc	%g5, MMU_SFSR_FT_PRIV, %g0
	movz	%xcc, MMU_FT_PRIV, %g6 ! priv is only bit set
	andncc	%g5, (MMU_SFSR_FT_VARANGE | MMU_SFSR_FT_VARANGE2), %g0
	movz	%xcc, MMU_FT_VARANGE, %g6 ! varange are only bits set
1:	stx	%g6, [%g3 + MMU_FAULT_AREA_IFT]
	REVECTOR(TT_IAX)
	SET_SIZE(immu_err)
