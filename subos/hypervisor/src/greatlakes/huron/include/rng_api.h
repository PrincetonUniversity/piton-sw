/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: rng_api.h
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

#ifndef	_RNG_API_H
#define	_RNG_API_H

#pragma ident	"@(#)rng_api.h	1.1	07/05/03 SMI"

#ifdef	__cplusplus
extern "C" {
#endif

/*
 * RNG API definitions
 */

#define	RNG_CTL_DELAY_SHIFT		9
#define	RNG_CTL_DELAY_MASK		0xffff
#define	RNG_CTL_BYPASS_SHIFT		8
#define	RNG_CTL_BYPASS_MASK		0x1
#define	RNG_CTL_FREQ_SEL_SHIFT		6
#define	RNG_CTL_FREQ_SEL_MASK		0x3
#define	RNG_CTL_ANLG_SEL_SHIFT		4
#define	RNG_CTL_ANLG_SEL_MASK		0x3
#define	RNG_CTL_MODE_SHIFT		3
#define	RNG_CTL_MODE_MASK		0x1
#define	RNG_CTL_NOISE_SEL_SHIFT		0
#define	RNG_CTL_NOISE_SEL_MASK		0x7

#define	RNG_CTL_MASK			0x1ffffff

#define	RNG_STATE_UNCONFIGURED	0
#define	RNG_STATE_CONFIGURED	1
#define	RNG_STATE_HEALTHCHECK	2
#define	RNG_STATE_ERROR		3

#define	RNG_DATA_MINLEN		8
#define	RNG_DATA_MAXLEN		(128 * 1024)

#ifndef _ASM

struct rng_ctlregs {
	uint64_t	reg0;
	uint64_t	reg1;
	uint64_t	reg2;
	uint64_t	reg3;
};

#endif /* !_ASM */

#ifdef	__cplusplus
}
#endif

#endif	/* _RNG_API_H */
