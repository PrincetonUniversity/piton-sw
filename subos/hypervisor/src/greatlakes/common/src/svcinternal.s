/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: svcinternal.s
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

	.ident	"@(#)svcinternal.s	1.15	07/06/07 SMI"

#ifdef CONFIG_SVC

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sun4v/mmu.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>
#include <fpga.h>

#include <offsets.h>
#include <config.h>
#include <guest.h>
#include <svc.h>
#include <util.h>
#include <debug.h>

#define CHECKSUM_PKT(addr, len, retval, sum, tmp0) \
	.pushlocals			;\
	btst	1, len			;\
	be,pt	%xcc, 1f		;\
	mov	%g0, sum		;\
	deccc	len			;\
	ldub	[addr + len], sum	;\
1:	lduh	[addr], tmp0		;\
	add	tmp0, sum, sum		;\
	deccc	2, len			;\
	bgt,pt	%xcc, 1b		;\
	inc	2, addr			;\
2:	srl	sum, 16, tmp0		;\
	sll	sum, 16, sum		;\
	srl	sum, 16, sum		;\
	brnz,pt	tmp0, 2b		;\
	add	tmp0, sum, sum		;\
	mov	-1, len			;\
	srl	len, 16, len		;\
	xor	sum, len, retval	;\
	.poplocals

/*
 * This is the internal access to the svc driver.
 */
#define r_svc	%g1
#define r_buf	%g2
#define r_len	%g3
#define r_tmp0	%g4
#define r_tmp1	%g5
#define r_svcbuf %g6
/*
 * svc_internal_send - Use this to send a packet from inside
 * the hypervisor
 *
 * You had better be sure *you* are not holding the SVC_CTRL_LOCK..
 *
 * Arguments:
 *   %g1 = is the handle given to you by svc_register
 *   %g2 = buf
 *   %g3 = len
 *   %g7 = return address
 * Return value:
 *   %g1 == 0	- ok
 *   %g1 != 0	- failed
 */
	ENTRY(svc_internal_send)
	!! r_svc = %g1
	!! r_tmp0 = %g4
	!! r_tmp1 = %g5
	LOCK(r_svc, SVC_CTRL_LOCK, r_tmp0, r_tmp1)
	ld	[r_svc + SVC_CTRL_CONFIG], r_tmp0	! get status
	btst	SVC_CFG_TX, r_tmp0
	bnz,pt	%xcc, 1f				! cant TX on this SVC
	ld	[r_svc + SVC_CTRL_STATE], r_tmp0

	mov	-1, %g2					! return FAILED.
.svc_internal_send_fail:
2:	UNLOCK(r_svc, SVC_CTRL_LOCK)
	mov	%g2, %g1
	HVRET

1:	btst	SVC_FLAGS_TP, r_tmp0			! TX pending?
	bnz,a,pn %xcc, .svc_internal_send_fail
	  mov	-2, %g2
	ld	[r_svc + SVC_CTRL_MTU], r_tmp0		! size
	dec	SVC_PKT_SIZE, r_tmp0			! mtu -= hdr
	cmp	r_len, r_tmp0
	bgu,a,pn %xcc, .svc_internal_send_fail		! failed - too big!!
	  mov	-3, %g2
	ld	[r_svc + SVC_CTRL_STATE], r_tmp0	! get state flags
	or	r_tmp0, SVC_FLAGS_TP, r_tmp0
	st	r_tmp0, [r_svc SVC_CTRL_STATE]
	UNLOCK(r_svc, SVC_CTRL_LOCK)			! set state
	!! r_svc = %g1
	!! r_tmp0 = %g4
	!! r_tmp1 = %g5
	!! r_svcbuf = %g6
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	ld	[r_svc + SVC_CTRL_XID], r_tmp0
	st	r_tmp0, [r_svcbuf + SVC_PKT_XID]	! xpid
	sth	%g0, [r_svcbuf + SVC_PKT_SUM]		! checksum=0
	ld	[r_svc + SVC_CTRL_SID], r_tmp0
	sth	r_tmp0, [r_svcbuf + SVC_PKT_SID]	! svcid
	add	r_len, SVC_PKT_SIZE, r_tmp0
	stx	r_tmp0, [r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE] ! total size
	add	r_svcbuf, SVC_PKT_SIZE, r_tmp0		! dest
	SMALL_COPY_MACRO(r_buf, r_len, r_tmp0, r_tmp1)
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], r_len
	CHECKSUM_PKT(r_svcbuf, r_len, r_buf, r_tmp0, r_tmp1)	!
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	sth	r_buf, [r_svcbuf + SVC_PKT_SUM]		! checksum
#undef r_svcbuf
#undef r_buf
#undef r_len
#define r_root  %g2
#define r_tmp2	%g3
#define r_tmp3	%g6
1:	ROOT_STRUCT(r_root)				! date root
	ldx	[r_root + CONFIG_SVCS], r_root		! svc root
	brz,a,pn r_root, .svc_internal_send_return	! failed!
	  mov	-4, %g1
	LOCK(r_root, HV_SVC_DATA_LOCK, r_tmp0, r_tmp1)
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp0	! Tail
	brz,pt r_tmp0, 1f
	  stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT] ! svc->next = 0
	/* Tail was non NULL */
	stx	r_svc, [r_tmp0 + SVC_CTRL_SEND + SVC_LINK_NEXT]
1:	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp0	! Head
	brnz,pt	r_tmp0, 2f
	stx	r_svc, [r_root + HV_SVC_DATA_SENDT]	! set Tail
	stx	r_svc, [r_root + HV_SVC_DATA_SENDH]

	/* If fpga is busy, don't send */
	lduw	[r_root + HV_SVC_DATA_SENDBUSY], r_tmp3
	brnz,pn	r_tmp3, 2f
	nop

	/* Head == NULL.. copy to SRAM, hit TX, enable SSI interrupts.. */
	SEND_SVC_PACKET(r_root, r_svc, r_tmp0, r_tmp1, r_tmp2, r_tmp3)
2:
	UNLOCK(r_root, HV_SVC_DATA_LOCK)
	mov	0, %g1
.svc_internal_send_return:
	HVRET
	SET_SIZE(svc_internal_send)
#undef r_svc
#undef r_buf
#undef r_len
#undef r_tmp1
#undef r_tmp2

#define r_svc	%g1
#define r_buf	%g2
#define r_len	%g3
#define r_tmp0	%g4
#define r_tmp1	%g5
#define r_svcbuf %g6
/*
 * svc_internal_send_nolock - Use this to send a packet from inside
 * the hypervisor. Caller is responsible for managing the sevices locks
 *
 * Arguments:
 *   %g1 = is the handle given to you by svc_register
 *   %g2 = buf
 *   %g3 = len
 *   %g7 = return address
 * Return value:
 *   %g1 == 0	- ok
 *   %g1 != 0	- failed
 */
	ENTRY(svc_internal_send_nolock)
	ld	[r_svc + SVC_CTRL_MTU], r_tmp0		! size
	dec	SVC_PKT_SIZE, r_tmp0			! mtu -= hdr
	cmp	r_len, r_tmp0
	bgu,a,pn %xcc, .svc_internal_send_fail_nolock	! failed - too big!!
	  mov	-3, %g2
	ld	[r_svc + SVC_CTRL_STATE], r_tmp0	! get state flags
	or	r_tmp0, SVC_FLAGS_TP, r_tmp0
	st	r_tmp0, [r_svc SVC_CTRL_STATE]
	!! r_svc = %g1
	!! r_tmp0 = %g4
	!! r_tmp1 = %g5
	!! r_svcbuf = %g6
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	ld	[r_svc + SVC_CTRL_XID], r_tmp0
	st	r_tmp0, [r_svcbuf + SVC_PKT_XID]	! xpid
	sth	%g0, [r_svcbuf + SVC_PKT_SUM]		! checksum=0
	ld	[r_svc + SVC_CTRL_SID], r_tmp0
	sth	r_tmp0, [r_svcbuf + SVC_PKT_SID]	! svcid
	add	r_len, SVC_PKT_SIZE, r_tmp0
	stx	r_tmp0, [r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE] ! total size
	add	r_svcbuf, SVC_PKT_SIZE, r_tmp0		! dest
	SMALL_COPY_MACRO(r_buf, r_len, r_tmp0, r_tmp1)
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_SIZE], r_len
	CHECKSUM_PKT(r_svcbuf, r_len, r_buf, r_tmp0, r_tmp1)	!
	ldx	[r_svc + SVC_CTRL_SEND + SVC_LINK_PA], r_svcbuf
	sth	r_buf, [r_svcbuf + SVC_PKT_SUM]		! checksum
#undef r_svcbuf
#undef r_buf
#undef r_len
#define r_root  %g2
#define r_tmp2	%g3
#define r_tmp3	%g6
1:	ROOT_STRUCT(r_root)				! data root
	ldx	[r_root + CONFIG_SVCS], r_root		! svc root
	brz,a,pn r_root, .svc_internal_send_return	! failed!
	  mov	-4, %g1
	ldx	[r_root + HV_SVC_DATA_SENDT], r_tmp0	! Tail
	brz,pt r_tmp0, 1f
	  stx	%g0, [r_svc + SVC_CTRL_SEND + SVC_LINK_NEXT] ! svc->next = 0
	/* Tail was non NULL */
	stx	r_svc, [r_tmp0 + SVC_CTRL_SEND + SVC_LINK_NEXT]
1:	ldx	[r_root + HV_SVC_DATA_SENDH], r_tmp0	! Head
	brnz,pt	r_tmp0, 2f
	  stx	r_svc, [r_root + HV_SVC_DATA_SENDT]	! set Tail
	/* Head == NULL.. copy to SRAM, hit TX, enable SSI interrupts.. */
	SEND_SVC_PACKET(r_root, r_svc, r_tmp0, r_tmp1, r_tmp2, r_tmp3)
	stx	r_svc, [r_root + HV_SVC_DATA_SENDH]
2:
	mov	0, %g1
.svc_internal_send_return_nolock:
.svc_internal_send_fail_nolock:
	HVRET
	SET_SIZE(svc_internal_send_nolock)
#undef r_svc
#undef r_buf
#undef r_len
#undef r_tmp1
#undef r_tmp2

#if 0 /* XXX unused? need to wire up for virtual interrupts */
/*
 * svc_internal_getstate - check state of a channel
 *
 * Arguments:
 *   %g1 is the handle given to you by svc_register
 * Return value:
 *   %g1 is the service state value (SVC_CTRL_STATE)
 */
	ENTRY(svc_internal_getstate)
	jmp	%g7 + 4
	  ld	[%g1 + SVC_CTRL_STATE], %g1
	SET_SIZE(svc_internal_getstate)
#endif

#endif /* CONFIG_SVC */
