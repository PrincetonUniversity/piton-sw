/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: instr_emul.s
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

#pragma ident	"@(#)instr_emul.s	1.2	07/07/17 SMI"

/*
 * Niagara II unimplemented instruction emulation
 */
#include <sys/asm_linkage.h>
#include <sys/stack.h>
#include <hypervisor.h>
#include <hprivregs.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <mmu.h>
#include <traps.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <sun4v/instr.h>
#include <sparcv9/misc.h>

#include <offsets.h>
#include <traptable.h>
#include <util.h>
#include <guest.h>
#include <segments.h>
#include <debug.h>
#include <abort.h>

	/*
	 * Illegal access to non-cacheable page
	 *
	 * Emulate VIS LDBLOCKF instruction.
	 *
	 * %g1	TPC
	 * %g2	VA from D-SFAR (sign-extended)
	 * %g3	LSUCR
	 */
	ENTRY(dae_nc_page)

	/*
	 * Decode the instruction to determine whether it's a VIS block load
	 * instruction.
	 *
	 * Note: We know that we will never use these instructions in
	 * hyper-privileged mode so we could ignore that possibility and
	 * save a few instructions. Leave the test in for debug.
	 */
#ifdef DEBUG
	rdhpr	%htstate, %g4
	btst	HTSTATE_HPRIV, %g4
	bnz,a,pn	%xcc, hvabort
	  rd	%pc, %g1	
#endif

	/*
	 * Ascertain what the MMU is doing for instruction translation by
	 * checking LSUCR.im
	 */
	btst	LSUCR_IM, %g3
	bz,pn	%xcc, .dae_nc_page_tpc_ra
	nop

	/*
	 * Check if we are in nucleus ctx or not. If we
	 * are (ie, we took the trap the trap at TL == 0),
	 * we need to zero the primary ctx regs
	 * before using ASI_ITLB_PROBE.
	 */
	rdpr	%tl, %g3
	dec	%g3
	brz	%g3, 1f
	.empty

	mov	MMU_PCONTEXT0, %g5
	ldxa	[%g5]ASI_MMU, %g4
	stxa	%g0, [%g5]ASI_MMU
	STRAND_PUSH(%g4, %g6, %g7)

	mov	MMU_PCONTEXT1, %g5
	ldxa	[%g5]ASI_MMU, %g4
	stxa	%g0, [%g5]ASI_MMU
	STRAND_PUSH(%g4, %g6, %g7)
1:
	/*
	 * LSUCR.im == 1, virtual address translation is enabled
	 * %g1	contains VA of instruction, clear VA[12:0]
	 */
	srlx	%g1, 13, %g6
	sllx	%g6, 13, %g6
	
	/*
	 * VA[39:5] for ASI_ITLB_PROBE is VA[47:13]
	 */
	srlx	%g6, 13 - 5, %g6
	ldxa	[%g6]ASI_ITLB_PROBE, %g7
	brlz,a,pt	%g7, 2f 	! valid PA ? (bit 63 == 1 ?)
	  nop

	! not a valid PA, look for RA->PA translation
	or	%g6, (1 << 4), %g6
	ldxa	[%g6]ASI_ITLB_PROBE, %g7
2:
	! if needed, restore MMU contexts
	brz	%g3, 3f
	nop
	
	STRAND_POP(%g4, %g5)
	mov	MMU_PCONTEXT0, %g5
	stxa	%g4, [%g5]ASI_MMU
	STRAND_POP(%g4, %g5)
	mov	MMU_PCONTEXT1, %g5
	stxa	%g4, [%g5]ASI_MMU

3:
	! valid PA ? (bit 63 is Valid bit)
	brlz,a,pt	%g7, .dae_nc_page_va
	  sllx	%g7, 1, %g6			! %g6 	bit 62 after ITLB_PROBE,
						!		multi-hit

	/*
	 * nope, retry the instruction and hope for better luck next time
	 *
	 * Note: We are introducing a possible infinite retry/trap loop
	 *	 here. This needs to be carefully considered.
	 */
	retry

.dae_nc_page_va:
	/*
	 * valid instruction address found with ASI_ITLB_PROBE
	 * better avoid multi-hits and parity errors
	 *
	 * %g1	instruction VA
	 * %g7	Valid PA[39:13], (need to clear bit 63)
	 */
	brlz,pn %g6, .dae_nc_page_dmmu_err	! %g6	bit 62 << 1
	sllx	%g6, 1, %g6			! %g6	bit 61 after ITLB_PROBE,
						!			parity
	brlz,pn %g6, .dae_nc_page_dmmu_err	! %g6	bit 61 << 1

	sllx	%g7, 1, %g7
	srlx	%g7, 1, %g7

	! VA[12:0] -> PA[12:0]
	set	0x1fff, %g6
	and	%g1, %g6, %g5			! %g5	VA[12:0]
	or	%g7, %g5, %g7			! %g7	PA of instruction
	ba	.dae_nc_page_decode_instr
	ld	[%g7], %g5			! %g5	instruction

.dae_nc_page_tpc_ra:

	/*
	 * TPC contains RA
	 * %g1	contains RA of instruction
	 */
	GUEST_STRUCT(%g4)
	RA2PA_CONV(%g4, %g1, %g5, %g6)		! %g5	PA
	ld	[%g5], %g5			! %g5	instruction

.dae_nc_page_decode_instr:
	/*
	 * %g1	TPC
	 * %g2	VA from D-SFAR (sign-extended)
	 * %g5	instruction to decode
	 */
	srlx	%g5, LDBLOCKF_OP_SHIFT, %g7	! op
	cmp	%g7, LDBLOCKF_OP
	bne,pn	%xcc, .dae_nc_page_dmmu_err
	set	LDBLOCKF_OP3_MASK, %g7
	and	%g5, %g7, %g7
	srlx	%g7, LDBLOCKF_OP3_SHIFT, %g7
	cmp	%g7, LDBLOCKF_OP3		! block load
	bne,pn	%xcc, .dae_nc_page_dmmu_err

	/*
	 * Block load/store, check the ASI from the instruction if instr.i = 0,
	 * from TSTATE.ASI if instr.i = 1.
	 *
	 * %g5	instruction
	 */
	srlx	%g5, LDBLOCKF_I_SHIFT, %g4
	btst	1, %g4
	bnz,pn	%xcc, 1f			! i = 1
	nop
	
	set	LDBLOCKF_ASI_MASK, %g4
	and	%g4, %g5, %g4
	ba,pt	%xcc, 2f
	srlx	%g4, LDBLOCKF_ASI_SHIFT, %g4	! %g4	instr.imm_asi
1:
	rdpr	%tstate, %g4
	srlx	%g4, TSTATE_ASI_SHIFT, %g4
	and	%g4, TSTATE_ASI_MASK, %g4
2:

	/*
	 * If the ASI is not for a block load/store, no emulation
	 * The following ASIs  are for use with LDDFA and STDFA instructions
	 * as Block Load (LDBLOCKF) and Block Store (STBLOCKF) operations.
	 *
	 *	The block load ASI is mapped as :-
	 *
	 * 	ASI_BLK_AIUP	-> 	ASI_AIUP
	 * 	ASI_BLK_AIUS	-> 	ASI_AIUS
	 * 	ASI_BLK_AIUP_LE	-> 	ASI_AIUP_LE
	 * 	ASI_BLK_AIUS_LE	-> 	ASI_AIUS_LE
	 * 	ASI_BLK_P	-> 	ASI_AIUP
	 * 	ASI_BLK_S	-> 	ASI_AIUS
	 * 	ASI_BLK_PL	-> 	ASI_AIUP_LE
	 * 	ASI_BLK_SL	-> 	ASI_AIUS_LE
	 *
	 * Note: Is there a possible TLB/TSB miss here which would cause
	 *	 a guest trap at TL > 1 but with a user VA ? We are entering
	 *	 dangerous territor here.
	 *
	 * %g4	ASI
	 */
	cmp	%g4, ASI_BLK_P
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUP, %g7
	cmp	%g4, ASI_BLK_S
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUS, %g7
	cmp	%g4, ASI_BLK_PL
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUP_LE, %g7
	cmp	%g4, ASI_BLK_SL
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUS_LE, %g7
	cmp	%g4, ASI_BLK_AIUP
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUP, %g7
	cmp	%g4, ASI_BLK_AIUS
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUS, %g7
	cmp	%g4, ASI_BLK_AIUP_LE
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUP_LE, %g7
	cmp	%g4, ASI_BLK_AIUS_LE
	be,pn	%xcc, .dae_nc_page_asi_ok
	mov	ASI_AIUS_LE, %g7

	/*
	 * Not a block load/store ASI, so treat this as any other
	 * MMU DAE_nc_page error
	 */
	ba,a,pt	%xcc, .dae_nc_page_dmmu_err
	.empty

.dae_nc_page_asi_ok:
	/*
	 * Valid LDBLOCKF VIS instruction, emulate
	 *
	 * %g2	VA from D-SFAR (sign-extended)
	 * %g5	instruction
	 * %g7	ASI
	 */

	/*
	 * Get the target register, verify that it is a double-precision
	 * FP register aligned on an eight-double-precision register boundary.
	 */
	set	LDBLOCKF_RD_MASK, %g3
	and	%g5, %g3, %g3
	srlx	%g3, LDBLOCKF_RD_SHIFT, %g3	! %g3 target FP register
	btst	1, %g3				! if odd-numbered fp reg, it
						!	is for fp32 and up

	bnz,a,pt %xcc, 0f			! it is for fp32 and up
	  add	%g3, 31, %g3			! only 5 bits available for
						!	dest reg in instr
0:
#if 0
	/*
	 * illegal_inst trap  has priority, no need to check for aligned fp reg
	 * save a couple of instructions here
	 */
	btst	0xf, %g3
	bnz,pn	%xcc, .dae_nc_page_dmmu_err
	nop
#endif

	wr	%g7, %asi			! set target ASI

	/*
	 * we know this was a valid FP block load operation,
	 * as the fp_disabled trap has priority, so FPRS.fef
	 * must have been set. Set it again now for the hypervisor
	 * without checking/storing FPRS, save a few instructions.
	 * The DAE_nc_page trap will have enabled PSTATE.PEF.
	 */
	wr	%g0, FPRS_FEF, %fprs

.dae_nc_page_ldblockf:

#define	LD_FP_SIZE	(SZ_INSTR * 9)

	/*
	 * get address of 'load table' below
	 * 
	 * %g2	PA
	 * %g3	target register
	 */
	ba	1f
	rd	%pc, %g5

.dae_nc_page_load_fp0:
	ldda	[%g2 + 0]%asi, %f0
	ldda	[%g2 + 8]%asi, %f2
	ldda	[%g2 + 16]%asi, %f4
	ldda	[%g2 + 24]%asi, %f6
	ldda	[%g2 + 32]%asi, %f8
	ldda	[%g2 + 40]%asi, %f10
	ldda	[%g2 + 48]%asi, %f12
	ldda	[%g2 + 56]%asi, %f14
	done

.dae_nc_page_load_fp16:
	ldda	[%g2 + 0]%asi, %f16
	ldda	[%g2 + 8]%asi, %f18
	ldda	[%g2 + 16]%asi, %f20
	ldda	[%g2 + 24]%asi, %f22
	ldda	[%g2 + 32]%asi, %f24
	ldda	[%g2 + 40]%asi, %f26
	ldda	[%g2 + 48]%asi, %f28
	ldda	[%g2 + 56]%asi, %f30
	done

.dae_nc_page_load_fp32:
	ldda	[%g2 + 0]%asi, %f32
	ldda	[%g2 + 8]%asi, %f34
	ldda	[%g2 + 16]%asi, %f36
	ldda	[%g2 + 24]%asi, %f38
	ldda	[%g2 + 32]%asi, %f40
	ldda	[%g2 + 40]%asi, %f42
	ldda	[%g2 + 48]%asi, %f44
	ldda	[%g2 + 56]%asi, %f46
	done

.dae_nc_page_load_fp48:
	ldda	[%g2 + 0]%asi, %f48
	ldda	[%g2 + 8]%asi, %f50
	ldda	[%g2 + 16]%asi, %f52
	ldda	[%g2 + 24]%asi, %f54
	ldda	[%g2 + 32]%asi, %f56
	ldda	[%g2 + 40]%asi, %f58
	ldda	[%g2 + 48]%asi, %f60
	ldda	[%g2 + 56]%asi, %f62
	done

1:

	/*
	 * Jump into the load table, load the FP registers from the
	 * source address and return to TNPC.
	 *
	 * target register must be 8 double-aligned, (% 16 == 0)
	 *	
	 * %g2	PA for load
	 * %g3	target register
	 * %g5	&.dae_nc_page_load_fp0
	 */
	srlx	%g3, 4, %g3			! fpreg / 16
	mulx	%g3, LD_FP_SIZE, %g3
	add	%g3, %g5, %g3
	jmp	%g3 + SZ_INSTR
	nop	

.dae_nc_page_dmmu_err:
	/*
	 * Emulation not supported for this instruction, treat as
	 * DMMU DAE_nc_page error
	 */
	DMMU_ERR_RV(MMU_FT_NCATOMIC)

	/* NOTREACHED */

	SET_SIZE(dae_nc_page)
