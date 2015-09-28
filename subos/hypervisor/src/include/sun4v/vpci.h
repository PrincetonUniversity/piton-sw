/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci.h
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

#ifndef _SUN4V_VPCI_H
#define	_SUN4V_VPCI_H

#pragma ident	"@(#)vpci.h	1.6	07/07/17 SMI"


#ifdef __cplusplus
extern "C" {
#endif

#define	HVIO_TTE_R		0x00000001
#define	HVIO_TTE_W		0x00000002
#define	HVIO_TTE_ATTR_MASK	0x00000003

#define	HVIO_TTE_PP		0x00000030
#define	HVIO_TTE_L		0x00000004
#define	HVIO_TTE_BDF		0xffff0000
#define	HVIO_TTE_EXT_MASK	0xffff0034

#define	HVIO_TTE_PP_NONE	0x00000000
#define	HVIO_TTE_PP_2MSBS	0x00000020
#define	HVIO_TTE_PP_MSB		0x00000010
#define	HVIO_TTE_PP_ALL		0x00000030

#define	HVIO_TTE_PP_SHIFT	4
#define	HVIO_TTE_BDF_SHIFT	16

#define	HVIO_TTE_ATTR_MASK_V2	(HVIO_TTE_ATTR_MASK | HVIO_TTE_EXT_MASK)

#define	HVIO_IO_R		0x001
#define	HVIO_IO_W		0x002
#define	HVIO_IO_ATTR_MASK	0x003

#define	HVIO_MSI_INVALID	0
#define	HVIO_MSI_VALID		1
#define	HVIO_MSI_VALID_MAX_VALUE	HVIO_MSI_VALID

#define	HVIO_PCIE_MSG_INVALID	0
#define	HVIO_PCIE_MSG_VALID	1
#define	HVIO_PCIE_MSG_VALID_MAX_VALUE	HVIO_PCIE_MSG_VALID

#define	HVIO_MSISTATE_DELIVERED	1

#define	HVIO_MSIQSTATE_IDLE	0
#define	HVIO_MSIQSTATE_ERROR	1
#define	HVIO_MSIQSTATE_MAX_VALUE HVIO_MSIQSTATE_ERROR

#define	MSIQTYPE_32		0
#define	MSIQTYPE_64		1
#define	MSIQTYPE_MAX_VALUE	MSIQTYPE_64

#define	MSIEQ_REC_SHIFT		6
#define	MSIEQ_REC_SIZE		(xULL(1) << MSIEQ_REC_SHIFT)
#define	MSIEQ_REC_SIZE_MASK	(MSIEQ_REC_SIZE - 1)

#define	INTR_DISABLED		0
#define	INTR_ENABLED		1
#define	INTR_ENABLED_MAX_VALUE	INTR_ENABLED

#define	INTR_IDLE		0
#define	INTR_RECEIVED		1
#define	INTR_DELIVERED		2
#define	INTR_STATE_MAX_VALUE	INTR_DELIVERED

#define	HVIO_DMA_SYNC_DEVICE	1
#define	HVIO_DMA_SYNC_CPU	2

#define	VPCI_MSIEQ_TID_SHIFT	32
#define	VPCI_MSIEQ_MSG_RT_CODE_SHIFT 16
#define	VPCI_MSG_CODE_SHIFT	0

#define	PCIE_CFG_OFFSET_MASK	((1 << 12) - 1)
#define	PCIE_BDF_MASK		(((1 << 24) - 1) ^ ((1 << 8) - 1))

#define	IOMMU_MAP_MAX		64 /* max # of pages mapped  */

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_VPCI_H */
