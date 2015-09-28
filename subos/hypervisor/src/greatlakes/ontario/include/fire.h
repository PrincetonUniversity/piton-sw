/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: fire.h
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

#ifndef _ONTARIO_FIRE_H
#define	_ONTARIO_FIRE_H

#pragma ident	"@(#)fire.h	1.19	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <support.h>
#include <fire/fire_regs.h>
#include <fire/fire.h>
#include <sun4v/vpci.h>
#include <vpci_errs_defs.h>
#include <jbi_regs.h>

#define	NFIRES		1
#define	NFIRELEAVES	(NFIRES*2)

#define	AID2JBUS(aid)	((0x080ull << 32)|((uint64_t)(FIRE_##aid##_AID) << 23))
#define	AID2HANDLE(aid)	((uint64_t)(FIRE_##aid##_AID) << DEVCFGPA_SHIFT)

#define	AID2PCI(aid)	((uint64_t)(FIRE_##aid##_AID & 0xf) << 36)
#define	AID2VINO(aid)	((FIRE_##aid##_AID) << FIRE_DEVINO_SHIFT)
#define	AID2PCIE(aid)	((uint64_t)(AID2JBUS(aid)|((FIRE_##aid##_AID&1) << 20)\
				    | 0x600000LL))

#define	AID2MMU(aid)	((uint64_t)(AID2PCIE(aid)|FIRE_DLC_MMU_CTL))
#define	AID2INTMAP(aid)	(AID2PCIE(aid)|FIRE_DLC_IMU_ISS_INTERRUPT_MAPPING(0))
#define	AID2INTCLR(aid)	(AID2PCIE(aid)|FIRE_DLC_IMU_ISS_CLR_INT_REG(0))

#define	CFGIO_A		0xe800
#define	MEM32_A		0xea00
#define	MEM64_A		0xec00

#define	CFGIO_B		0xf000
#define	MEM32_B		0xf200
#define	MEM64_B		0xf400
#define	EBUS		0xf820

#define	AID2PCIECFG(aid) (AID2PCI(aid) | \
	    (((((FIRE_##aid##_AID) & 1) ^ 1) | 0LL) << 35))

#define	IO_SIZE		(256 MB)
#define	CFG_SIZE	IO_SIZE
#define	CFGIO_SIZE	(CFG_SIZE + IO_SIZE)
#define	MEM32_SIZE	(2 GB)
#define	MEM64_SIZE	(16 GB)
#define	EBUS_SIZE	(128 MB)

/* BEGIN CSTYLED */
/*
 *       FIRE LEAF A                              FIRE LEAF B
 *      e0.0000.0000                             f0.0000.0000
 *#=========================# 0.0000.0000  #=========================#
 *|                         |              | CFG    256 MB           |
 *|                         | 0.1000.0000  +-------------------------+
 *|                         |              | IO     256 MB           |
 *|                         | 0.2000.0000  +-------------------------+
 *|                         |              | UNUSED   8 GB - 512 MB  |
 *| UNUSED   16 GB          | 2.0000.0000  +-------------------------+
 *|                         |              | MEM32    2 GB           |
 *|                         | 2.8000.0000  +-------------------------+
 *|                         |              | DVMA     2 GB           |
 *|                         | 3.0000.0000  +-------------------------+
 *|                         |              | UNUSED   4 GB           |
 *#-------------------------# 4.0000.0000  #-------------------------#
 *| UNUSED 16 GB            |              | MEM64   16 GB           |
 *#-------------------------# 8.0000.0000  #-------------------------#
 *| CFG     256 MB          |              |                         |
 *+-------------------------+ 8.1000.0000  | UNUSED 512 MB           |
 *| IO      256 MB          |              |                         |
 *+-------------------------+ 8.2000.0000  +-------------------------+
 *|                         |              | EBUS   128 MB           |
 *| UNUSED    8 GB - 512 MB | 8.2800.0000  +-------------------------+
 *|                         |              |                         |
 *+-------------------------+ a.0000.0000  |                         |
 *| MEM32     2 GB          |              |                         |
 *+-------------------------+ a.8000.0000  | UNUSED  16GB - 640 MB   |
 *| DVMA      2 GB          |              |                         |
 *+-------------------------+ b.0000.0000  |                         |
 *| UNUSED    4 GB          |              |                         |
 *#-------------------------# c.0000.0000  #-------------------------#
 *|                         |              | UNUSED  12 GB           |
 *| MEM64    16 GB          | f.0000.0000  +-------------------------+
 *|                         |              | NIAGARA  4 GB           |
 *#=========================# f.ffff.ffff  #=========================#
 */
/* END CSTYLED */

/* BEGIN CSTYLED */
#define	CFGIO(n)	(CFGIO_/**/n)
#define	MEM32(n)	(MEM32_/**/n)
#define	MEM64(n)	(MEM64_/**/n)

#define	FIRE_IOBASE(n)	(FIRE_BAR(CFGIO_/**/n) + CFG_SIZE)
#define	FIRE_IOLIMIT(n)	(FIRE_BAR(MEM64_/**/n) + MEM64_SIZE)
/* END CSTYLED */

#define	FIRE_BAR(n)	((n) << 24)
#define	FIRE_BAR_V(n)	(FIRE_BAR(n) | (1LL << 63))
#define	FIRE_SIZE(n)	(((1 << 43) - 1) ^ ((n) - 1))

#define	AID2PCIEIO(aid)	(AID2PCIECFG(aid) | CFG_SIZE)

/*
 * XXX Entire EBus is open to the guest, need to narrow it
 */
#define	FIRE_EBUSBASE	(FIRE_BAR(EBUS))
#define	FIRE_EBUSLIMIT	(FIRE_BAR(EBUS) + EBUS_SIZE)

#define	FIRE_JBC_PERF_CNTRL_MASK				0x0001
#define	FIRE_JBC_PERF_CNT0_MASK					0x0002
#define	FIRE_JBC_PERF_CNT1_MASK					0x0004
#define	FIRE_DLC_IMU_ICS_IMU_PERF_CNTRL_MASK			0x0008
#define	FIRE_DLC_IMU_ICS_IMU_PERF_CNT0_MASK			0x0010
#define	FIRE_DLC_IMU_ICS_IMU_PERF_CNT1_MASK			0x0020
#define	FIRE_DLC_MMU_PRFC_MASK					0x0040
#define	FIRE_DLC_MMU_PRF0_MASK					0x0080
#define	FIRE_DLC_MMU_PRF1_MASK					0x0100
#define	FIRE_PLC_TLU_CTB_TLR_TLU_PRFC_MASK			0x0200
#define	FIRE_PLC_TLU_CTB_TLR_TLU_PRF0_MASK			0x0400
#define	FIRE_PLC_TLU_CTB_TLR_TLU_PRF1_MASK			0x0800
#define	FIRE_PLC_TLU_CTB_TLR_TLU_PRF2_MASK			0x1000
#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1_SEL_MASK	0x2000
#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1_MASK	0x4000
#define	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR2_MASK	0x8000

#define	FIRE_JBC_PERF_MASK	0x0007
#define	FIRE_PCIE_PERF_MASK	0xfff8
#define	FIRE_PERF_REGS_A	(FIRE_JBC_PERF_MASK|FIRE_PCIE_PERF_MASK)
#define	FIRE_PERF_REGS_B	(FIRE_PCIE_PERF_MASK)
#define	FIRE_PERF_REGS(n)	(FIRE_PERF_REGS_##n)
#define	FIRE_NPERFREGS		16

#define	RUC_P	(1 << 16)
#define	WUC_P	(1 << 17)

#define	RWUC_P	(RUC_P | WUC_P)
#define	RWUC_S	(RWUC_P << 32)

/*
 * These IO config space offsets are expected to remain fixed and so
 * we just hard code them. These are used for PCI bus reset of a logical
 * domain which is being reset (and controls one or more of the IO leafs).
 */
#define	UPST_CFG_BASE		0x200000	/* upstream port cfg base */

#define	DNST_CFG_PORT_BASE(_x)  (0x300000 + ((_x)<<15))
#define	DNST_CFG_BASE		0x308000	/* downstream port 1 cfg base */

#define	PE2X_CFG_BASE		0x400000	/* PCIE->PCIX bridge cfg base */
#define	SOUTHBRIDGE_CFG_BASE	0x510000
#define	CFG_SECONDARY_RESET	0x3c		/* used for secondary reset */
#define	CFG_CMD_REG		0x4		/* command register */
#define	CFG_CLASS_CODE		0x8		/* class code */
#define	CFG_BAR0		0x10		/* BAR0 */
#define	CFG_BAR1		0x14		/* BAR1 */
#define	CFG_PS_BUS		0x18		/* primary/secondary bus#s */
#define	CFG_IOBASE_LIM		0x1c		/* I/O base and Limit */
#define	CFG_MEMBASE		0x20		/* memory base */
#define	CFG_MEMLIM		0x22		/* memory limit */
#define	CFG_PFBASE		0x24		/* prefetchable base */
#define	CFG_PFLIM		0x26		/* prefetchable limit */
#define	CFG_PF_UBASE		0x28		/* prefetchable upper base */
#define	CFG_PF_ULIM		0x2c		/* prefetchable upper limit */
#define	CFG_IO_UBASE		0x30		/* IO upper base */
#define	CFG_IO_ULIM		0x32		/* IO upper limit */

#define	CFG_STAT_CTRL		0x70		/* device status and control */
#define	CFG_LINK_TRAIN		0x78		/* link training status */
#define	CFG_LINK_TRAIN_MASK	(1LL<<27)	/* link training status */
#define	CFG_LINK_TRAIN_ERR_MASK	(1LL<<26)	/* link training status */
#define	CFG_VC0_STATUS		0x160		/* Virtual channel 0 status */
#define	CFG_VC0_STATUS_MASK	(1LL<<17)	/* link train up */

#define	UPST_CFG_PS_BUS_VAL	0x60302
#define	DNST_CFG_PS_BUS_VAL	0x60403
#define	PE2X_CFG_PS_BUS_VAL	0x60504
#define	SOUTHBRIDGE_RESET_VAL	0xfe
#define	SOUTHBRIDGE_CFG_RESET	0x44		/* Southbridge reset (cfg) */
#define	SOUTHBRIDGE_IO_RESET	0x64		/* Southbridge reset (io) */

#define	PLX_8532_DEV_VEND_ID	0x853210b5
#define	INTEL_BRG_DEV_VEND_ID	0x3408086
#define	ALI_SB_DEV_VEND_ID	0x153310b9
#define	BRIDGE_CLASS_CODE	0x60400

/*
 * Disable reporting of Fire R/W Unsuccessful Completion (UC) errors
 * during PCI config space accesses, PCI peek and PCI poke
 */
/* BEGIN CSTYLED */
#define	DISABLE_PCIE_RWUC_ERRORS(fire, scr1, scr2, scr3)	\
	.pushlocals						;\
	add	fire, FIRE_COOKIE_ERR_LOCK, scr3		;\
	SPINLOCK_ENTER(scr3, scr1, scr2)			;\
	ldx	[fire + FIRE_COOKIE_ERR_LOCK_COUNTER], scr1	;\
	add	scr1, 1, scr2					;\
	stx	scr2, [fire + FIRE_COOKIE_ERR_LOCK_COUNTER]	;\
	brgz,pn	scr1, 0f					;\
	  ldx	[fire + FIRE_COOKIE_PCIE], scr1			;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_EN_ERR, scr2		;\
	ldx	[scr1 + scr2], scr2				;\
	stx	scr2, [fire + FIRE_COOKIE_OE_STATUS]		;\
	setx	(RWUC_P | RWUC_S), scr2, scr3			;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	ldx	[scr1 + scr2], scr2				;\
	andn	scr2, scr3, scr3				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	stx	scr3, [scr1 + scr2]				;\
	ldx	[scr1 + scr2], %g0				;\
	setx	JBI_SIG_ENB, scr2, scr1				;\
	ldx	[scr1], scr2					;\
	stx	scr2, [fire + FIRE_COOKIE_JBI_SIG_ENABLE]	;\
	andn	scr2, (JBI_READ_TO | JBI_UNMAP_WR | JBI_ERR_CYCLE), scr2	;\
	stx	scr2, [scr1]					;\
0:	add	fire, FIRE_COOKIE_ERR_LOCK, scr3		;\
	SPINLOCK_EXIT(scr3)					;\
	.poplocals

/*
 * After PCI config space acesses, PCI peek and PCI poke
 * are completed, clear any new R/W Unsuccessful Completion (UC)
 * errors and then reenable reporting of these errors.
 */
#define	ENABLE_PCIE_RWUC_ERRORS(fire, scr1, scr2, scr3)		\
	.pushlocals						;\
	add	fire, FIRE_COOKIE_ERR_LOCK, scr3		;\
	SPINLOCK_ENTER(scr3, scr1, scr2)			;\
	ldx	[fire + FIRE_COOKIE_ERR_LOCK_COUNTER], scr1	;\
	dec	scr1						;\
	stx	scr1, [fire + FIRE_COOKIE_ERR_LOCK_COUNTER]	;\
	brgz,pn	scr1, 0f					;\
	  ldx	[fire + FIRE_COOKIE_PCIE], scr1			;\
	setx	(RWUC_P | RWUC_S), scr2, scr3			;\
	ldx	[fire + FIRE_COOKIE_OE_STATUS], scr2		;\
	andn	scr3, scr2, scr3				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, scr2	;\
	stx	scr3, [scr1 + scr2]				;\
	setx	(RWUC_P | RWUC_S), scr2, scr3			;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	ldx	[scr1 + scr2], scr2				;\
	or	scr2, scr3, scr3				;\
	set	FIRE_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	stx	scr3, [scr1 + scr2]				;\
	/*							;\
	 * If any of (JBI_READ_TO | JBI_UNMAP_WR | JBI_ERR_CYCLE) was set	;\
	 * in JBI_SIG_ENABLE we reset them now			;\
	 */							;\
	ldx	[fire + FIRE_COOKIE_JBI_SIG_ENABLE], scr2	;\
	and	scr2, (JBI_READ_TO | JBI_UNMAP_WR | JBI_ERR_CYCLE), scr2	;\
	brz,pn	scr2, 0f					;\
	.empty							;\
	setx	JBI_SIG_ENB, scr3, scr1				;\
	ldx	[scr1], scr3					;\
	or	scr3, scr2, scr3				;\
	stx	scr3, [scr1]					;\
0:	add	fire, FIRE_COOKIE_ERR_LOCK, scr3		;\
	SPINLOCK_EXIT(scr3)					;\
	.poplocals


/*
 * This macro flushes all IOMMU entries from a given Fire leaf
 *
 * Inputs:
 *
 *    fire - (preserved) pointer to FIRE_COOKIE
 *
 */
#define	FIRE_IOMMU_FLUSH(fire, scr1, scr2, scr3, scr4)		\
	.pushlocals						;\
	ldx	[fire + FIRE_COOKIE_IOTSB], scr1		;\
	setx	IOTSB_INDEX_MAX, scr4, scr3			;\
	/*							;\
	 * fire - fire cookie pointer				;\
	 * scr1 = IOTSB offset					;\
	 * scr3 = #ttes to unmap				;\
	 */							;\
	ldx	[fire + FIRE_COOKIE_MMU], scr4			;\
0:								;\
	ldx	[scr1], scr2					;\
	/* Clear V bit */					;\
	sllx	scr2, 1, scr2					;\
	srlx	scr2, 1, scr2					;\
	/* Clear Attributes */					;\
	srlx	scr2, FIRE_PAGESIZE_8K_SHIFT, scr2		;\
	sllx	scr2, FIRE_PAGESIZE_8K_SHIFT, scr2		;\
	stx	scr2, [scr1]					;\
	/* IOMMU Flush */					;\
	stx	scr1, [scr4 + 0x100]				;\
	add	scr1, IOTTE_SIZE, scr1				;\
	sub	scr3, 1, scr3					;\
	brgz,pt	scr3, 0b					;\
	  nop							;\
	.poplocals

/* END CSTYLED */

#ifndef _ASM

extern void fire_devino2vino(void);
extern void fire_mondo_receive(void);
extern void fire_intr_getvalid(void);
extern void fire_intr_setvalid(void);
extern void fire_intr_getstate(void);
extern void fire_intr_setstate(void);
extern void fire_intr_gettarget(void);
extern void fire_intr_settarget(void);
extern void fire_get_perf_reg(void);
extern void fire_set_perf_reg(void);

extern void fire_err_devino2vino(void);
extern void fire_err_mondo_receive(void);
extern void fire_err_intr_getvalid(void);
extern void fire_err_intr_setvalid(void);
extern void fire_err_intr_getstate(void);
extern void fire_err_intr_setstate(void);
extern void fire_err_intr_gettarget(void);
extern void fire_err_intr_settarget(void);

extern void fire_msi_devino2vino(void);
extern void fire_msi_mondo_receive(void);
extern void fire_msi_intr_getvalid(void);
extern void fire_msi_intr_setvalid(void);
extern void fire_msi_intr_getstate(void);
extern void fire_msi_intr_setstate(void);
extern void fire_msi_intr_gettarget(void);
extern void fire_msi_intr_settarget(void);

extern void fire_iommu_map(void);
extern void fire_iommu_map_v2(void);
extern void fire_iommu_getmap(void);
extern void fire_iommu_getmap_v2(void);
extern void fire_iommu_unmap(void);
extern void fire_iommu_getbypass(void);
extern void fire_config_get(void);
extern void fire_config_put(void);
extern void fire_dma_sync(void);
extern void fire_io_peek(void);
extern void fire_io_poke(void);

extern void fire_msiq_conf(void);
extern void fire_msiq_info(void);
extern void fire_msiq_getvalid(void);
extern void fire_msiq_setvalid(void);
extern void fire_msiq_getstate(void);
extern void fire_msiq_setstate(void);
extern void fire_msiq_gethead(void);
extern void fire_msiq_sethead(void);
extern void fire_msiq_gettail(void);
extern void fire_msi_msg_getmsiq(void);
extern void fire_msi_msg_setmsiq(void);
extern void fire_msi_msg_getvalid(void);
extern void fire_msi_msg_setvalid(void);

extern void fire_msi_getvalid(void);
extern void fire_msi_setvalid(void);
extern void fire_msi_getstate(void);
extern void fire_msi_setstate(void);
extern void fire_msi_getmsiq(void);
extern void fire_msi_setmsiq(void);


struct fire_msieq {
	uint64_t eqmask;
	uint64_t *base;
	uint64_t *guest;
	uint64_t word0;
	uint64_t word1;
};

struct fire_msi_cookie {
	const struct fire_cookie *fire;
#ifdef CONFIG_FIRE
	struct fire_msieq eq[FIRE_NEQS];
#else
	struct fire_msieq eq[1];
#endif
};

struct fire_err_cookie {
	const struct fire_cookie *fire;
	uint64_t state[2]; /* XXX */
};

struct fire_cookie {
	uint64_t	handle;
	uint64_t	jbus;	/* JBus Base PA */
	uint64_t	pcie;
	uint64_t	cfg;	/* PCI CFG PA */

	bool_t		needs_warm_reset; /* false if fresh from poweron */
	uint64_t	live_port;	/* Bit mask for  live PLX ports */

	uint64_t	perfregs;

	uint64_t	eqctlset;
	uint64_t	eqctlclr;
	uint64_t	eqstate;
	uint64_t	eqtail;
	uint64_t	eqhead;
	uint64_t	msimap;
	uint64_t	msiclr;
	uint64_t	msgmap;

	uint64_t	mmu;

	uint64_t	intclr;
	uint64_t	intmap;
	uint64_t	intmap_other;
	uint64_t	*virtual_intmap;

#ifdef FIRE_ERRATUM_20_18
	uint64_t	extracfgrdaddrpa;
#endif

	uint64_t	err_lock;
	uint64_t	err_lock_counter;
	uint64_t	tlu_oe_status;
	uint64_t	jbi_sig_enable;

	uint16_t	inomax;	/* Max INO */
	uint16_t	vino;	/* First Vino */
	uint64_t	*iotsb;	/* IOTSB Base PA */
	uint64_t	*msieqbase;
	struct fire_msi_cookie *msicookie;
	struct fire_err_cookie *errcookie;

	struct pci_erpt	jbc_erpt; /* Fire error buffer */
	struct pci_erpt	pcie_erpt; /* Fire error buffer */
	bool_t		blacklist;
	uint64_t	guest_pci_va_limit;
};

typedef struct fire_cookie fire_dev_t;

extern const fire_dev_t fire_dev[];

extern bool_t	is_fire_port_link_up(fire_dev_t *);
extern bool_t	fire_link_up(fire_dev_t *);
extern bool_t	fire_link_down(fire_dev_t *);
extern void	fire_config_bypass(fire_dev_t *, bool_t);

extern bool_t pci_config_get(fire_dev_t *, uint64_t offset, int size,
	uint64_t *valp);
extern bool_t pci_config_put(fire_dev_t *, uint64_t offset, int size,
	uint64_t val);
extern bool_t pci_io_peek(fire_dev_t *, uint64_t offset, int size,
	uint64_t *valp);
extern bool_t pci_io_poke(fire_dev_t *, uint64_t offset, int size,
	uint64_t val, uint64_t cfg_offset);

extern bool_t pcie_bus_reset(int busnum);
extern void init_pcie_buses(void);

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _ONTARIO_FIRE_H */
