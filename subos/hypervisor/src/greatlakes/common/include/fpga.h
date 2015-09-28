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

#ifndef _FPGA_H_
#define	_FPGA_H_

#pragma ident	"@(#)fpga.h	1.5	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	MByte(x)		(1024 * 1024 * (x))
#define	FPGA_BASE		0xfff0000000

#include <platform/fpga.h>

#define	FPGA_QIN_BASE		HOST_REGS_BASE(0x02000)
#define	FPGA_QOUT_BASE		HOST_REGS_BASE(0x02100)
#define	FPGA_Q1IN_BASE		HOST_REGS_BASE(0x02200)
#define	FPGA_Q1OUT_BASE		HOST_REGS_BASE(0x02300)
#define	FPGA_Q2IN_BASE		HOST_REGS_BASE(0x02400)
#define	FPGA_Q2OUT_BASE		HOST_REGS_BASE(0x02500)
#define	FPGA_Q3IN_BASE		HOST_REGS_BASE(0x02600)
#define	FPGA_Q3OUT_BASE		HOST_REGS_BASE(0x02700)

/* mbox/queue offsets */
#define	FPGA_Q_MTU		0x0
#define	FPGA_Q_SIZE		0x8
#define	FPGA_Q_BASE		0x10

#define	IRQ_QUEUE_IN	0x0001
#define	IRQ_QUEUE_OUT	0x0002
#define	IRQ1_QUEUE_IN	0x0004
#define	IRQ1_QUEUE_OUT	0x0008
#define	IRQ2_QUEUE_IN	0x0010
#define	IRQ2_QUEUE_OUT	0x0020
#define	IRQ3_QUEUE_IN	0x0040
#define	IRQ3_QUEUE_OUT	0x0080

#define	QINTR_ACK	1	/* payload undamaged, accepted */
#define	QINTR_NACK	2	/* payload damaged, rejected */
#define	QINTR_BUSY	4	/* payload undamaged, rejected try later */
#define	QINTR_ABORT	8	/* sync lost, abort */


#ifdef __cplusplus
}
#endif

#endif /* _FPGA_H_ */
