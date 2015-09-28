/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: dram.h
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

#ifndef _PLATFORM_DRAM_H
#define	_PLATFORM_DRAM_H

#pragma ident	"@(#)dram.h	1.2	07/06/20 SMI"

/*
 * Niagara2 DRAM definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	DRAM_BASE			(0x84 << 32)
#define	DRAM_ERROR_RETRY_REG		0x2a8
#define	DRAM_ERROR_FBD_SYNDROME_REG	0xc00
#define	DRAM_ERROR_FBD_COUNTER_REG	0xc10

#define	DRAM_ESR_ERROR_SHIFT		54	/* first error bit set */

#define	DRAM_ESR_MEU			(1 << 63)
#define	DRAM_ESR_MEC			(1 << 62)
#define	DRAM_ESR_DAC			(1 << 61)
#define	DRAM_ESR_DAU			(1 << 60)
#define	DRAM_ESR_DSC			(1 << 59)
#define	DRAM_ESR_DSU			(1 << 58)
#define	DRAM_ESR_DBU			(1 << 57)
#define	DRAM_ESR_MEB			(1 << 56)
#define	DRAM_ESR_FBU			(1 << 55)
#define	DRAM_ESR_FBR			(1 << 54)

/*
 * DRAM Error Retry Register (count 4 Step 4096)
 */
#define	DRAM_RETRY_OFFSET	DRAM_ERROR_RETRY_REG
#define	DRAM_RETRY_BASE		(DRAM_BASE + DRAM_RETRY_OFFSET)

/*
 * DRAM FBD Error Syndrome Register (count 4 Step 4096)
 */
#define	DRAM_FBD_OFFSET		DRAM_ERROR_FBD_SYNDROME_REG
#define	DRAM_FBD_BASE		(DRAM_BASE + DRAM_FBD_OFFSET)

/*
 * DRAM FBR Error Counter Register (count 4 Step 4096)
 */
#define	DRAM_FBR_COUNT_OFFSET	DRAM_ERROR_FBD_COUNTER_REG
#define	DRAM_FBR_COUNT_BASE	(DRAM_BASE + DRAM_FBR_COUNT_OFFSET)

/* BEGIN CSTYLED */
#define	SKIP_DISABLED_DRAM_BANK(bank, reg1, reg2, skip_label)		\
	setx	L2_BANK_ENABLE_STATUS, reg1, reg2			;\
	ldx	[reg2], reg2						;\
	srlx	reg2, L2_BANK_ENABLE_STATUS_SHIFT, reg2			;\
	and	reg2, L2_BANK_ENABLE_STATUS_MASK, reg2			;\
	or	%g0, bank, reg1						;\
	srlx	reg2, reg1, reg2					;\
	btst	1, reg2							;\
	bz,pn	%xcc, skip_label					;\
	nop								;\
	setx	DRAM_BASE, reg1, reg2 					;\
	or	reg2, DRAM_CHANNEL_DISABLE_REG, reg2			;\
	mov	bank, reg1						;\
	sllx	reg1, DRAM_BANK_SHIFT, reg1				;\
	or	reg2, reg1, reg2					;\
	ldx	[reg2], reg1						;\
	brnz,pn	reg1, skip_label					;\
	nop

#define	DRAM_SNGL_CHNL_MODE_REG		0x148
#define	DRAM_SNGL_CHNL_MODE_BASE	(DRAM_BASE + DRAM_SNGL_CHNL_MODE_REG)
#define	DRAM_DIMM_PRESENT_BASE		(DRAM_BASE + DRAM_DIMM_PRESENT_REG)

#define	CONFIG_REG_ACC_ADDR_REG		0x900
#define	CONFIG_REG_ACC_DATA_REG		0x908

#define	DRAM_CONFIG_REG_ACC_ADDR_BASE	(DRAM_BASE + CONFIG_REG_ACC_ADDR_REG)
#define	DRAM_CONFIG_REG_ACC_DATA_BASE	(DRAM_BASE + CONFIG_REG_ACC_DATA_REG)

#define	DRAM_FBDIMM_FERR		0x90
#define	DRAM_FBDIMM_NERR		0x94

/*	CONFIG_REG_ACCESS_ADDR_REG bit positions */
#define	CONFIG_ADDR_AMB_POS		11
#define	CONFIG_ADDR_CH_POS		15
#define	CONFIG_FUNCTION_SHIFT		8
#define	CONFIG_FUNCTION_FBD		1

/* END CSTYLED */
#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_DRAM_H */
