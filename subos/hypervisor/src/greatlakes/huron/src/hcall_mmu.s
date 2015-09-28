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

	.ident	"@(#)hcall_mmu.s	1.3	07/07/17 SMI"

	.file	"hcall_mmu.s"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>
#include <sun4v/mmu.h>
#include <hprivregs.h>
#include <offsets.h>
#include <config.h>
#include <guest.h>
#include <util.h>
#include <debug.h>

#define	MAPTR	0
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
	HVCALL(set_dummytsb_ctx0)
	brz,pn	%o0, setntsbs0
	cmp	%o0, MAX_NTSB
	bgu,pn	%xcc, herr_inval
	btst	TSBD_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	sllx	%o0, TSBD_SHIFT, %g3
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o1, %g3, herr_noraddr, %g2, %g1)
        ! %g1   paddr

	/* xcopy(tsbs, cpu->tsbds, ntsbs*TSBD_BYTES) */
	add	%g5, CPU_TSBDS_CTX0, %g2
	! xcopy trashes g1-4
	HVCALL(xcopy)
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
	bnz,pn	%icc, herr_inval
	nop

	/* check associativity - only support 1-way */
	lduh	[%g2 + TSBD_ASSOC_OFF], %g3
	cmp	%g3, 1
	bne,pn	%icc, herr_badtsb
	nop
	/* check TSB size */
	lduw	[%g2 + TSBD_SIZE_OFF], %g3
	sub	%g3, 1, %g4
	btst	%g3, %g4		! check for power-of-two
	bnz,pn	%xcc, herr_badtsb
	mov	TSB_SZ0_ENTRIES, %g4
	cmp	%g3, %g4
	blu,pn	%xcc, herr_badtsb
	sll	%g4, TSB_MAX_SZCODE, %g4
	cmp	%g3, %g4
	bgu,pn	%xcc, herr_badtsb
	nop
	/* check context index field - must be -1 (shared) or zero/one */
	lduw	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, TSBD_CTX_IDX_SHARE
	be,pt	%xcc, 2f	! -1 is OK
	nop
	cmp	%g3, MAX_NCTX_INDEX
	bgu,pn	%xcc, herr_inval
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

	/* now setup HWTW regs */
	! %g5 = CPU pointer
	clr	%g7
.ctx0_tsbd_loop:
	cmp	%g7, %o0
	bgeu,pn	%xcc, .ctx0_tsbd_finish
	nop

	add	%g5, CPU_TSBDS_CTX0, %g2
	sllx	%g7, TSBD_SHIFT, %g1
	add	%g2, %g1, %g2
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	RA2PA_CONV(%g6, %g1, %g1, %g4)		! start with TSB base PA

	lduw	[%g2 + TSBD_SIZE_OFF], %g4

	dec	%g4
	popc	%g4, %g4
	dec	TSB_SZ0_SHIFT, %g4
	or	%g1, %g4, %g1

	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g4
	sll	%g4, TSB_CFG_PGSZ_SHIFT, %g4
	or	%g1, %g4, %g1			! add page size field
	or	%g1, TSB_CFG_RA_NOT_PA, %g1	! add RA not PA bit
	clr	%g4
	ld	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, 0				! use primary-ctx0 always?
	move	%xcc, USE_TSB_PRIMARY_CTX, %g4
	cmp	%g3, 1				! use secondary-ctx0 always?
	move	%xcc, USE_TSB_SECONDARY_CTX, %g4
	sllx	%g4, TSB_CFG_USE_CTX1_SHIFT, %g4
	or	%g1, %g4, %g1			! add any use-ctx0|ctx1 bits
	mov	1, %g4
	sllx	%g4, 63, %g4
	or	%g1, %g4, %g1			! add valid bit

	mov	TSB_CFG_CTX0_0, %g4
	cmp	%g7, 1
	move	%xcc, TSB_CFG_CTX0_1, %g4
	cmp	%g7, 2
	move	%xcc, TSB_CFG_CTX0_2, %g4
	cmp	%g7, 3
	move	%xcc, TSB_CFG_CTX0_3, %g4
	stxa	%g1, [%g4]ASI_MMU_TSB

	STRAND_STRUCT(%g2)
	add	%g2, STRAND_MRA, %g2
	mulx	%g7, STRAND_MRA_INCR, %g3		! save z_tsb_cfg in strand.mra[0->3]
	stx	%g1, [%g2 + %g3]

	ba,pt	%xcc, .ctx0_tsbd_loop
	inc	%g7

.ctx0_tsbd_finish:
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
	HVCALL(set_dummytsb_ctxN)
	brz,pn	%o0, setntsbsN
	cmp	%o0, MAX_NTSB
	bgu,pn	%xcc, herr_inval
	btst	TSBD_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	sllx	%o0, TSBD_SHIFT, %g3
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o1, %g3, herr_noraddr, %g2, %g1)
	!! %g1   paddr
	add	%g5, CPU_TSBDS_CTXN, %g2
	! xcopy trashes g1-4
	HVCALL(xcopy)
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
	lduw	[%g2 + TSBD_SIZE_OFF], %g3
	sub	%g3, 1, %g4
	btst	%g3, %g4		! check for power-of-two
	bnz,pn	%xcc, herr_badtsb
	mov	TSB_SZ0_ENTRIES, %g4
	cmp	%g3, %g4
	blu,pn	%xcc, herr_badtsb
	sll	%g4, TSB_MAX_SZCODE, %g4
	cmp	%g3, %g4
	bgu,pn	%xcc, herr_badtsb
	nop
	/* check context index field - must be -1 (shared) or zero/one */
	lduw	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, TSBD_CTX_IDX_SHARE
	be,pt	%xcc, 2f	! -1 is OK
	nop
	cmp	%g3, MAX_NCTX_INDEX
	bgu,pn	%xcc, herr_inval
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

	/* now setup HWTW regs */
	! %g5 = CPU pointer
	clr	%g7
.ctxn_tsbd_loop:
	cmp	%g7, %o0
	bgeu,pn	%xcc, .ctxn_tsbd_finish
	nop

	add	%g5, CPU_TSBDS_CTXN, %g2
	sllx	%g7, TSBD_SHIFT, %g1
	add	%g2, %g1, %g2
	ldx	[%g2 + TSBD_BASE_OFF], %g1
	RA2PA_CONV(%g6, %g1, %g1, %g4)		! start with TSB base PA

	lduw	[%g2 + TSBD_SIZE_OFF], %g4

	dec	%g4
	popc	%g4, %g4
	dec	TSB_SZ0_SHIFT, %g4
	or	%g1, %g4, %g1

	lduh	[%g2 + TSBD_IDXPGSZ_OFF], %g4
	sll	%g4, TSB_CFG_PGSZ_SHIFT, %g4
	or	%g1, %g4, %g1			! add page size field
	or	%g1, TSB_CFG_RA_NOT_PA, %g1	! add RA not PA bit
	clr	%g4
	ld	[%g2 + TSBD_CTX_INDEX], %g3
	cmp	%g3, 0				! use primary-ctxnon0 always?
	move	%xcc, USE_TSB_PRIMARY_CTX, %g4
	cmp	%g3, 1				! use secondary-ctxnon0 always?
	move	%xcc, USE_TSB_SECONDARY_CTX, %g4
	sllx	%g4, TSB_CFG_USE_CTX1_SHIFT, %g4
	or	%g1, %g4, %g1			! add any use-ctxnon0|ctx1 bits
	mov	1, %g4
	sllx	%g4, 63, %g4
	or	%g1, %g4, %g1			! add valid bit

	mov	TSB_CFG_CTXN_0, %g4
	cmp	%g7, 1
	move	%xcc, TSB_CFG_CTXN_1, %g4
	cmp	%g7, 2
	move	%xcc, TSB_CFG_CTXN_2, %g4
	cmp	%g7, 3
	move	%xcc, TSB_CFG_CTXN_3, %g4
	stxa	%g1, [%g4]ASI_MMU_TSB

	STRAND_STRUCT(%g2)
	add	%g2, STRAND_MRA, %g2
	add	%g7, 4, %g3			! save nz_tsb_cfg in strand.mra[4->7]
	mulx    %g3, STRAND_MRA_INCR, %g3
	stx	%g1, [%g2 + %g3]

	ba,pt	%xcc, .ctxn_tsbd_loop
	inc	%g7

.ctxn_tsbd_finish:
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
	! %g2 pa of buffer
	! xcopy(cpu->tsbds, buffer, ntsbs*TSBD_BYTES)
	add	%g5, CPU_TSBDS_CTX0, %g1
	! clobbers %g1-%g4
	HVCALL(xcopy)

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
	! %g2 pa of buffer
	! xcopy(cpu->tsbds, buffer, ntsbs*TSBD_BYTES)
	add	%g5, CPU_TSBDS_CTXN, %g1
	! clobbers %g1-%g4
	HVCALL(xcopy)

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
	RA2PA_RANGE_CONV(%g6, %g2, %g4, 3f, %g5, %g7)
        mov	%g7, %g2
	! %g2	PA
4:	or	%g3, %g2, %g1	! %g1 new tte with pa

	set	(NCTXS - 1), %g3
	and	%o1, %g3, %o1
	andn	%o0, %g3, %o0
	or	%o0, %o1, %g2	! %g2 tag
	mov	MMU_TAG_ACCESS, %g3 ! %g3 tag_access

	btst	MAP_DTLB, %o3
	bz	2f
	btst	MAP_ITLB, %o3

	stxa	%g2, [%g3]ASI_DMMU
	membar	#Sync
	stxa	%g1, [%g0]ASI_DTLB_DATA_IN

	! condition codes still set
2:	bz	1f
	nop

	stxa	%g2, [%g3]ASI_IMMU
	membar	#Sync
	stxa	%g1, [%g0]ASI_ITLB_DATA_IN

1:	HCALL_RET(EOK)

	! Check for I/O
3:
	RANGE_CHECK_IO(%g6, %g2, %g4, .hcall_mmu_map_addr_io_found,
	    .hcall_mmu_map_addr_io_not_found, %g1, %g5)
.hcall_mmu_map_addr_io_found:
	ba,a	4b
.hcall_mmu_map_addr_io_not_found:

	ALTENTRY(hcall_mmu_map_addr_ra_not_found)
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
#ifdef STRICT_API
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o2, herr_inval)
#endif /* STRICT_API */
	mov	MMU_PCONTEXT, %g1
	set	(NCTXS - 1), %g2	! 8K page mask
	andn	%o0, %g2, %g2
	ldxa	[%g1]ASI_MMU, %g3 ! save current primary ctx
	mov	MMU_PCONTEXT1, %g4
	ldxa	[%g4]ASI_MMU, %g5 ! save current primary ctx1
	stxa	%o1, [%g1]ASI_MMU ! switch to new ctx
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o2
	stxa	%g0, [%g2]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g2]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU !  restore original primary ctx
	stxa	%g5, [%g4]ASI_MMU !  restore original primary ctx1
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
	mov	MMU_PCONTEXT1, %g4
	ldxa	[%g4]ASI_MMU, %g5 ! save primary ctx1
	stxa	%o3, [%g1]ASI_MMU
	btst	MAP_ITLB, %o4
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o4
	stxa	%g0, [%g2]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g2]ASI_DMMU_DEMAP
2:	stxa	%g3, [%g1]ASI_MMU ! restore primary ctx
	stxa	%g5, [%g4]ASI_MMU ! restore primary ctx1
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
	mov	MMU_PCONTEXT1, %g4
	ldxa	[%g4]ASI_MMU, %g6 ! save current primary ctx1
	stxa	%o2, [%g2]ASI_MMU
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	  btst	MAP_DTLB, %o3
	stxa	%g0, [%g3]ASI_IMMU_DEMAP
1:	bz,pn	%xcc, 2f
	  nop
	stxa	%g0, [%g3]ASI_DMMU_DEMAP
2:	stxa	%g7, [%g2]ASI_MMU ! restore primary ctx
	stxa	%g6, [%g4]ASI_MMU ! restore primary ctx1
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
	brnz,pn	%o1, herr_inval
	VCPU_GUEST_STRUCT(%g1, %g6)

	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o3, herr_inval)

	! Fail if tte isn't valid
	brgez,pn %o2, herr_inval
	nop

	! extract sz from tte
	TTE_SIZE(%o2, %g4, %g2, herr_badpgsz)
	sub	%g4, 1, %g5	! %g5 page mask

	! Fail if page-offset bits aren't zero
	btst	%g5, %o0
	bnz,pn	%xcc, herr_inval
	.empty

	! extract ra from tte
	sllx	%o2, 64 - 40, %g2
	srlx	%g2, 64 - 40 + 13, %g2
	sllx	%g2, 13, %g2	! %g2 real address
	xor	%o2, %g2, %g3	! %g3 orig tte with ra field zeroed
	andn	%g2, %g5, %g2
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %g2, %g4, herr_noraddr, %g5, %g7)
	!! %g7 PA
        or      %g3, %g7, %g2   ! %g2 new tte with pa
        !! %g2 = swizzled tte

	/*
	 * OBP & Solaris assume demap semantics.  Whack the TLBs to remove
	 * overlapping (multi-hit trap producing) entries.  Note this isn't
	 * strictly necessary for incoming 8KB entries as auto-demap would
	 * properly handle those.
	 */
	set	(TLB_DEMAP_CTX_TYPE | TLB_DEMAP_NUCLEUS), %g1
	stxa	%g0, [%g1]ASI_IMMU_DEMAP
	stxa	%g0, [%g1]ASI_DMMU_DEMAP

	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_ENTER(%g1, %g3, %g4)

	/* Search for existing perm mapping */
	add	%g6, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	mov	0, %g4

	/*
	 * Save the first uninitialised or invalid entry (TTE_V == 0)
	 * for the permanent mapping. Loop through all entries checking
	 * for an existing matching entry.
	 *
	 * for (i = NPERMMAPPINGS - 1; i >= 0; i--) {
	 *	if (!table[i] || !table[i]->tte.v) {
	 *		if (saved_entry == 0)
	 *			saved_entry = &table[i];  // free entry
	 *		continue;
	 *	}
	 *	if (table[i]->va == va) {
	 *		saved_entry = &table[i];  // matching entry
	 *		break;
	 *	}
	 * }
	 */
.pmap_loop:
	! %g1 = permanent mapping table base address
	! %g3 = current offset into table
	! %g4 = last free entry / saved_entry
	add	%g1, %g3, %g5
	ldx	[%g5 + MAPPING_TTE], %g6

	/*
	 * if (!tte || !tte.v) {
	 *	if (saved_entry == 0) {
	 *		// (first invalid/uninitialised entry)
	 *		saved_entry = current_entry;
	 *	}
	 *	continue;
	 * }
	 */
	brgez,a,pt %g6, .pmap_continue
	  movrz	%g4, %g5, %g4

	/*
	 * if (m->va == va) {
	 *	saved_entry = current_entry;
	 *	break;
	 * }
	 *
	 * NB: overlapping mappings not detected, behavior
	 * is undefined right now.   The hardware will demap
	 * when we insert and a TLB error later could reinstall
	 * both in some order where the end result is different
	 * than the post-map-perm result.
	 */
	ldx	[%g5 + MAPPING_VA], %g6
	cmp	%g6, %o0
	be,a,pt	%xcc, .pmap_break
	  mov	%g5, %g4

.pmap_continue:
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .pmap_loop
	nop

.pmap_break:
	! %g4 = saved_entry

	/*
	 * if (saved_entry == NULL)
	 *	return (ETOOMANY);
	 */
	brz,a,pn %g4, .pmap_return
	  mov	ETOOMANY, %o0

	/*
	 * if (saved_entry->tte.v)
	 *	existing entry to modify
	 * else
	 *	free entry to fill in
	 */
	ldx	[%g4 + MAPPING_TTE], %g5
	brgez,pn %g5, .pmap_free_entry
	nop

	/*
	 * Compare new tte with existing tte
	 */
	cmp	%g2, %g5
	bne,a,pn %xcc, .pmap_return
	   mov	EINVAL, %o0

.pmap_existing_entry:
	VCPU_STRUCT(%g1)
	ldub	[%g1 + CPU_VID], %g1
	mov	1, %g3
	sllx	%g3, %g1, %g1
	! %g1 = (1 << CPU->vid)

	/*
	 * if (flags & I) {
	 *	if (saved_entry->icpuset & (1 << curcpu))
	 *		return (EINVAL);
	 * }
	 */
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 1f
	nop
	ldx	[%g4 + MAPPING_ICPUSET], %g5
	btst	%g1, %g5
	bnz,a,pn %xcc, .pmap_return
	  mov	EINVAL, %o0
1:
	/*
	 * if (flags & D) {
	 *	if (saved_entry->dcpuset & (1 << curcpu))
	 *		return (EINVAL);
	 * }
	 */
	btst	MAP_DTLB, %o3
	bz,pn	%xcc, 2f
	nop
	ldx	[%g4 + MAPPING_DCPUSET], %g5
	btst	%g1, %g5
	bnz,a,pn %xcc, .pmap_return
	  mov	EINVAL, %o0
2:
	ba,pt	%xcc, .pmap_finish
	nop

.pmap_free_entry:
	/*
	 * m->va = va;
	 * m->tte = tte;
	 */
	stx	%o0, [%g4 + MAPPING_VA]
	stx	%g2, [%g4 + MAPPING_TTE]

.pmap_finish:
	VCPU_STRUCT(%g1)
	ldub	[%g1 + CPU_VID], %g3
	mov	1, %g1
	sllx	%g1, %g3, %g1
	! %g1 = (1 << CPU->vid)
	! %g3 = pid
	! %g4 = saved_entry

	/*
	 * If no other strands on this core have this mapping then map
	 * it in both TLBs.
	 *
	 * if (((m->icpuset >> (CPU2COREID(curcpu) * 8)) & 0xff) == 0 &&
	 *     ((m->dcpuset >> (CPU2COREID(curcpu) * 8)) & 0xff) == 0) {
	 *	map in iTLB
	 *	map in dTLB
	 * }
	 */
	ldx	[%g4 + MAPPING_ICPUSET], %g5
	ldx	[%g4 + MAPPING_DCPUSET], %g3
	or	%g5, %g3, %g5
	PCPUID2COREID(%g3, %g6)
	sllx	%g6, CPUID_2_COREID_SHIFT, %g6	! %g6 * NSTRANDSPERCORE
	srlx	%g5, %g6, %g7
	btst	CORE_MASK, %g7
	bnz,pt	%xcc, 0f
	mov	MMU_TAG_ACCESS, %g3

	stxa	%o0, [%g3]ASI_IMMU
	membar	#Sync
	stxa	%g2, [%g0]ASI_ITLB_DATA_IN
	membar	#Sync
	stxa	%o0, [%g3]ASI_DMMU
	membar	#Sync
	stxa	%g2, [%g0]ASI_DTLB_DATA_IN
	membar	#Sync

0:
	/*
	 * if (flags & I)
	 *	m->icpuset |= (1 << CPU->pid);
	 * }
	 */
	btst	MAP_ITLB, %o3
	bz,pn	%xcc, 3f
	ldx	[%g4 + MAPPING_ICPUSET], %g5

	or	%g5, %g1, %g5
	stx	%g5, [%g4 + MAPPING_ICPUSET]

3:
	/*
	 * if (flags & D) {
	 *	m->dcpuset |= (1 << CPU->pid);
	 * }
	 */
	btst	MAP_DTLB, %o3
	bz,pn	%xcc, 4f
	ldx	[%g4 + MAPPING_DCPUSET], %g5

	or	%g5, %g1, %g5
	stx	%g5, [%g4 + MAPPING_DCPUSET]

4:
	mov	EOK, %o0

.pmap_return:
	GUEST_STRUCT(%g1)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_EXIT(%g1)
	done
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
	ENTRY_NP(hcall_mmu_unmap_perm_addr)
	brnz,pn	%o1, herr_inval
	nop
	CHECK_VA_CTX(%o0, %o1, herr_inval, %g2)
	CHECK_MMU_FLAGS(%o2, herr_inval)

	/*
	 * Search for existing perm mapping
	 */
	GUEST_STRUCT(%g6)
	add	%g6, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	mov	0, %g4

	add	%g6, GUEST_PERM_MAPPINGS_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g5, %g6)

	/*
	 * for (i = NPERMMAPPINGS - 1; i >= 0; i--) {
	 *	if (!table[i]->tte.v)
	 *		continue;
	 *	if (table[i]->va == va)
	 *		break;
	 * }
	 */
.punmap_loop:
	! %g1 = permanent mapping table base address
	! %g3 = current offset into table
	! %g4 = last free entry / saved_entry
	add	%g1, %g3, %g5
	ldx	[%g5 + MAPPING_TTE], %g6

	/*
	 * if (!m->tte.v)
	 *	continue;
	 */
	brgez,pt %g6, .punmap_continue
	nop

	/*
	 * if (m->va == va)
	 *	break;
	 */
	ldx	[%g5 + MAPPING_VA], %g6
	cmp	%g6, %o0
	be,pt	%xcc, .punmap_break
	nop

.punmap_continue:
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .punmap_loop
	nop

.punmap_break:
	! %g5 = entry in mapping table

	/*
	 * if (i < 0)
	 *	return (EINVAL);
	 */
	brlz,a,pn %g3, .punmap_return
	  mov	ENOMAP, %o0

	VCPU_STRUCT(%g1)
	ldub	[%g1 + CPU_VID], %g3
	mov	1, %g1
	sllx	%g1, %g3, %g1
	! %g1 = (1 << CPU->vid)
	! %g3 = pid
	! %g5 = entry in mapping table

	/*
	 * if (flags & MAP_I) {
	 *	m->cpuset_i &= ~(1 << curcpu);
	 * }
	 */
	btst	MAP_ITLB, %o2
	bz,pn	%xcc, 1f
	nop

	ldx	[%g5 + MAPPING_ICPUSET], %g2
	andn	%g2, %g1, %g2
	stx	%g2, [%g5 + MAPPING_ICPUSET]

1:
	/*
	 * if (flags & MAP_D) {
	 *	m->cpuset_d &= ~(1 << curcpu);
	 * }
	 */
	btst	MAP_DTLB, %o2
	bz,pn	%xcc, 2f
	nop

	ldx	[%g5 + MAPPING_DCPUSET], %g2
	andn	%g2, %g1, %g2
	stx	%g2, [%g5 + MAPPING_DCPUSET]

2:
	/*
	 *
	 * If no other strands on this core still use this mapping
	 * then demap it in both TLBs.
	 *
	 * if (((m->cpuset_i >> (CPU2COREID(curcpu) * 8)) & 0xff) == 0 &&
	 *     ((m->cpuset_d >> (CPU2COREID(curcpu) * 8)) & 0xff) == 0) {
	 *	demap in iTLB
	 *	demap in dTLB
	 * }
	 */
	ldx	[%g5 + MAPPING_ICPUSET], %g4
	ldx	[%g5 + MAPPING_DCPUSET], %g3
	or	%g4, %g3, %g4
	PCPUID2COREID(%g3, %g6)
	sllx	%g6, CPUID_2_COREID_SHIFT, %g6	! %g6 * NSTRANDSPERCORE
	srlx	%g4, %g6, %g7
	btst	CORE_MASK, %g7
	bnz,pt	%xcc, 3f
	mov	MMU_PCONTEXT, %g1

	mov	MMU_PCONTEXT1, %g4
	ldxa	[%g1]ASI_MMU, %g3 ! save current primary ctx
	ldxa	[%g4]ASI_MMU, %g6 ! save current primary ctx1
	stxa	%o1, [%g1]ASI_MMU ! switch to new ctx
	stxa	%g0, [%o0]ASI_IMMU_DEMAP
	stxa	%g0, [%o0]ASI_DMMU_DEMAP
	stxa	%g3, [%g1]ASI_MMU !  restore original primary ctx
	stxa	%g6, [%g4]ASI_MMU !  restore original primary ctx1

	/*
	 * if (m->cpuset_d == 0 && m->cpuset_i == 0) {
	 *	m->va = 0;
	 *	m->tte = tte & ~TTE_V;
	 * }
	 */
	ldx	[%g5 + MAPPING_DCPUSET], %g1
	ldx	[%g5 + MAPPING_ICPUSET], %g2
	orcc	%g1, %g2, %g0
	bnz,pt	%xcc, 3f
	nop

	stx	%g0, [%g5 + MAPPING_VA]
	! clear TTE_V, bit 63
	ldx	[%g5 + MAPPING_TTE], %g1
	sllx	%g1, 1, %g1
	srlx	%g1, 1, %g1
	stx	%g1, [%g5 + MAPPING_TTE]
3:
	mov	EOK, %o0

.punmap_return:
	GUEST_STRUCT(%g1)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_EXIT(%g1)
	done
	SET_SIZE(hcall_mmu_unmap_perm_addr)


#ifdef DEBUG /* { */

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
	GUEST_STRUCT(%g7)
	! %g7 guestp

	! Check to see if table fits into the supplied buffer
	cmp	%o1, NPERMMAPPINGS
	blu,pn	%xcc, herr_inval
	mov	NPERMMAPPINGS, %o1

	btst	3, %o0
	bnz,pn	%xcc, herr_badalign
	mulx	%o1, PERMMAPINFO_BYTES, %g3
	! %g3 size of permmap table in bytes
        RA2PA_RANGE_CONV_UNK_SIZE(%g7, %o0, %g3, herr_noraddr, %g5, %g2)
	! %g2 pa of buffer

	add	%g7, GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_ENTER(%g1, %g3, %g4)

	/*
	 * Search for valid perm mappings
	 */
	add	%g7, GUEST_PERM_MAPPINGS, %g1
	mov	((NPERMMAPPINGS - 1) * MAPPING_SIZE), %g3
	mov	0, %o1
	add	%g1, %g3, %g4
.perm_info_loop:
	! %o1 = count of valid entries
	! %g1 = base of mapping table
	! %g2 = pa of guest's buffer
	! %g3 = current offset into table
	! %g4 = current entry in table
	! %g7 = guestp
	ldx	[%g4 + MAPPING_TTE], %g5
	brgez,pn %g5, .perm_info_continue
	nop

	/* Found a valid mapping */
	ldx	[%g4 + MAPPING_VA], %g5
	stx	%g5, [%g2 + PERMMAPINFO_VA]
	stx	%g0, [%g2 + PERMMAPINFO_CTX]
	ldx	[%g4 + MAPPING_TTE], %g5
	stx	%g5, [%g2 + PERMMAPINFO_TTE]

	VCPU_STRUCT(%g5)
	ldub	[%g5 + CPU_VID], %g5
	mov	1, %o0
	sllx	%o0, %g5, %o0
	! %o0 = curcpu bit mask
	mov	0, %g6
	! %g6 = flags
	ldx	[%g4 + MAPPING_ICPUSET], %g5
	btst	%g5, %o0
	bnz,a,pt %xcc, 0f
	  or	%g6, MAP_ITLB, %g6
0:	ldx	[%g4 + MAPPING_DCPUSET], %g5
	btst	%g5, %o0
	bnz,a,pt %xcc, 0f
	  or	%g6, MAP_DTLB, %g6
0:	stx	%g6, [%g4 + PERMMAPINFO_FLAGS]

	inc	%o1
	inc	PERMMAPINFO_BYTES, %g2

.perm_info_continue:
	deccc	GUEST_PERM_MAPPINGS_INCR, %g3
	bgeu,pt	%xcc, .perm_info_loop
	add	%g1, %g3, %g4

	GUEST_STRUCT(%g1)
	inc	GUEST_PERM_MAPPINGS_LOCK, %g1
	SPINLOCK_EXIT(%g1)

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_perm_addr_info)

#endif /* } DEBUG */
