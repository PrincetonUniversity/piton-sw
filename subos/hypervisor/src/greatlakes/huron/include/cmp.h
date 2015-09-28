/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cmp.h
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

#ifndef _NIAGARA2_CMP_H
#define	_NIAGARA2_CMP_H

#pragma ident	"@(#)cmp.h	1.2	07/07/27 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include "config.h"

/*
 * Idle/Resume all strands
 */
/* BEGIN CSTYLED */

#define SPINLOCK_ENTER_SS_LOCK(scr1, scr2, scr3) 		\
	LOCK_ADDR(CONFIG_SINGLE_STRAND_LOCK, scr1)	/* ->lock */	;\
	SPINLOCK_ENTER(scr1, scr2, scr3)

#define SPINLOCK_EXIT_SS_LOCK(scr1) 				\
	LOCK_ADDR(CONFIG_SINGLE_STRAND_LOCK, scr1)	/* ->lock */	;\
	SPINLOCK_EXIT(scr1)

/*
 * ASI_CMT_STRAND_ID (ASI 0x63, VA 0x10) bits[5:0]
 */
#define	CMT_STRAND_ID_MASK			0x3f

#define	PHYS_STRAND_ID(scr)						\
	mov	CMP_CORE_ID, scr					;\
	ldxa	[scr]ASI_CMP_CORE, scr	/* current cpu */		;\
	and	scr, CMT_STRAND_ID_MASK, scr

#define	PARK_ALL_STRANDS(scr1, scr2, scr3, scr4)			\
	.pushlocals							;\
	SPINLOCK_ENTER_SS_LOCK(scr1, scr2, scr3)			;\
	mov	CMP_CORE_ID, scr2					;\
	ldxa	[scr2]ASI_CMP_CORE, scr2	/* current cpu */	;\
	and	scr2, (NSTRANDS - 1), scr2				;\
	mov	1, scr3							;\
        sllx    scr3, scr2, scr3					;\
	VCPU_STRUCT(scr1)						;\
	VCPU2ROOT_STRUCT(scr1, scr2)		/* ->config*/		;\
	add     scr2, CONFIG_STACTIVE, scr4	/* ->active mask */	;\
	ldx	[scr4], scr1			/* active CPUs */	;\
	andn	scr1, scr3, scr1					;\
	stx	scr3, [scr4]			/* curcpu ACTIVE */	;\
	add	scr2, CONFIG_STIDLE, scr2	/* ->idle mask */	;\
	stx	scr1, [scr2]						;\
	mov	CMP_CORE_RUNNING_W1C, scr2				;\
	stxa	scr1, [scr2]ASI_CMP_CHIP	/* park all cpus */	;\
	mov	CMP_CORE_RUNNING_STATUS, scr2				;\
1:	ldxa	[scr2]ASI_CMP_CHIP, scr1				;\
	cmp	scr1, scr3						;\
	bne,pn	%xcc, 1b		/* wait until stopped */	;\
	nop								;\
	SPINLOCK_EXIT_SS_LOCK(scr1)					;\
	.poplocals
/* END CSTYLED */

/*
 * Resume all strands
 */
/* BEGIN CSTYLED */
#define	RESUME_ALL_STRANDS(scr1, scr2, scr3, scr4)			\
	.pushlocals							;\
	SPINLOCK_ENTER_SS_LOCK(scr1, scr2, scr3)			;\
	mov	CMP_CORE_ID, scr2					;\
	ldxa	[scr2]ASI_CMP_CORE, scr2	/* current cpu */	;\
	and	scr2, (NSTRANDS - 1), scr2				;\
	mov	1, scr3							;\
        sllx    scr3, scr2, scr3					;\
	VCPU_STRUCT(scr1)						;\
	VCPU2ROOT_STRUCT(scr1, scr2)		/* ->config*/		;\
	add     scr2, CONFIG_STIDLE, scr4	/* ->idle mask */	;\
	ldx	[scr4], scr1						;\
	stx	%g0, [scr4]			/* no idle CPUs */	;\
	add	scr2, CONFIG_STACTIVE, scr4	/* ->active mask */	;\
	ldx	[scr4], scr2			/* current active */	;\
	or	scr3, scr2, scr3		/* active + curcpu */	;\
	or	scr1, scr3, scr1		/* + idle */		;\
	stx	scr1, [scr4]			/* all active */	;\
	mov	CMP_CORE_RUNNING_W1S, scr2				;\
	stxa	scr1, [scr2]ASI_CMP_CHIP	/* start all cpus */	;\
	mov	CMP_CORE_RUNNING_STATUS, scr2				;\
1:	ldxa	[scr2]ASI_CMP_CHIP, scr3				;\
	cmp	scr1, scr3						;\
	bne,pn	%xcc, 1b		/* wait until started */	;\
	nop								;\
	SPINLOCK_EXIT_SS_LOCK(scr1)					;\
	.poplocals
/* END CSTYLED */

#define	halt		.word	0xbd980000	/* wrhpr	%g0, %hpreg30 */
#define	read_halt	.word	0x814f8000	/* rdhpr	%hpreg30, %g0 */

#ifdef	SUPPORT_NIAGARA2_1x

/*
 * Niagara2 1.x: Try to slow down the progress of this thread by
 * performing long-latency loads.  Furthermore, spread out the loads
 * to different queueing FIFOs by core number.
 */
/* BEGIN CSTYLED */
#ifndef	DEBUG_LEGION			

#define	READ_REGS_FOR_HALT(paddr)			\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */	;\
	ldx	[paddr], %g0	/* read paddr */
#else

#define	READ_REGS_FOR_HALT(paddr)				\
	nop

#endif /* !DEBUG_LEGION */

#define	HALT_STRAND_NIAGARA2_1x()				\
	.pushlocals						;\
	setx	niagara2_cpu_yield_paddr_table, %g1, %g4	;\
	RELOC_OFFSET(%g2, %g1)					;\
	sub	%g4, %g1, %g1 /* %g1 table base */		;\
	mov	CMP_CORE_ID, %g3				;\
	ldxa	[%g3]ASI_CMP_CORE, %g3				;\
	and	%g3, NSTRANDS_PER_CORE_MASK, %g3		;\
	sllx	%g3, 3, %g3 /* %g3 offset into table */		;\
	add	%g1, %g3, %g1 /* %g1 addr of table entry */	;\
	ldx	[%g1], %g2 /* %g2 reg paddr */			;\
	READ_REGS_FOR_HALT(%g2)					;\
	.poplocals
#endif

/*
 * Niagara2 > 1.x: use the "halt" instruction.
 */
#define	HALT_STRAND_NIAGARA2()					\
	halt


#ifdef SUPPORT_NIAGARA2_1x
#define	HALT_STRAND()					\
	.pushlocals						;\
	rdhpr   %hver, %g1				;\
	srlx    %g1, VER_MASK_MAJOR_SHIFT, %g1		;\
	and     %g1, VER_MASK_MAJOR_MASK, %g1		;\
	cmp     %g1, 1	/* Check for Niagara2 1.x */	;\
	bleu,pt %xcc, 8f				;\
	nop						;\
	halt						;\
	ba	%xcc, 9f				;\
	nop						;\
8:							;\
	HALT_STRAND_NIAGARA2_1x()			;\
9:							;\
	.poplocals
#else
#define	HALT_STRAND	HALT_STRAND_NIAGARA2
#endif

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_CMP_H */
