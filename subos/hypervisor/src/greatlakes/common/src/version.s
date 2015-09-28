/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: version.s
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

	.ident	"@(#)version.s	1.7	07/05/03 SMI"

	.file	"version.s"

/*
 * Niagara startup code
 */

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <offsets.h>
#include <util.h>

	.section ".text"
	.global	qversion, eqversion, qinfo, eqinfo
	.align	64
qversion:
#ifdef DEBUG
	.ascii	"@(#)", VERSION, " [", INFO, "]"
#else
	.ascii	"@(#)", VERSION
#endif
	.asciz	"\r\n"
eqversion:
qinfo:
	.ascii	INFO
	.asciz	"\r\n"
eqinfo:
	.align	8

#ifdef DEBUG
	ENTRY_NP(printversion)
	LABEL_ADDRESS(qversion, %g1)
	ba	puts
	nop		! tail call
	SET_SIZE(printversion)
#endif
	/*
	 * dump_version(dest, size)
	 *
	 * Copies the version and info  strings into dest up to a max. of
	 * size bytes
	 *
	 * %g2		dest	(clobbered)
	 * %g3		size	(clobbered)
	 * %g7		return address
	 */
	ENTRY(dump_version)

	brz,pn	%g2, .dump_version_exit
	nop
	brlez,pn %g3, .dump_version_exit
	nop

	LABEL_ADDRESS(qversion, %g4)
1:
	ldub	[%g4], %g5
	brz,a,pn %g5, .dump_info
	stb	%g5, [%g2]
	inc	%g4
	inc	%g2
	brgz,pt	%g3, 1b
	dec	%g3

.dump_info:
	LABEL_ADDRESS(qinfo, %g4)
1:
	ldub	[%g4], %g5
	brz,a,pn %g5, .dump_version_exit
	stb	%g5, [%g2]
	inc	%g4
	inc	%g2
	brgz,pt	%g3, 1b
	dec	%g3

.dump_version_exit:
	HVRET
	SET_SIZE(dump_version)
