/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ncu.h
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

#ifndef _HURON_NCU_H
#define	_HURON_NCU_H

#pragma ident	"@(#)ncu.h	1.2	07/07/25 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <cmp.h>

/*
 * Niagara2 Non-Cacheable Unit definitions
 */
#define	NCU_BASE		0x8000000000
#define	MONDO_INT_VEC		0xa00

#define	NCUINT			0x8000040000
#define	MONDO_INT_BUSY		0x800	/* step 8 count 64 */
#define	MONDO_INT_ABUSY		0xa00	/* aliased to the current strands */

#define	MONDO_INT_BUSY_BUSY	(1 << 6)
#define	MONDO_INT_ADATA0	0x400
#define	MONDO_INT_ADATA1	0x600

#define	PROC_SER_NUM		0x1000
/*
 * Interrupt Management
 */
#define	INT_MAN			(0x0)
#define	INT_MAN_BASE		(NCU_BASE + INT_MAN)
#define	INT_MAN_REGISTERS	128	/* number of INT MAN registers */
#define	INT_MAN_STEP		(8)
#define	INT_MAN_SHIFT		(3) /* log2(INT_MAN_STEP) */
#define	INT_MAN_DEV_OFF(dev)	((dev) * INT_MAN_STEP)
#define	INT_CTL_DEV_OFF(dev)	((dev) * INT_MAN_STEP)

/*
 * NCU internal device ids
 */
#define	NCUDEV_SSIERR		1 /* Used for errors */
#define	NCUDEV_SSI		2 /* SSI interrupt from EXT_INT_L pin */
/* NIU device ids are 64 + logical device number */

#define	DEV_SSI			NCUDEV_SSI

/*
 * INT_MAN Register
 */
#define	INT_MAN_CPU_SHIFT	8
#define	INT_MAN_CPU_MASK	0x3f
#define	INT_MAN_VEC_MASK	0x3f


/*
 * some vector dispatch priorities
 *
 * N.B. some of the "remaining" vector dispatch priorities 0..35 are
 * reserved for NIU devices.  These aren't really priorities more at
 * identifiers.
 */
#define	VECINTR_CPUINERR	63	/* not used */
#define	VECINTR_ERROR_XCALL	62
#define	VECINTR_XCALL		61
#define	VECINTR_SSIERR		60
#define	VECINTR_DEV		59
#define	VECINTR_VDEV		58
#define	VECINTR_HVXCALL		57
#define	VECINTR_FPGA		36	/* not used */
#define	VECINTR_NIU_HI		35
#define	VECINTR_NIU_LO		0

/* BEGIN CSTYLED */
#define FPGA_MBOX_INT_DISABLE(x, scr1, scr2)				\
	setx	FPGA_INTR_BASE, scr1, scr2			;\
	mov	x, scr1						;\
	stb	scr1, [scr2 + FPGA_MBOX_INTR_DISABLE]

#define	CLEAR_INT_CTL_PEND(scr1, scr2)

/* END CSTYLED */

/*
 * Reset Unit
 */
#define	SUBSYS_RESET	0x8900000838
#define	RESET_NIU	(1 << 0)

#ifdef __cplusplus
}
#endif

#endif /* _HURON_NCU_H */
