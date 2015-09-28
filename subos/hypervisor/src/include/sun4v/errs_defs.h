/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errs_defs.h
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

#ifndef _SUN4V_ERRS_DEFS_H
#define	_SUN4V_ERRS_DEFS_H

#pragma ident	"@(#)errs_defs.h	1.3	07/05/03 SMI"

/*
 * sun4v cpu/memory error report definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM

struct sun4v_cpu_erpt {
	uint64_t	g_ehdl;		/* error handle in guest */
	uint64_t	g_stick;	/* %stick to guest */
	uint32_t	edesc;		/* error descriptor */
	uint32_t	attr;		/* error attribute */
	uint64_t	addr;		/* address */
	uint32_t	sz;		/* size */
	uint16_t	g_cpuid;	/* CPU ID */
	uint16_t	g_secs;		/* shutdown grace time in seconds */
	uint8_t		asi;		/* ASI value */
	uint8_t		rsvd;		/* filler */
	uint16_t	reg;		/* REG */
	uint32_t	word6;		/* filler */
	uint64_t	word7;		/* filler */
	uint64_t	word8;		/* filler */
};

typedef struct sun4v_cpu_erpt sun4v_cpu_erpt_t;

#endif /* ASM */

/*
 * Error Descriptor values (ENUM)
 */
#define	EDESC_UNDEF			0x0
#define	EDESC_UE_RESUMABLE		0x1
#define	EDESC_PRECISE_NONRESUMABLE	0x2
#define	EDESC_DEFERRED_NONRESUMABLE	0x3
#define	EDESC_WARN_RESUMABLE		0x4	/* Shutdown Warning */
#define	EDESC_FORCED_PANIC		0x5	/* Forced Panic */

/*
 * Error Attributes values (Bit position Mask)
 */
#define	EATTR_CPU		(1 << 0)
#define	EATTR_MEM		(1 << 1)
#define	EATTR_PIO		(1 << 2)
#define	EATTR_IRF		(1 << 3)
#define	EATTR_FRF		(1 << 4)
#define	EATTR_SECS		(1 << 5)
#define	ERR_ATTR_MODE_SHIFT	24
#define	ERR_ATTR_MODE(mode)	((mode) << ERR_ATTR_MODE_SHIFT)

/*
 * Error Execution Mode (Bit position Mask)
 */
#define	ERR_MODE_UNKNOWN	0x0
#define	ERR_MODE_USER		0x1
#define	ERR_MODE_PRIV		0x2
#define	ERR_MODE_RSVD		0x3

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_ERRS_DEFS_H */
