/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: debug.h
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

#ifndef _DEBUG_H
#define	_DEBUG_H

#pragma ident	"@(#)debug.h	1.10	07/09/14 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <legion.h>

#ifndef _ASM
extern uint64_t		hv_debug_flags;
#endif

#define	DEBUG_DBG_PRINT		(1 << 0)
#define	DEBUG_DBGL_PRINT	(1 << 1)
#define	DEBUG_DBGHL_PRINT	(1 << 2)
#define	DEBUG_DBGPE_PRINT	(1 << 3)
#define	DEBUG_DBG2_PRINT	(1 << 4)
#define	DEBUG_DBG3_PRINT	(1 << 5)
#define	DEBUG_DBGINIT_PRINT	(1 << 6)
#define	DEBUG_DBGSVC_PRINT	(1 << 7)
#define	DEBUG_DBGVCPU_PRINT	(1 << 8)
#define	DEBUG_DBGG_PRINT	(1 << 9)
#define	DEBUG_DBGBR_PRINT	(1 << 10)
#define	DEBUG_DBGEQ_PRINT	(1 << 11)
#define	DEBUG_DBG_CWQ_PRINT	(1 << 12)
#define	DEBUG_DBG_MAU_PRINT	(1 << 13)
#define	DEBUG_DBG_NET_PRINT	(1 << 14)

#ifdef DEBUG
#define	DBG(_s)		if (hv_debug_flags & DEBUG_DBG_PRINT) \
		do { _s; } while (0)
#define	DBGL(_s)	if (hv_debug_flags & DEBUG_DBGL_PRINT) \
		do { _s; } while (0)	/* LDCs */
#define	DBGHL(_s)	if (hv_debug_flags & DEBUG_DBGHL_PRINT) \
		do { _s; } while (0)	/* HV LDCs */
#define	DBGPE(_s)	if (hv_debug_flags & DEBUG_DBGPE_PRINT) \
		do { _s; } while (0)	/* PCI-E */
#define	DBG2(_s)	if (hv_debug_flags & DEBUG_DBG2_PRINT) \
		do { _s; } while (0)
#define	DBG3(_s)	if (hv_debug_flags & DEBUG_DBG3_PRINT) \
		do { _s; } while (0)
#define	DBGINIT(_s)	if (hv_debug_flags & DEBUG_DBGINIT_PRINT) \
		do { _s; } while (0)
#define	DBGSVC(_s)	if (hv_debug_flags & DEBUG_DBGSVC_PRINT) \
		do { _s; } while (0)
#define	DBGVCPU(_s)	if (hv_debug_flags & DEBUG_DBGVCPU_PRINT) \
		do { _s; } while (0)
#define	DBGG(_s)	if (hv_debug_flags & DEBUG_DBGG_PRINT) \
		do { _s; } while (0)
#define	DBGBR(_s)	if (hv_debug_flags & DEBUG_DBGBR_PRINT) \
		do { _s; } while (0)	/* PCI-E Bus Reset */
#define	DBGEQ(_s)	if (hv_debug_flags & DEBUG_DBGEQ_PRINT) \
		do { _s; } while (0)	/* PCI-E MSI EQ mapping */
#define	DBG_CWQ(_s)	if (hv_debug_flags & DEBUG_DBG_CWQ_PRINT) \
		do { _s; } while (0)	/* N1/N2 MAU */
#define	DBG_MAU(_s)	if (hv_debug_flags & DEBUG_DBG_MAU_PRINT) \
		do { _s; } while (0)	/* N1/N2 MAU */
#define	DBGNET(_s)	if (hv_debug_flags & DEBUG_DBG_NET_PRINT) \
		do { _s; } while (0)	/* Network */
#else
#define	DBG(_s)
#define	DBGL(_s)
#define	DBGHL(_s)
#define	DBGPE(_s)
#define	DBG2(_s)
#define	DBG3(_s)
#define	DBGINIT(_s)
#define	DBGSVC(_s)
#define	DBGVCPU(_s)
#define	DBGG(_s)
#define	DBGBR(_s)
#define	DBGEQ(_s)
#define	DBG_CWQ(_s)
#define	DBG_MAU(_s)
#define	DBGNET(_s)
#endif

/*
 * Debugging aids
 */

/* BEGIN CSTYLED */
#define	_PRINT_SPINLOCK_ENTER(scr1, scr2, scr3)				\
	.pushlocals							;\
	STRAND_STRUCT(scr2)						;\
	ldub	[scr2 + STRAND_ID], scr2				;\
	inc	scr2			/* lockID = cpuid + 1 */ 	;\
	ROOT_STRUCT(scr1)						;\
	add	scr1, CONFIG_PRINT_SPINLOCK, scr1 /* scr1 = lockaddr */ ;\
1: 	nop; nop; nop; nop;			/* delay */		;\
	mov	scr2, scr3						;\
	casxa	[scr1]0x4, %g0, scr3	/* if zero, write my lockID */	;\
	brnz	scr3, 1b						;\
	  nop								;\
	.poplocals

#define	_PRINT_SPINLOCK_EXIT(scr1)					\
	ROOT_STRUCT(scr1)						;\
	add	scr1, CONFIG_PRINT_SPINLOCK, scr1 /* scr1 = lockaddr */	;\
	stx	%g0, [scr1]
/* END CSTYLED */

/*
 * These PRINT macros clobber %g7
 *
 * XXX - when gl is too high ta 0x13/0x14 which will print "lost message" error
 */

#define	MAX_PRINTTRAP_GL 2

/* BEGIN CSTYLED */
#define _PRINTX(x)		\
	.pushlocals		;\
	rdpr	%gl, %g7	;\
	cmp	%g7, MAX_PRINTTRAP_GL ;\
	bgu,pt	%xcc, 2f	;\
	nop			;\
	mov	%o0, %g7	;\
	mov	x, %o0		;\
	ta	0x14		;\
	mov	%g7, %o0	;\
2:				;\
	.poplocals

#define	_PRINT(s)		\
	.pushlocals		;\
	rdpr	%gl, %g7	;\
	cmp	%g7, MAX_PRINTTRAP_GL ;\
	bgu,pt	%xcc, 2f	;\
	nop			;\
	mov	%o0, %g7	;\
	ba	1f		;\
	  rd	%pc, %o0	;\
	.asciz	s		;\
	.align	4		;\
1:	add	%o0, 4, %o0	;\
	ta	0x13		;\
	mov	%g7, %o0	;\
2:				;\
	.poplocals

#define _PRINT_REGISTER(desc, reg) \
	_PRINT(desc)		;\
	_PRINT(" = 0x")		;\
	_PRINTX(reg)		;\
	_PRINT("\r\n")

/*
 * clobbers %g1-%g4,%g7
 */
#define	_PRINT_NOTRAP(s)	\
	.pushlocals		;\
	ba	1f		;\
	rd	%pc, %g1	;\
2:	.asciz	s		;\
	.align	4		;\
1:	add	%g1, 4, %g1	;\
	ba	puts		;\
	rd	%pc, %g7	;\
	.poplocals

/*
 * clobbers %g1-%g5,%g7
 */
#define	_PRINTX_NOTRAP(x)	\
	mov	x, %g1		;\
	ba	putx		;\
	rd	%pc, %g7

/* END CSTYLED */

#ifdef DEBUG

#define	PRINT(s)			 _PRINT(s)
#define	PRINTX(x)			 _PRINTX(x)
#define	PRINT_REGISTER(d, x)		 _PRINT_REGISTER(d, x)
#define	PRINT_NOTRAP(s)			 _PRINT_NOTRAP(s)
#define	PRINTX_NOTRAP(x)		 _PRINTX_NOTRAP(x)

#define	DEBUG_SPINLOCK_ENTER(s1, s2, s3) _PRINT_SPINLOCK_ENTER(s1, s2, s3)
#define	DEBUG_SPINLOCK_EXIT(s)		 _PRINT_SPINLOCK_EXIT(s)

#else /* !DEBUG */

#define	PRINT(x)
#define	PRINTX(x)
#define	PRINT_REGISTER(d, x)
#define	PRINTX_NOTRAP(x)
#define	PRINT_NOTRAP(x)

#define	DEBUG_SPINLOCK_ENTER(s1, s2, s3)
#define	DEBUG_SPINLOCK_EXIT(s)

#endif /* !DEBUG */

/*
 * The following macros are only intended for messages that
 * should always get printed to the hypervisor console.
 */
#define	HV_PRINT(s)			    _PRINT(s)
#define	HV_PRINTX(x)			    _PRINTX(x)
#define	HV_PRINT_REGISTER(d, x)		    _PRINT_REGISTER(d, x)
#define	HV_PRINT_NOTRAP(s)		    _PRINT_NOTRAP(s)
#define	HV_PRINTX_NOTRAP(x)		    _PRINTX_NOTRAP(x)

#define	HV_PRINT_SPINLOCK_ENTER(s1, s2, s3) _PRINT_SPINLOCK_ENTER(s1, s2, s3)
#define	HV_PRINT_SPINLOCK_EXIT(s)	    _PRINT_SPINLOCK_EXIT(s)

#ifdef __cplusplus
}
#endif

#endif /* _DEBUG_H */
