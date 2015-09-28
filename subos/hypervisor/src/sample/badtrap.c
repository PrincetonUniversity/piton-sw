/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: badtrap.c
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

#pragma ident	"@(#)badtrap.c	1.9	07/06/07 SMI"

#include <stdio.h>
#include <sys/types.h>

#include <sample/sample.h>

struct trapinfo {
	uint64_t	g[3][8];
	uint64_t	tpc;
	uint64_t	tnpc;
	uint64_t	tstate;

	uint8_t		tl;
	uint8_t		tt;
	uint8_t		pil;
	uint8_t		gl;
	uint8_t		align1[4];
};


void
stacktrace(uint64_t fp, uint64_t sp)
{
	uint64_t *ip, *lp, *op;
	int i;

	while (fp & 1) {
		lp = (uint64_t *)((uint64_t)(fp+(2048-1)));
		ip = lp + 8;
		op = ((uint64_t *)(sp+2048-1))+8;
		for (i = 0; i < 8; i++) {
			(void) printf("%%o%d=%016lx ", i, op[i]);
			(void) printf("%%l%d=%016lx ", i, lp[i]);
			(void) printf("%%i%d=%016lx ", i, ip[i]);
			(void) printf("\n");
		}
		(void) printf("\n");
		sp = fp;
		fp = ip[6];

	}
}

void
badtrap(struct trapinfo *ti)
{
	uint64_t fp, sp;
	int i, j;
	(void) printf("TT=%02x\n", ti->tt);
	(void) printf("TL=%02x\n", ti->tl);
	(void) printf("TPC=%016lx\n", ti->tpc);
	(void) printf("TnPC=%016lx\n", ti->tnpc);
	(void) printf("TSTATE=%010lx\n", ti->tstate);
	(void) printf("PIL=%x\n", ti->pil);
	(void) printf("\n");

	flushw();

	printf("GL=0\t\t\tGL=1\t\t\tGL=2\n");
	for (j = 0; j < 7; j++) {
		for (i = 0; i < 3; i++) {
			printf("%%g%d=%016x ", j, ti->g[i][j]);
		}
		printf("\n");
	}

	printf("\n");

	fp = (uint64_t)getfp();
	sp = (uint64_t)getsp();

	stacktrace(fp, sp);

#if 0
	if (ti->tt == 0x68) {
		ti->tpc = ti->tnpc;
		ti->tnpc += 4;
		rtt(ti);
		printf("XXX SHOULD NOT GET HERE!!!\n");
	}
#endif

	while (1) {
		/* LINTED */
	}
}
