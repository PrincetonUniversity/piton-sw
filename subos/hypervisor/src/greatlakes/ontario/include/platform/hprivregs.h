/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hprivregs.h
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

#ifndef _PLATFORM_HPRIVREGS_H
#define	_PLATFORM_HPRIVREGS_H

#pragma ident	"@(#)hprivregs.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Maximum number of ASI_QUEUE queue entries
 */
#define	MAX_QUEUE_ENTRIES	256

/*
 * Strand Status Register
 */
#define	STR_STATUS_REG	%asr26

#define	STR_STATUS_STRAND_ACTIVE	1
#define	STR_STATUS_STRAND_ID_SHIFT	8
#define	STR_STATUS_STRAND_ID_MASK	0x3
#define	STR_STATUS_CORE_ID_SHIFT	10
#define	STR_STATUS_CORE_ID_MASK		0x7

#define	STR_STATUS_CPU_ID_SHIFT		STR_STATUS_STRAND_ID_SHIFT
#define	STR_STATUS_CPU_ID_MASK		0x1f

#define	HPSTATE_GUEST	(HPSTATE_ENB)
#define	HTSTATE_GUEST	(HPSTATE_GUEST)

/*
 * TLB DATA IN ASI VA bits
 * (ASI_DTLB_DATA_IN/ASI_ITLB_DATA_IN)
 */
#define	TLB_IN_4V_FORMAT	(1 << 10)
#define	TLB_IN_REAL		(1 << 9)

/*
 * IDLE_ALL_STRAND
 *
 * Sends interrupt IDLE to all strands whose bit is set in CONFIG_STACTIVE,
 * excluding the executing one. CONFIG_STACTIVE, CONFIG_STIDLE are
 * updated.
 *
 * Delay Slot: no
 */
/* BEGIN CSTYLED */
#define	IDLE_ALL_STRAND(strand, scr1, scr2, scr3, scr4) \
	ldx	[strand + STRAND_CONFIGP], scr1	/* ->config*/		;\
	add	scr1, CONFIG_STACTIVE, scr3	/* ->active mask */	;\
	add	scr1, CONFIG_STIDLE, scr4	/* ->idle mask   */	;\
	INT_VEC_DSPCH_ALL(INT_VEC_DIS_TYPE_IDLE, scr3, scr4, scr1, scr2)
/* END CSTYLED */

/*
 * RESUME_ALL_STRAND
 *
 * Sends interrupt RESUME to all strands whose bit is set in CONFIG_STIDLE,
 * excluding the executing one. CONFIG_STACTIVE, CONFIG_STIDLE are
 * updated.
 *
 * Delay Slot: no
 */
/* BEGIN CSTYLED */
#define	RESUME_ALL_STRAND(strand, scr1, scr2, scr3, scr4) \
	ldx	[strand + STRAND_CONFIGP], scr1	/* ->config*/		;\
	add	scr1, CONFIG_STIDLE, scr3	/* ->idle mask   */	;\
	add	scr1, CONFIG_STACTIVE, scr4	/* ->active mask */	;\
	INT_VEC_DSPCH_ALL(INT_VEC_DIS_TYPE_RESUME, scr3, scr4, scr1, scr2)
/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_HPRIVREGS_H */
