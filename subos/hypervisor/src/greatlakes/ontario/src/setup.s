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

	.ident	"@(#)setup.s	1.50	07/05/29 SMI"

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

#include <config.h>
#include <guest.h>
#include <offsets.h>
#include <md.h>
#include <dram.h>
#include <cpu_errs.h>
#include <svc.h>
#include <vdev_intr.h>
#include <abort.h>
#include <util.h>
#include <debug.h>
#include <mmu.h>
#include <ldc.h>
#include <fire.h>

#define	HVALLOC(root, size, ptr, tmp)		\
	ldx	[root + CONFIG_BRK], ptr	;\
	add	ptr, size, tmp			;\
	stx	tmp, [root + CONFIG_BRK]

#define	STRANDID_2_MAUPID(cpu, mau)			\
	srlx	cpu, STRANDID_2_COREID_SHIFT, mau


#define	CONFIG	%i0
#define	GUESTS	%i1




#if defined(CONFIG_FIRE)
/*
 * setup_fire: Initialize Fire
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
	ENTRY_NP(setup_fire)

	mov	%g7, %l7	/* save return address */
	PRINT("HV:setup_fire\r\n")
	/*
	 * Relocate Fire TSB base pointers
	 */
	ldx	[%i0 + CONFIG_RELOC], %o0
	setx	fire_dev, %o2, %o1
	sub	%o1, %o0, %o1
	ldx	[%o1 + FIRE_COOKIE_IOTSB], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_IOTSB]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_IOTSB], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_IOTSB]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	/*
	 * Relocate Fire MSI EQ base pointers
	 */
	ldx	[%o1 + FIRE_COOKIE_MSIEQBASE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSIEQBASE]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_MSIEQBASE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSIEQBASE]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	/*
	 * Relocate Fire Virtual Interrupt pointer
	 */
	ldx	[%o1 + FIRE_COOKIE_VIRTUAL_INTMAP], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_VIRTUAL_INTMAP]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_VIRTUAL_INTMAP], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_VIRTUAL_INTMAP]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	/*
	 * Relocate Fire MSI and ERR Cookies
	 */

	ldx	[%o1 + FIRE_COOKIE_ERRCOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_ERRCOOKIE]
	ldx	[%o2 + FIRE_ERR_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_ERR_COOKIE_FIRE]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_ERRCOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_ERRCOOKIE]
	ldx	[%o2 + FIRE_ERR_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_ERR_COOKIE_FIRE]

	sub	%o1, FIRE_COOKIE_SIZE, %o1

	ldx	[%o1 + FIRE_COOKIE_MSICOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSICOOKIE]
	ldx	[%o2 + FIRE_MSI_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSI_COOKIE_FIRE]
	add	%o1, FIRE_COOKIE_SIZE, %o1
	ldx	[%o1 + FIRE_COOKIE_MSICOOKIE], %o2
	sub	%o2, %o0, %o2
	stx	%o2, [%o1 + FIRE_COOKIE_MSICOOKIE]
	ldx	[%o2 + FIRE_MSI_COOKIE_FIRE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSI_COOKIE_FIRE]

	setx	fire_msi, %o2, %o1
	sub	%o1, %o0, %o1

	mov	FIRE_NEQS, %o3
	add	%o1, FIRE_MSI_COOKIE_EQ, %o2
0:
	ldx	[%o2 + FIRE_MSIEQ_BASE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSIEQ_BASE]
	add	%o2, FIRE_MSIEQ_SIZE, %o2
	subcc	%o3, 1, %o3
	bnz	0b
	nop

	add	%o1, FIRE_MSI_COOKIE_SIZE, %o1

	mov	FIRE_NEQS, %o3
	add	%o1, FIRE_MSI_COOKIE_EQ, %o2
0:
	ldx	[%o2 + FIRE_MSIEQ_BASE], %o4
	sub	%o4, %o0, %o4
	stx	%o4, [%o2 + FIRE_MSIEQ_BASE]
	add	%o2, FIRE_MSIEQ_SIZE, %o2
	subcc	%o3, 1, %o3
	bnz	0b
	nop

	ba	fire_init
	mov	%l7, %g7
	SET_SIZE(setup_fire)
#endif


	/*
	 * The FPGA interrupt output is an active-low level interrupt.
	 * The Niagara SSI interrupt input is falling-edge-triggered.
	 * We can lose an interrupt across a warm reset so workaround
	 * that by injecting a fake SSI interrupt at start-up time.
	 */
#ifdef CONFIG_FPGA /* Don't touch fpga hardware if it isn't there */
	ENTRY_NP(fake_ssiirq)
	setx	IOBBASE, %o1, %o2
	ldx	[%o2 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSI)], %o1
	stx	%o1, [%o2 + INT_VEC_DIS]
	HVRET
	SET_SIZE(fake_ssiirq)
#endif /* CONFIG_FPGA */




/*
 * dummy tsb for the hypervisor to use
 */
BSS_GLOBAL(dummytsb, DUMMYTSB_SIZE, DUMMYTSB_ALIGN)


/*
 * setup_iob
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
	ENTRY_NP(setup_iob)
#ifdef CONFIG_FPGA
	ldx	[CONFIG + CONFIG_INTRTGT], %g1
	setx	IOBBASE, %g3, %g2
	! %g1 = intrtgt CPUID array (8-bits per INT_MAN target)
	! %g2 = IOB Base address

	/*
	 * Clear interrupts for both SSIERR and SSI
	 *
	 * PRM: "After setting the MASK bit, software needs to issue a
	 * read on the INT_CTL register to guarantee the masking write
	 * is completed."
	 */
	mov	INT_CTL_MASK, %g4
	stx	%g4, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)]
	ldx	[%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)], %g0
	stx	%g4, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSI)]
	ldx	[%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSI)], %g0

	/*
	 * setup the map registers for the SSI
	 */

	/* SSI Error interrupt */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev1 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_SSIERR, %g3 ! int_man.vecnum
	stx	%g3, [%g2 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSIERR)]

	/* SSI Interrupt */
	srl	%g1, INTRTGT_DEVSHIFT, %g1 ! get dev2 bits in bottom
	and	%g1, INTRTGT_CPUMASK, %g3
	sllx	%g3, INT_MAN_CPU_SHIFT, %g3 ! int_man.cpu
	or	%g3, VECINTR_FPGA, %g3 ! int_man.vecnum
	stx	%g3, [%g2 + INT_MAN + INT_MAN_DEV_OFF(IOBDEV_SSI)]
	stx	%g0, [%g2 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSI)]

#endif /* CONFIG_FPGA */

	/*
	 * Set J_INT_VEC to target all JBus interrupts to vec# VECINTR_DEV
	 */
	setx	IOBBASE + J_INT_VEC, %l2, %l1
	mov	VECINTR_DEV, %l2
	stx	%l2, [%l1]

	jmp	%g7 + 4
	nop
	SET_SIZE(setup_iob)


/*
 * JBI_TRANS_TIMEOUT_VALUE - number of JBus clocks transactions must be
 * completed in
 *
 * We need a JBus transaction timeout that's at least as long as Fire's
 * transaction timeout.  The Fire TLU CTO is currently set to 67.1ms.
 * 80ms seems like a fine value.
 *
 * This value is dependent on the vpci_fire.s fire_leaf_init_table entry
 * for the FIRE_PLC_TLU_CTB_TLR_TLU_CTL register.  Changes to either value
 * may require the other value to change as well.
 */
#define	JBI_TRANS_TIMEOUT_MS	80

#define	JBI_FREQUENCY		(200 MHZ)	/* assumed */
#define	JBI_NS_PER_CLOCK	(NS_PER_S / JBI_FREQUENCY)
#if JBI_NS_PER_CLOCK == 0
#error "Invalid JBI_FREQUENCY"
#endif
#define	JBI_TRANS_TIMEOUT_VALUE	\
	(JBI_TRANS_TIMEOUT_MS * MS_PER_NS / JBI_NS_PER_CLOCK)

/*
 * setup_jbi - configure JBI global settings
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
	ENTRY_NP(setup_jbi)
	/*
	 * The JBI transaction timeout (JBI_TRANS_TIMEOUT) must be at
	 * least as long as the Fire transaction timeout (TLU CTO).
	 */
	setx	JBI_TRANS_TIMEOUT, %g2, %g1
	set	JBI_TRANS_TIMEOUT_VALUE, %g2
	stx	%g2, [%g1]

	HVRET
	SET_SIZE(setup_jbi)


/*
 * Enable JBI error interrupts
 *
 * %g1 - errors to be enabled
 * %g2 - clear SSIERR mask (true/false)
 * %g3, %g4 - clobbered
 * %g7 return address
 */
	ENTRY(setup_jbi_err_interrupts)
#ifdef CONFIG_FPGA	/* { */
	/*
	 * Enable All JBUS errors which generate an SSI interrupt
	 */
	ENABLE_JBI_INTR_ERRS(%g1, %g3, %g4)

	/*
	 * Enable interrupts for SSIERR by clearing the MASK bit
	 */

	brz,a	%g2, 1f
	nop

	setx	IOBBASE, %g3, %g4
	stx	%g0, [%g4 + INT_CTL + INT_CTL_DEV_OFF(IOBDEV_SSIERR)]
1:
#endif /* } CONFIG_FPGA */
	HVRET
	SET_SIZE(setup_jbi_err_interrupts)

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
	ld      [%g2 + SVC_CTRL_STATE], %g5
	andn    %g5, SVC_FLAGS_RI, %g5
	st      %g5, [%g2 + SVC_CTRL_STATE]     ! clear RECV pending

	mov     %g7, %g6
	PRINT("error_svc_rx\r\n")
	mov     %g6, %g7

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
 * Look at fire A jbi err buffer
 * Look at fire A pcie err buffer
 * Look at fire B jbi err buffer
 * Look at fire B pcie err buffer
 * For each strand in NSTRANDS
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
	PRINT("error_svc_tx\r\n")

	VCPU_STRUCT(%g1)	/* FIXME: strand */
	ldx	[%g1 + CPU_ROOT], %g1	/* FIXME: CPU2ROOT */
	stx	%g0, [%g1 + CONFIG_SRAM_ERPT_BUF_INUSE] ! clear the inuse flag

	/*
	 * See if we need to send more packets
	 */
	ldx	[%g1 + CONFIG_ERRS_TO_SEND], %g2
	brz	%g2, 4f
	nop

	PRINT("NEED TO SEND ANOTHER PACKET\r\n")
#ifdef CONFIG_FIRE
	/*
	 * search vpci to see if we need to send errors
	 */

	/* Look at fire_a jbi */
	GUEST_STRUCT(%g1)
	mov	FIRE_A_AID, %g2
	DEVINST2INDEX(%g1, %g2, %g2, %g3, 4f)
	DEVINST2COOKIE(%g1, %g2, %g2, %g3, 4f)
	mov	%g2, %g1
	add	%g1, FIRE_COOKIE_JBC_ERPT, %g5
	add     %g5, PCI_UNSENT_PKT, %g2        ! %g2 needed at 2f
	ldsw    [%g5 + PCI_UNSENT_PKT], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	brnz	%g4, 2f
	nop

	/* Look at fire_a pcie */
	add	%g1, FIRE_COOKIE_PCIE_ERPT, %g1
	add     %g1, PCI_UNSENT_PKT, %g2        ! %g2 needed at 2f
	ldsw    [%g1 + PCI_UNSENT_PKT], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	brnz	%g4, 2f
	add	%g1, PCI_ERPT_U, %g1

	/* Look at fire_b jbc */
	GUEST_STRUCT(%g1)
	mov	FIRE_B_AID, %g2
	DEVINST2INDEX(%g1, %g2, %g2, %g3, 4f)
	DEVINST2COOKIE(%g1, %g2, %g2, %g3, 4f)
	mov	%g2, %g1
	add	%g1, FIRE_COOKIE_JBC_ERPT, %g5
	ldsw	[%g5 + PCI_UNSENT_PKT], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	cmp	%g4, %g0
	bnz	%xcc, 2f
	nop

	/* Look at fire_b pcie */
	add	%g1, FIRE_COOKIE_PCIE_ERPT, %g1
	ldsw	[%g1 + PCI_UNSENT_PKT], %g4
	mov	PCIERPT_SIZE - EPKTSIZE, %g3
	cmp	%g4, %g0
	bnz	%xcc, 2f
	add	%g1, PCI_ERPT_U, %g1
#endif /* CONFIG_FIRE */

	/* Now look at the strand erpts */

	STRAND_STRUCT(%g6)
	ldx	[%g6 + STRAND_CONFIGP], %g6
	ldx	[%g6 + CONFIG_STRANDS], %g6
	set	STRAND_SIZE * NSTRANDS, %g5
	add	%g6, %g5, %g5	! last cpu ptr

1:
	! Check in the CE err buf for marked pkt
	add	%g6, STRAND_CE_RPT + STRAND_UNSENT_PKT, %g2
	mov	EVBSC_SIZE, %g3
	ldx	[%g2], %g4
	cmp	%g0, %g4
	bnz	%xcc, 2f
	add	%g6, STRAND_CE_RPT + STRAND_VBSC_ERPT, %g1

	! Check in the UE err buf for marked pkt
	set	STRAND_UE_RPT + STRAND_UNSENT_PKT, %g2
	add	%g6, %g2, %g2
	ldx	[%g2], %g4
	set	STRAND_UE_RPT + STRAND_VBSC_ERPT, %g3
	add	%g6, %g3, %g1
	cmp	%g0, %g4
	bnz	%xcc, 2f
	mov	EVBSC_SIZE, %g3

	! %g6 = current strand ptr
3:
	set	STRAND_SIZE, %g4
	add	%g4, %g6, %g6
	cmp	%g6, %g5		! new ptr == last ptr?
	bl	%xcc, 1b
	nop

	ba	4f
	nop

2:
	PRINT("FOUND THE PACKAGE TO SEND\r\n")
	! We found it.  We have all the args in place, so just sent the pkt
	HVCALL(send_diag_erpt_nolock)

	! Mark as one less pkt to send
	STRAND_STRUCT(%g6)
	ldx	[%g6 + STRAND_CONFIGP], %g6		/* config data */
	add	%g6, CONFIG_ERRS_TO_SEND, %g6
	ldx	[%g6], %g1
0:	sub	%g1, 1, %g3
	casx	[%g6], %g1, %g3
	cmp	%g1, %g3
	bne,a,pn %xcc, 0b
	mov	%g3, %g1

4:
	! Pop return pc. Done
	STRAND_POP(%g7, %g1)
	HVRET
        SET_SIZE(error_svc_tx)

#endif /* CONFIG_SVC } */

/*
 * Clear memory sub-system and other error status registers
 * ready to start overall system
 *
 * %g2-%g5	clobbered
 * %g7 = return address
 */

	ENTRY(clear_error_status_registers)

	! clear the l2 esr regs
	! XXX need to log the nonzero error status
	set	(NO_L2_BANKS - 1), %g5		! bank select
2:
	setx	L2_ESR_BASE, %g2, %g4		! access the L2 csr
	sllx	%g5, L2_BANK_SHIFT, %g2
	or	%g4, %g2, %g4
	ldx	[%g4], %g3			! read status
	stx	%g3, [%g4]			! clear status (RW1C)
	subcc	%g5, 1, %g5
	bge	%xcc, 2b
	nop

	! clear the DRAM esr regs
	! XXX need to log the nonzero error status
	set	(NO_DRAM_BANKS - 1), %g5	! bank select
2:
	setx	DRAM_ESR_BASE, %g2, %g4		! access the dram csr
	sllx	%g5, DRAM_BANK_SHIFT, %g2
	or	%g4, %g2, %g4
	ldx	[%g4], %g3			! read status
	stx	%g3, [%g4]			! clear status (RW1C)
	subcc	%g5, 1, %g5
	bge	%xcc, 2b
	nop

	! clear CEs logged in SPARC ESR also
	setx	SPARC_CE_BITS, %g1, %g2
	stxa	%g2, [%g0]ASI_SPARC_ERR_STATUS

	! enable all errors, UEs should already be enabled
	mov	(CEEN | NCEEN), %g1
	stxa	%g1, [%g0]ASI_SPARC_ERR_EN

	! enable L2 errors
	mov	(CEEN | NCEEN), %g1
	mov	0, %g2
	BSET_L2_BANK_EEN(%g2, %g1, %g3, %g4)
	mov	1, %g2
	BSET_L2_BANK_EEN(%g2, %g1, %g3, %g4)
	mov	2, %g2
	BSET_L2_BANK_EEN(%g2, %g1, %g3, %g4)
	mov	3, %g2
	BSET_L2_BANK_EEN(%g2, %g1, %g3, %g4)

	HVRET

	SET_SIZE(clear_error_status_registers)



#ifdef RESETCONFIG_ENABLEHWSCRUBBERS	/* { */

/*
 * Configuration
 */
#define	DEFAULT_L2_SCRUBINTERVAL	0x100
#define	DEFAULT_DRAM_SCRUBFREQ		0xfff

/*
 * Helper macros which check if the scrubbers should be enabled, if so
 * they get enabled with the default scrub rates.
 */
#define	DRAM_SCRUB_ENABLE(dram_base, bank, reg1, reg2)			\
	.pushlocals							;\
	set	DRAM_CHANNEL_DISABLE_REG + ((bank) * DRAM_BANK_STEP), reg1 ;\
	ldx	[dram_base + reg1], reg1				;\
	brnz,pn	reg1, 1f						;\
	nop								;\
	set	DRAM_SCRUB_ENABLE_REG + ((bank) * DRAM_BANK_STEP), reg1	;\
	mov	DEFAULT_DRAM_SCRUBFREQ, reg2				;\
	stx	reg2, [dram_base + reg1]				;\
	set	DRAM_SCRUB_ENABLE_REG + ((bank) * DRAM_BANK_STEP), reg1	;\
	mov	DRAM_SCRUB_ENABLE_REG_ENAB, reg2			;\
	stx	reg2, [dram_base + reg1]				;\
    1: 	.poplocals

#define	L2_SCRUB_ENABLE(l2cr_base, bank, reg1, reg2)			\
	.pushlocals							;\
	set	bank << L2_BANK_SHIFT, reg1				;\
	ldx	[l2cr_base + reg1], reg2				;\
	btst	L2_SCRUBENABLE, reg2					;\
	bnz,pt	%xcc, 1f						;\
	nop								;\
	set	L2_SCRUBINTERVAL_MASK, reg1				;\
	andn	reg2, reg1, reg2					;\
	set	DEFAULT_L2_SCRUBINTERVAL, reg1				;\
	sllx	reg1, L2_SCRUBINTERVAL_SHIFT, reg1			;\
	or	reg1, L2_SCRUBENABLE, reg1				;\
	or	reg2, reg1, reg2					;\
	set	bank << L2_BANK_SHIFT, reg1				;\
	stx	reg2, [l2cr_base + reg1]				;\
    1: 	.poplocals



	ENTRY(enable_hw_scrubbers)
	/*
	 * Enable the l2$ scrubber for each of the four l2$ banks
	 */
	setx	L2_CONTROL_REG, %g2, %g1
	L2_SCRUB_ENABLE(%g1, /* bank */ 0, %g2, %g3)
	L2_SCRUB_ENABLE(%g1, /* bank */ 1, %g2, %g3)
	L2_SCRUB_ENABLE(%g1, /* bank */ 2, %g2, %g3)
	L2_SCRUB_ENABLE(%g1, /* bank */ 3, %g2, %g3)

	/*
	 * Enable the Niagara memory scrubber for each enabled DRAM
	 * bank
	 */
	setx	DRAM_BASE, %g2, %g1
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 0, %g2, %g3)
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 1, %g2, %g3)
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 2, %g2, %g3)
	DRAM_SCRUB_ENABLE(%g1, /* bank */ 3, %g2, %g3)

	HVRET

	SET_SIZE(enable_hw_scrubbers)

#endif	/* } */
