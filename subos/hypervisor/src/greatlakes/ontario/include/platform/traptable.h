/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traptable.h
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

#ifndef _PLATFORM_TRAPTABLE_H
#define	_PLATFORM_TRAPTABLE_H

#pragma ident	"@(#)traptable.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/* BEGIN CSTYLED */

/*
 * MMU traps
 *
 * XXX - hack for now until the trap table entry gets rewritten
 * on-the-fly when the guest takes over the mmu
 *
 * It is perfectly legal for the guest to experience a trap
 * when gl=MAXPGL or tl=MAXPTL provided that trap does not
 * result in a miss. So we allow this case, and check for the
 * watchdog condition on the way back from the trap if a TSB etc
 * miss occurred.
 *
 * So upfront we allow gl to be 1 to MAXPGL+1 (since we may
 * legally have taken the TLB miss when gl=MAXPGL.
 * 
 */
#define	IMMU_MISS						\
	rdpr	%gl, %g1					;\
	cmp	%g1, MAXPGL+1					;\
	bgu,pn	%xcc, watchdog_guest				;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, immu_miss					;\
	  ldxa	[%g1]ASI_HSCRATCHPAD, %g1

#define	DMMU_MISS						\
	rdpr	%gl, %g1					;\
	cmp	%g1, MAXPGL+1					;\
	bgu,pn	%xcc, watchdog_guest				;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, dmmu_miss					;\
	  ldxa	[%g1]ASI_HSCRATCHPAD, %g1

#define	DMMU_PROT						\
	rdpr	%gl, %g1					;\
	cmp	%g1, MAXPGL					;\
	bgu,pn	%xcc, watchdog_guest				;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1			;\
	ba,pt	%xcc, dmmu_prot					;\
	ldx	[%g1 + CPU_MMU_AREA], %g2

#define	RDMMU_MISS						\
	mov	MMU_TAG_ACCESS, %g2				;\
	ldxa	[%g2]ASI_DMMU, %g2	/* tag access */	;\
	set	((1 << 13) - 1), %g3				;\
	andn	%g2, %g3, %g2					;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, rdmmu_miss				;\
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1

#define	RIMMU_MISS						\
	mov	MMU_TAG_ACCESS, %g2				;\
	ldxa	[%g2]ASI_IMMU, %g2	/* tag access */	;\
	set	((1 << 13) - 1), %g3				;\
	andn	%g2, %g3, %g2					;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, rimmu_miss				;\
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1

/*
 * Interrupt traps
 */
#ifdef NIAGARA_ERRATUM_43
#define	VECINTR							\
	membar	#Sync						;\
	ldxa	[%g0]ASI_INTR_UDB_R, %g2			;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, vecintr					;\
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1
#else
#define	VECINTR							\
	ldxa	[%g0]ASI_INTR_UDB_R, %g2			;\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, vecintr					;\
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1
#endif

#define	MAUINTR							\
	mov	HSCRATCH_VCPU_STRUCT, %g1			;\
	ba,pt	%xcc, mau_intr					;\
	ldxa	[%g1]ASI_HSCRATCHPAD, %g1			

/*
 * CE Error traps
 */
#define	CE_ERR							\
	ba,a,pt	%xcc, ce_err					;\
	.empty

/*
 * UE Error traps
 */
#define	UE_ERR							\
	ba,a,pt	%xcc, ue_err					;\
	.empty

/*
 * Disrupting UE Error traps
 */
#define	DIS_UE_ERR						\
	ba,a,pt	%xcc, dis_ue_err				;\
	.empty

/*
 * Hstick_match hypervisor interrupt handler
 */
#define	HSTICK_INTR						\
	ba,pt	%xcc, hstick_intr				;\
	wrhpr	%g0, -1, %hstick_cmpr

/*
 * No error injector reg on N1
 */
#define	CLEAR_INJECTOR_REG
#define	SIZEOF_CLEAR_INJECTOR_REG	0

/*
 * Trap-trace layer trap table.
 */
#define	TTRACE_TRAP_TABLE							\
	/*									;\
	 * Hardware traps							;\
	 */									;\
	TTRACE(tt0_000, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_001, NOTRACE)		/* power-on reset */		;\
	TTRACE(tt0_002, NOTRACE)		/* watchdog reset */		;\
	TTRACE(tt0_003, NOTRACE)		/* externally initiated reset */;\
	TTRACE(tt0_004, LINK(ttrace_generic))	/* software initiated reset */	;\
	TTRACE(tt0_005, NOTRACE)		/* red mode exception */	;\
	TTRACE(tt0_006, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_007, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_008, LINK(ttrace_immu))	/* instr access exception */	;\
	TTRACE(tt0_009, LINK(ttrace_generic))	/* instr access mmu miss */	;\
	TTRACE(tt0_00a, LINK(ttrace_ue))	/* instruction access error */	;\
	TTRACE(tt0_00b, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_00c, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_00d, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_00e, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_00f, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_010, NOTRACE)		/* illegal instruction */	;\
	TTRACE(tt0_011, NOTRACE)		/* privileged opcode */		;\
	TTRACE(tt0_012, NOTRACE)		/* unimplemented LDD */		;\
	TTRACE(tt0_013, NOTRACE)		/* unimplemented STD */		;\
	TTRACE(tt0_014, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_015, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_016, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_017, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_018, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_019, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_01a, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_01b, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_01c, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_01d, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_01e, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_01f, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_020, NOTRACE)		/* fp disabled */		;\
	TTRACE(tt0_021, NOTRACE)		/* fp exception ieee 754 */	;\
	TTRACE(tt0_022, NOTRACE)		/* fp exception other */	;\
	TTRACE(tt0_023, NOTRACE)		/* tag overflow */		;\
	BIG_TTRACE(tt0_024, NOTRACE)		/* TRC?? clean window */	;\
	TTRACE(tt0_028, NOTRACE)		/* division by zero */		;\
	TTRACE(tt0_029, LINK(ttrace_ue))	/* internal processor error */	;\
	TTRACE(tt0_02a, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_02b, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_02c, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_02d, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_02e, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_02f, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_030, LINK(ttrace_dmmu))	/* data access exception */	;\
	TTRACE(tt0_031, NOTRACE)		/* data access mmu miss */	;\
	TTRACE(tt0_032, LINK(ttrace_ue))		/* data access error */		;\
	TTRACE(tt0_033, LINK(ttrace_ue))		/* data access protection */	;\
	TTRACE(tt0_034, LINK(ttrace_dmmu))	/* mem address not aligned */	;\
	TTRACE(tt0_035, LINK(ttrace_dmmu))	/* lddf mem addr not aligned */	;\
	TTRACE(tt0_036, LINK(ttrace_dmmu))	/* stdf mem addr not aligned */	;\
	TTRACE(tt0_037, LINK(ttrace_dmmu))	/* privileged action */		;\
	TTRACE(tt0_038, LINK(ttrace_dmmu))	/* ldqf mem addr not aligned */	;\
	TTRACE(tt0_039, LINK(ttrace_dmmu))	/* stqf mem addr not aligned */	;\
	TTRACE(tt0_03a, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_03b, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_03c, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_03d, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_03e, NOTRACE)		/* HV: real immu miss */	;\
	TTRACE(tt0_03f, NOTRACE)		/* HV: real dmmu miss */	;\
	TTRACE(tt0_040, NOTRACE)		/* async data error */		;\
	TTRACE(tt0_041, NOTRACE)		/* interrupt level 1 */		;\
	TTRACE(tt0_042, NOTRACE)		/* interrupt level 2 */		;\
	TTRACE(tt0_043, NOTRACE)		/* interrupt level 3 */		;\
	TTRACE(tt0_044, NOTRACE)		/* interrupt level 4 */		;\
	TTRACE(tt0_045, NOTRACE)		/* interrupt level 5 */		;\
	TTRACE(tt0_046, NOTRACE)		/* interrupt level 6 */		;\
	TTRACE(tt0_047, NOTRACE)		/* interrupt level 7 */		;\
	TTRACE(tt0_048, NOTRACE)		/* interrupt level 8 */		;\
	TTRACE(tt0_049, NOTRACE)		/* interrupt level 9 */		;\
	TTRACE(tt0_04a, NOTRACE)		/* interrupt level a */		;\
	TTRACE(tt0_04b, NOTRACE)		/* interrupt level b */		;\
	TTRACE(tt0_04c, NOTRACE)		/* interrupt level c */		;\
	TTRACE(tt0_04d, NOTRACE)		/* interrupt level d */		;\
	TTRACE(tt0_04e, NOTRACE)		/* interrupt level e */		;\
	TTRACE(tt0_04f, NOTRACE)		/* interrupt level f */		;\
	TTRACE(tt0_050, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_051, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_052, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_053, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_054, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_055, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_056, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_057, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_058, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_059, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_05a, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_05b, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_05c, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_05d, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_05e, NOTRACE)		/* HV: hstick match */		;\
	TTRACE(tt0_05f, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_060, NOTRACE)		/* interrupt vector */		;\
	TTRACE(tt0_061, NOTRACE)		/* RA watchpoint */		;\
	TTRACE(tt0_062, NOTRACE)		/* VA watchpoint */		;\
	TTRACE(tt0_063, LINK(ttrace_ce))	/* corrected ECC error */	;\
	BIG_TTRACE(tt0_064, NOTRACE)		/* fast instr access MMU miss */;\
	BIG_TTRACE(tt0_068, NOTRACE)		/* fast data access MMU miss */	;\
	BIG_TTRACE(tt0_06C, NOTRACE)		/* fast data access prot */	;\
	TTRACE(tt0_070, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_071, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_072, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_073, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_074, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_075, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_076, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_077, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_078, LINK(ttrace_ue))	/* data error (disrupting) */	;\
	TTRACE(tt0_079, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_07a, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_07b, NOTRACE)		/* reserved */			;\
	TTRACE(tt0_07c, NOTRACE)		/* HV: cpu mondo */		;\
	TTRACE(tt0_07d, NOTRACE)		/* HV: dev mondo */		;\
	TTRACE(tt0_07e, NOTRACE)		/* HV: resumable error */	;\
	TTRACE(tt0_07f, NOTRACE)		/* HV: non-resumable error */	;\
	BIG_TTRACE(tt0_080, NOTRACE)		/* spill 0 normal */		;\
	BIG_TTRACE(tt0_084, NOTRACE)		/* spill 1 normal */		;\
	BIG_TTRACE(tt0_088, NOTRACE)		/* spill 2 normal */		;\
	BIG_TTRACE(tt0_08c, NOTRACE)		/* spill 3 normal */		;\
	BIG_TTRACE(tt0_090, NOTRACE)		/* spill 4 normal */		;\
	BIG_TTRACE(tt0_094, NOTRACE)		/* spill 5 normal */		;\
	BIG_TTRACE(tt0_098, NOTRACE)		/* spill 6 normal */		;\
	BIG_TTRACE(tt0_09c, NOTRACE)		/* spill 7 normal */		;\
	BIG_TTRACE(tt0_0a0, NOTRACE)		/* spill 0 other */		;\
	BIG_TTRACE(tt0_0a4, NOTRACE)		/* spill 1 other */		;\
	BIG_TTRACE(tt0_0a8, NOTRACE)		/* spill 2 other */		;\
	BIG_TTRACE(tt0_0ac, NOTRACE)		/* spill 3 other */		;\
	BIG_TTRACE(tt0_0b0, NOTRACE)		/* spill 4 other */		;\
	BIG_TTRACE(tt0_0b4, NOTRACE)		/* spill 5 other */		;\
	BIG_TTRACE(tt0_0b8, NOTRACE)		/* spill 6 other */		;\
	BIG_TTRACE(tt0_0bc, NOTRACE)		/* spill 7 other */		;\
	BIG_TTRACE(tt0_0c0, NOTRACE)		/* fill 0 normal */		;\
	BIG_TTRACE(tt0_0c4, NOTRACE)		/* fill 1 normal */		;\
	BIG_TTRACE(tt0_0c8, NOTRACE)		/* fill 2 normal */		;\
	BIG_TTRACE(tt0_0cc, NOTRACE)		/* fill 3 normal */		;\
	BIG_TTRACE(tt0_0d0, NOTRACE)		/* fill 4 normal */		;\
	BIG_TTRACE(tt0_0d4, NOTRACE)		/* fill 5 normal */		;\
	BIG_TTRACE(tt0_0d8, NOTRACE)		/* fill 6 normal */		;\
	BIG_TTRACE(tt0_0dc, NOTRACE)		/* fill 7 normal */		;\
	BIG_TTRACE(tt0_0e0, NOTRACE)		/* fill 0 other */		;\
	BIG_TTRACE(tt0_0e4, NOTRACE)		/* fill 1 other */		;\
	BIG_TTRACE(tt0_0e8, NOTRACE)		/* fill 2 other */		;\
	BIG_TTRACE(tt0_0ec, NOTRACE)		/* fill 3 other */		;\
	BIG_TTRACE(tt0_0f0, NOTRACE)		/* fill 4 other */		;\
	BIG_TTRACE(tt0_0f4, NOTRACE)		/* fill 5 other */		;\
	BIG_TTRACE(tt0_0f8, NOTRACE)		/* fill 6 other */		;\
	BIG_TTRACE(tt0_0fc, NOTRACE)		/* fill 7 other */		;\
	/*									;\
	 * Software traps							;\
	 */									;\
	TTRACE(tt0_100, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_101, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_102, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_103, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_104, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_105, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_106, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_107, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_108, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_109, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_10a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_10b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_10c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_10d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_10e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_10f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_110, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_111, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_112, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_113, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_114, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_115, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_116, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_117, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_118, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_119, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_11a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_11b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_11c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_11d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_11e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_11f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_120, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_121, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_122, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_123, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_124, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_125, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_126, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_127, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_128, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_129, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_12a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_12b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_12c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_12d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_12e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_12f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_130, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_131, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_132, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_133, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_134, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_135, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_136, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_137, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_138, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_139, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_13a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_13b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_13c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_13d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_13e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_13f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_140, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_141, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_142, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_143, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_144, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_145, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_146, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_147, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_148, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_149, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_14a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_14b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_14c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_14d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_14e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_14f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_150, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_151, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_152, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_153, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_154, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_155, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_156, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_157, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_158, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_159, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_15a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_15b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_15c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_15d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_15e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_15f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_160, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_161, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_162, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_163, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_164, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_165, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_166, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_167, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_168, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_169, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_16a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_16b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_16c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_16d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_16e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_16f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_170, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_171, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_172, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_173, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_174, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_175, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_176, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_177, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_178, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_179, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_17a, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_17b, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_17c, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_17d, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_17e, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_17f, NOTRACE)		/* software trap */		;\
	TTRACE(tt0_180, LINK(ttrace_hcall))	/* hypervisor software trap */	;\
	TTRACE(tt0_181, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_182, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_183, LINK(ttrace_mmu_map))	/* hyp software trap */		;\
	TTRACE(tt0_184, LINK(ttrace_mmu_unmap)) /* hyp software trap */		;\
	TTRACE(tt0_185, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_186, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_187, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_188, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_189, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_18a, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_18b, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_18c, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_18d, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_18e, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_18f, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_190, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_191, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_192, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_193, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_194, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_195, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_196, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_197, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_198, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_199, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_19a, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_19b, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_19c, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_19d, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_19e, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_19f, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a0, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a1, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a2, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a3, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a4, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a5, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a6, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a7, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a8, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1a9, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1aa, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ab, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ac, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ad, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ae, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1af, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b0, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b1, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b2, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b3, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b4, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b5, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b6, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b7, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b8, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1b9, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ba, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1bb, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1bc, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1bd, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1be, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1bf, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c0, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c1, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c2, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c3, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c4, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c5, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c6, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c7, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c8, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1c9, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ca, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1cb, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1cc, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1cd, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ce, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1cf, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d0, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d1, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d2, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d3, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d4, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d5, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d6, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d7, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d8, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1d9, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1da, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1db, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1dc, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1dd, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1de, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1df, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e0, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e1, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e2, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e3, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e4, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e5, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e6, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e7, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e8, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1e9, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ea, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1eb, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ec, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ed, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ee, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ef, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f0, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f1, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f2, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f3, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f4, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f5, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f6, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f7, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f8, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1f9, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1fa, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1fb, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1fc, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1fd, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1fe, NOTRACE)		/* hypervisor software trap */	;\
	TTRACE(tt0_1ff, LINK(ttrace_hcall))	/* hypervisor software trap */

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* !_PLATFORM_TRAPTABLE_H */
