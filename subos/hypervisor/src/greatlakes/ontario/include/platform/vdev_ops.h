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

#ifdef CONFIG_FIRE
#define	DEVOPS_FIRE_A		1
#define	DEVOPS_FIRE_B		2
#define	DEVOPS_INT_FIRE_A	3
#define	DEVOPS_INT_FIRE_B	4
#define	DEVOPS_MSI_FIRE_A	5
#define	DEVOPS_MSI_FIRE_B	6
#define	DEVOPS_ERR_FIRE_A	7
#define	DEVOPS_ERR_FIRE_B	8
#else /* CONFIG_FIRE */
#define	DEVOPS_FIRE_A		DEVOPS_RESERVED
#define	DEVOPS_FIRE_B		DEVOPS_RESERVED
#define	DEVOPS_INT_FIRE_A	DEVOPS_RESERVED
#define	DEVOPS_INT_FIRE_B	DEVOPS_RESERVED
#define	DEVOPS_MSI_FIRE_A	DEVOPS_RESERVED
#define	DEVOPS_MSI_FIRE_B	DEVOPS_RESERVED
#define	DEVOPS_ERR_FIRE_A	DEVOPS_RESERVED
#define	DEVOPS_ERR_FIRE_B	DEVOPS_RESERVED
#endif /* CONFIG_FIRE */

#define	DEVOPS_VDEV		9

#define	DEVOPS_CDEV		10

/*
 * Fire nexus
 */
#ifdef CONFIG_FIRE

#define	FIRE_LEAF(n)	(FIRE_##n##_AID) & (NFIRELEAVES-1)
#define	FIRE_DEV_COOKIE(n) (struct fire_cookie *)&fire_dev[FIRE_LEAF(n)]
#define	FIRE_MSI_COOKIE(n) (struct fire_msi_cookie *)&fire_msi[FIRE_LEAF(n)]
#define	FIRE_ERR_COOKIE(n) (struct fire_err_cookie *)&fire_err[FIRE_LEAF(n)]

/*
 * Functions with first arg as devhandle
 */
#define	FIRE_DEV_OPS \
	INTR_OPS(fire), MONDO_OPS(NULL), VINO_OPS(NULL), \
		VPCI_OPS(fire), MSI_OPS(fire), PERF_OPS(fire)

/*
 * Functions with first arg as vINO
 */
#define	FIRE_INT_OPS \
	INTR_OPS(NULL), MONDO_OPS(fire), VINO_OPS(fire), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * MSI functions
 */
#define	FIRE_MSI_OPS \
		INTR_OPS(NULL), MONDO_OPS(fire_msi), VINO_OPS(fire), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

/*
 * Fire Error INOs
 */
#define	FIRE_ERR_OPS \
	INTR_OPS(NULL), MONDO_OPS(fire_err), VINO_OPS(fire_err), \
		VPCI_OPS(NULL), MSI_OPS(NULL), PERF_OPS(NULL)

#define	DEVOPS_INT_FIRE(n)	(DEVOPS_INT_FIRE_##n)
#define	DEVOPS_MSI_FIRE(n)	(DEVOPS_MSI_FIRE_##n)
#define	DEVOPS_ERR_FIRE(n)	(DEVOPS_ERR_FIRE_##n)

#define	VINO_HANDLER_FIRE(n) \
	/* Standard INOs from devices */		      \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 00 - 01 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 02 - 03 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 04 - 05 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 06 - 07 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 08 - 09 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 10 - 11 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 12 - 13 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 14 - 15 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 16 - 17 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 18 - 19 */ \
	/* INTx emulation */				      \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 20 - 21 */ \
	DEVOPS_INT_FIRE(n), DEVOPS_INT_FIRE(n),	/* 22 - 23 */ \
	/* MSI QUEUEs */				      \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 24 - 25 */	\
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 26 - 27 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 28 - 29 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 30 - 31 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 32 - 33 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 34 - 35 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 36 - 37 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 38 - 39 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 40 - 41 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 42 - 43 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 44 - 45 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 46 - 47 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 48 - 49 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 50 - 51 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 52 - 53 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 54 - 55 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 56 - 57 */ \
	DEVOPS_MSI_FIRE(n), DEVOPS_MSI_FIRE(n),	/* 58 - 59 */ \
	/* I2C Interrupts */				      \
	DEVOPS_RESERVED, DEVOPS_RESERVED,	/* 60 - 61 */ \
	/* Error Interrupts */				      \
	DEVOPS_ERR_FIRE(n), DEVOPS_ERR_FIRE(n)	/* 62 - 63 */


#else /* !CONFIG_FIRE */

#define	FIRE_DEV_COOKIE(n) 0
#define	FIRE_MSI_COOKIE(n) 0
#define	FIRE_ERR_COOKIE(n) 0
#define	FIRE_DEV_OPS	NULL_DEV_OPS
#define	FIRE_INT_OPS	NULL_DEV_OPS
#define	FIRE_MSI_OPS	NULL_DEV_OPS
#define	FIRE_ERR_OPS	NULL_DEV_OPS

#endif /* !CONFIG_FIRE */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_VDEV_OPS_H */
