/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cwq.h
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

#ifndef _PLATFORM_CWQ_H
#define	_PLATFORM_CWQ_H

#pragma ident	"@(#)cwq.h	1.1	07/05/03 SMI"

/*
 * Niagara2 CWQ definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM

/*
 * Per-cwq attributes.
 */
typedef struct {
	resource_t	res;
	int		pid;
	int		ino;
	int		guestid;
	uint64_t	cpuset;		/* cpus ref CWQ */
} cwq_parse_info_t;


typedef struct cwq_queue {
	uint64_t	cq_lock;
	uint32_t	cq_state;
	uint32_t	cq_busy;
	uint64_t	cq_dr_base_ra;
	uint64_t	cq_dr_base;
	uint64_t	cq_dr_last;
	uint64_t	cq_dr_head;
	uint64_t	cq_dr_tail;
	uint64_t	cq_base;
	uint64_t	cq_last;
	uint64_t	cq_head;
	uint64_t	cq_head_marker;
	uint64_t	cq_tail;
	uint64_t	cq_nentries;
	uint64_t	cq_cpu_pid;	/* HV intr target */
	uint64_t	cq_scr1;
	uint64_t	cq_scr2;
	uint64_t	cq_scr3;
	uint64_t	cq_dr_hv_offset;
	/*
	 * space allocated for "shadow queue" elements
	 * allocate one more entry than necessary to make room
	 * for alignment of array to 64-byte boundary
	 */
	cwq_cw_t	cq_hv_cws[NCS_MAX_CWQ_NENTRIES + 1];
} cwq_queue_t;

struct cwq {
	uint64_t	pid;		/* physical CWQ id */
	uint64_t	state;		/* error/running/unconfig */
	uint64_t	handle;		/* handle for CWQ */
	uint64_t	ino;		/* ino property */
	uint64_t	cpuset;		/* cpus ref CWQ */
	uint8_t		cpu_active[NSTRANDS_PER_CORE];
	crypto_intr_t	ihdlr;		/* intr_handler info */
	struct guest	*guest;

	/*
	 * Configuration and running status
	 */
	uint32_t	res_id;
	cwq_parse_info_t	pip;
	cwq_queue_t	queue;		/* queue for CWQ */
};

#endif

/*
 * Niagara2 CWQ definitions
 */

/*
 * CWQ Initial Control Word
 *	Field		Bits	R/W
 *	-----		----	---
 *	EOB		53	R/W
 *	INTR		48	R/W
 *	RES		52:50	R/W
 *	STRAND_ID	39:37	R/W
 *	HMAC_KEYLEN	23:16	R/W
 *	LENGTH		15:0	R/W
 */
#define	CW_SOB_SHIFT		54
#define	CW_SOB_MASK		0x1
#define	CW_EOB_SHIFT		53
#define	CW_EOB_MASK		0x1
#define	CW_RES_SHIFT		50
#define	CW_RES_MASK		0x7
#define	CW_INTR_SHIFT		48
#define	CW_INTR_MASK		0x1
#define	CW_STRAND_ID_SHIFT	37
#define	CW_STRAND_ID_MASK	0x7
#define	CW_HMAC_KEYLEN_SHIFT	16
#define	CW_HMAC_KEYLEN_MASK	0xff
#define	CW_LENGTH_MASK		0xffff

#define	MAX_IV_LENGTH		32
#define	MAX_AUTHSTATE_LENGTH	32

/*
 * CWQ CSR bits
 */
#define	CWQ_CSR_ENABLED		1
#define	CWQ_CSR_BUSY		2
#define	CWQ_CSR_PROTOERR	4
#define	CWQ_CSR_HWERR		8

#define	CWQ_CSR_ERROR_SHIFT	2
#define	CWQ_CSR_ERROR		(CWQ_CSR_PROTOERR | \
				CWQ_CSR_HWERR)

#ifdef _ASM

/* BEGIN CSTYLED */


#ifndef	NCS_HANDLE_DEFS

#define	NCS_HANDLE_DEFS
#define	HANDLE_SIGMASK		0xfff
#define	HANDLE_IDMASK		0xfff
#define	HANDLE_IDSHIFT		16
#define	HANDLE2ID(hdl, idx)			\
	srlx	hdl, HANDLE_IDSHIFT, idx	; \
	and	idx, HANDLE_IDMASK, idx
#define	ID2HANDLE(idx, sig, hdl)		\
	and	idx, HANDLE_IDMASK, hdl		; \
	sllx	hdl, HANDLE_IDSHIFT, hdl	; \
	or	hdl, sig, hdl

#endif	/* NCS_HANDLE_DEFS */


#define	CWQ_HANDLE_SIG		0x0a72
#define	HANDLE_IS_CWQ(hdl, scr)			\
	and	hdl, HANDLE_SIGMASK, scr	; \
	cmp	scr, CWQ_HANDLE_SIG
#define	HANDLE_IS_CWQ_BRANCH(hdl, scr, label)	\
	and	hdl, HANDLE_SIGMASK, scr	; \
	cmp	scr, CWQ_HANDLE_SIG		;\
	be	%xcc, label			;\
	nop

/*
 * CWQ_HANDLE2ID_VERIFY
 *	Translates and verifies a CWQ specific handle
 *	for a valid signature and ID.
 */
#define	CWQ_HANDLE2ID_VERIFY(hdl, lbl, id)	\
	HANDLE_IS_CWQ(hdl, id)			; \
	bne,pn	%xcc, lbl			; \
	nop					; \
	HANDLE2ID(hdl, id)			; \
	cmp	id, NCWQS			; \
	bgeu,pn	%xcc, lbl			; \
	nop


#define	CWQ_CLEAR_QSTATE(cwq)			\
	stx	%g0, [cwq + CWQ_QUEUE + CQ_LOCK]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_DR_BASE_RA]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_DR_BASE]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_DR_LAST]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_DR_HEAD]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_DR_TAIL]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_BASE]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_LAST]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_HEAD]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_HEAD_MARKER]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_NENTRIES]	; \
	stx	%g0, [cwq + CWQ_QUEUE + CQ_DR_HV_OFFSET]	; \
	st	%g0, [cwq + CWQ_QUEUE + CQ_BUSY]

#define	GUEST_CID_GETCWQ(guest, id, cwq)	\
	sllx	id, GUEST_CWQS_SHIFT, cwq	; \
	add	cwq, GUEST_CWQS, cwq		; \
	ldx	[guest + cwq], cwq


#define	CWQ_LOCK_ENTER(cwq, lck, scr1, scr2)	\
	add	cwq, CWQ_QUEUE, lck		; \
	add	lck, CQ_LOCK, lck		; \
	SPINLOCK_ENTER(lck, scr1, scr2)
#define	CWQ_LOCK_EXIT(cwq, lck)			\
	add	cwq, CWQ_QUEUE, lck		; \
	add	lck, CQ_LOCK, lck		; \
	SPINLOCK_EXIT(lck)
#define	CWQ_LOCK_EXIT_L(lck)			\
	SPINLOCK_EXIT(lck)

#define	HCALL_NCS_QINFO_CWQ()				\
	HANDLE_IS_CWQ(%o0, %g2)				;\
	bne,pn	%xcc, herr_inval			;\
	nop						;\
							;\
	CWQ_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)	;\
	GUEST_CID_GETCWQ(%g1, %g2, %g3)			;\
	brz,pn	%g3, herr_inval				;\
	nop						;\
							;\
	CWQ_LOCK_ENTER(%g3, %g2, %g5, %g6)		;\
							;\
	mov	NCS_QTYPE_CWQ, %o1			;\
	ldx	[%g3 + CWQ_QUEUE + CQ_DR_BASE_RA], %o2	;\
	ldx	[%g3 + CWQ_QUEUE + CQ_NENTRIES], %o3	;\
							;\
	CWQ_LOCK_EXIT_L(%g2)				;\
							;\
	HCALL_RET(EOK)					;\

#define	HCALL_NCS_GETHEAD_CWQ()				\
	HANDLE_IS_CWQ(%o0, %g2)				;\
	bne,pn	%xcc, herr_inval			;\
	nop						;\
							;\
	CWQ_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)	;\
	GUEST_CID_GETCWQ(%g1, %g2, %g3)			;\
	brz,pn	%g3, herr_inval				;\
	nop						;\
							;\
	CWQ_LOCK_ENTER(%g3, %g5, %g2, %g6)		;\
							;\
	ldx	[%g3 + CWQ_QUEUE + CQ_BASE], %g1	;\
	ldx	[%g3 + CWQ_QUEUE + CQ_HEAD], %g2	;\
	sub	%g2, %g1, %o1				;\
							;\
	CWQ_LOCK_EXIT_L(%g5)				;\
							;\
	HCALL_RET(EOK)					;\

#define	HCALL_NCS_GETTAIL_CWQ()				\
	HANDLE_IS_CWQ(%o0, %g2)				;\
	bne,pn	%xcc, herr_inval			;\
	nop						;\
							;\
	CWQ_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)	;\
	GUEST_CID_GETCWQ(%g1, %g2, %g3)			;\
	brz,pn	%g3, herr_inval				;\
	nop						;\
							;\
	CWQ_LOCK_ENTER(%g3, %g5, %g2, %g6)		;\
							;\
	ldx	[%g3 + CWQ_QUEUE + CQ_BASE], %g1	;\
	ldx	[%g3 + CWQ_QUEUE + CQ_TAIL], %g2	;\
	sub	%g2, %g1, %o1				;\
							;\
	CWQ_LOCK_EXIT_L(%g5)				;\
							;\
	HCALL_RET(EOK)					;\

#define	HCALL_NCS_QHANDLE_TO_DEVINO_CWQ()		\
	HANDLE_IS_CWQ(%o0, %g2)				;\
	bne,pn	%xcc, herr_inval			;\
	nop						;\
							;\
	CWQ_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)	;\
	GUEST_CID_GETCWQ(%g1, %g2, %g3)			;\
	brz,pn	%g3, herr_inval				;\
	nop						;\
							;\
	ldx	[%g3 + CWQ_INO], %o1			;\
							;\
	HCALL_RET(EOK)					;\

#define	HCALL_NCS_SETHEAD_MARKER_CWQ()			\
	.pushlocals					;\
	HANDLE_IS_CWQ(%o0, %g2)				;\
	bne,pn	%xcc, herr_inval			;\
	nop						;\
							;\
	CWQ_HANDLE2ID_VERIFY(%o0, herr_inval, %g2)	;\
	GUEST_CID_GETCWQ(%g1, %g2, %g3)			;\
	brz,pn	%g3, herr_inval				;\
	nop						;\
							;\
	btst	CWQ_CW_SIZE - 1, %o1			;\
	bnz,a,pn %xcc, herr_inval			;\
	nop						;\
							;\
	CWQ_LOCK_ENTER(%g3, %g5, %g2, %g6)		;\
							;\
	ldx	[%g3 + CWQ_QUEUE + CQ_BASE], %g1	;\
	add	%g1, %o1, %g1				;\
	ldx	[%g3 + CWQ_QUEUE + CQ_LAST], %g2		;\
	cmp	%g1, %g2				;\
	bleu,a,pn %xcc, 2f				;\
	  stx	%g1, [%g3 + CWQ_QUEUE + CQ_HEAD_MARKER]	;\
							;\
	CWQ_LOCK_EXIT_L(%g5)				;\
							;\
	HCALL_RET(EINVAL)				;\
							;\
2:							;\
	CWQ_LOCK_EXIT_L(%g5)				;\
							;\
	HCALL_RET(EOK)					;\
	.poplocals

#define	IS_NCS_QTYPE_CWQ(q, qtype, qlabel)		\
	cmp	q, qtype				;\
	be	qlabel					;\
	nop

#endif	/* _ASM */

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_CWQ_H */
