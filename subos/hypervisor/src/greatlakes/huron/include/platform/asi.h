/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: asi.h
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

#ifndef _PLATFORM_ASI_H
#define	_PLATFORM_ASI_H

#pragma ident	"@(#)asi.h	1.4	07/07/17 SMI"

/*
 * Niagara2 ASI definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	ASI_ERR_EN		0x4c
#define	CORE_ERR_REPORT_EN	0x10
#define	CORE_ERR_TRAP_EN	0x18

#define	ASI_MMU_HWTW 0x52	/* MMU HWTW real range and phys offset regs */
#define	ASI_MMU_TSB 0x54	/* MMU TSB registers */
#define	ASI_MMU_CFG 0x58	/* MMU configuration register */

#define	ASI_SPU_CWQ_HEAD	0x0	/* SPU CWQ Head pointer */
#define	ASI_SPU_CWQ_TAIL	0x8	/* SPU CWQ Tail pointer */
#define	ASI_SPU_CWQ_FIRST	0x10	/* SPU CWQ First pointer */
#define	ASI_SPU_CWQ_LAST	0x18	/* SPU CWQ Last pointer */
#define	ASI_SPU_CWQ_CSR		0x20	/* SPU CWQ CSR register */
#define	ASI_SPU_CWQ_CSR_ENABLE	0x28	/* SPU CWQ CSR bit 0 only */
#define	ASI_SPU_CWQ_SYNC	0x30	/* SPU CWQ Sync register */

#define	ASI_CMP_CHIP	0x41	/* per-chip CMP registers */
#define	CMP_CORE_ENABLE_STATUS	0x10
#define	CMP_TICK_ENABLE		0x38
#define	CMP_CORE_RUNNING_STATUS	0x58
#define	CMP_CORE_RUNNING_W1S	0x60
#define	CMP_CORE_RUNNING_W1C	0x68
#define	ASI_CMP_CORE	0x63	/* per-core (local) CMP registers */
#define	CMP_CORE_ID	0x10

#define	ASI_DCACHE_DATA	0x46
#define	ASI_DCACHE_TAG	0x47

#define	ASI_ITLB_PROBE  0x53

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_ASI_H */
