/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_soc.s
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

#pragma ident	"@(#)errors_soc.s	1.6	07/08/17 SMI"

#include <sys/asm_linkage.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>
#include <intr.h>

#include <offsets.h>
#include <util.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_soc.h>
#include <error_asm.h>
#include <niu.h>
#include <piu.h>

	/*
	 * SOC FBR Correctable Errrors require the DRAM ESRs to be included
	 * in the SER.
	 */
	ENTRY(dump_soc_fbr)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	! DIAG_BUF in %g1

	/*
	 * Store L2 ESR for the bank in error into the DIAG_BUF
	 */
	set	(NO_L2_BANKS - 1), %g3
.dump_soc_l2_banks:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_L2_BANK(%g3, %g4, %g5, .dump_soc_no_l2_error)

	setx	L2_ERROR_STATUS_REG, %g4, %g5
	sllx	%g3, L2_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4

	brz,pt	%g4, .dump_soc_no_l2_error
	nop

	stx	%g3, [%g1 + ERR_DIAG_L2_BANK]

	add	%g1, ERR_DIAG_BUF_L2_CACHE_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_L2_CACHE_ESR_INCR, %g5
	add	%g2, %g5, %g2
	! %g2	diag_buf->l2_cache.esr
	stx	%g4, [%g2]
.dump_soc_no_l2_error:
	brgz,pt	%g3, .dump_soc_l2_banks
	dec	%g3

	/*
	 * Store DRAM ESR/EAR/ND for the bank in error into the DIAG_BUF
	 */
	set	(NO_DRAM_BANKS - 1), %g3
.dump_soc_dram_banks:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, .dump_soc_no_dram_error)

	! DRAM Error Status register
	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	add	%g1, ERR_DIAG_BUF_DRAM_ESR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_ESR_INCR, %g5
	add	%g2, %g5, %g2
	stx	%g4, [%g2]	! store DRAM ESR

	! DRAM Error Address register
	add	%g1, ERR_DIAG_BUF_DRAM_EAR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_EAR_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_EAR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g2]

	! DRAM Error Location register
	add	%g1, ERR_DIAG_BUF_DRAM_LOC, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_LOC_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_ELR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g2]

	! DRAM Error Counter register
	add	%g1, ERR_DIAG_BUF_DRAM_CTR, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_CTR_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_ECR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g2]

	! DRAM FBD Syndrome register
	add	%g1, ERR_DIAG_BUF_DRAM_FBD, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_FBD_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_FBD_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g2]

	! DRAM Error Retry register
	add	%g1, ERR_DIAG_BUF_DRAM_RETRY, %g2
	mulx	%g3, ERR_DIAG_BUF_DRAM_RETRY_INCR, %g5
	add	%g2, %g5, %g2
	setx	DRAM_RETRY_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	ldx	[%g4], %g5
	stx	%g5, [%g2]

.dump_soc_no_dram_error:
	! next bank
	brgz,pt	%g3, .dump_soc_dram_banks
	dec	%g3

	ba	dump_soc	! tail call
	nop

	SET_SIZE(dump_soc_fbr)

	/*
	 * Dump SOC diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_soc)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * get diag_buf->err_soc
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_SOC, %g1

	! SOC Error Status Register
	setx	SOC_ERROR_STATUS_REG, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_ESR]

	! SOC Pending Error Status Register
	setx	SOC_PENDING_ERROR_STATUS_REG, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_PESR]

	! SOC SII Syndrome Status Register
	setx	SOC_SII_ERROR_SYNDROME_REG, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_SII_SYND]

	! SOC NCU Syndrome Status Register
	setx	SOC_NCU_ERROR_SYNDROME_REG, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_NCU_SYND]

	! SOC Error Log Enable Register
	setx	SOC_ERROR_LOG_ENABLE, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_ELER]

	! SOC Error Interrupt Enable Register
	setx	SOC_ERROR_TRAP_ENABLE, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_EIER]

#ifndef DEBUG_LEGION
	! SOC Error Steering Register
	setx	SOC_ERRORSTEER_REG, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_VCID]
#else
	stx	%g0, [%g1 + ERR_SOC_VCID]
#endif

	! SOC Fatal Error Enable Register
	setx	SOC_FATAL_ERROR_ENABLE, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_FEER]

	! SOC Error Injection Register
	setx	SOC_ERROR_INJECTION_REG, %g5, %g6
	ldx	[%g6], %g6
	stx	%g6, [%g1 + ERR_SOC_EIR]

	HVRET

	SET_SIZE(dump_soc)

	/*
	 * Clear ESRs after SOC error
	 * args
	 * %g7	return address
	 */
	ENTRY(clear_soc)

	ALTENTRY(clear_soc_after_storm)

	! SOC Error Status Register
	setx	SOC_ERROR_STATUS_REG, %g5, %g6
	ldx	[%g6], %g4			! save for later
	stx	%g0, [%g6]

	! SOC Pending Error Status Register
	setx	SOC_PENDING_ERROR_STATUS_REG, %g5, %g6
	stx	%g0, [%g6]

	! SOC SII Syndrome Status Register
	setx	SOC_SII_ERROR_SYNDROME_REG, %g5, %g6
	stx	%g0, [%g6]

	! SOC NCU Syndrome Status Register
	setx	SOC_NCU_ERROR_SYNDROME_REG, %g5, %g6
	stx	%g0, [%g6]

	! if we got an MCU/FBD error, clear the MCU/FBD registers now

	setx	SOC_MCU0FBR|SOC_MCU0ECC, %g5, %g6
	btst	%g4, %g6
	bnz	1f
	mov	0, %g3
	setx	SOC_MCU1FBR|SOC_MCU1ECC, %g5, %g6
	btst	%g4, %g6
	bnz	1f
	mov	1, %g3
	setx	SOC_MCU2FBR|SOC_MCU2ECC, %g5, %g6
	btst	%g4, %g6
	bnz	1f
	mov	2, %g3
	setx	SOC_MCU3FBR|SOC_MCU3ECC, %g5, %g6
	btst	%g4, %g6
	bnz	1f
	mov	3, %g3
	ba	2f		! no MCU/FBD error
	nop
1:
	! %g3	which MCU

	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 2f)

	setx	DRAM_ESR_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g2
	or	%g5, %g2, %g2
	ldx	[%g2], %g4
	stx	%g4, [%g2]	! clear DRAM ESR 	RW1C
	stx	%g0, [%g2]	! clear DRAM ESR 	RW

	setx	DRAM_FBD_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	or	%g5, %g4, %g4
	stx	%g0, [%g4]	! clear DRAM FBD SYND	RW
2:

	HVRET

	SET_SIZE(clear_soc)
	SET_SIZE(clear_soc_after_storm)

	ENTRY(soc_storm)

	! first verify that storm prevention is enabled
	CHECK_BLACKOUT_INTERVAL(%g4)

	/*
	 * save our return address
	 */
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)

	setx	SOC_ERROR_TRAP_ENABLE, %g4, %g3
	ldx	[%g3], %g4
	setx	SOC_CORRECTABLE_ERRORS, %g5, %g6
	btst	%g6, %g4
	bz,pn	%xcc, 9f		! SOC CEs already disabled
	andn	%g4, %g6, %g4
	stx	%g4, [%g3]
	setx	SOC_ERROR_LOG_ENABLE, %g4, %g3
	ldx	[%g3], %g4
	andn	%g4, %g6, %g4
	stx	%g4, [%g3]

	/*
	 * Set up a cyclic on this strand to re-enable the SOC CE bits
	 * after an interval of 6 seconds. Set a flag in the
	 * strand struct to indicate that the cyclic has been set
	 * for this bank.
	 */
	mov	STRAND_ERR_FLAG_SOC, %g4
	STRAND_STRUCT(%g6)
	lduw	[%g6 + STRAND_ERR_FLAG], %g2	! installed flags
	btst	%g4, %g2			! handler installed?
	bnz,pn	%xcc, 9f			!   yes

	STRAND2CONFIG_STRUCT(%g6, %g4)
	ldx	[%g4 + CONFIG_CE_BLACKOUT], %g1
	brz,a,pn %g1, 9f			! zero: blackout disabled
	  nop
	SET_STRAND_ERR_FLAG(%g6, STRAND_ERR_FLAG_SOC, %g5)
	setx	soc_set_error_bits, %g5, %g2
	RELOC_OFFSET(%g4, %g5)
	sub	%g2, %g5, %g2			! g2 = handler address
	setx	SOC_CORRECTABLE_ERRORS, %g4, %g3	! g3 = arg 0 : bit(s) to set
	mov	STRAND_ERR_FLAG_SOC, %g4		! g4 = arg 1 : cpu flags to clear
				        	! g1 = delta tick
	VCPU_STRUCT(%g6)
						! g6 - CPU struct
	HVCALL(cyclic_add_rel)	/* ( del_tick, address, arg0, arg1 ) */
9:
	GET_ERR_RETURN_ADDR(%g7, %g2)
	HVRET
	SET_SIZE(soc_storm)

	/*
	 * cyclic function used to re-enable SOC_TRAP_ENABLE bits
	 *
	 * %g1		SOC_TRAP_ENABLE bits to set
	 * %g2		CPU->err_flags to clear
	 * %g7		return address
	 * %g5 - %g6	clobbered
	 */
	ENTRY(soc_set_error_bits)
	STRAND_STRUCT(%g6)
	CLEAR_STRAND_ERR_FLAG(%g6, %g2, %g5)

	setx	SOC_ERROR_TRAP_ENABLE, %g4, %g5
	ldx	[%g5], %g4
	or	%g4, %g1, %g4
	stx	%g4, [%g5]
	setx	SOC_ERROR_LOG_ENABLE, %g4, %g5
	ldx	[%g5], %g4
	or	%g4, %g1, %g4
	stx	%g4, [%g5]

	/*
	 * We need to clear the SOC ESRs in case they were
	 * set while the error traps were disabled
	 */
	ba,a	clear_soc_after_storm		! tail call
	! NOTREACHED
	SET_SIZE(soc_set_error_bits)

	ENTRY(soc_sun4v_report)
	GET_ERR_SUN4V_RPRT_BUF(%g2, %g3)
	brz,pn	%g2, soc_sun4v_report_exit
	.empty

	! workaround for SOC ESRs always reading as 0
	ba	1f
	nop

	setx	SOC_NCU_ERROR_SYNDROME_REG, %g3, %g4
	ldx	[%g4], %g4
	! has a valid syndrome been logged ?
	setx	SOC_NCU_ESR_V, %g3, %g5
	btst	%g5, %g4
	bz,pn	%xcc, soc_sun4v_report_exit
	.empty
	! has a valid strandid been logged ?
	setx	SOC_NCU_ESR_S, %g3, %g5
	btst	%g5, %g4
	bz,pn	%xcc, soc_sun4v_report_exit
	.empty
	! has a valid PA been logged ?
	setx	SOC_NCU_ESR_P, %g3, %g5
	btst	%g5, %g4
	bz,pn	%xcc, soc_sun4v_report_exit
	.empty

1:
	srlx	%g4, SOC_NCU_ESR_STRANDID_SHIFT, %g5
	and	%g5, SOC_NCU_ESR_STRANDID_MASK, %g5
	stuh	%g5, [%g2 + ERR_SUN4V_RPRT_G_CPUID]
	setx	SOC_NCU_ESR_PA_MASK, %g3, %g5
	and	%g4, %g5, %g5
	VCPU_STRUCT(%g6)
	CPU_ERR_IO_PA_TO_RA(%g6, %g5, %g5)
	GUEST_STRUCT(%g6)
	mov	1, %g3
	! %g6	guestp
	! %g5	raddr		(need PA -> RA)
	! %g3	size
	RANGE_CHECK_IO(%g6, %g5, %g3, soc_pa_good, soc_pa_bad, %g4, %g1)
soc_pa_bad:
	mov	CPU_ERR_INVALID_RA, %g5
soc_pa_good:
	stx	%g5, [%g2 + ERR_SUN4V_RPRT_ADDR]
	/*
	 * SZ is 8 bytes for a single ASI VA
	 */
	mov	8, %g5
	st	%g5, [%g2 + ERR_SUN4V_RPRT_SZ]

soc_sun4v_report_exit:
	HVRET
	SET_SIZE(soc_sun4v_report)


	ENTRY(print_soc)
#ifdef DEBUG_LEGION
	STORE_ERR_RETURN_ADDR(%g7, %g4, %g5)
	GET_ERR_DIAG_DATA_BUF(%g1, %g2)

	/*
	 * print the D-SFSR/D-SFAR
	 */
	mov	%g1, %g6
	PRINT_NOTRAP("SOCU error: D-SFSR : ");
	ldx	[%g6 + ERR_DIAG_BUF_SPARC_DSFSR], %g3
	PRINTX_NOTRAP(%g3)
	PRINT_NOTRAP("\r\nSOCU error: D-SFAR : ");
	ldx	[%g6 + ERR_DIAG_BUF_SPARC_DSFAR], %g3
	PRINTX_NOTRAP(%g3)
	PRINT_NOTRAP("\r\nSOCU error: DESR: ");
	GET_ERR_DESR(%g3, %g4)
	PRINTX_NOTRAP(%g3)

	/*
	 * get diag_buf->err_soc
	 */
	add	%g6, ERR_DIAG_BUF_DIAG_DATA, %g6
	add	%g6, ERR_DIAG_DATA_SOC, %g6
	! SOC Error Status Register
	PRINT_NOTRAP("\r\nSOCU error: SOC ESR: ");
	ldx	[%g6 + ERR_SOC_ESR], %g3
	PRINTX_NOTRAP(%g3)

	! SOC Pending Error Status Register
	PRINT_NOTRAP("\r\nSOCU error: SOC PENDING ESR: ");
	ldx	[%g6 + ERR_SOC_PESR], %g3
	PRINTX_NOTRAP(%g3)

	! SOC SII Syndrome Status Register
	PRINT_NOTRAP("\r\nSOCU error: SOC SII ESR: ");
	ldx	[%g6 + ERR_SOC_SII_SYND], %g3
	PRINTX_NOTRAP(%g3)

	! SOC NCU Syndrome Status Register
	PRINT_NOTRAP("\r\nSOCU error: SOC NCU SYND : ");
	ldx	[%g6 + ERR_SOC_NCU_SYND], %g3
	PRINTX_NOTRAP(%g3)
	PRINT_NOTRAP("\r\n");

	GET_ERR_RETURN_ADDR(%g7, %g2)
#endif
	HVRET
	SET_SIZE(print_soc)

	/*
	 * Set the DRAM FBR Error Count registers
	 */
	ENTRY(reset_fbr_counters)
	set	(NO_DRAM_BANKS - 1), %g3
1:
	! skip banks which are disabled.  causes hang.
	SKIP_DISABLED_DRAM_BANK(%g3, %g4, %g5, 2f)

	setx	DRAM_FBR_COUNT_BASE, %g4, %g5
	sllx	%g3, DRAM_BANK_SHIFT, %g4
	add	%g5, %g4, %g5
	ldx	[%g5], %g4
	brnz,pt	%g4, 2f
	mov	DRAM_ERROR_COUNTER_FBR_RATIO, %g4
	stx	%g4, [%g5]
2:
	! next bank
	brgz,pt	%g3, 1b
	dec	%g3

	HVRET
	SET_SIZE(reset_fbr_counters)

	/*
	 * Clean up after FBR errors
	 * DSU errata (N2 erratum 190) means we must check whether
	 * the FBR has caused a bogus DSU error to be logged.
	 */
	ENTRY(reset_soc_fbr)
	STRAND_PUSH(%g7, %g3, %g4)

	GET_ERR_TABLE_ENTRY(%g3, %g4)
	ld	[%g3 + ERR_FLAGS], %g4
	set	ERR_CLEAR_SOC, %g3
	btst	%g4, %g3
	bz,pn	%xcc, 1f
	nop

	HVCALL(clear_soc)
1:
	HVCALL(reset_fbr_counters)
	HVCALL(verify_dsu_error)
	HVCALL(clear_dram_l2c_esr_regs)
	STRAND_POP(%g7, %g3)
	HVRET
	SET_SIZE(reset_soc_fbr)
