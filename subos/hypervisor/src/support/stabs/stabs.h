/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: stabs.h
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
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").
 * You may not use this file except in compliance with the License.
 *
 * You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
 * or http://www.opensolaris.org/os/licensing.
 * See the License for the specific language governing permissions
 * and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at usr/src/OPENSOLARIS.LICENSE.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright 2006 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SYS_STABS_H
#define	_SYS_STABS_H

#pragma ident	"@(#)stabs.h	1.1	06/10/26 SMI"

#include <stdio.h>
#include <setjmp.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

#define	MAXLINE	8192

#define	BUCKETS	128

struct node {
	char *name;
	char *format;
	char *format2;
	struct child *child;
};

struct	child {
	char *name;
	char *format;
	struct child *next;
};

#define	HASH(NUM)		((int)(NUM & (BUCKETS - 1)))

enum type {
	INTRINSIC,
	POINTER,
	ARRAY,
	FUNCTION,
	STRUCT,
	UNION,
	ENUM,
	FORWARD,
	TYPEOF,
	VOLATILE,
	CONST
};

	/* Flags are ored together */
typedef enum {
	Intr_unknown = 0x0,
	Intr_unsigned = 0x1,
	Intr_signed = 0x2,
	Intr_char = 0x4
} intr_flags_t;

struct tdesc {
	char	*name;
	struct	tdesc *next;
	enum	type type;
	int	size;
	union {
		intr_flags_t flags;	/* signed / unsigned / [u]char */
		struct	tdesc *tdesc;		/* *, f , to */
		struct	ardef *ardef;		/* ar */
		struct members {		/* s, u */
			struct	mlist *forw;
			struct	mlist *back;
		} members;
		struct  elist *emem; 		/* e */
	} data;
	int	id;
	struct tdesc *hash;
};

struct elist {
	char	*name;
	int	number;
	struct elist *next;
};

struct element {
	struct tdesc *index_type;
	int	range_start;
	int	range_end;
};

struct ardef {
	struct tdesc	*contents;
	struct element	*indices;
};

struct mlist {
	int	offset;
	int	size;
	char	*name;
	struct	mlist *next;
	struct	mlist *prev;
	struct	tdesc *fdesc;		/* s, u */
};

struct model_info {
	char *name;
	size_t pointersize;
	size_t charsize;
	size_t shortsize;
	size_t intsize;
	size_t longsize;
};

extern struct tdesc *lookupname(char *);
extern void parse_input(void);
extern char *convert_format(char *format, char *dfault);
extern struct child *find_child(struct node *np, char *w);
extern char *uc(const char *s);

extern boolean_t error;
extern struct model_info *model;

#ifdef __cplusplus
}
#endif

#endif	/* _SYS_STABS_H */
