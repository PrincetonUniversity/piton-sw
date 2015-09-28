/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: error_regs.h
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

#ifndef _NIAGARA2_ERROR_REGS_H
#define	_NIAGARA2_ERROR_REGS_H

#pragma ident	"@(#)error_regs.h	1.4	07/07/25 SMI"

#include <sys/htypes.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Core errors
 */
#define	ERR_CWQL2ND		(1 << 0)
#define	ERR_CWQL2U		(1 << 1)
#define	ERR_CWQL2C		(1 << 2)
#define	ERR_MAL2ND		(1 << 3)
#define	ERR_MAL2U		(1 << 4)
#define	ERR_MAL2C		(1 << 5)
#define	ERR_TCUD		(1 << 6)
#define	ERR_TCCD		(1 << 7)
#define	ERR_MAMU		(1 << 8)
#define	ERR_SBDPU_SBPIOU	(1 << 9)
#define	ERR_SBDPC		(1 << 10)
#define	ERR_DCDP		(1 << 11)
#define	ERR_DCTM		(1 << 12)
#define	ERR_DCTP		(1 << 13)
#define	ERR_DCVP		(1 << 14)
#define	ERR_ICDP		(1 << 15)
#define	ERR_ICTM		(1 << 16)
#define	ERR_ICTP		(1 << 17)
#define	ERR_ICVP		(1 << 18)
#define	ERR_L2ND		(1 << 19)
#define	ERR_L2U_SOCU		(1 << 20)
#define	ERR_L2C_SOCC		(1 << 21)
#define	ERR_SBAPP		(1 << 23)
#define	ERR_TCUP		(1 << 27)
#define	ERR_TCCP		(1 << 28)
#define	ERR_SCAU		(1 << 29)
#define	ERR_SCAC		(1 << 30)
#define	ERR_TSAU		(1 << 31)
#define	ERR_TSAC		(1 << 32)
#define	ERR_MRAU		(1 << 33)
#define	ERR_SBDLU		(1 << 36)
#define	ERR_SBDLC		(1 << 37)
#define	ERR_DCL2ND		(1 << 38)
#define	ERR_DCL2U		(1 << 39)
#define	ERR_DCL2C		(1 << 40)
#define	ERR_DTDP		(1 << 46)
#define	ERR_DTTM		(1 << 47)
#define	ERR_DTTP		(1 << 48)
#define	ERR_FRF			(1 << 50)
#define	ERR_IRF			(1 << 52)
#define	ERR_ICL2ND		(1 << 53)
#define	ERR_ICL2U		(1 << 54)
#define	ERR_ICL2C		(1 << 55)
#define	ERR_HWTWL2		(1 << 58)
#define	ERR_HWTWMU		(1 << 59)
#define	ERR_ITTM		(1 << 61)
#define	ERR_ITDP		(1 << 62)
#define	ERR_ITTP		(1 << 63)

#define	CORE_ERRORS_ENABLE			\
	(ERR_ITTP | ERR_ITDP | ERR_ITTM | ERR_HWTWMU |		\
	    ERR_HWTWL2 | ERR_ICL2C | ERR_ICL2U | ERR_ICL2ND |	\
	    ERR_IRF | ERR_FRF | ERR_DTTP | ERR_DTTM |		\
	    ERR_DTDP | ERR_DCL2C | ERR_DCL2U | ERR_DCL2ND |	\
	    ERR_SBDLC |	ERR_SBDLU | ERR_MRAU | ERR_TSAC |	\
	    ERR_TSAU | ERR_SCAC | ERR_SCAU | ERR_TCCP |		\
	    ERR_TCUP | ERR_SBAPP | ERR_L2C_SOCC | ERR_L2U_SOCU |\
	    ERR_L2ND | ERR_ICVP | ERR_ICTP | ERR_ICTM |		\
	    ERR_ICDP | ERR_DCVP | ERR_DCTP | ERR_DCTM |		\
	    ERR_DCDP | ERR_SBDPC | ERR_SBDPU_SBPIOU | ERR_MAMU |\
	    ERR_TCCD | ERR_TCUD | ERR_MAL2C | ERR_MAL2U |	\
	    ERR_MAL2ND | ERR_CWQL2C | ERR_CWQL2U | ERR_CWQL2ND)

#define	CORE_ICACHE_ERRORS_ENABLE	(ERR_ICL2C)
#define	CORE_DCACHE_ERRORS_ENABLE	(ERR_DCL2C)
#define	CORE_DRAM_ERRORS_ENABLE		(ERR_L2C_SOCC)

/*
 * Trap enables
 */
#define	ERR_DHCCE	(1 << 60)
#define	ERR_DE		(1 << 61)
#define	ERR_PSCCE	(1 << 62)

#define	CORE_ERROR_TRAP_ENABLE			\
	(ERR_DHCCE | ERR_DE | ERR_PSCCE)

/*
 * I-SFSR errors
 */
#define	ISFSR_ERRTYPE_MASK	0x7
#define	ISFSR_ITTM		1
#define	ISFSR_ITTP		2
#define	ISFSR_ITDP		3
#define	ISFSR_ITMU		4
#define	ISFSR_ITL2U		5
#define	ISFSR_ITL2ND		6
#define	ISFSR_ICL2U		1
#define	ISFSR_ICL2ND		2

/*
 * D-SFSR errors
 */
#define	DSFSR_ERRTYPE_MASK	0xf

/*
 * Data Access MMU errors
 */
#define	DSFSR_DTTM		1
#define	DSFSR_DTTP		2
#define	DSFSR_DTDP		3
#define	DSFSR_DTMU		4
#define	DSFSR_DTL2U		5
#define	DSFSR_DTL2ND		6

/*
 * Data Access errors
 */
#define	DSFSR_DCL2U		1
#define	DSFSR_DCL2ND		2
#define	DSFSR_SOCU		4
/*
 * Internal Processor errors
 */
#define	DSFSR_IRFU		1
#define	DSFSR_IRFC		2
#define	DSFSR_FRFU		3
#define	DSFSR_FRFC		4
#define	DSFSR_SBDLC		5
#define	DSFSR_SBDLU		6
#define	DSFSR_MRAU		7
#define	DSFSR_TSAC		8
#define	DSFSR_TSAU		9
#define	DSFSR_SCAC		10
#define	DSFSR_SCAU		11
#define	DSFSR_TCCP		12
#define	DSFSR_TCUP		13

#define	ASI_DFESR		0x4c
#define	DFESR_VA		0x8
#define	DFESR_ERRTYPE_MASK	0x3
#define	DFESR_ERRTYPE_SHIFT	60
#define	DFESR_STB_INDEX_MASK	0x7
#define	DFESR_STB_INDEX_SHIFT	55

/*
 * ICache Diagnostic registers
 */
#define	ASI_ICACHE_INSTR_WORD_SHIFT	3
#define	ASI_ICACHE_INSTR_INDEX_SHIFT	6
#define	ASI_ICACHE_INSTR_WAY_SHIFT	12
#define	ASI_ICACHE_TAG_INDEX_SHIFT	6
#define	ASI_ICACHE_TAG_WAY_SHIFT	12
#define	ASI_DCACHE_DATA_INDEX_SHIFT	4
#define	ASI_DCACHE_DATA_WAY_SHIFT	11
#define	ASI_DCACHE_TAG_INDEX_SHIFT	4
#define	ASI_DCACHE_TAG_WAY_SHIFT	11

#define	ASI_ICACHE_INDEX_MASK		0x1f
#define	ASI_DCACHE_INDEX_MASK		0x3f

/*
 * Store Buffer Diagnostic Registers
 */
#define	ASI_STB_ACCESS			0x4a
#define	ASI_STB_ENTRY_MASK		0x7
#define	ASI_STB_ENTRY_SHIFT		3
#define	ASI_STB_FIELD_MASK		0x7
#define	ASI_STB_FIELD_SHIFT		6
#define	ASI_STB_FIELD_DATA		(0x0 << ASI_STB_FIELD_SHIFT)
#define	ASI_STB_FIELD_DATA_ECC		(0x1 << ASI_STB_FIELD_SHIFT)
#define	ASI_STB_FIELD_PARITY		(0x2 << ASI_STB_FIELD_SHIFT)
#define	ASI_STB_FIELD_MARKS		(0x3 << ASI_STB_FIELD_SHIFT)
#define	ASI_STB_FIELD_CURR_PTR		(0x4 << ASI_STB_FIELD_SHIFT)

/*
 * Scratchpad Diagnostic Registers
 */
#define	ASI_SCRATCHPAD_ACCESS		0x59
#define	ASI_SCRATCHPAD_INDEX_MASK	0x7
#define	ASI_SCRATCHPAD_INDEX_SHIFT	3
#define	ASI_SCRATCHPAD_DATA_NP_SHIFT	6
#define	ASI_SCRATCHPAD_DATA_NP_ECC	(0 << ASI_SCRATCHPAD_DATA_NP_SHIFT)
#define	ASI_SCRATCHPAD_DATA_NP_DATA	(1 << ASI_SCRATCHPAD_DATA_NP_SHIFT)

#define	DSFAR_SCRATCHPAD_INDEX_MASK	0x7
#define	DSFAR_SCRATCHPAD_INDEX_SHIFT	0
#define	DSFAR_SCRATCHPAD_SYNDROME_MASK	0xff
#define	DSFAR_SCRATCHPAD_SYNDROME_SHIFT	3

/*
 * Trap Stack Array Diagnostic Registers
 */
#define	ASI_TSA_ACCESS			0x5B
#define	ASI_TSA_INDEX_MASK		0x7
#define	ASI_TSA_INDEX_SHIFT		3
#define	DSFAR_TSA_INDEX_MASK		0x7
#define	DSFAR_TSA_INDEX_SHIFT		0
#define	DSFAR_TSA_ODD_SYNDROME_SHIFT	11
#define	DSFAR_TSA_EVEN_SYNDROME_SHIFT	3
#define	DSFAR_TSA_SYNDROME_MASK		0xff

#define	TSA_TNPC_LO_BIT			0
#define	TSA_TNPC_HI_BIT			45
#define	TSA_TPC_LO_BIT			46
#define	TSA_TPC_HI_BIT			91
#define	TSA_TT_LO_BIT			92
#define	TSA_TT_HI_BIT			100
#define	TSA_TSTATE_CWP_LO_BIT		101
#define	TSA_TSTATE_CWP_HI_BIT		103
#define	TSA_HTSTATE_TLZ_LO_BIT		104
#define	TSA_HTSTATE_TLZ_HI_BIT		104
#define	TSA_TSTATE_PSTATE_IE_LO_BIT	105
#define	TSA_TSTATE_PSTATE_IE_HI_BIT	105
#define	TSA_TSTATE_PSTATE_PRIV_LO_BIT	106
#define	TSA_TSTATE_PSTATE_PRIV_HI_BIT	106
#define	TSA_TSTATE_PSTATE_AM_LO_BIT	107
#define	TSA_TSTATE_PSTATE_AM_HI_BIT	107
#define	TSA_TSTATE_PSTATE_PEF_LO_BIT	108
#define	TSA_TSTATE_PSTATE_PEF_HI_BIT	108
#define	TSA_HTSTATE_RED_LO_BIT		109
#define	TSA_HTSTATE_RED_HI_BIT		109
#define	TSA_HTSTATE_PRIV_LO_BIT		110
#define	TSA_HTSTATE_PRIV_HI_BIT		110
#define	TSA_TSTATE_PSTATE_TCT_LO_BIT	111
#define	TSA_TSTATE_PSTATE_TCT_HI_BIT	111
#define	TSA_TSTATE_PSTATE_TLE_LO_BIT	112
#define	TSA_TSTATE_PSTATE_TLE_HI_BIT	112
#define	TSA_TSTATE_PSTATE_CLE_LO_BIT	113
#define	TSA_TSTATE_PSTATE_CLE_HI_BIT	113
#define	TSA_HTSTATE_IBE_LO_BIT		114
#define	TSA_HTSTATE_IBE_HI_BIT		114
#define	TSA_TSTATE_ASI_LO_BIT		115
#define	TSA_TSTATE_ASI_HI_BIT		122
#define	TSA_TSTATE_CCR_LO_BIT		123
#define	TSA_TSTATE_CCR_HI_BIT		130
#define	TSA_TSTATE_GL_LO_BIT		131
#define	TSA_TSTATE_GL_HI_BIT		132

#define	TSA_NONRES_ERR_QUEUE_TAIL_LO_BIT	14
#define	TSA_NONRES_ERR_QUEUE_TAIL_HI_BIT	21
#define	TSA_NONRES_ERR_QUEUE_HEAD_LO_BIT	22
#define	TSA_NONRES_ERR_QUEUE_HEAD_HI_BIT	29
#define	TSA_RES_ERR_QUEUE_TAIL_LO_BIT		30
#define	TSA_RES_ERR_QUEUE_TAIL_HI_BIT		37
#define	TSA_RES_ERR_QUEUE_HEAD_LO_BIT		38
#define	TSA_RES_ERR_QUEUE_HEAD_HI_BIT		45
#define	TSA_DEV_QUEUE_TAIL_LO_BIT		60
#define	TSA_DEV_QUEUE_TAIL_HI_BIT		67
#define	TSA_DEV_QUEUE_HEAD_LO_BIT		68
#define	TSA_DEV_QUEUE_HEAD_HI_BIT		75
#define	TSA_MONDO_QUEUE_TAIL_LO_BIT		76
#define	TSA_MONDO_QUEUE_TAIL_HI_BIT		83
#define	TSA_MONDO_QUEUE_HEAD_LO_BIT		84
#define	TSA_MONDO_QUEUE_HEAD_HI_BIT		91

/*
 * MMU Register Array Diagnostic Registers
 */
#define	ASI_MRA_ACCESS			0x51
#define	ASI_MRA_INDEX_MASK		0x7
#define	ASI_MRA_INDEX_SHIFT		3
#define	DSFAR_MRA_INDEX_MASK		0x7
#define	DSFAR_MRA_INDEX_SHIFT		0
#define	MRA_PARITY_MASK			0x3

/*
 * Tick_compare Diagnostic Registers
 */
#define	ASI_TICK_ACCESS			0x5a
#define	ASI_TICK_INDEX_MASK		0x3
#define	ASI_TICK_INDEX_SHIFT		3
#define	ASI_TICK_DATA_NP_SHIFT		5
#define	ASI_TICK_DATA_NP_ECC		(0 << ASI_TICK_DATA_NP_SHIFT)
#define	ASI_TICK_DATA_NP_DATA		(1 << ASI_TICK_DATA_NP_SHIFT)

#define	DSFAR_TCA_INDEX_MASK		0x3
#define	DSFAR_TCA_INDEX_SHIFT		0
#define	DSFAR_TCA_SYNDROME_MASK		0xff
#define	DSFAR_TCA_SYNDROME_SHIFT	2

/*
 * The ASR the TCA index refers to
 */
#define	TCA_TICK_CMPR			0
#define	TCA_STICK_CMPR			1
#define	TCA_HSTICK_COMPARE		2

/*
 * L2 cache registers
 */
#define	L2_ERROR_ENABLE_REG		0xaa00000000
#define	L2_ERROR_STATUS_REG		0xab00000000
#define	L2_ERROR_ADDRESS_REG		0xac00000000
#define	L2_ERROR_NOTDATA_REG		0xae00000000

#define	L2_ESR_SYND_MASK		0x7ffffff
#define	L2_ESR_SYND_SHIFT		0
#define	L2_ESR_VCID_MASK		0x3f
#define	L2_ESR_VCID_SHIFT		54
#define	L2_ESR_MODA_MASK		0x1
#define	L2_ESR_MODA_SHIFT		60
#define	L2_ESR_RW_MASK			0x1
#define	L2_ESR_RW_SHIFT			61
#define	L2_ESR_MEC_MASK			0x1

#define	L2_ESR_MEC_SHIFT		62
#define	L2_ESR_MEU_SHIFT		63
#define	L2_ESR_ERROR_SHIFT		34	/* first error bit */

/*
 * L2 ESR error types
 */
#define	L2_ESR_LVC			(1 << 34)
#define	L2_ESR_VEU			(1 << 35)
#define	L2_ESR_VEC			(1 << 36)
#define	L2_ESR_DSU			(1 << 37)
#define	L2_ESR_DSC			(1 << 38)
#define	L2_ESR_DRU			(1 << 39)
#define	L2_ESR_DRC			(1 << 40)
#define	L2_ESR_DAU			(1 << 41)
#define	L2_ESR_DAC			(1 << 42)
#define	L2_ESR_LVF			(1 << 43)
#define	L2_ESR_LRF			(1 << 44)
#define	L2_ESR_LTC			(1 << 45)
#define	L2_ESR_LDSU			(1 << 46)
#define	L2_ESR_LDSC			(1 << 47)
#define	L2_ESR_LDRU			(1 << 48)
#define	L2_ESR_LDRC			(1 << 49)
#define	L2_ESR_LDWU			(1 << 50)
#define	L2_ESR_LDWC			(1 << 51)
#define	L2_ESR_LDAU			(1 << 52)
#define	L2_ESR_LDAC			(1 << 53)

#define	L2_ESR_ERRORS			\
	(L2_ESR_LDAC | L2_ESR_LDAU | L2_ESR_LDWC | L2_ESR_LDWU | 	\
	    L2_ESR_LDRC | L2_ESR_LDRU | L2_ESR_LDSC | L2_ESR_LDSU | 	\
	    L2_ESR_LTC | L2_ESR_LRF | L2_ESR_LVF | L2_ESR_DAC |     	\
	    L2_ESR_DAU | L2_ESR_DRC | L2_ESR_DRU | L2_ESR_DSC |     	\
	    L2_ESR_DSU | L2_ESR_LVC)

#define	L2_ESR_CE_ERRORS			\
	(L2_ESR_LDAC | L2_ESR_LDWC | L2_ESR_LDRC | L2_ESR_LDSC |	\
	    L2_ESR_LTC | L2_ESR_DAC | L2_ESR_DRC | L2_ESR_DSC |     	\
	    L2_ESR_LVC | L2_ESR_VEC)

/*
 * L2 cache Addressing
 *
 *	Tag	Set	Bank
 *	39:18	17:9	8:6
 */
#define	L2_CACHE_TAG_MASK		0x0x1fffff
#define	L2_CACHE_TAG_SHIFT		18
#define	L2_CACHE_SET_MASK		0xff
#define	L2_CACHE_SET_SHIFT		9
#define	L2_CACHE_BANK_MASK		0x7
#define	L2_CACHE_BANK_SHIFT		6

/*
 * Register file errors
 */
#define	ASI_IRF_ECC_REG			0x48
#define	ASI_FRF_ECC_REG			0x49
#define	ASI_IRF_ECC_INDEX_MASK		0x1f
#define	ASI_IRF_ECC_INDEX_SHIFT		3
#define	ASI_FRF_ECC_INDEX_MASK		0x1f
#define	ASI_FRF_ECC_INDEX_SHIFT		2
#define	ASI_FRF_ECC_EVEN_SHIFT		7
#define	ASI_FRF_ECC_ODD_MASK		0x7f
#define	DSFAR_FRF_INDEX_MASK		0x3f
#define	DSFAR_FRF_DBL_REG_MASK		0x3e
#define	DSFAR_FRF_INDEX_SHIFT		0
#define	DSFAR_FRF_ODD_SYNDROME_SHIFT	13
#define	DSFAR_FRF_EVEN_SYNDROME_SHIFT	6
#define	DSFAR_FRF_SYNDROME_MASK		0x7f
#define	DSFAR_IRF_INDEX_MASK		0x1f
#define	DSFAR_IRF_INDEX_SHIFT		0
#define	DSFAR_IRF_GL_SHIFT		5
#define	DSFAR_IRF_GL_MASK		0x3
#define	DSFAR_IRF_SYNDROME_SHIFT	7
#define	DSFAR_IRF_SYNDROME_MASK		0xff

/*
 * Disrupting Error Status Register
 */

#define	ASI_DESR		0x4c
#define	DESR_VA			0x0

#define	DESR_F_MASK		0x1
#define	DESR_F_SHIFT		63
#define	DESR_F			(1 << DESR_F_SHIFT)
#define	DESR_S_MASK		0x1
#define	DESR_S_SHIFT		61
#define	DESR_S			(1 << DESR_S_SHIFT)
#define	DESR_ME_MASK		0x1
#define	DESR_ME_SHIFT		62
#define	DESR_TRAP_TYPE_MASK	0x1
#define	DESR_TRAP_TYPE_SHIFT	61
#define	DESR_TRAP_TYPE_SW	(1 << DESR_TRAP_TYPE_SHIFT)
#define	DESR_TRAP_TYPE_HW	(0 << DESR_TRAP_TYPE_SHIFT)
#define	DESR_ERRTYPE_MASK	0x1f
#define	DESR_ERRTYPE_SHIFT	56
#define	DESR_ADDRESS_MASK	0x3ff
#define	DESR_ADDRESS_SHIFT	0

#define	DESR_L2U_ERRTYPE	16

/*
 * DESR Tick_compare data
 */
#define	DESR_TCA_INDEX_SHIFT	0
#define	DESR_TCA_INDEX_MASK	0x3
#define	DESR_TCA_SYNDROME_SHIFT	2
#define	DESR_TCA_SYNDROME_MASK	0xff

/*
 * Many ASIs have a set of registers with the VA starting from
 * 0x0 and incrementing by the ASI register size.
 */
#define	ASI_REGISTER_INCR		8

/*
 * Error Injection
 */
#define	ASI_ERROR_INJECT_REG		0x43

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_ERROR_REGS_H */
