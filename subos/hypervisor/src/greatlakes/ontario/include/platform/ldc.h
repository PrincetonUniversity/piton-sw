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

#pragma ident	"@(#)ldc.h	1.2	07/05/04 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Location of the SRAM queues
 * XXX - Eventually, we probably want to read this out of the SRAM.
 * For now it is hardcoded between HV and vbsc.
 */
#define	LDC_SRAM_CHANNEL_TXBASE	FPGA_BASE + FPGA_SRAM_BASE + 0x4e0
#define	LDC_SRAM_CHANNEL_RXBASE	FPGA_BASE + FPGA_SRAM_BASE + 0x1c40

/*
 * FPGA mailbox for LDC
 */
#define	FPGA_LDCIN_BASE		FPGA_Q1IN_BASE
#define	FPGA_LDCOUT_BASE	FPGA_Q1OUT_BASE

/*
 * FPGA Interrupts for LDC
 */
#define	IRQ_LDC_IN		IRQ1_QUEUE_IN
#define	IRQ_LDC_OUT		IRQ1_QUEUE_OUT

/*
 * Send the SP an interrupt on the LDC IN channel.
 *
 * target_endpt		target endpoint, preserved (unused)
 * tmp1, tmp2		clobbered
 * status_bit		interrupt type
 */
/* BEGIN CSTYLED */
#define	LDC_SEND_SP_INTR(target_endpt, tmp1, tmp2, status_bit)	\
	.pushlocals;							\
	ROOT_STRUCT(tmp1);						\
	mov	CONFIG_FPGA_STATUS_LOCK, tmp2;				\
	add	tmp1, tmp2, tmp1;	/* address of lock */		\
1:	mov	1, tmp2;						\
	casx	[tmp1], %g0, tmp2;	/* if zero, take lock */	\
	brnz,pn	tmp2, 1b;						\
	nop;								\
	MEMBAR_ENTER;			/* we own the lock here */	\
	setx	FPGA_LDCIN_BASE, tmp1, tmp2;				\
	ldub	[tmp2 + FPGA_Q_STATUS], tmp1;	/* read...	*/	\
	or	tmp1, status_bit, tmp1;		/* modify..	*/	\
	stub	tmp1, [tmp2 + FPGA_Q_STATUS];	/* write	*/	\
	ROOT_STRUCT(tmp1);						\
	mov	CONFIG_FPGA_STATUS_LOCK, tmp2;				\
	add	tmp1, tmp2, tmp1;	/* address of lock */		\
	MEMBAR_EXIT;					       		\
	stx	%g0, [tmp1];		/* release the lock */		\
	.poplocals
/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_LDC_H */
