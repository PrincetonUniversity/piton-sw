/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svc.s
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

	.ident	"@(#)svc.s	1.26	07/05/24 SMI"

#ifdef CONFIG_SVC /* { */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <fpga.h>
#include <intr.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <offsets.h>
#include <config.h>
#include <strand.h>
#include <guest.h>
#include <debug.h>
#include <svc.h>
#include <abort.h>
#include <util.h>
#include <ldc.h>
#include <vdev_intr.h>

/*
 * Perform service related functions
 *
 * enumerate_len(void)
 *		ret0 status
 *		ret1 len
 *
 * enumerate(buffer,len)
 *		ret0 status
 *		ret1 len
 *
 * send(svc, buffer, len)
 *		ret0 status
 *		ret1 len
 *
 * recv(svc, buffer, len)
 *		ret0 status
 *		ret1 len
 *
 * getstatus(svc)
 *		ret0 status
 *		ret1 vreg
 *
 * setstatus(svc, reg)			this is considered a SET SVC
 *		ret0 status
 *  
 * clrstatus(svc, reg)			this is considered a SET SVC
 *		ret0 status
 */
#define SVC_GET_SVC(r_g, r_s, fail_label)	\
	ROOT_STRUCT(r_s)			;\
	GUEST_STRUCT(r_g)			;\
	ldx	[r_s + CONFIG_SVCS], r_s	;\
	brz,pn	r_s, fail_label			;\
	nop

	! IN
	!   %o0 = svcid
	!   %o1 = size
	!   %g1 = guest data
	!   %g2 = svc data start
	!   %g7 = return address
	!
	! OUT
	!   %g1 - trashed
	!   %g2 - ??
	!   %g3 - ??
	!   %g4 -
	!   %g5 - scratch
	!   %g6 - service pointer
	!
#define r_svcarg %o0
#define r_xpid %g1
#define	r_nsvcs %g2
#define r_tmp0 %g3
#define r_tmp1 %g4
#define r_guest %g5
#define r_svc %g6
	ENTRY_NP(findsvc)
	SVC_GET_SVC(r_guest, r_svc, 2f)
	ld	[r_svc + HV_SVC_DATA_NUM_SVCS], r_nsvcs	! numsvcs
	add	r_svc, HV_SVC_DATA_SVC, r_svc		! svc base
	set	GUEST_GID, r_xpid
	ldx	[r_guest + r_xpid], r_xpid
	add	r_xpid, XPID_GUESTBASE, r_xpid
1:	ld	[r_svc + SVC_CTRL_XID], r_tmp0	! svc partid
	cmp	r_xpid, r_tmp0
	bne,pn	%xcc, 8f
	  ld	[r_svc + SVC_CTRL_SID], r_tmp1	! svcid
	cmp	r_tmp1, r_svcarg
	beq,pn	%xcc, 9f
8:	deccc	r_nsvcs
	bne,pn	%xcc, 1b
	  add	r_svc, SVC_CTRL_SIZE, r_svc		! next
2:	HCALL_RET(EINVAL)	! XXX was ENXIO
9:	HVRET
	SET_SIZE(findsvc)
#undef r_svcarg
#undef r_nsvcs
#undef r_xpid

#define r_svcarg %o0
#define r_xpid %g1
#define	r_nsvcs %g2
#define r_tmp0 %g3
#define r_tmp1 %g4
	
	ENTRY_NP(hcall_svc_getstatus)
	TRACE1("hcall_svc_getstatus")
	HVCALL(findsvc)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
	btst	SVC_CFG_GET, r_tmp0
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1
	HCALL_RET(EINVAL)
1:	and	r_tmp1, 0xfff, %o1		! XXX FLAGS MASK
	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_getstatus)

	! In
	!   %o0 = svc
	!   %o1 = bits to set
	ENTRY_NP(hcall_svc_setstatus)
	TRACE2("hcall_svc_setstatus")
	HVCALL(findsvc)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
	btst	SVC_CFG_SET, r_tmp0			! can set?
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp1, %g7)
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	HCALL_RET(EINVAL)
1:	and	r_tmp1, SVC_FLAGS_RE + SVC_FLAGS_TE, %g1
	mov	%g0, %g2				! mask
	btst	SVC_CFG_RE, r_tmp0			! svc has RE?
	bz,pt %xcc, 1f
	  btst	SVC_CFG_TE, r_tmp0			! svc has TE?
	or	%g2, SVC_FLAGS_RE, %g2			! RE bits ok
1:	bz,pt %xcc, 1f
	  btst	(1 << ABORT_SHIFT), %o1
	or	%g2, SVC_FLAGS_TE, %g2			! clr TE bits
1:	bz,pt	%xcc, 1f
	  btst	SVC_FLAGS_TP, r_tmp1		! queued?
	bz,pn	%xcc, 1f
	  nop
	! XXX need mutex.
	! need to check HEAD.. if pkt==head its too late..
	! else need to rip from the queue..
	PRINT("In Queue, Process Abort\r\n")
1:	and	%o1, %g2, %g2				! bits changed?
	xorcc	%g2, %g1, %g0
	beq,pn	%xcc, 1f
	  or	%g2, %g1, %g1
	or	r_tmp1, %g2, %g1
	st	%g1, [r_svc + SVC_CTRL_STATE]		! update state
1:
	/*
	 * Check if changing the flags requires an interrupt
	 * to be generated
	 */
	mov	r_svc, %g1
	HVCALL(svc_intr_getstate)
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	brz,pt	%g1, 1f
	nop

	/* Generate the interrupt */
	ldx	[r_svc	+ SVC_CTRL_INTR_COOKIE], %g1
	HVCALL(vdev_intr_generate)

1:	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_setstatus)

/*
 * svc send
 *
 * arg0 sid (%o0)
 * arg1 buffer (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 * XXX clobbers %o4
 */
#define r_tmp2 %g1
#define r_svcbuf %o4
	ENTRY_NP(hcall_svc_send)
	TRACE3("hcall_svc_send")
	HVCALL(findsvc)
	RA2PA_RANGE_CONV_UNK_SIZE(r_guest, %o1, %o2, herr_noraddr, \
							r_tmp0, r_tmp1)
	mov	r_tmp1, %o1		! PA
	ld	[r_svc + SVC_CTRL_MTU], r_tmp1
	sub	r_tmp1, SVC_PKT_SIZE, r_tmp1		! mtu -= hdr
	cmp	%o2, r_tmp1
	bleu,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
2:	mov	%g0, %o1				! NO HINTS
	mov	%g0, r_svcbuf				! NO HINTS
	HCALL_RET(EINVAL)				! size < 0
1:
	btst	SVC_CFG_TX, r_tmp0
	bz,pn	%xcc, 2b				! cant TX on this SVC
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp1, r_tmp2)
	ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state flags
	btst	SVC_FLAGS_TP, r_tmp1			! tx pending already?
	bz,pt	%xcc, 1f
	  or	r_tmp1, SVC_FLAGS_TP, r_tmp1
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	mov	%g0, %o1
	mov	%g0, r_svcbuf
	HCALL_RET(EWOULDBLOCK)				! bail
1:	st	r_tmp1, [r_svc + SVC_CTRL_STATE]	! set TX pending
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	ld	[r_svc + SVC_CTRL_XID], r_tmp1
	st	r_tmp1, [r_svcbuf + SVC_PKT_XID]	! xpid
	sth	%g0, [r_svcbuf + SVC_PKT_SUM]		! checksum=0
	sth	%o0, [r_svcbuf + SVC_PKT_SID]		! svcid
	add	r_svcbuf, SVC_PKT_SIZE, %o3		! dest
	add	%o2, SVC_PKT_SIZE, %g1
	stx	%g1, [r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE] ! total pkt size
	SMALL_COPY_MACRO(%o1, %o2, %o3, %g1)
	mov	r_svcbuf, %g1
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], %g2
	HVCALL(checksum_pkt)
	sth	%g1, [r_svcbuf + SVC_PKT_SUM]		! checksum

	! Now the fun starts, the packet is ready to go
	! but not on the tx queue yet.
	! check if it is 'linked'. A linked packet is
	! a fast path between two services, the RX, TX buffers
	! for linked services are swapped.
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp1	! get state flags
	btst	SVC_CFG_LINK, r_tmp1			! xlinked?
	bz,pt	%xcc, 1f
#ifdef CONFIG_MAGIC
	  nop
#endif
	  ldx	[r_svc + SVC_CTRL_LINK], r_tmp1		! get the linked svc
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], r_tmp2 ! get size
	stx	r_tmp2, [r_tmp1 + SVC_CTRL_RECV + SVC_LINK_SIZE]
	LOCK(r_tmp1, SVC_CTRL_LOCK, r_tmp2, %g2)
	ld	[r_tmp1 + SVC_CTRL_STATE], r_tmp2
	or	r_tmp2, SVC_FLAGS_RI, r_tmp2
	st	r_tmp2, [r_tmp1 + SVC_CTRL_STATE]	! RECV pending
	UNLOCK(r_tmp1, SVC_CTRL_LOCK)
	btst	SVC_FLAGS_RE, r_tmp2			! RECV intr enabled?
	bz,pn	%xcc, 2f
	  ldx	[r_tmp1	+ SVC_CTRL_INTR_COOKIE], %g1	! Cookie
	PRINT("XXX - SENDING RX PENDING INTR - XXX\r\n")
	ba	vdev_intr_generate			! deliver??
	  rd	%pc, %g7
2:	HCALL_RET(EOK)
#undef r_tmp2
1:	! Normal packet, need to queue it.
	!
#define r_root r_guest
#ifdef CONFIG_MAGIC
	btst	SVC_CFG_MAGIC, r_tmp1			! magic trap?
	bz,pt	%xcc, 1f
	  nop
#ifdef DEBUG_LEGION
	ta	%xcc, 0x7f	! not a standard legion magic trap
#endif
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], %o1
	sub	%o1, SVC_PKT_SIZE, %o1			! return bytes
	HCALL_RET(EOK)
#endif
1:
	ROOT_STRUCT(r_root)
	ldx	[r_root + CONFIG_SVCS], r_root		! svc root
	LOCK(r_root, HV_SVC_DATA_LOCK, r_tmp0, r_tmp1)
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp0	! Tail
	brz,pt r_tmp0, 1f
	  stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT] ! svc->next = 0
	! Tail was non NULL.
	stx	r_svc, [r_tmp0 + SVC_CTRL_SEND + SVC_LINK_NEXT]
#ifdef INTR_DEBUG
	PRINT("Queuing packet\r\n")
#endif
1:	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp0	! Head
	brnz,pt	r_tmp0, 2f
	  stx	r_svc, [r_root + HV_SVC_DATA_SENDT]	! set Tail
	! Head == NULL.. copy to SRAM, hit TX, enable SSI interrupts..
	!
#ifdef INTR_DEBUG
	PRINT("Copy packet to sram, kick it\r\n");
#endif
	SEND_SVC_PACKET(r_root, r_svc, %o1, %o2, r_tmp0, r_tmp1)
	stx	r_svc, [r_root + HV_SVC_DATA_SENDH]
2:	UNLOCK(r_root, HV_SVC_DATA_LOCK)
	mov	%g0, %o1				! NO HINTS
	mov	%g1, %o2				! NO HINTS
	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_send)
#undef r_root

/*
 * svc recv
 *
 * arg0 sid (%o0)
 * arg1 buffer (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 size (%o1)
 */
	ENTRY_NP(hcall_svc_recv)
	TRACE3("hcall_svc_recv")
	HVCALL(findsvc)
	RA2PA_RANGE_CONV_UNK_SIZE(r_guest, %o1, %o2, herr_noraddr, \
							r_tmp0, r_tmp1)
	mov	r_tmp1, %o1			! get the buffer addr
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp1	! get cfg flags
	btst	SVC_CFG_RX, r_tmp1			! can RX?
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state flags
	! XXX was ENXIO
	mov	0, %o1					! NO HINTS
	HCALL_RET(EINVAL)				! No SVC
1:	btst	SVC_FLAGS_RI, r_tmp1			! got a pkt?
	bnz,pt	%xcc, 1f
	  ldx	[r_svc + SVC_CTRL_RECV + SVC_LINK_PA], r_svcbuf
	mov	%g0, r_svcbuf
	mov	0, %o1					! NO HINTS
	HCALL_RET(EWOULDBLOCK)				! no pkt.
1:	ldx	[r_svc + SVC_CTRL_RECV + SVC_LINK_SIZE], r_tmp1	! # bytes
	sub	r_tmp1, SVC_PKT_SIZE, r_tmp1		! remove header
	cmp	%o2, r_tmp1
	bleu,pt	%xcc, 1f				! min xfer
	  mov	%o1, %g2
	mov	r_tmp1, %o2				! return size..
1:	mov	%o2, %g3				! set size
	mov	%o2, %o1				! return size..
	add	r_svcbuf, SVC_PKT_SIZE, %g1		! src
	SMALL_COPY_MACRO(%g1,%g3,%g2,%g4)
	HCALL_RET(EOK)					! all done
	SET_SIZE(hcall_svc_recv)
#undef r_tmp2
#undef r_svcbuf


#define r_lsvc	%g5
#define r_tmp2	%g1
#define r_tmp3	%o4
#define r_tmp4	%g2
#define r_clr	%o1
	! %o0 = svc
	! %o1 = state bits
	ENTRY_NP(hcall_svc_clrstatus)
	TRACE2("hcall_svc_clrstatus")
	HVCALL(findsvc)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0
	btst	SVC_CFG_SET, r_tmp0			! can set?
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp1, r_tmp3)
	bnz,pt	%xcc, 1f
	  ld	[r_svc + SVC_CTRL_STATE], r_tmp1	! get state
	UNLOCK(r_svc, SVC_CTRL_LOCK)
	HCALL_RET(EINVAL)
1:	and	r_clr, (1 << ABORT_SHIFT), r_tmp3	! permit clr of abort
	and	r_clr, r_tmp0, r_clr			! toss bad bits
	or	r_clr, r_tmp3, r_clr
	and	r_clr, r_tmp1, r_clr
	mov	r_tmp1, r_tmp3				! save current state
	mov	%g0, r_tmp4
	btst	SVC_FLAGS_RI, r_clr			! test RI
	bz,pn	%xcc, clrre				! got RI?
	  btst	SVC_CFG_RE, r_clr			! test RE
	andn	r_tmp1, SVC_FLAGS_RI, r_tmp1		! clr RI status
	btst	SVC_CFG_LINK, r_tmp0			! linked?
	bz,pt	%xcc, clrre
	  btst	SVC_CFG_RE, r_clr			! re-test RE
	! Linked service:  a clear RX done completes XFER
	ldx	[r_svc + SVC_CTRL_LINK], r_lsvc
	LOCK(r_lsvc, SVC_CTRL_LOCK, r_tmp4, %g7)
	ld	[r_lsvc + SVC_CTRL_STATE], r_tmp4	! get linked state
	andn	r_tmp4, SVC_FLAGS_TP, r_tmp4		! TP clear
	or	r_tmp4, SVC_FLAGS_TI, r_tmp4		! set TX intr
	btst	SVC_FLAGS_TE, r_tmp4			! TX INTR enabled?
	st	r_tmp4, [r_lsvc + SVC_CTRL_STATE]	! done.
	UNLOCK(r_lsvc, SVC_CTRL_LOCK)
	mov	%g0, r_tmp4				! no-linked intr
	bz,pn	%xcc, clrre
	  btst	SVC_CFG_RE, r_clr
	mov	r_lsvc, r_tmp4				! yes, linked intr
clrre:	bz,pn	%xcc, 1f				! got RE?
	  btst	SVC_CFG_TX, r_clr			! test TI
	andn	r_tmp1, SVC_FLAGS_RE, r_tmp1		! clr RE
1:	bz,pn	%xcc, 1f				! got TI?
	  btst	SVC_CFG_TE, r_clr			! test TE
	andn	r_tmp1, SVC_FLAGS_TI, r_tmp1		! clr TI
1:	bz,pn	%xcc, 1f				! got TE?
	  btst	(1 << ABORT_SHIFT), r_clr
	andn	r_tmp1, SVC_FLAGS_TE, r_tmp1		! clr TE
1:	bz,pn	%xcc, 1f				! clr Abort?
	  cmp	r_clr, %g0				! <nothing>
	andn	r_tmp1, (1 << ABORT_SHIFT), r_tmp1
1:	bz,pn	%xcc, 1f
	  xorcc	r_tmp3, r_tmp1, %g0			! bits changed?
	bz,pn	%xcc, 1f
	  mov	%g0, r_tmp3
	st	r_tmp1, [r_svc + SVC_CTRL_STATE]	! update state
1:	UNLOCK(r_svc, SVC_CTRL_LOCK)
	brz,pt	r_tmp4, 1f
	  nop
	PRINT("XXX - SENDING TX COMPLETE INTR - XXX\r\n")
	ldx	[r_lsvc	+ SVC_CTRL_INTR_COOKIE], %g1	! Cookie
	ba	vdev_intr_generate			! deliver??
	  rd	%pc, %g7
1:	HCALL_RET(EOK)
	SET_SIZE(hcall_svc_clrstatus)
#undef r_lsvc
#undef r_tmp2
#undef r_tmp3
#undef r_tmp4
#undef r_clr
#undef r_svcarg
#undef r_xpid
#undef r_nsvcs
#undef r_tmp0
#undef r_tmp1
#undef r_guest
#undef r_svc

#endif /* } CONFIG_SVC */
