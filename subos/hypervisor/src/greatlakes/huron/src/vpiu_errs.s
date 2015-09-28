/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpiu_errs.s
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

	.ident	"@(#)vpiu_errs.s	1.2	07/05/15 SMI"

	.file	"vpci_errs.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <offsets.h>
#include <errs_common.h>
#include <debug.h>
#include <vpiu_errs.h>
#include <vcpu.h>
#include <abort.h>
#include <util.h>


#define	r_piu_cookie	%g1
#define	r_piu_e_rpt	%g2
#define	r_piu_leaf_address	%g4

#define	r_tmp1		%g5
#define	r_tmp2		%g7

#if defined(CONFIG_PIU)

#define	PIU_PRINT	PRINT
#define	PIU_PRINTX	PRINTX


#define	PIU_ERR_PRINT(s, piu, off, scr1, scr2)	 \
	PIU_PRINT(s)				;\
	set	off, scr1			;\
	ldx	[piu + PIU_COOKIE_PCIE], scr2	;\
	ldx	[scr1 + scr2], scr1		;\
	PIU_PRINTX(scr1)

	! %g1 = PIU Cookie
	! %g2 = Mondo DATA0
	! %g3 = IGN
	! %g4 = INO
	ENTRY_NP(error_mondo_62)
	PRINT("HV:PCIE Error mondo\r\n")

#if DEBUG
	PIU_ERR_PRINT("\r\n631800 = ", %g1, 0x31800, %g5, %g6)
	PIU_ERR_PRINT("\r\n631808 = ", %g1, 0x31808, %g5, %g6)
	PIU_PRINT("\r\n")
	ldx	[%g1 + PIU_COOKIE_PCIE], %g5
	set	0x31808, %g6
	ldx	[%g5 + %g6], %g6
	btst	1, %g6
	bz	1f		! No IMU Error
	nop
	PIU_ERR_PRINT("\r\n631000 = ", %g1, 0x31000, %g5, %g6)
	PIU_ERR_PRINT("\r\n631008 = ", %g1, 0x31008, %g5, %g6)
	PIU_ERR_PRINT("\r\n631010 = ", %g1, 0x31010, %g5, %g6)
	PIU_ERR_PRINT("\r\n631018 = ", %g1, 0x31018, %g5, %g6)
	PIU_ERR_PRINT("\r\n631020 = ", %g1, 0x31020, %g5, %g6)
	PIU_ERR_PRINT("\r\n631028 = ", %g1, 0x31028, %g5, %g6)
	PIU_ERR_PRINT("\r\n631030 = ", %g1, 0x31030, %g5, %g6)
	PIU_ERR_PRINT("\r\n631038 = ", %g1, 0x31038, %g5, %g6)
	PIU_PRINT("\r\n")
1:
	ldx	[%g1 + PIU_COOKIE_PCIE], %g5
	set	0x31808, %g6
	ldx	[%g5 + %g6], %g6
	btst	2, %g6
	bz	1f		! No MMU Error
	nop

	PIU_ERR_PRINT("\r\n641000 = ", %g1, 0x41000, %g5, %g6)
	PIU_ERR_PRINT("\r\n641008 = ", %g1, 0x41008, %g5, %g6)
	PIU_ERR_PRINT("\r\n641010 = ", %g1, 0x41010, %g5, %g6)
	PIU_ERR_PRINT("\r\n641018 = ", %g1, 0x41018, %g5, %g6)
	PIU_ERR_PRINT("\r\n641020 = ", %g1, 0x41020, %g5, %g6)
	PIU_ERR_PRINT("\r\n641028 = ", %g1, 0x41028, %g5, %g6)
	PIU_ERR_PRINT("\r\n641030 = ", %g1, 0x41030, %g5, %g6)
	PIU_PRINT("\r\n")
1:
#endif

	mov	%g2, %g7 ! save DATA0 for err handle setup

	!
	! Generate a unique error handle
	! enters with:
	! %g1 loaded with piu cookie
	! %g2 data0, overwritten with r_piu_e_rpt
	! %g3 IGN
	! %g4 INO
	! %g5 scratch
	! %g6 scratch
	! %g7 data0
	!
	! returns with:
	! %g1 r_piu_cookie
	! %g2 pointing to r_piu_e_rpt
	!
	GEN_ERR_HNDL_SETUP_ERPTS(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	ldx	[r_piu_cookie + PIU_COOKIE_PCIE], %g4
	! use alias r_piu_leaf_address for %g4 now
	!
	set	PCI_E_DMU_CORE_BLK_ERR_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	and	r_tmp1, IMU_BIT, r_tmp2
	brnz,a	r_tmp2, imu_block_processing
	  stx	r_tmp2, [r_piu_e_rpt + PCIERPT_DMU_CORE_AND_BLOCK_ERR_STATUS]

        and     r_tmp1, MMU_BIT, r_tmp2
        brnz,a  r_tmp2, mmu_block_processing
          stx   r_tmp2, [r_piu_e_rpt + PCIERPT_DMU_CORE_AND_BLOCK_ERR_STATUS]
        ! should not get here
        PRINT("HV:mondo 62 fall through to retry\r\n")
        ba,a    clear_dmu_err_piu_interrupt
        .empty


imu_block_processing:
	PRINT("HV:imu_block_processing\r\n")
	set	PCI_E_IMU_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1

.imu_eq_not_en_group_p:
	PRINT("HV:.imu_eq_not_en_group_p\r\n")
	btst	IMU_EQ_NOT_EN_GROUP_P, r_tmp1
	bz	%xcc, .imu_eq_over_group_p
	and	r_tmp1, IMU_EQ_NOT_EN_GROUP_P, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_SCS_ERROR_LOG_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_P(r_piu_e_rpt,			\
				r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_NOT_EN_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.imu_eq_over_group_p:
	PRINT("HV:imu_eq_over_group_p\r\n")
	btst	IMU_EQ_OVER_GROUP_P, r_tmp1
	bz	%xcc, .imu_msi_mes_group_p
	and	r_tmp1, IMU_EQ_OVER_GROUP_P, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_EQS_ERROR_LOG_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_IMU_EQ_OVER_GROUP_EPKT_P(r_piu_e_rpt,			\
				r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_OVER_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.imu_msi_mes_group_p:
	PRINT("HV:imu_msi_mes_group_p\r\n")
	btst	IMU_MSI_MES_GROUP_P, r_tmp1
	bz	%xcc, .imu_eq_not_en_group_s
	and	r_tmp1, IMU_MSI_MES_GROUP_P, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_RDS_ERROR_LOG_REG(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_IMU_MSI_MES_GROUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_IMU_MSI_MES_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.imu_eq_not_en_group_s:
	PRINT("HV:imu_eq_not_en_group_s\r\n")
	set	IMU_EQ_NOT_EN_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .imu_eq_over_group_s
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_S(r_piu_e_rpt,			\
				r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_NOT_EN_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.imu_eq_over_group_s:
	PRINT("HV:imu_eq_over_group_s\r\n")
	set	IMU_EQ_OVER_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .imu_msi_mes_group_s
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_IMU_EQ_OVER_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_IMU_EQ_OVER_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.imu_msi_mes_group_s:
	PRINT("HV:imu_msi_mes_group_s\r\n")
	set	IMU_MSI_MES_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .imu_block_processing_nothing_to_do
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_IMU_ENABLED_ERR_STATUS]
	LOG_DMC_IMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_IMU_MSI_MES_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_IMU_MSI_MES_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.imu_block_processing_nothing_to_do:
	PRINT("HV:imu_block_processing_nothing_to_do\r\n")
	! we should not get here
	ba,a	clear_dmu_err_piu_interrupt
	.empty

	PRINT("HV:mondo 62 fall through to retry\r\n")
	CLEAR_PIU_INTERRUPT(r_piu_cookie, DMU_INTERNAL_INT, r_tmp1)
	GENERATE_FMA_REPORT;

mmu_block_processing:
	PRINT("HV:mmu_block_processing\r\n")
	set	PCI_E_MMU_INT_STAT_ADDR, r_tmp1
	ldx	[r_piu_leaf_address + r_tmp1], r_tmp1

.mmu_err_group_p:
#ifdef DEBUG
	PRINT("HV:mmu_err_group_p\r\n")
	PRINT("HV:PCI_E_MMU_INT_STAT_ADDR:0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif
	set	MMU_ERR_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .mmu_err_group_s
	and	r_tmp1, r_tmp2, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_MMU_INTR_STATUS]
	LOG_DMC_MMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_MMU_TRANS_FAULT_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_MMU_ERR_GROUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_MMU_ERR_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.mmu_err_group_s:
	PRINT("HV:mmu_err_group_s\r\n")
	set	MMU_ERR_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .mmu_block_processing_nothing_to_do
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_MMU_INTR_STATUS]
	LOG_DMC_MMU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_MMU_ERR_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_MMU_ERR_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	dmu_err_mondo_ereport
	.empty

.mmu_block_processing_nothing_to_do:
	PRINT("HV:mmu_block_processing_nothing_to_do\r\n")
	! we should not get here
	ba,a	clear_dmu_err_piu_interrupt
	.empty

	SET_SIZE(error_mondo_62)

	! %g1 = PIU Cookie
	! %g2 = Mondo DATA0
	! %g3 = IGN
	! %g4 = INO
	ENTRY_NP(error_mondo_63)
	PRINT("HV:mondo 63\r\n")

	mov	%g2, %g7 ! save DATA0 for err handle setup

	!
	! Generate a unique error handle
	! enters with:
	! %g1 loaded with piu cookie
	! %g2 data0, overwritten with r_piu_e_rpt
	! %g3 IGN
	! %g4 INO
	! %g5 scratch
	! %g6 scratch
	! %g7 data0
	!
	! returns with:
	! %g1 r_piu_cookie
	! %g2 pointing to r_piu_e_rpt
	!
	GEN_ERR_HNDL_SETUP_ERPTS(%g1, %g2, %g3, %g4, %g5, %g6, %g7)
	ldx	[r_piu_cookie + PIU_COOKIE_PCIE], %g4
	! use alias r_piu_leaf_address for %g4 now
	!
	
	set	PCI_E_PEU_INT_ENB_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	stx	r_tmp1, [r_piu_e_rpt + PCIERPT_PEU_CORE_AND_BLOCK_INTR_ENABLE]

	/* PEU Core and Block Interrupt Status Register (0x651808) */
	set	PCI_E_PEU_INT_STAT_ADDR, r_tmp2

	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	and	r_tmp1, ILU_BIT, r_tmp2
	brnz,a	r_tmp2, .peu_ilu_processing
	  stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_CORE_AND_BLOCK_INTR_STATUS]
	and	r_tmp1, UE_BIT, r_tmp2
	brnz,a	r_tmp2, .peu_ue_processing
	  stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_CORE_AND_BLOCK_INTR_STATUS]
	and	r_tmp1, CE_BIT, r_tmp2
	brnz,a	r_tmp2, .peu_ce_processing
	  stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_CORE_AND_BLOCK_INTR_STATUS]
	and	r_tmp1, OE_BIT, r_tmp2
	brnz,a,pt r_tmp2, .peu_oe_processing
	  stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_CORE_AND_BLOCK_INTR_STATUS]
	ba,a	clear_peu_err_piu_interrupt
	.empty

.peu_ue_processing:
/*
 * All PEU Uncorrectable errors log to the same group and use the Uncorrectable
 * Header1 and Header2 Log registers to capture data.  Completion Timeout
 * Primary Error also logs to the PEU Transmit Other Event Header1 and Header2
 * Log Registers.  If UR_P is set, Hypervisor must also see if PP_P is set, as this
 * indicates a Ingress MsgD request (posted) with poisend data error.  If only
 * UR_P is set, then a Ingress MWr request (posted) with poisend data error
 * occured.
 */
.peu_uce_recv_group_p:
        PRINT("HV:peu_uce_recv_group_p\r\n")
        set     PCI_E_PEU_UE_INT_STAT_ADDR, r_tmp2
        ldx     [r_piu_leaf_address + r_tmp2], r_tmp1
        set     PEU_UE_RECV_GROUP_P, r_tmp2
        and     r_tmp2, r_tmp1, r_tmp2
        brz     r_tmp2, .peu_uce_trans_group_p
        nop
        stx     r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
        LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
        LOG_PEU_UE_RCV_HDR_REGS(r_piu_e_rpt, r_piu_leaf_address,      \
                                                        r_tmp1, r_tmp2)
        LOG_PEU_UE_RECV_GROUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,\
                                                        r_tmp1, r_tmp2)
        CLEAR_PEU_UE_RECV_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,    \
                                                        r_tmp1, r_tmp2)

        ba,a    peu_err_mondo_ereport
        .empty

.peu_uce_trans_group_p:
	PRINT("HV:peu_uce_trans_group_p\r\n")
	set	PEU_UE_TRANS_GROUP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_uce_dlp_p
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	PRINT("r_tmp1 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_PEU_UE_TRANS_HDR_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_PEU_UE_TRANS_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_UE_TRANS_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_uce_dlp_p:
	PRINT("HV:peu_uce_dlp_p\r\n")
	set	PEU_DLP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_uce_fcp_p
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	PRINT("HV:r_tmp1 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_PEU_UE_DLP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_UE_DLP_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_uce_fcp_p:
	PRINT("HV:peu_uce_fcp_p\r\n")
	set	PEU_FCP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_uce_tlu_dlp_s
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_PEU_UE_FCP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_UE_FCP_P(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, 	\
								r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_uce_tlu_dlp_s:
	PRINT("HV:peu_uce_tlu_dlp_s\r\n")
	set	PEU_DLP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_uce_recv_group_s
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_PEU_UE_DLP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_UE_DLP_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty


.peu_uce_recv_group_s:
	PRINT("HV:peu_uce_recv_group_s\r\n")
	set	PEU_UE_RECV_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_uce_trans_group_s
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_PEU_UE_RECV_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,\
							r_tmp1, r_tmp2)
	CLEAR_PEU_UE_RECV_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_uce_trans_group_s:
	PRINT("HV:peu_uce_trans_group_s\r\n")
	set	PEU_UE_TRANS_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz,pn  r_tmp2, .peu_uce_fcp_s
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	LOG_PEU_UE_TRANS_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_PEU_UE_TRANS_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_uce_fcp_s:
	PRINT("HV:peu_uce_fcp_s\r\n")
	set	PEU_FCP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_uce_nothingtodo
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_UE_STATUS]
	LOG_PEU_UE_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_PEU_UE_FCP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_UE_FCP_S(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, 	\
								r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_uce_nothingtodo:
	PRINT("HV:peu_uce_nothingtodo\r\n")
	PRINT("HV:r_tmp1 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	ba,a	clear_peu_err_piu_interrupt
	.empty

.peu_ce_processing:
.pec_ce_primary:
	PRINT("HV:pec_ce_processing\r\n")
	set	PCI_E_PEU_CE_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:PCI_E_PEU_CE_INT_STAT_ADDR = 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	set	PEU_CE_GROUP_P, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz	r_tmp2, .peu_ce_secondary
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_CE_INTERRUPT_STATUS]
	LOG_PEU_CE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_CE_GROUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_PEU_CE_GROUP_P(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_ce_secondary:
	PRINT("HV:peu_ce_secondary\r\n")
	set	PEU_CE_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	and	r_tmp2, r_tmp1, r_tmp2
	brz,pn  r_tmp2, .peu_ce_nothingtodo
	nop
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_PEU_CE_INTERRUPT_STATUS]
	LOG_PEU_CE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_CE_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_PEU_CE_GROUP_S(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,	\
								r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_ce_nothingtodo:
#ifdef DEBUG
	PRINT("HV:peu_ce_nothingtodo\r\n")
	set	PCI_E_PEU_CE_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:PCI_E_PEU_CE_INT_STAT_ADDR:0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif
	ba,a	clear_peu_err_piu_interrupt
	.empty

.peu_oe_processing:
/*
 * Only MFC, CTO, UR, MRC, CRS, WUC, and RUC log information to any
 * registers. All other capture no data(exception LIN, see CXPL Error
 * Processing)
 *
 * MFC, UR, CTO, MRC, and CRS log to the ....
 * PEU Recieve Other Event Header1 and Header2 Log Registers.
 *
 *
 * MFC, CTO, WUC, RUC, and CRS log to the ....
 * PEU Transmit Other Event Header1 and Header2 Log Registers.
 */
	PRINT("HV:peu_oe_processing\r\n")
.peu_receive_other_event_p:
	PRINT("HV:peu_receive_other_event_p\r\n")
	/*
	 * Also logs trans regs
	 */
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:contents = 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	set	PEU_OE_RECEIVE_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .peu_oe_link_interrupt_group_p
	nop
	/*
	 * Special, this set of errors also records some in the transmit
	 * regs
	 */
	set	 PEU_OE_TRANS_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	nop
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1,	r_tmp2, PEU_OE_RECEIVE_GROUP_P)
	LOG_PEU_OE_TRANS_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	2f
	  .empty
1:
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1,	r_tmp2, PEU_OE_RECEIVE_GROUP_P)
2:
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	set	PEU_OE_RECV_SVVS_RPT_MSK, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, 3f
	nop
	LOG_PEU_OE_RECV_GROUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_PEU_OE_RECV_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	CLEAR_PEU_OE_RECV_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty
3:
	LOG_PEU_OE_RECV_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_OE_RECV_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_peu_err_piu_interrupt
	.empty
	.poplocals

.peu_oe_link_interrupt_group_p:
	PRINT("HV:.peu_oe_link_interrupt_group_p\r\n")
	PRINT("HV:r_tmp1 = 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
	set	PEU_OE_LINK_INTERRUPT_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .peu_trans_other_event_p
	nop
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
			r_tmp1,	r_tmp2, PEU_OE_LINK_INTERRUPT_GROUP_P)

	set	PCI_E_PEU_CXPL_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:PCI_E_PEU_CXPL_INT_STAT_ADDR\r\n")
	PRINTX(r_tmp1)
	PRINT("\r\n")

	set	CXPL_EVT_RCV_EN_LB, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_en_lb
	nop
	set	CXPL_EVT_RCV_DIS_LINK, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_dis_link
	nop
	set	CXPL_EVT_RCV_HOT_RST, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_hot_rst
	nop
	set	CXPL_EVT_RCV_EIDLE_EXIT, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_eidle_exit
	nop
	set	CXPL_EVT_RCV_EIDLE, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_eidle
	nop
	set	CXPL_EVT_RCV_TS1, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_ts1
	nop
	set	CXPL_EVT_RCV_TS2, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_rcv_ts2
	nop
	set	CXPL_EVT_SEND_SKP_B2B, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_evt_send_skp_b2b
	nop
	set	CXPL_ERR_OUTSTANDING_SKIP, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_outstanding_skip
	nop
	set	CXPL_ERR_ELASTIC_FIFO_UNDRFLW, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_elastic_fifo_undrflw
	nop
	set	CXPL_ERR_ELSTC_FIFO_OVRFLW, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_elstc_fifo_ovrflw
	nop
	set	CXPL_ERR_ALIGN, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_align
	nop
	set	CXPL_ERR_KCHAR_DLLP_TLP, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_kchar_dllp_tlp
	nop
	set	CXPL_ERR_ILL_END_POS, r_tmp2
	and	r_tmp1, r_tmp2, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_ill_end_pos
	nop
	and	r_tmp1, CXPL_ERR_SYNC, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_sync
	nop
	and	r_tmp1, CXPL_ERR_END_NO_STP_SDP, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_end_no_stp_sdp
	nop
	and	r_tmp1, CXPL_ERR_SDP_NO_END, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_sdp_no_end
	nop
	and	r_tmp1, CXPL_ERR_STP_NO_END_EDB, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_stp_no_end_edb
	nop
	and	r_tmp1, CXPL_ERR_ILL_PAD_POS, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_ill_pad_pos
	nop
	and	r_tmp1, CXPL_ERR_MULTI_SDP, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_multi_sdp
	nop
	and	r_tmp1, CXPL_ERR_MULTI_STP, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_multi_stp
	nop
	and	r_tmp1, CXPL_ERR_ILL_SDP_POS, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_ill_sdp_pos
	nop
	and	r_tmp1, CXPL_ERR_ILL_STP_POS, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_ill_stp_pos
	nop
	and	r_tmp1, CXPL_ERR_UNSUP_DLLP, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_unsup_dllp
	nop
	and	r_tmp1, CXPL_ERR_SRC_TLP, r_tmp2
	brnz,pn r_tmp2, .cxpl_err_src_tlp
	nop
	and	r_tmp1, CXPL_ERR_SDS_LOS, r_tmp2
	brnz,pt r_tmp2, .cxpl_err_sds_los
	nop

.nothing_to_do_peu_oe_link_interrupt_group_p:
	PRINT("HV:.nothing_to_do_tlu_oe_link_interrupt_group_p\r\n")
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_en_lb:
	PRINT("HV:.cxpl_evt_rcv_en_lb\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_EN_LB, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_EN_LB, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_dis_link:
	PRINT("HV:.cxpl_evt_rcv_dis_link\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_DIS_LINK, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_DIS_LINK, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_hot_rst:
	PRINT("HV:.cxpl_evt_rcv_hot_rst\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_HOT_RST, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_HOT_RST, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_eidle_exit:
	PRINT("HV:.cxpl_evt_rcv_eidle_exit\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_EIDLE_EXIT, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_EIDLE_EXIT, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_eidle:
	PRINT("HV:.cxpl_evt_rcv_eidle\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_EIDLE, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_EIDLE, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_ts1:
	PRINT("HV:.cxpl_evt_rcv_ts1\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_TS1, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_TS1, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_rcv_ts2:
	PRINT("HV:.cxpl_evt_rcv_ts2\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_TS2, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_RCV_TS2, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_evt_send_skp_b2b:
	PRINT("HV:.cxpl_evt_send_skp_b2b\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_SEND_SKP_B2B, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_EVT_SEND_SKP_B2B, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_outstanding_skip:
	PRINT("HV:.cxpl_err_outstanding_skip\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_OUTSTANDING_SKIP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_OUTSTANDING_SKIP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_elastic_fifo_undrflw:
	PRINT("HV:.cxpl_err_elastic_fifo_undrflw\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ELASTIC_FIFO_UNDRFLW, r_tmp1, 	\
								r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ELASTIC_FIFO_UNDRFLW, r_tmp1,	\
								r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_elstc_fifo_ovrflw:
	PRINT("HV:.cxpl_err_elstc_fifo_ovrflw\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ELSTC_FIFO_OVRFLW, r_tmp1, 	\
								r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ELSTC_FIFO_OVRFLW, r_tmp1, 	\
								r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_align:
	PRINT("HV:.cxpl_err_align\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ALIGN, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ALIGN, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_kchar_dllp_tlp:
	PRINT("HV:.cxpl_err_kchar_dllp_tlp\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_KCHAR_DLLP_TLP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_KCHAR_DLLP_TLP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_ill_end_pos:
	PRINT("HV:.cxpl_err_ill_end_pos\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_END_POS, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_END_POS, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_sync:
	PRINT("HV:.cxpl_err_sync\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_SYNC, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_SYNC, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_end_no_stp_sdp:
	PRINT("HV:.cxpl_err_end_no_stp_sdp\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_END_NO_STP_SDP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_END_NO_STP_SDP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_sdp_no_end:
	PRINT("HV:.cxpl_err_sdp_no_end\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_SDP_NO_END, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_SDP_NO_END, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_stp_no_end_edb:
	PRINT("HV:.cxpl_err_stp_no_end_edb\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_STP_NO_END_EDB, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_STP_NO_END_EDB, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_ill_pad_pos:
	PRINT("HV:.cxpl_err_ill_pad_pos\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_PAD_POS, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_PAD_POS, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_multi_sdp:
	PRINT("HV:.cxpl_err_multi_sdp\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_MULTI_SDP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_MULTI_SDP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_multi_stp:
	PRINT("HV:.cxpl_err_multi_stp\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_MULTI_STP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_MULTI_STP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_ill_sdp_pos:
	PRINT("HV:.cxpl_err_ill_sdp_pos\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_SDP_POS, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_SDP_POS, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_ill_stp_pos:
	PRINT("HV:.cxpl_err_ill_stp_pos\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_STP_POS, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_ILL_STP_POS, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_unsup_dllp:
	PRINT("HV:.cxpl_err_unsup_dllp\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_UNSUP_DLLP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
				CXPL_ERR_UNSUP_DLLP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_src_tlp:
	PRINT("HV:.cxpl_err_src_tlp\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
					CXPL_ERR_SRC_TLP, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
					CXPL_ERR_SRC_TLP, r_tmp1, r_tmp2)
	ba,a	.all_done_peu_oe_link_interrupt_group_p
	  .empty

.cxpl_err_sds_los:
	PRINT("HV:.cxpl_err_sds_los\r\n")
	LOG_PCIERPT_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
					CXPL_ERR_SDS_LOS, r_tmp1, r_tmp2)
	CLEAR_CXPL_INTR_STATUS(r_piu_e_rpt, r_piu_leaf_address, 	\
					CXPL_ERR_SDS_LOS, r_tmp1, r_tmp2)


.all_done_peu_oe_link_interrupt_group_p:
	PRINT("HV:all_done_peu_oe_link_interrupt_group_p\r\n")
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, r_tmp2
	set	PEU_OE_LINK_INTERRUPT_GROUP_P, r_tmp1
	stx	r_tmp1, [r_piu_leaf_address + r_tmp2]

#ifdef	DEBUG
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	PRINT("HV:PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR 0x")
	PRINTX(r_tmp1)
	PRINT("\r\n")
#endif
	ba,a	clear_peu_err_piu_interrupt
	.empty

.peu_trans_other_event_p:
	PRINT("HV:peu_trans_other_event_p\r\n")
	/*
	 * Bits 22:21, 17, 16, and 15
	 * this test must happen after the recieve other event test
	 * as both the transmit and recieve groups have overlap and
	 * post info to both trans and receive regs.  Since we tested
	 * the overlap in the receive we won't need to test it here
	 * in theory the only bit we should see is the one that only
	 * posts to the trans reg
	 */
	set	PEU_OE_TRANS_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .peu_oe_no_dup_group_p
	nop
	set	PEU_OE_TRANS_SVVS_RPT_MSK, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_TRANS_GROUP_P)
	LOG_PEU_OE_TRANS_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_PEU_OE_TRANS_GROUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,\
							r_tmp1, r_tmp2)
	CLEAR_PEU_OE_TRANS_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty
1:
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_TRANS_GROUP_P)
	LOG_PEU_OE_TRANS_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_OE_TRANS_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_peu_err_piu_interrupt
	.empty
	.poplocals

.peu_oe_no_dup_group_p:
	PRINT("HV:peu_oe_no_dup_group_p\r\n")
	set	PEU_OE_NO_DUP_GROUP_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .peu_oe_dup_lli_p
	nop
	set	PEU_OE_NO_DUP_SVVS_RPT_MSK, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_NO_DUP_GROUP_P)
	LOG_PEU_OE_NO_DUP_EPKT_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_OE_NO_DUP_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty
1:
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_NO_DUP_GROUP_P)
	CLEAR_PEU_OE_NO_DUP_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_peu_err_piu_interrupt
	.empty
	.poplocals

.peu_oe_dup_lli_p:
	PRINT("HV:peu_oe_dup_lli_p\r\n")
	set	PEU_OE_DUP_LLI_P, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .peu_oe_no_dup_group_s
	nop
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_OE_INTR_STATUS_P(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_DUP_LLI_P)
	LOG_ILU_EPKT_P(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_PEU_OE_DUP_LLI_GROUP_P(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_oe_no_dup_group_s:
	PRINT("HV:peu_oe_no_dup_group_s\r\n")
	set	PEU_OE_NO_DUP_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .peu_trans_other_event_s
	nop
	set	PEU_OE_NO_DUP_SVVS_RPT_MSK, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_PEU_OE_INTR_STATUS_S(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_NO_DUP_GROUP_P)
	LOG_PEU_OE_NO_DUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							 r_tmp1, r_tmp2)
	CLEAR_PEU_OE_NO_DUP_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty
1:
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	LOG_PEU_OE_INTR_STATUS_S(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_NO_DUP_GROUP_P)
	CLEAR_PEU_OE_NO_DUP_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_peu_err_piu_interrupt
	.empty
	.poplocals

.peu_trans_other_event_s:
	PRINT("HV:peu_trans_other_event_s\r\n")
	set	PEU_OE_TRANS_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .peu_receive_other_event_s
	nop
	set	PEU_OE_TRANS_SVVS_RPT_MSK, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	.pushlocals
	bz	%xcc, 1f
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								 r_tmp2)
	LOG_PEU_OE_INTR_STATUS_S(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
					r_tmp2, PEU_OE_TRANS_GROUP_P)
	LOG_PEU_OE_TRANS_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,\
							 r_tmp1, r_tmp2)
	CLEAR_PEU_OE_TRANS_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							 r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

1:
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address,	\
							 r_tmp1, r_tmp2)
	LOG_PEU_OE_INTR_STATUS_S(r_piu_e_rpt, r_piu_leaf_address,	\
				 r_tmp1, r_tmp2, PEU_OE_TRANS_GROUP_P)
	CLEAR_PEU_OE_TRANS_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							 r_tmp1, r_tmp2)
	ba,a	clear_peu_err_piu_interrupt
	.empty
	.poplocals

.peu_receive_other_event_s:
	PRINT("HV:peu_receive_other_event_s\r\n")
	set	PEU_OE_RECEIVE_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, .peu_oe_dup_lli_s
	nop
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_OE_INTR_STATUS_S(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1,	r_tmp2, PEU_OE_RECEIVE_GROUP_P)
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	set	PEU_OE_RECV_SVVS_RPT_MSK, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz	%xcc, 1f
	nop
	LOG_PEU_OE_RECV_GROUP_EPKT_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	CLEAR_PEU_OE_RECV_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1,	r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty
1:
	CLEAR_PEU_OE_RECV_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	clear_peu_err_piu_interrupt
	.empty

.peu_oe_dup_lli_s:
	PRINT("HV:peu_oe_dup_lli_s\r\n")
	set	PEU_OE_DUP_LLI_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .peu_oe_processing_nothingtodo
	nop
	LOG_PEU_OE_GROUP_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1,\
								r_tmp2)
	LOG_PEU_OE_INTR_STATUS_S(r_piu_e_rpt, r_piu_leaf_address,	\
				r_tmp1, r_tmp2, PEU_OE_DUP_LLI_P)
	LOG_ILU_EPKT_S(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_PEU_OE_DUP_LLI_GROUP_S(r_piu_e_rpt, r_piu_leaf_address,	\
							r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.peu_ilu_processing:
.ilu_interrupt_status_p:
	PRINT("HV:ilu_interrupt_status_p\r\n")
	set	PCI_E_ILU_INT_STAT_ADDR, r_tmp2
	ldx	[r_piu_leaf_address + r_tmp2], r_tmp1
	btst	ILU_GROUP_P, r_tmp1
	bz	%xcc, .ilu_interrupt_status_s
	and	r_tmp1, ILU_GROUP_P, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_ILU_INTR_STATUS]
	LOG_ILU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_ILU_EPKT_P(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_ILU_GROUP_P(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty


.ilu_interrupt_status_s:
	PRINT("HV:ilu_interrupt_status_s\r\n")
	set	ILU_GROUP_P, r_tmp2
	sllx	r_tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, r_tmp2
	btst	r_tmp2, r_tmp1
	bz,pn	%xcc, .ilu_nothing_todo
	and	r_tmp2, r_tmp1, r_tmp2
	stx	r_tmp2, [r_piu_e_rpt + PCIERPT_ILU_INTR_STATUS]
	LOG_ILU_REGS(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	LOG_ILU_EPKT_S(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	CLEAR_ILU_GROUP_S(r_piu_e_rpt, r_piu_leaf_address, r_tmp1, r_tmp2)
	ba,a	peu_err_mondo_ereport
	.empty

.ilu_nothing_todo:
	PRINT("HV:ilu_nothing_todo\r\n")
	ba,a	clear_peu_err_piu_interrupt
	.empty

	SET_SIZE(error_mondo_63)

dmu_err_mondo_ereport:
	DMU_ERR_MONDO_EREPORT(r_piu_cookie, r_piu_e_rpt, r_tmp1, r_tmp2)
clear_dmu_err_piu_interrupt:
	CLEAR_PIU_INTERRUPT(r_piu_cookie, DMU_INTERNAL_INT, r_tmp1)
	GENERATE_FMA_REPORT; /* never returns */


peu_err_mondo_ereport:
	PEU_ERR_MONDO_EREPORT(r_piu_cookie, r_piu_e_rpt, r_tmp1, r_tmp2)
clear_peu_err_piu_interrupt:
	CLEAR_PIU_INTERRUPT(r_piu_cookie, PEU_INTERNAL_INT, r_tmp1)
	GENERATE_FMA_REPORT; /* never returns */

.peu_oe_processing_nothingtodo:
	PRINT("HV:peu_oe_processing_nothingtodo\r\n")
	ba,a	clear_peu_err_piu_interrupt
	.empty

/*
 *	%g2 pointing to ereport buffer, i.e. r_piu_e_rpt
 */
	ENTRY_NP(generate_guest_report)
	add	r_piu_e_rpt, PCIERPT_SYSINO, %g1
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
	STRAND_PUSH(%g1, %g2, %g3)
	ba	insert_device_mondo_p
	rd	%pc, %g7
	STRAND_POP(%g1, %g2)
	PRINT("HV:calling:generate_fma_report\r\n")
	/*
	 * %g1 already points to the r_piu_e_rpt, no fixup, so don't use macro
	 */
	ba,a	generate_fma_report
	  .empty

	SET_SIZE(generate_guest_report)
/*
 *	%g1 pointing to piu error buffer
 */
	ENTRY_NP(generate_fma_report)

	! set %g2 to point to unsent flag
	add	%g1, PCI_UNSENT_PKT, %g2

	! set %g1 to point to vbsc err report
	add	%g1, PCI_ERPT_U, %g1

	! set %g3 to contain the size of the buf
	mov	PCIERPT_SIZE - EPKTSIZE, %g3

	HVCALL(send_diag_erpt)

	PRINT("HV:all done with piu error processing, fma report sent\r\n")
	retry
	SET_SIZE(generate_fma_report)

! piu_err_mondo_receive
!
! %g1 = PIU Cookie
! %g2 = Mondo DATA0
! %g3 = IGN
! %g4 = INO
!
	ENTRY_NP(piu_err_mondo_receive)
	/*
	 * is it mondo 62 or 63
	 */
	cmp	%g4, PEU_INTERNAL_INT	! 63
	beq,pt  %xcc, error_mondo_63
	cmp	%g4, DMU_INTERNAL_INT	! 62
	beq,pt  %xcc, error_mondo_62
	nop
	ba	insert_device_mondo_r
	rd	%pc, %g7
	retry
	SET_SIZE(piu_err_mondo_receive)

!
! piu_err_intr_getvalid
!
! %g1 PIU Cookie Pointer
! arg0 Virtual INO (%o0)
! --
! ret0 status (%o0)
! ret1 intr valid state (%o1)
!
	ENTRY_NP(piu_err_intr_getvalid)
	ba,a	piu_intr_getvalid
	.empty
	SET_SIZE(piu_err_intr_getvalid)

!
! piu_err_intr_setvalid
!
! %g1 PIU Cookie Pointer
! arg0 Virtual INO (%o0)
! arg1 intr valid state (%o1) 1: Valid 0: Invalid
! --
! ret0 status (%o0)
!

	ENTRY_NP(piu_err_intr_setvalid)
	mov	%o0, %g2
	mov	%o1, %g3
	HVCALL(_piu_err_intr_setvalid)

	! _piu_err_intr_setvalid doesn't have any failure cases
	! so it is safe to just return EOK
	HCALL_RET(EOK)
	SET_SIZE(piu_err_intr_setvalid)

!
! _piu_err_intr_setvalid
! %g1 PIU Cookie Pointer
! %g2 device ino
! %g3 Valid/Invalid
!
	ENTRY_NP(_piu_err_intr_setvalid)
	and	%g2, PIU_DEVINO_MASK, %g5
	cmp	%g5, PEU_INTERNAL_INT	! is it mondo 63
	mov	DMU_ERR_MONDO_OFFSET, %g4
	movne	%xcc, PEU_ERR_MONDO_OFFSET, %g4
	ldx	[%g1 + PIU_COOKIE_VIRTUAL_INTMAP], %g6
	add	%g6, %g4, %g6 	! virtual intmap + mondo offset
	stb	%g3, [%g6]

	HVRET
	SET_SIZE(_piu_err_intr_setvalid)

!
! piu_err_intr_getstate
!
! %g1 PIU Cookie Pointer
! arg0 Virtual INO (%o0)
! --
! ret0 status (%o0)
! ret1 (%o1) 1: Pending / 0: Idle
!
	ENTRY_NP(piu_err_intr_getstate)
	ba,a	piu_intr_getstate
	.empty
	SET_SIZE(piu_err_intr_getstate)

!
! piu_err_intr_setstate
!
! %g1 PIU Cookie Pointer
! arg0 Virtual INO (%o0)
! arg1 (%o1) 1: Pending / 0: Idle
! --
! ret0 status (%o0)
!
	ENTRY_NP(piu_err_intr_setstate)
	ba,a	piu_intr_setstate
	.empty
	SET_SIZE(piu_err_intr_setstate)

!
! piu_err_intr_gettarget
!
! %g1 PIU Cookie Pointer
! arg0 Virtual INO (%o0)
! --
! ret0 status (%o0)
! ret1 cpuid (%o1)
!
	ENTRY_NP(piu_err_intr_gettarget)
	ba,a	piu_intr_gettarget
	.empty
	SET_SIZE(piu_err_intr_gettarget)

!
! piu_err_intr_settarget
!
! %g1 PIU Cookie Pointer
! arg0 Virtual INO (%o0)
! arg1 cpuid (%o1)
! --
! ret0 status (%o0)
!
	ENTRY_NP(piu_err_intr_settarget)
	ba,a	piu_intr_settarget
	.empty
	SET_SIZE(piu_err_intr_settarget)


!
! piu_err_intr_redistribution
! %g1 - this cpu
! %g2 - tgt cpu
!
! Generates each INO and calls the function that actually
! does the work
!
	ENTRY_NP(piu_err_intr_redistribution)
	CPU_PUSH(%g7, %g3, %g4, %g5)

	mov %g2, %g1
	CPU_PUSH(%g1, %g3, %g4, %g5)
	mov	PIU_AID << PIU_DEVINO_SHIFT, %g4
	or	%g4, DMU_INTERNAL_INT, %g3
	HVCALL(_piu_err_intr_redistribution)

	CPU_POP(%g1, %g3, %g4, %g5)
	CPU_PUSH(%g1, %g3, %g4, %g5)
	mov	PIU_AID << PIU_DEVINO_SHIFT, %g4
	or	%g4, PEU_INTERNAL_INT, %g3
	HVCALL(_piu_err_intr_redistribution)

	CPU_POP(%g7, %g3, %g4, %g5)
	HVRET
	SET_SIZE(piu_err_intr_redistribution)

	/*
	 * _piu_err_intr_redistribution
	 *
	 * %g1 - tgt cpu
	 * %g3 - INO
	 */
	ENTRY_NP(_piu_err_intr_redistribution)
	CPU_PUSH(%g7, %g4, %g5, %g6)
	CPU_PUSH(%g1, %g4, %g5, %g6)	! save tgt cpu
	CPU_PUSH(%g3, %g4, %g5, %g6)	! save INO

	GUEST_STRUCT(%g4)
	! get dev
	srlx	%g3, PIU_DEVINO_SHIFT, %g6
	DEVINST2INDEX(%g4, %g6, %g6, %g5, ._piu_err_intr_redistribution_fail)
	DEVINST2COOKIE(%g4, %g6, %g1, %g5, ._piu_err_intr_redistribution_fail)

	and	%g3, PIU_DEVINO_MASK, %g2

	! %g1 = PIU Cookie
	! %g2 = device ino
	HVCALL(_piu_intr_gettarget)
	! %g3 phys cpuid for this ino

	STRAND_STRUCT(%g4)
	ldub	[%g4 + STRAND_ID], %g2
	! %g2 this cpu id
	cmp	%g3, %g2
	bne	%xcc, ._piu_err_intr_redistribution_done
	nop

	! deal with virtual portion
	CPU_POP(%g2, %g4, %g6, %g7)
	mov	INTR_DISABLED, %g3
	! %g1 = PIU cookie
	! %g2 = vino
	! %g3 = Disable
	HVCALL(_piu_err_intr_setvalid)

	! set new target
	and	%g2, PIU_DEVINO_MASK, %g2
	CPU_POP(%g3, %g4, %g6, %g7)
	! %g1 = PIU Cookie Ptr
	! %g2 = device ino
	! %g3 = Physical target CPU id
	HVCALL(_piu_intr_settarget)

	! clear state machine
	mov	INTR_IDLE, %g3
	! %g1 = PIU cookie
	! %g2 = device ino
	! %g3 = Idle
	HVCALL(_piu_intr_setstate)

	ba,a	._piu_err_intr_redistribution_exit

._piu_err_intr_redistribution_done:
	CPU_POP(%g3, %g4, %g5, %g6)
	CPU_POP(%g1, %g3, %g4, %g5)
._piu_err_intr_redistribution_exit:
	CPU_POP(%g7, %g3, %g4, %g5)
	HVRET
._piu_err_intr_redistribution_fail:
	CPU_POP(%g3, %g4, %g5, %g6)
	CPU_POP(%g1, %g3, %g4, %g5)
	ba	hvabort
	rd	%pc, %g1

	SET_SIZE(_piu_err_intr_redistribution)
#endif /* CONFIG_PIU */
