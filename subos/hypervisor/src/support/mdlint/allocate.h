/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: allocate.h
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

#ifndef	_ALLOCATE_H_
#define	_ALLOCATE_H_

#pragma ident	"@(#)allocate.h	1.1	05/03/31 SMI"

#ifdef __cplusplus
extern "C" {
#endif

extern void *xmalloc(int size, int line, char *filep);
#define	Xmalloc(_size)	xmalloc(_size, __LINE__, __FILE__)

extern void *xcalloc(int num, int size, int linen, char *filep);
#define	Xcalloc(_num, _type) xcalloc(_num, sizeof (_type), __LINE__, __FILE__)

extern void xfree(void *p, int, char *);
#define	Xfree(_p)	xfree(_p, __LINE__, __FILE__)

extern void *xrealloc(void *, int, int, char *);
#define	Xrealloc(_oldp, _size)	xrealloc(_oldp, _size, __LINE__, __FILE__)

extern char *xstrdup(char *ptr, int linen, char *filen);
#define	Xstrdup(_s)	xstrdup(_s, __LINE__, __FILE__)

#ifdef __cplusplus
}
#endif

#endif /* _ALLOCATE_H_ */
