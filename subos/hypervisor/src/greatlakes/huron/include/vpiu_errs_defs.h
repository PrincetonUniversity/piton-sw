/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpiu_errs_defs.h
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

#ifndef _NIAGARA2_VPIU_ERRS_DEFS_H
#define	_NIAGARA2_VPIU_ERRS_DEFS_H

#pragma ident	"@(#)vpiu_errs_defs.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM
/*
 * Diagnostic error report structure.
 * Area containing both the sun4v error report and the diagnostic
 * error report.
 * Total size < 4096 (0x1000). So offsets into this struct can be used
 * as immediate values in assembler for reads and writes.
 * First 64 bytes is the sun4v error report sent to the affected guest.
 * The diagnostic error report starts at offset 0x40.
 */
struct epkt {
	/* sun4v guest error report starts at offset 0x0 */
	uint64_t	sysino;		/* I/O error interrupt number */
	uint64_t	sun4v_ehdl;	/* guest error handle */
	uint64_t	sun4v_stick;	/* %stick to guest */
	uint32_t	sun4v_desc;	/* error decriptor */
	uint32_t	sun4v_specfic;	/* error specific */
	uint64_t	word4;
	uint64_t	HDR1;		/* pci header 1 */
	uint64_t	HDR2;		/* pci header 2 */
	uint64_t	word7;		/* filler */
};

struct dmu_err {
	uint64_t	report_type;	/* cpu/io identifier */
	uint64_t	fpga_tod;	/* FPGA TOD */
	uint64_t	pciehdl; 	/* EHDL */
	uint64_t	pcistick; 	/* STICK */
	uint64_t	cpuver;		/* Proc version reg */
	uint32_t	agentid;
	uint32_t	mondo_num;
		/* mondo 62 regs */
	uint64_t	dmu_core_and_block_err_status;	/* 0x631808, dmu_cbes */
	uint64_t	imu_err_log_enable;		/* 0x631000, imu_ele */
	uint64_t	imu_interrupt_enable;		/* 0x631008, imu_ie */
	uint64_t	imu_enabled_err_status;		/* 0x631010, imu_is */
	uint64_t	imu_err_status_set;		/* 0x631020, imu_ess */
	uint64_t	imu_scs_err_log;
	uint64_t	imu_eqs_err_log;
	uint64_t	imu_rds_err_log;
	uint64_t	mmu_err_log_enable;		/* 0x641000, mmu_ele */
	uint64_t	mmu_intr_enable;		/* 0x641008, mmu_ie */
	uint64_t	mmu_intr_status;		/* 0x641010, mmu_is */
	uint64_t	mmu_err_status_set;		/* 0x641020, mmu_iss */
	uint64_t	mmu_translation_fault_address;	/* 0x641028, mmu_tfa */
	uint64_t	mmu_translation_fault_status;	/* 0x641030, mmu_tfs */
};

struct	peu_err {
	uint64_t	report_type;	/* cpu or io identifier */
	uint64_t	fpga_tod;	/* FPGA TOD */
	uint64_t	pciehdl; 	/* error handle */
	uint64_t	pcistick; 	/* value of %stick */
	uint64_t	cpuver;		/* Processor version reg */
	uint32_t	agentid;
	uint32_t	mondo_num;
	/* mondo 63 regs */
	uint64_t	peu_core_and_block_intr_enable;	/* 0x651800 peu_cbie */
	uint64_t	peu_core_and_block_intr_status;	/* 0x651808 peu_cbis */
	uint64_t	ilu_err_log_enable;		/* 0x651000 ilu_ele */
	uint64_t	ilu_intr_enable;		/* 0x651008 ilu_ie */
	uint64_t	ilu_intr_status;		/* 0x651010 ilu_is */
	uint64_t	ilu_err_status_set;		/* 0x651020 ilu_ess */
	uint64_t	peu_other_event_log_enable;	/* 0x681000 peu_oele */
	uint64_t	peu_other_event_intr_enable;	/* 0x681008 peu_oeie */
	uint64_t	peu_other_event_intr_status;	/* 0x681010 peu_oeis */
	uint64_t	peu_other_event_status_set;	/* 0x681020 peu_oess */
	uint64_t	peu_receive_other_event_header1_log;
							/* 0x681028 peu_roeh1 */
	uint64_t	peu_receive_other_event_header2_log;
							/* 0x681030 peu_roeh2 */
	uint64_t	peu_transmit_other_event_header1_log;
							/* 0x681038 peu_toeh1 */
	uint64_t	peu_transmit_other_event_header2_log;
							/* 0x681040 peu_toeh2 */
	uint64_t	peu_ue_log_enable;		/* 0x691000 peu_uele */
	uint64_t	peu_ue_interrupt_enable;	/* 0x691008 peu_ueie */
	uint64_t	peu_ue_status;			/* 0x691010 peu_ueis */
	uint64_t	peu_ue_status_set;		/* 0x691020 peu_uess */
	uint64_t	peu_receive_ue_header1_log;	/* 0x691028 peu_rueh1 */
	uint64_t	peu_receive_ue_header2_log;	/* 0x691030 peu_rueh2 */
	uint64_t	peu_transmit_ue_header1_log;	/* 0x691038 peu_tueh1 */
	uint64_t	peu_transmit_ue_header2_log;	/* 0x691040 peu_tueh2 */
	uint64_t	peu_ce_log_enable;		/* 0x6a1000 peu_cele */
	uint64_t	peu_ce_interrupt_enable;	/* 0x6a1008 peu_ceie */
	uint64_t	peu_ce_interrupt_status;	/* 0x6a1010 peu_ceis */
	uint64_t	peu_ce_status_set;		/* 0x6a1020 peu_cess */
	uint64_t	PEU_CXPL_event_error_log_enable; /* 0x6E2108 peu_eele */
	uint64_t	PEU_CXPL_event_error_int_enable; /* 0x6E2110 peu_eeie */
	uint64_t	PEU_CXPL_event_error_int_status; /* 0x6E2118 peu_eeis */
	uint64_t	PEU_CXPL_event_error_status_set; /* 0x6E2128 peu_eess */
};

struct pci_erpt {
	struct epkt	pciepkt;
	union {
		struct	dmu_err		dmu_err;
		struct	peu_err		peu_err;
	} _u;
	int		unsent_pkt;	/* mark pkt to be sent */
};

typedef struct epkt	sun4v_pcie_erpt_t;

#endif /* ASM */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_VPIU_ERRS_DEFS_H */
