/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: output_bin.c
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

#pragma ident	"@(#)output_bin.c	1.2	07/06/07 SMI"

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
	 * Currently spec defines namelen to be strlen, not size of entry in
	 * nametable.
	 */
#define	SIZETONAMELEN(_s)	((_s)-1)






	/*
	 * Output in binary format for use in partitions
	 */


	/*
	 * We use this set of structs as a temporary list of the
	 * sub-blocks comprising the data block and the string block.
	 * We tag those that are strings, and search for duplicates
	 * each time we insert the string.
	 */

typedef struct MD_CHUNK md_chunk_t;

struct MD_CHUNK {
	uint8_t		*datap;
	uint32_t	size;
	uint32_t	offset;
	md_chunk_t	*nextp;
};

typedef struct MD_BLK {
	md_chunk_t	*firstp;
	md_chunk_t	*lastp;
	int total_size;
} md_blk_t;


md_blk_t name_blk;
md_blk_t data_blk;


	/* predefines */


static int bin_write(int fh, void *ptrp, int size);

static md_chunk_t *md_add_chunk(md_blk_t *bp, void *ptrp, int size);
static md_chunk_t *md_insert_data(uint8_t *ptrp, int size, int align);
static md_chunk_t *md_insert_name(char *strp);

#define	BASE_TAG_COUNT	2
#define	LAST_OFFSET	1



void
output_bin(FILE *fp)
{
	md_hdr_t mdh;
	dag_node_t *dnp;
	int fh;
	int offset;
	int list_end_offset;
	md_chunk_t *sbp, *nsbp;
	md_element_t mde;
	int data_alignment;

	fflush(fp);
	fh = fileno(fp);

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
	list_end_offset = offset;

		/*
		 * step through the list of nodes and compute the
		 * number of node entries and the size of the data block
		 */

	name_blk.firstp = NULL;
	name_blk.lastp = NULL;
	name_blk.total_size = 0;

	data_blk.firstp = NULL;
	data_blk.lastp = NULL;
	data_blk.total_size = 0;

		/*
		 * FIXME: scan properties to see if we need greater
		 * alignment at start of data block
		 */
	data_alignment = 16;

	for (dnp = dag_listp; NULL != dnp; dnp = dnp->nextp) {
		int i;
		pair_entry_t *pep;

			/* string for node type */
		dnp->name_tmp = (void*)md_insert_name(dnp->typep);

			/*
			 * go find the relevent sub-blocks of
			 * data and property names
			 */

		pep = dnp->properties.listp;
		for (i = 0; i < dnp->properties.num; i++) {
			pep->name_tmp = md_insert_name(pep->namep);

			switch (pep->utype) {
			case PE_string:
				pep->data_tmp =
				    md_insert_data((uint8_t *)pep->u.strp,
				    strlen(pep->u.strp)+1, 8);
				break;

			case PE_data:
				pep->data_tmp =
				    md_insert_data(pep->u.data.buffer,
				    pep->u.data.len, 8);
				break;

			default:;
				/* nada */
			}
			pep ++;
		}
	}

		/*
		 * Carefully align the data segment
		 */

	do {
		int pad;

		pad = name_blk.total_size % data_alignment;

		if (pad != 0) {
			(void) md_add_chunk(&name_blk, NULL,
			    data_alignment - pad);
		}
	} while (0);


		/*
		 * Output noise if needed
		 */
	if (flag_verbose) {
		fprintf(stderr, "Machine description holds %d elements\n",
		    list_end_offset + LAST_OFFSET);
		fprintf(stderr, "node block size = %d bytes\n",
		    MD_ELEMENT_SIZE * (list_end_offset + LAST_OFFSET));
		fprintf(stderr, "name block size = %d bytes\n",
		    name_blk.total_size);
		fprintf(stderr, "data block size = %d bytes\n",
		    name_blk.total_size);
	}


		/*
		 * Prepare the header and write it out
		 */

	mdh.transport_version = hton32(MD_TRANSPORT_VERSION);
	mdh.node_blk_sz = hton32(MD_ELEMENT_SIZE *
	    (list_end_offset + LAST_OFFSET));
	mdh.name_blk_sz = hton32(name_blk.total_size);
	mdh.data_blk_sz = hton32(data_blk.total_size);

	bin_write(fh, &mdh, sizeof (mdh));

		/* Now write out the node block */

	for (dnp = dag_listp; NULL != dnp; dnp = dnp->nextp) {
		int i;
		pair_entry_t *pep;
		uint64_t val;

		memset(&mde, 0, sizeof (mde));

		mde.tag = DT_NODE;

		sbp = (md_chunk_t *)dnp->name_tmp;
		ASSERT(sbp->size < 256);

		mde.namelen = SIZETONAMELEN(sbp->size);
		mde.name = hton32(sbp->offset);

		if (NULL == dnp->nextp) {
			/* index points to END_OF_LIST element */
			val = list_end_offset;
		} else {
			val = dnp->nextp->offset;
		}
		mde.d.prop_idx = hton64(val);

		bin_write(fh, &mde, sizeof (mde));

			/*
			 * Now write out the properties elements
			 */

		pep = dnp->properties.listp;
		for (i = 0; i < dnp->properties.num; i++) {

			sbp = (md_chunk_t *)pep->name_tmp;
			ASSERT(sbp->size < 256);

			memset(&mde, 0, sizeof (mde));
			mde.namelen = SIZETONAMELEN(sbp->size);
			mde.name = hton32(sbp->offset);

			switch (pep->utype) {
			case PE_none:
				fatal("PE_none found in node");
				break;

			case PE_string:
				mde.tag = DT_PROP_STR;
				goto data_elem;
			case PE_data:
				mde.tag = DT_PROP_DAT;
data_elem:;
				sbp = (md_chunk_t *)pep->data_tmp;
				mde.d.prop_data.len = hton32(sbp->size);
				mde.d.prop_data.offset = hton32(sbp->offset);
				break;

			case PE_int:
				mde.tag = DT_PROP_VAL;
				mde.d.prop_val = pep->u.val;
				break;

			case PE_arc:
				mde.tag = DT_PROP_ARC;
				mde.d.prop_idx = hton64(pep->u.dnp->offset);
				break;

			case PE_noderef:
				fatal("PE_noderef found in node");
				break;

			default:
				fatal("unknown property type found %d",
				    pep->utype);
			}
			bin_write(fh, &mde, sizeof (mde));

			pep ++;
		}

		memset(&mde, 0, sizeof (mde));
		mde.tag = DT_NODE_END;
		bin_write(fh, &mde, sizeof (mde));
	}

		/* Terminate the node block output */
	memset(&mde, 0, sizeof (mde));
	mde.tag = DT_LIST_END;
	bin_write(fh, &mde, sizeof (mde));


		/*
		 * Finally let's dump out the name & data sections.
		 */

	for (sbp = name_blk.firstp; NULL != sbp; sbp = sbp->nextp) {
		bin_write(fh, sbp->datap, sbp->size);
	}

	for (sbp = data_blk.firstp; NULL != sbp; sbp = sbp->nextp) {
		bin_write(fh, sbp->datap, sbp->size);
	}

		/*
		 * Now free up the allocated data section stuff.
		 */
	for (sbp = name_blk.firstp; NULL != sbp; sbp = nsbp) {
		nsbp = sbp->nextp;

		Xfree(sbp->datap);
		Xfree(sbp);
	}

	for (sbp = data_blk.firstp; NULL != sbp; sbp = nsbp) {
		nsbp = sbp->nextp;

		Xfree(sbp->datap);
		Xfree(sbp);
	}

		/*
		 * sanity
		 */

	name_blk.firstp = NULL;
	name_blk.lastp = NULL;
	name_blk.total_size = 0;

	data_blk.firstp = NULL;
	data_blk.lastp = NULL;
	data_blk.total_size = 0;
}





static int
bin_write(int fh, void *ptrp, int size)
{
	uint8_t *bp;
	int left;
	int amt;

	for (left = size, bp = ptrp; left > 0; left -= amt, bp += amt) {
loop:;
		amt = write(fh, bp, left);
		if (amt <= 0) {
			if (amt < 0 && EAGAIN == errno) goto loop;
			fatal("Failed writing binary file output");
		}
	}

	return (size);
}








static md_chunk_t *
md_add_chunk(md_blk_t *bp, void *ptrp, int size)
{
	md_chunk_t *cp;

	cp = Xcalloc(1, md_chunk_t);

	cp->datap = Xmalloc(size);
	if (ptrp != NULL) {
		memcpy(cp->datap, ptrp, size);
	} else {
		memset(cp->datap, 0, size);
	}

	cp->size = size;
	cp->offset = bp->total_size;
	cp->nextp = NULL;
	if (NULL == bp->firstp) {
		bp->firstp = cp;
		bp->lastp = cp;
	} else {
		bp->lastp->nextp = cp;
		bp->lastp = cp;
	}
	bp->total_size += size;

	return (cp);
}


static md_chunk_t *
md_insert_data(uint8_t *ptrp, int size, int align)
{
	int pad;

	pad = data_blk.total_size % align;
	if (pad != 0) {
		pad = align-pad;
		(void) md_add_chunk(&data_blk, NULL, pad);
	}

	ASSERT((data_blk.total_size % align) == 0);

	return (md_add_chunk(&data_blk, ptrp, size));
}


static md_chunk_t *
md_insert_name(char *ptrp)
{
	md_chunk_t *sbp;
	int size;

	size = strlen(ptrp)+1;

	for (sbp = name_blk.firstp; NULL != sbp; sbp = sbp->nextp) {
		if (size == sbp->size && memcmp(ptrp, sbp->datap, size) == 0)
				return (sbp);
	}

	return (md_add_chunk(&name_blk, ptrp, size));
}
