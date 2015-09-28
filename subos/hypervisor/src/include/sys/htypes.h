/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: htypes.h
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

#ifndef _SYS_HTYPES_H
#define	_SYS_HTYPES_H

#pragma ident	"@(#)htypes.h	1.5	07/02/12 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM
/*
 * Basic / Extended integer types
 *
 * The following defines the basic fixed-size integer types.
 */
typedef char			int8_t;
typedef short			int16_t;
typedef int			int32_t;
typedef	long 			int64_t;

typedef unsigned char		uint8_t;
typedef unsigned short		uint16_t;
typedef unsigned int		uint32_t;

#if !defined(__sparcv9)
#error "__sparcv9 compilation environment required"
#endif

typedef unsigned long		uint64_t;

#define	NULL	((void*)0)

#endif /* _ASM */

/*
 * Sizeof definitions
 */
#define	SHIFT_BYTE	0			/* log2(SZ_BYTE)	    */
#define	SZ_BYTE		(1 << SHIFT_BYTE)	/* # bytes in a byte	    */

#define	SHIFT_HWORD	1			/* log2(SZ_HWORD)	    */
#define	SZ_HWORD	(1 << SHIFT_HWORD)	/* # bytes in a half word   */

#define	SHIFT_WORD	2			/* log2(SZ_WORD)	    */
#define	SZ_WORD		(1 << SHIFT_WORD)	/* # bytes in a word	    */

#define	SHIFT_LONG	3			/* log2(SZ_LONG)	    */
#define	SZ_LONG		(1 << SHIFT_LONG)	/* # bytes in a long	    */

#define	SHIFT_INST	2			/* log2(SZ_INST)	    */
#define	SZ_INSTR	(1 << SHIFT_INST)	/* # bytes in an instruction */


#define	SIZEOF_UI64	SZ_LONG		/* # bytes in a unsigned int 64 bit */

/*
 * Limits
 */
#define	UINT64_MAX	(18446744073709551615ULL)

#ifdef __cplusplus
}
#endif

#endif /* _SYS_HTYPES_H */
