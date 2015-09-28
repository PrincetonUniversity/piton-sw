/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traps.s
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

	.ident	"@(#)traps.s	1.10	07/04/22 SMI"

	.file	"trap.s"

#include <sys/privregs.h>
#include <sys/asm_linkage.h>
#include <hypervisor.h>
#include <sys/stack.h>

#define NWINDOWS	8

#if defined(lint)
void
watchdog(void)
{
}
#else
	ENTRY(watchdog)
	mov	1, %o0
	mov	API_EXIT, %o5
	ta	CORE_TRAP
	illtrap
	SET_SIZE(watchdog)
#endif /* lint */

#if defined(lint)
void
xir(void)
{
}
#else
	ENTRY(xir)
	mov	2, %o0
	mov	API_EXIT, %o5
	ta	CORE_TRAP
	illtrap
	SET_SIZE(xir)
#endif /* lint */

#if defined(lint)
void
__badtrap(void)
{
}
#else
	ENTRY(__badtrap)
	save	%sp, -SA(MINFRAME+(30*8)), %sp ! Room for uint64_t n[30]

	rdpr	%tpc, %o0;	stx	%o0, [%o6+STACK_BIAS+MINFRAME+(8*24)]	! %TPC
	rdpr	%tnpc, %o0;	stx	%o0, [%o6+STACK_BIAS+MINFRAME+(8*25)]	! %TNPC
	rdpr	%tstate, %o0;	stx	%o0, [%o6+STACK_BIAS+MINFRAME+(8*26)]	! %TSTATE
	rdpr	%tl, %o0;	stb	%o0, [%o6+STACK_BIAS+MINFRAME+(8*27)+0]	! %TL
	rdpr	%tt, %o0;	stb	%o0, [%o6+STACK_BIAS+MINFRAME+(8*27)+1]	! %TT
	rdpr	%pil, %o0;	stb	%o0, [%o6+STACK_BIAS+MINFRAME+(8*27)+2]	! %PIL
	rdpr	%gl, %o0;	stb	%o0, [%o6+STACK_BIAS+MINFRAME+(8*27)+3]	! %GL

	cmp	%o0, 2
	bne,a	0f
	stx	%g0, [%o6+STACK_BIAS+MINFRAME+(8*16)]
	stx	%g1, [%o6+STACK_BIAS+MINFRAME+(8*17)]
	stx	%g2, [%o6+STACK_BIAS+MINFRAME+(8*18)]
	stx	%g3, [%o6+STACK_BIAS+MINFRAME+(8*19)]
	stx	%g4, [%o6+STACK_BIAS+MINFRAME+(8*20)]
	stx	%g5, [%o6+STACK_BIAS+MINFRAME+(8*21)]
	stx	%g6, [%o6+STACK_BIAS+MINFRAME+(8*22)]
	stx	%g7, [%o6+STACK_BIAS+MINFRAME+(8*23)]
	wrpr	%g0, 1, %gl
0:	stx	%g0, [%o6+STACK_BIAS+MINFRAME+(8* 8)]
	stx	%g1, [%o6+STACK_BIAS+MINFRAME+(8* 9)]
	stx	%g2, [%o6+STACK_BIAS+MINFRAME+(8*10)]
	stx	%g3, [%o6+STACK_BIAS+MINFRAME+(8*11)]
	stx	%g4, [%o6+STACK_BIAS+MINFRAME+(8*12)]
	stx	%g5, [%o6+STACK_BIAS+MINFRAME+(8*13)]
	stx	%g6, [%o6+STACK_BIAS+MINFRAME+(8*14)]
	stx	%g7, [%o6+STACK_BIAS+MINFRAME+(8*15)]
	wrpr	%g0, %gl
	stx	%g0, [%o6+STACK_BIAS+MINFRAME+(8*0)]
	stx	%g1, [%o6+STACK_BIAS+MINFRAME+(8*1)]
	stx	%g2, [%o6+STACK_BIAS+MINFRAME+(8*2)]
	stx	%g3, [%o6+STACK_BIAS+MINFRAME+(8*3)]
	stx	%g4, [%o6+STACK_BIAS+MINFRAME+(8*4)]
	stx	%g5, [%o6+STACK_BIAS+MINFRAME+(8*5)]
	stx	%g6, [%o6+STACK_BIAS+MINFRAME+(8*6)]
	stx	%g7, [%o6+STACK_BIAS+MINFRAME+(8*7)]

	wrpr	%g0, 15, %pil
	setn	badtrap, %g2, %g1
	add	%g1, 4, %g2
	wrpr	%g1, %tpc
	wrpr	%g2, %tnpc
	add	%o6, STACK_BIAS+MINFRAME, %o0
	rdpr	%tstate, %g1
	andn	%g1, 0x3f, %g1
	rdpr	%cwp, %g2
	wrpr	%g1, %g2, %tstate
	retry
	SET_SIZE(__badtrap)
#endif /* lint */

#if defined(lint)
void
rtt(void *ti)
{
}
#else
	ENTRY(rtt)
	ldx	[%o0+(8*0)], %g0
	ldx	[%o0+(8*1)], %g1
	ldx	[%o0+(8*2)], %g2
	ldx	[%o0+(8*3)], %g3
	ldx	[%o0+(8*4)], %g4
	ldx	[%o0+(8*5)], %g5
	ldx	[%o0+(8*6)], %g6
	ldx	[%o0+(8*7)], %g7
	ldub	[%o0+(8*27)+0], %o1; wrpr	%o1, %tl
	ldub	[%o0+(8*27)+3], %o1; wrpr	%o1, %gl
	cmp	%o1, 2
	bne,a	0f
	ldx	[%o0+(8*16)], %g0
	ldx	[%o0+(8*17)], %g1
	ldx	[%o0+(8*18)], %g2
	ldx	[%o0+(8*19)], %g3
	ldx	[%o0+(8*20)], %g4
	ldx	[%o0+(8*21)], %g5
	ldx	[%o0+(8*22)], %g6
	ldx	[%o0+(8*23)], %g7
	wrpr	%g0, 1, %gl
0:	ldx	[%o0+(8* 8)], %g0
	ldx	[%o0+(8* 9)], %g1
	ldx	[%o0+(8*10)], %g2
	ldx	[%o0+(8*11)], %g3
	ldx	[%o0+(8*12)], %g4
	ldx	[%o0+(8*13)], %g5
	ldx	[%o0+(8*14)], %g6
	ldx	[%o0+(8*15)], %g7
	ldx	[%o0+(8*24)], %o1; wrpr	%o1, %tpc
	ldx	[%o0+(8*25)], %o1; wrpr	%o1, %tnpc
	ldx	[%o0+(8*26)], %o1; wrpr	%o1, %tstate
	restore
	retry
	SET_SIZE(rtt)
#endif /* lint */

#if defined(lint)
void
por(void)
{
}
#else
	ENTRY(por)
	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl
	wrpr	%g0, NWINDOWS-2, %cansave
	wrpr	%g0, NWINDOWS-1, %cleanwin
	wrpr	%g0, 0, %canrestore
	wrpr	%g0, 0, %otherwin
	wrpr	%g0, 0, %cwp
	wrpr	%g0, 0, %wstate
	wr	%g0, %y
	wrpr	%g0, 0xf, %pil

	! Establish API version
	call	api_version_init
	nop

	! Figure out RA base
	setn	traptable0, %g2, %g1
	wrpr	%g1, %tba
	setn	0f, %g3, %g2
0:	rd	%pc, %g3
	sub	%g2, %g1, %g1
	sub	%g3, %g1, %g1	! %g1 = RA base

	! Take over the MMU
	call	mmu_init
	mov	%g1, %o0

	! Setup env. for C and goto main()
	ba,a	start
	nop
	SET_SIZE(por)
#endif /* lint */
