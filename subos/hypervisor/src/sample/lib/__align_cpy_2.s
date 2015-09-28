/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: __align_cpy_2.s
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
 * Copyright (c) 1997, Sun Microsystems, Inc.
 * All rights reserved.
 */

.ident	"@(#)__align_cpy_2.s 1.1     97/02/10 SMI"

	.file	"__align_cpy_2.s"

/*
 * __align_cpy_2(s1, s2, len)
 *
 * Copy s2 to s1, always copy n bytes.
 * Note: this does not work for overlapped copies, bcopy() does
 *	 This routine is copied from memcpy.s, with all values doubled.
 *	 No attempt has been made to improve the comments or performance.
 *
 */

#include <sys/asm_linkage.h>

!#include "synonyms.h"

	ENTRY(__align_cpy_2)
	cmp	%o0, %o1
	be,pn	%xcc, .done		! Identical addresses--done.
	mov	%o0, %g5		! save des address for return val
	cmp	%o2, 18			! for small counts copy bytes
	ble,pn	%xcc, .dbytecp
	andcc	%o1, 6, %o5		! is src 8-byte aligned
	bz,pn	%xcc, .aldst
	cmp	%o5, 4			! is src 4-byte aligned
	be,pt	%xcc, .s2algn
	cmp	%o5, 6			! src is 2-byte aligned
.s1algn:lduh	[%o1], %o3		! move 2 or 6 bytes to align it
	inc	2, %o1
	sth	%o3, [%g5]		! move 2 bytes to align src
	inc	2, %g5
	bne,pt	%xcc, .s2algn
	dec	2, %o2
	b	.ald			! now go align dest
	andcc	%g5, 6, %o5

.s2algn:lduw	[%o1], %o3		! know src is 4-byte aligned
	inc	4, %o1
	srlx	%o3, 16, %o4
	sth	%o4, [%g5]		! have to do 2-bytes,
	sth	%o3, [%g5 + 2]		! don't know dst alignment
	inc	4, %g5
	dec	4, %o2

.aldst:	andcc	%g5, 6, %o5		! align the destination address
.ald:	bz,pn	%xcc, .w4cp
	cmp	%o5, 4
	bz,pn	%xcc, .w2cp
	cmp	%o5, 6
.w3cp:	ldx	[%o1], %o4
	inc	8, %o1
	srlx	%o4, 48, %o5
	sth	%o5, [%g5]
	bne,pt	%xcc, .w1cp
	inc	2, %g5
	dec	2, %o2
	andn	%o2, 6, %o3		! o3 is aligned word count
	sub	%o1, %g5, %o1		! g5 gets the difference

1:	sllx	%o4, 16, %g1		! save residual bytes
	ldx	[%o1+%g5], %o4
	deccc	8, %o3
	srlx	%o4, 48, %o5		! merge with residual
	or	%o5, %g1, %g1
	stx	%g1, [%g5]
	bnz,pt	%xcc, 1b
	inc	8, %g5
	sub	%o1, 6, %o1		! used two bytes of last word read
	b	7f
	and	%o2, 6, %o2

.w1cp:	srlx	%o4, 16, %o5
	st	%o5, [%g5]
	inc	4, %g5
	dec	6, %o2
	andn	%o2, 6, %o3
	sub	%o1, %g5, %o1		! g5 gets the difference

2:	sllx	%o4, 48, %g1		! save residual bytes
	ldx	[%o1+%g5], %o4
	deccc	8, %o3
	srlx	%o4, 16, %o5		! merge with residual
	or	%o5, %g1, %g1
	stx	%g1, [%g5]
	bnz,pt	%xcc, 2b
	inc	8, %g5
	sub	%o1, 2, %o1		! used six bytes of last word read
	b	7f
	and	%o2, 6, %o2

.w2cp:	ldx	[%o1], %o4
	inc	8, %o1
	srlx	%o4, 32, %o5
	st	%o5, [%g5]
	inc	4, %g5
	dec	4, %o2
	andn	%o2, 6, %o3		! o3 is aligned word count
	sub	%o1, %g5, %o1		! g5 gets the difference
	
3:	sllx	%o4, 32, %g1		! save residual bytes
	ldx	[%o1+%g5], %o4
	deccc	8, %o3
	srlx	%o4, 32, %o5		! merge with residual
	or	%o5, %g1, %g1
	stx	%g1, [%g5]
	bnz,pt	%xcc, 3b
	inc	8, %g5
	sub	%o1, 4, %o1		! used four bytes of last word read
	b	7f
	and	%o2, 6, %o2

.w4cp:	andn	%o2, 6, %o3		! o3 is aligned word count
	sub	%o1, %g5, %o1		! g5 gets the difference

1:	ldx	[%o1+%g5], %o4		! read from address
	deccc	8, %o3			! decrement count
	stx	%o4, [%g5]		! write at destination address
	bg,pt	%xcc, 1b
	inc	8, %g5			! increment to address
	b	7f
	and	%o2, 6, %o2		! number of leftover bytes, if any

	!
	! differenced byte copy, works with any alignment
	!
.dbytecp:
	b	7f
	sub	%o1, %g5, %o1		! g5 gets the difference

4:	sth	%o4, [%g5]		! write to address
	inc	2, %g5			! inc to address
7:	deccc	2, %o2			! decrement count
	bge,a,pt %xcc,4b		! loop till done
	lduh	[%o1+%g5], %o4		! read from address
.done:
	retl
	nop

	SET_SIZE(__align_cpy_2)
