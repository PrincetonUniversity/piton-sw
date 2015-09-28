/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: subr.s
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

	.ident	"@(#)subr.s	1.4	03/11/10 SMI"

	.file	"subr.s"

#include <sys/asm_linkage.h>
#include <sys/privregs.h>
#include <sys/stack.h>

#if defined(lint)
/* ARGSUSED */
int
gettl(void)
{
	return 0;
}
#else
	ENTRY(gettl)
	retl
	rdpr	%tl, %o0
	SET_SIZE(gettl)
#endif

#if defined(lint)
/* ARGSUSED */
void *
getfp(void)
{
	return 0;
}
#else
	ENTRY(getfp)
	retl
	mov	%fp, %o0
	SET_SIZE(getfp)
#endif

#if defined(lint)
/* ARGSUSED */
void *
getsp(void)
{
	return 0;
}
#else
	ENTRY(getsp)
	retl
	mov	%sp, %o0
	SET_SIZE(getsp)
#endif

#if defined(lint)
/* ARGSUSED */
int
getcwp(void)
{
	return 0;
}
#else
	ENTRY(getcwp)
	retl
	rdpr	%cwp, %o0
	SET_SIZE(getcwp)
#endif

#if defined(lint)
/* ARGSUSED */
int
getcansave(void)
{
	return 0;
}
#else

	ENTRY(getcansave)
	retl
	rdpr	%cansave, %o0
	SET_SIZE(getcansave)
#endif

#if defined(lint)
/* ARGSUSED */
void flushw(void) {}
#else

	ENTRY(flushw)
	save	%g0, %g0, %g0
	flushw
	ret
	restore
	SET_SIZE(flushw)
#endif
