/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mdparse.c
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

#pragma ident	"@(#)mdparse.c	1.7	07/06/07 SMI"

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


static bool_t get_token_value(pair_entry_t *pep, lexer_tok_t tok);


#if	ENABLE_LOOKUP	/* { */
void
parse_lookup(pair_entry_t *pep)
{
	dag_node_t *src;
	pair_entry_t *prop;

	src = grab_node("lookup(<node>, <property): bad node");
	lex_get(T_Comma);
	prop =  grab_prop("lookup(<node>, <property): bad property", src);
	lex_get(T_R_Bracket);
	pep->utype = prop->utype;
	pep->u = prop->u;
}
#endif	/* } */

#define	EXPR_ANY	0
#define	EXPR_OP		1
#define	EXPR_INT	2
#define	EXPR_STR	3
#define	EXPR_EVAL_INT	4
#define	EXPR_EVAL_STR	5

void
parse_expr(pair_entry_t *ipep)
{
	lexer_tok_t tok, op;
	uint64_t lval = 0;
	char *lstr = "";
	uint64_t n[2];
	char *str[2];
	int idx = 0;
	int type = EXPR_ANY;
	int done = 0;
	int getop = 1;
	int invert = 0;
	pair_entry_t mypp, pp, *opep = &pp, *pep = &mypp;

	pep->namep = ipep->namep;
	pep->utype = PE_none;
	pep->u.data.len = 0;
	opep->namep = ipep->namep;
	opep->utype = PE_none;
	opep->u.data.len = 0;
	tok = 0;
	op = 0;
	while (!done) {
		if (getop) {
			tok = lex_get_token();
			lval = lex.val;
			lstr = lex.strp;
		}
		switch (type) {
		case EXPR_ANY:
		case EXPR_INT:
		case EXPR_STR:
			switch (tok) {
			case T_Not:
				if (type == EXPR_STR)
					goto error;
				invert = 1;
				break;

			case T_Number:
				if (type == EXPR_STR)
					goto error;
				n[idx] = lval;
				if (invert) {
					n[idx] = ~n[idx];
					invert = 0;
				}
				pep->utype = PE_int;
				if (idx) {
					type = EXPR_EVAL_INT;
					getop = 0;
				} else {
					type = EXPR_OP;
					idx = 1;
					getop = 1;
				}
				break;

			case T_String:
				if (type == EXPR_INT)
					goto error;
				str[idx] = Xstrdup(lstr);
				pep->utype = PE_string;
				if (idx) {
					type = EXPR_EVAL_STR;
					getop = 0;
				} else {
					type = EXPR_OP;
					idx = 1;
					getop = 1;
				}
				break;

#if	ENABLE_LOOKUP
			case T_KW_lookup:
				parse_lookup(opep);
				goto cont_assign;
#endif

			case T_KW_expr:
				parse_expr(opep);
#if	ENABLE_LOOKUP
cont_assign:;
#endif
				switch (opep->utype) {
				case PE_int:
					type = (((pep->utype == PE_int) ||
					    (pep->utype == PE_none)) ?
					    EXPR_INT : EXPR_STR);
					tok = T_Number;
					lval = opep->u.val;
					break;
				case PE_string:
					type = (((pep->utype == PE_string) ||
					    (pep->utype == PE_none)) ?
					    EXPR_STR : EXPR_INT);
					tok = T_String;
					lstr = opep->u.strp;
					break;
				default:
					lex_fatal("Bad EXPR type: %d\n",
					    opep->utype);
				}
				getop = 0;
				break;

			default:
				lex_fatal("Bad expression: %s", lex.strp);
				break;
			}
			break;

		case EXPR_OP:
			if (tok == T_R_Bracket) {
				if (idx == 1) {
					if (pep->utype == PE_int) {
						pep->u.val = n[0];
					} else {
						pep->u.strp = Xstrdup(str[0]);
					}
				} else {
					printf("EXPR_OP: idx == 0???\n");
					goto error;
				}
				done = 1;
				break;
			}
			op = tok;
			type = ((pep->utype == PE_int) ?
			    EXPR_INT : EXPR_STR);
			break;

		case EXPR_EVAL_INT:
			pep->utype = PE_int;
			switch (op) {
			case T_Minus:
				pep->u.val = n[0] - n[1];
				break;
			case T_Xor:
				pep->u.val = n[0] ^ n[1];
				break;
			case T_Or:
				pep->u.val = n[0] | n[1];
				break;
			case T_And:
				pep->u.val = n[0] & n[1];
				break;
			case T_Plus:
				pep->u.val = n[0] + n[1];
				break;
			case T_Multiply:
				pep->u.val = n[0] * n[1];
				break;
			case T_LShift:
				pep->u.val = n[0] << n[1];
				break;

			default:
				goto error;
			}
			idx = 1;
			getop = 1;
			n[0] = pep->u.val;
			type = EXPR_OP;
			break;

		case EXPR_EVAL_STR:
			pep->utype = PE_string;
			if (op == T_Plus) {
				char *dst = Xmalloc(strlen(str[0]) +
				    strlen(str[1]) + 1);
				sprintf(dst, "%s%s", str[0], str[1]);
				free(str[1]);
				free(str[0]);
				pep->u.strp = dst;
			} else {
				goto error;
			}
			idx = 1;
			str[0] = pep->u.strp;
			type = EXPR_OP;
			break;

		default:
		error:
			lex_fatal("Expression syntax error");
		}
	}
#if 0
	if (pep->utype == PE_int) {
		printf("Int Expr: %llx\n", pep->u.val);
	} else {
		printf("Str Expr: [%s]\n", pep->u.strp);
	}
#endif
	*ipep = mypp;
}



#if ENABLE_PROTO	/* { */

void
clone_pair_entry(pair_list_t *plp, pair_entry_t *pep)
{
	pair_entry_t *np;

	np = add_pair_entry(plp);
	np->namep = Xstrdup(pep->namep);
	np->utype = pep->utype;
	switch (np->utype) {
	case PE_int:
		np->u.val = pep->u.val;
		break;
	case PE_string:
	case PE_noderef:
		np->u.strp = Xstrdup(pep->u.strp);
		break;
	case PE_data:
		memmove(np->u.data.buffer, pep->u.data.buffer, pep->u.data.len);
		np->u.data.len = pep->u.data.len;
		break;
	default:
		fatal("clone_pair_entry: Internal error: unexpected type %d\n",
		    np->utype);
	}
}

void
parse_include(dag_node_t *dnp)
{
	lexer_tok_t tok;
	dag_node_t *src;
	pair_entry_t *pep;
	pair_list_t *plp;
	int i, n;

	src = grab_node("include <node>: bad node");
	tok = lex_get_token();
	switch (tok) {
	case T_Comma:
		pep =  grab_prop("lookup(<node>, <property>): bad property",
		    src);
			/* be careful.. clone_pair_entry does a Realloc */
		clone_pair_entry(&dnp->properties, pep);

		lex_get(T_S_Colon);
		break;

	case T_S_Colon:
		break;

	default:
		lex_fatal("include: <node>[, <property>]; syntax error");
	}

	plp = &src->properties;
	n = plp->num;
	for (i = 0; i < n; i++) {
			/* be careful.. clone_pair_entry does a Realloc */
		clone_pair_entry(&dnp->properties, &(plp->listp[i]));
	}
}
#endif	/* } */

static void
parse_data(pair_entry_t *pep)
{
	pair_entry_t pp;
	lexer_tok_t tok;

	pep->utype = PE_data;
	pep->u.data.len = 0;

	/*
	 * FIXME: not true anymore.
	 * represented as ints, upper zero bytes are discarded.
	 * [0] is a single zero byte
	 * [01020304] is 01,02,03,04, the upper 32bits were discarded.
	 */
	do {
		int n;
		bool_t ok;

		pp.utype = PE_none;	/* SANITY */

		tok = lex_get_token();

		ok = get_token_value(&pp, tok);
		if (!ok) lex_fatal("Illegal assignment expression");

		switch (pp.utype) {
		case PE_int:
			for (n = 7; n > 0; n--) {
				if ((pp.u.val >> (8*n)) != 0) break;
			}

			if (pep->u.data.len+n+1 >= MAX_DATALEN)
				lex_fatal("Internal error; out of data space");

			for (; n >= 0; n--) {
				pep->u.data.buffer[pep->u.data.len++] =
				    (uint8_t)(pp.u.val >> (8*n));
			}
			break;

		case PE_string:
			n = strlen(pp.u.strp)+1;
			if (pep->u.data.len+n >= MAX_DATALEN)
				lex_fatal("Internal error; out of data space");
			memmove(&(pep->u.data.buffer[pep->u.data.len]),
			    pp.u.strp, n);
			pep->u.data.len += n;
			Xfree(pp.u.strp);
			break;

		case PE_data:
			lex_fatal("data concat unimplemented !");

		default:
			lex_fatal("invalid data entry");
		}

			/* Look for a comma, or R brace */
		tok = lex_get_token();
		if (tok != T_Comma && tok != T_R_Brace)
			lex_fatal("Syntax error; comma or } expected");

	} while (tok != T_R_Brace);

	if (pep->u.data.len == 0) {
		lex_fatal("Empty data encoding");
	}
}


static bool_t
get_token_value(pair_entry_t *pep, lexer_tok_t tok)
{
	switch (tok) {
	case T_Number:
		pep->utype = PE_int;
		pep->u.val = lex.val;
		break;
	case T_String:
		pep->utype = PE_string;
		pep->u.strp = Xstrdup(lex.strp);
		break;
	case T_KW_expr:
		parse_expr(pep);
		break;
#if ENABLE_LOOKUP
	case T_KW_lookup:
		parse_lookup(pep);
		break;
#endif
	case T_L_Brace:
		parse_data(pep);
		break;

	default:
		return (0);
	}
	return (1);
}

static void
do_assignment(pair_entry_t *pep, bool_t fn)
{
	int done = 0;
	pair_entry_t pp, mypp;
	lexer_tok_t tok;
	uint8_t *dest;
	char *src;
	int len;
	uint64_t d;

	pp.namep = pep->namep;
	pp.utype = PE_none;
	pp.u.data.len = 0;

	mypp.namep = pep->namep;
	mypp.utype = PE_none;
	mypp.u.data.len = 0;

	tok = lex_get_token();
	if (tok == T_S_Colon)	lex_fatal("empty assignment");
	if (tok == T_Comma)	lex_fatal("invalid compound data");
	if (fn && (tok == T_R_Bracket)) lex_fatal("missing argument");

	while (!done) {
		bool_t ok;

		ok = get_token_value(&pp, tok);
		if (!ok) lex_fatal("Illegal assignment expression");

		switch (mypp.utype) {
		case PE_none:
			/*
			 * first iteration, copy data,
			 * this is the 'normal' path.
			 */
			mypp = pp;
			pp.namep = NULL;	/* cleanup */
			pp.utype = PE_none;	/* cleanup */
			pp.u.strp = NULL;	/* cleanup in case of a str */
			break;

		case PE_int:
			/*
			 * an append onto an int.
			 */
			mypp.utype = PE_data;
			len = sizeof (uint64_t);
				/* FIXME: memory order !! */
			d = mypp.u.val;	/* move to be copy safe */
			memmove(mypp.u.data.buffer, &d, len);
			mypp.u.data.len = len;
			goto do_data;

		case PE_string:
			/*
			 * an append onto a string.
			 */
			mypp.utype = PE_data;
			src = mypp.u.strp;
			len = strlen(src) + 1;
			memmove(mypp.u.data.buffer, src, len);
			free(src);
			mypp.u.data.len = len;
			goto do_data;

		case PE_data:
		do_data:
			ASSERT(mypp.utype == PE_data);

				/* ensure no overflow */
			switch (pp.utype) {
			case PE_int:
				len = sizeof (uint64_t);
				break;
			case PE_string:
				len = strlen(pp.u.strp) + 1;
				break;
			case PE_data:
				len = pp.u.data.len;
				break;
			default:
				lex_fatal("improper concatination");
				break;
			}

			if ((mypp.u.data.len + len) >= MAX_DATALEN)
				lex_fatal("compound data too long");
			dest = &(mypp.u.data.buffer[mypp.u.data.len]);

			switch (pp.utype) {
			case PE_int:
				memmove(dest, &pp.u.val, len);
				break;

			case PE_string:
				memmove(dest, pp.u.strp, len);
				free(pp.u.strp);
				pp.u.strp = NULL;
				break;

			case PE_data:
				memmove(dest, pp.u.data.buffer, len);
				break;

			default:
				break;
			}
			mypp.u.data.len += len;
			break;

		default:
			lex_fatal("improper concatination");
		}

		tok = lex_get_token();
		if (tok == T_Comma) {
			tok = lex_get_token();
		} else
		if ((tok == T_S_Colon) || (fn && (tok == T_R_Bracket))) {
			*pep = mypp;
			done = 1;
		} else {
			lex_fatal("invalid compound expression");
		}
	}
}

#if ENABLE_SETPROP /* { */
void
parse_setprop(void)
{
	dag_node_t *src;
	pair_entry_t *pep;

	src = grab_node("setprop(<node>, <property>, <value>): bad node");
	lex_get(T_Comma);
	pep = grab_prop("setprop(<node>, <property>, <value>): bad property",
	    src);
	lex_get(T_Comma);
	do_assignment(pep, true);
}
#endif	/* } */

void
parse_dag(char *fnamep, FILE *fp)
{
	lexer_tok_t tok;

	init_lexer(fnamep, fp, NULL);

	while ((tok = lex_get_token()) != T_EOF) {
		dag_node_t *dnp;

#if ENABLE_PROTO	/* FIXME: delete enourage CPP macros { */
		if ((tok != T_KW_node) &&
		    (tok != T_KW_proto))
			lex_fatal("node definition expected");
		dnp = new_dag_node();
		if (tok == T_KW_proto) {
			dnp->is_proto = true;
		}
#else	/* } { */
		if (tok != T_KW_node)
			lex_fatal("node definition expected");
		dnp = new_dag_node();
#endif	/* } */

		lex_get(T_Token);
		dnp->typep = Xstrdup(lex.strp);

		lex_get(T_Token);
		dnp->namep = Xstrdup(lex.strp);

		lex_get(T_L_Brace);

		while ((tok = lex_get_token()) != T_R_Brace) {
			pair_entry_t *pep;

			switch (tok) {
#if ENABLE_SETPROP /* FIXME: TBD delete in favour of variables { */
			case T_KW_setprop:
				parse_setprop();
				lex_get(T_S_Colon);
				break;

#endif	/* } */
#if ENABLE_PROTO /* FIXME: use CPP macros instead */
			case T_KW_include:
				parse_include(dnp);
				break;
#endif	/* } */

			case T_Token:
				pep = add_pair_entry(&dnp->properties);
				pep->namep = Xstrdup(lex.strp);

				tok = lex_get_token();
				switch (tok) {
				case T_Equals:
					do_assignment(pep, false);
					break;

				case T_KW_arc:
					lex_get(T_Token);
					pep->utype = PE_noderef;
					pep->u.strp = Xstrdup(lex.strp);
					lex_get(T_S_Colon);
					break;

				default:
					goto expect;
				}
				break;

			default:
expect:;
				lex_fatal("property expected");
			}
		}
	}
}
