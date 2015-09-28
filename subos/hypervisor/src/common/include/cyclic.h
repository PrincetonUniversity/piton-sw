/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: cyclic.h
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
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _CYCLIC_H
#define	_CYCLIC_H

#pragma ident	"@(#)cyclic.h	1.4	07/03/23 SMI"

#ifdef __cplusplus
extern "C" {
#endif


/*
 * HStick Interrupt:
 */
#define	N_CB		16		/* # callback array elements */

#define	RETURN_HANDLER_ADDRESS(scr1)	/* relocation independent code */  \
	rd	%pc, scr1		/* handler starts after these */;  \
	jmp	%g7 + SZ_INSTR		/*  three instructions */;	   \
	inc	3 * SZ_INSTR, scr1

/*
 * HStick Interrupt execution times.
 *
 * These are used in an attempt to exit hypervisor to guest code
 * and make some progress before the next interrupt. It is a fail-safe that
 * prevents a runaway callback from totally consuming the strand.
 *
 * Number ticks needed to:
 */
#define	EXIT_NTICK	0x800	/* exit to guest: measured @ 240 - 3f0 */
#define	HSTICK_RET	0x100	/* set new hstick_cmpr & return */

/*
 * Maximum delay time allowed
 */
#define	CYCLIC_MAX_DAYS		367		/* 1 yr + 1 day */


#ifndef _ASM

/*
 * hstick interrupt support:
 *
 * This struct holds the registered handler & number of ticks required
 * to delay, and two args to be passed to the callback handler.
 *
 * Note: handlers that take a long time are not acounted for (yet?).
 */
struct callback {
	uint64_t		tick;		/* delta tick	   */
	uint64_t		handler;	/* handler address */
	uint64_t		arg0;		/* handler args	   */
	uint64_t		arg1;		/*	..	   */
};

struct cyclic {
	uint64_t		t0;		/* absolute time reference  */
	struct callback		cb[N_CB+1];	/* cyclic callback handlers */
	uint64_t		tick;		/* tmp storage		    */
	uint64_t		handler;	/*	..		    */
	uint64_t		arg0;		/*	..		    */
	uint64_t		arg1;		/*	..		    */
};


#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _CYCLIC_H */
