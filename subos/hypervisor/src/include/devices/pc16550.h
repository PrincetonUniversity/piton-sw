/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: pc16550.h
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
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _PC16550_H
#define _PC16550_H

#pragma ident	"@(#)pc16550.h	1.3	04/07/21 SMI"

/*
 * Hypervisor UART console definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	RBR_ADDR	0x0
#define	THR_ADDR	0x0
#define	IER_ADDR	0x1
#define	IIR_ADDR	0x2
#define	FCR_ADDR	0x2
#define	LCR_ADDR	0x3
#define	MCR_ADDR	0x4
#define	LSR_ADDR	0x5
#define	MSR_ADDR	0x6
#define	SCR_ADDR	0x7
#define	DLL_ADDR	0x0
#define	DLM_ADDR	0x1

/*
 * Some Line Status Register (FCR) bits
 */
#define	LSR_DRDY	0x1
#define	LSR_BINT	0x10
#define	LSR_THRE	0x20
#define	LSR_TEMT	0x40

/*
 * Some FIFO Control Register (FCR) bits
 */
#define	FCR_FIFO_ENABLE	0x1
#define	FCR_RCVR_RESET	0x2
#define	FCR_XMIT_RESET	0x4

/*
 * Line Control Register settings
 */
#define	LCR_DLAB	0x80
#define	LCR_8N1		0x3

/*
 * Baud rate settings for Divisor Latch Low (DLL) and Most (DLM)
 */
#define	DLL_9600	0xc
#define	DLM_9600	0x0
#endif /* _PC16550_H */
