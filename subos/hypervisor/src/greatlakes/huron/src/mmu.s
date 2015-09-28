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

	.ident	"@(#)mmu.s	1.6	07/07/11 SMI"

/*
 * Niagara2 MMU code
 */
#include <sys/asm_linkage.h>
#include <hprivregs.h>
#include <asi.h>
#include <traps.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>

#include <guest.h>
#include <offsets.h>
#include <debug.h>
#include <util.h>
#include <error_regs.h>
#include <error_asm.h>

	! %g1	cpup
	! %g2	8k-aligned real addr from tag access
	ENTRY_NP(rdmmu_miss)
	! offset handling
	! XXX if hypervisor access then panic instead of watchdog_guest
	VCPU2GUEST_STRUCT(%g1, %g7)
	set	8 KB, %g5
	RA2PA_RANGE_CONV(%g7, %g2, %g5, 1f, %g4, %g3)
	! %g3	PA
2:
	! tte valid, cp, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE_CP | TTE_P | TTE_W, %g2
	or	%g3, %g2, %g3
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN
	retry

1:
	RANGE_CHECK_IO(%g7, %g2, %g5, .rdmmu_miss_found, .rdmmu_miss_not_found,
	    %g3, %g4)
.rdmmu_miss_found:
	mov	%g2, %g3

	! tte valid, e, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE_E | TTE_P | TTE_W, %g2
	or	%g3, %g2, %g3
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g3, [%g2]ASI_DTLB_DATA_IN
	retry

	ALTENTRY(rdmmu_miss_not_found2)
.rdmmu_miss_not_found:
1:
	! %g2 real address
	! LEGION_GOT_HERE
	wrpr	%g0, TT_DAX, %tt
	mov	MMU_FT_INVALIDRA, %g1
	ba,pt	%xcc, dmmu_err_common	! (%g1=ft, %g2=addr, %g3=ctx)
	mov	0, %g3
	SET_SIZE(rdmmu_miss)

	! %g1	cpup
	! %g2	8k-aligned real addr from tag access

	ENTRY_NP(rimmu_miss)
	mov     MMU_TAG_ACCESS, %g2
	ldxa    [%g2]ASI_IMMU, %g2      /* tag access */
	set     ((1 << 13) - 1), %g3
	andn    %g2, %g3, %g2

	VCPU2GUEST_STRUCT(%g1, %g3)
	RA2PA_RANGE_CONV(%g3, %g2, %g0, 1f, %g4, %g1)
        ! %g1   PA


	! tte valid, cp, writable, priv
	mov	1, %g2
	sllx	%g2, 63, %g2
	or	%g2, TTE_CP | TTE_P | TTE_W, %g2
	or	%g1, %g2, %g1
	mov	TLB_IN_REAL, %g2	! Real bit
	stxa	%g1, [%g2]ASI_ITLB_DATA_IN
	retry

1:
	! %g2 real address
	! LEGION_GOT_HERE
	wrpr	%g0, TT_IAX, %tt
	mov	MMU_FT_INVALIDRA, %g1
	ba,pt	%xcc, immu_err_common	! (%g1=ft, %g2=addr, %g3=ctx)
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
	/* %g3 contains immu tag target */
	ENTRY_NP(immu_miss_ctx0)

	VCPU2GUEST_STRUCT(%g1, %g6)
	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g3, %g4)

	/*
	 * Look for a possible miss on a permanent entry.
	 * Note that the permanent mapping can have one of
	 * three states :-
	 *
	 * valid - TTE.V != 0. This is a valid mapping, check for
	 *	   a match. If not a match, continue the search
	 *	   with the next permanent mapping from the array.
	 *	   If it is a match, we have a hit, update the TLB
	 *	   and retry.
	 *
	 * invalid - TTE != 0 && TTE.V == 0. This is a TTE which has
	 *	   been used for a permanent mapping but has been 
	 *	   subsequently unmapped, setting the TTE.V bit to 0.
	 *	   This is not a match, continue the search
	 *	   with the next permanent mapping from the array.
	 *
	 * invalid - TTE == 0 && TTE.V == 0. This is a TTE which is
	 *	   still uninitialised and has never been used for a
	 *	   permanent mapping. This means that the other
	 *	   entries in the permanent mapping array are also
	 *	   unused (as we always use the first available
	 *	   permanent mapping array element for a mapping) so
	 *	   we can stop searching for a permanent mapping now,
	 *	   break out of the loop.
	 */
	mov	MMU_TAG_ACCESS, %g1
	ldxa	[%g1]ASI_IMMU, %g1
	add	%g6, GUEST_PERM_MAPPINGS, %g2
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3

	/*
	 * for (i = NPERMMAPPINGS - 1; i >= 0; i--) {
	 *	if (!table[i]->tte.v) {
	 *		continue;
	 *	}
	 *	shift = TTE_PAGE_SHIFT(table[i]->tte);
	 *	if ((table[i]->va >> shift) == (va >> shift)) {
	 *		break;
	 *	}
	 * }
	 */
.ipmap_loop:
	!! %g1 = tag access
	!! %g2 = permanent mapping table base address
	!! %g3 = current offset into table
	!! %g5 = matching entry
	add	%g2, %g3, %g5

	/*
	 * if (!tte) {
	 *	uninitialised, no more mappings, miss;
	 * }
	 * if (!tte.v) {
	 *	initialised but invalid, get next, continue;
	 * }
	 */
	ldx	[%g5 + MAPPING_TTE], %g6
	brlz,pt %g6, 1f				! TTE.V == 1
	nop
	brz,pt	%g6, .ipmap_miss		! TTE == 0
	nop
	ba,pt	%xcc, .ipmap_continue		! TTE != 0 && TTE.V == 0
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
1:
	/*
	 * (valid TTE, check for hit)
	 * shift = TTE_PAGE_SHIFT(m->tte);
	 * if ((m->va >> shift) == (va >> shift)) {
	 *	break;
	 * }
	 */
	TTE_SHIFT_NOCHECK(%g6, %g7, %g4)
	ldx	[%g5 + MAPPING_VA], %g6
	srlx	%g6, %g7, %g6
	srlx	%g1, %g7, %g7
	cmp	%g6, %g7
	be,a,pt	%xcc, .ipmap_hit
	  ldx	[%g5 + MAPPING_TTE], %g5
	! not a match
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	/* FALLTHRU */
.ipmap_continue:
	bgeu,pt	%xcc, .ipmap_loop
	nop

	ba,a,pt	%xcc, .ipmap_miss
	nop

.ipmap_hit:
	!! %g5 = tte (with pa) of matching entry

	GUEST_STRUCT(%g6)

	stxa	%g5, [%g0]ASI_ITLB_DATA_IN
	inc	GUEST_PERM_MAPPINGS_LOCK, %g6
	SPINLOCK_EXIT(%g6)
	retry

.ipmap_miss:
	VCPU_GUEST_STRUCT(%g1, %g6)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g6
	SPINLOCK_EXIT(%g6)

	rdpr	%gl, %g2
	ba,pt	%xcc, immu_miss_common
	ldxa	[%g0]ASI_IMMU, %g3          /* tag target */
	SET_SIZE(immu_miss_ctx0)

	/* %g1 contains per CPU area */
	/* %g2 contains %gl */
	/* %g3 contains immu tag target */
	ENTRY_NP(immu_miss_common)
	ALTENTRY(immu_miss_ctxnon0)
	cmp	%g2, MAXPGL
	bgu,pn	%xcc, watchdog_guest		/* enforce %gl <= MAXPGL */
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest		/* enforce CPU_MMU_AREA != 0 */
	nop

	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */

	/* if ctx == 0 and ctx0 set TSBs used, take slow trap */
	/* if ctx != 0 and ctxnon0 set TSBs used, take slow trap */
	mov	CPU_NTSBS_CTXN, %g7
	movrz	%g4, CPU_NTSBS_CTX0, %g7
	ldx	[%g1 + %g7], %g7
	brnz,pn	%g7, .islowmiss
	nop

.ifastmiss:
	/* update MMU_FAULT_AREA_INSTR */
#ifdef	TSBMISS_ALIGN_ADDR
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_IMMU, %g3		/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g3
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
#else	/* !TSBMISS_ALIGN_ADDR */
	mov	MMU_TAG_TARGET, %g3
	ldxa	[%g3]ASI_IMMU, %g3		/* tag target */
	srlx	%g3, 48, %g3
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
	rdpr	%tpc, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
#endif	/* !TSBMISS_ALIGN_ADDR */
	/* fast misses do not update MMU_FAULT_AREA_IFT with MMU_FT_FASTMISS */
	wrpr	%g0, TT_FAST_IMMU_MISS, %tt
	rdpr	%tba, %g3
	add	%g3, (TT_FAST_IMMU_MISS << TT_OFFSET_SHIFT), %g3
7:
	rdpr	%tl, %g2
	cmp	%g2, 1	/* trap happended at TL=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu	watchdog_guest
	add	%g5, %g3, %g3

1:
	TRAP_GUEST(%g3, %g1, %g2)
	/*NOTREACHED*/

.islowmiss:
	/* update MMU_FAULT_AREA_INSTR */
#ifdef	TSBMISS_ALIGN_ADDR
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_IMMU, %g3		/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g3
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
#else	/* !TSBMISS_ALIGN_ADDR */
	mov	MMU_TAG_TARGET, %g3
	ldxa	[%g3]ASI_IMMU, %g3		/* tag target */
	srlx	%g3, 48, %g3
	stx	%g3, [%g2 + MMU_FAULT_AREA_ICTX]
	rdpr	%tpc, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IADDR]
#endif	/* !TSBMISS_ALIGN_ADDR */
	mov	MMU_FT_MISS, %g4
	stx	%g4, [%g2 + MMU_FAULT_AREA_IFT]
	wrpr	%g0, TT_IMMU_MISS, %tt
	rdpr	%pstate, %g3
	or	%g3, PSTATE_PRIV, %g3
	wrpr	%g3, %pstate
	rdpr	%tba, %g3
	add	%g3, (TT_IMMU_MISS << TT_OFFSET_SHIFT), %g3
	ba,a	7b
	nop
	SET_SIZE(immu_miss_common)
	SET_SIZE(immu_miss_ctxnon0)

	/* %g1 contains per CPU area */
	/* %g3 contains dmmu tag target */
	ENTRY_NP(dmmu_miss_ctx0)

	VCPU2GUEST_STRUCT(%g1, %g6)
	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g3, %g4)

	/*
	 * Look for a possible miss on a permanent entry.
	 * Note that the permanent mapping can have one of
	 * three states :-
	 *
	 * valid - TTE.V != 0. This is a valid mapping, check for
	 *	   a match. If not a match, continue the search
	 *	   with the next permanent mapping from the array.
	 *	   If it is a match, we have a hit, update the TLB
	 *	   and retry.
	 *
	 * invalid - TTE != 0 && TTE.V == 0. This is a TTE which has
	 *	   been used for a permanent mapping but has been 
	 *	   subsequently unmapped, setting the TTE.V bit to 0.
	 *	   This is not a match, continue the search
	 *	   with the next permanent mapping from the array.
	 *
	 * invalid - TTE == 0 && TTE.V == 0. This is a TTE which is
	 *	   still uninitialised and has never been used for a
	 *	   permanent mapping. This means that the other
	 *	   entries in the permanent mapping array are also
	 *	   unused (as we always use the first available
	 *	   permanent mapping array element for a mapping) so
	 *	   we can stop searching for a permanent mapping now,
	 *	   break out of the loop.
	 */
	mov	MMU_TAG_ACCESS, %g1
	ldxa	[%g1]ASI_DMMU, %g1
	add	%g6, GUEST_PERM_MAPPINGS, %g2
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3

	/*
	 * for (i = NPERMMAPPINGS - 1; i >= 0; i--) {
	 *	if (!table[i]->tte) {
	 *		uninitialised, no more mappings, miss;
	 *	}
	 *	if (!table[i]->tte.v) {
	 *		initialised but invalid, get next, continue;
	 *	}
	 *	(valid TTE, check for hit)
	 *	shift = TTE_PAGE_SHIFT(table[i]->tte);
	 *	if ((table[i]->va >> shift) == (va >> shift)) {
	 *		break;
	 *	}
	 * }
	 */
.dpmap_loop:
	!! %g1 = tag access
	!! %g2 = permanent mapping table base address
	!! %g3 = current offset into table
	!! %g5 = matching entry
	add	%g2, %g3, %g5

	/*
	 * if (!tte) {
	 *	uninitialised, no more mappings, miss;
	 * }
	 * if (!tte.v) {
	 *	initialised but invalid, get next, continue;
	 * }
	 */
	ldx	[%g5 + MAPPING_TTE], %g6
	brlz,pt %g6, 1f				! TTE.V == 1
	nop
	brz,pt	%g6, .dpmap_miss		! TTE == 0
	nop
	ba,pt	%xcc, .dpmap_continue		! TTE != 0 && TTE.V == 0
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
1:
	/*
	 * shift = TTE_PAGE_SHIFT(m->tte);
	 * if ((m->va >> shift) == (va >> shift)) {
	 *	break;
	 * }
	 */
	TTE_SHIFT_NOCHECK(%g6, %g7, %g4)
	ldx	[%g5 + MAPPING_VA], %g6
	srlx	%g6, %g7, %g6
	srlx	%g1, %g7, %g7
	cmp	%g6, %g7
	be,a,pt	%xcc, .dpmap_hit
	  ldx	[%g5 + MAPPING_TTE], %g5
	! not a match
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	/* FALLTHRU */

.dpmap_continue:
	bgeu,pt	%xcc, .dpmap_loop
	nop

	ba,a,pt	%xcc, .dpmap_miss
	nop

.dpmap_hit:
	!! %g5 = tte (with pa) of matching entry

	GUEST_STRUCT(%g6)

	stxa	%g5, [%g0]ASI_DTLB_DATA_IN
	inc	GUEST_PERM_MAPPINGS_LOCK, %g6
	SPINLOCK_EXIT(%g6)
	retry

.dpmap_miss:
	VCPU_GUEST_STRUCT(%g1, %g6)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g6
	SPINLOCK_EXIT(%g6)

	rdpr	%gl, %g2
	ba,pt	%xcc, dmmu_miss_common
	ldxa	[%g0]ASI_DMMU, %g3          /* tag target */
	SET_SIZE(dmmu_miss_ctx0)

	/* %g1 contains per CPU area */
	/* %g2 contains %gl */
	/* %g3 contains dmmu tag target */
	ENTRY_NP(dmmu_miss_common)
	ALTENTRY(dmmu_miss_ctxnon0)
	cmp	%g2, MAXPGL
	bgu,pn	%xcc, watchdog_guest		/* enforce %gl <= MAXPGL */
	ldx	[%g1 + CPU_MMU_AREA], %g2
	brz,pn	%g2, watchdog_guest		/* enforce CPU_MMU_AREA != 0 */
	nop

	srlx	%g3, TAGTRG_CTX_RSHIFT, %g4	/* ctx from tag target */

	/* if ctx == 0 and ctx0 set TSBs used, take slow trap */
	/* if ctx != 0 and ctxnon0 set TSBs used, take slow trap */
	mov	CPU_NTSBS_CTXN, %g7
	movrz	%g4, CPU_NTSBS_CTX0, %g7
	ldx	[%g1 + %g7], %g7
	brnz,pn	%g7, .dslowmiss
	nop

.dfastmiss:
	/* update MMU_FAULT_AREA_DATA */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3		/* tag access */
	set	(NCTXS - 1), %g5
	andn	%g3, %g5, %g4
	and	%g3, %g5, %g5
	stx	%g4, [%g2 + MMU_FAULT_AREA_DADDR]
	stx	%g5, [%g2 + MMU_FAULT_AREA_DCTX]
	/* fast misses do not update MMU_FAULT_AREA_DFT with MMU_FT_FASTMISS */
	wrpr	%g0, TT_FAST_DMMU_MISS, %tt
	rdpr	%tba, %g3
	add	%g3, (TT_FAST_DMMU_MISS << TT_OFFSET_SHIFT), %g3
7:
	rdpr	%tl, %g2
	cmp	%g2, 1	/* trap happened at TL=0 */
	be,pt	%xcc, 1f
	.empty
	set	TRAPTABLE_SIZE, %g5

	cmp	%g2, MAXPTL
	bgu	watchdog_guest
	add	%g5, %g3, %g3

1:
	TRAP_GUEST(%g3, %g1, %g2)
	/*NOTREACHED*/

.dslowmiss:
	/* update MMU_FAULT_AREA_DATA */
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3		/* tag access */
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
	nop
	SET_SIZE(dmmu_miss_common)
	SET_SIZE(dmmu_miss_ctxnon0)

	/* %g2 contains guest's miss info pointer (hv phys addr) */
	ENTRY_NP(dmmu_prot)
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
	TRAP_GUEST(%g3, %g1, %g2)
	/*NOTREACHED*/
	SET_SIZE(dmmu_prot)


/*
 * set all TSB base registers to dummy
 * call sequence and store a copy in
 * cpu.mra[0->7].
 *
 * in:
 *	%g7 return address
 *
 * volatile:
 *	%g1
 */
	ENTRY_NP(set_dummytsb_ctx0)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DUMMYTSB], %g1
	STRAND_STRUCT(%g2)
	add	%g2, STRAND_MRA, %g3

	mov	TSB_CFG_CTX0_0, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3]
	mov	TSB_CFG_CTX0_1, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 1)]
	mov	TSB_CFG_CTX0_2, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 2)]
	mov	TSB_CFG_CTX0_3, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 3)]

	HVRET
	SET_SIZE(set_dummytsb_ctx0)

	ENTRY_NP(set_dummytsb_ctxN)
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DUMMYTSB], %g1
	STRAND_STRUCT(%g2)
	add	%g2, STRAND_MRA, %g3

	mov	TSB_CFG_CTXN_0, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 4)]
	mov	TSB_CFG_CTXN_1, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 5)]
	mov	TSB_CFG_CTXN_2, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 6)]
	mov	TSB_CFG_CTXN_3, %g2
	stxa	%g1, [%g2]ASI_MMU_TSB
	stx	%g1, [%g3 + (STRAND_MRA_INCR * 7)]
	HVRET
	SET_SIZE(set_dummytsb_ctxN)


/*
 * Initialize hardware tablewalk configuration registers.
 *
 * in:
 *	%g7 return address
 *
 * volatile:
 *	%g1-%g2
 */
	ENTRY_NP(mmu_hwtw_init)

	/*
	 * If no value has been set in the MD, the default is to set
	 * HWTW Predict mode.
	 */
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_SYS_HWTW_MODE], %g1
	movrlz	%g1, HWTW_PREDICT_MODE, %g1
	cmp	%g1, HWTW_PREDICT_MODE
	movg	%xcc, HWTW_PREDICT_MODE, %g1
	mov	HWTW_CFG, %g2
	stxa	%g1, [%g2]ASI_MMU_CFG

	mov	MMU_REAL_RANGE_0, %g1
	stxa	%g0, [%g1]ASI_MMU_HWTW
	mov	MMU_REAL_RANGE_1, %g1
	stxa	%g0, [%g1]ASI_MMU_HWTW
	mov	MMU_REAL_RANGE_2, %g1
	stxa	%g0, [%g1]ASI_MMU_HWTW
	mov	MMU_REAL_RANGE_3, %g1
	stxa	%g0, [%g1]ASI_MMU_HWTW

	HVRET
	SET_SIZE(mmu_hwtw_init)

	/*
	 * %g1 - contains the Data Fault Type
	 */
	ENTRY_NP(dmmu_err)
	mov	MMU_SFAR, %g2
	ldxa	[%g2]ASI_DMMU, %g2
	mov	MMU_TAG_ACCESS, %g3
	ldxa	[%g3]ASI_DMMU, %g3
	set	(NCTXS - 1), %g4
	and	%g3, %g4, %g3

	ALTENTRY(dmmu_err_common)
	/*
	 * %g1 - fault type
	 * %g2 - fault addr
	 * %g3 - fault ctx
	 */
	VCPU_STRUCT(%g4)
	ldx	[%g4 + CPU_MMU_AREA], %g4
	brz,pn	%g4, watchdog_guest
	nop
	stx	%g1, [%g4 + MMU_FAULT_AREA_DFT]
	stx	%g2, [%g4 + MMU_FAULT_AREA_DADDR]
	stx	%g3, [%g4 + MMU_FAULT_AREA_DCTX]

	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	rdpr	%tba, %g1
	rdpr	%tt, %g2
	sllx	%g2, TT_OFFSET_SHIFT, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	add	%g1, %g2, %g1
	TRAP_GUEST(%g1, %g2, %g3)
	/*NOTREACHED*/
	SET_SIZE(dmmu_err_common)
	SET_SIZE(dmmu_err)

	/*
	 * %g1 - contains the Instruction Fault Type
	 */
	ENTRY_NP(immu_err)
	rdpr	%tpc, %g2
#if 1 /* XXXQ */
	/* %tl>1: nucleus */
	/* %tl==1: primary */
	mov	%g0, %g3
#endif

	ALTENTRY(immu_err_common)
	/*
	 * %g1 - fault type
	 * %g2 - fault addr
	 * %g3 - fault ctx
	 */
	VCPU_STRUCT(%g4)
	ldx	[%g4 + CPU_MMU_AREA], %g4
	brz,pn	%g4, watchdog_guest
	nop
	stx	%g1, [%g4 + MMU_FAULT_AREA_IFT]
	stx	%g2, [%g4 + MMU_FAULT_AREA_IADDR]
	stx	%g3, [%g4 + MMU_FAULT_AREA_ICTX]

	rdhpr	%htstate, %g1
	btst	HTSTATE_HPRIV, %g1
	bnz,pn	%xcc, badtrap
	rdpr	%tba, %g1
	rdpr	%tt, %g2
	sllx	%g2, TT_OFFSET_SHIFT, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	add	%g1, %g2, %g1
	TRAP_GUEST(%g1, %g2, %g3)
	/*NOTREACHED*/
	SET_SIZE(immu_err_common)
	SET_SIZE(immu_err)

	/*
	 * instruction_invalid_TSB_entry trap
	 */
	ENTRY_NP(itsb_err)

	/*
	 * Find the RA for the VA from the Tag Access register.
	 * Get the PA of the TTE from each D-TSB pointer register.
	 * Read the TTE Tag/data  from that PA and check whether the
	 * tag matches. If we have a match, get the RA from the TTE data.
	 *
	 * N2 HWTW puts the PA of the four TSB entries it checked into
	 * the MMU I/D-TSB Pointer registers.
	 */
	mov	MMU_TAG_TARGET, %g2
	ldxa	[%g2]ASI_IMMU, %g2
	srlx	%g2, TAGTRG_CTX_RSHIFT, %g4
	brnz	%g4, .itsb_err_ctxn
	mov	MMU_ITSB_PTR_0, %g3

.itsb_err_ctx0:
	mov	TSB_CFG_CTX0_0, %g1
0:
	!! %g1 TSB Config Register
	!! %g2 Tag Target
	!! %g3 TSB Pointer Register

	ldxa	[%g1]ASI_MMU_TSB, %g5		! %g5 TSB Config
	brgez,pn %g5, 1f
	nop

	ldxa	[%g3]ASI_MMU_TSB, %g6		! %g6 PA of I-TSB entry
	brz,pn	%g6, 1f
	nop

	! load the TTE tag/data from the TSB
	ldda	[%g6]ASI_QUAD_LDD, %g4		! %g4 tag, %g5 data

	brgez,pn %g5, 1f			! check TTE.data.v bit 63,
						! if not set, TTE invalid

	cmp	%g4, %g2			! TTE.Tag == Tag Target ?
	be,pn	%xcc, .itsb_err_RA_found
	nop

1:
	! get next TSB pointer and configuration register
	inc	8, %g1				! TSB Config + 8
	cmp	%g3, MMU_ITSB_PTR_3
	bl,pt	%xcc, 0b
	inc	8, %g3				! ITSB_PTR VA + 8

	! no TTE found for this VA.  That must mean it got evicted from
	! the TSB
	retry

.itsb_err_ctxn:
	mov	TSB_CFG_CTXN_0, %g1
0:
	!! %g1 TSB Config Register
	!! %g2 Tag Target
	!! %g3 TSB Pointer Register

	ldxa	[%g1]ASI_MMU_TSB, %g7		! %g7 TSB Config
	brgez,pn %g7, 1f
	nop

	ldxa	[%g3]ASI_MMU_TSB, %g6		! %g6 PA of I-TSB entry
	brz,pn	%g6, 1f
	nop

	! load the TTE tag/data from the TSB
	ldda	[%g6]ASI_QUAD_LDD, %g4		! %g4 tag, %g5 data

	brgez,pn %g5, 1f			! check TTE.data.v bit 63,
						! if not set, TTE invalid

	/*
	 * Check whether "use-context-0" or "use-context-1" is in effect
	 * if so, ignore the context when checking for a tag match.
	 */
	srlx	%g7, TSB_CFG_USE_CTX1_SHIFT, %g7
	and	%g7, (USE_TSB_PRIMARY_CTX | USE_TSB_SECONDARY_CTX), %g7

	sllx	%g2, TAGTRG_VA_LSHIFT, %g6	! clear [63:42] of Tag Target
	srlx	%g6, TAGTRG_VA_LSHIFT, %g6	!   (context)
	movrz	%g7, %g2, %g6			! go with masked Tag Target?

	cmp	%g4, %g6			! TTE.tag == Tag Target ?
	be,pn	%xcc, .itsb_err_RA_found
	nop
1:
	! get next TSB pointer and configuration register
	inc	8, %g1				! TSB Config + 8
	cmp	%g3, MMU_ITSB_PTR_3
	bl,pt	%xcc, 0b
	inc	8, %g3				! ITSB_PTR + 8

	! no TTE found for this VA.  That must mean it got evicted from
	! the TSB
	retry

.itsb_err_RA_found:

	! found the TSB entry for the VA
	! %g5	TTE.data, RA is bits[55:13]
	srlx	%g5, 13, %g5
	sllx	%g5, 13 + 63 - 55, %g5
	srlx	%g5, 63 - 55, %g2		! RA -> %g2

	/*
	 * RA[55:40] must be zero
	 */
	srlx	%g2, RA_55_40_SHIFT, %g3
	set	RA_55_40_MASK, %g5
	and	%g3, %g5, %g3
	brnz,pn	%g3, .itsb_invalid_ra_err
	nop

	/*
	 * Find the guest memory segment that contains this RA
	 * If this RA is not allocated to the guest, revector to the
	 * guests trap handler. Note that this can be either a
	 * memory or I/O segment.
	 */
	GUEST_STRUCT(%g5)
	RA_GET_SEGMENT(%g5, %g2, %g3, %g4)
	! %g3	segment

	/*
	 * If we have a valid segment for this RA, set up the RA->PA
	 * translation in the MMU HWTW range/offset registers
	 */
	brnz,pn	%g3, .tsb_err_check_hwtw_regs
	nop

	/*
	 * No valid guest memory segment for this RA -or-
	 * RA[55:40] not zero
	 */
.itsb_invalid_ra_err:
	rdpr	%tba, %g1
	mov	TT_IAX, %g2
	wrpr	%g2, %tt
	sllx	%g2, TT_OFFSET_SHIFT, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	VCPU_STRUCT(%g3)
	ldx	[%g3 + CPU_MMU_AREA], %g3
	brz,pn	%g3, watchdog_guest	! Nothing we can do about this
	nop
	!! %g3 - MMU_FAULT_AREA
	rdpr	%tpc, %g4
	stx	%g4, [%g3 + MMU_FAULT_AREA_IADDR]
	mov	MMU_TAG_ACCESS, %g5
	ldxa	[%g5]ASI_IMMU, %g5
	set	(NCTXS - 1), %g6
	and	%g5, %g6, %g5
	stx	%g5, [%g3 + MMU_FAULT_AREA_ICTX]
	mov	MMU_FT_INVALIDRA, %g6
	stx	%g6, [%g3 + MMU_FAULT_AREA_IFT]
	add	%g1, %g2, %g1
	TRAP_GUEST(%g1, %g2, %g3)
	/*NOTREACHED*/
	SET_SIZE(itsb_err)

	/*
	 * data_invalid_TSB_entry trap
	 */
	ENTRY_NP(dtsb_err)

	/*
	 * Find the RA for the VA from the Tag Access register.
	 * Get the PA of the TTE from each D-TSB pointer register.
	 * Read the TTE Tag/data  from that PA and check whether the
	 * tag matches. If we have a match, get the RA from the TTE data.
	 *
	 * N2 HWTW puts the PA of the four TSB entries it checked into
	 * the MMU I/D-TSB Pointer registers.
	 */
	mov	MMU_TAG_TARGET, %g2
	ldxa	[%g2]ASI_DMMU, %g2
	srlx	%g2, TAGTRG_CTX_RSHIFT, %g4
	brnz	%g4, .dtsb_err_ctxn
	mov	MMU_DTSB_PTR_0, %g3

.dtsb_err_ctx0:
	mov	TSB_CFG_CTX0_0, %g1
0:
	!! %g1 TSB Config Register
	!! %g2 Tag Target
	!! %g3 TSB Pointer Register

	ldxa	[%g1]ASI_MMU_TSB, %g5		! %g5 TSB Config
	brgez,pn %g5, 1f
	nop

	ldxa	[%g3]ASI_MMU_TSB, %g6		! %g6 PA of D-TSB entry
	brz,pn	%g6, 1f
	nop

	! load the TTE tag/data from the TSB
	ldda	[%g6]ASI_QUAD_LDD, %g4		! %g4 tag, %g5 data

	brgez,pn %g5, 1f			! check TTE.data.v bit 63,
						! if not set, TTE invalid

	cmp	%g4, %g2			! TTE.Tag == Tag Target ?
	be,pn	%xcc, .dtsb_err_RA_found
	nop

1:
	! get next TSB pointer and configuration register
	inc	8, %g1				! TSB Config + 8
	cmp	%g3, MMU_DTSB_PTR_3
	bl,pt	%xcc, 0b
	inc	8, %g3				! DTSB_PTR VA + 8

	! no TTE found for this VA.  That must mean it got evicted from
	! the TSB
	retry

.dtsb_err_ctxn:
	mov	TSB_CFG_CTXN_0, %g1
0:
	!! %g1 TSB Config Register
	!! %g2 Tag Target
	!! %g3 TSB Pointer Register

	ldxa	[%g1]ASI_MMU_TSB, %g7		! %g7 TSB Config
	brgez,pn %g7, 1f
	nop

	ldxa	[%g3]ASI_MMU_TSB, %g6		! %g6 PA of D-TSB entry
	brz,pn	%g6, 1f
	nop

	! load the TTE tag/data from the TSB
	ldda	[%g6]ASI_QUAD_LDD, %g4		! %g4 tag, %g5 data

	brgez,pn %g5, 1f			! check TTE.data.v bit 63,
						! if not set, TTE invalid

	/*
	 * Check whether "use-context-0" or "use-context-1" is in effect
	 * if so, ignore the context when checking for a tag match.
	 */
	srlx	%g7, TSB_CFG_USE_CTX1_SHIFT, %g7
	and	%g7, (USE_TSB_PRIMARY_CTX | USE_TSB_SECONDARY_CTX), %g7

	sllx	%g2, TAGTRG_VA_LSHIFT, %g6	! clear [63:42] of Tag Target
	srlx	%g6, TAGTRG_VA_LSHIFT, %g6	!   (context)
	movrz	%g7, %g2, %g6			! go with masked Tag Target?

	cmp	%g4, %g6			! TTE.tag == Tag Target ?
	be,pn	%xcc, .dtsb_err_RA_found
	nop
1:
	! get next TSB pointer and configuration register
	inc	8, %g1				! TSB Config + 8
	cmp	%g3, MMU_DTSB_PTR_3
	bl,pt	%xcc, 0b
	inc	8, %g3				! DTSB_PTR VA + 8

	! no TTE found for this VA.  That must mean it got evicted from
	! the TSB
	retry

.dtsb_err_RA_found:

	! found the TSB entry for the VA
	! %g5	TTE.data, RA is bits[55:13]
	srlx	%g5, 13, %g5
	sllx	%g5, 13 + 63 - 55, %g5
	srlx	%g5, 63 - 55, %g2		! RA -> %g2

	/*
	 * RA[55:40] must be zero
	 */
	srlx	%g2, RA_55_40_SHIFT, %g3
	set	RA_55_40_MASK, %g5
	and	%g3, %g5, %g3
	brnz,a,pn %g3, .dtsb_invalid_ra_err
	nop

	/*
	 * Find the guest memory segment that contains this RA
	 * If this RA is not allocated to the guest, revector to the
	 * guests trap handler. Note that this can be either a
	 * memory or I/O segment.
	 */
	GUEST_STRUCT(%g5)
	RA_GET_SEGMENT(%g5, %g2, %g3, %g4)
	! %g3	segment
	brz,pn	%g3, .dtsb_invalid_ra_err
	nop

	/*
	 * We have a valid guest memory segment for this RA. Use this
	 * to populate one of the MMU Real Range/Physical Offset registers
	 * Find the first disabled Real range/offset registers. If all are
	 * enabled, disable all four range/offset pairs and start again
	 */
.tsb_err_check_hwtw_regs:
	! %g2	RA
	! %g3	guest memory segment
	mov	MMU_REAL_RANGE_0, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g5
	brgez,pn	%g5, .tsb_err_ra_hwtw_insert	! enable, (bit 63), not set
	mov	MMU_PHYS_OFF_0, %g5

	mov	MMU_REAL_RANGE_1, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g5
	brgez,pn	%g5, .tsb_err_ra_hwtw_insert	! enable, (bit 63), not set
	mov	MMU_PHYS_OFF_1, %g5

	mov	MMU_REAL_RANGE_2, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g5
	brgez,pn	%g5, .tsb_err_ra_hwtw_insert	! enable, (bit 63), not set
	mov	MMU_PHYS_OFF_2, %g5

	mov	MMU_REAL_RANGE_3, %g4
	ldxa	[%g4]ASI_MMU_HWTW, %g5
	brgez,pn	%g5, .tsb_err_ra_hwtw_insert	! enable, (bit 63), not set
	mov	MMU_PHYS_OFF_3, %g5

	! all the HWTW range/offsets in use, disable them all
	mov	MMU_REAL_RANGE_0, %g4
	stxa	%g0, [%g4]ASI_MMU_HWTW
	mov	MMU_REAL_RANGE_1, %g4
	stxa	%g0, [%g4]ASI_MMU_HWTW
	mov	MMU_REAL_RANGE_2, %g4
	stxa	%g0, [%g4]ASI_MMU_HWTW
	mov	MMU_REAL_RANGE_3, %g4
	stxa	%g0, [%g4]ASI_MMU_HWTW
	mov	MMU_PHYS_OFF_3, %g5

	! fall through, leave range/offset 0/1/2 for next time to save
	! a little search time

.tsb_err_ra_hwtw_insert:
	/*
	 * Insert the base/limit/offset from the guest memory segment into
	 * the MMU Real Range/Physical Offset registers.
	 *
	 * Note that the base/limit/offset are >> 13 for the MMU HWTW registers
	 *
	 * %g3	guest memory segment
	 * %g4	VA of ASI_MMU_HWTW of REAL_RANGE
	 * %g5	VA of ASI_MMU_HWTW of PHYS_OFFSET
	 */
	mov	1, %g2
	sllx	%g2, 63, %g2				! MMU Real Range enable bit[63]
	ldx	[%g3 + RA2PA_SEGMENT_LIMIT], %g6
	srlx	%g6, 13, %g6
	sllx	%g6, REALRANGE_BOUNDS_SHIFT, %g6	! MMU Real Range limit bits[53:27]
	or	%g6, %g2, %g2
	ldx	[%g3 + RA2PA_SEGMENT_BASE], %g6
	srlx	%g6, 13, %g6
	sllx	%g6, REALRANGE_BASE_SHIFT, %g6		! MMU Real Range base bits[26:0]
	or	%g6, %g2, %g2
	stxa	%g2, [%g4]ASI_MMU_HWTW			! MMU Real Range

	ldx	[%g3 + RA2PA_SEGMENT_OFFSET], %g6
	srlx	%g6, 13, %g6
	sllx	%g6, PHYSOFF_SHIFT, %g6
	stxa	%g6, [%g5]ASI_MMU_HWTW			! MMU Physical Offset

	/*
	 * Now we have a valid RA->PA translation ready for the VA, the HWTW
	 * TSB TTE RA->PA  translation will succeed so we just re-execute
	 * the instruction
	 */

	retry

	/*
	 * No valid guest memory segment for this RA -or-
	 * RA[55:40] not zero
	 */
.dtsb_invalid_ra_err:
	rdpr	%tba, %g1
	mov	TT_DAX, %g2
	wrpr	%g2, %tt
	sllx	%g2, TT_OFFSET_SHIFT, %g2
	add	%g1, %g2, %g1
	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	clr	%g2
	cmp	%g3, 1
	movne	%xcc, 1, %g2
	sllx	%g2, 14, %g2
	VCPU_STRUCT(%g3)
	ldx	[%g3 + CPU_MMU_AREA], %g3
	brz,pn	%g3, watchdog_guest	! Nothing we can do about this
	nop
	!! %g3 - MMU_FAULT_AREA
	stx	%g0, [%g3 + MMU_FAULT_AREA_DADDR]	/* XXX */
	mov	MMU_TAG_ACCESS, %g5
	ldxa	[%g5]ASI_DMMU, %g5
	set	(NCTXS - 1), %g6
	and	%g5, %g6, %g5
	stx	%g5, [%g3 + MMU_FAULT_AREA_DCTX]
	mov	MMU_FT_INVALIDRA, %g6
	stx	%g6, [%g3 + MMU_FAULT_AREA_DFT]
	add	%g1, %g2, %g1
	TRAP_GUEST(%g1, %g2, %g3)
	/*NOTREACHED*/
	SET_SIZE(dtsb_err)
