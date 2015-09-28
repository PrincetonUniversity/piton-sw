/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: traptable.h
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

#ifndef _TRAPTABLE_H
#define	_TRAPTABLE_H

#pragma ident	"@(#)traptable.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <platform/traptable.h>

/* BEGIN CSTYLED */

#define	TRAP_ALIGN_SIZE		32
#define	TRAP_ALIGN		.align TRAP_ALIGN_SIZE
#define	TRAP_ALIGN_BIG		.align (TRAP_ALIGN_SIZE * 4)


#define	TRAP(ttnum, action) \
	.global	ttnum		;\
	ttnum:			;\
	action			;\
	TRAP_ALIGN

#define	TRAP_NOALIGN(ttnum, action) \
	.global	ttnum		;\
	ttnum:			;\
	action			;\

#define	BIGTRAP(ttnum, action) \
	.global	ttnum		;\
	ttnum:			;\
	action			;\
	TRAP_ALIGN_BIG

#define	GOTO(label)		\
	.global	label		;\
	ba,a	label		;\
	.empty

#define NOT	GOTO(badtrap)
#define	NOT_BIG	NOT NOT NOT NOT
#define	RED	NOT

/*
 * Note: First NOP instruction is for delay slot for preceding
 *	 HCALL() trap table entry
 */
#define	HCALL_BAD			\
	nop				;\
	mov	EBADTRAP, %o0		;\
	done

/*
 * First instruction of GUEST_STRUCT() is safe in delay slot
 * for subsequent HCALL() trap entry
 */
#define	HCALL(idx)					\
	GUEST_STRUCT(%g1)				;\
	ldx	[%g1 + GUEST_HCALL_TABLE], %g1		;\
	set	(idx * API_ENTRY_SIZE), %g2		;\
	ldx	[%g1 + %g2], %g1			;\
	jmp	%g1				

/*
 * Basic register window handling
 */
#define	CLEAN_WINDOW                                            \
        rdpr %cleanwin, %l0; inc %l0; wrpr %l0, %cleanwin       ;\
        clr %l0; clr %l1; clr %l2; clr %l3                      ;\
        clr %l4; clr %l5; clr %l6; clr %l7                      ;\
        clr %o0; clr %o1; clr %o2; clr %o3                      ;\
        clr %o4; clr %o5; clr %o6; clr %o7                      ;\
        retry

/*
 * FIXME:
 * We dont need the 32bit stack handling here since the HV is 64 bit only.
 * could and prob. should use the extra instructions to check for
 * strand stack over and under-runs for safety.
 */
#define SPILL_WINDOW						\
	andcc	%o6, 1, %g0					;\
	be,pt	%xcc, 0f					;\
	wr	%g0, 0x80, %asi					;\
	stxa	%l0, [%o6+V9BIAS64+(0*8)]%asi			;\
	stxa	%l1, [%o6+V9BIAS64+(1*8)]%asi			;\
	stxa	%l2, [%o6+V9BIAS64+(2*8)]%asi			;\
	stxa	%l3, [%o6+V9BIAS64+(3*8)]%asi			;\
	stxa	%l4, [%o6+V9BIAS64+(4*8)]%asi			;\
	stxa	%l5, [%o6+V9BIAS64+(5*8)]%asi			;\
	stxa	%l6, [%o6+V9BIAS64+(6*8)]%asi			;\
	stxa	%l7, [%o6+V9BIAS64+(7*8)]%asi			;\
	stxa	%i0, [%o6+V9BIAS64+(8*8)]%asi			;\
	stxa	%i1, [%o6+V9BIAS64+(9*8)]%asi			;\
	stxa	%i2, [%o6+V9BIAS64+(10*8)]%asi			;\
	stxa	%i3, [%o6+V9BIAS64+(11*8)]%asi			;\
	stxa	%i4, [%o6+V9BIAS64+(12*8)]%asi			;\
	stxa	%i5, [%o6+V9BIAS64+(13*8)]%asi			;\
	stxa	%i6, [%o6+V9BIAS64+(14*8)]%asi			;\
	stxa	%i7, [%o6+V9BIAS64+(15*8)]%asi			;\
	ba	1f						;\
	nop							;\
0:	srl	%o6, 0, %o6					;\
	stda	%i0, [%o6+(0*8)] %asi				;\
	stda	%i2, [%o6+(1*8)] %asi				;\
	stda	%i4, [%o6+(2*8)] %asi				;\
	stda	%i6, [%o6+(3*8)] %asi				;\
	stda	%l0, [%o6+(4*8)] %asi				;\
	stda	%l2, [%o6+(5*8)] %asi				;\
	stda	%l4, [%o6+(6*8)] %asi				;\
	stda	%l6, [%o6+(7*8)] %asi				;\
1:	saved							;\
	retry

#define FILL_WINDOW						\
	andcc	%o6, 1, %g0					;\
	be,pt	%xcc, 0f					;\
	wr	%g0, 0x80, %asi					;\
	ldxa	[%o6+V9BIAS64+(0*8)]%asi, %l0 			;\
	ldxa	[%o6+V9BIAS64+(1*8)]%asi, %l1 			;\
	ldxa	[%o6+V9BIAS64+(2*8)]%asi, %l2 			;\
	ldxa	[%o6+V9BIAS64+(3*8)]%asi, %l3 			;\
	ldxa	[%o6+V9BIAS64+(4*8)]%asi, %l4 			;\
	ldxa	[%o6+V9BIAS64+(5*8)]%asi, %l5 			;\
	ldxa	[%o6+V9BIAS64+(6*8)]%asi, %l6 			;\
	ldxa	[%o6+V9BIAS64+(7*8)]%asi, %l7 			;\
	ldxa	[%o6+V9BIAS64+(8*8)]%asi, %i0 			;\
	ldxa	[%o6+V9BIAS64+(9*8)]%asi, %i1 			;\
	ldxa	[%o6+V9BIAS64+(10*8)]%asi, %i2 			;\
	ldxa	[%o6+V9BIAS64+(11*8)]%asi, %i3 			;\
	ldxa	[%o6+V9BIAS64+(12*8)]%asi, %i4 			;\
	ldxa	[%o6+V9BIAS64+(13*8)]%asi, %i5 			;\
	ldxa	[%o6+V9BIAS64+(14*8)]%asi, %i6 			;\
	ldxa	[%o6+V9BIAS64+(15*8)]%asi, %i7 			;\
	ba	1f						;\
	nop							;\
0:	srl	%o6, 0, %o6					;\
	ldda	[%o6+(0*8)] %asi, %i0				;\
	ldda	[%o6+(1*8)] %asi, %i2				;\
	ldda	[%o6+(2*8)] %asi, %i4				;\
	ldda	[%o6+(3*8)] %asi, %i6				;\
	ldda	[%o6+(4*8)] %asi, %l0				;\
	ldda	[%o6+(5*8)] %asi, %l2				;\
	ldda	[%o6+(6*8)] %asi, %l4				;\
	ldda	[%o6+(7*8)] %asi, %l6				;\
1:	restored						;\
	retry

#define	POR							\
	.global	start_master					;\
	ba,a	start_master					;\
	nop; nop; nop						;\
	.global	start_slave					;\
	ba,a	start_slave					;\
	.empty
	
/*
 * Trap-trace layer trap table.
 */

#define LINK(sym)			 \
	CLEAR_INJECTOR_REG		;\
	rd	%pc, %g7		;\
	ba	sym			;\
	sub	%g7, SIZEOF_CLEAR_INJECTOR_REG, %g7

#define NOTRACE				 		 \
	ba,a	(htraptable+(.-htraptracetable))	;\
	 nop
	
#define	TTRACE(unused, action)		 \
	action				;\
	TRAP_ALIGN

#define	BIG_TTRACE(unused, action)	 \
	action				;\
	TRAP_ALIGN_BIG

#define TTRACE_EXIT(pc, scr1)				 \
	set	(htraptracetable - htraptable), scr1	;\
	neg	scr1					;\
	jmp	pc + scr1				;\
	nop

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _TRAPTABLE_H */
