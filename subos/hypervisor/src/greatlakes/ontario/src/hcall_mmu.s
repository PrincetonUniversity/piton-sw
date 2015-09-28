/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_mmu.s
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

	.ident	"@(#)hcall_mmu.s	1.99	07/06/20 SMI"

#include <sys/asm_linkage.h>
#include <asi.h>
#include <sun4v/mmu.h>
#include <mmu.h>
#include <hprivregs.h>
#include <guest.h>
#include <offsets.h>
#include <mmustat.h>
#include <util.h>

/*
 * mmu_tsb_ctx0
 *
 * arg0 ntsb (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_tsb_ctx0)
	VCPU_GUEST_STRUCT(%g5, %g6)
	/* set cpu->ntsbs to zero now in case we error exit */
	stx	%g0, [%g5 + CPU_NTSBS_CTX0]
	/* Also zero out H/W bases */
	ba	set_dummytsb_ctx0
	rd	%pc, %g7
	brz,pn	%o0, setntsbs0
	cmp	%o0, MAX_NTSB
	bgu,pn	%xcc, herr_inval
	btst	TSBD_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	sllx	%o0, TSBD_SHIFT, %g3
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o1, %g3, herr_noraddr, %g2, %g1)
	! %g1 	paddr
	add	%g5, CPU_TSBDS_CTX0, %g2
	! xcopy trashes g1-4
	ba	xcopy
	rd	%pc, %g7
	/* loop over each TSBD and validate */
	mov	%o0, %g1
	add	%g5, CPU_TSBDS_CTX0, %g2
1:
	/* check pagesize - accept only valid encodings */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	cmp	%g3, NPGSZ
	bgeu,pn	%xcc, herr_badpgsz
	mov	1, %g4
	sll	%g4, %g3, %g3
	btst	TTE_VALIDSIZEARRAY, %g3
	bz,pn	%icc, herr_badpgsz
	nop

	/* check that pageszidx is set in pageszmask */
	lduw	[%g2 + TSBD_PGSZS_OFF], %g4
	btst	%g3, %g4
	bz,pn	%icc, herr_inval

	/* check that pageszidx is lowest-order bit of pageszmask */
	sub	%g3, 1, %g3
	btst	%g3, %g4
	bnz,p	%icc, herr_inval
	nop

	/* check associativity - only support 1-way */
	lduh	[%g2 + TSBD_ASSOC_OFF], %g3
	cmp	%g3, 1
	bne,pn	%icc, herr_badtsb
	nop
	/* check TSB size */
	ld	[%g2 + TSBD_SIZE_OFF], %g3
	sub	%g3, 1, %g4
	btst	%g3, %g4
	bnz,pn	%icc, herr_badtsb
	mov	TSB_SZ0_ENTRIES, %g4
	cmp	%g3, %g4
	blt,pn	%icc, herr_badtsb
	sll	%g4, TSB_MAX_SZCODE, %g4
	cmp	%g3, %g4
	bgt,pn	%icc, herr_badtsb
	nop
	/* check context index field - must be -1 (shared) or zero */
	ld	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, TSBD_CTX_IDX_SHARE
	be	%icc, 2f	! -1 is OK
	nop
	brnz,pn	%g3, herr_inval	! only one set of context regs
	nop
2:
	/* check reserved field - must be zero for now */
	ldx	[%g2 + TSBD_RSVD_OFF], %g3
	brnz,pn	%g3, herr_inval
	nop
	/* check TSB base real address */
	ldx	[%g2 + TSBD_BASE_OFF], %g3
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	sllx	%g4, TSBE_SHIFT, %g4
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g3, %g4, herr_noraddr, %g7, %g2)
	! restore %g2
	add	%g5, CPU_TSBDS_CTX0, %g2

	/* range OK, check alignment */
	sub	%g4, 1, %g4
	btst	%g3, %g4
	bnz,pn	%xcc, herr_badalign
	sub	%g1, 1, %g1
	brnz,pt	%g1, 1b
	add	%g2, TSBD_BYTES, %g2

	/* now setup H/W TSB regs */
	/* only look at first two TSBDs for now */
	add	%g5, CPU_TSBDS_CTX0, %g2
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	RA2PA_CONV(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS0

	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTX0 ! (PS0 only)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTX0 ! (PS0 only)

	/* process second TSBD, if available */
	cmp	%o0, 1
	be,pt	%xcc, 2f
	add	%g2, TSBD_BYTES, %g2	! move to next TSBD
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	RA2PA_CONV(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTX0_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTX0_PS1

	/* %g3 still has old CONFIG value. */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g7
	sllx	%g7, ASI_TSB_CONFIG_PS1_SHIFT, %g7
	or	%g3, %g7, %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTX0 ! (PS0 + PS1)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTX0 ! (PS0 + PS1)

2:
	stx	%o0, [%g5 + CPU_NTSBS_CTX0]
setntsbs0:
	clr	%o1	! no return value
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctx0)


/*
 * mmu_tsb_ctxnon0
 *
 * arg0 ntsb (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_tsb_ctxnon0)
	VCPU_GUEST_STRUCT(%g5, %g6)
	/* set cpu->ntsbs to zero now in case we error exit */
	stx	%g0, [%g5 + CPU_NTSBS_CTXN]
	/* Also zero out H/W bases */
	ba	set_dummytsb_ctxN
	rd	%pc, %g7
	brz,pn	%o0, setntsbsN
	cmp	%o0, MAX_NTSB
	bgu,pn	%xcc, herr_inval
	btst	TSBD_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	sllx	%o0, TSBD_SHIFT, %g3
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o1, %g3, herr_noraddr, %g2, %g1)
	! %g1	paddr
	/* xcopy(tsbs, cpu->tsbds, ntsbs*TSBD_BYTES) */
	add	%g5, CPU_TSBDS_CTXN, %g2
	! xcopy trashes g1-4
	ba	xcopy
	rd	%pc, %g7
	/* loop over each TSBD and validate */
	mov	%o0, %g1
	add	%g5, CPU_TSBDS_CTXN, %g2
1:
	/* check pagesize - accept only valid encodings */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	cmp	%g3, NPGSZ
	bgeu,pn	%xcc, herr_badpgsz
	mov	1, %g4
	sll	%g4, %g3, %g3
	btst	TTE_VALIDSIZEARRAY, %g3
	bz,pn	%icc, herr_badpgsz
	nop

	/* check that pageszidx is set in pageszmask */
	lduw	[%g2 + TSBD_PGSZS_OFF], %g4
	btst	%g3, %g4
	bz,pn	%icc, herr_inval

	/* check that pageszidx is lowest-order bit of pageszmask */
	sub	%g3, 1, %g3
	btst	%g3, %g4
	bnz,pn	%icc, herr_inval
	nop

	/* check associativity - only support 1-way */
	lduh	[%g2 + TSBD_ASSOC_OFF], %g3
	cmp	%g3, 1
	bne,pn	%icc, herr_badtsb
	nop
	/* check TSB size */
	ld	[%g2 + TSBD_SIZE_OFF], %g3
	sub	%g3, 1, %g4
	btst	%g3, %g4
	bnz,pn	%icc, herr_badtsb
	mov	TSB_SZ0_ENTRIES, %g4
	cmp	%g3, %g4
	blt,pn	%icc, herr_badtsb
	sll	%g4, TSB_MAX_SZCODE, %g4
	cmp	%g3, %g4
	bgt,pn	%icc, herr_badtsb
	nop
	/* check context index field - must be -1 (shared) or zero */
	ld	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, TSBD_CTX_IDX_SHARE
	be	%icc, 2f	! -1 is OK
	nop
	brnz,pn	%g3, herr_inval	! only one set of context regs
	nop
2:
	/* check reserved field - must be zero for now */
	ldx	[%g2 + TSBD_RSVD_OFF], %g3
	brnz,pn	%g3, herr_inval
	nop
	/* check TSB base real address */
	ldx	[%g2 + TSBD_BASE_OFF], %g3
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	sllx	%g4, TSBE_SHIFT, %g4
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g3, %g4, herr_noraddr, %g7, %g2)
	! restore %g2
	add	%g5, CPU_TSBDS_CTXN, %g2
	/* range OK, check alignment */
	sub	%g4, 1, %g4
	btst	%g3, %g4
	bnz,pn	%xcc, herr_badalign
	sub	%g1, 1, %g1
	brnz,pt	%g1, 1b
	add	%g2, TSBD_BYTES, %g2

	/* now setup H/W TSB regs */
	/* only look at first two TSBDs for now */
	add	%g5, CPU_TSBDS_CTXN, %g2
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	RA2PA_CONV(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS0
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS0

	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTXN ! (PS0 only)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTXN ! (PS0 only)

	/* process second TSBD, if available */
	cmp	%o0, 1
	be,pt	%xcc, 2f
	add	%g2, TSBD_BYTES, %g2	! move to next TSBD
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	RA2PA_CONV(%g6, %g1, %g1, %g4)
	ld	[%g2 + TSBD_SIZE_OFF], %g4
	srl	%g4, TSB_SZ0_SHIFT, %g4
1:
	btst	1, %g4
	srl	%g4, 1, %g4
	bz,a,pt	%icc, 1b
	  add	%g1, 1, %g1	! increment TSB size field

	stxa	%g1, [%g0]ASI_DTSBBASE_CTXN_PS1
	stxa	%g1, [%g0]ASI_ITSBBASE_CTXN_PS1

	/* %g3 still has old CONFIG value. */
	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g7
	sllx	%g7, ASI_TSB_CONFIG_PS1_SHIFT, %g7
	or	%g3, %g7, %g3
	stxa	%g3, [%g0]ASI_DTSB_CONFIG_CTXN ! (PS0 + PS1)
	stxa	%g3, [%g0]ASI_ITSB_CONFIG_CTXN ! (PS0 + PS1)

2:
	stx	%o0, [%g5 + CPU_NTSBS_CTXN]
setntsbsN:
	clr	%o1	! no return value
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctxnon0)


/*
 * mmu_tsb_ctx0_info
 *
 * arg0 maxtsbs (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ntsbs (%o1)
 */
	ENTRY_NP(hcall_mmu_tsb_ctx0_info)
	VCPU_GUEST_STRUCT(%g5, %g6)
	! %g5 cpup
	! %g6 guestp

	! actual ntsbs always returned in %o1, so save tsbs now
	mov	%o1, %g4
	! Check to see if ntsbs fits into the supplied buffer
	ldx	[%g5 + CPU_NTSBS_CTX0], %o1
	brz,pn	%o1, hret_ok
	cmp	%o1, %o0
	bgu,pn	%xcc, herr_inval
	nop

	btst	TSBD_ALIGNMENT - 1, %g4
	bnz,pn	%xcc, herr_badalign
	sllx	%o1, TSBD_SHIFT, %g3
	! %g3 size of tsbd in bytes
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g4, %g3, herr_noraddr, %g1, %g2)
	! %g2	paddr
	! %g2 pa of buffer
	! xcopy(cpu->tsbds, buffer, ntsbs*TSBD_BYTES)
	add	%g5, CPU_TSBDS_CTX0, %g1
	! clobbers %g1-%g4
	ba	xcopy
	rd	%pc, %g7

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctx0_info)


/*
 * mmu_tsb_ctxnon0_info
 *
 * arg0 maxtsbs (%o0)
 * arg1 tsbs (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ntsbs (%o1)
 */
	ENTRY_NP(hcall_mmu_tsb_ctxnon0_info)
	VCPU_GUEST_STRUCT(%g5, %g6)
	! %g5 cpup
	! %g6 guestp

	! actual ntsbs always returned in %o1, so save tsbs now
	mov	%o1, %g4
	! Check to see if ntsbs fits into the supplied buffer
	ldx	[%g5 + CPU_NTSBS_CTXN], %o1
	brz,pn	%o1, hret_ok
	cmp	%o1, %o0
	bgu,pn	%xcc, herr_inval
	nop

	btst	TSBD_ALIGNMENT - 1, %g4
	bnz,pn	%xcc, herr_badalign
	sllx	%o1, TSBD_SHIFT, %g3
	! %g3 size of tsbd in bytes
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g4, %g3, herr_noraddr, %g1, %g2)
	! %g2	paddr
	! %g2 pa of buffer
	! xcopy(cpu->tsbds, buffer, ntsbs*TSBD_BYTES)
	add	%g5, CPU_TSBDS_CTXN, %g1
	! clobbers %g1-%g4
	ba	xcopy
	rd	%pc, %g7

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_tsb_ctxnon0_info)


/*
 * mmu_map_addr - stuff ttes directly into the tlbs
 *
 * arg0 vaddr (%o0)
 * arg1 ctx (%o1)
 * arg2 tte (%o2)
 * arg3 flags (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_map_addr)
#if MAPTR /* { FIXME: */
	PRINT("mmu_map_addr: va=0x")
	PRINTX(%o0)
	PRINT(" ctx=0x")
	PRINTX(%o1)
	PRINT(" flags=0x")
	PRINTX(%o2)
	PRINT("\r\n")
1:
#endif /* } */
	VCPU_GUEST_STRUCT(%g1, %g6)

#ifdef STRICT_API
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)
#endif /* STRICT_API */

	! extract sz from tte
	TTE_SIZE(%o2, %g4, %g2, herr_badpgsz)
	sub	%g4, 1, %g5	! %g5 page mask

	! extract ra from tte
	sllx	%o2, 64 - 40, %g2
	srlx	%g2, 64 - 40 + 13, %g2
	sllx	%g2, 13, %g2	! %g2 real address
	xor	%o2, %g2, %g3	! %g3 orig tte with ra field zeroed
	andn	%g2, %g5, %g2
		/* FIXME: This eventually to also cover the IO
		 * address ranges, and TTE flags as appropriate
		 */
	RA2PA_RANGE_CONV(%g6, %g2, %g4, 3f, %g5, %g7)
	mov	%g7, %g2
4:	or	%g3, %g2, %g1	! %g1 new tte with pa

#ifndef STRICT_API
	set	(NCTXS - 1), %g3
	and	%o1, %g3, %o1
	andn	%o0, %g3, %o0
#endif /* STRICT_API */
	or	%o0, %o1, %g2	! %g2 tag
	mov	MMU_TAG_ACCESS, %g3 ! %g3 tag_access
	CLEAR_TTE_LOCK_BIT(%g1, %g4)
	set	TLB_IN_4V_FORMAT, %g5	! %g5 sun4v-style tte selection

	btst	MAP_DTLB, %o3
	bz	2f
	btst	MAP_ITLB, %o3

	stxa	%g2, [%g3]ASI_DMMU
	membar	#Sync
	stxa	%g1, [%g5]ASI_DTLB_DATA_IN
	! condition codes still set
2:	bz	1f
	nop

	stxa	%g2, [%g3]ASI_IMMU
	membar	#Sync
	stxa	%g1, [%g5]ASI_ITLB_DATA_IN

1:	HCALL_RET(EOK)

	! Check for I/O
3:
	RANGE_CHECK_IO(%g6, %g2, %g4, .hcall_mmu_map_addr_io_found,
	    .hcall_mmu_map_addr_io_not_found, %g1, %g5)
.hcall_mmu_map_addr_io_found:
	ba,a	4b
	  nop
.hcall_mmu_map_addr_io_not_found:
		! %g1 = cpu struct
		! %g2 = real address
		! %g3 = TTE without PA/RA field
		! %g6 = guest struct

	! FIXME: This test to be subsumed when we fix the RA mappings
	! for multiple RA blocks
	! %g1 guest struct
	! %g2 real address

	set	GUEST_LDC_MAPIN_BASERA, %g7
	ldx	[ %g6 + %g7 ], %g5
	subcc	%g2, %g5, %g5
	bneg,pn	%xcc, herr_noraddr
	  nop
	set	GUEST_LDC_MAPIN_SIZE, %g7
	ldx	[ %g6 + %g7 ], %g7
	subcc	%g5, %g7, %g0
		! check regs passed in to mapin_ra:
	bneg,pt %xcc, ldc_map_addr_api
	  nop

	ENTRY_NP(hcall_mmu_map_addr_ra_not_found)
	ba,a	herr_noraddr
	  nop
	SET_SIZE(hcall_mmu_map_addr)


/*
 * mmu_unmap_addr
 *
 * arg0 vaddr (%o0)
 * arg1 ctx (%o1)
 * arg2 flags (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_unmap_addr)
#if MAPTR /* { FIXME: */
	PRINT("mmu_unmap_addr: va=0x")
	PRINTX(%o0)
	PRINT(" ctx=0x")
	PRINTX(%o1)
	PRINT(" flags=0x")
	PRINTX(%o2)
	PRINT("\r\n")
1:
#endif /* } */
#ifdef STRICT_API
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o2, herr_inval)
#endif /* STRICT_API */
	mov	MMU_PCONTEXT, %g1
	set	(NCTXS - 1), %g2	! 8K page mask
	andn	%o0, %g2, %g2
	ldxa	[%g1]ASI_MMU, %g3 ! save current primary ctx
	stxa	%o1, [%g1]ASI_MMU ! switch to new ctx
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o2
	stxa	%g0, [%g2]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g2]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU !  restore original primary ctx
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_unmap_addr)


/*
 * mmu_demap_page
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 vaddr (%o2)
 * arg3 ctx (%o3)
 * arg4 flags (%o4)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_demap_page)
	orcc	%o0, %o1, %g0
	bnz,pn	%xcc, herr_notsupported ! cpulist not yet supported
#ifdef STRICT_API
	nop
	CHECK_VA_CTX(%o2, %o3, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o4, herr_inval)
#endif /* STRICT_API */
	mov	MMU_PCONTEXT, %g1
	set	(NCTXS - 1), %g2
	andn	%o2, %g2, %g2
	ldxa	[%g1]ASI_MMU, %g3
	stxa	%o3, [%g1]ASI_MMU
	btst	MAP_ITLB, %o4
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o4
	stxa	%g0, [%g2]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g2]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU ! restore primary ctx
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_demap_page)


/*
 * mmu_demap_ctx
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 ctx (%o2)
 * arg3 flags (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_demap_ctx)
	orcc	%o0, %o1, %g0
	bnz,pn	%xcc, herr_notsupported ! cpulist not yet supported
#ifdef STRICT_API
	nop
	CHECK_CTX(%o2, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)
#endif /* STRICT_API */
	set	TLB_DEMAP_CTX_TYPE, %g3
	mov	MMU_PCONTEXT, %g2
	ldxa	[%g2]ASI_MMU, %g7
	stxa	%o2, [%g2]ASI_MMU
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o3
	stxa	%g0, [%g3]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g3]ASI_DMMU_DEMAP
2:	stxa	%g7, [%g2]ASI_MMU ! restore primary ctx
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_demap_ctx)


/*
 * mmu_demap_all
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 flags (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_demap_all)
	orcc	%o0, %o1, %g0
	bnz,pn	%xcc, herr_notsupported ! cpulist not yet supported
#ifdef STRICT_API
	nop
	CHECK_MMU_FLAGS(%o2, herr_inval)
#endif /* STRICT_API */
	set	TLB_DEMAP_ALL_TYPE, %g3
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o2
	stxa	%g0, [%g3]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g3]ASI_DMMU_DEMAP
2:	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_demap_all)


/*
 * mmu_map_perm_addr
 *
 * arg0 vaddr (%o0)
 * arg1 context (%o1)  must be zero
 * arg2 tte (%o2)
 * arg3 flags (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_map_perm_addr)
#if MAPTR /* { FIXME: */
	PRINT("mmu_map_perm_addr: va=0x")
	PRINTX(%o0)
	PRINT(" ctx=0x")
	PRINTX(%o1)
	PRINT(" tte=0x")
	PRINTX(%o2)
	PRINT(" flags=0x")
	PRINTX(%o3)
	PRINT("\r\n")
1:
#endif /* } */

	brnz,pn	%o1, herr_inval
	  nop
	VCPU_GUEST_STRUCT(%g1, %g6)

	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)

	! Fail if tte isn't valid
	brgez,pn %o2, herr_inval
	  nop

	! Fail if flags indicate ITLB, but no execute perm
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	  nop
#if 1 /* FIXME: Hack for broken OBP */
	or	%o2, TTE_X, %o2
#endif
	btst	TTE_X, %o2
	bz,pn	%xcc, herr_inval
	  nop
1:
	! extract sz from tte
	TTE_SIZE(%o2, %g4, %g2, herr_badpgsz)
	sub	%g4, 1, %g5	! %g5 page mask

	! Fail if page-offset bits aren't zero
	btst	%g5, %o0
	bnz,pn	%xcc, herr_inval
	.empty

	! %g1 = cpu struct
	! %g4 = page size
	! %g5 = page size mask
	! %g6 = guest struct

	! extract ra from tte
	sllx	%o2, 64 - 56, %g2
	srlx	%g2, 64 - 56 + 13, %g2
	sllx	%g2, 13, %g2	! %g2 real address
	xor	%o2, %g2, %g3	! %g3 orig tte with ra field zeroed

#ifdef STRICT_API
	andcc	%g2, %g5, %g0
	bne,pn	%xcc, herr_inval	! if RA not page size aligned
	  nop
#else
	andn	%g2, %g5, %g2		! Align RA to page size
#endif

	! %g1 = cpu struct
	! %g2 = real address
	! %g3 = TTE with RA field zeroed
	! %g4 = page size
	! %g5 = page size mask
	! %g6 = guest struct

	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g2, %g4, herr_noraddr, %g5, %g7)
	mov	%g7, %g2	! %g2 	paddr
	or	%g3, %g2, %o2

	! Force clear TTE lock bit
	CLEAR_TTE_LOCK_BIT(%o2, %g5)

	! %o2 = swizzled tte
	!
	! %g1 = cpu struct
	! %g4 = page size
	! %g6 = guest struct

	sub	%g4, 1, %g3	! page mask

	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g7
	SPINLOCK_ENTER(%g7, %g2, %g5)

	! %o2 = swizzled tte
	!
	! %g1 = cpu struct
	! %g3 = page mask
	! %g6 = guest struct
	! %g7 = spin lock

	/* Search for existing perm mapping */
	add	%g6, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g6

	! %o2 = swizzled tte
	!
	! %g1 = perm mappings list
	! %g3 = page mask
	! %g6 = offset
	! %g7 = spin lock addr

	/*
	 * Skim mapping entries for potential conflict.
	 * NOTE: Start at end of array so we prefer to fill
	 * empty slots earlier on in the perm-mapping array.
	 *
	 * for (i=NPERMAPPINGS-1; i>=0 i--) {
	 *	if (((addr & table[i].mask)^table[i].tag) & mask) == 0) {
	 *		matching entry ... write over it.
	 *	}
	 * }
	 */

	mov	-1, %o1

.perm_map_loop:
	ldda	[ %g1 + %g6 ] ASI_QUAD_LDD, %g4		! Ld Tag (g4) + TTE (g5)

		! Record slot if empty
	brgez,a,pn %g5, .pml_next_loop
	  mov	%g6, %o1		! del-slot executed if branch taken

	and	%g5, TTE_SZ_MASK, %g2
	add	%g2, %g2, %g7
	add	%g2, %g7, %g7		! Mult by 3
	add	%g7, 13, %g7		! Add 13
	mov	1, %g2
	sllx	%g2, %g7, %g2		! Shift to get bytes of page size
	sub	%g2, 1, %g2		! Page mask for TTE retrieved

	xor	%o0, %g4, %g7
	andn	%g7, %g2, %g7
	andncc	%g7, %g3, %g7		! Check for tag match

	bne,pt %xcc, .pml_next_loop
	  nop

	! Brute force demap both I & D Tlbs:
	! FIXME: really only need to do pages ...
	mov	MMU_PCONTEXT, %g7
	ldxa	[%g7]ASI_MMU, %g2 ! save current primary ctx
	stxa	%g0, [%g7]ASI_MMU ! switch to ctx0
	stxa	%g0, [%o0]ASI_IMMU_DEMAP
	stxa	%g0, [%o0]ASI_DMMU_DEMAP
	stxa	%g2, [%g7]ASI_MMU !  restore original primary ctx

	ba,pt	%xcc, .pml_match
	  mov	%g6, %o1

.pml_next_loop:
	sub	%g6, MAPPING_SIZE, %g6
	brgez,pt %g6, .perm_map_loop
	  nop

.pml_match:
	cmp	%o1, -1
	bne,pn  %xcc, 2f
	nop
 
	GUEST_STRUCT(%g1)
	add	%g1, GUEST_PERM_MAPPINGS_LOCK, %g6
	SPINLOCK_EXIT(%g6)
	ba,pt	%xcc, herr_toomany
	nop
2:

	! %o2 = swizzled tte
	!
	! %g1 = perm mappings list
	! %g3 = page mask
	! %g6 = offset of matching or free entry

	! Fill in the new data.

	add	%g1, %o1, %g6
	membar	#StoreStore | #LoadStore

	! Now determine the offset and bit that needs setting for this vcpu
	! within the guest.

	VCPU_STRUCT(%g1)

	! %g1 = cpu struct
	! %g3 = page mask
	! %g6 = mapping entry


	/* Calculate this cpu's cpuset mask */
	ldub	[%g1 + CPU_VID], %g2
	and	%g2, MAPPING_XWORD_MASK, %g3
	mov	1, %g4
	sllx	%g4, %g3, %g3
	srlx	%g2, MAPPING_XWORD_SHIFT, %g2
	sllx	%g2, MAPPING_XWORD_BYTE_SHIFT_BITS, %g2
	add	%g6, %g2, %g2		! Just add offset to this for I or d cpuset arrays

	andcc	%o3, MAP_ITLB, %g0
	beq,pn	%xcc, .perm_map_testd
	  nop
	ldx	[ %g2 + MAPPING_ICPUSET ], %g4
	or	%g3, %g4, %g4
	stx	%g4, [ %g2 + MAPPING_ICPUSET ]

.perm_map_testd:
	andcc	%o3, MAP_DTLB, %g0
	beq,pn	%xcc, .perm_map_done
	  nop
	ldx	[ %g2 + MAPPING_DCPUSET ], %g4
	or	%g3, %g4, %g4
	stx	%g4, [ %g2 + MAPPING_DCPUSET ]

.perm_map_done:

	stx	%o0, [ %g6 + MAPPING_VA ]
	stx	%o2, [ %g6 + MAPPING_TTE ]	! Finally store the TTE

	membar	#StoreStore | #StoreLoad

	VCPU2GUEST_STRUCT(%g1, %g1)

	add	%g1, GUEST_PERM_MAPPINGS_LOCK, %g7
	
	SPINLOCK_EXIT(%g7)
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_map_perm_addr)


/*
 * mmu_unmap_perm_addr
 *
 * arg0 vaddr (%o0)
 * arg1 ctx (%o1)
 * arg2 flags (%o2)
 * --
 * ret0 status (%o0)
 */

/*
 * FIXME: Need to make this a subroutine call so it can
 * be performed as part of the guest and CPU exit clean up.
 */
	ENTRY_NP(hcall_mmu_unmap_perm_addr)
	brnz,pn	%o1, herr_inval
	nop
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o2, herr_inval)

	GUEST_STRUCT(%g2)

	add	%g2, GUEST_PERM_MAPPINGS_LOCK, %g7
	SPINLOCK_ENTER(%g7, %g3, %g5)

	! %g2 = guest struct
	! %g7 = spin lock

	/* Search for existing perm mapping */
	add	%g2, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g6

	! %g1 = perm mappings list
	! %g2 = guest struct
	! %g6 = offset
	! %g7 = spin lock addr

	/*
	 * Skim mapping entries for potential match

	 * for (i=NPERMAPPINGS-1; i>=0 i--) {
	 *	if ((addr & table[i].mask)^table[i].tag) == 0) {
	 *		matching entry ... invalidate it
	 *	}
	 * }
	 */

.perm_unmap_loop:
	ldda	[ %g1 + %g6 ] ASI_QUAD_LDD, %g4		! Ld Tag (g4) + TTE (g5)

		! Record slot if empty
	brgez,a,pn %g5, .puml_next_loop
	  nop

	and	%g5, TTE_SZ_MASK, %g5
	add	%g5, %g5, %g3
	add	%g5, %g3, %g3		! Multiply by 3
	add	%g3, 13, %g3		! Add 13
	mov	1, %g5
	sllx	%g5, %g3, %g3		! Shift to get bytes of page size
	sub	%g3, 1, %g3		! Page mask for TTE retrieved
	
	xor	%o0, %g4, %g5
	andncc	%g5, %g3, %g0		! Check for tag match

	be,pn %xcc, .puml_match
	  nop

.puml_next_loop:
	brgz,pt %g6, .perm_unmap_loop
	  sub	%g6, MAPPING_SIZE, %g6

	! %g2 = guest structure
	! Bail out no match was found
	add	%g2, GUEST_PERM_MAPPINGS_LOCK, %g7
	SPINLOCK_EXIT(%g7)
	ba,pt	%xcc, herr_nomap
	  nop

.puml_match:
	! %g1 = perm mappings list
	! %g2 = guest struct
	! %g6 = offset of matching entry

	! NOTE: We assume that the overlap match on insert is good enough that
	! there can never be two or more matching entries in the mapping table

	add	%g1, %g6, %g6
	membar	#StoreStore | #LoadStore

	! Now determine the offset and bit that needs setting for this vcpu
	! within the guest.

	VCPU_STRUCT(%g1)

	! %g1 = cpu struct
	! %g2 = guest struct
	! %g6 = mapping entry


	!
	! The remaining logic is as follows:
	! For both the I & D cases determine if we need to clear the
	! presence bits in the active cpusets, and perform a demap on the
	! local CPU (always is the simplest case since the other strands
	! will re-load anyway)
	!

	/* Calculate this cpu's cpuset mask */
	ldub	[%g1 + CPU_VID], %g3
	and	%g3, MAPPING_XWORD_MASK, %g5
	mov	1, %g4
	sllx	%g4, %g5, %g4
	srlx	%g3, MAPPING_XWORD_SHIFT, %g5
	sllx	%g5, MAPPING_XWORD_BYTE_SHIFT_BITS, %g5
	add	%g6, %g5, %g5		! Just add offset to this for I or d cpuset arrays

	! %g1 = cpu struct
	! %g2 = guest struct
	! %g3 = CPU vid
	! %g4 = xword bit for vcpu
	! %g5 = cpu xword offset into permmap
	! %g6 = permmap entry

	andcc	%o2, MAP_ITLB, %g0
	beq,pn	%xcc, .perm_umap_testd
	  nop
	ldx	[ %g5 + MAPPING_ICPUSET ], %g7
	andn	%g7, %g4, %g7
	stx	%g7, [ %g5 + MAPPING_ICPUSET ]

	mov	MMU_PCONTEXT, %g7
	ldxa	[%g7]ASI_MMU, %o1 ! save current primary ctx
	stxa	%g0, [%g7]ASI_MMU ! switch to ctx0
	stxa	%g0, [%o0]ASI_IMMU_DEMAP
	stxa	%o1, [%g7]ASI_MMU !  restore original primary ctx

.perm_umap_testd:
	andcc	%o2, MAP_DTLB, %g0
	beq,pn	%xcc, .perm_umap_finish
	  nop
	ldx	[ %g5 + MAPPING_DCPUSET ], %g7
	andn	%g7, %g4, %g7
	stx	%g7, [ %g5 + MAPPING_DCPUSET ]

	mov	MMU_PCONTEXT, %g7
	ldxa	[%g7]ASI_MMU, %o1 ! save current primary ctx
	stxa	%g0, [%g7]ASI_MMU ! switch to ctx0
	stxa	%g0, [%o0]ASI_DMMU_DEMAP
	stxa	%o1, [%g7]ASI_MMU !  restore original primary ctx

.perm_umap_finish:

	! %g1 = cpu struct
	! %g2 = guest struct
	! %g6 = permmap entry
	!
	! Final step... if all the CPU set entries are gone
	! then clean out the mapping entry itself

	mov	(NVCPU_XWORDS-1)*MAPPING_XWORD_SIZE, %g4
1:
	add	%g4, %g6, %g7
	ldx	[ %g7 + MAPPING_ICPUSET ], %g5
	ldx	[ %g7 + MAPPING_DCPUSET ], %g7
	orcc	%g5, %g7, %g0
		! Bail out if we find a non-zero entry
	bne,pn	%xcc, .perm_umap_done
	  nop
	brgz	%g4, 1b
	  sub	%g4, MAPPING_XWORD_SIZE, %g4

	stx	%g0, [ %g6 + MAPPING_TTE ]	! Invalidate first
	stx	%g0, [ %g6 + MAPPING_VA ]	! For sanity cleanse tag

.perm_umap_done:
	membar	#StoreStore | #StoreLoad

	VCPU2GUEST_STRUCT(%g1, %g1)

	add	%g1, GUEST_PERM_MAPPINGS_LOCK, %g7
	
	SPINLOCK_EXIT(%g7)
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_unmap_perm_addr)


#ifdef DEBUG

/*
 * mmu_perm_addr_info
 *
 * arg0 buffer (%o0)
 * arg1 nentries (%o1)
 * --
 * ret0 status (%o0)
 * ret1 nentries (%o1)
 */
	ENTRY_NP(hcall_mmu_perm_addr_info)
	HCALL_RET(ENOTSUPPORTED)
	SET_SIZE(hcall_mmu_perm_addr_info)

#endif /* DEBUG */


/*
 * niagara_mmustat_conf
 *
 * arg0 mmustat buffer ra (%o0)
 * --
 * ret0 status (%o0)
 * ret1 old mmustat buffer ra (%o1)
 */
	ENTRY_NP(hcall_niagara_mmustat_conf)
	btst	MMUSTAT_AREA_ALIGN - 1, %o0	! check alignment
	bnz,pn	%xcc, herr_badalign
	VCPU_GUEST_STRUCT(%g1, %g4)
	brz,a,pn %o0, 1f
	  mov	0, %g2
	RA2PA_RANGE_CONV(%g4, %o0, MMUSTAT_AREA_SIZE, herr_noraddr, %g3, %g2)
1:
	ldx	[%g1 + CPU_MMUSTAT_AREA_RA], %o1
	stx	%o0, [%g1 + CPU_MMUSTAT_AREA_RA]
	stx	%g2, [%g1 + CPU_MMUSTAT_AREA]
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_mmustat_conf)


/*
 * niagara_mmustat_info
 *
 * --
 * ret0 status (%o0)
 * ret1 mmustat buffer ra (%o1)
 */
	ENTRY_NP(hcall_niagara_mmustat_info)
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_MMUSTAT_AREA_RA], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_niagara_mmustat_info)
