/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: __align_cpy_4.s
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

.ident "@(#)__align_cpy_4.s 1.1     97/02/10 SMI"

	.file "__align_cpy_4.s"

/* __align_cpy_4(s1, s2, n)
 *
 * Copy 4-byte aligned source to 4-byte aligned target in multiples of 4 bytes.
 *
 * Input:
 *	o0	address of target
 *	o1	address of source
 *	o2	number of bytes to copy (must be a multiple of 4)
 * Output:
 *	o0	address of target
 * Caller's registers that have been changed by this function:
 *	o1-o5, g1, g5
 *
 * Note:
 *	This helper routine will not be used by any 32-bit compilations.
 *	To do so would break binary compatibility with previous versions of
 *	Solaris.
 *
 * Assumptions:
 *	Source and target addresses are 4-byte aligned.
 *	Bytes to be copied are non-overlapping or _exactly_ overlapping.
 *	The number of bytes to be copied is a multiple of 4.
 *	Call will usually be made with a byte count of more than 4*4 and
 *	less than a few hundred bytes.  Legal values are 0 to MAX_SIZE_T.
 *
 * Optimization attempt:
 *	Reasonable speed for a generic v9.
 */

#include <sys/asm_linkage.h>
 
!#include "synonyms.h"

	ENTRY(__align_cpy_4)
	brz,pn %o2, .done		! Skip out if no bytes to copy.
	cmp	%o0, %o1
	be,pn	%xcc, .done		! Addresses are identical--done.
	and	%o0, 7, %o3		! Is target 8-byte aligned?
	and	%o1, 7, %o4		! Is source 8-byte aligned?
	cmp	%o3, %o4
	bne,pt	%icc, .noton8		! Exactly one of source and target is
	mov	%o0, %g1		!     8-byte aligned.
	brz,pt	%o3, .both8		! Both are 8-byte aligned.
	nop

	ld	[%o1], %o3		! Neither is aligned, so do 4 bytes;
	subcc	%o2, 4, %o2		! then both will be aligned.
	st	%o3, [%g1]
	bz,pn	%xcc, .done
	add	%g1, 4, %g1
	b	.both8
	add	%o1, 4, %o1

! Section of code dealing with case where source and target are both 8-byte
! aligned.  Get and store 16 bytes at a time using ldx and stx.

	.align	32
.both8:					! Both source and target are aligned.
	cmp	%o2, 16
	bl,a,pn %xcc, .chkwd
	cmp	%o2, 8

	sub	%o2, 12, %o2
.loop16a:				! Load and store 16 bytes at a time.
	ldx	[%o1], %o3
	ldx	[%o1+8], %o4
	subcc	%o2, 16, %o2
	stx	%o3, [%g1]
	stx	%o4, [%g1+8]
	add	%o1, 16, %o1
	bg,pt	%xcc, .loop16a		! Have at least 16 bytes left.
	add	%g1, 16, %g1

	addcc	%o2, 12, %o2
	bg,a,pt	%xcc, .chkwd		! Have some remaining bytes.
	cmp	%o2, 8
	retl
	nop

.chkwd:
	bl,a,pn	%xcc, .wrword		! Only 4 bytes left.
	ld	[%o1], %o3

	ldx	[%o1], %o3		! Have 8 or 12, so do 8.
	stx	%o3, [%g1]
	add	%o1, 8, %o1
	add	%g1, 8, %g1
	subcc	%o2, 8, %o2
	bg,a,pn %xcc, .wrword		! Still have four to do.
	ld	[%o1], %o3

	retl
	nop
	
.wrword:				! Copy final word.
	st	%o3, [%g1]

.done:
	retl
	nop

! Section of code where either source or target, but not both, are 8-byte
! aligned.  So, use ld and st instructions rather than trying to copy stuff
! around in registers.

	.align	32			! Ultra cache line boundary.
.noton8:
	add	%o1, %o2, %g5	! Ending address of source.
	andcc	%o2, 15, %o3	! Mod 16 of number of bytes to copy.
	bz,pn	%xcc, .loop16	! Copy odd amounts first, then multiples of 16.
	cmp	%o3, 4
	bz,pn	%xcc, .mod4
	cmp	%o3, 8
	bz,pn	%xcc, .mod8
	cmp	%o3, 12
	bz,pt	%xcc, .mod12
	nop
	illtrap	0		! Size not valid.

.mod4:				! Do first 4 bytes, then do multiples of 16.
	lduw	[%o1], %o2
	add	%o1, 4, %o1
	st	%o2, [%g1]
	cmp	%o1, %g5
	bl,a,pt %xcc, .loop16
	add	%g1, 4, %g1
	retl
	nop
.mod8:				! Do first 8 bytes, then do multiples of 16.
	lduw	[%o1], %o2
	lduw	[%o1+4], %o3
	add	%o1, 8, %o1
	st	%o2, [%g1]
	st	%o3, [%g1+4]
	cmp	%o1, %g5
	bl,a,pt	%xcc, .loop16
	add	%g1, 8, %g1
	retl
	nop
.mod12:				! Do first 12 bytes, then do multiples of 16.
	lduw	[%o1], %o2
	lduw	[%o1+4], %o3
	lduw	[%o1+8], %o4
	add	%o1, 12, %o1
	st	%o2, [%g1]
	st	%o3, [%g1+4]
	st	%o4, [%g1+8]
	cmp	%o1, %g5
	bl,a,pt	%xcc, .loop16
	add	%g1, 12, %g1
	retl
	nop
	.align	32			! Ultra cache line boundary.
.loop16:				! Do multiples of 16 bytes.
	lduw	[%o1], %o2
	lduw	[%o1+4], %o3
	lduw	[%o1+8], %o4
	lduw	[%o1+12], %o5
	add	%o1, 16, %o1
	st	%o2, [%g1]
	st	%o3, [%g1+4]
	cmp	%o1, %g5
	st	%o4, [%g1+8]
	st	%o5, [%g1+12]
	bl,a,pt	%xcc, .loop16
	add	%g1, 16,%g1
	retl			! Target address is already in o0.
	nop

	SET_SIZE(__align_cpy_4)
