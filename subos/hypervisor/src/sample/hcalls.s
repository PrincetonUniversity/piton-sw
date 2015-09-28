/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcalls.s
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

	.ident	"@(#)hcalls.s	1.7	07/04/22 SMI"

	.file	"hcalls.s"

#include <sys/asm_linkage.h>
#include <sys/privregs.h>
#include <sys/stack.h>

#include <hypervisor.h>

#if defined(lint)
/* ARGSUSED */
int
hv_core_trap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3,
	     uint64_t a4, int func)
{
	return -1;
}
#else
	ENTRY(hv_core_trap)
	ta	CORE_TRAP
	retl
	addc	%g0, 0, %o0
	SET_SIZE(hv_core_trap)
#endif

#if defined(lint)
/* ARGSUSED */
int
hv_fast_trap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3,
	     uint64_t a4, int func)
{
	return -1;
}
#else
	ENTRY(hv_fast_trap)
	ta	FAST_TRAP
	retl
	addc	%g0, 0, %o0
	SET_SIZE(hv_fast_trap)
#endif
	
#if defined(lint)
/* ARGSUSED */
int
hv_trap(uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3,
	     uint64_t a4, int trap)
{
	return -1;
}
#else
	ENTRY(hv_trap)
	ta	%o5
	retl
	addc	%g0, 0, %o0
	SET_SIZE(hv_trap)
#endif

#if 0

	ENTRY(soft_trap)
	subcc	%g0, %g0, %g0
	mov	%o0, %g1
	mov	%o1, %o0
	mov	%o2, %o1
	mov	%o3, %o2
	mov	%o4, %o3
	mov	%o5, %o4
	ta	%g1
	retl
	addc	%g0, 0, %o0
	SET_SIZE(soft_trap)

	ENTRY(htrap)
	subcc	%g0, %g0, %g0
	mov	%o0, %g1
	mov	%o1, %o0
	mov	%o2, %o1
	mov	%o3, %o2
	mov	%o4, %o3
	mov	%o5, %o4
	ta	%g1+0x80
	retl
	addc	%g0, 0, %o0
	SET_SIZE(htrap)

	ENTRY(legion_debug)
	ta	%xcc, 0x70
	retl
	nop
	SET_SIZE(legion_debug)

#endif
