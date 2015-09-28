/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mdlint.c
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

#pragma ident	"@(#)mdlint.c	1.3	07/06/07 SMI"

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <malloc.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

#include <netinet/in.h>
#include <inttypes.h>


#include <assert.h>

#define	ASSERT(_s)	assert(_s)

#include <md/md_impl.h>

#include "basics.h"
#include "allocate.h"
#include "fatal.h"


	/*
	 * NOTE:
	 * Deliberate attempt to not borrow code and
	 * be able to lint the MD based on the spec.
	 * That way when things get broken in other
	 * pieces of code we dont lint them as correct anyway.
	 */

typedef struct {
	int fh;
	int size;
	caddr_t caddr;

	md_header_t *headerp;
	md_element_t *mdep;
	char *namep;
	uint8_t *datap;

	int node_blk_size;
	int name_blk_size;
	int data_blk_size;

	int element_count;
	int node_count;
} md_t;

struct {
	bool_t	textdump;
} option;



md_t *md_init(char *fnamep);
int md_close(md_t *mdp);
int process_options(int argc, char **argv);
void md_lint(md_t *mdp);
void output_text(md_t *mdp, FILE *fp);
void brief_sanity(md_t *mdp, FILE *fp);
void output_text_data(FILE *fp, char *propp, uint8_t *datap, int len);




int
main(int argc, char **argv)
{
	md_t *mdp;
	int i;

	i = process_options(argc, argv);

	if (i != argc-1) fatal("Machine description filename expected");

	mdp = md_init(argv[i]);
	if (mdp == NULL) fatal("Unable to open MD");

	md_lint(mdp);

	return (0);
}




void
usage(char *namep)
{
	fprintf(stderr, "usage: %s [-t|--text] <mdfile>\n", namep);
	exit(1);
}


int
process_options(int argc, char **argv)
{
	int i;

	for (i = 1; i < argc && argv[i][0] == '-'; i++) {
		if (strcmp(argv[i], "-h") == 0 ||
		    strcmp(argv[i], "--help") == 0) {
			usage(argv[0]);
		} else
		if ((strcmp(argv[i], "-t") == 0) ||
		    (strcmp(argv[i], "--text") == 0)) {
			option.textdump = true;
		} else
		fatal("Unrecognised option %s\n", argv[i]);
	}

	return (i);
}




void
md_lint(md_t *mdp)
{
	if (option.textdump) {
		output_text(mdp, stdout);
		fflush(stdout);
	}

	fflush(stderr);

	brief_sanity(mdp, stderr);
}






void
output_text(md_t *mdp, FILE *fp)
{
	int idx;
	int count;
	bool_t done;

	count = 0;
	done = false;

	for (idx = 0; !done; idx++) {
		md_element_t *np;
		uint32_t stro;
		uint64_t nextidx;
		uint64_t val;
		uint32_t offset;
		uint32_t len;

		np = &(mdp->mdep[idx]);
		switch (np->tag) {
		case DT_LIST_END:
			fprintf(fp, "\t\t/* The end @ 0x%x */\n", idx);
			done = true;
			break;

		case DT_NULL:
			fprintf(fp, "\t\t/* NULL */\n");
			break;

		case DT_NODE:
			nextidx = ntoh64(np->d.prop_idx);
			stro = ntoh32(np->name);

			fprintf(fp, "node %s node_0x%x {\t\t\t/* next "
			    "@ 0x%llx */\n",
			    mdp->namep + stro, idx, nextidx);
			count ++;
			break;

		case DT_NODE_END:
			fprintf(fp, "}\t\t\t\t\t/* @ 0x%x */\n", idx);
			break;

		case DT_PROP_ARC:
			nextidx = ntoh64(np->d.prop_idx);
			stro = ntoh32(np->name);

			fprintf(fp, "\t%s -> node_0x%llx;\n",
			    mdp->namep + stro, nextidx);
			break;

		case DT_PROP_VAL:
			val = ntoh64(np->d.prop_val);
			stro = ntoh32(np->name);

			fprintf(fp, "\t%s = 0x%llx;\t\t/* %lld */\n",
			    mdp->namep + stro, val, val);
			break;

		case DT_PROP_STR:
			offset = ntoh32(np->d.prop_data.offset);
			len = ntoh32(np->d.prop_data.len);
			stro = ntoh32(np->name);

			fprintf(fp, "\t%s = \"%s\";\n",
			    mdp->namep + stro, mdp->datap + offset);
			break;

		case DT_PROP_DAT:
			offset = ntoh32(np->d.prop_data.offset);
			len = ntoh32(np->d.prop_data.len);
			stro = ntoh32(np->name);

			output_text_data(fp, mdp->namep + stro,
			    &(mdp->datap[offset]), len);
			break;

		default:
			fatal("At index %d found unexpected node type %d"
			    " (0x%x : '%c') while searching for nodes",
			    idx, np->tag, np->tag, np->tag);
		}
	}
}




	/*
	 * Data properties are a little special since in some cases
	 * we have an array of strings.
	 * First scan the data looking for legal string characters
	 * and ensuring that there are no null strings and the last
	 * string is correctly terminated
	 */

void
output_text_data(FILE *fp, char *propp, uint8_t *datap, int len)
{
	int i;
	int step;
	bool_t new_string;

		/* array of strings check */

	fprintf(fp, "\t%s = {\n", propp);

	new_string = true;

	for (i = 0; i < len; i++) {
		int ch;

		ch = datap[i];
		if (ch != 0 && (ch < ' ' || ch >= 126))
			goto non_sarray;

		if (ch == '\0') {
				/* back-to-back nulls not allowed */
			if (new_string)
				goto non_sarray;
			new_string = true;
		} else {
			new_string = false;
		}
	}
	if (!new_string)
		goto non_sarray;

		/* looks like safe to assume an array of strings */

	for (i = 0; i < len; i += step) {
		char *p;

		p = ((char *)(datap + i));
		step = strlen(p)+1;

		fprintf(fp, "\t\t\"%s\"%s", p, (i+step) == len ? "\n" : ",\n");
	}
	fprintf(fp, "\t}; \n");

	return;

non_sarray:;

	for (i = 0; i < len-1; i++) {
		fprintf(fp, "%s0x%02x,",
		    ((i&7) == 0) ? "\n\t\t" : " ", datap[i]);
	}
	fprintf(fp, " 0x%02x };\n", datap[i]);
}







void
brief_sanity(md_t *mdp, FILE *fp)
{
	int idx;
	int count;
	bool_t done;
	bool_t in_node;
	int nodeidx;

	count = 0;
	done = false;
	in_node = false;
	nodeidx = -1;

	for (idx = 0; !done; idx++) {
		md_element_t *np;
		uint32_t stro;
		bool_t check_name = false;

		np = &(mdp->mdep[idx]);
		switch (np->tag) {
		case DT_LIST_END:
			done = true;
			break;

		case DT_NULL:
			break;

		case DT_NODE:
			stro = ntoh32(np->name);

			if (in_node)
				fatal("Node element @ 0x%x (%s) "
				    "defined within node @ 0x%x (%s)\n",
				    idx, mdp->namep + stro, nodeidx,
				    mdp->namep +
				    ntoh32(mdp->mdep[nodeidx].name));
			in_node = true;
			nodeidx = idx;
			check_name = true;
			count ++;
			break;

		case DT_NODE_END:
			if (!in_node)
				fatal("Node end element @ 0x%x "
				    "defined outside a node\n", idx);
			in_node = false;
			break;

		case DT_PROP_ARC:
			stro = ntoh32(np->name);
			check_name = true;
			break;

		case DT_PROP_VAL:
			stro = ntoh32(np->name);
			check_name = true;
			break;

		case DT_PROP_STR:
			stro = ntoh32(np->name);
			check_name = true;
			break;

		case DT_PROP_DAT:
			stro = ntoh32(np->name);
			check_name = true;

			break;

		default:
			fatal("At index %d found unexpected node type %d"
			    " (0x%x : '%c') while searching for nodes",
			    idx, np->tag, np->tag, np->tag);
		}

		if (check_name) {
			int nlen;

			nlen = strlen((char *)(mdp->namep + stro));
			if (np->namelen != nlen)
				fatal("Element @ 0x%x (%s): "
				    "name length (%d) doesnt match strlen (%d)"
				    " of name in table",
				    idx, mdp->datap + stro, np->namelen, nlen);
		}
	}
}









md_t *
md_init(char *fnamep)
{
	md_t *mdp;
	struct stat sb;
	int idx, count;

	mdp = (md_t *)Xcalloc(1, md_t);
	if (mdp == NULL)
		return (NULL);

	if (stat(fnamep, &sb) < 0)
		return (NULL);

	if ((sb.st_mode & S_IFMT) != S_IFREG ||
	    sb.st_size < sizeof (md_hdr_t)) {
		errno = EIO;
		return (NULL);
	}

	mdp->fh = open(fnamep, O_RDONLY, 0);
	if (mdp->fh < 0)
		return (NULL);

	mdp->caddr = mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, mdp->fh,
	    (off_t)0);
	if (mdp->headerp == MAP_FAILED) {
		int res;
		res = errno;
		close(mdp->fh);
		mdp->fh = -1;
		errno = res;
		return (NULL);
	}

	mdp->size = sb.st_size;

		/* setup internal structures */
	mdp->headerp = (md_hdr_t *)mdp->caddr;

	mdp->node_blk_size = ntoh32(mdp->headerp->node_blk_sz);
	mdp->name_blk_size = ntoh32(mdp->headerp->name_blk_sz);
	mdp->data_blk_size = ntoh32(mdp->headerp->data_blk_sz);

	mdp->mdep = (md_element_t *)(mdp->caddr + sizeof (md_header_t));
	mdp->namep = (char *)(mdp->caddr + sizeof (md_header_t) +
	    mdp->node_blk_size);
	mdp->datap = (uint8_t *)(mdp->caddr + sizeof (md_header_t) +
	    mdp->name_blk_size + mdp->node_blk_size);


		/*
		 * should do a lot more sanity checking here.
		 */

	if (mdp->headerp->transport_version != MD_TRANSPORT_VERSION)
		fatal("Unrecognised transport version");

		/*
		 * One more property we need is the count of nodes in the
		 * DAG, not just the number of elements.
		 */

	idx = 0;
	count = 0;
	do {
		md_element_t *np;

		np = &(mdp->mdep[idx]);
		switch (np->tag) {
		case DT_LIST_END:
			goto the_end;
		case DT_NULL:
			idx++;
			break;
		case DT_NODE:
			idx = ntoh64(np->d.prop_idx);
			count ++;
			break;
		default:
			fatal("At index %d found unexpected node type "
			    "%d (0x%x : '%c') while searching for nodes",
			    idx, np->tag, np->tag, np->tag);
		}
	} while (1);

the_end:
	mdp->element_count = idx+1;	/* include DT_LIST_END */
	mdp->node_count = count;

	ASSERT(mdp->element_count == (mdp->node_blk_size / MD_ELEMENT_SIZE));

	return (mdp);
}




int
md_close(md_t *mdp)
{
	munmap(mdp->caddr, mdp->size);
	close(mdp->fh);

	Xfree(mdp);

	return (0);
}
