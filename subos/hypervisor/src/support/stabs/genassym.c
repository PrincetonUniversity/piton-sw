/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: genassym.c
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

#pragma ident	"@(#)genassym.c	1.1	06/10/26 SMI"

#include <unistd.h>
#include <math.h>
#include "stabs.h"

void genassym_do_sou(struct tdesc *tdp, struct node *np);
void genassym_do_enum(struct tdesc *tdp, struct node *np);
void genassym_do_intrinsic(struct tdesc *tdp, struct node *np);

static void switch_on_type(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);

static void print_intrinsic(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_forward(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_pointer(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_array(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_function(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_union(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_enum(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_forward(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_typeof(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_struct(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static void print_volatile(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level);
static int stabs_log2(unsigned int value);

void
genassym_do_intrinsic(struct tdesc *tdp, struct node *np)
{
	if (np->format != NULL) {
		char *upper = uc(np->format);

		printf("#define\t%s 0x%x\n", upper, tdp->size);

		free(upper);
	}
}


void
genassym_do_sou(struct tdesc *tdp, struct node *np)
{
	struct mlist *mlp;
	struct child *chp;
	char *format;

	if (np->format != NULL) {
		char *upper = uc(np->format);
		int l;

		printf("#define\t%s 0x%x\n", upper, tdp->size);

		if ((np->format2 != NULL) &&
		    (l = stabs_log2(tdp->size)) != -1) {
			printf("#define\t%s 0x%x\n", np->format2, l);
		}

		free(upper);
	}

	/*
	 * Run thru all the fields of a struct and print them out
	 */
	for (mlp = tdp->data.members.forw; mlp != NULL; mlp = mlp->next) {
		/*
		 * If there's a child list, only print those members.
		 */
		if (np->child != NULL) {
			if (mlp->name == NULL)
				continue;
			chp = find_child(np, mlp->name);
			if (chp == NULL)
				continue;
			format = uc(chp->format);
		} else {
			format = NULL;
		}
		if (mlp->fdesc == NULL)
			continue;
		switch_on_type(mlp, mlp->fdesc, format, 0);
		if (format != NULL)
			free(format);
	}
}

void
genassym_do_enum(struct tdesc *tdp, struct node *np)
{
	int nelem = 0;
	struct elist *elp;

	printf("\n");
	for (elp = tdp->data.emem; elp != NULL; elp = elp->next) {
		printf("#define\tENUM_%s 0x%x\n", elp->name, elp->number);
		nelem++;
	}
	printf("%x c-enum .%s\n", nelem, np->name);
}

static void
switch_on_type(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	boolean_t allocated = B_FALSE;

	if (format == NULL) {
		allocated = B_TRUE;
		format = uc(mlp->name);
	}

	switch (tdp->type) {
	case INTRINSIC:
		print_intrinsic(mlp, tdp, format, level);
		break;
	case POINTER:
		print_pointer(mlp, tdp, format, level);
		break;
	case ARRAY:
		print_array(mlp, tdp, format, level);
		break;
	case FUNCTION:
		print_function(mlp, tdp, format, level);
		break;
	case UNION:
		print_union(mlp, tdp, format, level);
		break;
	case ENUM:
		print_enum(mlp, tdp, format, level);
		break;
	case FORWARD:
		print_forward(mlp, tdp, format, level);
		break;
	case TYPEOF:
		print_typeof(mlp, tdp, format, level);
		break;
	case STRUCT:
		print_struct(mlp, tdp, format, level);
		break;
	case VOLATILE:
		print_volatile(mlp, tdp, format, level);
		break;
	default:
		fprintf(stderr, "Switch to Unknown type\n");
		error = B_TRUE;
		break;
	}
	if (allocated)
		free(format);
}


static void
print_forward(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	fprintf(stderr, "%s never defined\n", mlp->name);
	error = B_TRUE;
}

static void
print_typeof(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	switch_on_type(mlp, tdp->data.tdesc, format, level);
}

static void
print_volatile(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	switch_on_type(mlp, tdp->data.tdesc, format, level);
}

static void
print_intrinsic(struct mlist *mlp, struct tdesc *tdp,
    char *format, int level)
{
	if (level != 0) {
		switch (tdp->size) {
		case 1:
			printf("/* ' c@ ' %s */", format);
			break;
		case 2:
			printf("/* ' w@ ' %s */", format);
			break;
		case 4:
			printf("/* ' l@ ' %s */", format);
			break;
		case 8:
			printf("/* ' x@ ' %s */", format);
			break;
		}
	/*
	 * Check for bit field.
	 */
	} else if (mlp->size != 0 &&
	    ((mlp->size % 8) != 0 || (mlp->offset % mlp->size) != 0)) {
		int offset, shift, mask;

		offset = (mlp->offset / 32) * 4;
		shift = 32 - ((mlp->offset % 32) + mlp->size);
		mask = ((int)pow(2, mlp->size) - 1) << shift;

		printf("#define\t%s_SHIFT 0x%x\n", format, shift);
		printf("#define\t%s_MASK 0x%x\n", format, mask);
		printf("#define\t%s_OFFSET 0x%x\n", format, offset);
	} else if (mlp->name != NULL) {
		printf("#define\t%s 0x%x\n", format, mlp->offset / 8);
	}
}

static void
print_pointer(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	if (level != 0) {
		switch (tdp->size) {
		case 1:
			printf("/* ' c@ ' %s */", format);
			break;
		case 2:
			printf("/* ' w@ ' %s */", format);
			break;
		case 4:
			printf("/* ' l@ ' %s */", format);
			break;
		case 8:
			printf("/* ' x@ ' %s */", format);
			break;
		}
	} else {
		printf("#define\t%s 0x%x\n", format, mlp->offset / 8);
	}
}

static void
print_array(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	struct ardef *ap = tdp->data.ardef;
	int items, inc;

	if (level == 0) {
		items = ap->indices->range_end - ap->indices->range_start + 1;
		inc = (mlp->size / items) / 8;
		printf("#define\t%s 0x%x\n", format, mlp->offset / 8);
		printf("#define\t%s_INCR 0x%x\n", format, inc);
	}
}

static void
print_function(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	fprintf(stderr, "function in struct %s\n", tdp->name);
	error = B_TRUE;
}

static void
print_struct(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	if (level != 0)
		printf("/* ' noop ' %s */", format);
	else
		printf("#define\t%s 0x%x\n", format, mlp->offset / 8);
}

static void
print_union(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	if (level != 0)
		printf("/* ' noop ' %s */", format);
	else
		printf("#define\t%s 0x%x\n", format, mlp->offset / 8);
}

static void
print_enum(struct mlist *mlp, struct tdesc *tdp, char *format, int level)
{
	if (level != 0)
		printf("/* ' l@ ' %s */", format);
	else
		printf("#define\t%s 0x%x\n", format, mlp->offset / 8);
}

static int
stabs_log2(unsigned int value)
{
	int log = 1;
	int i;

	for (i = 0; i < sizeof (value) * 8; i++) {
		if ((log << i) == value)
			return (i);
	}
	return (-1);
}
