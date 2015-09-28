/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: fire.h
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

#ifndef _FIRE_FIRE_H
#define	_FIRE_FIRE_H

#pragma ident	"@(#)fire.h	1.9	07/07/17 SMI"


#ifdef __cplusplus
extern "C" {
#endif

#include <support.h>

#define	FIRE_A_AID	(0x1e)
#define	FIRE_B_AID	(FIRE_A_AID+1)

#define	FIRE_VINO_MIN	(FIRE_A_AID << FIRE_DEVINO_SHIFT)
#define	FIRE_VINO_MAX	((FIRE_B_AID << FIRE_DEVINO_SHIFT) | FIRE_DEVINO_MASK)

#define	NFIREDEVINO		(64)
#define	FIRE_DEVINO_MASK	(NFIREDEVINO - 1)
#define	FIRE_DEVINO_SHIFT	6

#define	FIRE_EQ2INO(n)	(24+n)
#define	FIRE_NEQS	36

#define	FIRE_MAX_MSIS	256
#define	FIRE_MSI_MASK	(FIRE_MAX_MSIS - 1)

#define	FIRE_MSIEQNUM_MASK	((1 << 6) - 1)

#define	FIRE_EQREC_SHIFT	MSIEQ_REC_SHIFT
#define	FIRE_EQREC_SIZE		MSIEQ_REC_SIZE
#define	FIRE_NEQRECORDS		128

#define	FIRE_EQSIZE	(FIRE_NEQRECORDS * FIRE_EQREC_SIZE)
#define	FIRE_EQMASK	(FIRE_EQSIZE - 1)

#define	NFIREINTRCONTROLLERS 4
#define	FIRE_INTR_CNTLR_MASK	((1 << NFIREINTRCONTROLLERS) - 1)
#define	FIRE_INTR_CNTLR_SHIFT	6

#define	INTRSTATE_MASK	0x1

#define	JPID_MASK	0x1f
#define	JPID_SHIFT	26

#define	PCI_CFG_OFFSET_MASK	((1 << 12) - 1)
#define	PCI_CFG_SIZE_MASK	7
#define	PCI_DEV_MASK		(((1 << 24) - 1)^((1 << 8) -1))
#define	PCI_DEV_SHIFT		4

#define	JBUS_PA_SHIFT		43
#define	FIRE_PAGESIZE_8K_SHIFT	13

#define	FIRE_TSB_1K		0
#define	FIRE_TSB_2K		1
#define	FIRE_TSB_4K		2
#define	FIRE_TSB_8K		3
#define	FIRE_TSB_16K		4
#define	FIRE_TSB_32K		5
#define	FIRE_TSB_64K		6
#define	FIRE_TSB_128K		7
#define	FIRE_TSB_256K		8
#define	FIRE_TSB_512K		9

#define	FIRE_TSB_SIZE		FIRE_TSB_256K

#define	FIRE_IOMMU_SIZE(n)	(xULL(1) << ((n) + 10))

#define	IOTTE_SIZE		8
#define	IOTTE_SHIFT		3	/* log2(IOTTE_SIZE) */
#define	IOMMU_PAGESHIFT		13	/* 2K */
#define	IOMMU_PAGESIZE		(xULL(1) << IOMMU_PAGESHIFT)

#define	EQALIGN			(xULL(512) * xULL(1024))	/* 512K Align */
#define	EQ_MAX_SIZE		(FIRE_NEQS * FIRE_EQSIZE)
#define	IOMMU_EQ_RESERVE	((EQ_MAX_SIZE + EQALIGN - 1) & ~(EQALIGN - 1))

#define	IOMMU_SPACE		(FIRE_IOMMU_SIZE(FIRE_TSB_SIZE) << \
				    IOMMU_PAGESHIFT)
/*
 * We carve out a 512K aligned chunk (IOMMU_EQ_RESERVE) of the DVMA range
 * for MSI Event Queues. So we make sure the max idx a guest can pass for
 * a map call doesn't trample on the event queues.
 */
#define	IOTSB_INDEX_MAX		(((IOMMU_SPACE - IOMMU_EQ_RESERVE) >> \
				    IOMMU_PAGESHIFT) - 1)
#define	IOTSB_SIZE		((IOMMU_SPACE/IOMMU_PAGESIZE) * IOTTE_SIZE)

#define	FIRE_IOTTE_V_SHIFT	63
#define	FIRE_IOTTE_W_SHIFT	1
#define	FIRE_INTMR_V_SHIFT	31
#define	FIRE_INTMR_MDO_MODE_SHIFT 63
#define	FIRE_MSIMR_V_SHIFT	63
#define	FIRE_MSIMR_EQWR_N_SHIFT	62
#define	FIRE_MSGMR_V_SHIFT	63
#define	FIRE_EQREC_TYPE_SHIFT	56
#define	FIRE_EQCCR_E2I_SHIFT	47
#define	FIRE_EQCCR_COVERR	57
#define	FIRE_EQCSR_EN_SHIFT	44
#define	FIRE_EQCSR_ENOVERR	57

#define	FIRE_IO_TTE(x)	 ((x) | (1ull << FIRE_IOTTE_V_SHIFT)	\
			    | (1ull << FIRE_IOTTE_W_SHIFT))
#define	FIRE_DVMA_RANGE_MAX	(xULL(1) << 32)

#define	MSI_EQ_BASE_BYPASS_ADDR	(0xfffc000000000000LL)

#define	FIRE_INTR_IDLE		0
#define	FIRE_INTR_RECEIVED	3


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

#define	FIRE_CORR_OFF		0x00
#define	FIRE_NONFATAL_OFF	0x08
#define	FIRE_FATAL_OFF		0x10
#define	FIRE_PME_OFF		0x18
#define	FIRE_PME_ACK_OFF	0x20

#define	FIRE_MMU_CSR_TE		(1 << 0)	/* Translation Enable */
#define	FIRE_MMU_CSR_BE		(1 << 1)	/* Bypass Enable */
#define	FIRE_MMU_CSR_CM		(3 << 8)	/* Cache Mode */
#define	FIRE_MMU_CSR_SE		(1 << 10)	/* Snoop Enable */

#define	FIRE_MMU_CSR_VALUE	(FIRE_MMU_CSR_TE |\
				FIRE_MMU_CSR_BE |\
				FIRE_MMU_CSR_CM |\
				FIRE_MMU_CSR_SE)

#define	FIRE_IOMMU_BYPASS_BASE	(0xffffc000000000000LL)
#define	FIRE_JBUS_ID_MR_MASK	0xf
#define	FIRE_REV_1		0x1
#define	FIRE_REV_2_0		0x3
#define	FIRE_REV_2_1		0x4

#define	FIRE_TLU_CTL_NPWR_EN	0x100000
#define	FIRE_TLU_STS_STATUS_MASK	0xf
#define	FIRE_TLU_STS_STATUS_DATA_LINK_ACTIVE	0x4

#ifdef __cplusplus
}
#endif

#endif /* _FIRE_FIRE_H */
