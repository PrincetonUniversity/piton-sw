/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cpu_errs_defs.h
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
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _NIAGARA_CPU_ERRS_DEFS_H
#define	_NIAGARA_CPU_ERRS_DEFS_H

#pragma ident	"@(#)cpu_errs_defs.h	1.10	07/02/22 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	CE_XDIAG_NONE	0x0	/* No disposition */
#define	CE_XDIAG_CE1	0x20	/* CE logged on casx during scrub */
#define	CE_XDIAG_CE2	0x40	/* CE logged on post-scrub reread */

#ifndef _ASM
#include <cache.h>

struct way {
	uint64_t	tag_and_ecc;	/* tag and ecc */
	uint64_t	data_and_ecc[16]; /* data and ecc */
};

struct l2 {
	uint64_t	vdbits;		/* parity, valid, dirty */
	uint64_t	uabits;		/* APARITY | USED bits | ALLOC bits */
	struct way	ways[L2_NUM_WAYS];	/* info on all ways */
	uint64_t	dram_contents[N_LONG_IN_LINE];
};

struct tlb {
	uint64_t	tag;		/* Tlb tag */
	uint64_t	data;		/* TLB data */
};

/*
 * Each icache word of the data contains:
 * 63..34	reserved
 * 33		switch bit for instruction
 * 32		parity
 * 31..0	instruction
 * Even though the icache is only 32 bits of data/subblocks we need
 * a 64 bit word to save the parity and the switch.
 */
struct icache_way {
	uint64_t	tag;
	uint64_t	diag_data[ICACHE_NUM_OF_WORDS];
};

struct icache {
	uint64_t	lsu_diag_reg;
	struct icache_way	icache_way[ICACHE_MAX_WAYS];
};

struct dcache_way {
	uint64_t	tag;
	uint64_t	data[DCACHE_NUM_OF_WORDS];	/* cache line */
};

struct dcache {
	uint64_t	lsu_diag_reg;
	struct dcache_way	dcache_way[DCACHE_MAX_WAYS];
};

struct dram {
	struct l2	l2_info;
	uint64_t	disposition;	/* CE disposition */
};

struct js {
	uint64_t	jbi_err_config;
	uint64_t	jbi_err_ovf;
	uint64_t	jbi_log_enb;
	uint64_t	jbi_sig_enb;
	uint64_t	jbi_log_addr;
	uint64_t	jbi_log_data0;
	uint64_t	jbi_log_data1;
	uint64_t	jbi_log_ctrl;
	uint64_t	jbi_log_par;
	uint64_t	jbi_log_nack;
	uint64_t	jbi_log_arb;
	uint64_t	jbi_l2_timeout;
	uint64_t	jbi_arb_timeout;
	uint64_t	jbi_trans_timeout;
	uint64_t	jbi_memsize;
	uint64_t	jbi_err_inject;
	uint64_t	ssi_timeout;
	uint64_t	ssi_log;
};

union diag_buf {
	struct l2	l2_info;
	struct tlb	dtlb[64];
	struct tlb	itlb[64];
	struct icache	icache;
	struct dcache	dcache;
	struct dram	dram_info;
	struct js	jbi_ssi_info;
	uint8_t		reg_info;
};

/*
 * Diagnostic error report structure.
 * Area containing both the sun4v error report and the diagnostic
 * error report.
 */

struct evbsc {
	uint64_t	report_type;	/* cpu or io identifier */
	uint64_t	fpga_tod;	/* Value of FPGA TOD */
	uint64_t	ehdl; 		/* error handle */
	uint64_t	stick; 		/* value of %stick */
	uint64_t	cpuver;		/* Processor version reg */
	uint64_t	cpuserial;	/* Processor serial reg */
	uint64_t	sparc_afsr;	/* Value of strand's %afsr */
	uint64_t	sparc_afar;	/* Value of strand's %afar */
	uint64_t	l2_afsr[4];	/* L2$ bank %afsr */
	uint64_t	l2_afar[4];	/* L2$ bank %afar */
	uint64_t	dram_afsr[4]; 	/* DRAM %afsr */
	uint64_t	dram_afar[4]; 	/* DRAM %afar */
	uint64_t	dram_loc[4]; 	/* DRAM error location reg */
	uint64_t	dram_cntr[4]; 	/* DRAM error counter reg */
	uint64_t	tstate;		/* Value of %tstate */
	uint64_t	htstate;	/* Value of %htstate */
	uint64_t	tpc;		/* Value of %tpc */
	uint16_t	cpuid;		/* ID of CPU */
	uint16_t	tt;		/* Value of %tt */
	uint8_t		tl;		/* Value of %tl */
	uint8_t		erren;		/* error enable setting */
	uint16_t	pad1;		/* pad1 */
	uint64_t	jbi_err_log;	/* JBI error status reg */
	union diag_buf	ediag_buf;	/* buffer */
};

struct strand_erpt {
	struct sun4v_cpu_erpt strand_sun4v_erpt; /* error report pkt to sun4v */
	struct evbsc	strand_vbsc_erpt;	 /* error report pkt to vbsc */
	int		unsent_pkt;		 /* make pkt to be sent */
};
#endif /* ASM */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_CPU_ERRS_DEFS_H */
