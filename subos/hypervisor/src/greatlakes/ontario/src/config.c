/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: config.c
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

#pragma ident	"@(#)config.c	1.31	07/05/03 SMI"

/*
 * Guest configuration
 */

#include <sys/htypes.h>
#include <hypervisor.h>
#include <traps.h>
#include <cache.h>
#include <mmu.h>
#include <vdev_ops.h>
#include <vdev_intr.h>
#include <config.h>
#include <ncs.h>
#include <cyclic.h>
#include <vcpu.h>
#include <strand.h>
#include <guest.h>
#include <memory.h>
#include <pcie.h>
#include <fire.h>
#include <ldc.h>

#define	DEVOPS(n)	DEVOPS_##n

#define	_VINO_HANDLER(n) 			\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n),	\
	(n), (n), (n), (n), (n), (n), (n), (n)

#define	VINO_HANDLER(n)	_VINO_HANDLER(DEVOPS_##n)

extern void vdev_devino2vino(void);
extern void vdev_intr_getvalid(void);
extern void vdev_intr_setvalid(void);
extern void vdev_intr_settarget(void);
extern void vdev_intr_gettarget(void);
extern void vdev_intr_getstate(void);
extern void vdev_intr_setstate(void);

extern void ldc_vintr_getcookie(void);
extern void ldc_vintr_setcookie(void);
extern void ldc_vintr_getvalid(void);
extern void ldc_vintr_setvalid(void);
extern void ldc_vintr_gettarget(void);
extern void ldc_vintr_settarget(void);
extern void ldc_vintr_getstate(void);
extern void ldc_vintr_setstate(void);

#if defined(CONFIG_FIRE)

extern const uint64_t fire_a_iotsb;
extern const uint64_t fire_a_equeue;
extern const uint64_t fire_b_iotsb;
extern const uint64_t *fire_b_equeue;
extern const uint64_t fire_virtual_intmap;

#define	FIRE_EQ(leaf, n) \
	.base = (uint64_t *)&fire_##leaf##_equeue+(n*0x400), \
	.eqmask = FIRE_EQMASK

const struct fire_msi_cookie fire_msi[NFIRELEAVES] = {
	{
		.fire = FIRE_DEV_COOKIE(A),
		.eq = {
			{ FIRE_EQ(a,  0) }, { FIRE_EQ(a,  1) },
			{ FIRE_EQ(a,  2) }, { FIRE_EQ(a,  3) },
			{ FIRE_EQ(a,  4) }, { FIRE_EQ(a,  5) },
			{ FIRE_EQ(a,  6) }, { FIRE_EQ(a,  7) },
			{ FIRE_EQ(a,  8) }, { FIRE_EQ(a,  9) },
			{ FIRE_EQ(a, 10) }, { FIRE_EQ(a, 11) },
			{ FIRE_EQ(a, 12) }, { FIRE_EQ(a, 13) },
			{ FIRE_EQ(a, 14) }, { FIRE_EQ(a, 15) },
			{ FIRE_EQ(a, 16) }, { FIRE_EQ(a, 17) },
			{ FIRE_EQ(a, 18) }, { FIRE_EQ(a, 19) },
			{ FIRE_EQ(a, 20) }, { FIRE_EQ(a, 21) },
			{ FIRE_EQ(a, 22) }, { FIRE_EQ(a, 23) },
			{ FIRE_EQ(a, 24) }, { FIRE_EQ(a, 25) },
			{ FIRE_EQ(a, 26) }, { FIRE_EQ(a, 27) },
			{ FIRE_EQ(a, 28) }, { FIRE_EQ(a, 29) },
			{ FIRE_EQ(a, 30) }, { FIRE_EQ(a, 31) },
			{ FIRE_EQ(a, 32) }, { FIRE_EQ(a, 33) },
			{ FIRE_EQ(a, 34) }, { FIRE_EQ(a, 35) },
		},
	},
	{
		.fire = FIRE_DEV_COOKIE(B),
		.eq = {
			{ FIRE_EQ(b,  0) }, { FIRE_EQ(b,  1) },
			{ FIRE_EQ(b,  2) }, { FIRE_EQ(b,  3) },
			{ FIRE_EQ(b,  4) }, { FIRE_EQ(b,  5) },
			{ FIRE_EQ(b,  6) }, { FIRE_EQ(b,  7) },
			{ FIRE_EQ(b,  8) }, { FIRE_EQ(b,  9) },
			{ FIRE_EQ(b, 10) }, { FIRE_EQ(b, 11) },
			{ FIRE_EQ(b, 12) }, { FIRE_EQ(b, 13) },
			{ FIRE_EQ(b, 14) }, { FIRE_EQ(b, 15) },
			{ FIRE_EQ(b, 16) }, { FIRE_EQ(b, 17) },
			{ FIRE_EQ(b, 18) }, { FIRE_EQ(b, 19) },
			{ FIRE_EQ(b, 20) }, { FIRE_EQ(b, 21) },
			{ FIRE_EQ(b, 22) }, { FIRE_EQ(b, 23) },
			{ FIRE_EQ(b, 24) }, { FIRE_EQ(b, 25) },
			{ FIRE_EQ(b, 26) }, { FIRE_EQ(b, 27) },
			{ FIRE_EQ(b, 28) }, { FIRE_EQ(b, 29) },
			{ FIRE_EQ(b, 30) }, { FIRE_EQ(b, 31) },
			{ FIRE_EQ(b, 32) }, { FIRE_EQ(b, 33) },
			{ FIRE_EQ(b, 34) }, { FIRE_EQ(b, 35) },
		},
	}
};

const struct fire_err_cookie fire_err[NFIRELEAVES] = {
	{ .fire = FIRE_DEV_COOKIE(A), },
	{ .fire = FIRE_DEV_COOKIE(B), },
};

const fire_dev_t fire_dev[NFIRELEAVES] = {
	{	/* Fire Leaf AID = 0x1e */
		.inomax	= NFIREDEVINO,
		.vino	= AID2VINO(A),
		.handle = AID2HANDLE(A),
		.jbus	= AID2JBUS(A),
		.intclr	= AID2INTCLR(A),
		.intmap	= AID2INTMAP(A),
		.intmap_other	= AID2INTMAP(B),
		.virtual_intmap	= (void *)&fire_virtual_intmap,
		.mmu	= AID2MMU(A),
		.pcie	= AID2PCIE(A),
		.cfg	= AID2PCIECFG(A),
		.eqctlset = AID2PCIE(A)|FIRE_DLC_IMU_EQS_EQ_CTRL_SET(0),
		.eqctlclr = AID2PCIE(A)|FIRE_DLC_IMU_EQS_EQ_CTRL_CLR(0),
		.eqstate  = AID2PCIE(A)|FIRE_DLC_IMU_EQS_EQ_STATE(0),
		.eqtail	  = AID2PCIE(A)|FIRE_DLC_IMU_EQS_EQ_TAIL(0),
		.eqhead	  = AID2PCIE(A)|FIRE_DLC_IMU_EQS_EQ_HEAD(0),
		.msimap	  = AID2PCIE(A)|FIRE_DLC_IMU_RDS_MSI_MSI_MAPPING(0),
		.msiclr	  = AID2PCIE(A)|FIRE_DLC_IMU_RDS_MSI_MSI_CLEAR_REG(0),
		.msgmap	  = AID2PCIE(A)|FIRE_DLC_IMU_RDS_MESS_ERR_COR_MAPPING,
		.msieqbase = (void *)&fire_a_equeue,	/* RELOC */
		.iotsb	= (void *)&fire_a_iotsb,	/* RELOC */
		.msicookie = FIRE_MSI_COOKIE(A),	/* RELOC */
		.errcookie = FIRE_ERR_COOKIE(A),	/* RELOC */
		.perfregs  = FIRE_PERF_REGS(A),
	},
	{	/* Fire Leaf AID = 0x1f */
		.inomax	= NFIREDEVINO,
		.vino	= AID2VINO(B),
		.handle = AID2HANDLE(B),
		.jbus	= AID2JBUS(B),
		.intclr	= AID2INTCLR(B),
		.intmap	= AID2INTMAP(B),
		.intmap_other	= AID2INTMAP(A),
		.virtual_intmap	= (void *)&fire_virtual_intmap,
		.mmu	= AID2MMU(B),
		.pcie	= AID2PCIE(B),
		.cfg	= AID2PCIECFG(B),
		.eqctlset = AID2PCIE(B)|FIRE_DLC_IMU_EQS_EQ_CTRL_SET(0),
		.eqctlclr = AID2PCIE(B)|FIRE_DLC_IMU_EQS_EQ_CTRL_CLR(0),
		.eqstate  = AID2PCIE(B)|FIRE_DLC_IMU_EQS_EQ_STATE(0),
		.eqtail	  = AID2PCIE(B)|FIRE_DLC_IMU_EQS_EQ_TAIL(0),
		.eqhead	  = AID2PCIE(B)|FIRE_DLC_IMU_EQS_EQ_HEAD(0),
		.msimap	  = AID2PCIE(B)|FIRE_DLC_IMU_RDS_MSI_MSI_MAPPING(0),
		.msiclr	  = AID2PCIE(B)|FIRE_DLC_IMU_RDS_MSI_MSI_CLEAR_REG(0),
		.msgmap	  = AID2PCIE(B)|FIRE_DLC_IMU_RDS_MESS_ERR_COR_MAPPING,
		.msieqbase = (void *)&fire_b_equeue,	/* RELOC */
		.iotsb	= (void *)&fire_b_iotsb,	/* RELOC */
		.msicookie = FIRE_MSI_COOKIE(B),	/* RELOC */
		.errcookie = FIRE_ERR_COOKIE(B),	/* RELOC */
		.perfregs  = FIRE_PERF_REGS(B),
	}
};

#else /* !CONFIG_FIRE */

#define	VINO_HANDLER_FIRE(n)	VINO_HANDLER(RESERVED)

#endif /* !CONFIG_FIRE */


struct config config;

#ifdef CONFIG_CRYPTO
struct mau maus[NMAUS];
#endif /* CONFIG_CRYPTO */

vcpu_t		vcpus[NVCPUS];
strand_t	strands[NSTRANDS];
mblock_t	mblocks[NMBLOCKS];

#ifdef CONFIG_PCIE
pcie_device_t	pcie_bus[NUM_PCIE_BUSSES];
#endif

struct guest guests[NGUESTS];

uint8_t hcall_tables[NGUESTS * HCALL_TABLE_SIZE + L2_LINE_SIZE-1];
struct ldc_endpoint hv_ldcs[MAX_HV_LDC_CHANNELS];
struct sp_ldc_endpoint sp_ldcs[MAX_SP_LDC_CHANNELS];

/* BEGIN CSTYLED */
#pragma align 64 (cons_queues)
struct guest_console_queues cons_queues[NGUESTS];
/* END CSTYLED */

struct devopsvec fire_dev_ops = { FIRE_DEV_OPS };
struct devopsvec fire_int_ops = { FIRE_INT_OPS };
struct devopsvec fire_msi_ops = { FIRE_MSI_OPS };
struct devopsvec fire_err_int_ops = { FIRE_ERR_OPS };

struct devopsvec vdev_ops = { VDEV_OPS };

struct devopsvec cdev_ops = { CDEV_OPS };

/*
 * vino2inst and dev2inst arrays contain indexes
 * into this struct devinst.
 *
 * vino2inst array is used to go from vINO => inst
 *
 * dev2inst array is used to go from devID => inst
 */
struct devinst devinstances[NDEV_INSTS] = {
	{ 0, 0 },
	{ .cookie = FIRE_DEV_COOKIE(A), .ops = &fire_dev_ops },
	{ .cookie = FIRE_DEV_COOKIE(B), .ops = &fire_dev_ops },

	{ .cookie = FIRE_DEV_COOKIE(A), .ops = &fire_int_ops },
	{ .cookie = FIRE_DEV_COOKIE(B), .ops = &fire_int_ops },

	{ .cookie = FIRE_DEV_COOKIE(A), .ops = &fire_msi_ops },
	{ .cookie = FIRE_DEV_COOKIE(B), .ops = &fire_msi_ops },

	{ .cookie = FIRE_DEV_COOKIE(A), .ops = &fire_err_int_ops },
	{ .cookie = FIRE_DEV_COOKIE(B), .ops = &fire_err_int_ops },

	{ .cookie = 0, .ops = &vdev_ops },

	{ .cookie = 0, .ops = &cdev_ops },

	{ 0, 0 },

};

const struct vino_pcie config_pcie_vinos = {
	VINO_HANDLER_FIRE(A),
	VINO_HANDLER_FIRE(B)
};
