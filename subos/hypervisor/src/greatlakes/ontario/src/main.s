/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: main.s
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

	.ident	"@(#)main.s	1.85	07/07/17 SMI"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>
#include <sys/stack.h>
#include <sys/htypes.h>
#include <sparcv9/misc.h>
#include <sparcv9/asi.h>
#include <hprivregs.h>
#include <asi.h>
#include <traps.h>
#include <sun4v/traps.h>
#include <dram.h>
#include <sun4v/mmu.h>
#include <mmu.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <devices/pc16550.h>
#include <hypervisor.h>
#include <clock.h>
#include <guest.h>
#include <strand.h>
#include <offsets.h>
#include <md.h>
#include <vcpu.h>
#include <sun4v/errs_defs.h>
#include <errs_common.h>
#include <cpu_errs.h>
#include <config.h>
#include <cyclic.h>
#include <util.h>
#include <abort.h>
#include <hvctl.h>
#include <debug.h>
#include <fpga.h>
#include <ldc.h>
#include <iob.h>

#define	DBG_SCHEDULE	1
#define	DBG_DESCHEDULE	1
#define	DBG_STOP	1
#define	DBG_LAUNCH	0

	ENTRY_NP(start_master)
	! save incoming arguments
	mov	%g1, %i0	! membase
	mov	%g2, %i1	! memsize
	mov	%g3, %i2	! hypervisor description
	mov	%g4, %i3	! strandstartset
	mov	%g5, %i4	! total physical memory size		

	! init scratch pad register to a known state
	SET_VCPU_STRUCT(%g0, %g1)
	SET_STRAND_STRUCT(%g0, %g1)

#ifdef CONFIG_HVUART
	! initialize HV console UART
	setx	FPGA_UART_BASE, %g2, %g1
	HVCALL(uart_init)	! clobbers %g1,%g2,%g3,%g7 
#endif

	/*
	 * Determine if we're running in RAM or ROM
	 */
	rd	%pc, %g4
	srlx	%g4, 32, %g4	! in rom?
	cmp	%g4, 0x80	! bits <39,32>
	blu,pt	%xcc, .master_nocopy ! no, in ram already
	nop

	/*
	 * Running from ROM
	 *
	 * Scrub the memory that we're going to copy ourselves
	 * into.
	 */
	mov	%i0, %g1
	setx	htraptable, %g7, %g2
	setx	_edata, %g7, %g3
	brnz	%g3, 0f
	nop
	setx	_etext, %g7, %g3
0:
	! align to next 64-byte boundary
	inc	(64 - 1), %g3
	andn	%g3, (64 - 1), %g3
	sub	%g3, %g2, %g2
	HVCALL(memscrub)

	/*
	 * Currently executing in ROM, copy to RAM
	 */
	RELOC_OFFSET(%g1, %g5)	! %g5 = offset

	mov	%i0, %g2	! %g2 = membase
	setx	htraptable, %g7, %g1
	sub	%g1, %g5, %g1
	setx	_edata, %g7, %g3
	brnz	%g3, 0f
	nop
	setx	_etext, %g7, %g3
0:
	sub	%g3, %g5, %g3

	sub	%g3, %g1, %g3
	inc	7, %g3
	andn	%g3, 7, %g3
	HVCALL(xcopy)

	mov	%i0, %g1	! membase
	mov	%i1, %g2	! memsize
	mov	%i2, %g3	! hypervisor md address
	mov	%i3, %g4	! strandstartset
	mov	%i4, %g5	! total physical memory size

	add	%i0, (TT_POR * TRAPTABLE_ENTRY_SIZE), %g6	! master offset
	jmp	%g6
	nop

.master_nocopy:
	wrpr	%g0, 1, %tl
	wrpr	%g0, 1, %gl
	wrhpr	%g0, (HPSTATE_ENB | HPSTATE_HPRIV), %hpstate
	wrpr	%g0, NWINDOWS - 2, %cansave
	wrpr	%g0, NWINDOWS - 2, %cleanwin
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %cwp
	wrpr	%g0, 0, %wstate

	! save parameters for memory scrub which is done later
	mov	%i0, %l0	! membase
	mov	%i1, %l1	! memsize
	mov	%i3, %l2	! strandstartset
	mov	%i4, %l3	! total physical memory size

	RELOC_OFFSET(%g1, %g5)	! %g5 = offset
	setx	htraptable, %g3, %g1
	sub	%g1, %g5, %g1
	wrhpr	%g1, %htba

	setx	_edata, %g7, %g1
	brnz	%g1, 0f
	nop
	setx	_etext, %g7, %g1
0:
	! align to next 64-byte boundary
	add	%g1, (64 - 1), %g1
	andn	%g1, (64 - 1), %g1
	sub	%g1, %g5, %g1	! Start address
	add	%i0, %i1, %g2	! end address + 1
	sub	%g2, %g1, %g2	! length = end+1 - start
	HVCALL(memscrub)

	RELOC_OFFSET(%g1, %g5)	! %g5 = offset
	setx	config, %g6, %g1
	sub	%g1, %g5, %g6	! %g6 = global config

	! set
	stx	%i0, [%g6 + CONFIG_MEMBASE]
	stx	%i1, [%g6 + CONFIG_MEMSIZE]
	stx	%i3, [%g6 + CONFIG_STRAND_STARTSET]
	stx	%i4, [%g6 + CONFIG_PHYSMEMSIZE]
 
	/*
	 * Find first strand, and use it as the default
	 * target of system interrupts.
	 *	
	 * Simply, for now, we just pick the lowest functional strand
	 * as the host for SSI and error interrupts.
	 */
	brnz    %i3, 1f
	nop
	HVABORT(-1, "No live strands defined");
1:
	! Find first bit set !
	mov	0, %g1
2:
	srlx	%i3, %g1, %g2
	btst	1, %g2
	beq,a,pt %xcc, 2b
	  inc	%g1
	sllx	%g1, 1*INTRTGT_DEVSHIFT, %g2
	sllx	%g1, 2*INTRTGT_DEVSHIFT, %g1
	or	%g1, %g2, %g1
	stx	%g1, [%g6 + CONFIG_INTRTGT]

	mov	%g6, %i0	! %i0 - global config

	stx	%g5, [%i0 + CONFIG_RELOC]

	! Stash away the boot configs HV md.
	stx	%i2, [%i0 + CONFIG_PARSE_HVMD]
	mov	%i2, %i4
	! %i4 - hypervisor description

	setx	guests, %g6, %g1
	sub	%g1, %g5, %i1
	! %i1 - guests base
	stx	%i1, [%i0 + CONFIG_GUESTS]

	setx	vcpus, %g6, %g1
	sub	%g1, %g5, %i2
	! %i2 - vcpu base
	stx	%i2, [%i0 + CONFIG_VCPUS]

	setx	strands, %g6, %g1
	sub	%g1, %g5, %i3
	! %i3 - strands base
	stx	%i3, [%i0 + CONFIG_STRANDS]

	setx	hv_ldcs, %g6, %g1
	sub	%g1, %g5, %g1
	stx	%g1, [%i0 + CONFIG_HV_LDCS]

	setx	sp_ldcs, %g6, %g1
	sub	%g1, %g5, %g1
	stx	%g1, [%i0 + CONFIG_SP_LDCS]

	! Perform some basic setup for this strand.
	rd	STR_STATUS_REG, %g3
	srlx	%g3, STR_STATUS_CPU_ID_SHIFT, %g3
	and	%g3, STR_STATUS_CPU_ID_MASK, %g3

	! %g3 = strand id

	SET_VCPU_STRUCT(%g0, %g2)

	set	STRAND_SIZE, %g2
	mulx	%g3, %g2, %g4
	ldx	[%i0 + CONFIG_STRANDS], %g1
	add	%g1, %g4, %g1
	SET_STRAND_STRUCT(%g1, %g2)
	stx	%i0, [%g1 + STRAND_CONFIGP]

	! initialize the strand mini-stack
	stx	%g0, [%g1 + STRAND_MINI_STACK + MINI_STACK_PTR]

	PRINT("Alive and well ...\r\n")

	PRINT_REGISTER("Strand start set", %l2)
	PRINT_REGISTER("Total physical mem", %l3)

#ifndef T1_FPGA
#ifdef RESETCONFIG_BROKENTICK

	/*
	 * The %tick register on all strands are not properly
	 * synchronized coming out of reset. Use one of the JBUS
	 * performance counters as a common reference point for
	 * this task.
	 *
	 * As each strand is initialized, it reads a value from
	 * the counter and applies the appropriate scaling factor
	 * to convert it from JBUS cycles to a tick value in sync
	 * with all the other strands.
	 */

	! start counting JBUS cycles in perf counter 2
	setx	JBI_PERF_CTL, %g2, %g1
	set	(JBI_PERF1_EVT_OFF | JBI_PERF2_EVT_CYCLES), %g2
	stx	%g2, [%g1]

	! reset counter
	setx	JBI_PERF_COUNT, %g2, %g1
	stx	%g0, [%g1]
	!! %g1 = JBI performance counter reg

	! calculate JBUS clock multiplier
	setx	CLK_BASE, %g3, %g2
	ldx	[%g2 + CLK_DIV_REG], %g2	! %g2 = clock divider reg
	and	%g2, CLK_DIV_MASK, %g3		! %g3 = CMP divisor
	srlx	%g2, CLK_DIV_JDIV_SHIFT, %g5
	and	%g5, CLK_DIV_MASK, %g5
	sllx	%g5, CLK_DIV_SCALE_SHIFT, %g5	! %g5 = scaled JBUS divisor
	udivx	%g5, %g3, %g2
	!! %g2 = JBUS clock multiplier

	! convert to ticks and set %tick
	ldx	[%g1], %g3			! %g3 = JBUS cycle count
	mulx	%g3, %g2, %g3
	srlx	%g3, CLK_DIV_SCALE_SHIFT, %g3
	wrpr	%g3, %tick

#endif /* RESETCONFIG_BROKENTICK */
#endif /* ifndef T1_FPGA */

	! Before we can start using C compiled PIC code
	! we have to adjust the GLOBAL_OFFSET_TABLE

	setx	_GLOBAL_OFFSET_TABLE_, %g7, %g1
	setx	_start_data, %g7, %g2
	RELOC_OFFSET(%g7, %g3)
	sub	%g1, %g3, %g1
	sub	%g2, %g3, %g2
1:
	ldx	[%g1], %g4
	sub	%g4, %g3, %g4
	stx	%g4, [%g1]
	add	%g1, 8, %g1
	cmp	%g1, %g2
	blt,pt	%xcc, 1b
	  nop

#ifndef T1_FPGA
	PRINT("setup iob\r\n");
	HVCALL(setup_iob)

	PRINT("setup jbi\r\n");
	HVCALL(setup_jbi)
#endif /* ifndef T1_FPGA */

#ifdef CONFIG_VBSC_SVC
	PRINT("Sending HV start message to vbsc\r\n")
	HVCALL(vbsc_hv_start)
#endif

#ifdef CONFIG_FIRE
	PRINT("setup fire\r\n")
	HVCALL(setup_fire)
#endif

	! Scrub all of memory, except for the hypervisor.
	! This starts all other strands.
	STRAND_STRUCT(%g1)
	STRAND2CONFIG_STRUCT(%g1, %i0)
	HVCALL(scrub_all_memory)

	! Setup and run the initial C environment
	wrpr	%g0, 0, %gl
	wrpr	%g0, 0, %tl
	HVCALL(setup_c_environ)
	call	c_start
	  nop

	! Recover and run the old initialization code

	STRAND_STRUCT(%g1)
	STRAND2CONFIG_STRUCT(%g1, %i0)
	ldx	[%i0 + CONFIG_GUESTS], %i1
	ldx	[%i0 + CONFIG_VCPUS], %i2

	/*
	 * Setup everything else
	 */
	PRINT("setup everything else\r\n");

	/*
	 * Enable JBI error interrupts and clear SSIERROR
	 * mask (%g1 = 1)
	 */
	setx	JBI_INTR_ONLY_ERRS, %g2, %g1
	mov	1, %g2
	HVCALL(setup_jbi_err_interrupts)

	/*
	 * The SSI interrupts are generated from the FPGA which has a
	 * level output. The SSI input for N1 is however edge triggered.
	 * So if there is still an interrupt pending from the FPGA while
	 * the HV is reset, then N1 never sees an edge transition from the
	 * FPGA, and the interrupt is never taken by N1.
	 * To solve that here we fake a pending interrupt for N1, so that the
	 * interrupt service routine is run and anything that may be pending
	 * is cleared appropriately, and the FPGA is serviced correctly.
	 * Ugh!
	 */
#ifdef CONFIG_FPGA
	HVCALL(fake_ssiirq)
#endif

#ifdef CONFIG_SVC
	/* initialize the service channel */
	call c_svc_init
	nop
#endif /* CONFIG_SVC */

	PRINT("Setting remaining details\r\n")

#ifndef T1_FPGA

	/*
	 * Setup the Error Steer & Start the Polling Daemon:
	 */
	setx	L2_CONTROL_REG, %g1, %g4
	ldx	[%g4], %g3	
	setx	(NSTRANDS -1) << L2_ERRORSTEER_SHIFT, %g1, %g2
	andn	%g3, %g2, %g3				! remove current
	rd	STR_STATUS_REG, %g1			! this cpu
	srlx	%g1, STR_STATUS_CPU_ID_SHIFT, %g1	! right justify
	sllx	%g1, L2_ERRORSTEER_SHIFT, %g1		! position for CReg
	and	%g1, %g2, %g1				! mask
	or	%g3, %g1, %g3				! insert
	stx	%g3, [%g4]				! set to this cpu

	/*
	 * Initialize the poll daemon cyclic time.
	 */
	PRINT("Start error poll daemon\r\n")
	HVCALL(err_poll_daemon_start)			! start the daemon
#endif /* ifndef T1_FPGA */

	/*
	 * FIXME: Start heartbeat for the control domain.
	 * Eventually, this will need to be aware of multiple
	 * guests.
	 */
	PRINT("Start heart beat for control domain\r\n")
	HVCALL(heartbeat_enable)

	/*
	 * Final cleanup before we can consider the hypervisor truly
	 * running.
	 */

	DEBUG_SPINLOCK_ENTER(%g1, %g2, %g3)

#ifndef T1_FPGA
	/*
	 * Ensure all zero'd memory is flushed from the l2$
	 */
	PRINT_NOTRAP("Flush the L2 cache\r\n");
	HVCALL(l2_flush_cache)

#ifdef RESETCONFIG_ENABLEHWSCRUBBERS
	PRINT_NOTRAP("Enable L2 and DRAM HW scrubbers\r\n");
	HVCALL(enable_hw_scrubbers)
#endif
	
	PRINT_NOTRAP("Clear error status registers\r\n");
	HVCALL(clear_error_status_registers)
#endif /* ifndef T1_FPGA */

/*
 * XXXLDOMS: - Disabled due to intermittent INTACK TIMEOUT
 * seen.
 * Complete hack revisit and fix before FW putback.
 */
#if 0 /* FIXME */
	/*
	 * Enable JBI Interrupt timeout errors before entering the guest
	 * Don't clear the SSIERR mask bit (%g2 = 0) as we might already
	 * have a pending JBI error interrupt and we don't want to lose
	 * it.
	 */
	set	JBI_INTR_TO, %g1
	clr	%g2
	HVCALL(setup_jbi_err_interrupts)
#endif

	DEBUG_SPINLOCK_EXIT(%g1)

#if defined(CONFIG_SVC) && defined(CONFIG_VBSC_SVC)
	PRINT("Sending guest start message to vbsc\r\n")

	call	c_vbsc_guest_start
	mov	0, %o0		! ID of guest started
#endif /* defined(CONFIG_SVC) && defined(CONFIG_VBSC_SVC) */

	ba,a	start_work
	 nop
	SET_SIZE(start_master)



	ENTRY_NP(start_slave)
	mov	%g1, %i0	! membase

	! init scratch pad registers to a known state
	SET_VCPU_STRUCT(%g0, %g4)
	SET_STRAND_STRUCT(%g0, %g4)

	rd	%pc, %g4
	srlx	%g4, 32, %g4	! in rom?
	cmp	%g4, 0x80	! bits <39,32>
	blu,pt	%xcc, 1f	! no, in ram already
	nop
	add	%i0, (TT_POR * TRAPTABLE_ENTRY_SIZE) + 0x10, %g4 ! slave offset
	jmp	%g4		! goto ram traptable
	nop
1:
	wrhpr	%i0, %htba

	! Setup slave scratchpad for own identity

.reloc2:
	rd	%pc, %g1
	setx	.reloc2, %g3, %g2
	sub	%g2, %g1, %g3	! %g3 = offset
	setx	config, %g4, %g2
	sub	%g2, %g3, %g2
	! %g2 = &config

	rd	STR_STATUS_REG, %g1
	srlx	%g1, STR_STATUS_CPU_ID_SHIFT, %g1
	and	%g1, STR_STATUS_CPU_ID_MASK, %i3
	! %i3 = current cpu id

	! Set up the scratchpad registers

	ldx	[%g2 + CONFIG_STRANDS], %i2
	set	STRAND_SIZE, %g1
	mulx	%g1, %i3, %g1
	add	%i2, %g1, %i2
	SET_STRAND_STRUCT(%i2, %g1)

	SET_VCPU_STRUCT(%g0, %g1)

	! initialize the strand mini-stack
	! FIXME: should already be done
	stx	%g0, [%i2 + STRAND_MINI_STACK + MINI_STACK_PTR]

	! save &config on mini-stack since it cannot be retrieved
	! via CONFIG_STRUCT() until the master has run c_start()
	STRAND_PUSH(%g2, %g3, %g4)

	! Get us a sane tl & gl and out of red state asap
	wrpr	%g0, 0, %gl
	wrpr	%g0, 0, %tl
	wrhpr	%g0, (HPSTATE_ENB | HPSTATE_HPRIV), %hpstate
	wrpr	%g0, NWINDOWS - 2, %cansave
	wrpr	%g0, NWINDOWS - 2, %cleanwin
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %cwp
	wrpr	%g0, 0, %wstate

	STRAND_POP(%g4, %g3)	! restore %g4 = &config

#ifndef T1_FPGA
#ifdef RESETCONFIG_BROKENTICK

	/*
	 * Synchronize the %tick register with all other
	 * strands. One of the JBUS performance counters
	 * is used as a common reference point to calculate
	 * an appropriate tick value. The initialization
	 * of the counter has already been performed by
	 * the master.
	 */

	! calculate JBUS clock multiplier
	setx	CLK_BASE, %g3, %g2
	ldx	[%g2 + CLK_DIV_REG], %g2	! %g2 = clock divider reg
	and	%g2, CLK_DIV_MASK, %g3		! %g3 = CMP divisor
	srlx	%g2, CLK_DIV_JDIV_SHIFT, %g5
	and	%g5, CLK_DIV_MASK, %g5
	sllx	%g5, CLK_DIV_SCALE_SHIFT, %g5	! %g5 = scaled JBUS divisor
	udivx	%g5, %g3, %g2
	!! %g2 = JBUS clock multiplier

	! convert to ticks and set %tick
	setx	JBI_PERF_COUNT, %g3, %g1
	ldx	[%g1], %g3			! %g3 = jbus cycle count
	mulx	%g3, %g2, %g3
	srlx	%g3, CLK_DIV_SCALE_SHIFT, %g3
	wrpr	%g3, %tick

#endif /* RESETCONFIG_BROKENTICK */
#endif /* ifndef T1_FPGA */

	/* Slave now does its bit of the memory scrubbing */
#if  defined(CONFIG_FPGA) || defined(T1_FPGA)
	STRAND_STRUCT(%g1)
	set	STRAND_SCRUB_SIZE, %g3
	ldx	[%g1 + %g3], %g2
	set	STRAND_SCRUB_BASEPA, %g3
	ldx	[%g1 + %g3], %g1

	HVCALL(memscrub)

	STRAND_STRUCT(%g1)
	ldub	[%g1 + STRAND_ID], %i3
	mov	1, %i0
	sllx	%i0, %i3, %i0
	add	%g4, CONFIG_SCRUB_SYNC, %g4
1:
	ldx	[ %g4 ], %g2
	andn	%g2, %i0, %g3
	casx	[ %g4 ], %g2, %g3
	cmp	%g2, %g3
	bne,pt	%xcc, 1b
	  nop
#endif /* if  defined(CONFIG_FPGA) || defined(T1_FPGA) */

#ifndef T1_FPGA
	HVCALL(clear_error_status_registers)
#endif /* ifndef T1_FPGA */

	ba,a,pt	%xcc, start_work
	  nop
	SET_SIZE(start_slave)


	!
	! The main work section for each CPU strand.
	!
	! We basically look for things to do in the strand
	! structures work wheel. If we can find nothing to
	! do there, we simple suspend the strand and wait
	! for HV mondos which would request this strand to
	! add or remove something from its work wheel.
	!

	ENTRY_NP(start_work)
	!
	! This loop works through the schedule list looking for
	! something to do.
	! If an entire pass is made without an action, then we
	! simply go to sleep waiting for a X-call mondo.
	!
	mov	0, %g4
.work_loop:
	STRAND_STRUCT(%g1)
	lduh	[%g1 + STRAND_CURRENT_SLOT], %g2
	mulx	%g2, SCHED_SLOT_SIZE, %g3
	add	%g1, %g3, %g3
	add	%g3, STRAND_SLOT, %g3

	ldx	[%g3 + SCHED_SLOT_ACTION], %g6
	cmp	%g6, SLOT_ACTION_RUN_VCPU
	be,a,pt	%xcc, launch_vcpu
	  ldx	[%g3 + SCHED_SLOT_ARG], %g1	! get arg in annulled ds
	cmp	%g6, SLOT_ACTION_NOP
	be,pt	%xcc, 1f
	  nop

	HVABORT(-1, "Illegal slot code")
1:
	inc	%g2
	cmp	%g2, NUM_SCHED_SLOTS
	move	%xcc, %g0, %g2
	sth	%g2, [%g1 + STRAND_CURRENT_SLOT]
	inc	%g4
	cmp	%g4, NUM_SCHED_SLOTS
	bne,pt	%xcc, .work_loop
	  nop

	! OK nothing found to do wait for wake up call

	/* Wait for a HVXCALL PYN */
	HVCALL(hvmondo_wait)

	ba,pt	%xcc, handle_hvmondo
	nop
	SET_SIZE(start_work)

/* 
 * stop_vcpu
 * 
 * stop a virtual cpu 
 * 	and all associated state.
 * resets it so if started again, it will have a clean state
 * associated interrupts and memory mappings are unconfigured.
 *
 * NOTE: we go to some lengths to NOT get the vcpup from the
 * scratchpad registers so we can call this even when the vcpu
 * is not currently active.
 *
 * Expects:
 *	%g1 : vcpu pointer 
 * Returns:
 *	%g1 : vcpu pointer
 * Register Usage:
 *	%g1..%g6
 *	%g7 return address
 */
	ENTRY_NP(stop_vcpu)

	VCPU2GUEST_STRUCT(%g1, %g2)

#ifdef DEBUG
	brnz	%g2, 1f		! paranoia. expect this to be nz
	  nop
	HVABORT(-1, "vcpu has no assigned guest")
1:
#endif

	!
	! Save the vcpu ptr - we need it again later
	!
	STRAND_PUSH(%g1, %g3, %g4)

	!
	! Remove the strands permanent mappings
	!
	add	%g2, GUEST_PERM_MAPPINGS_LOCK, %g3
	SPINLOCK_ENTER(%g3, %g4, %g5)

	! Discover the bit for this cpu in the cpuset
	ldub	[%g1 + CPU_VID], %g3
	and	%g3, MAPPING_XWORD_MASK, %g5
	mov	1, %g4
	sllx	%g4, %g5, %g4
	srlx	%g3, MAPPING_XWORD_SHIFT, %g5
	sllx	%g5, MAPPING_XWORD_BYTE_SHIFT_BITS, %g5	! offset into xword array
	add	%g2, GUEST_PERM_MAPPINGS + GUEST_PERM_MAPPINGS_INCR*(NPERMMAPPINGS-1), %g2
	mov	-(GUEST_PERM_MAPPINGS_INCR*(NPERMMAPPINGS-1)), %g3

1:
	add	%g3, %g2, %g1	! Ptr to this perm mapping
	add	%g1, %g5, %g1	! Xword in a specific cpu set
		! Unset bit fields for this cpu
	ldx	[ %g1 + MAPPING_ICPUSET ], %g6
	andn	%g6, %g4, %g6
	stx	%g6, [%g1 + MAPPING_ICPUSET]
	ldx	[ %g1 + MAPPING_DCPUSET ], %g6
	andn	%g6, %g4, %g6
	stx	%g6, [%g1 + MAPPING_DCPUSET]

		! If entry is completely null, invalidate entry
	mov	MAPPING_XWORD_SIZE*(NVCPU_XWORDS-1), %g1
2:
	add	%g3, %g2, %g6	! Grr out of registers
	add	%g6, %g1, %g6
	ldx	[%g6 + MAPPING_ICPUSET], %g6
	brnz	%g6, 3f
	add	%g3, %g2, %g6	! Grr out of registers
	add	%g6, %g1, %g6
	ldx	[%g6 + MAPPING_DCPUSET], %g6
	brnz	%g6, 3f
	  nop
	brgz,pt %g1, 2b
	  sub	%g1, MAPPING_XWORD_SIZE, %g1

	add	%g3, %g2, %g6	! Grr out of registers
	stx	%g0, [%g6 + MAPPING_TTE]	! Invalidate TTE first
	stx	%g0, [%g6 + MAPPING_VA]
3:
	brlz,pt	%g3, 1b
	add	%g3, GUEST_PERM_MAPPINGS_INCR, %g3

	membar	#Sync	! needed ?
	
	!
	! demap all unlocked tlb entries
	!
	set	TLB_DEMAP_ALL_TYPE, %g3
	stxa	%g0, [%g3]ASI_IMMU_DEMAP
	stxa	%g0, [%g3]ASI_DMMU_DEMAP

	membar	#Sync	! needed ?

	! Reload guest and cpu struct pointers
	STRAND_POP(%g1, %g2)
	VCPU2GUEST_STRUCT(%g1, %g2)
	add	%g2, GUEST_PERM_MAPPINGS_LOCK, %g3
	SPINLOCK_EXIT(%g3)


	!
	! remove this cpu as the target of any ldc interrupts
	!
	set	GUEST_LDC_ENDPOINT, %g3
	add	%g2, %g3, %g3
	set	(GUEST_LDC_ENDPOINT_INCR * MAX_LDC_CHANNELS), %g5
	add	%g3, %g5, %g4
	! %g3 = ldc endpoint array base address
	! %g4 = current offset into array

.next_ldc:
	sub	%g4, GUEST_LDC_ENDPOINT_INCR, %g4
	cmp	%g4, %g3
	bl	%xcc, .ldc_disable_loop_done
	nop

	ldub	[%g4 + LDC_IS_LIVE], %g5
	brz	%g5, .next_ldc
	nop

	! %g1 = the vcpu to stop

	!
	! Only clear out the Q CPU so that no interrupts
	! will be targeted to this CPU. The LDC channel is
	! still live and incoming packets will still be
	! queued up.
	!
	ldx	[%g4 + LDC_TX_MAPREG + LDC_MAPREG_CPUP], %g5
	cmp	%g5, %g1
	bne	%xcc, .check_rx
	  nop
	stx	%g0, [%g4 + LDC_TX_MAPREG + LDC_MAPREG_CPUP]
.check_rx:
	ldx	[%g4 + LDC_RX_MAPREG + LDC_MAPREG_CPUP], %g5
	cmp	%g5, %g1
	bne	%xcc, .next_ldc
	  nop
	stx	%g0, [%g4 + LDC_RX_MAPREG + LDC_MAPREG_CPUP]

	ba	.next_ldc
	  nop

.ldc_disable_loop_done:

	! FIXME: must cancel device interrupts targeted at this cpu
	!        HOW?

	! FIXME; Do we have to do all this or does it happen on
	! the way back in on starting the cpu again ?

	stx	%g0, [%g1 + CPU_MMU_AREA_RA]	! erase remaining info
	stx	%g0, [%g1 + CPU_MMU_AREA]
	stx	%g0, [%g1 + CPU_TTRACEBUF_RA]
	stx	%g0, [%g1 + CPU_TTRACEBUF_PA]
	stx	%g0, [%g1 + CPU_TTRACEBUF_SIZE]
	stx	%g0, [%g1 + CPU_NTSBS_CTX0]
	stx	%g0, [%g1 + CPU_NTSBS_CTXN]

	! Unconfig all the interrupt and error queues
	stx	%g0, [%g1 + CPU_ERRQNR_BASE] 
	stx	%g0, [%g1 + CPU_ERRQNR_BASE_RA] 
	stx	%g0, [%g1 + CPU_ERRQNR_SIZE] 
	stx	%g0, [%g1 + CPU_ERRQNR_MASK] 

	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g3
	stxa	%g0, [%g3]ASI_QUEUE

	stx	%g0, [%g1 + CPU_ERRQR_BASE] 
	stx	%g0, [%g1 + CPU_ERRQR_BASE_RA] 
	stx	%g0, [%g1 + CPU_ERRQR_SIZE] 
	stx	%g0, [%g1 + CPU_ERRQR_MASK] 

	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g3
	stxa	%g0, [%g3]ASI_QUEUE

	stx	%g0, [%g1 + CPU_DEVQ_BASE] 
	stx	%g0, [%g1 + CPU_DEVQ_BASE_RA] 
	stx	%g0, [%g1 + CPU_DEVQ_SIZE] 
	stx	%g0, [%g1 + CPU_DEVQ_MASK] 

	mov	DEV_MONDO_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_TAIL, %g3
	stxa	%g0, [%g3]ASI_QUEUE

	stx	%g0, [%g1 + CPU_CPUQ_BASE] 
	stx	%g0, [%g1 + CPU_CPUQ_BASE_RA] 
	stx	%g0, [%g1 + CPU_CPUQ_SIZE] 
	stx	%g0, [%g1 + CPU_CPUQ_MASK] 

	mov	CPU_MONDO_QUEUE_HEAD, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	mov	CPU_MONDO_QUEUE_TAIL, %g3
	stxa	%g0, [%g3]ASI_QUEUE
	

	! FIXME
	! just an off-the-cuff list
	! what else of this cpu struct should be cleared/cleaned?
	!
	! FIXME: All this stuff goes away if we call reset_vcpu_state
	! in reconf.c - except that maybe we do this in startvcpu instead ?

	! indicate cpu is unconfigured
	mov	CPU_STATE_STOPPED, %g3
	ldx	[%g1 + CPU_STATUS], %g4		! do not change status to
	cmp	%g4, CPU_STATE_ERROR		! STATE_STOPPPED if in CPU
	bne,a,pn %xcc, 1f			! is in error
	  stx	%g3, [%g1 + CPU_STATUS]
	membar	#Sync
1:
	HVRET
	SET_SIZE(stop_vcpu)


	!
	! Enter from start_work loop
	! Expects no register setups (except hv scratchpads)
	! Provides register setups for master_start
	!
	! Argument in %g1 points to vcpu struct
	!

	ENTRY_NP(launch_vcpu)

	/*
	 * quick set of sanity checks.
	 */
#ifdef DEBUG
		 /* is it assigned to this strand ? */
	STRAND_STRUCT(%g2)
	ldx	[%g1 + CPU_STRAND], %g3
	cmp	%g2, %g3
	be,pt	%xcc, 1f
	nop

	HVABORT(-1, "Scheduled vcpu not assigned to this strand")
1:

	/*
	 * is the cpu configured ?
	 * is it stopped or running and not in error ?
	 */
	ldx	[%g1 + CPU_STATUS], %g3
	cmp	%g3, CPU_STATE_STOPPED
	be,pt	%xcc, 1f
	cmp	%g3, CPU_STATE_SUSPENDED
	be,pt	%xcc, 1f
	cmp	%g3, CPU_STATE_RUNNING
	be,pt	%xcc, 1f
	cmp	%g3, CPU_STATE_STARTING
	be,pt	%xcc, 1f
	  nop

	PRINT("\tvcpu state = 0x")
	PRINTX(%g3)
	PRINT("\r\n")
	HVABORT(-1, "Scheduled vcpu is in an illegal state or not configured")
1:

#endif

	/*
	 * OK let fly ...
	 */

	!
	! The vcpu should be fully configured and ready to
	! go even if it has never been run before.
	! However, because the vcpu state save and restore is not
	! complete, and because we're not (re)scheduleing vcpus yet
	! then the very first time the vcpu gets kicked off we try and
	! initialize some of the basic registers that are not
	! (re)stored into place with the state restoration.
	!
	! We figure this all out from the cpu state. If it was
	! stopped, then we need to configure registers to bring it
	! alive. If it is RUNNING or SUSPENDED then we just
	! restore the registers and launch into it.
	!
	! An additional wrinkle - if the cpu is stopped, then it
	! may be that the guest too is stopped, in which case we
	! assume we're the boot cpu and do the appropriate reset setup
	! for the guest too. This can result in an aync status update
	! message on the HVCTL channel if it is configured.
	!
	
	SET_VCPU_STRUCT(%g1, %g2)

	ldx	[%g1 + CPU_STATUS], %g3
	cmp	%g3, CPU_STATE_STOPPED
	be,pn	%xcc, slow_start
	cmp	%g3, CPU_STATE_STARTING
	be,pn	%xcc, slow_start
	nop

	! Fast start ...
	PRINT("About to restore\r\n")
	HVCALL(vcpu_state_restore)
	PRINT_NOTRAP("Completed restore\r\n")
fast_start:

	VCPU_STRUCT(%g1)
	mov	CPU_STATE_RUNNING, %g2
	stx	%g2, [%g1 + CPU_STATUS]	! it's running now

	/*
	 * Now that the vcpu is running, set the starting stick
	 * value for the first utilization query.
	 */
	rd	%tick, %g3
	sllx	%g3, 1, %g3	! remove npt bit
	srax	%g3, 1, %g3
	stx	%g3, [%g1 + CPU_UTIL_STICK_LAST]

	set	CPU_LAUNCH_WITH_RETRY, %g2
	ldub	[%g1 + %g2], %g1
	brnz,pt	%g1, 1f
	nop
	done
1:
	retry

slow_start:
	!
	! This section is to formally start a virtual CPU
	! from the stopped state.
	!
	! There are a number of additional things we want to do
	! if this is the very first time we're entering a guest.
	!

	VCPU_GUEST_STRUCT(%g1, %g5)

#ifdef CONFIG_CRYPTO

	/*
	 * Start crypto
	 */
	mov	%g5, %g2
	!
	! %g1 = cpu struct
	! %g2 = guest struct
	!
	HVCALL(start_crypto)
#endif /* CONFIG_CRYPTO */

	lduw	[%g5 + GUEST_STATE], %g3
	cmp	%g3, GUEST_STATE_NORMAL
	be,pt	%xcc, .launch_non_boot_cpu
	nop
	cmp	%g3, GUEST_STATE_RESETTING
	be,pt	%xcc, .launch_boot_cpu
	nop
	cmp	%g3, GUEST_STATE_SUSPENDED
	bne,pt	%xcc, 1f
	nop
	HVABORT(-1, "guest suspend not yet supported")
	! when it is supported we need to move the guest
	! from suspended back to its prior state ...
	! which begs the question of whether we want to have
	! the suspended state or a separate flag ?
1:
	cmp	%g3, GUEST_STATE_STOPPED
	bne,pt	%xcc, 1f
	  nop
	HVABORT(-1, "guest in STOPPED state in launch_vcpu")
1:
	HVABORT(-1, "invalid guest state in launch_vcpu")

.launch_boot_cpu:

	/*
	 * FIXME: This scrub needs to go away
	 *
	 * Only scrub guest memory if reset reason is POR
	 *
	 * %g1 - vcpu
	 * %g5 - guest
	 */

	set	GUEST_RESET_REASON, %g3
	ldx	[%g5 + %g3], %g3
	cmp	%g3, RESET_REASON_POR
	bne,pt	%xcc, .master_guest_scrub_done
	nop

	mov	(NUM_RA2PA_SEGMENTS - 1) * RA2PA_SEGMENT_SIZE, %g3
	set	(-1), %g6
1:
	add	%g3, GUEST_RA2PA_SEGMENT, %g4
	add	%g4, %g5, %g4				! &guest.ra2pa_segment

	! only scrub memory segments (obviously ...)
	ldub	[%g4 + RA2PA_SEGMENT_FLAGS], %g1
	btst	MEM_SEGMENT, %g1
	bz,pn	%xcc, 2f
	nop

	ldx	[%g4 + RA2PA_SEGMENT_BASE], %g1		! RA of base of
							! 	memory segment
	brlz,pn	%g1, 2f
	nop
	ldx	[%g4 + RA2PA_SEGMENT_LIMIT], %g2	! limit of memory
							!	segment
	sub	%g2, %g1, %g2				! %g2
							!  (limit - base)->size
	brlez,pn	%g2, 2f
	nop

	ldx	[%g4 + RA2PA_SEGMENT_OFFSET], %g7	! offset of memory
							!		segment
	add	%g1, %g7, %g1				! RA -> PA

	/*
	 * It's possible that two (or more) contiguous segments describe
	 * the same physical area in memory so we keep track of the
	 * last segment PA scrubbed and skip this segment scrub if it's
	 * the same. Note that all the segments will have the same size
	 * (> 16GB) so one scrub fits all.
	 */
	cmp	%g1, %g6
	be,pn	%xcc, 2f
	mov	%g1, %g6

	HVCALL(memscrub)
2:
	brgz,pt	%g3, 1b
	sub	%g3, RA2PA_SEGMENT_SIZE, %g3

.master_guest_scrub_done:

	/*
	 * Copy guest's firmware image into the partition
	 */
	VCPU_GUEST_STRUCT(%g1, %g2)

	set	GUEST_ROM_SIZE, %g7
	ldx	[%g2 + %g7], %g3
	set	GUEST_ROM_BASE, %g7
	ldx	[%g5 + %g7], %g1
	set	GUEST_ROM_SIZE, %g7
	ldx	[%g5 + %g7], %g3

	! find segment for the guest which contains GUEST_REAL_BASE
	ldx	[%g5 + GUEST_REAL_BASE], %g2		! guest real base addr
	srlx	%g2, RA2PA_SHIFT, %g2
	sllx    %g2, RA2PA_SEGMENT_SHIFT, %g2		! ra2pa_segment
	add	%g2, GUEST_RA2PA_SEGMENT, %g2
	add	%g5, %g2, %g4				! %g4 &
							!    guest.ra2pa_segment
	ldx	[%g4 + RA2PA_SEGMENT_BASE], %g2		! RA of segment base
	ldx	[%g4 + RA2PA_SEGMENT_OFFSET], %g4	! Offset of segment base
	add	%g2, %g4, %g2				! PA of segment

	! %g1	ROM base
	! %g2	ROM size
	! %g3	GUEST base

	HVCALL(xcopy)


#ifdef CONFIG_FIRE

	GUEST_STRUCT(%g3)

	! %g3 guest struct

	!
	! Does this guest have control over Fire leaf A?
	! If so, we need to reset and unconfigure the leaf.
	!

	CONFIG_STRUCT(%g1)
	ldx	[%g1 + CONFIG_PCIE_BUSSES], %g2
	ldx	[%g2 + PCIE_DEVICE_GUESTP], %g2	/* bus 0 */
	cmp	%g2, %g3
	bne,pt	%xcc, 1f
	nop

	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl
	HVCALL(setup_c_environ)
	mov	0, %o0				! PCI bus A = 0
	call	pcie_bus_reset
	nop

	CONFIG_STRUCT(%g1)
	setx    fire_dev, %g7, %g5
	ldx     [%g1 + CONFIG_RELOC], %g7
	sub     %g5, %g7, %g1		! ptr to fire_dev[0]
	
	mov	0, %g2			! PCI bus A = 0

	! %g1 - fire cookie
	! %g2 - root complex (0=A, 1=B)
	HVCALL(fire_leaf_soft_reset)

1:
	GUEST_STRUCT(%g3)

	!
	! Does this guest have control over Fire leaf B?
	! If so, we need to reset and unconfigure the leaf.
	!

	CONFIG_STRUCT(%g1)
	ldx	[%g1 + CONFIG_PCIE_BUSSES], %g2
	ldx	[%g2 + PCIE_DEVICE_GUESTP + PCIE_DEVICE_SIZE], %g2  /* bus 1 */
	cmp	%g2, %g3
	bne,pt	%xcc, 1f
	nop

	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl
	HVCALL(setup_c_environ)
	mov	1, %o0				! PCI bus B = 1
	call	pcie_bus_reset
	nop

	CONFIG_STRUCT(%g1)
	setx    fire_dev, %g7, %g5
	ldx     [%g1 + CONFIG_RELOC], %g7
	sub     %g5, %g7, %g5                   ! ptr to fire_dev[]
	add     %g5, FIRE_COOKIE_SIZE, %g1	! &fire_dev[1]
	
	mov	1, %g2			! PCI bus B = 1

	! %g1 - fire cookie
	! %g2 - root complex (0=A, 1=B)
	HVCALL(fire_leaf_soft_reset)

1:
bus_failed:
#endif	/* CONFIG_FIRE */

	VCPU_GUEST_STRUCT(%g6, %g5)

	! Back to original reg assignments
	! %g6 = cpu
	! %g5 = guest

	! For the boot CPU we must set the launch point - which is in
	! the real trap table. Since we have now copied in a new
	! firmware image, we must also reset the rtba to point to
	! this location.
	! There are only two ways a cpu can start from stopped
	! 1. as the boot cpu in which case we force the start address
	! 2. via a cpu_start API call in which case the start address
	!	is set there.

	ldx	[%g5 + GUEST_REAL_BASE], %g2
	stx	%g2, [%g6 + CPU_RTBA]
	inc	(TT_POR * TRAPTABLE_ENTRY_SIZE), %g2 ! Power-on-reset vector
	stx	%g2, [%g6 + CPU_START_PC]

	/*
	 * Set the guest state to normal, and signal this to Zeus
	 * on the hvctl channel if it is configured.
	 */
	mov	GUEST_STATE_NORMAL, %g1
	stw	%g1, [%g5 + GUEST_STATE]

	mov	SIS_TRANSITION, %g1
	stub	%g1, [%g5 + GUEST_SOFT_STATE]

	add	%g5, GUEST_SOFT_STATE_STR, %g1
	mov	SOFT_STATE_SIZE, %g2
	HVCALL(bzero)

	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl
	HVCALL(setup_c_environ)
	GUEST_STRUCT(%o0)
	call	guest_state_notify
	nop

	/*
	 * Now that the guest is officially up and running,
	 * initialize the utilization statistics.
	 */
	rd	%tick, %g1
	sllx	%g1, 1, %g1	! remove npt bit
	srax	%g1, 1, %g1

	GUEST_STRUCT(%g2)
	set	GUEST_START_STICK, %g3
	add	%g2, %g3, %g3
	stx	%g1, [%g3]

	set	GUEST_UTIL, %g3
	add	%g2, %g3, %g3
	stx	%g1, [%g3 + GUTIL_STICK_LAST]
	stx	%g0, [%g3 + GUTIL_STOPPED_CYCLES]

	ba	1f
	nop

.launch_non_boot_cpu:

	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl
	HVCALL(setup_c_environ)
1:
	VCPU_STRUCT(%o0)
	call	reset_vcpu_state
	nop

	HVCALL(vcpu_state_restore)

	!
	! This nastyness should be replaced by vcpu_state_restore
	!

	! clear NPT
	rdpr	%tick, %g3
	cmp	%g3, 0
	bge	%xcc, 1f
	nop
	sllx	%g3, 1, %g3
	srlx	%g3, 1, %g3
	wrpr	%g3, %tick
1:

#define	INITIAL_PSTATE	(PSTATE_PRIV | PSTATE_MM_TSO)
#define	INITIAL_TSTATE	((INITIAL_PSTATE << TSTATE_PSTATE_SHIFT) | \
	(MAXPGL << TSTATE_GL_SHIFT))

	VCPU_GUEST_STRUCT(%g6, %g5)

	setx	INITIAL_TSTATE, %g2, %g1
	wrpr	%g1, %tstate
	wrhpr	%g0, %htstate

	ldub	[%g6 + CPU_PARTTAG], %g2
	set	IDMMU_PARTITION_ID, %g1
	stxa	%g2, [%g1]ASI_DMMU
	mov	MMU_PCONTEXT, %g1
	stxa	%g0, [%g1]ASI_MMU
	mov	MMU_SCONTEXT, %g1
	stxa	%g0, [%g1]ASI_MMU

	HVCALL(set_dummytsb_ctx0)
	HVCALL(set_dummytsb_ctxN)

	/*
	 * A strand must enter the guest with MMUs disabled.
	 * The guest assumes responsibility for establishing
	 * any mappings it requires and enabling the MMU.
	 */
	ldxa	[%g0]ASI_LSUCR, %g1
	set	(LSUCR_DM | LSUCR_IM), %g2
	btst	%g1, %g2
	be,pn	%xcc, 0f		! already disabled
	nop
	andn	%g1, %g2, %g1		! mask out enable bits
	stxa	%g1, [%g0]ASI_LSUCR
0:
	stx	%g0, [%g6 + CPU_MMU_AREA_RA]
	stx	%g0, [%g6 + CPU_MMU_AREA]

	wr	%g0, 0, SOFTINT
	wrpr	%g0, PIL_15, %pil
	mov	CPU_MONDO_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	CPU_MONDO_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	DEV_MONDO_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE

	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, %g1
	stxa	%g0, [%g1]ASI_QUEUE
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, %g1
	stxa	%g0, [%g1]ASI_QUEUE

	! FIXME: This should be part of the restore_state call
	! initialize fp regs
	rdpr	%pstate, %g1
	or	%g1, PSTATE_PEF, %g1
	wrpr	%g1, %g0, %pstate
	wr	%g0, FPRS_FEF, %fprs
	stx	%g0, [%g6 + CPU_SCR0]
	ldd	[%g6 + CPU_SCR0], %f0
	ldd	[%g6 + CPU_SCR0], %f2
	ldd	[%g6 + CPU_SCR0], %f4
	ldd	[%g6 + CPU_SCR0], %f6
	ldd	[%g6 + CPU_SCR0], %f8
	ldd	[%g6 + CPU_SCR0], %f10
	ldd	[%g6 + CPU_SCR0], %f12
	ldd	[%g6 + CPU_SCR0], %f14
	ldd	[%g6 + CPU_SCR0], %f16
	ldd	[%g6 + CPU_SCR0], %f18
	ldd	[%g6 + CPU_SCR0], %f20
	ldd	[%g6 + CPU_SCR0], %f22
	ldd	[%g6 + CPU_SCR0], %f24
	ldd	[%g6 + CPU_SCR0], %f26
	ldd	[%g6 + CPU_SCR0], %f28
	ldd	[%g6 + CPU_SCR0], %f30

	ldd	[%g6 + CPU_SCR0], %f32
	ldd	[%g6 + CPU_SCR0], %f34
	ldd	[%g6 + CPU_SCR0], %f36
	ldd	[%g6 + CPU_SCR0], %f38
	ldd	[%g6 + CPU_SCR0], %f40
	ldd	[%g6 + CPU_SCR0], %f42
	ldd	[%g6 + CPU_SCR0], %f44
	ldd	[%g6 + CPU_SCR0], %f46
	ldd	[%g6 + CPU_SCR0], %f48
	ldd	[%g6 + CPU_SCR0], %f50
	ldd	[%g6 + CPU_SCR0], %f52
	ldd	[%g6 + CPU_SCR0], %f54
	ldd	[%g6 + CPU_SCR0], %f56
	ldd	[%g6 + CPU_SCR0], %f58
	ldd	[%g6 + CPU_SCR0], %f60
	ldd	[%g6 + CPU_SCR0], %f62

	ldx	[%g6 + CPU_SCR0], %fsr
	wr	%g0, 0, %gsr
	wr	%g0, 0, %fprs

	! %g6 cpu
	VCPU2GUEST_STRUCT(%g6, %g5)
	! %g5 guest

	/*
	 * Initial arguments for the guest
	 */
	mov	CPU_STATE_RUNNING, %o0
	stx	%o0, [%g6 + CPU_STATUS]
	membar	#Sync

	/*
	 * Start at the correct POR vector entry point
	 */
	set	CPU_LAUNCH_WITH_RETRY, %g2
	stb	%g0, [%g6 + %g2]

	set	CPU_START_PC, %g2
	ldx	[%g6 + %g2], %g2
	wrpr	%g2, %tnpc

	ldx	[%g6 + CPU_START_ARG], %o0	! argument
        ldx     [%g5 + GUEST_REAL_BASE], %i0	! memory base

	! find size of base memory segment
	mov	%i0, %g2
	srlx	%g2, RA2PA_SHIFT, %g2
	sllx	%g2, RA2PA_SEGMENT_SHIFT, %g2	! ra2pa_segment
	add	%g2, GUEST_RA2PA_SEGMENT, %g2
	add	%g5, %g2, %g4			! %g4 &guest.ra2pa_segment
	ldx	[%g4 + RA2PA_SEGMENT_BASE], %g1
	ldx	[%g4 + RA2PA_SEGMENT_LIMIT], %g2
	sub	%g2, %g1, %i1			! memory size = limit - base

	membar	#Sync

	ba	fast_start
	nop
	SET_SIZE(launch_vcpu)

/*
 * Scrub all of memory except for the HV. 
 * Only scrub if running on hardware or in other words if HW FPGA is present.
 *
 * Parallelize the scrubbing activity by breaking the total
 * amount into chunks that each CPU can handle, and require them to
 * do their bit as part of their initial startup activity.
 *
 * Inputs:
 *   %i0 global config pointer
 */
	ENTRY_NP(scrub_all_memory)
	mov	%g7, %l7	! save return address
	ldx	[%i0 + CONFIG_MEMBASE], %l0
	ldx	[%i0 + CONFIG_MEMSIZE], %l1
	ldx	[%i0 + CONFIG_STRAND_STARTSET], %l2
	ldx	[%i0 + CONFIG_PHYSMEMSIZE], %l3

#if  defined(CONFIG_FPGA) || defined(T1_FPGA)
	! How many functional strands do we have available?
	mov	%l2, %o7
	mov	1, %o1
	mov	%g0, %o2
1:
	andcc	%o7, %o1, %g0
	beq,pt	%xcc, 2f
	  nop
	add	%o2, 1, %o2
2:
	sllx	%o1, 1, %o1
	brnz,pt	%o1, 1b
	  nop

	! %o2 = number of available strands
	PRINT("Scrubbing the rest of memory\r\n")
	PRINT_REGISTER("Number of strands", %o2)

	PRINT_REGISTER("membase", %l0)
	PRINT_REGISTER("memsize", %l1)
	PRINT_REGISTER("physmem", %l3)

	mov	%l0, %g1			! membase
	mov	%l1, %g2			! memsize
	add	%g1, %g2, %g1			! start of rest of memory
	mov	%l3, %g2			! total size
	sub	%g2, %g1, %g3
	! %g1 = start address
	! %g3 = size to scrub

	! Figure a chunk per strand (round up to 64 bytes)
	udivx	%g3, %o2, %g3
	add	%g3, 63, %g3
	andn	%g3, 63, %g3

	! Now allocate a slice per strand (phys cpu)
	! %i0 = config struct
	! %o7 = live strand bit mask
	! %g1 = scrub start address
	! %g2 = max scrub address
	! %g3 = size for each chunk

	ldx	[%i0 + CONFIG_STRANDS], %o3
	mov	%g0, %g6
1:
	mov	1, %o1
	sllx	%o1, %g6, %o1
	andcc	%o7, %o1, %g0
	beq,pt	%xcc, 2f
	  nop
	set	STRAND_ID, %g5
	stub	%g6, [ %o3 + %g5 ]
	set	STRAND_SCRUB_BASEPA, %g5
	stx	%g1, [ %o3 + %g5 ]
	sub	%g2, %g1, %g4
	cmp	%g4, %g3
	movg	%xcc, %g3, %g4
	set	STRAND_SCRUB_SIZE, %g5
	stx	%g4, [ %o3 + %g5 ]
	add	%g1, %g4, %g1
2:
	set	STRAND_SIZE, %g5
	add	%o3, %g5, %o3
	inc	%g6
	cmp	%g6, NSTRANDS
	blt,pt	%xcc, 1b
	  nop

	! Master removes itself from the completed set
	STRAND_STRUCT(%o3)
	ldub	[%o3 + STRAND_ID], %g1
	mov	1, %g2
	sllx	%g2, %g1, %g2
	andn	%o7, %g2, %o7

	! strand bits get cleared as their scrub is completed
	stx	%o7, [ %i0 + CONFIG_SCRUB_SYNC ]
#endif /* if  defined(CONFIG_FPGA) || defined(T1_FPGA) */

	/*
	 * Start all the other strands. They will scrub their slice of memory
	 * and then go into start work.
	 */

#ifdef T1_FPGA

	mov	%l2, %g2				! %g2 = strandstartset
	mov	0, %g1
	setx	IOBBASE + INT_VEC_DIS, %g4, %g5

1:	mov	1, %g3
	btst	%g2, %g3
	bz,pn	%xcc, 2f
	nop

/* skip the current cpu */

	! get coreid from our register
	! this code comes from htraps.s - HT0_RdThId_0x18e
	setx     0xba00000000, %g3, %g6
    	ldxa     [%g6] 0x15, %g6            ! has coreid


    	srlx    %g6, 8, %g3
 	mulx    %g3, PTON_X_TILES, %g3
    	and     %g6, 0xff, %g6
    	add     %g6, %g3, %g6    

    	sllx    %g6, 1, %g6

	rd	%STR_STATUS_REG, %g3
    	srlx    %g3, STR_STATUS_STRAND_ID_SHIFT, %g3
    	and	%g3, STR_STATUS_STRAND_ID_MASK, %g3	! %g3 = current cpu
    	add     %g3, %g6, %g3
        set     0x007f, %g6
    	and     %g3, %g6, %g3

	!rd	STR_STATUS_REG, %g3
	!srlx	%g3, STR_STATUS_STRAND_ID_SHIFT, %g3
	!and	%g3, STR_STATUS_STRAND_ID_MASK, %g3	! %g3 = current cpu
	
	!or 	%g6, %g3, %g6
	cmp     %g1, %g3
	beq,pt  %xcc, 3f                                 ! skip the current cpu
	nop

/* Send poweron reset to other core master strands. */
/* The lowest numbered cpu in a core is the core master */

	mov	INT_VEC_DIS_TYPE_RESET, %g4
	
	sllx	%g4, INT_VEC_DIS_TYPE_SHIFT, %g4
	or      %g4, INT_VEC_DIS_VECTOR_RESET, %g4
	sllx	%g1, INT_VEC_DIS_VCID_SHIFT, %g3	! target strand
	or	%g4, %g3, %g3				! int_vec_dis value
	
	!srlx	%g6, 2, %g6
	!sllx	%g6, 18, %g6
	!or	%g6, %g3, %g3
	
	!setx	0x8000000000000000, %g7, %g6
	!or	%g6, %g3, %g3
	
	stx	%g3, [%g5]

3:
/* skip the slave strands in a core. the core master wakes up the other strands in reset code.  */
	srlx    %g2, 1, %g2
	inc	%g1
	and     %g1, 3, %g3
	brnz,pt %g3, 3b
	nop
	cmp     %g1, (NSTRANDS-1)
	bleu,pt	%xcc, 1b
	nop
	brz,pt  %g0, 4f
	nop

2:	
	srlx    %g2, 1, %g2
	inc	%g1
	cmp     %g1, (NSTRANDS-1)
	bleu,pt	%xcc, 1b
	nop

4:



/* The current cpu wakes up the slave strands in it's own core */

	mov	%l2, %g2				! %g2 = strandstartset


	! get coreid from our register
	! this code comes from htraps.s - HT0_RdThId_0x18e
	setx     0xba00000000, %g3, %g6
    	ldxa     [%g6] 0x15, %g6            ! has coreid


    	srlx    %g6, 8, %g3
 	mulx    %g3, PTON_X_TILES, %g3
    	and     %g6, 0xff, %g6
    	add     %g6, %g3, %g6    

    	sllx    %g6, 1, %g6

	rd	%STR_STATUS_REG, %g3
    	srlx    %g3, STR_STATUS_STRAND_ID_SHIFT, %g3
    	and	%g3, STR_STATUS_STRAND_ID_MASK, %g3	! %g3 = current cpu
    	add     %g3, %g6, %g3
        set     0x007f, %g6
    	and     %g3, %g6, %g3

	!rd	STR_STATUS_REG, %g3
	!srlx	%g3, STR_STATUS_CPU_ID_SHIFT, %g3
	!and	%g3, STR_STATUS_CPU_ID_MASK, %g3	! %g3 = current cpu

	add	%g3, 1, %g1
	srlx    %g2, %g1, %g2
	setx	IOBBASE + INT_VEC_DIS, %g4, %g5

1:	
	and     %g1, 3, %g3
	brz,pt  %g3, 3f                                 ! reached next core
	nop

	mov	1, %g3
	btst	%g2, %g3
	bz,pn	%xcc, 2f
	nop

/* Send poweron reset to other master core slave strands. */

	mov	INT_VEC_DIS_TYPE_RESET, %g4
	sllx	%g4, INT_VEC_DIS_TYPE_SHIFT, %g4
	or      %g4, INT_VEC_DIS_VECTOR_RESET, %g4
	sllx	%g1, INT_VEC_DIS_VCID_SHIFT, %g3	! target strand
	or	%g4, %g3, %g3				! int_vec_dis value
	
	!srlx	%g6, 2, %g6
	!sllx	%g6, 18, %g6
	!or	%g6, %g3, %g3
	
	!setx	0x8000000000000000, %g7, %g6
	!or	%g6, %g3, %g3
	
	stx	%g3, [%g5]

2:	
	srlx    %g2, 1, %g2
	inc	%g1
	cmp     %g1, (NSTRANDS-1)
	bleu,pt	%xcc, 1b
	nop
3:

#else /* ifdef T1_FPGA */

	mov	%l2, %g2				! %g2 = strandstartset

	rd	STR_STATUS_REG, %g3
	srlx	%g3, STR_STATUS_CPU_ID_SHIFT, %g3
	and	%g3, STR_STATUS_CPU_ID_MASK, %g3	! %g3 = current cpu
	mov	1, %g4
	sllx	%g4, %g3, %g3
	andn	%g2, %g3, %g2			! remove current cpu from set
	mov	NSTRANDS - 1, %g1

	setx	IOBBASE + INT_VEC_DIS, %g4, %g5
1:	mov	1, %g3
	sllx	%g3, %g1, %g3
	btst	%g2, %g3
	bz,pn	%xcc, 2f
	mov	INT_VEC_DIS_TYPE_RESUME, %g4
	sllx	%g4, INT_VEC_DIS_TYPE_SHIFT, %g4
	sllx	%g1, INT_VEC_DIS_VCID_SHIFT, %g3	! target strand
	or	%g4, %g3, %g3				! int_vec_dis value
	stx	%g3, [%g5]

2:	deccc	%g1
	bgeu,pt	%xcc, 1b
	nop
#endif

	/* 
	 * Master now does its bit of the memory scrubbing.
	 */
#if  defined(CONFIG_FPGA) || defined(T1_FPGA) 
	clr	%g1
	mov	%l0, %g2	! %g2 = membase
	HVCALL(memscrub)	! scrub below hypervisor

	STRAND_STRUCT(%g3)
	ldx	[%g3 + STRAND_SCRUB_BASEPA], %g1
	ldx	[%g3 + STRAND_SCRUB_SIZE], %g2
	HVCALL(memscrub)	! scrub masters slice above hypervisor

	! Now wait until all the other strands are done
#ifdef T1_FPGA
	mov  0, %o1
	set  0xFFFFFF, %o2
1:
	ldx [ %i0 + CONFIG_SCRUB_SYNC ], %g2
	inc   %o1
	andcc %o1, %o2, %g0
	bne,pt %xcc, 3f
	nop
	PRINT(" ")
 	PRINTX(%g2)
3:
	brnz,pt	%g2, 1b
	nop
	PRINT(" done\r\n")
#else /* ifdef T1_FPGA */
1:
	ldx [ %i0 + CONFIG_SCRUB_SYNC ], %g2
	PRINT(" ")
 	PRINTX(%g2)
	brnz,pt	%g2, 1b
	nop
	PRINT(" done\r\n")
#endif /* ifdef T1_FPGA */
#endif /* if  defined(CONFIG_FPGA) || defined(T1_FPGA) */

	mov	%l7, %g7	! restore return address
	HVRET
	SET_SIZE(scrub_all_memory)
