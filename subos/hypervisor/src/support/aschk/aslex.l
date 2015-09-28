/*
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

%{

#pragma ident	"@(#)aslex.l	1.2	07/02/12 SMI"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/param.h>	/* for MAXPATHLEN */
#include <string.h>	/* for strchr & strdup */
#include <ctype.h>	/* for islower / toupper */

#include <assert.h>

#include "basics.h"
#include "internal.h"
#include "parser.h"


int yywrap();

bool_t flag_debug = false;

YYLTYPE yyloc;
yylval_t yylval;

int yy_line_num;

#define	UOP(_t, _size)	{ yylval.ldst.wordsize=(_size); yylval.ldst.signext=false; return (_t); }
#define	SOP(_t, _size)	{ yylval.ldst.wordsize=(_size); yylval.ldst.signext=true; return (_t); }

void validate_op(token_t tok, ldst_t *ldstinfop, char *namep);

%}

%x comment
%x string

%%

<<EOF>>				{
				return T_eof;
				}

"!"([^\n])*$				{
				DBG(printf("comment: %s\n", yytext););
				}

^"#"([^\n])*$				{
				DBG(printf("directive: %s\n", yytext););
				}

"/*"				{
				BEGIN(comment);
				DBG(printf("comment begin\n"););
				}

<comment>\n			{
				yy_line_num++;
				}

<comment>.			/* swallow */

<comment>"*/"			{
				BEGIN(INITIAL);
				DBG(printf("comment end\n"););
				}

"\""				{
				BEGIN(string);
				DBG(printf("string begin\n"););
				}

<string>"\""			{
				BEGIN(INITIAL);
				DBG(printf("string end\n"););
				yylval.namep = NULL;	/* dont care for now */
				return T_string;
				}
				
<string>\n			{
				yy_line_num++;
				}

<string>"\\\""			{ /* escaped quote is part of string */ }

<string>[^\"]*			{ /* swallow for now */ }


"\n"				{
				yyloc.first_line =
					yyloc.last_line = ++yy_line_num;
				return T_nl;
				}

"ldsb"				{ SOP(T_load, 1); }

"ldub"				{ UOP(T_load, 1); }

"ldsh"				{ SOP(T_load, 2); }

"lduh"				{ UOP(T_load, 2); }

"ldsw"				{ SOP(T_load, 4); }

"lduw"				{ UOP(T_load, 4); }

"ldn"				{ UOP(T_load, 8); }

"ldx"				{ UOP(T_load, 8); }

"ldd"				{ UOP(T_load, 16); }

"stb"				{ UOP(T_store, 1); }

"sth"				{ UOP(T_store, 2); }

"stw"				{ UOP(T_store, 4); }

"stx"				{ UOP(T_store, 8); }

"stn"				{ UOP(T_store, 8); }

"std"				{ UOP(T_store, 16); }

^"."?[A-Za-z0-9_]+":"	{
				yylval.namep = strdup(yytext);
				return T_labeldef; 
				}

"%"([a-z]+)([0-9]*)		{
				yylval.namep = strdup(yytext);
				return T_register;
				}

([A-Za-z])([A-Za-z0-9_])*	{
				yylval.namep = strdup(yytext);
				return T_name; 
				}

"0x"([1-9A-Fa-f])([0-9A-Fa-f])*	{
				uint64_t val;
				val = strtoull(yytext, NULL, 16);
				yylval.val = val;
				return T_number;	
				}

"0x0"				{
				yylval.val = 0;
				return T_number;
				}

([1-9])([0-9])*			{
				uint64_t val;
				val = strtoull(yytext, NULL, 10);
				yylval.val = val;
				return T_number;	
				}


([ \t])+			{ /* swallow */ }

.				return yytext[0] ;

%%






int yywrap()
{
	return 1;
}


void yyerror(char *strp)
{
	fprintf(stderr,"error @ line %d: %s\n",
		yyloc.first_line,
		strp);
	exit(1);
}


static char *tok_to_str(int tok)
{
	static char buf[2];
	char * s;

	if (tok<256) {
		buf[0]=tok;
		buf[1]='\0';
		return (char*)buf;
	}
#define T(_t)	case _t : s = #_t; break;
	switch(tok) {
	T(T_nl);
	T(T_name);
	T(T_labeldef);
	T(T_register);
	T(T_number);
	T(T_string);
	T(T_load);
	T(T_store);
	T(T_cas);
	default: s = "unknown";
	}
#undef T
	return s;
}

token_t get_token()
{
	token_t tok;

	tok = yylex();

DBG(	printf("Line %d : token %d : %s",
		yyloc.first_line, tok, tok_to_str(tok));
	switch(tok) {
	case T_eof:	printf("END OF FILE"); break;
	case T_name:	printf(" : %s", yylval.namep);	break;
	case T_labeldef:	printf(" : %s", yylval.namep);	break;
	case T_register:	printf(" : %s", yylval.namep);	break;
	case T_number:	printf(" : 0x%llx", yylval.val);	break;
	case T_cas:
	case T_store:
	case T_load:	printf(" : %s : bytes=%d",
			yylval.ldst.signext ? "s" : "u", yylval.ldst.wordsize);
		break;
	default:
		break;
	}
	printf("\n");
	);

	return tok;
}


void free_yyval(token_t tok)
{
	switch (tok) {
	case T_name:
	case T_labeldef:
	case T_register:
		free(yylval.namep);
		yylval.namep = NULL;
		break;
	default:
		break;
	}
}


	/*
	 * Ultra simple parser to pull out only load or store instructions
	 * that fit a very basic template.
	 */

void lex_only()
{
	token_t tok, ldsttok, tok_left, tok_right;
	char	*tok_left_ptr, *tok_right_ptr;
	ldst_t	ldstinfo;

	while ((tok = get_token())!=T_eof) {
DBG(		printf("Start line with token %d\n", tok); );
		if (tok == T_nl) {
			continue;
		}

		/*
		 * Look for a load or store at the beginning of a line.
		 * if not found - swallow the line and move to the next.
		 * A line may also be allowed to have an initial label def.
		 */
		if (tok == T_labeldef) {
			free_yyval(tok);
			tok = get_token();
			if (tok==T_eof) break;
			if (tok == T_nl) continue;
		}

DBG(		printf("look for memop %d\n", tok); );

		tok_left = -1;
		tok_right = -1;
		tok_left_ptr = NULL;
		tok_right_ptr = NULL;

		if (tok != T_load && tok != T_store) goto swallow;

		ldsttok = tok;
		ldstinfo = yylval.ldst;

		if (tok == T_store) goto handle_store;
DBG(		printf("Handle load\n"); );

		tok = get_token();
		if (tok != '[') goto swallow;

		tok = get_token();
		if (tok != T_register && tok != T_name && tok != T_number) goto swallow;
		tok_left = tok;
		tok_left_ptr = yylval.namep;

			/* only want a + b forms */
		tok = get_token();
		if (tok != '+') goto cleanup;

		tok = get_token();
		if (tok != T_register && tok != T_name && tok != T_number) goto cleanup;
		tok_right = tok;
		tok_right_ptr = yylval.namep;

		tok = get_token();
		if (tok != ']') goto cleanup;

DBG(		printf("Load accepted\n"); );

		goto sanity_check;




handle_store:;
DBG(		printf("Handle store\n"););

		tok = get_token();
		if (tok != T_register) goto swallow;

		tok = get_token();
		if (tok != ',') goto swallow;

		tok = get_token();
		if (tok != '[') goto swallow;

		tok = get_token();
		if (tok != T_register && tok != T_name && tok != T_number) goto swallow;
		tok_left = tok;
		tok_left_ptr = yylval.namep;

			/* only want a + b forms */
		tok = get_token();
		if (tok != '+') goto cleanup;

		tok = get_token();
		if (tok != T_register && tok != T_name && tok != T_number) goto cleanup;
		tok_right = tok;
		tok_right_ptr = yylval.namep;

		tok = get_token();
		if (tok != ']') goto cleanup;

DBG(		printf("Store accepted\n"); );

		goto sanity_check;



	/*
	 * Finally the check we care about ...
	 */

sanity_check:;
	/*
	 * The load/store operands can be given in any order -
	 * register + offset or offset + register ... so to make things easier
	 * if we find one form we swap the paramaters to give us the other.
	 */

	/* one side must have a name for us to check */

	if (tok_left != T_name && tok_right != T_name) goto cleanup;

	/*
	 * if both sides are a name - we bail since there is likely more than one type
	 * for us to have to sanity check .. i.e. %g3 + BASE_OFSET + FOOBAR
	 */
	if (tok_left == T_name && tok_right == T_name) goto cleanup;

	/* now for the switch over */

	if (tok_left == T_name) {
		token_t temptok;
		char *tempptr;

		temptok = tok_left;
		tempptr = tok_left_ptr;
		tok_left = tok_right;
		tok_left_ptr = tok_right_ptr;
		tok_right = temptok;
		tok_right_ptr = tempptr;
	}
	
	/* finally something we can validate ... */

DBG(	printf("Validation of name %s\n", tok_right_ptr); );

	validate_op(ldsttok, &ldstinfo, tok_right_ptr);

	goto cleanup;


cleanup:;
		if (tok_left == T_name || tok_left == T_register) {
			free(tok_left_ptr);
		}
		if (tok_left == T_name || tok_left == T_register) {
			free(tok_left_ptr);
		}
		goto swallow;

swallow_loop:;
		tok = get_token();
		if (tok==T_eof) break;
swallow:;
		free_yyval(tok);
		if (tok!=T_nl) goto swallow_loop;
	}
}




void validate_op(token_t ldsttok, ldst_t *ldstinfop, char *namep)
{
	symbol_t *symp;

	symp = hash_find(namep);
	if (symp == NULL) {
		if (!flag_suppress_unknowns) {
			fprintf(stderr,"%s:%d : Warning: unknown symbol \'%s\' for memop\n",
				yyloc.fnamep, yyloc.first_line, namep);
			warning_count++;
		}
		return;
	}

		/* Compare sizes */
	if (symp->size != ldstinfop->wordsize) {
		fprintf(stderr,"%s:%d : Warning: access size mismatch using symbol \'%s\'\n",
			yyloc.fnamep, yyloc.first_line, namep);
		fprintf(stderr,"\tAccess uses %d byte memop, but should be a %d byte memop\n",
			ldstinfop->wordsize, symp->size);
		warning_count++;
	}

		/* if its a load compare sign extension */

	if (ldsttok == T_load) {
		if (ldstinfop->signext && ((symp->flags & Sym_unsigned)!=0)) {
			fprintf(stderr,"%s:%d : Warning: sign extension mismatch for symbol \'%s\'\n",
				yyloc.fnamep, yyloc.first_line, namep);
			fprintf(stderr,"\tAccess uses signed memop, but should be unsigned\n");
			warning_count++;
		} else
		if (!ldstinfop->signext && ((symp->flags & Sym_signed)!=0)) {
			fprintf(stderr,"%s:%d : Warning: sign extension mismatch for symbol \'%s\'\n",
				yyloc.fnamep, yyloc.first_line, namep);
			fprintf(stderr,"\tAccess uses unsigned memop, but should be signed\n");
			warning_count++;
		}
	}
}
