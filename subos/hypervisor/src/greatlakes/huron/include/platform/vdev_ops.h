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

#ifndef _PLATFORM_VDEV_OPS_H
#define	_PLATFORM_VDEV_OPS_H

#pragma ident	"@(#)vdev_ops.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Devops assignments to various nexii
 */

#define	DEVOPS_RESERVED		0

#ifdef CONFIG_PIU
#define	DEVOPS_PIU(n)		1
#define	DEVOPS_INT_PIU(n)	2
#define	DEVOPS_MSI_PIU(n)	3
#define	DEVOPS_ERR_PIU(n)	4
#else /* CONFIG_PIU */
#define	DEVOPS_PIU(n)		DEVOPS_RESERVED
#define	DEVOPS_INT_PIU(n)	DEVOPS_RESERVED
#define	DEVOPS_MSI_PIU(n)	DEVOPS_RESERVED
#define	DEVOPS_ERR_PIU(n)	DEVOPS_RESERVED
#endif /* CONFIG_PIU */

#define	DEVOPS_NIU		5
#define	DEVOPS_VDEV		6
#define	DEVOPS_CDEV		7

#ifdef	CONFIG_FPGA_UART
#define	DEVOPS_FPGA		8
#else	/* !CONFIG_FPGA_UART */
#define	DEVOPS_FPGA		DEVOPS_RESERVED
#endif	/* !CONFIG_FPGA_UART */

/*
 * NIU nexus
 */
#define	NIU_COOKIE	((void *)&niu_dev)

#define	VINO_HANDLER_NIU \
	DEVOPS_NIU, DEVOPS_NIU,	/* 00 - 01 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 02 - 03 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 04 - 05 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 06 - 07 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 08 - 09 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 10 - 11 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 12 - 13 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 14 - 15 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 16 - 17 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 18 - 19 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 20 - 21 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 22 - 23 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 24 - 25 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 26 - 27 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 28 - 29 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 30 - 31 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 32 - 33 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 34 - 35 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 36 - 37 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 38 - 39 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 40 - 41 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 42 - 33 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 44 - 45 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 46 - 47 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 48 - 49 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 50 - 51 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 52 - 53 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 54 - 55 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 56 - 57 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 58 - 59 */ \
	DEVOPS_NIU, DEVOPS_NIU,	/* 60 - 61 */ \
	DEVOPS_NIU, DEVOPS_NIU	/* 62 - 63 */

#define	NIU_OPS \
	INTR_OPS(niu), MONDO_OPS(NULL), VINO_OPS(niu),	\
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)


/*
 * Piu nexus
 */
#ifdef CONFIG_PIU

#define	PIU_LEAF(n)	PIU_AID
#define	PIU_DEV_COOKIE(n) (struct piu_cookie *)&piu_dev[PIU_LEAF(n)]
#define	PIU_MSI_COOKIE(n) (struct piu_msi_cookie *)&piu_msi[PIU_LEAF(n)]
#define	PIU_ERR_COOKIE(n) (struct piu_err_cookie *)&piu_err[PIU_LEAF(n)]

/*
 * Functions with first arg as devhandle
 */
#define	PIU_DEV_OPS \
	INTR_OPS(piu), MONDO_OPS(NULL), VINO_OPS(NULL), \
		VPCI_OPS(piu), MSI_OPS(piu), PERF_OPS(piu)

/*
 * Functions with first arg as vINO
 */
#define	PIU_INT_OPS \
	INTR_OPS(NULL), MONDO_OPS(piu), VINO_OPS(piu), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * MSI functions
 */
#define	PIU_MSI_OPS \
		INTR_OPS(NULL), MONDO_OPS(piu_msi), VINO_OPS(piu), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * Piu Error INOs
 */
#define	PIU_ERR_OPS \
	INTR_OPS(NULL), MONDO_OPS(piu_err), VINO_OPS(piu_err), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * FPGA INOs
 */
#ifdef CONFIG_FPGA_UART

#define	FPGA_UART_COOKIE	(struct fpga_uart_cookie *)&fpga_uart_dev

#define	FPGA_UART_OPS \
	INTR_OPS(NULL), MONDO_OPS(fpga_uart), VINO_OPS(fpga_uart), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

#else /* !CONFIG_FPGA_UART */

#define	FPGA_UART_OPS	NULL_DEV_OPS

#define	FPGA_UART_COOKIE	0

#endif /* !CONFIG_FPGA_UART */

#define	VINO_HANDLER_PIU(n) \
	/* Standard INOs from devices */		      \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 00 - 01 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 02 - 03 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 04 - 05 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 06 - 07 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 08 - 09 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 10 - 11 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 12 - 13 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 14 - 15 */ \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 16 - 17 */ \
	DEVOPS_RESERVED, DEVOPS_FPGA,		/* 18 - 19 */ \
	/* INTx emulation */				      \
	DEVOPS_INT_PIU(n), DEVOPS_INT_PIU(n),	/* 20 - 21 */ \
	DEVOPS_INT_PIU(n), DEVOPS_INT_PIU(n),	/* 22 - 23 */ \
	/* MSI QUEUEs */				      \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 24 - 25 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 26 - 27 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 28 - 29 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 30 - 31 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 32 - 33 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 34 - 35 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 36 - 37 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 38 - 39 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 40 - 41 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 42 - 43 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 44 - 45 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 46 - 47 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 48 - 49 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 50 - 51 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 52 - 53 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 54 - 55 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 56 - 57 */ \
	DEVOPS_MSI_PIU(n), DEVOPS_MSI_PIU(n),	/* 58 - 59 */ \
	/* I2C Interrupts */				      \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 60 - 61 */ \
	/* Error Interrupts */				      \
	DEVOPS_ERR_PIU(n), DEVOPS_ERR_PIU(n)	/* 62 - 63 */


#else /* !CONFIG_PIU */

#define	PIU_DEV_COOKIE(n) 0
#define	PIU_MSI_COOKIE(n) 0
#define	PIU_ERR_COOKIE(n) 0
#define	PIU_DEV_OPS	NULL_DEV_OPS
#define	PIU_INT_OPS	NULL_DEV_OPS
#define	PIU_MSI_OPS	NULL_DEV_OPS
#define	PIU_ERR_OPS	NULL_DEV_OPS

#endif /* !CONFIG_PIU */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_VDEV_OPS_H */
