/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_subr.s
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

#pragma ident	"@(#)errors_subr.s	1.6	07/08/03 SMI"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <cache.h>

#include <offsets.h>
#include <util.h>
#include <abort.h>
#include <debug.h>
#include <dram.h>
#include <cmp.h>
#include <intr.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_soc.h>
#include <error_asm.h>

	/*
	 * Enable errors
	 */
	ENTRY(enable_errors_strand)

	! enable CMP reporting
	mov	CORE_ERR_REPORT_EN, %g4
	setx	CORE_ERRORS_ENABLE, %g5, %g6
	stxa	%g6, [%g4]ASI_ERR_EN

	! enable CMP traps
	mov	CORE_ERR_TRAP_EN, %g4
	setx	CORE_ERROR_TRAP_ENABLE, %g5, %g6
	stxa	%g6, [%g4]ASI_ERR_EN

	HVRET

	SET_SIZE(enable_errors_strand)

	ENTRY(enable_errors_chip)

	/*
	 * Target SOC/L2 errors at current strand
	 */
	PHYS_STRAND_ID(%g2)
	setx	SOC_ERRORSTEER_REG, %g3, %g4
	stx	%g2, [%g4]

	set	L2_ERRORSTEER_MASK, %g1
	sllx	%g2, L2_ERRORSTEER_SHIFT, %g2
	and	%g2, %g1, %g2
	setx	L2_CONTROL_REG, %g4, %g5
	set	(NO_L2_BANKS - 1), %g3
1:
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g6, 2f)

	sllx	%g3, L2_BANK_SHIFT, %g4
	ldx	[%g5 + %g4], %g6
	andn	%g6, %g1, %g6
	or	%g6, %g2, %g6
	stx	%g6, [%g5 + %g4]
2:
	! next L2 bank
	brgz,pt	%g3, 1b
	dec	%g3
	
	/*
	 * Clear DRAM ESR/FBD/ND for all banks
	 * Set the DRAM ECC/FBR Error Count registers
	 */
	set	(NO_DRAM_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 2f)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	stx	%g4, [%g2]	! clear DRAM ESR 	RW1C
	stx	%g0, [%g2]	! clear DRAM ESR 	RW

#ifndef DEBUG_LEGION

	setx	DRAM_FBD_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	stx	%g0, [%g4]	! clear DRAM FBD SYND	RW

	setx	DRAM_FBR_COUNT_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	add	%g5, %g4, %g5
	mov	DRAM_ERROR_COUNTER_FBR_RATIO, %g4
	stx	%g4, [%g5]

#endif
2:
	! next bank
	brgz,pt	%g3, 1b
	dec	%g3

	! enable L2$ and DRAM error traps
	set	(NO_L2_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, 2f)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g4, %g5, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g4]		! clear ESR	RW1C
	stx	%g0, [%g4]		! clear ESR	RW

	setx	L2_ERROR_ADDRESS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g4, %g5, %g4
	stx	%g0, [%g4]		! clear EAR	RW

	setx	L2_ERROR_NOTDATA_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	or	%g4, %g5, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g4]		! clear NDESR	RW1C
	stx	%g0, [%g4]		! clear NDESR	RW

	setx	L2_ERROR_ENABLE_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g4
	add	%g4, %g5, %g4
	ldx	[%g4], %g2
	or	%g2, (L2_NCEEN | L2_CEEN), %g2
	stx	%g2, [%g4]
2:
	brgz,pt	%g3, 1b
	dec	%g3

	! clear the SOC STATUS register before enabling logs/traps
	setx	SOC_ERROR_STATUS_REG, %g5, %g6
	stx	%g0, [%g6]

	! enable all SOC error recording -- reset/config?
	setx	SOC_ERROR_LOG_ENABLE, %g5, %g6
	setx	SOC_ALL_ERRORS, %g3, %g1
	stx	%g1, [%g6]

	! enable all SOC error traps -- reset/config?
	setx	SOC_ERROR_TRAP_ENABLE, %g5, %g6
	setx	SOC_ALL_ERRORS, %g3, %g1
	stx	%g1, [%g6]

	! enable all SOC fatal errors -- reset/config?
	setx	SOC_FATAL_ERROR_ENABLE, %g5, %g6
	setx	SOC_FATAL_ERRORS, %g3, %g1
	stx	%g1, [%g6]

	HVRET

	SET_SIZE(enable_errors_chip)

#ifdef DEBUG_LEGION
	/*
	 * Print Service Error Report (SER) to console
	 * %g7	return address
	 */
	ENTRY(print_diag_ser)
	GET_ERR_DIAG_BUF(%g1, %g2)
	brz,pn	%g1, 1f
	nop

	mov	%g7, %g6

	PRINT("Error type : 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_ERROR_TYPE], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("Report type : 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_REPORT_TYPE], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("TOD: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_TOD], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("EHDL : 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_EHDL], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("ERR_STICK: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_ERR_STICK], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("CPUVER: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_CPUVER], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("CPUSERIAL: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_SERIAL], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("TSTATE: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_TSTATE], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("HTSTATE: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_HTSTATE], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("TPC: 0x");
	ldx	[%g1 + ERR_DIAG_RPRT_TPC], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("CPUID : 0x");
	lduh	[%g1 + ERR_DIAG_RPRT_CPUID], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("TT: 0x");
	lduh	[%g1 + ERR_DIAG_RPRT_TT], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("TL : 0x");
	ldub	[%g1 + ERR_DIAG_RPRT_TL], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	mov	%g6, %g7
1:
	HVRET
	SET_SIZE(print_diag_ser)

	
	/*
	 * print diag buf data to console
	 * %g7	return address
	 */	
	ENTRY(print_diag_buf)
	GET_ERR_DIAG_BUF(%g1, %g2)
	brz,pn	%g1, 1f
	nop

	mov	%g7, %g6

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	PRINT("ISFSR: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_SPARC_ISFSR], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("DSFSR: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_SPARC_DSFSR], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("DSFAR: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_SPARC_DSFAR], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("DESR: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_SPARC_DESR], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("DFESR: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_SPARC_DFESR], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("BANK 0: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 1: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 2: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 3: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 4: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 4)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 4)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 4)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 5: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 5)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 5)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 5)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 6: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 6)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 6)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 6)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("BANK 7: L2_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ESR + (ERR_DIAG_BUF_L2_CACHE_ESR_INCR * 7)], %g2
	PRINTX(%g2)
	PRINT(" : L2_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_EAR + (ERR_DIAG_BUF_L2_CACHE_EAR_INCR * 7)], %g2
	PRINTX(%g2)
	PRINT(" : L2_ND: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_L2_CACHE_ND + (ERR_DIAG_BUF_L2_CACHE_ND_INCR * 7)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	
	PRINT("Bank 0: DRAM_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_ESR + (ERR_DIAG_BUF_DRAM_ESR_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_EAR + (ERR_DIAG_BUF_DRAM_EAR_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_LOC: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_LOC + (ERR_DIAG_BUF_DRAM_LOC_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\n");
	PRINT("        DRAM_CTR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_CTR + (ERR_DIAG_BUF_DRAM_CTR_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_FBD :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_FBD + (ERR_DIAG_BUF_DRAM_FBD_INCR * 0)], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("Bank 1: DRAM_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_ESR + (ERR_DIAG_BUF_DRAM_ESR_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_EAR + (ERR_DIAG_BUF_DRAM_EAR_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_LOC: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_LOC + (ERR_DIAG_BUF_DRAM_LOC_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\n");	
	PRINT("        DRAM_CTR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_CTR + (ERR_DIAG_BUF_DRAM_CTR_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_FBD :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_FBD + (ERR_DIAG_BUF_DRAM_FBD_INCR * 1)], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("Bank 2: DRAM_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_ESR + (ERR_DIAG_BUF_DRAM_ESR_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_EAR + (ERR_DIAG_BUF_DRAM_EAR_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_LOC: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_LOC + (ERR_DIAG_BUF_DRAM_LOC_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\n");	
	PRINT("        DRAM_CTR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_CTR + (ERR_DIAG_BUF_DRAM_CTR_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_FBD :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_FBD + (ERR_DIAG_BUF_DRAM_FBD_INCR * 2)], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	PRINT("Bank 3: DRAM_ESR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_ESR + (ERR_DIAG_BUF_DRAM_ESR_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_EAR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_EAR + (ERR_DIAG_BUF_DRAM_EAR_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_LOC: 0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_LOC + (ERR_DIAG_BUF_DRAM_LOC_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\n");	
	PRINT("        DRAM_CTR :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_CTR + (ERR_DIAG_BUF_DRAM_CTR_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT(" : DRAM_FBD :0x");
	ldx	[%g1 + ERR_DIAG_BUF_DRAM_FBD + (ERR_DIAG_BUF_DRAM_FBD_INCR * 3)], %g2
	PRINTX(%g2)
	PRINT("\r\n");

	mov	%g6, %g7
1:
	HVRET
	SET_SIZE(print_diag_buf)

	/*
	 * print sun4v erpt data to console
	 * %g7	return address
	 */
	ENTRY(print_sun4v_erpt)
	GET_ERR_SUN4V_RPRT_BUF(%g1, %g2)
	brz,pn	%g1, 1f
	nop

	mov     %g7, %g6

	PRINT("EHDL : 0x");
	ldx     [%g1 + ERR_SUN4V_RPRT_G_EHDL], %g2	! ehdl
	PRINTX(%g2)
        PRINT("\r\n");
	
	PRINT("STICK : 0x");
	ldx	[%g1 + ERR_SUN4V_RPRT_G_STICK], %g2	! stick
	PRINTX(%g2)
        PRINT("\r\n");
	
	PRINT("EDESC : 0x");
	ld	[%g1 + ERR_SUN4V_RPRT_EDESC], %g2	! edesc
	PRINTX(%g2)
        PRINT("\r\n");
	
	PRINT("ATTR : 0x");
	ld	[%g1 + ERR_SUN4V_RPRT_ATTR], %g2	! attr
	PRINTX(%g2)
        PRINT("\r\n");
	
	PRINT("ADDR : 0x");
	ldx	[%g1 + ERR_SUN4V_RPRT_ADDR], %g2	! addr
	PRINTX(%g2)
        PRINT("\r\n");
	
	PRINT("SZ : 0x");
	ld	[%g1 + ERR_SUN4V_RPRT_SZ], %g2		! sz
	PRINTX(%g2)
        PRINT("\r\n");

	PRINT("CPUID : 0x");
	lduh	[%g1 + ERR_SUN4V_RPRT_G_CPUID], %g2	! cpuid
	PRINTX(%g2)
        PRINT("\r\n");

	PRINT("SECS : 0x");
	lduh	[%g1 + ERR_SUN4V_RPRT_G_SECS], %g2	! secs
	PRINTX(%g2)
        PRINT("\r\n");

	PRINT("ASI : 0x");
	lduh	[%g1 + ERR_SUN4V_RPRT_ASI], %g2		! asi/pad
	PRINTX(%g2)
        PRINT("\r\n");

	PRINT("REG : 0x");
	lduh	[%g1 + ERR_SUN4V_RPRT_REG], %g2		! reg
	PRINTX(%g2)
        PRINT("\r\n");
	
	mov     %g6, %g7	
1:
        HVRET
        SET_SIZE(print_sun4v_erpt)

#endif	/* DEBUG */

	ENTRY(relocate_error_tables)
	mov	%g7, %g6

	setx	instruction_access_MMU_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	data_access_MMU_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	internal_processor_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	hw_corrected_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	store_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	data_access_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	sw_recoverable_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	instruction_access_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	l2c_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	soc_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	dram_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	precise_dau_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	disrupting_dau_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	precise_ldau_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	disrupting_ldau_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	dbu_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)
	setx	sw_abort_errors, %g2, %g3
	HVCALL(relocate_error_table_entries)

	mov	%g6, %g7
	HVRET
	SET_SIZE(relocate_error_tables)

	/*
	 * Relocate the function pointers in an error table
	 * %g3	error_table
	 * %g5	relocation offset
	 * %g7	return address
	 * %g1	clobbered
	 * %g2, %g4, %g6	preserved
	 */
	ENTRY(relocate_error_table_entries)
	sub	%g3, %g5, %g3
1:
	ldx	[%g3 + ERR_GUEST_REPORT_FCN], %g1
	brz	%g1, 2f
	sub	%g1, %g5, %g1
	stx	%g1, [%g3 + ERR_GUEST_REPORT_FCN]
2:
	ldx	[%g3 + ERR_REPORT_FCN], %g1
	brz	%g1, 3f
	sub	%g1, %g5, %g1
	stx	%g1, [%g3 + ERR_REPORT_FCN]
3:
	ldx	[%g3 + ERR_CORRECT_FCN], %g1
	brz	%g1, 4f
	sub	%g1, %g5, %g1
	stx	%g1, [%g3 + ERR_CORRECT_FCN]
4:
	ldx	[%g3 + ERR_STORM_FCN], %g1
	brz	%g1, 5f
	sub	%g1, %g5, %g1
	stx	%g1, [%g3 + ERR_STORM_FCN]
5:
	ldx	[%g3 + ERR_PRINT_FCN], %g1
	brz	%g1, 6f
	sub	%g1, %g5, %g1
	stx	%g1, [%g3 + ERR_PRINT_FCN]

6:
	ld	[%g3 + ERR_FLAGS], %g1
	btst	ERR_LAST_IN_TABLE, %g1
	bz,pn	%xcc, 1b
	add	%g3, ERROR_TABLE_ENTRY_SIZE, %g3

	HVRET

	SET_SIZE(relocate_error_table_entries)

	/*
	 * If we get an error trap which we cannot identify we want
	 * a basic service report (TT, TPC etc) sent to the FERG.
	 * To make this happen the error_table_entry for that trap
	 * must have an error report function.
	 *
	 * XXXX
	 * Is there any useful information we could gather here ?
	 * XXXX
	 */
	ENTRY(dump_no_error)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	HVRET

	SET_SIZE(dump_no_error)

	/*
	 * Clear AMB FBDIMM memory errors
	 *
	 * These regs are RWCST, which is write 1 to clear,
	 * and sticky through a link reset.
	 */
	ENTRY(clear_amb_errors)

	STORE_ERR_RETURN_ADDR(%g7, %g1, %g2)

	set	(NO_DRAM_BANKS - 1), %g3
0:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 4f)

	/*
	 * How many channels to clear ?
	 */
	setx	DRAM_SNGL_CHNL_MODE_BASE, %g2, %g1
	sllx    %g3, DRAM_BANK_SHIFT, %g2
	or	%g1, %g2, %g1
	ldx	[%g1], %g2
	and	%g2, 1, %g2		! %g2 == 1 single channel mode
	movrz	%g2, 1, %g1		! loop counter 1 for 2 channels
	movrnz	%g2, 0, %g1		! loop counter 0 for 1 channel
1:
	/*
	 * How many DIMMs per channel ?
	 */
	setx	DRAM_DIMM_PRESENT_BASE, %g2, %g4
	sllx    %g3, DRAM_BANK_SHIFT, %g2
	or	%g4, %g2, %g4
	ldx	[%g4], %g4
	and	%g4, 0xf, %g4		! max AMB ID
2:
	! %g3	bank
	! %g1	channel
	! %g4	DIMM

	sllx	%g4, CONFIG_ADDR_AMB_POS, %g6
	! %g6	AMB ID of Configuration register access

	/* clear FERR */
	set	((CONFIG_FUNCTION_FBD << CONFIG_FUNCTION_SHIFT) | DRAM_FBDIMM_FERR), %g5
	or	%g5, %g6, %g5			! AMB ID
	sllx	%g1, CONFIG_ADDR_CH_POS, %g2	! Channel of Configuration register access
	or	%g5, %g2, %g5
	! %g5	channel/AMB ID/FERR

	setx	DRAM_CONFIG_REG_ACC_ADDR_BASE, %g2, %g7
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g7, %g2, %g7
	stx	%g5, [%g7]

	setx	DRAM_CONFIG_REG_ACC_DATA_BASE, %g2, %g7
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g7, %g2, %g7
	! config registers are RWCST
	mov	-1, %g5
	stx	%g5, [%g7]
	
	/* clear NERR */
	set	((CONFIG_FUNCTION_FBD << CONFIG_FUNCTION_SHIFT) | DRAM_FBDIMM_NERR), %g5
	or	%g5, %g6, %g5			! AMB ID
	sllx	%g1, CONFIG_ADDR_CH_POS, %g2	! Channel of Configuration register access
	or	%g5, %g2, %g5
	! %g5	channel/AMB ID/FERR

	setx	DRAM_CONFIG_REG_ACC_ADDR_BASE, %g2, %g7
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g7, %g2, %g7
	stx	%g5, [%g7]

	setx	DRAM_CONFIG_REG_ACC_DATA_BASE, %g2, %g7
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g7, %g2, %g7
	! config registers are RWCST
	mov	-1, %g5
	stx	%g5, [%g7]

	brgz,pt	%g4, 2b
	dec	%g4		! next AMB ID

	brgz,pt	%g1, 1b		! next channel
	dec	%g1

4:
	brgz,pt	%g3, 0b
	dec	%g3		! next DRAM bank

	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET

	SET_SIZE(clear_amb_errors)

	/*
	 * Determine whether a particular error has been steered to this
	 * CPU rather than actually occurring on a resource owned by this
	 * guest. If it has, send the error details to a CPU owned by the
	 * guest which owns the resource which took the error and then just
	 * allow this CPU/guest to continue.
	 *
	 * %g1 - %g6	clobbered
	 * %g7		return address
	 */
	ENTRY(errors_check_steering)

	/*
	 * Errors causing precise/deferred traps will never require rerouting. 
	 * Also, errors causing hw_corrected_error traps are always corrected
	 * by the hardware so no guest intervention is required. Only
	 * sw_recoverable_error traps might require a sun4v guest error
	 * report to be rerouted to a different guests CPU.
	 */
	rdpr	%tt, %g2
	cmp	%g2, TT_ASYNCERR
	bne,pt	%xcc, errors_check_steering_exit
	nop

	/*
	 * Only MEM reports might need rerouting
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g4)
	ld	[%g2 + ERR_SUN4V_RPRT_ATTR], %g4	! attr
	mov	1, %g3
	sllx	%g3, SUN4V_MEM_RPRT, %g3
	and	%g4, %g3, %g4
	brz,pt	%g4, errors_check_steering_exit
	nop

	/*
	 * Only MEM reports with a valid RA can be rerouted
	 */	
	ldx	[%g2 + ERR_SUN4V_RPRT_ADDR], %g4
	setx	CPU_ERR_INVALID_RA, %g3, %g5
	cmp	%g4, %g5
	be,pn	%xcc, errors_check_steering_exit
	nop

	/*
	 * Does this RA belong to this guest ?
	 */
	RA2PA_RANGE_CHECK(%g2, %g4, ERPT_MEM_SIZE, 1f, %g5)
	! yes, it does.
	ba,pt	%xcc, errors_check_steering_exit
	nop
1:
	! nope, some other guest

	/*
	 * Find the guest which owns this RA.
	 * For each guest loop through the ra2pa_segment array and check the
	 * RA against the base/limit
	 * %g4	RA
	 */
	ROOT_STRUCT(%g2)
	ldx     [%g2 + CONFIG_GUESTS], %g2	! &guests[0]
	set	NGUESTS - 1, %g3		! %g3	guest loop counter
1:
	RA2PA_RANGE_CHECK(%g2, %g4, ERPT_MEM_SIZE, 2f, %g5)
	! we have a valid RA so this is the guest for this error
	ba,pt	%xcc, 3f
	nop
2:
	set	GUEST_SIZE, %g5
	add	%g2, %g5, %g2			! guest++
	brnz,pt	%g3, 1b
	dec	%g3				! nguests--

	! no guest found for this RA
	ba,pt	%xcc, errors_check_steering_exit
	nop

3:
	! %g2	&guest
	! %g4	RA	

	! is it for the guest we are running on ? (redundant check ...)
	GUEST_STRUCT(%g1)
	cmp	%g1, %g2	
	be,pt	%xcc, errors_check_steering_exit
	nop

	! go and finish re-routing this error
	ba	cpu_reroute_error
	nop

	/*
	 * If cpu_reroute_error() returns it has failed to reroute the
	 * error so just return and take the sun4v report on this guest
	 */

errors_check_steering_exit:

	HVRET	

	SET_SIZE(errors_check_steering)

	/*
	 * re-route an error report (cont'd)
	 * 1. select one of the active CPUs for that guest
	 * 2. Copy the data from the error erport into that
	 *    CPUs cpu struct
	 * 3. Send a VECINTR_ERROR_XCALL to that CPU
	 * 4. Clear the diag_buf/sun4v erpt in_use bits
	 * 5: RETRY
	 *
	 * %g2	target guest
	 * %g4	RA
	 * %g7	return address
	 */

	ENTRY_NP(cpu_reroute_error)

	/*
         * find first live cpu in guest->vcpus
	 * Then deliver the error to that vcpu, and interrupt
	 * the strand it is running on to make that happen.
         */
	add	%g2, GUEST_VCPUS, %g2
	mov	0, %g3
1:
	cmp	%g3, NVCPUS
	be,pn	%xcc, cpu_reroute_error_exit
	  nop

	mulx	%g3, GUEST_VCPUS_INCR, %g5
	ldx	[%g2 + %g5], %g1
	brz,a,pn %g1, 1b
	  inc	%g3
	! check whether this CPU is running guest code ?
	ldx     [%g1 + CPU_STATUS], %g5
	cmp	%g5, CPU_STATE_RUNNING
	bne,pt	%xcc, 1b
	  inc	%g3
	
	! %g3	target vcpu id
	! %g1	&vcpus[target]

	ldx	[%g1 + CPU_STRAND], %g1

	/*
	 * It is possible that the CPUs rerouted data is already in use.
	 * We use the rerouted_addr field as a spinlock. The target CPU
	 * will set this to 0 after reading the error data allowing us
	 * to re-use the rerouting fields.
	 * See cpu_err_rerouted() below.
	 *
	 * %g1	&strands[target]
	 * %g3	target cpuid
	 * %g4	RA
	 */
	set	STRAND_REROUTED_ADDR, %g2
	add	%g1, %g2, %g6
1:	casx	[%g6], %g0, %g4
	brnz,pn	%g4, 1b
	nop


	! get the data out of the current STRAND's sun4v erpt and store
	! in the target STRAND struct
	GET_ERR_SUN4V_RPRT_BUF(%g5, %g6)
	set	STRAND_REROUTED_CPU, %g4
	stx	%g3, [%g1 + %g4]
	ldx	[%g5 + ERR_SUN4V_RPRT_G_EHDL], %g6	! ehdl
	set	STRAND_REROUTED_EHDL, %g4
	stx	%g6, [%g1 + %g4]
	ld	[%g5 + ERR_SUN4V_RPRT_ATTR], %g6	! attr
	set	STRAND_REROUTED_ATTR, %g4
	stx	%g6, [%g1 + %g4]
	ldx	[%g5 + ERR_SUN4V_RPRT_G_STICK], %g6	! stick
	! STICK is probably not necessary. I doubt if FMA checks
	! both EHDL/STICK when looking for duplicate reports,
	! but it doesn't kill us to do it.
	set	STRAND_REROUTED_STICK, %g4
	stx	%g6, [%g1 + %g4]

	! send an x-call to the target CPU
	ldub	[%g1 + STRAND_ID], %g3
	sllx    %g3, INT_VEC_DIS_VCID_SHIFT, %g3
	mov     VECINTR_ERROR_XCALL, %g5
	or      %g3, %g5, %g3
	stxa    %g3, [%g0]ASI_INTR_UDB_W

	/*
	 * Clear the in_use bit on the sun4v report buffer
	*/
        GET_ERR_SUN4V_RPRT_BUF(%g2, %g4)
	brnz,a,pt       %g1, 1f
          stub    %g0, [%g2 + ERR_SUN4V_RPRT_IN_USE]
1:

	/*
	 * Clear the error report in_use field
	 */
	GET_ERR_DIAG_BUF(%g1, %g2)
	brnz,a,pt       %g1, 1f
	  stub	%g0, [%g1 + ERR_DIAG_RPRT_IN_USE]
1:
	/*
	 * error is rerouted, get out of here
	 */
	GET_ERR_TABLE_ENTRY(%g1, %g2)

	/*
	 * Does the trap handler for this error park the strands ?
	 * If yes, resume them here.
	 */
	ld	[%g1 + ERR_FLAGS], %g2
	btst	ERR_STRANDS_PARKED, %g2
	bz,pn	%xcc, 1f
	nop

	RESUME_ALL_STRANDS(%g3, %g4, %g5, %g6)

1:
	/*
	 * check whether we stored the globals and re-used
	 * at MAXPTL
	 */
	btst	ERR_GL_STORED, %g2
	bz,pt	%xcc, 1f
	nop

	RESTORE_GLOBALS(retry)
1:
	retry

cpu_reroute_error_exit:

	/*
	 * failed to find a guest to send this error to ...
	 */
	HVRET	

	SET_SIZE(cpu_reroute_error)

	/*
	 * An error has been re-routed to this STRAND.
	 * The EHDL/ADDR/STICK/ATTR have been stored in the STRAND struct
	 * by the STRAND that originally detected the error.
	 *
	 * Note: STICK may not be strictly necessary
	 */
	ENTRY_NP(cpu_err_rerouted)

1:
	STRAND_STRUCT(%g6)

	set	STRAND_REROUTED_ATTR, %g4
	ldx	[%g6 + %g4], %g3

	HVCALL(error_handler_sun4v_report)

	/*
	 * Must ensure that we get a sun4v report buffer, spin if necessary
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, 1b
	nop

	STRAND_STRUCT(%g6)

	set	STRAND_REROUTED_CPU, %g4
	ldx	[%g6 + %g4], %g4
	stx     %g4, [%g2 + ERR_SUN4V_RPRT_G_CPUID]
	STRAND_PUSH(%g4, %g3, %g5)

	set	STRAND_REROUTED_EHDL, %g4
	ldx	[%g6 + %g4], %g4
	stx     %g4, [%g2 + ERR_SUN4V_RPRT_G_EHDL]

	set	STRAND_REROUTED_STICK, %g4
	ldx	[%g6 + %g4], %g4
	stx     %g4, [%g2 + ERR_SUN4V_RPRT_G_STICK]

	set	STRAND_REROUTED_ATTR, %g4
	ldx	[%g6 + %g4], %g4
	stw     %g4, [%g2 + ERR_SUN4V_RPRT_ATTR]
	STRAND_PUSH(%g4, %g3, %g5)

	! keep ADDR after EHDL/STICK/ATTR to avoid race
	set	STRAND_REROUTED_ADDR, %g4
	ldx	[%g6 + %g4], %g1

	! Clear the strand->rerouted-addr field now to let other
	! errors in.
	stx	%g0, [%g6 + %g4]
	stx     %g1, [%g2 + ERR_SUN4V_RPRT_ADDR]

	set     EDESC_UE_RESUMABLE, %g4
	stw     %g4, [%g2 + ERR_SUN4V_RPRT_EDESC]

	mov     ERPT_MEM_SIZE, %g4
	st      %g4, [%g2 + ERR_SUN4V_RPRT_SZ]

	/*
	 * gueue a resumable error report and exit
	 */
	add     %g2, ERR_SUN4V_CPU_ERPT, %g2
	HVCALL(queue_resumable_erpt)

	/*
	 * Clear the in_use bit on the sun4v report buffer
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g4)
	stub    %g0, [%g2 + ERR_SUN4V_RPRT_IN_USE]

	! get the error CPUID to do the necessary cleanup
	STRAND_POP(%g2, %g3)			! ATTR
	STRAND_POP(%g1, %g3)

	/*
	 * This should be a CPU error report for a strand in error
	 */
	cmp	%g2, SUN4V_CPU_RPRT
	bne,pt	%xcc, 1f
	nop

	/*
	 * Must be a different CPU ID for a strand in error
	 */	
	VCPU_STRUCT(%g3)
	ldub	[%g3 + CPU_VID], %g3
	cmp	%g1, %g4
	be,pt	%xcc, 1f
	nop

	/*
	 * get the vcpu and strand for the vcpu that took the error
	 * %g1	error vcpu
	 */
	GUEST_STRUCT(%g3)
	sllx    %g1, GUEST_VCPUS_SHIFT, %g1
	add     %g1, %g3, %g1
	add     %g1, GUEST_VCPUS, %g1
	ldx     [%g1], %g1                      ! err vcpu struct
	ldx     [%g1 + CPU_STRAND], %g2         ! err strand struct

	! deschedule and stop the vcpu
	! %g1 - vcpu struct
	! %g2 - strand struct
	HVCALL(desched_n_stop_vcpu)

	/*
	 * If the heartbeat is disabled then it was running on the failed
	 * cpu and needs to be restarted on this cpu.
	 */
	ROOT_STRUCT(%g2)
	ldx	[%g2 + CONFIG_HEARTBEAT_CPU], %g2
	cmp	%g2, -1
	bne,pt	%xcc, 1f
	nop
	HVCALL(heartbeat_enable)
1:

	/*
	 * and exit the x-call handler
	 */
	retry

	SET_SIZE(cpu_err_rerouted)

	ENTRY_NP(strand_in_error)

	STRAND_STRUCT(%g5)
	ldub	[%g5 + STRAND_ID], %g5
	mov	1, %g4
	sllx	%g4, %g5, %g4
    
	ROOT_STRUCT(%g2)		! config ptr

	! clear this strand from the active list
	ldx	[%g2 + CONFIG_STACTIVE], %g3
	bclr	%g4, %g3
	stx	%g3, [%g2 + CONFIG_STACTIVE]

	! set this strand in the halted list
	ldx	[%g2 + CONFIG_STHALT], %g3
	bset	%g4, %g3
	stx	%g3, [%g2 + CONFIG_STHALT]

	! find another idle strand for re-targetting
	ldx	[%g2 + CONFIG_STIDLE], %g3
	mov	0, %g6
.find_strand:
	cmp	%g5, %g6
	be,pn	%xcc, .next_strand
	mov	1, %g4
	sllx	%g4, %g6, %g4	
	andcc	%g3, %g4, %g0
	bnz,a	%xcc, .found_a_strand
	  nop

.next_strand:
	inc	%g6
	cmp	%g6, NSTRANDS
	bne,pn	%xcc, .find_strand
	  nop

	/*
	 * No usable active strands are left in the
	 * system, force host exit
	 */
#ifdef CONFIG_VBSC_SVC
	ba,a	vbsc_guest_exit
#else
        LEGION_EXIT(%o0)
#endif

.found_a_strand:
	! %g5	this strand ID
	! %g6	target strand ID

	/*
	 * handoff L2 Steering CPU
	 * If we are the steering cpu, migrate it to our chosen one
	 */
	setx	L2_CONTROL_REG, %g3, %g4
	ldx	[%g4], %g2			! current setting
	srlx	%g2, L2_ERRORSTEER_SHIFT, %g3
	and	%g3, (NSTRANDS - 1), %g3
	cmp	%g3, %g5			! is this steering strand ?
	bnz,pt	%xcc, 1f
	nop

	! It is the L2 Steering strand. Migrate responsibility to tgt strand
	sllx	%g3, L2_ERRORSTEER_SHIFT, %g3
	andn	%g3, %g2, %g2			! remove this strand
	sllx	%g6, L2_ERRORSTEER_SHIFT, %g3
	or	%g2, %g3, %g2
	stx	%g2, [%g4]

1:
	mov	%g5, %g1			! this strand
	mov	%g6, %g2			! target strand

#ifdef	CONFIG_FPGA
	/*
	 * Migrate SSI interrupts
	 */
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	HVCALL(ssi_redistribute_interrupts)
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g1, %g3)
#endif

	/*
	 * Disable heartbeat interrupts if they're on this cpu.
	 * cpu_in_error_finish will invoke heartbeat_enable on the
	 * remote cpu if the heartbeat was disabled.
	 */
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	HVCALL(heartbeat_disable)
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g1, %g3)

#ifdef CONFIG_PIU
	/*
	 * if this guest owns a PCIE bus, redirect
	 * PIU interrupts
	 */
	 GUEST_STRUCT(%g3)
	 ROOT_STRUCT(%g4)
	 ldx     [%g4 + CONFIG_PCIE_BUSSES], %g4
	! check leaf A
	 ldx     [%g4 + PCIE_DEVICE_GUESTP], %g5
	 cmp     %g3, %g5
	 bne      %xcc, 1f
	 nop

	/*
	 * Migrate PIU intrs
	 */
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	HVCALL(piu_intr_redistribution)
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g1, %g3)
1:

#if defined(CONFIG_FPGA) && defined(CONFIG_FPGA_UART)
	/*
	 * redirect serial uart interrupts
	 */
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	HVCALL(fpga_uart_intr_redistribute)
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g1, %g3)
#endif	/* CONFIG_FPGA`&& CONFIG_FPGA_UART */

#endif	/* CONFIG_PIU */

	/*
	 * Migrate vdev intrs
	 */
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	HVCALL(vdev_intr_redistribution)
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g1, %g3)

	! %g1 this strand id
	! %g2 tgt strand id

	/*
	 * Now pick another VCPU in this guest to target the erpt
	 * Ensure that the VCPU is not bound to the strand in error
	 */
	VCPU_STRUCT(%g1)
	GUEST_STRUCT(%g2)
	add	%g2, GUEST_VCPUS, %g2
	mov	0, %g3

	! %g1 - this vcpu struct
	! %g2 - array of vcpus in guest
	! %g3 - vcpu array idx
.find_cpu_loop:
	ldx	[%g2], %g4		! vcpu struct
	brz,pn	%g4, .find_cpu_continue
	  nop

	! ignore this vcpu
	cmp	%g4, %g1
	be,pn	%xcc, .find_cpu_continue
	  nop

	! check whether this CPU is running guest code ?
	ldx     [%g4 + CPU_STATUS], %g6
	cmp	%g6, CPU_STATE_RUNNING
	bne,pt	%xcc, .find_cpu_continue
	  nop

	! check the error queues.. if not set, not a good candidate
	ldx	[%g4 + CPU_ERRQR_BASE], %g6
	brz,pt	%g6, .find_cpu_continue
	  nop

	/*
	 * find the strand this vcpu is ON, make sure it is idle
	 * NOTE: currently this check is not necessary, more
	 * likely when we have sub-strand scheduling
	 */
	! %g1 - this vcpu struct
	! %g2 - curr vcpu in guest vcpu array
	! %g3 - vcpu array idx
	! %g4 - target vcpus struct
	STRAND_STRUCT(%g5)			! this strand
	ldx	[%g4 + CPU_STRAND], %g6		! vcpu->strand
	cmp	%g5, %g6
	be,pn	%xcc, .find_cpu_continue
	  nop

	! check if the target strand is IDLE
	ldub	[%g6 + STRAND_ID], %g6		! vcpu->strand->id
	mov	1, %g5
	sllx	%g5, %g6, %g6
	VCPU2ROOT_STRUCT(%g1, %g5)
	ldx	[%g5 + CONFIG_STIDLE], %g5
	btst	%g5, %g6
	bnz,pt	%xcc, .found_a_cpu
	  nop

.find_cpu_continue:
	add	%g2, GUEST_VCPUS_INCR, %g2
	inc	%g3
	cmp	%g3, NVCPUS
	bne,pn	%xcc, .find_cpu_loop
	  nop
	
	! If we got here, we didn't find a good tgt cpu
	! do not send an erpt, exit the guest
	
	! HVCALL(guest_exit)
	
	ba,a	.skip_sending_erpt

.found_a_cpu:
	! %g4 - target vcpu struct

	STRAND_STRUCT(%g1)				! this strand

	ldx	[%g4 + CPU_STRAND], %g3

	/*
	 * It is possible that the target STRANDs rerouted data is already in use.
	 * We use the rerouted_addr field as a spinlock. The target strand
	 * will set this to 0 after reading the error data allowing us
	 * to re-use the rerouting fields.
	 * See cpu_err_rerouted() below.
	 *
	 * %g3	&strands[target]
	 */
	set	ERR_INVALID_RA, %g6
	set	STRAND_REROUTED_ADDR, %g5
	add	%g3, %g5, %g5
1:	casx	[%g5], %g0, %g6
	brnz,pn	%g6, 1b
	nop

	! %g3	target strand struct
	ldub	[%g1 + CPU_VID], %g6
	set	STRAND_REROUTED_CPU, %g4
	stx	%g6, [%g3 + %g4]
	GEN_SEQ_NUMBER(%g6, %g5)
	set	STRAND_REROUTED_EHDL, %g4
	stx	%g6, [%g3 + %g4]
	set	SUN4V_CPU_RPRT, %g6
	set	STRAND_REROUTED_ATTR, %g4
	stx	%g6, [%g3 + %g4]
	GET_ERR_STICK(%g6)
	set	STRAND_REROUTED_STICK, %g4
	stx	%g6, [%g3 + %g4]

	/*
	 * Send a xcall to the target cpu so it can finish the work
	 */
	ldub	[%g2 + STRAND_ID], %g2			! tgt strand id
	sllx	%g2, INT_VEC_DIS_VCID_SHIFT, %g5
	or	%g5, VECINTR_CPUINERR, %g5
	stxa	%g5, [%g0]ASI_INTR_UDB_W

.skip_sending_erpt:

	RESUME_ALL_STRANDS(%g3, %g4, %g5, %g6)

	/*
	 * Clear the error report in_use field
	 */
	GET_ERR_DIAG_BUF(%g4, %g5)
	brnz,a,pt	%g4, 1f	
	  stub	%g0, [%g4 + ERR_DIAG_RPRT_IN_USE]
1:
	/*
	 * Clear the sun4v report in_use field
	 */
	GET_ERR_SUN4V_RPRT_BUF(%g4, %g5)
	brnz,a,pt	%g4, 1f
	  stub	%g0, [%g4 + ERR_SUN4V_RPRT_IN_USE]
1:

	! park myself
	STRAND_STRUCT(%g6)
	ldub	[%g6 + STRAND_ID], %g6
	mov	1, %g5
	sllx	%g5, %g6, %g6
	ROOT_STRUCT(%g2)			! %g2 config    
	add	%g2, CONFIG_STACTIVE, %g3
	ldx	[%g3], %g4
	andn	%g4, %g6, %g4			! %g6	my strand
	stx	%g4, [%g3]                      ! pull myself off from active CPUs 
	add	%g2, CONFIG_STIDLE, %g2
	ldx	[%g2], %g3
	andn 	%g6, %g3, %g3  			! %g6	my strand
	st	%g3, [%g2]                      ! remove myself from idle CPUs       

	! idle this strand
	mov	CMP_CORE_RUNNING_W1C, %g2
	stxa	%g6, [%g2]ASI_CMP_CHIP

	/*
	 * If we get here someone else resumed this strand by mistake
	 * hvabort to catch the mistake
	 */
	ba	hvabort
	  rd	%pc, %g1

	SET_SIZE(strand_in_error)

	ENTRY(dump_hvabort)

	STRAND_PUSH(%g7, %g2, %g3)

	GET_ERR_DIAG_BUF(%g1, %g2)
	add	%g1, ERR_DIAG_ABORT_DATA, %g1

	STRAND_STRUCT(%g2)
	ldx	[%g2 + STRAND_ABORT_PC], %g3
	stx	%g3, [%g1 + ERR_ABORT_PC]

	add	%g1, ERR_ABORT_VERSION, %g2
	mov	ABORT_VERSION_INFO_SIZE, %g3
	HVCALL(dump_version)

	GET_ERR_CWP(%g3)
	stx	%g3, [%g1 + ERR_ABORT_CWP]

	! %g3	%cwp

	! store this strands register windows
	add	%g1, ERR_ABORT_REG_WINDOWS, %g2
	mov	NWINDOWS - 1, %g4
1:
	mulx	%g4, 24 * 8, %g5
	add	%g5, %g2, %g5
	wrpr	%g4, %cwp

	stx	%o0, [%g5 + (0 * 8)]
	stx	%o1, [%g5 + (1 * 8)]
	stx	%o2, [%g5 + (2 * 8)]
	stx	%o3, [%g5 + (3 * 8)]
	stx	%o4, [%g5 + (4 * 8)]
	stx	%o5, [%g5 + (5 * 8)]
	stx	%o6, [%g5 + (6 * 8)]
	stx	%o7, [%g5 + (7 * 8)]
	stx	%i0, [%g5 + (8 * 8)]
	stx	%i1, [%g5 + (9 * 8)]
	stx	%i2, [%g5 + (10 * 8)]
	stx	%i3, [%g5 + (11 * 8)]
	stx	%i4, [%g5 + (12 * 8)]
	stx	%i5, [%g5 + (13 * 8)]
	stx	%i6, [%g5 + (14 * 8)]
	stx	%i7, [%g5 + (15 * 8)]
	stx	%l0, [%g5 + (16 * 8)]
	stx	%l1, [%g5 + (17 * 8)]
	stx	%l2, [%g5 + (18 * 8)]
	stx	%l3, [%g5 + (19 * 8)]
	stx	%l4, [%g5 + (20 * 8)]
	stx	%l5, [%g5 + (21 * 8)]
	stx	%l6, [%g5 + (22 * 8)]
	stx	%l7, [%g5 + (23 * 8)]

	brgz,pt	%g4, 1b
	dec	%g4

	wrpr	%g3, %cwp	! restore %cwp

	! store the trap stack
	rdpr	%tl, %g4
	brz,pn	%g4, .no_trap_stack
	mov	%g4, %g3
	add	%g1, ERR_ABORT_TRAP_REGS, %g2
1:
	mulx	%g4, ERR_TRAP_REGS_SIZE, %g5
	add	%g5, %g2, %g5
	wrpr	%g4, %tl

	rdpr	%tt, %g6
	stx	%g6, [%g5 + ERR_TT]
	rdpr	%tpc, %g6
	stx	%g6, [%g5 + ERR_TPC]
	rdpr	%tnpc, %g6
	stx	%g6, [%g5 + ERR_TNPC]
	rdpr	%tstate, %g6
	stx	%g6, [%g5 + ERR_TSTATE]
	rdhpr	%htstate, %g6
	stx	%g6, [%g5 + ERR_HTSTATE]

	dec	%g4
	brgz,pt	%g4, 1b
	nop

	wrpr	%g3, %tl	! restore %tl

.no_trap_stack:

	! now I have all those local registers to play with ....
	mov	%g1, %l1
	GET_ERR_GL(%l7)

	! store this strands register windows
	add	%g1, ERR_ABORT_GLOBAL_REGS, %l2
	mov	MAXGL - 1, %l4
1:
	mulx	%l4, 8 * 8, %l5
	add	%l5, %l2, %l5
	wrpr	%l4, %gl

	stx	%g0, [%l5 + (0 * 8)]
	stx	%g1, [%l5 + (1 * 8)]
	stx	%g2, [%l5 + (2 * 8)]
	stx	%g3, [%l5 + (3 * 8)]
	stx	%g4, [%l5 + (4 * 8)]
	stx	%g5, [%l5 + (5 * 8)]
	stx	%g6, [%l5 + (6 * 8)]
	stx	%g7, [%l5 + (7 * 8)]

	brgz,pt	%l4, 1b
	dec	%l4

	wrpr	%l7, %gl	! restore %gl
	mov	%l1, %g1

	/*
	 * Do C/ASM specific bits
	 */
	GET_ERR_TABLE_ENTRY(%g3, %g2)
	lduw	[%g3 + ERR_FLAGS], %g3
	set	ERR_ABORT_ASM, %g2
	btst	%g3, %g2
	bz,pn	%xcc, .c_dump_hvabort
	nop

.asm_dump_hvabort:
	/*
	 * This is an assembler-initiated abort
	 * fill in .....
	 */
	ba	.dump_hvabort_exit
	nop

.c_dump_hvabort:
	/*
	 * This is a C-initiated abort
	 * fill in .....
	 */
	ba	.dump_hvabort_exit
	nop

.dump_hvabort_exit:
	STRAND_POP(%g7, %g2)
	HVRET
	SET_SIZE(dump_hvabort)

	/*
	 * %g1	calling %pc
	 */
	ENTRY_NP(hvabort)
	mov	%g1, %g6
	HV_PRINT_NOTRAP("ABORT: Failure 0x");
	HV_PRINTX_NOTRAP(%g6)

	! stash the calling %pc
	STRAND_STRUCT(%g2)
	set	STRAND_ABORT_PC, %g3
	stx	%g6, [%g2 + %g3]

	! ASM  abort errors use sw_abort_errors[0]
	setx	sw_abort_errors, %g2, %g3
	RELOC_OFFSET(%g2, %g4)
	ba	error_handler	! tail call
	sub	%g3, %g4, %g1

	SET_SIZE(hvabort)

	ENTRY(c_hvabort)

	! stash the calling %pc
	STRAND_STRUCT(%g2)
	set	STRAND_ABORT_PC, %g3
	stx	%o7, [%g2 + %g3]

	setx	sw_abort_errors, %g2, %g3
	RELOC_OFFSET(%g2, %g4)
	sub	%g3, %g4, %g3

	! C abort errors use sw_abort_errors[1]
	set	ERROR_TABLE_ENTRY_SIZE, %g2
	ba	error_handler
	add	%g3, %g2, %g1
	SET_SIZE(c_hvabort)
