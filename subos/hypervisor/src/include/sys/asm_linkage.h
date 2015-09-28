/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: asm_linkage.h
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

#ifndef _SYS_ASM_LINKAGE_H
#define	_SYS_ASM_LINKAGE_H

#pragma ident	"@(#)asm_linkage.h	1.3	07/04/18 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _ASM

/*
 * Assembler short-cuts
 */

#define	ENTRY(x)					\
	/* BEGIN CSTYLED */				\
	.section	".text"				;\
	.align		4				;\
	.global		x				;\
	.type		x, #function			;\
x:							;\

#define	ENTRY_NP(x)	ENTRY(x)

#define	ALTENTRY(x)					\
	/* BEGIN CSTYLED */				\
	.global		x				;\
	.type		x, #function			;\
	x:						;\
	/* END CSTYLED */


#define	DATA_GLOBAL(name)				\
	/* BEGIN CSTYLED */				\
	.align		8				;\
	.section	".data"				;\
	.global		name				;\
	name:						;\
	.type		name, #object			;\
	/* END CSTYLED */

#define	BSS_GLOBAL(name, sz, algn)			\
	/* BEGIN CSTYLED */				\
	.section	".bss"				;\
	.align		algn				;\
	.global		name				;\
	name:						;\
	.type		name, #object			;\
	.skip		sz				;\
	.size		name, . - name			;\
	/* END CSTYLED */

#define	SET_SIZE(x)					\
	.size		x, (. - x)

/* END CSTYLED */

#endif /* _ASM */

#ifdef __cplusplus
}
#endif

#endif /* _SYS_ASM_LINKAGE_H */
