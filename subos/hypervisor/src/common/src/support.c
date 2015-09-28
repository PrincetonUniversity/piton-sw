/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: support.c
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

#pragma ident	"@(#)support.c	1.5	07/07/09 SMI"

#include <stdarg.h>

#include <sys/htypes.h>
#include <support.h>
#include <vdev_intr.h>
#include <config.h>

/*
 * Basic printf capability for debugging output.
 */
void
c_printf(char *strp, ...)
{
	va_list argsp;
	int i, ch;
	char buf[2];

	va_start(argsp, strp);

	buf[1] = '\0';
#define	PUTC(_x)	do { buf[0] = (_x); c_puts(buf); } while (0)

	for (i = 0; (ch = strp[i]) != '\0'; i++) {
		switch (ch) {
		case '%':
			ch = strp[++i];
			switch (ch) {
			case '\0':
				goto done;
			case 'x':
			case 'p':
				c_putn(va_arg(argsp, uint64_t), 16);
				break;
			case 'd':
				c_putn(va_arg(argsp, uint64_t), 10);
				break;
			case 's':
				c_puts(va_arg(argsp, char *));
				break;
			case '%':
				goto def;
			default:
				break;
			}
			break;
		case '\n':
			PUTC('\r');
		default:
def:;
			PUTC(ch);
			break;
		}
	}

done:;
	va_end(argsp);
}


/*
 * HV console output a number in the specified base
 */
void
c_putn(uint64_t val, int base)
{
	uint64_t num;
	static char ch[] = "0123456789abcdef";
	char buf[2];

	buf[1] = '\0';

	if (base == 10 && ((int64_t)val) < 0LL) {
		PUTC('-');
		val = 0 - val;
	}

	num = 1;
	while ((val / num) >= base) {
		num *= base;
	}

	do {
		PUTC(ch[ val / num ]);
		val = val % num;
		num = num / base;
	} while (num != 0);
}


/*
 * Brain dead bzero ...
 * ... do properly if we ever need to bzero large chunks of memory
 */
void
c_bzero(void *ptr, uint64_t size)
{
	uint8_t *p = ptr;
	uint64_t i;

	for (i = 0; i < size; i++) p[i] = 0;
}

/*
 * Brain dead memcpy ...
 * ... do properly if we ever need to copy large chunks of memory
 */
void
c_memcpy(void *dest, void *src, uint64_t size)
{
	uint8_t *destp = dest;
	uint8_t *srcp = src;
	uint64_t i;

	for (i = 0; i < size; i++)
		destp[i] = srcp[i];
}

void
c_usleep(uint64_t usecs)
{

	uint64_t delay, old;

#ifdef	DEBUG
	/*
	 * Make sure the MD has been parsed/read in before using
	 * stickfrequency
	 */
	if (config.stickfrequency == 0) {
	c_hvabort();
	}
#endif

	delay = (usecs * config.stickfrequency) / 1000000ll;

	for (old = c_get_stick(); (c_get_stick() - old ) < delay; )
		/* LINTED */
		;
}
