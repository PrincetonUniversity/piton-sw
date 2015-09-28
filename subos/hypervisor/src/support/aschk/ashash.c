/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ashash.c
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

#pragma ident	"@(#)ashash.c	1.2	07/06/07 SMI"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#include "basics.h"
#include "internal.h"
#include "parser.h"


static symbol_t *sym_listp, *sym_list_endp;

typedef struct {
	symbol_t	*firstp;
	int		len;
} hash_bucket_t;

#define	INVALID_HASH_KEY	((uint64_t)-1)

#define	HASH_SIZE_BITS	10
#define	HASH_SIZE	(1<<HASH_SIZE_BITS)
#define	HASH_SIZE_MASK	(HASH_SIZE -1)
static hash_bucket_t	*hashp;

static symbol_t *hash_find_key(int idx, uint64_t key, char *namep);
static void hash_key(char *nampep, uint64_t *keyp, int *idxp);



void
init_symbols(void)
{
	sym_listp = NULL;
	sym_list_endp = NULL;

	hashp = calloc(HASH_SIZE, sizeof (hash_bucket_t));
	if (hashp == NULL) {
		fprintf(stderr, "Failed allocating hash space : %s\n",
		    strerror(errno));
		exit(1);
	}
}


symbol_t *
new_sym(sym_flags_t flags, char *namep, int offset, int size)
{
	symbol_t *symp;
	char *namecopyp;

	symp = malloc(sizeof (symbol_t));
	if (symp == NULL) {
		fprintf(stderr, "Failed allocating symbol space : %s\n",
		    strerror(errno));
		exit(1);
	}
	namecopyp = strdup(namep);
	if (namecopyp == NULL) {
		fprintf(stderr, "Failed allocating symbol space : %s\n",
		    strerror(errno));
		exit(1);
	}

	symp->flags = flags;
	symp->namep = namecopyp;
	symp->size = size;
	symp->offset = offset;

	symp->name_key = INVALID_HASH_KEY;
	symp->hash_nextp = NULL;
	symp->nextp = sym_list_endp;
	if (sym_list_endp == NULL)
		sym_listp = symp;
	sym_list_endp = symp;

	return (symp);
}


/*
 * Returns false if failed to insert because
 * of existing duplicate
 */
bool_t
sym_hash_insert(symbol_t *symp)
{
	uint64_t key;
	int idx;
	symbol_t *otherp;

	hash_key(symp->namep, &key, &idx);

	otherp = hash_find_key(idx, key, symp->namep);
	if (otherp != NULL)
		return (false);

	/*
	 * Insert new entry
	 */
	symp->name_key = key;
	symp->hash_nextp = hashp[idx].firstp;
	hashp[idx].firstp = symp;
	hashp[idx].len ++;

	return (true);
}


symbol_t *
hash_find(char *namep)
{
	uint64_t key;
	int idx;

	hash_key(namep, &key, &idx);

	return (hash_find_key(idx, key, namep));
}


static symbol_t *
hash_find_key(int idx, uint64_t key, char *namep)
{
	symbol_t *p;

	for (p = hashp[idx].firstp; p != NULL; p = p->hash_nextp) {
		if (p->name_key == key && strcmp(p->namep, namep) == 0)
			return (p);
	}
	return (NULL);
}


/*
 * can use any old hash ... this is not a particualrly good one,
 * but OK for now.
 */

#define	KEY_SHIFT	5

static void
hash_key(char *namep, uint64_t *keyp, int *idxp)
{
	char *sp;
	uint64_t key;
	uint64_t ch;

	key = 0;
	for (sp = namep; (ch = *sp) != '\0'; sp++) {
		key = (key >> (64 - KEY_SHIFT)) ^ (key << KEY_SHIFT) ^ ch;
	}

	*keyp = key;
	*idxp = key & HASH_SIZE_MASK;
}
