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

#ifndef _HURON_PLATFORM_FPGA_H_
#define	_HURON_PLATFORM_FPGA_H_

#pragma ident	"@(#)fpga.h	1.5	07/08/16 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	HOST_REGS_BASE(x)	(FPGA_BASE + (MByte(13) + (x)))
#define	FPGA_SRAM_BASE		MByte(14)
#define	FPGA_INTR_BASE		HOST_REGS_BASE(0x18000)

#define	FPGA_Q_SEND		0x18
#define	FPGA_Q_STATUS		0x20

/* Interrupt control */
#define	FPGA_MBOX_INTR_STATUS   0x0
#define	FPGA_MBOX_INTR_ENABLE   0x8
#define	FPGA_MBOX_INTR_DISABLE  0x10
#define	FPGA_OTHER_INTR_STATUS  0x1
#define	FPGA_OTHER_INTR_ENABLE  0x9
#define	FPGA_OTHER_INTR_DISABLE 0x11

#define	FPGA_INT_UART_BIT	0x7

/* MMU IO bypass */
#define	FPGA_UART_BASE		(FPGA_BASE + 0xca0000)
#define	FPGA_UART_LIMIT		(FPGA_UART_BASE + 0x2000)

#define	UART_CLOCK_MULTIPLIER	1 /* For "interim" Niagara1-esque FPGA */

/* BEGIN CSTYLED */
#define FPGA_CLEAR_LDC_INTERRUPTS(scr1, scr2)			\
	setx	FPGA_LDCIN_BASE, scr1, scr2			;\
	ld	[scr2 + FPGA_LDC_RECV_REG], scr1		;\
	st	scr1, [scr2 + FPGA_LDC_RECV_REG]
/* END CSTYLED */

/*
 * FPGA ID register
 */
#define	FPGA_DEVICE_ID			HOST_REGS_BASE(0x0)

#define	FPGA_ID_MINOR_ID_SHIFT		0
#define	FPGA_ID_MINOR_ID_MASK		0x1f
#define	FPGA_ID_MAJOR_ID_SHIFT		5
#define	FPGA_ID_MAJOR_ID_MASK		0x7
#define	FPGA_ID_PLATFORM_ID_SHIFT	8
#define	FPGA_ID_PLATFORM_ID_MASK	0xf
#define	FPGA_ID_DEBUG_ID_SHIFT		12
#define	FPGA_ID_DEBUG_ID_MASK		0x7
#define	FPGA_MIN_MAJOR_ID_RESET_SUPPORT	0x3	/* minimum major value for */
						/* ldoms fpga reset support */

/*
 * FPGA Platform-specific Registers
 * GPIO pcie reset control registers (see 0.7 FPGA PRM)
 */
#define	FPGA_PLATFORM_REGS		(FPGA_BASE + 0xcb0000)

#define	FPGA_LDOM_RESET_CONTROL_OFFSET		0x30
#define	FPGA_LDOM_SLOT_RESET_CONTROL_OFFSET	0x31
#define	FPGA_DEVICE_PRESENT_OFFSET		0x40

#define	FPGA_LDOM_RESET_CONTROL		(FPGA_PLATFORM_REGS + \
					    FPGA_LDOM_RESET_CONTROL_OFFSET)
#define	FPGA_LDOM_SLOT_RESET_CONTROL	(FPGA_PLATFORM_REGS + \
					    FPGA_LDOM_SLOT_RESET_CONTROL_OFFSET)
#define	FPGA_DEVICE_PRESENT		(FPGA_PLATFORM_REGS + \
					    FPGA_DEVICE_PRESENT_OFFSET)
/*
 * Reset control register mask is 8 bits
 * The bit defines are as follows
 *
 * bit name for Huron
 *
 *  0   8533 Reset (switch 0)
 *  1   8533 Reset (switch 1)
 *  2   8533 Reset (switch 2)
 *  3   1068 SAS Reset
 *  4   8111 PCI-e to PCI
 *  5   82571 GBE Reset (device 0)
 *  6   82571 GBE Reset (device 1)
 *  7   USB Reset
 *
 */
#define	FPGA_LDOM_RESET_CONTROL_MASK	0xff
#define	FPGA_LDOM_RESET_CONTROL_DEV_0	(1 << 0)
#define	FPGA_LDOM_RESET_CONTROL_DEV_1	(1 << 1)


/*
 * Reset control 'slot' register mask is 8 bits
 * The bits defines are as follows
 *
 * bit	name for Huron
 *  0	PCI-E Slot 1
 *  1	PCI-E Slot 2
 *  2	PCI-E Slot 3
 *  3	PCI-E Slot 4
 *  4	PCI-E Slot 5
 *  5	PCI-E Slot 6
 *  6	XAUI 0
 *  7	XAUI 1
 */
#define	FPGA_PCIE_SLOT_RESET_CTRL_MASK	0x3f
#define	FPGA_XAUI_SLOT_RESET_CTRL_MASK	0xc0

#ifndef _ASM

struct fpga_cookie {
	uint64_t	status;		/* Interrupt status register */
	uint64_t	enable;		/* Interrupt enable register */
	uint64_t	disable;	/* Interrupt disable register */
	uint8_t		valid;		/* Enabled / Disabled */
	uint8_t		state;		/* Idle / Received / Delivered */
	uint8_t		target;		/* Physical CPU number */
};

extern void fpga_uart_mondo_receive(void);
extern void fpga_uart_intr_getvalid(void);
extern void fpga_uart_intr_setvalid(void);
extern void fpga_uart_intr_getstate(void);
extern void fpga_uart_intr_setstate(void);
extern void fpga_uart_intr_gettarget(void);
extern void fpga_uart_intr_settarget(void);

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _HURON_PLATFORM_FPGA_H_ */
