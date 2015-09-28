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

#ifndef _ASI_H
#define	_ASI_H

#pragma ident	"@(#)asi.h	1.8	07/05/03 SMI"

/*
 * Niagara-family ASI definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#include <platform/asi.h>

#define	ASI_MEM		0x14	/* Physical address, non-L1$-allocating */
#define	ASI_IO		0x15	/* Physical address, non-$able w/ side-effect */
#define	ASI_BLK_AIUP	0x16	/* Block store, as if user primary */
#define	ASI_BLK_AIUS	0x17	/* Block store, as if user secondary */
#define	ASI_MEM_LE	0x1c	/* ASI_MEM, little endian */
#define	ASI_IO_LE	0x1d	/* ASI_IO, little endian */
#define	ASI_BLK_AIUP_LE	0x1e	/* ASI_BLK_AIUP, little endian */
#define	ASI_BLK_AIUS_LE	0x1f	/* ASI_BLK_AIUS, little endian */

#define	ASI_MMU		0x21
#define	ASI_BLKINIT_AIUP	0x22
#define	ASI_BLKINIT_AIUS	0x23
#define	ASI_BLKINIT_AIUP_LE	0x2a
#define	ASI_BLKINIT_AIUS_LE	0x2b

#define	ASI_QUAD_LDD	0x24	/* 128-bit atomic ldda/stda */
#define	ASI_QUAD_LDD_REAL 0x26	/* 128-bit atomic ldda/stda real */
#define	ASI_QUAD_LDD_LE	0x2c	/* 128-bit atomic ldda/stda, little endian */

#define	ASI_STREAM	0x40	/* Niagara streaming extensions */
#define	ASI_NIAGARA	0x42	/* BIST/LSU diag registers */ /* XXX */

#define	ASI_DC_DATA	0x46	/* D$ data array diag access */
#define	ASI_DC_TAG	0x47	/* D$ tag array diag access */

#define	ASI_HSCRATCHPAD	0x4f	/* Hypervisor scratchpad registers */

#define	ASI_IMMU	0x50	/* IMMU registers */
#define	ASI_ITLB_DATA_IN 0x54	/* IMMU data in register */
#define	ASI_ITLB_DATA_ACC 0x55	/* IMMU data access register */
#define	ASI_ITLB_TAG	0x56	/* IMMU tag read register */
#define	ASI_IMMU_DEMAP	0x57	/* IMMU tlb demap */

#define	ASI_DMMU	0x58	/* DMMU registers */

#define	IDMMU_PARTITION_ID	0x80 /* Partition ID register */

#define	ASI_DTLB_DATA_IN 0x5c	/* DMMU data in register */
#define	ASI_DTLB_DATA_ACC 0x5d	/* DMMU data access register */
#define	ASI_DTLB_TAG	0x5e	/* DMMU tag read register */
#define	ASI_DMMU_DEMAP	0x5f	/* DMMU tlb demap */

#define	ASI_TLB_INVALIDATE 0x60 /* TLB invalidate registers */

#define	ASI_ICACHE_INSTR 0x66
#define	ASI_ICACHE_TAG	0x67

#define	ASI_INTR_RCV	0x72	/* Interrupt receive register */
#define	ASI_INTR_UDB_W	0x73	/* Interrupt vector dispatch register */
#define	ASI_INTR_UDB_R	0x74	/* Incoming interrupt vector register */

#define	ASI_BLK_INIT_P	0xe2	/* Block initializing store, primary ctx */
#define	ASI_BLK_INIT_S	0xe3	/* Block initializing store, secondary ctx */
#define	ASI_BLK_INIT_P_LE 0xea	/* Block initializing store, primary ctx, le */
#define	XXX_ASI_BLK_INIT_S 0xeb	/* Block initializing store, sec ctx, le */

#define	HSCRATCH0	0x20	/* first hypervisor scratch register */
#define	HSCRATCH1	0x28	/* second hypervisor scratch register */

#define	ASI_MAU_CONTROL	0x80	/* MA control register */
#define	ASI_MAU_MPA	0x88	/* MA memory register */
#define	ASI_MAU_ADDR	0x90	/* MA module ops offsets register */
#define	ASI_MAU_NP	0x98	/* MA N prime value register */
#define	ASI_MAU_SYNC	0xA0	/* MA Sync register */

#ifdef __cplusplus
}
#endif

#endif /* _ASI_H */
