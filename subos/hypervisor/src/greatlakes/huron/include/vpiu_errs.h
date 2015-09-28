/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpiu_errs.h
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

#ifndef _NIAGARA_VPIU_ERRS_H
#define	_NIAGARA_VPIU_ERRS_H

#pragma ident	"@(#)vpiu_errs.h	1.6	07/07/30 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Macro to generate unique error handle
 * and load some of the diag ereport and sun4v erpt
 * entries that are common to mondo 0x62 and 0x63.
 * %g1 - piu cookie
 * %g2 - r_piu_e_rpt
 * %g3 - IGN
 * %g4 - INO
 * %g5 - scratch
 * %g6 - scratch
 * %g7 - data0
 */

/* BEGIN CSTYLED */
#define	GEN_ERR_HNDL_SETUP_ERPTS(PIU_COOKIE, PIU_rpt, IGN, INO, scr1,	\
							scr2, DATA0)	\
	.pushlocals							;\
	set	PIU_COOKIE_DMU_ERPT, scr1				;\
	set	DMU_INTERNAL_INT, scr2					;\
	cmp	scr2, INO						;\
	beq,a,pt  %xcc, 1f						;\
	  set	PIU_COOKIE_PEU_ERPT, scr1				;\
1:									;\
	add	PIU_COOKIE, scr1, PIU_rpt				;\
	GEN_SEQ_NUMBER(scr1, scr2);					;\
	/* store the error handle in the error report */		;\
	stx	scr1, [PIU_rpt + PCIERPT_EHDL] /* store ehdlin erpt */	;\
	stx	scr1, [PIU_rpt + PCIERPT_SUN4V_EHDL]			;\
	stx	DATA0, [PIU_rpt + PCIERPT_SYSINO]			;\
	st	INO, [PIU_rpt + PCIERPT_MONDO_NUM]			;\
	st	IGN, [PIU_rpt + PCIERPT_AGENTID]			;\
	/* save the TOD/STICK count	*/				;\
	ROOT_STRUCT(scr1)						;\
	ldx    [scr1 + CONFIG_TOD], scr1				;\
	brnz,a,pn	scr1, 1f					;\
	  ldx	[scr1], scr1			/* aborted if no TOD */	;\
1:	rd	STICK, scr2				/* stick */	;\
	stx	scr1, [PIU_rpt + PCIERPT_FPGA_TOD]			;\
	stx	scr2, [PIU_rpt + PCIERPT_STICK]				;\
	stx	scr2, [PIU_rpt + PCIERPT_SUN4V_STICK] 			;\
	rdhpr	%hver, scr1			/* read cpu version */	;\
	stx	scr1, [PIU_rpt + PCIERPT_CPUVER]			;\
	set	ERPT_TYPE_VPCI, scr2					;\
	stx	scr2, [PIU_rpt + PCIERPT_REPORT_TYPE_62]		;\
	.poplocals							;\

#define	CLEAR_PIU_INTERRUPT(PIU_COOKIE, MONDO, reg1)			\
	ldx	[PIU_COOKIE + PIU_COOKIE_INTCLR], reg1			;\
	stx	%g0, [reg1 + (MONDO<<3)]

#define	GENERATE_FMA_REPORT						\
	mov	r_piu_e_rpt, %g1					;\
	ba,a	generate_fma_report					;\
	  .empty


#define	PEU_ERR_MONDO_OFFSET		8
#define	DMU_ERR_MONDO_OFFSET		0

/* mondo 63 */
#define	PEU_ERR_MONDO_EREPORT(PIU_COOKIE, PIU_rpt, reg1, reg2)		\
	ldx	[PIU_COOKIE + PIU_COOKIE_VIRTUAL_INTMAP],  reg2		;\
	add	reg2, PEU_ERR_MONDO_OFFSET, reg2			;\
	ldub	[reg2], reg1						;\
	brnz	reg1, generate_guest_report	/* yes, send a ereport*/;\
	nop

/* mondo 62 */
#define	DMU_ERR_MONDO_EREPORT(PIU_COOKIE, PIU_rpt, reg1, reg2)		\
	ldx	[PIU_COOKIE + PIU_COOKIE_VIRTUAL_INTMAP],  reg2		;\
	add	reg2, DMU_ERR_MONDO_OFFSET, reg2			;\
	ldub	[reg2], reg1						;\
	brnz	reg1, generate_guest_report	/* yes, send a ereport*/;\
	nop

/* DESC.BLOCK bits 31:28 */
#define	HOSTBUS		(1LL << 28)
#define	MMU		(2LL << 28)
#define	INTR		(3LL << 28)
#define	PCI		(4LL << 28)
#define	BLK_UNKOWN	(0xeLL << 28)

/* HOSTBUS.op */
#define	PIO		(1LL << 24)
#define	DMA		(2LL << 24)
#define	OP_UNKNOWN	(0xeLL << 24)

/* MMU.op */
#define	TRANSLATION	(1LL << 24)
#define	BYPASS		(2LL << 24)
#define	TABLEWALK	(3LL << 24)

/* INTR.op */
#define	MSI32		(1LL << 24)
#define	MSI64		(2LL << 24)
#define	MSIQ		(3LL << 24)
#define	PCIEMSG		(4LL << 24)
#define	INT_OP_UNKNOWN	(0xeLL << 24)

/* phase */
#define	ADDR		(1LL << 20)
#define	PDATA		(2LL << 20)
#define	PHASE_UNKNOWN	(0xeLL << 20)
#define	PHASE_IRRELEVANT	(0xfLL << 20)

/* conditions */
#define	ILL		(1LL << 16)
#define	UNMAP		(2LL << 16)
#define	INT		(3LL << 16)
#define	UE		(4LL << 16)
#define	PROT		(5LL << 16)
#define	INV		(6LL << 16)
#define	OV		(5LL << 16)
#define	TO		(5LL << 16)
#define	COND_UNKNOWN	(0xeLL << 16)
#define	COND_IRRELEVENT	(0xfLL << 16)

/* directions */
#define	READ		(1LL << 12)
#define	WRITE		(2LL << 12)
#define	RDRW		(3LL << 12)
#define	INGRESS		(4LL << 12)
#define	EGRESS		(5LL << 12)
#define	LINK		(6LL << 12)
#define	DIR_UNKNOWN	(0xeLL << 12)
#define	DIR_IRRELEVANT	(0xfLL << 12)

/* flags */
#define	SIZE		(1LL << 0) /* size of the memory region affected */
#define	P		(1LL << 0) /* PCI Status Register */
#define	M		(1LL << 1) /* address field contains memory addr (RA) */
#define	E		(1LL << 1) /* PCIe Status Register */
#define	D		(1LL << 2) /* address field is a DMA virtual address */
#define	U		(1LL << 2) /* UE Status reg */
#define	RST		(1LL << 3) /* restartable */
#define	C		(1LL << 3) /* reserved(note: CE Status Register */
#define	H		(1LL << 4) /* contain PCIE headers or HDR1 */
#define	I		(1LL << 5) /* HDR2 */
#define	R		(1LL << 6) /* Root error status reg */
#define	S		(1LL << 7) /* error source reg */
#define	Z		(1LL << 8) /* error requires clearing before re-arm */
#define STOP		(1LL << 11) /* HV detects that error info is lost, ask guest to panic */


/* PCI Express epkt bits */
/* UE bits */
#define	TRAINING_ERROR		(1LL <<  0)
#define	DATA_LINK_ERROR		(1LL <<  4)
#define	POISONED_TLP		(1LL << 12)
#define	FLOW_CONTROL_ERROR	(1LL << 13)
#define	COMPLETION_TIMEOUT	(1LL << 14)
#define	COMPLETER_ABORT		(1LL << 15)
#define	UNEXPECTED_COMPLETION	(1LL << 16)
#define	RECEIVER_OVERFLOW	(1LL << 17)
#define	MALFORMED_TLP		(1LL << 18)
#define	ECRC_ERROR		(1LL << 19)
#define	UNSUPPORTED_REQUEST	(1LL << 20)

/* CE bits */
#define	RECEIVER_ERROR		(1LL <<  0)
#define	BAD_TLP			(1LL <<  6)
#define	BAD_DLLP		(1LL <<  7)
#define	REPLAY_NUM_ROLLOVER	(1LL <<  8)
#define	REPLAY_TIMER_TIMEOUT	(1LL << 12)

/* UE/CE bits */
#define	IS			(1LL <<  3)	/* Interrupt Status */
#define	MDP			(1LL <<  8)	/* Master Data Parity Error */
#define	ST			(1LL << 11)	/* Signaled Target Abort */
#define	RT			(1LL << 12)	/* Received Target Abort */
#define	RM			(1LL << 13)	/* Received Master Abort */
#define	SS			(1LL << 14)	/* Signaled System Error */
#define	DP			(1LL << 15)	/* Detected Parity Error */

/*
 * test bits for the IMU Interrupt Status Register
 * (0x631010)
 */

#define	IMU_SPARE_1_S		(1LL << 43)
#define	IMU_SPARE_0_S		(1LL << 42)
#define	IMU_EQ_OVER_S		(1LL << 41)
#define	IMU_EQ_NOT_EN_S		(1LL << 40)
#define	IMU_MSI_MAL_ERR_S	(1LL << 39)
#define	IMU_MSI_PAR_ERR_S	(1LL << 38)
#define	IMU_PMEACK_MES_NOT_EN_S	(1LL << 37)
#define	IMU_PMPME_MES_NOT_EN_S	(1LL << 36)
#define	IMU_FATAL_MES_NOT_EN_S	(1LL << 35)
#define	IMU_NONFATAL_MES_NOT_EN_S	(1LL << 34)
#define	IMU_COR_MES_NOT_EN_S	(1LL << 33)
#define	IMU_MSI_NOT_EN_S	(1LL << 32)
#define	IMU_SPARE_1_P		(1LL << 11)
#define	IMU_SPARE_0_P		(1LL << 10)
#define	IMU_EQ_OVER_P		(1LL <<  9)
#define	IMU_EQ_NOT_EN_P		(1LL <<  8)
#define	IMU_MSI_MAL_ERR_P	(1LL <<  7)
#define	IMU_MSI_PAR_ERR_P	(1LL <<  6)
#define	IMU_PMEACK_MES_NOT_EN_P	(1LL <<  5)
#define	IMU_PMPME_MES_NOT_EN_P	(1LL <<  4)
#define	IMU_FATAL_MES_NOT_EN_P	(1LL <<  3)
#define	IMU_NONFATAL_MES_NOT_EN_P	(1LL <<  2)
#define	IMU_COR_MES_NOT_EN_P	(1LL <<  1)
#define	IMU_MSI_NOT_EN_P	(1LL <<  0)

/* test bits for the MMUInterrupt Status Register (0x00641010) */
#define	MMU_SUN4V_KEY_ERR_S	(1LL << 52)
#define	MMU_VA_ADJ_UF_S		(1LL << 51)
#define	MMU_VA_OOR_S		(1LL << 50)
#define	MMU_IOTSBDESC_DPE_S	(1LL << 49)
#define	MMU_IOTSBDESC_INV_S	(1LL << 48)
#define	MMU_TBW_DPE_S		(1LL << 47)
#define	MMU_TBW_ERR_S		(1LL << 46)
#define	MMU_TBW_UDE_S		(1LL << 45)
#define	MMU_TBW_DME_S		(1LL << 44)
#define	MMU_SPARE3_S		(1LL << 43)
#define	MMU_SPARE2_S		(1LL << 42)
#define	MMU_TTC_CAE_S		(1LL << 41)
#define	MMU_TTC_DPE_S		(1LL << 40)
#define	MMU_TTE_PRT_S		(1LL << 39)
#define	MMU_TTEINV_S		(1LL << 38)
#define	MMU_TRN_OOR_S		(1LL << 37)
#define	MMU_TRN_ERR_S		(1LL << 36)
#define	MMU_SPARE1_S		(1LL << 35)
#define	MMU_INV_PG_SZ_S		(1LL << 34)
#define	MMU_BYP_OOR_S		(1LL << 33)
#define	MMU_BYP_ERR_S		(1LL << 32)
#define	MMU_SUN4V_KEY_ERR_P	(1LL << 20)
#define	MMU_VA_ADJ_UF_P		(1LL << 19)
#define	MMU_VA_OOR_P		(1LL << 18)
#define	MMU_IOTSBDESC_DPE_P	(1LL << 17)
#define	MMU_IOTSBDESC_INV_P	(1LL << 16)
#define	MMU_TBW_DPE_P		(1LL << 15)
#define	MMU_TBW_ERR_P		(1LL << 14)
#define	MMU_TBW_UDE_P		(1LL << 13)
#define	MMU_TBW_DME_P		(1LL << 12)
#define	MMU_SPARE3_P		(1LL << 11)
#define	MMU_SPARE2_P		(1LL << 10)
#define	MMU_TTC_CAE_P		(1LL <<  9)
#define	MMU_TTC_DPE_P		(1LL <<  8)
#define	MMU_TTE_PRT_P		(1LL <<  7)
#define	MMU_TTE_INV_P		(1LL <<  6)
#define	MMU_TRN_OOR_P		(1LL <<  5)
#define	MMU_TRN_ERR_P		(1LL <<  4)
#define	MMU_SPARE1_P		(1LL <<  3)
#define	MMU_INV_PG_SZ_P		(1LL <<  2)
#define	MMU_BYP_OOR_P		(1LL <<  1)
#define	MMU_BYP_ERR_P		(1LL <<  0)

/* ILU Interrupt Status Register (0x00651010, 0x00751010) */
#define	ILU_SPARE3_S		(1LL << 39)
#define	ILU_SPARE2_S		(1LL << 38)
#define	ILU_SPARE1_S		(1LL << 37)
#define	ILU_IHB_PE_S		(1LL << 36)
#define	ILU_SPARE3_P		(1LL <<  7)
#define	ILU_SPARE2_P		(1LL <<  6)
#define	ILU_SPARE1_P		(1LL <<  5)
#define	ILU_IHB_PE_P		(1LL <<  4)

/* DMU Core and Block Error Status Register (0x00631808 / 0x0) */
#define	MMU_BIT			(1LL <<  1)
#define	IMU_BIT			(1LL <<  0)

/* PEU Core and Block Interrupt Status Register (0x00651808 / 0x0) */
#define	ILU_BIT			(1LL <<  3)
#define	UE_BIT			(1LL <<  2)
#define CE_BIT			(1LL <<  1)
#define	OE_BIT			(1LL <<  0)

/* PEU Uncorrectable Error Status Clear Register (0x00691018, 0x00791018) */
#define	PEU_UR_S		(1LL << 52)
#define	PEU_MFP_S		(1LL << 50)
#define	PEU_ROF_S		(1LL << 49)
#define	PEU_UC_S		(1LL << 48)
#define	PEU_SPARE1_S		(1LL << 47)
#define	PEU_CTO_S		(1LL << 46)
#define	PEU_FCP_S		(1LL << 45)
#define	PEU_PP_S		(1LL << 44)
#define	PEU_DLP_S		(1LL << 36)
#define	PEU_SPARE0_S		(1LL << 32)
#define	PEU_UR_P		(1LL << 20)
#define	PEU_MFP_P		(1LL << 18)
#define	PEU_ROF_P		(1LL << 17)
#define	PEU_UC_P		(1LL << 16)
#define	PEU_SPARE1_P		(1LL << 15)
#define	PEU_CTO_P		(1LL << 14)
#define	PEU_FCP_P		(1LL << 13)
#define	PEU_PP_P		(1LL << 12)
#define	PEU_DLP_P		(1LL <<  4)
#define	PEU_SPARE0_P		(1LL <<  0)

/* PEU Correctable Error Status Reg (0x6a1018, 0x7a1018) */
#define	PEU_CE_RTO_S		(1LL << 44)
#define	PEU_CE_RNR_S		(1LL << 40)
#define	PEU_CE_BDP_S		(1LL << 39)
#define	PEU_CE_BTP_S		(1LL << 38)
#define	PEU_CE_RE_S		(1LL << 32)
#define	PEU_CE_RTO_P		(1LL << 12)
#define	PEU_CE_RNR_P		(1LL <<  8)
#define	PEU_CE_BDP_P		(1LL <<  7)
#define	PEU_CE_BTP_P		(1LL <<  6)
#define	PEU_CE_RE_P		(1LL <<  0)

/* PEU Other Events Status Register (0x681010, 0x781010) */
#define	PEU_O_SPARE_S		(1LL << 55)
#define	PEU_O_MFC_S		(1LL << 54)
#define	PEU_O_CTO_S		(1LL << 53)
#define	PEU_O_NFP_S		(1LL << 52)
#define	PEU_O_LWC_S		(1LL << 51)
#define	PEU_O_MRC_S		(1LL << 50)
#define	PEU_O_WUC_S		(1LL << 49)
#define	PEU_O_RUC_S		(1LL << 48)
#define	PEU_O_CRS_S		(1LL << 47)
#define	PEU_O_IIP_S		(1LL << 46)
#define	PEU_O_EDP_S		(1LL << 45)
#define	PEU_O_EHP_S		(1LL << 44)
#define	PEU_O_LRS_S		(1LL << 42)
#define	PEU_O_LDN_S		(1LL << 41)
#define	PEU_O_LUP_S		(1LL << 40)
#define	PEU_O_LPU_S		(3LL << 38)
#define	PEU_O_ERU_S		(1LL << 37)
#define	PEU_O_ERO_S		(1LL << 36)
#define	PEU_O_EMP_S		(1LL << 35)
#define	PEU_O_EPE_S		(1LL << 34)
#define	PEU_O_ERP_S		(1LL << 33)
#define	PEU_O_EIP_S		(1LL << 32)
#define	PEU_O_SPARE_P		(1LL << 23)
#define	PEU_O_MFC_P		(1LL << 22)
#define	PEU_O_CTO_P		(1LL << 21)
#define	PEU_O_NFP_P		(1LL << 20)
#define	PEU_O_LWC_P 		(1LL << 19)
#define	PEU_O_MRC_P		(1LL << 18)
#define	PEU_O_WUC_P		(1LL << 17)
#define	PEU_O_RUC_P		(1LL << 16)
#define	PEU_O_CRS_P		(1LL << 15)
#define	PEU_O_IIP_P		(1LL << 14)
#define	PEU_O_EDP_P		(1LL << 13)
#define	PEU_O_EHP_P		(1LL << 12)
#define	PEU_O_LIN		(1LL << 11)
#define	PEU_O_LRS_P		(1LL << 10)
#define	PEU_O_LDN_P		(1LL <<  9)
#define	PEU_O_LUP_P		(1LL <<  8)
#define	PEU_O_LPU_P		(3LL <<  6)
#define	PEU_O_ERU_P		(1LL <<  5)
#define	PEU_O_ERO_P		(1LL <<  4)
#define	PEU_O_EMP_P		(1LL <<  3)
#define	PEU_O_EPE_P		(1LL <<  2)
#define	PEU_O_ERP_P		(1LL <<  1)
#define	PEU_O_EIP_P		(1LL <<  0)

/* CXPL Interrupt Status Register (0x6e2118) */
#define	CXPL_EVT_RCV_EN_LB		(1LL << 31)
#define	CXPL_EVT_RCV_DIS_LINK		(1LL << 30)
#define	CXPL_EVT_RCV_HOT_RST		(1LL << 29)
#define	CXPL_EVT_RCV_EIDLE_EXIT		(1LL << 28)
#define	CXPL_EVT_RCV_EIDLE		(1LL << 27)
#define	CXPL_EVT_RCV_TS1		(1LL << 26)
#define	CXPL_EVT_RCV_TS2		(1LL << 25)
#define	CXPL_EVT_SEND_SKP_B2B		(1LL << 24)
#define	CXPL_ERR_OUTSTANDING_SKIP	(1LL << 17)
#define	CXPL_ERR_ELASTIC_FIFO_UNDRFLW	(1LL << 16)
#define	CXPL_ERR_ELSTC_FIFO_OVRFLW	(1LL << 15)
#define	CXPL_ERR_ALIGN			(1LL << 14)
#define	CXPL_ERR_KCHAR_DLLP_TLP		(1LL << 13)
#define	CXPL_ERR_ILL_END_POS		(1LL << 12)
#define	CXPL_ERR_SYNC			(1LL << 11)
#define	CXPL_ERR_END_NO_STP_SDP		(1LL << 10)
#define	CXPL_ERR_SDP_NO_END		(1LL <<  9)
#define	CXPL_ERR_STP_NO_END_EDB		(1LL <<  8)
#define	CXPL_ERR_ILL_PAD_POS		(1LL <<  7)
#define	CXPL_ERR_MULTI_SDP		(1LL <<  6)
#define	CXPL_ERR_MULTI_STP		(1LL <<  5)
#define	CXPL_ERR_ILL_SDP_POS		(1LL <<  4)
#define	CXPL_ERR_ILL_STP_POS		(1LL <<  3)
#define	CXPL_ERR_UNSUP_DLLP		(1LL <<  2)
#define	CXPL_ERR_SRC_TLP		(1LL <<  1)
#define	CXPL_ERR_SDS_LOS		(1LL <<  0)

#define	PRIMARY_ERRORS_MASK	0xffffffff
#define	SECONDARY_ERRORS_MASK	0xffffffff00000000LL
#define	PRIMARY_TO_SECONDARY_SHIFT_SZ	(32)
#define	SECONDARY_TO_PRIMARY_SHIFT_SZ	PRIMARY_TO_SECONDARY_SHIFT_SZ
#define	ALIGN_TO_64			(32)

#define	PEU_CE_GROUP		(PEU_CE_RTO_S | PEU_CE_RNR_S | PEU_CE_BDP_S | \
				 PEU_CE_BTP_S | PEU_CE_RE_S | PEU_CE_RTO_P | \
				 PEU_CE_RNR_P | PEU_CE_BDP_P | PEU_CE_BTP_P | \
				 PEU_CE_RE_P)

#define	PEU_CE_GROUP_P		(PEU_CE_GROUP & PRIMARY_ERRORS_MASK)
#define	PEU_CE_GROUP_S		(PEU_CE_GROUP & SECONDARY_ERRORS_MASK)

#define	PEU_OE_RECEIVE_GROUP_P	(PEU_O_MFC_P | PEU_O_MRC_P | PEU_O_WUC_P | \
				 PEU_O_CTO_P | PEU_O_RUC_P | PEU_O_CRS_P)

#define	PEU_OE_TRANS_GROUP_P	(PEU_O_MFC_P | PEU_O_CTO_P | PEU_O_WUC_P | \
				 PEU_O_RUC_P | PEU_O_CRS_P)

#define	PEU_OE_NO_DUP_GROUP_P	(PEU_O_SPARE_P | PEU_O_MFC_P | PEU_O_CTO_P | \
				 PEU_O_NFP_P | PEU_O_LWC_P | PEU_O_IIP_P | \
				 PEU_O_EDP_P | PEU_O_EHP_P | PEU_O_LRS_P | \
				 PEU_O_LDN_P | PEU_O_LUP_P | PEU_O_LPU_P)

#define	PEU_OE_DUP_LLI_P	(PEU_O_ERU_P | PEU_O_ERO_P | PEU_O_EMP_P | \
				 PEU_O_EPE_P | PEU_O_ERP_P | PEU_O_EIP_P)

#define	PEU_OE_NO_DUP_SVVS_RPT_MSK	(PEU_O_IIP_P | PEU_O_EDP_P | \
					 PEU_O_EHP_P)


#define	PEU_OE_LINK_INTERRUPT_GROUP_P	(PEU_O_LIN)

#define	PEU_OE_RECV_SVVS_RPT_MSK	(PEU_O_MFC_P)

#define	PEU_OE_TRANS_SVVS_RPT_MSK	(PEU_O_WUC_P | PEU_O_RUC_P)

#define	IMU_EQ_NOT_EN_GROUP	(IMU_EQ_NOT_EN_P | IMU_EQ_NOT_EN_S)

#define	IMU_EQ_OVER_GROUP	(IMU_EQ_OVER_P | IMU_EQ_OVER_S)

#define	IMU_MSI_MES_GROUP	(IMU_MSI_MAL_ERR_P | IMU_MSI_MAL_ERR_S | \
				 IMU_MSI_PAR_ERR_P | IMU_MSI_PAR_ERR_S | \
				 IMU_PMEACK_MES_NOT_EN_P | \
				 IMU_PMEACK_MES_NOT_EN_S | \
				 IMU_PMPME_MES_NOT_EN_P | \
				 IMU_PMPME_MES_NOT_EN_S | \
				 IMU_FATAL_MES_NOT_EN_P | \
				 IMU_FATAL_MES_NOT_EN_S | \
				 IMU_NONFATAL_MES_NOT_EN_P | \
				 IMU_NONFATAL_MES_NOT_EN_S | \
				 IMU_COR_MES_NOT_EN_P | \
				 IMU_COR_MES_NOT_EN_S | \
				 IMU_MSI_NOT_EN_P | IMU_MSI_NOT_EN_S)

#define	IMU_EQ_NOT_EN_GROUP_P	(IMU_EQ_NOT_EN_GROUP & PRIMARY_ERRORS_MASK)
#define	IMU_EQ_OVER_GROUP_P	(IMU_EQ_OVER_GROUP & PRIMARY_ERRORS_MASK)
#define	IMU_MSI_MES_GROUP_P	(IMU_MSI_MES_GROUP & PRIMARY_ERRORS_MASK)

#define	IMU_EQ_NOT_EN_GROUP_S	(IMU_EQ_NOT_EN_GROUP & SECONDARY_ERRORS_MASK)
#define	IMU_EQ_OVER_GROUP_S	(IMU_EQ_OVER_GROUP & SECONDARY_ERRORS_MASK)
#define	IMU_MSI_MES_GROUP_S	(IMU_MSI_MES_GROUP & SECONDARY_ERRORS_MASK)

#define	MMU_ERR_GROUP		(MMU_TBW_DPE_S | MMU_TBW_ERR_S | \
				 MMU_TBW_UDE_S | MMU_TBW_DME_S | \
				 MMU_SPARE3_S | MMU_SPARE2_S | \
				 MMU_TTC_CAE_S | MMU_TTC_DPE_S | \
				 MMU_TTE_PRT_S | MMU_TTEINV_S | \
				 MMU_TRN_OOR_S | MMU_TRN_ERR_S | \
				 MMU_SPARE1_S | MMU_INV_PG_SZ_S | \
				 MMU_BYP_OOR_S  | MMU_BYP_ERR_S | \
				 MMU_TBW_DPE_P | MMU_TBW_ERR_P | \
				 MMU_TBW_UDE_P | MMU_TBW_DME_P | \
				 MMU_SPARE3_P | MMU_SPARE2_P | \
				 MMU_TTC_CAE_P | MMU_TTC_DPE_P | \
				 MMU_TTE_PRT_P | MMU_TTE_INV_P | \
				 MMU_TRN_OOR_P | MMU_TRN_ERR_P | \
				 MMU_SPARE1_P | MMU_INV_PG_SZ_P | \
				 MMU_BYP_OOR_P | MMU_BYP_ERR_P | \
				 MMU_SUN4V_KEY_ERR_P | MMU_VA_ADJ_UF_P | \
				 MMU_VA_OOR_P | MMU_IOTSBDESC_DPE_P | \
				 MMU_IOTSBDESC_INV_P | MMU_TBW_DPE_P | \
				 MMU_SUN4V_KEY_ERR_S | MMU_VA_ADJ_UF_S | \
				 MMU_VA_OOR_S | MMU_IOTSBDESC_DPE_S | \
				 MMU_IOTSBDESC_INV_S | MMU_TBW_DPE_S)


#define	MMU_ERR_GROUP_P		(MMU_ERR_GROUP & PRIMARY_ERRORS_MASK)
#define	MMU_ERR_GROUP_S		(MMU_ERR_GROUP & SECONDARY_ERRORS_MASK)

#define	PEU_UE_RECV_GROUP	(PEU_UR_P | PEU_UR_S | PEU_MFP_P | PEU_MFP_S | \
				 PEU_ROF_P | PEU_ROF_S | PEU_UC_P | PEU_UC_S | \
				 PEU_PP_P | PEU_PP_S)

#define	PEU_UE_TRANS_GROUP	(PEU_CTO_P | PEU_CTO_S)

#define	PEU_UE_RECV_GROUP_P	(PEU_UE_RECV_GROUP & PRIMARY_ERRORS_MASK)
#define	PEU_UE_RECV_GROUP_S    (PEU_UE_RECV_GROUP & SECONDARY_ERRORS_MASK)
#define	PEU_UE_TRANS_GROUP_P	(PEU_UE_TRANS_GROUP & PRIMARY_ERRORS_MASK)
#define	PEU_UE_TRANS_GROUP_S   (PEU_UE_TRANS_GROUP & SECONDARY_ERRORS_MASK)

#define	IMU_RDS_ERROR_BITS	(IMU_MSI_MAL_ERR_P | IMU_MSI_PAR_ERR_P | \
				 IMU_PMEACK_MES_NOT_EN_P | \
				 IMU_PMPME_MES_NOT_EN_P | \
				 IMU_FATAL_MES_NOT_EN_P | \
				 IMU_NONFATAL_MES_NOT_EN_P | \
				 IMU_COR_MES_NOT_EN_P | IMU_MSI_NOT_EN_P)

#define	ILU_GROUP		(ILU_SPARE3_P | ILU_SPARE2_P | \
				 ILU_SPARE1_P | ILU_IHB_PE_P | \
				 ILU_SPARE3_S | ILU_SPARE2_S | \
				 ILU_SPARE1_S | ILU_IHB_PE_S)

#define	ILU_GROUP_P		(ILU_GROUP & PRIMARY_ERRORS_MASK)
#define	ILU_GROUP_S		(ILU_GROUP & SECONDARY_ERRORS_MASK)

/* mondo guest epkt macro's */
#define	EPKT_FILL_HEADER(PIU_E_rpt, scr)				\
	ldx	[PIU_E_rpt + PCIERPT_EHDL], scr				;\
	stx	scr, [PIU_E_rpt + PCIERPT_SUN4V_EHDL]			;\
	ldx	[PIU_E_rpt + PCIERPT_STICK], scr			;\
	stx	scr, [PIU_E_rpt + PCIERPT_SUN4V_STICK]

/* Mondo 62 related macro's */
#define	LOG_DMC_IMU_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_INT_EN_REG, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_IMU_INTERRUPT_ENABLE]		;\
	set	PIU_DLC_IMU_ICS_IMU_ERROR_LOG_EN_REG, tmp1		;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_IMU_ERR_LOG_ENABLE]		;\
	set	PCI_E_IMU_ERR_STAT_SET_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_IMU_ERR_STATUS_SET]


#define	LOG_IMU_SCS_ERROR_LOG_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_CSR_A_IMU_SCS_ERROR_LOG_REG_ADDR, tmp2	;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_IMU_SCS_ERR_LOG]

#define	CLEAR_IMU_EQ_NOT_EN_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_NOT_EN_GROUP_P, tmp1				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_EQ_NOT_EN_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_NOT_EN_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_SCS_ERROR_LOG_REGS_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_NOT_EN_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ , tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_IMU_EQS_ERROR_LOG_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_EQS_ERROR_LOG_REG, tmp2		;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_IMU_EQS_ERR_LOG]

#define	CLEAR_IMU_EQ_OVER_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_OVER_GROUP_P, tmp1				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_EQ_OVER_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_OVER_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_IMU_RDS_ERROR_LOG_REG(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_CSR_A_IMU_RDS_ERROR_LOG_REG_ADDR, tmp2	;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_IMU_RDS_ERR_LOG]

#define	CLEAR_IMU_MSI_MES_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_MSI_MES_GROUP_P, tmp1				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_MSI_MES_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_MSI_MES_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_DMC_MMU_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PIU_DLC_MMU_CSR_A_LOG_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_MMU_ERR_LOG_ENABLE]		;\
	set	PIU_DLC_MMU_INT_EN, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_MMU_INTR_ENABLE]		;\
	set     PCI_E_MMU_ERR_STAT_SET_ADDR, tmp2			;\
	ldx     [PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx     tmp1, [PIU_rpt + PCIERPT_MMU_ERR_STATUS_SET]

#define	LOG_MMU_TRANS_FAULT_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_MMU_TRANS_FAULT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_MMU_TRANSLATION_FAULT_ADDRESS];\
	set	PIU_DLC_MMU_CSR_A_FLTS_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_MMU_TRANSLATION_FAULT_STATUS]

#define	CLEAR_MMU_ERR_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	.pushlocals							;\
	/* check for table walk parity error, scrub cache */		;\
	set	PCI_E_MMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	btst	MMU_TTC_DPE_P, tmp1					;\
	bnz	%xcc, 1f						;\
	mov	-1, tmp2						;\
	set	PIU_DLC_MMU_INV, tmp1					;\
	stx	tmp2, [PIU_LEAF_BASE_ADDR + tmp1]			;\
1:									;\
	set	PCI_E_MMU_ERR_STAT_CL_ADDR, tmp2			;\
	set	MMU_ERR_GROUP_P, tmp1					;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]			;\
	.poplocals

#define	CLEAR_MMU_ERR_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	.pushlocals							;\
	/* check for table walk parity error, scrub cache */		;\
	set	PCI_E_MMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	srlx	tmp1, SECONDARY_TO_PRIMARY_SHIFT_SZ, tmp1		;\
	btst	MMU_TTC_DPE_P, tmp1					;\
	bnz	%xcc, 1f						;\
	mov	-1, tmp2						;\
	set	PIU_DLC_MMU_INV, tmp1					;\
	stx	tmp2, [PIU_LEAF_BASE_ADDR + tmp1]			;\
1:									;\
	setx	MMU_ERR_GROUP_P, tmp2, tmp1				;\
	set	PCI_E_MMU_ERR_STAT_CL_ADDR, tmp2			;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]			;\
	.poplocals

#define	LOG_ILU_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)		\
	set	PCI_E_ILU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_ILU_ERR_LOG_ENABLE]		;\
	set	PCI_E_ILU_INT_ENB_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_ILU_INTR_ENABLE]		;\
	set	PCI_E_ILU_ERR_STAT_SET_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_ILU_ERR_STATUS_SET]

#define	CLEAR_ILU_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PCI_E_ILU_ERR_STAT_CL_ADDR, tmp2			;\
	set	ILU_GROUP_P, tmp1					;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

/* ILU_IHB_PE_P */
#define	LOG_ILU_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)		\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | INGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]

#define	LOG_ILU_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)		\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | INGRESS | U | STOP), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]

#define	CLEAR_ILU_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PCI_E_ILU_ERR_STAT_CL_ADDR, tmp2			;\
	set	ILU_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_PEU_UE_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PIU_PLC_TLU_CTB_TLR_UE_LOG, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_UE_LOG_ENABLE]			;\
	set	PCI_E_PEU_UE_INT_ENB_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_UE_INTERRUPT_ENABLE]		;\
	set	PCI_E_PEU_UE_STAT_SET_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
				PCIERPT_PEU_UE_STATUS_SET]

#define	LOG_PEU_UE_RCV_HDR_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_RUE_HDR1_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_RECEIVE_UE_HEADER1_LOG]	;\
	set	PCI_E_PEU_RUE_HDR2_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_RECEIVE_UE_HEADER2_LOG]

/*
 * bit 14, PEU_CTO_P   PCI | READ | U | H | I
 *	UE/CE Regs = Conpletion Timeout, PCIe Status = IS
 */
#define	LOG_PEU_UE_TRANS_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_UE_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	.pushlocals							;\
	set	PEU_CTO_P, tmp2						;\
	btst	tmp2, tmp1						;\
	bnz,a,pt %xcc, 1f						;\
	clr	tmp1							;\
	ba,a	9f							;\
1:									;\
	set	(PCI | READ | U | H | I), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	COMPLETION_TIMEOUT, tmp1				;\
	stx	tmp1, [PIU_rpt +  PCIERPT_WORD4]			;\
	set	PCI_E_PEU_TUE_HDR1_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_HDR1]				;\
	set	PCI_E_PEU_TUE_HDR2_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
9:									;\
	.poplocals							;\
	stx	tmp1, [PIU_rpt + PCIERPT_HDR2]


#define	LOG_PEU_UE_TRANS_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_UE_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	.pushlocals							;\
	set	PEU_CTO_P, tmp2						;\
	btst	tmp2, tmp1						;\
	bnz,a,pn %xcc, 1f						;\
	clr	tmp1							;\
	ba,a	8f							;\
1:									;\
	set	(PCI | READ | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	COMPLETION_TIMEOUT, tmp1				;\
	stx	tmp1, [PIU_rpt +  PCIERPT_WORD4]			;\
8:									;\
	.poplocals


#define	LOG_PEU_UE_FCP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1,	[PIU_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	FLOW_CONTROL_ERROR, tmp1				;\
	stx	tmp1, [PIU_rpt +  PCIERPT_WORD4]

#define	LOG_PEU_UE_FCP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | LINK | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1,	[PIU_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	FLOW_CONTROL_ERROR, tmp1				;\
	stx	tmp1, [PIU_rpt +  PCIERPT_WORD4]

#define	LOG_PEU_UE_DLP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [PIU_rpt +  PCIERPT_WORD4]


#define	LOG_PEU_UE_DLP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | LINK | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [PIU_rpt +  PCIERPT_WORD4]

#define	CLEAR_PEU_UE_FCP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
        set     PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_FCP_P, tmp1						;\
        stx     tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_UE_FCP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
        set     PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_FCP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
        stx     tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_UE_DLP_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_DLP_P, tmp1						;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_UE_DLP_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	;\
	set	PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_DLP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_UE_RECV_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	;\
	set	PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_UE_RECV_GROUP_P, tmp1				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_UE_RECV_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	set	PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_UE_RECV_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_PEU_UE_TRANS_HDR_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_TUE_HDR1_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_TRANSMIT_OTHER_EVENT_HEADER1_LOG]	;\
	set	PCI_E_PEU_TUE_HDR2_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt +					\
			PCIERPT_PEU_TRANSMIT_OTHER_EVENT_HEADER2_LOG]


#define	CLEAR_PEU_UE_TRANS_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_UE_TRANS_GROUP_P, tmp1				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_UE_TRANS_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_UE_STAT_CL_ADDR, tmp2				;\
	set	PEU_UE_TRANS_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

/*
 * IMU RDS Error Log Register:Offset: 0x00631028
 *
 * T [63:58] The lowest 6 bits of the Type of the errored
 *    transaction as seen by the IMU in the RDS pipe stage
 * L [57:48] The length of the errored transaction.
 * R [47:32] The REQ ID of the errored transaction.
 * t [31:24] The TLP tag of the errored transaction.
 * B [23:16] The Message code of the error, if the error is a message
 *    otherwise the First and Last Byte Enabled if the error is a MSI
 * x [15:0] the first 2 bytes MSI data if the error is a MSI, (byte 1,
 *    byte 0) 
 *
 *
 *    6         5         4         3         2         1         0
 * 3210987654321098765432109876543210987654321098765432109876543210
 * TTTTTTLLLLLLLLLLRRRRRRRRRRRRRRRRttttttttBBBBBBBBxxxxxxxxxxxxxxxx
 * 
 * RDS above, convert to HDR1 below
 * 
 * 00TTTTTT00000000000000LLLLLLLLLLRRRRRRRRRRRRRRRRttttttttBBBBBBBB
 * 
 */


/*
 *
 * IMU SCS Error Log Register:Offset: 0x00631030
 *
 * T [63:58] Low 6 bits of the Type of Error transaction as seen
 *    by the IMU SCS.
 * L [57:48] The length of the errored transaction.
 * R [47:32] The REQ ID of the errored transaction.
 * t [31:24] The TLP tag of the errored transaction.
 * B [23:16] The Message code of the error, if the error is a message
 *    otherwise the First and Last Byte Enabled if the error is a MSI
 * x [5:0] EQ number that the transaction tried to go into but
 *    was not enabled.
 *
 *    6         5         4         3         2         1         0
 * 3210987654321098765432109876543210987654321098765432109876543210
 * TTTTTTLLLLLLLLLLRRRRRRRRRRRRRRRRttttttttBBBBBBBB          xxxxxx
 * 
 * SCS above, convert to HDR1 below
 * 
 * 00TTTTTT00000000000000LLLLLLLLLLRRRRRRRRRRRRRRRRttttttttBBBBBBBB
 * 
 */

#define FILL_PCIE_HDR_FIELDS_FROM_ERR_LOG(PIU_E_rpt,			\
			PIU_LEAF_BASE_ADDRx, REG1, REG2, ERR_LOG_REG)	\
	set	ERR_LOG_REG, REG1					;\
	ldx	[PIU_LEAF_BASE_ADDRx + REG1], REG2			;\
	/* move LRtB into right place */				;\
	srlx	REG2, 16, REG1						;\
	sllx	REG1, (63-41), REG1					;\
	srlx	REG1, (63-41), REG1					;\
	/* move T into right place */					;\
	srlx	REG2, 58, REG2						;\
	sllx	REG2, 56, REG2						;\
	add	REG2, REG1, REG1					;\
	stx	REG1, [PIU_E_rpt + PCIERPT_HDR1]
/*
 * Bit 8
 */
#define	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | ILL | DIR_IRRELEVANT |	\
							H), tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	FILL_PCIE_HDR_FIELDS_FROM_ERR_LOG(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
		tmp1, tmp2, 						\
		 PIU_DLC_IMU_ICS_CSR_A_IMU_SCS_ERROR_LOG_REG_ADDR);

#define	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | ILL | DIR_IRRELEVANT |	\
							STOP), tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]

#define	LOG_IMU_EQ_OVER_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | OV | DIR_IRRELEVANT), 	\
								tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]


#define	LOG_IMU_EQ_OVER_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | OV | DIR_IRRELEVANT |	\
							STOP), tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]

#define	IMU_RDS_ERR_LOG_MSIINFO_SHIFT	(58)
#define	MSI64BITPATTERN			(0x78) /* 1111000 64 bit msi */
#define	MSI32BITPATTERN			(0x2c) /* 1011000 32 bit msi */

#define	LOG_IMU_MSI_MES_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	.pushlocals							;\
	set	PCI_E_IMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	btst	IMU_MSI_NOT_EN_P, tmp1					;\
	bnz	%xcc, 1f						;\
	btst	IMU_COR_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_NONFATAL_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_FATAL_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_PMPME_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_PMEACK_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_MSI_PAR_ERR_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	IMU_MSI_MAL_ERR_P, tmp1					;\
	bnz	%xcc, 5f						;\
	clr	tmp1							;\
	ba,a	9f							;\
	  .empty							;\
1:									;\
	ldx	[PIU_rpt + PCIERPT_IMU_RDS_ERR_LOG], tmp1		;\
	srlx	tmp1, IMU_RDS_ERR_LOG_MSIINFO_SHIFT, tmp1		;\
	cmp	tmp1, MSI64BITPATTERN	/* is it 1111000 - 64 bit msi */;\
	bne,pn %xcc, 1f							;\
	nop								;\
	set	(INTR | MSI64 | PHASE_UNKNOWN | ILL | H), tmp1		;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	set	(INTR | MSI32 | PHASE_UNKNOWN | ILL | H), tmp1		;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(INTR | PCIEMSG | PHASE_UNKNOWN | ILL | INGRESS | H),	\
								 tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	ldx	[PIU_rpt + PCIERPT_IMU_RDS_ERR_LOG], tmp1		;\
	srlx	tmp1, IMU_RDS_ERR_LOG_MSIINFO_SHIFT, tmp1		;\
	cmp	tmp1, MSI64BITPATTERN	/* is it 1111000 - 64 bit msi */;\
	bne,pn %xcc, 1f							;\
	nop								;\
	set	(INTR | MSI64 | PDATA | INT  | DIR_UNKNOWN | H), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	cmp	tmp1, MSI32BITPATTERN	/* is it 1011000 - 32 bit msi */;\
	set	(INTR | MSI32 | PDATA | INT  | DIR_UNKNOWN | H), tmp1	;\
	bne,pn	%xcc, 1f						;\
	nop								;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	set	(INTR | INT_OP_UNKNOWN | PDATA | INT | DIR_UNKNOWN | H),\
		 tmp1							;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	ldx	[PIU_rpt + PCIERPT_IMU_RDS_ERR_LOG], tmp1		;\
	srlx	tmp1, IMU_RDS_ERR_LOG_MSIINFO_SHIFT, tmp1		;\
	cmp	tmp1, MSI64BITPATTERN	/* is it 1111000 - 64 bit msi */;\
	bne,pn  %xcc, 2f						;\
	nop								;\
	set	(INTR | MSI64 | PHASE_UNKNOWN | ILL  | DIR_IRRELEVANT | \
							H), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	cmp	tmp1, MSI32BITPATTERN	/* is it 1011000 - 32 bit msi */;\
	set	(INTR | MSI32 | PHASE_UNKNOWN | ILL  | DIR_IRRELEVANT | \
							H), tmp1	;\
	bne,pn	%xcc, 2f						;\
	nop								;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(INTR | INT_OP_UNKNOWN | PHASE_UNKNOWN | ILL |		\
		 DIR_IRRELEVANT | H), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	FILL_PCIE_HDR_FIELDS_FROM_ERR_LOG(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
		tmp1, tmp2,						\
		 PIU_DLC_IMU_ICS_CSR_A_IMU_RDS_ERROR_LOG_REG_ADDR)	;\
9:									;\
	.poplocals

#define	LOG_IMU_MSI_MES_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	.pushlocals							;\
	set	PCI_E_IMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	srlx	tmp1, SECONDARY_TO_PRIMARY_SHIFT_SZ, tmp1		;\
	btst	IMU_MSI_NOT_EN_P, tmp1					;\
	bnz	%xcc, 1f						;\
	btst	IMU_COR_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_NONFATAL_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_FATAL_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_PMPME_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_PMEACK_MES_NOT_EN_P, tmp1				;\
	bnz	%xcc, 2f						;\
	btst	IMU_MSI_PAR_ERR_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	IMU_MSI_MAL_ERR_P, tmp1					;\
	bnz	%xcc, 5f						;\
	clr	tmp1							;\
	ba,a	9f							;\
	  .empty							;\
1:									;\
	set	(INTR | MSI32 | PHASE_UNKNOWN | ILL | STOP), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(INTR | PCIEMSG | PHASE_UNKNOWN | ILL | INGRESS | STOP),\
								 tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(INTR | OP_UNKNOWN | PDATA | INT  | DIR_UNKNOWN | STOP),\
								tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(INTR | OP_UNKNOWN | PHASE_UNKNOWN | ILL  |		\
					DIR_IRRELEVANT | STOP), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
9:									;\
	.poplocals

/*
 * bit 17, PEU_ROF_P   PCI | INGRESS | U | H | I
 *	UE/CE Regs = Receiver Overflow, PCIe Status = IS
 * bit 20, PEU_UR_P     PCI | INGRESS | U | H | I
 * 			UE/CE Regs = Unsupported Request, PCIe Status = IS
 */
#define	LOG_PEU_UE_RECV_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | INGRESS | U | H | I), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	PCI_E_PEU_UE_INT_STAT_ADDR, tmp1			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp1], tmp2			;\
	.pushlocals							;\
	set	PEU_UR_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	PEU_UC_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	PEU_MFP_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	.empty								;\
	set	PEU_PP_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 4f						;\
	.empty								;\
	set	PEU_ROF_P, tmp1						;\
	btst    tmp1, tmp2						;\
	bnz	%xcc, 5f						;\
	clr	tmp2							;\
	ba,a	9f							;\
	  .empty							;\
1:									;\
	set	UNSUPPORTED_REQUEST, tmp1				;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	UNEXPECTED_COMPLETION, tmp1				;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
3:									;\
	set	MALFORMED_TLP, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
4:									;\
	set	DP, tmp1						;\
	add	tmp1, IS, tmp1						;\
	/* rewrite the 4 bytes containing the PCIe err status */	;\
	/* to include the Detected Parity bit */			;\
	stuw	tmp1, [PIU_rpt + (PCIERPT_SUN4V_DESC + 4)]		;\
	set	POISONED_TLP, tmp1					;\
	ba	8f							;\
	   stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
5:									;\
	set	RECEIVER_OVERFLOW, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	set	PCI_E_PEU_RUE_HDR1_ADDR, tmp1				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp1], tmp2			;\
	stx	tmp2, [PIU_rpt + PCIERPT_HDR1]				;\
	set	PCI_E_PEU_RUE_HDR2_ADDR, tmp1				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp1], tmp2			;\
9:									;\
	.poplocals							;\
	stx	tmp2, [PIU_rpt + PCIERPT_HDR2]


#define	LOG_PEU_UE_RECV_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	(PCI | INGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	PCI_E_PEU_UE_INT_STAT_ADDR, tmp1			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp1], tmp2			;\
	.pushlocals							;\
	set	PEU_UR_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	PEU_UC_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	PEU_MFP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	.empty								;\
	set	PEU_PP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 4f						;\
	set	PEU_ROF_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 5f						;\
	clr	tmp2							;\
	ba,a	8f							;\
	  .empty							;\
1:									;\
	set	(UNSUPPORTED_REQUEST | STOP), tmp1			;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(UNEXPECTED_COMPLETION | STOP), tmp1			;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
3:									;\
	set	(MALFORMED_TLP | STOP), tmp1				;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
4:									;\
	set	(DP | STOP), tmp1					;\
	add	tmp1, IS, tmp1						;\
	/* rewrite the 4 bytes containing the PCIe err status */	;\
	/* to include the Detected Parity bit */			;\
	stuw	tmp1, [PIU_rpt + (PCIERPT_SUN4V_DESC + 4)]		;\
	set	(POISONED_TLP | STOP), tmp1				;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
5:									;\
	set	(RECEIVER_OVERFLOW | STOP), tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	.poplocals

#define	LOG_PEU_CE_GROUP_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PIU_PLC_TLU_CTB_TLR_CE_LOG, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_CE_LOG_ENABLE]		;\
	set	PIU_PLC_TLU_CTB_TLR_CE_INT_EN, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_CE_INTERRUPT_ENABLE]	;\
	set	PCI_E_PEU_CE_STAT_SET_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_CE_STATUS_SET]

#define	CLEAR_PEU_CE_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PEU_CE_GROUP_P, tmp1					;\
	set	PCI_E_PEU_CE_STAT_CL_ADDR, tmp2				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_CE_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PEU_CE_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	PCI_E_PEU_CE_STAT_CL_ADDR, tmp2				;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_PEU_CE_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	.pushlocals							;\
	set	PCI_E_PEU_CE_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_CE_RTO_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	PEU_CE_RNR_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	PEU_CE_BDP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	btst	PEU_CE_BTP_P, tmp2					;\
	bnz	%xcc, 4f						;\
	  .empty							;\
	set	(PCI | INGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	RECEIVER_ERROR, tmp2					;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
1:									;\
	set	(PCI | EGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_TIMER_TIMEOUT, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(PCI | EGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_NUM_ROLLOVER, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
3:									;\
	set	(PCI | INGRESS), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_DLLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
4:									;\
	set	(PCI | INGRESS), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_TLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	.poplocals


#define	LOG_PEU_CE_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	.pushlocals							;\
	set	PCI_E_PEU_CE_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_CE_RTO_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	PEU_CE_RNR_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	PEU_CE_BDP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	PEU_CE_BTP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 4f						;\
	  .empty							;\
	set	(PCI | INGRESS | C | STOP), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	RECEIVER_ERROR, tmp2					;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
1:									;\
	set	(PCI | EGRESS | C | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_TIMER_TIMEOUT, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(PCI | EGRESS | C | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_NUM_ROLLOVER, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
3:									;\
	set	(PCI | INGRESS | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_DLLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
4:									;\
	set	(PCI | INGRESS | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_TLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	stx	tmp2, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	.poplocals

#define	LOG_PEU_OE_GROUP_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	PCI_E_PEU_OTHER_LOG_ENB_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_OTHER_EVENT_LOG_ENABLE]	;\
	set	PCI_E_PEU_OTHER_ERR_STAT_SET_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_OTHER_EVENT_STATUS_SET]	;\
	set	PCI_E_PEU_OTHER_INT_ENB_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_OTHER_EVENT_INTR_ENABLE]	;\

#define	LOG_PEU_OE_INTR_STATUS_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
							 tmp2, MASK)	\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	MASK, tmp2						;\
	and	tmp1, tmp2, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_OTHER_EVENT_INTR_STATUS]	;\

#define	LOG_PEU_OE_INTR_STATUS_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
						 tmp2, INTR_MASK)	\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	INTR_MASK, tmp2						;\
	sllx	tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp2		;\
	and	tmp1, tmp2, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_PEU_OTHER_EVENT_INTR_STATUS]	;\

#define	LOG_PEU_OE_RECV_GROUP_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_ROE_HDR1_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_RECEIVE_OTHER_EVENT_HEADER1_LOG]	;\
	set	PCI_E_PEU_ROE_HDR2_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_RECEIVE_OTHER_EVENT_HEADER2_LOG]

#define	CLEAR_PEU_OE_RECV_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PEU_OE_RECEIVE_GROUP_P, tmp1				;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_OE_RECV_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PEU_OE_RECEIVE_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_OE_DUP_LLI_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	;\
	set	PEU_OE_DUP_LLI_P, tmp1					;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_OE_DUP_LLI_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	;\
	set	PEU_OE_DUP_LLI_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_OE_NO_DUP_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PEU_OE_NO_DUP_GROUP_P, tmp1				;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_PEU_OE_NO_DUP_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PEU_OE_NO_DUP_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_PEU_OE_TRANS_GROUP_REGS(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PCI_E_PEU_TOE_HDR1_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_TRANSMIT_OTHER_EVENT_HEADER1_LOG]	;\
	set	PCI_E_PEU_TOE_HDR2_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [PIU_rpt + 					\
			PCIERPT_PEU_TRANSMIT_OTHER_EVENT_HEADER2_LOG]

#define	LOG_PEU_OE_RECV_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)    \
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_O_MFC_P, tmp1					;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	clr	tmp1							;\
	ba	8f							;\
	  nop								;\
1:									;\
	set	(PCI | INGRESS | U | H | I), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set     MALFORMED_TLP, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
	set	PCI_E_PEU_RUE_HDR1_ADDR, tmp1				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp1], tmp2			;\
	stx	tmp2, [PIU_rpt + PCIERPT_HDR1]				;\
	set	PCI_E_PEU_RUE_HDR2_ADDR, tmp1				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp1], tmp2			;\
	stx	tmp2, [PIU_rpt + PCIERPT_HDR2]				;\
8:									;\
	.poplocals							;\
	nop
	

#define	LOG_PEU_OE_RECV_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)    \
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_O_MFC_P, tmp1					;\
	sllx    tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	clr	tmp1							;\
	ba	8f							;\
	  nop								;\
1:									;\
	set	(PCI | INGRESS | U | I | STOP), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set     MALFORMED_TLP, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	.poplocals							;\
	nop

#define	LOG_PEU_OE_TRANS_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_O_WUC_P, tmp1					;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	set	PEU_O_RUC_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	clr	tmp1							;\
	ba	8f							;\
	  nop								;\
1:									;\
	set	(PCI | WRITE | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(PCI | READ | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	.poplocals							;\
	nop

#define	LOG_PEU_OE_TRANS_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_O_WUC_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	set	PEU_O_RUC_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	clr	tmp1							;\
	ba	8f							;\
	  nop								;\
1:									;\
	set	(PCI | WRITE | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(PCI | READ | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	.poplocals							;\
	nop

#define	CLEAR_PEU_OE_TRANS_GROUP_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PEU_OE_TRANS_GROUP_P, tmp1				;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]


#define	CLEAR_PEU_OE_TRANS_GROUP_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	PEU_OE_TRANS_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	PCI_E_PEU_OTHER_ERR_STAT_CL_ADDR, tmp2			;\
	stx	tmp1, [PIU_LEAF_BASE_ADDR + tmp2]

#define	LOG_PEU_OE_NO_DUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_O_IIP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	set	PEU_O_EDP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	set	PEU_O_EHP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	set	PEU_O_LRS_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	PEU_O_LDN_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	PEU_O_LUP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	clr	tmp1							;\
	ba	8f							;\
	  nop								;\
1:									;\
	set	(PCI | INGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(PCI | EGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
3:									;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	.poplocals							;\
	nop

#define	LOG_PEU_OE_NO_DUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_PEU_OTHER_INT_STAT_ADDR, tmp2			;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp2			;\
	set	PEU_O_IIP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	set	PEU_O_EDP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	set	PEU_O_EHP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	set	PEU_O_LRS_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	PEU_O_LDN_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	PEU_O_LUP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	clr	tmp1							;\
	ba	8f							;\
	  nop								;\
1:									;\
	set	(PCI | INGRESS | U | STOP), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
2:									;\
	set	(PCI | EGRESS | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
3:									;\
	set	(PCI | LINK | U | STOP), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [PIU_rpt + PCIERPT_WORD4]				;\
8:									;\
	.poplocals							;\
	nop

#define	LOG_PCIERPT_CXPL_INTR_STATUS(PIU_rpt, PIU_LEAF_BASE_ADDR, LOGBIT,\
							scr1, scr2)	\
	set	LOGBIT, scr1						;\
	stx	scr1, [PIU_rpt + PCIERPT_PEU_CXPL_EVENT_ERROR_INT_STATUS];\
	set	PCI_E_PEU_CXPL_INT_ENB_ADDR, scr2			;\
	ldx	[PIU_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [PIU_LEAF_BASE_ADDR + 				\
				PCIERPT_PEU_CXPL_EVENT_ERROR_INT_ENABLE];\
	set	PCI_E_PEU_CXPL_LOG_ENB_ADDR, scr2			;\
	ldx	[PIU_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [PIU_LEAF_BASE_ADDR +				\
				PCIERPT_PEU_CXPL_EVENT_ERROR_LOG_ENABLE];\
	set	PCI_E_PEU_CXPL_STAT_SET_ADDR, scr2			;\
	ldx	[PIU_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [PIU_LEAF_BASE_ADDR +				\
				PCIERPT_PEU_CXPL_EVENT_ERROR_STATUS_SET]


#define	CLEAR_CXPL_INTR_STATUS(PIU_rpt, PIU_LEAF_BASE_ADDR, LOGBIT, 	\
							scr1, scr2)	\
	set	LOGBIT, scr2						;\
	set	PCI_E_PEU_CXPL_STAT_CL_ADDR, scr1			;\
	stx	scr2, [PIU_LEAF_BASE_ADDR + scr1]


/*
 * log MMU header and addr fields for the errors that need them
 */
#define	MMU_FAULT_LOGGING_GROUP		(MMU_TBW_DPE_P | MMU_TBW_ERR_P | \
					 MMU_TBW_UDE_P | MMU_TBW_DME_P | \
					 MMU_TTE_PRT_P | MMU_TTE_INV_P | \
					 MMU_TRN_OOR_P | MMU_TRN_ERR_P | \
					 MMU_BYP_OOR_P | MMU_BYP_ERR_P | \
					 MMU_VA_OOR_P | MMU_VA_ADJ_UF_P | \
					 MMU_IOTSBDESC_DPE_P | \
					 MMU_IOTSBDESC_INV_P | \
					 MMU_INV_PG_SZ_P | \
					 MMU_SUN4V_KEY_ERR_P)

#define LOG_MMU_FAULT_ADDR_AND_FAULT_STATUS(PIU_E_rpt,			\
				PIU_LEAF_BASE_ADDRx, REG1, REG2)	\
	set     PCI_E_MMU_TRANS_FAULT_ADDR, REG1			;\
	ldx     [PIU_LEAF_BASE_ADDRx + REG1], REG2			;\
	/* bits 63:2 hold the va, align value for ereport */		;\
	srlx    REG2, 2, REG2						;\
	sllx	REG2, 2, REG2						;\
	stx     REG2, [PIU_E_rpt + PCIERPT_WORD4]			;\
	sllx	REG2, 32, REG2						;\
	stx     REG2, [PIU_E_rpt + PCIERPT_HDR2]			;\
	set     PIU_DLC_MMU_CSR_A_FLTS_ADDR, REG1			;\
	ldx     [PIU_LEAF_BASE_ADDRx + REG1], REG2			;\
	/* bits 22:16 hold tranaction type move to 62:56 */		;\
	srlx    REG2, 16, REG2						;\
	sllx    REG2, 56, REG2						;\
	ldx     [PIU_LEAF_BASE_ADDRx + REG1], REG1			;\
	/* bits 15:0 hold BDF, move to 31:16, zero upper 32 bits */	;\
	sllx    REG1, (63 - 15), REG1					;\
	srlx    REG1, 32, REG1						;\
	and     REG1, REG2, REG2					;\
	stx     REG2, [PIU_E_rpt + PCIERPT_HDR1]

#define	LOG_MMU_ERR_GROUP_EPKT_P(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_MMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	.pushlocals							;\
	btst	MMU_BYP_ERR_P, tmp1					;\
	bnz	%xcc, 1f						;\
	btst	MMU_BYP_OOR_P, tmp1					;\
	bnz	%xcc, 2f						;\
	set	MMU_VA_OOR_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 3f						;\
	set	MMU_VA_ADJ_UF_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 3f						;\
	btst	MMU_TTE_INV_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	MMU_INV_PG_SZ_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	MMU_TTE_PRT_P, tmp1					;\
	bnz	%xcc, 5f						;\
	btst	MMU_TTC_DPE_P, tmp1					;\
	bnz	%xcc, 6f						;\
	set	MMU_IOTSBDESC_DPE_P, tmp2				;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 6f						;\
	btst	MMU_TTC_CAE_P, tmp1					;\
	bnz	%xcc, 7f						;\
	nop								;\
	ba,a	8f							;\
	  .empty								;\
1:									;\
	set	(MMU | BYPASS | PHASE_UNKNOWN | ILL | DIR_UNKNOWN | D | \
							H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(MMU | BYPASS | ADDR | ILL | RDRW | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(MMU | TRANSLATION | ADDR | UNMAP | RDRW | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(MMU | TRANSLATION | PDATA | INV | DIR_UNKNOWN | D | H),\
								tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(MMU | TRANSLATION | PDATA | PROT | WRITE | D | H),	\
								 tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
6:									;\
	set	(MMU | TRANSLATION | ADDR | PHASE_IRRELEVANT| 		\
					DIR_IRRELEVANT | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
7:									;\
	set 	(MMU | TRANSLATION | PDATA | COND_IRRELEVENT |		\
						DIR_IRRELEVANT), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	set	MMU_TBW_DME_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 2f						;\
	set	MMU_TBW_UDE_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 2f						;\
	set	MMU_TBW_ERR_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 3f						;\
	set	MMU_TBW_DPE_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 4f						;\
	btst	MMU_TRN_ERR_P, tmp1					;\
	bnz	%xcc, 5f						;\
	btst	MMU_TRN_OOR_P, tmp1					;\
	bnz	%xcc, 6f						;\
	set	MMU_IOTSBDESC_INV_P, tmp2				;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 7f						;\
	set	MMU_SUN4V_KEY_ERR_P, tmp2				;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 8f						;\
	clr	tmp1							;\
	ba,a	1f							;\
	nop								;\
2:									;\
	set	(MMU | TABLEWALK | PHASE_UNKNOWN | ILL | 		\
					DIR_IRRELEVANT | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(MMU | TABLEWALK | PHASE_UNKNOWN | COND_UNKNOWN | 	\
					DIR_IRRELEVANT | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(MMU | TABLEWALK | PDATA | INT | DIR_IRRELEVANT | D | H),\
								 tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(MMU | TRANSLATION | PHASE_UNKNOWN | ILL | 		\
					 DIR_IRRELEVANT | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
6:									;\
	set	(MMU | TRANSLATION | ADDR | ILL | RDRW | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
7:									;\
	set	(MMU | TRANSLATION | PDATA | INV | RDRW | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	set	(MMU | TRANSLATION | ADDR | PROT | RDRW | D | H), tmp1	;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	set	PCI_E_MMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	MMU_FAULT_LOGGING_GROUP, tmp2				;\
	btst	tmp2, tmp1						;\
	bz	%xcc, 1f						;\
	  .empty							;\
	LOG_MMU_FAULT_ADDR_AND_FAULT_STATUS(PIU_rpt, PIU_LEAF_BASE_ADDR,\
							tmp1, tmp2);	;\
1:									;\
	.poplocals

#define	LOG_MMU_ERR_GROUP_EPKT_S(PIU_rpt, PIU_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	EPKT_FILL_HEADER(PIU_rpt, tmp1);				;\
	set	PCI_E_MMU_INT_STAT_ADDR, tmp2				;\
	ldx	[PIU_LEAF_BASE_ADDR + tmp2], tmp1			;\
	srlx	tmp1, SECONDARY_TO_PRIMARY_SHIFT_SZ, tmp1		;\
	.pushlocals							;\
	btst	MMU_BYP_ERR_P, tmp1					;\
	bnz	%xcc, 1f						;\
	btst	MMU_BYP_OOR_P, tmp1					;\
	bnz	%xcc, 2f						;\
	set	MMU_VA_OOR_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 3f						;\
	set	MMU_VA_ADJ_UF_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 3f						;\
	btst	MMU_TTE_INV_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	MMU_INV_PG_SZ_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	MMU_TTE_PRT_P, tmp1					;\
	bnz	%xcc, 5f						;\
	btst	MMU_TTC_DPE_P, tmp1					;\
	bnz	%xcc, 6f						;\
	set	MMU_IOTSBDESC_DPE_P, tmp2				;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 6f						;\
	btst	MMU_TTC_CAE_P, tmp1					;\
	bnz	%xcc, 7f						;\
	nop								;\
	ba,a	8f							;\
	.empty					;\
1:									;\
	set	(MMU | BYPASS | PHASE_UNKNOWN | ILL | DIR_UNKNOWN | 	\
							STOP), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(MMU | BYPASS | ADDR | ILL | RDRW | STOP), tmp1		;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(MMU | TRANSLATION | ADDR | UNMAP | RDRW | STOP), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(MMU | TRANSLATION | PDATA | INV | DIR_UNKNOWN | STOP), \
								tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(MMU | TRANSLATION | PDATA | PROT | WRITE | STOP), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
6:									;\
	set	(MMU | TRANSLATION | ADDR | PHASE_IRRELEVANT| 		\
					DIR_IRRELEVANT | STOP), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
7:									;\
	set 	(MMU | TRANSLATION | PDATA | COND_IRRELEVENT | 		\
					DIR_IRRELEVANT | STOP), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	set	MMU_TBW_DME_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 2f						;\
	set	MMU_TBW_UDE_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 2f						;\
	set	MMU_TBW_ERR_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 3f						;\
	set	MMU_TBW_DPE_P, tmp2					;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 4f						;\
	btst	MMU_TRN_ERR_P, tmp1					;\
	bnz	%xcc, 5f						;\
	btst	MMU_TRN_OOR_P, tmp1					;\
	bnz	%xcc, 6f						;\
	set	MMU_IOTSBDESC_INV_P, tmp2				;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 7f						;\
	set	MMU_SUN4V_KEY_ERR_P, tmp2				;\
	btst	tmp2, tmp1						;\
	bnz	%xcc, 8f						;\
	clr	tmp1							;\
	ba,a	1f							;\
	.empty					;\
2:									;\
	set	(MMU | TABLEWALK | PHASE_UNKNOWN | ILL | 		\
				DIR_IRRELEVANT | STOP), tmp1		;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(MMU | TABLEWALK | PHASE_UNKNOWN | COND_UNKNOWN |	 \
				DIR_IRRELEVANT | STOP), tmp1		;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(MMU | TABLEWALK | PDATA | INT | DIR_IRRELEVANT | STOP),\
								 tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(MMU | TRANSLATION | PHASE_UNKNOWN | ILL | 		\
				DIR_IRRELEVANT | STOP), tmp1		;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
6:									;\
	set	(MMU | TRANSLATION | ADDR | ILL | RDRW | D | STOP), 	\
								tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
7:									;\
	set	(MMU | TRANSLATION | PDATA | INV | RDRW | STOP), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	set	(MMU | TRANSLATION | ADDR | PROT | RDRW | STOP), tmp1	;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	stx	tmp1, [PIU_rpt + PCIERPT_SUN4V_DESC]			;\
	.poplocals

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_VPIU_ERRS_H */
