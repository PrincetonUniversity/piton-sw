/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vpci_piu.s
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

	.ident	"@(#)vpci_piu.s	1.7	07/08/15 SMI"

	.file	"vpci_piu.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <mmu.h>

#include <guest.h>
#include <offsets.h>
#include <debug.h>
#include <vcpu.h>
#include <util.h>
#include <abort.h>
#include <vpiu_errs.h>
#include <intr.h>
#include <fpga.h>

#if defined(CONFIG_PIU)

#ifdef VPCI_DEBUG

#define	_VPCI_PRINTX(r)		PRINTX(r)
#define	_VPCI_PRINT(s)		PRINT(s)
#else
#define	_VPCI_PRINTX(r)
#define	_VPCI_PRINT(s)
#endif

#define	_VPCI_PRINT1(s, r1)		_VPCI_PRINT(s); _VPCI_PRINTX(r1)
#define	_VPCI_PRINT2(s, r1, r2)		_VPCI_PRINT1(s, r1);		\
		_VPCI_PRINT1(" ", r2)
#define	_VPCI_PRINT3(s, r1, r2, r3)	_VPCI_PRINT2(s, r1, r2);	\
		_VPCI_PRINT1(" ", r3)
#define	_VPCI_PRINT4(s, r1, r2, r3, r4)	_VPCI_PRINT3(s, r1, r2, r3);	\
		_VPCI_PRINT1(" ", r4)
#define	VPCI_PRINT1(s, r1)		_VPCI_PRINT1(s, r1);		\
		_VPCI_PRINT("\r\n")
#define	VPCI_PRINT2(s, r1, r2)		_VPCI_PRINT1(s, r1);		\
		VPCI_PRINT1(" ", r2)
#define	VPCI_PRINT3(s, r1, r2, r3)	_VPCI_PRINT2(s, r1, r2);	\
		VPCI_PRINT1(" ", r3)
#define	VPCI_PRINT4(s, r1, r2, r3, r4)	_VPCI_PRINT3(s, r1, r2, r3)	\
		VPCI_PRINT1(" ", r4)

#define	REGNO2OFFSET(no, off)		sllx	no, 3, off
#define	PCIDEV2PIUDEV(pci, piu)	sllx	pci, 4, piu

#if PIU_MSIEQ_SIZE != 0x28
#error "PIU_MSIEQ_SIZE changed, breaks the shifts below"
#endif
#define	MSIEQNUM2MSIEQ(piucookie, num, msieq, scr1, scr2) \
	ldx	[piucookie + PIU_COOKIE_MSICOOKIE], msieq ;\
	sllx	num, 5, scr1				;\
	sllx	num, 3, scr2				;\
	add	scr1, scr2, scr1			;\
	inc	PIU_MSI_COOKIE_EQ, scr1			;\
	add	msieq, scr1, msieq

#define	IOTSB0_PIU_COOKIE	PIU_COOKIE_IOTSB0
#define	IOTSB1_PIU_COOKIE	PIU_COOKIE_IOTSB1
#define	SETUP_IOTSB_BASE(rc_cookie, pcie, t, scr1, scr2, scr3)	\
	ldx	[rc_cookie + t/**/_PIU_COOKIE], scr1		;\
	srlx	scr1, t/**/_PAGESHIFT, scr1			;\
	sllx	scr1, IOTSB_BASE_PA_SHIFT, scr1			;\
	set	IOTSBDESC_REG(t), scr2				;\
	ldx	[pcie + scr2], scr3				;\
	or	scr3, scr1, scr3				;\
	stx	scr3, [pcie + scr2]

	! Ordered to minimize wasted space
	BSS_GLOBAL(piu_0_equeue, (PIU_NEQS * PIU_EQSIZE), 512 KB)
	BSS_GLOBAL(piu_iotsb0, IOTSB0_SIZE, 8 KB)
	BSS_GLOBAL(piu_iotsb1, IOTSB1_SIZE, 8 KB)
	BSS_GLOBAL(piu_virtual_intmap, 0x10, 0x10)

	DATA_GLOBAL(piu_ncu_init_table)
	.xword	PIU_BAR(CFGIO(0)), PIU_PCIE_A_IOCON_OFFSET_BASE
	.xword	PIU_BAR(MEM32(0)), PIU_PCIE_A_MEM32_OFFSET_BASE
	.xword	PIU_BAR(MEM64(0)), PIU_PCIE_A_MEM64_OFFSET_BASE
	.xword	PIU_SIZE(MEM32_SIZE), PIU_PCIE_A_MEM32_OFFSET_MASK
	.xword	PIU_BAR_V(MEM32(0)), PIU_PCIE_A_MEM32_OFFSET_BASE

	.xword	PIU_SIZE(CFGIO_SIZE), PIU_PCIE_A_IOCON_OFFSET_MASK
	.xword	PIU_BAR_V(CFGIO(0)), PIU_PCIE_A_IOCON_OFFSET_BASE

	.xword	PIU_SIZE(MEM64_SIZE), PIU_PCIE_A_MEM64_OFFSET_MASK
	.xword	PIU_BAR_V(MEM64(0)), PIU_PCIE_A_MEM64_OFFSET_BASE
	.xword	-1,-1 /* End of Table */
	SET_SIZE(piu_ncu_init_table)

	DATA_GLOBAL(piu_leaf_init_table)
	.xword	0xffffffffffffffff, PIU_DLC_IMU_ICS_IMU_ERROR_LOG_EN_REG
	.xword	0xffffffffffffffff, PIU_DLC_IMU_ICS_IMU_INT_EN_REG
	.xword	0xffffffffffffffff, PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS
	.xword	0x0000000000000010, PIU_DLC_ILU_CIB_ILU_LOG_EN
	.xword	0x0000001000000010, PIU_DLC_ILU_CIB_ILU_INT_EN
	.xword	0x00000000da130001, PIU_PLC_TLU_CTB_TLR_TLU_CTL
	/* DW for N2 set fast link mode, reset assert */
	.xword  0x00000000001b0808, PIU_PLC_TLU_CTB_TLR_CSR_A_LINK_CTL_ADDR
	.xword	0xffffffffffffffff, PIU_PLC_TLU_CTB_TLR_OE_LOG
	.xword	0xffffffffffffffff, PIU_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS
	.xword	0xffffffffffffffff, PCI_E_PEU_OTHER_INT_ENB_ADDR
	.xword	0x0000000000000040, PIU_PLC_TLU_CTB_TLR_DEV_CTL
	.xword	0x0000000000000040, PIU_PLC_TLU_CTB_TLR_LNK_CTL
	.xword	0xffffffffffffffff, PIU_PLC_TLU_CTB_TLR_UE_LOG
	.xword	0xffffffffffffffff, PIU_PLC_TLU_CTB_TLR_UE_INT_EN
	.xword	0xffffffffffffffff, PIU_PLC_TLU_CTB_TLR_CE_LOG
	.xword	0xffffffffffffffff, PIU_PLC_TLU_CTB_TLR_CE_INT_EN
	.xword	0xffffffffffffffff, PIU_DLC_IMU_ICS_DMC_INTERRUPT_MASK_REG
	.xword	0x0000000000000000, PIU_DLC_CRU_DMC_DBG_SEL_A_REG
	.xword	0x0000000000000000, PIU_DLC_CRU_DMC_DBG_SEL_B_REG
	.xword	0xffffffffffffffff, PIU_DLC_ILU_CIB_PEC_INT_EN
	.xword	0xffffffffffffffff, PIU_DLC_MMU_INV
	.xword	0x0000000000000000, PIU_DLC_MMU_TSB
#ifndef DEBUG_LEGION
	.xword	0x0000000000000000, PIU_PLC_TLU_CTB_TLR_CSR_A_DEV_CTL_ADDR ! XXX is this right?
#endif

	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(0)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(1)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(2)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(3)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(4)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(5)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(6)
	.xword	DEV2IOTSB(IOTSB0), DEV2IOTSB_REG(7)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(8)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(9)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(10)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(11)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(12)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(13)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(14)
	.xword	DEV2IOTSB(IOTSB1), DEV2IOTSB_REG(15)

	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(0)	/* 0 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(1)	/* 1 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(2)	/* 2 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(3)	/* 3 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(4)	/* 4 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(5)	/* 5 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(6)	/* 6 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(7)	/* 7 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(8)	/* 8 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(9)	/* 9 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(10)	/* 10 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(11)	/* 11 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(12)	/* 12 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(13)	/* 13 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(14)	/* 14 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(15)	/* 15 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(16)	/* 16 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(17)	/* 17 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(18)	/* 18 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(19)	/* 19 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(20)	/* 20 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(21)	/* 21 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(22)	/* 22 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(23)	/* 23 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(24)	/* 24 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(25)	/* 25 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(26)	/* 26 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(27)	/* 27 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(28)	/* 28 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(29)	/* 29 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(30)	/* 30 */
	.xword	IOTSBDESC(UNUSED), IOTSBDESC_REG(31)	/* 31 */

	.xword	IOTSBDESC(IOTSB0), IOTSBDESC_REG(IOTSB0)
	.xword	IOTSBDESC(IOTSB1), IOTSBDESC_REG(IOTSB1)

	.xword	0x0000000000000000, PIU_DLC_MMU_TSB
	.xword	0x0000000000000000, PIU_DLC_MMU_CTL
	.xword	0xffffffffffffffff, PIU_DLC_MMU_INT_EN

	.xword	0x0000000002000000, PIU_DLC_CRU_CSR_A_DMC_PCIE_CFG_ADDR

	/* MSI ranges */

	.xword	0x000000007fff0000, PIU_DLC_IMU_ICS_MSI_32_ADDR_REG
	.xword	0x00000003ffff0000, PIU_DLC_IMU_ICS_MSI_64_ADDR_REG
	.xword	-1, -1 /* End of Table */
	SET_SIZE(piu_leaf_init_table)

/*
 * piu_init
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests	(not used)
 *	%i2 - base of cpus	(not used)
 *	%g7 - return address
 */
	ENTRY_NP(piu_init)

	setx	piu_ncu_init_table, %g5, %g3
	setx	piu_dev, %g5, %g1
	ldx	[%i0 + CONFIG_RELOC], %o0
	sub	%g3, %o0, %g3
	sub	%g1, %o0, %g1
	! %g1 = piup
	! %g3 = piu_ncu_init_table base
	! %g7 = return PC
	ldx	[%g1 + PIU_COOKIE_NCU], %g4

	brz,pn	%g4, 3f
	nop

	! %g1 = piup
	! %g3 = piu_init_table base
	! %g4 = NCU Base PA
	! %g7 = return PC
1:
	ldx	[%g3 + 8], %g5	! Offset
	add	%g5, 1, %g6
	brz,pn	%g6, 3f
	ldx	[%g3 + 0], %g6	! Data
	add	%g3, 16, %g3
	ba	1b
	stx	%g6, [%g4 + %g5]
3:
	setx	piu_leaf_init_table, %g5, %g3
	ldx	[%i0 + CONFIG_RELOC], %o0
	sub	%g3, %o0, %g3

	ldx	[%g1 + PIU_COOKIE_PCIE], %g4

	!brz,pn	%g4, 3f
	!nop
1:
	ldx	[%g3 + 8], %g6	! Offset
	add	%g6, 1, %g2
	brz,pn	%g2, 2f
	ldx	[%g3 + 0], %g2	! Data
	add	%g3, 16, %g3
	ba	1b
	stx	%g2, [%g4 + %g6]
2:
	! Setup Interrupt Mondo Data 0 register
	set	PCI_E_INT_MONDO_DATA_0_ADDR, %g6
	stx	%g0, [%g4 + %g6]

	! Setup Interrupt Mondo Data 1 register
	set	PCI_E_INT_MONDO_DATA_1_ADDR, %g6
	set	PIU_AID, %g2
	sllx	%g2, PIU_DEVINO_SHIFT, %g2
!	ldx	[%g1 + PIU_COOKIE_HANDLE], %g2
	stx	%g2, [%g4 + %g6]

	! Setup interrupt mappings
	! mondo 62 leafs A and B
	! mondo 63 only leaf A
	VCPU_STRUCT(%g4)
	VCPU2STRAND_STRUCT(%g4, %g2)
        ldub    [%g2 + STRAND_ID], %g2

	mov %g0, %g5
	! Add CPU number
	sllx	%g2, JPID_SHIFT, %g6
	or	%g5, %g6, %g5

	! Select a PIU Interrupt Controller
	and	%g2, (NPIUINTRCONTROLLERS - 1), %g2
	add	%g2, PIU_INTR_CNTLR_SHIFT, %g2
	mov	1, %g6
	sllx	%g6, %g2, %g2
	or	%g5, %g2, %g5

	! Set MDO MODE bit
	mov	1, %g6
	sllx	%g6, PIU_INTMR_MDO_MODE_SHIFT, %g6
	or	%g5, %g6, %g5

	! Set Valid bit
	mov	1, %g6
	sllx	%g6, PIU_INTMR_V_SHIFT, %g6
	or	%g5, %g6, %g5

	mov	DMU_INTERNAL_INT, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g1 + PIU_COOKIE_INTMAP], %g3
	stx	%g5, [%g3 + %g4]	! leaf A, mondo 62
	ldx	[%g1 + PIU_COOKIE_INTCLR], %g2
	stx	%g0, [%g2 + %g4]

	mov	PEU_INTERNAL_INT, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g1 + PIU_COOKIE_INTMAP], %g3
	stx	%g5, [%g3 + %g4]	! leaf A, mondo 63
	ldx	[%g1 + PIU_COOKIE_INTCLR], %g2
	stx	%g0, [%g2 + %g4]

	! %g1 = PIU COOKIE
	! %g3 = PIU PCIE Base
	set	PIU_DLC_MMU_CTL, %g5
	! PIU Leaf A PCIE reg base
	ldx	[%g1 + PIU_COOKIE_PCIE], %g3
	set	PIU_MMU_CSR_VALUE, %g2
	! Leaf A MMU_CTRL reg
	stx	%g2, [%g3 + %g5]

	! %g1 = PIU COOKIE
	! %g3 = PIU PCIE Base
	set	PIU_DLC_MMU_TSB, %g6
	ldx	[%g1 + PIU_COOKIE_IOTSB0], %g2
	or	%g2, IOTSB0_TSB_SIZE, %g2
	! Leaf A MMU_TSB_CTRL reg
#if (PIU_MMU_CSR_VALUE & PIU_MMU_CSR_SUN4V_EN == 0)
	stx	%g2, [%g3 + %g6]
#else
	stx	%g0, [%g3 + %g6]
#endif

	! %g1 = PIU COOKIE
	! %g3 = PIU PCIE Base
	SETUP_IOTSB_BASE(%g1, %g3, IOTSB0, %g2, %g4, %g5)
	SETUP_IOTSB_BASE(%g1, %g3, IOTSB1, %g2, %g4, %g5)

	! %g1 = PIU COOKIE
	! %g3 = PIU PCIE Base
	ldx	[%g1 + PIU_COOKIE_MSIEQBASE], %g2
	setx	MSI_EQ_BASE_BYPASS_ADDR, %g7, %g6
	or	%g2, %g6, %g2
	set	PIU_DLC_IMU_EQS_EQ_BASE_ADDRESS, %g6
	! Leaf A  EQ Base Address
	stx	%g2, [%g3 + %g6]

3:
	HVRET
	SET_SIZE(piu_init)


/*
 * piu_devino2vino
 *
 * %g1 Piu Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 dev ino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 virtual INO (%o1)
 */
	ENTRY_NP(piu_devino2vino)
	! %g1 pointer to PIU_COOKIE
	ldx	[%g1 + PIU_COOKIE_HANDLE], %g2
	cmp	%o0, %g2
	bne	herr_inval
	lduh	[%g1 + PIU_COOKIE_INOMAX], %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	lduh	[%g1 + PIU_COOKIE_VINO], %g4
	or	%o1, %g4, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_devino2vino)

/*
 * piu_intr_getvalid
 *
 * %g1 PIU Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(piu_intr_getvalid)
	! %g1 pointer to PIU_COOKIE
	VPCI_PRINT1("HV: intr_getvalid ", %o0)
	ldx	[%g1 + PIU_COOKIE_INTMAP], %g2
	and	%o0, PIU_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g2 + %g4], %g5
	sra	%g5, 0, %g5
	mov	INTR_DISABLED, %o1
	movrlz	%g5, INTR_ENABLED, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_intr_getvalid)

/*
 * _piu_intr_setvalid
 *
 * %g1 PIU Cookie Pointer
 * %g2 INO
 * %g3 intr valid state
 * --
 *
 * ret0 PIU Cookie (%g1)
 * ret1 INO (%g2)
 */
	ENTRY_NP(_piu_intr_setvalid)
	! %g1 = pointer to PIU_COOKIE
	ldx	[%g1 + PIU_COOKIE_INTMAP], %g6
	and	%g2, PIU_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	add	%g4, %g6, %g4
	ldx	[%g4], %g5
	mov	1, %g6
	sllx	%g6, PIU_INTMR_V_SHIFT, %g6
	andn	%g5, %g6, %g5
	sllx	%g3, PIU_INTMR_V_SHIFT, %g6
	or	%g5, %g6, %g5
	stx	%g5, [%g4]

	HVRET
	SET_SIZE(_piu_intr_setvalid)

/*
 * piu_intr_setvalid
 *
 * %g1 PIU Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_intr_setvalid)
	VPCI_PRINT2("HV: intr_setvalid ", %o0, %o1)
	! %g1 = pointer to PIU_COOKIE
	mov	%o0, %g2
	mov	%o1, %g3
	HVCALL(_piu_intr_setvalid)

	HCALL_RET(EOK)
	SET_SIZE(piu_intr_setvalid)

/*
 * piu_intr_getstate
 *
 * %g1 PIU Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 (%o1) 1: Pending / 0: Idle
 */
	ENTRY_NP(piu_intr_getstate)
	VPCI_PRINT1("HV: intr_getstate ", %o0)
	! %g1 pointer to PIU_COOKIE
	ldx	[%g1 + PIU_COOKIE_INTCLR], %g2
	and	%o0, PIU_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g2 + %g4], %g3
	sub	%g3, PIU_INTR_RECEIVED, %g4
	movrz	%g4, INTR_DELIVERED, %o1
	movrnz	%g4, INTR_RECEIVED, %o1
	movrz	%g3, INTR_IDLE, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_intr_getstate)

/*
 * piu_intr_setstate
 *
 * %g1 PIU Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 (%o1) 1: Pending / 0: Idle  XXX
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_intr_setstate)
	VPCI_PRINT2("HV: intr_setstate ", %o0, %o1)
	! %g1 pointer to PIU_COOKIE
	cmp	%o1, INTR_DELIVERED
	bgu,pn	%xcc, herr_inval
	mov	%o0, %g2
	mov	%o1, %g3
	HVCALL(_piu_intr_setstate)

	HCALL_RET(EOK)
	SET_SIZE(piu_intr_setstate)

/*
 * %g1 = PIU Cookie
 * %g2 = device ino
 * %g3 = Pending/Idle
 * --
 * %g1 = PIU Cookie
 * %g2 = device ino
 */
	ENTRY_NP(_piu_intr_setstate)
	ldx	[%g1 + PIU_COOKIE_INTCLR], %g5
	and	%g2, PIU_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	movrz	%g3, PIU_INTR_IDLE, %g3
	movrnz	%g3, PIU_INTR_RECEIVED, %g3
	stx	%g3, [%g5 + %g4]

	HVRET
	SET_SIZE(_piu_intr_setstate)

/*
 * piu_intr_gettarget
 *
 * %g1 PIU Cookie Pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(piu_intr_gettarget)
	VPCI_PRINT1("HV: intr_gettarget ", %o0)
	! %g1 pointer to PIU_COOKIE

	mov	%o0, %g2
	HVCALL(_piu_intr_gettarget)

	! get the virtual cpuid
	PID2VCPUP(%g3, %g4, %g5, %g6)
	ldub	[%g4 + CPU_VID], %o1

	HCALL_RET(EOK)
	SET_SIZE(piu_intr_gettarget)

/*
 * %g1 = PIU cookie
 * %g2 = device ino
 * --
 * %g1 = PIU cookie
 * %g2 = device ino
 * %g3 = phys cpuid
 */
	ENTRY_NP(_piu_intr_gettarget)
	ldx	[%g1 + PIU_COOKIE_INTMAP], %g3
	and	%g2, PIU_DEVINO_MASK, %g4
	REGNO2OFFSET(%g4, %g4)
	ldx	[%g3 + %g4], %g3
	srlx	%g3, JPID_SHIFT, %g3
	and	%g3, JPID_MASK, %g4
	STRAND_STRUCT(%g3)
	STRAND2CONFIG_STRUCT(%g3, %g3)
	ldx	[%g3 + CONFIG_STRANDS], %g3
	set	STRAND_SIZE, %g5
	mulx	%g4, %g5, %g5
	add	%g3, %g5, %g3
	ldub	[%g3 + STRAND_ID], %g3

	HVRET
	SET_SIZE(_piu_intr_gettarget)

/*
 * piu_intr_settarget
 *
 * %g1 PIU Cookie Pointer
 * arg0 Virtual INO (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_intr_settarget)
	VPCI_PRINT2("HV: intr_settarget ", %o0, %o1)
	! %g1 pointer to PIU_COOKIE
	GUEST_STRUCT(%g3)
	VCPUID2CPUP(%g3, %o1, %g4, herr_nocpu, %g5)

	IS_CPU_IN_ERROR(%g4, %g5)
	be,pn	%xcc, herr_cpuerror
	nop

	VCPU2STRAND_STRUCT(%g4, %g3)
	ldub	[%g3 + STRAND_ID], %g3
	and	%o0, PIU_DEVINO_MASK, %g2

	HVCALL(_piu_intr_settarget)

	HCALL_RET(EOK)
	SET_SIZE(piu_intr_settarget)

/*
 * %g1 = PIU cookie
 * %g2 = device ino
 * %g3 = Physical CPU number
 * --
 * %g1 = PIU cookie
 * %g2 = device ino
 */

	ENTRY_NP(_piu_intr_settarget)
	ldx	[%g1 + PIU_COOKIE_INTMAP], %g4
	REGNO2OFFSET(%g2, %g6)
	add	%g4, %g6, %g4
	ldx	[%g4], %g5

	! %g2 INO offset
	! %g3 Physical CPU number
	! %g4 INTMAP base
	! %g5 INTMAP reg value

	! Add CPU number
	mov	JPID_MASK, %g6
	sllx	%g6, JPID_SHIFT, %g6
	andn	%g5, %g6, %g5
	sllx	%g3, JPID_SHIFT, %g6
	or	%g5, %g6, %g5

	! Clear Interrupt Controller bits
	andn	%g5, (PIU_INTR_CNTLR_MASK << PIU_INTR_CNTLR_SHIFT), %g5

	! Select a PIU Interrupt Controller
	and	%g3, (NPIUINTRCONTROLLERS - 1), %g3
	add	%g3, PIU_INTR_CNTLR_SHIFT, %g3
	mov	1, %g6
	sllx	%g6, %g3, %g3
	or	%g5, %g3, %g5

	! Set MDO MODE bit
	mov	1, %g6
	sllx	%g6, PIU_INTMR_MDO_MODE_SHIFT, %g6
	or	%g5, %g6, %g5

	stx	%g5, [%g4]
	HVRET
	SET_SIZE(_piu_intr_settarget)

/*
 * piu_iommu_map
 *
 * %g1 PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * arg3 tte attributes (%o3)
 * arg4 io_page_list_p (%o4)
 * --
 * ret0 status (%o0)
 * ret1 #ttes mapped (%o1)
 */
	ENTRY_NP(_piu_iommu_map)
	VPCI_PRINT2("HV: iommu_map ", %o1, %o2)
	!! %g1 pointer to PIU_COOKIE
	! Check io_page_list_p alignment
	! and make sure it is 8 byte aligned
	btst	SZ_LONG - 1, %o4
	bnz,pn	%xcc, herr_badalign
	ldx	[%g1 + PIU_COOKIE_IOTSB0], %g5
	sethi	%hi(IOTSB0_INDEX_MASK), %g3
	or	%g3, %lo(IOTSB0_INDEX_MASK), %g3
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

	ldx	[%g1 + PIU_COOKIE_MMUFLUSH], %g1
	mov	1, %g7
	sllx	%g7, PIU_IOTTE_V_SHIFT, %g7
	or	%g7, %o3, %o3

	set	IOTSB0_PAGESIZE, %g4

	!! %g1 = PIU MMU Flush Reg
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

	!! %g1 = PIU NCU Reg Block Base
	!! %g2 = Guest
	!! %g4 = IOTSB pagesize
	!! %g5 = IOTSB base
	!! %g6 = PA of pagelist
	!! %o1 = TTE index
	!! %o2 = #ttes to map
	!! %o3 = TTE Attributes + Valid Bit

.piu_iommu_map_loop:
	ldx	[%g6], %g3
	srlx	%g3, IOTSB0_PAGESHIFT, %o0
	sllx	%o0, IOTSB0_PAGESHIFT, %o0

	cmp	%g3, %o0
	bne,pn	%xcc, .piu_badalign
	nop

	RA2PA_RANGE_CONV(%g2, %o0, %g4, .piu_noraddr, %g7, %g3)
	mov	%g3, %o0
	!! RA -> PA (%o0)

	or	%o0, %o3, %o0
	stx	%o0, [%g5]
	and	%g5, (1 << 6) - 1, %o0

	stx	%g5, [%g1]		! IOMMU flush

	add	%g5, IOTTE_SIZE, %g5	! *IOTSB++
	add	%g6, IOTTE_SIZE, %g6	! *PAGELIST++
	sub	%o2, 1, %o2
	brgz,pt	%o2, .piu_iommu_map_loop
	add	%o1, 1, %o1

	mov	0, %o2
	HCALL_RET(EOK)

.piu_noraddr:
	brz,pn	%o1, herr_noraddr
	mov	0, %o2
	HCALL_RET(EOK)

.piu_badalign:
	brz,pn	%o1, herr_badalign
	mov	0, %o2
	HCALL_RET(EOK)
	SET_SIZE(_piu_iommu_map)
/*
 * piu_iommu_map
 *
 * %g1 Piu Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * arg3 tte attributes (%o3)
 * arg4 io_page_list_p (%o4)
 * --
 * ret0 status (%o0)
 * ret1 #ttes mapped (%o1)
 */
	ENTRY_NP(piu_iommu_map)
	VPCI_PRINT4("HV: iommu_map ", %o1, %o2, %o3, %o4)
	! %g1 pointer to PIU_COOKIE
	and	%o3, HVIO_TTE_ATTR_MASK, %g7
	cmp	%o3, %g7
	bne,pn	%xcc, herr_inval
	nop
	ba,a	_piu_iommu_map
	SET_SIZE(piu_iommu_map)

/*
 * piu_iommu_map_v2
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * arg3 tte attributes (%o3)
 * arg4 io_page_list_p (%o4)
 * --
 * ret0 status (%o0)
 * ret1 #ttes mapped (%o1)
 */
	ENTRY_NP(piu_iommu_map_v2)
	VPCI_PRINT4("HV: iommu_map_v2 ", %o1, %o2, %o3, %o4)
	! %g1 pointer to PIU_COOKIE
	andn	%o3, HVIO_TTE_L, %o3
	set	HVIO_TTE_ATTR_MASK_V2, %g6
	and	%o3, %g6, %g7
	cmp	%o3, %g7
	bne,pn	%xcc, herr_inval
	set	HVIO_TTE_BDF, %g6
	btst	%o3, %g6
	bnz,pt	%xcc, 1f
	and	%o3, (HVIO_TTE_R | HVIO_TTE_W), %g5
	! No BDF given, check for PP bits
	btst	HVIO_TTE_PP, %o3
	bnz,pn	%xcc, herr_inval
	nop
	ba	2f
	nop
1:
	srlx	%o3, HVIO_TTE_BDF_SHIFT, %g6
	sllx	%g6, PIU_TTE_BDF_SHIFT, %g6
	or	%g6, PIU_TTE_DEV_KEY, %g6
	or	%g5, %g6, %g5

	! %g5 = IOTTE
	and	%o3, HVIO_TTE_PP, %g6

	cmp	%g6, HVIO_TTE_PP_ALL
	be,a,pt	%xcc, 2f
	  or	%g5, PIU_TTE_FNM_ALL, %g5

	cmp	%g6, HVIO_TTE_PP_2MSBS
	be,a,pt	%xcc, 2f
	  or	%g5, PIU_TTE_FNM_2MSBS, %g5

	cmp	%g6, HVIO_TTE_PP_MSB
	be,a,pt	%xcc, 2f
	  or	%g5, PIU_TTE_FNM_MSB, %g5

	cmp	%g6, HVIO_TTE_PP_NONE
	be,a,pt	%xcc, 2f
	  or	%g5, PIU_TTE_FNM_NONE, %g5

	! %g5 = IOTTE
2:	ba	_piu_iommu_map
	mov	%g5, %o3
	SET_SIZE(piu_iommu_map_v2)

/*
 * _piu_iommu_getmap
 *
 * %g1 = Piu Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * --
 * ret0 status (%o0)
 * ret1 attributes (%o1)
 * ret2 ra (%o2)
 */
	ENTRY_NP(_piu_iommu_getmap)
	! %g1 pointer to PIU_COOKIE
	ldx	[%g1 + PIU_COOKIE_IOTSB0], %g5
	sethi	%hi(IOTSB0_INDEX_MASK), %g3
	or	%g3, %lo(IOTSB0_INDEX_MASK), %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	sllx	%o1, IOTTE_SHIFT, %g2
	ldx	[%g5 + %g2], %g5
	mov	1, %g4
	sllx	%g4, PIU_IOTTE_V_SHIFT, %g4
	btst	%g4, %g5
	bz,pt %xcc, herr_nomap
	GUEST_STRUCT(%g2)

	! %g1 = PIU Cookie Pointer
	! %g2 = Guest pointer
	! %g5 = IOTTE
	sllx	%g5, (64-JBUS_PA_SHIFT), %g3
	srlx	%g3, (64-JBUS_PA_SHIFT + IOTSB0_PAGESHIFT), %g3
	sllx	%g3, IOTSB0_PAGESHIFT, %g3
	PA2RA_CONV(%g2, %g3, %o2, %g7, %g4)     ! PA -> RA (%o2)

	btst	PIU_TTE_DEV_KEY, %g5	! Device key valid?
	bz	1f
	and	%g5, HVIO_TTE_ATTR_MASK, %o1

	srlx	%g5, PIU_TTE_BDF_SHIFT, %g6
	sllx	%g6, HVIO_TTE_BDF_SHIFT, %g6
	set	HVIO_TTE_BDF, %g3
	and	%g6, %g3, %g3
	or	%o1, %g3, %o1

	and	%g5, PIU_TTE_FNM_MASK, %g6
	cmp	%g6, PIU_TTE_FNM_ALL	! All bits of func number used
	be,a,pt	%xcc, 1f
	  or	%o1, HVIO_TTE_PP_ALL, %o1
	cmp	%g6, PIU_TTE_FNM_2MSBS	! 2 MSBs of func number used
	be,a,pt	%xcc, 1f
	  or	%o1, HVIO_TTE_PP_2MSBS, %o1
	cmp	%g6, PIU_TTE_FNM_MSB	! MSB of func number used
	be,a,pt	%xcc, 1f
	  or	%o1, HVIO_TTE_PP_MSB, %o1
	cmp	%g6, PIU_TTE_FNM_NONE	! No phanthom func numbers
	be,a,pt	%xcc, 1f
	  or	%o1, HVIO_TTE_PP_NONE, %o1
1:
	and	%g5, (1 << PIU_IOTTE_V_SHIFT), %g5
	movrz	%g5, 0, %o1	! Clear the attributes if V=0
#ifdef DEBUG
	brz	%o1, 1f
	nop
	VPCI_PRINT2("HV:iommu_getmap ", %g2, %o1)
1:
#endif
	HCALL_RET(EOK)
	SET_SIZE(_piu_iommu_getmap)

/*
 * piu_iommu_getmap
 *
 * %g1 = Piu Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * --
 * ret0 status (%o0)
 * ret1 attributes (%o1)
 * ret2 ra (%o2)
 */
	ENTRY_NP(piu_iommu_getmap)
	HVCALL(_piu_iommu_getmap)
	and	%o1, HVIO_TTE_ATTR_MASK, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_iommu_getmap)

/*
 * piu_iommu_getmap_v2
 *
 * %g1 PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * --
 * ret0 status (%o0)
 * ret1 attributes (%o1)
 * ret2 ra (%o2)
 */
	ENTRY_NP(piu_iommu_getmap_v2)
	HVCALL(_piu_iommu_getmap)
	HCALL_RET(EOK)
	SET_SIZE(piu_iommu_getmap_v2)

/*
 *
 *
 * %g1 Piu Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 tsbid (%o1)
 * arg2 #ttes (%o2)
 * --
 * ret0 status (%o0)
 * ret1 #ttes demapped (%o1)
 */
	ENTRY_NP(piu_iommu_unmap)
	VPCI_PRINT2("HV: iommu_unmap ", %o1, %o2)
	! %g1 pointer to PIU_COOKIE
	ldx	[%g1 + PIU_COOKIE_IOTSB0], %g5
	sethi	%hi(IOTSB0_INDEX_MASK), %g3
	or	%g3, %lo(IOTSB0_INDEX_MASK), %g3
	cmp	%o1, %g3
	bgu,pn	%xcc, herr_inval
	brlez,pn %o2, herr_inval
	cmp	%o2, IOMMU_MAP_MAX
	movgu	%xcc, IOMMU_MAP_MAX, %o2
	brz,pn	%o2, herr_inval
	add	%o1, %o2, %g2
	inc	%g3			! make sure last mapping succeeds.
	cmp	%g2, %g3
	bgu,pn	%xcc, herr_inval
	sllx	%o1, IOTTE_SHIFT, %g2
	add	%g5, %g2, %g2
	mov	0, %o1

	! %g1 = PIU Cookie Pointer
	! %g2 = IOTSB offset
	! %o1 = #ttes unmapped so far
	! %o2 = #ttes to unmap
	ldx	[%g1 + PIU_COOKIE_MMUFLUSH], %g1
0:
	ldx	[%g2], %g5
	! Clear Valid bit
	mov	1, %g4
	sllx	%g4, PIU_IOTTE_V_SHIFT, %g4
	andn	%g5, %g4, %g4
	! Clear Attributes
	srlx	%g4, IOTSB0_PAGESHIFT, %g4
	sllx	%g4, IOTSB0_PAGESHIFT, %g4
	stx	%g4, [%g2]
	! IOMMU Flush
	stx	%g2, [%g1] !  IOMMU Flush
	add	%g2, IOTTE_SIZE, %g2
	sub	%o2, 1, %o2
	brgz,pt	%o2, 0b
	add	%o1, 1, %o1

	! Flush PIU TSB here XXXX
	HCALL_RET(EOK)
	SET_SIZE(piu_iommu_unmap)

/*
 * piu_iommu_getbypass
 *
 * arg0 dev config pa
 * arg1 ra
 * arg2 io attributes
 * --
 * ret0 status (%o0)
 * ret1 bypass addr (%o1)
 */
	ENTRY_NP(piu_iommu_getbypass)
	! %g1 pointer to PIU_COOKIE

	/*
	 * ldoms hypervisor does not handle this
	 * function correctly yet, so all we can do
	 * is to return ENOSUPP right here and now
	 */
	HCALL_RET(ENOTSUPPORTED)

	andncc	%o2, HVIO_IO_ATTR_MASK, %g0
	bnz,pn	%xcc, herr_inval
	.empty
	GUEST_STRUCT(%g2)

	RA2PA_RANGE_CONV(%g2, %o1, 1, herr_noraddr, %g4, %g3)
        ! %g3 pa of bypass ra

	setx	PIU_IOMMU_BYPASS_BASE, %g5, %g4
	or	%g3, %g4, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_iommu_getbypass)

/*
 * piu_config_get
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

	! %g1 pointer to PIU_COOKIE
	ENTRY_NP(piu_config_get)

	! If leaf is  blacklisted fail access
	lduw    [%g1 + PIU_COOKIE_BLACKLIST], %g3
	brnz,a,pn  %g3, .skip_config_get
	  mov   1, %o1

	ldx	[%g1 + PIU_COOKIE_CFG], %g3
	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	! %g1 = PIU cookie
	! %g3 = CFG base address
	! %g4 = CPU struct

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	PCIDEV2PIUDEV(%o1, %g2)
	or	%g2, %o2, %g2
	sub	%g0, 1, %o2

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

	! %g1 = PIU cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

#if DEBUG
	brnz	%o1, 1f
	nop
	VPCI_PRINT2("HV:config_get ", %g2, %o2)
1:
#endif
.skip_config_get:
	HCALL_RET(EOK)
	SET_SIZE(piu_config_get)

/*
 * piu_config_put
 *
 * arg0 dev config pa (%o0)
 * arg1 PCI device (%o1)
 * arg2 offset (%o2)
 * arg3 size (%o3)
 * arg4 data (%o4)
 * --
 * ret0 status (%o0)
 */
	! %g1 pointer to PIU_COOKIE
	ENTRY_NP(piu_config_put)

	! If leaf is  blacklisted fail access
	lduw    [%g1 + PIU_COOKIE_BLACKLIST], %g3
	brnz,a,pn  %g3, .skip_config_put
	  mov   1, %o1

	ldx	[%g1 + PIU_COOKIE_CFG], %g3
	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	! %g1 = PIU cookie
	! %g3 = CFG base address
	! %g4 = CPU struct

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	PCIDEV2PIUDEV(%o1, %g2)
	or	%g2, %o2, %g2
	cmp	%o3, SZ_WORD
	beq,a,pn %xcc,1f
	  stwa	%o4, [%g3 + %g2]ASI_P_LE
	cmp	%o3, SZ_HWORD
	beq,a,pn %xcc,1f
	  stha	%o4, [%g3 + %g2]ASI_P_LE
	stb	%o4, [%g3 + %g2]

1:
	andn	%g2, PCI_CFG_OFFSET_MASK, %g6
	ldub	[%g3 + %g6], %g0
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 0
	stx	%g0, [%g4 + %g6]
	set	STRAND_IO_ERROR, %g6
	! strand.io_error
	ldx	[%g4 + %g6], %o1
	! strand.io_error = 0
	stx	%g0, [%g4 + %g6]

	! %g1 = PIU cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

#if DEBUG
	brnz	%o1, 1f
	nop
	VPCI_PRINT2("HV:config_put ", %g2, %o4)
1:
#endif
.skip_config_put:
	HCALL_RET(EOK)
	SET_SIZE(piu_config_put)


/*
 * piu_dma_sync
 *
 * %g1 = PIU Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * arg3 direction (%o3) (1: for device 2: for cpu)
 * --
 * ret0 status (%o0)
 * ret1 #bytes synced (%o1)
 */
	ENTRY_NP(piu_dma_sync)
	GUEST_STRUCT(%g2)
	RA2PA_RANGE_CONV_UNK_SIZE(%g2, %o1, %o2, herr_noraddr, %g4, %g3)
	mov	%o2, %o1
	HCALL_RET(EOK);
	SET_SIZE(piu_dma_sync)

/*
 * piu_io_peek
 *
 * %g1 = PIU Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * --
 * ret0 status (%o0)
 * ret1 error? (%o1)
 * ret2 data (%o2)
 */
	ENTRY_NP(piu_io_peek)
	GUEST_STRUCT(%g2)
	! %g2 = Guestp
	! %o1 = ra
	! %o2 = size
	! %g4, %g5 = scratch
	RANGE_CHECK_IO(%g2, %o1, %o2, .piu_io_peek_found, herr_noraddr,
	    %g4, %g6)
.piu_io_peek_found:
	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6
	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	! %g1 = PIU cookie
	! %g4 = strand struct

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

	! %g1 = PIU cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	HCALL_RET(EOK)
	SET_SIZE(piu_io_peek)

/*
 * piu_io_poke
 *
 * %g1 = PIU Cookie Pointer
 * arg0 devhandle (%o0)
 * arg1 r_addr (%o1)
 * arg2 size (%o2)
 * arg3 data (%o3)
 * arg4 PCI device (%o4)
 * --
 * ret0 status (%o0)
 * ret1 error? (%o1)
 */
	ENTRY_NP(piu_io_poke)
	ldx	[%g1 + PIU_COOKIE_CFG], %g3
	GUEST_STRUCT(%g2)
	! %g2 = Guestp
	! %o1 = ra
	! %o2 = size
	! %g4, %g5 = scratch
	RANGE_CHECK_IO(%g2, %o1, %o2, .piu_io_poke_found, herr_noraddr,
	    %g4, %g6)
.piu_io_poke_found:
	PCIDEV2PIUDEV(%o4, %g2)
	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	! %g1 = PIU cookie
	! %g2 = PCI device BDF
	! %g3 = CFG base address
	! %g4 = strand struct

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

	! %g1 = PIU cookie

	ENABLE_PCIE_RWUC_ERRORS(%g1, %g5, %g6, %g7)

	HCALL_RET(EOK)
	SET_SIZE(piu_io_poke)

/*
 * piu_mondo_receive
 *
 * %g1 = PIU Cookie
 * %g2 = Mondo DATA0
 * %g3 = Mondo DATA1
 */
	ENTRY_NP(piu_mondo_receive)
	ba	insert_device_mondo_r
	rd	%pc, %g7
	retry
	SET_SIZE(piu_mondo_receive)

/*
 * piu_msiq_conf
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ base RA (%o2)
 * arg3 #entries (%o3)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msiq_conf)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	sethi	%hi(PIU_EQSIZE-1), %g2
	or	%g2, %lo(PIU_EQSIZE-1), %g2
	and	%o2, %g2, %g2
	brnz	%g2, herr_badalign
	cmp	%o3, PIU_NEQRECORDS
	bne	herr_inval

	/*
	 * Verify RA range/alignment
	 */
	set	PIU_EQREC_SIZE, %g2
	mulx	%g2, %o3, %g4
	GUEST_STRUCT(%g2)
	RA2PA_RANGE_CONV(%g2, %o2, %g0, herr_noraddr, %g7, %g6)
	andcc	%o2, 3, %g0
	bnz	%xcc, herr_badalign
	.empty
	! %g6	PA

	MSIEQNUM2MSIEQ(%g1, %o1, %g4, %g3, %g2)
	ldx	[%g1 + PIU_COOKIE_EQSTATE], %g2
	REGNO2OFFSET(%o1, %g5)
	ldx	[%g2 + %g5], %g3
	and	%g3, 3, %g3
	sub	%g3, 1, %g3
	brnz	%g3, herr_inval
	ldx	[%g1 + PIU_COOKIE_EQHEAD], %g2
	ldx	[%g1 + PIU_COOKIE_EQTAIL], %g3

	stx	%g0, [%g2 + %g5]
	stx	%g0, [%g3 + %g5]
	stx	%g6, [%g4 + PIU_MSIEQ_GUEST]

	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_conf)

/*
 * piu_msiq_info
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 ra (%o1)
 * ret2 #entries (%o2)
 */
	ENTRY_NP(piu_msiq_info)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	.empty
	MSIEQNUM2MSIEQ(%g1, %o1, %g4, %g3, %g5)
	ldx	[%g4 + PIU_MSIEQ_GUEST], %g5
	set	PIU_NEQRECORDS, %o2
	movrz	%g5, %g0, %o2
	brz,pn	%g5, 1f
	GUEST_STRUCT(%g2)
	PA2RA_CONV(%g2, %g5, %o1, %g6, %g4)	! PA -> RA (%o1)
1:	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_info)

/*
 * piu_msiq_getvalid
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 EQ valid (%o1) (0: Invalid 1: Valid)
 */
	ENTRY_NP(piu_msiq_getvalid)
	VPCI_PRINT1("HV:msiq_getvalid ", %o1)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	ldx	[%g1 + PIU_COOKIE_EQSTATE], %g2
	REGNO2OFFSET(%o1, %g7)
	ldx	[%g2 + %g7], %g4
	and	%g4, 3, %g4
	sub	%g4, 1, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_getvalid)

/*
 * piu_msiq_setvalid
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ valid (%o2) (0: Invalid 1: Valid)
 * --
 * ret0 status
 */
	ENTRY_NP(piu_msiq_setvalid)
	VPCI_PRINT2("HV:msiq_setvalid ", %o1, %o2)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	.empty
	MSIEQNUM2MSIEQ(%g1, %o1, %g3, %g2, %g4)

	ldx	[%g3 + PIU_MSIEQ_GUEST], %g2	! Guest Q base
	brnz	%g2, 1f
	movrz	%o2, PIU_COOKIE_EQCTLCLR, %g3
	brnz	%o2, herr_inval
1:	movrnz	%o2, PIU_COOKIE_EQCTLSET, %g3
	ldx	[%g1 + %g3], %g3
	setx	(1<<44), %g5, %g4
	REGNO2OFFSET(%o1, %g7)
	stx	%g4, [%g3 + %g7]
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_setvalid)

/*
 * piu_msiq_getstate
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 EQ state (%o1) (0: Idle 1: Error)
 */
	ENTRY_NP(piu_msiq_getstate)
	VPCI_PRINT1("HV:msiq_getstate ", %o1)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + PIU_COOKIE_EQSTATE], %g2
	ldx	[%g2 + %g4], %g3
	and	%g3, 4, %o1
	movrnz	%o1, HVIO_MSIQSTATE_ERROR, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_getstate)

/*
 * piu_msiq_setstate
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 EQ state (%o2) (0: Idle 1: Error)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msiq_setstate)
	VPCI_PRINT2("HV:msiq_setstate ", %o1, %o2)
	REGNO2OFFSET(%o1, %g4)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	.empty
	/*
	 * To change state from error to idle, we set bits 57 and 47 in the
	 * Event Queue Control Clear Register (CCR)
	 *
	 * To change state from idle to error, we set bits 44 and 57 in the
	 * Event Queue Control Set Register (CSR)
	 */
	mov	PIU_COOKIE_EQCTLCLR, %g6			! EQ CCR
	movrnz	%o2, PIU_COOKIE_EQCTLSET, %g6			! EQ CSR
	ldx	[%g1 + %g6], %g2
	setx	(1 << PIU_EQCCR_COVERR)|(1 << PIU_EQCCR_E2I_SHIFT), %g5, %g3	! set idle
	setx	(1 << PIU_EQCSR_ENOVERR)|(1 << PIU_EQCSR_EN_SHIFT), %g5, %g6	! set error
	movrnz	%o2, %g6, %g3
	stx	%g3, [%g2 + %g4]
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_setstate)

/*
 * piu_msiq_gethead
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status
 * ret1 head index
 */
	ENTRY_NP(piu_msiq_gethead)
	VPCI_PRINT1("HV:msiq_gethead ", %o1)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + PIU_COOKIE_EQHEAD], %g2
	ldx	[%g2 + %g4], %o1
	sllx	%o1, PIU_EQREC_SHIFT, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_gethead)

/*
 * piu_msiq_sethead
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * arg2 head offset (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msiq_sethead)
	VPCI_PRINT2("HV:msiq_sethead ", %o1, %o2)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	set	PIU_EQSIZE, %g2
	cmp	%o2, %g2
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g6)
	ldx	[%g1 + PIU_COOKIE_EQHEAD], %g2
	ldx	[%g2 + %g6], %g3
	mov	%o2, %g6
	sllx	%g3, PIU_EQREC_SHIFT, %g3
	!! %g1 = PIU COOKIE
	!! %g2 = EQ HEAD reg
	!! %g3 = Prev Head offset
	!! %g6 = New Head offset
	MSIEQNUM2MSIEQ(%g1, %o1, %g4, %g5, %g7)
	!! %g1 = PIU COOKIE
	!! %g2 = EQ HEAD reg
	!! %g3 = Prev Head offset
	!! %g4 = struct *piu_msieq
	!! %g6 = New Head offset
	ldx	[%g4 + PIU_MSIEQ_BASE], %g5	/* HW Q base */
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
	ldx	[%g4 + PIU_MSIEQ_EQMASK], %g7
	and	%g3, %g7, %g3
	cmp	%g6, %g3
	bne	1b
	add	%g5, %g3, %g7
	REGNO2OFFSET(%o1, %g6)
	srlx	%o2, PIU_EQREC_SHIFT, %g3
	stx	%g3, [%g2 + %g6]
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_sethead)

/*
 * piu_msiq_gettail
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI EQ id (%o1)
 * --
 * ret0 status (%o0)
 * ret1 tail index (%o1)
 */
	ENTRY_NP(piu_msiq_gettail)
	VPCI_PRINT1("HV:msiq_gettail ", %o1)
	cmp	%o1, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + PIU_COOKIE_EQTAIL], %g2
	ldx	[%g2 + %g4], %o1
	sllx	%o1, PIU_EQREC_SHIFT, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msiq_gettail)

/*
 * piu_msi_getvalid
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI status (%o1) (0: Invalid 1: Valid)
 */
	ENTRY_NP(piu_msi_getvalid)
	VPCI_PRINT1("HV:msiq_getvalid ", %o1)
	cmp	%o1, PIU_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + PIU_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g4], %g5
	mov	HVIO_MSI_INVALID, %o1
	movrlz	%g5, HVIO_MSI_VALID, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_getvalid)

/*
 * piu_msi_setvalid
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI status (%o2) (0: Invalid 1: Valid)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msi_setvalid)
	VPCI_PRINT2("HV:msiq_setvalid ", %o1, %o2)
	cmp	%o1, PIU_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + PIU_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g4], %g5
	sllx	%g5, 1, %g5
	srlx	%g5, 1, %g5
	sllx	%o2, PIU_MSIMR_V_SHIFT, %g3
	or	%g5, %g3, %g5
	stx	%g5, [%g2 + %g4]
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_setvalid)

/*
 * piu_msi_getstate
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI state (%o1) (0: Idle 1: Delivered)
 */
	ENTRY_NP(piu_msi_getstate)
	VPCI_PRINT1("HV:msi_getstate ", %o1)
	cmp	%o1, PIU_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	ldx	[%g1 + PIU_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g4], %g5
	brlz,pn %g5, 0f
	mov	HVIO_MSI_INVALID, %o1
	HCALL_RET(EOK)

0:	srlx	%g5, PIU_MSIMR_EQWR_N_SHIFT, %o1
	and	%o1, HVIO_MSI_VALID, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_getstate)

/*
 * piu_msi_setstate
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI state (%o2) (0: Idle)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msi_setstate)
	VPCI_PRINT2("HV:msi_setstate ", %o1, %o2)
	cmp	%o1, PIU_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g4)
	brnz,pn	%o2, herr_inval
	mov	1, %g5
	sllx	%g5, PIU_MSIMR_EQWR_N_SHIFT, %g5
	ldx	[%g1 + PIU_COOKIE_MSICLR], %g2
	stx	%g5, [%g2 + %g4]
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_setstate)

/*
 * piu_msi_getmsiq
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI EQ id (%o1)
 */
	ENTRY_NP(piu_msi_getmsiq)
	VPCI_PRINT1("HV:msi_getmsiq ", %o1)
	cmp	%o1, PIU_MSI_MASK
	bgu,pn	%xcc, herr_inval
	REGNO2OFFSET(%o1, %g7)
	ldx	[%g1 + PIU_COOKIE_MSIMAP], %g2
	ldx	[%g2 + %g7], %o1
	and	%o1, PIU_MSIEQNUM_MASK, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_getmsiq)

/*
 * piu_msi_setmsiq
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI number (%o1)
 * arg2 MSI EQ id (%o2)
 * arg3 MSI type (%o3) (MSI32=0 MSI64=1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msi_setmsiq)
	VPCI_PRINT2("HV:msi_setmsiq ", %o1, %o2)
	cmp	%o1, PIU_MSI_MASK
	bgu,pn	%xcc, herr_inval
	cmp	%o2, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	ldx	[%g1 + PIU_COOKIE_MSIMAP], %g2
	REGNO2OFFSET(%o1, %g7)
	ldx	[%g2 + %g7], %g5
	andn	%g5, PIU_MSIEQNUM_MASK, %g5
	or	%g5, %o2, %g5
	stx	%g5, [%g2 + %g7]
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_setmsiq)

/*
 * piu_msi_msg_getmsiq
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI EQ id (%o1)
 */
	ENTRY_NP(piu_msi_msg_getmsiq)
	VPCI_PRINT1("HV:msi_msg_getmsiq ", %o1)
	ldx	[%g1 + PIU_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_CORR_OFF, %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_NONFATAL_OFF, %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_FATAL_OFF, %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_PME_OFF, %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_PME_ACK_OFF, %g3
	ba	herr_inval
	nop
1:	ldx	[%g2 + %g3], %o1
	and	%o1, PIU_MSIEQNUM_MASK, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_msg_getmsiq)

/*
 * piu_msi_msg_setmsiq
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * arg2 MSI EQ id (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msi_msg_setmsiq)
	VPCI_PRINT2("HV:msi_msg_setmsiq ", %o1, %o2)
	cmp	%o2, PIU_NEQS
	bgeu,pn	%xcc, herr_inval
	ldx	[%g1 + PIU_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_CORR_OFF, %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_NONFATAL_OFF, %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_FATAL_OFF, %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_PME_OFF, %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_PME_ACK_OFF, %g3
	ba	herr_inval
	nop
1:	ldx	[%g2 + %g3], %g4
	andn	%g4, PIU_MSIEQNUM_MASK, %g4
	or	%g4, %o2, %g4
	stx	%g4, [%g2 + %g3]
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_msg_setmsiq)

/*
 * piu_msi_msg_getvalid
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * --
 * ret0 status (%o0)
 * ret1 MSI msg valid state (%o1)
 */
	ENTRY_NP(piu_msi_msg_getvalid)
	VPCI_PRINT1("HV:msi_msg_getvalid ", %o1)
	ldx	[%g1 + PIU_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + PIU_CORR_OFF], %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + PIU_NONFATAL_OFF], %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + PIU_FATAL_OFF], %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + PIU_PME_OFF], %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	ldx	[%g2 + PIU_PME_ACK_OFF], %g3
	ba,pt	%xcc, herr_inval
	nop
1:	movrlz	%g3, HVIO_PCIE_MSG_VALID, %o1
	movrgez	%g3, HVIO_PCIE_MSG_INVALID, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_msg_getvalid)

/*
 * piu_msi_msg_setvalid
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 MSI msg type (%o1)
 * arg2 MSI msg valid state (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_msi_msg_setvalid)
	VPCI_PRINT2("HV:msi_msg_setvalid ", %o1, %o2)
	cmp	%o2, 1
	bgu,pn	%xcc, herr_inval
	ldx	[%g1 + PIU_COOKIE_MSGMAP], %g2
	cmp	%o1, PCIE_CORR_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_CORR_OFF, %g3
	cmp	%o1, PCIE_NONFATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_NONFATAL_OFF, %g3
	cmp	%o1, PCIE_FATAL_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_FATAL_OFF, %g3
	cmp	%o1, PCIE_PME_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_PME_OFF, %g3
	cmp	%o1, PCIE_PME_ACK_MSG
	be,a,pn	%xcc, 1f
	  mov	PIU_PME_ACK_OFF, %g3
	ba	herr_inval
	nop
1:
	sllx	%o2, PIU_MSGMR_V_SHIFT, %g5
	ldx	[%g2 + %g3], %g4
	sllx	%g4, 1, %g4
	srlx	%g4, 1, %g4
	or	%g4, %g5, %g4
	stx	%g4, [%g2 + %g3]
	HCALL_RET(EOK)
	SET_SIZE(piu_msi_msg_setvalid)

/*
 * piu_msi_mondo_receive
 *
 * %g1 = PIU Cookie
 * %g2 = Mondo DATA0
 * %g3 = Mondo DATA1
 */
	ENTRY_NP(piu_msi_mondo_receive)
	STRAND_PUSH(%g1, %g6, %g7)
	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	ba	insert_device_mondo_r
	rd	%pc, %g7
	STRAND_POP(%g3, %g6)
	STRAND_POP(%g2, %g6)
	STRAND_POP(%g1, %g6)

	and	%g2, PIU_DEVINO_MASK, %g2
	sub	%g2, PIU_EQ2INO(0), %g2
	MSIEQNUM2MSIEQ(%g1, %g2, %g3, %g4, %g5)
	! %g1 = PIU Cookie
	! %g2 = MSI EQ Number
	! %g3 = struct *piu_msieq
	REGNO2OFFSET(%g2, %g2)
	ldx	[%g1 + PIU_COOKIE_EQTAIL], %g5
	ldx	[%g5 + %g2], %g7
	ldx	[%g1 + PIU_COOKIE_EQHEAD], %g5
	ldx	[%g5 + %g2], %g6

	! %g1 = PIU COOKIE
	! %g2 = MSI EQ OFFSET
	! %g3 = struct piu_msieq *
	! %g6 = Head
	! %g7 = New Tail
	cmp	%g6, %g7
	be	9f
	sllx	%g6, PIU_EQREC_SHIFT, %g6	/* New tail offset */
	sllx	%g7, PIU_EQREC_SHIFT, %g7	/* Old Tail offset */

	ldx	[%g3 + PIU_MSIEQ_GUEST], %g2	/* Guest Q base */
	brz,pn	%g2, 9f
	ldx	[%g3 + PIU_MSIEQ_BASE], %g5	/* HW Q base */

	! %g2 = Guest Q base
	! %g3 = struct piu_msieq *
	! %g5 = HW Q base
	! %g6 = Old Tail
	! %g7 = New Tail
	! %g1 = scratch
	! %g4 = scratch

1:
	! Word 0 is TTTT EQW0[63:61]
	ldx	[%g5 + %g6], %g1 ! Read Word 0 From HW
	stx	%g1, [%g3 + PIU_MSIEQ_WORD0]

	srlx	%g1, PIU_EQREC_TYPE_SHIFT+5, %g4
	stx	%g4, [%g2 + %g6] ! Store Word 0
	add	%g6, 8, %g6

	ldx	[%g5 + %g6], %g4 ! Read Word 1 from HW
	stx	%g4, [%g3 + PIU_MSIEQ_WORD1]

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
	ldx	[%g3 + PIU_MSIEQ_WORD1], %g4
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
	! %g1 = HW Word 0

	! Extract GGGG.GGGG EQW0[31:16] -> W6[47:32]
	srlx	%g1, MSIEQ_TID_SHIFT, %g4
	sllx	%g4, 64-MSIEQ_TID_SIZE_BITS, %g4
	srlx	%g4, 64-(MSIEQ_TID_SIZE_BITS+VPCI_MSIEQ_TID_SHIFT), %g4

	ldx	[%g3 + PIU_MSIEQ_WORD0], %g1

	! Extract CCC field EQW0[58:56] -> W6[18:16]
	sllx	%g1, 64-(MSIEQ_MSG_RT_CODE_SHIFT+MSIEQ_MSG_RT_CODE_SIZE_BITS), %g1
	srlx	%g1, 64-MSIEQ_MSG_RT_CODE_SIZE_BITS, %g1
	sllx	%g1, VPCI_MSIEQ_MSG_RT_CODE_SHIFT, %g1
	or	%g1, %g4, %g4

	ldx	[%g3 + PIU_MSIEQ_WORD0], %g1

	! Extract MMMM.MMMM field EQW0[7:0] -> W6[7:0]
	sllx	%g1, 64-MSIEQ_MSG_CODE_SIZE_BITS, %g1
	srlx	%g1, 64-MSIEQ_MSG_CODE_SIZE_BITS, %g1
	or	%g1, %g4, %g4
	stx	%g4, [%g2 + %g6] ! Store Word 6
	add	%g6, 8, %g6
3:
	stx	%g0, [%g2 + %g6] ! Store Word 7
	add	%g6, 8, %g6

	ldx	[%g3 + PIU_MSIEQ_EQMASK], %g4
	and	%g6, %g4, %g6
	cmp	%g6, %g7
	bne	1b
	nop
9:
	retry
	SET_SIZE(piu_msi_mondo_receive)



/*
 * Each register entry is 0x20 bytes
 */
#define	PIU_PERF_READ_ADR	(0 * SIZEOF_UI64)
#define	PIU_PERF_READ_MASK	(1 * SIZEOF_UI64)
#define	PIU_PERF_WRITE_ADR	(2 * SIZEOF_UI64)
#define	PIU_PERF_WRITE_MASK	(3 * SIZEOF_UI64)
#define	PIU_PERF_TBL_ENTRY_SIZE (4 * SIZEOF_UI64)
#define	PIU_PERF_TBL_ENTRY_SHIFT 5 /* log2(TBL_ENTRY_SIZE) */
#define	PIU_PERF_TBL_NENTRIES	((piu_perf_regs_table_end - \
	    piu_perf_regs_table) / PIU_PERF_TBL_ENTRY_SIZE)
#define	PIU_REGID2OFFSET(id, offset)	\
	    sllx id, PIU_PERF_TBL_ENTRY_SHIFT, offset

	.align		8
	.section	".text"
piu_perf_regs_table:
	! Registers 0 - 2
	.xword	PIU_DLC_IMU_ICS_IMU_PERF_CNTRL, 0x000000000000ffff
	.xword	PIU_DLC_IMU_ICS_IMU_PERF_CNTRL, 0x000000000000ffff
	.xword	PIU_DLC_IMU_ICS_IMU_PERF_CNT0, 0xffffffffffffffff
	.xword	PIU_DLC_IMU_ICS_IMU_PERF_CNT0, 0xffffffffffffffff
	.xword	PIU_DLC_IMU_ICS_IMU_PERF_CNT1, 0xffffffffffffffff
	.xword	PIU_DLC_IMU_ICS_IMU_PERF_CNT1, 0xffffffffffffffff
	! Registers 3 - 5
	.xword	PIU_DLC_MMU_PRFC, 0x000000000000ffff
	.xword	PIU_DLC_MMU_PRFC, 0x000000000000ffff
	.xword	PIU_DLC_MMU_PRF0, 0xffffffffffffffff
	.xword	PIU_DLC_MMU_PRF0, 0xffffffffffffffff
	.xword	PIU_DLC_MMU_PRF1, 0xffffffffffffffff
	.xword	PIU_DLC_MMU_PRF1, 0xffffffffffffffff
	! Registers 6 - 9
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRFC, 0x000000000003ffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRFC, 0x000000000003ffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRF0, 0xffffffffffffffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRF0, 0xffffffffffffffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRF1, 0xffffffffffffffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRF1, 0xffffffffffffffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRF2, 0x00000000ffffffff
	.xword	PIU_PLC_TLU_CTB_TLR_TLU_PRF2, 0x00000000ffffffff
	! Registers 10 - 11
	.xword	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_BIT_ERR_CNT_1_ADDR, 0xc0000000ffff003f
	.xword	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_BIT_ERR_CNT_1_ADDR, 0xc000000000000000
	.xword	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_BIT_ERR_CNT_2_ADDR, 0x3f3f3f3f3f3f3f3f
	.xword	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_BIT_ERR_CNT_2_ADDR, 0x0000000000000000
piu_perf_regs_table_end:

/*
 * piu_get_perf_reg
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 perf reg ID (%o1)
 * --
 * ret0 status (%o0)
 * ret1 value (%o1)
 */
	ENTRY_NP(piu_get_perf_reg)
	cmp	%o1, PIU_PERF_TBL_NENTRIES
	bgeu,pn	%xcc, herr_inval
	mov	1, %g3
	sllx	%g3, %o1, %g3
	ldx	[%g1 + PIU_COOKIE_PERFREGS], %g2
	and	%g2, %g3, %g3
	brz,pn	%g3, herr_inval
	ldx	[%g1 + PIU_COOKIE_PCIE], %g2

	! %g1 = PIU cookie pointer
	! %g2 = PIU base PA
	LABEL_ADDRESS(piu_perf_regs_table, %g4)

	! %g1 = PIU cookie pointer
	! %g2 = PIU base PA
	! %g4 = Performance regs table
	PIU_REGID2OFFSET(%o1, %g3)
	add	%g3, %g4, %g4
	ldx	[%g4 + PIU_PERF_READ_ADR], %g3
	ldx	[%g4 + PIU_PERF_READ_MASK], %g4

	! %g1 = PIU cookie pointer
	! %g2 = PIU base PA
	! %g3 = Perf reg offset
	! %g4 = Perf reg mask
	ldx	[%g2 + %g3], %o1
	and	%o1, %g4, %o1
	HCALL_RET(EOK)
	SET_SIZE(piu_get_perf_reg)

/*
 * piu_set_perf_reg
 *
 * %g1 = PIU Cookie Pointer
 * arg0 dev config pa (%o0)
 * arg1 perf reg ID (%o1)
 * arg2 value (%o2)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(piu_set_perf_reg)
	cmp	%o1, PIU_PERF_TBL_NENTRIES
	bgeu,pn	%xcc, herr_inval
	mov	1, %g3
	sllx	%g3, %o1, %g3
	ldx	[%g1 + PIU_COOKIE_PERFREGS], %g2
	and	%g2, %g3, %g3
	brz,pn	%g3, herr_inval
	ldx	[%g1 + PIU_COOKIE_PCIE], %g2

	! %g1 = PIU cookie pointer
	! %g2 = PIU base PA
	LABEL_ADDRESS(piu_perf_regs_table, %g4)

	! %g1 = PIU cookie pointer
	! %g2 = PIU base PA
	! %g4 = Performance regs table
	PIU_REGID2OFFSET(%o1, %g3)
	add	%g3, %g4, %g4
	ldx	[%g4 + PIU_PERF_WRITE_ADR], %g3
	ldx	[%g4 + PIU_PERF_WRITE_MASK], %g4

	! %g1 = PIU cookie pointer
	! %g2 = PIU base PA
	! %g3 = Perf reg offset
	! %g4 = Perf reg mask
	and	%o2, %g4, %g5
	stx	%g5, [%g2 + %g3]
	HCALL_RET(EOK)
	SET_SIZE(piu_set_perf_reg)


#ifdef DEBUG
! When DEBUG is defined hcall.s versions
! of these are labels are too far away
herr_nocpu:	HCALL_RET(ENOCPU)
herr_nomap:	HCALL_RET(ENOMAP)
herr_inval:	HCALL_RET(EINVAL)
herr_badalign:	HCALL_RET(EBADALIGN)
#endif


#define PIU_INVALIDATE_INTX(piup, intx_off, scr1, scr2)        \
	ldx	[piup + PIU_COOKIE_PCIE], scr1                 ;\
        set     intx_off, scr2                                  ;\
        add     scr1, scr2, scr1                                ;\
        set     1, scr2                                         ;\
        stx     scr2, [scr1]

/*
 * PIU_MSIQ_UNCONFIGURE
 *
 * piu		- (preserved) PIU Cookie Pointer
 * msieq_id 	- (preserved) MSI EQ id
 *
 */
#define	PIU_MSIQ_UNCONFIGURE(piu, msieq_id, scr1, scr2, scr3, scr4)	\
	.pushlocals							;\
	cmp	msieq_id, PIU_NEQS					;\
	bgeu,pn	%xcc, 0f						;\
	MSIEQNUM2MSIEQ(piu, msieq_id, scr3, scr2, scr1)			;\
	REGNO2OFFSET(msieq_id, scr4)					;\
	ldx	[piu + PIU_COOKIE_EQHEAD], scr1				;\
	ldx	[piu + PIU_COOKIE_EQTAIL], scr2				;\
	stx	%g0, [scr1 + scr4]					;\
	stx	%g0, [scr2 + scr4]					;\
	stx	%g0, [scr3 + PIU_MSIEQ_GUEST]				;\
0:									;\
	.poplocals


/*
 * PIU_MSIQ_INVALIDATE
 *
 * piu		- (preserved) PIU Cookie Pointer
 * msieq_id 	- (preserved) MSI EQ id
 *
 */
#define	PIU_MSIQ_INVALIDATE(piu, msieq_id, scr1, scr2, scr3, scr4)	\
	.pushlocals							;\
	cmp	msieq_id, PIU_NEQS					;\
	bgeu,pn	%xcc, 0f						;\
	  nop								;\
	ldx	[piu + PIU_COOKIE_EQCTLCLR], scr1			;\
	/* setx	(1<<44), scr3, scr2 */					;\
	/* 44=disable, 47=e2i 57=coverr */                      	;\
	setx    (1<<44)|(1<<47)|(1<<57), scr3, scr2                     ;\
	REGNO2OFFSET(msieq_id, scr4)					;\
	stx	scr2, [scr1 + scr4]					;\
0:									;\
	.poplocals


/*
 * PIU_MSI_INVALIDATE - Invalidate the MSI mappings and then clear
 * the MSI status (mark as "idle")
 *
 * piu	- (preserved) PIU Cookie Pointer
 * msi_num - (preserved) MSI number (%o1)
 *
 */
#define	PIU_MSI_INVALIDATE(piu, msi_num, scr1, scr2, scr3)	\
	.pushlocals						;\
	cmp	msi_num, PIU_MSI_MASK				;\
	bgu,pn	%xcc, 0f					;\
	REGNO2OFFSET(msi_num, scr2)				;\
	ldx	[piu + PIU_COOKIE_MSIMAP], scr1			;\
	ldx	[scr1 + scr2], scr3				;\
	/* clear both bits 62 and 63 in the map reg */  	;\
	/* valid and ok to write (pending MSI) bit */   	;\
	sllx    scr3, 2, scr3                                   ;\
	srlx    scr3, 2, scr3                                   ;\
	stx	scr3, [scr1 + scr2]				;\
	mov	1, scr3		/* now mark status as "idle" */	;\
	sllx	scr3, PIU_MSIMR_EQWR_N_SHIFT, scr3		;\
	ldx	[piu + PIU_COOKIE_MSICLR], scr1			;\
	stx	scr3, [scr1 + scr2]				;\
0:								;\
	.poplocals


/*
 * PIU_MSI_MSG_INVALIDATE
 *
 * piu		- (preserved) PIU Cookie Pointer
 * msg_offset - (preserved) message offset such as PIU_CORR_OFF,
 *                          PIU_NONFATAL_OFF, etc. (reg or contant)
 *
 */
#define	PIU_MSI_MSG_INVALIDATE(piu, msg_offset, scr1, scr2)	\
	ldx	[piu+  PIU_COOKIE_MSGMAP], scr1			;\
	ldx	[scr1 + msg_offset], scr2			;\
	sllx	scr2, 1, scr2					;\
	srlx	scr2, 1, scr2					;\
	stx	scr2, [scr1 + msg_offset]

	! %g1	PIU cookie
	! %g7	return address
        ENTRY(piu_leaf_soft_reset)

	!
	! if piu is blacklisted just skip this
	!
	lduw	[%g1 + PIU_COOKIE_BLACKLIST], %g4
	brnz,pn	%g4, skip_piu_leaf_soft_reset
	nop
	!
	! Disable Link errors
	!
	DISABLE_PCIE_LUP_LDN_ERRORS(%g1, %g4, %g5, %g6)
	membar	#Sync

	!
	! Put STRAND in protected mode
	!
	STRAND_STRUCT(%g4)
	mov	1, %g5
	set	STRAND_IO_PROT, %g6
	stx	%g5, [%g4 + %g6]
	membar	#Sync

	! clear the IOTSB
	mov	%g1, %g6
	mov	%g7, %g5
	ldx	[%g1 + PIU_COOKIE_IOTSB0], %g1
	set	IOTSB0_SIZE, %g2
	HVCALL(bzero)
	mov	%g6, %g1
	mov	%g5, %g7


	! %g1 piu struct

	!
	! Do secondary reset and initialize upstream port)
	!
	mov	PIU_RESET_MAX_ATTEMPTS, %g3
0:
	STRAND_PUSH(%g3, %g4, %g5)
	mov	%g0, %g2	! %g2	bus
	RESET_PIU_LEAF(%g1, %g2, %g3, %g4, %g5, %g6)
	membar	#Sync
	STRAND_POP(%g3, %g4)

	!
	! Verify that the PIU link came up in x8 mode
	! Give the Link Status a chance to update first
	!
	CPU_MSEC_DELAY(300, %g2, %g4, %g5)

	set	PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_ADDR, %g4
	ldx	[%g1 + PIU_COOKIE_PCIE], %g2
	ldx	[%g2 + %g4], %g2
#ifdef DEBUG
	mov	%g7, %g5
	PRINT("PIU Link Status Register after leaf reset 0x")
	PRINTX(%g2)
	PRINT("\r\n")
	mov	%g5, %g7
#endif
	srlx	%g2, PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_WIDTH_SHIFT, %g2
	and	%g2, PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_WIDTH_MASK, %g2
	cmp	%g2, PIU_PLC_TLU_CTB_TLR_CSR_A_LNK_STS_WIDTH_x8
	be,pt	%xcc, 1f	! link width x8, continue
	dec	%g3
	brgz,pt	%g3, 0b		! < PIU_RESET_MAX_ATTEMPTS ?
	nop

	!
	! we have exhausted the PIU link training retry limit, blacklist
	! the device and move on
	!
	mov	1, %g4
	ba,pn	%xcc, piu_leaf_soft_reset_exit
	stw	%g4, [%g1 + PIU_COOKIE_BLACKLIST]
1:

	!
        ! Invalidate any pending legacy (level) interrupts
        ! that were previously signalled from switches we just reset
        !

        PIU_INVALIDATE_INTX(%g1, PCI_E_INT_A_CLEAR_ADDR, %g2, %g4)
        PIU_INVALIDATE_INTX(%g1, PCI_E_INT_B_CLEAR_ADDR, %g2, %g4)
        PIU_INVALIDATE_INTX(%g1, PCI_E_INT_C_CLEAR_ADDR, %g2, %g4)
        PIU_INVALIDATE_INTX(%g1, PCI_E_INT_D_CLEAR_ADDR, %g2, %g4)

	!
	! invalidate all MSIs
	!
	set	PIU_MAX_MSIS - 1, %g2
1:	PIU_MSI_INVALIDATE(%g1, %g2, %g6, %g4, %g5)
	brgz,pt	%g2, 1b
	  dec	%g2
	membar	#Sync

	!
	! invalidate all MSI Messages
	!
	PIU_MSI_MSG_INVALIDATE(%g1, PIU_CORR_OFF, %g5, %g4)
	PIU_MSI_MSG_INVALIDATE(%g1, PIU_NONFATAL_OFF, %g5, %g4)
	PIU_MSI_MSG_INVALIDATE(%g1, PIU_FATAL_OFF, %g5, %g4)
	PIU_MSI_MSG_INVALIDATE(%g1, PIU_PME_OFF, %g5, %g4)
	PIU_MSI_MSG_INVALIDATE(%g1, PIU_PME_ACK_OFF, %g5, %g4)

	!
	! invalidate all interrupts
	!
	! invalidate inos 63 and 62, special case ones not set with
	! _piu_intr_setvalid
	ldx     [%g1 + PIU_COOKIE_VIRTUAL_INTMAP], %g2
	add	%g2, DMU_ERR_MONDO_OFFSET, %g2
	stb	%g0, [%g2]
	ldx     [%g1 + PIU_COOKIE_VIRTUAL_INTMAP], %g2
	add	%g2, PEU_ERR_MONDO_OFFSET, %g2
	stb	%g0, [%g2]

	STRAND_PUSH(%g7, %g4, %g5)	! _piu_intr_setvalid clobbers all regs
	! Don't invalidate inos 62 & 63 in this loop, 62 and 63 done above
	set	NPIUDEVINO - 3, %g2
	clr	%g3
1:	HVCALL(_piu_intr_setvalid)	! clobbers %g4-%g6
	cmp	%g2, 20
	bgu,pt	%xcc, 1b
	  dec	%g2
	membar	#Sync
	STRAND_POP(%g7, %g4)	! restore clobbered value

	!
	! invalidate and unconfigure all MSI EQs
	!
	set	PIU_NEQS - 1, %g2
1:	PIU_MSIQ_INVALIDATE(%g1, %g2, %g3, %g4, %g5, %g6)
	PIU_MSIQ_UNCONFIGURE(%g1, %g2, %g3, %g4, %g5, %g6)
	brgz,pt	%g2, 1b
	  dec	%g2
	membar	#Sync

	!
	! clear any pending error interrupts
	! all these registers are RW1C
	!
	mov	-1, %g3
	ldx	[%g1 + PIU_COOKIE_PCIE], %g2
	set	PIU_DLC_IMU_ICS_IMU_LOGGED_ERROR_STATUS_REG_RW1C_ALIAS, %g4
	stx	%g3, [%g2 + %g4]
	set	PIU_PLC_TLU_CTB_TLR_OE_ERR_RW1C_ALIAS, %g4
	stx	%g3, [%g2 + %g4]
	set	PCI_E_MMU_ERR_STAT_CL_ADDR, %g4
	stx	%g3, [%g2 + %g4]
	set	PCI_E_PEU_UE_STAT_CL_ADDR, %g4
	stx	%g3, [%g2 + %g4]
	set	PCI_E_ILU_ERR_STAT_CL_ADDR, %g4
	stx	%g3, [%g2 + %g4]
	set	PCI_E_PEU_CXPL_STAT_CL_ADDR, %g4
	stx	%g3, [%g2 + %g4]

	!
	! re-enable errors
	!
	ENABLE_PCIE_LUP_LDN_ERRORS(%g1, %g2, %g4, %g5)
	membar	#Sync

piu_leaf_soft_reset_exit:
	!
	! Bring STRAND out of protected mode
	!
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g2
	stx	%g0, [%g4 + %g2]
	set	STRAND_IO_ERROR, %g2
	stx	%g0, [%g4 + %g2]

skip_piu_leaf_soft_reset:

	HVRET

	SET_SIZE(piu_leaf_soft_reset)

        /*
         * Wrapper around piu_leaf_soft_reset() so that it can be called from C
         * SPARC ABI requries only that g2,g3,g4 are preserved across
         * function calls.
         * %o0 = PIU cookie
         * %o1 = root complex bus number (0)
         *
         * void c_piu_leaf_soft_reset(struct pcie_cookie *, uint64 root)
         */

        ENTRY(c_piu_leaf_soft_reset)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	mov	%o0, %g1	! %g1	PIU cookie
	HVCALL(piu_leaf_soft_reset)

        STRAND_POP(%g4, %g6)
        STRAND_POP(%g3, %g6)
        STRAND_POP(%g2, %g6)

        retl
          nop
        SET_SIZE(c_piu_leaf_soft_reset)

	/*
	 * FIXME: The following link up/down functions are not ready
	 *	  for use yet, awaiting more information
	 */

	/*
	 * This macro brings a given PIU leaf's link up
	 *
	 * Inputs:
	 *
	 *    piu - (preserved) pointer to PIU_COOKIE
	 *
	 * Bring up a piu link. Returns false on failure.
	 */
	ENTRY(piu_link_up)

	PIU_LINK_UP(%o0, %o1, %o2, %o3)

	retl
	  mov	1, %o0
	SET_SIZE(piu_link_up)

	/*
	 * This function brings a given piu leaf's link down
	 * Inputs:
	 *
	 *    piu - (preserved) pointer to PIU_COOKIE
	 * Returns:
	 * 	false (0) on failure.
	 */
	ENTRY(piu_link_down)

		/* get the base addr of RC control regs */
	ldx	[ %o0 + PIU_COOKIE_PCIE ], %o1
		/* And now the actual reset code... */
		/* Remain in detect quiesce */
	! PEU control register
	set	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_CTL_ADDR, %o2
	ldx	[ %o1 + %o2 ], %o3
	bset	(1 << 8), %o3
	stx	%o3, [ %o1 + %o2]

	! Disable link - set bit 4 of PEU Link Control register
	set	PIU_PLC_TLU_CTB_TLR_LNK_CTL, %o2
	ldx	[ %o1 + %o2], %o3
	bset	(1 << 4), %o3
	stx	%o3, [ %o1 + %o2]

	! Wait for link to go down
	setx	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_STS_ADDR, %o4, %o2
1:
	ldx	[ %o1 + %o2 ], %o3
	andcc	%o3, 0x7, %o3		! status bits [2:0]
	cmp	%o3, 0x1		! data link inactive
	bne,pt	%xcc, 1b
	  nop


	retl
	  mov	1, %o0
	SET_SIZE(piu_link_down)

	/*
	 * Check and see if a PIU link is up. Returns true on
	 * success, false on failure.
	 */
	ENTRY(is_piu_port_link_up)
	ldx	[ %o0 + PIU_COOKIE_PCIE ], %o1
	! PEU status register
	setx	PIU_PLC_TLU_CTB_TLR_CSR_A_TLU_STS_ADDR, %o3, %o2
	ldx	[ %o1 + %o2 ], %o3
	and	%o3, 0x7, %o3	! status bits [2:0]
	cmp	%o3, 0x4	! data link active
	mov	%g0, %o0
	move	%xcc, 1, %o0
	retl
	  nop
	SET_SIZE(is_piu_port_link_up)


/*
 * arg0 (%g1) = PIU Cookie
 * arg2 (%g2) = Offset
 * arg3 (%g3) = size (1, 2, 4)
 * --------------------
 * ret0 = status (1 fail, 0 pass)
 * ret1 = data
 */

	ENTRY_NP(hv_config_get)

	!! %g1 =  piu cookie (pointer)
	!! %g2 = offset
	!! %g3 = size (1 byte, 2 bytes, 4 bytes)

	mov	1, %g5
	STRAND_STRUCT(%g4)
	set	STRAND_IO_PROT, %g6

	!! %g4 = Strand struct

	! strand.io_prot = 1
	stx	%g5, [%g4 + %g6]

	DISABLE_PCIE_RWUC_ERRORS(%g1, %g4, %g5, %g6)


	ldx	[%g1 + PIU_COOKIE_CFG], %g4
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
 * bool_t pci_config_get(uint64_t piup, uint64_t offset, int size,
 *		uint64_t *data)
 */
        ENTRY(pci_config_get)

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

        mov     %o0, %g1
        mov     %o1, %g2
	mov	%o2, %g3

	! %g1 - piupp
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
 * piu_intr_redistribution
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
	ENTRY(piu_intr_redistribution)
	CPU_PUSH(%g7, %g3, %g4, %g5)

	mov	%g1, %g3	! save cpuid
	GUEST_STRUCT(%g4)
	mov	PIU_AID, %g1
	DEVINST2INDEX(%g4, %g1, %g1, %g5, .piu_intr_redis_fail)
	DEVINST2COOKIE(%g4, %g1, %g1, %g5, .piu_intr_redis_fail)

	! %g1 - piu cookie
	! %g3 - this cpu
	HVCALL(_piu_intr_redistribution)

.piu_intr_redis_fail:
	mov	%g3, %g1	! restore cpuid
	CPU_POP(%g7, %g3, %g4, %g5)
	HVRET
	SET_SIZE(piu_intr_redistribution)

/*
 * _piu_intr_redistribution
 *
 * %g1 - piu cookie
 * %g3 - this cpu
 */
	ENTRY(_piu_intr_redistribution)
	CPU_PUSH(%g7, %g4, %g5, %g6)

	! %g1 - piu cookie ptr
	lduh	[%g1 + PIU_COOKIE_INOMAX], %g2	! loop counter
	dec	%g2	! INOMAX - 1

._piu_intr_redis_loop:
	cmp	%g2, DMU_INTERNAL_INT
	be	%xcc, .piu_intr_redis_continue	! DMU errors handle separate
	nop

	cmp	%g2, PEU_INTERNAL_INT
	be	%xcc, .piu_intr_redis_continue	! PEU errors handle separate
	nop

	ldx	[%g1 + PIU_COOKIE_INTMAP], %g5
	REGNO2OFFSET(%g2, %g4)
	ldx	[%g5 + %g4], %g4

	! Extract cpuid
	srlx	%g4, JPID_SHIFT, %g7
	and	%g7, JPID_MASK, %g7

	! %g7 - cpuid
	! compare with this cpu, if match,  set to idle
	cmp	%g3, %g7
	bne,pt	%xcc, .piu_intr_redis_continue
	nop

	! save cpuid since call clobbers it
	CPU_PUSH(%g3, %g4, %g5, %g6)
	CPU_PUSH(%g2, %g4, %g5, %g6)
	mov	INTR_DISABLED, %g3	! Invalid

	! %g1 = PIU Cookie
	! %g2 = device ino
	! %g3 = Idle
	HVCALL(_piu_intr_setvalid)

	CPU_POP(%g2, %g4, %g5, %g6)
	CPU_POP(%g3, %g4, %g5, %g6)

.piu_intr_redis_continue:
	deccc	%g2
	bgeu,pt	 %xcc, ._piu_intr_redis_loop
	nop

.piu_redis_done:

	CPU_POP(%g7, %g4, %g5, %g6)
	HVRET
	SET_SIZE(_piu_intr_redistribution)

#endif /* CONFIG_PIU */
