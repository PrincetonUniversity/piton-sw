/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: intr_ontario.s
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

	.ident	"@(#)intr_ontario.s	1.43	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <asi.h>
#include <hprivregs.h>
#include <sun4v/asi.h>
#include <offsets.h>
#include <vdev_intr.h>
#include <util.h>
#include <iob.h>

/*
 * cpu_in_error_finish - invoked from a cpu about to enter the error
 * state so another cpu can finish cleaning up.
 */
	ENTRY(cpu_in_error_finish)
	CPU_PUSH(%g7, %g2, %g3, %g4)		! save return address
	STRAND_STRUCT(%g1)

	/*
	 * Send a resumable erpt to the guest.  The fault cpu should have
	 * left a valid erpt in the current cpu's ce err buf.
	 */
	add	%g1, STRAND_CE_RPT, %g2

	! get the error CPUID to do the necessary cleanup
	lduh	[%g2 + STRAND_SUN4V_ERPT + ESUN4V_G_CPUID], %g1

	! get the vcpu and strand for the vcpu that took the error
	GUEST_STRUCT(%g3)
	sllx	%g1, GUEST_VCPUS_SHIFT, %g1
	add	%g1, %g3, %g1
	add	%g1, GUEST_VCPUS, %g1
	ldx	[%g1], %g1			! err vcpu struct
	ldx	[%g1 + CPU_STRAND], %g2		! err strand struct

	! deschedule and stop the vcpu
	! %g1 - vcpu struct
	! %g2 - strand struct
	HVCALL(desched_n_stop_vcpu)

	STRAND_STRUCT(%g1)			! this strand
	add	%g1, STRAND_CE_RPT, %g2
	HVCALL(queue_resumable_erpt)

	/*
	 * If the heartbeat is disabled then it was running on the failed
	 * cpu and needs to be restarted on this cpu.
	 */
	ROOT_STRUCT(%g2)
	ldx	[%g2 + CONFIG_HEARTBEAT_CPU], %g2
	cmp	%g2, -1
	bne,pt	%xcc, 1f
	nop
	HVCALL(heartbeat_enable)
1:
	CPU_POP(%g7, %g1, %g2, %g5)
	retry
	SET_SIZE(cpu_in_error_finish)


/*
 * vdev_mondo - deliver a virtual mondo on the current cpu's
 * devmondo queue.
 *
 * %g1 - cpup
 * %g7 - return address
 * --
 *
 * Note: This function is called from the interrupt handler and also
 *	 as a tail function
 */

	! the mondo starting point.
	! %g1	cpup
	! %g2	intr-type
	ENTRY_NP(vecintr)
	cmp	%g2, VECINTR_XCALL
	beq,pt	%xcc, cpu_mondo
	cmp	%g2, VECINTR_HVXCALL
	beq,pt	%xcc, hvxcall_mondo
	cmp	%g2, VECINTR_DEV
	beq,pt	%xcc, dev_mondo
#ifdef CONFIG_FPGA
	cmp	%g2, VECINTR_FPGA
	beq,pt	%xcc, fpga_intr
#endif
#ifdef T1_FPGA_SNET
	cmp	%g2, VECINTR_SNET
	beq,pt	%xcc, snet_mondo
#endif
	cmp	%g2, VECINTR_VDEV
	bne,pt	%xcc, 1f
	nop

	HVCALL(vdev_mondo)
	retry
1:
	cmp	%g2, VECINTR_ERROR_XCALL
	beq,pt	%xcc, cpu_err_rerouted

	cmp	%g2, VECINTR_SSIERR
	beq,pt	%xcc, ssi_mondo
	cmp	%g2, VECINTR_CPUINERR 
	beq,pt	%xcc, cpu_in_error_finish
	nop

	! XXX unclaimed interrupt
irq_unclaimed:
.vecintr_qfull:			! XXX need to do the right thing here
	retry
	SET_SIZE(vecintr)
