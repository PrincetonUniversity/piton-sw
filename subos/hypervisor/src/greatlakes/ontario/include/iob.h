/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: iob.h
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

#ifndef _ONTARIO_IOB_H
#define	_ONTARIO_IOB_H

#pragma ident	"@(#)iob.h	1.5	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <fpga.h>

/*
 * Interrupt Management
 */
#define	IOBBASE		0x9800000000
#define	INT_MAN		0x000
#define	INT_CTL		0x400
#define	INT_VEC_DIS	0x800
#define	PROC_SER_NUM	0x820
#define	CORE_AVAIL	0x830
#define	IOB_FUSE	0x840
#define	J_INT_VEC	0xa00

#define	IOBINT		0x9f00000000
#define	J_INT_DATA0	0x600
#define	J_INT_DATA1	0x700
#define	J_INT_BUSY	0x900	/* step 8 count 32 */
#define	J_INT_ABUSY	0xb00	/* aliased to current strand's J_INT_BUSY */

#define	J_INT_BUSY_BUSY	0x0020
#define	J_INT_BUSY_SRC_MASK 0x0001f

#define	SSI_LOG		0xff00000018
#define	SSI_TIMEOUT	0xff00010088

#define	INT_MAN_BASE		(IOBBASE + INT_MAN)
#define	INT_MAN_STEP		(8)
#define	INT_MAN_DEV_OFF(dev)	((dev) * INT_MAN_STEP)

#define	INT_CTL_BASE		(IOBBASE + INT_CTL)
#define	INT_CTL_STEP		(8)
#define	INT_CTL_DEV_OFF(dev)	((dev) * INT_CTL_STEP)


/*
 * IOB Internal device ids
 */
#define	IOBDEV_SSIERR		1 /* Used for errors */
#define	IOBDEV_SSI		2 /* SSI interrupt from EXT_INT_L pin */

#define	DEV_SSI			IOBDEV_SSI

/*
 * INT_MAN Register
 */
#define	INT_MAN_CPU_SHIFT	8
#define	INT_MAN_CPU_MASK	0x1f
#define	INT_MAN_VEC_MASK	0x3f

/*
 * INT_CTL register
 */
#define	INT_CTL_MASK		0x04
#define	INT_CTL_CLEAR		0x02
#define	INT_CTL_PEND		0x01

/*
 * HW DEBUG Reg support
 */

#define	L2_VIS_CONTROL 	(IOBBASE + 0x1800)
#define	L2_VIS_MASK_A 	(IOBBASE + 0x1820)
#define	L2_VIS_MASK_B 	(IOBBASE + 0x1828)
#define	L2_VIS_CMP_A 	(IOBBASE + 0x1830)
#define	L2_VIS_CMP_B 	(IOBBASE + 0x1838)
#define	L2_TRIG_DELAY 	(IOBBASE + 0x1840)
#define	IOB_VIS_SELECT 	(IOBBASE + 0x1000)

#define	DB_ENET_CONTROL (IOBBASE + 0x2000)
#define	DB_ENET_IDLEVAL (IOBBASE + 0x2008)

#define	DB_JBUS_CONTROL (IOBBASE + 0x2100)
#define	DB_JBUS_MASK 	(IOBBASE + 0x2140)
#define	DB_JBUS_COMPARE (IOBBASE + 0x2148)


/*
 * The Niagara vector dispatch priorities
 */
#define	VECINTR_CPUINERR	63
#define	VECINTR_ERROR_XCALL	62
#define	VECINTR_XCALL		61
#define	VECINTR_SSIERR		60
#define	VECINTR_HVXCALL		58
#define	VECINTR_DEV		31
#define	VECINTR_FPGA		16
#define	VECINTR_VDEV		30
#define	VECINTR_SNET		29

/* BEGIN CSTYLED */
#ifdef NIAGARA_ERRATUM_39
#define	CHECK_NIAGARA_VERSION()					\
	rdhpr   %hver, %g1					;\
	srlx    %g1, VER_MASK_MAJOR_SHIFT, %g1			;\
	and     %g1, VER_MASK_MAJOR_MASK, %g1			;\
	cmp     %g1, 1	/* Check for Niagara 1.x */		;\
	bleu,pt %xcc, hret_ok					;\
	nop
#else
#define	CHECK_NIAGARA_VERSION()
#endif

#define	HALT_STRAND()						\
	CHECK_NIAGARA_VERSION()					;\
	rd      STR_STATUS_REG, %g1				;\
	/*							;\
	 * xor ACTIVE to clear it on current strand		;\
	 */							;\
	wr      %g1, STR_STATUS_STRAND_ACTIVE, STR_STATUS_REG	;\
	/* skid */						;\
	nop							;\
	nop							;\
	nop							;\
	nop

#define FPGA_MBOX_INT_DISABLE(x, scr1, scr2)			\
	setx	FPGA_INTR_BASE, scr1, scr2			;\
	mov	x, scr1						;\
	stub	scr1, [scr2 + FPGA_MBOX_INTR_DISABLE]

#define	CLEAR_INT_CTL_PEND(scr1, scr2)					\
	/*								;\
         * Clear the int_ctl.pend bit by writing it to zero, do not	;\
         * set int_ctl.clear; int_ctl.pend is read-only and cleared by	;\
         * hardware.							;\
         */								;\
	setx    IOBBASE + INT_CTL, scr2, scr1				;\
	stx	%g0, [scr1 + INT_CTL_DEV_OFF(DEV_SSI)]

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _ONTARIO_IOB_H */
