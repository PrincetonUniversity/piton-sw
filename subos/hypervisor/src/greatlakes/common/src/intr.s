/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: intr.s
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

	.ident	"@(#)intr.s	1.43	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <asi.h>
#include <hprivregs.h>
#include <sun4v/asi.h>
#include <offsets.h>
#include <guest.h>
#include <intr.h>
#include <vdev_intr.h>
#include <util.h>
#include <debug.h>

	/*
	 * cpu_mondo -
	 *
	 * handles an incoming cpu_mondo x-call from another
	 * strand hosting a vcpu in the same domain as the current vcpu
	 * on this strand.
	 *
	 * On entry:
	 *  %g1 = vcpup
	 *  %g2	= intr-type
	 *
	 * On exit:
	 *  retry trapped instruction
	 */
	ENTRY(cpu_mondo)

	/*
	 * Update when we were called last
	 */
	rd	%tick, %g6
	stx	%g6, [%g1 + CPU_CMD_LASTPOKE]

	/*
	 * Wait for mailbox to not be busy
	 */
1:	ldx	[%g1 + CPU_COMMAND], %g6
	cmp	%g6, CPU_CMD_BUSY
	be,pn	%xcc, 1b
	cmp	%g6, CPU_CMD_GUESTMONDO_READY
	bne,pn	%xcc, .cpu_mondo_return
	.empty

	mov	CPU_MONDO_QUEUE_TAIL, %g2
	ldxa	[%g2]ASI_QUEUE, %g3
	add	%g3, Q_EL_SIZE, %g5
	ldx	[%g1 + CPU_CPUQ_MASK], %g6
	and	%g5, %g6, %g5
	mov	CPU_MONDO_QUEUE_HEAD, %g2
	ldxa	[%g2]ASI_QUEUE, %g4
	cmp	%g5, %g4
	be,pn	%xcc, .cpu_mondo_return	! queue is full
	  ldx	[%g1 + CPU_CPUQ_BASE], %g6

	! Simply return and drop mondo if Q was unconfigured from under us
	brz	%g6, .cpu_mondo_return
	  mov	CPU_MONDO_QUEUE_TAIL, %g2
	stxa	%g5, [%g2]ASI_QUEUE ! new tail pointer
	add	%g3, %g6, %g5

	/* Fill in newly-allocated cpu mondo entry */
	ldx	[%g1 + CPU_CMD_ARG0], %g6
	stxa	%g6, [%g5]ASI_BLK_INIT_P
	ldx	[%g1 + CPU_CMD_ARG1], %g6
	stx	%g6, [%g5 + 0x8]
	ldx	[%g1 + CPU_CMD_ARG2], %g6
	stx	%g6, [%g5 + 0x10]
	ldx	[%g1 + CPU_CMD_ARG3], %g6
	stx	%g6, [%g5 + 0x18]
	ldx	[%g1 + CPU_CMD_ARG4], %g6
	stx	%g6, [%g5 + 0x20]
	ldx	[%g1 + CPU_CMD_ARG5], %g6
	stx	%g6, [%g5 + 0x28]
	ldx	[%g1 + CPU_CMD_ARG6], %g6
	stx	%g6, [%g5 + 0x30]
	ldx	[%g1 + CPU_CMD_ARG7], %g6
	stx	%g6, [%g5 + 0x38]
	membar	#Sync		! make sure stores visible
	stx	%g0, [%g1 + CPU_COMMAND] ! clear for next xcall
.cpu_mondo_return:
	retry
	SET_SIZE(cpu_mondo)


/*
 * insert_device_mondo_r
 *
 * %g2 = data0
 * %g7 + 4 = return address
 *
 * %g1 - %g6 trashed
 */
	/*
	 * FIXME: This should probably arrive with a pointer to the
	 * vcpu the mondo is targeted at
	 */
	ENTRY_NP(insert_device_mondo_r)
	
	VCPU_STRUCT(%g1)	/* FIXME ! */
	mov	%g2, %g3
	ba send_dev_mondo	! tail call returns to caller
	set	1, %g2

	SET_SIZE(insert_device_mondo_r)


/*
 * insert_device_mondo_p
 *
 * %g1 = datap
 * %g7 + 4 = return address
 *
 * %g1 - %g6 trashed
 */
	ENTRY_NP(insert_device_mondo_p)
	
	mov	%g1, %g3
	VCPU_STRUCT(%g1)
	ba	send_dev_mondo	! tail call returns to caller
	mov	%g0, %g2
.no_devmondo_q:
	mov	%g7, %g5
	PRINT("dev q unconfigured\r\n");
	mov	%g5, %g7
	SET_SIZE(insert_device_mondo_p)


/*
 * send_dev_mondo
 *
 * %g1 = vcpup
 * %g2 = flag (0 = pointer to data, 1 = mondo) 
 * %g3 = data (depending on value of flag)	 
 * %g7 + 4 = return address
 *
 * %g2 - %g6 trashed
 */
	ENTRY_NP(send_dev_mondo)

	add	%g1, CPU_DEVQ_LOCK, %g4
	SPINLOCK_ENTER(%g4, %g5, %g6)
	
	ldx	[ %g1 + CPU_DEVQ_BASE ], %g4
	brz,a	%g4, 4f		! Queue not configured exit!
	  nop

	ldx	[ %g1 + CPU_DEVQ_SHDW_TAIL ], %g5
	add	%g5, Q_EL_SIZE, %g6
	ldx	[%g1 + CPU_DEVQ_MASK ], %g4
	and	%g6, %g4, %g6	
	!! %g1 = vcpup
	!! %g6 = new shadow tail
	!! %g5 = shadow tail

	stx	%g6, [ %g1 + CPU_DEVQ_SHDW_TAIL ]

	ldx	[ %g1 + CPU_DEVQ_BASE ], %g4
	add	%g5, %g4, %g5	! pointer to stuff mondo 

	brz	%g2, 1f		! data or pointer in %g3?
	nop

	stx	%g3, [ %g5 + 0x00 ]
	ba,a 	2f
	
1:
	ldx	[ %g3 + 0x00 ], %g2
	stx	%g2, [%g5 + 0x00]
	ldx	[%g3 + 0x08], %g2
	stx	%g2, [%g5 + 0x08]
	ldx	[%g3 + 0x10], %g2
	stx	%g2, [%g5 + 0x10]
	ldx	[%g3 + 0x18], %g2
	stx	%g2, [%g5 + 0x18]
	ldx	[%g3 + 0x20], %g2
	stx	%g2, [%g5 + 0x20]
	ldx	[%g3 + 0x28], %g2
	stx	%g2, [%g5 + 0x28]
	ldx	[%g3 + 0x30], %g2
	stx	%g2, [%g5 + 0x30]
	ldx	[%g3 + 0x38], %g2
	stx	%g2, [%g5 + 0x38]

2:
	! is local the target?
	VCPU_STRUCT(%g3)
	
	cmp	%g3, %g1
	bne	%xcc, 3f
	 nop

	! Just update the local cpu's devq since it is the target.
	! %g6 = new shadow tail.	
	
	/*
 	 * XXX Sanity test that new tail does not corrupt head of queue
	 */  	
	set	DEV_MONDO_QUEUE_TAIL, %g4
	ba	4f
	stxa	%g6, [%g4] ASI_QUEUE
3:
	/*
	 * Poke target to update DevQ
	 * %g2 = target strand id
	 */
	VCPU2STRAND_STRUCT(%g1, %g2)
	ldub	[%g2 + STRAND_ID], %g2
	
	! %g2 = target strand
	
	sllx	%g2, INT_VEC_DIS_VCID_SHIFT, %g3
	or	%g3, VECINTR_VDEV, %g3
	stxa	%g3, [%g0]ASI_INTR_UDB_W

4:
	add	%g1, CPU_DEVQ_LOCK, %g4
	SPINLOCK_EXIT(%g4)
	
	HVRET
	SET_SIZE(send_dev_mondo)


/*
 * vdev_mondo
 * 
 * %g1 = vcpup
 * %g2-%g4 clobbered. 
 */
	ENTRY_NP(vdev_mondo)

	add	 %g1,  CPU_DEVQ_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g3, %g4)

	ldx	[ %g1 + CPU_DEVQ_SHDW_TAIL], %g3

	set	DEV_MONDO_QUEUE_TAIL, %g4
	stxa	%g3, [ %g4 ] ASI_QUEUE

	add	 %g1,  CPU_DEVQ_LOCK, %g2
	SPINLOCK_EXIT(%g2)
	
	HVRET		
	SET_SIZE(vdev_mondo)


/*
 * dev_mondo - handle an incoming JBus mondo
 *
 * %g1 = cpup
 * %g7 + 4 = return address
 */
	ENTRY(dev_mondo)
	! XXX Check BUSY bit and ignore the dev mondo if it is not set
	setx	DEV_MONDO_INT, %g4, %g6
	ldx	[%g6 + DEV_MONDO_INT_ABUSY], %g4
	btst	DEV_MONDO_INT_ABUSY_BUSY, %g4
	bz,pn	%xcc, 2f			! Not BUSY .. just ignore
	ldx	[%g6 + DEV_MONDO_INT_DATA0], %g2	! THREADID[5:0],INO[5:0]
	ldx	[%g6 + DEV_MONDO_INT_DATA1], %g3	! IGN[5:0],ZERO[5:0]
	stx	%g0, [%g6 + DEV_MONDO_INT_ABUSY]	! Clear BUSY bit

	! vINOs and what I/O bridge puts into DATA0 are
	! the same therefore we don't need to translate
	! anything here

	and	%g2, NINOSPERDEV - 1 , %g4
	or	%g4, %g3, %g2
	srlx	%g3, DEV_DEVINO_SHIFT, %g3
	! %g1 = cpup
	! %g2 = IGN,INO
	! %g3 = IGN
	! %g4 = INO
	JMPL_VINO2DEVOP(%g2, DEVOPSVEC_MONDO_RECEIVE, %g1, %g6, 2f)
2:
	retry
	SET_SIZE(dev_mondo)


	/*
	 * We were interrupted for a x-call mondo for something.
	 * so we stash the state of the current vcpu and
	 * jump to the main handler/scheduler function
	 */
	ENTRY_NP(hvxcall_mondo)

	VCPU_STRUCT(%g2)
	set	CPU_LAUNCH_WITH_RETRY, %g3
	mov	1, %g1
	stb	%g1, [%g2 + %g3]

	HVCALL(vcpu_state_save)

	ba,pt	%xcc, handle_hvmondo
	  nop
	SET_SIZE(hvxcall_mondo)
