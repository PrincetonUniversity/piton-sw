/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: legion.h
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

#ifndef _LEGION_H
#define	_LEGION_H

#pragma ident	"@(#)legion.h	1.4	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef DEBUG_LEGION

#define	LEGION_MAGICTRAP_DEBUG		0x70
#define	LEGION_MAGICTRAP_EXIT		0x71
#define	LEGION_MAGICTRAP_GOT_HERE	0x72
#define	LEGION_MAGICTRAP_LOGROTATE	0x74
#define	LEGION_MAGICTRAP_PABCOPY	0x75
#define	LEGION_MAGICTRAP_INSTCOUNT	0x76
#define	LEGION_MAGICTRAP_TRACEON	0x77
#define	LEGION_MAGICTRAP_TRACEOFF	0x78

/* BEGIN CSTYLED */

#define	LEGION_GOT_HERE

#define	LEGION_EXIT(n)					\
	mov	n, %o0					;\
	ta	%xcc, LEGION_MAGICTRAP_EXIT

#define	LEGION_TRACEON					\
	ta	%xcc, LEGION_MAGICTRAP_TRACEON

#define	LEGION_TRACEOFF					\
	ta	%xcc, LEGION_MAGICTRAP_TRACEOFF

/* END CSTYLED */

#else /* !DEBUG_LEGION */

#define	LEGION_GOT_HERE
#define	LEGION_EXIT(n)
#define	LEGION_TRACEON
#define	LEGION_TRACEOFF

#endif /* !DEBUG_LEGION */

#ifdef __cplusplus
}
#endif

#endif /* _LEGION_H */
