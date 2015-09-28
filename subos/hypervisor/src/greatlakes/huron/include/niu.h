/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: niu.h
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

#ifndef _NIAGARA2_NIU_H
#define	_NIAGARA2_NIU_H

#pragma ident	"@(#)niu.h	1.7	07/08/16 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <vdev_intr.h>
#include <error_defs.h>

/*
 * Niagara2 NIU definitions
 */

#define	NIU_ADDR_BASE		0x8100000000

#define	NIU_ADDR_LIMIT		(NIU_ADDR_BASE + 0x4000000)

#define	NIU_RX_DMA_N_CH		16
#define	NIU_TX_DMA_N_CH		16

#define	NIU_LDN_RX_DMA_CH0	0
#define	NIU_LDN_RX_DMA_CH1	1
#define	NIU_LDN_RX_DMA_CH2	2
#define	NIU_LDN_RX_DMA_CH3	3
#define	NIU_LDN_RX_DMA_CH4	4
#define	NIU_LDN_RX_DMA_CH5	5
#define	NIU_LDN_RX_DMA_CH6	6
#define	NIU_LDN_RX_DMA_CH7	7
#define	NIU_LDN_RX_DMA_CH8	8
#define	NIU_LDN_RX_DMA_CH9	9
#define	NIU_LDN_RX_DMA_CH10	10
#define	NIU_LDN_RX_DMA_CH11	11
#define	NIU_LDN_RX_DMA_CH12	12
#define	NIU_LDN_RX_DMA_CH13	13
#define	NIU_LDN_RX_DMA_CH14	14
#define	NIU_LDN_RX_DMA_CH15	15
#define	NIU_LDN_TX_DMA_CH0	32
#define	NIU_LDN_TX_DMA_CH1	33
#define	NIU_LDN_TX_DMA_CH2	34
#define	NIU_LDN_TX_DMA_CH3	35
#define	NIU_LDN_TX_DMA_CH4	36
#define	NIU_LDN_TX_DMA_CH5	37
#define	NIU_LDN_TX_DMA_CH6	38
#define	NIU_LDN_TX_DMA_CH7	39
#define	NIU_LDN_TX_DMA_CH8	40
#define	NIU_LDN_TX_DMA_CH9	41
#define	NIU_LDN_TX_DMA_CH10	42
#define	NIU_LDN_TX_DMA_CH11	43
#define	NIU_LDN_TX_DMA_CH12	44
#define	NIU_LDN_TX_DMA_CH13	45
#define	NIU_LDN_TX_DMA_CH14	46
#define	NIU_LDN_TX_DMA_CH15	47
#define	NIU_LDN_MIF		63
#define	NIU_LDN_MAC0		64
#define	NIU_LDN_MAC1		65
#define	NIU_LDN_SYSERR		68


/*
 * PIO region
 */
#define	NIU_PIO_BASE		(NIU_ADDR_BASE + 0x0)


/*
 * PIO function zero control (PIO_FZC) region
 */
#define	NIU_PIO_FZC_BASE	(NIU_PIO_BASE + 0x80000)

/*
 * DMA channel binding registers
 */
#define	NIU_DMA_BIND_REG	(NIU_PIO_FZC_BASE + 0x10000)
#define	NIU_DMA_BIND_REG_STEP	0x8
#define	NIU_DMA_BIND_N_REG	64

/*
 * System interrupt data registers
 */
#define	NIU_SID_REG		(NIU_PIO_FZC_BASE + 0x10200)
#define	NIU_SID_REG_STEP	0x8
#define	NIU_SID_N_REG		64

/*
 * Logical device group registers
 */
#define	NIU_LDG_NUM_REG		(NIU_PIO_FZC_BASE + 0x20000)
#define	NIU_LDG_NUM_REG_STEP	0x8
#define	NIU_LDG_NUM_REG_SHIFT	3	/* log2(NIU_LDG_NUM_REG_STEP) */
#define	NIU_LDG_NUM_N_REG	69


/*
 * PIO media adaptation controller (PIO_MAC) region
 */
#define	NIU_PIO_MAC_BASE	(NIU_PIO_BASE + 0x180000)

/*
 * xMAC configuration register
 */
#define	NIU_XMAC_CFG_REG	(NIU_PIO_MAC_BASE + 0x60)
#define	NIU_XMAC_CFG_REG_STEP	0x6000
#define	NIU_XMAC_CFG_REG_0	(NIU_XMAC_CFG_REG)
#define	NIU_XMAC_CFG_REG_1	(NIU_XMAC_CFG_REG + NIU_XMAC_CFG_REG_STEP)
#define	XMAC_TX_ENABLE		(1 << 0)
#define	XMAC_RX_ENABLE		(1 << 8)

/*
 * xMAC state machines register
 */
#define	NIU_XMAC_SM_REG		(NIU_PIO_MAC_BASE + 0x1A8)
#define	NIU_XMAC_SM_REG_STEP	0x6000
#define	NIU_XMAC_SM_REG_0	(NIU_XMAC_SM_REG)
#define	NIU_XMAC_SM_REG_1	(NIU_XMAC_SM_REG + NIU_XMAC_SM_REG_STEP)
#define	XMAC_SM_RX_QST_ST	(1<<8)

/*
 * TxMAC Software Reset Register
 */
#define	NIU_XTXMAC_RST_REG	(NIU_PIO_MAC_BASE + 0x0)
#define	NIU_XTXMAC_RST_REG_STEP	0x6000
#define	NIU_XTXMAC_RST_REG_0	(NIU_XTXMAC_RST_REG)
#define	NIU_XTXMAC_RST_REG_1	(NIU_XTXMAC_RST_REG + NIU_XTXMAC_RST_REG_STEP)
#define	XTXMAC_REG_RST		(1 << 1)
#define	XTXMAC_SM_RST		(1 << 0)

/*
 * RxMAC software reset register
 */
#define	NIU_XRXMAC_RST_REG	(NIU_PIO_MAC_BASE + 0x8)
#define	NIU_XRXMAC_RST_REG_STEP	0x6000
#define	NIU_XRXMAC_RST_REG_0	(NIU_XRXMAC_RST_REG)
#define	NIU_XRXMAC_RST_REG_1	(NIU_XRXMAC_RST_REG + NIU_XRXMAC_RST_REG_STEP)
#define	XRXMAC_REG_RST		(1 << 1)
#define	XRXMAC_SM_RST		(1 << 0)


/*
 * PIO inport packet processor (PIO_IPP) region
 */
#define	NIU_PIO_IPP_BASE	(NIU_PIO_BASE + 0x280000)

/*
 * IPP configuration register
 */
#define	NIU_IPP_CFG_REG		(NIU_PIO_IPP_BASE + 0x0)
#define	NIU_IPP_CFG_REG_STEP	0x8000
#define	NIU_IPP_CFG_REG_0	(NIU_IPP_CFG_REG)
#define	NIU_IPP_CFG_REG_1	(NIU_IPP_CFG_REG + NIU_IPP_CFG_REG_STEP)
#define	IPP_ENABLE		(1 << 0)
#define	IPP_RESET		(1 << 31)

/*
 * PIO zero copy processor (PIO_ZCP) region
 */
#define	NIU_PIO_ZCP_BASE	(NIU_PIO_BASE + 0x580000)

/*
 * Control FIFO Reset register
 */
#define	NIU_CFIFO_RESET_REG	(NIU_PIO_ZCP_BASE + 0x98)
#define	RESET_CFIFO1		(1 << 1)
#define	RESET_CFIFO0		(1 << 0)

/*
 * PIO DMA control (DMC) region
 */
#define	NIU_PIO_DMC_BASE	(NIU_PIO_BASE + 0x600000)

/*
 * Receive DMA configuration register 1
 */
#define	NIU_RX_CFG1_REG		(NIU_PIO_DMC_BASE + 0x0)
#define	NIU_RX_CFG1_REG_STEP	0x200
#define	NIU_RX_CFG1_N_REG	16
#define	RX_DMA_ENABLE		(1 << 31)
#define	RX_DMA_RESET		(1 << 30)
#define	RX_DMA_QUIESCED		(1 << 29)

/*
 * Transmit DMA control and status register
 */
#define	NIU_TX_CTL_ST_REG	(NIU_PIO_DMC_BASE + 0x40028)
#define	NIU_TX_CTL_ST_REG_STEP	0x200
#define	NIU_TX_CTL_ST_REG_SHIFT	9
#define	NIU_TX_CTL_ST_N_REG	16
#define	TX_CTL_RESET		(1 << 31)
#define	TX_CTL_RESET_STS	(1 << 30)
#define	TX_CTL_STOP_N_GO	(1 << 28)
#define	TX_CTL_SNG_STS		(1 << 27)


/*
 * PIO function zero DMA control (FZC_DMC) region
 */
#define	NIU_PIO_FZC_DMC_BASE	(NIU_PIO_BASE +  0x680000)

/*
 * Recieve DMA channel logical page registers
 */
#define	NIU_RX_LPG_VALID_REG	(NIU_PIO_FZC_DMC_BASE + 0x20000)
#define	NIU_RX_LPG_V_PG0_VALUE	0x1	/* page 0, valid */
#define	NIU_RX_LPG_V_PG1_VALUE	0x2	/* page 1, valid */

#define	NIU_RX_LPG_MASK1_REG	(NIU_PIO_FZC_DMC_BASE + 0x20008)
#define	NIU_RX_LPG_MASK2_REG	(NIU_PIO_FZC_DMC_BASE + 0x20018)

#define	NIU_RX_LPG_VALUE1_REG	(NIU_PIO_FZC_DMC_BASE + 0x20010)
#define	NIU_RX_LPG_VALUE2_REG	(NIU_PIO_FZC_DMC_BASE + 0x20020)

#define	NIU_RX_LPG_RELO1_REG	(NIU_PIO_FZC_DMC_BASE + 0x20028)
#define	NIU_RX_LPG_RELO2_REG	(NIU_PIO_FZC_DMC_BASE + 0x20030)

#define	NIU_RX_LPG_REG_STEP	0x40
#define	NIU_RX_LPG_REG_SHIFT	6	/* log2(NIU_RX_LPG_REG_STEP) */
#define	NIU_RX_LPG_CH_N_REG	2

#define	NIU_RX_LPG_SHIFT	12

/*
 * Transmit DMA channel logical page registers
 */
#define	NIU_TX_LPG_VALID_REG	(NIU_PIO_FZC_DMC_BASE + 0x40000)
#define	NIU_TX_LPG_V_PG0_VALUE	0x1	/* page 0, valid */
#define	NIU_TX_LPG_V_PG1_VALUE	0x2	/* page 1, valid */

#define	NIU_TX_LPG_MASK1_REG	(NIU_PIO_FZC_DMC_BASE + 0x40008)
#define	NIU_TX_LPG_MASK2_REG	(NIU_PIO_FZC_DMC_BASE + 0x40018)

#define	NIU_TX_LPG_VALUE1_REG	(NIU_PIO_FZC_DMC_BASE + 0x40010)
#define	NIU_TX_LPG_VALUE2_REG	(NIU_PIO_FZC_DMC_BASE + 0x40020)

#define	NIU_TX_LPG_RELO1_REG	(NIU_PIO_FZC_DMC_BASE + 0x40028)
#define	NIU_TX_LPG_RELO2_REG	(NIU_PIO_FZC_DMC_BASE + 0x40030)

#define	NIU_TX_LPG_REG_STEP	0x200
#define	NIU_TX_LPG_REG_SHIFT	9	/* log2(NIU_TX_LPG_REG_STEP) */
#define	NIU_TX_LPG_CH_N_REG	2

#define	NIU_TX_LPG_SHIFT	12


/*
 * PIO "TXC" block registers region
 */
#define	NIU_PIO_FZC_TXC_BASE	(NIU_PIO_BASE + 0x780000)

/*
 * Transmit DMA port binding register
 */
#define	NIU_TX_PORT_REG		(NIU_PIO_FZC_TXC_BASE + 0x20028)
#define	NIU_TX_PORT_REG_STEP	0x100
#define	NIU_TX_PORT0_REG	(NIU_TX_PORT_REG)
#define	NIU_TX_PORT1_REG	(NIU_TX_PORT_REG + NIU_TX_PORT_REG_STEP)


/*
 * PIO logical devices interrupt state vector and management region
 *
 * (Now why there are three mask regions is way beyond comprehension because it
 * makes things so really ugly.  Compounding this the register layouts aren't
 * even consistent!)
 */
#define	NIU_PIO_LDSV_BASE	(NIU_PIO_BASE + 0x800000)

/*
 * Interrupt state vector 0 registers
 */
#define	NIU_LDSV0_REG		(NIU_PIO_LDSV_BASE + 0x0)
#define	NIU_LDSV0_REG_STEP	0x2000
#define	NIU_LDSV0_REG_SHIFT	13	/* log2(NIU_PIO_LDSV0_REG_STEP) */

/*
 * Interrupt state vector 1 registers
 */
#define	NIU_LDSV1_REG		(NIU_PIO_LDSV_BASE + 0x8)
#define	NIU_LDSV1_REG_STEP	0x2000
#define	NIU_LDSV1_REG_SHIFT	13	/* log2(NIU_PIO_LDSV1_REG_STEP) */

/*
 * Interrupt state vector 2 registers
 */
#define	NIU_LDSV2_REG		(NIU_PIO_LDSV_BASE + 0x10)
#define	NIU_LDSV2_REG_STEP	0x2000
#define	NIU_LDSV2_REG_SHIFT	13	/* log2(NIU_PIO_LDSV2_REG_STEP) */


/*
 * PIO logical devices interrupt mask0 region
 */
#define	NIU_PIO_IMASK0_BASE	(NIU_PIO_BASE + 0xA00000)

#define	NIU_INTR_MASK0_REG	(NIU_PIO_IMASK0_BASE + 0x0)
#define	NIU_INTR_MASK0_REG_STEP	0x2000
#define	NIU_INTR_MASK0_REG_SHIFT 13	/* log2(NIU_INTR_MASK0_REG_STEP) */
#define	NIU_INTR_MASK0_N_REG	64

/*
 * PIO logical devices interrupt mask1 region
 *
 * (Now why there are two mask regions is way beyond comprehension because it
 * makes things so really ugly.)
 */
#define	NIU_PIO_IMASK1_BASE	(NIU_PIO_BASE + 0xB00000)

#define	NIU_INTR_MASK1_REG	(NIU_PIO_IMASK1_BASE + 0x0)
#define	NIU_INTR_MASK1_REG_STEP	0x2000
#define	NIU_INTR_MASK1_REG_SHIFT 13	/* log2(NIU_INTR_MASK1_REG_STEP) */
#define	NIU_INTR_MASK1_N_REG	5


#define	NIU_INTR_MASK_VALUE	0x3	/* normal datapath and error events */

#ifndef _ASM

extern void niu_devino2vino(void);
extern void niu_mondo_receive(void);
extern void niu_intr_getvalid(void);
extern void niu_intr_setvalid(void);
extern void niu_intr_getstate(void);
extern void niu_intr_setstate(void);
extern void niu_intr_gettarget(void);
extern void niu_intr_settarget(void);

struct niu_cookie {
	uint64_t *ldg2ldn_table;
	uint64_t *vec2ldg_table;
};

/*
 * N.B. Keep the size of struct niu_mapreg a power of 2 so the offset
 * can be computed via 'sllx' versus 'mulx'.
 * Also pad the struct so each instance maps to a unique cacheline to
 * avoid store buffer collisions.
 */
struct niu_mapreg {
	uint32_t		state;
	uint32_t		valid;
	uint64_t		vcpup;
	uint64_t		pad1;
	uint64_t		pad2;
	uint64_t		pad3;
	uint64_t		pad4;
	uint64_t		pad5;
	uint64_t		pad6;
};

struct niu_state {
	struct niu_mapreg	mapreg[NUM_VINTRS];
};

extern void niu_init(void);
extern void niu_reset(void);
extern void xaui_reset(void);

#endif /* !_ASM */

#define	NIU_INO_RXDMA_BASE	0
#define	NIU_INO_TXDMA_BASE	16
#define	NIU_INO_MIF_BASE	32
#define	NIU_INO_MAC_BASE	33
#define	NIU_INO_ERR_BASE	35

/*
 * XXX this should come from the MD, no?
 */
#define	NIU_DEVINST		0x2

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_NIU_H */
