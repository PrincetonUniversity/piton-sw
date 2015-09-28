/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_soft_state.s
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

	.ident	"@(#)hcall_soft_state.s	1.97	07/04/18 SMI"

#include <sys/asm_linkage.h>
#include <asi.h>
#include <guest.h>
#include <offsets.h>
#include <util.h>

/*
 * soft_state_set - Set guest's soft state
 *
 * arg0 software state (%o0)
 * arg1 software state description pointer (%o1)
 * --
 * ret0 error code (%o0)
 */
	ENTRY_NP(hcall_soft_state_set)
	GUEST_STRUCT(%g6)		! %g6 = guestp

	! check for valid software state
	! must be one of SIS_NORMAL or SIS_TRANSITION
	cmp	%o0, SIS_NORMAL
	be,pn	%xcc, 1f
	cmp	%o0, SIS_TRANSITION
	bne,pn	%xcc, herr_inval
	nop
1:
	! check that the software state description is aligned and 
	! contained in guest mmeory
	btst	SOFT_STATE_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	nop

	! RA2PA_RANGE_CONV(guestp, raddr, size, fail_label, segp, paddr)

	mov	%o1, %g3
	RA2PA_RANGE_CONV(%g6, %g3, SOFT_STATE_SIZE, herr_noraddr, %g2, %o1)

	! check for NUL termination of software state description
	mov	%o1, %g1			! %g1 is buffer pointer
	mov	SOFT_STATE_SIZE, %g4		! %g4 is loop counter
2:
	ldub	[%g1], %g5
	brz,pn	%g5, 1f				! found NUL
	dec	%g4
	brnz,pt	%g4, 2b
	inc	%g1				! check next char
	ba	herr_inval			! missing NUL
	nop
1:
	! get here when arguments are valid
	! acquire the guest's asynchronous soft state lock
	set	GUEST_ASYNC_LOCK, %g5
	add	%g5, (ENUM_HVctl_info_guest_soft_state * 8), %g5
	add	%g6, %g5, %g7
	SPINLOCK_ENTER(%g7, %g2, %g5)

	! save software state in guest structure
	stb	%o0, [%g6 + GUEST_SOFT_STATE]

	! zero out end of software state description in guest structure
	sub	%g1, %o1, %g3			! %g3 = index of NUL char
	add	%g6, GUEST_SOFT_STATE_STR, %g1
	add	%g1, %g3, %g1			! bzero destination
	add	%g4, 1, %g2	! bzero size (accounting for dec in delay slot)
	HVCALL(bzero)

	! copy software state description (up to NUL) into guest structure
	mov	%o1, %g1			! bcopy source
	add	%g6, GUEST_SOFT_STATE_STR, %g2	! bcopy destination
	! %g3 already set up			  bcopy size
	HVCALL(bcopy)

	! check if async notification for soft state is busy or not
	set	GUEST_ASYNC_BUSY, %g5
	add	%g6, %g5, %g3		! %g3 = base of busy flags array
	ldub	[%g3 + ENUM_HVctl_info_guest_soft_state], %g1
	brnz,pn	%g1, 1f
	! not busy, set busy flag and send asynchronous notification
	  mov	1, %g1
	stub	%g1, [%g3 + ENUM_HVctl_info_guest_soft_state]
	set	GUEST_ASYNC_BUF, %g5
	add	%g6, %g5, %g3
	add     %g3, HVCTL_MSG_MSG, %g3		! %g3 = base of hvctl msg field
	! zero out data part of message
	add	%g3, HVCTL_RES_STATUS_DATA, %g1
	set	HVCTL_RES_STATUS_DATA_SIZE, %g2
	HVCALL(bzero)
	! fill in message fields
	set	ENUM_HVctl_res_guest, %g5
	stuw	%g5, [%g3 + HVCTL_RES_STATUS_RES]	! resource type
	ldx	[%g6 + GUEST_GID], %g5
	stuw	%g5, [%g3 + HVCTL_RES_STATUS_RESID]	! resource id 
	set	ENUM_HVctl_info_guest_soft_state, %g5
	stuw	%g5, [%g3 + HVCTL_RES_STATUS_INFOID]	! info id 
	! code field is initialized to zero in init_guest() and never changed
	! fill in the info specific data, i.e. the soft state
	add	%g3, HVCTL_RES_STATUS_DATA, %g3	! g3 = base of data field
	stub	%o0, [%g3 + RS_GUEST_SOFT_STATE]
	add	%g6, GUEST_SOFT_STATE_STR, %g1
	add	%g3, RS_GUEST_SOFT_STATE_STR, %g2
	set	SOFT_STATE_SIZE, %g3
	HVCALL(bcopy)
	! send the message
	CONFIG_STRUCT(%g3)
	ldx	[%g3 + CONFIG_HVCTL_LDC], %g1
	set	GUEST_ASYNC_BUF, %g5
	add	%g6, %g5, %g2
	add	%g3, CONFIG_HVCTL_LDC_LOCK, %g7
	SPINLOCK_ENTER(%g7, %g4, %g5)
	HVCALL(hv_ldc_send_pkt)
	CONFIG_STRUCT(%g3)
	add	%g3, CONFIG_HVCTL_LDC_LOCK, %g7
	SPINLOCK_EXIT(%g7)
	GUEST_STRUCT(%g6)		! restore %g6 = guestp
1:
	! release guest's asynchronous notification lock
	set	GUEST_ASYNC_LOCK, %g5
	add	%g5, (ENUM_HVctl_info_guest_soft_state * 8), %g5
	add	%g6, %g5, %g7
	SPINLOCK_EXIT(%g7)

	HCALL_RET(EOK)
	SET_SIZE(hcall_soft_state_set)

/*
 * soft_state_get - Get guest's soft state
 *
 * arg0  software state description pointer (%o0)
 * --
 * ret0 error code (%o0)
 * ret1 software state (%o1)
 */
	ENTRY_NP(hcall_soft_state_get)
	GUEST_STRUCT(%g6)

	! check that software state description is aligned and 
	! contained in guest mmeory
	btst	SOFT_STATE_ALIGNMENT - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	! RA2PA_RANGE_CONV(guestp, raddr, size, fail_label, segp, paddr)
	
	RA2PA_RANGE_CONV(%g6, %o0, SOFT_STATE_SIZE, herr_noraddr, %g1, %g2)

	set	GUEST_ASYNC_LOCK, %g1
	add	%g1, (ENUM_HVctl_info_guest_soft_state * 8), %g1
	add	%g6, %g1, %g5
	SPINLOCK_ENTER(%g5, %g1, %g3)

	! copy software state description from guest structure
	!! %g2 bcopy destination

	add	%g6, GUEST_SOFT_STATE_STR, %g1	! bcopy source
	mov	SOFT_STATE_SIZE, %g3		! bcopy size
	HVCALL(bcopy)

	! set software state return value
	ldub	[%g6 + GUEST_SOFT_STATE], %o1

	SPINLOCK_EXIT(%g5)

	HCALL_RET(EOK)
	SET_SIZE(hcall_soft_state_get)
