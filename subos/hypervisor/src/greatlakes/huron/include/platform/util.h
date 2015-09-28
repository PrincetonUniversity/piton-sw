/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: util.h
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

#ifndef _PLATFORM_UTIL_H
#define	_PLATFORM_UTIL_H

#pragma ident	"@(#)util.h	1.1	07/07/09 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/* BEGIN CSTYLED */

/*
 * Cause the CPU to spin in a loop for the specified number of milliseconds
 *
 * Inputs:
 *
 *    msecs - (constant) time value to spin
 *
 */
#define	CPU_MSEC_DELAY(msecs, scr1, scr2, scr3)				\
	.pushlocals							;\
	ROOT_STRUCT(scr1)						;\
	ldx	[scr1 + CONFIG_STICKFREQUENCY], scr1			;\
	brnz,pt scr1, 1f						;\
	nop								;\
	HVABORT(-1, "CONFIG_STICKFREQUENCY is null\r\n")		;\
1:									;\
	set	1000, scr3						;\
	udivx   scr1, scr3, scr1	/* ticks per millisecond */	;\
	setx	msecs, scr3, scr2	/* # of milliseconds to wait */	;\
	mulx    scr1, scr2, scr2	/* delay value in ticks */	;\
	rdpr	%tick, scr1						;\
0:									;\
	rdpr	%tick, scr3						;\
	sub	scr3, scr1, scr3					;\
	cmp	scr3, scr2						;\
	bl	%xcc, 0b						;\
	nop								;\
	.poplocals

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_UTIL_H */
