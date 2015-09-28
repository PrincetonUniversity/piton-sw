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

#pragma ident	"@(#)config.c	1.4	07/08/01 SMI"

/*
 * Guest configuration
 */

#include <sys/htypes.h>
#include <hprivregs.h>
#include <hypervisor.h>
#include <traps.h>
#include <cache.h>
#include <mmu.h>
#include <vpiu_errs_defs.h>
#include <vdev_ops.h>
#include <vdev_intr.h>
#include <ncs.h>
#include <rng.h>
#include <cyclic.h>
#include <vcpu.h>
#include <strand.h>
#include <guest.h>
#include <vdev_ops.h>
#include <pcie.h>
#ifdef STANDALONE_NET_DEVICES
#include <network.h>
#endif
#include <memory.h>
#include <fpga.h>

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

#if defined(CONFIG_PIU)

extern const uint64_t piu_iotsb0;
extern const uint64_t piu_iotsb1;
extern const uint64_t piu_0_equeue;
extern const uint64_t piu_virtual_intmap;

#define	PIU_EQ(chip, eq) 					\
	.base = (uint64_t *)&piu_##chip##_equeue+(eq*0x400),	\
	.eqmask = PIU_EQMASK

#define	PIU_MSI_COOKIE_SETUP(chip)					\
	{								\
		.piu = PIU_DEV_COOKIE(0),				\
		    .eq = {						\
			{ PIU_EQ(chip,  0) }, { PIU_EQ(chip,  1) },	\
			{ PIU_EQ(chip,  2) }, { PIU_EQ(chip,  3) },	\
			{ PIU_EQ(chip,  4) }, { PIU_EQ(chip,  5) },	\
			{ PIU_EQ(chip,  6) }, { PIU_EQ(chip,  7) },	\
			{ PIU_EQ(chip,  8) }, { PIU_EQ(chip,  9) },	\
			{ PIU_EQ(chip, 10) }, { PIU_EQ(chip, 11) },	\
			{ PIU_EQ(chip, 12) }, { PIU_EQ(chip, 13) },	\
			{ PIU_EQ(chip, 14) }, { PIU_EQ(chip, 15) },	\
			{ PIU_EQ(chip, 16) }, { PIU_EQ(chip, 17) },	\
			{ PIU_EQ(chip, 18) }, { PIU_EQ(chip, 19) },	\
			{ PIU_EQ(chip, 20) }, { PIU_EQ(chip, 21) },	\
			{ PIU_EQ(chip, 22) }, { PIU_EQ(chip, 23) },	\
			{ PIU_EQ(chip, 24) }, { PIU_EQ(chip, 25) },	\
			{ PIU_EQ(chip, 26) }, { PIU_EQ(chip, 27) },	\
			{ PIU_EQ(chip, 28) }, { PIU_EQ(chip, 29) },	\
			{ PIU_EQ(chip, 30) }, { PIU_EQ(chip, 31) },	\
			{ PIU_EQ(chip, 32) }, { PIU_EQ(chip, 33) },	\
			{ PIU_EQ(chip, 34) }, { PIU_EQ(chip, 35) },	\
		}							\
	},

const struct piu_msi_cookie piu_msi[NPIUS] = {
		PIU_MSI_COOKIE_SETUP(0)
};

#define	PIU_ERR_COOKIE_SETUP(chip)		\
	{ .piu = PIU_DEV_COOKIE(chip), }

const struct piu_err_cookie piu_err[NPIUS] = {
	PIU_ERR_COOKIE_SETUP(0)
};

#define	PIU_COOKIE_SETUP(chip)						\
	{								\
		/* PIU(chip) */						\
		.inomax	= NPIUDEVINO,					\
		.vino	= AID2VINO(chip),				\
		.handle = AID2HANDLE(chip),				\
		.ncu	= AID2JBUS(chip),				\
		.intclr	= AID2INTCLR(chip),				\
		.intmap	= AID2INTMAP(chip),				\
		.virtual_intmap	= (void *)&piu_virtual_intmap,		\
		.mmu	= AID2MMU(chip),				\
		.mmuflush = AID2MMUFLUSH(chip),				\
		.pcie	= AID2PCIE(chip),				\
		.cfg	= AID2PCIECFG(chip),				\
		.eqctlset = AID2PCIE(chip)|PIU_DLC_IMU_EQS_EQ_CTRL_SET(0),\
		.eqctlclr = AID2PCIE(chip)|PIU_DLC_IMU_EQS_EQ_CTRL_CLR(0),\
		.eqstate = AID2PCIE(chip)|PIU_DLC_IMU_EQS_EQ_STATE(0),	\
		.eqtail = AID2PCIE(chip)|PIU_DLC_IMU_EQS_EQ_TAIL(0),	\
		.eqhead = AID2PCIE(chip)|PIU_DLC_IMU_EQS_EQ_HEAD(0),	\
		.msimap = AID2PCIE(chip)|PIU_DLC_IMU_RDS_MSI_MSI_MAPPING(0),\
		.msiclr = AID2PCIE(chip)|PIU_DLC_IMU_RDS_MSI_MSI_CLEAR_REG(0),\
		.msgmap = AID2PCIE(chip)|PIU_DLC_IMU_RDS_MESS_ERR_COR_MAPPING,\
		.msieqbase = (void *)&piu_##chip##_equeue, /* RELOC */	\
		.iotsb0	= (void *)&piu_iotsb0,		/* RELOC */	\
		.iotsb1	= (void *)&piu_iotsb1,		/* RELOC */	\
		.msicookie = PIU_MSI_COOKIE(chip),	/* RELOC */	\
		.errcookie = PIU_ERR_COOKIE(chip),	/* RELOC */	\
		.perfregs  = PIU_PERF_REGS(chip),			\
	}

const piu_dev_t piu_dev[NPIUS] = {
	PIU_COOKIE_SETUP(0)
};

#else /* !CONFIG_PIU */

#define	VINO_HANDLER_PIU(n)	VINO_HANDLER(RESERVED)

#endif /* !CONFIG_PIU */

extern const uint64_t niu_ldg2ldn_table;
extern const uint64_t niu_vec2ldg_table;

const struct niu_cookie niu_dev = {
	.ldg2ldn_table = (void *)&niu_ldg2ldn_table,
	.vec2ldg_table = (void *)&niu_vec2ldg_table
};

#ifdef CONFIG_FPGA_UART

const struct fpga_cookie fpga_uart_dev = {
	.status = FPGA_INTR_BASE + FPGA_OTHER_INTR_STATUS,
	.enable = FPGA_INTR_BASE + FPGA_OTHER_INTR_ENABLE,
	.disable = FPGA_INTR_BASE + FPGA_OTHER_INTR_DISABLE
};

#endif /* CONFIG_FPGA_UART */

struct config			config;

#ifdef CONFIG_CRYPTO
struct mau			maus[NMAUS];
struct cwq cwqs[NCWQS];
struct rng rng;
#endif /* CONFIG_CRYPTO */

vcpu_t		vcpus[NVCPUS];
strand_t	strands[NSTRANDS];
mblock_t	mblocks[NMBLOCKS];

#ifdef CONFIG_PIU
pcie_device_t	pcie_bus[NUM_PCIE_BUSSES];
#endif

#ifdef STANDALONE_NET_DEVICES
network_device_t	network_device[NUM_NETWORK_DEVICES];
#endif

struct guest	guests[NGUESTS];

uint8_t		hcall_tables[NGUESTS * HCALL_TABLE_SIZE + L2_LINE_SIZE-1];
struct ldc_endpoint	hv_ldcs[MAX_HV_LDC_CHANNELS];
struct sp_ldc_endpoint	sp_ldcs[MAX_SP_LDC_CHANNELS];

/* BEGIN CSTYLED */
#pragma align 64 (cons_queues)
struct guest_console_queues cons_queues[NGUESTS];
/* END CSTYLED */

struct devopsvec piu_dev_ops = { PIU_DEV_OPS };
struct devopsvec piu_int_ops = { PIU_INT_OPS };
struct devopsvec piu_msi_ops = { PIU_MSI_OPS };
struct devopsvec piu_err_int_ops = { PIU_ERR_OPS };

struct devopsvec vdev_ops = { VDEV_OPS };

struct devopsvec cdev_ops = { CDEV_OPS };

struct devopsvec niu_ops = { NIU_OPS };

#ifdef	CONFIG_FPGA_UART
struct devopsvec fpga_uart_ops = { FPGA_UART_OPS };
#endif	/* CONFIG_FPGA_UART */

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
	{ .cookie = PIU_DEV_COOKIE(0), .ops = &piu_dev_ops },

	{ .cookie = PIU_DEV_COOKIE(0), .ops = &piu_int_ops },

	{ .cookie = PIU_DEV_COOKIE(0), .ops = &piu_msi_ops },

	{ .cookie = PIU_DEV_COOKIE(0), .ops = &piu_err_int_ops },

	{ .cookie = NIU_COOKIE, .ops = &niu_ops },

	{ .cookie = 0, .ops = &vdev_ops },

	{ .cookie = 0, .ops = &cdev_ops },

#ifdef	CONFIG_FPGA_UART

	{ .cookie = FPGA_UART_COOKIE, .ops = &fpga_uart_ops },

#endif	/* CONFIG_FPGA_UART */

	{ 0, 0 },

};

const struct vino_pcie config_pcie_vinos = {
	VINO_HANDLER_PIU(A),
};
