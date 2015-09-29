/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T2 Processor File: reset.s
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/
/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

/*
 * OpenSPARC T1 reset sequence
 */

#include <sys/asm_linkage.h>

#include "xilinx_t1_system_config.h"
#include "asi.h"
#include "hprivregs.h"
#include "traps.h"


/*
 * Interrupt Management
*/
#define IOBBASE         0x9800000000
#define INT_MAN         0x000
#define INT_CTL         0x400
#define INT_VEC_DIS     0x800

#define ASI_ERROR_STATUS              0x4c

#define ICACHE_MAX_WAYS               4
#define PIL_15		              0xf


#define BIST_CTL_BISI_MODE	      (1 << 6)
#define BIST_DONE		      (1 << 10)
#define BIST_START		      1

#define BISI_START		      (BIST_CTL_BISI_MODE + BIST_START)



#define STR_STATUS_REG	                %asr26

#define STR_STATUS_STRAND_ACTIVE	1
#define STR_STATUS_STRAND_ID_SHIFT	8
#define STR_STATUS_STRAND_ID_MASK	0x3
#define STR_STATUS_CORE_ID_SHIFT	10
#define STR_STATUS_CORE_ID_MASK		0x7

#define CPU_ID_STRAND_MASK              0x3
#define CPU_ID_STRAND_SHIFT             0x0
#define CPU_ID_CORE_MASK                0x7
#define CPU_ID_CORE_SHIFT               0x2
#define CPU_ID_MASK                     0x1f

#define N_THREADS_PER_CORE              0x4
#define N_THREADS                       0x20


#define STR_STATUS_CPU_ID_SHIFT		STR_STATUS_STRAND_ID_SHIFT
#define STR_STATUS_CPU_ID_MASK		0x1f




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

	ENTRY_NP(start_reset)
#ifdef CONFIG_SAS
	! tick needs to be initialized, this is a hack for SAS
	wrpr	%g0, 0, %tick
#endif

	wrpr	%g0, 1, %gl
	wrpr	%g0, 1, %tl
	wrpr	%g0, 7, %cleanwin
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %wstate
	wrpr	%g0, 0, %cwp
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 5, %cansave
	wrpr	%g0, PSTATE_PRIV, %pstate

	clr	%g1
	mov	NWINDOWS - 1, %g1
1:	wrpr	%g1, %cwp
	clr	%i0
	clr	%i1
	clr	%i2
	clr	%i3
	clr	%i4
	clr	%i5
	clr	%i6
	clr	%i7
	clr	%l0
	clr	%l1
	clr	%l2
	clr	%l3
	clr	%l4
	clr	%l5
	clr	%l6
	deccc   %g1
	bge,pn  %xcc, 1b
	clr	%l7

	! %cwp == 0

	mov	MAXGL, %l0
1:      wrpr    %l0, %gl
        clr	%g1
        clr	%g2
        clr	%g3
        clr	%g4
        clr	%g5
        clr	%g6
        deccc   %l0
        bge,pn  %xcc, 1b
        clr     %g7

	wrpr	%g0, 1, %gl

	! set ENB bit
	set	HPSTATE_ENB, %g1
	rdhpr	%hpstate, %g2
	or	%g1, %g2, %g1
	wrhpr	%g1, %hpstate


	wrpr	%g0, 1, %tl
	set	((PSTATE_PRIV | PSTATE_MM_TSO) << TSTATE_PSTATE_SHIFT), %g2
	wrpr	%g2, %tstate	! gl=0 ccr=0 asi=0
	set	(HPSTATE_HPRIV), %g2
	wrhpr   %g2, %htstate

        call    init_regfile
	nop

	set  	STRAND_STARTSET, %o0
	call    is_core_master
	nop

	brz,pt  %o0, slave_thread
	nop

	call	l1_bisi
	nop

	call	init_icache
	nop

	call	init_dcache
	nop

	call	init_tlbs
	nop

	wrpr	%g0, 1, %gl
	wrpr	%g0, 1, %tl

#ifdef T1_FPGA_DISABLE_DCACHE
	set     (LSUCR_IC), %g1
	stxa    %g1, [%g0]ASI_LSUCR            ! enable Icache
#else
	set     (LSUCR_DC | LSUCR_IC), %g1
	stxa    %g1, [%g0]ASI_LSUCR            ! enable Icache and Dcache
#endif


	set  	STRAND_STARTSET, %o0
	call    is_master_cpu
	nop

	brnz,pt  %o0, master_cpu
	nop

	set  	STRAND_STARTSET, %o0
	call    wakeup_slave_threads
	nop

	brz,pt  %g0, slave_thread
	nop

master_cpu:
	setx	T1_FPGA_HV_MEMBASE, %o5, %g1
	setx	T1_FPGA_HV_MEMSIZE, %o5, %g2
	setx	T1_FPGA_HV_MD_ADDR, %o5, %g3
	set  	STRAND_STARTSET, %g4
	set  	T1_FPGA_TOTAL_MEMSIZE, %g5

	rd	%pc, %o3			! master
	srlx	%o3, 20, %o3
	sllx	%o3, 20, %o3
	set	T1_FPGA_PROM_HV_START_OFFSET, %o4		! next stage start point.

	jmp	%o3 + %o4
	  nop

slave_thread:

	wrpr	%g0, 1, %gl
	wrpr	%g0, 1, %tl

#ifdef T1_FPGA_DISABLE_DCACHE
	set     (LSUCR_IC), %g1
	stxa    %g1, [%g0]ASI_LSUCR            ! enable Icache
#else
	set     (LSUCR_DC | LSUCR_IC), %g1
	stxa    %g1, [%g0]ASI_LSUCR            ! enable Icache and Dcache
#endif

	setx	T1_FPGA_HV_MEMBASE, %o5, %g1
	setx	T1_FPGA_HV_MEMSIZE, %o5, %g2
	setx	T1_FPGA_HV_MD_ADDR, %o5, %g3
	set  	STRAND_STARTSET, %g4
	set  	T1_FPGA_TOTAL_MEMSIZE, %g5

	rd	%pc, %o3			! master
	srlx	%o3, 20, %o3
	sllx	%o3, 20, %o3
	set	T1_FPGA_PROM_HV_START_OFFSET, %o4		! next stage start point.
	add     %o4, 0x10, %o4

	jmp	%o3 + %o4
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



	ENTRY_NP(init_regfile)
	save    %sp, -(MINFRAME64), %sp

        wrpr    %g0, %tba
	wrpr    %g0, PIL_15, %pil

	mov	MAXGL, %l0
1:      wrpr    %l0, %gl
        clr	%g1
        clr	%g2
        clr	%g3
        clr	%g4
        clr	%g5
        clr	%g6
        deccc   %l0
        bge,pn  %xcc, 1b
        clr     %g7

        wr      %g0, %ccr
        wr      %g0, %y
	wr	%g0, %fprs
        wrpr    %g0, 0, %tick

	wrpr    %g0, 6, %tl
	wrpr    %g0, -1, %tpc
	wrpr    %g0, -1, %tnpc
	wrpr    %g0, -1, %tt

	wrpr    %g0, 5, %tl
	wrpr    %g0, -1, %tpc
	wrpr    %g0, -1, %tnpc
	wrpr    %g0, -1, %tt

	wrpr    %g0, 4, %tl
	wrpr    %g0, -1, %tpc
	wrpr    %g0, -1, %tnpc
	wrpr    %g0, -1, %tt

	wrpr    %g0, 3, %tl
	wrpr    %g0, -1, %tpc
	wrpr    %g0, -1, %tnpc
	wrpr    %g0, -1, %tt

	wrpr    %g0, 2, %tl
	wrpr    %g0, -1, %tpc
	wrpr    %g0, -1, %tnpc
	wrpr    %g0, -1, %tt

	wrpr    %g0, 1, %tl
	wrpr    %g0, -1, %tpc
	wrpr    %g0, -1, %tnpc
	wrpr    %g0, -1, %tt

	! tl == 1

	mov	 -1, %g1
	stxa	%g1, [%g0]ASI_ERROR_STATUS	! Clear SPARC Error Status 

	mov	0x18, %g1
	stxa	%g0, [%g1] ASI_IMMU		! Clear IMMU_SFSR
	stxa	%g0, [%g1] ASI_DMMU		! Clear DMMU_SFSR

        rd      %asr26, %g1
        or      %g1, 0x4, %g1                   ! Enable speculative load
        wr      %g1, %g0, %asr26

	ret
        restore

	SET_SIZE(init_regfile)


	ENTRY_NP(is_core_master)

	save    %sp, -(MINFRAME64), %sp

	rd	STR_STATUS_REG, %l0
	srlx	%l0, STR_STATUS_CPU_ID_SHIFT, %l0
	and	%l0, STR_STATUS_CPU_ID_MASK, %l0	! cpu_id

	mov     CPU_ID_STRAND_MASK, %l7
	andn    %l0, %l7, %l1                           ! id of the first cpu in the core

	srlx    %i0, %l1, %l2
	and     %l2, CPU_ID_MASK, %l2

	add     %l1, N_THREADS_PER_CORE, %l3

1:
        andcc   %l2, 1, %g0
        bne,pt %xcc, 2f
	nop
        inc    %l1
	srlx   %l2, 1, %l2
	cmp    %l1, %l3
	bne,pt %xcc, 1b
	nop
2:
	mov  0, %i0
	cmp  %l1, %l0
	movz  %xcc, 1, %i0

	ret
	restore

	SET_SIZE(is_core_master)


	ENTRY_NP(is_master_cpu)

	save    %sp, -(MINFRAME64), %sp

	rd	STR_STATUS_REG, %l0
	srlx	%l0, STR_STATUS_CPU_ID_SHIFT, %l0
	and	%l0, STR_STATUS_CPU_ID_MASK, %l0	! cpu_id

	mov     0, %l1
	mov    %i0, %l2

	mov     N_THREADS, %l3

1:
        andcc   %l2, 1, %g0
        bne,pt %xcc, 2f
	nop
        inc    %l1
	srlx   %l2, 1, %l2
	cmp    %l1, %l3
	bne,pt %xcc, 1b
	nop
2:
	mov  0, %i0
	cmp  %l1, %l0
	movz  %xcc, 1, %i0

	ret
	restore

	SET_SIZE(is_master_cpu)



	ENTRY_NP(wakeup_slave_threads)

	save    %sp, -(MINFRAME64), %sp

	rd	STR_STATUS_REG, %l0
	srlx	%l0, STR_STATUS_CPU_ID_SHIFT, %l0
	and	%l0, STR_STATUS_CPU_ID_MASK, %l0	! cpu_id

	mov     CPU_ID_STRAND_MASK, %l7
	andn    %l0, %l7, %l1                           ! id of the first cpu in the core

	srlx    %i0, %l0, %l2
	and     %l2, CPU_ID_MASK, %l2

	add     %l1, N_THREADS_PER_CORE, %l3

1:
        inc    %l0
	srlx   %l2, 1, %l2
	cmp    %l0, %l3
	beq,pt %xcc, 2f
	nop

        andcc  %l2, 1, %g0
        beq,pt %xcc, 1b
	nop

        setx    IOBBASE + INT_VEC_DIS, %g4, %g5
        mov     INT_VEC_DIS_TYPE_RESET, %g4
        sllx    %g4, INT_VEC_DIS_TYPE_SHIFT, %g4
        or      %g4, INT_VEC_DIS_VECTOR_RESET, %g4

        sllx    %l0, INT_VEC_DIS_VCID_SHIFT, %g3
        or      %g4, %g3, %g3                          
        stx     %g3, [%g5]

	brz,pt  %g0, 1b
	nop

2:
	ret
	restore

	SET_SIZE(wakeup_slave_threads)



	ENTRY_NP(init_tlbs)

	save %sp, -(MINFRAME64), %sp

	stxa	%g0, [%g0]ASI_TLB_INVALIDATE		! ITLB
	mov	0x8, %o1
	stxa	%g0, [%o1]ASI_TLB_INVALIDATE		! DTLB
	membar	#Sync

	ret
	restore

	SET_SIZE(init_tlbs)




	ENTRY_NP(l1_bisi)

	save %sp, -(MINFRAME64), %sp

	set	BIST_START, %l1
!       stxa	%l1, [%g0]ASI_NIAGARA
        nop

!1:     ldxa	[%g0]ASI_NIAGARA, %l0
1:      nop

!       andcc	%l0, BIST_DONE, %l0
        nop

!       be,pt	%xcc, 1b
        nop

	nop

	ret
	restore

	SET_SIZE(l1_bisi)



	ENTRY_NP(init_icache)
        save    %sp, -(MINFRAME64), %sp

        set     (ICACHE_MAX_WAYS - 1), %l0      /* way */
	sllx	%l0, 16, %l2
	set 	(1 << 13), %l1			/* index */ 


!1:     subcc	%l1, (1 << 3), %l1
1:      nop

!       stxa    %g0, [%l1+%l2] ASI_ICACHE_INSTR
        nop

!       bne,pt  %xcc, 1b
        nop

	nop

	set 	(1 << 13), %l1			/* index */ 
	subcc	%l0, 1, %l0
	bge,pt	%xcc, 1b
	sllx	%l0, 16, %l2

	set     (ICACHE_MAX_WAYS - 1), %l0      /* way */
        set     (1 << 13), %l1                  /* index */
        sllx    %l0, 16, %l2

!2:     subcc   %l1, (1 << 6), %l1
2:      nop

!       stxa    %g0, [%l1+%l2] ASI_ICACHE_TAG
        nop

!       bne,pt  %xcc, 2b
        nop

        nop

        set     (1 << 13), %l1                  /* index */
        subcc   %l0, 1, %l0
        bge,pt  %xcc, 2b
        sllx    %l0, 16, %l2

        ret
        restore
	SET_SIZE(init_icache)



/*
 * 	init_dcache - init D$ tag, data
 */

        ENTRY_NP(init_dcache)
        save    %sp, -(MINFRAME64), %sp

        set     (1 << 13), %l0                  /* index */
!1:     subcc   %l0, (1 << 3), %l0
1:      nop

!       stxa    %g0, [%l0]ASI_DC_DATA
        nop

!       bne,pt  %xcc, 1b
        nop

        nop

        set     (1 << 13), %l0                  /* index */
!2:     subcc   %l0, (1 << 4), %l0
2:      nop

!       stxa    %g0, [%l0]ASI_DC_TAG
        nop

!       bne,pt  %xcc, 2b
        nop

        nop

	ret
        restore
        SET_SIZE(init_dcache)



	!! KEEP THIS AT THE END
	.align	0x100
