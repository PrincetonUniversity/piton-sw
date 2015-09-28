/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci_errs.s
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

	.ident	"@(#)vpci_errs.s	1.23	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <strand.h>
#include <offsets.h>
#include <errs_common.h>
#include <debug.h>
#include <vpci_errs.h>
#include <util.h>
#include <abort.h>
#include <vdev_intr.h>
#include <fire.h>


#define	r_fire_cookie	%g1
#define	r_fire_e_rpt	%g2
#define	r_fire_leaf_address	%g4

#define	r_tmp1		%g5
#define	r_tmp2		%g7

#if defined(CONFIG_FIRE)

	!! %g1 = Fire Cookie
	!! %g2 = Mondo DATA0
	!! %g3 = IGN
	!! %g4 = INO
	ENTRY_NP(error_mondo_62)
	PRINT("HV:mondo 62\r\n")
	mov	%g2, %g7 ! save DATA0 for err handle setup

	!!
	!! Generate a unique error handle
	!! enters with:
	!! %g1 loaded with fire cookie
	!! %g2 data0, overwritten with r_fire_e_rpt
	!! %g3 IGN
	!! %g4 INO
	!! %g5 scratch
	!! %g6 scratch
	!! %g7 data0
	!!
	!! returns with:
	!! %g1 r_fire_cookie
	!! %g2 pointing to r_fire_e_rpt
	!!
	GEN_ERR_HNDL_SETUP_ERPTS(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	ldx	[r_fire_cookie + FIRE_COOKIE_PCIE], %g4
	! use alias r_fire_leaf_address for %g4 now
	!!
	!! %g1 Fire cookie
	!! %g2 fire error rpt
	!! %g3 - temporary
	!! %g4 r_fire_leaf_address
	!! %g5 - temporary, last register loaded
	!!
	! which core interruped?
	set	FIRE_DLC_IMU_ICS_MULTI_CORE_ERROR_STATUS_REG, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	and	r_tmp1, DMC_BIT, r_tmp2
	brnz,a	r_tmp2, dmc_core_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_MULTI_CORE_ERR_STATUS]
	and	r_tmp1, PEC_BIT, r_tmp2
	brnz,a	r_tmp2, pec_core_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_MULTI_CORE_ERR_STATUS]
	! should not get here
	PRINT("HV:mondo 62 fall through to retry\r\n")
	ba,a	clear_pcie_err_fire_interrupt
	.empty

dmc_core_processing:
	PRINT("HV:PEC\r\n")
	set	FIRE_DLC_IMU_ICS_DMC_INTERRUPT_STATUS_REG, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	and	r_tmp1, MMU_BIT, r_tmp2
	brnz,a	r_tmp2, mmu_block_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_DMC_CORE_AND_BLOCK_ERR_STATUS]
	and	r_tmp1, IMU_BIT, r_tmp2
	brnz,a	r_tmp2, imu_block_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_DMC_CORE_AND_BLOCK_ERR_STATUS]
	! should not get here
	PRINT("HV:PEC fallthrough to retry\r\n")
	ba,a	clear_pcie_err_fire_interrupt
	.empty


imu_block_processing:
	PRINT("HV:imu_block_processing\r\n")
	set	FIRE_DLC_IMU_ICS_IMU_ENABLED_ERROR_STATUS_REG, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	!r_tmp1 is not changed for this block

.imu_eq_not_en_group_p:
	PRINT("HV:.imu_eq_not_en_group_p\r\n")
	btst	IMU_EQ_NOT_EN_GROUP_P, r_tmp1
	bz	%xcc, .imu_eq_over_group_p
	and	r_tmp1, IMU_EQ_NOT_EN_GROUP_P, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_SCS_ERROR_LOG_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_P(r_fire_e_rpt,			\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_NOT_EN_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.imu_eq_over_group_p:
	PRINT("HV:imu_eq_over_group_p\r\n")
	btst	IMU_EQ_OVER_GROUP_P, r_tmp1
	bz	%xcc, .imu_msi_mes_group_p
	and	r_tmp1, IMU_EQ_OVER_GROUP_P, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_EQS_ERROR_LOG_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_IMU_EQ_OVER_GROUP_EPKT_P_S(r_fire_e_rpt,			\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_OVER_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.imu_msi_mes_group_p:
	PRINT("HV:imu_msi_mes_group_p\r\n")
	btst	IMU_MSI_MES_GROUP_P, r_tmp1
	bz	%xcc, .imu_eq_not_en_group_s
	and	r_tmp1, IMU_MSI_MES_GROUP_P, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_RDS_ERROR_LOG_REG(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_IMU_MSI_MES_GROUP_EPKT_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_IMU_MSI_MES_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.imu_eq_not_en_group_s:
	PRINT("HV:imu_eq_not_en_group_s\r\n")
	set	IMU_EQ_NOT_EN_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .imu_eq_over_group_s
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_S(r_fire_e_rpt,			\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_NOT_EN_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.imu_eq_over_group_s:
	PRINT("HV:imu_eq_over_group_s\r\n")
	set	IMU_EQ_OVER_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .imu_msi_mes_group_s
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_IMU_EQ_OVER_GROUP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,\
							r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_OVER_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.imu_msi_mes_group_s:
	PRINT("HV:imu_msi_mes_group_s\r\n")
	set	IMU_MSI_MES_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .imu_block_processing_nothing_to_do
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_MSI_MES_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.imu_block_processing_nothing_to_do:
	PRINT("HV:imu_block_processing_nothing_to_do\r\n")
	! we should not get here
	ba,a	clear_pcie_err_fire_interrupt
	.empty

mmu_block_processing:
	PRINT("HV:mmu_block_processing\r\n")
	set	FIRE_DLC_MMU_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1

.mmu_err_group_p:
	PRINT("HV:mmu_err_group_p\r\n")
	PRINT("HV:FIRE_DLC_MMU_EN_ERR:0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#ifdef DEBUG
	/* PRINT() destroys %g7, which is r_tmp2, so need to reload the reg */
	set	FIRE_DLC_MMU_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
#endif
	set	MMU_ERR_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .mmu_err_group_s
	and	r_tmp1, r_tmp2, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_MMU_INTR_STATUS]
	LOG_DMC_MMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_MMU_TRANS_FAULT_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_MMU_ERR_GROUP_EPKT_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_MMU_ERR_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.mmu_err_group_s:
	PRINT("HV:mmu_err_group_s\r\n")
	set	MMU_ERR_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .mmu_block_processing_nothing_to_do
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_MMU_INTR_STATUS]
	LOG_DMC_MMU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	CLEAR_MMU_ERR_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.mmu_block_processing_nothing_to_do:
	PRINT("HV:mmu_block_processing_nothing_to_do\r\n")
	! we should not get here
	ba,a	clear_pcie_err_fire_interrupt
	.empty

! read the PEC Core and Block Error Status Register (0x651808, 0x751808).
! This register describes which one or more than one of the 4 possible block(s)
! in the PEC Core has an error which needs to be processed.
! bit 0 set in this register the Mondo was caused by the a PEC OE register.
! bit 1 set in this register means the Mondo was caused by the PEC CE Register.
! bit 2 set in this register means the Mondo was caused by the PEC UE Register.
! bit 3 was set in this register the Mondo was caused by the ILU block.
pec_core_processing:
	PRINT("HV:pec_core_processing\r\n")
	set	FIRE_DLC_ILU_CIB_PEC_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	and	r_tmp1, PEC_ILU_BIT, r_tmp2
	brnz,a	r_tmp2, .pec_ilu_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_PEC_CORE_AND_BLOCK_INTR_STATUS]
	and	r_tmp1, PEC_UE_BIT, r_tmp2
	brnz,a	r_tmp2, .pec_ue_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_PEC_CORE_AND_BLOCK_INTR_STATUS]
	and	r_tmp1, PEC_CE_BIT, r_tmp2
	brnz,a	r_tmp2, .pec_ce_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_PEC_CORE_AND_BLOCK_INTR_STATUS]
	and	r_tmp1, PEC_OE_BIT, r_tmp2
	brnz,a,pt r_tmp2, .pec_oe_processing
	  stx	r_tmp2, [r_fire_e_rpt + PCIERPT_PEC_CORE_AND_BLOCK_INTR_STATUS]
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.pec_ilu_processing:
.ilu_interrupt_status_p:
	PRINT("HV:ilu_interrupt_status_p\r\n")
	set	FIRE_DLC_ILU_CIB_ILU_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	btst	ILU_GROUP_P, r_tmp1
	bz	%xcc, .ilu_interrupt_status_s
	and	r_tmp1, ILU_GROUP_P, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_ILU_INTR_STATUS]
	LOG_ILU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_ILU_EPKT_P(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_ILU_GROUP_P(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)

	ba,a	pcie_err_mondo_ereport
	.empty


.ilu_interrupt_status_s:
	PRINT("HV:ilu_interrupt_status_s\r\n")
	set	ILU_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .ilu_nothing_todo
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_ILU_INTR_STATUS]
	LOG_ILU_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_ILU_GROUP_S(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.ilu_nothing_todo:
	PRINT("HV:ilu_nothing_todo\r\n")
	ba,a	clear_pcie_err_fire_interrupt
	.empty

! spec doesn't mention bits 15 and 13
! bit 15 CA_P (Completer Abort Primary Error) does not capture any info
! As for the completer abort, this is a resultant of many of the MMU errors
! and not an error itself.
! bit 13 FCP_P (Flow Control Protocol Primary error) does not capture any info
! bits 17, 14 (rof, cto)
! TLU Transmit Uncorrectable Error Header1 Log Register (0x691038, 0x791038 )
! TLU Transmit Uncorrectable Error Header2 Log Register (0x691040, 0x791040 )
!
!
! clear with TLU Uncorrectable Error Status Clear Register (0x691018, 0x791018)
! no logging registers for bit 0 and 4
.pec_ue_processing:
.tlu_uce_recv_group_p:
	PRINT("HV:tlu_uce_recv_group_p\r\n")
	set	FIRE_PLC_TLU_CTB_TLR_UE_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	set	TLU_UE_RECV_GROUP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_trans_group_p
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_RCV_HDR_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_TLU_UE_RECV_GROUP_EPKT_P(r_fire_e_rpt, r_fire_leaf_address,\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_RECV_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty


.tlu_uce_trans_group_p:
	PRINT("HV:tlu_uce_trans_group_p\r\n")
	set	TLU_UE_TRANS_GROUP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_tlu_dlp_p
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	PRINT("r_tmp1 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_TRANS_HDR_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_TLU_UE_TRANS_EPKT_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_TRANS_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_dlp_p:
/*
 * Special case error, no data, plus dup in another reg
 */
	PRINT("HV:tlu_uce_tlu_dlp_p\r\n")
	set	TLU_DLP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_tlu_fcp_p
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	PRINT("HV:r_tmp1 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_DLP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_DLP_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_fcp_p:
	PRINT("HV:tlu_uce_tlu_fcp_p\r\n")
	set	TLU_FCP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_tlu_ca_p
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_FCP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_FCP_P(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, 	\
								r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty


.tlu_uce_tlu_ca_p:
	PRINT("HV:tlu_uce_tlu_fcp_p\r\n")
	set	TLU_CA_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_tlu_dlp_s
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_CA_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_CA_P(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_dlp_s:
/*
 * Special case error, no data, plus dup in another reg
 */
	PRINT("HV:tlu_uce_tlu_dlp_s\r\n")
	set	TLU_DLP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_tlu_te_p
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_DLP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_DLP_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_te_p:
/*
 * Special case error, no data, plus dup in another reg
 */
	PRINT("HV:tlu_uce_tlu_te_p\r\n")
	set	TLU_TE_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2,	.tlu_uce_tlu_te_s
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_TE_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_TE_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_te_s:
/*
 * Special case error, no data, plus dup in another reg
 */
	PRINT("HV:tlu_uce_tlu_te_s\r\n")
	set	TLU_TE_P, r_tmp2
	sllx	r_tmp2,  PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2,	.tlu_uce_recv_group_s
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_TE_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_TLU_UE_TE_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_recv_group_s:
	PRINT("HV:tlu_uce_recv_group_s\r\n")
	set	TLU_UE_RECV_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_trans_group_s
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_TRANS_HDR_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_RECV_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.tlu_uce_trans_group_s:
	PRINT("HV:tlu_uce_trans_group_s\r\n")
	set	TLU_UE_TRANS_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz,pn  r_tmp2, .tlu_uce_tlu_fcp_s
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_TLU_UE_TRANS_EPKT_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_TLU_UE_TRANS_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_fcp_s:
	set	TLU_FCP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_tlu_ca_s
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_FCP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_FCP_S(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, 	\
								r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_tlu_ca_s:
	PRINT("HV:tlu_uce_tlu_ca_s\r\n")
	set	TLU_CA_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .tlu_uce_nothingtodo
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_UE_STATUS]
	LOG_TLU_UE_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	LOG_TLU_UE_CA_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_UE_CA_S(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.tlu_uce_nothingtodo:
	PRINT("HV:tlu_uce_nothingtodo\r\n")
	PRINT("HV:r_tmp1 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.pec_ce_processing:
.pec_ce_primary:
	PRINT("HV:pec_ce_processing\r\n")
! to clear dup regs ,  read page 392 of the november fire spec
	set	FIRE_PLC_TLU_CTB_TLR_CE_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:FIRE_PLC_TLU_CTB_TLR_CE_EN_ERRR = 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	set	TLU_CE_GROUP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .pec_ce_secondary
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_CE_INTR_STATUS]
	LOG_TLU_CE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_CE_GROUP_EPKT_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_TLU_CE_GROUP_P(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.pec_ce_secondary:
	PRINT("HV:pec_ce_secondary\r\n")
	set	TLU_CE_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz,pn  r_tmp2, .pec_ce_nothingtodo
	nop
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_TLU_CE_INTR_STATUS]
	LOG_TLU_CE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_CE_GROUP_EPKT_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_TLU_CE_GROUP_S(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,	\
								r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

.pec_ce_nothingtodo:
#ifdef DEBUG
	PRINT("HV:pec_ce_nothingtodo\r\n")
	set	FIRE_PLC_TLU_CTB_TLR_CE_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:FIRE_PLC_TLU_CTB_TLR_CE_EN_ERR:0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.pec_oe_processing:
	PRINT("HV:pec_oe_processing\r\n")
.tlu_receive_other_event_p:
	PRINT("HV:tlu_receive_other_event_p\r\n")
	/*
	 * Also logs trans regs
	 */
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:contents = 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	set	TLU_OE_RECEIVE_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .tlu_oe_link_interrupt_group_p
	nop
	/*
	 * Special, this set of errors also records some in the transmit
	 * regs
	 */
	set	 TLU_OE_TRANS_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1,	r_tmp2, TLU_OE_RECEIVE_GROUP_P)
	LOG_TLU_OE_TRANS_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	2f
	  .empty
1:
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1,	r_tmp2, TLU_OE_RECEIVE_GROUP_P)
2:
	LOG_TLU_OE_RECV_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_TLU_OE_RECV_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty
	.poplocals

.tlu_receive_other_event_s:
	PRINT("HV:tlu_receive_other_event_s\r\n")
	set	TLU_OE_RECEIVE_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .tlu_oe_dup_lli_s
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1,	r_tmp2, TLU_OE_RECEIVE_GROUP_P)
	CLEAR_TLU_OE_RECV_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.tlu_oe_dup_lli_s:
	PRINT("HV:tlu_oe_dup_lli_s\r\n")
	/*
	 * these errors express themselves with possible duplicate bits
	 * in the LPU Link Layer Interrupt reg (0x6e2210, 0x7e2210)
	 */
	set	TLU_OE_DUP_LLI_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .pec_oe_processing_nothingtodo
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_DUP_LLI_P)
	/*
	 * bits 9 through 4 are the dup bits, yet we do not send any
	 * info to the guest, so just clear them all.  fma has received all
	 * the info
	 */ 
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_TLU_OE_DUP_LLI_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty
	
.tlu_oe_link_interrupt_group_p:
	PRINT("HV:.tlu_oe_link_interrupt_group_p\r\n")
	PRINT("HV:r_tmp1 = 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	set	TLU_OE_LINK_INTERRUPT_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .tlu_trans_other_event_p
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
			r_tmp1,	r_tmp2, TLU_OE_LINK_INTERRUPT_GROUP_P)

	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_INTERRUPT_STATUS, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_INTERRUPT_STATUS\r\n")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	and	r_tmp1, LPU_INT_STAT_INT_PERF_CNTR_2_OVFLW, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_perf_cntr_2_ovflw
	nop
	and	r_tmp1, LPU_INT_STAT_INT_PERF_CNTR_1_OVFLW, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_perf_cntr_1_ovflw
	nop
	and	r_tmp1, LPU_INT_STAT_INT_LINK_LAYER, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_link_layer
	nop
	and	r_tmp1, LPU_INT_STAT_INT_PHY_ERROR, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_phy_error
	nop
	and	r_tmp1, LPU_INT_STAT_INT_LTSSM, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_ltssm
	nop
	and	r_tmp1, LPU_INT_STAT_INT_PHY_TX, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_phy_tx
	nop
	and	r_tmp1, LPU_INT_STAT_INT_PHY_RX, r_tmp2
	brnz,pn r_tmp2, .lpu_int_stat_int_phy_rx
	nop
	and	r_tmp1, LPU_INT_STAT_INT_PHY_GB, r_tmp2
	brnz,pt r_tmp2, .lpu_int_stat_int_phy_gb
	nop

.nothing_to_do_tlu_oe_link_interrupt_group_p:
	PRINT("HV:.nothing_to_do_tlu_oe_link_interrupt_group_p\r\n")
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_perf_cntr_2_ovflw:
	PRINT("HV:.lpu_int_stat_int_perf_cntr_2_ovflw\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address, 	\
		LPU_INT_STAT_INT_PERF_CNTR_2_OVFLW, r_tmp1, r_tmp2)
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR2(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_PERF_CNTR_2_OVFLW(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_perf_cntr_1_ovflw:
	PRINT("HV:.lpu_int_stat_int_perf_cntr_1_ovflw\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
		LPU_INT_STAT_INT_PERF_CNTR_1_OVFLW, r_tmp1, r_tmp2) 
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_PERF_CNTR_1_OVFLW(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_link_layer:
	PRINT("HV:.lpu_int_stat_int_link_layer\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
			LPU_INT_STAT_INT_LINK_LAYER, r_tmp1, r_tmp2) 
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_phy_error:
	PRINT("HV:.lpu_int_stat_int_phy_error\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
		LPU_INT_STAT_INT_PHY_ERROR, r_tmp1, r_tmp2) 
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_ltssm:
	PRINT("HV:.lpu_int_stat_int_ltssm\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
		LPU_INT_STAT_INT_LTSSM, r_tmp1, r_tmp2) 
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM(r_fire_e_rpt,		\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM(r_fire_e_rpt,		\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_phy_tx:
	PRINT("HV:.lpu_int_stat_int_phy_tx\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
		LPU_INT_STAT_INT_PHY_TX, r_tmp1, r_tmp2) 
#ifdef	DEBUG
	set	 FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:LPU_INT_STAT_INT_PHY_TX\r\n")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif

	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_phy_rx:
	PRINT("HV:.lpu_int_stat_int_phy_rx\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
		LPU_INT_STAT_INT_PHY_RX, r_tmp1, r_tmp2) 
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	ba,a	.all_done_tlu_oe_link_interrupt_group_p
	  .empty

.lpu_int_stat_int_phy_gb:
	PRINT("HV:.lpu_int_stat_int_phy_gb\r\n")
	LOG_PCIERPT_LPU_INTR_STATUS(r_fire_e_rpt, r_fire_leaf_address,	\
		LPU_INT_STAT_INT_PHY_GB, r_tmp1, r_tmp2) 
#ifdef	DEBUG
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_GL_INT, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:LPU_GB_STAT_INT_PHY_TX\r\n")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif
	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_PHY_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_PHY_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)

.all_done_tlu_oe_link_interrupt_group_p:
	PRINT("HV:all_done_tlu_oe_link_interrupt_group_p\r\n")
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, r_tmp2
	set	TLU_OE_LINK_INTERRUPT_GROUP_P, r_tmp1
	stx	r_tmp1, [r_fire_leaf_address + r_tmp2]
	
#ifdef	DEBUG
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, r_tmp2
	ldx	[r_fire_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif
	ba,a	clear_pcie_err_fire_interrupt
	.empty

.tlu_trans_other_event_p:
	PRINT("HV:tlu_trans_other_event_p\r\n")
	/*
	 * Bits 22:21, 17, 16, and 15
	 * this test must happen after the recieve other event test
	 * as both the transmit and recieve groups have overlap and
	 * post info to both trans and receive regs.  Since we tested
	 * the overlap in the receive we won't need to test it here
	 * in theory the only bit we should see is the one that only
	 * posts to the trans reg
	 */
	set	TLU_OE_TRANS_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .tlu_oe_no_dup_group_p
	nop
	set	TLU_OE_TRANS_SVVS_RPT_MSK, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_TRANS_GROUP_P)
	LOG_TLU_OE_TRANS_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_TLU_OE_TRANS_GROUP_EPKT_P(r_fire_e_rpt, r_fire_leaf_address,\
							r_tmp1, r_tmp2)
	CLEAR_TLU_OE_TRANS_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty
1:
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_TRANS_GROUP_P)
	LOG_TLU_OE_TRANS_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_OE_TRANS_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty
	.poplocals

.tlu_oe_no_dup_group_p:
	PRINT("HV:tlu_oe_no_dup_group_p\r\n")
	set	TLU_OE_NO_DUP_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .tlu_oe_dup_lli_p
	nop
	set	TLU_OE_NO_DUP_SVVS_RPT_MSK, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_NO_DUP_GROUP_P)
	LOG_TLU_OE_NO_DUP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_TLU_OE_NO_DUP_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty
1:
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_NO_DUP_GROUP_P)
	CLEAR_TLU_OE_NO_DUP_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty
	.poplocals

.tlu_oe_dup_lli_p:
	PRINT("HV:tlu_oe_dup_lli_p\r\n")
	/*
	 * these errors express themselves with possible duplicate bits
	 * in the LPU Link Layer Interrupt reg (0x6e2210, 0x7e2210)
	 */
	set	TLU_OE_DUP_LLI_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .tlu_oe_no_dup_group_s
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_P(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_DUP_LLI_P)
	LOG_ILU_EPKT_P(r_fire_e_rpt, r_fire_leaf_address, r_tmp1, r_tmp2)
	/*
	 * bits 9 through 4 are the dup bits, yet we do not send any
	 * info to the guest, so just clear them all.  fma has recieved all
	 * the info
	 */ 
	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT(r_fire_e_rpt,	\
				r_fire_leaf_address, r_tmp1, r_tmp2)
	CLEAR_TLU_OE_DUP_LLI_GROUP_P(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty
	

.tlu_oe_no_dup_group_s:
	PRINT("HV:tlu_oe_no_dup_group_s\r\n")
	set	TLU_OE_NO_DUP_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .tlu_trans_other_event_s
	nop
	set	TLU_OE_NO_DUP_SVVS_RPT_MSK, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_NO_DUP_GROUP_P)
	LOG_TLU_OE_NO_DUP_EPKT_P_S(r_fire_e_rpt, r_fire_leaf_address,	\
							 r_tmp1, r_tmp2)
	CLEAR_TLU_OE_NO_DUP_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty
1:
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address,	\
				r_tmp1, r_tmp2, TLU_OE_NO_DUP_GROUP_P)
	CLEAR_TLU_OE_NO_DUP_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty
	.poplocals

.tlu_trans_other_event_s:
	PRINT("HV:tlu_trans_other_event_s\r\n")
	set	TLU_OE_TRANS_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .tlu_oe_link_interrupt_group_s
	nop
	set	TLU_OE_TRANS_SVVS_RPT_MSK, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
					r_tmp2, TLU_OE_TRANS_GROUP_P)
	LOG_TLU_OE_TRANS_GROUP_EPKT_S(r_fire_e_rpt, r_fire_leaf_address,\
							 r_tmp1, r_tmp2)
	CLEAR_TLU_OE_TRANS_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							 r_tmp1, r_tmp2)
	ba,a	pcie_err_mondo_ereport
	.empty

1:
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address,	\
							 r_tmp1, r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address,	\
				 r_tmp1, r_tmp2, TLU_OE_TRANS_GROUP_P)
	CLEAR_TLU_OE_TRANS_GROUP_S(r_fire_e_rpt, r_fire_leaf_address,	\
							 r_tmp1, r_tmp2)
	ba,a	clear_pcie_err_fire_interrupt
	.empty
	.poplocals

.tlu_oe_link_interrupt_group_s:
	PRINT("HV:tlu_oe_link_interrupt_group_s\r\n")
	set	TLU_OE_LINK_INTERRUPT_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .tlu_receive_other_event_s
	nop
	LOG_TLU_OE_GROUP_REGS(r_fire_e_rpt, r_fire_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_TLU_OE_INTR_STATUS_S(r_fire_e_rpt, r_fire_leaf_address,	\
			r_tmp1,	r_tmp2, TLU_OE_LINK_INTERRUPT_GROUP_P)

	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, r_tmp2
	set	TLU_OE_LINK_INTERRUPT_GROUP_P, r_tmp1
	sllx	r_tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp1
	stx	r_tmp1, [r_fire_leaf_address + r_tmp2]
	
	ba,a	clear_pcie_err_fire_interrupt
	.empty


pcie_err_mondo_ereport:
	PCIE_ERR_MONDO_EREPORT(r_fire_cookie, r_fire_e_rpt, r_tmp1, r_tmp2)
clear_pcie_err_fire_interrupt:
	CLEAR_FIRE_INTERRUPT(r_fire_cookie, PCIE_ERR_INO, r_tmp1)
	GENERATE_FMA_REPORT; /* never returns */

jbc_err_mondo_ereport:
	JBC_ERR_MONDO_EREPORT(r_fire_cookie, r_fire_e_rpt, r_tmp1, r_tmp2)
clear_jbc_err_fire_interrupt:
	CLEAR_FIRE_INTERRUPT(r_fire_cookie, JBC_ERR_INO, r_tmp1)
	GENERATE_FMA_REPORT; /* never returns */

.pec_oe_processing_nothingtodo:
	PRINT("HV:pec_oe_processing_nothingtodo\r\n")
	ba,a	clear_pcie_err_fire_interrupt
	.empty

	SET_SIZE(error_mondo_62)

	!! %g1 = Fire Cookie
	!! %g2 = Mondo DATA0
	!! %g3 = IGN
	!! %g4 = INO
	ENTRY_NP(error_mondo_63)
	PRINT("HV:mondo 63\r\n")
	mov	%g2, %g7 ! save DATA0 for err handle setup
	!!
	!! Generate a unique error handle
	!! enters with:
	!! %g1 loaded with fire cookie
	!! %g2 data0, overwritten with r_fire_e_rpt
	!! %g3 IGN
	!! %g4 INO
	!! %g5 scratch
	!! %g6 scratch
	!! %g7 data0
	!!
	!! returns with:
	!! %g1 r_fire_cookie
	!! %g2 pointing to r_fire_e_rpt
	!!
	GEN_ERR_HNDL_SETUP_ERPTS(%g1, %g2, %g3, %g4, %g5, %g6, %g7)

#define	r_jbc_intr_status	%g3
#define	r_jbus_base_addr	%g4

	ldx	[r_fire_cookie + FIRE_COOKIE_JBUS], r_jbus_base_addr
	set	FIRE_JBC_ERROR_LOG_EN_REG, r_tmp1	/* 0x471000 */
	ldx	[r_jbus_base_addr + r_tmp1], r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_ERR_LOG_ENABLE]

	/* 0x471020 */
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1S_ALIAS, r_tmp1
	ldx	[r_jbus_base_addr + r_tmp1], r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_ERROR_STATUS_SET_REG]

	set	FIRE_JBC_ERROR_INT_EN_REG, r_tmp1	/* 0x471008 */
	ldx	[r_jbus_base_addr + r_tmp1], r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_ENABLE]

	set	FIRE_JBC_ENABLED_ERROR_STATUS_REG, r_tmp1 /* 0x471010 */
	ldx	[r_jbus_base_addr + r_tmp1],  r_jbc_intr_status
	/* %g3 has the individual interrupt bits */

	setx	JBC_FATAL_GROUP, r_tmp2, r_tmp1
	btst    r_jbc_intr_status, r_tmp1
	bnz	%xcc, fatal_errors
	.empty

	set	FIRE_JBC_INTERRUPT_STATUS_REG, r_tmp1		/* 0x471808 */
	add	r_jbus_base_addr, r_tmp1, r_tmp1
	ldx	[r_tmp1], r_tmp2

	set	DMCINT_BIT, r_tmp1	! Mask for dmcint type errors
	btst	r_tmp2, r_tmp1
	bnz	%xcc, dmcint_errors
	stx	r_tmp1, [r_fire_e_rpt + PCIERPT_JBC_CORE_AND_BLOCK_ERR_STATUS]

	set	JBCINT_BIT, r_tmp1
	btst	r_tmp2, r_tmp1
	bnz	%xcc, jbcint_errors
	stx	r_tmp1, [r_fire_e_rpt + PCIERPT_JBC_CORE_AND_BLOCK_ERR_STATUS]

	set	MERGE_BIT, r_tmp1
	btst	r_tmp2, r_tmp1
	bnz	%xcc, merge_errors
	stx	r_tmp1, [r_fire_e_rpt + PCIERPT_JBC_CORE_AND_BLOCK_ERR_STATUS]

	set	CSR_BIT, r_tmp1
	btst	r_tmp2, r_tmp1
	bnz	%xcc, csr_errors
	stx	r_tmp1, [r_fire_e_rpt + PCIERPT_JBC_CORE_AND_BLOCK_ERR_STATUS]

	! Should not get here
	PRINT("HV:Fall through on top level mondo 63 processing\r\n")
	ba,a	clear_jbc_err_fire_interrupt
	.empty

fatal_errors:
	PRINT("HV:fatal_errors:\r\n")
	set	JBC_FATAL_LOGING_GROUP, r_tmp1
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_CORE_AND_BLOCK_ERR_STATUS]
	LOG_JBUS_FATAL_REGS(r_fire_e_rpt, r_jbus_base_addr, r_tmp1, r_tmp2)
	CLEAR_JBUS_FATAL_REGS(r_fire_e_rpt, r_jbus_base_addr, r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty
1:
	CLEAR_JBUS_FATAL_REGS(r_fire_e_rpt, r_jbus_base_addr, r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty
	.poplocals

dmcint_errors:
.dmcint.odc_p:
	PRINT("HV:.dmcint.odc_p:\r\n")
	PRINT("HV:setting reg to bits DMCINT_ODC_GROUP_P:0x")
	setx	DMCINT_ODC_GROUP_P, r_tmp2, r_tmp1
	PRINTX(r_tmp1)
	PRINT("\r\n")
	PRINT("HV:r_jbc_intr_status:0x")
	PRINTX(r_jbc_intr_status)
	PRINT("\r\n")
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc, .dmcint.idc_p
	and	r_tmp1, r_jbc_intr_status, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	LOG_DMCINT_ODC_REGS(r_fire_e_rpt, r_jbus_base_addr,	\
						r_tmp1, r_tmp2)
	CLEAR_DMCINT_ODC_P(r_fire_e_rpt, r_jbus_base_addr,	\
						r_tmp1, r_tmp2)
	set	DMCINT_ODC_SVVS_RPT_MSK, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	.pushlocals
	bnz	%xcc, 1f
	nop
	ba,a	clear_jbc_err_fire_interrupt
	.empty
1:
	.poplocals
	LOG_DMCINT_ODC_EPKT_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	jbc_err_mondo_ereport
	.empty	

.dmcint.idc_p:
	PRINT("HV:dmcint.idc_p:\r\n")
	set	DMCINT_IDC_GROUP_P, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc, .dmcint.idc_s
	and	r_jbc_intr_status, DMCINT_IDC_GROUP_P, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	LOG_DMCINT_IDC_REGS(r_fire_e_rpt, r_jbus_base_addr,	\
						r_tmp1, r_tmp2)
	CLEAR_DMCINT_IDC_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	/* no guest reports from this group */
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.dmcint.idc_s:
	PRINT("HV:dmcint.idc_s:\r\n")
	setx	DMCINT_IDC_GROUP_S, r_tmp2, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc, .dmcint.odc_s
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	CLEAR_DMCINT_IDC_S(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.dmcint.odc_s:
	PRINT("HV:dmcint.odc_s:\r\n")
	setx	DMCINT_ODC_GROUP_S, r_tmp2, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz,pn	%xcc, .dmcint_nothingtodo
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	CLEAR_DMCINT_ODC_S(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.dmcint_nothingtodo:
	PRINT("HV:dmcint_nothingtodo:\r\n")
	ba,a	clear_jbc_err_fire_interrupt
	.empty

jbcint_errors:
.jbcint_in_p:
	PRINT("HV:jbcint_in_p:\r\n")
	.pushlocals
	set	JBUSINT_IN_GROUP_P, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc, .jbcint_out_p
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	LOG_JBCINT_IN_REGS(r_fire_e_rpt, r_jbus_base_addr,	\
						r_tmp1, r_tmp2)
	CLEAR_JBCINT_IN_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	PRINT("HV:r_jbc_intr_status:0x")
	PRINTX(r_jbc_intr_status)
	PRINT("\r\n")
	set	JBUSINT_IN_SVVS_RPT_MSK, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bnz	%xcc,  1f
	nop
	PRINT("HV:no guest report for jbcint_in_p\r\n")
	ba,a	clear_jbc_err_fire_interrupt
	.empty
1:
	LOG_JBCINT_IN_EPKT_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	jbc_err_mondo_ereport
	.empty
	.poplocals

.jbcint_out_p:
	PRINT("HV:jbcint_out_p:\r\n")
	.pushlocals
	set	JBUSINT_OUT_GROUP_P, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc,	.jbcint_in_s
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	LOG_JBCINT_OUT_REGS(r_fire_e_rpt, r_jbus_base_addr,	\
						r_tmp1, r_tmp2)
	CLEAR_JBCINT_OUT_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	/* no guest report ever for this group */
	set	JBUSINT_OUT_SVVS_RPT_MSK, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bnz	%xcc,  1f
	nop
	ba,a	clear_jbc_err_fire_interrupt
	.empty
1:
	LOG_JBCINT_OUT_EPKT_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	jbc_err_mondo_ereport
	.empty
	.poplocals

.jbcint_in_s:
	PRINT("HV:jbcint_in_s:\r\n")
	setx	JBUSINT_IN_GROUP_S, r_tmp2, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc, .jbcint_out_s
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	CLEAR_JBCINT_IN_S(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.jbcint_out_s:
	PRINT("HV:jbcint_out_s:\r\n")
	setx	JBUSINT_OUT_GROUP_S, r_tmp2, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz,pn	%xcc, .jbcint_nothingtodo
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	CLEAR_JBCINT_OUT_S(r_fire_e_rpt, r_jbus_base_addr,	\
				 r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.jbcint_nothingtodo:
	PRINT("HV:jbcint_nothingtodo:\r\n")
	ba,a	clear_jbc_err_fire_interrupt
	.empty

merge_errors:
.merge_errors_p:
	PRINT("HV:merge_errors_p::\r\n")
	.pushlocals
	set	MERGE_GROUP_P, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc,	.merge_errors_s
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	LOG_MERGE_REGS(r_fire_e_rpt, r_jbus_base_addr, r_tmp1, r_tmp2)
	CLEAR_MERGE_P(r_fire_e_rpt, r_jbus_base_addr, r_jbc_intr_status,\
							 r_tmp1, r_tmp2)
	set	MERGE_SVVS_RPT_MSK, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bnz	%xcc, 1f
	nop
	ba,a	clear_jbc_err_fire_interrupt
	.empty
1:
	LOG_MERGE_ERROR_EPKT_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	jbc_err_mondo_ereport
	.empty
	.poplocals

.merge_errors_s:
	PRINT("HV:merge_errors_s:\r\n")
	setx	MERGE_GROUP_S, r_tmp2, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz,pn	%xcc,	.merge_errors_nothingtodo
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	CLEAR_MERGE_S(r_fire_e_rpt, r_jbus_base_addr, r_jbc_intr_status,\
							r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.merge_errors_nothingtodo:
	PRINT("HV:merge_errors_nothingtodo:\r\n")
	ba,a	clear_jbc_err_fire_interrupt
	.empty


csr_errors:
.csr_errors_p:
	PRINT("HV:csr_errors_p:\r\n")
	.pushlocals
	set	CSR_GROUP_P, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz	%xcc, .csr_errors_s
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	LOG_CSR_REGS(r_fire_e_rpt, r_jbus_base_addr, r_tmp1, r_tmp2)
	CLEAR_CSR_P(r_fire_e_rpt, r_jbus_base_addr, r_jbc_intr_status,	\
							 r_tmp1, r_tmp2)
	set	CSR_SVVS_RPT_MSK, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bnz	%xcc,  1f
	nop
	ba,a	clear_jbc_err_fire_interrupt
	.empty
1:
	LOG_CSR_ERRORS_P_EPKT_P(r_fire_e_rpt, r_jbus_base_addr,	\
				r_jbc_intr_status, r_tmp1, r_tmp2)
	ba,a	jbc_err_mondo_ereport
	.empty
	.poplocals

.csr_errors_s:
	PRINT("HV:csr_errors_s:\r\n")
	setx	CSR_GROUP_S, r_tmp2, r_tmp1
	btst	r_jbc_intr_status, r_tmp1
	bz,pn	%xcc, .csr_errors_nothingtodo
	.empty
	and	r_jbc_intr_status, r_tmp1, r_tmp2
	stx	r_tmp2, [r_fire_e_rpt + PCIERPT_JBC_INTR_STATUS]
	CLEAR_CSR_S(r_fire_e_rpt, r_jbus_base_addr, r_jbc_intr_status,	\
							 r_tmp1, r_tmp2)
	ba,a	clear_jbc_err_fire_interrupt
	.empty

.csr_errors_nothingtodo:
	PRINT("HV:csr_errors_nothingtodo:\r\n")
	ba,a	clear_jbc_err_fire_interrupt
	.empty

	SET_SIZE(error_mondo_63)


/*
 *	%g2 pointing to ereport buffer, i.e. r_fire_e_rpt
 *	so jbus is special, sometimes we need to send ereports
 *	to both leafs since we don't really know which leaf
 *	generated the error.  We do this here, by xor'ing bit
 *	7 of word 0 before we send it then call generate_guest_report
 */
	ENTRY_NP(generate_guest_report_special)

	/*
	 * this error code is completely unintelligible ...
	 * hopefully this register usage is OK but who can tell ???
	 *
	 * The PA has been inserted into the PCI error packet, now
	 * translate to a RA
	 */
	ldx	[r_fire_e_rpt + PCIERPT_ERROR_PADDR], r_tmp2
	RADDR_IS_IO_XCCNEG(r_tmp2, r_tmp1)
	bneg    %xcc, .generate_guest_report_special_ra2pa_done	! do nothing
        nop

	GUEST_STRUCT(r_tmp1)
	PA2RA_CONV(r_tmp1, r_tmp2, %g6, %g3, %g4)
	! %g6	RADDR
	stx	%g6, [r_fire_e_rpt + PCIERPT_ERROR_RADDR]

.generate_guest_report_special_ra2pa_done:

	/*
	 * Is other leaf on?
	 */
	PRINT("HV:Is other leaf is on?\r\n")
	ldx	[r_fire_e_rpt + PCIERPT_SYSINO], r_tmp1	! PCIERPT_SYSINO
	srlx	r_tmp1, FIRE_DEVINO_SHIFT, r_tmp1
	and	r_tmp1, FIRE_LEAF_DEVID_MASK, r_tmp1	! devid 0 or 1
	btog	1, r_tmp1				! make it other dev id
	ldx	[r_fire_cookie + FIRE_COOKIE_VIRTUAL_INTMAP],  r_tmp2
	ldub	[r_tmp2 + r_tmp1], r_tmp2
	brz	r_tmp2, generate_guest_report	! if off don't send a ereport
						! for other leaf
	nop
	PRINT("HV:other leaf is on!\r\n")
	CPU_PUSH(r_fire_cookie, r_tmp1, r_tmp2, %g6)
	CPU_PUSH(r_fire_e_rpt, r_tmp1, r_tmp2, %g6)
	add	r_fire_e_rpt, PCIERPT_SYSINO, %g1
	/*
	 * fixup mondo to report other leaf
	 */
	ldx	[%g1], %g3
	btog	0x40, %g3	! flip bit 7
	stx	%g3, [%g1]
	STRAND_PUSH(%g1, r_tmp1, r_tmp2)
	HVCALL(insert_device_mondo_p)
	STRAND_POP(%g1, r_tmp1)
	PRINT("HV:calling:generate_guest_report\r\n")

	/*
	 * fixup mondo to report current leaf
	 */
	ldx	[%g1], %g3
	btog	0x40, %g3	! flip bit 7
	stx	%g3, [%g1]

	CPU_POP(r_fire_e_rpt, r_tmp1, r_tmp2, %g6)
	CPU_POP(r_fire_cookie, r_tmp1, r_tmp2, %g6)

	PRINT("HV:Is this leaf on?\r\n")
	ldx	[r_fire_e_rpt + PCIERPT_SYSINO], r_tmp1	! PCIERPT_SYSINO
	srlx	r_tmp1, FIRE_DEVINO_SHIFT, r_tmp1
	and	r_tmp1, FIRE_LEAF_DEVID_MASK, r_tmp1	! devid 0 or 1
	ldx	[r_fire_cookie + FIRE_COOKIE_VIRTUAL_INTMAP],  r_tmp2
	ldub	[r_tmp2 + r_tmp1], r_tmp2
	brnz	r_tmp2, generate_guest_report	! It's on send it
	nop
	/*
	 * This one is off, but this one took the interrupt
	 * so we must clear the interrupt ourselves
	 */
	ba,a	clear_jbc_err_fire_interrupt
	.empty
	SET_SIZE(generate_guest_report_special)

/*
 *	%g2 pointing to ereport buffer, i.e. r_fire_e_rpt
 */
	ENTRY_NP(generate_guest_report)
	add	r_fire_e_rpt, PCIERPT_SYSINO, %g1
#ifdef DEBUG
	PRINT("HV:generate_guest_report\r\n")
	PRINT("\r\n")
	ldx	[%g1 + 0x00], %g3
	PRINT("HV:word0:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x08], %g3
	PRINT("HV:word1:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x10], %g3
	PRINT("HV:word2:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x18], %g3
	PRINT("HV:word3:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x20], %g3
	PRINT("HV:word4:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x28], %g3
	PRINT("HV:word5:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x30], %g3
	PRINT("HV:word6:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	ldx	[%g1 + 0x38], %g3
	PRINT("HV:word7:0x")
	PRINTX(%g3)
	PRINT("\r\n")
	PRINT("HV:calling:insert_device_mondo_p\r\n")
#endif
	STRAND_PUSH(r_fire_e_rpt, r_tmp1, r_tmp2)
	HVCALL(insert_device_mondo_p)
	STRAND_POP(r_fire_e_rpt, r_tmp1)
	mov	r_fire_e_rpt, %g1
	PRINT("HV:calling:generate_fma_report\r\n")
	/*
	 * %g1 r_fire_e_rpt
	 */
	ba,a	generate_fma_report
	  .empty
	SET_SIZE(generate_guest_report)
/*
 *	%g1 pointing to fire error buffer
 */
	ENTRY_NP(generate_fma_report)

	! set %g2 to point to unsent flag
	add	%g1, PCI_UNSENT_PKT, %g2

	! set %g1 to point to vbsc err report
	add	%g1, PCI_ERPT_U, %g1

	! set %g3 to contain the size of the buf
	mov	PCIERPT_SIZE - EPKTSIZE, %g3	

	HVCALL(send_diag_erpt)

	PRINT("HV:all done with fire error processing, fma report sent\r\n")
	retry
	SET_SIZE(generate_fma_report)

!!
!! fire_err_mondo_receive
!!
!! %g1 = Fire Cookie
!! %g2 = Mondo DATA0
!! %g3 = IGN
!! %g4 = INO
!!
	ENTRY_NP(fire_err_mondo_receive)
	/*
	 * is it mondo 62 or 63
	 */
	cmp	%g4, JBC_ERR_INO	! 63
	beq,pt  %xcc, error_mondo_63
	cmp	%g4, PCIE_ERR_INO	! 62
	beq,pt  %xcc, error_mondo_62
	nop
	ba	insert_device_mondo_r
	rd	%pc, %g7
	retry
	SET_SIZE(fire_err_mondo_receive)

!!
!! fire_err_intr_getvalid
!!
!! %g1 Fire Cookie Pointer
!! arg0 Virtual INO (%o0)
!! --
!! ret0 status (%o0)
!! ret1 intr valid state (%o1)
!!
	ENTRY_NP(fire_err_intr_getvalid)
	and	%o0, FIRE_DEVINO_MASK, %g2
	cmp	%g2, JBC_ERR_INO	! is it mondo 63
	mov	JBC_ERR_MONDO_OFFSET, %g4
	movne	%xcc, PCIE_ERR_MONDO_OFFSET, %g4
	srlx	%o0, FIRE_DEVINO_SHIFT, %g2
	and	%g2, FIRE_LEAF_DEVID_MASK, %g2	! devid 0 or 1
	ldx	[%g1 + FIRE_COOKIE_VIRTUAL_INTMAP], %g6
	add	%g6, %g4, %g6 ! JBC or PCIE offset
	ldub	[%g6 + %g2], %g6
	mov	INTR_DISABLED, %o1
	movrz	%g6, INTR_ENABLED, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_err_intr_getvalid)

!!
!! fire_err_intr_setvalid
!!
!! %g1 Fire Cookie Pointer
!! arg0 Virtual INO (%o0)
!! arg1 intr valid state (%o1) 1: Valid 0: Invalid
!! --
!! ret0 status (%o0)
!!

	ENTRY_NP(fire_err_intr_setvalid)
	mov	%o0, %g2
	mov	%o1, %g3
	HVCALL(_fire_err_intr_setvalid)

	! _fire_err_intr_setvalid doesn't have any failure cases
	! so it is safe to just return EOK
	HCALL_RET(EOK)
	SET_SIZE(fire_err_intr_setvalid)

!!
!! _fire_err_intr_setvalid
!! %g1  Fire Cookie Pointer
!! %g2 device ino
!! %g3 Valid/Invalid
!!
	ENTRY_NP(_fire_err_intr_setvalid)
	and	%g2, FIRE_DEVINO_MASK, %g5
	cmp	%g5, JBC_ERR_INO	! is it mondo 63
	mov	JBC_ERR_MONDO_OFFSET, %g4
	movne	%xcc, PCIE_ERR_MONDO_OFFSET, %g4
	ldx	[%g1 + FIRE_COOKIE_VIRTUAL_INTMAP], %g6
	srlx	%g2, FIRE_DEVINO_SHIFT, %g5
	and	%g5, FIRE_LEAF_DEVID_MASK, %g5	! devid 0 or 1
	add	%g6, %g4, %g6 	! virtual intmap + mondo offset
	stb	%g3, [%g6 + %g5]

	HVRET
	SET_SIZE(_fire_err_intr_setvalid)

!!
!! fire_err_intr_getstate
!!
!! %g1 Fire Cookie Pointer
!! arg0 Virtual INO (%o0)
!! --
!! ret0 status (%o0)
!! ret1 (%o1) 1: Pending / 0: Idle
!!
	ENTRY_NP(fire_err_intr_getstate)
	ba,a	fire_intr_getstate
	.empty
	SET_SIZE(fire_err_intr_getstate)

!!
!! fire_err_intr_setstate
!!
!! %g1 Fire Cookie Pointer
!! arg0 Virtual INO (%o0)
!! arg1 (%o1) 1: Pending / 0: Idle
!! --
!! ret0 status (%o0)
!!
	ENTRY_NP(fire_err_intr_setstate)
	ba,a	fire_intr_setstate
	.empty
	SET_SIZE(fire_err_intr_setstate)

!!
!! fire_err_intr_gettarget
!!
!! %g1 Fire Cookie Pointer
!! arg0 Virtual INO (%o0)
!! --
!! ret0 status (%o0)
!! ret1 cpuid (%o1)
!!
	ENTRY_NP(fire_err_intr_gettarget)
	ba,a	fire_intr_gettarget
	.empty
	SET_SIZE(fire_err_intr_gettarget)

!!
!! fire_err_intr_settarget
!!
!! %g1 Fire Cookie Pointer
!! arg0 Virtual INO (%o0)
!! arg1 cpuid (%o1)
!! --
!! ret0 status (%o0)
!!
	ENTRY_NP(fire_err_intr_settarget)
	ba,a	fire_intr_settarget
	.empty
	SET_SIZE(fire_err_intr_settarget)


!!
!! fire_err_intr_redistribution
!! %g1 - this cpu
!! %g2 - tgt cpu
!!
!! Generates each INO and calls the function that actually
!! does the work
!!
	ENTRY_NP(fire_err_intr_redistribution)
	CPU_PUSH(%g7, %g3, %g4, %g5)

	mov %g2, %g1
	CPU_PUSH(%g1, %g3, %g4, %g5)
	mov	FIRE_A_AID << FIRE_DEVINO_SHIFT, %g4
	or	%g4, JBC_ERR_INO, %g3
	HVCALL(_fire_err_intr_redistribution)

	CPU_POP(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g1, %g3, %g4, %g5)
	mov	FIRE_A_AID << FIRE_DEVINO_SHIFT, %g4
	or	%g4, PCIE_ERR_INO, %g3
	HVCALL(_fire_err_intr_redistribution)

	CPU_POP(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g1, %g3, %g4, %g5)
	mov	FIRE_B_AID << FIRE_DEVINO_SHIFT, %g4
	or	%g4, JBC_ERR_INO, %g3
	HVCALL(_fire_err_intr_redistribution)

	CPU_POP(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g1, %g3, %g4, %g5)
	mov	FIRE_B_AID << FIRE_DEVINO_SHIFT, %g4
	or	%g4, PCIE_ERR_INO, %g3
	HVCALL(_fire_err_intr_redistribution)
	CPU_POP(%g1, %g3, %g4, %g5)

	CPU_POP(%g7, %g3, %g4, %g5)
	HVRET
	SET_SIZE(fire_err_intr_redistribution)

	/*
	 * _fire_err_intr_redistribution
	 *
	 * %g1 - tgt cpu
	 * %g3 - INO
	 */
	ENTRY_NP(_fire_err_intr_redistribution)
	CPU_PUSH(%g7, %g4, %g5, %g6)
	CPU_PUSH(%g1, %g4, %g5, %g6)	! save tgt cpu
	CPU_PUSH(%g3, %g4, %g5, %g6)	! save INO

	GUEST_STRUCT(%g4)
	! get dev
	srlx	%g3, FIRE_DEVINO_SHIFT, %g6
	DEVINST2INDEX(%g4, %g6, %g6, %g5, ._fire_err_intr_redistribution_fail)
	DEVINST2COOKIE(%g4, %g6, %g1, %g5, ._fire_err_intr_redistribution_fail)

	and	%g3, FIRE_DEVINO_MASK, %g2

	!! %g1 = Fire Cookie
	!! %g2 = device ino
	HVCALL(_fire_intr_gettarget)
	!! %g3 phys cpuid for this ino

	STRAND_STRUCT(%g2)		/* FIXME: this ok ? */
	ldub	[%g2 + STRAND_ID], %g2

	!! %g2 this cpu (strand) id
	cmp	%g3, %g2
	bne	%xcc, ._fire_err_intr_redistribution_done
	nop

	! deal with virtual portion
	CPU_POP(%g2, %g4, %g6, %g7)
	mov	INTR_DISABLED, %g3
	!! %g1 = Fire cookie
	!! %g2 = vino
	!! %g3 = Disable
	HVCALL(_fire_err_intr_setvalid)

	! set new target
	and	%g2, FIRE_DEVINO_MASK, %g2
	CPU_POP(%g3, %g4, %g6, %g7)
	!! %g1 = Fire Cookie Ptr
	!! %g2 = device ino
	!! %g3 = Physical target CPU id
	HVCALL(_fire_intr_settarget)
	
	! clear state machine
	mov	INTR_IDLE, %g3
	!! %g1 = Fire cookie
	!! %g2 = device ino
	!! %g3 = Idle
	HVCALL(_fire_intr_setstate)

	ba,a	._fire_err_intr_redistribution_exit

._fire_err_intr_redistribution_done:
	CPU_POP(%g3, %g4, %g5, %g6)
	CPU_POP(%g1, %g3, %g4, %g5)
._fire_err_intr_redistribution_exit:
	CPU_POP(%g7, %g3, %g4, %g5)
	HVRET
._fire_err_intr_redistribution_fail:
	CPU_POP(%g3, %g4, %g5, %g6)
	CPU_POP(%g1, %g3, %g4, %g5)
	ba	hvabort
	rd	%pc, %g1

	SET_SIZE(_fire_err_intr_redistribution)
#endif /* CONFIG_FIRE */
