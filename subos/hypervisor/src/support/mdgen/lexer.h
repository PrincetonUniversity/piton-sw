/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: lexer.h
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
 * Copyright 2006 Sun Microsystems, Inc.	 All rights reserved.
 * Use is subject to license terms.
 *
 */

#ifndef	_LEXER_TOKENS_H_
#define	_LEXER_TOKENS_H_

#pragma ident	"@(#)lexer.h	1.3	06/10/26 SMI"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	T_EOF,
	T_L_Brace,
	T_R_Brace,
	T_L_Bracket,
	T_R_Bracket,
	T_Comma,
	T_S_Colon,

	T_Plus,
	T_Minus,
	T_And,
	T_Not,
	T_Or,
	T_Xor,
	T_LShift,
	T_Multiply,

	T_Equals,
	T_Number,
	T_String,
	T_Token,

	T_KW_node,
	T_KW_arc,

	T_KW_lookup,
	T_KW_expr,
	/* if ENABLE_SETPROP */
	T_KW_setprop,
	/* if ENABLE_PROTOTYPES */
	T_KW_proto,
	T_KW_include,

	T_Error
} lexer_tok_t;

typedef struct {
	int		linenum;
	char		*fnamep;
	char		*cleanup_filep;
	uint64_t	val;
	char		*strp;
	bool_t		ungot_available;
	lexer_tok_t	last_token;
} lexer_t;

extern lexer_t lex;

void init_lexer(char *fnamep, FILE *fp, char *cleanup_filep);
lexer_tok_t lex_get_token(void);
void lex_get(lexer_tok_t expected);
void lex_unget(void);
void lex_fatal(char *s, ...);

#ifdef __cplusplus
}
#endif

#endif /* _LEXER_TOKENS_H_ */
