/*
 * Copyright 2005 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 */


%{

#pragma ident	"@(#)mdlex.l	1.3	05/11/03 SMI"

/* any C includes here */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>

#include "basics.h"
#include "allocate.h"
#include "lexer.h"
#include "fatal.h"

lexer_t lex;	/* additional return value info */
#define	MAX_STR_LEN	(1024+1)
static struct {
	char base[MAX_STR_LEN];
	char * ptr;
} sbuffer;

#if TESTRIG /* { */
#include <stdarg.h>
#include <errno.h>
void fatal(char *s,...);
#endif		/* } */

#define	SBUFFER_INS(_c)	do {	\
		if ((sbuffer.ptr - sbuffer.base)>=MAX_STR_LEN)	\
			lex_fatal("Parse string too long - maximum is %d characters", MAX_STR_LEN);	\
		*sbuffer.ptr++ = (_c);	\
	} while(0)
%}

DECNUM	("0"|([1-9][0-9]*))

%x comment
%x string

%%

<<EOF>>			return T_EOF;

"{"			return T_L_Brace;

"}"			return T_R_Brace;

")"			return T_R_Bracket;

","			return T_Comma;

";"			return T_S_Colon;

"+"			return T_Plus;

"*"			return T_Multiply;

"-"			return T_Minus;

"&"			return T_And;

"|"			return T_Or;

"^"			return T_Xor;

"~"			return T_Not;

"<<"			return T_LShift;

"="			return T_Equals;

"]"			return T_R_Bracket;

"["			return T_L_Bracket;

^"#"[ \t].*$		{
				char lbuf[1024];
				int num;
				if (sscanf(mdlextext,"# %d \"%[^\"]\"", &num, lbuf)!=2)
					lex_fatal("Illegal # directive");
				lex.linenum = num-1;
				if (lex.fnamep != (char*)0) Xfree(lex.fnamep);
				lex.fnamep = Xstrdup(lbuf);
			}

"node"			return T_KW_node;

"proto"			return T_KW_proto;

"include"		return T_KW_include;

"("			return T_KW_expr;

"expr("			return T_KW_expr;

"lookup("		return T_KW_lookup;

"setprop("		return T_KW_setprop;

"->"			return T_KW_arc;


\"			{
				sbuffer.ptr = sbuffer.base;
				BEGIN(string);
			}

<string>\"		{	/* closing quote - wrap up string and return it */
				BEGIN(INITIAL);
				sbuffer.ptr[0]='\0';
				lex.strp = sbuffer.base;
				return T_String;
			}

<string>\n		{
				lex_fatal("unterminated string");
			}

<string>\\[0-7]{1,3}	{
				/* octal escape sequence */
				int result;

				result=-1;
				(void) sscanf( mdlextext + 1, "%o", &result );

				if ( result<0 || result>0xff )
					lex_fatal("error, constant is out-of-bounds");

				SBUFFER_INS( result );
			}

<string>\\[0-9]+		{
				lex_fatal("illegal escape sequence");
			}

<string>\\n		SBUFFER_INS( '\n' );
<string>\\t		SBUFFER_INS( '\t' );
<string>\\r		SBUFFER_INS( '\r' );
<string>\\b		SBUFFER_INS( '\b' );
<string>\\f		SBUFFER_INS( '\f' );

<string>\\(.|\n)	SBUFFER_INS( mdlextext[1] );

<string>[^\\\n\"]+	{
				char *iptr = mdlextext;

				while ( *iptr ) SBUFFER_INS( *iptr++ );
			}




"0x"[0-9A-F][0-9A-F]*	{
				lex.val = strtoull(mdlextext, (char **)NULL, 16);
				return T_Number;
			}

"0x"[0-9a-f][0-9a-f]*	{
				lex.val = strtoull(mdlextext, (char **)NULL, 16);

				return T_Number;
			}

{DECNUM}[KkMmGg]	{
				char * ep;
				lex.val = strtoll(mdlextext, &ep, 10);
				switch(*ep) {
				case 'G': case 'g':
					lex.val <<= 30;
					break;
				case 'M': case 'm':
					lex.val <<= 20;
					break;
				case 'K': case 'k':
					lex.val <<= 10;
					break;
				default:
					lex_fatal("parsing number");
				}
				return T_Number;
			}

{DECNUM}		{
				lex.val = atoll(mdlextext);
				return T_Number;
			}

\-{DECNUM}		{
				lex.val = atoll(mdlextext);
				return T_Number;
			}


[A-Za-z_#?$][A-Za-z_#\-?$0-9]* {
				lex.strp = mdlextext;
				return T_Token;
			}

			/* Note: . = any character EXCEPT newline */
\/\/.*			{ /* nada - swallow single line comments */ }

[\t ]*			{ /* nada - swallow white space */ }


"\n"			{
				lex.linenum ++;
			}

.			{
				lex_fatal("Illegal character %s", mdlextext);
			}

%%







void init_lexer(char * fnamep, FILE *fp, char * cleanup_filep)
{
	lex.cleanup_filep = cleanup_filep ? Xstrdup(cleanup_filep) : (char*)0;
	lex.linenum = 1;
	lex.fnamep = Xstrdup(fnamep);

	lex.ungot_available = false;
	lex.last_token = T_Error;

	mdlexin = fp;
}


lexer_tok_t lex_get_token()
{
	if (lex.ungot_available) {
		lex.ungot_available = false;
		return lex.last_token;
	}

	lex.last_token = mdlexlex();

	return lex.last_token;
}



void lex_unget()
{
	if (lex.ungot_available) fatal("Internal error, lex_unget with token already ungot");

	lex.ungot_available = true;
}


void lex_get(lexer_tok_t expected)
{
	lexer_tok_t tok;
	char *s;
	char buffer[1024];

	tok = lex_get_token();

	if (tok == expected) return;

	switch(tok) {
	case	T_EOF:		s="end of file";	break;
	case	T_L_Brace:	s="{";	break;
	case	T_R_Brace:	s="}";	break;
	case	T_S_Colon:	s=";";	break;
	case	T_Plus:		s="+";	break;
	case	T_Minus:	s="-";	break;
	case	T_Equals:	s="=";	break;
	case	T_Number:	s="number";	break;
	case	T_String:	s="string";	break;
	case	T_Token:
		sprintf(buffer,"token %s", lex.strp);
		s=buffer;
		break;
	case	T_KW_node:	s="node";	break;
	case	T_KW_proto:	s="proto";	break;
	case	T_KW_include:	s="include(";	break;
	case	T_KW_expr:	s="expr(";	break;
	case	T_KW_lookup:	s="lookup(";	break;
	case	T_KW_setprop:	s="setprop(";	break;

	case	T_Error:	s="error";	break;
	default:
		s="unknown token - internal error";
		break;
	}

	lex_fatal("unexpected %s", s);
}


/*
 * Special version of fatal for the lexer
 * to enable cleanup of stuff before death
 */
void
lex_fatal(char * fmt, ...)
{
	va_list	args;

	if (errno != 0)
		perror("FATAL: ");
	else
		fprintf(stderr,"FATAL: ");
	if (fmt) {
		va_start(args, fmt);
		(void) vfprintf(stderr, fmt, args);

		va_end(args);
	}

	if (lex.cleanup_filep != (char *)0) {
		unlink(lex.cleanup_filep);
		Xfree(lex.cleanup_filep);
	}
	fprintf(stderr," at line %d of %s\n", lex.linenum, lex.fnamep);
	Xfree(lex.fnamep);

	SANITY(	lex.fnamep = NULL; );
	SANITY(	lex.cleanup_filep = NULL; );
	exit(1);
}



int
mdlexwrap(void)
{
	return (1);
}

#if TESTRIG /* { */
main()
{
	lexer_tok_t tok;

	lex.linenum = 1;
	lex.fnamep = "test";

	do {
		tok = lexlex();

		fprintf(stderr,"token = %d at line %d in %s\n",tok, lex.linenum, lex.fnamep);
	} while (tok!=T_Error && tok!=T_EOF);
}


void fatal(char* fmt, ...)
{
	va_list 	args;
	int		status;
	
	if (errno!=0) perror("FATAL: "); else fprintf(stderr,"FATAL: ");
	if (fmt) {
		va_start(args, fmt);
		(void)vfprintf(stderr, fmt, args);

		va_end(args);
	}

	fprintf(stderr,"\n");
	fflush(stderr);
	fflush(stdout);

	thr_exit(&status);
}

#endif /* } */
