/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_groups.s
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

	.ident	"@(#)hcall_groups.s	1.98	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/misc.h>
#include <debug.h>
#include <hcall.h>

#ifdef CONFIG_BRINGUP
#define	VDEV_GENINTR		0xff
#endif

/*
 * If you add a group to this table, be sure to update
 * NUM_API_GROUPS in guest.h.  You have been warned...
 *
 * One important caveat:  don't put any data between GROUP_END
 * and GROUP_BEGIN entries, or you'll break the table.
 */

	DATA_GLOBAL(hcall_api_group_map)

	/*
	 * Core API group.  Basics needed for a sane guest.
	 */
	GROUP_BEGIN(core, API_GROUP_CORE)	! API group index #1
	GROUP_MAJOR_ENTRY(core, 1, 1)
	GROUP_MINOR_ENTRY(core_1_0)
	GROUP_MINOR_ENTRY(core_1_1)
	GROUP_MINOR_END(core_1)
	GROUP_MAJOR_END(core)

	GROUP_HCALL_TABLE(core_1_0)
	GROUP_HCALL_ENTRY(MACH_EXIT,		hcall_mach_exit)
	GROUP_HCALL_ENTRY(MACH_DESC,		hcall_mach_desc)
	GROUP_HCALL_ENTRY(MACH_SIR,		hcall_mach_sir)
	GROUP_HCALL_ENTRY(CPU_START,		hcall_cpu_start)
	GROUP_HCALL_ENTRY(CPU_YIELD,		hcall_cpu_yield)
	GROUP_HCALL_ENTRY(CPU_QCONF,		hcall_cpu_qconf)
	GROUP_HCALL_ENTRY(CPU_QINFO,		hcall_cpu_qinfo)
	GROUP_HCALL_ENTRY(CPU_MYID,		hcall_cpu_myid)
	GROUP_HCALL_ENTRY(CPU_GET_STATE,	hcall_cpu_get_state)
	GROUP_HCALL_ENTRY(CPU_SET_RTBA,		hcall_cpu_set_rtba)
	GROUP_HCALL_ENTRY(CPU_GET_RTBA,		hcall_cpu_get_rtba)
	GROUP_HCALL_ENTRY(MMU_TSB_CTX0,		hcall_mmu_tsb_ctx0)
	GROUP_HCALL_ENTRY(MMU_TSB_CTXNON0,	hcall_mmu_tsb_ctxnon0)
	GROUP_HCALL_ENTRY(MMU_DEMAP_PAGE,	hcall_mmu_demap_page)
	GROUP_HCALL_ENTRY(MMU_DEMAP_CTX,	hcall_mmu_demap_ctx)
	GROUP_HCALL_ENTRY(MMU_DEMAP_ALL,	hcall_mmu_demap_all)
	GROUP_HCALL_ENTRY(MMU_MAP_PERM_ADDR,	hcall_mmu_map_perm_addr)
	GROUP_HCALL_ENTRY(MMU_FAULT_AREA_CONF,	hcall_mmu_fault_area_conf)
	GROUP_HCALL_ENTRY(MMU_ENABLE,		hcall_mmu_enable)
	GROUP_HCALL_ENTRY(MMU_UNMAP_PERM_ADDR,	hcall_mmu_unmap_perm_addr)
	GROUP_HCALL_ENTRY(MMU_TSB_CTX0_INFO,	hcall_mmu_tsb_ctx0_info)
	GROUP_HCALL_ENTRY(MMU_TSB_CTXNON0_INFO,	hcall_mmu_tsb_ctxnon0_info)
	GROUP_HCALL_ENTRY(MMU_FAULT_AREA_INFO,	hcall_mmu_fault_area_info)
	GROUP_HCALL_ENTRY(MEM_SCRUB,		hcall_mem_scrub)
	GROUP_HCALL_ENTRY(MEM_SYNC,		hcall_mem_sync)
	GROUP_HCALL_ENTRY(CPU_MONDO_SEND,	hcall_cpu_mondo_send)
	GROUP_HCALL_ENTRY(TOD_GET,		hcall_tod_get)
	GROUP_HCALL_ENTRY(TOD_SET,		hcall_tod_set)
	GROUP_HCALL_ENTRY(CONS_GETCHAR,		hcall_cons_getchar)
	GROUP_HCALL_ENTRY(CONS_PUTCHAR,		hcall_cons_putchar)
	GROUP_HCALL_ENTRY(TTRACE_BUF_CONF,	hcall_ttrace_buf_conf)
	GROUP_HCALL_ENTRY(TTRACE_BUF_INFO,	hcall_ttrace_buf_info)
	GROUP_HCALL_ENTRY(TTRACE_ENABLE,	hcall_ttrace_enable)
	GROUP_HCALL_ENTRY(TTRACE_FREEZE,	hcall_ttrace_freeze)
	GROUP_HCALL_ENTRY(DUMP_BUF_UPDATE,	hcall_dump_buf_update)
	GROUP_HCALL_ENTRY(DUMP_BUF_INFO,	hcall_dump_buf_info)
	GROUP_HCALL_ENTRY(MMU_MAP_ADDR_IDX,	hcall_mmu_map_addr)
	GROUP_HCALL_ENTRY(MMU_UNMAP_ADDR_IDX,	hcall_mmu_unmap_addr)
	GROUP_HCALL_ENTRY(TTRACE_ADDENTRY_IDX,	hcall_ttrace_addentry)
#ifdef CONFIG_DISK
	GROUP_HCALL_ENTRY(DISK_READ,		hcall_disk_read)
	GROUP_HCALL_ENTRY(DISK_WRITE,		hcall_disk_write)
#endif
#ifdef T1_FPGA_SNET
	GROUP_HCALL_ENTRY(SNET_READ,		hcall_snet_read)
	GROUP_HCALL_ENTRY(SNET_WRITE,		hcall_snet_write)
#endif
#ifdef CONFIG_BRINGUP
	GROUP_HCALL_ENTRY(VDEV_GENINTR,		hcall_vdev_genintr)
#endif
#if 0 /* { FIXME: perm map info for debug currently disabled */
#ifdef DEBUG
	GROUP_HCALL_ENTRY(MMU_PERM_ADDR_INFO,	hcall_mmu_perm_addr_info)
#endif
#endif /* } */
	GROUP_HCALL_TABLE(core_1_1)
	GROUP_HCALL_ENTRY(MACH_SET_WATCHDOG,	hcall_set_watchdog)
	GROUP_HCALL_ENTRY(CPU_STOP,             hcall_cpu_stop)
	GROUP_HCALL_ENTRY(CONS_READ,            hcall_cons_read)
	GROUP_HCALL_ENTRY(CONS_WRITE,           hcall_cons_write)
	GROUP_HCALL_END(core_1)
	GROUP_END(core)

	/*
	 * Interrupt API group. For guests interested in using
	 * interrupts.
	 */
	GROUP_BEGIN(intr, API_GROUP_INTR)	! API group index #2
	GROUP_MAJOR_ENTRY(intr, 1, 0)
	GROUP_MINOR_ENTRY(intr_1_0)
	GROUP_MINOR_END(intr_1)
	GROUP_MAJOR_ENTRY(intr, 2, 0)
	GROUP_MINOR_ENTRY(intr_2_0)
	GROUP_MINOR_END(intr_2)
	GROUP_MAJOR_END(intr)

	GROUP_HCALL_TABLE(intr_1_0)
	GROUP_HCALL_ENTRY(INTR_DEVINO2SYSINO,	hcall_intr_devino2sysino)
	GROUP_HCALL_ENTRY(INTR_GETENABLED,	hcall_intr_getenabled)
	GROUP_HCALL_ENTRY(INTR_SETENABLED,	hcall_intr_setenabled)
	GROUP_HCALL_ENTRY(INTR_GETSTATE,	hcall_intr_getstate)
	GROUP_HCALL_ENTRY(INTR_SETSTATE,	hcall_intr_setstate)
	GROUP_HCALL_ENTRY(INTR_GETTARGET,	hcall_intr_gettarget)
	GROUP_HCALL_ENTRY(INTR_SETTARGET,	hcall_intr_settarget)

#ifdef SOLARIS_ERRATUM_6496266

	/*
	 * NOTE: The following workaround enables the interrupt_cookie 
	 * APIs (0xa7 - 0xae) as part of API_GROUP_INTR v1.0. Due a 
	 * bug in Solaris S10U3, it negotiates v1.0 of the interrupt 
	 * group and expects the vintr_cookie APIs to be available as
	 * part of this version. These APIs should only be enabled when
	 * a guest negotiates v2.0 as per Hypervisor API specification,
	 * and this workaround should be removed when legacy support for
	 * S10U3 and later is no longer required in the field.
	 */	
	GROUP_HCALL_ENTRY(VINTR_GETCOOKIE,      hcall_vintr_getcookie)
	GROUP_HCALL_ENTRY(VINTR_SETCOOKIE,      hcall_vintr_setcookie)
	GROUP_HCALL_ENTRY(VINTR_GETVALID,       hcall_vintr_getvalid)
	GROUP_HCALL_ENTRY(VINTR_SETVALID,       hcall_vintr_setvalid)
	GROUP_HCALL_ENTRY(VINTR_GETSTATE,       hcall_vintr_getstate)
	GROUP_HCALL_ENTRY(VINTR_SETSTATE,       hcall_vintr_setstate)
	GROUP_HCALL_ENTRY(VINTR_GETTARGET,      hcall_vintr_gettarget)
	GROUP_HCALL_ENTRY(VINTR_SETTARGET,      hcall_vintr_settarget)
#endif
	GROUP_HCALL_END(intr_1)

	GROUP_HCALL_TABLE(intr_2_0)
	GROUP_HCALL_ENTRY(VINTR_GETCOOKIE,      hcall_vintr_getcookie)
	GROUP_HCALL_ENTRY(VINTR_SETCOOKIE,      hcall_vintr_setcookie)
	GROUP_HCALL_ENTRY(VINTR_GETVALID,       hcall_vintr_getvalid)
	GROUP_HCALL_ENTRY(VINTR_SETVALID,       hcall_vintr_setvalid)
	GROUP_HCALL_ENTRY(VINTR_GETSTATE,       hcall_vintr_getstate)
	GROUP_HCALL_ENTRY(VINTR_SETSTATE,       hcall_vintr_setstate)
	GROUP_HCALL_ENTRY(VINTR_GETTARGET,      hcall_vintr_gettarget)
	GROUP_HCALL_ENTRY(VINTR_SETTARGET,      hcall_vintr_settarget)
	GROUP_HCALL_END(intr_2)
	GROUP_END(intr)

	/*
	 * Guest Soft State group.
	 */
	GROUP_BEGIN(softstate, API_GROUP_SOFTSTATE)	! API group index #3
	GROUP_MAJOR_ENTRY(softstate, 1, 0)
	GROUP_MINOR_ENTRY(softstate_1_0)
	GROUP_MINOR_END(softstate_1)
	GROUP_MAJOR_END(softstate)

	GROUP_HCALL_TABLE(softstate_1_0)
	GROUP_HCALL_ENTRY(SOFT_STATE_SET,	hcall_soft_state_set)
	GROUP_HCALL_ENTRY(SOFT_STATE_GET,	hcall_soft_state_get)
	GROUP_HCALL_END(softstate_1)
	GROUP_END(softstate)


	/*
	 * PCIe API group.  For guests doing physical I/O with
	 * PCI-Express Root Complexes.
	 */
	GROUP_BEGIN(pci, API_GROUP_PCI)		! API group index #4
#ifdef SOLARIS_ERRATUM_6538898
	GROUP_MAJOR_ENTRY(pci, 1, 0)
	GROUP_MINOR_ENTRY(pci_1_0)
	GROUP_MINOR_END(pci_1)
#else /* SOLARIS_ERRATUM_6538898 */
	GROUP_MAJOR_ENTRY(pci, 1, 1)
	GROUP_MINOR_ENTRY(pci_1_0)
	GROUP_MINOR_ENTRY(pci_1_1)
	GROUP_MINOR_END(pci_1)
#endif /* SOLARIS_ERRATUM_6538898 */
	GROUP_MAJOR_END(pci)

	GROUP_HCALL_TABLE(pci_1_0)
	GROUP_HCALL_ENTRY(VPCI_IOMMU_MAP,	hcall_vpci_iommu_map)
	GROUP_HCALL_ENTRY(VPCI_IOMMU_UNMAP,	hcall_vpci_iommu_unmap)
	GROUP_HCALL_ENTRY(VPCI_IOMMU_GETMAP,	hcall_vpci_iommu_getmap)
	GROUP_HCALL_ENTRY(VPCI_IOMMU_GETBYPASS,	hcall_vpci_iommu_getbypass)
	GROUP_HCALL_ENTRY(VPCI_CONFIG_GET,	hcall_vpci_config_get)
	GROUP_HCALL_ENTRY(VPCI_CONFIG_PUT,	hcall_vpci_config_put)
	GROUP_HCALL_ENTRY(VPCI_IO_PEEK,		hcall_vpci_io_peek)
	GROUP_HCALL_ENTRY(VPCI_IO_POKE,		hcall_vpci_io_poke)
	GROUP_HCALL_ENTRY(VPCI_DMA_SYNC,	hcall_vpci_dma_sync)
	GROUP_HCALL_ENTRY(MSIQ_CONF,		hcall_msiq_conf)
	GROUP_HCALL_ENTRY(MSIQ_INFO,		hcall_msiq_info)
	GROUP_HCALL_ENTRY(MSIQ_GETVALID,	hcall_msiq_getvalid)
	GROUP_HCALL_ENTRY(MSIQ_SETVALID,	hcall_msiq_setvalid)
	GROUP_HCALL_ENTRY(MSIQ_GETSTATE,	hcall_msiq_getstate)
	GROUP_HCALL_ENTRY(MSIQ_SETSTATE,	hcall_msiq_setstate)
	GROUP_HCALL_ENTRY(MSIQ_GETHEAD,		hcall_msiq_gethead)
	GROUP_HCALL_ENTRY(MSIQ_SETHEAD,		hcall_msiq_sethead)
	GROUP_HCALL_ENTRY(MSIQ_GETTAIL,		hcall_msiq_gettail)
	GROUP_HCALL_ENTRY(MSI_GETVALID,		hcall_msi_getvalid)
	GROUP_HCALL_ENTRY(MSI_SETVALID,		hcall_msi_setvalid)
	GROUP_HCALL_ENTRY(MSI_GETMSIQ,		hcall_msi_getmsiq)
	GROUP_HCALL_ENTRY(MSI_SETMSIQ,		hcall_msi_setmsiq)
	GROUP_HCALL_ENTRY(MSI_GETSTATE,		hcall_msi_getstate)
	GROUP_HCALL_ENTRY(MSI_SETSTATE,		hcall_msi_setstate)
	GROUP_HCALL_ENTRY(MSI_MSG_GETMSIQ,	hcall_msi_msg_getmsiq)
	GROUP_HCALL_ENTRY(MSI_MSG_SETMSIQ,	hcall_msi_msg_setmsiq)
	GROUP_HCALL_ENTRY(MSI_MSG_GETVALID,	hcall_msi_msg_getvalid)
	GROUP_HCALL_ENTRY(MSI_MSG_SETVALID,	hcall_msi_msg_setvalid)
	GROUP_HCALL_TABLE(pci_1_1)
	GROUP_HCALL_ENTRY(VPCI_IOMMU_MAP,	hcall_vpci_iommu_map_v2)
	GROUP_HCALL_ENTRY(VPCI_IOMMU_GETMAP,	hcall_vpci_iommu_getmap_v2)
	GROUP_HCALL_END(pci_1)
	GROUP_END(pci)

#ifdef CONFIG_SVC
	/*
	 * SVC API group.  Deprecated interface for early Solaris
	 * releases using Great Lakes Virtual Channels (glvc).
	 */
	GROUP_BEGIN(svc, API_GROUP_SVC)		! API group index #5
	GROUP_MAJOR_ENTRY(svc, 1, 0)
	GROUP_MINOR_ENTRY(svc_1_0)
	GROUP_MINOR_END(svc_1)
	GROUP_MAJOR_END(svc)

	GROUP_HCALL_TABLE(svc_1_0)
	GROUP_HCALL_ENTRY(SVC_SEND,		hcall_svc_send)
	GROUP_HCALL_ENTRY(SVC_RECV,		hcall_svc_recv)
	GROUP_HCALL_ENTRY(SVC_GETSTATUS,	hcall_svc_getstatus)
	GROUP_HCALL_ENTRY(SVC_SETSTATUS,	hcall_svc_setstatus)
	GROUP_HCALL_ENTRY(SVC_CLRSTATUS,	hcall_svc_clrstatus)
	GROUP_HCALL_END(svc_1)
	GROUP_END(svc)
#endif

	/*
	 * Niagara Crypto API group.  Niagara specific functions
	 * for access to crypto acceleration hardware.
	 */
	GROUP_BEGIN(ncs, API_GROUP_NCS)		! API group index #6
	GROUP_MAJOR_ENTRY(ncs, 1, 0)
	GROUP_MINOR_ENTRY(ncs_1_0)
	GROUP_MINOR_END(ncs_1)
	GROUP_MAJOR_ENTRY(ncs, 2, 0)
	GROUP_MINOR_ENTRY(ncs_2_0)
	GROUP_MINOR_END(ncs_2)
	GROUP_MAJOR_END(ncs)

	GROUP_HCALL_TABLE(ncs_1_0)
	GROUP_HCALL_ENTRY(NCS_REQUEST,		hcall_ncs_request)
	GROUP_HCALL_END(ncs_1)

	GROUP_HCALL_TABLE(ncs_2_0)
	GROUP_HCALL_ENTRY(NCS_SETTAIL,		hcall_ncs_settail)
	GROUP_HCALL_ENTRY(NCS_SETHEAD_MARKER,	hcall_ncs_sethead_marker)
	GROUP_HCALL_ENTRY(NCS_GETHEAD,		hcall_ncs_gethead)
	GROUP_HCALL_ENTRY(NCS_GETTAIL,		hcall_ncs_gettail)
	GROUP_HCALL_ENTRY(NCS_QCONF,		hcall_ncs_qconf)
	GROUP_HCALL_ENTRY(NCS_QHANDLE_TO_DEVINO, hcall_ncs_qhandle_to_devino)
	GROUP_HCALL_ENTRY(NCS_QINFO,		hcall_ncs_qinfo)
	GROUP_HCALL_END(ncs_2)

	GROUP_END(ncs)

	/*
	 * Niagara Perf Regs API group.  Niagara specific calls
	 * for performance monitoring.
	 */
	GROUP_BEGIN(niagara, API_GROUP_NIAGARA)	! API group index #7
	GROUP_MAJOR_ENTRY(niagara, 1, 0)
	GROUP_MINOR_ENTRY(niagara_1_0)
	GROUP_MINOR_END(niagara_1)
	GROUP_MAJOR_END(niagara)

	GROUP_HCALL_TABLE(niagara_1_0)
	GROUP_HCALL_ENTRY(NIAGARA_GET_PERFREG,	hcall_niagara_getperf)
	GROUP_HCALL_ENTRY(NIAGARA_SET_PERFREG,	hcall_niagara_setperf)
	GROUP_HCALL_ENTRY(NIAGARA_MMUSTAT_CONF,	hcall_niagara_mmustat_conf)
	GROUP_HCALL_ENTRY(NIAGARA_MMUSTAT_INFO,	hcall_niagara_mmustat_info)
	GROUP_HCALL_END(niagara_1)
	GROUP_END(niagara)

#ifdef CONFIG_FIRE
	/*
	 * Fire API group.  Fire specific calls for I/O performance
	 * monitoring.
	 */
	GROUP_BEGIN(fire, API_GROUP_FIRE)	! API group index #8
	GROUP_MAJOR_ENTRY(fire, 1, 0)
	GROUP_MINOR_ENTRY(fire_1_0)
	GROUP_MINOR_END(fire_1)
	GROUP_MAJOR_END(fire)

	GROUP_HCALL_TABLE(fire_1_0)
	GROUP_HCALL_ENTRY(FIRE_GET_PERFREG,	hcall_vpci_get_perfreg)
	GROUP_HCALL_ENTRY(FIRE_SET_PERFREG,	hcall_vpci_set_perfreg)
	GROUP_HCALL_END(fire_1)
	GROUP_END(fire)
#endif

	/*
	 * Diag and Test API group.  Special interfaces for lab test
	 * and debug tools (like the error injector).  Generally
	 * require special access permissions be specified in the
	 * machine description.  Not intended for use in production
	 * systems.
	 */
	GROUP_BEGIN(diag, API_GROUP_DIAG)	! API group index #9
	GROUP_MAJOR_ENTRY(diag, 1, 0)
	GROUP_MINOR_ENTRY(diag_1_0)
	GROUP_MINOR_END(diag_1)
	GROUP_MAJOR_END(diag)

	GROUP_HCALL_TABLE(diag_1_0)
	GROUP_HCALL_ENTRY(DIAG_RA2PA,		hcall_diag_ra2pa)
	GROUP_HCALL_ENTRY(DIAG_HEXEC,		hcall_diag_hexec)
	GROUP_HCALL_END(diag_1)
	GROUP_END(diag)

	GROUP_BEGIN(ldc, API_GROUP_LDC)		! API group index #10
	GROUP_MAJOR_ENTRY(ldc, 1, 0)
	GROUP_MINOR_ENTRY(ldc_1_0)
	GROUP_MINOR_END(ldc_1)
	GROUP_MAJOR_END(ldc)

	GROUP_HCALL_TABLE(ldc_1_0)
	GROUP_HCALL_ENTRY(LDC_TX_QCONF,		hcall_ldc_tx_qconf)
	GROUP_HCALL_ENTRY(LDC_TX_QINFO,		hcall_ldc_tx_qinfo)
	GROUP_HCALL_ENTRY(LDC_TX_GET_STATE,	hcall_ldc_tx_get_state)
	GROUP_HCALL_ENTRY(LDC_TX_SET_QTAIL,	hcall_ldc_tx_set_qtail)
	GROUP_HCALL_ENTRY(LDC_RX_QCONF,		hcall_ldc_rx_qconf)
	GROUP_HCALL_ENTRY(LDC_RX_QINFO,		hcall_ldc_rx_qinfo)
	GROUP_HCALL_ENTRY(LDC_RX_GET_STATE,	hcall_ldc_rx_get_state)
	GROUP_HCALL_ENTRY(LDC_RX_SET_QHEAD,	hcall_ldc_rx_set_qhead)
	GROUP_HCALL_ENTRY(LDC_SET_MAP_TABLE,	hcall_ldc_set_map_table)
	GROUP_HCALL_ENTRY(LDC_GET_MAP_TABLE,	hcall_ldc_get_map_table)
	GROUP_HCALL_ENTRY(LDC_COPY,		hcall_ldc_copy)
	GROUP_HCALL_ENTRY(LDC_MAPIN,		hcall_ldc_mapin)
	GROUP_HCALL_ENTRY(LDC_UNMAP,		hcall_ldc_unmap)
	GROUP_HCALL_ENTRY(LDC_REVOKE,		hcall_ldc_revoke)
	GROUP_HCALL_END(ldc_1)
	GROUP_END(ldc)


#ifdef CONFIG_VERSION_TEST
	/*
	 * Test API group.  Here to enable debugging changes to
	 * the set_version/get_version code, and/or to the table
	 * structure.
	 */
	GROUP_BEGIN(test, 0x400)		! API group index #11
	GROUP_MAJOR_ENTRY(test, 1, 2)
	GROUP_MINOR_ENTRY(test_1_0)
	GROUP_MINOR_ENTRY(test_1_1)
	GROUP_MINOR_ENTRY(test_1_2)
	GROUP_MINOR_END(test_1)
	GROUP_MAJOR_ENTRY(test, 2, 2)
	GROUP_MINOR_ENTRY(test_2_0)
	GROUP_MINOR_ENTRY(test_2_1)
	GROUP_MINOR_ENTRY(test_2_2)
	GROUP_MINOR_END(test_2)
	GROUP_MAJOR_ENTRY(test, 3, 0)
	GROUP_MINOR_ENTRY(test_3_0)
	GROUP_MINOR_END(test_3)
	GROUP_MAJOR_END(test)

	GROUP_HCALL_TABLE(test_1_0)
	GROUP_HCALL_ENTRY(0xe0,			hcall_version_test_1_0)
	GROUP_HCALL_TABLE(test_1_1)
	GROUP_HCALL_ENTRY(0xe1,			hcall_version_test_1_1)
	GROUP_HCALL_TABLE(test_1_2)
	GROUP_HCALL_ENTRY(0xe2,			hcall_version_test_1_2)
	GROUP_HCALL_END(test_1)
	GROUP_HCALL_TABLE(test_2_0)
	GROUP_HCALL_ENTRY(0xe0,			hcall_version_test_2_0)
	GROUP_HCALL_TABLE(test_2_1)
	GROUP_HCALL_ENTRY(0xe3,			hcall_version_test_2_1)
	GROUP_HCALL_TABLE(test_2_2)
	GROUP_HCALL_ENTRY(0xe1,			hcall_version_test_2_2)
	GROUP_HCALL_END(test_2)
	GROUP_HCALL_TABLE(test_3_0)
	GROUP_HCALL_ENTRY(0xe3,			hcall_version_test_3_0)
	GROUP_HCALL_END(test_3)
	GROUP_END(test)
#endif

	/*
	 * You can add new groups here.  Remember to update
	 * NUM_API_GROUPS.
	 */


	/* End of API groups - delete this and be sorry */
	.xword	0
	SET_SIZE(hcall_api_group_map)
