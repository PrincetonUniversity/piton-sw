/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: support.h
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

#ifndef	_SUPPORT_H_
#define	_SUPPORT_H_

#pragma ident	"@(#)support.h	1.6	07/05/03 SMI"


#ifdef __cplusplus
extern "C" {
#endif

#include <abort.h>
#include <debug.h>

#ifdef	_ASM
#define	xULL(_x)	(_x)
#else
#define	xULL(_x)	(_x##ull)
#endif

#ifndef _ASM

typedef enum {
	false = 0,
	true = (!false)
} bool_t;

extern void c_puts(char *s);
extern void c_printf(char *str, ...);
extern void c_putn(uint64_t val, int base);
extern void c_bzero(void *ptr, uint64_t size);
extern void c_memcpy(void *dest, void *src, uint64_t size);
extern void c_usleep(uint64_t usecs);
extern void hvabort(char *msgp);
extern void c_hvabort();

#define	ntoh8(_x)	(_x)	/* FIXME: check endianess */
#define	ntoh16(_x)	(_x)	/* FIXME: check endianess */
#define	ntoh32(_x)	(_x)	/* FIXME: check endianess */
#define	ntoh64(_x)	(_x)	/* FIXME: check endianess */
#define	hton8(_x)	(_x)	/* FIXME: check endianess */
#define	hton16(_x)	(_x)	/* FIXME: check endianess */
#define	hton32(_x)	(_x)	/* FIXME: check endianess */
#define	hton64(_x)	(_x)	/* FIXME: check endianess */

#ifdef DEBUG /* { */

#define	ASSERT(_x)							\
	do {								\
		if (!(_x)) {						\
			c_printf("Assert failed: %s, file %s, "		\
			    "line %d\n", #_x, __FILE__, __LINE__);	\
			c_hvabort();			\
		}							\
	} while (0)

#else /* } { */
#define	ASSERT(_x)
#endif /* } */

void		*reloc_ptr(void *ptr);
uint32_t	c_cas32(uint32_t *ptr, uint32_t compval, uint32_t stval);
uint64_t	c_cas64(uint64_t *ptr, uint64_t compval, uint64_t stval);
uint64_t	c_atomic_swap64(uint64_t *ptr, uint64_t stval);

void		*c_mystrand();
uint64_t	c_get_stick();
	/* Get the cycle count from stick; mask off npt bit */
#define	GET_STICK_TIME() (c_get_stick() & 0x7fffffffffffffffull)


#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif	/* _SUPPORT_H_ */
