/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: piu.h
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

#ifndef _NIAGARA_PIU_H
#define	_NIAGARA_PIU_H

#pragma ident	"@(#)piu.h	1.6	07/08/16 SMI"


#ifdef __cplusplus
extern "C" {
#endif

#include <support.h>
#include <vpiu_errs_defs.h>
#include <piu/piu_regs.h>
#include <piu/piu.h>
#include <sun4v/vpci.h>

#define	NPIUS		1

#define	AID2JBUS(aid)	(0x080ull << 32)
#define	AID2HANDLE(aid)	((uint64_t)(PIU_AID) << DEVCFGPA_SHIFT)

#define	AID2PCI(aid)	((uint64_t)(0x0c0ull << 32))

#define	AID2VINO(aid)	(PIU_AID << PIU_DEVINO_SHIFT)
#define	AID2PCIE(aid)	((uint64_t)(AID2JBUS(aid)|0x600000LL|(0x8ull << 32)))

#define	AID2MMU(aid)	((uint64_t)(AID2PCIE(aid) | PIU_DLC_MMU_CTL))
#define	AID2INTMAP(aid)	(AID2PCIE(aid) | PIU_DLC_IMU_ISS_INTERRUPT_MAPPING(0))
#define	AID2INTCLR(aid)	(AID2PCIE(aid) | PIU_DLC_IMU_ISS_CLR_INT_REG(0))
#define	AID2MMUFLUSH(aid) ((uint64_t)(AID2JBUS(aid) |\
		NCU_MMU_TTE_CACHE_FLUSH_ADDR_OFFSET))

#define	CFGIO(n)	(0xc800 << 24)
#define	MEM32(n)	(0xca00 << 24)
#define	MEM64(n)	(0xcc00 << 24)

#define	AID2PCIECFG(aid) (AID2PCI(aid) | 1ull << 35)

#define	IO_SIZE		(256 MB)
#define	CFG_SIZE	IO_SIZE
#define	CFGIO_SIZE	(CFG_SIZE + IO_SIZE)
#define	MEM32_SIZE	(2 GB)
#define	MEM64_SIZE	(16 GB)

/* BEGIN CSTYLED */
/*
 *       PIU LEAF 0
 *      c0.0000.0000
 *#=========================# 0.0000.0000
 *|                         |
 *|                         | 0.1000.0000
 *|                         |
 *|                         | 0.2000.0000
 *|                         |
 *| UNUSED   16 GB          | 2.0000.0000
 *|                         |
 *|                         | 2.8000.0000
 *|                         |
 *|                         | 3.0000.0000
 *|                         |
 *#-------------------------# 4.0000.0000
 *| UNUSED 16 GB            |
 *#-------------------------# 8.0000.0000
 *| CFG     256 MB          |
 *+-------------------------+ 8.1000.0000
 *| IO      256 MB          |
 *+-------------------------+ 8.2000.0000
 *|                         |
 *| UNUSED    8 GB - 512 MB | 8.2800.0000
 *|                         |
 *+-------------------------+ a.0000.0000
 *| MEM32     2 GB          |
 *+-------------------------+ a.8000.0000
 *| DVMA      2 GB          |
 *+-------------------------+ b.0000.0000
 *| UNUSED    4 GB          |
 *#-------------------------# c.0000.0000
 *|                         |
 *| MEM64    16 GB          | f.0000.0000
 *|                         |
 *#=========================# f.ffff.ffff
 */
/* END CSTYLED */

#define	PIU_IOBASE(n)	(CFGIO(n) + CFG_SIZE)
#define	PIU_IOLIMIT(n)	(MEM64(n) + MEM64_SIZE)

#define	PIU_BAR(n)	((n) & 0x8000000fff000000)
#define	PIU_BAR_V(n)	(PIU_BAR(n) | (1LL << 63))
#define	PIU_SIZE(n)	(((1 << 40) - 1) ^ ((n) - 1))

#define	AID2PCIEIO(aid)	(AID2PCIECFG(aid) | CFG_SIZE)

#define	PIU_PERF_REGS(n)	0x0fff

#define	RUC_P	(1 << 16)
#define	WUC_P	(1 << 17)
#define	LUP_P	(1 << 8)
#define	LDN_P	(1 << 9)

#define	RWUC_P	(RUC_P | WUC_P)
#define	RWUC_S	(RWUC_P << 32)

#define	LUP_LDN_P	(LUP_P | LDN_P)
#define	LUP_LDN_S	(LUP_LDN_P << 32)

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
 * PIU Link Status Register values
 */
#define	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_WIDTH_MASK		0x3f
#define	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_WIDTH_SHIFT		4
#define	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_WIDTH_x8		0x8

/*
 * Disable reporting of PIU R/W Unsuccessful Completion (UC) errors
 * during PCI config space accesses, PCI peek and PCI poke
 */
/* BEGIN CSTYLED */
#define	DISABLE_PCIE_RWUC_ERRORS(piu, scr1, scr2, scr3)	\
	DISABLE_PCIE_OE_ERR_INTERRUPTS(piu, scr1, scr2, scr3, \
					(RWUC_P | RWUC_S))

/*
 * After PCI config space acesses, PCI peek and PCI poke
 * are completed, clear any new R/W Unsuccessful Completion (UC)
 * errors and then reenable reporting of these errors.
 */
#define	ENABLE_PCIE_RWUC_ERRORS(piu, scr1, scr2, scr3) \
	ENABLE_PCIE_OE_ERR_INTERRUPTS(piu, scr1, scr2, scr3, \
					(RWUC_P | RWUC_S))

/*
 * For link training or retraining, disable generation of
 * Link Up or Down events.
 */
#define	DISABLE_PCIE_LUP_LDN_ERRORS(piu, scr1, scr2, scr3) \
	DISABLE_PCIE_OE_ERR_INTERRUPTS(piu, scr1, scr2, scr3, \
					(LUP_LDN_P | LUP_LDN_S))

#define	ENABLE_PCIE_LUP_LDN_ERRORS(piu, scr1, scr2, scr3) \
	ENABLE_PCIE_OE_ERR_INTERRUPTS(piu, scr1, scr2, scr3, \
					(LUP_LDN_P | LUP_LDN_S))


#define	DISABLE_PCIE_OE_ERR_INTERRUPTS(piu, scr1, scr2, scr3, \
						registers_bits)	\
	.pushlocals						;\
	add	piu, PIU_COOKIE_ERR_LOCK, scr3			;\
	SPINLOCK_ENTER(scr3, scr1, scr2)			;\
	ldx	[piu + PIU_COOKIE_ERR_LOCK_COUNTER], scr1	;\
	add	scr1, 1, scr2					;\
	stx	scr2, [piu + PIU_COOKIE_ERR_LOCK_COUNTER]	;\
	brgz,pn	scr1, 0f					;\
	  ldx	[piu + PIU_COOKIE_PCIE], scr1			;\
	set	PIU_PLC_TLU_CTB_TLR_OE_EN_ERR, scr2		;\
	ldx	[scr1 + scr2], scr2				;\
	stx	scr2, [piu + PIU_COOKIE_OE_STATUS]		;\
	setx	registers_bits, scr2, scr3			;\
	set	PIU_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	ldx	[scr1 + scr2], scr2				;\
	andn	scr2, scr3, scr3				;\
	set	PIU_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	stx	scr3, [scr1 + scr2]				;\
	ldx	[scr1 + scr2], %g0				;\
0:	add	piu, PIU_COOKIE_ERR_LOCK, scr3			;\
	SPINLOCK_EXIT(scr3)					;\
	.poplocals

#define	ENABLE_PCIE_OE_ERR_INTERRUPTS(piu, scr1, scr2, scr3, \
						registers_bits) \
	.pushlocals						;\
	add	piu, PIU_COOKIE_ERR_LOCK, scr3			;\
	SPINLOCK_ENTER(scr3, scr1, scr2)			;\
	ldx	[piu + PIU_COOKIE_ERR_LOCK_COUNTER], scr1	;\
	dec	scr1						;\
	stx	scr1, [piu + PIU_COOKIE_ERR_LOCK_COUNTER]	;\
	brgz,pn	scr1, 0f					;\
	  ldx	[piu + PIU_COOKIE_PCIE], scr1			;\
	setx	registers_bits, scr2, scr3			;\
	ldx	[piu + PIU_COOKIE_OE_STATUS], scr2		;\
	andn	scr3, scr2, scr3				;\
	set	PIU_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, scr2	;\
	stx	scr3, [scr1 + scr2]				;\
	setx	(RWUC_P | RWUC_S), scr2, scr3			;\
	set	PIU_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	ldx	[scr1 + scr2], scr2				;\
	or	scr2, scr3, scr3				;\
	set	PIU_PLC_TLU_CTB_TLR_OE_INT_EN, scr2		;\
	stx	scr3, [scr1 + scr2]				;\
0:	add	piu, PIU_COOKIE_ERR_LOCK, scr3			;\
	SPINLOCK_EXIT(scr3)					;\
	.poplocals

/*
 * This macro flushes all IOMMU entries from the PIU
 *
 * Inputs:
 *
 *    piu	- (preserved) pointer to PIU_COOKIE
 *
 */
#define	PIU_IOMMU_FLUSH(piu, scr1, scr2, scr3, scr4)		\
	.pushlocals						;\
	ldx	[piu + PIU_COOKIE_IOTSB0], scr1			;\
	setx	IOTSB0_INDEX_MASK, scr4, scr3			;\
	/*							;\
	 * piu - piu cookie pointer				;\
	 * scr1 = IOTSB offset					;\
	 * scr3 = #ttes to unmap				;\
	 */							;\
	ldx	[piu + PIU_COOKIE_MMUFLUSH], scr4			;\
0:								;\
	ldx	[scr1], scr2					;\
	/* Clear V bit 0 */					;\
	srlx	scr2, PIU_IOTTE_V_SHIFT, scr2					;\
	sllx	scr2, PIU_IOTTE_V_SHIFT, scr2					;\
	/* Clear Attributes */					;\
	srlx	scr2, IOMMU_PAGESHIFT_8K, scr2			;\
	sllx	scr2, IOMMU_PAGESHIFT_8K, scr2			;\
	stx	scr2, [scr1]					;\
	/* IOMMU Flush */					;\
	stx	scr1, [scr4]					;\
	add	scr1, IOTTE_SIZE, scr1				;\
	sub	scr3, 1, scr3					;\
	brgz,pt	scr3, 0b					;\
	  nop							;\
	.poplocals


/*
 * This macro brings a given piu leaf's link down
 *
 * Inputs:
 *
 *    piu	- (preserved) pointer to PIU_COOKIE
 *
 */
#define	PIU_LINK_DOWN(piu, scr1, scr2, scr3, scr4)			\
	.pushlocals							;\
	ldx	[ piu + PIU_COOKIE_PCIE ], scr1				;\
		/* And now the actual reset code... */			;\
		/* Remain in detect quiesce */				;\
	/* PEU control register	*/					;\
	set	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_CTL_ADDR, scr2		;\
	ldx	[scr1 + scr2], scr3					;\
	or	scr3, (1 << 8), scr3					;\
	stx	scr3, [scr1 + scr2]					;\
									;\
	/* Disable link - set bit 4 of PEU Link Control register */	;\
	set	PIU_PLC_TLU_CTB_TLR_LNK_CTL, scr2			;\
	ldx	[scr1 + scr2], scr3					;\
	bset	(1 << 4), scr3						;\
	stx	scr3, [scr1 + scr2]					;\
									;\
	CPU_MSEC_DELAY(50, scr2, scr3, scr4) 				;\
									;\
	/* Clear Disable link - bit 4 of PEU Link Control register */	;\
	set	PIU_PLC_TLU_CTB_TLR_LNK_CTL, scr2			;\
	ldx	[scr1 + scr2], scr3					;\
	bclr	(1 << 4), scr3						;\
	stx	scr3, [scr1 + scr2]					;\
	/* Wait for link to go down */					;\
	/* PEU CXPL  Core Status ltssm_state.Detect.Quiet e2100 */	;\
	clr	scr4							;\
1:									;\
	cmp	scr4, 100	/* 100 * 50 = 5 sec max delay */	;\
	bge,pn	%xcc, 1f						;\
	ldx	[ piu + PIU_COOKIE_PCIE ], scr1				;\
	set	PIU_PLC_TLU_CTB_TLR_CSR_A_CORE_STATUS_ADDR, scr2	;\
	ldx	[scr1 + scr2 ], scr3					;\
	srlx	scr3, 44, scr3						;\
	and	scr3, 0x1f, scr3	/* ltssm_state[48:44] */	;\
	brz,pt	scr3, 2f		/* 0x0 = DETECT.QUIET */	;\
	nop								;\
	CPU_MSEC_DELAY(50, scr1, scr2, scr3)				;\
	ba	1b							;\
	inc	scr4							;\
1:									;\
	/* Link did not go down, abort */				;\
	HVABORT(-1, "piu linkdown failed\r\n")				;\
2:									;\
	.poplocals


/*
 * This macro brings a given piu leaf's link up
 *
 * Inputs:
 *
 *    piu	- (preserved) pointer to PIU_COOKIE
 *
 */
#define	PIU_LINK_UP(piu, scr1, scr2, scr3)				\
	.pushlocals							;\
		/* get the base addr of RC control regs */		;\
	ldx	[ piu + PIU_COOKIE_PCIE ], scr1				;\
		/* Clear Other Event Status Register errors */		;\
	set	PIU_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, scr2		;\
	mov	-1, scr3						;\
	stx	scr3, [scr1 + scr2]					;\
		/* The drain bit is cleared via W1C */			;\
	set	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_STS_ADDR, scr2		;\
	ldx	[scr1 + scr2], scr3					;\
	bset	(1 << 8), scr3		/* drain bit */			;\
	stx	scr3, [scr1 + scr2]					;\
		/* bit 8 of the TLU Control Register is */		;\
		/* cleared to initiate link training    */		;\
	set	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_CTL_ADDR, scr2		;\
	ldx	[scr1 + scr2], scr3					;\
	bclr	1<<8, scr3						;\
	stx	scr3, [scr1 + scr2]					;\
	.poplocals

/*
 * This macro resets the PIU using the following sequence :-
 *
 * 1. Disable the PIU link.
 * 2. Drive all on-board devices into reset
 * 3. Short delay, (300ms).
 * 4. Drive all slots into reset
 * 5. Short delay, (300ms).
 * 6. Release all slots from reset
 * 7. Short delay, (300ms).
 * 8. Release all on-board devices from reset except PLX devices 0/1
 * 9. Short delay, (300ms).
 * 10. Start PIU linkup with the PLX switch.
 * 11. Short delay, (300ms).
 * 12. Release on-board devices PLX devices 0/1 from reset
 * 13. Short delay, (300ms), as per PLX errata.
 *
 * Inputs:
 *
 *    piu - (preserved) pointer to PIU_COOKIE
 *    bus - (clobbered) 0
 *
 */
#define	RESET_PIU_LEAF(piu, bus, scr1, scr2, scr3, scr4)		\
	.pushlocals							;\
									;\
	/* ******************************************** */		;\
	/* If the link is down, we don't do anything    */		;\
	/* since it may mean there is no HW on the bus. */		;\
	/* ******************************************** */		;\
	ldx	[piu + PIU_COOKIE_PCIE ], scr1				;\
	setx	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_STS_ADDR, scr3, scr2	;\
	ldx	[ scr1 + scr2 ], scr3					;\
	and	scr3, 0x7, scr3						;\
	cmp	scr3, 0x4						;\
	bne,pt	%xcc, 0f						;\
	  nop								;\
									;\
	PIU_LINK_DOWN(piu, scr1, scr2, scr3, scr4)			;\
									;\
	setx	FPGA_DEVICE_ID, scr2, scr1				;\
	lduh	[scr1], scr1	 					;\
	srlx	scr1, FPGA_ID_MAJOR_ID_SHIFT, scr1			;\
	and	scr1, FPGA_ID_MAJOR_ID_MASK, scr1			;\
	cmp	scr1, FPGA_MIN_MAJOR_ID_RESET_SUPPORT			;\
	blu,pn	%xcc, 4f						;\
	.empty								;\
									;\
	setx	FPGA_PLATFORM_REGS, scr2, scr1				;\
	mov	FPGA_LDOM_RESET_CONTROL_MASK, scr3			;\
	/* drive all devices into reset */				;\
	stb	scr3, [scr1 + FPGA_LDOM_RESET_CONTROL_OFFSET]		;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
	/* drive all slots into reset */				;\
	ldub	[scr1 + FPGA_DEVICE_PRESENT_OFFSET], scr2		;\
	and	scr2, FPGA_PCIE_SLOT_RESET_CTRL_MASK, scr2		;\
	stb	scr2, [scr1 + FPGA_LDOM_SLOT_RESET_CONTROL_OFFSET]	;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
	/* take all slots out of reset */				;\
	stb	%g0, [scr1 +  FPGA_LDOM_SLOT_RESET_CONTROL_OFFSET]	;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
	/* take all devices except PLX's out of reset */		;\
	mov	FPGA_LDOM_RESET_CONTROL_DEV_1 | FPGA_LDOM_RESET_CONTROL_DEV_0, scr2	;\
	stb	scr2, [scr1 + FPGA_LDOM_RESET_CONTROL_OFFSET]		;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
									;\
	/* train PIU link */						;\
	PIU_LINK_UP(piu, scr4, scr2, scr3)				;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
									;\
	/* Bring PLX's out of reset */					;\
	stb	%g0, [scr1 + FPGA_LDOM_RESET_CONTROL_OFFSET]		;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
	ba,pt	%xcc, 0f						;\
	nop								;\
									;\
4:									;\
	PIU_LINK_UP(piu, scr1, scr2, scr3)				;\
	CPU_MSEC_DELAY(300, scr2, scr3, scr4)				;\
0:									;\
	.poplocals

/*
 * We check the link width to ensure that the link came up in x8 mode.
 * If not, we retry. If it fails PIU_RESET_MAX_ATTEMPTS times we blacklist
 * the device.
 */
#define	PIU_RESET_MAX_ATTEMPTS			3

/* END CSTYLED */

#ifndef _ASM

extern void piu_devino2vino(void);
extern void piu_mondo_receive(void);
extern void piu_intr_getvalid(void);
extern void piu_intr_setvalid(void);
extern void piu_intr_getstate(void);
extern void piu_intr_setstate(void);
extern void piu_intr_gettarget(void);
extern void piu_intr_settarget(void);
extern void piu_get_perf_reg(void);
extern void piu_set_perf_reg(void);

extern void piu_err_devino2vino(void);
extern void piu_err_mondo_receive(void);
extern void piu_err_intr_getvalid(void);
extern void piu_err_intr_setvalid(void);
extern void piu_err_intr_getstate(void);
extern void piu_err_intr_setstate(void);
extern void piu_err_intr_gettarget(void);
extern void piu_err_intr_settarget(void);

extern void piu_msi_devino2vino(void);
extern void piu_msi_mondo_receive(void);
extern void piu_msi_intr_getvalid(void);
extern void piu_msi_intr_setvalid(void);
extern void piu_msi_intr_getstate(void);
extern void piu_msi_intr_setstate(void);
extern void piu_msi_intr_gettarget(void);
extern void piu_msi_intr_settarget(void);

extern void piu_iommu_map(void);
extern void piu_iommu_map_v2(void);
extern void piu_iommu_getmap(void);
extern void piu_iommu_getmap_v2(void);
extern void piu_iommu_unmap(void);
extern void piu_iommu_getbypass(void);
extern void piu_config_get(void);
extern void piu_config_put(void);
extern void piu_dma_sync(void);
extern void piu_io_peek(void);
extern void piu_io_poke(void);

extern void piu_msiq_conf(void);
extern void piu_msiq_info(void);
extern void piu_msiq_getvalid(void);
extern void piu_msiq_setvalid(void);
extern void piu_msiq_getstate(void);
extern void piu_msiq_setstate(void);
extern void piu_msiq_gethead(void);
extern void piu_msiq_sethead(void);
extern void piu_msiq_gettail(void);
extern void piu_msi_msg_getmsiq(void);
extern void piu_msi_msg_setmsiq(void);
extern void piu_msi_msg_getvalid(void);
extern void piu_msi_msg_setvalid(void);

extern void piu_msi_getvalid(void);
extern void piu_msi_setvalid(void);
extern void piu_msi_getstate(void);
extern void piu_msi_setstate(void);
extern void piu_msi_getmsiq(void);
extern void piu_msi_setmsiq(void);

extern void init_pcie_buses(void);


struct piu_msieq {
	uint64_t eqmask;
	uint64_t *base;
	uint64_t *guest;
	uint64_t word0;
	uint64_t word1;
};

struct piu_msi_cookie {
	const struct piu_cookie *piu;
#ifdef CONFIG_PIU
	struct piu_msieq eq[PIU_NEQS];
#else
	struct piu_msieq eq[1];
#endif
};

struct piu_err_cookie {
	const struct piu_cookie *piu;
	uint64_t state[2]; /* XXX */
};

struct piu_cookie {
	uint64_t	handle;
	uint64_t	ncu;	/* NCU Base PA */
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
	uint64_t	mmuflush;

	uint64_t	intclr;
	uint64_t	intmap;
	uint64_t	*virtual_intmap;

	uint64_t	err_lock;
	uint64_t	err_lock_counter;
	uint64_t	tlu_oe_status;

	uint16_t	inomax;	/* Max INO */
	uint16_t	vino;	/* First Vino */
	uint64_t	*iotsb0;	/* IOTSB 8k page Base PA */
	uint64_t	*iotsb1;	/* IOTSB 4m page Base PA */
	uint64_t	*msieqbase;
	struct piu_msi_cookie *msicookie;
	struct piu_err_cookie *errcookie;

	struct pci_erpt	dmu_erpt; /* PIU error buffer */
	struct pci_erpt	peu_erpt; /* PIU error buffer */
	bool_t	blacklist;
};


typedef struct piu_cookie piu_dev_t;

extern const piu_dev_t piu_dev[];

extern bool_t is_piu_port_link_up(piu_dev_t *);
extern bool_t pci_config_get(piu_dev_t *, uint64_t offset, int size,
	uint64_t *valp);
extern bool_t pci_config_put(piu_dev_t *, uint64_t offset, int size,
	uint64_t val);
extern bool_t pci_io_peek(piu_dev_t *, uint64_t offset, int size,
	uint64_t *valp);
extern bool_t pci_io_poke(piu_dev_t *, uint64_t offset, int size,
	uint64_t val, uint64_t cfg_offset);

extern bool_t piu_link_up(piu_dev_t *);
extern bool_t piu_link_down(piu_dev_t *);

extern bool_t pcie_bus_reset(int busnum);

extern void piu_reset_onboard_devices(void);

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_PIU_H */
