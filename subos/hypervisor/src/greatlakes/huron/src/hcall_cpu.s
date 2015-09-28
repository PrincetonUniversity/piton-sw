/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_cpu.s
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

	.ident	"@(#)hcall_cpu.s	1.2	07/07/03 SMI"

	.file	"hcall_cpu.s"

#include <sys/asm_linkage.h>
#include <asi.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <hprivregs.h>
#include <hypervisor.h>
#include <ncu.h>
#include <offsets.h>
#include <config.h>
#include <util.h>
#include <clock.h>
#include <cmp.h>
#include <debug.h>
#ifdef	SUPPORT_NIAGARA2_1x
#include <cache.h>
#include <dram.h>
#endif

/*
 * Halt the current strand
 *
 * %g1 - %g6	clobbered
 * %g7		return address
 */
	ENTRY_NP(plat_halt_strand)

	/*
	 * The set of conditions where the halt instruction will "fall
	 * through" is described in the PRM.  However, the set doesn't
	 * include a pending cpu, device or error queue interrupt.  To
	 * avoid halting this strand with a pending interrupt, check for
	 * those first.
	 */
	mov	CPU_MONDO_QUEUE_HEAD, %g1
	ldxa	[%g1]ASI_QUEUE, %g1
	mov	CPU_MONDO_QUEUE_TAIL, %g2
	ldxa	[%g2]ASI_QUEUE, %g2
	cmp	%g1, %g2
	bne,pn	%xcc, plat_halt_strand_exit
	mov	DEV_MONDO_QUEUE_HEAD, %g1
	ldxa	[%g1]ASI_QUEUE, %g1
	mov	DEV_MONDO_QUEUE_TAIL, %g2
	ldxa	[%g2]ASI_QUEUE, %g2
	cmp	%g1, %g2
	bne,pn	%xcc, plat_halt_strand_exit
	mov	ERROR_RESUMABLE_QUEUE_HEAD, %g1
	ldxa	[%g1]ASI_QUEUE, %g1
	mov	ERROR_RESUMABLE_QUEUE_TAIL, %g2
	ldxa	[%g2]ASI_QUEUE, %g2
	cmp	%g1, %g2
	bne,pn	%xcc, plat_halt_strand_exit
	nop

	HALT_STRAND()

plat_halt_strand_exit:

	HVRET

	SET_SIZE(plat_halt_strand)


#ifdef	SUPPORT_NIAGARA2_1x
/* Serial Number Register */
#define	SERIAL_NUMBER			0x8000001000

/* DRAM CAS Address Width Register (Count 4 Step 4096) */
#define	DRAM_CAS_ADDR_WIDTH_REG0	0x8400000000
#define	DRAM_CAS_ADDR_WIDTH_REG1	0x8400001000
#define	DRAM_CAS_ADDR_WIDTH_REG2	0x8400002000
#define	DRAM_CAS_ADDR_WIDTH_REG3	0x8400003000

/* PLL Control Register */
#define	PLL_CONTROL_REG			(CLK_BASE + PLL_CTL_REG)

/* PLL Lock Time Register */
#define	PLL_LOCK_TIME_REG		0x8900000870

/* PEU Control Register */
#define	PEU_CTRL_REG			0x8800680000

/* Debug Port Configuration Register */
#define	DEBUG_PORT_CFG_REG		0x8600000000	


#define	TABLE_TWEAK(table, reg, bank, scr1, scr2)			\
	.pushlocals							;\
	/* skip banks which are disabled.  causes hang. */  		;\
	SKIP_DISABLED_DRAM_BANK(bank, scr1, scr2, 0f)			;\
	setx	reg, scr2, scr1						;\
	stx	scr1, [table + (bank * 8)]				;\
0:	.poplocals


	ENTRY_NP(init_cpu_yield_table)
	mov	%g7, %l7	/* save return address */
	PRINT("HV:init_cpu_yield_table\r\n")

	LABEL_ADDRESS(niagara2_cpu_yield_paddr_table, %g1)

	TABLE_TWEAK(%g1, DRAM_CAS_ADDR_WIDTH_REG0, /* bank */ 0, %g2, %g3)
	TABLE_TWEAK(%g1, DRAM_CAS_ADDR_WIDTH_REG1, /* bank */ 1, %g2, %g3)
	TABLE_TWEAK(%g1, DRAM_CAS_ADDR_WIDTH_REG2, /* bank */ 2, %g2, %g3)
	TABLE_TWEAK(%g1, DRAM_CAS_ADDR_WIDTH_REG3, /* bank */ 3, %g2, %g3)

	jmp	%l7 + 4
	nop
	SET_SIZE(init_cpu_yield_table)


	.section ".text"
	.align	8
	.global	niagara2_cpu_yield_paddr_table
niagara2_cpu_yield_paddr_table:
	.xword SERIAL_NUMBER
	.xword SERIAL_NUMBER
	.xword SERIAL_NUMBER
	.xword SERIAL_NUMBER
	.xword PLL_CONTROL_REG
	.xword PLL_LOCK_TIME_REG
	.xword PEU_CTRL_REG
	.xword DEBUG_PORT_CFG_REG
#endif	/* SUPPORT_NIAGARA2_1x */
