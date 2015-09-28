/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: main.c
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

#pragma ident	"@(#)main.c	1.10	07/06/07 SMI"

#include <stdio.h>
#include <stdarg.h>
#include <sys/types.h>
#include <malloc.h>
#include <unistd.h>

#include <sample/sample.h>

#define	KB(n)	((n)*1024)
#define	MB(n)	((n)*KB(1024))

int
main(uint64_t ra)
{
#if LEGION_DEBUG
	int i;
	char *p;
	uint64_t va = ra;
#endif
	(void) printf("Hello World RA BASE = %x\n", ra);

#if LEGION_DEBUG
	legion_debug(-1);
	p = 0x80000000+MB(512);
	*p = 0;
#endif

#if LEGION_DEBUG
	for (i = 0x0; i < 0x80; i++) {
		int rv;
		printf("%x\n", i);
		if (i == 0x00) continue;
		if (i == 0x71) continue;
		if ((rv = htrap(i)) == 0)
			printf("RV=0 for htrap %x\n", i);
		if ((rv = soft_trap(i)) == 0)
			printf("RV=0 for soft_trap %x\n", i);
	}

	map_daddr(va+K(0), ra+MB(0), K(8));
	map_daddr(va+K(0), ra+MB(0), K(64));
	map_daddr(va+M(0), ra+MB(0), M(4));
	map_daddr(va+MB(0), ra+MB(0), M(256));

	p = (char *)ra;

	for (i = 0; i < MB(256) - 1; i += K(4)) {
		printf("VA = %x n = %x\n", &p[i], p[i]);
	}

	while (1) { }
#endif

	return (0);
}
