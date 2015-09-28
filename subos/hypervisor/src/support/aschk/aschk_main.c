/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: aschk_main.c
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

#pragma ident	"@(#)aschk_main.c	1.3	07/06/07 SMI"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>

#include "basics.h"
#include "internal.h"
#include "parser.h"

extern void lex_only();

static void usage();
static void check_file(char *fnamep);
static void add_name_file(char *fnamep);

bool_t	flag_suppress_unknowns;
int	warning_count;

int
main(int argc, char **argv)
{
	int i;
	bool_t	flag_strict_mode;

	init_symbols();
	flag_suppress_unknowns = false;
	flag_strict_mode = false;

	for (i = 1; i < argc && argv[i][0] == '-'; i++) {
		switch (argv[i][1]) {
		case 'n':
			add_name_file(argv[++i]);
			break;
		case 'u':
			flag_suppress_unknowns = true;
			break;
		case 's':
			flag_strict_mode = true;
			break;
		default:
			usage();
		}
	}

	warning_count = 0;

	for (; i < argc; i++) {
		check_file(argv[i]);
	}

	if (warning_count > 0) {
		fprintf(stderr, "Completed with %d warnings\n", warning_count);
	}

	if (!flag_strict_mode)
		return (0);

	return ((warning_count != 0) ? 1 : 0);
}


static void
check_file(char *fnamep)
{
	FILE *fp;

	fp = fopen(fnamep, "r");

	aslexin = fp;
	yyloc.fnamep = fnamep;
	yy_line_num = 1;
	lex_only();

	fclose(fp);
}



static void
usage(void)
{
	fprintf(stderr, "aschk [-s] [-u] [-n <chk file>] <testfile.s>"
	    " [<others.s>]*\n"
	    "\t-u = suppress warnings for unknowns\n"
	    "\t-s = strict mode; non-zero exit if warning count >0\n"
	    "\t-n = specify name table file\n");
	exit(1);
}



#define	MAXLINE	2048

static void
add_name_file(char *fnamep)
{
	FILE *fp;
	char	linebuf[MAXLINE];
	char	typestr[4];
	char	symname[MAXLINE];
	int	offset, size;
	int	linenum;
	sym_flags_t	flags;
	symbol_t	*symp;

	fp = fopen(fnamep, "r");
	if (fp == NULL) {
		fprintf(stderr, "Opening: %s : %s\n", fnamep, strerror(errno));
		exit(1);
	}

	linenum = 0;
	while (fgets(linebuf, MAXLINE, fp) != NULL) {
		/* skip comments and directives */
		linenum++;
		if (linebuf[0] == '!' || linebuf[0] == '#')
			continue;

		if (sscanf(linebuf, "%4s %x %x %s\n", typestr,
		    &offset, &size, symname) != 4)
			continue;
		DBG(printf("Sym: %s\t@ 0x%x\tsize=0x%x\ttype=%s\n",
		    symname, offset, size, typestr));

		flags = Sym_unknown;
		switch (typestr[0]) {
		case 'p':	flags |= Sym_pointer;	break;
		case 'u':	flags |= Sym_unsigned;	break;
		case 's':	flags |= Sym_signed;	break;
		default:
			fprintf(stderr, "Unknown check type for line %d\n",
			    linenum);
			exit(1);
		}
		if (typestr[1] == 'c') flags |= Sym_char;

		symp = new_sym(flags, symname, offset, size);
		sym_hash_insert(symp);
	}

	fclose(fp);
}
