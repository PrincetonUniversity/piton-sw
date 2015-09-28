/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_core.s
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

	.ident	"@(#)hcall_core.s	1.104	07/08/02 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <sun4v/traps.h>
#include <sun4v/asi.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <hprivregs.h>
#include <guest.h>
#include <offsets.h>
#include <util.h>
#include <debug.h>
#include <traptrace.h>
#include <vdev_intr.h>
#include <vdev_ops.h>
#include <intr.h>
#include <cache.h>

/*
 * guest_exit
 *
 * Invoked by hcall_mach_exit or a strand in error. In the case
 * of mach_exit, the strand waits for more work. In the case of
 * the latter, on return the strand idles itself.
 */
	ENTRY(guest_exit)

	STRAND_PUSH(%g7, %g2, %g3)		! save return address

	/*
	 * Loop over all guests and check if there is more
	 * than one guest configured in the system. If not,
	 * call vbsc_guest_exit.
	 */
	ROOT_STRUCT(%g1)
	GUEST_STRUCT(%g5)			! this guest
	ldx	[%g1 + CONFIG_GUESTS], %g1	! &guest[0]
	set	NGUESTS - 1, %g3		! guest loop counter
	set	GUEST_SIZE, %g2
1:
	cmp	%g1, %g5
	beq	%xcc, 2f			! skip this guest
	  nop
	lduw	[%g1 + GUEST_STATE], %g4
	cmp	%g4, GUEST_STATE_UNCONFIGURED	! if another guest, and if
	bne,pt	%xcc, 3f			! it is not unconfigured
	  nop					! do not poweroff
2:
	add	%g1, %g2, %g1			! guest++
	brnz,pt	%g3, 1b
	 dec	%g3				! nguests--

	/*
	 * If this is the last guest and there is a delayed reconfig in
	 * progress, do not poweroff
	 */
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DEL_RECONF_GID], %g1
	ldx	[%g5 + GUEST_GID], %g2
	cmp	%g1, %g2
	beq,pn	%xcc, 3f
	nop

	PRINT("\tfor the last guest ...\r\n")
#ifdef CONFIG_VBSC_SVC
        ba,pt   %xcc, vbsc_guest_exit
        nop
#else
        LEGION_EXIT(%o0)
#endif
3:
        wrpr    %g0, 0, %gl
        wrpr    %g0, 0, %tl
        HVCALL(setup_c_environ)

	GUEST_STRUCT(%o0)
	add	%o0, GUEST_STATE_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g1, %g3)
	!! %o0 current guest
	!! %g2 guest state lock

	! check the state of the guest
	lduw	[%o0 + GUEST_STATE], %g3
	cmp	%g3, GUEST_STATE_RESETTING
	be,pn	%xcc, 6f
	cmp	%g3, GUEST_STATE_EXITING
	be,pn	%xcc, 6f
	nop

	! check if this is the control domain
	CTRL_DOMAIN(%g1, %g3, %g4)	!! %g1 control domain guestp
	cmp	%g1, %o0
	beq,pn	%xcc, 4f
	  nop

	! not the control domain - exit
	set	GUEST_STATE_EXITING, %g4
	stuw	%g4, [%o0 + GUEST_STATE]
	SPINLOCK_EXIT(%g2)

	mov	GUEST_EXIT_MACH_EXIT, %o1
	call	c_guest_exit
	  nop

	mov	1, %g1
	SET_VCPU_STRUCT(%g1, %g2)	! force alignment trap
	ba,pt	%xcc, 5f
	  nop
4:
	! control domain - do a sir
	set	GUEST_STATE_RESETTING, %g4
	stuw	%g4, [%o0 + GUEST_STATE]
	SPINLOCK_EXIT(%g2)

	mov     GUEST_EXIT_MACH_SIR, %o1
        call    c_guest_exit
          nop

5:
	STRAND_POP(%g7, %g2)		! restore return address
	HVRET
6:
	/*
	 * The guest is already in the process of being
	 * stopped or started. Deschedule the current vcpu
	 * and send it off to wait for the xcall that will
	 * tell it what to do next.
	 */
	VCPU_STRUCT(%g1)
	VCPU2STRAND_STRUCT(%g1, %g3)
	!! %g1 current vcpu
	!! %g2 guest state lock
	!! %g3 current strand

	ldub	[%g1 + CPU_STRAND_SLOT], %g4
	mulx	%g4, SCHED_SLOT_SIZE, %g4
	add	%g3, STRAND_SLOT, %g5
	add	%g5, %g4, %g4
	set	SLOT_ACTION_NOP, %g3
	stx	%g3, [%g4 + SCHED_SLOT_ACTION]
	mov	1, %g3	! force alignment trap
	stx	%g3, [%g4 + SCHED_SLOT_ARG]

	SPINLOCK_EXIT(%g2)

	STRAND_POP(%g7, %g2)		! restore return address
	HVRET

	SET_SIZE(guest_exit)


/*
 * mach_exit
 *
 * arg0 exit code (%o0)
 * --
 * does not return
 */
	ENTRY(hcall_mach_exit)

	PRINT("hcall_mach_exit called\r\n")

	HVCALL(guest_exit)

        ba,a,pt   %xcc, start_work
          nop

	SET_SIZE(hcall_mach_exit)


/*
 * mach_sir
 *
 * In the world of SIR the domain is merely asking for a reset.
 * This can simply be a plain reboot/reset of the domain, or an
 * opportunity to trigger a delayed reconfigure.
 *
 * --
 * does not return
 */
	ENTRY_NP(hcall_mach_sir)
	PRINT("hcall_mach_sir called\r\n")

	/*
	 * Solaris/OS reboot triggers an SIR
	 *
	 * We cannot request a power cycle from the SP here because
	 * we will lose the current configuration of the domain(s)
	 * consequently all SIR actions must result in a simple HV
	 * reset of the domain - the SP/vBSC is never involved.
	 *
	 * Note: For LDoms 1.0 we decommit the hot reset of the last
	 * guest and instead request a power cycle of the system. The
	 * presumption is that the last guest is the control domain
	 * as will be recommended by best practices.
	 */

#ifdef LDOMS_1_0_ERRATUM_POWER_CYCLE
	/*
	 * Loop over all guests and check if there is more
	 * than one guest configured in the system. If not,
	 * call vbsc_guest_sir.
	 */
	ROOT_STRUCT(%g1)
	GUEST_STRUCT(%g5)			! this guest
	ldx	[%g1 + CONFIG_GUESTS], %g1	! &guest[0]
	set	NGUESTS - 1, %g3		! guest loop counter
	set	GUEST_SIZE, %g2
1:
	cmp	%g1, %g5
	beq	%xcc, 2f			! skip this guest
	  nop
	lduw	[%g1 + GUEST_STATE], %g4
	cmp	%g4, GUEST_STATE_UNCONFIGURED	! if another guest, and if
	bne,pt	%xcc, 3f			! it is not unconfigured
	  nop					! do not poweroff
2:
	add	%g1, %g2, %g1			! guest++
	brnz,pt	%g3, 1b
	 dec	%g3				! nguests--

	/*
	 * If this is the last guest and there is a delayed reconfig in
	 * progress, do not poweroff
	 */
	ROOT_STRUCT(%g1)
	ldx	[%g1 + CONFIG_DEL_RECONF_GID], %g1
	ldx	[%g5 + GUEST_GID], %g2
	cmp	%g1, %g2
	beq,pn	%xcc, 3f
	nop

	PRINT("\tfor the last guest ...\r\n")
#ifdef CONFIG_VBSC_SVC
        ba,pt   %xcc, vbsc_guest_sir
        nop
#else
        LEGION_EXIT(%o0)
#endif
3:
#endif /* LDOMS_1_0_ERRATUM_POWER_CYCLE */

        wrpr    %g0, 0, %gl
	wrpr    %g0, 0, %tl
        HVCALL(setup_c_environ)
        GUEST_STRUCT(%o0)
	!! %o0 current guest pointer

	add	%o0, GUEST_STATE_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g3, %g4)
	!! %g2 guest state lock

	! check the state of the guest
	lduw	[%o0 + GUEST_STATE], %g3
	cmp	%g3, GUEST_STATE_RESETTING
	be,pn	%xcc, 4f
	cmp	%g3, GUEST_STATE_EXITING
	be,pn	%xcc, 4f
	nop

	mov	GUEST_STATE_RESETTING, %g3
	stuw	%g3, [%o0 + GUEST_STATE]
	SPINLOCK_EXIT(%g2)

        mov     GUEST_EXIT_MACH_SIR, %o1
        call    c_guest_exit
          nop

        ba,a,pt %xcc, start_work
          nop
4:
	/*
	 * The guest is already in the process of being
	 * stopped or started. Deschedule the current vcpu
	 * and send it off to wait for the xcall that will
	 * tell it what to do next.
	 */
	VCPU_STRUCT(%g1)
	VCPU2STRAND_STRUCT(%g1, %g3)
	!! %g1 current vcpu
	!! %g2 guest state lock
	!! %g3 current strand

	ldub	[%g1 + CPU_STRAND_SLOT], %g4
	mulx	%g4, SCHED_SLOT_SIZE, %g4
	add	%g3, STRAND_SLOT, %g5
	add	%g5, %g4, %g4
	set	SLOT_ACTION_NOP, %g3
	stx	%g3, [%g4 + SCHED_SLOT_ACTION]
	mov	1, %g3	! force alignment trap
	stx	%g3, [%g4 + SCHED_SLOT_ARG]

	SPINLOCK_EXIT(%g2)

        ba,a,pt %xcc, start_work
        nop

	SET_SIZE(hcall_mach_sir)


/*
 * mach_desc
 *
 * arg0 buffer (%o0)
 * arg1 len (%o1)
 * --
 * ret0 status (%o0)
 * ret1 actual len (%o1) (for EOK or EINVAL)
 *
 * guest uses this sequence to get the machine description:
 *	mach_desc(0, 0)
 *	if %o0 != EINVAL, failed
 *	len = %o1
 *	buf = allocate(len)
 *	mach_desc(buf, len)
 *	if %o0 != EOK, failed
 * so the EINVAL case is the first error check
 */
	ENTRY_NP(hcall_mach_desc)
	VCPU_GUEST_STRUCT(%g1, %g6)
	set	GUEST_MD_SIZE, %g7
	ldx	[%g6 + %g7], %g3
	! paranoia for xcopy - should already be 16byte multiple
	add	%g3, MACH_DESC_ALIGNMENT - 1, %g3
	andn	%g3, MACH_DESC_ALIGNMENT - 1, %g3
	cmp	%g3, %o1
	bgu,pn	%xcc, herr_inval
	mov	%g3, %o1	! return PD size for success or EINVAL

	btst	MACH_DESC_ALIGNMENT - 1, %o0
	bnz,pn	%xcc, herr_badalign
	  nop

	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o0, %g3, herr_noraddr, %g2, %g4)

	! %g3 = size of pd
	! %g4 = pa of guest buffer
	/* xcopy(pd, buf[%o0], size[%g3]) */
	set	GUEST_MD_PA, %g7
	ldx	[%g6 + %g7], %g1
	mov	%g4, %g2
	HVCALL(xcopy)

	! %o1 was set above to the guest's PD size
	HCALL_RET(EOK)
	SET_SIZE(hcall_mach_desc)


/*
 * tod_get - Time-of-day get
 *
 * no arguments
 * --
 * ret0 status (%o0)
 * ret1 tod (%o1)
 */
	ENTRY_NP(hcall_tod_get)
	GUEST_STRUCT(%g1)
	ROOT_STRUCT(%g2)
	! %g1 guestp
	! %g2 configp
	ldx	[%g1 + GUEST_TOD_OFFSET], %g3
	ldx	[%g2 + CONFIG_TOD], %g4
	ldx	[%g2 + CONFIG_TODFREQUENCY], %g5
	! %g3 guest's tod offset
	! %g4 tod
	! %g5 tod frequency
#ifdef CONFIG_STATICTOD
	! If the PD says no TOD then start with 0
	brz,pn	%g4, hret_ok
	  clr	%o1
#else
	brz,pn	%g4, herr_notsupported
	  clr	%o1		! In case error status not checked
#endif

	ldx	[%g4], %o1
	udivx	%o1, %g5, %o1	! Convert to seconds
	add	%o1, %g3, %o1	! Add partition's tod offset
	HCALL_RET(EOK)
	SET_SIZE(hcall_tod_get)

/*
 * tod_set - Time-of-day set
 *
 * arg0 tod (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_tod_set)
	ROOT_STRUCT(%g1)		! %g1 = configp
	ldx	[%g1 + CONFIG_TOD], %g2	! %g2 = address of TOD counter

#ifdef CONFIG_STATICTOD
	/*
	 * If no hardware TOD then tod-get returned 0 the first time
	 * and will continue to do so.
	 */
	brz,pn	%g2, hret_ok
	  nop
#else
	brz,pn	%g2, herr_notsupported
	  nop
#endif

	GUEST_STRUCT(%g6)		! %g6 = guestp

	! acquire the guest's asynchronous lock
	set	GUEST_ASYNC_LOCK, %g5
	add	%g6, %g5, %g7
	SPINLOCK_ENTER(%g7, %g3, %g5)

	! compare new tod with current
	ldx	[%g1 + CONFIG_TODFREQUENCY], %g5
	ldx	[%g2], %g4		! %g4 = system tod
	udivx	%g4, %g5, %g4		! convert to seconds
	sub	%o0, %g4, %g4		! %g4 = new delta
	ldx	[%g6 + GUEST_TOD_OFFSET], %g3 ! current delta
	cmp	%g4, %g3		! check if tod changed
	beq,pn	%xcc, 1f
	  nop

	! tod has changed

	stx	%g4, [%g6 + GUEST_TOD_OFFSET] ! store new tod

	! check if async notification for tod is busy or not
	set	GUEST_ASYNC_BUSY, %g5
	add	%g6, %g5, %g3		! %g3 = base of busy flags array
	ldub	[%g3 + ENUM_HVctl_info_guest_tod], %g1
	brnz,pn	%g1, 1f
	! not busy, set busy flag and send asynchronous notification
	  mov	1, %g1
	stub	%g1, [%g3 + ENUM_HVctl_info_guest_tod]
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
	set	ENUM_HVctl_info_guest_tod, %g5
	stuw	%g5, [%g3 + HVCTL_RES_STATUS_INFOID]	! info id 
	! code field is initialized to zero in init_guest() and never changed
	! fill in the info specific data, i.e. the tod
#if	(HVCTL_RES_STATUS_DATA & 0x7) != 0
#error	data field in hvctl_res_status struct needs to be 8 byte aligned
#endif
	stx	%g4, [%g3 + HVCTL_RES_STATUS_DATA + 0 /* aschk ignore */]
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
	add	%g6, %g5, %g7
	SPINLOCK_EXIT(%g7)

#ifdef CONFIG_VBSC_SVC
	/*
	 * Send the new offset to vbsc on control domain only.
	 */
	GUEST_STRUCT(%g1)
	CTRL_DOMAIN(%g2, %g3, %g4)
	cmp	%g1, %g2		! is this the control domain ?
	bne,pn	%xcc, 1f
	nop
	HVCALL(vbsc_guest_tod_offset)
1:
#endif
	PRINT("Warning TOD has been set\r\n")
	HCALL_RET(EOK)
	SET_SIZE(hcall_tod_set)


/*
 * mmu_enable
 *
 * arg0 enable (%o0)
 * arg1 return address (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_mmu_enable)
	/*
	 * Check requested return address for instruction
	 * alignment
	 */
	btst	(INSTRUCTION_ALIGNMENT - 1), %o1
	bnz,pn	%xcc, herr_badalign
	nop

	ldxa	[%g0]ASI_LSUCR, %g1
	set	(LSUCR_DM | LSUCR_IM), %g2
	! %g1 = current lsucr value
	! %g2 = mmu enable mask

	brz,pn	%o0, 1f		! enable or disable?
	btst	%g1, %g2	! ccr indicates current status

	/*
	 * Trying to enable
	 *
	 * The return address will be virtual and we cannot
	 * check its range, the alignment has already been
	 * checked.
	 */
	bnz,pn	%xcc, herr_inval ! it's already enabled
	or	%g1, %g2, %g1	! enable MMU

	ba,pt	%xcc, 2f
	nop

1:
	/*
	 * Trying to disable
	 *
	 * The return address is a real address so we check
	 * its range, the alignment has already been checked.
	 */
	bz,pn	%xcc, herr_inval ! it's already disabled
	andn	%g1, %g2, %g1	! disable MMU

	/* Check RA range */
	GUEST_STRUCT(%g3)
	RA2PA_RANGE_CONV(%g3, %o1, INSTRUCTION_SIZE, herr_noraddr, %g4, %g5)

2:
	wrpr	%o1, %tnpc
	stxa	%g1, [%g0]ASI_LSUCR
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_enable)


/*
 * mmu_fault_area_conf
 *
 * arg0 raddr (%o0)
 * --
 * ret0 status (%o0)
 * ret1 oldraddr (%o1)
 */
	ENTRY_NP(hcall_mmu_fault_area_conf)
	btst	(MMU_FAULT_AREA_ALIGNMENT - 1), %o0	! check alignment
	bnz,pn	%xcc, herr_badalign
	VCPU_GUEST_STRUCT(%g1, %g4)
	brz,a,pn %o0, 1f
	  mov	0, %g2

	RA2PA_RANGE_CONV(%g4, %o0, MMU_FAULT_AREA_SIZE, herr_noraddr, %g3, %g2)
1:
	ldx	[%g1 + CPU_MMU_AREA_RA], %o1
	stx	%o0, [%g1 + CPU_MMU_AREA_RA]
	stx	%g2, [%g1 + CPU_MMU_AREA]

	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_fault_area_conf)

/*
 * mmu_fault_area_info
 *
 * --
 * ret0 status (%o0)
 * ret1 fault area raddr (%o1)
 */
	ENTRY_NP(hcall_mmu_fault_area_info)
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_MMU_AREA_RA], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_mmu_fault_area_info)


/*
 * cpu_qconf
 *
 * arg0 queue (%o0)
 * arg1 base raddr (%o1)
 * arg2 size (#entries, not #bytes) (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_qconf)
	sllx	%o2, Q_EL_SIZE_SHIFT, %g4	! convert #entries to bytes
	VCPU_STRUCT(%g1)

	! size of 0 unconfigures queue
	brnz,pt	%o2, 1f
	nop

	/*
	 * Set the stored configuration to relatively safe values
	 * when un-initializing the queue
	 */
	mov	%g0, %g2
	mov	%g0, %o1
	ba,pt	%xcc, 2f
	mov	%g0, %g4

1:
	cmp	%o2, MIN_QUEUE_ENTRIES
	blu,pn	%xcc, herr_inval
	.empty

	setx	MAX_QUEUE_ENTRIES, %g3, %g2
	cmp	%o2, %g2
	bgu,pn	%xcc, herr_inval
	.empty

	! check that size is a power of two
	sub	%o2, 1, %g2
	andcc	%o2, %g2, %g0
	bnz,pn	%xcc, herr_inval
	.empty

	! Check base raddr alignment
	sub	%g4, 1, %g2	! size in bytes to mask
	btst	%o1, %g2
	bnz,pn	%xcc, herr_badalign
	.empty

	VCPU2GUEST_STRUCT(%g1, %g6)
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o1, %g4, herr_noraddr, %g3, %g2)

	! %g2 - queue paddr
	! %g4 - queue size (#bytes)
	dec	%g4
	! %g4 - queue mask

2:
	cmp	%o0, CPU_MONDO_QUEUE
	be,pn	%xcc, qconf_cpuq
	cmp	%o0, DEV_MONDO_QUEUE
	be,pn	%xcc, qconf_devq
	cmp	%o0, ERROR_RESUMABLE_QUEUE
	be,pn	%xcc, qconf_errrq
	cmp	%o0, ERROR_NONRESUMABLE_QUEUE
	bne,pn	%xcc, herr_inval
	nop

qconf_errnrq:
	stx	%g2, [%g1 + CPU_ERRQNR_BASE]
	stx	%o1, [%g1 + CPU_ERRQNR_BASE_RA]
	stx	%o2, [%g1 + CPU_ERRQNR_SIZE]
	stx	%g4, [%g1 + CPU_ERRQNR_MASK]
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	ba,pt	%xcc, 4f
	stxa	%g0, [%g3]ASI_QUEUE

qconf_errrq:
	stx	%g2, [%g1 + CPU_ERRQR_BASE]
	stx	%o1, [%g1 + CPU_ERRQR_BASE_RA]
	stx	%o2, [%g1 + CPU_ERRQR_SIZE]
	stx	%g4, [%g1 + CPU_ERRQR_MASK]
	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	ba,pt	%xcc, 4f
	stxa	%g0, [%g3]ASI_QUEUE

qconf_devq:
	stx	%g2, [%g1 + CPU_DEVQ_BASE]
	stx	%o1, [%g1 + CPU_DEVQ_BASE_RA]
	stx	%o2, [%g1 + CPU_DEVQ_SIZE]
	stx	%g4, [%g1 + CPU_DEVQ_MASK]
	stx	%g0, [%g1 + CPU_DEVQ_SHDW_TAIL]
	mov	DEV_MONDO_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_TAIL, %g3
	ba,pt	%xcc, 4f
	stxa	%g0, [%g3]ASI_QUEUE

qconf_cpuq:
	stx	%g2, [%g1 + CPU_CPUQ_BASE]
	stx	%o1, [%g1 + CPU_CPUQ_BASE_RA]
	stx	%o2, [%g1 + CPU_CPUQ_SIZE]
	stx	%g4, [%g1 + CPU_CPUQ_MASK]
	mov	CPU_MONDO_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	CPU_MONDO_QUEUE_TAIL, %g3
	stxa	%g0, [%g3]ASI_QUEUE

4:
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_qconf)


/*
 * cpu_qinfo
 *
 * arg0 queue (%o0)
 * --
 * ret0 status (%o0)
 * ret1 base raddr (%o1)
 * ret2 size (#entries) (%o2)
 */
	ENTRY_NP(hcall_cpu_qinfo)
	VCPU_STRUCT(%g1)

	cmp	%o0, CPU_MONDO_QUEUE
	be,pn	%xcc, qinfo_cpuq
	cmp	%o0, DEV_MONDO_QUEUE
	be,pn	%xcc, qinfo_devq
	cmp	%o0, ERROR_RESUMABLE_QUEUE
	be,pn	%xcc, qinfo_errrq
	cmp	%o0, ERROR_NONRESUMABLE_QUEUE
	bne,pn	%xcc, herr_inval
	nop
qinfo_errnrq:
	ldx	[%g1 + CPU_ERRQNR_BASE_RA], %o1
	ba,pt	%xcc, 1f
	ldx	[%g1 + CPU_ERRQNR_SIZE], %o2

qinfo_errrq:
	ldx	[%g1 + CPU_ERRQR_BASE_RA], %o1
	ba,pt	%xcc, 1f
	ldx	[%g1 + CPU_ERRQR_SIZE], %o2

qinfo_devq:
	ldx	[%g1 + CPU_DEVQ_BASE_RA], %o1
	ba,pt	%xcc, 1f
	ldx	[%g1 + CPU_DEVQ_SIZE], %o2

qinfo_cpuq:
	ldx	[%g1 + CPU_CPUQ_BASE_RA], %o1
	ldx	[%g1 + CPU_CPUQ_SIZE], %o2

1:
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_qinfo)


/*
 * cpu_start
 *
 * arg0 cpu (%o0)
 * arg1 pc (%o1)
 * arg2 rtba (%o2)
 * arg3 arg (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_start)
	VCPU_GUEST_STRUCT(%g6, %g7)
	! %g6 = CPU
	! %g7 = guest

	cmp	%o0, NVCPUS
	bgeu,pn	%xcc, herr_nocpu
	nop

	! Check pc (real) and tba (real) for validity
	RA2PA_RANGE_CONV(%g7, %o1, INSTRUCTION_SIZE, herr_noraddr, %g1, %g2)
	RA2PA_RANGE_CONV(%g7, %o2, REAL_TRAPTABLE_SIZE, herr_noraddr, %g1, %g2)
	btst	(INSTRUCTION_ALIGNMENT - 1), %o1	! Check pc alignment
	bnz,pn	%xcc, herr_badalign
	set	REAL_TRAPTABLE_SIZE - 1, %g1
	btst	%o2, %g1
	bnz,pn	%xcc, herr_badalign
	nop

	! Validate requested cpu
	sllx	%o0, 3, %g1
	add	%g7, %g1, %g1
	add	%g1, GUEST_VCPUS, %g1
	ldx	[%g1], %g1
	brz,pn	%g1, herr_nocpu
	nop

	add	%g7, GUEST_STATE_LOCK, %g2
	SPINLOCK_ENTER(%g2, %g3, %g4)
	!! %g2 guest state lock

	lduw	[%g7 + GUEST_STATE], %g3
	cmp	%g3, GUEST_STATE_NORMAL
	bne,pn	%xcc, .start_wouldblock
	nop

	!! %g1 requested CPU struct

	ldx	[%g1 + CPU_STATUS], %g3
	cmp	%g3, CPU_STATE_STOPPED
	bne,pn	%xcc, .start_inval
	nop

	set	CPU_STATE_STARTING, %g3
	stx	%g3, [%g1 + CPU_STATUS]
	SPINLOCK_EXIT(%g2)

	/*
	 * OK we setup the target vcpu before it gets
	 * launched, so we put the arguments into the
	 * appropriate locations.
	 * %g1 - our target cpu
	 */

	stx	%o1, [%g1 + CPU_START_PC]
	stx	%o2, [%g1 + CPU_RTBA]
	stx	%o3, [%g1 + CPU_START_ARG]	/*FIXME: direct to reg ? */

	/* force a launch by done - this should be an assert */

	set	CPU_LAUNCH_WITH_RETRY, %g2
	stub	%g0, [%g1 + %g2]	! false

	/*
	 * The setup arguments for the virtual cpu
	 * should have been placed in its vcpu struct
	 * so we only need to identify which vcpu to schedule
	 * the strand we're sending the mondo to.
	 */

	STRAND_STRUCT(%g4)
	add	%g4, STRAND_HV_TXMONDO, %g2

	mov	HXCMD_SCHED_VCPU, %g3		! mondop->cmd = SCHED_VCPU
	stx	%g3, [%g2 + HVM_CMD]
	stx	%g4, [%g2 + HVM_FROM_STRANDP]	! mondop->from_strandp = me
	add	%g2, HVM_ARGS, %g3
	stx	%g1, [%g3 + HVM_SCHED_VCPUP]	! mondop->pkt.sched.vcpup = vp

	ldx	[%g1 + CPU_STRAND], %g1		! shipit !
	HVCALL(hvmondo_send)

	HCALL_RET(EOK)

.start_wouldblock:
	!! %g2 guest state lock
	SPINLOCK_EXIT(%g2)
	ba,pt	%xcc, herr_wouldblock
	nop

.start_inval:
	!! %g2 guest state lock
	SPINLOCK_EXIT(%g2)
	ba,pt	%xcc, herr_inval
	nop

	SET_SIZE(hcall_cpu_start)


/*
 * cpu_stop
 *
 * arg0 cpu (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_stop)
	VCPU_GUEST_STRUCT(%g6, %g7)
	! %g6 = vcpup
	! %g7 = guestp

	cmp	%o0, NVCPUS
	bgeu,pn	%xcc, herr_nocpu
	nop

	/*
	 * This HV only runs 1 vcpu per strand, so the
	 * guest vcpu check is sufficient to ensure we're
	 * not stopping ourselves
	 */

	ldub	[%g6 + CPU_VID], %g1
	cmp	%o0, %g1
	be,pn	%xcc, herr_inval
	nop

	! Check current state of requested cpu
	sllx	%o0, 3, %g1
	mov	GUEST_VCPUS, %g2
	add	%g1, %g2, %g1	! %g1 = vcpus[n] offset
	ldx	[%g7 + %g1], %g1 ! %g1 = guest.vcpus[n]
	brz,pn	%g1, herr_nocpu
	nop
	!! %g1 targeted vcpu cpu struct
	!! %g6 vcpup
	!! %g7 guestp

	/*
	 * Prevent stopping a vcpu while the guest
	 * is being stopped.
	 */
	add	%g7, GUEST_STATE_LOCK, %g4
	SPINLOCK_ENTER(%g4, %g5, %g3)
	!! %g4 guest state lock

	lduw	[%g7 + GUEST_STATE], %g3
	cmp	%g3, GUEST_STATE_EXITING
	be,pn	%xcc, .stop_wouldblock
	nop

	/*
	 * Check if the current vcpu is stopping.
	 * Returning in that case prevents a deadlock
	 * if the target vcpu is trying to stop the
	 * current vcpu.
	 */
	ldx	[%g6 + CPU_STATUS], %g3
	cmp	%g3, CPU_STATE_STOPPING
	be,pn	%xcc, .stop_wouldblock
	nop

	/*
	 * Examine the target vcpu state. It must be in
	 * the running or suspended state in order to
	 * proceed. Return EWOULDBLOCK if the CPU is in
	 * transition.
	 */
	ldx	[%g1 + CPU_STATUS], %g3
	cmp	%g3, CPU_STATE_INVALID
	be,pn	%xcc, .stop_inval
	cmp	%g3, CPU_STATE_STOPPED
	be,pn	%xcc, .stop_inval
	cmp	%g3, CPU_STATE_ERROR
	be,pn	%xcc, .stop_inval
	cmp	%g3, CPU_STATE_STOPPING
	be,pn	%xcc, .stop_wouldblock
	cmp	%g3, CPU_STATE_STARTING
	be,pn	%xcc, .stop_wouldblock
	nop

	! mark the vcpu in transition
	set	CPU_STATE_STOPPING, %g3
	stx	%g3, [%g1 + CPU_STATUS]
	SPINLOCK_EXIT(%g4)

	/*
	 * Send a command to the strand running the vcpu
	 * to clean up and stop the vcpu.
	 */
	STRAND_STRUCT(%g4)
	add	%g4, STRAND_HV_TXMONDO, %g2

	mov	HXCMD_STOP_VCPU, %g3
	stx	%g3, [%g2 + HVM_CMD]
	stx	%g4, [%g2 + HVM_FROM_STRANDP]
	add	%g2, HVM_ARGS, %g3
	stx	%g1, [%g3 + HVM_SCHED_VCPUP]

	STRAND_PUSH(%g1, %g3, %g4)		! remember the cpu

	ldx	[%g1 + CPU_STRAND], %g1		! shipit !
	HVCALL(hvmondo_send)

	STRAND_POP(%g1, %g2)			! pop the vcpup

	/* FIXME: This should time out in case we get no response */
1:
	membar	#Sync
	ldx	[%g1 + CPU_STATUS], %g2
	cmp	%g2, CPU_STATE_STOPPING
	be,pt	%xcc, 1b
	nop

	HCALL_RET(EOK)	 

.stop_wouldblock:
	!! %g4 guest state lock
	SPINLOCK_EXIT(%g4)
	ba,pt	%xcc, herr_wouldblock
	nop

.stop_inval:
	!! %g4 guest state lock
	SPINLOCK_EXIT(%g4)
	ba,pt	%xcc, herr_inval
	nop

	SET_SIZE(hcall_cpu_stop)


/*
 * cpu_get_state
 *
 * arg0 cpu (%o0)
 * --
 * ret0 status (%o0)
 * ret1 state (%o1)
 */
	ENTRY_NP(hcall_cpu_get_state)
	GUEST_STRUCT(%g1)
	VCPUID2CPUP(%g1, %o0, %g2, herr_nocpu, %g3)
	!! %g2 target vcpup

	ldx	[%g2 + CPU_STATUS], %o1

	/*
	 * Convert the transitional CPU states to one
	 * of the public states defined by the HV API.
	 */
	cmp	%o1, CPU_STATE_STOPPING
	be,a,pn	%xcc, 1f
	  mov	CPU_STATE_RUNNING, %o1

	cmp	%o1, CPU_STATE_STARTING
	be,a,pn	%xcc, 1f
	  mov	CPU_STATE_STOPPED, %o1

	! ASSERT(%o1 != CPU_STATE_INVALID)
	cmp	%o1, CPU_STATE_LAST_PUBLIC
	movgu	%xcc, CPU_STATE_ERROR, %o1	! Any non-API state is ERROR
1:

	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_get_state)


/*
 * mem_scrub
 *
 * arg0 real address (%o0)
 * arg1 length       (%o1)
 * --
 * ret0 status (%o0)
 *   EOK       : success or partial success
 *   ENORADDR  : invalid (bad) address
 *   EBADALIGN : bad alignment
 * ret1 length scrubbed (%o1)
 */
	ENTRY_NP(hcall_mem_scrub)
	brz,pn	%o1, herr_inval			! length 0 invalid
	or	%o0, %o1, %g1			! address and length
	btst	L2_LINE_SIZE - 1, %g1		!    aligned?
	bnz,pn	%xcc, herr_badalign		! no: error
	  nop

        VCPU_GUEST_STRUCT(%g6, %g5)

	/* Check input arguments with guest map: error ret: r0=ENORADDR */
	RA2PA_RANGE_CONV_UNK_SIZE(%g5, %o0, %o1, herr_noraddr, %g1, %g2)
	mov	%g2, %o0

	/* Get Max length: */
	VCPU2ROOT_STRUCT(%g6, %g2)
	ldx	[%g2 + CONFIG_MEMSCRUB_MAX], %g5 ! limit (# cache lines)

	/* Compute max # lines: */
	srlx	%o1, L2_LINE_SHIFT, %g2		! # input cache lines
	cmp	%g5, %g2			! g2 = min(inp, max)
	movlu	%xcc, %g5, %g2			!	..
	sllx	%g2, L2_LINE_SHIFT, %o1		! ret1 = count scrubbed

	/*
	 * This is the core of this function.
	 * All of the code before and after has been optimized to make this
	 *   and the most common path the fastest.
	 */
	wr	%g0, ASI_BLK_INIT_P, %asi
.ms_clear_mem:
	stxa	%g0, [%o0 + (0 * 8)]%asi
	stxa	%g0, [%o0 + (1 * 8)]%asi
	stxa	%g0, [%o0 + (2 * 8)]%asi
	stxa	%g0, [%o0 + (3 * 8)]%asi
	stxa	%g0, [%o0 + (4 * 8)]%asi
	stxa	%g0, [%o0 + (5 * 8)]%asi
	stxa	%g0, [%o0 + (6 * 8)]%asi
	stxa	%g0, [%o0 + (7 * 8)]%asi
	deccc	1, %g2
	bnz,pt	%xcc, .ms_clear_mem
	  inc	64, %o0
	HCALL_RET(EOK)				! ret0=status, ret1=count
	SET_SIZE(hcall_mem_scrub)


/*
 * mem_sync
 *
 * arg0 real address (%o0)
 * arg1 length       (%o1)
 * --
 * ret0 (%o0):
 *   EOK       : success, partial success
 *   ENORADDR  : bad address
 *   EBADALIGN : bad alignment
 * ret1 (%o1):
 *   length synced
 */
	ENTRY_NP(hcall_mem_sync)
	brz,pn	%o1, herr_inval		! len 0 not valid
	or	%o0, %o1, %g2
	set	MEMSYNC_ALIGNMENT - 1, %g3
	btst	%g3, %g2	! check for alignment of addr/len
	bnz,pn	%xcc, herr_badalign
	.empty

	VCPU_GUEST_STRUCT(%g5, %g6)
	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o0, %o1, herr_noraddr, %g1, %g2)
	mov	%g2, %o0

	! %o0 pa
	! %o1 length

	/*
	 * Clamp requested length at MEMSCRUB_MAX
	 */
	VCPU2ROOT_STRUCT(%g5, %g2)
	ldx	[%g2 + CONFIG_MEMSCRUB_MAX], %g3

	sllx	%g3, L2_LINE_SHIFT, %g3
	cmp	%o1, %g3
	movgu	%xcc, %g3, %o1
	! %o1 MIN(requested length, max length)

	/*
	 * Push cache lines to memory
	 */
	sub	%o1, L2_LINE_SIZE, %o5
	! %o5 loop counter
	add	%o0, %o5, %g1	! hoisted delay slot (see below)
1:
	ba	l2_flush_line
	  rd	%pc, %g7
	deccc	L2_LINE_SIZE, %o5 ! get to next line
	bgeu,pt	%xcc, 1b
	  add	%o0, %o5, %g1	! %g1 is pa to flush

	HCALL_RET(EOK)
	SET_SIZE(hcall_mem_sync)

/*
 * cpu_myid
 *
 * --
 * ret0 status (%o0)
 * ret1 mycpuid (%o1)
 */
	ENTRY_NP(hcall_cpu_myid)
	VCPU_STRUCT(%g1)
	ldub	[%g1 + CPU_VID], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_myid)

/*
 * dump_buf_update
 *
 * arg0 ra of dump buffer (%o0)
 * arg1 size of dump buffer (%o1)
 * --
 * ret0 status (%o0)
 * ret1 size on success (%o1), min size on EINVAL
 */
	ENTRY_NP(hcall_dump_buf_update)
	GUEST_STRUCT(%g1)

	/*
	 * XXX What locking is required between multiple strands
	 * XXX making simultaneous conf calls?
	 */

	/*
	 * Any error unconfigures any currently configured dump buf
	 * so set to unconfigured now to avoid special error exit code.
	 */
	set	GUEST_DUMPBUF_SIZE, %g4
	stx	%g0, [%g1 + %g4]
	set	GUEST_DUMPBUF_RA, %g4
	stx	%g0, [%g1 + %g4]
	set	GUEST_DUMPBUF_PA, %g4
	stx	%g0, [%g1 + %g4]

	! Size of 0 unconfigures the dump
	brz,pn	%o1, hret_ok
	nop

	set	DUMPBUF_MINSIZE, %g2
	cmp	%o1, %g2
	blu,a,pn %xcc, herr_inval
	  mov	%g2, %o1	! return min size on EINVAL

	! Check alignment
	btst	(DUMPBUF_ALIGNMENT - 1), %o0
	bnz,pn	%xcc, herr_badalign
	  nop

	RA2PA_RANGE_CONV_UNK_SIZE(%g1, %o0, %o1, herr_noraddr, %g3, %g2)
	! %g2 pa of dump buffer
	set	GUEST_DUMPBUF_SIZE, %g4
	stx	%o1, [%g1 + %g4]
	set	GUEST_DUMPBUF_RA, %g4
	stx	%o0, [%g1 + %g4]
	set	GUEST_DUMPBUF_PA, %g4
	stx	%g2, [%g1 + %g4]

	! XXX Need to put something in the buffer

	HCALL_RET(EOK)
	SET_SIZE(hcall_dump_buf_update)


/*
 * dump_buf_info
 *
 * --
 * ret0 status (%o0)
 * ret1 current dumpbuf ra (%o1)
 * ret2 current dumpbuf size (%o2)
 */
	ENTRY_NP(hcall_dump_buf_info)
	GUEST_STRUCT(%g1)
	set	GUEST_DUMPBUF_SIZE, %g4
	ldx	[%g1 + %g4], %o2
	set	GUEST_DUMPBUF_RA, %g4
	ldx	[%g1 + %g4], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_dump_buf_info)


/*
 * cpu_mondo_send
 *
 * arg0/1 cpulist (%o0/%o1)
 * arg2 ptr to 64-byte-aligned data to send (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY(hcall_cpu_mondo_send)
	btst	CPULIST_ALIGNMENT - 1, %o1
	bnz,pn	%xcc, herr_badalign
	btst	MONDO_DATA_ALIGNMENT - 1, %o2
	bnz,pn	%xcc, herr_badalign
	nop

	VCPU_GUEST_STRUCT(%g3, %g6)
	! %g3 cpup
	! %g6 guestp

	sllx	%o0, CPULIST_ENTRYSIZE_SHIFT, %g5

	RA2PA_RANGE_CONV_UNK_SIZE(%g6, %o1, %g5, herr_noraddr, %g7, %g1)
	RA2PA_RANGE_CONV(%g6, %o2, MONDO_DATA_SIZE, herr_noraddr, %g7, %g2)
	! %g1 cpulistpa
	! %g2 mondopa

	clr	%g4
	! %g4 true for EWOULDBLOCK
.cpu_mondo_continue:
	! %g1 pa of current entry in cpulist
	! %g3 cpup
	! %g4 ewouldblock flag
	! %o0 number of entries remaining in the list
	deccc	%o0
	blu,pn	%xcc, .cpu_mondo_break
	nop

	ldsh	[%g1], %g6
	! %g6 tcpuid
	cmp	%g6, CPULIST_ENTRYDONE
	be,a,pn	%xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1

	ldx	[%g3 + CPU_GUEST], %g5
	VCPUID2CPUP(%g5, %g6, %g6, herr_nocpu, %g7)
	! %g6 tcpup

	/* Sending to one's self is not allowed */
	cmp	%g3, %g6	! cpup <?> tcpup
	be,pn	%xcc, herr_inval
	nop

	IS_CPU_IN_ERROR(%g6, %g5)
	be,pn	%xcc, herr_cpuerror
	nop

	/*
	 * Check to see if the recipient's mailbox is available
	 */
	add	%g6, CPU_COMMAND, %g5
	mov	CPU_CMD_BUSY, %g7
	casxa	[%g5]ASI_P, %g0, %g7
	brz,pt	%g7, .cpu_mondo_send_one
	nop

	! %g1 pa of current entry in cpulist
	! %g2 is our mondo dont corrupt it.
	! %g3 cpup
	! %g4 ewouldblock flag
	! %g6 tcpup
	! %o0 number of entries remaining in the list

	/*
	 * If the mailbox isn't available then the queue could
	 * be full.  Poke the target cpu to check if the queue
	 * is still full since we cannot read its head/tail
	 * registers.
	 */
	inc	%g4		! ewouldblock flag

	cmp	%g7, CPU_CMD_GUESTMONDO_READY
	bne,a,pt %xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1 ! next entry in list

	/*
	 * Only send another if CPU_POKEDELAY ticks have elapsed since the
	 * last poke.
	 */
	ldx	[%g6 + CPU_CMD_LASTPOKE], %g7
	inc	CPU_POKEDELAY, %g7
	rd	%tick, %g5
	cmp	%g5, %g7
	blu,a,pt %xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1
	stx	%g5, [%g6 + CPU_CMD_LASTPOKE]

	/*
	 * Send the target cpu a dummy vecintr so it checks
	 * to see if the guest removed entries from the queue
	 */
	VCPU2STRAND_STRUCT(%g6, %g7)
	ldub	[%g7 + STRAND_ID], %g7
	sllx	%g7, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_XCALL, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W

	ba,pt	%xcc, .cpu_mondo_continue
	  inc	CPULIST_ENTRYSIZE, %g1 ! next entry in list

	/*
	 * Copy the mondo data into the target cpu's incoming buffer
	 */
.cpu_mondo_send_one:
	ldx	[%g2 + 0x00], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG0]
	ldx	[%g2 + 0x08], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG1]
	ldx	[%g2 + 0x10], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG2]
	ldx	[%g2 + 0x18], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG3]
	ldx	[%g2 + 0x20], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG4]
	ldx	[%g2 + 0x28], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG5]
	ldx	[%g2 + 0x30], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG6]
	ldx	[%g2 + 0x38], %g7
	stx	%g7, [%g6 + CPU_CMD_ARG7]
	membar	#Sync
	mov	CPU_CMD_GUESTMONDO_READY, %g7
	stx	%g7, [%g6 + CPU_COMMAND]

	/*
	 * Send a xcall vector interrupt to the target cpu
	 */
	VCPU2STRAND_STRUCT(%g6, %g7)
	ldub	[%g7 + STRAND_ID], %g7
	sllx	%g7, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_XCALL, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W

	mov	CPULIST_ENTRYDONE, %g7
	sth	%g7, [%g1]

	ba	.cpu_mondo_continue
	inc	CPULIST_ENTRYSIZE, %g1 ! next entry in list

.cpu_mondo_break:
	brnz,pn	%g4, herr_wouldblock	! If remaining then EAGAIN
	nop
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_mondo_send)


#define	TTRACE_RELOC_ADDR(addr, scr0, scr1)	 \
	setx	.+8, scr0, scr1			;\
	rd	%pc, scr0			;\
	sub	scr1, scr0, scr0		;\
	sub	addr, scr0, addr

/*
 * hcal_ttrace_buf_conf
 *
 * arg0 ra of traptrace buffer (%o0)
 * arg1 size of traptrace buffer in entries (%o1)
 * --
 * ret0 status (%o0)
 * ret1 minimum #entries on EINVAL, #entries on success (%o1)
 */
	ENTRY_NP(hcall_ttrace_buf_conf)
	VCPU_GUEST_STRUCT(%g1, %g2)

	/*
	 * Disable traptrace by restoring %htba to original traptable
	 * always do this first to make error returns easier.
	 */
	setx	htraptable, %g3, %g4
	TTRACE_RELOC_ADDR(%g4, %g3, %g5)
	wrhpr	%g4, %htba

	! Clear buffer description
	stx	%g0, [%g1 + CPU_TTRACEBUF_SIZE]	! size must be first
	stx	%g0, [%g1 + CPU_TTRACEBUF_PA]
	stx	%g0, [%g1 + CPU_TTRACEBUF_RA]

	/*
	 * nentries (arg1) > 0 configures the buffer
	 * nentries ==  0 disables traptrace and cleans up buffer config
	 */
	brz,pn	%o1, hret_ok
	nop

	! Check alignment
	btst	TTRACE_ALIGNMENT - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	! Check that #entries is >= TTRACE_MINIMUM_ENTRIES
	cmp	%o1, TTRACE_MINIMUM_ENTRIES
	blu,a,pn %xcc, herr_inval
	  mov	TTRACE_MINIMUM_ENTRIES, %o1

	sllx	%o1, TTRACE_RECORD_SZ_SHIFT, %g6 ! convert #entries to bytes

	RA2PA_RANGE_CONV_UNK_SIZE(%g2, %o0, %g6, herr_noraddr, %g4, %g3)
	! %g3 pa of traptrace buffer
	stx	%o0, [%g1 + CPU_TTRACEBUF_RA]
	stx	%g3, [%g1 + CPU_TTRACEBUF_PA]
	stx	%g6, [%g1 + CPU_TTRACEBUF_SIZE]	! size must be last

	! Initialize traptrace buffer header
	mov	TTRACE_RECORD_SIZE, %g2
	stx	%g2, [%g1 + CPU_TTRACE_OFFSET]
	stx	%g2, [%g3 + TTRACE_HEADER_OFFSET]
	stx	%g2, [%g3 + TTRACE_HEADER_LAST_OFF]
	! %o1 return is the same as that passed in
	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_buf_conf)


/*
 * ttrace_buf_info
 *
 * --
 * ret0 status (%o0)
 * ret1 current traptrace buf ra (%o1)
 * ret2 current traptrace buf size (%o2)
 */
	ENTRY_NP(hcall_ttrace_buf_info)
	VCPU_STRUCT(%g1)

	ldx	[%g1 + CPU_TTRACEBUF_RA], %o1
	ldx	[%g1 + CPU_TTRACEBUF_SIZE], %o2
	srlx	%o2, TTRACE_RECORD_SZ_SHIFT, %o2 ! convert bytes to #entries
	movrz	%o2, %g0, %o1	! ensure RA zero if size is zero

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_buf_info)


/*
 * ttrace_enable
 *
 * arg0 boolean: 0 = disable, non-zero = enable (%o0)
 * --
 * ret0 status (%o0)
 * ret1 previous enable state (0=disabled, 1=enabled) (%o1)
 */
	ENTRY_NP(hcall_ttrace_enable)
	setx	htraptracetable, %g1, %g2	! %g2 = reloc'd &htraptracetable
	TTRACE_RELOC_ADDR(%g2, %g1, %g3)

	setx	htraptable, %g1, %g3		! %g3 = reloc'd &htraptable
	TTRACE_RELOC_ADDR(%g3, %g1, %g4)

	mov	%g3, %g1			! %g1 = (%o0 ? %g3 : %g2)
	movrnz	%o0, %g2, %g1

	rdhpr	%htba, %g4			! %o1 = (%htba == %g2)
	mov	%g0, %o1
	cmp	%g4, %g2
	move	%xcc, 1, %o1

	/*
	 * Check that the guest has previously provided a buf for this cpu
	 * Check here since by now %o1 will be properly set
	 */
	VCPU_STRUCT(%g2)
	TTRACE_CHK_BUF(%g2, %g3, herr_inval)

	wrhpr	%g1, %htba

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_enable)


/*
 * ttrace_freeze
 *
 * arg0 boolean: 0 = disable, non-zero = enable (%o0)
 * --
 * ret0 status (%o0)
 * ret1 previous freeze state (0=disabled, 1=enabled) (%o1)
 */
	ENTRY_NP(hcall_ttrace_freeze)
	VCPU_GUEST_STRUCT(%g1, %g3)

	ldx	[%g1 + CPU_TTRACEBUF_SIZE], %g2
	brz,pn	%g2, herr_inval
	.empty

	movrnz	%o0, 1, %o0			! normalize to formal bool

	! race conditions for two CPUs updating this not harmful
	ldx	[%g3 + GUEST_TTRACE_FRZ], %o1	! current val for ret1
	stx	%o0, [%g3 + GUEST_TTRACE_FRZ]

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_freeze)


/*
 * ttrace_addentry
 *
 * arg0 lower 16 bits stored in TTRACE_ENTRY_TAG (%o0)
 * arg1 stored in TTRACE_ENTRY_F1 (%o1)
 * arg2 stored in TTRACE_ENTRY_F2 (%o2)
 * arg3 stored in TTRACE_ENTRY_F3 (%o3)
 * arg4 stored in TTRACE_ENTRY_F4 (%o4)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_ttrace_addentry)
	/*
	 * Check that the guest has perviously provided a buf for this cpu
	 * return EINVAL if not configured, ignore (EOK) if frozen
	 */
	TTRACE_PTR(%g3, %g2, herr_inval, hret_ok)

	rdpr	%tl, %g4			! %g4 holds current tl
	sub	%g4, 1, %g3			! %g3 holds tl of caller
	mov	%g3, %g1			! save for TL field fixup
	movrz	%g3, 1, %g3			! minimum is TL=1
	wrpr	%g3, %tl

	TTRACE_STATE(%g2, TTRACE_TYPE_GUEST, %g3, %g5)
	stb	%g1, [%g2 + TTRACE_ENTRY_TL]	! overwrite with calc'd TL

	wrpr	%g4, %tl			! restore trap level

	sth	%o0, [%g2 + TTRACE_ENTRY_TAG]
	stx	%o1, [%g2 + TTRACE_ENTRY_F1]
	stx	%o2, [%g2 + TTRACE_ENTRY_F2]
	stx	%o3, [%g2 + TTRACE_ENTRY_F3]
	stx	%o4, [%g2 + TTRACE_ENTRY_F4]

	TTRACE_NEXT(%g2, %g3, %g4, %g5)

	HCALL_RET(EOK)
	SET_SIZE(hcall_ttrace_addentry)


/*
 * cpu_set_rtba - set the current cpu's rtba
 *
 * arg0 rtba (%o0)
 * --
 * ret0 status (%o0)
 * ret1 previous rtba (%o1)
 */
	ENTRY_NP(hcall_cpu_set_rtba)
	VCPU_GUEST_STRUCT(%g1, %g2)
	! %g1 = cpup
	! %g2 = guestp

	! Return prior rtba value
	ldx	[%g1 + CPU_RTBA], %o1

	! Check rtba for validity
	RA2PA_RANGE_CONV(%g2, %o0, REAL_TRAPTABLE_SIZE, herr_noraddr, %g7, %g3)
	set	REAL_TRAPTABLE_SIZE - 1, %g3
	btst	%o0, %g3
	bnz,pn	%xcc, herr_badalign
	nop
	stx	%o0, [%g1 + CPU_RTBA]
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_set_rtba)


/*
 * cpu_get_rtba - return the current cpu's rtba
 *
 * --
 * ret0 status (%o0)
 * ret1 rtba (%o1)
 */
	ENTRY_NP(hcall_cpu_get_rtba)
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_RTBA], %o1
	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_get_rtba)


/*
 * hcall_set_watchdog - configure the guest's watchdog timer
 *
 * This implementation has a granularity of 1s.  Arguments are rounded up
 * to the nearest second.
 *
 * arg0 timeout in milliseconds (%o0)
 * --
 * ret0 status (%o0)
 * ret1 time remaining in milliseconds (%o1)
 */
	ENTRY_NP(hcall_set_watchdog)
	GUEST_STRUCT(%g2)
	set	GUEST_WATCHDOG + WATCHDOG_TICKS, %g3
	add	%g2, %g3, %g2

	/*
	 * Round up arg0, convert to seconds, and validate
	 */
	brz,pn	%o0, 1f
	  mov	0, %g1
	add	%o0, MSEC_PER_SEC - 1, %g1
	udivx	%g1, MSEC_PER_SEC, %g1
	set	WATCHDOG_MAX_TIMEOUT, %g3
	cmp	%g1, %g3
	bleu,pn	%xcc, 1f
	inc	%g1	/* take care of a heartbeat about to happen */

	ldx	[%g2], %o1
	ba,pt	%xcc, herr_inval ! return remaining time even for EINVAL
	mulx	%o1, MSEC_PER_SEC, %o1

1:
	/*
	 * Replace the current ticks with the new value, calculate
	 * the return value
	 */
	ATOMIC_SWAP_64(%g2, %g1, %g4, %g5)
	mulx	%g4, MSEC_PER_SEC, %o1

	HCALL_RET(EOK)
	SET_SIZE(hcall_set_watchdog)


#ifdef CONFIG_BRINGUP

/*
 * vdev_genintr - generate a virtual interrupt
 *
 * arg0 sysino (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vdev_genintr)
	GUEST_STRUCT(%g1)
	! %g1 = guestp
	VINO2DEVINST(%g1, %o0, %g2, herr_inval)
	cmp	%g2, DEVOPS_VDEV
	bne,pn	%xcc, herr_inval
	nop
	GUEST2VDEVSTATE(%g1, %g2)
	add	%g2, VDEV_STATE_MAPREG, %g2
	! %g2 = mapreg array
	and	%o0, VINTR_INO_MASK, %o0	! get INO bits
	mulx	%o0, MAPREG_SIZE, %g1
	add	%g2, %g1, %g1
	! %g1 = mapreg
	HVCALL(vdev_intr_generate)
	HCALL_RET(EOK)
	SET_SIZE(hcall_vdev_genintr)

#endif /* CONFIG_BRINGUP */

/*
 * cpu_yield
 *
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_cpu_yield)

	rd	%tick, %g6
	sllx	%g6, 1, %g6	! remove npt bit
	srax	%g6, 1, %g6	! sign extend for correct delta comp

	! store the start tick
	VCPU_STRUCT(%g1)
	stx	%g6, [%g1 + CPU_UTIL_YIELD_START]

	STRAND_PUSH(%g6, %g2, %g3)

	HVCALL(plat_halt_strand)

	STRAND_POP(%g2, %g3)
	!! %g2 = tick prior to strand de-activate

	rd	%tick, %g3
	sllx	%g3, 1, %g3	! remove npt bit
	srax	%g3, 1, %g3	! sign extend for correct delta comp
	sub	%g3, %g2, %g2
	!! %g2 = tick delta for yield time

	/*
	 * Add the tick delta to the total yielded cycles for this
	 * vcpu. The value of this counter is never reset as long
	 * as the vcpu is bound to a guest.
	 *
	 * As there is a 1:1 relationship between vcpus and physical
	 * strands, exclusive access to the vcpu struct can be assumed.
	 * If this relationship changes and this assumption becomes
	 * invalid, the code must be modified to ensure this counter
	 * is updated atomically.
	 */
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_UTIL_YIELD_COUNT], %g3
	add	%g3, %g2, %g3
	!! %g3 = updated yielded cycle count

	/*
	 * Clear the yield start variable just before updating the
	 * counter. This minimizes the window where the cycles from
	 * the current yield are not accounted for.
	 */
	stx	%g0, [%g1 + CPU_UTIL_YIELD_START]
	stx	%g3, [%g1 + CPU_UTIL_YIELD_COUNT]

	HCALL_RET(EOK)
	SET_SIZE(hcall_cpu_yield)
