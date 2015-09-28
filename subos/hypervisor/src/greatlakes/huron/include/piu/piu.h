/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: piu.h
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

#ifndef _PIU_PIU_H
#define	_PIU_PIU_H

#pragma ident	"@(#)piu.h	1.3	07/07/17 SMI"


#ifdef __cplusplus
extern "C" {
#endif

#include <support.h>

#define	PIU_AID			0

#define	NPIUDEVINO		(64)
#define	PIU_DEVINO_MASK		(NPIUDEVINO - 1)
#define	PIU_DEVINO_SHIFT	6


#define	DMU_ADDR_BASE		0x8800000000
#define	DMU_INTERNAL_INT	62
#define	PEU_INTERNAL_INT	63
/* BEGIN CSTYLED */
#define	SET_PIU_ERROR_SYSINO(ino)			 \
	mov	PIU_AID << PIU_DEVINO_SHIFT, ino	;\
	or	ino, DMU_INTERNAL_INT, ino
/* END CSTYLED */

#define	PIU_EQ2INO(n)	(24+n)
#define	PIU_NEQS	36

#define	PIU_MAX_MSIS	256
#define	PIU_MSI_MASK	(PIU_MAX_MSIS - 1)

#define	PIU_MSIEQNUM_MASK	((xULL(1) << 6) - 1)

#define	PIU_EQREC_SHIFT	MSIEQ_REC_SHIFT
#define	PIU_EQREC_SIZE	MSIEQ_REC_SIZE
#define	PIU_NEQRECORDS	128

#define	PIU_EQSIZE	(PIU_NEQRECORDS * PIU_EQREC_SIZE)
#define	PIU_EQMASK	(PIU_EQSIZE - 1)

#define	NPIUINTRCONTROLLERS	4
#define	PIU_INTR_CNTLR_MASK	((xULL(1) << NPIUINTRCONTROLLERS) - 1)
#define	PIU_INTR_CNTLR_SHIFT	6

#define	INTRSTATE_MASK	0x1

#define	JPID_MASK	0x3f
#define	JPID_SHIFT	25

#define	PCI_CFG_OFFSET_MASK	((xULL(1) << 12) - 1)
#define	PCI_CFG_SIZE_MASK	7
#define	PCI_DEV_MASK		(((xULL(1) << 24) - 1)^((1 << 8) - 1))
#define	PCI_DEV_SHIFT		4

#define	JBUS_PA_SHIFT		40

#define	PIU_TTE_BDF_SHIFT	48
#define	PIU_TTE_DEV_KEY		(xULL(1) << 2)
#define	PIU_TTE_FNM_ALL		(0 << 3)
#define	PIU_TTE_FNM_2MSBS	(xULL(1) << 3)
#define	PIU_TTE_FNM_MSB		(xULL(3) << 3)
#define	PIU_TTE_FNM_NONE	(xULL(7) << 3)
#define	PIU_TTE_FNM_MASK	PIU_TTE_FNM_NONE

#define	TSB_SIZE_1K		0
#define	TSB_SIZE_2K		1
#define	TSB_SIZE_4K		2
#define	TSB_SIZE_8K		3
#define	TSB_SIZE_16K		4
#define	TSB_SIZE_32K		5
#define	TSB_SIZE_64K		6
#define	TSB_SIZE_128K		7
#define	TSB_SIZE_256K		8
#define	TSB_SIZE_512K		9

#define	IOMMU_SIZE(n)	(xULL(1) << ((n) + 10))

#define	IOTTE_SIZE		8
#define	IOTTE_SHIFT		3	/* log2(IOTTE_SIZE) */

#define	IOMMU_PAGESHIFT_8K	13
#define	IOMMU_PAGESHIFT_64K	16
#define	IOMMU_PAGESHIFT_4M	22
#define	IOMMU_PAGESHIFT_256M	28

#define	IOMMU_PAGESIZE(pshift)	(xULL(1) << (pshift))

#define	IOMMU_SPACE(tsbsize, pgshift)	(IOMMU_SIZE(tsbsize) <<	(pgshift))

#define	IOTSB_INDEX_MASK(tsbsize, pgshift) ((IOMMU_SPACE(tsbsize, pgshift)/\
		IOMMU_PAGESIZE(pgshift) - 1))

#define	IOTSB_SIZE(tsbsize, pgshift)	((IOMMU_SPACE(tsbsize, pgshift)/\
		IOMMU_PAGESIZE(pgshift)) * IOTTE_SIZE)

#define	IOTSB_PAGESIZE(n) (((n) - 13) / 3)

#define	IOTSB0_SIZE	IOTSB_SIZE(IOTSB0_TSB_SIZE, IOTSB0_PAGESHIFT)
#define	IOTSB0_PAGESIZE	IOTSB_PAGESIZE(IOTSB0_PAGESHIFT)
#define	IOTSB0_INDEX_MASK IOTSB_INDEX_MASK(IOTSB0_TSB_SIZE, IOTSB0_PAGESHIFT)

#define	IOTSB1_SIZE	IOTSB_SIZE(IOTSB1_TSB_SIZE, IOTSB1_PAGESHIFT)
#define	IOTSB1_PAGESIZE	IOTSB_PAGESIZE(IOTSB1_PAGESHIFT)
#define	IOTSB1_INDEX_MASK IOTSB_INDEX_MASK(IOTSB1_TSB_SIZE, IOTSB1_PAGESHIFT)

/*  2GB DVMA Space using 8K pages */
#define	IOTSB0			3
#define	IOTSB0_DVMA_BASE	2 GB
#define	IOTSB0_TSB_SIZE		TSB_SIZE_256K
#define	IOTSB0_PAGESHIFT	IOMMU_PAGESHIFT_8K
#define	IOTSB0_PAGE_MASK	((xULL(1) << IOTSB0_PAGESHIFT) - 1)

/*  64GB DVMA Space using 4M pages */
#define	IOTSB1			8
#define	IOTSB1_DVMA_BASE	64 GB
#define	IOTSB1_TSB_SIZE		TSB_SIZE_16K
#define	IOTSB1_PAGESHIFT	IOMMU_PAGESHIFT_4M
#define	IOTSB1_PAGE_MASK	((xULL(1) << IOTSB1_PAGESHIFT) - 1)

/* sun4v IOMMU IOTTE */
#define	PIU_IOTTE_V_SHIFT	0		/* data_v */
#define	PIU_IOTTE_V		(xULL(1) << PIU_IOTTE_V_SHIFT)
#define	PIU_IOTTE_W_SHIFT	1		/* data_w */
#define	PIU_IOTTE_W		(xULL(1) << PIU_IOTTE_W_SHIFT)
#define	PIU_IOTTE_KEY_V_SHIFT	2		/* key_valid */
#define	PIU_IOTTE_FNM_SHIFT	3		/* fnm */
#define	PIU_IOTTE_FNM_MASK	0x7
#define	PIU_IOTTE_DATA_SHIFT	6		/* data_soft */
#define	PIU_IOTTE_DATA_MASK	(xULL(0xbff) << PIU_IOTTE_DATA_SHIFT)
#define	PIU_IOTTE_PA_SHIFT	13		/* data_pa */
#define	PIU_IOTTE_PA_MASK	(xULL(0x3ffffff) << PIU_IOTTE_PA_SHIFT)
#define	PIU_IOTTE_KEY_SHIFT	48		/* dev_key */

/*
 * Create a sun4v mode IOMMU TTE for a given PA. We do not set
 * key_valid or fnm
 */
#define	PIU_IOTTE(pa)			\
	(((pa) & PIU_IOTTE_PA_MASK) | PIU_IOTTE_V | PIU_IOTTE_W)

#define	PIU_INTMR_V_SHIFT	31
#define	PIU_INTMR_MDO_MODE_SHIFT 63
#define	PIU_MSIMR_V_SHIFT	63
#define	PIU_MSIMR_EQWR_N_SHIFT	62
#define	PIU_MSGMR_V_SHIFT	63
#define	PIU_EQREC_TYPE_SHIFT	56
#define	PIU_EQCCR_E2I_SHIFT	47
#define	PIU_EQCCR_COVERR	57
#define	PIU_EQCSR_EN_SHIFT	44
#define	PIU_EQCSR_ENOVERR	57

#define	MSI_EQ_BASE_BYPASS_ADDR	(0xfffc000000000000LL)

#define	PIU_INTR_IDLE		0
#define	PIU_INTR_RECEIVED	3

#define	MSIEQ_RID_SHIFT	16
#define	MSIEQ_RID_SIZE_BITS 16

#define	MSIEQ_TID_SHIFT	16
#define	MSIEQ_TID_SIZE_BITS 8

#define	MSIEQ_MSG_RT_CODE_SHIFT 56
#define	MSIEQ_MSG_RT_CODE_SIZE_BITS 3

#define	MSIEQ_DATA_SHIFT	16
#define	MSIEQ_DATA_SIZE_BITS 16

#define	MSIEQ_MSG_CODE_SHIFT	0
#define	MSIEQ_MSG_CODE_SIZE_BITS 8

#define	PCIE_PME_MSG		0x18
#define	PCIE_PME_ACK_MSG	0x1b
#define	PCIE_CORR_MSG		0x30
#define	PCIE_NONFATAL_MSG	0x31
#define	PCIE_FATAL_MSG		0x33

#define	PIU_CORR_OFF		0x00
#define	PIU_NONFATAL_OFF	0x08
#define	PIU_FATAL_OFF		0x10
#define	PIU_PME_OFF		0x18
#define	PIU_PME_ACK_OFF		0x20

#define	PIU_MMU_CSR_TE		(1 << 0)	/* Translation Enable */
#define	PIU_MMU_CSR_BE		(1 << 1)	/* Bypass Enable */
#define	PIU_MMU_CSR_SUN4V_EN	(1 << 2)	/* sun4v enable */
/*
 * 0 = busid[6:1] for DEV2IOTSB index
 * 1 = busid[5:0] for DEV2IOTSB index
 */
#define	PIU_MMU_BUSID_SEL	(1 << 3)
#define	PIU_MMU_CSR_CM		(3 << 8)	/* Cache Mode */

/*
 * Note: This is essential to enable IOMMU Cache flushing functionality
 */
#define	PIU_MMU_CSR_SE		(1 << 10)	/* Snoop Enable */

#define	PIU_MMU_CSR_VALUE	(PIU_MMU_CSR_TE |	\
	    PIU_MMU_CSR_CM |				\
	    PIU_MMU_CSR_SE |				\
	    PIU_MMU_CSR_SUN4V_EN|			\
	    0)

#define	DEV2IOTSB_REG(n)	(PIU_DLC_MMU_CSR_A_DEV2IOTSB_ADDR+(8*(n)))
#define	IOTSBDESC_REG(n)	(PIU_DLC_MMU_CSR_A_IOTSBDESC_ADDR+(8*(n)))

#define	DEV2IOTSB(n)		\
	((n) << (0 << 3))	|\
	((n) << (1 << 3))	|\
	((n) << (2 << 3))	|\
	((n) << (3 << 3))	|\
	((n) << (4 << 3))	|\
	((n) << (5 << 3))	|\
	((n) << (6 << 3))	|\
	((n) << (7 << 3))

#define	IOTSB_BASE_PA_SHIFT	34
#define	IOTSB_V_SHIFT		63
#define	IOTSB0_VALID_BIT	(1 << IOTSB_V_SHIFT)
#define	IOTSB1_VALID_BIT	(1 << IOTSB_V_SHIFT)

#define	UNUSED_VALID_BIT	0
#define	UNUSED_SIZE		0
#define	UNUSED_PAGESIZE		0
#define	UNUSED_TSB_SIZE		0
#define	UNUSED_PAGESHIFT	0

/* BEGIN CSTYLED */
#define	IOTSBDESC(t)	((t/**/_VALID_BIT) |			\
	    ((IOMMU_SPACE(t/**/_TSB_SIZE, t/**/_PAGESHIFT) 	\
		>> (t/**/_PAGESHIFT)) << 7) |			\
	    ((t/**/_PAGESIZE) << 4) | (t/**/_TSB_SIZE))
/* END CSTYLED */

#define	PIU_IOMMU_BYPASS_BASE	(xULL(0xfffc000000000000))

#ifdef __cplusplus
}
#endif

#endif /* _PIU_PIU_H */
