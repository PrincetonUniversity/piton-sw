/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: asi.h
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
 * Copyright 2002 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _SPARCV9_ASI_H
#define _SPARCV9_ASI_H

#pragma ident	"@(#)asi.h	1.1	02/12/21 SMI"

/*
 * SPARC v9 ASI definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	ASI_N		0x04	/* Nucleus */
#define	ASI_N_LE	0x0c	/* Nucleus, little endian */
#define	ASI_AIUP	0x10	/* As if user, primary */
#define	ASI_AIUS	0x11	/* As if user, secondary */
#define	ASI_AIUP_LE	0x18	/* As if user, primary, little endian */
#define	ASI_AIUS_LE	0x19	/* As is user, secondary, little endian */
#define	ASI_P		0x80	/* Primary MMU context*/
#define	ASI_S		0x81	/* Secondary MMU context */
#define	ASI_P_NF	0x82	/* Primary MMU context, no fault */
#define	ASI_S_NF	0x83	/* Secondary MMU context, no fault */
#define	ASI_P_LE	0x88	/* Primary MMU context, little endian */
#define	ASI_S_LE	0x89	/* Secondary MMU context, little endian */
#define	ASI_P_NF_LE	0x8a	/* Primary MMU context, LE, no fault */
#define	ASI_S_NF_LE	0x8b	/* Secondary MMU context, LE, no fault */

#endif /* _SPARCV9_ASI_H */
