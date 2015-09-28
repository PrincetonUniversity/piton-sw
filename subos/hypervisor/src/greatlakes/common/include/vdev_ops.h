/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vdev_ops.h
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

#ifndef _VDEV_OPS_H
#define	_VDEV_OPS_H

#pragma ident	"@(#)vdev_ops.h	1.7	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <platform/vdev_ops.h>

#define	NULL_iommu_map		0
#define	NULL_iommu_map_v2	0
#define	NULL_iommu_getmap	0
#define	NULL_iommu_getmap_v2	0
#define	NULL_iommu_unmap	0
#define	NULL_iommu_getbypass	0
#define	NULL_config_get		0
#define	NULL_config_put		0
#define	NULL_io_peek		0
#define	NULL_io_poke		0
#define	NULL_dma_sync		0
#define	NULL_devino2vino	0
#define	NULL_mondo_receive	0
#define	NULL_intr_getvalid	0
#define	NULL_intr_setvalid	0
#define	NULL_intr_settarget	0
#define	NULL_intr_gettarget	0
#define	NULL_intr_getstate	0
#define	NULL_intr_setstate	0
#define	NULL_vintr_getcookie	0
#define	NULL_vintr_setcookie	0
#define	NULL_vintr_getvalid	0
#define	NULL_vintr_setvalid	0
#define	NULL_vintr_gettarget	0
#define	NULL_vintr_settarget	0
#define	NULL_vintr_getstate	0
#define	NULL_vintr_setstate	0
#define	NULL_msiq_conf		0
#define	NULL_msiq_info		0
#define	NULL_msiq_getvalid	0
#define	NULL_msiq_setvalid	0
#define	NULL_msiq_getstate	0
#define	NULL_msiq_setstate	0
#define	NULL_msiq_gethead	0
#define	NULL_msiq_sethead	0
#define	NULL_msiq_gettail	0
#define	NULL_msi_getvalid	0
#define	NULL_msi_setvalid	0
#define	NULL_msi_getstate	0
#define	NULL_msi_setstate	0
#define	NULL_msi_getmsiq	0
#define	NULL_msi_setmsiq	0
#define	NULL_msi_msg_getmsiq	0
#define	NULL_msi_msg_setmsiq	0
#define	NULL_msi_msg_getvalid	0
#define	NULL_msi_msg_setvalid	0
#define	NULL_get_perf_reg	0
#define	NULL_set_perf_reg	0

#define	INTR_OPS(device) \
	.devino2vino = device##_devino2vino

#define	MONDO_OPS(device) \
	.mondo_receive = device##_mondo_receive

#define	PERF_OPS(device) \
	.getperfreg = device##_get_perf_reg, \
	.setperfreg = device##_set_perf_reg

#define	VINO_OPS(device) \
	.getvalid = device##_intr_getvalid, \
	.setvalid = device##_intr_setvalid, \
	.getstate = device##_intr_getstate, \
	.setstate = device##_intr_setstate, \
	.gettarget = device##_intr_gettarget, \
	.settarget = device##_intr_settarget

#define	VINTR_OPS(device) \
	.vgetcookie = device##_vintr_getcookie, \
	.vsetcookie = device##_vintr_setcookie, \
	.vgetvalid = device##_vintr_getvalid, \
	.vsetvalid = device##_vintr_setvalid, \
	.vgettarget = device##_vintr_gettarget, \
	.vsettarget = device##_vintr_settarget, \
	.vgetstate = device##_vintr_getstate, \
	.vsetstate = device##_vintr_setstate

#define	VPCI_OPS(bridge)			\
	.map = bridge##_iommu_map,		\
	.getmap = bridge##_iommu_getmap,	\
	.map_v2 = bridge##_iommu_map_v2,	\
	.getmap_v2 = bridge##_iommu_getmap_v2,	\
	.unmap	= bridge##_iommu_unmap,		\
	.getbypass = bridge##_iommu_getbypass,	\
	.configget = bridge##_config_get,	\
	.configput = bridge##_config_put,	\
	.peek = bridge##_io_peek,		\
	.poke = bridge##_io_poke,		\
	.dmasync = bridge##_dma_sync

#define	MSI_OPS(bridge) \
	.msiq_conf	= bridge##_msiq_conf, \
	.msiq_info	= bridge##_msiq_info, \
	.msiq_getvalid	= bridge##_msiq_getvalid, \
	.msiq_setvalid	= bridge##_msiq_setvalid, \
	.msiq_getstate	= bridge##_msiq_getstate, \
	.msiq_setstate	= bridge##_msiq_setstate, \
	.msiq_gethead	= bridge##_msiq_gethead, \
	.msiq_sethead	= bridge##_msiq_sethead, \
	.msiq_gettail	= bridge##_msiq_gettail, \
	.msi_getvalid	= bridge##_msi_getvalid, \
	.msi_setvalid	= bridge##_msi_setvalid, \
	.msi_getstate	= bridge##_msi_getstate, \
	.msi_setstate	= bridge##_msi_setstate, \
	.msi_getmsiq	= bridge##_msi_getmsiq, \
	.msi_setmsiq	= bridge##_msi_setmsiq, \
	.msi_msg_getmsiq = bridge##_msi_msg_getmsiq, \
	.msi_msg_setmsiq = bridge##_msi_msg_setmsiq, \
	.msi_msg_getvalid = bridge##_msi_msg_getvalid, \
	.msi_msg_setvalid = bridge##_msi_msg_setvalid

/*
 * "null" nexus
 */
#define	NULL_DEV_OPS \
	INTR_OPS(NULL), VINO_OPS(NULL), VPCI_OPS(NULL),	\
		MSI_OPS(NULL), PERF_OPS(NULL), VINTR_OPS(NULL)


/*
 * Virtual device (vdev) nexus
 */
#define	VINO_HANDLER_VDEV \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 00 - 01 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 02 - 03 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 04 - 05 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 06 - 07 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 08 - 09 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 10 - 11 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 12 - 13 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 14 - 15 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 16 - 17 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 18 - 19 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 20 - 21 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 22 - 23 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 24 - 25 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 26 - 27 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 28 - 29 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 30 - 31 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 32 - 33 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 34 - 35 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 36 - 37 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 38 - 39 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 40 - 41 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 42 - 33 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 44 - 45 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 46 - 47 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 48 - 49 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 50 - 51 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 52 - 53 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 54 - 55 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 56 - 57 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 58 - 59 */ \
	DEVOPS_VDEV, DEVOPS_VDEV,	/* 60 - 61 */ \
	DEVOPS_VDEV, DEVOPS_VDEV	/* 62 - 63 */

#define	VDEV_OPS \
	INTR_OPS(vdev), MONDO_OPS(NULL), VINO_OPS(vdev),	\
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL), VINTR_OPS(NULL)


/*
 * LDom Channel nexus
 */
#define	VINO_HANDLER_CDEV \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 00 - 01 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 02 - 03 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 04 - 05 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 06 - 07 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 08 - 09 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 10 - 11 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 12 - 13 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 14 - 15 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 16 - 17 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 18 - 19 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 20 - 21 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 22 - 23 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 24 - 25 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 26 - 27 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 28 - 29 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 30 - 31 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 32 - 33 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 34 - 35 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 36 - 37 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 38 - 39 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 40 - 41 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 42 - 33 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 44 - 45 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 46 - 47 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 48 - 49 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 50 - 51 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 52 - 53 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 54 - 55 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 56 - 57 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 58 - 59 */ \
	DEVOPS_CDEV, DEVOPS_CDEV,		/* 60 - 61 */ \
	DEVOPS_CDEV, DEVOPS_CDEV		/* 62 - 63 */

#define	CDEV_OPS \
	INTR_OPS(NULL), MONDO_OPS(NULL), VINO_OPS(NULL),	\
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL), VINTR_OPS(ldc)



#ifndef _ASM

typedef struct devopsvec devopsvec_t;
struct devopsvec {
	void	(*devino2vino)();

	void	(*mondo_receive)();
	void	(*getvalid)();
	void	(*setvalid)();
	void	(*getstate)();
	void	(*setstate)();
	void	(*gettarget)();
	void	(*settarget)();

	void	(*map)();
	void	(*map_v2)();
	void	(*getmap)();
	void	(*getmap_v2)();
	void	(*unmap)();
	void	(*getbypass)();
	void	(*configget)();
	void	(*configput)();
	void	(*peek)();
	void	(*poke)();
	void	(*dmasync)();
	void	(*msiq_conf)();
	void	(*msiq_info)();
	void	(*msiq_getvalid)();
	void	(*msiq_setvalid)();
	void	(*msiq_getstate)();
	void	(*msiq_setstate)();
	void	(*msiq_gethead)();
	void	(*msiq_sethead)();
	void	(*msiq_gettail)();
	void	(*msi_getvalid)();
	void	(*msi_setvalid)();
	void	(*msi_getstate)();
	void	(*msi_setstate)();
	void	(*msi_getmsiq)();
	void	(*msi_setmsiq)();
	void	(*msi_msg_getmsiq)();
	void	(*msi_msg_setmsiq)();
	void	(*msi_msg_getvalid)();
	void	(*msi_msg_setvalid)();

	void	(*getperfreg)();
	void	(*setperfreg)();

	void	(*vgetcookie)();
	void	(*vsetcookie)();
	void	(*vgetvalid)();
	void	(*vsetvalid)();
	void	(*vgettarget)();
	void	(*vsettarget)();
	void	(*vgetstate)();
	void	(*vsetstate)();
};

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _VDEV_OPS_H */
