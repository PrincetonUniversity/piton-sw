/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci_fire.s
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

	.ident	"@(#)vpci_fire.s	1.51	07/07/17 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <strand.h>
#include <offsets.h>
#include <debug.h>
#include <util.h>
#include <abort.h>
#include <fire.h>
#include <vdev_intr.h>
#include <vpci_errs.h>
#include <ldc.h>

#if defined(CONFIG_FIRE)

#define	REGNO2OFFSET(no, off)		sllx	no, 3, off
#define	PCIDEV2FIREDEV(pci, fire)	sllx	pci, 4, fire

/*
 * CHK_FIRE_LINK_STATUS - Check status of Fire link. Returns status
 * of 0 if the link is down.
 *
 * Delay Slot:	 not safe in a delay slot
 */
#define CHK_FIRE_LINK_STATUS(firecookie, status, scr1)		 \
	ldx     [firecookie + FIRE_COOKIE_PCIE], status		;\
	set     FIRE_PLC_TLU_CTB_TLR_TLU_STS, scr1		;\
	ldx     [status + scr1], scr1				;\
	and     scr1, FIRE_TLU_STS_STATUS_MASK, scr1		;\
	cmp     scr1, FIRE_TLU_STS_STATUS_DATA_LINK_ACTIVE	;\
	movne   %xcc, 0, status

#if FIRE_MSIEQ_SIZE != 0x28
#error "FIRE_MSIEQ_SIZE changed, breaks the shifts below"
#endif
#define	MSIEQNUM2MSIEQ(firecookie, num, msieq, scr1, scr2) \
	ldx	[firecookie + FIRE_COOKIE_MSICOOKIE], msieq ;\
	sllx	num, 5, scr1				;\
	sllx	num, 3, scr2				;\
	add	scr1, scr2, scr1			;\
	inc	FIRE_MSI_COOKIE_EQ, scr1		;\
	add	msieq, scr1, msieq


	! Ordered to minimize wasted space
	BSS_GLOBAL(fire_a_equeue, (FIRE_NEQS * FIRE_EQSIZE), 512 KB)
	BSS_GLOBAL(fire_a_iotsb, IOTSB_SIZE, 8 KB)
	BSS_GLOBAL(fire_b_equeue, (FIRE_NEQS * FIRE_EQSIZE), 512 KB)
	BSS_GLOBAL(fire_b_iotsb, IOTSB_SIZE, 8 KB)
	BSS_GLOBAL(fire_virtual_intmap, 0x10, 0x10)

	DATA_GLOBAL(fire_jbus_init_table)
#ifdef CONFIG_FIRE_EBUS
	.xword	FIRE_SIZE(EBUS_SIZE), FIRE_EBUS_OFFSET_MASK
	.xword	FIRE_BAR_V(EBUS), FIRE_EBUS_OFFSET_BASE
#else
 	.xword	FIRE_BAR(EBUS), FIRE_EBUS_OFFSET_BASE
#endif
	.xword	FIRE_BAR(CFGIO(A)), FIRE_PCIE_A_IOCON_OFFSET_BASE
	.xword	FIRE_BAR(MEM32(A)), FIRE_PCIE_A_MEM32_OFFSET_BASE
	.xword	FIRE_BAR(MEM64(A)), FIRE_PCIE_A_MEM64_OFFSET_BASE
	.xword	FIRE_BAR(MEM32(B)), FIRE_PCIE_B_MEM32_OFFSET_BASE
	.xword	FIRE_BAR(CFGIO(B)), FIRE_PCIE_B_IOCON_OFFSET_BASE
	.xword	FIRE_BAR(MEM64(B)), FIRE_PCIE_B_MEM64_OFFSET_BASE

	.xword	FIRE_SIZE(MEM32_SIZE), FIRE_PCIE_A_MEM32_OFFSET_MASK
	.xword	FIRE_BAR_V(MEM32(A)), FIRE_PCIE_A_MEM32_OFFSET_BASE

	.xword	FIRE_SIZE(CFGIO_SIZE), FIRE_PCIE_A_IOCON_OFFSET_MASK
	.xword	FIRE_BAR_V(CFGIO(A)), FIRE_PCIE_A_IOCON_OFFSET_BASE

	.xword	FIRE_SIZE(MEM64_SIZE), FIRE_PCIE_A_MEM64_OFFSET_MASK
	.xword	FIRE_BAR_V(MEM64(A)), FIRE_PCIE_A_MEM64_OFFSET_BASE

	.xword	FIRE_SIZE(MEM32_SIZE), FIRE_PCIE_B_MEM32_OFFSET_MASK
	.xword	FIRE_BAR_V(MEM32(B)), FIRE_PCIE_B_MEM32_OFFSET_BASE

	.xword	FIRE_SIZE(CFGIO_SIZE), FIRE_PCIE_B_IOCON_OFFSET_MASK
	.xword	FIRE_BAR_V(CFGIO(B)), FIRE_PCIE_B_IOCON_OFFSET_BASE

	.xword	FIRE_SIZE(MEM64_SIZE), FIRE_PCIE_B_MEM64_OFFSET_MASK
	.xword	FIRE_BAR_V(MEM64(B)), FIRE_PCIE_B_MEM64_OFFSET_BASE

	/* From Solaris Driver */
	.xword	0x8000000000000000, FIRE_JBUS_PAR_CTL
	.xword	0x000000000600c047, FIRE_JBC_FATAL_RESET_ENABLE_REG
	.xword	0xffffffffffffffff, FIRE_JBC_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS
	.xword	0xffffffffffffffff, FIRE_JBC_INTERRUPT_MASK_REG
	.xword	0xffffffffffffffff, FIRE_JBC_ERROR_LOG_EN_REG
	.xword	0xffffffffffffffff, FIRE_JBC_ERROR_INT_EN_REG
	! XXX
	.xword	0xfffc000000000000, FIRE_DLC_IMU_ICS_MEM_64_PCIE_OFFSET_REG
	.xword	0x000007f513cb7000, FIRE_FIRE_CONTROL_STATUS
	.xword	-1,-1 /* End of Table */
	SET_SIZE(fire_jbus_init_table)

	DATA_GLOBAL(fire_leaf_init_table)
	.xword	0xffffffffffffffff, FIRE_DLC_IMU_ICS_IMU_ERROR_LOG_EN_REG
	.xword	0xffffffffffffffff, FIRE_DLC_IMU_ICS_IMU_INT_EN_REG
	.xword	0xffffffffffffffff, FIRE_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS
	.xword	0x0000000000000010, FIRE_DLC_ILU_CIB_ILU_LOG_EN
	.xword	0x0000001000000010, FIRE_DLC_ILU_CIB_ILU_INT_EN
	/*
	 * Changes to the CTO field of FIRE_PLC_TLU_CTB_TLR_TLU_CTL
	 * need to be reflected in the Niagara JBI_TRANS_TIMEOUT
	 * register.  See the setup_jbi routine in setup.s.
	 */
#ifdef FIRE_ERRATUM_20_18
	/*
	 * Also, see below where NPRW_EN is masked off for Fire 2.0 but
	 * is set here for Fire 2.1 and later.
	 */
#endif
	.xword	0x00000000da130001, FIRE_PLC_TLU_CTB_TLR_TLU_CTL
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_OE_LOG
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_OE_INT_EN
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_TLR_DEV_CTL
	.xword	0x0000000000000040, FIRE_PLC_TLU_CTB_TLR_LNK_CTL
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_UE_LOG
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_UE_INT_EN
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_CE_LOG
	.xword	0xffffffffffffffff, FIRE_PLC_TLU_CTB_TLR_CE_INT_EN
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RST
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_DBG_CONFIG
	.xword	0x00000000800000ff, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_INTERRUPT_MASK
	.xword	0x0000000000000100, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LL_CONFIG
	.xword	0x0000000000000003, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_FC_UP_CNTL
	.xword	0x0000000000000070, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_ACKNAK_LATENCY
	.xword	0x00000000000001bf, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RPLAY_TMR_THHOLD
	.xword	0x00000000ffff0000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RTRY_FIFO_PTR
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_PHY_ERR_MSK
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RX_PHY_MSK
	.xword	0x0000000000000050, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_TX_PHY_MSK
	.xword	0x00000000002dc6c0, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CONFIG2
	.xword	0x000000000007a120, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CONFIG3
	.xword	0x0000000000029c00, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CONFIG4
	.xword	0x0000000000000800, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CONFIG5
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_MSK
	.xword	0x0000000000000000, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_GL_MSK
	.xword	0xffffffffffffffff, FIRE_DLC_IMU_ICS_DMC_INTERRUPT_MASK_REG
	.xword	0x0000000000000000, FIRE_DLC_CRU_DMC_DBG_SEL_A_REG
	.xword	0x0000000000000000, FIRE_DLC_CRU_DMC_DBG_SEL_B_REG
	.xword	0xffffffffffffffff, FIRE_DLC_ILU_CIB_PEC_INT_EN
	.xword	0xffffffffffffffff, FIRE_DLC_MMU_INV
	.xword	0x0000000000000000, FIRE_DLC_MMU_TSB
	.xword	0x0000000000000703, FIRE_DLC_MMU_CTL
	.xword	0xffffffffffffffff, FIRE_DLC_MMU_INT_EN

	/* From OBP */
	.xword	0x00000000da130001, FIRE_PLC_TLU_CTB_TLR_TLU_CTL
	.xword	0x00000000a06bf035, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_GB_GL_CONFIG2
	.xword	0x0000000000000070, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_ACKNAK_LATENCY
	.xword	0x00000000000000f6, FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_RPLAY_TMR_THHOLD
	.xword	0x0000000002000000, FIRE_DLC_CRU_DMC_PCIE_CFG

	/* MSI ranges */

	.xword	0x000000007fff0000, FIRE_DLC_IMU_ICS_MSI_32_ADDR_REG
	.xword	0x00000003ffff0000, FIRE_DLC_IMU_ICS_MSI_64_ADDR_REG
	.xword	-1, -1 /* End of Table */
	SET_SIZE(fire_leaf_init_table)

/*
 * fire_init
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 */
	ENTRY_NP(fire_init)
	setx	fire_jbus_init_table, %g5, %g3
	setx	fire_dev, %g5, %g1
	ldx	[%i0 + CONFIG_RELOC], %o0
	sub	%g3, %o0, %g3
	sub	%g1, %o0, %g1
	!! %g1 = firep
	!! %g3 = fire_jbus_init_table base
	!! %g7 = return PC
	ldx	[%g1 + FIRE_COOKIE_JBUS], %g4
	brz,pn	%g4, 3f
	nop

	!! %g1 = firep
	!! %g3 = fire_init_table base
	!! %g4 = Fire Base JBus PA
	!! %g7 = return PC
	ldx	[%g4], %g2
	and	%g2, FIRE_JBUS_ID_MR_MASK, %g2
	cmp	%g2, FIRE_REV_2_0
	bgeu,pn	%xcc, 1f
	nop
#ifdef DEBUG
	PRINT("HV:Unsupported Fire Version\r\n")
#endif
	ba	hvabort
	rd	%pc, %g1

1:
	ldx	[%g3 + 8], %g5	! Offset
	add	%g5, 1, %g6
	brz,pn	%g6, 3f
	ldx	[%g3 + 0], %g6	! Data
	add	%g3, 16, %g3
	ba	1b
	stx	%g6, [%g4 + %g5]
3:
	setx	fire_leaf_init_table, %g5, %g3
	ldx	[%i0 + CONFIG_RELOC], %o0
	sub	%g3, %o0, %g3

	ldx	[%g1 + FIRE_COOKIE_PCIE], %g4
	ldx	[%g1 + FIRE_COOKIE_PCIE+FIRE_COOKIE_SIZE], %g5
	!! %g4 leaf A base address
	!! %g5 leaf B base address
	brz,pn	%g4, 3f
	nop
1:
	ldx	[%g3 + 8], %g6	! Offset
	add	%g6, 1, %g2
	brz,pn	%g2, 2f		! End of table?
	ldx	[%g3 + 0], %g2	! Data

#ifdef FIRE_ERRATUM_20_18
	/*
	 * Don't set the NPWR_EN bit in TLU CTL for Fire 2.0
	 */
	set	FIRE_PLC_TLU_CTB_TLR_TLU_CTL, %l0
	cmp	%g6, %l0
	bne,pt	%xcc, 4f
	nop

	/* Check Fire version */
	ldx	[%g1 + FIRE_COOKIE_JBUS], %l0
	brz,pn	%l0, 4f		! shouldn't happen at this point
	nop
	ldx	[%l0], %l0
	and	%l0, FIRE_JBUS_ID_MR_MASK, %l0
	cmp	%l0, FIRE_REV_2_0
	bne,pt	%xcc, 4f
	nop
	set	FIRE_TLU_CTL_NPWR_EN, %l0
	andn	%g2, %l0, %g2
4:
#endif
	add	%g3, 16, %g3
	stx	%g2, [%g4 + %g6]
	ba	1b
	stx	%g2, [%g5 + %g6]
2:
	! Setup Interrupt Mondo Data 0 register
	set	FIRE_DLC_IMU_RDS_MSI_INT_MONDO_DATA_0_REG, %g6
	stx	%g0, [%g4 + %g6]	! Leaf A
	stx	%g0, [%g5 + %g6]	! Leaf B

	! Setup Interrupt Mondo Data 1 register
	set	FIRE_DLC_IMU_RDS_MSI_INT_MONDO_DATA_1_REG, %g6
	set	FIRE_A_AID, %g2
	sllx	%g2, FIRE_DEVINO_SHIFT, %g2
	stx	%g2, [%g4 + %g6]	! Leaf A
	set	FIRE_B_AID, %g2
	sllx	%g2, FIRE_DEVINO_SHIFT, %g2
	stx	%g2, [%g5 + %g6]	! Leaf B

	! Setup interrupt mappings
	! mondo 62 leafs A and B
	! mondo 63 only leaf A
	STRAND_STRUCT(%g4)	/* FIXME: what does it want the PID for?*/
	ldub	[%g4 + STRAND_ID], %g2

	mov %g0, %g5
	! Add CPU number
	sllx	%g2, JPID_SHIFT, %g6
	or	%g5, %g6, %g5

	! Select a Fire Interrupt Controller
	and	%g2, (NFIREINTRCONTROLLERS - 1), %g2
	add	%g2, FIRE_INTR_CNTLR_SHIFT, %g2
	mov	1, %g6
	sllx	%g6, %g2, %g2
	or	%g5, %g2, %g5

	! Set MDO MODE bit
	mov	1, %g6
	sllx	%g6, FIRE_INTMR_MDO_MODE_SHIFT, %g6
	or	%g5, %g6, %g5

	! Set Valid bit
	mov	1, %g6
	sllx	%g6, FIRE_INTMR_V_SHIFT, %g6
	or	%g5, %g6, %g5

	mov	PCIE_ERR_INO, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g3
	stx	%g5, [%g3 + %g4]	! leaf A, modno 62
	ldx	[%g1 + FIRE_COOKIE_INTCLR], %g2
	stx	%g0, [%g2 + %g4]
	ldx	[%g2 + %g4], %g6
	ldx	[%g1 + FIRE_COOKIE_INTMAP+FIRE_COOKIE_SIZE], %g3
	stx	%g5, [%g3 + %g4]	! leaf B, mondo 62
	ldx	[%g1 + FIRE_COOKIE_INTCLR+FIRE_COOKIE_SIZE], %g2
	stx	%g0, [%g2 + %g4]
	ldx	[%g2 + %g4], %g6

	mov	JBC_ERR_INO, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g3
	stx	%g5, [%g3 + %g4]	! leaf A, mondo 63
	ldx	[%g1 + FIRE_COOKIE_INTCLR], %g2
	stx	%g0, [%g2 + %g4]

	! Clear Valid bit
	mov	1, %g6
	sllx	%g6, FIRE_INTMR_V_SHIFT, %g6
	bclr	%g6, %g5
	ldx	[%g1 + FIRE_COOKIE_INTMAP+FIRE_COOKIE_SIZE], %g3
	stx	%g5, [%g3 + %g4]	! leaf B, mondo 63
	ldx	[%g1 + FIRE_COOKIE_INTCLR+FIRE_COOKIE_SIZE], %g2
	stx	%g0, [%g2 + %g4]

	set	FIRE_DLC_MMU_CTL, %g5
	set	FIRE_DLC_MMU_TSB, %g6
	! Fire Leaf A PCIE reg base
	ldx	[%g1 + FIRE_COOKIE_PCIE], %g3
	! Fire Leaf B PCIE reg base
	ldx	[%g1 + FIRE_COOKIE_PCIE+FIRE_COOKIE_SIZE], %g4
	set	FIRE_MMU_CSR_VALUE, %g2
	! Leaf A MMU_CTRL reg
	stx	%g2, [%g3 + %g5]
	! Leaf B MMU_CTRL reg
	stx	%g2, [%g4 + %g5]

	ldx	[%g1 + FIRE_COOKIE_IOTSB], %g2
	ldx	[%g1 + FIRE_COOKIE_IOTSB+FIRE_COOKIE_SIZE], %g5
	or	%g2, FIRE_TSB_SIZE, %g2
	or	%g5, FIRE_TSB_SIZE, %g5
	! Leaf A MMU_TSB_CTRL reg
	stx	%g2, [%g3 + %g6]
	! Leaf B MMU_TSB_CTRL reg
	stx	%g5, [%g4 + %g6]

	!! %g1 = FIRE COOKIE
	!! %g3 = FIRE_A PCIE Base
	!! %g4 = FIRE_B PCIE Base
	ldx	[%g1 + FIRE_COOKIE_MSIEQBASE], %g2
	ldx	[%g1 + FIRE_COOKIE_MSIEQBASE+FIRE_COOKIE_SIZE], %g5
	setx	MSI_EQ_BASE_BYPASS_ADDR, %g7, %g6
	or	%g2, %g6, %g2
	or	%g5, %g6, %g5
	set	FIRE_DLC_IMU_EQS_EQ_BASE_ADDRESS, %g6
	! Leaf A  EQ Base Address
	stx	%g2, [%g3 + %g6]
	! Leaf B  EQ Base Address
	stx	%g5, [%g4 + %g6]
3:

#ifdef FIRE_ERRATUM_20_18

#define	BDF2DEV(b, d, f) ((((b) << 8) | ((d) << 5) | (f)) << 8)
#define	DV(v, d)	(((d) << 16) | (v)) /* for 32-bit ASI_L */
#define	VENDOR_PLX	0x10b5
#define	DEVICE32_PLX8532 DV(VENDOR_PLX, 0x8532)
#define	DEVICE32_PLX8516 DV(VENDOR_PLX, 0x8516)

	/* Check Fire version for 2.0 */
	ldx	[%g1 + FIRE_COOKIE_JBUS], %l0
	brz,pn	%l0, .skip_plx_workaround  ! shouldn't happen
	nop
	ldx	[%l0], %l0
	and	%l0, FIRE_JBUS_ID_MR_MASK, %l0
	cmp	%l0, FIRE_REV_2_0
	bne,pt	%xcc, .skip_plx_workaround
	nop

.check_plx_leafa:
	/* Check if link is up, it should be for the PLX leaf on Ontario */
	!! %g3 leaf A pcie base address
	clr	%l4
1:
	cmp	%l4, 20		! 20 * 50msec = 1 sec max delay
	bge,pn	%xcc, .skip_plx_leafa
	.empty
	CPU_MSEC_DELAY(50, %l5, %l6, %l7)
	set	FIRE_PLC_TLU_CTB_TLR_TLU_STS, %l0
	ldx	[%g3 + %l0], %l0
	and	%l0, FIRE_TLU_STS_STATUS_MASK, %l0
	cmp	%l0, FIRE_TLU_STS_STATUS_DATA_LINK_ACTIVE
	bne,pt	%xcc, 1b
	inc	%l4

	/* calculate PA of config address for BDF 2.0.0, offset 0 */
	set	BDF2DEV(2, 0, 0), %l0
	PCIDEV2FIREDEV(%l0, %l1)
	ldx	[%g1 + FIRE_COOKIE_CFG], %l2
	add	%l2, %l1, %l1
	!! %l1 PA of config address of BDF 2.0.0

	/* fire link up, but downlink needs a little more time */
	CPU_MSEC_DELAY(200, %l5, %l6, %l7)
	/* Check for PLX 8532/8516 */
	lduwa	[%l1]ASI_P_LE, %l2
	set	DEVICE32_PLX8532, %l3
	cmp	%l2, %l3
	be,pt	%xcc, 1f
	nop
	set	DEVICE32_PLX8516, %l3
	cmp	%l2, %l3
	bne,pn	%xcc, .skip_plx_leafa
	nop
1:
	stx	%l1, [%g1 + FIRE_COOKIE_EXTRACFGRDADDRPA]
#ifdef PLX_ERRATUM_LINK_HACK
	mov	%g7, %l7
	mov	%g3, %l2
	!! %l1 = plx config base addr
	!! %l2 = fire leaf base addr
	HVCALL(fire_plx_reset_hack)
	mov	%l7, %g7
#endif /* PLX_ERRATUM_LINK_HACK */
.skip_plx_leafa:

.check_plx_leafb:
	/* Check if link is up, it should be for the PLX leaf on Ontario */
	!! %g4 leaf B pcie base address
	clr	%l4
1:
	cmp	%l4, 20			! 20 * 50msec = 1 sec delay max
	bge,pn	%xcc, .skip_plx_leafb
	.empty
	CPU_MSEC_DELAY(50, %l5, %l6, %l7)
	set	FIRE_PLC_TLU_CTB_TLR_TLU_STS, %l0
	ldx	[%g4 + %l0], %l0
	and	%l0, FIRE_TLU_STS_STATUS_MASK, %l0
	cmp	%l0, FIRE_TLU_STS_STATUS_DATA_LINK_ACTIVE
	bne,pt	%xcc, 1b
	inc	%l4

	/* calculate PA of config address for BDF 2.0.0, offset 0 */
	set	BDF2DEV(2, 0, 0), %l0
	PCIDEV2FIREDEV(%l0, %l1)
	ldx	[%g1 + FIRE_COOKIE_SIZE + FIRE_COOKIE_CFG], %l2
	add	%l2, %l1, %l1
	!! %l1 PA of config address of BDF 2.0.0

	/* fire link up, but downlink needs a little more time */
	CPU_MSEC_DELAY(200, %l5, %l6, %l7)
	/* Check for PLX 8532/8516 */
	lduwa	[%l1]ASI_P_LE, %l2
	set	DEVICE32_PLX8532, %l3
	cmp	%l2, %l3
	be,pt	%xcc, 1f
	nop
	set	DEVICE32_PLX8516, %l3
	cmp	%l2, %l3
	bne,pn	%xcc, .skip_plx_leafb
	nop
1:
	stx	%l1, [%g1 + FIRE_COOKIE_SIZE + FIRE_COOKIE_EXTRACFGRDADDRPA]
#ifdef PLX_ERRATUM_LINK_HACK
	mov	%g7, %l7
	mov	%g4, %l2
	!! %l1 = plx config base addr
	!! %l2 = fire leaf base addr
	!! %g3 = fire leaf A base
	!! %g4 = fire leaf B base
	HVCALL(fire_plx_reset_hack)
	mov	%l7, %g7
#endif /* PLX_ERRATUM_LINK_HACK */
.skip_plx_leafb:

.skip_plx_workaround:
#endif
	HVRET
	SET_SIZE(fire_init)


/*
 * void fire_config_bypass(fire_dev_t *firep, bool_t enable);
 *
 *	Configures the bypass mode of a given fire PCI-E root complex.
 *
 *	%o0	= fire_dev_t *
 *	%o1	= enable (true) / disable (false) bypass mode
 */

	ENTRY(fire_config_bypass)

	ldx	[%o0 + FIRE_COOKIE_PCIE], %o2
	mov	FIRE_MMU_CSR_BE, %o3
	movrnz	%o1, %o3, %o1

	! Leaf MMU_CTRL reg
	set	FIRE_DLC_MMU_CTL, %o4
	ldx	[%o2 + %o4], %o5
	andn	%o5, %o3, %o5
	or	%o5, %o1, %o5
	stx	%o5, [%o2 + %o4]

	retl
	  nop
	SET_SIZE(fire_config_bypass)



#ifdef PLX_ERRATUM_LINK_HACK
/*
 * Workaround for PLX link training problem
 */

#define	PLX_HACK_STATUS_LEAFB_SHIFT	4
#define	PLX_HACK_STATUS_PORT1		0x1
#define	PLX_HACK_STATUS_PORT2		0x2
#define	PLX_HACK_STATUS_PORT8		0x4
#define	PLX_HACK_STATUS_PORT9		0x8

#define	PLX_PORT_OFFSET			0x1000
#define	PLX_UE_STATUS_REG_OFFSET	0xfb8
#define	PLX_UESR_TRAINING_ERROR		0x1
#define	PLX_VC0_RSRC_STATUS_HI		0x162
#define	PLX_VC0_RSRC_NEGPEND_SHIFT	0x1

#define	PLX_PCIE_CAPABILITY_HI	0x6a
#define	PLX_PCIE_PORTTYPE_MASK	0xf0
#define	PLX_PCIE_PORTTYPE_UPSTREAM	0x50
#define	PLX_CONFIG_CMD	0x4
#define	PLX_CONFIG_CMD_MEMENABLE	0x2
#define	PLX_CONFIG_BAR0	0x10


/*
 * Register usage:
 * %l1 - config base physical address
 * %l3 - mem32 base physical address
 */

/* Uses %l4/%l5 as scratch */
#define	PLX_MEM_STOREB(value, offset)		\
	set	value, %l4			;\
	set	offset, %l5			;\
	stub	%l4, [%l3 + %l5]

/* Uses %l4/%l5 as scratch */
#define	PLX_MEM_STOREW(value, offset)		\
	set	value, %l4			;\
	set	offset, %l5			;\
	stuha	%l4, [%l3 + %l5]ASI_P_LE

/* Uses %l4/%l5 as scratch */
#define	PLX_MEM_STOREL(value, offset)		\
	set	value, %l4			;\
	set	offset, %l5			;\
	stuwa	%l4, [%l3 + %l5]ASI_P_LE

/* Uses %l5 as scratch */
#define	PLX_MEM_FETCHW(offset, dest)		\
	set	offset, %l5			;\
	lduha	[%l3 + %l5]ASI_P_LE, dest

/* Uses %l5 as scratch */
#define	PLX_MEM_FETCHL(offset, dest)		\
	set	offset, %l5			;\
	lduwa	[%l3 + %l5]ASI_P_LE, dest

/* Uses %l4/%l5 as scratch */
#define	PLX_CFG_STOREW(value, offset)		\
	set	value, %l4			;\
	set	offset, %l5			;\
	stuha	%l4, [%l1 + %l5]ASI_P_LE

#define	PLX_CFG_STOREREGW(reg, offset)	\
	set	offset, %l5			;\
	stuha	reg, [%l1 + %l5]ASI_P_LE

/* Uses %l4/%l5 as scratch */
#define	PLX_CFG_STOREL(value, offset)		\
	set	value, %l4			;\
	set	offset, %l5			;\
	stuwa	%l4, [%l1 + %l5]ASI_P_LE

#define	PLX_CFG_STOREREGL(reg, offset)		\
	set	offset, %l5			;\
	stuwa	reg, [%l1 + %l5]ASI_P_LE

/* Uses %l5 as scratch */
#define	PLX_CFG_FETCHB(offset, dest)		\
	set	offset, %l5			;\
	ldub	[%l1 + %l5], dest

/* Uses %l5 as scratch */
#define	PLX_CFG_FETCHW(offset, dest)		\
	set	offset, %l5			;\
	lduha	[%l1 + %l5]ASI_P_LE, dest

/* Uses %l5 as scratch */
#define	PLX_CFG_FETCHL(offset, dest)		\
	set	offset, %l5			;\
	lduwa	[%l1 + %l5]ASI_P_LE, dest

/* Uses %g5/%g6 as scratch, invokes PLX_FETCH */
#define	PLX_TRAINING_ERROR_nz(port)				\
	PLX_MEM_FETCHW(((port * PLX_PORT_OFFSET) +		\
	    PLX_VC0_RSRC_STATUS_HI), %g5)			;\
	srlx	%g5, PLX_VC0_RSRC_NEGPEND_SHIFT, %g5		;\
	PLX_MEM_FETCHL(((port * PLX_PORT_OFFSET) +		\
	    PLX_UE_STATUS_REG_OFFSET), %g6)			;\
	and	%g5, %g6, %g5					;\
	btst	PLX_UESR_TRAINING_ERROR, %g5


/*
 * fire_plx_reset_hack - work around PLX link training problem
 *
 * %l1 PLX config space address
 * %l2 Fire leaf base
 * %g1 base of Fire state structures ("cookies")
 * %g3 fire leaf A base
 * %g4 fire leaf B base
 * %l3-%l6,%g5,%g6 available
 */
	ENTRY_NP(fire_plx_reset_hack)
	/*
	 * See if this hack has been disabled by the SP
	 */
	ldx	[%i0 + CONFIG_IGNORE_PLX_LINK_HACK], %l6
	brz,pt	%l6, 0f
	nop
	HVRET
0:

	/*
	 * Check for rev AA and upstream port
	 */
	PLX_CFG_FETCHB(0x8, %l6)
	cmp	%l6, 0xaa
	bne,pt	%xcc, .fire_plx_reset_hack_done
	nop

	PLX_CFG_FETCHW(PLX_PCIE_CAPABILITY_HI, %l6)
	and	%l6, PLX_PCIE_PORTTYPE_MASK, %l6
	cmp	%l6, PLX_PCIE_PORTTYPE_UPSTREAM
	bne,pt	%xcc, .fire_plx_reset_hack_done
	nop

	/*
	 * Get MEM32 base address for the appropriate leaf
	 */
	setx	FIRE_BAR(MEM32(A)), %l6, %l3
	setx	FIRE_BAR(MEM32(B)), %l6, %l4
	cmp	%l2, %g3	! compare current leaf to leaf A addr
	movne	%xcc, %l4, %l3
	!! %l3 = plx mem32 base addr

	/* It's probably not enabled to respond in cmd register */
	PLX_CFG_FETCHW(PLX_CONFIG_CMD, %g5)
	or	%g5, PLX_CONFIG_CMD_MEMENABLE, %g5
	PLX_CFG_STOREREGW(%g5, PLX_CONFIG_CMD)

	/* Map in PLX mem space BAR */
	PLX_CFG_STOREREGL(%g0, PLX_CONFIG_BAR0)
	mov	PLX_CONFIG_BAR0, %l5	! BAR0
	lduwa	[%l1 + %l5]ASI_P_LE, %g0 ! force completion of stores

	/*
	 * If the link is not up, and a training error was logged
	 * then try to retrain
	 */
	!! %l3 = plx mem32 base addr
	!! %l2 = fire pcie leaf base addr
	!! %l1 = plx cfg base addr

	/*
	 * Check for link training errors
	 */
	mov	0, %o0		! failure flag
	PLX_TRAINING_ERROR_nz(1) ! port 1
	bnz,a,pt %xcc, 0f
	  bset	PLX_HACK_STATUS_PORT1, %o0
0:	PLX_TRAINING_ERROR_nz(2) ! port 2
	bnz,a,pt %xcc, 0f
	  bset	PLX_HACK_STATUS_PORT2, %o0
0:	PLX_TRAINING_ERROR_nz(8) ! port 8
	bnz,a,pt %xcc, 0f
	  bset	PLX_HACK_STATUS_PORT8, %o0
0:	PLX_TRAINING_ERROR_nz(9) ! port 9
	bnz,a,pt %xcc, 0f
	  bset	PLX_HACK_STATUS_PORT9, %o0
0:
	brz,pt	%o0, .fire_plx_reset_hack_done
	nop

	/*
	 * PLX encountered a link training problem, tell vbsc to reset
	 * the system.
	 * %o0 contains a bitmask of ports on the plx that failed
	 * |9|8|2|1|
	 * For leaf B we shift the bitmask up by 4 bits:
	 * |B9|B8|B2|B1|A9|A8|A2|A1|
	 */
	mov	0, %g1
	cmp	%l2, %g3
	movne	%xcc, PLX_HACK_STATUS_LEAFB_SHIFT, %g1
	sllx	%o0, %g1, %g1
	HVCALL(vbsc_hv_plxreset)
	/* spin until vbsc resets the system */
	ba	.
	nop

.fire_plx_reset_hack_done:
	PLX_CFG_STOREREGW(%g0, PLX_CONFIG_CMD)

	HVRET
	SET_SIZE(fire_plx_reset_hack)

#endif /* PLX_ERRATUM_LINK_HACK */


/*
 * fire_devino2vino
 *
 * %g1 Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 dev ino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 virtual INO (%o1)
 */
	ENTRY_NP(fire_devino2vino)
	!! %g1 pointer to FIRE_COOKIE
	ldx	[%g1 + FIRE_COOKIE_HANDLE], %g2
	cmp	%o0, %g2
	bne	herr_inval
	lduh	[%g1 + FIRE_COOKIE_INOMAX], %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	lduh	[%g1 + FIRE_COOKIE_VINO], %g4
	or	%o1, %g4, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_devino2vino)

/*
 * fire_intr_getvalid
 *
 * %g1 Fire Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(fire_intr_getvalid)
	!! %g1 pointer to FIRE_COOKIE
	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g2
	and	%o0, FIRE_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g2 + %g4], %g5
	sra	%g5, 0, %g5
	mov	INTR_DISABLED, %o1
	movrlz	%g5, INTR_ENABLED, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_intr_getvalid)

/*
 * _fire_intr_setvalid
 *
 * %g1 Fire Cookie Pointer
 * %g2 INO
 * %g3 intr valid state
 * --
 *
 * ret0 Fire Cookie (%g1)
 * ret1 INO (%g2)
 */
	ENTRY_NP(_fire_intr_setvalid)
	!! %g1 = pointer to FIRE_COOKIE
	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g6
	and	%g2, FIRE_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	add	%g4, %g6, %g4
	ldx	[%g4], %g5
	mov	1, %g6
	sllx	%g6, FIRE_INTMR_V_SHIFT, %g6
	andn	%g5, %g6, %g5
	sllx	%g3, FIRE_INTMR_V_SHIFT, %g6
	or	%g5, %g6, %g5
	stx	%g5, [%g4]

	HVRET
	SET_SIZE(_fire_intr_setvalid)

/*
 * fire_intr_setvalid
 *
 * %g1 Fire Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_intr_setvalid)
	!! %g1 = pointer to FIRE_COOKIE
	mov	%o0, %g2
	mov	%o1, %g3
	HVCALL(_fire_intr_setvalid)

	HCALL_RET(EOK)
	SET_SIZE(fire_intr_setvalid)

/*
 * fire_intr_getstate
 *
 * %g1 Fire Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 1: Pending / 0: Idle
 */
	ENTRY_NP(fire_intr_getstate)
	!! %g1 pointer to FIRE_COOKIE
	ldx	[%g1 + FIRE_COOKIE_INTCLR], %g2
	and	%o0, FIRE_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g2 + %g4], %g3
	sub	%g3, FIRE_INTR_RECEIVED, %g4
	movrz	%g4, INTR_DELIVERED, %o1
	movrnz	%g4, INTR_RECEIVED, %o1
	movrz	%g3, INTR_IDLE, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_intr_getstate)

/*
 * fire_intr_setstate
 *
 * %g1 Fire Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 (%o1) 1: Pending / 0: Idle  XXX
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_intr_setstate)
	!! %g1 pointer to FIRE_COOKIE
	cmp	%o1, INTR_DELIVERED
	bgu,pn	%xcc, herr_inval
	mov	%o0, %g2
	mov	%o1, %g3
	HVCALL(_fire_intr_setstate)

	HCALL_RET(EOK)
	SET_SIZE(fire_intr_setstate)

/*
 * %g1 = Fire Cookie
 * %g2 = device ino
 * %g3 = Pending/Idle
 * --
 * %g1 = Fire Cookie
 * %g2 = device ino
 */
	ENTRY_NP(_fire_intr_setstate)
	ldx	[%g1 + FIRE_COOKIE_INTCLR], %g5
	and	%g2, FIRE_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	movrz	%g3, FIRE_INTR_IDLE, %g3
	movrnz	%g3, FIRE_INTR_RECEIVED, %g3
	stx	%g3, [%g5 + %g4]

	HVRET
	SET_SIZE(_fire_intr_setstate)

/*
 * fire_intr_gettarget
 *
 * %g1 Fire Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(fire_intr_gettarget)
	!! %g1 pointer to FIRE_COOKIE

	mov	%o0, %g2
	HVCALL(_fire_intr_gettarget)

	! get the virtual cpuid
	PID2VCPUP(%g3, %g4, %g5, %g6)
	ldub	[%g4 + CPU_VID], %o1

	HCALL_RET(EOK)
	SET_SIZE(fire_intr_gettarget)

/*
 * %g1 = Fire cookie
 * %g2 = device ino
 * --
 * %g1 = Fire cookie
 * %g2 = device ino
 * %g3 = phys cpuid
 */
	ENTRY_NP(_fire_intr_gettarget)
	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g3
	and	%g2, FIRE_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g3 + %g4], %g3
	srlx	%g3, JPID_SHIFT, %g3
	and	%g3, JPID_MASK, %g4

		/* FIXME: What is this trying to do ?! */
	ROOT_STRUCT(%g3)
	ldx	[%g3 + CONFIG_VCPUS], %g3
	set	VCPU_SIZE, %g5
	mulx	%g4, %g5, %g5
	add	%g3, %g5, %g3
	VCPU2STRAND_STRUCT(%g3, %g3)
	ldub	[%g3 + STRAND_ID], %g3

	HVRET
	SET_SIZE(_fire_intr_gettarget)

/*
 * fire_intr_settarget
 *
 * %g1 Fire Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_intr_settarget)
	!! %g1 pointer to FIRE_COOKIE
	GUEST_STRUCT(%g3)
	VCPUID2CPUP(%g3, %o1, %g4, herr_nocpu, %g5)

	IS_CPU_IN_ERROR(%g4, %g5)
	be,pn	%xcc, herr_cpuerror
	nop

	VCPU2STRAND_STRUCT(%g4, %g3)
	ldub	[%g3 + STRAND_ID], %g3
	and	%o0, FIRE_DEVINO_MASK, %g2

	HVCALL(_fire_intr_settarget)

	HCALL_RET(EOK)
	SET_SIZE(fire_intr_settarget)

/*
 * %g1 = fire cookie
 * %g2 = device ino
 * %g3 = Physical CPU number
 * --
 * %g1 = fire cookie
 * %g2 = device ino
 */
	ENTRY_NP(_fire_intr_settarget)
	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g4
	REGNO2OFFSET(%g2, %g6)
	add	%g4, %g6, %g4
	ldx	[%g4], %g5

	!! %g2 INO offset
	!! %g3 Physical CPU number
	!! %g4 INTMAP base
	!! %g5 INTMAP reg value

	! Add CPU number
	mov	JPID_MASK, %g6
	sllx	%g6, JPID_SHIFT, %g6
	andn	%g5, %g6, %g5
	sllx	%g3, JPID_SHIFT, %g6
	or	%g5, %g6, %g5

	! Clear Interrupt Controller bits
	andn	%g5, (FIRE_INTR_CNTLR_MASK << FIRE_INTR_CNTLR_SHIFT), %g5

	! Select a Fire Interrupt Controller
	and	%g3, (NFIREINTRCONTROLLERS - 1), %g3
	add	%g3, FIRE_INTR_CNTLR_SHIFT, %g3
	mov	1, %g6
	sllx	%g6, %g3, %g3
	or	%g5, %g3, %g5

	! Set MDO MODE bit
	mov	1, %g6
	sllx	%g6, FIRE_INTMR_MDO_MODE_SHIFT, %g6
	or	%g5, %g6, %g5

	stx	%g5, [%g4]

	HVRET
	SET_SIZE(_fire_intr_settarget)

/*
 * fire_iommu_map
 *
 * %g1 Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * arg3 tte attributes (%o3)
 * arg4 io_page_list_p (%o4)
 * --
 * ret0 status (%o0)
 * ret1 #ttes mapped (%o1)
 */
	ENTRY_NP(fire_iommu_map)
	!! %g1 pointer to FIRE_COOKIE
	and	%o3, HVIO_TTE_ATTR_MASK, %g7
	cmp	%o3, %g7
	bne,pn	%xcc, herr_inval
	! Check io_page_list_p alignment
	! and make sure it is 8 byte aligned
	btst	SZ_LONG - 1, %o4
	bnz,pn	%xcc, herr_badalign
	ldx	[%g1 + FIRE_COOKIE_IOTSB], %g5
	set	IOTSB_INDEX_MAX, %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	brlez,pn %o2, herr_inval
	cmp	%o2, IOMMU_MAP_MAX
	movgu	%xcc, IOMMU_MAP_MAX, %o2

	! Check to ensure the end of the mapping is still within
	! range.

	!! %o2 #ttes
	!! %o1 tte index
	!! %g3 IOTSB_INDEX_MAX

	add	%o1, %o2, %g2
	inc	%g3		! make sure last mapping succeeds.
	cmp	%g2, %g3
	bgu,pn	%xcc, herr_inval
	nop

	GUEST_STRUCT(%g2)

	sllx	%o2, IOTTE_SHIFT, %g6
	RA2PA_RANGE_CONV_UNK_SIZE(%g2, %o4, %g6, herr_noraddr, %g7, %g3)
	mov	%g3, %g6
	!! %g6	PA

	ldx	[%g1 + FIRE_COOKIE_MMU], %g1
	mov	1, %g7
	sllx	%g7, FIRE_IOTTE_V_SHIFT, %g7
	or	%g7, %o3, %o3

	set	IOMMU_PAGESIZE, %g4

	!! %g1 = Fire MMU Reg Block Base
	!! %g2 = Guest Struct
	!! %g4 = IOTSB pagesize
	!! %g5 = IOTSB base
	!! %g6 = PA of pagelist
	!! %o1 = TTE index
	!! %o2 = #ttes to map
	!! %o3 = TTE Attributes + Valid Bit

	sllx	%o1, IOTTE_SHIFT, %o1
	add	%g5, %o1, %g5
	mov	0, %o1

	!! %g1 = Fire MMU Reg Block Base
	!! %g2 = Guest
	!! %g4 = IOTSB pagesize
	!! %g5 = IOTSB base
	!! %g6 = PA of pagelist
	!! %o1 = TTE index
	!! %o2 = #ttes to map
	!! %o3 = TTE Attributes + Valid Bit

.fire_iommu_map_loop:
	ldx	[%g6], %g3
	srlx	%g3, FIRE_PAGESIZE_8K_SHIFT, %o0
	sllx	%o0, FIRE_PAGESIZE_8K_SHIFT, %o0

	cmp	%g3, %o0
	bne,pn	%xcc, .fire_badalign
	nop

	RA2PA_RANGE_CONV(%g2, %o0, %g4, .fire_check_ldc_ra, %g7, %g3)
	ba	.fire_valid_ra
	mov	%g3, %o0

.fire_check_ldc_ra:
	LDC_IOMMU_GET_PA(%g2, %o0, %g3, %g7, .fire_noraddr, .fire_noaccess)
	mov	%g3, %o0

.fire_valid_ra:
	!! %g1 = Fire MMU Reg Block Base
	!! %g2 = Guest Struct
	!! %g4 = IOTSB pagesize
	!! %g5 = IOTSB base
	!! %g6 = PA of pagelist
	!! %o0 = PA of map addr
	!! %o1 = TTE index
	!! %o2 = #ttes to map
	!! %o3 = TTE Attributes + Valid Bit
	or	%o0, %o3, %o0
	stx	%o0, [%g5]
	and	%g5, (1 << 6) - 1, %o0

	stx	%g5, [%g1+0x100]	! IOMMU Flush

	add	%g5, IOTTE_SIZE, %g5	! *IOTSB++
	add	%g6, IOTTE_SIZE, %g6	! *PAGELIST++
	sub	%o2, 1, %o2
	brgz,pt	%o2, .fire_iommu_map_loop
	add	%o1, 1, %o1

.fire_noaccess:
	brz,pn	%o1, herr_noaccess
	mov	0, %o2
	HCALL_RET(EOK)

.fire_noraddr:
	brz,pn	%o1, herr_noraddr
	mov	0, %o2
	HCALL_RET(EOK)

.fire_badalign:
	brz,pn	%o1, herr_badalign
	mov	0, %o2
	HCALL_RET(EOK)
	SET_SIZE(fire_iommu_map)

/*
 * fire_iommu_map_v2
 *
 * %g1 Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * arg3 tte attributes (%o3)
 * arg4 io_page_list_p (%o4)
 * --
 * ret0 status (%o0)
 * ret1 #ttes mapped (%o1)
 */
	ENTRY_NP(fire_iommu_map_v2)
	set	HVIO_TTE_ATTR_MASK_V2, %g7
	and	%o3, %g7, %g7
	cmp	%o3, %g7
	bne,pn	%xcc, herr_inval
	and	%o3, HVIO_TTE_ATTR_MASK, %o3
	ba,a	fire_iommu_map
	.empty
	SET_SIZE(fire_iommu_map_v2)

/*
 * fire_iommu_getmap
 * fire_iommu_getmap_v2
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * --
 * ret0 status (%o0)
 * ret1 attributes (%o1)
 * ret2 ra (%o2)
 */
	ENTRY_NP(fire_iommu_getmap)
	ALTENTRY(fire_iommu_getmap_v2)
	!! %g1 pointer to FIRE_COOKIE
	ldx	[%g1 + FIRE_COOKIE_IOTSB], %g5
	set	IOTSB_INDEX_MAX, %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	sllx	%o1, IOTTE_SHIFT, %g2
	ldx	[%g5 + %g2], %g5
	brgez,pt %g5, herr_nomap
	GUEST_STRUCT(%g2)

	!! %g1 = Fire Cookie Pointer
	!! %g2 = Guest pointer
	!! %g5 = IOTTE
	sllx	%g5, (64-JBUS_PA_SHIFT), %g3
	srlx	%g3, (64-JBUS_PA_SHIFT+FIRE_PAGESIZE_8K_SHIFT), %g3
	sllx	%g3, FIRE_PAGESIZE_8K_SHIFT, %g3
	PA2RA_CONV(%g2, %g3, %o2, %g7, %g4)	! PA -> RA (%o2)
	brnz	%g4, herr_nomap		/* invalid translation */
	nop

	and	%g5, HVIO_TTE_ATTR_MASK, %o1
	movrgez	%g5, 0, %o1	! Clear the attributes if V=0
	HCALL_RET(EOK)
	SET_SIZE(fire_iommu_getmap)

/*
 *
 *
 * %g1 Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * --
 * ret0 status (%o0)
 * ret1 #ttes demapped (%o1)
 */
	ENTRY_NP(fire_iommu_unmap)
	!! %g1 pointer to FIRE_COOKIE
	ldx	[%g1 + FIRE_COOKIE_IOTSB], %g5
	set	IOTSB_INDEX_MAX, %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	brlez,pn %o2, herr_inval
	cmp	%o2, IOMMU_MAP_MAX
	movgu	%xcc, IOMMU_MAP_MAX, %o2
	brz,pn	%o2, herr_inval
	add	%o1, %o2, %g2
	inc	%g3	! make sure last mapping succeeds.
	cmp	%g2, %g3
	bgu,pn	%xcc, herr_inval
	sllx	%o1, IOTTE_SHIFT, %g2
	add	%g5, %g2, %g2
	mov	0, %o1

	!! %g1 = Fire Cookie Pointer
	!! %g2 = IOTSB offset
	!! %o1 = #ttes unmapped so far
	!! %o2 = #ttes to unmap
	ldx	[%g1 + FIRE_COOKIE_MMU], %g1
0:
	ldx	[%g2], %g5
	! Clear V bit
	sllx	%g5, 1, %g4
	srlx	%g4, 1, %g4
	! Clear Attributes
	srlx	%g4, FIRE_PAGESIZE_8K_SHIFT, %g4
	sllx	%g4, FIRE_PAGESIZE_8K_SHIFT, %g4
	stx	%g4, [%g2]
	! IOMMU Flush
	stx	%g2, [%g1+0x100]
	add	%g2, IOTTE_SIZE, %g2
	sub	%o2, 1, %o2
	brgz,pt	%o2, 0b
	add	%o1, 1, %o1

	! Flush Fire TSB here XXXX
	HCALL_RET(EOK)
	SET_SIZE(fire_iommu_unmap)

/*
 * fire_iommu_getbypass
 *
 * arg0 dev config pa
 * arg1 ra
 * arg2 io attributes
 * --
 * ret0 status (%o0)
 * ret1 bypass addr (%o1)
 */
	ENTRY_NP(fire_iommu_getbypass)
	!! %g1 pointer to FIRE_COOKIE

	! Check to see if bypass is allowed
	! (We could check the pcie structure, but what better way
	! than to check and see what Fire itself has enabled after config)
	!
	! FIXME: Note S10U3 has a bug in the px driver that will assume
	! bypass is available if anything other than ENOTSUPP is returned
	! .. so if the other tests also fail and return EINVAL or EBADRADDR
	! *before* the bypass enable test then Solaris assumes bypass *is*
	! supported. For this reason, the not supported test must be first.
	! - ug !

	ldx	[%g1 + FIRE_COOKIE_PCIE], %g4
	set	FIRE_DLC_MMU_CTL, %g5
	ldx	[%g4 + %g5], %g5
	andcc	%g5, FIRE_MMU_CSR_BE, %g0
	be,pn	%xcc, herr_notsupported
	  nop

	andncc	%o2, HVIO_IO_ATTR_MASK, %g0
	bnz,pn	%xcc, herr_inval
	.empty

	GUEST_STRUCT(%g2)

	RA2PA_RANGE_CONV(%g2, %o1, 1, herr_noraddr, %g4, %g3)
	!! %g3 pa of bypass ra

	setx	FIRE_IOMMU_BYPASS_BASE, %g5, %g4
	or	%g3, %g4, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_iommu_getbypass)

/*
 * fire_config_get
 *
 * arg0 dev config pa (%o0)
 * arg1 PCI device (%o1)
 * arg2 offset (%o2)
 * arg3 size (%o3)
 * --
 * ret0 status (%o0)
 * ret1 error_flag (%o1)
 * ret2 value (%o2)
 */

	ENTRY_NP(fire_config_get)
	!! %g1 pointer to FIRE_COOKIE

	! If leaf is  blacklisted fail access
	lduw	[%g1 + FIRE_COOKIE_BLACKLIST], %g3
	brnz,a,pn  %g3, .skip_config_get
	  mov	1, %o1

	ldx	[%g1 + FIRE_COOKIE_CFG], %g3

	PCIDEV2FIREDEV(%o1, %g2)
	or	%g2, %o2, %g2
	sub	%g0, 1, %o2

	!! %g1 = Fire cookie
	!! %g2 = PCIE config space offset
	!! %g3 = CFG base address
	!! %o2 = Error return value

	CHK_FIRE_LINK_STATUS(%g1, %g5, %g6)
	brz,pn %g5, .skip_config_get
	  mov	1, %o1		! Error flag

	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	!! %g1 = Fire cookie
	!! %g2 = PCIE config space offset
	!! %g3 = CFG base address
	!! %g4 = STRAND struct

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	cmp	%o3, SZ_WORD
	beq,a,pn %xcc,1f
	  lduwa	[%g3 + %g2]ASI_P_LE, %o2
	cmp	%o3, SZ_HWORD
	beq,a,pn %xcc,1f
	  lduha	[%g3 + %g2]ASI_P_LE, %o2
	ldub	[%g3 + %g2], %o2

1:
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %o1
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	!! %g1 = Fire cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

.skip_config_get:
	HCALL_RET(EOK)
	SET_SIZE(fire_config_get)

/*
 * fire_config_put
 *
 * arg0 dev config pa (%o0)
 * arg1 PCI device (%o1)
 * arg2 offset (%o2)
 * arg3 size (%o3)
 * arg4 data (%o4)
 * --
 * ret0 status (%o0)
 * ret1 error_flag (%o1)
 */
	ENTRY_NP(fire_config_put)
	!! %g1 pointer to FIRE_COOKIE

	! If leaf is  blacklisted fail access
	lduw	[%g1 + FIRE_COOKIE_BLACKLIST], %g3
	brnz,a,pn  %g3, .skip_config_put
	  mov	1, %o1

	ldx	[%g1 + FIRE_COOKIE_CFG], %g3

	PCIDEV2FIREDEV(%o1, %g2)
	or	%g2, %o2, %g2

	!! %g1 = Fire cookie
	!! %g2 = PCIE config space offset
	!! %g3 = CFG base address

	CHK_FIRE_LINK_STATUS(%g1, %g5, %g6)
	brz,pn %g5, .skip_config_put
	  mov	1, %o1		! Error flag

	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	!! %g1 = Fire cookie
	!! %g2 = PCIE config space offset
	!! %g3 = CFG base address
	!! %g4 = STRAND struct

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	cmp	%o3, SZ_WORD
	beq,a,pn %xcc,1f
	  stwa	%o4, [%g3 + %g2]ASI_P_LE
	cmp	%o3, SZ_HWORD
	beq,a,pn %xcc,1f
	  stha	%o4, [%g3 + %g2]ASI_P_LE
	stb	%o4, [%g3 + %g2]
1:
#ifdef FIRE_ERRATUM_20_18
	ldx	[%g1 + FIRE_COOKIE_EXTRACFGRDADDRPA], %g6
	brz,pt %g6, 2f
	nop
	lduw	[%g6], %g0
2:
#endif
	andn	%g2, PCI_CFG_OFFSET_MASK, %g2
	ldub	[%g3 + %g2], %g0
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %o1
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	!! %g1 = Fire cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)
.skip_config_put:
	HCALL_RET(EOK)
	SET_SIZE(fire_config_put)

/*
 * arg0 (%g1) = Fire Cookie
 * arg2 (%g2) = Offset
 * arg3 (%g3) = size (1, 2, 4)
 * --------------------
 * ret0 = status (1 fail, 0 pass)
 * ret1 = data
 */

	ENTRY_NP(hv_config_get)

	!! %g1 =  fire cookie (pointer)
	!! %g2 = offset
	!! %g3 = size (1 byte, 2 bytes, 4 bytes)

	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	!! %g4 = Strand struct

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g4, %g5, %g6)


	ldx	[%g1 + FIRE_COOKIE_CFG], %g4
	cmp	%g3, 1
	beq,a,pn %xcc,1f
	  ldub	[%g4 + %g2], %g3
	cmp	%g3, 2
	beq,a,pn %xcc,1f
	  lduha	[%g4 + %g2]ASI_P_LE, %g3
	lduwa	[%g4 + %g2]ASI_P_LE, %g3
1:
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %g5
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g4, %g2, %g6)
	HVRET
	SET_SIZE(hv_config_get)

/*
 * bool_t pci_config_get(uint64_t firep, uint64_t offset, int size,
 *		uint64_t *data)
 */
        ENTRY(pci_config_get)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

        mov     %o0, %g1
        mov     %o1, %g2
	mov	%o2, %g3

	! %g1 - firep
	! %g2 - Address
	! %g3 - size ( 1, 2, 4)

	HVCALL(hv_config_get)

	stx	%g3, [%o3]
	movrnz	%g5, 0, %o0
	movrz	%g5, 1, %o0

        STRAND_POP(%g4, %g6)
        STRAND_POP(%g3, %g6)
        STRAND_POP(%g2, %g6)

        retl
          nop
	SET_SIZE(pci_config_get)



/*
 * arg0 (%o0) = Fire Cookie
 * arg2 (%o1) = Offset
 * arg3 (%o2) = size (1, 2, 4)
 * arg4 (%o3) = data
 * --------------------
 * ret0 (%o0)= status (1 fail, 0 pass)
 * %g1, %g5, %g6, %g7 Clobbered.
 *
 * bool_t pci_config_put(uint64_t firep, uint64_t offset, int size,
 *	uint64_t data)
 */

	ENTRY_NP(pci_config_put)
	!! %o0 = fire cookie (pointer)
	!! %o1 = offset
	!! %o2 = size (1 byte, 2 bytes, 4 bytes)
	!! %o3 = Data
	ldx	[%o0 + FIRE_COOKIE_CFG], %o4
	add	%o1, %o4, %o1

	mov	1, %g5
	STRAND_STRUCT(%g6)
	set	STRAND_IO_PROT, %g7

	!! %g6 = Strand struct

	! strand.io_prot = 1
	stx	%g5, [%g6 + %g7]

	DISABLE_PCIE_RWUC_ERRORS(%o0, %g5, %g7, %g1)

	cmp	%o2, 1
	beq,a,pn %xcc,1f
	  stb	%o3, [%o1]
	cmp	%o2, 2
	beq,a,pn %xcc,1f
	  stha	%o3, [%o1]ASI_P_LE
	stwa	%o3, [%o1]ASI_P_LE
1:

#ifdef FIRE_ERRATUM_20_18
	ldx	[%o0 + FIRE_COOKIE_EXTRACFGRDADDRPA], %g5
	brz,pt %g5, 2f
	nop
	lduw	[%g5], %g0
2:
#endif
	!! %g6 = Strand struct
	andn	%o1, PCI_CFG_OFFSET_MASK, %g1
	ldub	[%g1], %g0

	set	STRAND_IO_PROT, %g7
	! strand.io_prot = 0
	stx	%g0, [%g6 + %g7]
	set	STRAND_IO_ERROR, %g7
	! strand.io_error
	ldx	[%g6 + %g7], %o1
	! strand.io_error = 0
	stx	%g0, [%g6 + %g7]

	ENABLE_PCIE_RWUC_ERRORS(%o0, %g5, %g7, %g1)

	movrnz	%o1, 0, %o0
	movrz	%o1, 1, %o0

	retl
	  nop
	SET_SIZE(pci_config_put)



/*
 * arg0 (%g1) = Fire Cookie
 * arg2 (%g2) = Offset
 * arg3 (%g3) = size (1, 2, 4)
 * --------------------
 * ret0 = status (1 fail, 0 pass)
 * ret1 = data
 */

	ENTRY_NP(hv_io_peek)

	!! %g1 =  fire cookie (pointer)
	!! %g2 =  address
	!! %g3 = size (1 byte, 2 bytes, 4 bytes)

	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	!! %g4 = Strand struct

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g4, %g5, %g6)


	ldx	[%g1 + FIRE_COOKIE_CFG], %g4
	cmp	%g3, 1
	beq,a,pn %xcc,1f
	  ldub	[%g2], %g3
	cmp	%g3, 2
	beq,a,pn %xcc,1f
	  lduha	[%g2]ASI_P_LE, %g3
	lduwa	[%g2]ASI_P_LE, %g3
1:
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %g5
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g4, %g2, %g6)
	HVRET
	SET_SIZE(hv_io_peek)

/*
 * bool_t pci_io_peek(uint64_t firep, uint64_t address, int size,
 *		uint64_t *data)
 */
        ENTRY(pci_io_peek)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

        mov     %o0, %g1
        mov     %o1, %g2
	mov	%o2, %g3

	! %g1 - firep
	! %g2 - Address
	! %g3 - size ( 1, 2, 4)

	HVCALL(hv_io_peek)

	stx	%g3, [%o3]
	movrnz	%g5, 0, %o0
	movrz	%g5, 1, %o0

        STRAND_POP(%g4, %g6)
        STRAND_POP(%g3, %g6)
        STRAND_POP(%g2, %g6)

        retl
          nop
	SET_SIZE(pci_io_peek)



/*
 * arg0 (%o0) = Fire Cookie
 * arg1 (%o1) = Offset
 * arg2 (%o2) = size (1, 2, 4)
 * arg3 (%o3) = data
 * arg4 (%o4) = PCI device
 * --------------------
 * ret0 (%o0)= status (1 fail, 0 pass)
 * %g1, %g5, %g6, %g7 Clobbered.
 *
 * bool_t pci_io_put(uint64_t firep, uint64_t address, int size,
 *	uint64_t data)
 */

	ENTRY_NP(pci_io_poke)
	!! %o0 = fire cookie (pointer)
	!! %o1 = Address
	!! %o2 = size (1 byte, 2 bytes, 4 bytes)
	!! %o3 = Data
	!! %o4 = Config space offset for device

	STRAND_STRUCT(%g6)

	!! %g6 = Strand struct

	! strand.io_prot = 1
	mov	1, %g5
	set	STRAND_IO_PROT, %g7
	stx	%g5, [%g6 + %g7]

	DISABLE_PCIE_RWUC_ERRORS(%o0, %g5, %g7, %g1)

	cmp	%o2, 1
	beq,a,pn %xcc,1f
	  stb	%o3, [%o1]
	cmp	%o2, 2
	beq,a,pn %xcc,1f
	  stha	%o3, [%o1]ASI_P_LE
	stwa	%o3, [%o1]ASI_P_LE
1:

#ifdef FIRE_ERRATUM_20_18
	ldx	[%o0 + FIRE_COOKIE_EXTRACFGRDADDRPA], %g5
	brz,pt %g5, 2f
	nop
	lduw	[%g5], %g0
2:
#endif
	! Read from PCI config space as error barrier
	ldx	[%o0 + FIRE_COOKIE_CFG], %g5
	ldub	[%g5 + %o4], %g0

	!! %g6 = Strand struct

	set	STRAND_IO_PROT, %g7
	! strand.io_prot = 0
	stx	%g0, [%g6 + %g7]
	set	STRAND_IO_ERROR, %g7
	! strand.io_error
	ldx	[%g6 + %g7], %o1
	! strand.io_error = 0
	stx	%g0, [%g6 + %g7]

	ENABLE_PCIE_RWUC_ERRORS(%o0, %g5, %g7, %g1)

	movrnz	%o1, 0, %o0
	movrz	%o1, 1, %o0

	retl
	  nop
	SET_SIZE(pci_io_poke)

/*
 * fire_dma_sync
 *
 * %g1 = Fire Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * arg3 direction (%o3) (one or both of 1: for device 2: for cpu)
 * --
 * ret0 status (%o0)
 * ret1 #bytes synced (%o1)
 */
	ENTRY_NP(fire_dma_sync)
	GUEST_STRUCT(%g2)
	RA2PA_RANGE_CONV_UNK_SIZE(%g2, %o1, %o2, herr_noraddr, %g4, %g3)
	mov	%o2, %o1
	HCALL_RET(EOK);
	SET_SIZE(fire_dma_sync)

/*
 * fire_io_peek
 *
 * %g1 = Fire Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 error? (%o1)
 * ret2 data (%o2)
 */
	ENTRY_NP(fire_io_peek)
	!! %g1 = Fire Cookie
	GUEST_STRUCT(%g2)

	!! %g2 = Guestp
	!! %o1 = ra
	!! %o2 = size
	!! %g4, %g5 = scratch
	RANGE_CHECK_IO(%g2, %o1, %o2, .fire_io_peek_found, herr_noraddr,
	    %g4, %g6)
.fire_io_peek_found:

	CHK_FIRE_LINK_STATUS(%g1, %g5, %g6)
	brz,a,pn %g5, .skip_io_peek
	  mov	1, %o1		! Error flag

	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	!! %g1 = Fire cookie
	!! %g4 = STRAND struct

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	cmp	%o2, SZ_LONG
	beq,a,pn %xcc,1f
	  ldxa	[%o1]ASI_P_LE, %o2
	cmp	%o2, SZ_WORD
	beq,a,pn %xcc,1f
	  lduwa	[%o1]ASI_P_LE, %o2
	cmp	%o2, SZ_HWORD
	beq,a,pn %xcc,1f
	  lduha	[%o1]ASI_P_LE, %o2
	ldub	[%o1], %o2

1:	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %o1
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	!! %g1 = Fire cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

.skip_io_peek:
	HCALL_RET(EOK)
	SET_SIZE(fire_io_peek)

/*
 * fire_io_poke
 *
 * %g1 = Fire Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * arg3 data (%o3)
 * arg4 PCI device (%o4)
 * --
 * ret0 status (%o0)
 * ret1 error? (%o1)
 */
	ENTRY_NP(fire_io_poke)
	!! %g1 = Fire Cookie
	ldx	[%g1 + FIRE_COOKIE_CFG], %g3
	GUEST_STRUCT(%g2)

	!! %g1 = Fire Cookie
	!! %g2 = Guestp
	!! %o1 = ra
	!! %o2 = size
	!! %g4, %g5 = scratch
	RANGE_CHECK_IO(%g2, %o1, %o2, .fire_io_poke_found, herr_noraddr,
	    %g4, %g6)
.fire_io_poke_found:

	CHK_FIRE_LINK_STATUS(%g1, %g5, %g6)
	brz,a,pn %g5, .skip_io_poke
	  mov	1, %o1		! Error flag

	PCIDEV2FIREDEV(%o4, %g2)
	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	!! %g1 = Fire cookie
	!! %g2 = PCI device BDF
	!! %g3 = CFG base address
	!! %g4 = CPU struct

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	cmp	%o2, SZ_LONG
	beq,a,pn %xcc,1f
	  stxa	%o3, [%o1]ASI_P_LE
	cmp	%o2, SZ_WORD
	beq,a,pn %xcc,1f
	  stwa	%o3, [%o1]ASI_P_LE
	cmp	%o2, SZ_HWORD
	beq,a,pn %xcc,1f
	  stha	%o3, [%o1]ASI_P_LE
	stb	%o3, [%o1]
1:
	! Read from PCI config space
	ldub	[%g3 + %g2], %g0

	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %o1
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	!! %g1 = Fire cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

.skip_io_poke:
	HCALL_RET(EOK)
	SET_SIZE(fire_io_poke)

/*
 * fire_mondo_receive
 *
 * %g1 = Fire Cookie
 * %g2 = Mondo DATA0
 * %g3 = Mondo DATA1
 */
	ENTRY_NP(fire_mondo_receive)
	ba	insert_device_mondo_r
	rd	%pc, %g7
	retry
	SET_SIZE(fire_mondo_receive)

/*
 * fire_msiq_conf
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ base RA (%o2)
 * arg3 #entries (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msiq_conf)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	sethi	%hi(FIRE_EQSIZE-1), %g2
	or	%g2, %lo(FIRE_EQSIZE-1), %g2
	and	%o2, %g2, %g2
	brnz	%g2, herr_badalign
	cmp	%o3, FIRE_NEQRECORDS
	bne	herr_inval

	/*
	 * Verify RA range/alignment
	 */
	GUEST_STRUCT(%g2)
	andcc	%o2, 3, %g0
	bnz	%xcc, herr_badalign
	.empty
	RA2PA_RANGE_CONV(%g2, %o2, %g0, herr_noraddr, %g7, %g6)
	!! %g6 	paddr

	MSIEQNUM2MSIEQ(%g1, %o1, %g4, %g3, %g2)
	ldx	[%g1 + FIRE_COOKIE_EQSTATE], %g2
	REGNO2OFFSET(%o1, %g5)
	ldx	[%g2 + %g5], %g3
	and	%g3, 3, %g3
	sub	%g3, 1, %g3
	brnz	%g3, herr_inval
	ldx	[%g1 + FIRE_COOKIE_EQHEAD], %g2
	ldx	[%g1 + FIRE_COOKIE_EQTAIL], %g3

	stx	%g0, [%g2 + %g5]
	stx	%g0, [%g3 + %g5]
	stx	%g6, [%g4 + FIRE_MSIEQ_GUEST]

	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_conf)

/*
 * fire_msiq_info
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ra (%o1)
 * ret2 #entries (%o2)
 */
	ENTRY_NP(fire_msiq_info)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	.empty
	MSIEQNUM2MSIEQ(%g1, %o1, %g4, %g3, %g5)
	ldx	[%g4 + FIRE_MSIEQ_GUEST], %g5
	set	FIRE_NEQRECORDS, %o2
	movrz	%g5, %g0, %o2
	brz,pn	%g5, 1f
	GUEST_STRUCT(%g2)
	PA2RA_CONV(%g2, %g5, %o1, %g6, %g3)	! PA -> RA (%o1)
	brnz	%g3, herr_inval
	nop

1:	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_info)

/*
 * fire_msiq_getvalid
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 EQ valid (%o1) (0: Invalid 1: Valid)
 */
	ENTRY_NP(fire_msiq_getvalid)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	ldx	[%g1 + FIRE_COOKIE_EQSTATE], %g2
	REGNO2OFFSET(%o1, %g7)
	ldx	[%g2 + %g7], %g4
	and	%g4, 3, %g4
	sub	%g4, 1, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_getvalid)

/*
 * fire_msiq_setvalid
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ valid (%o2) (0: Invalid 1: Valid)
 * --
 * ret0 status
 */
	ENTRY_NP(fire_msiq_setvalid)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	.empty
	MSIEQNUM2MSIEQ(%g1, %o1, %g3, %g2, %g4)

	ldx	[%g3 + FIRE_MSIEQ_GUEST], %g2	! Guest Q base
	brnz	%g2, 1f
	movrz	%o2, FIRE_COOKIE_EQCTLCLR, %g3
	brnz	%o2, herr_inval
1:	movrnz	%o2, FIRE_COOKIE_EQCTLSET, %g3
	ldx	[%g1 + %g3], %g3
	setx	(1<<44), %g5, %g4
	REGNO2OFFSET(%o1, %g7)
	stx	%g4, [%g3 + %g7]
	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_setvalid)

/*
 * fire_msiq_getstate
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 EQ state (%o1) (0: Idle 1: Error)
 */
	ENTRY_NP(fire_msiq_getstate)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + FIRE_COOKIE_EQSTATE], %g2
	ldx	[%g2 + %g4], %g3
	and	%g3, 4, %o1
	movrnz	%o1, HVIO_MSIQSTATE_ERROR, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_getstate)

/*
 * fire_msiq_setstate
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ state (%o2) (0: Idle 1: Error)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msiq_setstate)
	REGNO2OFFSET(%o1, %g4)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	.empty
	/*
	 * To change state from error to idle, we set bits 57 and 47 in the
	 * Event Queue Control Clear Register (CCR)
	 *
	 * To change state from idle to error, we set bits 44 and 57 in the
	 * Event Queue Control Set Register (CSR)
	 */
	mov	FIRE_COOKIE_EQCTLCLR, %g6		! EQ CCR
	movrnz	%o2, FIRE_COOKIE_EQCTLSET, %g6		! EQ CSR
	ldx     [%g1 + %g6], %g2
	setx    (1 << FIRE_EQCCR_COVERR)|(1 << FIRE_EQCCR_E2I_SHIFT), %g5, %g3    ! set idle
        setx    (1 << FIRE_EQCSR_ENOVERR)|(1 << FIRE_EQCSR_EN_SHIFT), %g5, %g6    ! set error
        movrnz	%o2, %g6, %g3
        stx     %g3, [%g2 + %g4]

	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_setstate)

/*
 * fire_msiq_gethead
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status
 * ret1 head index
 */
	ENTRY_NP(fire_msiq_gethead)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + FIRE_COOKIE_EQHEAD], %g2
	ldx	[%g2 + %g4], %o1
	sllx	%o1, FIRE_EQREC_SHIFT, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_gethead)

/*
 * fire_msiq_sethead
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 head offset (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msiq_sethead)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	set	FIRE_EQSIZE, %g2
	cmp	%o2, %g2
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g6)
	ldx	[%g1 + FIRE_COOKIE_EQHEAD], %g2
	ldx	[%g2 + %g6], %g3
	mov	%o2, %g6
	sllx	%g3, FIRE_EQREC_SHIFT, %g3
	!! %g1 = FIRE COOKIE
	!! %g2 = EQ HEAD reg
	!! %g3 = Prev Head offset
	!! %g6 = New Head offset
	MSIEQNUM2MSIEQ(%g1, %o1, %g4, %g5, %g7)
	!! %g1 = FIRE COOKIE
	!! %g2 = EQ HEAD reg
	!! %g3 = Prev Head offset
	!! %g4 = struct *fire_msieq
	!! %g6 = New Head offset
	ldx	[%g4 + FIRE_MSIEQ_BASE], %g5	/* HW Q base */
	add	%g5, %g3, %g7
1:
	stx	%g0, [%g7 + 0x00]
	stx	%g0, [%g7 + 0x08]
	stx	%g0, [%g7 + 0x10]
	stx	%g0, [%g7 + 0x18]
	stx	%g0, [%g7 + 0x20]
	stx	%g0, [%g7 + 0x28]
	stx	%g0, [%g7 + 0x30]
	stx	%g0, [%g7 + 0x38]
	add	%g3, 0x40, %g3
	ldx	[%g4 + FIRE_MSIEQ_EQMASK], %g7
	and	%g3, %g7, %g3
	cmp	%g6, %g3
	bne	1b
	add	%g5, %g3, %g7
	REGNO2OFFSET(%o1, %g6)
	srlx	%o2, FIRE_EQREC_SHIFT, %g3
	stx	%g3, [%g2 + %g6]
	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_sethead)

/*
 * fire_msiq_gettail
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 tail index (%o1)
 */
	ENTRY_NP(fire_msiq_gettail)
	cmp	%o1, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + FIRE_COOKIE_EQTAIL], %g2
	ldx	[%g2 + %g4], %o1
	sllx	%o1, FIRE_EQREC_SHIFT, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msiq_gettail)

/*
 * fire_msi_getvalid
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI status (%o1) (0: Invalid 1: Valid)
 */
	ENTRY_NP(fire_msi_getvalid)
	cmp	%o1, FIRE_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + FIRE_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g4], %g5
	mov	HVIO_MSI_INVALID, %o1
	movrlz	%g5, HVIO_MSI_VALID, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_getvalid)

/*
 * fire_msi_setvalid
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI status (%o2) (0: Invalid 1: Valid)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msi_setvalid)
	cmp	%o1, FIRE_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + FIRE_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g4], %g5
	sllx	%g5, 1, %g5
	srlx	%g5, 1, %g5
	sllx	%o2, FIRE_MSIMR_V_SHIFT, %g3
	or	%g5, %g3, %g5
	stx	%g5, [%g2 + %g4]
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_setvalid)

/*
 * fire_msi_getstate
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI state (%o1) (0: Idle 1: Delivered)
 */
	ENTRY_NP(fire_msi_getstate)
	cmp	%o1, FIRE_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + FIRE_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g4], %g5
	brlz,pn %g5, 0f
	mov	HVIO_MSI_INVALID, %o1
	HCALL_RET(EOK)

0:	srlx	%g5, FIRE_MSIMR_EQWR_N_SHIFT, %o1
	and	%o1, HVIO_MSI_VALID, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_getstate)

/*
 * fire_msi_setstate
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI state (%o2) (0: Idle)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msi_setstate)
	cmp	%o1, FIRE_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	brnz,pn	%o2, herr_inval
	mov	1, %g5
	sllx	%g5, FIRE_MSIMR_EQWR_N_SHIFT, %g5
	ldx	[%g1 + FIRE_COOKIE_MSICLR], %g2
	stx	%g5, [%g2 + %g4]
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_setstate)

/*
 * fire_msi_getmsiq
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI EQ id (%o1)
 */
	ENTRY_NP(fire_msi_getmsiq)
	cmp	%o1, FIRE_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g7)
	ldx	[%g1 + FIRE_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g7], %o1
	and	%o1, FIRE_MSIEQNUM_MASK, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_getmsiq)

/*
 * fire_msi_setmsiq
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI EQ id (%o2)
 * arg3 MSI type (%o3) (MSI32=0 MSI64=1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msi_setmsiq)
	cmp	%o1, FIRE_MSI_MASK
	bgu,pn	%xcc, herr_inval
	cmp	%o2, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	ldx	[%g1 + FIRE_COOKIE_MSIMAP], %g2
	REGNO2OFFSET(%o1, %g7)
	ldx	[%g2 + %g7], %g5
	andn	%g5, FIRE_MSIEQNUM_MASK, %g5
	or	%g5, %o2, %g5
	stx	%g5, [%g2 + %g7]
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_setmsiq)

/*
 * fire_msi_msg_getmsiq
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI EQ id (%o1)
 */
	ENTRY_NP(fire_msi_msg_getmsiq)
	ldx	[%g1 + FIRE_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_CORR_OFF, %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_NONFATAL_OFF, %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_FATAL_OFF, %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_PME_OFF, %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_PME_ACK_OFF, %g3
	ba	herr_inval
	nop
1:	ldx	[%g2 + %g3], %o1
	and	%o1, FIRE_MSIEQNUM_MASK, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_msg_getmsiq)

/*
 * fire_msi_msg_setmsiq
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * arg2 MSI EQ id (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msi_msg_setmsiq)
	cmp	%o2, FIRE_NEQS
	bgeu,pn	%xcc, herr_inval
	ldx	[%g1 + FIRE_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_CORR_OFF, %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_NONFATAL_OFF, %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_FATAL_OFF, %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_PME_OFF, %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_PME_ACK_OFF, %g3
	ba	herr_inval
	nop
1:	ldx	[%g2 + %g3], %g4
	andn	%g4, FIRE_MSIEQNUM_MASK, %g4
	or	%g4, %o2, %g4
	stx	%g4, [%g2 + %g3]
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_msg_setmsiq)

/*
 * fire_msi_msg_getvalid
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI msg valid state (%o1)
 */
	ENTRY_NP(fire_msi_msg_getvalid)
	ldx	[%g1 + FIRE_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + FIRE_CORR_OFF], %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + FIRE_NONFATAL_OFF], %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + FIRE_FATAL_OFF], %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + FIRE_PME_OFF], %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + FIRE_PME_ACK_OFF], %g3
	ba,pt	%xcc, herr_inval
	nop
1:	movrlz	%g3, HVIO_PCIE_MSG_VALID, %o1
	movrgez	%g3, HVIO_PCIE_MSG_INVALID, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_msg_getvalid)

/*
 * fire_msi_msg_setvalid
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * arg2 MSI msg valid state (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_msi_msg_setvalid)
	cmp	%o2, 1
	bgu,pn	%xcc, herr_inval
	ldx	[%g1 + FIRE_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_CORR_OFF, %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_NONFATAL_OFF, %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_FATAL_OFF, %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_PME_OFF, %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	  mov	FIRE_PME_ACK_OFF, %g3
	ba	herr_inval
	nop
1:
	sllx	%o2, FIRE_MSGMR_V_SHIFT, %g5
	ldx	[%g2 + %g3], %g4
	sllx	%g4, 1, %g4
	srlx	%g4, 1, %g4
	or	%g4, %g5, %g4
	stx	%g4, [%g2 + %g3]
	HCALL_RET(EOK)
	SET_SIZE(fire_msi_msg_setvalid)

/*
 * fire_msi_mondo_receive
 *
 * %g1 = Fire Cookie
 * %g2 = Mondo DATA0
 * %g3 = Mondo DATA1
 */
	ENTRY_NP(fire_msi_mondo_receive)
	STRAND_PUSH(%g1, %g3, %g4)
	STRAND_PUSH(%g2, %g3, %g4)
	ba	insert_device_mondo_r
	rd	%pc, %g7
	STRAND_POP(%g2, %g3)
	STRAND_POP(%g1, %g3)

	and	%g2, FIRE_DEVINO_MASK, %g2
	sub	%g2, FIRE_EQ2INO(0), %g2
	MSIEQNUM2MSIEQ(%g1, %g2, %g3, %g4, %g5)
	!! %g1 = Fire Cookie
	!! %g2 = MSI EQ Number
	!! %g3 = struct *fire_msieq
	REGNO2OFFSET(%g2, %g2)
	ldx	[%g1 + FIRE_COOKIE_EQTAIL], %g5
	ldx	[%g5 + %g2], %g7
	ldx	[%g1 + FIRE_COOKIE_EQHEAD], %g5
	ldx	[%g5 + %g2], %g6

	!! %g1 = Fire COOKIE
	!! %g2 = MSI EQ OFFSET
	!! %g3 = struct fire_msieq *
	!! %g6 = Head
	!! %g7 = New Tail
	cmp	%g6, %g7
	be	9f
	sllx	%g6, FIRE_EQREC_SHIFT, %g6	/* New tail offset */
	sllx	%g7, FIRE_EQREC_SHIFT, %g7	/* Old Tail offset */

	ldx	[%g3 + FIRE_MSIEQ_GUEST], %g2	/* Guest Q base */
	brz,pn	%g2, 9f
	ldx	[%g3 + FIRE_MSIEQ_BASE], %g5	/* HW Q base */

	!! %g2 = Guest Q base
	!! %g3 = struct fire_msieq *
	!! %g5 = HW Q base
	!! %g6 = Old Tail
	!! %g7 = New Tail
	!! %g1 = scratch
	!! %g4 = scratch

1:
	! Word 0 is TTTT EQW0[63:61]
	ldx	[%g5 + %g6], %g1 ! Read Word 0 From HW
	stx	%g1, [%g3 + FIRE_MSIEQ_WORD0]

	srlx	%g1, FIRE_EQREC_TYPE_SHIFT+5, %g4
	stx	%g4, [%g2 + %g6] ! Store Word 0
	add	%g6, 8, %g6

	ldx	[%g5 + %g6], %g4 ! Read Word 1 from HW
	stx	%g4, [%g3 + FIRE_MSIEQ_WORD1]

	stx	%g0, [%g2 + %g6] ! Store Word 1 = 0
	add	%g6, 8, %g6

	stx	%g0, [%g2 + %g6] ! Store Word 2 = 0
	add	%g6, 8, %g6

	stx	%g0, [%g2 + %g6] ! Store Word 3 = 0
	add	%g6, 8, %g6

	! Word 4 is RRRR.RRRR EQW0[31:16]
	sllx	%g1, 64-(MSIEQ_RID_SHIFT+MSIEQ_RID_SIZE_BITS), %g4
	srlx	%g4, 64-MSIEQ_RID_SHIFT, %g4

	stx	%g4, [%g2 + %g6] ! Store Word 4
	add	%g6, 8, %g6

	! Word 5 is MSI address EQW1[63:0]
	ldx	[%g3 + FIRE_MSIEQ_WORD1], %g4
	stx	%g4, [%g2 + %g6] ! Store Word 5
	add	%g6, 8, %g6

	! Word 6 is MSI Data EQW0[15:0]
	sllx	%g1, 1, %g4
	brgz,pt	%g4, 2f
	sllx	%g1, 64-MSIEQ_DATA_SIZE_BITS, %g4
	! MSI
	srlx	%g4, 64-MSIEQ_DATA_SIZE_BITS, %g4
	stx	%g4, [%g2 + %g6] ! Store Word 6
	ba	3f
	add	%g6, 8, %g6

2:	! MSG
	!! %g1 = HW Word 0

	! Extract GGGG.GGGG EQW0[31:16] -> W6[47:32]
	srlx	%g1, MSIEQ_TID_SHIFT, %g4
	sllx	%g4, 64-MSIEQ_TID_SIZE_BITS, %g4
	srlx	%g4, 64-(MSIEQ_TID_SIZE_BITS+VPCI_MSIEQ_TID_SHIFT), %g4

	ldx	[%g3 + FIRE_MSIEQ_WORD0], %g1

	! Extract CCC field EQW0[58:56] -> W6[18:16]
	sllx	%g1, 64-(MSIEQ_MSG_RT_CODE_SHIFT+MSIEQ_MSG_RT_CODE_SIZE_BITS), %g1
	srlx	%g1, 64-MSIEQ_MSG_RT_CODE_SIZE_BITS, %g1
	sllx	%g1, VPCI_MSIEQ_MSG_RT_CODE_SHIFT, %g1
	or	%g1, %g4, %g4

	ldx	[%g3 + FIRE_MSIEQ_WORD0], %g1

	! Extract MMMM.MMMM field EQW0[7:0] -> W6[7:0]
	sllx	%g1, 64-MSIEQ_MSG_CODE_SIZE_BITS, %g1
	srlx	%g1, 64-MSIEQ_MSG_CODE_SIZE_BITS, %g1
	or	%g1, %g4, %g4
	stx	%g4, [%g2 + %g6] ! Store Word 6
	add	%g6, 8, %g6
3:
	stx	%g0, [%g2 + %g6] ! Store Word 7
	add	%g6, 8, %g6

	ldx	[%g3 + FIRE_MSIEQ_EQMASK], %g4
	and	%g6, %g4, %g6
	cmp	%g6, %g7
	bne	1b
	nop
9:
	retry
	SET_SIZE(fire_msi_mondo_receive)

	DATA_GLOBAL(fire_perf_regs_table)
	! Registers 0 - 2
	.xword	FIRE_JBC_PERF_CNTRL, 0x000000000000ffff	! Read Offset & Mask
	.xword	FIRE_JBC_PERF_CNTRL, 0x000000000000ffff	! Write Offset & Mask
	.xword	FIRE_JBC_PERF_CNT0, 0xffffffffffffffff
	.xword	FIRE_JBC_PERF_CNT0, 0xffffffffffffffff
	.xword	FIRE_JBC_PERF_CNT1, 0xffffffffffffffff
	.xword	FIRE_JBC_PERF_CNT1, 0xffffffffffffffff
	! Registers 3 - 5
	.xword	FIRE_DLC_IMU_ICS_IMU_PERF_CNTRL, 0x000000000000ffff
	.xword	FIRE_DLC_IMU_ICS_IMU_PERF_CNTRL, 0x000000000000ffff
	.xword	FIRE_DLC_IMU_ICS_IMU_PERF_CNT0, 0xffffffffffffffff
	.xword	FIRE_DLC_IMU_ICS_IMU_PERF_CNT0, 0xffffffffffffffff
	.xword	FIRE_DLC_IMU_ICS_IMU_PERF_CNT1, 0xffffffffffffffff
	.xword	FIRE_DLC_IMU_ICS_IMU_PERF_CNT1, 0xffffffffffffffff
	! Registers 6 - 8
	.xword	FIRE_DLC_MMU_PRFC, 0x000000000000ffff
	.xword	FIRE_DLC_MMU_PRFC, 0x000000000000ffff
	.xword	FIRE_DLC_MMU_PRF0, 0xffffffffffffffff
	.xword	FIRE_DLC_MMU_PRF0, 0xffffffffffffffff
	.xword	FIRE_DLC_MMU_PRF1, 0xffffffffffffffff
	.xword	FIRE_DLC_MMU_PRF1, 0xffffffffffffffff
	! Registers 9 - 12
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRFC, 0x000000000003ffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRFC, 0x000000000003ffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRF0, 0xffffffffffffffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRF0, 0xffffffffffffffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRF1, 0xffffffffffffffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRF1, 0xffffffffffffffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRF2, 0x00000000ffffffff
	.xword	FIRE_PLC_TLU_CTB_TLR_TLU_PRF2, 0x00000000ffffffff
	! Registers 13 - 15
	.xword	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1_SEL, 0xffffffff
	.xword	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1_SEL, 0xffffffff
	.xword	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1, 0xffffffff
	.xword	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR1_TEST, 0xffffffff
	.xword	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR2, 0xffffffff
	.xword	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LINK_PERF_CNTR2_TEST, 0xffffffff
	SET_SIZE(fire_perf_regs_table)

/*
 * Each register entry is 0x20 bytes
 */
#define	FIRE_REGID2OFFSET(id, offset)	sllx	id, 5, offset
#define	FIRE_PERF_READ_ADR	0
#define	FIRE_PERF_READ_MASK	8
#define	FIRE_PERF_WRITE_ADR	0x10
#define	FIRE_PERF_WRITE_MASK	0x18

/*
 * fire_get_perf_reg
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 perf reg ID (%o1)
 * --
 * ret0 status (%o0)
 * ret1 value (%o1)
 */
	ENTRY_NP(fire_get_perf_reg)
	cmp	%o1, FIRE_NPERFREGS
	bgeu,pn	%xcc, herr_inval
	mov	1, %g3
	sllx	%g3, %o1, %g3
	ldx	[%g1 + FIRE_COOKIE_PERFREGS], %g2
	and	%g2, %g3, %g3
	brz,pn	%g3, herr_inval
	mov	FIRE_COOKIE_JBUS, %g2
	cmp	%g3, FIRE_DLC_IMU_ICS_IMU_PERF_CNTRL_MASK
	movgeu	%xcc, FIRE_COOKIE_PCIE, %g2
	ldx	[%g1 + %g2], %g2

	!! %g1 = Fire cookie pointer
	!! %g2 = Fire base PA
	ROOT_STRUCT(%g5)
	setx	fire_perf_regs_table, %g3, %g4
	ldx	[%g5 + CONFIG_RELOC], %g3
	sub	%g4, %g3, %g4

	!! %g1 = Fire cookie pointer
	!! %g2 = Fire base PA
	!! %g4 = Performance regs table
	FIRE_REGID2OFFSET(%o1, %g3)
	add	%g3, %g4, %g4
	ldx	[%g4 + FIRE_PERF_READ_ADR], %g3
	ldx	[%g4 + FIRE_PERF_READ_MASK], %g4

	!! %g1 = Fire cookie pointer
	!! %g2 = Fire base PA
	!! %g3 = Perf reg offset
	!! %g4 = Perf reg mask
	ldx	[%g2 + %g3], %o1
	and	%o1, %g4, %o1
	HCALL_RET(EOK)
	SET_SIZE(fire_get_perf_reg)

/*
 * fire_set_perf_reg
 *
 * %g1 = Fire Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 perf reg ID (%o1)
 * arg2 value (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(fire_set_perf_reg)
	cmp	%o1, FIRE_NPERFREGS
	bgeu,pn	%xcc, herr_inval
	mov	1, %g3
	sllx	%g3, %o1, %g3
	ldx	[%g1 + FIRE_COOKIE_PERFREGS], %g2
	and	%g2, %g3, %g3
	brz,pn	%g3, herr_inval
	mov	FIRE_COOKIE_JBUS, %g2
	cmp	%g3, FIRE_DLC_IMU_ICS_IMU_PERF_CNTRL_MASK
	movgeu	%xcc, FIRE_COOKIE_PCIE, %g2
	ldx	[%g1 + %g2], %g2

	!! %g1 = Fire cookie pointer
	!! %g2 = Fire base PA
	ROOT_STRUCT(%g5)
	setx	fire_perf_regs_table, %g3, %g4
	ldx	[%g5 + CONFIG_RELOC], %g3
	sub	%g4, %g3, %g4

	!! %g1 = Fire cookie pointer
	!! %g2 = Fire base PA
	!! %g4 = Performance regs table
	FIRE_REGID2OFFSET(%o1, %g3)
	add	%g3, %g4, %g4
	ldx	[%g4 + FIRE_PERF_WRITE_ADR], %g3
	ldx	[%g4 + FIRE_PERF_WRITE_MASK], %g4

	!! %g1 = Fire cookie pointer
	!! %g2 = Fire base PA
	!! %g3 = Perf reg offset
	!! %g4 = Perf reg mask
	and	%o2, %g4, %g5
	stx	%g5, [%g2 + %g3]
	HCALL_RET(EOK)
	SET_SIZE(fire_set_perf_reg)

/*
 * fire_intr_redistribution
 *
 * %g1 - this cpu id
 * %g2 - tgt cpu id
 *
 * Need to invalidate all of the virtual intrs that are
 * mapped to the cpu passed in %g1
 *
 * Need to retarget the 3 HW intrs hv controls that are
 * mapped to the cpu passed in %g1 to cpu in %g2
 */
	ENTRY_NP(fire_intr_redistribution)
	CPU_PUSH(%g7, %g3, %g4, %g5)

	mov	%g1, %g3	! save cpuid
	GUEST_STRUCT(%g4)
	mov	FIRE_A_AID, %g1
	DEVINST2INDEX(%g4, %g1, %g1, %g5, .fire_intr_redis_fail)
	DEVINST2COOKIE(%g4, %g1, %g1, %g5, .fire_intr_redis_fail)

	! %g1 - fire cookie
	! %g3 - this cpu
	HVCALL(_fire_intr_redistribution)

	mov	FIRE_B_AID, %g1
	GUEST_STRUCT(%g4)
	DEVINST2INDEX(%g4, %g1, %g1, %g5, .fire_intr_redis_fail)
	DEVINST2COOKIE(%g4, %g1, %g1, %g5, .fire_intr_redis_fail)

	! %g1 - fire cookie
	! %g3 - this cpu
	HVCALL(_fire_intr_redistribution)

.fire_intr_redis_fail:
	mov	%g3, %g1	! restore cpuid
	CPU_POP(%g7, %g3, %g4, %g5)
	HVRET
	SET_SIZE(fire_intr_redistribution)




/*
 * _fire_intr_redistribution
 *
 * %g1 - Fire cookie
 * %g3 - this cpu
 */
	ENTRY_NP(_fire_intr_redistribution)
	CPU_PUSH(%g7, %g4, %g5, %g6)

	! %g1 - fire cookie ptr
	lduh	[%g1 + FIRE_COOKIE_INOMAX], %g2	! loop counter
	dec	%g2	! INOMAX - 1

._fire_intr_redis_loop:
	cmp	%g2, PCIE_ERR_INO
	be	%xcc, .fire_intr_redis_continue	! fire errors handle separate
	nop

	cmp	%g2, JBC_ERR_INO
	be	%xcc, .fire_intr_redis_continue	! fire errors handle separate
	nop

	ldx	[%g1 + FIRE_COOKIE_INTMAP], %g5
	REGNO2OFFSET(%g2, %g4)
	ldx	[%g5 + %g4], %g4

	! Extract cpuid
	srlx	%g4, JPID_SHIFT, %g7
	and	%g7, JPID_MASK, %g7

	! %g7 - jpid
	! compare with this cpu, if match,  set to idle
	cmp	%g3, %g7
	bne,pt	%xcc, .fire_intr_redis_continue
	nop

	! save cpuid since call clobbers it
	CPU_PUSH(%g3, %g4, %g5, %g6)
	CPU_PUSH(%g2, %g4, %g5, %g6)
	mov	INTR_DISABLED, %g3	! Invalid

	! %g1 = Fire Cookie
	! %g2 = device ino
	! %g3 = Idle
	HVCALL(_fire_intr_setvalid)

	CPU_POP(%g2, %g4, %g5, %g6)
	CPU_POP(%g3, %g4, %g5, %g6)

.fire_intr_redis_continue:
	deccc	%g2
	bgeu,pt	%xcc, ._fire_intr_redis_loop
	nop

.fire_redis_done:

	CPU_POP(%g7, %g4, %g5, %g6)
	HVRET
	SET_SIZE(_fire_intr_redistribution)


/*
 * FIRE_MSIQ_UNCONFIGURE
 *
 * fire     - (preserved) Fire Cookie Pointer
 * msieq_id - (preserved) MSI EQ id
 *
 */
#define	FIRE_MSIQ_UNCONFIGURE(fire, msieq_id, scr1, scr2, scr3, scr4)	\
	.pushlocals							;\
	cmp	msieq_id, FIRE_NEQS					;\
	bgeu,pn	%xcc, 0f						;\
	MSIEQNUM2MSIEQ(fire, msieq_id, scr3, scr2, scr1)		;\
	REGNO2OFFSET(msieq_id, scr4)					;\
	ldx	[fire + FIRE_COOKIE_EQHEAD], scr1			;\
	ldx	[fire + FIRE_COOKIE_EQTAIL], scr2			;\
	stx	%g0, [scr1 + scr4]					;\
	stx	%g0, [scr2 + scr4]					;\
	stx	%g0, [scr3 + FIRE_MSIEQ_GUEST]				;\
0:									;\
	.poplocals


/*
 * FIRE_MSIQ_INVALIDATE
 *
 * fire     - (preserved) Fire Cookie Pointer
 * msieq_id - (preserved) MSI EQ id
 *
 */
#define	FIRE_MSIQ_INVALIDATE(fire, msieq_id, scr1, scr2, scr3, scr4)	\
	.pushlocals							;\
	cmp	msieq_id, FIRE_NEQS					;\
	bgeu,pn	%xcc, 0f						;\
	  nop								;\
	ldx	[fire + FIRE_COOKIE_EQCTLCLR], scr1			;\
		/* 44=disable, 47=e2i 57=coverr */			;\
	setx	(1<<44)|(1<<47)|(1<<57), scr3, scr2			;\
	REGNO2OFFSET(msieq_id, scr4)					;\
	stx	scr2, [scr1 + scr4]					;\
0:									;\
	.poplocals


/*
 * FIRE_MSI_INVALIDATE - Invalidate the MSI mappings and then clear
 * the MSI status (mark as "idle")
 *
 * fire    - (preserved) Fire Cookie Pointer
 * msi_num - (preserved) MSI number (%o1)
 *
 */
#define	FIRE_MSI_INVALIDATE(fire, msi_num, scr1, scr2, scr3)	\
	.pushlocals						;\
	cmp	msi_num, FIRE_MSI_MASK				;\
	bgu,pn	%xcc, 0f					;\
	REGNO2OFFSET(msi_num, scr2)				;\
	ldx	[fire + FIRE_COOKIE_MSIMAP], scr1		;\
	ldx	[scr1 + scr2], scr3				;\
		/* clear both bits 62 and 63 in the map reg */	;\
		/* valid and ok to write (pending MSI) bit */	;\
	sllx	scr3, 2, scr3					;\
	srlx	scr3, 2, scr3					;\
	stx	scr3, [scr1 + scr2]				;\
	mov	1, scr3		/* now mark status as "idle" */	;\
	sllx	scr3, FIRE_MSIMR_EQWR_N_SHIFT, scr3		;\
	ldx	[fire + FIRE_COOKIE_MSICLR], scr1		;\
	stx	scr3, [scr1 + scr2]				;\
0:								;\
	.poplocals


/*
 * FIRE_MSI_MSG_INVALIDATE
 *
 * fire       - (preserved) Fire Cookie Pointer
 * msg_offset - (preserved) message offset such as FIRE_CORR_OFF,
 *                          FIRE_NONFATAL_OFF, etc. (reg or contant)
 *
 */
#define	FIRE_MSI_MSG_INVALIDATE(fire, msg_offset, scr1, scr2)	\
	ldx	[fire + FIRE_COOKIE_MSGMAP], scr1		;\
	ldx	[scr1 + msg_offset], scr2			;\
	sllx	scr2, 1, scr2					;\
	srlx	scr2, 1, scr2					;\
	stx	scr2, [scr1 + msg_offset]


#define	FIRE_INVALIDATE_INTX(fire, intx_off, scr1, scr2)	\
	ldx	[fire + FIRE_COOKIE_PCIE], scr1			;\
	set	intx_off, scr2					;\
	add	scr1, scr2, scr1				;\
	set	1, scr2						;\
	stx	scr2, [scr1]



/*
 * fire_leaf_soft_reset
 *
 * %g1 - Fire cookie			(preserved)
 * %g2 - root complex (0=A, 1=B)
 * %g7 - return address
 *
 * clobbers %g2-%g6
 */
	ENTRY_NP(fire_leaf_soft_reset)

	!
	! Put STRAND in protected mode
	!
	STRAND_STRUCT(%g4)
	mov	1, %g5
	set	STRAND_IO_PROT, %g6
	stx	%g5, [%g4 + %g6]
	membar	#Sync

	!
	! Disable errors
	!
	DISABLE_PCIE_RWUC_ERRORS(%g1, %g4, %g5, %g6)
	membar	#Sync

	!! %g1 fire struct
	!! %g2 PCI bus (0=A, 1=B)

	!
	! Destroy the iommu mappings
	!
	FIRE_IOMMU_FLUSH(%g1, %g2, %g4, %g5, %g6)
	membar	#Sync

	!
	! Invalidate any pending legacy (level) interrupts
	! that were previously signalled from switches we just reset
	!

	FIRE_INVALIDATE_INTX(%g1, FIRE_DLC_IMU_RDS_INTX_INT_A_INT_CLR_REG,
		%g2, %g4)
	FIRE_INVALIDATE_INTX(%g1, FIRE_DLC_IMU_RDS_INTX_INT_B_INT_CLR_REG,
		%g2, %g4)
	FIRE_INVALIDATE_INTX(%g1, FIRE_DLC_IMU_RDS_INTX_INT_C_INT_CLR_REG,
		%g2, %g4)
	FIRE_INVALIDATE_INTX(%g1, FIRE_DLC_IMU_RDS_INTX_INT_D_INT_CLR_REG,
		%g2, %g4)

	!
	! invalidate all MSIs
	!
	set	FIRE_MAX_MSIS - 1, %g2
1:	FIRE_MSI_INVALIDATE(%g1, %g2, %g6, %g4, %g5)
	brgz,pt	%g2, 1b
	  dec	%g2
	membar	#Sync

	!
	! invalidate all MSI Messages
	!
	FIRE_MSI_MSG_INVALIDATE(%g1, FIRE_CORR_OFF, %g5, %g4)
	FIRE_MSI_MSG_INVALIDATE(%g1, FIRE_NONFATAL_OFF, %g5, %g4)
	FIRE_MSI_MSG_INVALIDATE(%g1, FIRE_FATAL_OFF, %g5, %g4)
	FIRE_MSI_MSG_INVALIDATE(%g1, FIRE_PME_OFF, %g5, %g4)
	FIRE_MSI_MSG_INVALIDATE(%g1, FIRE_PME_ACK_OFF, %g5, %g4)

	!
	! invalidate all interrupts
	!

	! invalidate inos 63 and 62, special case ones not set with
	! _fire_intr_setvalid
	ldx	[%g1 + FIRE_COOKIE_VIRTUAL_INTMAP], %g2
	add	%g2, PCIE_ERR_MONDO_OFFSET, %g2
	mov	0, %g3			! devid 0
	add	%g3, %g2, %g2
	stb	%g0, [%g1 + %g2]

	ldx	[%g1 + FIRE_COOKIE_VIRTUAL_INTMAP], %g2
	add	%g2, PCIE_ERR_MONDO_OFFSET, %g2
	mov	1, %g3			! devid 1
	add	%g3, %g2, %g2
	stb	%g0, [%g1 + %g2]

	ldx     [%g1 + FIRE_COOKIE_VIRTUAL_INTMAP], %g2
	add	%g2, JBC_ERR_MONDO_OFFSET, %g2
	sth	%g0, [%g1 + %g2]

	CPU_PUSH(%g7, %g4, %g5, %g6)	! _fire_intr_setvalid clobbers all regs
	! Don't invalidate inos 62 & 63 in this loop, 62 and 63 are done above
	set	NFIREDEVINO - 3, %g2
	clr	%g3
1:	HVCALL(_fire_intr_setvalid)	! clobbers %g4-%g6
	brgz,pt	%g2, 1b
	  dec	%g2
	membar	#Sync
	CPU_POP(%g7, %g4, %g5, %g6)	! restore clobbered value

	!
	! invalidate and unconfigure all MSI EQs
	!
	set	FIRE_NEQS - 1, %g2
1:	FIRE_MSIQ_INVALIDATE(%g1, %g2, %g3, %g4, %g5, %g6)
	FIRE_MSIQ_UNCONFIGURE(%g1, %g2, %g3, %g4, %g5, %g6)
	brgz,pt	%g2, 1b
	  dec	%g2
	membar	#Sync

	!
	! re-enable errors
	!
	ENABLE_PCIE_RWUC_ERRORS(%g1, %g2, %g4, %g5)
	membar	#Sync

	!
	! Bring STRAND out of protected mode
	!
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g2
	stx	%g0, [%g4 + %g2]
	set	STRAND_IO_ERROR, %g2
	stx	%g0, [%g4 + %g2]

	HVRET
	SET_SIZE(fire_leaf_soft_reset)


        /*
         * Wrapper around fire_leaf_soft_reset so it can be called from C
         * SPARC ABI requries only that g2,g3,g4 are preserved across
         * function calls.
         * %o0 = fire cookie
         * %o1 = root complex (0=A, 1=B), bus number
         *
         * void c_fire_leaf_soft_reset(struct fire_cookie *, uint64 root)
         */

        ENTRY(c_fire_leaf_soft_reset)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

        mov     %o0, %g1
        mov     %o1, %g2

	!! %g1 - fire cookie
	!! %g2 - root complex (0=A, 1=B)
	HVCALL(fire_leaf_soft_reset)

        STRAND_POP(%g4, %g6)
        STRAND_POP(%g3, %g6)
        STRAND_POP(%g2, %g6)

        retl
          nop
        SET_SIZE(c_fire_leaf_soft_reset)

#ifdef DEBUG
! When DEBUG is defined hcall.s versions
! of these are labels are too far away
herr_nocpu:	HCALL_RET(ENOCPU)
herr_nomap:	HCALL_RET(ENOMAP)
herr_inval:	HCALL_RET(EINVAL)
herr_badalign:	HCALL_RET(EBADALIGN)
#endif


	/*
	 * This macro brings a given fire leaf's link up
	 *
	 * Inputs:
	 *
	 *    fire - (preserved) pointer to FIRE_COOKIE
	 *
	 * Bring up a fire link. Returns false on failure.
	 */
	ENTRY(fire_link_up)
		/* get the base addr of RC control regs */
	ldx	[ %o0 + FIRE_COOKIE_PCIE ], %o1

		/* Clear Other Event Status Register LinkDown bit */
	setx	FIRE_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, %o3, %o2
	ldx	[ %o1 + %o2 ], %o3
	stx	%o3, [ %o1 + %o2]

		/* The drain bit is cleared via W1C */
	setx	FIRE_PLC_TLU_CTB_TLR_TLU_STS, %o3, %o2
	ldx	[ %o1 + %o2 ], %o3
	stx	%o3, [ %o1 + %o2]

		/* bit 8 of the TLU Control Register is */
		/* cleared to initiate link training    */
	setx	FIRE_PLC_TLU_CTB_TLR_TLU_CTL, %o3, %o2
	ldx	[ %o1 + %o2 ], %o3
	andn	%o3, 1<<8, %o3
	stx	%o3, [ %o1 + %o2]

	CPU_MSEC_DELAY(200, %o1, %o2, %o3)

	ldx	[ %o0 + FIRE_COOKIE_CFG ], %o1
	setx	UPST_CFG_BASE, %o3, %o2
	lduwa	[%o1 + %o2]ASI_P_LE, %o3	/* 16 reads are    */
	lduwa	[%o1 + %o2]ASI_P_LE, %o3	/* needed to flush */
	lduwa	[%o1 + %o2]ASI_P_LE, %o3	/* the fifo after  */
	lduwa	[%o1 + %o2]ASI_P_LE, %o3	/* toggling the    */
	lduwa	[%o1 + %o2]ASI_P_LE, %o3	/* link.           */
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3
	lduwa	[%o1 + %o2]ASI_P_LE, %o3

	retl
	  mov	1, %o0
	SET_SIZE(fire_link_up)




	/*
	 * This function brings a given fire leaf's link down
	 * Inputs:
	 *
	 *    fire - (preserved) pointer to FIRE_COOKIE
	 * Returns:
	 * 	false (0) on failure.
	 */
	ENTRY(fire_link_down)
		/* get the base addr of RC control regs */
	ldx	[ %o0 + FIRE_COOKIE_PCIE ], %o1
		/* And now the actual reset code... */
		/* Remain in detect quiesce */
	setx	FIRE_PLC_TLU_CTB_TLR_TLU_CTL, %o4, %o2
	ldx	[ %o1 + %o2 ], %o3
	or	%o3, 1<<8, %o3
	stx	%o3, [ %o1 + %o2]
		/* Disable link */
	setx	FIRE_PLC_TLU_CTB_LPR_PCIE_LPU_LTSSM_CNTL, %o4, %o2
	setx	0x80000401, %o4, %o3
	stx	%o3, [ %o1 + %o2]

		/* Wait for link to go down */
	setx	FIRE_PLC_TLU_CTB_TLR_TLU_STS, %o4, %o2
1:
	ldx	[ %o1 + %o2 ], %o3
	andcc	%o3, 0x7, %o3
	cmp	%o3, 0x1
	bne,pt	%xcc, 1b
	  nop

	retl
	  mov	1, %o0
	SET_SIZE(fire_link_down)




	/*
	 * Check and see if a fire link is up. Returns true on
	 * success, false on failure.
	 */
	ENTRY(is_fire_port_link_up)
	ldx	[ %o0 + FIRE_COOKIE_PCIE ], %o1
	setx	FIRE_PLC_TLU_CTB_TLR_TLU_STS, %o3, %o2
	ldx	[ %o1 + %o2 ], %o3
	and	%o3, 0x7, %o3
	cmp	%o3, 0x4
	mov	%g0, %o0
	move	%xcc, 1, %o0
	retl
	  nop
	SET_SIZE(is_fire_port_link_up)

#endif /* CONFIG_FIRE */
