/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: basics.h
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
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef	_BASICS_H
#define	_BASICS_H

#pragma ident	"@(#)basics.h	1.1	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__linux__)
#include <linux/types.h>
typedef __uint8_t uint8_t;	/* UG! */
typedef __uint16_t uint16_t;	/* UG! */
typedef __uint32_t uint32_t;	/* UG! */
typedef __uint64_t uint64_t;	/* UG! */
#endif

typedef enum {
	false = 0, true = !false
} bool_t;

#define	SANITY(_s)	do { _s } while (0)
#define	DBG(_s)		do { _s } while (0)

#if defined(_BIG_ENDIAN)
#define	hton16(_s)	((uint16_t)(_s))
#define	hton32(_s)	((uint32_t)(_s))
#define	hton64(_s)	((uint64_t)(_s))
#define	ntoh16(_s)	((uint16_t)(_s))
#define	ntoh32(_s)	((uint32_t)(_s))
#define	ntoh64(_s)	((uint64_t)(_s))
#else
#error	FIXME: Define byte reversal functions for network byte ordering
#endif

#ifdef __cplusplus
}
#endif

#endif /* _BASICS_H */
