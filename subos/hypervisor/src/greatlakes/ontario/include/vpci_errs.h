/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci_errs.h
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

#ifndef _ONTARIO_VPCI_ERRS_H
#define	_ONTARIO_VPCI_ERRS_H

#pragma ident	"@(#)vpci_errs.h	1.34	07/07/30 SMI"

#ifdef __cplusplus
extern "C" {
#endif


#define	PCIE_ERR_INO	62
#define	JBC_ERR_INO	63

/*
 * Macro to generate unique error handle
 * and load some of the diag ereport and sun4v erpt
 * entries that are common to mondo 0x62 and 0x63.
 * %g1 - fire cookie
 * %g2 - r_fire_e_rpt
 * %g3 - IGN
 * %g4 - INO
 * %g5 - scratch
 * %g6 - scratch
 * %g7 - data0
 */

/* BEGIN CSTYLED */
#define	GEN_ERR_HNDL_SETUP_ERPTS(FIRE_COOKIE, FIRE_rpt, IGN, INO, scr1, \
							scr2, DATA0)	\
	.pushlocals							;\
	set	FIRE_COOKIE_JBC_ERPT, scr1				;\
	set	PCIE_ERR_INO, scr2					;\
	cmp	scr2, INO						;\
	beq,a,pt  %xcc, 1f						;\
	  set	FIRE_COOKIE_PCIE_ERPT, scr1				;\
1:									;\
	add	FIRE_COOKIE, scr1, FIRE_rpt				;\
	GEN_SEQ_NUMBER(scr1, scr2);					;\
	/* store the error handle in the error report */		;\
	stx	scr1, [FIRE_rpt + PCIERPT_EHDL] /* store ehdlin erpt */	;\
	stx	scr1, [FIRE_rpt + PCIERPT_SUN4V_EHDL]			;\
	stx	DATA0, [FIRE_rpt + PCIERPT_SYSINO]			;\
	st	INO, [FIRE_rpt + PCIERPT_MONDO_NUM]			;\
	st	IGN, [FIRE_rpt + PCIERPT_AGENTID]			;\
	/* save the TOD/STICK count	*/				;\
	ROOT_STRUCT(scr1)						;\
	ldx    [scr1 + CONFIG_TOD], scr1				;\
	brnz,a,pn	scr1, 1f					;\
	  ldx	[scr1], scr1			/* aborted if no TOD */	;\
1:	rd	STICK, scr2				/* stick */	;\
	stx	scr1, [FIRE_rpt + PCIERPT_FPGA_TOD]			;\
	stx	scr2, [FIRE_rpt + PCIERPT_STICK]			;\
	stx	scr2, [FIRE_rpt + PCIERPT_SUN4V_STICK] 			;\
	rdhpr	%hver, scr1			/* read cpu version */	;\
	stx	scr1, [FIRE_rpt + PCIERPT_CPUVER]			;\
	set	ERPT_TYPE_VPCI, scr2					;\
	stx	scr2, [FIRE_rpt + PCIERPT_REPORT_TYPE_62]		;\
	.poplocals							;\

#define	CLEAR_FIRE_INTERRUPT(FIRE_COOKIE, MONDO, reg1)			\
	ldx	[FIRE_COOKIE + FIRE_COOKIE_INTCLR], reg1		;\
	stx	%g0, [reg1 + (MONDO<<3)]

#define	GENERATE_FMA_REPORT						\
	mov	r_fire_e_rpt, %g1					;\
	ba,a	generate_fma_report					;\
	  .empty

#define	PCIE_ERR_MONDO_OFFSET		8
#define	JBC_ERR_MONDO_OFFSET		0
#define	FIRE_LEAF_DEVID_MASK		1

#define	PCIE_ERR_MONDO_EREPORT(FIRE_COOKIE, FIRE_rpt, reg1, reg2)	\
	ldx	[FIRE_rpt + PCIERPT_SYSINO], reg1			;\
	srlx	reg1, FIRE_DEVINO_SHIFT, reg1				;\
	and	reg1, FIRE_LEAF_DEVID_MASK, reg1 /* devid 0 or 1 */	;\
	ldx	[FIRE_COOKIE + FIRE_COOKIE_VIRTUAL_INTMAP],  reg2	;\
	add	reg2, PCIE_ERR_MONDO_OFFSET, reg2			;\
	ldub	[reg2 + reg1], reg1					;\
	brnz	reg1, generate_guest_report	/* yes, send a ereport*/;\
	nop

#define	JBC_ERR_MONDO_EREPORT(FIRE_COOKIE, FIRE_rpt, reg1, reg2)	\
	ldx	[FIRE_COOKIE + FIRE_COOKIE_VIRTUAL_INTMAP],  reg2	;\
	lduh	[reg2 + JBC_ERR_MONDO_OFFSET], reg2			;\
	brnz	reg2, generate_guest_report_special			;\
	nop

#define	FIRE_JBCINT_IN_TRAN_ERROR_LOG_ADDR_NBITS		(42)

#define	FIRE_JBCINT_IN_TRAN_ERROR_LOG_ADDR_BITS(addr)	\
	sllx	addr, (63 - FIRE_JBCINT_IN_TRAN_ERROR_LOG_ADDR_NBITS), addr	;\
	srlx	addr, (63 - FIRE_JBCINT_IN_TRAN_ERROR_LOG_ADDR_NBITS), addr

#define	FIRE_JBCINT_OUT_TRAN_ERROR_LOG_ADDR_BITS	\
	  FIRE_JBCINT_IN_TRAN_ERROR_LOG_ADDR_BITS

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

/* JBC Error Status Clear Register bit defs */

#define	SPARE_BIT_2_S		(1LL << 63)
#define	SPARE_BIT_0_S		(1LL << 62)
#define	SPARE_BIT_1_S		(1LL << 61)
#define	PIO_UNMAP_RD_S		(1LL << 60)
#define	ILL_ACC_RD_S		(1LL << 59)
#define	EBUS_TO_S		(1LL << 58)
#define	MB_PEA_S		(1LL << 57)
#define	MB_PER_S		(1LL << 56)
#define	MB_PEW_S		(1LL << 55)
#define	UE_ASYN_S		(1LL << 54)
#define	CE_ASYN_S		(1LL << 53)
#define	JTE_S			(1LL << 52)
#define	JBE_S			(1LL << 51)
#define	JUE_S			(1LL << 50)
#define	IJP_S			(1LL << 49)
#define	ICISE_S			(1LL << 48)
#define	CPE_S			(1LL << 47)
#define	APE_S			(1LL << 46)
#define	WR_DPE_S		(1LL << 45)
#define	RD_DPE_S		(1LL << 44)
#define	ILL_BMW_S		(1LL << 43)
#define	ILL_BMR_S		(1LL << 42)
#define	BJC_S			(1LL << 41)
#define	PIO_UNMAP_S		(1LL << 40)
#define	PIO_DPE_S		(1LL << 39)
#define	PIO_CPE_S		(1LL << 38)
#define	ILL_ACC_S		(1LL << 37)
#define	UNSOL_RD_S		(1LL << 36)
#define	UNSOL_INTR_S		(1LL << 35)
#define	JTCEEW_S		(1LL << 34)
#define	JTCEEI_S		(1LL << 33)
#define	JTCEER_S		(1LL << 32)
#define	SPARE_BIT_2_P		(1LL << 31)
#define	SPARE_BIT_0_P		(1LL << 30)
#define	SPARE_BIT_1_P		(1LL << 29)
#define	PIO_UNMAP_RD_P		(1LL << 28)
#define	ILL_ACC_RD_P		(1LL << 27)
#define	EBUS_TO_P		(1LL << 26)
#define	MB_PEA_P		(1LL << 25)
#define	MB_PER_P		(1LL << 24)
#define	MB_PEW_P		(1LL << 23)
#define	UE_ASYN_P		(1LL << 22)
#define	CE_ASYN_P		(1LL << 21)
#define	JTE_P			(1LL << 20)
#define	JBE_P			(1LL << 19)
#define	JUE_P			(1LL << 18)
#define	IJP_P			(1LL << 17)
#define	ICISE_P			(1LL << 16)
#define	CPE_P			(1LL << 15)
#define	APE_P			(1LL << 14)
#define	WR_DPE_P		(1LL << 13)
#define	RD_DPE_P		(1LL << 12)
#define	ILL_BMW_P		(1LL << 11)
#define	ILL_BMR_P		(1LL << 10)
#define	BJC_P			(1LL <<  9)
#define	PIO_UNMAP_P		(1LL <<  8)
#define	PIO_DPE_P		(1LL <<  7)
#define	PIO_CPE_P		(1LL <<  6)
#define	ILL_ACC_P		(1LL <<  5)
#define	UNSOL_RD_P		(1LL <<  4)
#define	UNSOL_INTR_P		(1LL <<  3)
#define	JTCEEW_P		(1LL <<  2)
#define	JTCEEI_P		(1LL <<  1)
#define	JTCEER_P		(1LL <<  0)

/* JBC Interrupt Enable Register bit defs */
#define	SPARE_S_INT_EN		(1LL << 61)
#define	PIO_UNMAP_RD_S_INT_EN	(1LL << 60)
#define	ILL_ACC_RD_S_INT_EN	(1LL << 59)
#define	EBUS_TO_S_LOG_EN	(1LL << 58)
#define	MB_PEA_S_INT_EN		(1LL << 57)
#define	MB_PER_S_INT_EN		(1LL << 56)
#define	MB_PEW_S_INT_EN		(1LL << 55)
#define	UE_ASYN_S_INT_EN	(1LL << 54)
#define	CE_ASYN_S_INT_EN	(1LL << 53)
#define	JTE_S_INT_EN		(1LL << 52)
#define	JBE_S_INT_EN		(1LL << 51)
#define	JUE_S_INT_EN		(1LL << 50)
#define	IJP_S_INT_EN		(1LL << 49)
#define	ICISE_S_INT_EN		(1LL << 48)
#define	CPE_S_INT_EN		(1LL << 47)
#define	APE_S_INT_EN		(1LL << 46)
#define	WR_DPE_S_INT_EN		(1LL << 45)
#define	RD_DPE_S_INT_EN		(1LL << 44)
#define	ILL_BMW_S_INT_EN	(1LL << 43)
#define	ILL_BMR_S_INT_EN	(1LL << 42)
#define	BJC_S_INT_EN		(1LL << 41)
#define	PIO_UNMAP_S_INT_EN	(1LL << 40)
#define	PIO_DPE_S_INT_EN	(1LL << 39)
#define	PIO_CPE_S_INT_EN	(1LL << 38)
#define	ILL_ACC_S_INT_EN	(1LL << 37)
#define	UNSOL_RD_S_INT_EN	(1LL << 36)
#define	UNSOL_INTR_S_INT_EN	(1LL << 35)
#define	JTCEEW_S_INT_EN		(1LL << 34)
#define	JTCEEI_S_INT_EN		(1LL << 33)
#define	JTCEER_S_INT_EN		(1LL << 32)
#define	SPARE_P_INT_EN		(3LL << 29)
#define	PIO_UNMAP_RD_P_INT_EN	(1LL << 28)
#define	ILL_ACC_RD_P_INT_EN	(1LL << 27)
#define	EBUS_TO_P_INT_EN	(1LL << 26)
#define	MB_PEA_P_INT_EN		(1LL << 25)
#define	MB_PER_P_INT_EN		(1LL << 24)
#define	MB_PEW_P_INT_EN		(1LL << 23)
#define	UE_ASYN_P_INT_EN	(1LL << 22)
#define	CE_ASYN_P_INT_EN	(1LL << 21)
#define	JTE_P_INT_EN		(1LL << 20)
#define	JBE_P_INT_EN		(1LL << 19)
#define	JUE_P_INT_EN		(1LL << 18)
#define	IJP_P_INT_EN		(1LL << 17)
#define	ICISE_P_INT_EN		(1LL << 16)
#define	CPE_P_INT_EN		(1LL << 15)
#define	APE_P_INT_EN		(1LL << 14)
#define	WR_DPE_P_INT_EN		(1LL << 13)
#define	RD_DPE_P_INT_EN		(1LL << 12)
#define	ILL_BMW_P_INT_EN	(1LL << 11)
#define	ILL_BMR_P_INT_EN	(1LL << 10)
#define	BJC_P_INT_EN		(1LL <<  9)
#define	PIO_UNMAP_P_INT_EN	(1LL <<  8)
#define	PIO_DPE_P_INT_EN	(1LL <<  7)
#define	PIO_CPE_P_INT_EN	(1LL <<  6)
#define	ILL_ACC_P_INT_EN	(1LL <<  5)
#define	UNSOL_RD_P_INT_EN	(1LL <<  4)
#define	UNSOL_INTR_P_INT_EN	(1LL <<  3)
#define	JTCEEW_P_INT_EN		(1LL <<  2)
#define	JTCEEI_P_INT_EN		(1LL <<  1)
#define	JTCEER_P_INT_EN		(1LL <<  0)

/* bit test masks for the JBC Core and Block Error Status Reg */
#define	DMCINT_BIT		0x1
#define	JBCINT_BIT		0x2
#define	MERGE_BIT		0x4
#define	CSR_BIT			0x8


/* bit test masks for the Multi Core Error Status Reg */
#define	DMC_BIT			(1LL << 0)
#define	PEC_BIT			(1LL << 1)

/* bit test mask for the DMC Core and Block Error Status Register */
#define	IMU_BIT			(1LL << 0)
#define	MMU_BIT			(1LL << 1)

/* test bits for the IMU Interrupt Status Register */

#define	IMU_SPARE_S		(1LL << 42)
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
#define	IMU_SPARE_P		(1LL << 10)
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

/* test bits for the MMUInterrupt Status Register (0x00641010, 0x00741010) */
#define	MMU_TBW_DPE_S		(1LL << 47)
#define	MMU_TBW_ERR_S		(1LL << 46)
#define	MMU_TBW_UDE_S		(1LL << 45)
#define	MMU_TBW_DME_S		(1LL << 44)
#define	MMU_SPARE3_S		(1LL << 43)
#define	MMU_SPARE2_S		(1LL << 42)
#define	MMU_TTC_CAE_S		(1ll << 41)
#define	MMU_TTC_DPE_S		(1LL << 40)
#define	MMU_TTE_PRT_S		(1LL << 39)
#define	MMU_TTEINV_S		(1LL << 38)
#define	MMU_TRN_OOR_S		(1LL << 37)
#define	MMU_TRN_ERR_S		(1LL << 36)
#define	MMU_SPARE1_S		(1LL << 35)
#define	MMU_SPARE0_S		(1LL << 34)
#define	MMU_BYP_OOR_S		(1LL << 33)
#define	MMU_BYP_ERR_S		(1LL << 32)
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
#define	MMU_SPARE0_P		(1LL <<  2)
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

/* PEC Core and Block Interrupt Status Register (0x00651808, 0x00751808) */
#define	PEC_ILU_BIT		(1LL <<  3)
#define	PEC_UE_BIT		(1LL <<  2)
#define	PEC_CE_BIT		(1LL <<  1)
#define	PEC_OE_BIT		(1LL <<  0)

/* TLU Uncorrectable Error Status Clear Register (0x00691018, 0x00791018) */
#define	TLU_UR_S		(1LL << 52)
#define	TLU_MFP_S		(1LL << 50)
#define	TLU_ROF_S		(1LL << 49)
#define	TLU_UC_S		(1LL << 48)
#define	TLU_CA_S		(1LL << 47)
#define	TLU_CTO_S		(1LL << 46)
#define	TLU_FCP_S		(1LL << 45)
#define	TLU_PP_S		(1LL << 44)
#define	TLU_DLP_S		(1LL << 36)
#define	TLU_TE_S		(1LL << 32)
#define	TLU_UR_P		(1LL << 20)
#define	TLU_MFP_P		(1LL << 18)
#define	TLU_ROF_P		(1LL << 17)
#define	TLU_UC_P		(1LL << 16)
#define	TLU_CA_P		(1LL << 15)
#define	TLU_CTO_P		(1LL << 14)
#define	TLU_FCP_P		(1LL << 13)
#define	TLU_PP_P		(1LL << 12)
#define	TLU_DLP_P		(1LL <<  4)
#define	TLU_TE_P		(1LL <<  0)

/* TLU Correctable Error Status Reg (0x6a1018, 0x7a1018) */
#define	TLU_CE_RTO_S		(1LL << 44)
#define	TLU_CE_RNR_S		(1LL << 40)
#define	TLU_CE_BDP_S		(1LL << 39)
#define	TLU_CE_BTP_S		(1LL << 38)
#define	TLU_CE_RE_S		(1LL << 32)
#define	TLU_CE_RTO_P		(1LL << 12)
#define	TLU_CE_RNR_P		(1LL <<  8)
#define	TLU_CE_BDP_P		(1LL <<  7)
#define	TLU_CE_BTP_P		(1LL <<  6)
#define	TLU_CE_RE_P		(1LL <<  0)

/* TLU Other Events Status Register (0x681010, 0x781010) */
#define	TLU_O_SPARE_S		(1LL << 55)
#define	TLU_O_MFC_S		(1LL << 54)
#define	TLU_O_CTO_S		(1LL << 53)
#define	TLU_O_NFP_S		(1LL << 52)
#define	TLU_O_LWC_S		(1LL << 51)
#define	TLU_O_MRC_S		(1LL << 50)
#define	TLU_O_WUC_S		(1LL << 49)
#define	TLU_O_RUC_S		(1LL << 48)
#define	TLU_O_CRS_S		(1LL << 47)
#define	TLU_O_IIP_S		(1LL << 46)
#define	TLU_O_EDP_S		(1LL << 45)
#define	TLU_O_EHP_S		(1LL << 44)
#define	TLU_O_LIN_S		(1LL << 43)
#define	TLU_O_LRS_S		(1LL << 42)
#define	TLU_O_LDN_S		(1LL << 41)
#define	TLU_O_LUP_S		(1LL << 40)
#define	TLU_O_LPU_S		(3LL << 38)
#define	TLU_O_ERU_S		(1LL << 37)
#define	TLU_O_ERO_S		(1LL << 36)
#define	TLU_O_EMP_S		(1LL << 35)
#define	TLU_O_EPE_S		(1LL << 34)
#define	TLU_O_ERP_S		(1LL << 33)
#define	TLU_O_EIP_S		(1LL << 32)
#define	TLU_O_SPARE_P		(1LL << 23)
#define	TLU_O_MFC_P		(1LL << 22)
#define	TLU_O_CTO_P		(1LL << 21)
#define	TLU_O_NFP_P		(1LL << 20)
#define	TLU_O_LWC_P 		(1LL << 19)
#define	TLU_O_MRC_P		(1LL << 18)
#define	TLU_O_WUC_P		(1LL << 17)
#define	TLU_O_RUC_P		(1LL << 16)
#define	TLU_O_CRS_P		(1LL << 15)
#define	TLU_O_IIP_P		(1LL << 14)
#define	TLU_O_EDP_P		(1LL << 13)
#define	TLU_O_EHP_P		(1LL << 12)
#define	TLU_O_LIN_P		(1LL << 11)
#define	TLU_O_LRS_P		(1LL << 10)
#define	TLU_O_LDN_P		(1LL <<  9)
#define	TLU_O_LUP_P		(1LL <<  8)
#define	TLU_O_LPU_P		(3LL <<  6)
#define	TLU_O_ERU_P		(1LL <<  5)
#define	TLU_O_ERO_P		(1LL <<  4)
#define	TLU_O_EMP_P		(1LL <<  3)
#define	TLU_O_EPE_P		(1LL <<  2)
#define	TLU_O_ERP_P		(1LL <<  1)
#define	TLU_O_EIP_P		(1LL <<  0)

/* LPU Link Layer Interrupt and Status Register (0x6E2210, 0x7E2210  */
#define	LPU_LLI_INT_LINK_ERR_ACT	(1LL << 31)
#define	LPU_LLI_INT_UNSPRTD_DLLP 	(1LL << 22)
#define	LPU_LLI_INT_DLLP_RCV_ERR 	(1LL << 21)
#define	LPU_LLI_INT_BAD_DLLP		(1LL << 20)
#define	LPU_LLI_INT_TLP_RCV_ERR 	(1LL << 18)
#define	LPU_LLI_INT_SRC_ERR_TLP		(1LL << 17)
#define	LPU_LLI_INT_BAD_TLP		(1LL << 16)
#define	LPU_LLI_INT_RTRY_BUF_UDF_ERR 	(1LL <<  9)
#define	LPU_LLI_INT_RTRY_BUF_OVF_ERR 	(1LL <<  8)
#define	LPU_LLI_INT_EG_TLP_MIN_ERR 	(1LL <<  7)
#define	LPU_LLI_INT_EG_TRNC_FRM_ERR 	(1LL <<  6)
#define	LPU_LLI_INT_RTRY_BUF_PE 	(1LL <<  5)
#define	LPU_LLI_INT_EGRESS_PE		(1LL <<  4)
#define	LPU_LLI_INT_RPLAY_TMR_TO	(1LL <<  2) /* Use TLU copy in CE reg */
#define	LPU_LLI_INT_RPLAY_NUM_RO	(1LL <<  1) /* Use TLU copy in CE reg */
#define	LPU_LLI_INT_DLNK_PES		(1LL <<  0)

/* LPU Phy Layer Interrupt and Status Register (0x6E2610, 0x7E2610 */
#define	LPU_PHY_INT_PHY_LAYER_ERR 	(1LL << 31)
#define	LPU_PHY_INT_KCHAR_DLLP_ERR 	(1LL << 11) /* Note: Don't use it */
#define	LPU_PHY_INT_ILL_END_POS_ERR 	(1LL << 10)
#define	LPU_PHY_INT_LNK_ERR 		(1LL <<  9)
#define	LPU_PHY_INT_TRN_ERR 		(1LL <<  8)
#define	LPU_PHY_INT_EDB_DET 		(1LL <<  7)
#define	LPU_PHY_INT_SDP_END 		(1LL <<  6) /* Note: Don't use it */
#define	LPU_PHY_INT_STP_END_EDB 	(1LL <<  5) /* Note: Don't use it */
#define	LPU_PHY_INT_INVLD_CHAR_ERR 	(1LL <<  4)
#define	LPU_PHY_INT_MULTI_SDP 		(1LL <<  3)
#define	LPU_PHY_INT_MULTI_STP 		(1LL <<  2)
#define	LPU_PHY_INT_ILL_SDP_POS 	(1LL <<  1)
#define	LPU_PHY_INT_ILL_STP_POS 	(1LL <<  0)

/* LPU Interrupt Status Register (0x6e2040, 0x7e2040) */
#define	LPU_INT_STAT_INTERRUPT		(1LL << 31)
#define	LPU_INT_STAT_INT_PERF_CNTR_2_OVFLW	(1LL <<  7)
#define	LPU_INT_STAT_INT_PERF_CNTR_1_OVFLW	(1LL <<  6)
#define	LPU_INT_STAT_INT_LINK_LAYER	(1LL <<  5)
#define	LPU_INT_STAT_INT_PHY_ERROR	(1LL <<  4)
#define	LPU_INT_STAT_INT_LTSSM		(1LL <<  3)
#define	LPU_INT_STAT_INT_PHY_TX		(1LL <<  2)
#define	LPU_INT_STAT_INT_PHY_RX		(1LL <<  1)
#define	LPU_INT_STAT_INT_PHY_GB		(1LL <<  0)


#define	PRIMARY_ERRORS_MASK	0xffffffff
#define	SECONDARY_ERRORS_MASK	0xffffffff00000000LL
#define	PRIMARY_TO_SECONDARY_SHIFT_SZ	(32)
#define	ALIGN_TO_64			(32)

#define	TLU_CE_GROUP		(TLU_CE_RTO_S | TLU_CE_RNR_S | TLU_CE_BDP_S | \
				 TLU_CE_BTP_S | TLU_CE_RE_S | TLU_CE_RTO_P | \
				 TLU_CE_RNR_P | TLU_CE_BDP_P | TLU_CE_BTP_P | \
				 TLU_CE_RE_P)

#define	TLU_CE_GROUP_P		(TLU_CE_GROUP & PRIMARY_ERRORS_MASK)
#define	TLU_CE_GROUP_S		(TLU_CE_GROUP & SECONDARY_ERRORS_MASK)
/*
 * TLU CE Errors have duplicates in the LPU LInk Layer Interrupt and Status Reg
 * we will create a special TLU_CE_DUP_GROUP to use for clearing the duplicate
 * bits in the LPU reg
 *
 * one to one bits and dups
 * TLU_CE_RTO_P ->> LPU_LLI_INT_RPLAY_TMR_TO      bit 12, bit 2
 * TLU_CE_RNR_P ->> LPU_LLI_INT_RPLAY_NUM_RO      bit 8,  bit 1
 * TLU_CE_BDP_P ->> LPU_LLI_INT_BAD_DLLP          bit 7,  bit 20
 * TLU_CE_BTP_P ->> LPU_LLI_INT_BAD_TLP           bit 6,  bit 16
 *
 * the bit zero and the many other dup bits
 * TLU_CE_RE_P  ->> LPU_LLI_INT_DLLP_RCV_ERR
 *             and  LPU_LLI_INT_TLP_RCV_ERR
 *             and
 */
#define	TLU_CE_DUP_LPU_LLI	(LPU_LLI_INT_RPLAY_TMR_TO | \
				 LPU_LLI_INT_RPLAY_NUM_RO | \
				 LPU_LLI_INT_BAD_DLLP | LPU_LLI_INT_BAD_TLP)

#define	TLU_OE_RECEIVE_GROUP_P	(TLU_O_MFC_P | TLU_O_MRC_P | TLU_O_WUC_P | \
				 TLU_O_CTO_P | TLU_O_RUC_P | TLU_O_CRS_P)

#define	TLU_OE_TRANS_GROUP_P	(TLU_O_MFC_P | TLU_O_CTO_P | TLU_O_WUC_P | \
				 TLU_O_RUC_P | TLU_O_CRS_P)

#define	TLU_OE_NO_DUP_GROUP_P	(TLU_O_SPARE_P | TLU_O_MFC_P | TLU_O_CTO_P | \
				 TLU_O_NFP_P | TLU_O_LWC_P | TLU_O_IIP_P | \
				 TLU_O_EDP_P | TLU_O_EHP_P | TLU_O_LRS_P | \
				 TLU_O_LDN_P | TLU_O_LUP_P | TLU_O_LPU_P)

#define	TLU_OE_DUP_LLI_P	(TLU_O_ERU_P | TLU_O_ERO_P | TLU_O_EMP_P | \
				 TLU_O_EPE_P | TLU_O_ERP_P | TLU_O_EIP_P)

#define	TLU_OE_NO_DUP_SVVS_RPT_MSK	(TLU_O_IIP_P | TLU_O_EDP_P | \
					 TLU_O_EHP_P)


#define	TLU_OE_LINK_INTERRUPT_GROUP	(TLU_O_LIN_P | TLU_O_LIN_S)
#define	TLU_OE_LINK_INTERRUPT_GROUP_P	(TLU_OE_LINK_INTERRUPT_GROUP & \
					 PRIMARY_ERRORS_MASK)


#define	TLU_OE_TRANS_SVVS_RPT_MSK	(TLU_O_WUC_P | TLU_O_RUC_P)

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
				 MMU_SPARE1_S | MMU_SPARE0_S | \
				 MMU_BYP_OOR_S  | MMU_BYP_ERR_S | \
				 MMU_TBW_DPE_P | MMU_TBW_ERR_P | \
				 MMU_TBW_UDE_P | MMU_TBW_DME_P | \
				 MMU_SPARE3_P | MMU_SPARE2_P | \
				 MMU_TTC_CAE_P | MMU_TTC_DPE_P | \
				 MMU_TTE_PRT_P | MMU_TTE_INV_P | \
				 MMU_TRN_OOR_P | MMU_TRN_ERR_P | \
				 MMU_SPARE1_P | MMU_SPARE0_P | \
				 MMU_BYP_OOR_P | MMU_BYP_ERR_P)

#define	MMU_ERR_GROUP_P		(MMU_ERR_GROUP & PRIMARY_ERRORS_MASK)
#define	MMU_ERR_GROUP_S		(MMU_ERR_GROUP & SECONDARY_ERRORS_MASK)

#define	TLU_UE_RECV_GROUP	(TLU_UR_P | TLU_UR_S | TLU_MFP_P | TLU_MFP_S | \
				 TLU_ROF_P | TLU_ROF_S | TLU_UC_P | TLU_UC_S | \
				 TLU_PP_P | TLU_PP_S)

#define	TLU_UE_TRANS_GROUP	(TLU_CTO_P | TLU_CTO_S)

#define	TLU_UE_RECV_GROUP_P	(TLU_UE_RECV_GROUP & PRIMARY_ERRORS_MASK)
#define	TLU_UE_RECV_GROUP_S    (TLU_UE_RECV_GROUP & SECONDARY_ERRORS_MASK)
#define	TLU_UE_TRANS_GROUP_P	(TLU_UE_TRANS_GROUP & PRIMARY_ERRORS_MASK)
#define	TLU_UE_TRANS_GROUP_S   (TLU_UE_TRANS_GROUP & SECONDARY_ERRORS_MASK)

#define	JBC_FATAL_GROUP		(MB_PEA_P | MB_PEA_S | CPE_P | CPE_S | \
				 APE_P | APE_S | JTCEEW_S | JTCEEI_S | \
				 JTCEER_S | JTCEEW_P | JTCEEI_P | \
				 JTCEER_P | PIO_CPE_S | PIO_CPE_P | \
				 SPARE_BIT_0_S | SPARE_BIT_0_P | \
				 SPARE_BIT_1_S | SPARE_BIT_1_P)

#define	JBC_FATAL_LOGING_GROUP	(MB_PEA_P | CPE_P | APE_P | JTCEER_P | \
				 JTCEEI_P | PIO_CPE_P)

#define	DMCINT_ODC_GROUP	(PIO_UNMAP_S | PIO_UNMAP_P | PIO_UNMAP_RD_S | \
				 PIO_UNMAP_RD_P | PIO_DPE_S | PIO_DPE_P | \
				 ILL_ACC_S | ILL_ACC_P | ILL_ACC_RD_S | \
				 ILL_ACC_RD_P | SPARE_BIT_2_S | SPARE_BIT_2_P)

#define	DMCINT_ODC_SVVS_RPT_MSK	(PIO_UNMAP_P | PIO_DPE_P | ILL_ACC_P | \
				 ILL_ACC_RD_P | PIO_UNMAP_RD_P)

#define	DMCINT_IDC_GROUP	(UNSOL_RD_S | UNSOL_RD_P | UNSOL_INTR_S | \
				 UNSOL_INTR_P)

#define	DMCINT_IDC_SVVS_RPT_MSK	(0)

#define	JBUSINT_IN_GROUP	(UE_ASYN_S | UE_ASYN_P | CE_ASYN_S | \
				 CE_ASYN_P | JTE_S | JTE_P | JBE_S | \
				 JBE_P | JUE_S | JUE_P | ICISE_S | \
				 ICISE_P | WR_DPE_S | WR_DPE_P | \
				 RD_DPE_S | RD_DPE_P | ILL_BMW_S | \
				 ILL_BMW_P | ILL_BMR_S | ILL_BMR_P | \
				 BJC_S | BJC_P)

#define	JBUSINT_IN_SVVS_RPT_MSK	(UE_ASYN_P | JTE_P | JBE_P | JUE_P | ICISE_P | \
				 WR_DPE_P |  RD_DPE_P | ILL_BMW_P | ILL_BMR_P)

#define	JBUSINT_OUT_GROUP	(IJP_S | IJP_P)

#define	JBUSINT_OUT_SVVS_RPT_MSK	(IJP_P)

#define	MERGE_GROUP		(MB_PER_S | MB_PER_P | MB_PEW_S | \
				 MB_PEW_P)

#define	MERGE_SVVS_RPT_MSK	(MB_PER_P | MB_PEW_P)

#define	CSR_GROUP		(EBUS_TO_S | EBUS_TO_P)

#define	CSR_SVVS_RPT_MSK	(EBUS_TO_P)

#define	DMCINT_ERRORS		(DMCINT_ODC_GROUP | DMCINT_IDC_GROUP )
#define	JBCINT_ERRORS		(JBUSINT_IN_GROUP | JBUSINT_OUT_GROUP )
#define	MERGE_ERRORS		(MERGE_GROUP)
#define	CSR_ERRORS		(CSR_GROUP)

#define	IMU_RDS_ERROR_BITS	(IMU_MSI_MAL_ERR_P | IMU_MSI_PAR_ERR_P | \
				 IMU_PMEACK_MES_NOT_EN_P | \
				 IMU_PMPME_MES_NOT_EN_P | \
				 IMU_FATAL_MES_NOT_EN_P | \
				 IMU_NONFATAL_MES_NOT_EN_P | \
				 IMU_COR_MES_NOT_EN_P | IMU_MSI_NOT_EN_P)

#define	JBC_FATAL_GROUP_P	(JBC_FATAL_GROUP & PRIMARY_ERRORS_MASK)
#define	DMCINT_ODC_GROUP_P	(DMCINT_ODC_GROUP & PRIMARY_ERRORS_MASK)
#define	DMCINT_IDC_GROUP_P	(DMCINT_IDC_GROUP & PRIMARY_ERRORS_MASK)
#define	JBUSINT_IN_GROUP_P	(JBUSINT_IN_GROUP & PRIMARY_ERRORS_MASK)
#define	JBUSINT_OUT_GROUP_P	(JBUSINT_OUT_GROUP & PRIMARY_ERRORS_MASK)
#define	MERGE_GROUP_P		(MERGE_GROUP & PRIMARY_ERRORS_MASK)
#define	CSR_GROUP_P		(CSR_GROUP & PRIMARY_ERRORS_MASK)


#define	JBC_FATAL_GROUP_S	(JBC_FATAL_GROUP & SECONDARY_ERRORS_MASK)
#define	DMCINT_ODC_GROUP_S	(DMCINT_ODC_GROUP & SECONDARY_ERRORS_MASK)
#define	DMCINT_IDC_GROUP_S	(DMCINT_IDC_GROUP & SECONDARY_ERRORS_MASK)
#define	JBUSINT_IN_GROUP_S	(JBUSINT_IN_GROUP & SECONDARY_ERRORS_MASK)
#define	JBUSINT_OUT_GROUP_S	(JBUSINT_OUT_GROUP & SECONDARY_ERRORS_MASK)
#define	MERGE_GROUP_S		(MERGE_GROUP & SECONDARY_ERRORS_MASK)
#define	CSR_GROUP_S		(CSR_GROUP & SECONDARY_ERRORS_MASK)


#define	ILU_GROUP		(ILU_SPARE3_P | ILU_SPARE2_P | \
				 ILU_SPARE1_P | ILU_IHB_PE_P | \
				 ILU_SPARE3_S | ILU_SPARE2_S | \
				 ILU_SPARE1_S | ILU_IHB_PE_S)

#define	ILU_GROUP_P		(ILU_GROUP & PRIMARY_ERRORS_MASK)
#define	ILU_GROUP_S		(ILU_GROUP & SECONDARY_ERRORS_MASK)

/*
 *	The Fire registers are at :
 *
 *	Leaf A (AID=0x1e)  0x80.0f00.0000
 *	Leaf B (AID=0x1f)  0x80.0f80.0000
 *
 *	PCIE addresses are at:
 *	Leaf A  0xe0.0000.0000
 *	Leaf B  0xf0.0000.0000
*/

/* mondo guest epkt macro's */
#define	EPKT_FILL_HEADER(FIRE_E_rpt, scr)				\
	ldx	[FIRE_E_rpt + PCIERPT_EHDL], scr			;\
	stx	scr, [FIRE_E_rpt + PCIERPT_SUN4V_EHDL]			;\
	ldx	[FIRE_E_rpt + PCIERPT_STICK], scr			;\
	stx	scr, [FIRE_E_rpt + PCIERPT_SUN4V_STICK]

/* Mondo 62 related macro's */
#define	LOG_DMC_IMU_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_INT_EN_REG, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_IMU_INTERRUPT_ENABLE]		;\
	set	FIRE_DLC_IMU_ICS_IMU_ERROR_LOG_EN_REG, tmp1		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_IMU_ERR_LOG_ENABLE]		;\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1S_ALIAS,\
								 tmp2	;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_IMU_ERR_STATUS_SET]


#define	LOG_IMU_SCS_ERROR_LOG_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_SCS_ERROR_LOG_REG, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_IMU_SCS_ERR_LOG]

#define	CLEAR_IMU_EQ_NOT_EN_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_NOT_EN_GROUP_P, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_EQ_NOT_EN_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_NOT_EN_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_SCS_ERROR_LOG_REGS_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_NOT_EN_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ , tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_IMU_EQS_ERROR_LOG_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_EQS_ERROR_LOG_REG, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_IMU_EQS_ERR_LOG]

#define	CLEAR_IMU_EQ_OVER_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_OVER_GROUP_P, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_EQ_OVER_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_EQ_OVER_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_IMU_RDS_ERROR_LOG_REG(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_RDS_ERROR_LOG_REG, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_IMU_RDS_ERR_LOG]

#define	CLEAR_IMU_MSI_MES_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_MSI_MES_GROUP_P, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_IMU_MSI_MES_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS,\
								 tmp2	;\
	set	IMU_MSI_MES_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_DMC_MMU_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_DLC_MMU_LOG, tmp2					;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_MMU_ERR_LOG_ENABLE]		;\
	set	FIRE_DLC_MMU_INT_EN, tmp2				;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_MMU_INTR_ENABLE]		;\
	set     FIRE_DLC_MMU_ERR_RW1S_ALIAS, tmp2			;\
	ldx     [FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx     tmp1, [FIRE_rpt + PCIERPT_MMU_ERR_STATUS_SET]

#define	LOG_MMU_TRANS_FAULT_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_DLC_MMU_FLTA, tmp2					;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_MMU_TRANSLATION_FAULT_ADDRESS];\
	set	FIRE_DLC_MMU_FLTS, tmp2					;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_MMU_TRANSLATION_FAULT_STATUS]

#define	CLEAR_MMU_ERR_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	set	FIRE_DLC_MMU_ERR_RW1C_ALIAS, tmp2			;\
	set	MMU_ERR_GROUP_P, tmp1					;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_MMU_ERR_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	set	FIRE_DLC_MMU_ERR_RW1C_ALIAS, tmp2			;\
	set	MMU_ERR_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_ILU_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)		\
	set	FIRE_DLC_ILU_CIB_ILU_LOG_EN, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ILU_ERR_LOG_ENABLE]		;\
	set	FIRE_DLC_ILU_CIB_ILU_INT_EN, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ILU_INTR_ENABLE]		;\
	set	FIRE_DLC_ILU_CIB_ILU_LOG_ERR_RW1S_ALIAS, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ILU_ERR_STATUS_SET]

#define	CLEAR_ILU_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_DLC_ILU_CIB_ILU_LOG_ERR_RW1C_ALIAS, tmp2		;\
	set	ILU_GROUP_P, tmp1					;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

/* ILU_IHB_PE_P */
#define	LOG_ILU_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | INGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]

#define	CLEAR_ILU_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_DLC_ILU_CIB_ILU_LOG_ERR_RW1C_ALIAS, tmp2		;\
	set	ILU_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_TLU_UE_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_UE_LOG, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + 					\
			PCIERPT_TLU_UE_LOG_ENABLE]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_INT_EN, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + 					\
			PCIERPT_TLU_UE_INTR_ENABLE]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1S_ALIAS, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + 					\
				PCIERPT_TLU_UE_STATUS_SET]

#define	LOG_TLU_UE_RCV_HDR_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_RUE_HDR1, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_RCV_UE_ERR_HDR1_LOG]	;\
	set	FIRE_PLC_TLU_CTB_TLR_RUE_HDR2, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_RCV_UE_ERR_HDR2_LOG]

/*
 * bit 14, TLU_CTO_P   PCI | READ | U | H | I
 *	UE/CE Regs = Conpletion Timeout, PCIe Status = IS
 */
#define	LOG_TLU_UE_TRANS_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	.pushlocals							;\
	set	TLU_CTO_P, tmp2						;\
	btst	tmp2, tmp1						;\
	bnz,a,pt %xcc, 1f						;\
	clr	tmp1							;\
	ba,a	9f							;\
1:									;\
	set	(PCI | READ | U | H | I), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	COMPLETION_TIMEOUT, tmp1				;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_ERROR_TYPE]			;\
	set	FIRE_PLC_TLU_CTB_TLR_TUE_HDR1, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_HDR1]				;\
	set	FIRE_PLC_TLU_CTB_TLR_TUE_HDR2, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
9:									;\
	.poplocals							;\
	stx	tmp1, [FIRE_rpt + PCIERPT_HDR2]


#define	LOG_TLU_UE_TRANS_EPKT_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	.pushlocals							;\
	set	TLU_CTO_P, tmp2						;\
	btst	tmp2, tmp1						;\
	bnz,a,pn %xcc, 1f						;\
	clr	tmp1							;\
	ba,a	8f							;\
1:									;\
	set	(PCI | READ | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	COMPLETION_TIMEOUT, tmp1				;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_ERROR_TYPE]			;\
8:									;\
	.poplocals


#define	LOG_TLU_UE_FCP_EPKT_P_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1,	[FIRE_rpt +  PCIERPT_SUN4V_DESC]		;\
	set	FLOW_CONTROL_ERROR, tmp1				;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_ERROR_TYPE]

#define	LOG_TLU_UE_CA_EPKT_P_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1,   [FIRE_rpt +  PCIERPT_SUN4V_DESC]		;\
	set	COMPLETER_ABORT, tmp1					;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_ERROR_TYPE]

#define	LOG_TLU_UE_DLP_EPKT_P_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_ERROR_TYPE]


#define	LOG_TLU_UE_TE_EPKT_P_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [FIRE_rpt +  PCIERPT_ERROR_TYPE]

#define	CLEAR_TLU_UE_FCP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
        set     FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_FCP_P, tmp1						;\
        stx     tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_FCP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
        set     FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_FCP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
        stx     tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_CA_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
        set     FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_CA_P, tmp1						;\
        stx     tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_CA_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
        set     FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_CA_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
        stx     tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_TE_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	/* clear the dup */						;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT, tmp2		;\
	set	LPU_PHY_INT_TRN_ERR, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_TE_P, tmp1						;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]


#define	CLEAR_TLU_UE_TE_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	/* clear the dup */						;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT, tmp2		;\
	set	LPU_PHY_INT_TRN_ERR, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_TE_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_DLP_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	/* clear the dup */						;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, tmp2		;\
	set	LPU_LLI_INT_DLNK_PES, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_DLP_P, tmp1						;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_DLP_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	;\
	/* clear the dup */						;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, tmp2		;\
	set	LPU_LLI_INT_DLNK_PES, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_DLP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_RECV_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_UE_RECV_GROUP_P, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_RECV_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_UE_RECV_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_TLU_UE_TRANS_HDR_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_TUE_HDR1, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_TRANS_UE_ERR_HDR1_LOG]	;\
	set	FIRE_PLC_TLU_CTB_TLR_TUE_HDR2, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_TRANS_UE_ERR_HDR2_LOG]


#define	CLEAR_TLU_UE_TRANS_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_UE_TRANS_GROUP_P, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_UE_TRANS_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_UE_ERR_RW1C_ALIAS, tmp2		;\
	set	TLU_UE_TRANS_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

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

#define FILL_PCIE_HDR_FIELDS_FROM_ERR_LOG(FIRE_E_rpt,			\
			FIRE_LEAF_BASE_ADDRx, REG1, REG2, ERR_LOG_REG)	\
	set	ERR_LOG_REG, REG1					;\
	ldx	[FIRE_LEAF_BASE_ADDRx + REG1], REG2			;\
	/* move LRtB into right place */				;\
	srlx	REG2, 16, REG1						;\
	sllx	REG1, (63-41), REG1					;\
	srlx	REG1, (63-41), REG1					;\
	/* move T into right place */					;\
	srlx	REG2, 58, REG2						;\
	sllx	REG2, 56, REG2						;\
	add	REG2, REG1, REG1					;\
	stx	REG1, [FIRE_E_rpt + PCIERPT_HDR1]
/*
 * Bit 8
 */
#define	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | ILL | DIR_IRRELEVANT | 	\
							H), tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	FILL_PCIE_HDR_FIELDS_FROM_ERR_LOG(FIRE_rpt, FIRE_LEAF_BASE_ADDR,\
		 tmp1, tmp2, FIRE_DLC_IMU_ICS_IMU_SCS_ERROR_LOG_REG);

#define	LOG_IMU_EQ_NOT_EN_GROUP_EPKT_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | ILL | DIR_IRRELEVANT),	\
								tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]

#define	LOG_IMU_EQ_OVER_GROUP_EPKT_P_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set 	(INTR | MSIQ | PHASE_UNKNOWN | OV | DIR_IRRELEVANT), 	\
								tmp1	;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]


#define	IMU_RDS_ERR_LOG_MSIINFO_SHIFT	(58)
#define	MSI64BITPATTERN			(0x78) /* 1111000 64 bit msi */
#define	MSI32BITPATTERN			(0x2c) /* 1011000 32 bit msi */

#define	LOG_IMU_MSI_MES_GROUP_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	.pushlocals							;\
	set	FIRE_DLC_IMU_ICS_IMU_ENABLED_ERROR_STATUS_REG, tmp2	;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
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
	ldx	[FIRE_rpt + PCIERPT_IMU_RDS_ERR_LOG], tmp1		;\
	srlx	tmp1, IMU_RDS_ERR_LOG_MSIINFO_SHIFT, tmp1		;\
	cmp	tmp1, MSI64BITPATTERN	/* is it 1111000 - 64 bit msi */;\
	bne,pn %xcc, 1f							;\
	nop								;\
	set	(INTR | MSI64| PHASE_UNKNOWN | ILL | H), tmp1		;\
	ba	8f							;\
	  sllx  tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	set	(INTR | MSI32| PHASE_UNKNOWN | ILL | H), tmp1		;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(INTR | PCIEMSG | PHASE_UNKNOWN | ILL | INGRESS | H),	\
								 tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	ldx	[FIRE_rpt + PCIERPT_IMU_RDS_ERR_LOG], tmp1		;\
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
	ldx	[FIRE_rpt + PCIERPT_IMU_RDS_ERR_LOG], tmp1		;\
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
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	FILL_PCIE_HDR_FIELDS_FROM_ERR_LOG(FIRE_rpt, FIRE_LEAF_BASE_ADDR,\
		tmp1, tmp2, FIRE_DLC_IMU_ICS_IMU_RDS_ERROR_LOG_REG)	;\
9:									;\
	.poplocals

/*
 * bit 17, TLU_ROF_P   PCI | INGRESS | U | H | I
 *	UE/CE Regs = Receiver Overflow, PCIe Status = IS
 * bit 20, TLU_UR_P     PCI | INGRESS | U | H | I
 * 			UE/CE Regs = Unsupported Request, PCIe Status = IS
 */
#define	LOG_TLU_UE_RECV_GROUP_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | INGRESS | U | H | I), tmp1			;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_EN_ERR, tmp1			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp1], tmp2			;\
	.pushlocals							;\
	set	TLU_UR_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	TLU_UC_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	TLU_MFP_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	.empty								;\
	set	TLU_PP_P, tmp1						;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 4f						;\
	.empty								;\
	set	TLU_ROF_P, tmp1						;\
	btst    tmp1, tmp2						;\
	bnz	%xcc, 5f						;\
	clr	tmp2							;\
	ba,a	9f							;\
	  .empty							;\
1:									;\
	set	UNSUPPORTED_REQUEST, tmp1				;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	UNEXPECTED_COMPLETION, tmp1				;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
3:									;\
	set	MALFORMED_TLP, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
4:									;\
	set	DP, tmp1						;\
	add	tmp1, IS, tmp1						;\
	/* rewrite the 4 bytes containing the PCIe err status */	;\
	/* to include the Detected Parity bit */			;\
	stuw	tmp1, [FIRE_rpt + (PCIERPT_SUN4V_DESC + 4)]		;\
	set	POISONED_TLP, tmp1					;\
	ba	8f							;\
	   stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
5:									;\
	set	RECEIVER_OVERFLOW, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	set	FIRE_PLC_TLU_CTB_TLR_RUE_HDR1, tmp1			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp1], tmp2			;\
	stx	tmp2, [FIRE_rpt + PCIERPT_HDR1]				;\
	set	FIRE_PLC_TLU_CTB_TLR_RUE_HDR2, tmp1			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp1], tmp2			;\
9:									;\
	.poplocals							;\
	stx	tmp2, [FIRE_rpt + PCIERPT_HDR2]


/*
 * no header info fopr secondary errors
 */
#define	LOG_TLU_UE_RECV_GROUP_EPKT_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	(PCI | INGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	FIRE_PLC_TLU_CTB_TLR_UE_EN_ERR, tmp1			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp1], tmp2			;\
	.pushlocals							;\
	set	TLU_UR_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	TLU_UC_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	TLU_MFP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	.empty								;\
	set	TLU_PP_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 4f						;\
	set	TLU_ROF_P, tmp1						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 5f						;\
	clr	tmp2							;\
	ba,a	8f							;\
	  .empty							;\
1:									;\
	set	UNSUPPORTED_REQUEST, tmp1				;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	UNEXPECTED_COMPLETION, tmp1				;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
3:									;\
	set	MALFORMED_TLP, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
4:									;\
	set	DP, tmp1						;\
	add	tmp1, IS, tmp1						;\
	/* rewrite the 4 bytes containing the PCIe err status */	;\
	/* to include the Detected Parity bit */			;\
	stuw	tmp1, [FIRE_rpt + (PCIERPT_SUN4V_DESC + 4)]		;\
	set	POISONED_TLP, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
5:									;\
	set	RECEIVER_OVERFLOW, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	.poplocals

#define	LOG_TLU_CE_GROUP_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	set	FIRE_PLC_TLU_CTB_TLR_CE_LOG, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_CE_LOG_ENABLE]		;\
	set	FIRE_PLC_TLU_CTB_TLR_CE_INT_EN, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_CE_INTERRUPT_ENABLE]	;\
	set	FIRE_PLC_TLU_CTB_TLR_CE_ERR_RW1S_ALIAS, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_CE_STATUS]

/*
 * Dup bits for figure 1-11 bits 12, 8:6 of thr LPU LLI
 */
#define	CE_DUPS_FOR_BITS_12_8_7_6_OF_LPU_LLI	(LPU_LLI_INT_RPLAY_NUM_RO | \
		LPU_LLI_INT_RPLAY_TMR_TO | LPU_LLI_INT_BAD_TLP | \
		LPU_LLI_INT_BAD_DLLP)
/*
 * bit 0 dup bits
 * 21 and 18 of the LPU LLI
 */
#define	CE_DUPS_FOR_BIT_0_LPU_LLI	(LPU_LLI_INT_TLP_RCV_ERR | \
						LPU_LLI_INT_DLLP_RCV_ERR)
/*
 * and the other bit 0 dups 11:9 and 7:0,
 * the third draft of PRM has bits 13, and 12 listed
 * the prm is wrong
 */
#define	CE_DUPS_FOR_BIT_O_LPU_PHY	(LPU_PHY_INT_ILL_STP_POS | \
		 LPU_PHY_INT_ILL_SDP_POS | LPU_PHY_INT_MULTI_STP | \
		 LPU_PHY_INT_MULTI_SDP | LPU_PHY_INT_INVLD_CHAR_ERR | \
		 LPU_PHY_INT_STP_END_EDB | LPU_PHY_INT_SDP_END | \
		 LPU_PHY_INT_EDB_DET |  LPU_PHY_INT_LNK_ERR | \
		 LPU_PHY_INT_ILL_END_POS_ERR | LPU_PHY_INT_KCHAR_DLLP_ERR)

#define	CLEAR_TLU_CE_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	/* clear any dups for bits 12, 8:6 */				;\
	set	CE_DUPS_FOR_BITS_12_8_7_6_OF_LPU_LLI, tmp1		;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	/* clear any dups for bit 0 */					;\
	set	CE_DUPS_FOR_BIT_0_LPU_LLI, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	CE_DUPS_FOR_BIT_O_LPU_PHY, tmp1				;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	TLU_CE_GROUP_P, tmp1					;\
	set	FIRE_PLC_TLU_CTB_TLR_CE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_CE_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)	\
	/* clear any dups for bits 12, 8:6 */				;\
	set	CE_DUPS_FOR_BITS_12_8_7_6_OF_LPU_LLI, tmp1		;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	/* clear any dups for bit 0 */					;\
	set	CE_DUPS_FOR_BIT_0_LPU_LLI, tmp1				;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	CE_DUPS_FOR_BIT_O_LPU_PHY, tmp1				;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]			;\
	set	TLU_CE_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	FIRE_PLC_TLU_CTB_TLR_CE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_TLU_CE_GROUP_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	.pushlocals							;\
	set	FIRE_PLC_TLU_CTB_TLR_CE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	TLU_CE_RTO_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	TLU_CE_RNR_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	TLU_CE_BDP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	btst	TLU_CE_BTP_P, tmp2					;\
	bnz	%xcc, 4f						;\
	  .empty							;\
	set	(PCI | INGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	RECEIVER_ERROR, tmp2					;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
1:									;\
	set	(PCI | EGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_TIMER_TIMEOUT, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	(PCI | EGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_NUM_ROLLOVER, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
3:									;\
	set	(PCI | INGRESS), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_DLLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
4:									;\
	set	(PCI | INGRESS), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_TLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	.poplocals


#define	LOG_TLU_CE_GROUP_EPKT_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	.pushlocals							;\
	set	FIRE_PLC_TLU_CTB_TLR_CE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	TLU_CE_RTO_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	.empty								;\
	set	TLU_CE_RNR_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	.empty								;\
	set	TLU_CE_BDP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	TLU_CE_BTP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 4f						;\
	  .empty							;\
	set	(PCI | INGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	RECEIVER_ERROR, tmp2					;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
1:									;\
	set	(PCI | EGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_TIMER_TIMEOUT, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	(PCI | EGRESS | C), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	REPLAY_NUM_ROLLOVER, tmp2				;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
3:									;\
	set	(PCI | INGRESS), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_DLLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	ba	8f							;\
	  stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
4:									;\
	set	(PCI | INGRESS), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	set	BAD_TLP, tmp2						;\
	sllx	tmp2, ALIGN_TO_64, tmp2					;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	.poplocals

#define	LOG_TLU_OE_GROUP_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1, tmp2)\
	set	FIRE_PLC_TLU_CTB_TLR_OE_LOG, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_OTHER_EVENT_LOG_ENABLE]	;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1S_ALIAS, tmp2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIE_ERR_TLU_OTHER_EVENT_STATUS_SET]  ;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_INT_EN, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_OTHER_EVENT_INTR_ENABLE]	;\

#define	LOG_TLU_OE_INTR_STATUS_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
							 tmp2, MASK)	\
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	MASK, tmp2						;\
	and	tmp1, tmp2, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_OTHER_EVENT_INTR_STATUS]	;\

#define	LOG_TLU_OE_INTR_STATUS_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
						 tmp2, INTR_MASK)	\
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	INTR_MASK, tmp2						;\
	sllx	tmp2, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp2		;\
	and	tmp1, tmp2, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_OTHER_EVENT_INTR_STATUS]	;\

#define	LOG_TLU_OE_RECV_GROUP_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_ROE_HDR1, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_RCV_OTHER_EVENT_HDR1_LOG]	;\
	set	FIRE_PLC_TLU_CTB_TLR_ROE_HDR2, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_RCV_OTHER_EVENT_HDR2_LOG]

#define	CLEAR_TLU_OE_RECV_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	TLU_OE_RECEIVE_GROUP_P, tmp1				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_OE_RECV_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	TLU_OE_RECEIVE_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_OE_DUP_LLI_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								tmp2)	;\
	set	TLU_OE_DUP_LLI_P, tmp1					;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_OE_DUP_LLI_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								tmp2)	;\
	set	TLU_OE_DUP_LLI_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_OE_NO_DUP_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	TLU_OE_NO_DUP_GROUP_P, tmp1				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	CLEAR_TLU_OE_NO_DUP_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	TLU_OE_NO_DUP_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_TLU_OE_TRANS_GROUP_REGS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,\
								 tmp2)	\
	set	FIRE_PLC_TLU_CTB_TLR_TOE_HDR1, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_TRANS_OTHER_EVENT_HDR1_LOG];\
	set	FIRE_PLC_TLU_CTB_TLR_TOE_HDR2, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_TLU_TRANS_OTHER_EVENT_HDR2_LOG]

#define	LOG_TLU_OE_TRANS_GROUP_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	TLU_O_WUC_P, tmp1					;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	set	TLU_O_RUC_P, tmp1					;\
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
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	(PCI | READ | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	.poplocals							;\
	nop

#define	LOG_TLU_OE_TRANS_GROUP_EPKT_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR,	\
							 tmp1, tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	TLU_O_WUC_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	set	TLU_O_RUC_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
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
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	(PCI | READ | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	COMPLETER_ABORT, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	.poplocals							;\
	nop

#define	CLEAR_TLU_OE_TRANS_GROUP_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	TLU_OE_TRANS_GROUP_P, tmp1				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]


#define	CLEAR_TLU_OE_TRANS_GROUP_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	set	TLU_OE_TRANS_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, tmp2		;\
	stx	tmp1, [FIRE_LEAF_BASE_ADDR + tmp2]

#define	LOG_TLU_OE_NO_DUP_EPKT_P_S(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								 tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, tmp2			;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	TLU_O_IIP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	.pushlocals							;\
	bnz	%xcc, 1f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 1f						;\
	set	TLU_O_EDP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	set	TLU_O_EHP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 2f						;\
	set	TLU_O_LRS_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	TLU_O_LDN_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	set	TLU_O_LUP_P, tmp1					;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	btst	tmp1, tmp2						;\
	bnz	%xcc, 3f						;\
	clr	tmp1							;\
	ba,a	8f							;\
	  .empty							;\
1:									;\
	set	(PCI | INGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
2:									;\
	set	(PCI | EGRESS | U), tmp1				;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	ba	8f							;\
	  stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
3:									;\
	set	(PCI | LINK | U), tmp1					;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	tmp1, IS, tmp1						;\
	add	tmp1, ST, tmp1						;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	DATA_LINK_ERROR, tmp1					;\
	stx	tmp1, [FIRE_rpt + PCIERPT_ERROR_TYPE]			;\
8:									;\
	.poplocals							;\
	nop

/* LPU Link Performance Counter Control register (0x6e2110, 7e2110) */
#define	SET_PERF_CNTR2_OVER_FLOW	(1LL <<  6)
#define	SET_PERF_CNTR1_OVER_FLOW	(1LL <<  5)
#define	RST_PERF_CNTR2_OVER_FLOW	(1LL <<  3)
#define	RST_PERF_CNTR2			(1LL <<  2)
#define	RST_PERF_CNTR1_OVER_FLOW	(1LL <<  1)
#define	RST_PERF_CNTR1			(1LL <<  0)

#define	LOG_PCIERPT_LPU_INTR_STATUS(FIRE_rpt, FIRE_LEAF_BASE_ADDR, LOGBIT, \
							scr1, scr2)	\
	set	LOGBIT, scr1						;\
	stx	scr1, [FIRE_rpt + PCIERPT_LPU_INTR_STATUS]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR2(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR2, scr2	;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + 				\
					PCIE_ERR_LPU_LINK_PERF_COUNTER2]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1, scr2	;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + 				\
					PCIE_ERR_LPU_LINK_PERF_COUNTER1]

#define	CLEAR_PERF_CNTR_2_OVFLW(FIRE_rpt, FIRE_LEAF_BASE_ADDR, 	\
								scr1, scr2)\
	set	RST_PERF_CNTR2_OVER_FLOW, scr2				;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR_CTL, scr1	;\
	stx	scr2, [FIRE_LEAF_BASE_ADDR + scr1]

#define	CLEAR_PERF_CNTR_1_OVFLW(FIRE_rpt, FIRE_LEAF_BASE_ADDR,		 \
								scr1, scr2)\
	set	RST_PERF_CNTR1_OVER_FLOW, scr2				;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR_CTL, scr1	;\
	stx	scr2, [FIRE_LEAF_BASE_ADDR + scr1]


/* LPU Link Layer Interrupt and Status Register clear bits */
#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT_CLR_BITS	\
	(		\
	(1LL << 22) |	\
	(1LL << 21) |	\
	(1LL << 20) |	\
	(1LL << 18) |	\
	(1LL << 17) |	\
	(1LL << 16) |	\
	(1LL <<  9) |	\
	(1LL <<  8) |	\
	(1LL <<  7) |	\
	(1LL <<  6) |	\
	(1LL <<  5) |	\
	(1LL <<  4) |	\
	(1LL <<  2) |	\
	(1LL <<  1) |	\
	(1LL <<  0)	)

#define	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT_CLR_BITS, scr1	;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, scr2		;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + scr2]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT(FIRE_rpt,		\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, scr2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_rpt + 				\
			PCIERPT_LPU_LINK_LAYER_INTERRUPT_AND_STATUS]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT(FIRE_rpt,		\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT, scr2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_rpt + PCIERPT_LPU_PHY_ERR_INT]

#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT_CLR_BITS	\
	(		\
	(1LL << 11) |	\
	(1LL << 10) |	\
	(1LL <<  9) |	\
	(1LL <<  8) |	\
	(1LL <<  7) |	\
	(1LL <<  6) |	\
	(1LL <<  5) |	\
	(1LL <<  4) |	\
	(1LL <<  3) |	\
	(1LL <<  2) |	\
	(1LL <<  1) |	\
	(1LL <<  0)	)

#define	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_INT_CLR_BITS, scr1;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_ERR_INT, scr2		;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + scr2]

#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CLR_BITS	\
	(		\
	(1LL << 15) |	\
	(1LL << 14) |	\
	(1LL << 13) |	\
	(1LL << 12) |	\
	(1LL << 11) |	\
	(1LL << 10) |	\
	(1LL <<  9) |	\
	(1LL <<  8) |	\
	(1LL <<  7) |	\
	(1LL <<  6) |	\
	(1LL <<  5) |	\
	(1LL <<  4) |	\
	(1LL <<  3) |	\
	(1LL <<  2) |	\
	(1LL <<  1) |	\
	(1LL <<  0)	)


#define	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM(FIRE_rpt,		\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CLR_BITS, scr1	;\
	set	 FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_INT, scr2		;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + scr2]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM(FIRE_rpt,		\
				 FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	 FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_INT, scr2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_rpt + PCIERPT_LPU_LTSSM_STATUS]


#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT_CLR_BITS	\
	(		\
	(1LL << 11) |	\
	(1LL << 10) |	\
	(1LL <<  9) |	\
	(1LL <<  8) |	\
	(1LL <<  7) |	\
	(1LL <<  6) |	\
	(1LL <<  5) |	\
	(1LL <<  4) |	\
	(1LL <<  3) |	\
	(1LL <<  2) |	\
	(1LL <<  1) |	\
	(1LL <<  0)	)

#define	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT_CLR_BITS, scr1;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT, scr2		;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + scr2]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT(FIRE_rpt,		\
				 FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_INT, scr2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_rpt + PCIERPT_LPU_TX_PHY_INT]

#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT_CLR_BITS	\
	(		\
	(1LL <<  2) |	\
	(1LL <<  1) |	\
	(1LL <<  0)	)

#define	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT_CLR_BITS, scr1;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT, scr2		;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + scr2]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT(FIRE_rpt,		\
				 FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_INT, scr2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_rpt + PCIERPT_LPU_RX_PHY_INT]

/* bits 23:16 and 15:0 */
#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_PHY_INT_CLR_BITS	\
	(		\
	(  0xFFLL << 16) |	\
	(0xFFFFLL <<  0)	)

#define	CLEAR_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_PHY_INT(FIRE_rpt,	\
				FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_PHY_INT_CLR_BITS, scr1;\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_GL_INT, scr2		;\
	stx	scr1, [FIRE_LEAF_BASE_ADDR + scr2]

#define	LOG_FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_PHY_INT(FIRE_rpt,		\
				 FIRE_LEAF_BASE_ADDR, scr1, scr2)	\
	set	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_GL_INT, scr2		;\
	ldx	[FIRE_LEAF_BASE_ADDR + scr2], scr1			;\
	stx	scr1, [FIRE_rpt + PCIERPT_LPU_GB_PHY_INT]

/*
 * log MMU header and addr fields for the errors that need them
 */
#define	MMU_FAULT_LOGGING_GROUP		(MMU_TBW_DPE_P | MMU_TBW_ERR_P | \
					 MMU_TBW_UDE_P | MMU_TBW_DME_P | \
					 MMU_TTE_PRT_P | MMU_TTE_INV_P | \
					 MMU_TRN_OOR_P | MMU_TRN_ERR_P | \
					 MMU_BYP_OOR_P | MMU_BYP_ERR_P)

#define	LOG_MMU_FAULT_ADDR_AND_FAULT_STATUS(FIRE_E_rpt,			\
				FIRE_LEAF_BASE_ADDRx, REG1, REG2)	\
	set	FIRE_DLC_MMU_FLTA, REG1					;\
	ldx	[FIRE_LEAF_BASE_ADDRx + REG1], REG2			;\
	/* bits 63:2 hold the va, align value for ereport */		;\
	srlx	REG2, 2, REG2						;\
	sllx	REG2, 2, REG2						;\
	stx	REG2, [FIRE_E_rpt + PCIERPT_WORD4]			;\
	sllx	REG2, 32, REG2						;\
	stx	REG2, [FIRE_E_rpt + PCIERPT_HDR2]			;\
	set	FIRE_DLC_MMU_FLTS, REG1					;\
	ldx	[FIRE_LEAF_BASE_ADDRx + REG1], REG2			;\
	/* bits 22:16 hold transaction type move to 62:56 */		;\
	srlx	REG2, 16, REG2						;\
	sllx	REG2, 56, REG2						;\
	ldx	[FIRE_LEAF_BASE_ADDRx + REG1], REG1			;\
	/* bits 15:0 hold BDF, move to 31:16, zero upper 32 bits */	;\
	sllx	REG1, (63 - 15), REG1					;\
	srlx	REG1, 32, REG1						;\
	and	REG1, REG2, REG1					;\
	stx	REG2, [FIRE_E_rpt + PCIERPT_HDR1]

#define	LOG_MMU_ERR_GROUP_EPKT_P(FIRE_rpt, FIRE_LEAF_BASE_ADDR, tmp1,	\
								tmp2)	\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_DLC_MMU_EN_ERR, tmp2				;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	.pushlocals							;\
	btst	MMU_BYP_ERR_P, tmp1					;\
	bnz	%xcc, 1f						;\
	btst	MMU_BYP_OOR_P, tmp1					;\
	bnz	%xcc, 2f						;\
	btst	MMU_TTE_INV_P, tmp1					;\
	bnz	%xcc, 4f						;\
	btst	MMU_TTE_PRT_P, tmp1					;\
	bnz	%xcc, 5f						;\
	btst	MMU_TTC_DPE_P, tmp1					;\
	bnz	%xcc, 6f						;\
	btst	MMU_TTC_CAE_P, tmp1					;\
	bnz	%xcc, 7f						;\
	nop								;\
	ba,a	8f							;\
	  .empty							;\
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
	set	(MMU | TRANSLATION | ADDR | ILL | RDRW | D | H), tmp1	;\
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
	set	(MMU | TRANSLATION | ADDR | PHASE_IRRELEVANT| \
						DIR_IRRELEVANT), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
7:									;\
	set 	(MMU | TRANSLATION | PDATA | COND_IRRELEVENT | \
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
	clr	tmp1							;\
	ba,a	1f							;\
	  .empty							;\
2:									;\
	set	(MMU | TABLEWALK | PHASE_UNKNOWN | ILL | \
					DIR_IRRELEVANT | D | H), tmp1	;\
	ba	1f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(MMU | TABLEWALK | PHASE_UNKNOWN | COND_UNKNOWN | \
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
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
1:									;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]			;\
	set	FIRE_DLC_MMU_EN_ERR, tmp2				;\
	ldx	[FIRE_LEAF_BASE_ADDR + tmp2], tmp1			;\
	set	MMU_FAULT_LOGGING_GROUP, tmp2				;\
	btst	tmp2, tmp1						;\
	bz	%xcc, 1f						;\
	  .empty							;\
	LOG_MMU_FAULT_ADDR_AND_FAULT_STATUS(FIRE_rpt, FIRE_LEAF_BASE_ADDR,\
							tmp1, tmp2);	;\
1:									;\
	.poplocals

/* Mondo 63 related macro's */
#define	LOG_JBUS_FATAL_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_FATAL_ERROR_LOG_REG_1, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_FATAL_ERR_LOG_REG_1]		;\
	set	FIRE_FATAL_STATE_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_FATAL_ERR_LOG_REG_2]

#define	CLEAR_JBUS_FATAL_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1, tmp2)	\
	setx	JBC_FATAL_GROUP, tmp2, tmp1				;\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]


#define	LOG_DMCINT_ODC_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_DMCINT_ODCD_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	and	tmp2, DMCINT_IDC_GROUP_P, tmp1				;\
	stx	tmp1, [FIRE_rpt + PCIERPT_DMCINT_ODCD_ERR_LOG]

#define	CLEAR_DMCINT_ODC_P(FIRE_rpt, JBUS_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	DMCINT_ODC_GROUP_P, tmp1				;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

/*
 * jbc_core_and_block_err_status = reg1
 * bit 8, PIO_UNMAP_P     HOSTBUS | PIO | ADDR | UNMAP | WRITE | M
 * bit 7, PIO_DPE_P       HOSTBUS | PIO | PDATA | INT | WRITE | M
 * bit 5, ILL_ACC_P       HOSTBUS | PIO | PHASE_UNKNOWN | ILL | WRITE | M
 * bit 27, ILL_ACC_RD_P   HOSTBUS | PIO | PHASE_UNKNOWN | ILL | READ | M
 * bit 28, PIO_UNMAP_RD_P HOSTBUS | PIO | ADDR | UNMAP | READ | M
 *
 * reg1 = jbc_core_and_block_err_status
 */
#define	LOG_DMCINT_ODC_EPKT_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	.pushlocals							;\
	set	FIRE_DMCINT_ODCD_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
1:									;\
	btst	PIO_UNMAP_P, reg1					;\
	bnz	%xcc, 1f						;\
	btst	PIO_DPE_P, reg1						;\
	bnz	%xcc, 2f						;\
	btst	ILL_ACC_P, reg1						;\
	bnz	%xcc, 3f						;\
	.empty								;\
	set	ILL_ACC_RD_P, tmp1					;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 4f						;\
	.empty								;\
	set	PIO_UNMAP_RD_P, tmp1					;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 5f						;\
	clr	tmp1							;\
	ba	8f							;\
	  clr	tmp2							;\
1:									;\
	set	(HOSTBUS | PIO | ADDR | UNMAP | WRITE | M), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(HOSTBUS | PIO | PDATA | INT | WRITE | M), tmp1		;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(HOSTBUS | PIO | PHASE_UNKNOWN | ILL | WRITE | M), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(HOSTBUS | PIO | PHASE_UNKNOWN | ILL | READ | M), tmp1	;\
	ba	8f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(HOSTBUS | PIO | ADDR | UNMAP | READ | M), tmp1		;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
8:									;\
	.poplocals							;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_PADDR]			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]



#define	CLEAR_DMCINT_ODC_S(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	DMCINT_ODC_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]


#define	LOG_DMCINT_IDC_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_DMCINT_IDC_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_DMCINT_IDC_ERR_LOG]

#define	CLEAR_DMCINT_IDC_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	DMCINT_IDC_GROUP_P, tmp1				;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	CLEAR_DMCINT_IDC_S(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	DMCINT_IDC_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	LOG_JBCINT_IN_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1 tmp2)		\
	set	FIRE_JBCINT_IN_TRAN_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_JBCINT_IN_TRANS_ERR_LOG]	;\
	set	FIRE_JBCINT_IN_STATE_ERROR_LOG_REG, tmp1		;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_JBCINT_IN_TRANS_ERR_LOG_REG_2]

#define	CLEAR_JBCINT_IN_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp1	;\
	add	JBUS_BASE_ADDR, tmp1, tmp2				;\
	set	JBUSINT_IN_GROUP_P, tmp1				;\
	stx	tmp1, [tmp2]

/*
 * bit 22, UE_ASYN_P   hostbus/dma/data/ue/read/MS, size = 64byte;
 * bit 20, JTE_P       OS Needs to panic, not hypervisor
 * bit 19, JBE_P       HOSTBUS | DMA | PHASE_UNKNOWN | COND_UNKNOWN
 * bit 18, JUE_P       HOSTBUS | OP_UNKNOWN | ADDR | UNMAP | RDRW | M
 * bit 16, ICISE_P     HOSTBUS | DMA | PDATA | UE | READ | M
 * bit 13, WR_DPE_P    HOSTBUS | PIO | PDATA | INT | WRITE | M
 * bit 12, RD_DPE_P    HOSTBUS | PIO | PDATA | INT | READ | M
 * bit 11, ILL_BMW_P   HOSTBUS | PIO | PDATA | ILL | WRITE | M
 * bit 10, ILL_BMR_P   HOSTBUS | PIO | PDATA | ILL | WRITE | M
 */
#define	LOG_JBCINT_IN_EPKT_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)\
	.pushlocals							;\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_JBCINT_IN_TRAN_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	/* strip off upper bits, leaving address */			;\
	FIRE_JBCINT_IN_TRAN_ERROR_LOG_ADDR_BITS(tmp2)			;\
	btst	ILL_BMR_P, reg1						;\
	bnz	%xcc, 1f						;\
	set	ILL_BMW_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 1f						;\
	set	RD_DPE_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, bit_RD_DPE_P					;\
	set	ICISE_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	2f							;\
	set	WR_DPE_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 3f						;\
	set	JUE_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 4f						;\
	set	JBE_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 5f						;\
	set	JTE_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 6f						;\
	set	UE_ASYN_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 7f						;\
	set	IJP_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 8f						;\
	clr	tmp1							;\
	ba	9f							;\
	  clr	tmp2							;\
1:									;\
	set	(HOSTBUS | PIO | PDATA | ILL | WRITE | M), tmp1		;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
bit_RD_DPE_P:								;\
	set	(HOSTBUS | PIO | PDATA | INT | READ | M), tmp1		;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
2:									;\
	set	(HOSTBUS | DMA | PDATA | UE | READ | M), tmp1		;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
3:									;\
	set	(HOSTBUS | PIO | PDATA | INT | WRITE | M), tmp1		;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
4:									;\
	set	(HOSTBUS | OP_UNKNOWN | ADDR | UNMAP | RDRW | M), tmp1	;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
5:									;\
	set	(HOSTBUS | DMA | PHASE_UNKNOWN | COND_UNKNOWN), tmp1	;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
6:									;\
	set	(HOSTBUS | OP_UNKNOWN | PDATA | UE | COND_IRRELEVENT),	\
								tmp1	;\
	ba	9f							;\
	  sllx	tmp1, ALIGN_TO_64, tmp1					;\
7:									;\
	set	(HOSTBUS | DMA | PDATA | UE | READ | M | S), tmp1	;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	ba	9f							;\
	  add	64, tmp1, tmp1						;\
8:									;\
	set	(HOSTBUS | DMA | ADDR | ILL | WRITE | M), tmp1		;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
9:									;\
	.poplocals							;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_PADDR]			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]


#define	CLEAR_JBCINT_IN_S(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	JBUSINT_IN_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	LOG_JBCINT_OUT_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1, tmp2)	\
	set	FIRE_JBCINT_OUT_TRAN_ERROR_LOG_REG, tmp1		;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_JBCINT_OUT_TRANS_ERR_LOG]	;\
	set	FIRE_JBCINT_OUT_STATE_ERROR_LOG_REG, tmp1		;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_JBCINT_OUT_TRANS_ERR_LOG_REG_2]

/*
 * bit 17, IJP_P       HOSTBUS | DMA | ADDR | ILL | WRITE | M
 */
#define	LOG_JBCINT_OUT_EPKT_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)\
	.pushlocals							;\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_JBCINT_OUT_TRAN_ERROR_LOG_REG, tmp1		;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	/* strip off upper bits, leaving address */			;\
	FIRE_JBCINT_OUT_TRAN_ERROR_LOG_ADDR_BITS(tmp2)		;\
	set	IJP_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 1f						;\
	clr	tmp1							;\
	ba	9f							;\
	  clr	tmp2							;\
1:									;\
	set	(HOSTBUS | DMA | ADDR | ILL | WRITE | M), tmp1		;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
9:									;\
	.poplocals							;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_PADDR]			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]


#define	CLEAR_JBCINT_OUT_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	JBUSINT_OUT_GROUP_P, tmp1				;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	CLEAR_JBCINT_OUT_S(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	JBUSINT_OUT_GROUP_P, tmp1				;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	LOG_MERGE_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1 tmp2)		\
	set	FIRE_MERGE_TRAN_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_MERGE_TRANS_ERR_LOG]

#define	CLEAR_MERGE_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	MERGE_GROUP_P, tmp1					;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

/*
 * bit 24, MB_PER_P    HOSTBUS | DMA | PDATA | INT | READ | M | S  size =64
 * bit 23, MB_PEW_P    HOSTBUS | DMA | PDATA | INT | WRITE | M | S  size =64
 */
#define	LOG_MERGE_ERROR_EPKT_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	.pushlocals							;\
	set	FIRE_MERGE_TRAN_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	set	MB_PER_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 1f						;\
	set	MB_PEW_P, tmp1						;\
	btst	tmp1, reg1						;\
	bnz	%xcc, 2f						;\
	clr	tmp1							;\
	ba	8f							;\
	  clr	tmp2							;\
1:									;\
	set	(HOSTBUS | DMA | PDATA | INT | READ | M | S), tmp1	;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	ba	8f							;\
	  add	64, tmp1, tmp1						;\
2:									;\
	set	(HOSTBUS | DMA | PDATA | INT | WRITE | M | S), tmp1	;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	add	64, tmp1, tmp1						;\
8:									;\
	.poplocals							;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_PADDR]			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]


#define	CLEAR_MERGE_S(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)	\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	MERGE_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	LOG_CSR_REGS(FIRE_rpt, JBUS_BASE_ADDR, tmp1 tmp2)		\
	set	FIRE_DMCINT_IDC_ERROR_LOG_REG, tmp1			;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	stx	tmp2, [FIRE_rpt + PCIERPT_CSR_ERR_LOG]

#define	CLEAR_CSR_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)		\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	CSR_GROUP_P, tmp1					;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	CLEAR_CSR_S(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)		\
	set	FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, tmp2	;\
	set	CSR_GROUP_P, tmp1					;\
	sllx	tmp1, PRIMARY_TO_SECONDARY_SHIFT_SZ, tmp1		;\
	stx	tmp1, [JBUS_BASE_ADDR + tmp2]

#define	EBUS_ADDRESS_SHIFT_SZ	(39)

/* bit 26, EBUS_TO_P   HOSTBUS | PIO | PHASE_UNKNOWN | TO | RDRW | M */
#define	LOG_CSR_ERRORS_P_EPKT_P(FIRE_rpt, JBUS_BASE_ADDR, reg1, tmp1, tmp2)\
	EPKT_FILL_HEADER(FIRE_rpt, tmp1);				;\
	set	FIRE_CSR_ERROR_LOG_REG, tmp1				;\
	ldx	[JBUS_BASE_ADDR + tmp1], tmp2				;\
	/* 25 bit address */						;\
	sllx	tmp2, EBUS_ADDRESS_SHIFT_SZ, tmp2			;\
	srlx	tmp2, EBUS_ADDRESS_SHIFT_SZ, tmp2			;\
	set	(HOSTBUS | PIO | PHASE_UNKNOWN | TO | RDRW | M), tmp1	;\
	sllx	tmp1, ALIGN_TO_64, tmp1					;\
	stx	tmp2, [FIRE_rpt + PCIERPT_ERROR_PADDR]			;\
	stx	tmp1, [FIRE_rpt + PCIERPT_SUN4V_DESC]
/* END CSTYLED */


#ifdef __cplusplus
}
#endif

#endif /* _ONTARIO_VPCI_ERRS_H */
