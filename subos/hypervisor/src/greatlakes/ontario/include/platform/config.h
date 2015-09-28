/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: config.h
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

#ifndef _PLATFORM_CONFIG_H
#define	_PLATFORM_CONFIG_H

#pragma ident	"@(#)config.h	1.35	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	NCORES			8		/* #cores/chip */
#define	NSTRANDS_PER_CORE	4		/* Must be power of 2 */
#define	NSTRANDS_PER_CORE_MASK	(NSTRANDS_PER_CORE - 1)
#define	NSTRANDS		(NCORES * NSTRANDS_PER_CORE)
#define	LOG2_NSTRANDS		5		/* log2(NSTRANDS) */
#define	STRANDID_2_COREID_SHIFT	2		/* log2(NSTRANDS_PER_CORE) */
#define	STRANDID_2_CORE_IDX_MASK	0x3	/* Idx offset of cpu in core */
#define	CPUID_2_COREID_SHIFT	2		/* log2(NCPUS_PER_CORE) */
#define	CORE_MASK		0xf

/*
 * Maximum number of MA (crypto - modular arithmetic) units per
 * Niagara chip, 1 per core.
 */
#define	NMAUS			NCORES
#define	NSTRANDS_PER_MAU	NSTRANDS_PER_CORE
#define	NSTRANDS_PER_MAU_MASK	(NSTRANDS_PER_CORE - 1)

/*
 * Crypto code is common so to enable build we give N1 a dummy CWQ
 */
#define	NCWQS			2

#ifndef _ASM

struct machconfig {
	void		*maus;	/* pointer to base of maus array */
	void		*cwqs;	/* pointer to base of cwqs array */
};

#ifdef CONFIG_CRYPTO
extern struct mau maus[];
extern struct cwq cwqs[];
#endif /* CONFIG_CRYPTO */

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_CONFIG_H */
