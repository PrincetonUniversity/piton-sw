/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ldc.h
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

#ifndef _PLATFORM_LDC_H
#define	_PLATFORM_LDC_H

#pragma ident	"@(#)ldc.h	1.3	07/05/17 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Location of the SRAM queues
 * XXX - Eventually, we probably want to read this out of the SRAM.
 * For now it is hardcoded between HV and vbsc.
 */
#define	LDC_SRAM_CHANNEL_TXBASE	FPGA_BASE + FPGA_SRAM_BASE + 0x460
#define	LDC_SRAM_CHANNEL_RXBASE	FPGA_BASE + FPGA_SRAM_BASE + 0x19a0

/*
 * FPGA mailbox for LDC
 */
#define	FPGA_LDCIN_BASE		FPGA_Q1IN_BASE
#define	FPGA_LDCOUT_BASE	FPGA_Q1OUT_BASE

#define	FPGA_LDC_RECV_REG		0x0
#define	FPGA_LDC_MASK_REG		0x10

/*
 * FPGA_LDC_RECV_REG[14:0]	space available for channel
 *				corresponding to bit
 *
 * FPGA_LDC_RECV_REG[30:16]	data available for channel
 *				corresponding to bit
 *
 * bit[15] unused, reserved for future use
 *
 *
 * FPGA_LDC_RECV_REG[31]	reset all channels
 */
#define	FPGA_LDC_RECV_TX_CHANNELS	15
#define	FPGA_LDC_RECV_TX_CHANNEL_MASK	0x7fff
#define	FPGA_LDC_RECV_TX_CHANNEL_SHIFT	0
#define	FPGA_LDC_RECV_RX_CHANNELS	30
#define	FPGA_LDC_RECV_RX_CHANNEL_MASK	0x7fff0000
#define	FPGA_LDC_RECV_RX_CHANNEL_SHIFT	16

#define	FPGA_LDC_RECV_STATE_CHG_MASK	0x80000000	/* bit 31 */

/*
 * FPGA Interrupts for LDC
 */
#define	IRQ_LDC_OUT	(IRQ1_QUEUE_OUT | IRQ1_QUEUE_IN)

/*
 * Send the SP an interrupt on the LDC IN channel.
 *
 * target_endpt		target endpoint, preserved
 * tmp1, tmp2		clobbered
 * status_bit		interrupt type
 */
/* BEGIN CSTYLED */
#define	LDC_SEND_SP_INTR(target_endpt, tmp1, tmp2, status_bit)	\
	.pushlocals							;\
	setx	FPGA_LDCOUT_BASE, tmp1, tmp2				;\
	mov	status_bit, tmp1					;\
									;\
	cmp	tmp1, SP_LDC_STATE_CHG					;\
	be,a,pn	%xcc, 3f						;\
	  set	FPGA_LDC_RECV_STATE_CHG_MASK, tmp1			;\
									;\
	cmp	tmp1, SP_LDC_DATA					;\
	be,pt	%xcc, 2f						;\
	ldub	[target_endpt + LDC_CHANNEL_IDX], target_endpt		;\
									;\
	/* space available */						;\
	mov	1, tmp1							;\
	add	target_endpt, FPGA_LDC_RECV_TX_CHANNEL_SHIFT, target_endpt	;\
	ba,pt	%xcc, 3f						;\
	sllx	tmp1, target_endpt, tmp1				;\
2:									;\
	/* data available */						;\
	mov	1, tmp1							;\
	add	target_endpt, FPGA_LDC_RECV_RX_CHANNEL_SHIFT, target_endpt	;\
	sllx	tmp1, target_endpt, tmp1				;\
3:									;\
	st	tmp1, [tmp2 + FPGA_LDC_RECV_REG]			;\
	.poplocals
/* END CSTYLED */

#ifndef _ASM

#ifdef CONFIG_SPLIT_SRAM_ERRATUM

typedef struct sp_ldc_sram_ptrs {
	uint64_t	inq_offset;
	uint64_t	inq_data_offset;
	uint64_t	inq_num_packets;
	uint64_t	outq_offset;
	uint64_t	outq_data_offset;
	uint64_t	outq_num_packets;
} sp_ldc_sram_ptrs_t;

#endif	/* CONFIG_SPLIT_SRAM_ERRATUM */

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_LDC_H */
