/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_intr.s
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

	.ident	"@(#)vdev_intr.s	1.13	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <hprivregs.h>
#include <sun4v/asi.h>
#include <sun4v/intr.h>
#include <abort.h>
#include <strand.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>
#include <vdev_intr.h>


#ifndef MAPREG_SHIFT
#error "vdev_mapreg not properly sized (power of two)"
#endif


/*
 * vdev_init - initialize a guest's vdev state structure
 *
 * %i0 - &root, Config root data
 * %g1 - guest
 * --
 */
	ENTRY(vdev_init)
	!! %g1 = guestp
	/* XXX? get ign from CONFIG + CONFIG_VINTR, save */
	GUEST2VDEVSTATE(%g1, %g2)
	!! %g2 = vdevstatep

	/* XXX initialize vinobase */
	setx	VDEV_STATE_VINOBASE, %g4, %g3
	add	%g2, %g3, %g2
	mov	0x100, %g3
	sth	%g3, [%g2]

	jmp	%g7 + 4
	nop
	SET_SIZE(vdev_init)


/*
 * virtdevs_devino2vino
 *
 * arg0 dev config pa
 * arg1 dev ino
 * --
 * ret0 status
 * ret1 virtual INO
 */
	ENTRY(vdev_devino2vino)
	/*
	 * All validity checks on config pa and dev ino have been
	 * performed before we get here.  Just create the vino and
	 * and return.
	 */
	or	%o0, %o1, %o1
	HCALL_RET(EOK)
	SET_SIZE(vdev_devino2vino)

/*
 * vdev_intr_getvalid
 *
 * %g1 vdev state pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY(vdev_intr_getvalid)
	GUEST_STRUCT(%g2)
	GUEST2VDEVSTATE(%g2, %g1)
	!! %g1 = &guestp->vdev_state
	VINO2MAPREG(%g1, %o0, %g2)
	!! %g2 = vdev_mapregp
	ldub	[%g2 + MAPREG_VALID], %o1
	HCALL_RET(EOK)
	SET_SIZE(vdev_intr_getvalid)

/*
 * vdev_intr_setvalid
 *
 * %g1 vdev state pointer
 * arg0 Virtual INO (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY(vdev_intr_setvalid)
	GUEST_STRUCT(%g2)
	GUEST2VDEVSTATE(%g2, %g1)
	!! %g1 = &guestp->vdev_state
	VINO2MAPREG(%g1, %o0, %g2)
	!! %g2 = vdev_mapregp

	/*
	 * XXX Initialize data0 here for now
	 */
	stx	%o0, [%g2 + MAPREG_DATA0]

! mov	%g7, %g3
! PRINT("vdev_intr_setvalid mapreg 0x")
! PRINTX(%g2)
! PRINT(" INO 0x")
! PRINTX(%o0)
! PRINT("\r\n")
! mov	%g3, %g7

	and	%o0, DEVINOMASK, %g3
	stb	%g3, [%g2 + MAPREG_INO]

	/*
	 * Fill in new valid status
	 */
	stb	%o1, [%g2 + MAPREG_VALID]

	/*
	 * If !vmapreg.v then skip interrupt generation
	 */
	brz,pn	%o1, 1f
	nop

	/*
	 * Check for state IDLE, skip generating interrupt
	 * if not IDLE
	 */
	ldub	[%g2 + MAPREG_STATE], %g5
	cmp	%g5, INTR_IDLE
	bne,pn	%xcc, 1f
	nop

	/*
	 * Invoke driver's getstate callback if registered
	 */
	mov	%g2, %o0	! Save vdev_mapregp
	ldx	[%o0 + MAPREG_GETSTATE], %g2
	brz,pn	%g2, 1f
	ldx	[%o0 + MAPREG_DEVCOOKIE], %g1
	jmp	%g2		! getstate_callback(cookie)
	  rd	%pc, %g7
	mov	%g1, %g2
	mov	%o0, %g1
	brnz,pt	%g2, vdev_intr_generate
	  rd	%pc, %g7

1:	
	HCALL_RET(EOK)
	SET_SIZE(vdev_intr_setvalid)


/*
 * vdev_intr_settarget
 *
 * %g1 vdev state pointer
 * arg0 Virtual INO (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY(vdev_intr_settarget)
	GUEST_STRUCT(%g1)
	!! %g1 = guestp
	VCPUID2CPUP(%g1, %o1, %g3, herr_nocpu, %g4)
	!! %g3 = target cpup
	VCPU2STRAND_STRUCT(%g3, %g3)
	ldub	[%g3 + STRAND_ID], %g3
	!! %o0 = vino
	!! %o1 = target vcpuid
	!! %g3 = target pcpuid
	GUEST2VDEVSTATE(%g1, %g4)
	!! %g4 = &guestp->vdev_state
	VINO2MAPREG(%g4, %o0, %g2)
	!! %g2 = vdev_mapregp
	sth	%g3, [%g2 + MAPREG_PCPU]
	sth	%o1, [%g2 + MAPREG_VCPU]
	HCALL_RET(EOK)
	SET_SIZE(vdev_intr_settarget)


/*
 * vdev_intr_gettarget
 *
 * %g1 vdev state pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 target vcpu (%o1)
 */
	ENTRY(vdev_intr_gettarget)
	GUEST_STRUCT(%g2)
	GUEST2VDEVSTATE(%g2, %g1)
	!! %g1 = &guestp->vdev_state
	VINO2MAPREG(%g1, %o0, %g2)
	!! %g2 = vdev_mapregp
	lduh	[%g2 + MAPREG_VCPU], %o1
	HCALL_RET(EOK)
	SET_SIZE(vdev_intr_gettarget)


/*
 * vdev_intr_getstate
 *
 * %g1 vdev state pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr state (%o1)
 */
	ENTRY(vdev_intr_getstate)
	GUEST_STRUCT(%g2)
	GUEST2VDEVSTATE(%g2, %g1)
	!! %g1 = &guestp->vdev_state
	VINO2MAPREG(%g1, %o0, %g6)
	!! %g6 = mapreg
	ldub	[%g6 + MAPREG_STATE], %o1
	cmp	%o1, INTR_RECEIVED
	be,pn	%xcc, 1f
	nop
	ldx	[%g6 + MAPREG_GETSTATE], %g2
	brz,pn	%g2, 1f
	ldx	[%g6 + MAPREG_DEVCOOKIE], %g1
	jmp	%g2		! getstate_callback(cookie)
	  rd	%pc, %g7
	mov	%g1, %o1
1:	
	HCALL_RET(EOK)
	SET_SIZE(vdev_intr_getstate)


/*
 * vdev_intr_setstate
 *
 * %g1 vdev state pointer
 * arg0 vino (%o0)
 * arg1 new state (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY(vdev_intr_setstate)
	GUEST_STRUCT(%g2)
	GUEST2VDEVSTATE(%g2,%g1)
	!! %g1 = &guestp->vdev_state
	VINO2MAPREG(%g1, %o0, %g6)
	!! %g6 = vdev_mapregp

	/* Store new state, only check current state if the new state is IDLE */
	stb	%o1, [%g6 + MAPREG_STATE]

	ldx	[%g6 + MAPREG_SETSTATE], %g3
	brz,pn	%g3, 1f
	mov	%o1, %g2
	ldx	[%g6 + MAPREG_DEVCOOKIE], %g1
	mov	%g6, %o5	! XXX
	jmp	%g3		! setstate_callback(cookie,new-state)
	  rd	%pc, %g7
	mov	%o5, %g6
1:
	cmp	%o1, INTR_IDLE
	bne,pn	%xcc, 2f
	/* Call getstate callback */
	ldx	[%g6 + MAPREG_GETSTATE], %g2
	brz,pn	%g2, 2f
	ldx	[%g6 + MAPREG_DEVCOOKIE], %g1
	mov	%g6, %o5	! XXX
	jmp	%g2		! getstate_callback(cookie)
	  rd	%pc, %g7
	mov	%g1, %g2
	!! %g2 getstate result
	mov	%o5, %g1
	brnz,pn	%g2, vdev_intr_generate ! vdev_intr_generate(mapreg, state)
	  rd	%pc, %g7
2:
	HCALL_RET(EOK)
	SET_SIZE(vdev_intr_setstate)


/*
 * vdev_intr_register - internal routine to allow drivers to register
 * virtual interrupts.  The driver provides a callback routine that
 * returns the current "level" of its virtual interrupt pin.  The callback
 * routine is passed the driver's cookie in %g1 when it is invoked and is
 * expected to return 0 or non-zero for the pin state.
 *
 * %i0 - global config
 * %g1 - guest
 * %g2 - ino
 * %g3 - driver's cookie (pointer to state structure, etc)
 * %g4 - driver's getstate() callback address
 * %g5 - driver's setstate() callback address
 * %g7 - return address
 * --
 * %g1 - virtual interrupt handle (used by vdev_intr_generate)
 */
	ENTRY(vdev_intr_register)
	mov	%g1, %g6
	GUEST2VDEVSTATE(%g6, %g1)
	!! %g1 = vdev state pointer for the appropriate guest
	cmp	%g2, NINOSPERDEV
	bgeu,a,pn %xcc, 1f
	  mov	0, %g1
	VINO2MAPREG(%g1, %g2, %g6)
	!! %g6 = vdev_mapregp

	stx	%g3, [%g6 + MAPREG_DEVCOOKIE]
	stx	%g4, [%g6 + MAPREG_GETSTATE]
	stx	%g5, [%g6 + MAPREG_SETSTATE]

	setx	VDEV_STATE_VINOBASE, %g4, %g5
	lduh	[%g1 + %g5], %g5
	add	%g5, %g2, %g5
	!! %g5 vino
	stx	%g5, [%g6 + MAPREG_DATA0]
	mov	%g6, %g1	! return vdev_mapregp

1:	jmp	%g7 + 4
	nop
	SET_SIZE(vdev_intr_register)

	/*
	 * Wrapper around vdev_intr_register, so it can be called from C
	 * SPARC ABI requries only that g2,g3,g4 are preserved across
	 * function calls.
	 * %o0 = guestp
	 * %o1 = ino
	 * %o2 = &config.maus[mau-id]
	 * %o3 = mau_intr_getstate
	 * %o4 = mau_intr_setstate
	 *
	 * Returns cookie in %o0
	 *
	 * void c_vdev_intr_register(strand_t targetp, hvm_t *msgp)
	 */

	ENTRY(c_vdev_intr_register)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	mov	%o0, %g1
	mov	%o1, %g2
	mov	%o2, %g3
	mov	%o3, %g4
	mov	%o4, %g5
	HVCALL(vdev_intr_register)
	mov	%g1, %o0

	STRAND_POP(%g4, %g6)
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	
	retl
	  nop
	SET_SIZE(c_vdev_intr_register)


/*
 * vdev_intr_generate - generate a virtual interrupt.
 *
 * %g1 - virtual interrupt handle
 * %g7 - return address
 * --
 *
 * Clobbers:
 */

	/* FIXME: need to handle case of more than one vcpu per strand */

	ENTRY(vdev_intr_generate)
	ldub	[%g1 + MAPREG_VALID], %g2
	ldub	[%g1 + MAPREG_STATE], %g3
	brz,pn	%g2, 1f
	lduh	[%g1 + MAPREG_PCPU], %g2
	!! %g2 target pcpuid
	!! %g3 state

	/*
	 * Generate an interrupt if state is IDLE.
	 * Deliver locally if the current cpu is the same as the
	 * target.
	 */
	cmp	%g3, INTR_IDLE
	bne,pn	%xcc, 1f
	.empty	

	!! %g1 = vmapreg
	!! %g2 = target pcpuid
	PID2VCPUP(%g2, %g3, %g4, %g5)
	!! %g3 target cpup
	/*
	 * Update interrupt state to INTR_DELIVERED
	 */
	mov	INTR_DELIVERED, %g2
	stb	%g2, [%g1 + MAPREG_STATE]

	mov	%g1, %g4
	mov	%g3, %g1
	ldx	[%g4 + MAPREG_DATA0], %g3

	ba	send_dev_mondo	/* Returns to caller */
	mov	1 , %g2

1:	HVRET
	SET_SIZE(vdev_intr_generate)

/*
 * vdev_intr_redistribution
 *
 * Need to invalidate all of the virtual intrs that are
 * mapped to the cpu passed in %g1
 *
 * %g1 - this cpu id
 * %g2 - tgt cpu id
 */
	ENTRY_NP(vdev_intr_redistribution)
	GUEST_STRUCT(%g4)

	mov	(NINOSPERDEV -1), %g3
.vdev_intr_redis_loop:
	!! %g3 - vino
	!! %g4 - guest
	! get this vino's cpu target
	GUEST2VDEVSTATE(%g4, %g6)
	!! %g6 = &guestp->vdev_state
	VINO2MAPREG(%g6, %g3, %g5)
	!! %g5 = vdev_mapregp
	lduh	[%g5 + MAPREG_PCPU], %g6

	!! %g1 - cpuid
	!! %g6 - vino's cpuid
	! compare with this cpu, if match,  set to idle
	cmp	%g1, %g6
	bne,pt	%xcc, .vdev_intr_redis_continue
	nop

	/*
	 * Fill in the Invalid status
	 */
	mov	INTR_DISABLED, %g6	! Invalid
	stb	%g6, [%g5 + MAPREG_VALID]

.vdev_intr_redis_continue:
	deccc	%g3
	bgeu,pt	 %xcc, .vdev_intr_redis_loop 
	nop

.vdev_redis_done:

	HVRET
	SET_SIZE(vdev_intr_redistribution)
