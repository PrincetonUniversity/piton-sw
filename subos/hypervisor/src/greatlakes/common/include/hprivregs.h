/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hprivregs.h
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

#ifndef _HPRIVREGS_H
#define	_HPRIVREGS_H

#pragma ident	"@(#)hprivregs.h	1.20	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <platform/hprivregs.h>

/*
 * Niagara %ver
 */
#define	VER_MASK_SHIFT		24
#define	VER_MASK_MASK		0xff
#define	VER_MASK_MAJOR_SHIFT	(VER_MASK_SHIFT + 4)
#define	VER_MASK_MAJOR_MASK	0xf

/*
 * Hardware-implemented register windows
 */
#define	NWINDOWS	8

/*
 * Number of unique interrupts per strand
 */
#define	MAXINTR		64

/*
 * Max number of Global levels
 */
#define	MAXGL		3

/*
 * hpstate:
 *
 * +-----------------------------------------------------+
 * | rsvd | ENB | rsvd | RED | rsvd | HPRIV | rsvd | TLZ |
 * +-----------------------------------------------------+
 *  63..12  11   10..6    5    4..3     2       1     0
 */

#define	HPSTATE_TLZ	0x0001
#define	HPSTATE_HPRIV	0x0004
#define	HPSTATE_RED	0x0020
#define	HPSTATE_ENB	0x0800

/*
 * htstate:
 *
 * +-----------------------------------------+
 * | rsvd |  RED | rsvd | HPRIV | rsvd | TLZ |
 * +-----------------------------------------+
 *  63..6     5    4..3     2       1     0
 */

#define	HTSTATE_TLZ	0x0001
#define	HTSTATE_HPRIV	0x0004
#define	HTSTATE_RED	0x0010
#define	HTSTATE_ENB	0x0800

/*
 * hstickpending:
 *
 * +------------+
 * | rsvd | HSP |
 * +------------+
 *  63..1    0
 */

#define	HSTICKPEND_HSP	0x1

/*
 * htba:
 *
 * +---------------------------+
 * |    TBA     | TBATL | rsvd |
 * +---------------------------+
 *     63..15      14    13..0
 */
#define	TBATL		0x4000
#define	TBATL_SHIFT	14

/*
 * TLB demap register bit definitions
 * (ASI_DMMU_DEMAP/ASI_IMMU_DEMAP)
 */
#define	TLB_R_BIT		(0x200)
#define	TLB_DEMAP_PAGE_TYPE	0x00
#define	TLB_DEMAP_CTX_TYPE	0x40
#define	TLB_DEMAP_ALL_TYPE	0x80
#define	TLB_DEMAP_PRIMARY	0x00
#define	TLB_DEMAP_SECONDARY	0x10
#define	TLB_DEMAP_NUCLEUS	0x20

/*
 * LSU Control Register
 */
#define	ASI_LSUCR	0x45
#define	LSUCR_IC	0x000000001	/* I$ enable */
#define	LSUCR_DC	0x000000002	/* D$ enable */
#define	LSUCR_IM	0x000000004	/* IMMU enable */
#define	LSUCR_DM	0x000000008	/* DMMU enable */

/*
 * Misc
 */
#define	L2_CTL_REG	0xa900000000
#define	L2CR_DIS	0x00000001	/* L2$ Disable */
#define	L2CR_DMMODE	0x00000002	/* L2$ Direct-mapped mode */
#define	L2CR_SCRUBEN	0x00000004	/* L2$ Hardware scrub enable */

/*
 * INT_VEC_DIS constants
 */
#define	INT_VEC_DIS_TYPE_SHIFT	16
#define	INT_VEC_DIS_VCID_SHIFT	8
#define	INT_VEC_DIS_TYPE_INT	0x0
#define	INT_VEC_DIS_TYPE_RESET	0x1
#define	INT_VEC_DIS_TYPE_IDLE	0x2
#define	INT_VEC_DIS_TYPE_RESUME	0x3
#define	INT_VEC_DIS_VECTOR_RESET  0x1

/* BEGIN CSTYLED */
/*
 * Interrupt Vector Dispatch Macros
 */
/*
 * INT_VEC_DSPCH_ONE - interrupt vector dispatch one target
 *
 * Sends interrupt TYPE to any strand including the executing one.
 *
 * Delay Slot: no
 */
/* BEGIN CSTYLED */
#define	INT_VEC_DSPCH_ONE(TYPE, tgt, scr1, scr2) \
	setx	IOBBASE + INT_VEC_DIS, scr1, scr2			;\
	set	(TYPE) << INT_VEC_DIS_TYPE_SHIFT, scr1			;\
	sllx	tgt, INT_VEC_DIS_VCID_SHIFT, tgt			;\
	or	scr1, tgt, scr1						;\
	stx	scr1, [scr2]
/* END CSTYLED */

/*
 * INT_VEC_DSPCH_ALL - interrupt vector dispatch all
 *
 * Sends interrupt TYPE to all strands whose bit is set in SRC, excluding
 *   the executing one. SRC and DST bitmasks are updated.
 *
 * Delay Slot: no
 */
/* BEGIN CSTYLED */
#define	INT_VEC_DSPCH_ALL(TYPE, SRC, DST, scr1, scr2) \
	.pushlocals							;\
	rd	STR_STATUS_REG, scr2		/* my ID             */	;\
	srlx	scr2, STR_STATUS_CPU_ID_SHIFT, scr2			;\
	and	scr2, STR_STATUS_CPU_ID_MASK, scr2			;\
	mov	1, scr1							;\
	sllx	scr1, scr2, scr1		/* my bit            */	;\
	ldx	[SRC], scr2			/* Source state      */	;\
	stx	scr1, [SRC]			/* new Source        */	;\
	bclr	scr1, scr2			/* clear my bit      */	;\
	ldx	[DST], scr1			/* Destination state */	;\
	bset	scr2, scr1			/* add new bits      */	;\
	stx	scr1, [DST]			/* new To            */	;\
	setx	IOBBASE + INT_VEC_DIS, scr1, DST			;\
	set	(TYPE) << INT_VEC_DIS_TYPE_SHIFT, scr1			;\
1:	btst	1, scr2				/* valid strand?     */	;\
	bnz,a,pn %xcc, 2f			/*   yes: store      */	;\
	  stx	scr1, [DST]			/*   no: annul       */	;\
2:	srlx	scr2, 1, scr2			/* next strand bit   */	;\
	brnz	scr2, 1b			/* more to do        */	;\
	  inc	1 << INT_VEC_DIS_VCID_SHIFT, scr1			;\
	.poplocals
/* END CSTYLED */

/*
 * IDLE_ALL_STRAND
 *
 * Sends interrupt IDLE to all strands whose bit is set in CONFIG_STACTIVE,
 * excluding the executing one. CONFIG_STACTIVE, CONFIG_STIDLE are
 * updated.
 *
 * Delay Slot: no
 */
/* BEGIN CSTYLED */
#define	IDLE_ALL_STRAND(strand, scr1, scr2, scr3, scr4) \
	ldx	[strand + STRAND_CONFIGP], scr1	/* ->config*/		;\
	add	scr1, CONFIG_STACTIVE, scr3	/* ->active mask */	;\
	add	scr1, CONFIG_STIDLE, scr4	/* ->idle mask   */	;\
	INT_VEC_DSPCH_ALL(INT_VEC_DIS_TYPE_IDLE, scr3, scr4, scr1, scr2)
/* END CSTYLED */

/* BEGIN CSTYLED */
#define	RESUME_ALL_STRAND(strand, scr1, scr2, scr3, scr4) \
	ldx	[strand + STRAND_CONFIGP], scr1	/* ->config*/		;\
	add	scr1, CONFIG_STIDLE, scr3	/* ->idle mask   */	;\
	add	scr1, CONFIG_STACTIVE, scr4	/* ->active mask */	;\
	INT_VEC_DSPCH_ALL(INT_VEC_DIS_TYPE_RESUME, scr3, scr4, scr1, scr2)

#define	IS_STRAND_(state, vcpup, strand, scr1, scr2) \
	mov	1, scr1				/* bit */		;\
	sllx	scr1, strand, scr1		/* 1<<strand */		;\
	VCPU2ROOT_STRUCT(vcpup, scr2)		/* ->config*/		;\
	ldx	[scr2 + state], scr2		/* state mask */	;\
	btst	scr1, scr2			/* set cc */
/* END CSTYLED */

#define	IS_STRAND_ACTIVE(cpup, strand, scr1, scr2) \
	IS_STRAND_(CONFIG_STACTIVE, cpup, strand, scr1, scr2)

#define	IS_STRAND_HALT(cpup, strand, scr1, scr2) \
	IS_STRAND_(CONFIG_STHALT, cpup, strand, scr1, scr2)

#define	IS_STRAND_IDLE(cpup, strand, scr1, scr2) \
	IS_STRAND_(CONFIG_STIDLE, cpup, strand, scr1, scr2)

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _HPRIVREGS_H */
