/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: niu.s
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

	.ident	"@(#)niu.s	1.9	07/09/06 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>
#include <intr.h>
#include <fpga.h>

#include <guest.h>
#include <offsets.h>
#include <debug.h>
#include <util.h>

/*
 * Niagara2 NIU
 *
 * N.B. "internally NIU is a little-endian device".
 */

/*
 * NIU table
 *
 * Map logical devices to logical groups 1:1 according to the
 * following 'well-defined' mapping:
 *
 *  [0-15]  - reserved
 *  [16]    - mac0
 *  [17]    - MIF
 *  [18]    - SYSERR
 *  [19-26] - func0 Rx
 *  [27-34] - func0 Tx
 *  [35]    - mac1
 *  [36-43] - func1 Rx
 *  [44-51] - func1 Tx
 *
 * The group number will also function as the "devino".
 *
 * Furthermore, give each group number a unique vector ("identifier")
 * to use when an interrupt occurs so we know which device needs to
 * be serviced.
 */
	DATA_GLOBAL(niu_table)
	/* logical device #, logical group #, vector identifier/priority # */
	.xword NIU_LDN_RX_DMA_CH0,	19,	0,
	.xword NIU_LDN_RX_DMA_CH1,	20,	1,
	.xword NIU_LDN_RX_DMA_CH2,	21,	2,
	.xword NIU_LDN_RX_DMA_CH3,	22,	3,
	.xword NIU_LDN_RX_DMA_CH4,	23,	4,
	.xword NIU_LDN_RX_DMA_CH5,	24,	5,
	.xword NIU_LDN_RX_DMA_CH6,	25,	6,
	.xword NIU_LDN_RX_DMA_CH7,	26,	7,
	.xword NIU_LDN_RX_DMA_CH8,	36,	8,
	.xword NIU_LDN_RX_DMA_CH9,	37,	9,
	.xword NIU_LDN_RX_DMA_CH10,	38,	10,
	.xword NIU_LDN_RX_DMA_CH11,	39,	11,
	.xword NIU_LDN_RX_DMA_CH12,	40,	12,
	.xword NIU_LDN_RX_DMA_CH13,	41,	13,
	.xword NIU_LDN_RX_DMA_CH14,	42,	14,
	.xword NIU_LDN_RX_DMA_CH15,	43,	15,
	.xword NIU_LDN_TX_DMA_CH0,	27,	16,
	.xword NIU_LDN_TX_DMA_CH1,	28,	17,
	.xword NIU_LDN_TX_DMA_CH2,	29,	18,
	.xword NIU_LDN_TX_DMA_CH3,	30,	19,
	.xword NIU_LDN_TX_DMA_CH4,	31,	20,
	.xword NIU_LDN_TX_DMA_CH5,	32,	21,
	.xword NIU_LDN_TX_DMA_CH6,	33,	22,
	.xword NIU_LDN_TX_DMA_CH7,	34,	23,
	.xword NIU_LDN_TX_DMA_CH8,	44,	24,
	.xword NIU_LDN_TX_DMA_CH9,	45,	25,
	.xword NIU_LDN_TX_DMA_CH10,	46,	26,
	.xword NIU_LDN_TX_DMA_CH11,	47,	27,
	.xword NIU_LDN_TX_DMA_CH12,	48,	28,
	.xword NIU_LDN_TX_DMA_CH13,	49,	29,
	.xword NIU_LDN_TX_DMA_CH14,	50,	30,
	.xword NIU_LDN_TX_DMA_CH15,	51,	31,
	.xword NIU_LDN_MIF,		17,	32,
	.xword NIU_LDN_MAC0,		16,	33,
	.xword NIU_LDN_MAC1,		35,	34,
	.xword NIU_LDN_SYSERR,		18,	35,
	.xword	-1,-1,-1 /* End of Table */
	SET_SIZE(niu_table)


/*
 * NIU logical device group to logical device number table
 */
	DATA_GLOBAL(niu_ldg2ldn_table)
	/* groups 0..7 */
	.xword -1, -1, -1, -1, -1, -1, -1, -1
	/* groups 8..15 */
	.xword -1, -1, -1, -1, -1, -1, -1, -1
	/* groups 16..23 */
	.xword NIU_LDN_MAC0, NIU_LDN_MIF
	.xword NIU_LDN_SYSERR, NIU_LDN_RX_DMA_CH0,
	.xword NIU_LDN_RX_DMA_CH1, NIU_LDN_RX_DMA_CH2,
	.xword NIU_LDN_RX_DMA_CH3, NIU_LDN_RX_DMA_CH4
	/* groups 24..31 */
	.xword NIU_LDN_RX_DMA_CH5, NIU_LDN_RX_DMA_CH6,
	.xword NIU_LDN_RX_DMA_CH7, NIU_LDN_TX_DMA_CH0
	.xword NIU_LDN_TX_DMA_CH1, NIU_LDN_TX_DMA_CH2
	.xword NIU_LDN_TX_DMA_CH3, NIU_LDN_TX_DMA_CH4
	/* groups 32..39 */
	.xword NIU_LDN_TX_DMA_CH5, NIU_LDN_TX_DMA_CH6
	.xword NIU_LDN_TX_DMA_CH7, NIU_LDN_MAC1
	.xword NIU_LDN_RX_DMA_CH8, NIU_LDN_RX_DMA_CH9
	.xword NIU_LDN_RX_DMA_CH10, NIU_LDN_RX_DMA_CH11
	/* groups 40..47 */
	.xword NIU_LDN_RX_DMA_CH12, NIU_LDN_RX_DMA_CH13
	.xword NIU_LDN_RX_DMA_CH14, NIU_LDN_RX_DMA_CH15
	.xword NIU_LDN_TX_DMA_CH8, NIU_LDN_TX_DMA_CH9
	.xword NIU_LDN_TX_DMA_CH10, NIU_LDN_TX_DMA_CH11
	/* groups 48..55 */
	.xword NIU_LDN_TX_DMA_CH12, NIU_LDN_TX_DMA_CH13
	.xword NIU_LDN_TX_DMA_CH14, NIU_LDN_TX_DMA_CH15
	.xword -1, -1, -1, -1
	/* groups 56..63 */
	.xword -1, -1, -1, -1, -1, -1, -1, -1
	SET_SIZE(niu_ldg2ldn_table)


/*
 * NIU vector to logical device group table
 *
 * Map interrupt vector ("identifier") to logical device group
 * number.  The logical device group number is the "devino".
 */
	DATA_GLOBAL(niu_vec2ldg_table)
	/* vectors 0..7 */
	.xword 19, 20, 21, 22, 23, 24, 25, 26
	/* vectors 8..15 */
	.xword 36, 37, 38, 39, 40, 41, 42, 43
	/* vectors 16..23 */
	.xword 27, 28, 29, 30, 31, 32, 33, 34
	/* vectors 24..31 */
	.xword 44, 45, 46, 47, 48, 49, 50, 51
	/* vectors 32..39 */
	.xword 17, 16, 35, 18, -1, -1, -1, -1
	/* vectors 40..47 */
	.xword -1, -1, -1, -1, -1, -1, -1, -1
	/* vectors 48..55 */
	.xword -1, -1, -1, -1, -1, -1, -1, -1
	/* vectors 56..63 */
	.xword -1, -1, -1, -1, -1, -1, -1, -1
	SET_SIZE(niu_vec2ldg_table)


/*
 * NIU interrupt state
 *
 * To avoid store buffer collisions keep this struct cacheline aligned by
 * passing NIUMAPREG_SIZE as alignment restriction; see comment above
 * "struct niu_mapreg".
 */ 
	BSS_GLOBAL(niu_state, NIUSTATE_SIZE, NIUMAPREG_SIZE)


/*
 * Convert a Logical Group Number to a Logical Device Number.
 *
 * (ldn and cookie can be the same register) or
 *     (ldn and lgn can be the same register)
 */
#define	NIU_LGN2LDN(lgn, ldn, cookie, scr1) \
	sllx	lgn, SHIFT_LONG, scr1				;\
	ldx	[cookie + NIU_LDG2LDN_TABLE], ldn		;\
	ldx	[ldn + scr1], ldn


/*
 * Convert a Mondo Vector Number to a Logical Group Number.
 *
 * (lgn and cookie can be the same register) or
 *     (lgn and vec can be the same register)
 */
#define	NIU_VEC2LDN(vec, lgn, cookie, scr1) \
	sllx	vec, SHIFT_LONG, scr1				;\
	ldx	[cookie + NIU_VEC2LDG_TABLE], lgn		;\
	ldx	[lgn + scr1], lgn


/*
 * Get the MAPREG for a logical group number (INO).
 *
 * (guest and scr1 can be the same register)
 */
#define	NIU_LGN2MAPREG(guest, lgn, mapreg, scr1) \
	set	GUEST_NIU_STATEP, mapreg			;\
	ldn	[guest + mapreg], mapreg			;\
	add	mapreg, NIUSTATE_MAPREG, mapreg			;\
	sllx	lgn, NIUMAPREG_SHIFT, scr1			;\
	add	mapreg, scr1, mapreg


/*
 * Get the target VCPU pointer for a logical device group (INO).
 */
#define	NIU_LGN2TARGET_VCPUP(lgn, vcpup, scr1) \
	GUEST_STRUCT(scr1)					;\
	NIU_LGN2MAPREG(scr1, lgn, vcpup, scr1)			;\
	ldn	[vcpup + NIUMAPREG_VCPUP], vcpup


/*
 * Get the interrupt status bits for a logical device group (INO).
 */
#define	NIU_LGN2STATEBITS(lgn, ldn, bits, scr1, scr2, scr3)	\
	.pushlocals						;\
	cmp	ldn, 64						;\
	bge,pn	%xcc, 0f					;\
	.empty							;\
	/* LDN < 64, check the first two state vectors */	;\
	setx	NIU_LDSV0_REG, scr2, scr1			;\
	sllx	lgn, NIU_LDSV0_REG_SHIFT, bits			;\
	ldxa	[scr1 + bits]ASI_P_LE, bits			;\
	setx	NIU_LDSV1_REG, scr2, scr1			;\
	sllx	lgn, NIU_LDSV1_REG_SHIFT, scr3			;\
	ldxa	[scr1 + scr3]ASI_P_LE, scr3			;\
	ba,pt	%xcc, 1f					;\
	or	bits, scr3, bits				;\
0:	/* LDN >= 64, check the last state vector */		;\
	setx	NIU_LDSV2_REG, scr2, scr1			;\
	sllx	lgn, NIU_LDSV2_REG_SHIFT, bits			;\
	ldxa	[scr1 + bits]ASI_P_LE, bits			;\
1:	.poplocals


/*
 * niu_init: Initialize NIU device
 *
 * N.B. called from C; use only %g1, %g5, %g6 or %g7.
 */
	ENTRY_NP(niu_init)
	PRINT("niu_init\r\n")

	STRAND_PUSH(%g2, %g6, %g7)
	STRAND_PUSH(%g3, %g6, %g7)
	STRAND_PUSH(%g4, %g6, %g7)

	/*
	 * Initialize the logical device groups.
	 */
	setx	niu_table, %g3, %g2
	RELOC_OFFSET(%g4, %g3)
	sub	%g2, %g3, %g2
	setx	NIU_LDG_NUM_REG, %g4, %g3
0:
	ldx	[%g2], %g4			! %g4 is logical device number
	brlz,pn	%g4, 1f
	ldx	[%g2 + 8], %g5			! %g5 is logical group number
	sllx	%g4, NIU_LDG_NUM_REG_SHIFT, %g4
	stxa	%g5, [%g3 + %g4]ASI_P_LE
	ba,pt	%xcc, 0b
	add	%g2, 24, %g2
1:

	/*
	 * Initialize DMA channel bindings.  Don't bind any of the channels to
	 * virtualization regions.
	 */
	clr	%g1
	setx	NIU_DMA_BIND_REG, %g3, %g2
0:
	stxa	%g0, [%g2]ASI_P_LE
	inc	NIU_DMA_BIND_REG_STEP, %g2
	inc	%g1
	cmp	%g1, NIU_DMA_BIND_N_REG
	bl,pt	%icc, 0b
	nop

	/*
	 * Initialize the NCU-related interrupt registers.
	 *
	 * INT_MAN index = logical group number + 64
	 */
	clr	%g1
	setx	NIU_SID_REG, %g3, %g2
0:
	add	%g1, 64, %g3
	stxa	%g3, [%g2]ASI_P_LE
	inc	NIU_SID_REG_STEP, %g2
	inc	%g1
	cmp	%g1, NIU_SID_N_REG
	bl,pt	%icc, 0b
	nop

	STRAND_POP(%g4, %g7)
	STRAND_POP(%g3, %g7)
	STRAND_POP(%g2, %g7)

	retl
	nop
	SET_SIZE(niu_init)

/*
 * niu_intr_init: Initialize NCU-related part of NIU interrupt infrastructure
 *
 * in:
 *	%i0 - global config pointer
 *	%i1 - base of guests
 *	%i2 - base of cpus
 *	%g7 - return address
 *
 * volatile:
 *	%globals, %locals (%l7 preserved)
 */
	ENTRY_NP(niu_intr_init)
	/*
	 * Initialize INT_MAN[] vector dispatch priority aka
	 *  ("NIU device identifier").
	 */
	PHYS_STRAND_ID(%g1)
	sllx	%g1, INT_MAN_CPU_SHIFT, %g1	! master cpu is default target
	setx	niu_table, %g3, %g2
	ldx	[%i0 + CONFIG_RELOC], %g3
	sub	%g2, %g3, %g2
	setx	NCU_BASE, %g4, %g3
0:
	ldx	[%g2 + 16], %g4			! %g4 is "identifier"
	brlz,pn	%g4, 1f
	ldx	[%g2 + 8], %g5			! %g5 is logical group number
	add	%g5, 64, %g5
	sllx	%g5, INT_MAN_SHIFT, %g5
	or	%g4, %g1, %g4
	stx	%g4, [%g3 + %g5]
	ba,pt	%xcc, 0b
	add	%g2, 24, %g2
1:
	HVRET
	SET_SIZE(niu_intr_init)

/*
 * niu_reset: Reset NIU device
 *
 * N.B. called from C; use only %g1, %g5, %g6 or %g7.
 */
	ENTRY_NP(niu_reset)
	PRINT("niu_reset\r\n")

	/* stop the RX MACs */
	!! RX xMac port 0 stop
	setx	NIU_XMAC_CFG_REG_0, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	bclr	XMAC_RX_ENABLE, %g5
	stxa	%g5, [%g1]ASI_P_LE

	CPU_MSEC_DELAY(100, %g1, %g5, %g6)
	setx	NIU_XMAC_SM_REG_0, %g6, %g1
0:	ldxa	[%g1]ASI_P_LE, %g5
	btst	XMAC_SM_RX_QST_ST, %g5
	bnz,pn	%xcc, 0b
	nop

	!! RX xMac port 1 stop
	setx	NIU_XMAC_CFG_REG_1, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	bclr	XMAC_RX_ENABLE, %g5
	stxa	%g5, [%g1]ASI_P_LE

	CPU_MSEC_DELAY(100, %g1, %g5, %g6)
	setx	NIU_XMAC_SM_REG_1, %g6, %g1
0:	ldxa	[%g1]ASI_P_LE, %g5
	btst	XMAC_SM_RX_QST_ST, %g5
	bnz,pn	%xcc, 0b
	nop

	/* stop the RX DMA engines */
	setx	NIU_RX_CFG1_REG, %g6, %g1
	clr	%g6
0:	ldxa	[%g1]ASI_P_LE, %g5
	set	RX_DMA_ENABLE, %g7
	bclr	%g7, %g5
	stxa	%g5, [%g1]ASI_P_LE
1:	ldxa	[%g1]ASI_P_LE, %g5
	set	RX_DMA_QUIESCED, %g7
	btst	%g7, %g5
	bz,pn	%xcc, 1b
	nop
	inc	NIU_RX_CFG1_REG_STEP, %g1
	inc	%g6
	cmp	%g6, NIU_RX_CFG1_N_REG
	bl,pt	%icc, 0b
	nop

	/* disable ipp */
	setx	NIU_IPP_CFG_REG_0, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	bclr	IPP_ENABLE, %g5
	stxa	%g5, [%g1]ASI_P_LE

	setx	NIU_IPP_CFG_REG_1, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	bclr	IPP_ENABLE, %g5
	stxa	%g5, [%g1]ASI_P_LE

	/* reset the RX DMA engines */
	setx	NIU_RX_CFG1_REG, %g6, %g1
	clr	%g6
0:	ldxa	[%g1]ASI_P_LE, %g5
	set	RX_DMA_RESET, %g7
	and	%g5, %g7, %g5
	stxa	%g5, [%g1]ASI_P_LE
1:	ldxa	[%g1]ASI_P_LE, %g5
	set	RX_DMA_RESET, %g7
	btst	%g7, %g5
	bnz,pn	%xcc, 1b
	nop
	inc	NIU_RX_CFG1_REG_STEP, %g1
	inc	%g6
	cmp	%g6, NIU_RX_CFG1_N_REG
	bl,pt	%icc, 0b
	nop

	/* stop the TX DMA engines */
	clr	%g6
0:	setx	NIU_TX_PORT0_REG, %g5, %g1
	ldxa	[%g1]ASI_P_LE, %g7
	setx	NIU_TX_PORT1_REG, %g5, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	or	%g5, %g7, %g5
	mov	1, %g7
	sllx	%g7, %g6, %g7
	btst	%g7, %g5
	bz,pn	%xcc, 2f
	nop

	setx	NIU_TX_CTL_ST_REG, %g5, %g1
	sllx	%g6, NIU_TX_CTL_ST_REG_SHIFT, %g5
	add	%g1, %g5, %g1

	set	TX_CTL_STOP_N_GO, %g7
	stxa	%g7, [%g1]ASI_P_LE
1:	ldxa	[%g1]ASI_P_LE, %g5
	set	TX_CTL_SNG_STS, %g7
	btst	%g7, %g5
	bz,pn	%xcc, 1b
	nop

2:	inc	%g6
	cmp	%g6, NIU_TX_CTL_ST_N_REG
	bl,pt	%icc, 0b
	nop

	/* stop the TX MACs */
	!! TX xMac port 0 stop
	setx	NIU_XMAC_CFG_REG_0, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	bclr	XMAC_TX_ENABLE, %g5
	stxa	%g5, [%g1]ASI_P_LE

	/*
	 * Should be checking the xMAC State Machine Status register here
	 * but not sure what the 'final' state is.  Instead wait a while.
	 */
	CPU_MSEC_DELAY(100, %g1, %g5, %g6)

	!! TX xMac port 1 stop
	setx	NIU_XMAC_CFG_REG_1, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	bclr	XMAC_TX_ENABLE, %g5
	stxa	%g5, [%g1]ASI_P_LE

	/*
	 * Should be checking the xMAC State Machine Status register here
	 * but not sure what the 'final' state is.  Instead wait a while.
	 */
	CPU_MSEC_DELAY(100, %g1, %g5, %g6)

	/* reset the TX DMA engines */
	clr	%g6
0:	setx	NIU_TX_PORT0_REG, %g5, %g1
	ldxa	[%g1]ASI_P_LE, %g7
	setx	NIU_TX_PORT1_REG, %g5, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	or	%g5, %g7, %g5
	mov	1, %g7
	sllx	%g7, %g6, %g7
	btst	%g7, %g5
	bz,pn	%xcc, 2f
	nop

	setx	NIU_TX_CTL_ST_REG, %g5, %g1
	sllx	%g6, NIU_TX_CTL_ST_REG_SHIFT, %g5
	add	%g1, %g5, %g1

	set	TX_CTL_RESET, %g7
	stxa	%g7, [%g1]ASI_P_LE
1:	ldxa	[%g1]ASI_P_LE, %g5
	set	TX_CTL_RESET_STS, %g7
	btst	%g7, %g5
	bz,pn	%xcc, 1b
	nop

2:	inc	%g6
	cmp	%g6, NIU_TX_CTL_ST_N_REG
	bl,pt	%icc, 0b
	nop

	/* reset the MACs */
	!! Rx xMAC port 0 soft reset
	setx	NIU_XRXMAC_RST_REG_0, %g6, %g1
	set	(XRXMAC_REG_RST | XRXMAC_SM_RST), %g5
	stxa	%g5, [%g1]ASI_P_LE

	setx	NIU_XRXMAC_RST_REG_0, %g6, %g1
0:	ldxa	[%g1]ASI_P_LE, %g5
	brnz,pn	%g5, 0b
	nop

	!! Rx xMAC port 1 soft reset
	setx	NIU_XRXMAC_RST_REG_1, %g6, %g1
	set	(XRXMAC_REG_RST | XRXMAC_SM_RST), %g5
	stxa	%g5, [%g1]ASI_P_LE

	setx	NIU_XRXMAC_RST_REG_1, %g6, %g1
0:	ldxa	[%g1]ASI_P_LE, %g5
	brnz,pn	%g5, 0b
	nop

	!! Tx xMAC port 0 soft reset
	setx	NIU_XTXMAC_RST_REG_0, %g6, %g1
	set	(XTXMAC_REG_RST | XTXMAC_SM_RST), %g5
	stxa	%g5, [%g1]ASI_P_LE

	setx	NIU_XTXMAC_RST_REG_0, %g6, %g1
0:	ldxa	[%g1]ASI_P_LE, %g5
	brnz,pn	%g5, 0b
	nop

	!! Tx xMAC port 1 soft reset
	setx	NIU_XTXMAC_RST_REG_1, %g6, %g1
	set	(XTXMAC_REG_RST | XTXMAC_SM_RST), %g5
	stxa	%g5, [%g1]ASI_P_LE

	setx	NIU_XTXMAC_RST_REG_1, %g6, %g1
0:	ldxa	[%g1]ASI_P_LE, %g5
	brnz,pn	%g5, 0b
	nop

	/* reset ipp */
	setx	NIU_IPP_CFG_REG_0, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	set	IPP_RESET, %g7
	bset	%g7, %g5
	stxa	%g5, [%g1]ASI_P_LE

	setx	NIU_IPP_CFG_REG_1, %g6, %g1
	ldxa	[%g1]ASI_P_LE, %g5
	set	IPP_RESET, %g7
	bset	%g7, %g5
	stxa	%g5, [%g1]ASI_P_LE

	/* reset control FIFOs */
	setx	NIU_CFIFO_RESET_REG, %g6, %g1
	set	(RESET_CFIFO1 | RESET_CFIFO0), %g5
	stxa	%g5, [%g1]ASI_P_LE
	membar	#Sync
	stxa	%g0, [%g1]ASI_P_LE

	/*
	 * Now the NIU ought to be thoroughly quiesced.  For completeness
	 * and to bring all registers back to POR state whack the entire
	 * unit with a reset.
	 */
	setx	SUBSYS_RESET, %g5, %g1
	mov	RESET_NIU, %g5
	stx	%g5, [%g1]
0:	ldx	[%g1], %g5
	btst	RESET_NIU, %g5
	bnz,pn	%xcc, 0b
	nop

	retl
	nop
	SET_SIZE(niu_reset)


/*
 * niu_mondo - handle an NIU interrrupt.
 *
 * %g2 = vector number
 *
 * N.B. we perform the retry here.
 */
	ENTRY_NP(niu_mondo)
	mov	NIU_DEVINST, %g3
	GUEST_STRUCT(%g1)
	DEVINST2INDEX(%g1, %g3, %g3, %g4, niu_mondo_fail)
	DEVINST2COOKIE(%g1, %g3, %g3, %g4, niu_mondo_fail)
	NIU_VEC2LDN(%g2, %g2, %g3, %g4)		! %g2 = logical device group

	NIU_LGN2MAPREG(%g1, %g2, %g3, %g1)

	!! %g3 = MAPREG
	!! %g2 = INO

	ld	[%g3 + NIUMAPREG_VALID], %g4
	brnz	%g4, 1f				! interrupt enabled?
	mov	INTR_IDLE, %g4
	retry
	/*NOTREACHED*/
1:
	mov	INTR_DELIVERED, %g5
	add	%g3, NIUMAPREG_STATE, %g3
	casa	[%g3]ASI_P, %g4, %g5
	cmp	%g5, INTR_IDLE
	bne	%xcc, 2f
	add	%g2, (NIU_DEVINST << DEVCFGPA_SHIFT), %g2
	HVCALL(insert_device_mondo_r)
2:
	retry
	/*NOTREACHED*/
niu_mondo_fail:
	HVRET
	SET_SIZE(niu_mondo)

/*
 * niu_intr_notify
 *
 * %g1 = logical device number
 * %g4 = MAPREG
 * %g6 = logical group number
 *
 * Check if the logical device has a pending interrupt.  If pending,
 * deliver an interrupt.
 */
	ENTRY_NP(niu_intr_notify)
	NIU_LGN2STATEBITS(%g6, %g1, %g3, %g2, %g5, %g7)
	brz	%g3, niu_intr_notify_exit
	.empty

	!! %g1 = logical device number
	!! %g4 = MAPREG
	!! %g6 = logical group number
	mov	INTR_IDLE, %g2
	mov	INTR_DELIVERED, %g5
	add	%g4, NIUMAPREG_STATE, %g4
	casa	[%g4]ASI_P, %g2, %g5
	cmp	%g5, INTR_IDLE
	bne	%xcc, niu_intr_notify_exit
	.empty

	! determine the target vcpu and deliver the interrupt
	NIU_LGN2TARGET_VCPUP(%g6, %g1, %g2)
	mov	1, %g2		! is 'mondo'
	add	%g6, (NIU_DEVINST << DEVCFGPA_SHIFT), %g3
	HVCALL(send_dev_mondo)

niu_intr_notify_exit:
	HCALL_RET(EOK)

niu_intr_notify_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(niu_intr_notify)

/*
 * niu_intr_redistribution
 *
 * %g1 - this cpu id
 * %g2 - tgt cpu id
 *
 * Need to invalidate all of the virtual intrs that are
 * mapped to the cpu passed in %g1 and retarget to the
 * cpu in %g2.
 */
	ENTRY_NP(niu_intr_redistribution)
	/* XXX - stub for now */
	HVRET
	SET_SIZE(niu_intr_redistribution)

/*
 * niu_devino2vino
 *
 * arg0 dev config pa (%o0)
 * arg1 dev ino (%o1)
 * --
 * ret0 status (%o0)
 * ret1 virtual INO (%o1)
 */
	ENTRY_NP(niu_devino2vino)
	/*
	 * All validity checks on config pa and dev ino have been
	 * performed before we get here.  Just create the vino and
	 * and return.
	 */
	or	%o0, %o1, %o1
	HCALL_RET(EOK)
	SET_SIZE(niu_devino2vino)

/*
 * niu_intr_getvalid
 *
 * %g1 = NIU cookie pointer
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 intr valid state (%o1)
 */
	ENTRY_NP(niu_intr_getvalid)
	! convert from sysino -> devino (logical group) -> logical device
	and	%o0, DEVINOMASK, %g2		! %g2 is logical group number

	GUEST_STRUCT(%g3)

	NIU_LGN2MAPREG(%g3, %g2, %g4, %g3)

	ld	[%g4 + NIUMAPREG_VALID], %g1
	mov	INTR_ENABLED, %o1
	movrz	%g1, INTR_DISABLED, %o1
	HCALL_RET(EOK)
	SET_SIZE(niu_intr_getvalid)

/*
 * niu_intr_setvalid
 *
 * %g1 = NIU cookie pointer
 * arg0 Virtual INO (%o0)
 * arg1 intr valid state (%o1) 1: Valid 0: Invalid
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(niu_intr_setvalid)
	! convert from sysino -> devino (logical group) -> logical device
	and	%o0, DEVINOMASK, %g6		! %g6 is logical group number

	GUEST_STRUCT(%g3)

	NIU_LGN2MAPREG(%g3, %g6, %g4, %g3)

	brz,pn	%o1, niu_intr_setvalid_exit	! interrupt VALID?
	st	%o1, [%g4 + NIUMAPREG_VALID]	! regardless, fill in valid

	!! %g1 = cookie pointer
	!! %g6 = logical group number
	!! %g4 = MAPREG
	NIU_LGN2LDN(%g6, %g1, %g1, %g3)		! %g1 is logical device number
	brlz	%g1, niu_intr_setvalid_fail
	.empty

	! Enable interrupt by clearing mask register.
	!
	! Recall there are _two_ different mask regions,
	! one for the first 64 devices, the second for the remaining 5.
	!  (see comment in niu.h)
	cmp	%g1, 64
	bge,pn	%xcc, 0f
	.empty
	setx	NIU_PIO_IMASK0_BASE, %g3, %g2
	set	NIU_INTR_MASK0_REG_SHIFT, %g3
	ba,pt	%xcc, 1f
	mov	%g1, %g5
0:
	setx	NIU_PIO_IMASK1_BASE, %g3, %g2
	set	NIU_INTR_MASK1_REG_SHIFT, %g3
	sub	%g1, 64, %g5
1:
	sllx	%g5, %g3, %g5
	ldxa	[%g2 + %g5]ASI_P_LE, %g3
	brz	%g3, 2f				! already enabled?
	nop
	stxa	%g0, [%g2 + %g5]ASI_P_LE
2:

	! check if there is a pending interrupt, if so, notify guest
	HVCALL(niu_intr_notify)
	/*NOTREACHED*/

niu_intr_setvalid_exit:
	HCALL_RET(EOK)

niu_intr_setvalid_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(niu_intr_setvalid)

/*
 * niu_intr_getstate
 *
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(niu_intr_getstate)
	!!  %g1 = NIU cookie pointer
	! convert from sysino -> devino (logical group)
	and	%o0, DEVINOMASK, %g6		! %g6 is logical device group

	GUEST_STRUCT(%g2)

	NIU_LGN2MAPREG(%g2, %g6, %g3, %g2)

	ld	[%g3 + NIUMAPREG_STATE], %o1
	HCALL_RET(EOK)
	SET_SIZE(niu_intr_getstate)

/*
 * niu_intr_setstate
 *
 * arg0 Virtual INO (%o0)
 * arg1 (%o1) 1: Pending / 0: Idle  XXX
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(niu_intr_setstate)
	!!  %g1 = NIU cookie pointer
	! convert from sysino -> devino (logical group)
	and	%o0, DEVINOMASK, %g6		! %g6 is logical device group

	brlz,pn	%o1, niu_set_state_fail
	cmp	%o1, INTR_DELIVERED
	bgu,pn	%xcc, niu_set_state_fail
	.empty	

	GUEST_STRUCT(%g2)

	NIU_LGN2MAPREG(%g2, %g6, %g4, %g2)

	cmp	%o1, INTR_IDLE
	bne,pn	%xcc, niu_set_state_exit	! interrupt IDLE?
	st	%o1, [%g4 + NIUMAPREG_STATE]	! regardless, fill in state

	ld	[%g4 + NIUMAPREG_VALID], %o1
	brz	%o1, niu_set_state_exit		! interrupt enabled?
	.empty

	! check if there is a pending interrupt, if so, notify guest

	!! %g1 = cookie pointer
	!! %g4 = MAPREG
	!! %g6 = logical group number
	NIU_LGN2LDN(%g6, %g1, %g1, %g3)		! %g1 is logical device number
	brlz	%g1, niu_set_state_fail
	nop

	HVCALL(niu_intr_notify)
	/*NOTREACHED*/

niu_set_state_exit:
	HCALL_RET(EOK)

niu_set_state_fail:
	HCALL_RET(EINVAL)
	SET_SIZE(niu_intr_setstate)

/*
 * niu_intr_gettarget
 *
 * arg0 Virtual INO (%o0)
 * --
 * ret0 status (%o0)
 * ret1 cpuid (%o1)
 */
	ENTRY_NP(niu_intr_gettarget)
	and	%o0, DEVINOMASK, %g1		! %g1 is logical group number
	NIU_LGN2TARGET_VCPUP(%g1, %g2, %g3)
	ldub	[%g2 + CPU_VID], %o1

	HCALL_RET(EOK)
	SET_SIZE(niu_intr_gettarget)

/*
 * niu_intr_settarget
 *
 * arg0 Virtual INO (%o0)
 * arg1 cpuid (%o1)
 * --
 * ret0 status (%o0)
 */
	ENTRY_NP(niu_intr_settarget)
	GUEST_STRUCT(%g3)
	VCPUID2CPUP(%g3, %o1, %g4, herr_nocpu, %g5)

	IS_CPU_IN_ERROR(%g4, %g5)
	be,pn	%xcc, herr_cpuerror
	nop

	VCPU2STRAND_STRUCT(%g4, %g2)
	ldub	[%g2 + STRAND_ID], %g2
	and	%o0, DEVINOMASK, %g1		! %g1 is logical group number

	!! %g1 = logical group number
	!! %g2 = strand id
	!! %g3 = guest struct
	NIU_LGN2MAPREG(%g3, %g1, %g5, %g6)
	stn	%g4, [%g5 + NIUMAPREG_VCPUP]

	setx	NCU_BASE, %g4, %g3
	add	%g1, 64, %g1
	sllx	%g1, INT_MAN_SHIFT, %g1
	ldx	[%g3 + %g1], %g4
	setx	(INT_MAN_CPU_MASK << INT_MAN_CPU_SHIFT), %g6, %g5
	andn	%g4, %g5, %g4
	sllx	%g2, INT_MAN_CPU_SHIFT, %g2
	or	%g4, %g2, %g4
	stx	%g4, [%g3 + %g1]

	HCALL_RET(EOK)
	SET_SIZE(niu_intr_settarget)


/*
 * niu_rx_lp_set
 *
 * arg0 chidx (%o0)
 * arg1 pgidx (%o1)
 * arg2 raddr (%o2)
 * arg3 size (%o3)
 * --
 * ret0 status (%o0)
 *
 * N.B. this will only work if the guest pa base >= the guest ra base.
 */
	ENTRY_NP(hcall_niu_rx_lp_set)
	cmp	%o0, NIU_RX_DMA_N_CH
	bgeu,pn	%xcc, herr_inval
	cmp	%o1, NIU_RX_LPG_CH_N_REG
	bgeu,pn	%xcc, herr_inval
 	sllx	%o0, NIU_RX_LPG_REG_SHIFT, %g6

	brz	%o3, 0f			! deconfiguring?
	sub	%o3, 1, %g1
	btst	%o3, %g1		! check that size is a power of two
	bnz,pn	%xcc, herr_inval
	btst	%o2, %g1		! check for natural alignment
	bnz,pn	%xcc, herr_badalign
	GUEST_STRUCT(%g1)
	RA2PA_RANGE_CONV(%g1, %o2, %o3, herr_noraddr, %g3, %g2)

	! setup reloc register
	srlx	%g2, NIU_RX_LPG_SHIFT, %g2
	setx	NIU_RX_LPG_RELO1_REG, %g4, %g3
	setx	NIU_RX_LPG_RELO2_REG, %g5, %g4
	movrnz	%o1, %g4, %g3
	stxa	%g2, [%g3 + %g6]ASI_P_LE

	! setup value register
	srlx	%o2, NIU_RX_LPG_SHIFT, %o2
	setx	NIU_RX_LPG_VALUE1_REG, %g4, %g3
	setx	NIU_RX_LPG_VALUE2_REG, %g5, %g4
	movrnz	%o1, %g4, %g3
	stxa	%o2, [%g3 + %g6]ASI_P_LE

	! setup mask register
	dec	%o3
	not	%o3
	srax	%o3, NIU_RX_LPG_SHIFT, %o3
	setx	NIU_RX_LPG_MASK1_REG, %g4, %g3
	setx	NIU_RX_LPG_MASK2_REG, %g5, %g4
	movrnz	%o1, %g4, %g3
	stxa	%o3, [%g3 + %g6]ASI_P_LE

	! set page valid
	setx	NIU_RX_LPG_VALID_REG, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %g1
	set	NIU_RX_LPG_V_PG0_VALUE, %g4
	set	NIU_RX_LPG_V_PG1_VALUE, %g5
	movrnz	%o1, %g5, %g4
	or	%g1, %g4, %g1
	stxa	%g1, [%g3 + %g6]ASI_P_LE

	HCALL_RET(EOK)

0:
	! clear page valid
	setx	NIU_RX_LPG_VALID_REG, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %g1
	set	NIU_RX_LPG_V_PG0_VALUE, %g4
	set	NIU_RX_LPG_V_PG1_VALUE, %g5
	movrnz	%o1, %g5, %g4
	andn	%g1, %g4, %g1
	stxa	%g1, [%g3 + %g6]ASI_P_LE

	HCALL_RET(EOK)
	SET_SIZE(hcall_niu_rx_lp_set)

/*
 * niu_rx_lp_get
 *
 * arg0 chidx (%o0)
 * arg1 pgidx (%o1)
 * --
 * ret0 status (%o0)
 * ret1 raddr (%o1)
 * ret2 size (%o2)
 */
	ENTRY_NP(hcall_niu_rx_lp_get)
	cmp	%o0, NIU_RX_DMA_N_CH
	bgeu,pn	%xcc, herr_inval
	cmp	%o1, NIU_RX_LPG_CH_N_REG
	bgeu,pn	%xcc, herr_inval
	mov	%o1, %g1

	sllx	%o0, NIU_RX_LPG_REG_SHIFT, %g6

	! is this channel/register setup?
	setx	NIU_RX_LPG_VALID_REG, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %g2
	set	NIU_RX_LPG_V_PG0_VALUE, %g4
	set	NIU_RX_LPG_V_PG1_VALUE, %g5
	movrnz	%g1, %g5, %g4
	btst	%g4, %g2
	bnz,pn	%icc, 0f
	clr	%o1
	clr	%o2
	HCALL_RET(EOK)
0:
	! retrieve raddr from value register
	setx	NIU_RX_LPG_VALUE1_REG, %g4, %g3
	setx	NIU_RX_LPG_VALUE2_REG, %g5, %g4
	movrnz	%g1, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %o1
	sllx	%o1, NIU_RX_LPG_SHIFT, %o1

	! retrieve size from mask register
	setx	NIU_RX_LPG_MASK1_REG, %g4, %g3
	setx	NIU_RX_LPG_MASK2_REG, %g5, %g4
	movrnz	%g1, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %o2
	signx	%o2
	sllx	%o2, NIU_RX_LPG_SHIFT, %o2
	not	%o2
	inc	%o2

	HCALL_RET(EOK)
	SET_SIZE(hcall_niu_rx_lp_get)

/*
 * niu_tx_lp_set
 *
 * arg0 chidx (%o0)
 * arg1 pgidx (%o1)
 * arg2 raddr (%o2)
 * arg3 size (%o3)
 * --
 * ret0 status (%o0)
 *
 * N.B. this will only work if the guest pa base >= the guest ra base.
 */
	ENTRY_NP(hcall_niu_tx_lp_set)
	cmp	%o0, NIU_TX_DMA_N_CH
	bgeu,pn	%xcc, herr_inval
	cmp	%o1, NIU_TX_LPG_CH_N_REG
	bgeu,pn	%xcc, herr_inval
	sllx	%o0, NIU_TX_LPG_REG_SHIFT, %g6

	brz	%o3, 0f			! deconfiguring?
	sub	%o3, 1, %g1
	btst	%o3, %g1		! check that size is a power of two
	bnz,pn	%xcc, herr_inval
	btst	%o2, %g1		! check for natural alignment
	bnz,pn	%xcc, herr_badalign
	GUEST_STRUCT(%g1)
	RA2PA_RANGE_CONV(%g1, %o2, %o3, herr_noraddr, %g3, %g2)

	! setup reloc register
	srlx	%g2, NIU_TX_LPG_SHIFT, %g2
	setx	NIU_TX_LPG_RELO1_REG, %g4, %g3
	setx	NIU_TX_LPG_RELO2_REG, %g5, %g4
	movrnz	%o1, %g4, %g3
	stxa	%g2, [%g3 + %g6]ASI_P_LE

	! setup value register
	srlx	%o2, NIU_TX_LPG_SHIFT, %o2
	setx	NIU_TX_LPG_VALUE1_REG, %g4, %g3
	setx	NIU_TX_LPG_VALUE2_REG, %g5, %g4
	movrnz	%o1, %g4, %g3
	stxa	%o2, [%g3 + %g6]ASI_P_LE

	! setup mask register
	dec	%o3
	not	%o3
	srax	%o3, NIU_TX_LPG_SHIFT, %o3
	setx	NIU_TX_LPG_MASK1_REG, %g4, %g3
	setx	NIU_TX_LPG_MASK2_REG, %g5, %g4
	movrnz	%o1, %g4, %g3
	stxa	%o3, [%g3 + %g6]ASI_P_LE

	! set page valid
	setx	NIU_TX_LPG_VALID_REG, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %g1
	set	NIU_TX_LPG_V_PG0_VALUE, %g4
	set	NIU_TX_LPG_V_PG1_VALUE, %g5
	movrnz	%o1, %g5, %g4
	or	%g1, %g4, %g1
	stxa	%g1, [%g3 + %g6]ASI_P_LE

	HCALL_RET(EOK)

0:
	! clear page valid
	setx	NIU_TX_LPG_VALID_REG, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %g1
	set	NIU_TX_LPG_V_PG0_VALUE, %g4
	set	NIU_TX_LPG_V_PG1_VALUE, %g5
	movrnz	%o1, %g5, %g4
	andn	%g1, %g4, %g1
	stxa	%g1, [%g3 + %g6]ASI_P_LE

	HCALL_RET(EOK)
	SET_SIZE(hcall_niu_tx_lp_set)

/*
 * niu_tx_lp_get
 *
 * arg0 chidx (%o0)
 * arg1 pgidx (%o1)
 * --
 * ret0 status (%o0)
 * ret1 raddr (%o1)
 * ret2 size (%o2)
 */
	ENTRY_NP(hcall_niu_tx_lp_get)
	cmp	%o0, NIU_TX_DMA_N_CH
	bgeu,pn	%xcc, herr_inval
	cmp	%o1, NIU_TX_LPG_CH_N_REG
	bgeu,pn	%xcc, herr_inval
	mov	%o1, %g1

	sllx	%o0, NIU_TX_LPG_REG_SHIFT, %g6

	! is this channel/register setup?
	setx	NIU_TX_LPG_VALID_REG, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %g2
	set	NIU_TX_LPG_V_PG0_VALUE, %g4
	set	NIU_TX_LPG_V_PG1_VALUE, %g5
	movrnz	%g1, %g5, %g4
	btst	%g4, %g2
	bnz,pn	%icc, 0f
	clr	%o1
	clr	%o2
	HCALL_RET(EOK)
0:
	! retrieve raddr from value register
	setx	NIU_TX_LPG_VALUE1_REG, %g4, %g3
	setx	NIU_TX_LPG_VALUE2_REG, %g5, %g4
	movrnz	%g1, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %o1
	sllx	%o1, NIU_TX_LPG_SHIFT, %o1

	! retrieve size from mask register
	setx	NIU_TX_LPG_MASK1_REG, %g4, %g3
	setx	NIU_TX_LPG_MASK2_REG, %g5, %g4
	movrnz	%g1, %g4, %g3
	ldxa	[%g3 + %g6]ASI_P_LE, %o2
	signx	%o2
	sllx	%o2, NIU_TX_LPG_SHIFT, %o2
	not	%o2
	inc	%o2

	HCALL_RET(EOK)
	SET_SIZE(hcall_niu_tx_lp_get)


/*
 * xaui_reset: Reset XAUI cards
 *
 * N.B. called from C; use only %g1, %g5, %g6 or %g7.
 */
	ENTRY_NP(xaui_reset)
	PRINT("xaui_reset\r\n")

	setx	FPGA_PLATFORM_REGS, %g5, %g1
	/* drive xaui slots into reset */
	ldub	[%g1 + FPGA_DEVICE_PRESENT_OFFSET], %g5
	and	%g5, FPGA_XAUI_SLOT_RESET_CTRL_MASK, %g5	
	stb	%g5, [%g1 + FPGA_LDOM_SLOT_RESET_CONTROL_OFFSET]
	CPU_MSEC_DELAY(300, %g5, %g6, %g7)
	/* take xaui slots out of reset */
	stb	%g0, [%g1 + FPGA_LDOM_SLOT_RESET_CONTROL_OFFSET]
	CPU_MSEC_DELAY(300, %g5, %g6, %g7)

	retl
	nop
	SET_SIZE(xaui_reset)
