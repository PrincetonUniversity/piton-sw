/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: error_tables.c
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

#pragma ident	"@(#)error_tables.c	1.13	07/09/11 SMI"

#include <error_defs.h>
#include <offsets.h>

/*
 * statically allocate buffers FERG/SUN4V reporting
 */
err_sun4v_rprt_t	err_sun4v_rprt[MAX_ERROR_REPORT_BUFS];
err_diag_rprt_t		err_diag_rprt[MAX_ERROR_REPORT_BUFS];

/*
 * common functions
 */
extern void clear_soc(void);
extern void clear_ssi(void);

/*
 * Diagnosis Engine report functions
 * These are used to populate the ereport sent to the SP for the
 * FERG.
 */
extern void dump_store_buffer(void);
extern void itlb_dump(void);
extern void dtlb_dump(void);
extern void dump_scratchpad(void);
extern void dump_trapstack(void);
extern void dump_dbu_data(void);
extern void dump_mra(void);
extern void dump_mamu(void);
extern void dump_soc(void);
extern void dump_soc_fbr(void);
extern void dump_tick_compare(void);
extern void dump_icache(void);
extern void dump_dcache(void);
extern void dump_l2_cache(void);
extern void dump_reg_ecc(void);
extern void dump_ssi(void);
extern void dump_no_error(void);
extern void dump_hvabort(void);

/*
 * correction functions
 */
extern void itlb_demap_all(void);
extern void itlb_demap_page(void);
extern void dtlb_demap_all(void);
extern void correct_trapstack(void);
extern void correct_tick_compare(void);
extern void correct_tick_tccp(void);
extern void correct_tick_tccd(void);
extern void correct_l2_ildau(void);
extern void correct_l2_dldau(void);
extern void correct_l2_dldac(void);
extern void correct_stb(void);
extern void correct_frfc(void);
extern void correct_frfu(void);
extern void correct_irfc(void);
extern void correct_irfu(void);
extern void correct_imra(void);
extern void correct_dmra(void);
extern void correct_scac(void);
extern void correct_scau(void);
extern void clear_tick_compare(void);
extern void reset_soc_fbr(void);

/*
 * sun4v guest report functions
 * populate the sun4v guest ereport packet with error-specific data
 */
extern void stb_sun4v_report(void);
extern void sca_sun4v_report(void);
extern void tick_sun4v_report(void);
extern void tsa_sun4v_report(void);
extern void l2_sun4v_report(void);
extern void irf_sun4v_report(void);
extern void frf_sun4v_report(void);
extern void soc_sun4v_report(void);

/*
 * storm functions
 */
extern void l2_ce_storm(void);
extern void tick_cmp_storm(void);
extern void soc_storm(void);
extern void icache_storm(void);
extern void dcache_storm(void);
extern void dram_storm(void);

/*
 * error-specific print functions
 */
extern void itlb_print(void);
extern void dtlb_print(void);
extern void mra_print(void);
extern void l2_cache_print(void);
extern void print_soc(void);

/*
 * Errata: Filter out Addr parity err synd reported by N2 MCU on scrub (DSU)
 */
extern void verify_dsu_error(void);

/*
 * S/W error table for use with hvabort
 */
error_table_entry_t sw_abort_errors[] = {
	{ "HVABORT (asm)", dump_hvabort, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_ABORT_ASM,
		SUN4V_NO_REPORT,
		(SER_TYPE_ABORT << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_ABORT_DATA + ERR_ABORT_DATA_SIZE},
	{ "HVABORT (C)", dump_hvabort, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_ABORT_C|ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_ABORT << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_ABORT_DATA + ERR_ABORT_DATA_SIZE},
};

/*
 * Note: The addresses stored in the tables must be relocated
 *	 at runtime before use.
 */

error_table_entry_t instruction_access_MMU_errors[] = {
	{ "IAMU UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "ITTM", itlb_dump, null_fcn, itlb_demap_all, null_fcn,
		itlb_print,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_ITLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TLB_SIZE},
	{ "ITTP", itlb_dump, null_fcn, itlb_demap_all, null_fcn,
		itlb_print,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_ITLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TLB_SIZE},
	{ "ITDP", itlb_dump, null_fcn, itlb_demap_all, null_fcn,
		itlb_print,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_ITLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TLB_SIZE},
	{ "ITMU", dump_mra, null_fcn, correct_imra, null_fcn,
		mra_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_ITLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_MMU_ERR_REGS_SIZE},
	{ "ITL2U", dump_l2_cache, l2_sun4v_report, correct_l2_ildau, null_fcn,
		l2_cache_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_NON_RESUMABLE|ERR_STRANDS_PARKED|
		    ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "ITL2ND", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		l2_cache_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_NON_RESUMABLE|
		    ERR_STRANDS_PARKED|ERR_LAST_IN_TABLE|ERR_NO_DRAM_DUMP,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE}
};


error_table_entry_t data_access_MMU_errors[] = {
	{ "DAMU UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "DTTM", dtlb_dump, null_fcn, dtlb_demap_all, null_fcn,
		dtlb_print,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_DTLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TLB_SIZE},
	{ "DTTP", dtlb_dump, null_fcn, dtlb_demap_all, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_DTLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TLB_SIZE},
	{ "DTDP", dtlb_dump, null_fcn, dtlb_demap_all, null_fcn,
		dtlb_print,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_DTLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TLB_SIZE},
	{ "DTMU", dump_mra, null_fcn, correct_dmra, null_fcn,
		mra_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_DTLB << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_MMU_ERR_REGS_SIZE},
	{ "DTL2U", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		l2_cache_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_NON_RESUMABLE|
		    ERR_STRANDS_PARKED|ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DTL2ND", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		l2_cache_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_NON_RESUMABLE|
		    ERR_STRANDS_PARKED|ERR_LAST_IN_TABLE|ERR_NO_DRAM_DUMP,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE}
};

error_table_entry_t internal_processor_errors[] = {
	{ "IPE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "IRFU", dump_reg_ecc, irf_sun4v_report, correct_irfu, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|ERR_NON_RESUMABLE,
		SUN4V_IRF_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_REG_SIZE},
	{ "IRFC", dump_reg_ecc, null_fcn, correct_irfc, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_REG_SIZE},
	{ "FRFU", dump_reg_ecc, frf_sun4v_report, correct_frfu, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|ERR_NON_RESUMABLE,
		SUN4V_FRF_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_REG_SIZE},
	{ "FRFC", dump_reg_ecc, null_fcn, correct_frfc, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_REG_SIZE},
	{ "SBDLC", dump_store_buffer, null_fcn, correct_stb, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE},
	{ "SBDLU", dump_store_buffer, stb_sun4v_report, correct_stb, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|
			ERR_STRANDS_PARKED|ERR_NON_RESUMABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE},
	{ "MRAU", dump_mra, null_fcn, correct_dmra, null_fcn,
		mra_print,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_MMU_ERR_REGS_SIZE},
	{ "TSAC", dump_trapstack, null_fcn, correct_trapstack, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TSA_SIZE},
	{ "TSAU", dump_trapstack, tsa_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|ERR_NON_RESUMABLE,
		SUN4V_PREG_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_TSA_SIZE},
	{ "SCAC", dump_scratchpad, null_fcn, correct_scac, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SCRATCHPAD_SIZE},
	{ "SCAU", dump_scratchpad, sca_sun4v_report, correct_scau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|ERR_NON_RESUMABLE,
		SUN4V_ASI_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_SCRATCHPAD_SIZE},
	{ "TCCP", dump_tick_compare, null_fcn, correct_tick_tccp, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TCA_SIZE},
	{ "TCUP", dump_tick_compare, tick_sun4v_report,
		    clear_tick_compare, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_NON_RESUMABLE|ERR_LAST_IN_TABLE,
		SUN4V_ASR_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_TCA_SIZE}
};

error_table_entry_t hw_corrected_errors[] = {
	{ "HCE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "ICVP", dump_icache, null_fcn, null_fcn, icache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_ICACHE_SIZE},
	{ "ICTP", dump_icache, null_fcn, null_fcn, icache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_ICACHE_SIZE},
	{ "ICTM", dump_icache, null_fcn, null_fcn, icache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_ICACHE_SIZE},
	{ "ICDP", dump_icache, null_fcn, null_fcn, icache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_ICACHE_SIZE},
	{ "DCVP", dump_dcache, null_fcn, null_fcn, dcache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_ICACHE_SIZE},
	{ "DCTP", dump_dcache, null_fcn, null_fcn, dcache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + 0},
	{ "DCTM", dump_dcache, null_fcn, null_fcn, dcache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_DCACHE_SIZE},
	{ "DCDP", dump_dcache, null_fcn, null_fcn, dcache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L1C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_DCACHE_SIZE},
	{ "L2C (HCE)", null_fcn, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_USE_L2_CACHE_TABLE|ERR_USE_DRAM_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		0},
	{ "SBDPC", dump_store_buffer, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE},
	{ "SOCC", dump_soc, null_fcn, reset_soc_fbr, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_USE_SOC_TABLE|ERR_LAST_IN_TABLE|ERR_CLEAR_SOC,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE}
};

error_table_entry_t store_errors[] = {
	{ "SE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE},
	{ "SBDIOU", dump_store_buffer, stb_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_NON_RESUMABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_DEFERRED_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE},
	{ "SBAPP", dump_store_buffer, stb_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_NON_RESUMABLE|ERR_LAST_IN_TABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_DEFERRED_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE}
};

error_table_entry_t data_access_errors[] = {
	{ "DAE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
#ifdef DEBUG_LEGION
		ERR_IO_PROT|
#endif
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "DCL2U", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_CHECK_LINE_STATE|ERR_IO_PROT|ERR_NON_RESUMABLE|
		    ERR_CHECK_DAU_TYPE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DCL2ND", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_NON_RESUMABLE|ERR_NO_DRAM_DUMP,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE},
	{ "DAE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "NCU PIO", dump_soc, soc_sun4v_report, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_IO_PROT|ERR_UE|ERR_GL_STORED|
		    ERR_STRANDS_PARKED|ERR_NON_RESUMABLE|ERR_LAST_IN_TABLE,
		SUN4V_ASI_RPRT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
};

error_table_entry_t sw_recoverable_errors[] = {
	{ "SRE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "ITL2C", dump_l2_cache, null_fcn, correct_l2_dldac, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "ICL2C", dump_l2_cache, null_fcn, correct_l2_dldac, icache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DTL2C", dump_l2_cache, null_fcn, correct_l2_dldac, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DCL2C", dump_l2_cache, null_fcn, correct_l2_dldac, dcache_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "SRE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "SBDPU", dump_store_buffer, null_fcn, correct_stb, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_STB_SIZE},
	{ "MAMU", dump_mamu, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_MAMU_SIZE},
	{ "MAL2C", dump_l2_cache, null_fcn, correct_l2_dldac, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "MAL2U", dump_l2_cache, null_fcn, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_DAU_TYPE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "MAL2ND", dump_l2_cache, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_NO_DRAM_DUMP,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE},
	{ "CWQL2C", dump_l2_cache, null_fcn, correct_l2_dldac, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "CWQL2U", dump_l2_cache, null_fcn, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_DAU_TYPE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "CWQL2ND", dump_l2_cache, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_NO_DRAM_DUMP,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE},
	{ "TCCD", dump_tick_compare, null_fcn, correct_tick_tccd,
		tick_cmp_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_TCA_SIZE},
	{ "TCUD", dump_tick_compare, tick_sun4v_report,
		    clear_tick_compare, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE,
		SUN4V_ASR_RPRT,
		(SER_TYPE_CMP << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_TCA_SIZE},
	{ "L2U", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_USE_L2_CACHE_TABLE|ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "L2ND", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_NO_DRAM_DUMP,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE},
	{ "SRE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "SOCU SRE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_IO_PROT|ERR_UE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "L2C (SRE)", null_fcn, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_USE_L2_CACHE_TABLE|ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		0}
};

error_table_entry_t instruction_access_errors[] = {
	{ "IAE UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "ICL2U", dump_l2_cache, l2_sun4v_report, correct_l2_ildau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_CHECK_LINE_STATE|ERR_NON_RESUMABLE|
		    ERR_CHECK_DAU_TYPE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "ICL2ND", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_LAST_IN_TABLE|ERR_NON_RESUMABLE|ERR_NO_DRAM_DUMP,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE - ERR_DRAM_CONTENTS_SIZE}
};

/*
 * Boot ROM (SSI) errors
 *
 * We could just ignore these as per previous platforms but that
 * seems gratuitously lazy, even for us, so we will just report
 * them to the SP.
 */
error_table_entry_t ssi_errors[] = {
	{ "TOUT", dump_ssi, null_fcn, clear_ssi, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SSI << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SSI_SIZE},
	{ "PARITY", dump_ssi, null_fcn, clear_ssi, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SSI << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SSI_SIZE}
};

/*
 * We use the following sub-table to distinquish between the various
 * L2 errors. This table is based on the L2 ESR
 */
error_table_entry_t l2c_errors[] = {
	/*
	 * Note: L2 ESR entries start at bit[34]
	 */
	{ "LVC", dump_l2_cache, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	/* VEU bit */
	{ "L2C UNKNOWN (1)", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	/* VEC bit */
	{ "L2C UNKNOWN (2)", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "DSU", dump_l2_cache, l2_sun4v_report, verify_dsu_error, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_USE_DRAM_TABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DSC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_USE_DRAM_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DRU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DRC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DAU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_USE_DRAM_TABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DAC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_CHECK_LINE_STATE|ERR_USE_DRAM_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LVF", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE|ERR_NON_RESUMABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LRF", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_NON_RESUMABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LTC", dump_l2_cache, l2_sun4v_report, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDSU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDSC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDRU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDRC", dump_l2_cache, null_fcn, correct_l2_dldac, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDWU", dump_l2_cache, l2_sun4v_report, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDWC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDAU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "LDAC", dump_l2_cache, null_fcn, correct_l2_dldac, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE}
};

/*
 * We use the following sub-table to distinquish between the various
 * DRAM errors. This table is based on the DRAM ESR
 */
error_table_entry_t dram_errors[] = {
	/*
	 * Note: DRAM ESR entries start at bit[54]
	 */
	{ "FBR", dump_soc_fbr, null_fcn, reset_soc_fbr, dram_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_CLEAR_AMB_ERRORS,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "FBU", dump_l2_cache, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_NON_RESUMABLE|ERR_CLEAR_AMB_ERRORS|ERR_FORCE_SIR,
		SUN4V_MEM_RPRT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "MEB", dump_no_error, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "DBU", dump_dbu_data, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + (ERR_TRAP_REGS_SIZE * MAXTL)},
	{ "DSU", dump_l2_cache, l2_sun4v_report, verify_dsu_error, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DSC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DAU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
	{ "DAC", dump_l2_cache, null_fcn, null_fcn, l2_ce_storm,
		null_fcn,	/* DEBUG print function */
		ERR_CE|ERR_CHECK_LINE_STATE|ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE},
};

error_table_entry_t precise_dau_errors[] = {
	{ "DAU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_CHECK_LINE_STATE|ERR_IO_PROT|ERR_LAST_IN_TABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UE_RESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE}
};

error_table_entry_t precise_ldau_errors[] = {
	{ "LDAU", dump_l2_cache, l2_sun4v_report, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_GL_STORED|ERR_STRANDS_PARKED|ERR_NON_RESUMABLE|
		    ERR_CHECK_LINE_STATE|ERR_IO_PROT|ERR_LAST_IN_TABLE,
		SUN4V_MEM_RPRT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_PRECISE_NONRESUMABLE,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE}
};

/*
 * These are for CWQ/MAU errors which cause sw-recoverable_error trap.
 * These traps will always occur in HPRIV mode as the hypervisor
 * must access the CWQ/MAU hardware on behalf of the guest. However
 * we do not want to terminate when we encounter one of these errors
 * so these do not have the ERR_NON_RESUMABLE flag set.
 */
error_table_entry_t disrupting_dau_errors[] = {
	{ "DAU", dump_l2_cache, null_fcn, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE|
		    ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE}
};

error_table_entry_t disrupting_ldau_errors[] = {
	{ "LDAU", dump_l2_cache, null_fcn, correct_l2_dldau, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_UE|ERR_CHECK_LINE_STATE|
		    ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_L2C << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_L2_SIZE}
};

/*
 * We use the following sub-table to distinquish between the various
 * SOC errors. This table is based on the SOC ESR
 */
error_table_entry_t soc_errors[] = {
	{ "SIINIUCTAGUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIIDMUCTAGUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIINIUCTAGCE", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIIDMUCTAGCE", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIINIUAPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIIDMUDPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIINIUDPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIIDMUAPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "DMUINTERNAL", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "DMUNCUCREDIT", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "DMUCTAGCE", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "DMUCTAGUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "DMUSIICREDIT", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "DMUDATAPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUDATAPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUMONDOTABLE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUMONDOFIFO", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUINTTABLE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUPCXDATA", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUPCXUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUCPXUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUDMUUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUCTAGUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUCTAGCE", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SOC UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "SIOCTAGUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SIOCTAGCE", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NIUCTAGCE", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NIUCTAGUE", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NIUDATAPARITY", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SOC UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "MCU0FBR", dump_soc_fbr, null_fcn, reset_soc_fbr, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_CE|ERR_CLEAR_AMB_ERRORS|ERR_CLEAR_SOC,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "MCU0ECC", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SOC UNKNOWN", dump_no_error, null_fcn, null_fcn, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "MCU1FBR", dump_soc_fbr, null_fcn, reset_soc_fbr, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_CE|ERR_CLEAR_AMB_ERRORS|ERR_CLEAR_SOC,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "MCU1ECC", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SOC UNKNOWN", dump_no_error, null_fcn, null_fcn, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "MCU2FBR", dump_soc_fbr, null_fcn, reset_soc_fbr, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_CE|ERR_CLEAR_AMB_ERRORS|ERR_CLEAR_SOC,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "MCU2ECC", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "SOC UNKNOWN", dump_no_error, null_fcn, null_fcn, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL,
		SUN4V_NO_REPORT,
		(SER_TYPE_UNDEF << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET},
	{ "MCU3FBR", dump_soc_fbr, null_fcn, reset_soc_fbr, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_CE|ERR_CLEAR_AMB_ERRORS|ERR_CLEAR_SOC,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "MCU3ECC", dump_soc, null_fcn, clear_soc, soc_storm,
		print_soc,	/* DEBUG print function */
		ERR_CE,
		SUN4V_NO_REPORT, EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE},
	{ "NCUDMUCREDIT", dump_soc, null_fcn, clear_soc, null_fcn,
		print_soc,	/* DEBUG print function */
		ERR_FATAL|ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_SOC << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + ERR_SOC_SIZE}
};

error_table_entry_t dbu_errors[] = {
	{ "DBU", dump_dbu_data, null_fcn, null_fcn, null_fcn,
		null_fcn,	/* DEBUG print function */
		ERR_FATAL|ERR_GL_STORED|ERR_STRANDS_PARKED|
		    ERR_IO_PROT|ERR_NON_RESUMABLE|
			ERR_LAST_IN_TABLE,
		SUN4V_NO_REPORT,
		(SER_TYPE_DRAM << SER_TYPE_SHIFT) | EDESC_UNDEF,
		ERR_DIAG_DATA_OFFSET + (ERR_TRAP_REGS_SIZE * MAXTL)}
};

/*
 * ECC syndrome table for register file errors
 */
ecc_syndrome_table_entry irf_ecc_syndrome_table[] = {
	/* 0x0 - 0xf */
	ECC_ne, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x10 - 0x1f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x20 - 0x2f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x30 - 0x3f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x40 - 0x4f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x50 - 0x5f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x60 - 0x6f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x70 - 0x7f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x80 - 0x8f */
	ECC_C7, ECC_C0, ECC_C1, 0, ECC_C2, 1, 2, 3,
		ECC_C3, 4, 5, 6, 7, 8, 9, 10,
	/* 0x90 - 0x9f */
	ECC_C4, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
	/* 0xa0 - 0xaf */
	ECC_C5, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	/* 0xb0 - 0xbf */
	41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56,
	/* 0xc0 - 0xcf */
	ECC_C6, 57, 58, 59, 60, 61, 62, 63, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0xd0 - 0xdf */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0xe0 - 0xef */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0xf0 - 0xff */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M
};

/*
 * Syndrome table for L2 Data, FRF and Store Buffer errors
 */
ecc_syndrome_table_entry l2_ecc_syndrome_table[] = {
	/* 0x0 - 0xf */
	ECC_ne, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x10 - 0x1f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x20 - 0x2f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x30 - 0x3f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x40 - 0x4f */
	ECC_C6, ECC_C0, ECC_C1, 0, ECC_C2, 1, 2, 3, ECC_C3,
		4, 5, 6, 7, 8, 9, 10,
	/* 0x50 - 0x5f */
	ECC_C4, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
	/* 0x60 - 0x6f */
	ECC_C5, 26, 27, 28, 29, 30, 31, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0x70 - 0x7f */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_N_M
};
/*
 * Syndrome Table for TSA, TCA, and SCA Data ECC Code
 */
ecc_syndrome_table_entry core_array_ecc_syndrome_table[] = {
	/* 0x0 - 0xf */
	ECC_ne, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x10 - 0x1f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x20 - 0x2f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x30 - 0x3f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x40 - 0x4f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x50 - 0x5f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x60 - 0x6f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x70 - 0x7f */
	ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
		ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U, ECC_U,
	/* 0x80 - 0x8f */
	ECC_M, ECC_C0, ECC_C1, 0, ECC_C2, 1, 2, 3, ECC_C3, 4, 5, 6, 7, 8, 9, 10,
	/* 0x90 - 0x9f */
	ECC_C4, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
	/* 0xa0 - 0xaf */
	ECC_C5, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	/* 0xb0 - 0xbf */
	41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56,
	/* 0xc0 - 0xcf */
	ECC_C6, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67,
		ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0xd0 - 0xdf */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0xe0 - 0xef */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
	/* 0xf0 - 0xff */
	ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M,
		ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M, ECC_M
};

/*
 * Masks used in the calculation of check bits {6:0} for
 * floating point (FRF) errors.
 */
ecc_mask_table_entry frfc_ecc_mask_table[] = {
	/* C6 */
	0x2da65cb7,
	/* C5 */
	0xfc000000,
	/* C4 */
	0x03fff800,
	/* C3 */
	0x03fc07f0,
	/* C2 */
	0xe3c3c78e,
	/* C1 */
	0x9b33366d,
	/* C0 */
	0x56aaad5b
};

#ifdef CONFIG_CLEANSER
/* BEGIN CSTYLED */
/*
 * From L2 Tag ECC Table E-8, N2 PRM rev. 1.3
 */
ecc_syndrome_table_entry l2_tag_ecc_table[] = {
	/*  0      1      2      3      4      5      6      7*/
/*00*/	0x007, 0x00B, 0x00D, 0x00E, 0x013, 0x015, 0x016, 0x019,
/*08*/	0x01A, 0x01C, 0x01F, 0x023, 0x025, 0x026, 0x029, 0x02A,
/*10*/	0x02C, 0x02F, 0x031, 0x032, 0x034, 0x037,
	/* Now we have the check bits */
	/* C0     C1     C2     C3     C4     C5*/
	0x001, 0x002, 0x004, 0x008, 0x010, 0x020,
};
/* END CSTYLED */
#endif	/* CONFIG_CLEANSER */
