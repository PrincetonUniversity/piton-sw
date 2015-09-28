/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traps.h
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

#ifndef _TRAPS_H
#define	_TRAPS_H

#pragma ident	"@(#)traps.h	1.6	07/04/18 SMI"

/*
 * Niagara-family trap types
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	MAXTL		6
#define	MAXGL		3

/* Reset traps - not owned by Hypervisor */
#define	TT_POR		0x1	/* power-on reset */
#define	TT_WDR		0x2	/* watchdog reset */
#define	TT_XIR		0x3	/* eXternally-initiated reset */
#define	TT_SIR		0x4	/* software-initiated reset */
#define	TT_RED		0x5	/* RED state exception */

/* Normal hyperprivileged-only traps */
#define	TT_IAE		0xa	/* instruction access error */
#define	TT_PROCERR	0x29	/* internal processor error */
#define	TT_DAE		0x32	/* data access error */
#define	TT_REALMISS	0x3f	/* read translation miss trap */
#define	TT_ASYNCERR	0x40	/* async data error */
#define	TT_HSTICK	0x5e	/* hstick match interrupt */
#define	TT_LEVEL0	0x5f	/* trap level 0 */
#define	TT_VECINTR	0x60	/* interrupt vector trap */
#define	TT_ECC_ERROR	0x63	/* ECC error */
#define	TT_HTRAP_BASE	0x180	/* hypertrap instruction */


/*
 * REVECTOR - revector to a guest's traptable with %tt set to the
 * requested traptype (%g1)
 */
/* BEGIN CSTYLED */
#define	REVECTOR(traptype)				\
	ba,pt	%xcc, revector				;\
	mov	traptype, %g1
/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _TRAPS_H */
