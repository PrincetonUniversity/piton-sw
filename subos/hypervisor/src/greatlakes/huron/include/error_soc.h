/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: error_soc.h
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

#ifndef _NIAGARA2_ERROR_SOC_H
#define	_NIAGARA2_ERROR_SOC_H

#pragma ident	"@(#)error_soc.h	1.2	07/06/20 SMI"

#include <sys/htypes.h>

#ifdef __cplusplus
extern "C" {
#endif

#define	SOC_ERROR_STATUS_REG		0x8000003000
#define	SOC_ERROR_LOG_ENABLE		0x8000003008
#define	SOC_ERROR_TRAP_ENABLE		0x8000003010
#define	SOC_ERROR_INJECTION_REG		0x8000003018
#define	SOC_FATAL_ERROR_ENABLE		0x8000003020
#define	SOC_PENDING_ERROR_STATUS_REG	0x8000003028
#define	SOC_SII_ERROR_SYNDROME_REG	0x8000003030
#define	SOC_NCU_ERROR_SYNDROME_REG	0x8000003038
#define	SOC_ERRORSTEER_REG		0x9001041000

/*
 * All SOC ESRs have the same format
 */
#define	SOC_SIINIUCTAGUE		(1 << 0)
#define	SOC_SIIDMUCTAGUE		(1 << 1)
#define	SOC_SIINIUCTAGCE		(1 << 2)
#define	SOC_SIIDMUCTAGCE		(1 << 3)
#define	SOC_SIINIUAPARITY		(1 << 4)
#define	SOC_SIIDMUDPARITY		(1 << 5)
#define	SOC_SIINIUDPARITY		(1 << 6)
#define	SOC_SIIDMUAPARITY		(1 << 7)
#define	SOC_DMUINTERNAL			(1 << 8)
#define	SOC_DMUNCUCREDIT		(1 << 9)
#define	SOC_DMUCTAGCE			(1 << 10)
#define	SOC_DMUCTAGUE			(1 << 11)
#define	SOC_DMUSIICREDIT		(1 << 12)
#define	SOC_DMUDATAPARITY		(1 << 13)
#define	SOC_NCUDATAPARITY		(1 << 14)
#define	SOC_NCUMONDOTABLE		(1 << 15)
#define	SOC_NCUMONDOFIFO		(1 << 16)
#define	SOC_NCUINTTABLE			(1 << 17)
#define	SOC_NCUPCXDATA			(1 << 18)
#define	SOC_NCUPCXUE			(1 << 19)
#define	SOC_NCUCPXUE			(1 << 20)
#define	SOC_NCUDMUUE			(1 << 21)
#define	SOC_NCUCTAGUE			(1 << 22)
#define	SOC_NCUCTAGCE			(1 << 23)
#define	SOC_SIOCTAGUE			(1 << 25)
#define	SOC_SIOCTAGCE			(1 << 26)
#define	SOC_NIUCTAGCE			(1 << 27)
#define	SOC_NIUCTAGUE			(1 << 28)
#define	SOC_NIUDATAPARITY		(1 << 29)
#define	SOC_MCU0FBR			(1 << 31)
#define	SOC_MCU0ECC			(1 << 32)
#define	SOC_MCU1FBR			(1 << 34)
#define	SOC_MCU1ECC			(1 << 35)
#define	SOC_MCU2FBR			(1 << 37)
#define	SOC_MCU2ECC			(1 << 38)
#define	SOC_MCU3FBR			(1 << 40)
#define	SOC_MCU3ECC			(1 << 41)
#define	SOC_NCUDMUCREDIT		(1 << 42)
#define	SOC_V				(1 << 63)

#define	SOC_ALL_ERRORS						\
	(SOC_NCUDMUCREDIT | SOC_MCU3ECC | SOC_MCU3FBR |		\
	SOC_MCU2ECC | SOC_MCU2FBR | SOC_MCU1ECC | SOC_MCU1FBR |	\
	SOC_MCU0ECC | SOC_MCU0FBR | SOC_NIUDATAPARITY |		\
	SOC_NIUCTAGUE | SOC_NIUCTAGCE | SOC_SIOCTAGCE |		\
	SOC_SIOCTAGUE | SOC_NCUCTAGCE | SOC_NCUCTAGUE |		\
	SOC_NCUDMUUE | SOC_NCUCPXUE | SOC_NCUPCXUE |		\
	SOC_NCUPCXDATA | SOC_NCUINTTABLE | SOC_NCUMONDOFIFO |	\
	SOC_NCUMONDOTABLE |SOC_NCUDATAPARITY |			\
	SOC_DMUDATAPARITY | SOC_DMUSIICREDIT | SOC_DMUCTAGUE |	\
	SOC_DMUCTAGCE | SOC_DMUNCUCREDIT | SOC_DMUINTERNAL |	\
	SOC_SIIDMUAPARITY | SOC_SIINIUDPARITY |			\
	SOC_SIIDMUDPARITY | SOC_SIINIUAPARITY |			\
	SOC_SIIDMUCTAGCE | SOC_SIINIUCTAGCE | 			\
	SOC_SIIDMUCTAGUE | SOC_SIINIUCTAGUE)

#define	SOC_CORRECTABLE_ERRORS					\
	(SOC_MCU3ECC | SOC_MCU3FBR | SOC_MCU2ECC | SOC_MCU2FBR |\
	SOC_MCU1ECC | SOC_MCU1FBR | SOC_MCU0ECC | SOC_MCU0FBR | \
	SOC_NIUCTAGCE | SOC_SIOCTAGCE | SOC_NCUCTAGCE | \
	SOC_SIIDMUCTAGCE | SOC_SIINIUCTAGCE)

#define	SOC_FATAL_ERRORS					\
	(SOC_ALL_ERRORS & ~SOC_CORRECTABLE_ERRORS)

#define	SUN4V_DESC_FLAGS_TBD	0

#define	SUN4V_SIINIUDPARITY	ERR_PCIE_ERPT_DESC(1, 2, 2, 3, 2, 1)
#define	SUN4V_SIIDMUDPARITY	ERR_PCIE_ERPT_DESC(1, 2, 2, 3, 2, 1)
#define	SUN4V_NCUMONDOTABLE	ERR_PCIE_ERPT_DESC(1, 1, 2, 3, 1, \
		SUN4V_DESC_FLAGS_TBD)
#define	SUN4V_NCUPCXDATA	ERR_PCIE_ERPT_DESC(1, 2, 2, 3, 0, 1)

/*
 * SOC NCU Error Syndrome register
 *
 * +------------------------------------------------------------+
 * |63|62|61|60|59|58|57:56|55:51|  50:46| 45:43|  42:40|   39:0|
 * +------------------------------------------------------------+
 * | v| g| r| c| s| p|  -  | etag|reqtype|coreid|standid|pa_ctag|
 * +------------------------------------------------------------+
 */
#define	SOC_NCU_ESR_V_SHIFT		63	/* syndrome valid bit */
#define	SOC_NCU_ESR_V			(1 << SOC_NCU_ESR_V_SHIFT)
#define	SOC_NCU_ESR_G_SHIFT		62	/* CTAG valid bit */
#define	SOC_NCU_ESR_G			(1 << SOC_NCU_ESR_G_SHIFT)
#define	SOC_NCU_ESR_R_SHIFT		61	/* reqtype valid bit */
#define	SOC_NCU_ESR_R			(1 << SOC_NCU_ESR_R_SHIFT)
#define	SOC_NCU_ESR_C_SHIFT		60	/* coreid valid bit */
#define	SOC_NCU_ESR_C			(1 << SOC_NCU_ESR_C_SHIFT)
#define	SOC_NCU_ESR_S_SHIFT		59	/* strandid valid bit */
#define	SOC_NCU_ESR_S			(1 << SOC_NCU_ESR_S_SHIFT)
#define	SOC_NCU_ESR_P_SHIFT		58	/* PA valid bit */
#define	SOC_NCU_ESR_P			(1 << SOC_NCU_ESR_P_SHIFT)
#define	SOC_NCU_ESR_ETAG_SHIFT		51	/* Error tag */
#define	SOC_NCU_ESR_ETAG_MASK		0x1f
#define	SOC_NCU_ESR_REQTYPE_SHIFT	46	/* request type */
#define	SOC_NCU_ESR_REQTYPE_MASK	0x1f
#define	SOC_NCU_ESR_COREID_SHIFT	43	/* Physical strand id */
#define	SOC_NCU_ESR_COREID_MASK		0x7
#define	SOC_NCU_ESR_STRANDID_SHIFT	40	/* Strand id on physical core */
#define	SOC_NCU_ESR_STRANDID_MASK	0x7
/* PA[39:0] if p is set. CTAG[15:0] if g is set */
#define	SOC_NCU_ESR_PA_SHIFT		0
#define	SOC_NCU_ESR_PA_MASK		0xffffffffff
#define	SOC_NCU_ESR_PA_MSB_MASK		0xff00000000

/*
 * Filter FBRs to minimise the number of SERs sent to the SP.
 */
#define	DRAM_ERROR_COUNTER_FBR_RATIO		8

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_ERROR_SOC_H */
