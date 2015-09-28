/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mdmain.c
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

#pragma ident	"@(#)mdmain.c	1.3	07/06/07 SMI"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <ctype.h>
#include <strings.h>

#include <md/md_impl.h>

#include "basics.h"
#include "allocate.h"
#include "fatal.h"
#include "lexer.h"

#include "dagtypes.h"
#include "outputtypes.h"


#define	DBGD(s)




extern void dt_write_hdr(FILE *fd, char *name, md_hdr_t *root);

extern void parse_dag(char *fnamep, FILE *fp);
void stichin_reqd_properties(void);
void connect_dag(void);
#if ENABLE_PROTO /* { */
void delete_protos(void);
#endif		/* } */


enum {
	Out_binary, Out_text, Out_dot
} output_type;
char *output_dot_dagp;
bool_t output_dot_flag_none = false;

bool_t flag_verbose = false;


dag_node_t *dag_listp = NULL;
dag_node_t *dag_list_endp = NULL;




int
main(int argc, char **argv)
{
	int i;
	char *fnamep;
	FILE *fp;
	char *outfnp;	/* output filename */

	output_type = Out_binary;

	for (i = 1; i < argc && argv[i][0] == '-'; i++) {
		if (strcmp(argv[i], "-h") == 0 ||
		    strcmp(argv[i], "--help") == 0) {
			fprintf(stderr, "usage: %s "
			    "[--text|--binary|--header|--dot <arc>"
			    "|-t|-b|-H|--d <arc>] [--outfile <fname>]"
			    " <filename>\n", argv[0]);
			fprintf(stderr,
			    "\t--help         : this message\n"
			    "\t-b | --binary  : write binary file (default)\n"
			    "\t-o | --outfile : output file (default=stdout)\n"
			    "\t-t | --text    : rewrite as text\n"
			    "\t-d | --dot     :"
			    " output in dot format using arcs\n"
			    "\t\t-n | --noprop :"
			    "  Omit properties in dot format\n"
			    "\t-v | --verbose : be loquacious\n");
			exit(0);
		} else
		if ((strcmp(argv[i], "-b") == 0) ||
		    (strcmp(argv[i], "--binary") == 0)) {
			output_type = Out_binary;
			continue;
		}
		if ((strcmp(argv[i], "-t") == 0) ||
		    (strcmp(argv[i], "--text") == 0)) {
			output_type = Out_text;
			continue;
		} else
		if ((strcmp(argv[i], "-d") == 0) ||
		    (strcmp(argv[i], "--dot") == 0)) {
			output_type = Out_dot;
			output_dot_dagp = argv[++i];
			continue;
		} else
		if ((strcmp(argv[i], "-n") == 0) ||
		    (strcmp(argv[i], "--noprop") == 0)) {
			if (output_type != Out_dot) {
				fprintf(stderr, "Need to specify dot output \
format before -n/--noprop\n");
				exit(1);
			}
			output_dot_flag_none = true;
			continue;
		} else
		if ((strcmp(argv[i], "-v") == 0) ||
		    (strcmp(argv[i], "--verbose") == 0)) {
			flag_verbose = true;
			continue;
		} else
		if (strcmp(argv[i], "-o") == 0 ||
		    strcmp(argv[i], "--outfile") == 0) {
			outfnp = argv[++i];
		} else
		if (argv[i][1] == 'o' && argv[i][2] != '\0') {
			outfnp = &argv[i][2];
		} else
		fatal("Unrecognised option %s\n", argv[i]);
	}

	if ((argc - i) != 1)
		fatal("Input filename name expected");

	fnamep = argv[i];

	fp = fopen(fnamep, "r");
	if (fp == NULL)
		fatal("Cannot open input file %s", fnamep);

	parse_dag(fnamep, fp);
	fclose(fp);

#if ENABLE_PROTO /* { */
		/* remove prototypes after parse phase */
	delete_protos();
	DBGD(dump_dag_nodes(stderr));
#endif		/* } */

	DBGD(dump_dag_nodes(stderr));

	connect_dag();

	stichin_reqd_properties();

	DBGD(dump_dag_nodes(stderr));

	validate_dag();

	if (outfnp != NULL) {
		fp = fopen(outfnp, "w");
		if (fp == NULL) fatal("Opening %s for output", outfnp);
	} else {
		fp = stdout;
	}

	switch (output_type) {
	case Out_binary:
		output_bin(fp);
		break;

	case Out_text:
		output_text(fp);
		break;

	case Out_dot:
		output_dot(fp);
		break;
	}
	fclose(fp);

	return (0);
}






void
validate_dag()
{
	/* no validation just yet */
}







dag_node_t *
new_dag_node(void)
{
	dag_node_t *dnp;

	dnp = Xcalloc(1, dag_node_t);

	dnp->typep = NULL;
	dnp->namep = NULL;
#if ENABLE_PROTOTYPES
	dnp->is_proto = false;
#endif

	dnp->properties.num = 0;
	dnp->properties.space = 0;
	dnp->properties.listp = NULL;

		/* add to list */
	dnp->prevp = dag_list_endp;
	dnp->nextp = NULL;
	if (NULL == dag_listp) {
		dag_listp = dnp;
	} else {
		dag_list_endp->nextp = dnp;
	}
	dag_list_endp = dnp;

	return (dnp);
}


pair_entry_t *
add_pair_entry(pair_list_t *plp)
{
	pair_entry_t *pep;

	if (plp->num >= plp->space) {
		plp->space = plp->num + 5;
		plp->listp = Xrealloc(plp->listp,
		    plp->space * sizeof (plp->listp[0]));
	}

	pep = &(plp->listp[plp->num]);
	plp->num++;

	pep->namep = NULL;
	pep->utype = PE_none;
	pep->u.val = 0;
	pep->u.data.len = 0;
	return (pep);
}


pair_entry_t *
find_pair_by_name(pair_list_t *plp, char *namep)
{
	pair_entry_t *pep;
	int i;

	for (i = 0; i < plp->num; i++) {
		pep = &(plp->listp[i]);
		if (strcmp(pep->namep, namep) == 0)
			return (pep);
	}

	return (NULL);
}

dag_node_t *
find_dag_node_by_type(char *namep)
{
	dag_node_t *dnp;

	for (dnp = dag_listp; dnp != NULL; dnp = dnp->nextp) {
		if (strcmp(dnp->typep, namep) == 0)
			return (dnp);
	}

	return (NULL);
}

dag_node_t *
find_dag_node_by_name(char *namep)
{
	dag_node_t *dnp;

	for (dnp = dag_listp; dnp != NULL; dnp = dnp->nextp) {
		if (strcmp(dnp->namep, namep) == 0)
			return (dnp);
	}

	return (NULL);
}

dag_node_t *
grab_node(char *message)
{
	lexer_tok_t tok;
	dag_node_t *dnp = NULL;

	tok = lex_get_token();
	if (tok == T_Token) {
		dnp = find_dag_node_by_name(lex.strp);
		if (dnp == NULL) {
			lex_fatal("%s: %s", message, lex.strp);
		}
	} else {
		lex_fatal("%s: %s", message, lex.strp);
	}
	return (dnp);
}

pair_entry_t *
grab_prop(char *message, dag_node_t *node)
{
	lexer_tok_t tok;
	pair_entry_t *prop = NULL;

	tok = lex_get_token();
	if (tok == T_Token) {
		prop = find_pair_by_name(&node->properties, lex.strp);
		if (prop == NULL) {
			lex_fatal("%s: %s property must exist\n",
			    message, lex.strp);
		}
	} else {
		lex_fatal("%s: %s", message, lex.strp);
	}
	return (prop);
}


void
dump_dag_nodes(FILE *fp)
{
	dag_node_t *dnp;

	for (dnp = dag_listp; dnp != NULL; dnp = dnp->nextp) {
		int i;
		pair_entry_t *pep;

#if ENABLE_PROTO	/* { */
		fprintf(fp, "node %s%s %s {\n", dnp->is_proto ? " proto" : "",
		    dnp->typep, dnp->namep);
#else			/* } { */
		fprintf(fp, "node %s %s {\n", dnp->typep, dnp->namep);
#endif			/* } */

		pep = dnp->properties.listp;
		for (i = 0; i < dnp->properties.num; i++) {
			switch (pep->utype) {
			case PE_none:
				fprintf(fp, "\n");
				break;
			case PE_string:
				fprintf(fp, "\t%s = \"%s\";\n", pep->namep,
				    pep->u.strp);
				break;
			case PE_int:
				fprintf(fp, "\t%s = 0x%llx;\n", pep->namep,
				    pep->u.val);
				break;
			case PE_arc:
				fprintf(fp, "\t%s -> %s;\n", pep->namep,
				    pep->u.dnp->namep);
				break;
			case PE_noderef:
				fprintf(fp, "\t%s -> %s;\n", pep->namep,
				    pep->u.strp);
				break;
			case PE_data:
				fprintf(fp, "\t%s = XXXXXXXX;\n", pep->namep);
				break;
			default:
				fprintf(stderr, "%s:%d: Bad Encoding.. %d\n",
				    __FILE__, __LINE__, pep->utype);
				exit(1);
			}
			pep ++;
		}

		fprintf(fp, "}\n");
		fflush(fp);
	}
}

#if ENABLE_PROTO /* { */
void
free_node(dag_node_t *dnp)
{
	int i;

	for (i = 0; i < dnp->properties.num; i++) {
		pair_entry_t *pep;

		pep = &(dnp->properties.listp[i]);

		switch (pep->utype) {
		case PE_none:
			fatal("free_node: node %s : %d : PE_none element",
			    dnp->namep, i);
		case PE_arc:
			fatal("free_node: node %s : %d : PE_arc element",
			    dnp->namep, i);
		case PE_int:
		case PE_data:
			break;
		case PE_string:
		case PE_noderef:
			Xfree(pep->u.strp);
			break;
		default:
			fatal("free_node: node %s : %d : unknown type %d",
			    dnp->namep, i, pep->utype);
		}
	}

	Xfree(dnp->properties.listp);
	Xfree(dnp);
}


void
delete_protos(void)
{
	bool_t failed;
	dag_node_t *dnp;
	dag_node_t **pp;

	pp = &dag_listp;
	dnp = *pp;

	while (dnp != NULL) {
		dag_node_t *nextp;

		nextp = dnp->nextp;

		if (dnp->is_proto) {
			free_node(dnp);
		} else {
			*pp = dnp;
			pp = &(dnp->nextp);
		}
		dnp = nextp;
	}

	*pp = NULL;

}
#endif		/* } */

void
connect_dag(void)
{
	bool_t failed;
	dag_node_t *dnp;
	FILE *errfp = stderr;
	int idx;

	failed = false;

	idx = 0;
	for (dnp = dag_listp; dnp != NULL; dnp = dnp->nextp, idx++) {
		int i;

		/* Give this node an id number */
		dnp->idx = idx;

		/* stitch all property node references */
		if (dnp->properties.num > 0) {
			for (i = 0; i < dnp->properties.num; i++) {
				pair_entry_t *pep;

				pep = &(dnp->properties.listp[i]);

				if (pep->utype == PE_noderef) {
					dag_node_t *rnp;
					rnp = find_dag_node_by_name(
					    pep->u.strp);
					if (NULL != rnp) {
						Xfree(pep->u.strp);
						pep->u.dnp = rnp;
						pep->utype = PE_arc;
					} else {
						failed = true;
						fprintf(errfp, "Referenced "
						    "node %s not found\n",
						    pep->u.strp);
					}
				}
			}
		}
	}

	if (failed)
		goto failed;
	return;

failed:;
	fatal("errors found");
}


/*
 * We must have a "root" node ... look for it,
 * and hike it to the first entry in the table.
 */
void
stichin_reqd_properties(void)
{
	dag_node_t *dnp;

	dnp = find_dag_node_by_type("root");
	if (dnp == NULL)
		fatal("A root node is required for a valid description");

	/*
	 * Hike the root node to be the first element.
	 */
	if (dnp->prevp != NULL) {
		dnp->prevp->nextp = dnp->nextp;
		if (dnp->nextp != NULL) {
			dnp->nextp->prevp = dnp->prevp;
		} else {
			dag_list_endp = dnp->prevp;
		}

		dnp->nextp = dag_listp;
		dag_listp->prevp = dnp;
		dag_listp = dnp;
	}
}
