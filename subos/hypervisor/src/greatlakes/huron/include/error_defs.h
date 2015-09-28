/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: error_defs.h
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

#ifndef _NIAGARA2_ERROR_DEFS_H
#define	_NIAGARA2_ERROR_DEFS_H

#pragma ident	"@(#)error_defs.h	1.5	07/08/17 SMI"

#include <sys/htypes.h>
#include <sun4v/errs_defs.h>
#include <hprivregs.h>
#include <config.h>
#include <traps.h>
#include <cache.h>
#include <dram.h>
#include <mmu.h>
#include <errs_common.h>
#include <vpiu_errs_defs.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Error flags for error table entry
 */
#define	ERR_CE			(1 << 0)	/* correctable error */
#define	ERR_UE			(1 << 1)	/* uncorrectable error */
/*
 * When ERR_FATAL is set, the hypervisor will never return to the
 * guest. Instead it will abort after performing its usual error
 * handling.
 */
#define	ERR_FATAL		(1 << 2)
#define	ERR_STRANDS_PARKED	(1 << 3)	/* strands parked */
/*
 * Set when a non-resumable error report (epkt) is to be sent
 * to the guest for this error type. Note that when this flag
 * is set, the field err_sun4v_rprt_type in the error_table entry
 * must be set to a vlaid value and cannot be set to SUN4v_NO_REPORT.
 */
#define	ERR_NON_RESUMABLE	(1 << 4)
#define	ERR_GL_STORED		(1 << 5)	/* check for GL saturation */
#define	ERR_ISSUE_DONE		(1 << 6)	/* return using DONE */
#define	ERR_CHECK_LINE_STATE	(1 << 7)	/* Check if L2$ line dirty, */
						/* if yes - non-resumable */
#define	ERR_USE_L2_CACHE_TABLE	(1 << 8)	/* Use the L2$ error table */
#define	ERR_USE_SOC_TABLE	(1 << 9)	/* Use the SOC error table */
#define	ERR_LAST_IN_TABLE	(1 << 10)	/* Last entry in error table */
#define	ERR_IO_PROT		(1 << 11)	/* I/O protection peek/poke */
#define	ERR_USE_DRAM_TABLE	(1 << 12)	/* Use the DRAM error table */
#define	ERR_CLEAR_AMB_ERRORS	(1 << 13)	/* Clear AMB FBDIMM errors */
#define	ERR_CHECK_DAU_TYPE	(1 << 14)	/* LDAU or DAU ? */
#define	ERR_FORCE_SIR		(1 << 15)	/* Force SIR immediately */
#define	ERR_ABORT_ASM		(1 << 16)	/* Abort from ASM code */
#define	ERR_ABORT_C		(1 << 17)	/* Abort from C code */
#define	ERR_NO_DRAM_DUMP	(1 << 18)	/* No dump or clear of DRAM */
						/* ESRs and data */
#define	ERR_CLEAR_SOC		(1 << 19)	/* Clear SOC ESRs */

/*
 * error flags for strand->err_flags
 *
 * STRAND_ERR_FLAG_L2DRAM[7:0] which L2/DRAM banks have a cyclic set
 * to re-enable CEEN for that bank
 * STRAND_ERR_FLAG_TICK_CMP[8:8] cyclic for CERER.TCCP/CERER.TCCD on
 * STRAND_ERR_FLAG_SOC[9:9] cyclic for SOC_ERROR_INTERRUPT_ENABLE on
 * STRAND_ERR_FLAG_ICACHE[10:10] cyclic for CERER I-Cache CEs
 * STRAND_ERR_FLAG_DCACHE[11:11] cyclic for CERER D-Cache CEs
 * STRAND_ERR_FLAG_DCACHE[12:12] cyclic for DERER DRAM CEs
 * STRAND_ERR_FLAG_PROTECTION[13:13] This error trap happened because we are
 *	retrying an error condition under protection checking for
 *	'stuck-at' or 'false' error conditions. Treat the error as if
 *	IO-protection was enabled. Note that this should only be used
 *	for error conditions which cause precise traps. Disrupting traps
 *	will be masked by PSTATE.IE while the hypervisor is executing.
 */
#define	STRAND_ERR_FLAG_L2DRAM		(1 << 0)
#define	STRAND_ERR_FLAG_TICK_CMP	(1 << 8)
#define	STRAND_ERR_FLAG_SOC		(1 << 9)
#define	STRAND_ERR_FLAG_ICACHE		(1 << 10)
#define	STRAND_ERR_FLAG_DCACHE		(1 << 11)
#define	STRAND_ERR_FLAG_DRAM		(1 << 12)
#define	STRAND_ERR_FLAG_PROTECTION	(1 << 13)

/*
 * statically allocate max. FERG/SUN4V report buffers
 */
#define	MAX_ERROR_REPORT_BUFS	8

/*
 * Sun4v guest error report types as per Sun4v Error Handling I/F
 *
 * We store the shift-value rather than the actual value to keep
 * within an 8-bit range
 */
#define	SUN4V_NO_REPORT		0xff
#define	SUN4V_CPU_RPRT		0	/* (1 << 0) */
#define	SUN4V_MEM_RPRT		1	/* (1 << 1) */
#define	SUN4V_PIO_RPRT		2	/* (1 << 2) */
#define	SUN4V_IRF_RPRT		3	/* (1 << 3) */
#define	SUN4V_FRF_RPRT		4	/* (1 << 4) */
#define	SUN4V_SHT_RPRT		5	/* (1 << 5) */
#define	SUN4V_ASR_RPRT		6	/* (1 << 6) */
#define	SUN4V_ASI_RPRT		7	/* (1 << 7) */
#define	SUN4V_PREG_RPRT		8	/* (1 << 8) */

/*
 * Invalid Real Address
 */
#define	ERR_INVALID_RA		(-1)

/*
 * PCI-E error interrupt to guest
 */
#define	SUN4V_PCIE_RPRT		0xfe

/*
 * Error Descriptor values
 */
#define	EDESC_UNDEF			0x0
#define	EDESC_UE_RESUMABLE		0x1
#define	EDESC_PRECISE_NONRESUMABLE	0x2
#define	EDESC_DEFERRED_NONRESUMABLE	0x3
#define	EDESC_WARN_RESUMABLE		0x4	/* Shutdown Warning */

#define	EDESC_TYPE_SHIFT		0
#define	EDESC_TYPE_MASK			0xf

/*
 * The Sun4v error interface specification requires bit[15] of
 * the REG value to be set to indicate a valid register value.
 */
#define	SUN4V_VALID_REG			(1 << 15)

/*
 * The Sun4v error report MODE, bits [25:24] of the ATTR field
 * 	1	User mode
 *	2 	Privileged mode
 */
#define	ATTR_USER_MODE		1
#define	ATTR_PRIV_MODE		2
#define	ATTR_MODE_SHIFT		24

/*
 * N2 error types used to identify the service report type to the FERG
 */
#define	SER_TYPE_UNDEF			0x0	/* Unknown */
#define	SER_TYPE_ITLB			0x1	/* I-TLB errors */
#define	SER_TYPE_DTLB			0x2	/* D-TLB errors */
#define	SER_TYPE_L1C			0x3	/* I-Cache/D-Cache errors */
/*
 * Internal Processor Errors including
 * IRF/FRF/Store Buffer/Scratchpad/Tick_compare
 * Trap Stack Array/MMU Register Array/
 * Modular Arithmetic MEMory/Stream Processing Unit
 */
#define	SER_TYPE_CMP			0x4
#define	SER_TYPE_L2C			0x5	/* L2 Cache errors */
#define	SER_TYPE_DRAM			0x6	/* DRAM errors */
/* Boot ROM Interface errors */
#define	SER_TYPE_SSI			0x7
/* System-On-Chip Errors  */
#define	SER_TYPE_SOC			0x8
#define	SER_TYPE_ABORT			0xf	/* Hypervisor software abort */

#define	SER_TYPE_SHIFT			4
#define	SER_TYPE_MASK			0xf

/*
 * Offsets for the various fields on the sun4v ereport sent to
 * the guest as specified by the Sun4v Hypervisor Error Handling
 * Interface. We define these separately as there is no quarantee
 * that we will use an identical struct to store the data locally.
 */
#define	SUN4V_EHDL_OFFSET		0x0
#define	SUN4V_TICK_OFFSET		0x8
#define	SUN4V_DESC_OFFSET		0x10
#define	SUN4V_ATTR_OFFSET		0x14
#define	SUN4V_ADDR_OFFSET		0x18
#define	SUN4V_SZ_OFFSET			0x20
#define	SUN4V_CPUID_OFFSET		0x24
#define	SUN4V_SECS_OFFSET		0x26
#define	SUN4V_ASI_OFFSET		0x28
#define	SUN4V_REG_OFFSET		0x2a
#define	SUN4V_PAD0_OFFSET		0x2c
#define	SUN4V_PAD1_OFFSET		0x30
#define	SUN4V_PAD2_OFFSET		0x38

#define	ERR_NAMELEN		16
#define	ERPT_MEM_SIZE		L2_LINE_SIZE /* for MEM sun4v reports */

#ifndef TRUE
#define	TRUE			1
#endif
#ifndef	FALSE
#define	FALSE			0
#endif

#define	REPORT_BUF_FREE			0	/* available for use */
#define	REPORT_BUF_IN_USE		1	/* awaiting transmission */
#define	REPORT_BUF_PENDING		2	/* data being collected */

/*
 * For PCI-E error report DESC field
 * Block	 Op     Phase     Cond   Dir	Flags
 * 31:28         27:24  23:20     19:16  15:12  11:0
 */
#define	ERR_SUN4V_PCIE_DESC_FLAGS_SHIFT		0
#define	ERR_SUN4V_PCIE_DESC_DIR_SHIFT		12
#define	ERR_SUN4V_PCIE_DESC_COND_SHIFT		16
#define	ERR_SUN4V_PCIE_DESC_PHASE_SHIFT		20
#define	ERR_SUN4V_PCIE_DESC_OP_SHIFT		24
#define	ERR_SUN4V_PCIE_DESC_BLOCK_SHIFT		28

/*
 * The valid DESC field contents are defined in the document
 * PCI-Express Root Complex Error Handling Interfaces for Sun4v
 *
 *	DESC
 *  +--------------------------------------+
 *  |Block|   Op| Phase| Cond|  Dir| Flags |
 *  |31:28|27:24| 23:20|19:16|15:12|  11:0 |
 *  +--------------------------------------+
 */
#define	ERR_PCIE_ERPT_DESC(block, op, phase, cond, dir, flags)		\
	((block <<  ERR_SUN4V_PCIE_DESC_BLOCK_SHIFT) |			\
	    (op << ERR_SUN4V_PCIE_DESC_OP_SHIFT) |			\
	    (phase << ERR_SUN4V_PCIE_DESC_PHASE_SHIFT) |		\
	    (cond << ERR_SUN4V_PCIE_DESC_COND_SHIFT) |			\
	    (dir << ERR_SUN4V_PCIE_DESC_DIR_SHIFT) |			\
	    (flags << ERR_SUN4V_PCIE_DESC_FLAGS_SHIFT))

/*
 * Size of version + info string for abort SER
 */
#define	ABORT_VERSION_INFO_SIZE		64

#ifdef TCA_ECC_ERRATA
/*
 * The TCA diagnostic registers do not return the correct data.
 * The only option for correcting errors in the TCA is to write
 * some valid value which will cause an interrupt to be generated.
 * The interrupt handler must determine whether the interrupt is
 * spurious.
 */
#define	ERR_TCA_INCREMENT		0x2000	/* ticks */
#endif

#ifndef _ASM

#define	null_fcn	(0)


/*
 * Every error will have an error table entry in one of
 * the error_tables. The error_tables correspond to the
 * ESRs, so we have sfsr_errors, dsfsr_error, l2_esr_errors,
 * dfesr_errors, desr_errors
 */

typedef struct error_table_entry {
	/*
	 * name of the error from PRM. Used for printing
	 * debug data.
	 */
	char		err_name[ERR_NAMELEN];
	/*
	 * Pointer to function which loads the error-specific
	 * data for this error. If this is non-NULL, a diag_buf
	 * will be allocated to the error and generic error data
	 * stored before calling this function.
	 */
	void 		(*err_report_fcn)(void);
	/*
	 * Pointer to function which loads the error-specific
	 * sun4v guest report data for this error.
	 */
	void 		(*err_guest_report_fcn)(void);

	/*
	 * Pointer to function which performs the error-specific
	 * correction for this error. If this is non-NULL,
	 * the function will be called after the report data is
	 * collected.
	 *
	 * Note: This function should clear the ESR for the error
	 */
	void 		(*err_correct_fcn)(void);

	/*
	 * If this error can cause storms, we will defer re-enabling
	 * the error for a short interval. This function will be passed
	 * to the cyclic system for dealing with a storm.
	 */
	void 		(*err_storm_fcn)(void);

	/*
	 * function to dump out the error-specific data for DEBUG
	 */
	void 		(*err_print_fcn)(void);

	/*
	 * flags for this error type, see above
	 */
	uint32_t	err_flags;

	/*
	 * If this is set, a Sun4v guest report will be sent
	 * corresponding to the type.
	 */
	uint8_t		err_sun4v_rprt_type;

	/*
	 * bits[3:0] Error descriptor value for sun4v guest report
	 * bits[7:4] Service report type for FERG
	 */
	uint8_t		err_sun4v_edesc;

	/*
	 * Size of Service Error Report for this error type
	 */
	uint32_t	err_report_size;

} error_table_entry_t;


/*
 * structs for storing diagnostic data
 */

struct err_way {
	uint64_t	err_tag_and_ecc;	/* tag and ecc */
	uint64_t	err_data_and_ecc[L2_NUM_WAYS]; /* data and ecc */
};

struct err_l2 {
	uint64_t	err_vdbits;	/* parity, valid, dirty */
	uint64_t	err_uabits;	/* APARITY | USED bits | ALLOC bits */
	struct err_way	err_ways[L2_NUM_WAYS];	/* info on all ways */
	uint64_t	dram_contents[N_LONG_IN_LINE];
};

/*
 * Size of dram_content[] in bytes
 */
#define	ERR_DRAM_CONTENTS_SIZE		(N_LONG_IN_LINE * SIZEOF_UI64)

struct err_tlb {
	uint64_t	err_tlb_tag;		/* TLB tag */
	uint64_t	err_tlb_data;		/* TLB data */
};

struct err_icache_way {
	uint64_t	err_icache_instr[ICACHE_NUM_OF_WORDS];
	uint64_t	err_icache_tag;
};
struct err_icache {
	struct err_icache_way	err_icache_way[MAX_ICACHE_WAYS];
};

struct err_dcache_way {
	uint64_t	err_dcache_data[DCACHE_NUM_OF_WORDS];
	uint64_t	err_dcache_tag;
};
struct err_dcache {
	struct err_dcache_way	err_dcache_way[MAX_DCACHE_WAYS];
};

struct err_ssi {
	uint64_t    err_ssi_timeout;
	uint64_t    err_ssi_log;
};

/*
 * Store Buffer Diagnostic registers
 */
struct err_stb {
	uint64_t	err_stb_data;
	uint64_t	err_stb_data_ecc;
	uint64_t	err_stb_parity;
	uint64_t	err_stb_marks;
	uint64_t	err_stb_curr_ptr;
};

/*
 * Scratchpad Diagnostic registers
 */
struct err_scratchpad {
	uint64_t	err_scratchpad_data;
	uint64_t	err_scratchpad_ecc;
};


/*
 * Tick_compare Diagnostic registers
 */
struct err_tca {
	uint64_t	err_tca_data;
	uint64_t	err_tca_ecc;
};
/*
 * Trap Stack Diagnostic registers
 */
struct err_tsa {
	uint64_t	err_tsa_ecc;
	uint64_t	err_tsa_tl;
	uint64_t	err_tsa_tt;
	uint64_t	err_tsa_tstate;
	uint64_t	err_tsa_htstate;
	uint64_t	err_tsa_tpc;
	uint64_t	err_tsa_tnpc;
	uint64_t	err_tsa_cpu_mondo_qhead;
	uint64_t	err_tsa_cpu_mondo_qtail;
	uint64_t	err_tsa_dev_mondo_qhead;
	uint64_t	err_tsa_dev_mondo_qtail;
	uint64_t	err_tsa_res_err_qhead;
	uint64_t	err_tsa_res_err_qtail;
	uint64_t	err_tsa_nonres_err_qhead;
	uint64_t	err_tsa_nonres_err_qtail;
};

struct err_mmu_regs {
	uint8_t		err_mmu_parity[MRA_ENTRIES];
	uint64_t	err_mmu_tsb_cfg_ctx0[MAX_NTSB];
	uint64_t	err_mmu_tsb_cfg_ctxnz[MAX_NTSB];
	uint64_t	err_mmu_real_range[MAX_NTSB];
	uint64_t	err_mmu_phys_offset[MAX_NTSB];
};

struct err_soc {
	uint64_t	err_soc_esr;
	uint64_t	err_soc_eler;
	uint64_t	err_soc_eier;
	uint64_t	err_soc_vcid; /* error steering register */
	uint64_t	err_soc_feer;
	uint64_t	err_soc_pesr;
	uint64_t	err_soc_eir;
	uint64_t	err_soc_sii_synd;
	uint64_t	err_soc_ncu_synd;
};

struct	err_mamu {
	uint64_t	err_ma_pa;
	uint64_t	err_ma_addr;
	uint64_t	err_ma_np;
	uint64_t	err_ma_ctl;
	uint64_t	err_ma_sync;
};

struct err_trap_regs {
	uint64_t	err_tt;
	uint64_t	err_tpc;
	uint64_t	err_tnpc;
	uint64_t	err_tstate;
	uint64_t	err_htstate;
};

/*
 * For integer/floating point register errors
 */
struct	err_reg {
	uint64_t	err_reg_ecc;
};

union err_diag_data {
	struct err_tlb		err_dtlb[DTLB_ENTRIES];
	struct err_tlb		err_itlb[ITLB_ENTRIES];
	struct err_icache	err_icache;
	struct err_dcache	err_dcache;
	struct err_ssi		err_ssi_info;
	struct err_stb		err_stb;
	struct err_scratchpad	err_scratchpad;
	struct err_tsa		err_tsa;
	struct err_mmu_regs	err_mmu_regs;
	struct err_mamu		err_mamu;
	struct err_soc		err_soc;
	struct err_tca		err_tca;
	struct err_reg		err_reg;
	struct err_l2		err_l2_cache;
	struct err_trap_regs	err_trap_registers[MAXTL];
	uint8_t			err_reg_info;
};

typedef struct err_abort_data {
	/* HV version + info string */
	unsigned char		err_version[ABORT_VERSION_INFO_SIZE];
	/* %pc where abort was initiated */
	uint64_t		err_pc;
	/* %cwp where abort was initiated */
	uint64_t		err_cwp;
	/* trap stack at time of abort */
	struct err_trap_regs	err_trap_registers[MAXTL];
	/* global registers */
	uint64_t		err_globals[8 * MAXGL];
	/* strand register windows */
	uint64_t		err_registers[24 * NWINDOWS];
	/*
	 * Fill in the rest of the data required for the s/w abort
	 * service error report here
	 */

} err_abort_data_t;

typedef struct err_diag_buf {
	uint64_t	err_sparc_isfsr;
	uint64_t	err_sparc_dsfsr;
	uint64_t	err_sparc_dsfar;
	uint64_t	err_sparc_desr;
	uint64_t	err_sparc_dfesr;
	uint64_t	err_l2_cache_esr[NO_L2_BANKS];
	uint64_t	err_l2_cache_ear[NO_L2_BANKS];
	uint64_t	err_l2_cache_nd[NO_L2_BANKS];
	uint64_t	err_dram_esr[NO_DRAM_BANKS];
	uint64_t	err_dram_ear[NO_DRAM_BANKS];
	uint64_t	err_dram_cntr[NO_DRAM_BANKS];
	uint64_t	err_dram_loc[NO_DRAM_BANKS];
	uint64_t	err_dram_fbd[NO_DRAM_BANKS];
	uint64_t	err_dram_retry[NO_DRAM_BANKS];
	uint64_t	err_l2_bank;	/* bank in error */
	uint64_t	err_l2_line_state;
	uint64_t	err_l2_pa;
	union err_diag_data	err_diag_data;
	/* Note: the in_use flag must not move from here */
	uint32_t	err_report_in_use;	/* in-use flag */
	uint32_t	err_report_size; /* report diag-data size */
} err_diag_buf_t;

/*
 * Diagnostic error report structure.
 */

typedef struct err_sun4v_rprt {
	union {
		sun4v_cpu_erpt_t		sun4v_cpu_erpt;
		sun4v_pcie_erpt_t		sun4v_pcie_erpt;
	} sun4v_erpt;
	uint64_t	in_use;		/* in-use flag */
} err_sun4v_rprt_t;

typedef struct err_diag_rprt {
	uint64_t	error_type;	/* CPU/MEM or I/O */
	uint64_t	report_type;	/* report type */
	uint64_t	tod;		/* TOD value */
	uint64_t	ehdl; 		/* error handle */
	uint64_t	err_stick; 	/* value of %stick */
	uint64_t	cpuver;		/* Processor version reg */
	uint64_t	cpuserial;	/* Processor serial reg */
	uint64_t	tstate;		/* Value of %tstate */
	uint64_t	htstate;	/* Value of %htstate */
	uint64_t	tpc;		/* Value of %tpc */
	uint16_t	cpuid;		/* ID of CPU */
	uint16_t	tt;		/* Value of %tt */
	uint8_t		tl;		/* Value of %tl */
	union {
		err_diag_buf_t		err_diag;
		err_abort_data_t	err_abort;
	} err_diag_report_data;
} err_diag_rprt_t;

#endif /* !_ASM */


/*
 * ECC Syndromes
 *
 * Note: A value of 0:67 indicates a single bit error on the
 *	 data bit of that number. The TSA registers can go
 *	 up to 132 bits.
 */
#define	ECC_LAST_BIT	67
#define	ECC_ne		(ECC_LAST_BIT * 2 + 1) /* no error , keep this first) */
#define	ECC_C0		(ECC_LAST_BIT * 2 + 2) /* ECC Checkbit 0 error */
#define	ECC_C1		(ECC_LAST_BIT * 2 + 3) /* ECC Checkbit 1 error */
#define	ECC_C2		(ECC_LAST_BIT * 2 + 4) /* ECC Checkbit 2 error */
#define	ECC_C3		(ECC_LAST_BIT * 2 + 5) /* ECC Checkbit 3 error */
#define	ECC_C4		(ECC_LAST_BIT * 2 + 6) /* ECC Checkbit 4 error */
#define	ECC_C5		(ECC_LAST_BIT * 2 + 7) /* ECC Checkbit 5 error */
#define	ECC_C6		(ECC_LAST_BIT * 2 + 8) /* ECC Checkbit 6 error */
#define	ECC_C7		(ECC_LAST_BIT * 2 + 9) /* ECC Checkbit 7 error */
/* Uncorrectable double (or 2n) bit error */
#define	ECC_U		(ECC_LAST_BIT * 2 + 10)
/* Triple or worse (2n + 1) bit error */
#define	ECC_M		(ECC_LAST_BIT * 2 + 11)
/* Notdata -or- Triple or worse (2n + 1) bit error */
#define	ECC_N_M		(ECC_LAST_BIT * 2 + 12)

/*
 * 6 bit syndrome for FRF errors
 */
#define	FRF_SYND6_SHIFT		6
#define	FRF_SYND5_MASK		0x3f

/*
 * Number of entries in the frfc_ecc_mask_table
 */
#define	NO_FRF_ECC_MASKS	7

#ifndef _ASM
typedef	uint8_t		ecc_syndrome_table_entry;
typedef	uint32_t	ecc_mask_table_entry;
#endif

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_ERROR_DEFS_H */
