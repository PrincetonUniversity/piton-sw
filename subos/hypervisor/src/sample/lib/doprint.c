/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: doprint.c
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
 * Copyright 2003 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident	"@(#)doprint.c	1.2	03/11/10 SMI"

#include <limits.h>
#include <sys/types.h>
#include <stdarg.h>

#define	ADDCHAR(c)	if (bufp++ - buf < buflen) 	\
				bufp[-1] = (c);		\
			else if (print) (void)print((c))


/*
 * Given a buffer 'buf' of size 'buflen', render as much of the string
 * described by <fmt, args> as possible.  The string will always be
 * null-terminated, so the maximum string length is 'buflen - 1'.
 * Returns the number of bytes that would be necessary to render the
 * entire string, not including null terminator (just like vsnprintf(3S)).
 * To determine buffer size in advance, use _doprint(NULL, 0, fmt, args, 0) + 1.
 */
int
_doprint(char *buf, size_t buflen, const char *fmt, va_list args, int (*print)(char c))
{
	uint64_t ul, tmp;
	char *bufp = buf;	/* current buffer pointer */
	int pad, width, ells, base, sign, c;
	char *digits, *sp, *bs;
	char numbuf[65];	/* sufficient for a 64-bit binary value */

	if ((ssize_t)buflen < 0)
		buflen = 0;

	while ((c = *fmt++) != '\0') {
		if (c != '%') {
			ADDCHAR(c);
			continue;
		}

		if ((c = *fmt++) == '\0')
			break;

		for (pad = ' '; c == '0'; c = *fmt++)
			pad = '0';

		for (width = 0; c >= '0' && c <= '9'; c = *fmt++)
			width = width * 10 + c - '0';

		for (ells = 0; c == 'l'; c = *fmt++)
			ells++;

		digits = "0123456789abcdef";

		if (c >= 'A' && c <= 'Z') {
			c += 'a' - 'A';
			digits = "0123456789ABCDEF";
		}

		base = sign = 0;

		switch (c) {
		case 'd':
			sign = 1;
			/*FALLTHROUGH*/
		case 'u':
			base = 10;
			break;
		case 'p':
			ells = 1;
			/*FALLTHROUGH*/
		case 'x':
			base = 16;
			break;
		case 'o':
			base = 8;
			break;
		case 'b':
			ells = 0;
			base = 1;
			break;
		case 'c':
			ul = (int64_t)va_arg(args, int);
			ADDCHAR((int)ul & 0x7f);
			break;
		case 's':
			sp = va_arg(args, char *);
			if (sp == NULL)
				sp = "<null string>";
			while ((c = *sp++) != 0)
				ADDCHAR(c);
			break;
		case '%':
			ADDCHAR('%');
			break;
		}

		if (base == 0)
			continue;

		if (ells == 0)
			ul = (int64_t)va_arg(args, int);
		else if (ells == 1)
			ul = (int64_t)va_arg(args, long);
		else
			ul = (int64_t)va_arg(args, int64_t);

		if (sign && (int64_t)ul < 0)
			ul = -ul;
		else
			sign = 0;

		if (ells < 8 / sizeof (long))
			ul &= 0xffffffffU;

		if (c == 'b') {
			bs = va_arg(args, char *);
			base = *bs++;
		}

		tmp = ul;
		do {
			width--;
		} while ((tmp /= base) != 0);

		if (sign && pad == '0')
			ADDCHAR('-');
		while (width-- > sign)
			ADDCHAR(pad);
		if (sign && pad == ' ')
			ADDCHAR('-');

		sp = numbuf;
		tmp = ul;
		do {
			*sp++ = digits[tmp % base];
		} while ((tmp /= base) != 0);

		while (sp > numbuf) {
			sp--;
			ADDCHAR(*sp);
		}

		if (c == 'b' && ul != 0) {
			int any = 0;
			c = *bs++;
			while (c != 0) {
				if (ul & (1 << (c - 1))) {
					if (any++ == 0)
						ADDCHAR('<');
					while ((c = *bs++) >= 32)
						ADDCHAR(c);
					ADDCHAR(',');
				} else {
					while ((c = *bs++) >= 32)
						continue;
				}
			}
			if (any) {
				bufp--;
				ADDCHAR('>');
			}
		}
	}
	if (bufp - buf < buflen)
		bufp[0] = c;
	else if (buflen != 0)
		buf[buflen - 1] = c;
	return (bufp - buf);
}
