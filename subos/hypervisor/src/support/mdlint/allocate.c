/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: allocate.c
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

#pragma ident	"@(#)allocate.c	1.1	05/03/31 SMI"

#include <string.h>
#include <malloc.h>
#include <unistd.h>
#include <stdlib.h>

#include "fatal.h"
#include "allocate.h"


/*
 * Simple allocation routines
 */

void *
xmalloc(int size, int linen, char *filen)
{
	void *p;

	if (size <= 0) {
		if (size < 0) {
			fatal("xmalloc of negative size (%d) at %d in %s",
			    linen, filen);
		}
		warning("xmalloc of zero size at %d in %s", linen, filen);
		return (NULL);
	}

	p = malloc(size);
	if (p == NULL)
		fatal("malloc of %d at %d in %s", size, linen, filen);

	return (p);
}


void *
xcalloc(int num, int size, int linen, char *filen)
{
	void *p;

	if (size <= 0 || num <= 0) {
		fatal("xcalloc(%d,%d) : one of number or size is <= 0 "
		    "at line %d of %s", num, size, linen, filen);
	}

	p = calloc(num, size);
	if (p == NULL) {
		fatal("calloc of %d of size %d at %d in %s",
		    num, size, linen, filen);
	}

	return (p);
}



void
xfree(void *p, int linen, char *filen)
{
	if (p == NULL) {
		warning("xfree of NULL pointer at %d in %s", linen, filen);
		return;
	}

	free(p);
}


void *
xrealloc(void *oldp, int size, int linen, char *filen)
{
	void *p;

	if (size <= 0) {
		if (size == 0) {
			xfree(oldp, linen, filen);
			warning("xrealloc to zero size at %d in %s",
			    linen, filen);
			return (NULL);
		}

		fatal("xrealloc to negative size %d at %d in %s",
		    size, linen, filen);
	}

	if (oldp == NULL) {
		p = malloc(size);
	} else {
		p = realloc(oldp, size);
	}
	if (p == NULL)
		fatal("xrealloc failed @ %d in %s", linen, filen);

	return (p);
}



char *
xstrdup(char *strp, int linen, char *filen)
{
	char *p;

	p = strdup(strp);
	if (p == NULL)
		fatal("xstrdup @ %d in %s failed", linen, filen);

	return (p);
}
