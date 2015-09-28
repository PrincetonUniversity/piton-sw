/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: setup.s
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

	.ident	"@(#)setup.s	1.5	07/07/25 SMI"

	.file	"setup.s"

/*
 * Routines that configure the hypervisor
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hprivregs.h>
#include <asi.h>
#include <fpga.h>
#include <intr.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>

#include <guest.h>
#include <offsets.h>
#include <md.h>
#include <svc.h>
#include <vdev_intr.h>
#include <abort.h>
#include <vcpu.h>
#include <util.h>
#include <debug.h>
#include <error_asm.h>
#include <cmp.h>


#define	HVALLOC(root, size, ptr, tmp)		\
	ldx	[root + CONFIG_BRK], ptr	;\
	add	ptr, size, tmp			;\
	stx	tmp, [root + CONFIG_BRK]

#define	CPUID_2_MAUID(cpu, mau)		\
	srlx	cpu, CPUID_2_COREID_SHIFT, mau
#define	CPUID_2_CWQID(cpu, cwq)		\
	srlx	cpu, CPUID_2_COREID_SHIFT, cwq

#define	CONFIG	%i0
#define	GUESTS	%i1
#define	CPUS	%i2


#if defined(CONFIG_PIU)
/*
 * setup_piu: Initialize PIU
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%locals
 *	%outs
 *	%globals
 */
	ENTRY_NP(setup_piu)

	mov	%g7, %l7	/* save return address */
	PRINT("HV:setup_piu \r\n")
	/*
	 * Relocate PIU TSB base pointers
	 */
	ldx	[%i0 + CONFIG_RELOC], %o0
	setx	piu_dev, %o2, %o1
	sub	%o1, %o0, %o1
	ldx	[%o1 + PIU_COOKIE_IOTSB0], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + PIU_COOKIE_IOTSB0]
	ldx	[%o1 + PIU_COOKIE_IOTSB1], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + PIU_COOKIE_IOTSB1]

	/*
	 * Relocate PIU MSI EQ base pointers
	 */
	ldx	[%o1 + PIU_COOKIE_MSIEQBASE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + PIU_COOKIE_MSIEQBASE]

	/*
	 * Relocate PIU Virtual Interrupt pointer
	 */
	ldx	[%o1 + PIU_COOKIE_VIRTUAL_INTMAP], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + PIU_COOKIE_VIRTUAL_INTMAP]

	/*
	 * Relocate PIU MSI and ERR Cookies
	 */

	ldx	[%o1 + PIU_COOKIE_ERRCOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + PIU_COOKIE_ERRCOOKIE]
	ldx	[%o2 + PIU_ERR_COOKIE_PIU], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + PIU_ERR_COOKIE_PIU]

	ldx	[%o1 + PIU_COOKIE_MSICOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + PIU_COOKIE_MSICOOKIE]
	ldx	[%o2 + PIU_MSI_COOKIE_PIU], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + PIU_MSI_COOKIE_PIU]

	setx	piu_msi, %o2, %o1
	sub	%o1, %o0, %o1

	mov	PIU_NEQS, %o3
	add	%o1, PIU_MSI_COOKIE_EQ, %o2
0:
	ldx	[%o2 + PIU_MSIEQ_BASE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + PIU_MSIEQ_BASE]
	add	%o2, PIU_MSIEQ_SIZE, %o2
	subcc	%o3, 1, %o3
	bnz	0b
	nop

	ba	piu_init
	mov	%l7, %g7
	SET_SIZE(setup_piu)
#endif	/* CONFIG_PIU */

/*
 * dummy tsb for the hypervisor to use
 */
BSS_GLOBAL(dummytsb, DUMMYTSB_SIZE, DUMMYTSB_ALIGN)

/*
 * setup_ncu
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%locals
 */
	ENTRY_NP(setup_ncu)
	ldx	[CONFIG + CONFIG_INTRTGT], %g1
	setx	NCU_BASE, %g3, %g2
	!! %g1 = intrtgt CPUID array (8-bits per INT_MAN target)
	!! %g2 = NCU Base address

	/*
	 * setup the map registers for the SSI
	 */

	/* SSI Error interrupt */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev1 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_SSIERR, %g3 ! int_man.vecnum
	stx	%g3, [%g2 + INT_MAN + INT_MAN_DEV_OFF(NCUDEV_SSIERR)]

	/* SSI Interrupt */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev2 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_FPGA, %g3 ! int_man.vecnum
	stx	%g3, [%g2 + INT_MAN + INT_MAN_DEV_OFF(NCUDEV_SSI)]

	/* PIU Interrupt */
	setx	NCU_BASE + MONDO_INT_VEC, %g2, %g1
	mov	VECINTR_DEV, %g2
	stx	%g2, [%g1]

	setx	DEV_MONDO_INT + DEV_MONDO_INT_BUSY, %g2, %g1
	set	NSTRANDS * 8, %g3
	/* Clear the INT_BUSY bits */
1:	deccc	8, %g3
	bg,pt	%xcc, 1b
	stx	%g0, [%g1 + %g3]

	jmp	%g7 + 4
	nop
	SET_SIZE(setup_ncu)


#ifdef CONFIG_SVC /* { */

/*
 * c_svc_register() requires that we have these 2 null functions
 * declared here.
 */
/*
 * error_svc_rx
 *
 * %g1 callback cookie
 * %g2 svc pointer
 * %g7 return address
 */
        ENTRY(error_svc_rx)
	/*
	 * Done with this packet
	 */
	ld	[%g2 + SVC_CTRL_STATE], %g5
	andn	%g5, SVC_FLAGS_RI, %g5
	st	%g5, [%g2 + SVC_CTRL_STATE]	! clear RECV pending

        mov     %g7, %g6
	PRINT("error_svc_rx\r\n")
        mov	%g6, %g7

        jmp     %g7 + 4
        nop
        SET_SIZE(error_svc_rx)

/*
 * cn_svc_tx - error report transmission completion interrupt
 *
 * While sram was busy an other error may have occurred. In such case, we
 * increase the send pkt counter and mark such packet for delivery.
 * In this function, we check to see if there are any packets to be transmitted.
 *
 * We search in the following way:
 * Look at PIU jbi err buffer XXXX
 * Look at PIU pcie err buffer
 * For each cpu in NCPUS
 *   Look at CE err buffer
 *   Look at UE err buffer
 *
 * We only send a packet at a time, and in the previously described order.
 * Since we are running in the intr completion routing, the svc_internal_send
 * has already adquire the locks. For such reason, this routing needs to use
 * send_diag_buf_noblock.
 *
 * %g1 callback cookie
 * %g2 packet
 * %g7 return address
 */
        ENTRY(error_svc_tx)
	STRAND_PUSH(%g7, %g1, %g2)
#if 0
	PRINT("error_svc_tx\r\n")
#endif

	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_ROOT], %g1
	stx	%g0, [%g1 + CONFIG_SRAM_ERPT_BUF_INUSE] ! clear the inuse flag

	/*
	 * See if we need to send more packets
	 */
	ldx	[%g1 + CONFIG_ERRS_TO_SEND], %g2
	brz	%g2, 4f
	nop


	/* Now look at the cpu erpts */
	HVCALL(transmit_diag_reports)
4:
	! Pop return pc. Done
	STRAND_POP(%g7, %g1)
	HVRET
        SET_SIZE(error_svc_tx)

#endif /* } CONFIG_SVC */

/*
 * setup_niu:
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%globals, %locals
 */
	ENTRY_NP(setup_niu)
	mov	%g7, %l7	! save return address

	/*
	 * Relocate vector to logical device group table
	 */
	ldx	[%i0 + CONFIG_RELOC], %g1
	setx	niu_dev, %g3, %g2
	sub	%g2, %g1, %g2
	ldx	[%g2 + NIU_LDG2LDN_TABLE], %g3
	sub	%g3, %g1, %g3
	stx	%g3, [%g2 + NIU_LDG2LDN_TABLE]
	/*
	 * Relocate vector to logical device group table
	 */
	ldx	[%g2 + NIU_VEC2LDG_TABLE], %g3
	sub	%g3, %g1, %g3
	stx	%g3, [%g2 + NIU_VEC2LDG_TABLE]

	ba,pt	%xcc, niu_intr_init
	mov	%l7, %g7	! N.B: tail call
	/*NOTREACHED*/
	SET_SIZE(setup_niu)

#ifdef CONFIG_FPGA
	/*
	 * The FPGA interrupt output is an active-low level interrupt.
	 * The Niagara SSI interrupt input is falling-edge-triggered.
	 * We can lose an interrupt across a warm reset so workaround
	 * that by injecting a fake SSI interrupt at start-up time.
	*/
	ENTRY(fake_ssiirq)

        setx    INT_MAN_BASE, %g1, %g2
        ldx     [%g2 + INT_MAN + INT_MAN_DEV_OFF(NCUDEV_SSI)], %g1
        stxa    %g1, [%g0]ASI_INTR_UDB_W
	HVRET

	SET_SIZE(fake_ssiirq)

	ENTRY(setup_fpga_ldc)
	! clear the FPGA MASK registers
	setx	FPGA_LDCIN_BASE, %g6, %g1
	st	%g0, [%g1 + FPGA_LDC_MASK_REG]

	setx	FPGA_LDCOUT_BASE, %g6, %g1
	st	%g0, [%g1 + FPGA_LDC_MASK_REG]

	HVRET
	SET_SIZE(setup_fpga_ldc)
#endif
