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

	.ident	"@(#)reset.s	1.18	07/05/03 SMI"

	.file	"reset.s"

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

#if !FOR_ZEUS
#define	MEMBASE		(4 * 1024 * 1024)
#define	MEMSIZE		(60 * 1024 * 1024)
#define	LOCK_ADDR	(MEMBASE + MEMSIZE - 16)
#define	HVPD		0x1f12080000
#define	HV		0xfff0010000
#endif

#ifdef DEBUG_LEGION
#define	CPU_START_SET	0x3
#endif

#define	LOCK_SIZE	64

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
	

#define NOT	GOTO(rtrap)
#define	NOT_BIG	NOT NOT NOT NOT
#define	RED	NOT


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

#if FOR_ZEUS
	.align 8
	.global	hv_info
hv_info:
	.xword 0		/* membase */
	.xword 0		/* memsize */
	.xword 0		/* hv addr */
	.xword 0		/* hv md addr */
	.size	hv_info, (.-hv_info)
#endif

	ENTRY_NP(start_reset)
#ifdef CONFIG_SAS
	! tick needs to be initialized, this is a hack for SAS
	wrpr	%g0, 0, %tick
#endif
	wrpr	%g0, 1, %gl
	wrpr	%g0, 1, %tl
	wrpr	%g0, 0, %cwp

	! set ENB bit
	set	HPSTATE_ENB, %g1
	rdhpr	%hpstate, %g2
	or	%g1, %g2, %g1
	wrhpr	%g1, %hpstate

#ifdef CONFIG_SAS
	! Enable L2 cache prior to enabling L1 caches
	setx	L2_CONTROL_REG, %g2, %g1
	stx	%g0, [%g1 + 0x00]
	stx	%g0, [%g1 + 0x40]
	stx	%g0, [%g1 + 0x80]
	stx	%g0, [%g1 + 0xc0]
#endif

	set	(LSUCR_DC | LSUCR_IC), %g1
	stxa	%g1, [%g0]ASI_LSUCR

	set	((PSTATE_PRIV | PSTATE_MM_TSO) << TSTATE_PSTATE_SHIFT), %g2
	wrpr	%g2, %pstate	! gl=0 ccr=0 asi=0
	! before exiting RED state, setup htba
	setx	0xfff0000000, %g3, %g2	! XXXQ correct value?
	wrhpr	%g2, %htba
	set	(HPSTATE_HPRIV | HPSTATE_ENB), %g2
	wrhpr	%g2, %hpstate

	rd	%asr26, %g1
	srlx	%g1, 8, %g1
	and	%g1, 0x1f, %g5	! %g5 - current cpu id
	inc	%g5		! number from 1..32

#if FOR_ZEUS /* { */
local1:
	rd	%pc, %g6
	add	%g6, hv_info - local1, %g6
	ldx	[%g6], %g1	! Mem base
	ldx	[%g6+8], %g2	! Mem size
	ldx	[%g6+16], %g3	! Machine description location
	ldx	[%g6+24], %g4	! Hypervisor ROM location
#else	/* } { */
	setx	MEMBASE, %g6, %g1 ! Mem base XXX
	setx	MEMSIZE, %g6, %g2 ! Mem size XXX
	setx	HVPD, %g6, %g3	! Partition Description
	setx	HV, %g6, %g4

#endif	/* } */

	sub	%g2, LOCK_SIZE, %g2	! Hide lock location from HV
	add	%g1, %g2, %g7		! Addr of lock location

	ldx	[%g7], %g6
	brnz	%g6, .slave_entry
	  nop

	casxa	[%g7]ASI_N, %g6, %g5
	cmp	%g6, %g5
	be,pt	%xcc, .master_entry
	  nop


	/*
	 * Slave
	 */

.slave_entry:
1:	ldx	[%g7], %g5
	cmp	%g5, -1
	bne,pn	%xcc, 1b	! wait for copy to complete
	  nop

	add	%g4, 0x30, %g4	! Slave entry point
	jmp	%g4
	  nop


	/*
	 * Master
	 */

.master_entry:
		/* IDLE all of the other strands */
	rd	%asr26, %g6
	srlx	%g6, 8, %g6
	and	%g6, 0x1f, %g6	! %g6 - current strand id

	setx	0x9800000800, %g4, %g5 ! int_vec_dis address
	mov	31, %g1
1:	cmp	%g1, %g6
	be,pn	%xcc, 2f	! skip our strand
	nop

	mov	2, %g2		! IDLE command
	sllx	%g2, 16, %g2
	sllx	%g1, 8, %g3	! target strand
	or	%g2, %g3, %g2	! int_vec_dis value
	stx	%g2, [%g5]

2:	deccc	%g1
	bgeu,pt	%xcc, 1b
	nop

		/* Allow them to continue when they wake up */
	mov	-1, %g1
	stx	%g1, [%g7]

		/*
		 * re-init parameters
		 */

#if FOR_ZEUS /* { */
local2:
	rd	%pc, %g6
	add	%g6, hv_info - local2, %g6
	ldx	[%g6], %g1	! Mem base
	ldx	[%g6+8], %g2	! Mem size
	ldx	[%g6+16], %g3	! Machine description location
	ldx	[%g6+24], %g6	! Hypervisor ROM location
#else	/* } { */
	setx	MEMBASE, %g6, %g1 ! Mem base XXX
	setx	MEMSIZE, %g6, %g2 ! Mem size XXX
	setx	HVPD, %g6, %g3	! Partition Description
	setx	HV, %g4, %g6
#endif	/* } */

	! %g4 = cpustartset
	mov     -1, %g4
	srl     %g4, 0, %g4     ! %g4 now contains 0xffff.ffff

	! %g5 = phys mem - only used for scrubbing on real HW so we can use 0x0
	mov     %g0, %g5

        sub     %g2, LOCK_SIZE, %g2     ! Hide lock

	add	%g6, 0x20, %g6
	jmp	%g6
	nop
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
