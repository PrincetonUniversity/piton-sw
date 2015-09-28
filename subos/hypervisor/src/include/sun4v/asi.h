/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: asi.h
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

#ifndef _SUN4V_ASI_H
#define	_SUN4V_ASI_H

#pragma ident	"@(#)asi.h	1.6	07/07/17 SMI"

#ifdef __cplusplus
extern "C" {
#endif


/*
 * sun4v ASI definitions
 */
#define	ASI_REAL	0x14	/* Real-addressed memory */
#define	ASI_REAL_IO	0x15	/* Real-addressed I/O */
#define	ASI_REAL_L	0x1c	/* Real-addressed memory, little-endian */
#define	ASI_REAL_IO_L	0x1d	/* Real-addressed I/O, little-endian */
#define	ASI_SCRATCHPAD	0x20	/* Scratchpad registers */
#define	ASI_MMU		0x21   	/* MMU registers */
#define	ASI_QUEUE	0x25	/* Queue registers */
#define	ASI_REAL_QLDD	0x26	/* Real-addressed quad-ldd */
#define	ASI_REAL_QLDD_L	0x2e	/* Real-addressed quad-ldd, little-endian */

/*
 * 8x8-byte block load/store
 */
#define	ASI_BLK_P	0xf0	/* Primary address space */
#define	ASI_BLK_S	0xf1	/* Secondary address space */
#define	ASI_BLK_PL	0xf8	/* Primary address space, little-endian */
#define	ASI_BLK_SL	0xf9	/* Secondary address space, little-endian */

/*
 * sun4v ASR definitions
 */
#define	SOFTINT_SET	%asr20
#define	SOFTINT_CLR	%asr21
#define	PERFCNTRCTRL	%asr16	/* performance counter control */
#define	SOFTINT		%asr22	/* softint register */
#define	TICKCMP		%asr23	/* tick-compare */
#define	STICK		%asr24	/* system tick register */
#define	STICKCMP	%asr25	/* stick-compare */

#define	SOFTINT_SM_BIT	(1 << 16)

/*
 * Processor Interrupt Levels
 */
#define	PIL_15		0xf
#define	PIL_14		0xe
#define	PIL_13		0xd
#define	PIL_12		0xc
#define	PIL_11		0xb
#define	PIL_10		0xa
#define	PIL_9		0x9
#define	PIL_8		0x8
#define	PIL_7		0x7
#define	PIL_6		0x6
#define	PIL_5		0x5
#define	PIL_4		0x4
#define	PIL_3		0x3
#define	PIL_2		0x2
#define	PIL_1		0x1
#define	PIL_0		0x0

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_ASI_H */
