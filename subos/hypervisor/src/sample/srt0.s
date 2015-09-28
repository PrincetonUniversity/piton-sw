/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: srt0.s
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

	.ident	"@(#)srt0.s	1.7	06/04/28 SMI"

	.file	"srt0.s"

#include <sys/asm_linkage.h>
#include <sys/privregs.h>
#include <sys/stack.h>

#include <hypervisor.h>

#if defined(lint)

/*ARGSUSED*/
void
start(void)
{}
#else
	.seg	".text"
	.align	8
	.global	end
	.global	edata
	.global	main

	.seg	".bss"
	.align	8
!
! Create a stack just below start.
!
#define	STACK_SIZE	0x14000

	.skip	STACK_SIZE
	.ebootstack:			! end --top-- of boot stack

	.seg	".text"

	ENTRY(start)

	save	%sp, -SA(MINFRAME), %sp

	mov	%g1, %i0	! Save RA BASE in %i0

	!
	! Zero the bss [edata to end]
	!
	setn	edata, %g1, %o0
	setn	end, %g1, %i2
	mov	%g0, %o1
!	call	memset
	sub	%i2, %o0, %o2			! size

	restore %g0, %g0, %g0	! Trivial restore

	!
	! Switch to our new stack.
	!
	setn    (.ebootstack - STACK_BIAS), %g1, %o1
	mov	%g0, %i6
	mov	%g0, %i7
	mov	%g0, %o6
	mov	%g0, %o7
	add	%o1, -SA(MINFRAME), %sp

	!
	! Set supervisor mode, interrupt level >= 13, traps enabled
	! We don't set PSTATE_AM even though all our addresses are under 4G.
	!
	wrpr	%g0, 0xf, %pil
	wrpr	%g0, PSTATE_PEF+PSTATE_PRIV+PSTATE_IE, %pstate

	mov	%g0, %o1
	call	main			! main(rabase)
	mov	%g0, %o2

	mov	%g0, %o0
	mov	MACH_EXIT, %o5
	ta	FAST_TRAP
	! print stupid error message here!
	ta	%xcc, 0x72
	ba	.
	nop
	SET_SIZE(start)
#endif	/* lint */
