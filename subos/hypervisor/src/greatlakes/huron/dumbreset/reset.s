/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: reset.s
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

#pragma ident	"@(#)reset.s	1.2	07/09/20 SMI"

/*
 * dumbreset - a minimal Niagara reset sequence with the same
 * hypervisor invocation as the real reset/config.  This is useful
 * when running the hypervisor with Legion, Simics, RTL simulation,
 * Axis, etc.
 */

#include <sys/asm_linkage.h>
#include <sparcv9/asi.h>
#include <hprivregs.h>
#include <sun4v/traps.h>
#include <asi.h>
#include <cache.h>
#include <dram.h>
#include <config.h>
		
#define	MEMBASE		(4 * 1024 * 1024)
#define	MEMSIZE		(60 * 1024 * 1024)
#define	LOCK_ADDR	(MEMBASE + MEMSIZE - 16)
#define	LOCK_SIZE	64
#define	HVPD		0x180000
#define	HV_IN_ROM	0xfff0010000
#define	HV_IN_RAM	0x0000100000

#ifdef AXIS
#define	HV		HV_IN_RAM
#else
#define	HV		HV_IN_ROM
#endif

#define	SET_MCU_REG(_reg, _val, _scr1, _scr2) \
	setx	_reg, _scr1, _scr2		;\
	set	_val, _scr1			;\
	stx	_scr1, [_scr2]

#define	SET_MCU(_scr1, _scr2, _bank) \
	SET_MCU_REG((DRAM_BASE + (_bank*DRAM_BANK_STEP) + DRAM_DIMM_INIT_REG), 0x0, _scr1, _scr2)		;\
	SET_MCU_REG((DRAM_BASE + (_bank*DRAM_BANK_STEP) + DRAM_SEL_LO_ADDR_BITS_REG), 0x0, _scr1, _scr2)	;\
	SET_MCU_REG((DRAM_BASE + (_bank*DRAM_BANK_STEP) + DRAM_DIMM_STACK_REG), 0x0, _scr1, _scr2)		;\
	SET_MCU_REG((DRAM_BASE + (_bank*DRAM_BANK_STEP) + DRAM_FBD_CHNL_RESET), 0x1, _scr1, _scr2)

/*
 * Niagara reset trap tables
 */

#define	TRAP_ALIGN_SIZE		32
#define	TRAP_ALIGN		.align TRAP_ALIGN_SIZE
#define	TRAP_ALIGN_BIG		.align (TRAP_ALIGN_SIZE * 4)

#define	TT_TRACE(label)
#define	TT_TRACE_L(label)

#define	TRAP(ttnum, action) \
	.global	r/**/ttnum	;\
	r/**/ttnum:		;\
	action			;\
	TRAP_ALIGN

#define	BIGTRAP(ttnum, action) \
	.global	r/**/ttnum	;\
	r/**/ttnum:		;\
	action			;\
	TRAP_ALIGN_BIG

#define	GOTO(label)		\
	TT_TRACE(trace_gen)	;\
	.global	label		;\
	ba,a	label		;\
	.empty

/* revector to hypervisor */
#define	HREVEC(ttnum)		\
	TT_TRACE(trace_gen)	;\
	mov	ttnum, %g1	;\
	ba,a	revec		;\
	.empty
	

#define	NOT	GOTO(rtrap)
#define	NOT_BIG	NOT NOT NOT NOT
#define	RED	NOT
#define	SAVE_RESTORE	.xword 0x0

/*
 * The basic hypervisor trap table
 */

	.section ".text"
	.align	0x8000
	.global	rtraptable
	.type	rtraptable, #function
rtraptable:
	/* hardware traps */
	TRAP(tt0_000, NOT)		/* reserved */
	TRAP(tt0_001, GOTO(start_reset)) /* power-on reset */
	TRAP(tt0_002, HREVEC(0x2))	/* watchdog reset */
	TRAP(tt0_003, HREVEC(0x3))	/* externally initiated reset */
	TRAP(tt0_004, NOT)		/* software initiated reset */
	TRAP(tt0_005, NOT)		/* red mode exception */
	TRAP(tt0_006, NOT)		/* reserved */
	TRAP(tt0_007, NOT)		/* reserved */
ertraptable:
	.size	rtraptable, (.-rtraptable)
	.global	rtraptable
	.type	rtraptable, #function

	/* 
	 * The section below is for save-restore(checkpointing from Legion to AXIS/Palladium.
	 * In normal runs, when dumbreset is done, it hands off to hv. On a saved and restored
	 * run, it needs to handoff to the restore code. So, during a save, Legion patches in
	 * a non-zero value into this location.
	 */
	.align	0x200
	.section ".text"
	.global save_restore
save_restore:
	SAVE_RESTORE
	.size	save_restore, (.-save_restore)

	ENTRY_NP(start_reset)
	wrpr	%g0, 1, %gl
	wrpr	%g0, 1, %tl
	wrpr	%g0, 0, %cwp

	! set ENB bit
	set	HPSTATE_ENB, %g1
	rdhpr	%hpstate, %g2
	or	%g1, %g2, %g1
	wrhpr	%g1, %hpstate

	set	(LSUCR_DC | LSUCR_IC), %g1
	stxa	%g1, [%g0]ASI_LSUCR

	set	((PSTATE_PRIV | PSTATE_MM_TSO) << TSTATE_PSTATE_SHIFT), %g2
	wrpr	%g2, %pstate	! gl=0 ccr=0 asi=0
	! before exiting RED state, setup htba
	setx	0xfff0000000, %g3, %g2	! XXXQ correct value?
	wrhpr	%g2, %htba
	set	(HPSTATE_HPRIV | HPSTATE_ENB), %g2
	wrhpr	%g2, %hpstate


	mov	CMP_CORE_ID, %g1;
	ldxa	[%g1]ASI_CMP_CORE, %g1;
	andcc	%g1, NSTRANDS - 1, %g0;
	bnz	bypass_mcu_init;
	nop;

	SET_MCU(%g1, %g2, 0)
	SET_MCU(%g1, %g2, 1)
	SET_MCU(%g1, %g2, 2)
	SET_MCU(%g1, %g2, 3)

bypass_mcu_init:
	
	mov	CMP_CORE_ENABLE_STATUS, %g6
	ldxa    [%g6]ASI_CMP_CHIP, %g6    	! get enabled cores

	! find lowest bit set (the 1st nonzero bit) in asi_core_enable	
	clr	%g2				! %g2: initial bit to start btst
	mov	1, %g3				! %g3: bit mask of selected bit
1:
	inc	%g2				! 
	btst	%g3, %g6			! perform btst on bits 0,1,...,x 
	bz,a,pt %xcc, 1b			! until asi_core_enable[x]=1.
	sllx	%g3, 1, %g3			!
	dec	%g2				! 

	mov	CMP_CORE_ID, %g1
	ldxa	[%g1]ASI_CMP_CORE, %g1		! get virtual core id
	and	%g1, 0x3f, %g1			! %g1 - current core id

	! sync up tick regs in all enabled cores with bit masks set to LOCK_ADDR
	wrpr	%g0, %tick
	setx	LOCK_ADDR, %g4, %g3		! the initial mask value is zero
	mov	1, %g5				! set bit mask
	sllx	%g5, %g1, %g5			! (e.g., bit[i]=1 if %g1=i)
2:	
	ldx	[%g3], %g4			! get the old mask
	or	%g4, %g5, %g7			! set the new mask 
	casx	[%g3], %g4, %g7			! try to update [LOCK_ADDR] with 
	cmp	%g4, %g7			!  the new mask
	bne	2b				! try again if update failed 
	nop
	
	! branch out as master or slave (the lowest core becomes master)
	cmp	%g2, %g1
	be,pt	%xcc, .master_entry
	nop

.slave_entry:
	/*
	 * Slave
	 */
	setx	MEMBASE, %g4, %g1 ! Mem base XXX
	setx	MEMSIZE, %g4, %g2 ! Mem size XXX
	setx	HVPD, %g4, %g3	! Partition Description

	setx	save_restore, %g5, %g4	! are we running a checkpointed image?
	ldx	[%g4], %g4
	brnz,pn	%g4, 4f			! yes, then jump to SR code
	nop

	setx	HV, %g5, %g4
	jmp	%g4 + 0x30
	nop
4:
	jmp	%g4 + 0x20
	nop

.master_entry:
	/*
	 * Master
	 */
	mov     CMP_TICK_ENABLE, %g4
	mov     1, %g5
	stxa    %g5, [%g4]ASI_CMP_CHIP
	
	setx	L2_CONTROL_REG, %g2, %g1	! enable L2$ and scrubbing
	setx	L2_SCRUBENABLE | (1<<L2_SCRUBINTERVAL_SHIFT), %g3, %g2
	stx	%g2, [%g1]
	stx	%g2, [%g1 + 0x040]
	stx	%g2, [%g1 + 0x080]
	stx     %g2, [%g1 + 0x0c0]
	stx     %g2, [%g1 + 0x100]
	stx     %g2, [%g1 + 0x140]
	stx     %g2, [%g1 + 0x180]
	stx     %g2, [%g1 + 0x1c0]

	setx	MEMBASE, %g4, %g1 ! Mem base XXX
	setx	MEMSIZE, %g4, %g2 ! Mem size XXX
	setx	HVPD, %g4, %g3	! Partition Description

	mov	CMP_CORE_ENABLE_STATUS, %g6
	ldxa    [%g6]ASI_CMP_CHIP, %g6    	! get enabled cores

	setx	save_restore, %g5, %g4	! are we running a checkpointed image?
	ldx	[%g4], %g4
	brnz,pn	%g4, 5f			! yes, then jump to SR code
	nop

	setx	HV, %g5, %g4
5:	
	jmp	%g4 + 0x20
	mov	%g6, %g4		! %g4:  CPU start set

	SET_SIZE(start_reset)

	ENTRY_NP(rtrap)
	ta	0x1
	SET_SIZE(rtrap)

	! %g1 contains trap# to revector to 
	ENTRY_NP(revec)
	rdhpr	%htba, %g2
	sllx	%g1, 5, %g1
	add	%g2, %g1, %g2
	jmp	%g2
	wrhpr	%g0, (HPSTATE_HPRIV | HPSTATE_ENB), %hpstate
	SET_SIZE(revec)

	!! KEEP THIS AT THE END
	.align	0x100
