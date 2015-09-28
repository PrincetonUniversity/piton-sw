/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: fpga.h
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

#ifndef _NIAGARA_PLATFORM_FPGA_H_
#define	_NIAGARA_PLATFORM_FPGA_H_

#pragma ident	"@(#)fpga.h	1.2	07/05/04 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	HOST_REGS_BASE(x)	(FPGA_BASE + (MByte(12) + (x)))
#define	FPGA_SRAM_BASE		MByte(8)
#define	FPGA_INTR_BASE		HOST_REGS_BASE(0x0a000)

#define	UART_CLOCK_MULTIPLIER	8 /* For Niagara FPGA */
#define	FPGA_UART_BASE		(FPGA_BASE + 0xc2c000)

/* mbox/queue offsets */
#define	FPGA_Q_SEND		0x19
#define	FPGA_Q_STATUS		0x21

/* Interrupt control */
#define	FPGA_MBOX_INTR_STATUS	0x1
#define	FPGA_MBOX_INTR_ENABLE	0x9
#define	FPGA_MBOX_INTR_DISABLE	0x11

/* BEGIN CSTYLED */
#define	FPGA_CLEAR_LDC_INTERRUPTS(scr1, scr2)		\
	setx	FPGA_LDCOUT_BASE, scr1, scr2		;\
	ldub	[scr2 + FPGA_Q_STATUS], scr1		;\
	stub	scr1, [scr2 + FPGA_Q_STATUS]
/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_PLATFORM_FPGA_H_ */
