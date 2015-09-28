/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: squander.c
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

#pragma ident	"@(#)squander.c	1.1	06/10/26 SMI"

#include <unistd.h>
#include <math.h>
#include "stabs.h"

void squander_do_sou(struct tdesc *tdp, struct node *np);
void squander_do_enum(struct tdesc *tdp, struct node *np);
void squander_do_intrinsic(struct tdesc *tdp, struct node *np);

void
squander_do_intrinsic(struct tdesc *tdp, struct node *np)
{
}

void
squander_do_sou(struct tdesc *tdp, struct node *np)
{
	struct mlist *mlp;
	size_t msize = 0;
	unsigned long offset;

	if (np->name == NULL)
		return;
	if (tdp->type == UNION)
		return;

	offset = 0;
	for (mlp = tdp->data.members.forw; mlp != NULL; mlp = mlp->next) {
		if (offset != (mlp->offset / 8)) {
			printf("%lu wasted bytes before %s.%s (%lu, %lu)\n",
			    (mlp->offset / 8) - offset,
			    np->name,
			    mlp->name == NULL ? "(null)" : mlp->name,
			    offset, mlp->offset / 8);
		}
		msize += (mlp->size / 8);
		offset = (mlp->offset / 8) + (mlp->size / 8);
	}

	printf("%s: sizeof: %lu  total: %lu  wasted: %lu\n", np->name,
	    tdp->size, msize, tdp->size - msize);
}

void
squander_do_enum(struct tdesc *tdp, struct node *np)
{
}
