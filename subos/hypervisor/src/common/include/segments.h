/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: segments.h
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

#ifndef _SEGMENTS_H
#define	_SEGMENTS_H

#pragma ident	"@(#)segments.h	1.2	07/05/15 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM

struct ra2pa_segment {
	uint64_t	base;
	uint64_t	limit;
	uint64_t	offset;
	uint8_t		flags;
	uint8_t		_pad1;
	uint16_t	_pad2;
	uint32_t	_pad3;
};

typedef struct ra2pa_segment ra2pa_segment_t;

#endif /* _ASM */


#define	INVALID_SEGMENT_SIZE		(-1)

/* flags for ra2pa_segment.flags */
#define	INVALID_SEGMENT			(0)
#define	MEM_SEGMENT			(1 << 0)
#define	IO_SEGMENT			(1 << 1)

	/*
	 * The following macros apply for the ra->pa and pa->ra conversion
	 * using the segmented memory mechanism.
	 * This allows a guest's memory to be apportioned in multiple
	 * dis-contiguous blocks, as well as supporting the various
	 * IO address spaces that are relevent only if the specific IO
	 * busses are indeed placed in the guest's real address spaces.
	 *
	 * This scheme replaces the old linear base & bounds range check which
	 * was broken anyway.
	 *
	 * We use the upper (64-RA2PA_SHIFT) bits of any RA as the index into a
	 * simple linear "page table". The index retrieves a guest specific
	 * entry describing a memory segment to be checked and translated.
	 * A simple base & bounds is checked using values described within the
	 * segment .. a simple offset is applied to convert the RA to a PA
	 * within the segment.
	 *
	 * Once a segment is found the base RA is guaranteed to be sane.
	 * However, in many cases the SIZE value comes from the guest
	 * OS and if negative causes lots of problems with range testing.
	 *
	 * So we wrap the weaker form of this macro with one which tests the
	 * size for being negative before handing off to the weaker macro.
	 * Though the form with the size check only takes a register as
	 * its size parameter. The wrapped form can also take a small
	 * constant.
	 *
	 * The largest defined page size for 4v is 34 bits (13+7*3) thus
	 * we can place each segment at this boundary without the risk
	 * of having a need for a larger page size.
	 * Actually the algorithm works for smaller segment sizes too
	 * because each segment holds a full base and bounds.
	 *
	 * The segmentation arrangement causes problems with supporting
	 * live migration. We are constrained to be able to support the
	 * same segmentation map on the target system. This is easier
	 * if the segmentation separation is as wide as possible - hence
	 * the choice of 34 bits as the index shift.
	 *
	 * We arrange the RA bit range to be big enough to also pick up the
	 * the IO bus address ranges. Fortunately each bus has a separation
	 * in the address space of at least 34 bits ...
	 */

#define	MAX_RA_BITS	40
#define	RA2PA_SHIFT	34	/* largest possible 4v page size */

#define	RA2PA_SEGMENT_SHIFT	5	/* size of ra2pa_segment struct */
#define	NUM_RA2PA_SEGMENT_BITS (MAX_RA_BITS-RA2PA_SHIFT)
#define	NUM_RA2PA_SEGMENTS	(1<<NUM_RA2PA_SEGMENT_BITS)

/* BEGIN CSTYLED */
#define	RA2PA_RANGE_CONV_UNK_SIZE(guestp, raddr, size, fail_label, segp, paddr)\
	brlez,pn	size, fail_label				;\
	RA2PA_RANGE_CONV(guestp, raddr, size, fail_label, segp, paddr)
/* END CSTYLED */

	/*
	 * Macro to check range assuming that size is limited and
	 * positive. The first instn of this macro must be able to
	 * function in the delay slot of the last instn of the outer
	 * macro.
	 */
/* BEGIN CSTYLED */
#define	RA2PA_RANGE_CONV(guestp, raddr, size, fail_label, segp, paddr)	\
	srlx	raddr, RA2PA_SHIFT, segp				;\
	cmp	segp, NUM_RA2PA_SEGMENTS				;\
		/* can branch on signed as srlx makes the number +ve */	;\
	bge,pn	%xcc, fail_label					;\
	sllx	segp, RA2PA_SEGMENT_SHIFT, segp				;\
	add	segp, GUEST_RA2PA_SEGMENT, segp				;\
	add	guestp, segp, segp					;\
	ldub	[segp + RA2PA_SEGMENT_FLAGS], paddr			;\
	btst	MEM_SEGMENT, paddr					;\
	bz,pn	%xcc, fail_label					;\
	ldx	[segp + RA2PA_SEGMENT_BASE], paddr			;\
	cmp	paddr, raddr						;\
	bgu,pn	%xcc, fail_label					;\
	ldx	[segp + RA2PA_SEGMENT_LIMIT], paddr			;\
	sub	paddr, raddr, paddr					;\
	cmp	paddr, size						;\
	blt,pn	%xcc, fail_label					;\
	ldx	[segp + RA2PA_SEGMENT_OFFSET], paddr			;\
	add	paddr, raddr, paddr
/* END CSTYLED */

	/*
	 * Check range, no RA->PA conversion
	 */
/* BEGIN CSTYLED */
#define	RA2PA_RANGE_CHECK(guestp, raddr, size, fail_label, scr1)	\
	srlx	raddr, RA2PA_SHIFT, scr1				;\
	cmp	scr1, NUM_RA2PA_SEGMENTS				;\
		/* can branch on signed as srlx makes the number +ve */	;\
	bge,pn	%xcc, fail_label					;\
	sllx	scr1, RA2PA_SEGMENT_SHIFT, scr1				;\
	add	scr1, GUEST_RA2PA_SEGMENT, scr1				;\
	add	guestp, scr1, scr1					;\
	ldub	[scr1 + RA2PA_SEGMENT_FLAGS], scr1			;\
	btst	MEM_SEGMENT, scr1					;\
	bz,pn	%xcc, fail_label					;\
	srlx	raddr, RA2PA_SHIFT, scr1				;\
	sllx	scr1, RA2PA_SEGMENT_SHIFT, scr1				;\
	add	scr1, GUEST_RA2PA_SEGMENT, scr1				;\
	add	guestp, scr1, scr1					;\
	ldx	[scr1 + RA2PA_SEGMENT_BASE], scr1			;\
	cmp	scr1, raddr						;\
	bgu,pn	%xcc, fail_label					;\
	srlx	raddr, RA2PA_SHIFT, scr1				;\
	sllx	scr1, RA2PA_SEGMENT_SHIFT, scr1				;\
	add	scr1, GUEST_RA2PA_SEGMENT, scr1				;\
	add	guestp, scr1, scr1					;\
	ldx	[scr1 + RA2PA_SEGMENT_LIMIT], scr1			;\
	sub	scr1, raddr, scr1					;\
	cmp	scr1, size						;\
	blt,pn	%xcc, fail_label					;\
	nop
/* END CSTYLED */

	/*
	 * Macro to convert RA to PA. RA must be valid for this guest.
	 */
/* BEGIN CSTYLED */
#define	RA2PA_CONV(guestp, raddr, paddr, segp)				\
	srlx	raddr, RA2PA_SHIFT, segp				;\
	sllx	segp, RA2PA_SEGMENT_SHIFT, segp				;\
	add	segp, GUEST_RA2PA_SEGMENT, segp				;\
	add	guestp, segp, segp					;\
	ldx	[segp + RA2PA_SEGMENT_OFFSET], segp			;\
	add	raddr, segp, paddr

	/*
	 * macro to get segment pointer for an RA. Returns (0) in segp
	 * if RA not valid for this guest.
	 */
#define	RA_GET_SEGMENT(guestp, raddr, segp, scr)			\
	srlx	raddr, RA2PA_SHIFT, segp				;\
	sllx	segp, RA2PA_SEGMENT_SHIFT, segp				;\
	add	segp, GUEST_RA2PA_SEGMENT, segp				;\
	add	guestp, segp, segp					;\
	ldub	[segp + RA2PA_SEGMENT_FLAGS], scr			;\
        btst    (MEM_SEGMENT | IO_SEGMENT), scr				;\
        move	%xcc, %g0, segp

/* END CSTYLED */


/* BEGIN CSTYLED */
/*
 * Find the segment containing a PA and return the corresponding RA.
 *
 * guestp	&guest struct, preserved
 * paddr	Physical Address to translate, preserved
 * raddr	Real Address for this PA (-1 if no translation)
 * scrN		clobbered
 * scr2		ret of non zero if no segment found containing this PA
 */
#define	PA2RA_CONV(guestp, paddr, raddr, scr1, scr2)	\
	.pushlocals							;\
	add	guestp, ((NUM_RA2PA_SEGMENTS - 1) * RA2PA_SEGMENT_SIZE)	\
			 + GUEST_RA2PA_SEGMENT, scr1			;\
					/* &guest.ra2pa_segment[N-1] */	;\
0:									;\
	ldx	[scr1 + RA2PA_SEGMENT_BASE], scr2	/* RA base */	;\
	brlz,pn	scr2, 1f		/* segment not in use */	;\
	  nop								;\
	ldx	[scr1 + RA2PA_SEGMENT_OFFSET], raddr /* RA offset */	;\
	sub	paddr, raddr, raddr			/* PA->RA */	;\
	cmp	raddr, scr2		/* RA < segment.base ? */	;\
	blu,pn	%xcc, 1f						;\
	  nop								;\
	ldx	[scr1 + RA2PA_SEGMENT_LIMIT], scr2 /* RA limit */	;\
	cmp	raddr, scr2		/* RA > segment.limit ? */	;\
	bgu,pn	%xcc, 1f		/* yes, next segment */		;\
	  nop								;\
	ba	2f			/* no, we are done */		;\
	  mov	0, scr2							;\
1:									;\
	add	guestp, GUEST_RA2PA_SEGMENT, scr2			;\
	cmp	scr1, scr2	 /* scr2 &guest.ra2pa_segment[0] */	;\
	bne,pt	%xcc, 0b		/* next segment */		;\
	  sub scr1, RA2PA_SEGMENT_SIZE, scr1				;\
	mov	1, scr2		/* no segment found, ret fail */	;\
	mov	-1, raddr						;\
2:									;\
	.poplocals
/* END CSTYLED */

#ifdef CONFIG_PCIE

/*
 * Note: Could just use RA2PA_RANGE_CONV_UNK_SIZE() macro, but that would
 *	 involve an extra memory access for RA2PA_SEGMENT_OFFSET.
 */
/* BEGIN CSTYLED */
#define	RANGE_CHECK_IO(guestp, raddr, size, pass_label, fail_label, segp, scr) \
	srlx	raddr, RA2PA_SHIFT, segp				;\
	cmp	segp, NUM_RA2PA_SEGMENTS				;\
		/* can branch on signed as srlx makes the number +ve */	;\
	bge,pn	%xcc, fail_label					;\
	sllx	segp, RA2PA_SEGMENT_SHIFT, segp				;\
	add	segp, GUEST_RA2PA_SEGMENT, segp				;\
	add	guestp, segp, segp					;\
	ldub	[segp + RA2PA_SEGMENT_FLAGS], scr			;\
	btst	IO_SEGMENT, scr						;\
	bz,pn	%xcc, fail_label					;\
	ldx	[segp + RA2PA_SEGMENT_BASE], scr			;\
	cmp	scr, raddr						;\
	bgu,pn	%xcc, fail_label					;\
	ldx	[segp + RA2PA_SEGMENT_LIMIT], scr			;\
	sub	scr, raddr, scr						;\
	cmp	scr, size						;\
	bge,pn	%xcc, pass_label					;\
	nop								;\
	ba	%xcc, fail_label					;\
	nop
#else /* !CONFIG_PCIE */
#define	RANGE_CHECK_IO(hstruct, raddr, size, pass_lbl, fail_lbl,	\
	scr1, scr2)		\
	ba,a	fail_lbl	;\
	.empty
/* END CSTYLED */
#endif	/* CONFIG_PCIE */

#ifdef __cplusplus
}
#endif

#endif /* _SEGMENTS_H */
