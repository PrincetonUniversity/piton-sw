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
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

	.ident	"@(#)traptable.s	1.7	07/09/14 SMI"

	.file	"traptable.s"

/*
 * Niagara hypervisor trap table
 */

#include <sys/asm_linkage.h>
#include <sys/stack.h>
#include <hypervisor.h>
#include <hprivregs.h>
#include <asi.h>
#include <mmu.h>
#include <traps.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>

#include <offsets.h>
#include <traptable.h>
#include <util.h>
#include <guest.h>
#include <traptrace.h>
#include <debug.h>
#include <util.h>
#include <abort.h>
#include <error_asm.h>
#include <error_regs.h>

/*
 * The basic hypervisor trap table
 *
 * We use the linker to place this at the beginning of the hypervisor
 * binary which gets loaded at an appropriate alignment by Reset/Config.
 */

	ENTRY(htraptable)
	/*
	 * hardware traps
	 */
	TRAP(tt0_000, NOT)		/* reserved */
	TRAP(tt0_001, POR)		/* power-on reset */
	TRAP(tt0_002, GOTO(watchdog))	/* watchdog reset */
	TRAP(tt0_003, GOTO(xir))	/* externally initiated reset */
	TRAP(tt0_004, NOT)		/* software initiated reset */
	TRAP(tt0_005, NOT)		/* red mode exception */
	TRAP(tt0_006, NOT)		/* reserved */
	TRAP(tt0_007, STORE_ERROR)	/* Store error */
	TRAP(tt0_008, IMMU_ERR(MMU_FT_PRIV)) /* IAE - privilege violation */
	TRAP(tt0_009, IMMU_MISS_HWTW)	/* instruction access mmu miss */
	TRAP(tt0_00a, IA_ERR)		/* instruction access error */
	TRAP(tt0_00b, IMMU_ERR_RV(MMU_FT_PROT)) /* IAE - unauth access */
	TRAP(tt0_00c, IMMU_ERR_RV(MMU_FT_NFO)) /* IAE - NFO page */
	TRAP(tt0_00d, IMMU_ERR_RV(MMU_FT_VARANGE)) /* instr address range */
	TRAP(tt0_00e, IMMU_ERR_RV(MMU_FT_INVALIDRA)) /* instr real range */
	TRAP(tt0_00f, NOT)		/* reserved */
	TRAP(tt0_010, REVECTOR(TT_ILLINST)) /* illegal instruction */
	TRAP(tt0_011, REVECTOR(TT_PRIVOP)) /* privileged opcode */
	TRAP(tt0_012, REVECTOR(TT_UNIMP_LDD)) /* unimplemented LDD */
	TRAP(tt0_013, REVECTOR(TT_UNIMP_STD)) /* unimplemented STD */
	TRAP(tt0_014, DMMU_ERR_RV(MMU_FT_BADASI)) /* DAE - invalid asi */
	TRAP(tt0_015, DMMU_ERR_RV(MMU_FT_PRIV)) /* DAE - privilege violation */
	TRAP(tt0_016, DAE_nc_page) 	/* DAE - NC page */
	TRAP(tt0_017, DMMU_ERR_RV(MMU_FT_NFO)) /* DAE - NFO page */
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
	TRAP(tt0_029, IP_ERR)		/* internal processor error */
	TRAP(tt0_02a, ITSB_ERR)		/* instr. invalid TSB entry */
	TRAP(tt0_02b, DTSB_ERR)		/* data invalid TSB entry */
	TRAP(tt0_02c, NOT)		/* reserved */
	TRAP(tt0_02d, DMMU_ERR_RV(MMU_FT_INVALIDRA)) /* mem real range */
	TRAP(tt0_02e, DMMU_ERR_RV(MMU_FT_VARANGE)) /* mem address range */
	TRAP(tt0_02f, NOT)		/* reserved */
	TRAP(tt0_030, DMMU_ERR_RV(MMU_FT_SO)) /* DAE - so page */
	TRAP(tt0_031, DMMU_MISS_HWTW)	/* data access mmu miss */
	TRAP(tt0_032, DA_ERR)		/* data access error */
	TRAP(tt0_033, NOT)		/* data access protection */
	TRAP(tt0_034, DMMU_ERR(MMU_FT_ALIGN)) /* mem address not aligned */
	TRAP(tt0_035, DMMU_ERR(MMU_FT_ALIGN)) /* lddf mem address not aligned */
	TRAP(tt0_036, DMMU_ERR(MMU_FT_ALIGN)) /* stdf mem address not aligned */
	TRAP(tt0_037, DMMU_ERR(MMU_FT_PRIV)) /* privileged action */
	TRAP(tt0_038, DMMU_ERR(MMU_FT_ALIGN)) /* ldqf mem address not aligned */
	TRAP(tt0_039, DMMU_ERR(MMU_FT_ALIGN)) /* stqf mem address not aligned */
	TRAP(tt0_03a, NOT)		/* reserved */
	TRAP(tt0_03b, DMMU_ERR_RV(MMU_FT_MULTIERR)) /* unsupported page size */
	TRAP(tt0_03c, CWQINTR)		/* control word queue */
	TRAP(tt0_03d, MAUINTR)		/* modular arithmetic unit */
	TRAP(tt0_03e, RIMMU_MISS)	/* HV: real immu miss */
	TRAP(tt0_03f, RDMMU_MISS)	/* HV: real dmmu miss */
	TRAP(tt0_040, SW_RECOVERABLE_ERROR)	/* s/w recoverable error */
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
	TRAP(tt0_05e, HSTICK_INTR)	/* HV: hstick match */
	TRAP(tt0_05f, NOT)		/* trap level zero */
	TRAP(tt0_060, VECINTR)		/* interrupt vector */
	TRAP(tt0_061, NOT)		/* RA watchpoint */
	TRAP(tt0_062, NOT)		/* VA watchpoint */
	TRAP(tt0_063, HW_CORRECTED_ERROR) /* H/W CORRected ECC error XXX */
	BIGTRAP(tt0_064, IMMU_MISS)	/* fast instruction access MMU miss */
	BIGTRAP(tt0_068, DMMU_MISS)	/* fast data access MMU miss */
	BIGTRAP(tt0_06C, DMMU_PROT)	/* fast data access protection */
	TRAP(tt0_070, NOT)		/* reserved */
	TRAP(tt0_071, IAM_ERR)		/* instruction access MMU error */
	TRAP(tt0_072, DAM_ERR)		/* data access MMU error */
	TRAP(tt0_073, NOT)		/* reserved */
	TRAP(tt0_074, NOT)		/* control transfer instruction */
	TRAP(tt0_075, NOT)		/* instruction VA watchpoint */
	TRAP(tt0_076, NOT)		/* instruction breakpoint */
	TRAP(tt0_077, NOT)		/* reserved */
	TRAP(tt0_078, NOT)		/* data error (disrupting) */
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
	/*
	 * Software traps
	 */
	TRAP(tt0_100, NOT)		/* software trap */
	TRAP(tt0_101, NOT)		/* software trap */
	TRAP(tt0_102, NOT)		/* software trap */
	TRAP(tt0_103, NOT)		/* software trap */
	TRAP(tt0_104, NOT)		/* software trap */
	TRAP(tt0_105, NOT)		/* software trap */
	TRAP(tt0_106, NOT)		/* software trap */
	TRAP(tt0_107, NOT)		/* software trap */
	TRAP(tt0_108, NOT)		/* software trap */
	TRAP(tt0_109, NOT)		/* software trap */
	TRAP(tt0_10a, NOT)		/* software trap */
	TRAP(tt0_10b, NOT)		/* software trap */
	TRAP(tt0_10c, NOT)		/* software trap */
	TRAP(tt0_10d, NOT)		/* software trap */
	TRAP(tt0_10e, NOT)		/* software trap */
	TRAP(tt0_10f, NOT)		/* software trap */
	TRAP(tt0_110, NOT)		/* software trap */
	TRAP(tt0_111, NOT)		/* software trap */
	TRAP(tt0_112, NOT)		/* software trap */
#ifdef DEBUG
	TRAP(tt0_113, GOTO(hprint))	/* print string */
	TRAP(tt0_114, GOTO(hprintx))	/* print hex 64-bit */
#else
	TRAP(tt0_113, NOT)		/* software trap */
	TRAP(tt0_114, NOT)		/* software trap */
#endif
	TRAP(tt0_115, NOT)		/* software trap */
	TRAP(tt0_116, NOT)		/* software trap */
	TRAP(tt0_117, NOT)		/* software trap */
	TRAP(tt0_118, NOT)		/* software trap */
	TRAP(tt0_119, NOT)		/* software trap */
	TRAP(tt0_11a, NOT)		/* software trap */
	TRAP(tt0_11b, NOT)		/* software trap */
	TRAP(tt0_11c, NOT)		/* software trap */
	TRAP(tt0_11d, NOT)		/* software trap */
	TRAP(tt0_11e, NOT)		/* software trap */
	TRAP(tt0_11f, NOT)		/* software trap */
	TRAP(tt0_120, NOT)		/* software trap */
	TRAP(tt0_121, NOT)		/* software trap */
	TRAP(tt0_122, NOT)		/* software trap */
	TRAP(tt0_123, NOT)		/* software trap */
	TRAP(tt0_124, NOT)		/* software trap */
	TRAP(tt0_125, NOT)		/* software trap */
	TRAP(tt0_126, NOT)		/* software trap */
	TRAP(tt0_127, NOT)		/* software trap */
	TRAP(tt0_128, NOT)		/* software trap */
	TRAP(tt0_129, NOT)		/* software trap */
	TRAP(tt0_12a, NOT)		/* software trap */
	TRAP(tt0_12b, NOT)		/* software trap */
	TRAP(tt0_12c, NOT)		/* software trap */
	TRAP(tt0_12d, NOT)		/* software trap */
	TRAP(tt0_12e, NOT)		/* software trap */
	TRAP(tt0_12f, NOT)		/* software trap */
	TRAP(tt0_130, NOT)		/* software trap */
	TRAP(tt0_131, NOT)		/* software trap */
	TRAP(tt0_132, NOT)		/* software trap */
	TRAP(tt0_133, NOT)		/* software trap */
	TRAP(tt0_134, NOT)		/* software trap */
	TRAP(tt0_135, NOT)		/* software trap */
	TRAP(tt0_136, NOT)		/* software trap */
	TRAP(tt0_137, NOT)		/* software trap */
	TRAP(tt0_138, NOT)		/* software trap */
	TRAP(tt0_139, NOT)		/* software trap */
	TRAP(tt0_13a, NOT)		/* software trap */
	TRAP(tt0_13b, NOT)		/* software trap */
	TRAP(tt0_13c, NOT)		/* software trap */
	TRAP(tt0_13d, NOT)		/* software trap */
	TRAP(tt0_13e, NOT)		/* software trap */
	TRAP(tt0_13f, NOT)		/* software trap */
	TRAP(tt0_140, NOT)		/* software trap */
	TRAP(tt0_141, NOT)		/* software trap */
	TRAP(tt0_142, NOT)		/* software trap */
	TRAP(tt0_143, NOT)		/* software trap */
	TRAP(tt0_144, NOT)		/* software trap */
	TRAP(tt0_145, NOT)		/* software trap */
	TRAP(tt0_146, NOT)		/* software trap */
	TRAP(tt0_147, NOT)		/* software trap */
	TRAP(tt0_148, NOT)		/* software trap */
	TRAP(tt0_149, NOT)		/* software trap */
	TRAP(tt0_14a, NOT)		/* software trap */
	TRAP(tt0_14b, NOT)		/* software trap */
	TRAP(tt0_14c, NOT)		/* software trap */
	TRAP(tt0_14d, NOT)		/* software trap */
	TRAP(tt0_14e, NOT)		/* software trap */
	TRAP(tt0_14f, NOT)		/* software trap */
	TRAP(tt0_150, NOT)		/* software trap */
	TRAP(tt0_151, NOT)		/* software trap */
	TRAP(tt0_152, NOT)		/* software trap */
	TRAP(tt0_153, NOT)		/* software trap */
	TRAP(tt0_154, NOT)		/* software trap */
	TRAP(tt0_155, NOT)		/* software trap */
	TRAP(tt0_156, NOT)		/* software trap */
	TRAP(tt0_157, NOT)		/* software trap */
	TRAP(tt0_158, NOT)		/* software trap */
	TRAP(tt0_159, NOT)		/* software trap */
	TRAP(tt0_15a, NOT)		/* software trap */
	TRAP(tt0_15b, NOT)		/* software trap */
	TRAP(tt0_15c, NOT)		/* software trap */
	TRAP(tt0_15d, NOT)		/* software trap */
	TRAP(tt0_15e, NOT)		/* software trap */
	TRAP(tt0_15f, NOT)		/* software trap */
	TRAP(tt0_160, NOT)		/* software trap */
	TRAP(tt0_161, NOT)		/* software trap */
	TRAP(tt0_162, NOT)		/* software trap */
	TRAP(tt0_163, NOT)		/* software trap */
	TRAP(tt0_164, NOT)		/* software trap */
	TRAP(tt0_165, NOT)		/* software trap */
	TRAP(tt0_166, NOT)		/* software trap */
	TRAP(tt0_167, NOT)		/* software trap */
	TRAP(tt0_168, NOT)		/* software trap */
	TRAP(tt0_169, NOT)		/* software trap */
	TRAP(tt0_16a, NOT)		/* software trap */
	TRAP(tt0_16b, NOT)		/* software trap */
	TRAP(tt0_16c, NOT)		/* software trap */
	TRAP(tt0_16d, NOT)		/* software trap */
	TRAP(tt0_16e, NOT)		/* software trap */
	TRAP(tt0_16f, NOT)		/* software trap */
	TRAP(tt0_170, NOT)		/* software trap */
	TRAP(tt0_171, NOT)		/* software trap */
	TRAP(tt0_172, NOT)		/* software trap */
	TRAP(tt0_173, NOT)		/* software trap */
	TRAP(tt0_174, NOT)		/* software trap */
	TRAP(tt0_175, NOT)		/* software trap */
	TRAP(tt0_176, NOT)		/* software trap */
	TRAP(tt0_177, NOT)		/* software trap */
	TRAP(tt0_178, NOT)		/* software trap */
	TRAP(tt0_179, NOT)		/* software trap */
	TRAP(tt0_17a, NOT)		/* software trap */
	TRAP(tt0_17b, NOT)		/* software trap */
	TRAP(tt0_17c, NOT)		/* software trap */
	TRAP(tt0_17d, NOT)		/* software trap */
	TRAP(tt0_17e, NOT)		/* software trap */
	TRAP(tt0_17f, NOT)		/* software trap */
	TRAP(tt0_180, GOTO(hcall))	/* hypervisor software trap */
	TRAP(tt0_181, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_182, HCALL_BAD)	/* hypervisor software trap */
	TRAP_NOALIGN(tt0_183, HCALL(MMU_MAP_ADDR_IDX))		/* hyperfast trap */
	TRAP_NOALIGN(tt0_184, HCALL(MMU_UNMAP_ADDR_IDX))	/* hyperfast trap */
	TRAP_NOALIGN(tt0_185, HCALL(TTRACE_ADDENTRY_IDX))	/* hyperfast trap */
	TRAP(tt0_186, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_187, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_188, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_189, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_18a, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_18b, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_18c, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_18d, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_18e, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_18f, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_190, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_191, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_192, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_193, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_194, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_195, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_196, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_197, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_198, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_199, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_19a, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_19b, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_19c, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_19d, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_19e, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_19f, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a0, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a1, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a2, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a3, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a4, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a5, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a6, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a7, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a8, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1a9, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1aa, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ab, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ac, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ad, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ae, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1af, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b0, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b1, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b2, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b3, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b4, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b5, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b6, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b7, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b8, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1b9, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ba, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1bb, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1bc, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1bd, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1be, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1bf, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c0, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c1, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c2, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c3, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c4, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c5, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c6, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c7, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c8, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1c9, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ca, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1cb, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1cc, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1cd, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ce, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1cf, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d0, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d1, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d2, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d3, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d4, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d5, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d6, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d7, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d8, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1d9, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1da, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1db, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1dc, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1dd, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1de, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1df, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e0, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e1, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e2, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e3, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e4, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e5, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e6, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e7, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e8, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1e9, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ea, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1eb, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ec, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ed, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ee, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ef, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f0, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f1, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f2, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f3, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f4, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f5, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f6, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f7, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f8, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1f9, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1fa, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1fb, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1fc, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1fd, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1fe, HCALL_BAD)	/* hypervisor software trap */
	TRAP(tt0_1ff, GOTO(hcall_core))	/* hypervisor software trap */
ehtraptable:
	SET_SIZE(htraptable)

/*
 * Sparc V9 TBA registers require that bits 14 through 0 must be zero.
 * Ensure the trap tracing table is aligned on a TRAPTABLE_SIZE boundry. 
 * For additional information, refer to:
 * "The SPARC Architecture Manual", Version 9,
 * 	Section 5.2.8 "Trap Base Address (TBA)"
 *
 * There should be nothing in the .text segment between ehtraptable
 * and htraptracetable.
 */
	ENTRY(htraptracetable)
	TTRACE_TRAP_TABLE
ehtraptracetable:
	SET_SIZE(htraptracetable)


/*
 * revector - revector a trap to the guest as if the guest received
 * it directly
 *
 * %g1 - new trap type for guest
 */
	ENTRY_NP(revector)
	rdhpr	%htstate, %g2
	btst	HTSTATE_HPRIV, %g2
	bnz,pn	%xcc, badtrap
	.empty

	rdpr	%tba, %g2
	wrpr	%g1, %tt
	sllx	%g1, 5, %g1
	add	%g1, %g2, %g1
	!! %g1 tba offset to branch to in tt0

	rdpr	%tl, %g3
	cmp	%g3, MAXPTL
	bgu,pn	%xcc, watchdog_guest
	sub	%g3, 1, %g2	! %g3 is either 1 or 2
	sllx	%g2, 14, %g2
	!! %g2 tt1 offset for trap vector for traps at tl>0

	add	%g1, %g2, %g1

	TRAP_GUEST(%g1, %g2, %g3)
	/*NOTREACHED*/
	SET_SIZE(revector)

	ENTRY_NP(watchdog_guest)
#ifdef DEBUG_LEGION /* { */
	LEGION_GOT_HERE
	STRAND_STRUCT(%g1)

	! Save some locals so we can use them while moving around
	! the trap levels
	stx	%l0, [%g1 + STRAND_SCR0]
	stx	%l1, [%g1 + STRAND_SCR1]
	stx	%l2, [%g1 + STRAND_SCR2]
	stx	%l3, [%g1 + STRAND_SCR3]
	mov	%g1, %l0

	! Save current %tl and %gl
	rdpr	%tl, %l2
	set	STRAND_FAIL_TL, %l1
	stx	%l2, [%l0 + %l1]
	rdpr	%gl, %l2
	set	STRAND_FAIL_GL, %l1
	stx	%l2, [%l0 + %l1]

	! for each %tl 1..%tl
	set	STRAND_FAIL_TRAPSTATE, %l1
	add	%l0, %l1, %l1
	rdpr	%tl, %l2
	sub	%l2, 1, %l3		! tl - 1
	mulx	%l3, TRAPSTATE_SIZE, %l3
	add	%l1, %l3, %l1	! %l1 pointer to current trapstate
1:	wrpr	%l2, %tl	! %l2 current tl
	rdhpr	%htstate, %l3
	stx	%l3, [%l1 + TRAPSTATE_HTSTATE]
	rdpr	%tstate, %l3
	stx	%l3, [%l1 + TRAPSTATE_TSTATE]
	rdpr	%tt, %l3
	stx	%l3, [%l1 + TRAPSTATE_TT]
	rdpr	%tpc, %l3
	stx	%l3, [%l1 + TRAPSTATE_TPC]
	rdpr	%tnpc, %l3
	stx	%l3, [%l1 + TRAPSTATE_TNPC]
	deccc	%l2
	bnz,pt	%xcc, 1b
	dec	TRAPSTATE_SIZE, %l1

	! for each %gl 0..%gl-1
	set	STRAND_FAIL_TRAPGLOBALS, %l1
	add	%l0, %l1, %l1
	rdpr	%gl, %l2
	dec	%l2		! gl - 1
	mulx	%l2, TRAPGLOBALS_SIZE, %l3
	add	%l1, %l3, %l1	! %l1 pointer to current trapglobals
1:	wrpr	%l2, %gl	! %l2 current gl
	stx	%g0, [%l1 + 0x00]
	stx	%g1, [%l1 + 0x08]
	stx	%g2, [%l1 + 0x10]
	stx	%g3, [%l1 + 0x18]
	stx	%g4, [%l1 + 0x20]
	stx	%g5, [%l1 + 0x28]
	stx	%g6, [%l1 + 0x30]
	stx	%g7, [%l1 + 0x38]
	deccc	%l2
	bge,pt	%xcc, 1b
	dec	TRAPGLOBALS_SIZE, %l1

	! Restore state
	set	STRAND_FAIL_TL, %l1
	ldx	[%l0 + %l1], %l2
	wrpr	%l2, %tl
	set	STRAND_FAIL_GL, %l1
	ldx	[%l0 + %l1], %l2
	wrpr	%l2, %gl

	DEBUG_SPINLOCK_ENTER(%g1, %g2, %g3)

	HV_PRINT_NOTRAP("WATCHDOG: strandid: ")
	ldub	[%l0 + STRAND_ID], %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" tl: ")
	rdpr	%tl, %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" tt: ")
	rdpr	%tt, %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" gl: ")
	rdpr	%gl, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n")

	HV_PRINT_NOTRAP(" trap state:\r\n");
	set	STRAND_FAIL_TRAPSTATE, %l1
	add	%l0, %l1, %l1
	rdpr	%tl, %l2
	mov	1, %l3
1:	
	HV_PRINT_NOTRAP("  tl: ");
	mov	%l3, %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" tt: ");
	ldx	[%l1 + TRAPSTATE_TT], %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" htstate: ");
	ldx	[%l1 + TRAPSTATE_HTSTATE], %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" tstate: ");
	ldx	[%l1 + TRAPSTATE_TSTATE], %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP("\r\n   tpc: ");
	ldx	[%l1 + TRAPSTATE_TPC], %g1
	HV_PRINTX_NOTRAP(%g1)

	HV_PRINT_NOTRAP(" tnpc: ");
	ldx	[%l1 + TRAPSTATE_TNPC], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n");
	inc	%l3
	cmp	%l3, %l2
	bleu,pt	%xcc, 1b
	inc	TRAPSTATE_SIZE, %l1
	
	HV_PRINT_NOTRAP(" trap globals:\r\n");
	set	STRAND_FAIL_TRAPGLOBALS, %l1
	add	%l0, %l1, %l1
	rdpr	%gl, %l2
	mov	0, %l3
1:	
	HV_PRINT_NOTRAP("  gl: ");
	HV_PRINTX_NOTRAP(%l3)

	HV_PRINT_NOTRAP("\r\n");
	HV_PRINT_NOTRAP("   %g0-%g3: ");
	ldx	[%l1 + 0x00], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	ldx	[%l1 + 0x08], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	ldx	[%l1 + 0x10], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	ldx	[%l1 + 0x18], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n");
	HV_PRINT_NOTRAP("   %g4-%g7: ");
	ldx	[%l1 + 0x20], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	ldx	[%l1 + 0x28], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	ldx	[%l1 + 0x30], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	ldx	[%l1 + 0x38], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n");
	inc	%l3
	cmp	%l3, %l2
	blu,pt	%xcc, 1b
	inc	TRAPGLOBALS_SIZE, %l1

	HV_PRINT_NOTRAP("\r\n current window:\r\n");
	HV_PRINT_NOTRAP("  %o0-%o3: ");
	mov	%o0, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	mov	%o1, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	mov	%o2, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	mov	%o3, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n");
	HV_PRINT_NOTRAP("  %o4-%o7: ");
	mov	%o4, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	mov	%o5, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	mov	%o6, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP(" ");
	mov	%o7, %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n");

	HV_PRINT_NOTRAP("rtba: ")
	VCPU_STRUCT(%g1)
	ldx	[%g1 + CPU_RTBA], %g1
	HV_PRINTX_NOTRAP(%g1)
	HV_PRINT_NOTRAP("\r\n");

	DEBUG_SPINLOCK_EXIT(%g1)

	! Restore saved locals
	ldx	[%l0 + STRAND_SCR3], %l3
	ldx	[%l0 + STRAND_SCR2], %l2
	ldx	[%l0 + STRAND_SCR1], %l1
	ldx	[%l0 + STRAND_SCR0], %l0
#endif /* } DEBUG_LEGION */

	! Disable MMU
	ldxa	[%g0]ASI_LSUCR, %g1
	set	(LSUCR_DM | LSUCR_IM), %g2
	andn	%g1, %g2, %g1	! disable MMU
	stxa	%g1, [%g0]ASI_LSUCR

	! Get real-mode trap table base address
	VCPU_STRUCT(%g3)
	ldx	[%g3 + CPU_RTBA], %g3
	add	%g3, (TT_WDR << TT_OFFSET_SHIFT), %g3

	! cache TT, TSTATE for when TL is changed
	rdpr	%tt, %g5
	rdpr	%tstate, %g6

	/*
	 * We will enter the guests WDR handler at MAXPTL
	 */
	wrpr	%g0, MAXPTL, %tl

	! reset TT, TSTATE for TL = MAXPTL
	wrpr	%g5, %tt
	wrpr	%g6, %tstate

	mov	%g3, %o0	! clobbering %o0, can't use a global as GL changes
	wrpr	%g0, MAXPGL, %gl

	! %o0	Guest WDR PC
	TRAP_GUEST(%o0, %g1, %g2)

	/*NOTREACHED*/
	SET_SIZE(watchdog_guest)


	! ttrace_generic
	! General purpose trap trace routine.
	!
	! Records state. (See traptrace.h for details.)
	! Variable Fields:
	!	All fields are zeroed.
	!
	! Expects: %g7 to contain PC of trap table entry
	!
	ENTRY_NP(ttrace_generic)
	TTRACE_PTR(%g1, %g2, 1f, 1f)
	TTRACE_STATE(%g2, TTRACE_TYPE_HV, %g3, %g4)
	sth	%g0, [%g2 + TTRACE_ENTRY_TAG]
	stx	%g0, [%g2 + TTRACE_ENTRY_F1]
	stx	%g0, [%g2 + TTRACE_ENTRY_F2]
	stx	%g0, [%g2 + TTRACE_ENTRY_F3]
	stx	%g0, [%g2 + TTRACE_ENTRY_F4]
	TTRACE_NEXT(%g2, %g3, %g4, %g5)
1:	TTRACE_EXIT(%g7, %g1)
	SET_SIZE(ttrace_generic)

	! ttrace_dmmu
	! Traces data mmu exceptions.
	!
	! Records state. (See traptrace.h for details.)
	! Variable Fields:
	!	F1 = DMMU SFSR
	!   
	! Expects: %g7 to contain PC of trap table entry
	!
	ENTRY_NP(ttrace_dmmu)
	TTRACE_PTR(%g1, %g2, 1f, 1f)
	TTRACE_STATE(%g2, TTRACE_TYPE_HV, %g3, %g4)
	sth	%g0, [%g2 + TTRACE_ENTRY_TAG]
	mov	MMU_SFSR, %g4
	ldxa	[%g4]ASI_DMMU, %g4
	stx	%g4, [%g2 + TTRACE_ENTRY_F1]
	stx	%g0, [%g2 + TTRACE_ENTRY_F2]
	stx	%g0, [%g2 + TTRACE_ENTRY_F3]
	stx	%g0, [%g2 + TTRACE_ENTRY_F4]
	TTRACE_NEXT(%g2, %g3, %g4, %g5)
1:	TTRACE_EXIT(%g7, %g1)
	SET_SIZE(ttrace_dmmu)

	! ttrace_hcall
	! Traces hypervisor call traps.
	!
	! Records state. (See traptrace.h for details.)
	! Variable Fields:
	!	TAG = %o5, Hypervisor Call Number
	!	F1  = %o0, Argument 0
	!	F2  = %o1, Argument 1
	!	F3  = %o2, Argument 2
	!	F4  = %o3, Argument 3
	!
	! Expects: %g7 to contain PC of trap table entry
	!
	ENTRY_NP(ttrace_hcall)
	TTRACE_PTR(%g1, %g2, 1f, 1f)
	TTRACE_STATE(%g2, TTRACE_TYPE_HV, %g3, %g4)
	sth	%o5, [%g2 + TTRACE_ENTRY_TAG]
	stx	%o0, [%g2 + TTRACE_ENTRY_F1]
	stx	%o1, [%g2 + TTRACE_ENTRY_F2]
	stx	%o2, [%g2 + TTRACE_ENTRY_F3]
	stx	%o3, [%g2 + TTRACE_ENTRY_F4]
	TTRACE_NEXT(%g2, %g3, %g4, %g5)
1:	TTRACE_EXIT(%g7, %g1)
	SET_SIZE(ttrace_hcall)

	! ttrace_mmu_map
	! Traces mmu map traps.
	!
	! Records state. (See traptrace.h for details.)
	! Variable Fields:
	!	F1 = vaddr
	!	F2 = ctx
	!	F3 = TTE
	!	F4 = flags
	!
	! Expects: %g7 to contain PC of trap table entry
	!
	ENTRY_NP(ttrace_mmu_map)
	TTRACE_PTR(%g1, %g2, 1f, 1f)
	TTRACE_STATE(%g2, TTRACE_TYPE_HV, %g3, %g4)
	sth	%g0, [%g2 + TTRACE_ENTRY_TAG]
	stx	%o0, [%g2 + TTRACE_ENTRY_F1]
	stx	%o1, [%g2 + TTRACE_ENTRY_F2]
	stx	%o2, [%g2 + TTRACE_ENTRY_F3]
	stx	%o3, [%g2 + TTRACE_ENTRY_F4]
	TTRACE_NEXT(%g2, %g3, %g4, %g5)
1:	TTRACE_EXIT(%g7, %g1)
	SET_SIZE(ttrace_mmu_map)

	! ttrace_mmu_unmap
	! Traces MMU Unmap traps.
	!
	! Records state. (See traptrace.h for details.)
	! Variable Fields:
	!	F1 = vaddr
	!	F2 = ctx
	!	F3 = flags
	!
	! Expects: %g7 to contain PC of trap table entry
	!
	ENTRY_NP(ttrace_mmu_unmap)
	TTRACE_PTR(%g1, %g2, 1f, 1f)
	TTRACE_STATE(%g2, TTRACE_TYPE_HV, %g3, %g4)
	sth	%g0, [%g2 + TTRACE_ENTRY_TAG]
	stx	%o0, [%g2 + TTRACE_ENTRY_F1]
	stx	%o1, [%g2 + TTRACE_ENTRY_F2]
	stx	%o2, [%g2 + TTRACE_ENTRY_F3]
	stx	%g0, [%g2 + TTRACE_ENTRY_F4]
	TTRACE_NEXT(%g2, %g3, %g4, %g5)
1:	TTRACE_EXIT(%g7, %g1)
	SET_SIZE(ttrace_mmu_unmap)
