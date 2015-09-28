/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traptable.s
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
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)traptable.s	1.6	05/04/26 SMI"

	.file	"traptable.s"

#include <sys/asm_linkage.h>
#include <sys/stack.h>
#include <sys/privregs.h>
#include <hypervisor.h>

#define	TRAP_ALIGN_SIZE		32
#define	TRAP_ALIGN		.align TRAP_ALIGN_SIZE
#define	TRAP_ALIGN_BIG		.align (TRAP_ALIGN_SIZE * 4)

#define	TRAP(ttnum, action) \
	ENTRY(ttnum)		;\
	action			;\
	TRAP_ALIGN		;\
	SET_SIZE(ttnum)

#define	BIGTRAP(ttnum, action) \
	ENTRY(ttnum)		;\
	action			;\
	TRAP_ALIGN_BIG		;\
	SET_SIZE(ttnum)

#define	GOTO(label)		\
	.global	label		;\
	ba,a	label		;\
	.empty

#define NOT	GOTO(__badtrap)
#define	NOT_BIG	NOT NOT NOT NOT
#define	RED	NOT

#define SOFTTRAP	\
	mov EBADTRAP, %o0;\
	mov	0x11, %g1;\
	sllx	%g1, 32, %g1;\
	rdpr	%tstate, %g2;\
	or	%g1, %g2, %g2;\
	wrpr	%g2, %tstate;\
	done

/*
 * Basic register window handling
 */
#define	CLEAN_WINDOW                                            \
        rdpr %cleanwin, %l0; inc %l0; wrpr %l0, %cleanwin       ;\
        clr %l0; clr %l1; clr %l2; clr %l3                      ;\
        clr %l4; clr %l5; clr %l6; clr %l7                      ;\
        clr %o0; clr %o1; clr %o2; clr %o3                      ;\
        clr %o4; clr %o5; clr %o6; clr %o7                      ;\
        retry

#define SPILL_WINDOW						\
	andcc	%o6, 1, %g0					;\
	be,pt	%xcc, 0f					;\
	wr	%g0, 0x80, %asi					;\
	stxa	%l0, [%o6+V9BIAS64+(0*8)]%asi			;\
	stxa	%l1, [%o6+V9BIAS64+(1*8)]%asi			;\
	stxa	%l2, [%o6+V9BIAS64+(2*8)]%asi			;\
	stxa	%l3, [%o6+V9BIAS64+(3*8)]%asi			;\
	stxa	%l4, [%o6+V9BIAS64+(4*8)]%asi			;\
	stxa	%l5, [%o6+V9BIAS64+(5*8)]%asi			;\
	stxa	%l6, [%o6+V9BIAS64+(6*8)]%asi			;\
	stxa	%l7, [%o6+V9BIAS64+(7*8)]%asi			;\
	stxa	%i0, [%o6+V9BIAS64+(8*8)]%asi			;\
	stxa	%i1, [%o6+V9BIAS64+(9*8)]%asi			;\
	stxa	%i2, [%o6+V9BIAS64+(10*8)]%asi			;\
	stxa	%i3, [%o6+V9BIAS64+(11*8)]%asi			;\
	stxa	%i4, [%o6+V9BIAS64+(12*8)]%asi			;\
	stxa	%i5, [%o6+V9BIAS64+(13*8)]%asi			;\
	stxa	%i6, [%o6+V9BIAS64+(14*8)]%asi			;\
	stxa	%i7, [%o6+V9BIAS64+(15*8)]%asi			;\
	ba	1f						;\
	nop							;\
0:	srl	%o6, 0, %o6					;\
	stda	%i0, [%o6+(0*8)] %asi				;\
	stda	%i2, [%o6+(1*8)] %asi				;\
	stda	%i4, [%o6+(2*8)] %asi				;\
	stda	%i6, [%o6+(3*8)] %asi				;\
	stda	%l0, [%o6+(4*8)] %asi				;\
	stda	%l2, [%o6+(5*8)] %asi				;\
	stda	%l4, [%o6+(6*8)] %asi				;\
	stda	%l6, [%o6+(7*8)] %asi				;\
1:	saved							;\
	retry

#define FILL_WINDOW						\
	andcc	%o6, 1, %g0					;\
	be,pt	%xcc, 0f					;\
	wr	%g0, 0x80, %asi					;\
	ldxa	[%o6+V9BIAS64+(0*8)]%asi, %l0 			;\
	ldxa	[%o6+V9BIAS64+(1*8)]%asi, %l1 			;\
	ldxa	[%o6+V9BIAS64+(2*8)]%asi, %l2 			;\
	ldxa	[%o6+V9BIAS64+(3*8)]%asi, %l3 			;\
	ldxa	[%o6+V9BIAS64+(4*8)]%asi, %l4 			;\
	ldxa	[%o6+V9BIAS64+(5*8)]%asi, %l5 			;\
	ldxa	[%o6+V9BIAS64+(6*8)]%asi, %l6 			;\
	ldxa	[%o6+V9BIAS64+(7*8)]%asi, %l7 			;\
	ldxa	[%o6+V9BIAS64+(8*8)]%asi, %i0 			;\
	ldxa	[%o6+V9BIAS64+(9*8)]%asi, %i1 			;\
	ldxa	[%o6+V9BIAS64+(10*8)]%asi, %i2 			;\
	ldxa	[%o6+V9BIAS64+(11*8)]%asi, %i3 			;\
	ldxa	[%o6+V9BIAS64+(12*8)]%asi, %i4 			;\
	ldxa	[%o6+V9BIAS64+(13*8)]%asi, %i5 			;\
	ldxa	[%o6+V9BIAS64+(14*8)]%asi, %i6 			;\
	ldxa	[%o6+V9BIAS64+(15*8)]%asi, %i7 			;\
	ba	1f						;\
	nop							;\
0:	srl	%o6, 0, %o6					;\
	ldda	[%o6+(0*8)] %asi, %i0				;\
	ldda	[%o6+(1*8)] %asi, %i2				;\
	ldda	[%o6+(2*8)] %asi, %i4				;\
	ldda	[%o6+(3*8)] %asi, %i6				;\
	ldda	[%o6+(4*8)] %asi, %l0				;\
	ldda	[%o6+(5*8)] %asi, %l2				;\
	ldda	[%o6+(6*8)] %asi, %l4				;\
	ldda	[%o6+(7*8)] %asi, %l6				;\
1:	restored						;\
	retry

/*
 * The basic Guest trap table
 */
#if defined(lint)
void traptable0(void) {}
#else
	ENTRY(traptable0)
	/* hardware traps */
	TRAP(tt0_000, NOT)		/* reserved */
	TRAP(tt0_001, GOTO(por))	/* power-on reset */
	TRAP(tt0_002, GOTO(watchdog))	/* watchdog reset */
	TRAP(tt0_003, GOTO(xir))	/* externally initiated reset */
	TRAP(tt0_004, NOT)		/* software initiated reset */
	TRAP(tt0_005, NOT)		/* red mode exception */
	TRAP(tt0_006, NOT)		/* reserved */
	TRAP(tt0_007, NOT)		/* reserved */
	TRAP(tt0_008, NOT)		/* instruction access exception */
	TRAP(tt0_009, NOT)		/* instruction access mmu miss */
	TRAP(tt0_00a, NOT)		/* instruction access error */
	TRAP(tt0_00b, NOT)		/* reserved */
	TRAP(tt0_00c, NOT)		/* reserved */
	TRAP(tt0_00d, NOT)		/* reserved */
	TRAP(tt0_00e, NOT)		/* reserved */
	TRAP(tt0_00f, NOT)		/* reserved */
	TRAP(tt0_010, NOT)		/* illegal instruction */
	TRAP(tt0_011, NOT)		/* privileged opcode */
	TRAP(tt0_012, NOT)		/* unimplemented LDD */
	TRAP(tt0_013, NOT)		/* unimplemented STD */
	TRAP(tt0_014, NOT)		/* reserved */
	TRAP(tt0_015, NOT)		/* reserved */
	TRAP(tt0_016, NOT)		/* reserved */
	TRAP(tt0_017, NOT)		/* reserved */
	TRAP(tt0_018, NOT)		/* reserved */
	TRAP(tt0_019, NOT)		/* reserved */
	TRAP(tt0_01a, NOT)		/* reserved */
	TRAP(tt0_01b, NOT)		/* reserved */
	TRAP(tt0_01c, NOT)		/* reserved */
	TRAP(tt0_01d, NOT)		/* reserved */
	TRAP(tt0_01e, NOT)		/* reserved */
	TRAP(tt0_01f, NOT)		/* reserved */
	TRAP(tt0_020, NOT)		/* fp disabled */
	TRAP(tt0_021, NOT)		/* fp exception ieee 754 */
	TRAP(tt0_022, NOT)		/* fp exception other */
	TRAP(tt0_023, NOT)		/* tag overflow */
	BIGTRAP(tt0_024, CLEAN_WINDOW)	/* clean window */
	TRAP(tt0_028, NOT)		/* division by zero */
	TRAP(tt0_029, NOT)		/* internal processor error */
	TRAP(tt0_02a, NOT)		/* reserved */
	TRAP(tt0_02b, NOT)		/* reserved */
	TRAP(tt0_02c, NOT)		/* reserved */
	TRAP(tt0_02d, NOT)		/* reserved */
	TRAP(tt0_02e, NOT)		/* reserved */
	TRAP(tt0_02f, NOT)		/* reserved */
	TRAP(tt0_030, NOT)		/* data access exception */
	TRAP(tt0_031, NOT)		/* data access mmu miss */
	TRAP(tt0_032, NOT)		/* data access error */
	TRAP(tt0_033, NOT)		/* data access protection */
	TRAP(tt0_034, NOT)		/* mem address not aligned */
	TRAP(tt0_035, NOT)		/* lddf mem address not aligned */
	TRAP(tt0_036, NOT)		/* stdf mem address not aligned */
	TRAP(tt0_037, NOT)		/* privileged action */
	TRAP(tt0_038, NOT)		/* ldqf mem address not aligned */
	TRAP(tt0_039, NOT)		/* stqf mem address not aligned */
	TRAP(tt0_03a, NOT)		/* reserved */
	TRAP(tt0_03b, NOT)		/* reserved */
	TRAP(tt0_03c, NOT)		/* reserved */
	TRAP(tt0_03d, NOT)		/* reserved */
	TRAP(tt0_03e, NOT)		/* reserved */
	TRAP(tt0_03f, NOT)		/* HV: real translation miss */
	TRAP(tt0_040, NOT)		/* async data error */
	TRAP(tt0_041, NOT)		/* interrupt level 1 */
	TRAP(tt0_042, NOT)		/* interrupt level 2 */
	TRAP(tt0_043, NOT)		/* interrupt level 3 */
	TRAP(tt0_044, NOT)		/* interrupt level 4 */
	TRAP(tt0_045, NOT)		/* interrupt level 5 */
	TRAP(tt0_046, NOT)		/* interrupt level 6 */
	TRAP(tt0_047, NOT)		/* interrupt level 7 */
	TRAP(tt0_048, NOT)		/* interrupt level 8 */
	TRAP(tt0_049, NOT)		/* interrupt level 9 */
	TRAP(tt0_04a, NOT)		/* interrupt level a */
	TRAP(tt0_04b, NOT)		/* interrupt level b */
	TRAP(tt0_04c, NOT)		/* interrupt level c */
	TRAP(tt0_04d, NOT)		/* interrupt level d */
	TRAP(tt0_04e, NOT)		/* interrupt level e */
	TRAP(tt0_04f, NOT)		/* interrupt level f */
	TRAP(tt0_050, NOT)		/* reserved */
	TRAP(tt0_051, NOT)		/* reserved */
	TRAP(tt0_052, NOT)		/* reserved */
	TRAP(tt0_053, NOT)		/* reserved */
	TRAP(tt0_054, NOT)		/* reserved */
	TRAP(tt0_055, NOT)		/* reserved */
	TRAP(tt0_056, NOT)		/* reserved */
	TRAP(tt0_057, NOT)		/* reserved */
	TRAP(tt0_058, NOT)		/* reserved */
	TRAP(tt0_059, NOT)		/* reserved */
	TRAP(tt0_05a, NOT)		/* reserved */
	TRAP(tt0_05b, NOT)		/* reserved */
	TRAP(tt0_05c, NOT)		/* reserved */
	TRAP(tt0_05d, NOT)		/* reserved */
	TRAP(tt0_05e, NOT)		/* HV: hstick match */
	TRAP(tt0_05f, NOT)		/* reserved */
	TRAP(tt0_060, NOT)		/* interrupt vector */
	TRAP(tt0_061, NOT)		/* RA watchpoint */
	TRAP(tt0_062, NOT)		/* VA watchpoint */
	TRAP(tt0_063, NOT)		/* corrected ECC error XXX */
	BIGTRAP(tt0_064, NOT)		/* fast instruction access MMU miss */
	BIGTRAP(tt0_068, NOT)		/* fast data access MMU miss */
	BIGTRAP(tt0_06C, NOT)		/* fast data access protection */
	TRAP(tt0_070, NOT)		/* reserved */
	TRAP(tt0_071, NOT)		/* reserved */
	TRAP(tt0_072, NOT)		/* reserved */
	TRAP(tt0_073, NOT)		/* reserved */
	TRAP(tt0_074, NOT)		/* reserved */
	TRAP(tt0_075, NOT)		/* reserved */
	TRAP(tt0_076, NOT)		/* reserved */
	TRAP(tt0_077, NOT)		/* reserved */
	TRAP(tt0_078, NOT)		/* reserved */
	TRAP(tt0_079, NOT)		/* reserved */
	TRAP(tt0_07a, NOT)		/* reserved */
	TRAP(tt0_07b, NOT)		/* reserved */
	TRAP(tt0_07c, NOT)		/* HV: cpu mondo */
	TRAP(tt0_07d, NOT)		/* HV: dev mondo */
	TRAP(tt0_07e, NOT)		/* HV: resumable error */
	TRAP(tt0_07f, NOT)		/* HV: non-resumable error */
	BIGTRAP(tt0_080, SPILL_WINDOW)	/* spill 0 normal */
	BIGTRAP(tt0_084, SPILL_WINDOW)	/* spill 1 normal */
	BIGTRAP(tt0_088, SPILL_WINDOW)	/* spill 2 normal */
	BIGTRAP(tt0_08c, SPILL_WINDOW)	/* spill 3 normal */
	BIGTRAP(tt0_090, SPILL_WINDOW)	/* spill 4 normal */
	BIGTRAP(tt0_094, SPILL_WINDOW)	/* spill 5 normal */
	BIGTRAP(tt0_098, SPILL_WINDOW)	/* spill 6 normal */
	BIGTRAP(tt0_09c, SPILL_WINDOW)	/* spill 7 normal */
	BIGTRAP(tt0_0a0, SPILL_WINDOW)	/* spill 0 other */
	BIGTRAP(tt0_0a4, SPILL_WINDOW)	/* spill 1 other */
	BIGTRAP(tt0_0a8, SPILL_WINDOW)	/* spill 2 other */
	BIGTRAP(tt0_0ac, SPILL_WINDOW)	/* spill 3 other */
	BIGTRAP(tt0_0b0, SPILL_WINDOW)	/* spill 4 other */
	BIGTRAP(tt0_0b4, SPILL_WINDOW)	/* spill 5 other */
	BIGTRAP(tt0_0b8, SPILL_WINDOW)	/* spill 6 other */
	BIGTRAP(tt0_0bc, SPILL_WINDOW)	/* spill 7 other */
	BIGTRAP(tt0_0c0, FILL_WINDOW)	/* fill 0 normal */
	BIGTRAP(tt0_0c4, FILL_WINDOW)	/* fill 1 normal */
	BIGTRAP(tt0_0c8, FILL_WINDOW)	/* fill 2 normal */
	BIGTRAP(tt0_0cc, FILL_WINDOW)	/* fill 3 normal */
	BIGTRAP(tt0_0d0, FILL_WINDOW)	/* fill 4 normal */
	BIGTRAP(tt0_0d4, FILL_WINDOW)	/* fill 5 normal */
	BIGTRAP(tt0_0d8, FILL_WINDOW)	/* fill 6 normal */
	BIGTRAP(tt0_0dc, FILL_WINDOW)	/* fill 7 normal */
	BIGTRAP(tt0_0e0, FILL_WINDOW)	/* fill 0 other */
	BIGTRAP(tt0_0e4, FILL_WINDOW)	/* fill 1 other */
	BIGTRAP(tt0_0e8, FILL_WINDOW)	/* fill 2 other */
	BIGTRAP(tt0_0ec, FILL_WINDOW)	/* fill 3 other */
	BIGTRAP(tt0_0f0, FILL_WINDOW)	/* fill 4 other */
	BIGTRAP(tt0_0f4, FILL_WINDOW)	/* fill 5 other */
	BIGTRAP(tt0_0f8, FILL_WINDOW)	/* fill 6 other */
	BIGTRAP(tt0_0fc, FILL_WINDOW)	/* fill 7 other */
	TRAP(tt0_100, SOFTTRAP)		/* software trap */
	TRAP(tt0_101, SOFTTRAP)		/* software trap */
	TRAP(tt0_102, SOFTTRAP)		/* software trap */
	TRAP(tt0_103, SOFTTRAP)		/* software trap */
	TRAP(tt0_104, SOFTTRAP)		/* software trap */
	TRAP(tt0_105, SOFTTRAP)		/* software trap */
	TRAP(tt0_106, SOFTTRAP)		/* software trap */
	TRAP(tt0_107, SOFTTRAP)		/* software trap */
	TRAP(tt0_108, SOFTTRAP)		/* software trap */
	TRAP(tt0_109, SOFTTRAP)		/* software trap */
	TRAP(tt0_10a, SOFTTRAP)		/* software trap */
	TRAP(tt0_10b, SOFTTRAP)		/* software trap */
	TRAP(tt0_10c, SOFTTRAP)		/* software trap */
	TRAP(tt0_10d, SOFTTRAP)		/* software trap */
	TRAP(tt0_10e, SOFTTRAP)		/* software trap */
	TRAP(tt0_10f, SOFTTRAP)		/* software trap */
	TRAP(tt0_110, SOFTTRAP)		/* software trap */
	TRAP(tt0_111, SOFTTRAP)		/* software trap */
	TRAP(tt0_112, SOFTTRAP)		/* software trap */
	TRAP(tt0_113, SOFTTRAP)		/* software trap */
	TRAP(tt0_114, SOFTTRAP)		/* software trap */
	TRAP(tt0_115, SOFTTRAP)		/* software trap */
	TRAP(tt0_116, SOFTTRAP)		/* software trap */
	TRAP(tt0_117, SOFTTRAP)		/* software trap */
	TRAP(tt0_118, SOFTTRAP)		/* software trap */
	TRAP(tt0_119, SOFTTRAP)		/* software trap */
	TRAP(tt0_11a, SOFTTRAP)		/* software trap */
	TRAP(tt0_11b, SOFTTRAP)		/* software trap */
	TRAP(tt0_11c, SOFTTRAP)		/* software trap */
	TRAP(tt0_11d, SOFTTRAP)		/* software trap */
	TRAP(tt0_11e, SOFTTRAP)		/* software trap */
	TRAP(tt0_11f, SOFTTRAP)		/* software trap */
	TRAP(tt0_120, SOFTTRAP)		/* software trap */
	TRAP(tt0_121, SOFTTRAP)		/* software trap */
	TRAP(tt0_122, SOFTTRAP)		/* software trap */
	TRAP(tt0_123, SOFTTRAP)		/* software trap */
	TRAP(tt0_124, SOFTTRAP)		/* software trap */
	TRAP(tt0_125, SOFTTRAP)		/* software trap */
	TRAP(tt0_126, SOFTTRAP)		/* software trap */
	TRAP(tt0_127, SOFTTRAP)		/* software trap */
	TRAP(tt0_128, SOFTTRAP)		/* software trap */
	TRAP(tt0_129, SOFTTRAP)		/* software trap */
	TRAP(tt0_12a, SOFTTRAP)		/* software trap */
	TRAP(tt0_12b, SOFTTRAP)		/* software trap */
	TRAP(tt0_12c, SOFTTRAP)		/* software trap */
	TRAP(tt0_12d, SOFTTRAP)		/* software trap */
	TRAP(tt0_12e, SOFTTRAP)		/* software trap */
	TRAP(tt0_12f, SOFTTRAP)		/* software trap */
	TRAP(tt0_130, SOFTTRAP)		/* software trap */
	TRAP(tt0_131, SOFTTRAP)		/* software trap */
	TRAP(tt0_132, SOFTTRAP)		/* software trap */
	TRAP(tt0_133, SOFTTRAP)		/* software trap */
	TRAP(tt0_134, SOFTTRAP)		/* software trap */
	TRAP(tt0_135, SOFTTRAP)		/* software trap */
	TRAP(tt0_136, SOFTTRAP)		/* software trap */
	TRAP(tt0_137, SOFTTRAP)		/* software trap */
	TRAP(tt0_138, SOFTTRAP)		/* software trap */
	TRAP(tt0_139, SOFTTRAP)		/* software trap */
	TRAP(tt0_13a, SOFTTRAP)		/* software trap */
	TRAP(tt0_13b, SOFTTRAP)		/* software trap */
	TRAP(tt0_13c, SOFTTRAP)		/* software trap */
	TRAP(tt0_13d, SOFTTRAP)		/* software trap */
	TRAP(tt0_13e, SOFTTRAP)		/* software trap */
	TRAP(tt0_13f, SOFTTRAP)		/* software trap */
	TRAP(tt0_140, SOFTTRAP)		/* software trap */
	TRAP(tt0_141, SOFTTRAP)		/* software trap */
	TRAP(tt0_142, SOFTTRAP)		/* software trap */
	TRAP(tt0_143, SOFTTRAP)		/* software trap */
	TRAP(tt0_144, SOFTTRAP)		/* software trap */
	TRAP(tt0_145, SOFTTRAP)		/* software trap */
	TRAP(tt0_146, SOFTTRAP)		/* software trap */
	TRAP(tt0_147, SOFTTRAP)		/* software trap */
	TRAP(tt0_148, SOFTTRAP)		/* software trap */
	TRAP(tt0_149, SOFTTRAP)		/* software trap */
	TRAP(tt0_14a, SOFTTRAP)		/* software trap */
	TRAP(tt0_14b, SOFTTRAP)		/* software trap */
	TRAP(tt0_14c, SOFTTRAP)		/* software trap */
	TRAP(tt0_14d, SOFTTRAP)		/* software trap */
	TRAP(tt0_14e, SOFTTRAP)		/* software trap */
	TRAP(tt0_14f, SOFTTRAP)		/* software trap */
	TRAP(tt0_150, SOFTTRAP)		/* software trap */
	TRAP(tt0_151, SOFTTRAP)		/* software trap */
	TRAP(tt0_152, SOFTTRAP)		/* software trap */
	TRAP(tt0_153, SOFTTRAP)		/* software trap */
	TRAP(tt0_154, SOFTTRAP)		/* software trap */
	TRAP(tt0_155, SOFTTRAP)		/* software trap */
	TRAP(tt0_156, SOFTTRAP)		/* software trap */
	TRAP(tt0_157, SOFTTRAP)		/* software trap */
	TRAP(tt0_158, SOFTTRAP)		/* software trap */
	TRAP(tt0_159, SOFTTRAP)		/* software trap */
	TRAP(tt0_15a, SOFTTRAP)		/* software trap */
	TRAP(tt0_15b, SOFTTRAP)		/* software trap */
	TRAP(tt0_15c, SOFTTRAP)		/* software trap */
	TRAP(tt0_15d, SOFTTRAP)		/* software trap */
	TRAP(tt0_15e, SOFTTRAP)		/* software trap */
	TRAP(tt0_15f, SOFTTRAP)		/* software trap */
	TRAP(tt0_160, SOFTTRAP)		/* software trap */
	TRAP(tt0_161, SOFTTRAP)		/* software trap */
	TRAP(tt0_162, SOFTTRAP)		/* software trap */
	TRAP(tt0_163, SOFTTRAP)		/* software trap */
	TRAP(tt0_164, SOFTTRAP)		/* software trap */
	TRAP(tt0_165, SOFTTRAP)		/* software trap */
	TRAP(tt0_166, SOFTTRAP)		/* software trap */
	TRAP(tt0_167, SOFTTRAP)		/* software trap */
	TRAP(tt0_168, SOFTTRAP)		/* software trap */
	TRAP(tt0_169, SOFTTRAP)		/* software trap */
	TRAP(tt0_16a, SOFTTRAP)		/* software trap */
	TRAP(tt0_16b, SOFTTRAP)		/* software trap */
	TRAP(tt0_16c, SOFTTRAP)		/* software trap */
	TRAP(tt0_16d, SOFTTRAP)		/* software trap */
	TRAP(tt0_16e, SOFTTRAP)		/* software trap */
	TRAP(tt0_16f, SOFTTRAP)		/* software trap */
	TRAP(tt0_170, SOFTTRAP)		/* software trap */
	TRAP(tt0_171, SOFTTRAP)		/* software trap */
	TRAP(tt0_172, SOFTTRAP)		/* software trap */
	TRAP(tt0_173, SOFTTRAP)		/* software trap */
	TRAP(tt0_174, SOFTTRAP)		/* software trap */
	TRAP(tt0_175, SOFTTRAP)		/* software trap */
	TRAP(tt0_176, SOFTTRAP)		/* software trap */
	TRAP(tt0_177, SOFTTRAP)		/* software trap */
	TRAP(tt0_178, SOFTTRAP)		/* software trap */
	TRAP(tt0_179, SOFTTRAP)		/* software trap */
	TRAP(tt0_17a, SOFTTRAP)		/* software trap */
	TRAP(tt0_17b, SOFTTRAP)		/* software trap */
	TRAP(tt0_17c, SOFTTRAP)		/* software trap */
	TRAP(tt0_17d, SOFTTRAP)		/* software trap */
	TRAP(tt0_17e, SOFTTRAP)		/* software trap */
	TRAP(tt0_17f, SOFTTRAP)		/* software trap */
	TRAP(tt0_180, NOT)		/* hypervisor software trap */
	TRAP(tt0_181, NOT)		/* hypervisor software trap */
	TRAP(tt0_182, NOT)		/* hypervisor software trap */
	TRAP(tt0_183, NOT)		/* hypervisor software trap */
	TRAP(tt0_184, NOT)		/* hypervisor software trap */
	TRAP(tt0_185, NOT)		/* hypervisor software trap */
	TRAP(tt0_186, NOT)		/* hypervisor software trap */
	TRAP(tt0_187, NOT)		/* hypervisor software trap */
	TRAP(tt0_188, NOT)		/* hypervisor software trap */
	TRAP(tt0_189, NOT)		/* hypervisor software trap */
	TRAP(tt0_18a, NOT)		/* hypervisor software trap */
	TRAP(tt0_18b, NOT)		/* hypervisor software trap */
	TRAP(tt0_18c, NOT)		/* hypervisor software trap */
	TRAP(tt0_18d, NOT)		/* hypervisor software trap */
	TRAP(tt0_18e, NOT)		/* hypervisor software trap */
	TRAP(tt0_18f, NOT)		/* hypervisor software trap */
	TRAP(tt0_190, NOT)		/* hypervisor software trap */
	TRAP(tt0_191, NOT)		/* hypervisor software trap */
	TRAP(tt0_192, NOT)		/* hypervisor software trap */
	TRAP(tt0_193, NOT)		/* hypervisor software trap */
	TRAP(tt0_194, NOT)		/* hypervisor software trap */
	TRAP(tt0_195, NOT)		/* hypervisor software trap */
	TRAP(tt0_196, NOT)		/* hypervisor software trap */
	TRAP(tt0_197, NOT)		/* hypervisor software trap */
	TRAP(tt0_198, NOT)		/* hypervisor software trap */
	TRAP(tt0_199, NOT)		/* hypervisor software trap */
	TRAP(tt0_19a, NOT)		/* hypervisor software trap */
	TRAP(tt0_19b, NOT)		/* hypervisor software trap */
	TRAP(tt0_19c, NOT)		/* hypervisor software trap */
	TRAP(tt0_19d, NOT)		/* hypervisor software trap */
	TRAP(tt0_19e, NOT)		/* hypervisor software trap */
	TRAP(tt0_19f, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a0, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a1, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a2, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a3, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a4, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a5, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a6, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a7, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a8, NOT)		/* hypervisor software trap */
	TRAP(tt0_1a9, NOT)		/* hypervisor software trap */
	TRAP(tt0_1aa, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ab, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ac, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ad, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ae, NOT)		/* hypervisor software trap */
	TRAP(tt0_1af, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b0, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b1, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b2, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b3, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b4, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b5, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b6, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b7, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b8, NOT)		/* hypervisor software trap */
	TRAP(tt0_1b9, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ba, NOT)		/* hypervisor software trap */
	TRAP(tt0_1bb, NOT)		/* hypervisor software trap */
	TRAP(tt0_1bc, NOT)		/* hypervisor software trap */
	TRAP(tt0_1bd, NOT)		/* hypervisor software trap */
	TRAP(tt0_1be, NOT)		/* hypervisor software trap */
	TRAP(tt0_1bf, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c0, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c1, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c2, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c3, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c4, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c5, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c6, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c7, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c8, NOT)		/* hypervisor software trap */
	TRAP(tt0_1c9, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ca, NOT)		/* hypervisor software trap */
	TRAP(tt0_1cb, NOT)		/* hypervisor software trap */
	TRAP(tt0_1cc, NOT)		/* hypervisor software trap */
	TRAP(tt0_1cd, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ce, NOT)		/* hypervisor software trap */
	TRAP(tt0_1cf, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d0, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d1, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d2, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d3, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d4, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d5, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d6, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d7, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d8, NOT)		/* hypervisor software trap */
	TRAP(tt0_1d9, NOT)		/* hypervisor software trap */
	TRAP(tt0_1da, NOT)		/* hypervisor software trap */
	TRAP(tt0_1db, NOT)		/* hypervisor software trap */
	TRAP(tt0_1dc, NOT)		/* hypervisor software trap */
	TRAP(tt0_1dd, NOT)		/* hypervisor software trap */
	TRAP(tt0_1de, NOT)		/* hypervisor software trap */
	TRAP(tt0_1df, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e0, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e1, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e2, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e3, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e4, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e5, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e6, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e7, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e8, NOT)		/* hypervisor software trap */
	TRAP(tt0_1e9, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ea, NOT)		/* hypervisor software trap */
	TRAP(tt0_1eb, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ec, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ed, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ee, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ef, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f0, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f1, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f2, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f3, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f4, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f5, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f6, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f7, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f8, NOT)		/* hypervisor software trap */
	TRAP(tt0_1f9, NOT)		/* hypervisor software trap */
	TRAP(tt0_1fa, NOT)		/* hypervisor software trap */
	TRAP(tt0_1fb, NOT)		/* hypervisor software trap */
	TRAP(tt0_1fc, NOT)		/* hypervisor software trap */
	TRAP(tt0_1fd, NOT)		/* hypervisor software trap */
	TRAP(tt0_1fe, NOT)		/* hypervisor software trap */
	TRAP(tt0_1ff, NOT)		/* hypervisor software trap */
	SET_SIZE(traptable0)
#endif /* lint */
#if defined(lint)
void *traptable1;
#else
	ENTRY(traptable1)
	/* hardware traps */
	TRAP(tt1_000, NOT)		/* reserved */
	TRAP(tt1_001, NOT)		/* reserved */
	TRAP(tt1_002, NOT)		/* reserved */
	TRAP(tt1_003, NOT)		/* reserved */
	TRAP(tt1_004, NOT)		/* reserved */
	TRAP(tt1_005, NOT)		/* reserved */
	TRAP(tt1_006, NOT)		/* reserved */
	TRAP(tt1_007, NOT)		/* reserved */
	TRAP(tt1_008, NOT)		/* instruction access exception */
	TRAP(tt1_009, NOT)		/* instruction access mmu miss */
	TRAP(tt1_00a, NOT)		/* instruction access error */
	TRAP(tt1_00b, NOT)		/* reserved */
	TRAP(tt1_00c, NOT)		/* reserved */
	TRAP(tt1_00d, NOT)		/* reserved */
	TRAP(tt1_00e, NOT)		/* reserved */
	TRAP(tt1_00f, NOT)		/* reserved */
	TRAP(tt1_010, NOT)		/* illegal instruction */
	TRAP(tt1_011, NOT)		/* privileged opcode */
	TRAP(tt1_012, NOT)		/* unimplemented LDD */
	TRAP(tt1_013, NOT)		/* unimplemented STD */
	TRAP(tt1_014, NOT)		/* reserved */
	TRAP(tt1_015, NOT)		/* reserved */
	TRAP(tt1_016, NOT)		/* reserved */
	TRAP(tt1_017, NOT)		/* reserved */
	TRAP(tt1_018, NOT)		/* reserved */
	TRAP(tt1_019, NOT)		/* reserved */
	TRAP(tt1_01a, NOT)		/* reserved */
	TRAP(tt1_01b, NOT)		/* reserved */
	TRAP(tt1_01c, NOT)		/* reserved */
	TRAP(tt1_01d, NOT)		/* reserved */
	TRAP(tt1_01e, NOT)		/* reserved */
	TRAP(tt1_01f, NOT)		/* reserved */
	TRAP(tt1_020, NOT)		/* fp disabled */
	TRAP(tt1_021, NOT)		/* fp exception ieee 754 */
	TRAP(tt1_022, NOT)		/* fp exception other */
	TRAP(tt1_023, NOT)		/* tag overflow */
	BIGTRAP(tt1_024, CLEAN_WINDOW)	/* clean window */
	TRAP(tt1_028, NOT)		/* division by zero */
	TRAP(tt1_029, NOT)		/* internal processor error */
	TRAP(tt1_02a, NOT)		/* reserved */
	TRAP(tt1_02b, NOT)		/* reserved */
	TRAP(tt1_02c, NOT)		/* reserved */
	TRAP(tt1_02d, NOT)		/* reserved */
	TRAP(tt1_02e, NOT)		/* reserved */
	TRAP(tt1_02f, NOT)		/* reserved */
	TRAP(tt1_030, NOT)		/* data access exception */
	TRAP(tt1_031, NOT)		/* data access mmu miss */
	TRAP(tt1_032, NOT)		/* data access error */
	TRAP(tt1_033, NOT)		/* data access protection */
	TRAP(tt1_034, NOT)		/* mem address not aligned */
	TRAP(tt1_035, NOT)		/* lddf mem address not aligned */
	TRAP(tt1_036, NOT)		/* stdf mem address not aligned */
	TRAP(tt1_037, NOT)		/* privileged action */
	TRAP(tt1_038, NOT)		/* ldqf mem address not aligned */
	TRAP(tt1_039, NOT)		/* stqf mem address not aligned */
	TRAP(tt1_03a, NOT)		/* reserved */
	TRAP(tt1_03b, NOT)		/* reserved */
	TRAP(tt1_03c, NOT)		/* reserved */
	TRAP(tt1_03d, NOT)		/* reserved */
	TRAP(tt1_03e, NOT)		/* reserved */
	TRAP(tt1_03f, NOT)		/* HV: real translation miss */
	TRAP(tt1_040, NOT)		/* async data error */
	TRAP(tt1_041, NOT)		/* interrupt level 1 */
	TRAP(tt1_042, NOT)		/* interrupt level 2 */
	TRAP(tt1_043, NOT)		/* interrupt level 3 */
	TRAP(tt1_044, NOT)		/* interrupt level 4 */
	TRAP(tt1_045, NOT)		/* interrupt level 5 */
	TRAP(tt1_046, NOT)		/* interrupt level 6 */
	TRAP(tt1_047, NOT)		/* interrupt level 7 */
	TRAP(tt1_048, NOT)		/* interrupt level 8 */
	TRAP(tt1_049, NOT)		/* interrupt level 9 */
	TRAP(tt1_04a, NOT)		/* interrupt level a */
	TRAP(tt1_04b, NOT)		/* interrupt level b */
	TRAP(tt1_04c, NOT)		/* interrupt level c */
	TRAP(tt1_04d, NOT)		/* interrupt level d */
	TRAP(tt1_04e, NOT)		/* interrupt level e */
	TRAP(tt1_04f, NOT)		/* interrupt level f */
	TRAP(tt1_050, NOT)		/* reserved */
	TRAP(tt1_051, NOT)		/* reserved */
	TRAP(tt1_052, NOT)		/* reserved */
	TRAP(tt1_053, NOT)		/* reserved */
	TRAP(tt1_054, NOT)		/* reserved */
	TRAP(tt1_055, NOT)		/* reserved */
	TRAP(tt1_056, NOT)		/* reserved */
	TRAP(tt1_057, NOT)		/* reserved */
	TRAP(tt1_058, NOT)		/* reserved */
	TRAP(tt1_059, NOT)		/* reserved */
	TRAP(tt1_05a, NOT)		/* reserved */
	TRAP(tt1_05b, NOT)		/* reserved */
	TRAP(tt1_05c, NOT)		/* reserved */
	TRAP(tt1_05d, NOT)		/* reserved */
	TRAP(tt1_05e, NOT)		/* HV: hstick match */
	TRAP(tt1_05f, NOT)		/* reserved */
	TRAP(tt1_060, NOT)		/* interrupt vector */
	TRAP(tt1_061, NOT)		/* RA watchpoint */
	TRAP(tt1_062, NOT)		/* VA watchpoint */
	TRAP(tt1_063, NOT)		/* corrected ECC error XXX */
	BIGTRAP(tt1_064, NOT)		/* fast instruction access MMU miss */
	BIGTRAP(tt1_068, NOT)		/* fast data access MMU miss */
	BIGTRAP(tt1_06C, NOT)		/* fast data access protection */
	TRAP(tt1_070, NOT)		/* reserved */
	TRAP(tt1_071, NOT)		/* reserved */
	TRAP(tt1_072, NOT)		/* reserved */
	TRAP(tt1_073, NOT)		/* reserved */
	TRAP(tt1_074, NOT)		/* reserved */
	TRAP(tt1_075, NOT)		/* reserved */
	TRAP(tt1_076, NOT)		/* reserved */
	TRAP(tt1_077, NOT)		/* reserved */
	TRAP(tt1_078, NOT)		/* reserved */
	TRAP(tt1_079, NOT)		/* reserved */
	TRAP(tt1_07a, NOT)		/* reserved */
	TRAP(tt1_07b, NOT)		/* reserved */
	TRAP(tt1_07c, NOT)		/* HV: cpu mondo */
	TRAP(tt1_07d, NOT)		/* HV: dev mondo */
	TRAP(tt1_07e, NOT)		/* HV: resumable error */
	TRAP(tt1_07f, NOT)		/* HV: non-resumable error */
	BIGTRAP(tt1_080, SPILL_WINDOW)	/* spill 0 normal */
	BIGTRAP(tt1_084, SPILL_WINDOW)	/* spill 1 normal */
	BIGTRAP(tt1_088, SPILL_WINDOW)	/* spill 2 normal */
	BIGTRAP(tt1_08c, SPILL_WINDOW)	/* spill 3 normal */
	BIGTRAP(tt1_090, SPILL_WINDOW)	/* spill 4 normal */
	BIGTRAP(tt1_094, SPILL_WINDOW)	/* spill 5 normal */
	BIGTRAP(tt1_098, SPILL_WINDOW)	/* spill 6 normal */
	BIGTRAP(tt1_09c, SPILL_WINDOW)	/* spill 7 normal */
	BIGTRAP(tt1_0a0, SPILL_WINDOW)	/* spill 0 other */
	BIGTRAP(tt1_0a4, SPILL_WINDOW)	/* spill 1 other */
	BIGTRAP(tt1_0a8, SPILL_WINDOW)	/* spill 2 other */
	BIGTRAP(tt1_0ac, SPILL_WINDOW)	/* spill 3 other */
	BIGTRAP(tt1_0b0, SPILL_WINDOW)	/* spill 4 other */
	BIGTRAP(tt1_0b4, SPILL_WINDOW)	/* spill 5 other */
	BIGTRAP(tt1_0b8, SPILL_WINDOW)	/* spill 6 other */
	BIGTRAP(tt1_0bc, SPILL_WINDOW)	/* spill 7 other */
	BIGTRAP(tt1_0c0, FILL_WINDOW)	/* fill 0 normal */
	BIGTRAP(tt1_0c4, FILL_WINDOW)	/* fill 1 normal */
	BIGTRAP(tt1_0c8, FILL_WINDOW)	/* fill 2 normal */
	BIGTRAP(tt1_0cc, FILL_WINDOW)	/* fill 3 normal */
	BIGTRAP(tt1_0d0, FILL_WINDOW)	/* fill 4 normal */
	BIGTRAP(tt1_0d4, FILL_WINDOW)	/* fill 5 normal */
	BIGTRAP(tt1_0d8, FILL_WINDOW)	/* fill 6 normal */
	BIGTRAP(tt1_0dc, FILL_WINDOW)	/* fill 7 normal */
	BIGTRAP(tt1_0e0, FILL_WINDOW)	/* fill 0 other */
	BIGTRAP(tt1_0e4, FILL_WINDOW)	/* fill 1 other */
	BIGTRAP(tt1_0e8, FILL_WINDOW)	/* fill 2 other */
	BIGTRAP(tt1_0ec, FILL_WINDOW)	/* fill 3 other */
	BIGTRAP(tt1_0f0, FILL_WINDOW)	/* fill 4 other */
	BIGTRAP(tt1_0f4, FILL_WINDOW)	/* fill 5 other */
	BIGTRAP(tt1_0f8, FILL_WINDOW)	/* fill 6 other */
	BIGTRAP(tt1_0fc, FILL_WINDOW)	/* fill 7 other */
	TRAP(tt1_100, SOFTTRAP)		/* software trap */
	TRAP(tt1_101, SOFTTRAP)		/* software trap */
	TRAP(tt1_102, SOFTTRAP)		/* software trap */
	TRAP(tt1_103, SOFTTRAP)		/* software trap */
	TRAP(tt1_104, SOFTTRAP)		/* software trap */
	TRAP(tt1_105, SOFTTRAP)		/* software trap */
	TRAP(tt1_106, SOFTTRAP)		/* software trap */
	TRAP(tt1_107, SOFTTRAP)		/* software trap */
	TRAP(tt1_108, SOFTTRAP)		/* software trap */
	TRAP(tt1_109, SOFTTRAP)		/* software trap */
	TRAP(tt1_10a, SOFTTRAP)		/* software trap */
	TRAP(tt1_10b, SOFTTRAP)		/* software trap */
	TRAP(tt1_10c, SOFTTRAP)		/* software trap */
	TRAP(tt1_10d, SOFTTRAP)		/* software trap */
	TRAP(tt1_10e, SOFTTRAP)		/* software trap */
	TRAP(tt1_10f, SOFTTRAP)		/* software trap */
	TRAP(tt1_110, SOFTTRAP)		/* software trap */
	TRAP(tt1_111, SOFTTRAP)		/* software trap */
	TRAP(tt1_112, SOFTTRAP)		/* software trap */
	TRAP(tt1_113, SOFTTRAP)		/* software trap */
	TRAP(tt1_114, SOFTTRAP)		/* software trap */
	TRAP(tt1_115, SOFTTRAP)		/* software trap */
	TRAP(tt1_116, SOFTTRAP)		/* software trap */
	TRAP(tt1_117, SOFTTRAP)		/* software trap */
	TRAP(tt1_118, SOFTTRAP)		/* software trap */
	TRAP(tt1_119, SOFTTRAP)		/* software trap */
	TRAP(tt1_11a, SOFTTRAP)		/* software trap */
	TRAP(tt1_11b, SOFTTRAP)		/* software trap */
	TRAP(tt1_11c, SOFTTRAP)		/* software trap */
	TRAP(tt1_11d, SOFTTRAP)		/* software trap */
	TRAP(tt1_11e, SOFTTRAP)		/* software trap */
	TRAP(tt1_11f, SOFTTRAP)		/* software trap */
	TRAP(tt1_120, SOFTTRAP)		/* software trap */
	TRAP(tt1_121, SOFTTRAP)		/* software trap */
	TRAP(tt1_122, SOFTTRAP)		/* software trap */
	TRAP(tt1_123, SOFTTRAP)		/* software trap */
	TRAP(tt1_124, SOFTTRAP)		/* software trap */
	TRAP(tt1_125, SOFTTRAP)		/* software trap */
	TRAP(tt1_126, SOFTTRAP)		/* software trap */
	TRAP(tt1_127, SOFTTRAP)		/* software trap */
	TRAP(tt1_128, SOFTTRAP)		/* software trap */
	TRAP(tt1_129, SOFTTRAP)		/* software trap */
	TRAP(tt1_12a, SOFTTRAP)		/* software trap */
	TRAP(tt1_12b, SOFTTRAP)		/* software trap */
	TRAP(tt1_12c, SOFTTRAP)		/* software trap */
	TRAP(tt1_12d, SOFTTRAP)		/* software trap */
	TRAP(tt1_12e, SOFTTRAP)		/* software trap */
	TRAP(tt1_12f, SOFTTRAP)		/* software trap */
	TRAP(tt1_130, SOFTTRAP)		/* software trap */
	TRAP(tt1_131, SOFTTRAP)		/* software trap */
	TRAP(tt1_132, SOFTTRAP)		/* software trap */
	TRAP(tt1_133, SOFTTRAP)		/* software trap */
	TRAP(tt1_134, SOFTTRAP)		/* software trap */
	TRAP(tt1_135, SOFTTRAP)		/* software trap */
	TRAP(tt1_136, SOFTTRAP)		/* software trap */
	TRAP(tt1_137, SOFTTRAP)		/* software trap */
	TRAP(tt1_138, SOFTTRAP)		/* software trap */
	TRAP(tt1_139, SOFTTRAP)		/* software trap */
	TRAP(tt1_13a, SOFTTRAP)		/* software trap */
	TRAP(tt1_13b, SOFTTRAP)		/* software trap */
	TRAP(tt1_13c, SOFTTRAP)		/* software trap */
	TRAP(tt1_13d, SOFTTRAP)		/* software trap */
	TRAP(tt1_13e, SOFTTRAP)		/* software trap */
	TRAP(tt1_13f, SOFTTRAP)		/* software trap */
	TRAP(tt1_140, SOFTTRAP)		/* software trap */
	TRAP(tt1_141, SOFTTRAP)		/* software trap */
	TRAP(tt1_142, SOFTTRAP)		/* software trap */
	TRAP(tt1_143, SOFTTRAP)		/* software trap */
	TRAP(tt1_144, SOFTTRAP)		/* software trap */
	TRAP(tt1_145, SOFTTRAP)		/* software trap */
	TRAP(tt1_146, SOFTTRAP)		/* software trap */
	TRAP(tt1_147, SOFTTRAP)		/* software trap */
	TRAP(tt1_148, SOFTTRAP)		/* software trap */
	TRAP(tt1_149, SOFTTRAP)		/* software trap */
	TRAP(tt1_14a, SOFTTRAP)		/* software trap */
	TRAP(tt1_14b, SOFTTRAP)		/* software trap */
	TRAP(tt1_14c, SOFTTRAP)		/* software trap */
	TRAP(tt1_14d, SOFTTRAP)		/* software trap */
	TRAP(tt1_14e, SOFTTRAP)		/* software trap */
	TRAP(tt1_14f, SOFTTRAP)		/* software trap */
	TRAP(tt1_150, SOFTTRAP)		/* software trap */
	TRAP(tt1_151, SOFTTRAP)		/* software trap */
	TRAP(tt1_152, SOFTTRAP)		/* software trap */
	TRAP(tt1_153, SOFTTRAP)		/* software trap */
	TRAP(tt1_154, SOFTTRAP)		/* software trap */
	TRAP(tt1_155, SOFTTRAP)		/* software trap */
	TRAP(tt1_156, SOFTTRAP)		/* software trap */
	TRAP(tt1_157, SOFTTRAP)		/* software trap */
	TRAP(tt1_158, SOFTTRAP)		/* software trap */
	TRAP(tt1_159, SOFTTRAP)		/* software trap */
	TRAP(tt1_15a, SOFTTRAP)		/* software trap */
	TRAP(tt1_15b, SOFTTRAP)		/* software trap */
	TRAP(tt1_15c, SOFTTRAP)		/* software trap */
	TRAP(tt1_15d, SOFTTRAP)		/* software trap */
	TRAP(tt1_15e, SOFTTRAP)		/* software trap */
	TRAP(tt1_15f, SOFTTRAP)		/* software trap */
	TRAP(tt1_160, SOFTTRAP)		/* software trap */
	TRAP(tt1_161, SOFTTRAP)		/* software trap */
	TRAP(tt1_162, SOFTTRAP)		/* software trap */
	TRAP(tt1_163, SOFTTRAP)		/* software trap */
	TRAP(tt1_164, SOFTTRAP)		/* software trap */
	TRAP(tt1_165, SOFTTRAP)		/* software trap */
	TRAP(tt1_166, SOFTTRAP)		/* software trap */
	TRAP(tt1_167, SOFTTRAP)		/* software trap */
	TRAP(tt1_168, SOFTTRAP)		/* software trap */
	TRAP(tt1_169, SOFTTRAP)		/* software trap */
	TRAP(tt1_16a, SOFTTRAP)		/* software trap */
	TRAP(tt1_16b, SOFTTRAP)		/* software trap */
	TRAP(tt1_16c, SOFTTRAP)		/* software trap */
	TRAP(tt1_16d, SOFTTRAP)		/* software trap */
	TRAP(tt1_16e, SOFTTRAP)		/* software trap */
	TRAP(tt1_16f, SOFTTRAP)		/* software trap */
	TRAP(tt1_170, SOFTTRAP)		/* software trap */
	TRAP(tt1_171, SOFTTRAP)		/* software trap */
	TRAP(tt1_172, SOFTTRAP)		/* software trap */
	TRAP(tt1_173, SOFTTRAP)		/* software trap */
	TRAP(tt1_174, SOFTTRAP)		/* software trap */
	TRAP(tt1_175, SOFTTRAP)		/* software trap */
	TRAP(tt1_176, SOFTTRAP)		/* software trap */
	TRAP(tt1_177, SOFTTRAP)		/* software trap */
	TRAP(tt1_178, SOFTTRAP)		/* software trap */
	TRAP(tt1_179, SOFTTRAP)		/* software trap */
	TRAP(tt1_17a, SOFTTRAP)		/* software trap */
	TRAP(tt1_17b, SOFTTRAP)		/* software trap */
	TRAP(tt1_17c, SOFTTRAP)		/* software trap */
	TRAP(tt1_17d, SOFTTRAP)		/* software trap */
	TRAP(tt1_17e, SOFTTRAP)		/* software trap */
	TRAP(tt1_17f, SOFTTRAP)		/* software trap */
	TRAP(tt1_180, NOT)		/* hypervisor software trap */
	TRAP(tt1_181, NOT)		/* hypervisor software trap */
	TRAP(tt1_182, NOT)		/* hypervisor software trap */
	TRAP(tt1_183, NOT)		/* hypervisor software trap */
	TRAP(tt1_184, NOT)		/* hypervisor software trap */
	TRAP(tt1_185, NOT)		/* hypervisor software trap */
	TRAP(tt1_186, NOT)		/* hypervisor software trap */
	TRAP(tt1_187, NOT)		/* hypervisor software trap */
	TRAP(tt1_188, NOT)		/* hypervisor software trap */
	TRAP(tt1_189, NOT)		/* hypervisor software trap */
	TRAP(tt1_18a, NOT)		/* hypervisor software trap */
	TRAP(tt1_18b, NOT)		/* hypervisor software trap */
	TRAP(tt1_18c, NOT)		/* hypervisor software trap */
	TRAP(tt1_18d, NOT)		/* hypervisor software trap */
	TRAP(tt1_18e, NOT)		/* hypervisor software trap */
	TRAP(tt1_18f, NOT)		/* hypervisor software trap */
	TRAP(tt1_190, NOT)		/* hypervisor software trap */
	TRAP(tt1_191, NOT)		/* hypervisor software trap */
	TRAP(tt1_192, NOT)		/* hypervisor software trap */
	TRAP(tt1_193, NOT)		/* hypervisor software trap */
	TRAP(tt1_194, NOT)		/* hypervisor software trap */
	TRAP(tt1_195, NOT)		/* hypervisor software trap */
	TRAP(tt1_196, NOT)		/* hypervisor software trap */
	TRAP(tt1_197, NOT)		/* hypervisor software trap */
	TRAP(tt1_198, NOT)		/* hypervisor software trap */
	TRAP(tt1_199, NOT)		/* hypervisor software trap */
	TRAP(tt1_19a, NOT)		/* hypervisor software trap */
	TRAP(tt1_19b, NOT)		/* hypervisor software trap */
	TRAP(tt1_19c, NOT)		/* hypervisor software trap */
	TRAP(tt1_19d, NOT)		/* hypervisor software trap */
	TRAP(tt1_19e, NOT)		/* hypervisor software trap */
	TRAP(tt1_19f, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a0, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a1, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a2, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a3, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a4, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a5, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a6, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a7, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a8, NOT)		/* hypervisor software trap */
	TRAP(tt1_1a9, NOT)		/* hypervisor software trap */
	TRAP(tt1_1aa, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ab, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ac, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ad, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ae, NOT)		/* hypervisor software trap */
	TRAP(tt1_1af, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b0, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b1, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b2, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b3, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b4, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b5, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b6, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b7, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b8, NOT)		/* hypervisor software trap */
	TRAP(tt1_1b9, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ba, NOT)		/* hypervisor software trap */
	TRAP(tt1_1bb, NOT)		/* hypervisor software trap */
	TRAP(tt1_1bc, NOT)		/* hypervisor software trap */
	TRAP(tt1_1bd, NOT)		/* hypervisor software trap */
	TRAP(tt1_1be, NOT)		/* hypervisor software trap */
	TRAP(tt1_1bf, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c0, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c1, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c2, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c3, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c4, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c5, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c6, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c7, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c8, NOT)		/* hypervisor software trap */
	TRAP(tt1_1c9, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ca, NOT)		/* hypervisor software trap */
	TRAP(tt1_1cb, NOT)		/* hypervisor software trap */
	TRAP(tt1_1cc, NOT)		/* hypervisor software trap */
	TRAP(tt1_1cd, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ce, NOT)		/* hypervisor software trap */
	TRAP(tt1_1cf, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d0, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d1, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d2, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d3, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d4, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d5, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d6, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d7, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d8, NOT)		/* hypervisor software trap */
	TRAP(tt1_1d9, NOT)		/* hypervisor software trap */
	TRAP(tt1_1da, NOT)		/* hypervisor software trap */
	TRAP(tt1_1db, NOT)		/* hypervisor software trap */
	TRAP(tt1_1dc, NOT)		/* hypervisor software trap */
	TRAP(tt1_1dd, NOT)		/* hypervisor software trap */
	TRAP(tt1_1de, NOT)		/* hypervisor software trap */
	TRAP(tt1_1df, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e0, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e1, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e2, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e3, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e4, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e5, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e6, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e7, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e8, NOT)		/* hypervisor software trap */
	TRAP(tt1_1e9, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ea, NOT)		/* hypervisor software trap */
	TRAP(tt1_1eb, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ec, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ed, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ee, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ef, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f0, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f1, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f2, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f3, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f4, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f5, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f6, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f7, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f8, NOT)		/* hypervisor software trap */
	TRAP(tt1_1f9, NOT)		/* hypervisor software trap */
	TRAP(tt1_1fa, NOT)		/* hypervisor software trap */
	TRAP(tt1_1fb, NOT)		/* hypervisor software trap */
	TRAP(tt1_1fc, NOT)		/* hypervisor software trap */
	TRAP(tt1_1fd, NOT)		/* hypervisor software trap */
	TRAP(tt1_1fe, NOT)		/* hypervisor software trap */
	TRAP(tt1_1ff, NOT)		/* hypervisor software trap */
	SET_SIZE(traptable1)
#endif /* lint */
