/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: output_text.c
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
 * Copyright 2007 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)output_text.c	1.2	07/06/07 SMI"


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <ctype.h>
#include <strings.h>
#include <inttypes.h>
#include <netinet/in.h>
#include <errno.h>

#include <assert.h>

#include <md/md_impl.h>

#include "basics.h"
#include "allocate.h"
#include "fatal.h"
#include "lexer.h"

#include "dagtypes.h"
#include "outputtypes.h"


#define	ASSERT(_s)	assert(_s)

#define	DBGN(_s)

#if defined(_BIG_ENDIAN)
#define	hton16(_s)	((uint16_t)(_s))
#define	hton32(_s)	((uint32_t)(_s))
#define	hton64(_s)	((uint64_t)(_s))
#define	ntoh16(_s)	((uint16_t)(_s))
#define	ntoh32(_s)	((uint32_t)(_s))
#define	ntoh64(_s)	((uint64_t)(_s))
#else
#error	FIXME: Define byte reversal functions for network byte ordering
#endif





	/*
	 * Output in text format for human use
	 */


#define	BASE_TAG_COUNT	2
#define	LAST_OFFSET	1



void
output_text(FILE *fp)
{
	dag_node_t *dnp;
	int offset;

	fflush(fp);

		/*
		 * Step1: compute the offsets for the start of each node.
		 */

	offset = 0;
	for (dnp = dag_listp; NULL != dnp; dnp = dnp->nextp) {
		dnp->offset = offset;

/* BEGIN CSTYLED */
DBGN(	fprintf(stderr, "Node %d @ %d : %s %s\tprop=%d\n",
		dnp->idx, offset, dnp->typep, dnp->namep,
		dnp->properties.num); );
/* END CSTYLED */

		offset += BASE_TAG_COUNT;
		offset += dnp->properties.num;
	}

	dump_dag_nodes(fp);
}
