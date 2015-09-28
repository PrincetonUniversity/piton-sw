/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_vpci.s
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

	.ident	"@(#)hcall_vpci.s	1.8	07/07/17 SMI"

#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <asi.h>
#include <hprivregs.h>
#include <vdev_intr.h>
#include <offsets.h>
#include <guest.h>
#include <util.h>

#define	CHECK_PCIE_BDF(device, scr1)	 \
	set	PCIE_BDF_MASK, scr1	;\
	andncc	device, scr1, %g0	;\
	bnz,pn	%xcc, herr_inval	;\
	nop

#define	CHECK_PCIE_CFG_OFFSET(offset, scr1)	 \
	set	PCIE_CFG_OFFSET_MASK, scr1	;\
	andncc	offset, scr1, %g0		;\
	bnz,pn	%xcc, herr_inval		;\
	nop

#define	CHECK_OFFSET_SIZE_ALIGN(offset, size, max_size, scr1)	 \
	brz,pn	size, herr_inval				;\
	sub	size, 1, scr1					;\
	btst	scr1, size					;\
	/* Check for power two size */				;\
	bnz,pn	%xcc, herr_inval				;\
	.empty							;\
	cmp	size, max_size					;\
	/* Check for size > max_size */				;\
	bgu,pn	%xcc, herr_inval				;\
	.empty							;\
	/* Check for offset aligned on size */			;\
	btst	offset, scr1					;\
	bnz,pn	%xcc, herr_badalign				;\
	.empty

/*
 * Return code template
 */
	ENTRY_NP(hcall_vpci_iommu_map)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MAP, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_map)

	ENTRY_NP(hcall_vpci_iommu_map_v2)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_MAP_V2, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_map_v2)
	ENTRY_NP(hcall_vpci_iommu_getmap_v2)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETMAP_V2, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_getmap_v2)

	ENTRY_NP(hcall_vpci_iommu_getmap)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETMAP, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_getmap)

	ENTRY_NP(hcall_vpci_iommu_unmap)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_UNMAP, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_unmap)

	ENTRY_NP(hcall_vpci_iommu_getbypass)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETBYPASS, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_iommu_getbypass)

/*
 * config_get
 *
 * arg0 dev config pa (%o0)
 * arg1 PCI device (%o1)
 * arg2 offset (%o2)
 * arg3 size (%o3)
 * --
 * ret0 status (%o0)
 * ret1 error_flag (%o1)
 * ret2 value (%o2)
 */
	ENTRY_NP(hcall_vpci_config_get)
	CHECK_PCIE_BDF(%o1, %g2)
	CHECK_PCIE_CFG_OFFSET(%o2, %g2)
	CHECK_OFFSET_SIZE_ALIGN(%o2, %o3, SZ_WORD, %g2)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_CONFIGGET, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_config_get)

/*
 * config_put
 *
 * arg0 dev config pa (%o0)
 * arg1 PCI device (%o1)
 * arg2 offset (%o2)
 * arg3 size (%o3)
 * arg4 data (%o4)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(hcall_vpci_config_put)
	CHECK_PCIE_BDF(%o1, %g2)
	CHECK_PCIE_CFG_OFFSET(%o2, %g2)
	CHECK_OFFSET_SIZE_ALIGN(%o2, %o3, SZ_WORD, %g2)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_CONFIGPUT, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_config_put)

/*
 * io_peek
 *
 * %g1 = PIU Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 error? (%o1)
 * ret2 data (%o2)
 */
	ENTRY_NP(hcall_vpci_io_peek)
	CHECK_OFFSET_SIZE_ALIGN(%o1, %o2, SZ_LONG, %g2)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_IOPEEK, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_io_peek)

/*
 * io_poke
 *
 * %g1 = PIU Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * arg3 data (%o3)
 * arg4 PCI device (%o4)
 * --
 * ret0 status (%o0)
 * ret1 error? (%o1)
 */
	ENTRY_NP(hcall_vpci_io_poke)
	CHECK_PCIE_BDF(%o4, %g2)
	CHECK_OFFSET_SIZE_ALIGN(%o1, %o2, SZ_LONG, %g2)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_IOPOKE, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_io_poke)

/*
 * dma_sync
 *
 * %g1 = Fire Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * arg3 direction (%o3) (one or both of 1: for device 2: for cpu)
 * --
 * ret0 status (%o0)
 * ret1 #bytes synced (%o1)
 */
	ENTRY_NP(hcall_vpci_dma_sync)
	brz,pn	%o3, herr_inval
	andncc	%o3, (HVIO_DMA_SYNC_CPU | HVIO_DMA_SYNC_DEVICE), %g0
	bnz,pn	%xcc, herr_inval
	nop
	brz,pn	%o2, herr_inval
	.empty
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_DMASYNC, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_dma_sync)

	ENTRY_NP(hcall_vpci_get_perfreg)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_GETPERFREG, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_get_perfreg)

	ENTRY_NP(hcall_vpci_set_perfreg)
	JMPL_DEVHANDLE2DEVOP(%o0, DEVOPSVEC_SETPERFREG, %g1, %g2, %g3, herr_inval)
	SET_SIZE(hcall_vpci_set_perfreg)
