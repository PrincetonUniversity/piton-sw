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
 * Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#ifndef _PLATFORM_ASI_H
#define	_PLATFORM_ASI_H

#pragma ident	"@(#)asi.h	1.1	07/05/03 SMI"

/*
 * Niagara1 ASI definitions
 */

#ifdef __cplusplus
extern "C" {
#endif

#define	ASI_SPARC_ERR_EN	0x4b	/* Sparc Error enable */
#define	ASI_SPARC_ERR_STATUS	0x4c	/* Sparc Error status */
#define	ASI_SPARC_ERR_ADDR	0x4d	/* Sparc Error address */
#define	ASI_DTSBBASE_CTX0_PS0	0x31
#define	ASI_DTSBBASE_CTX0_PS1	0x32
#define	ASI_DTSB_CONFIG_CTX0	0x33
#define	ASI_ITSBBASE_CTX0_PS0	0x35
#define	ASI_ITSBBASE_CTX0_PS1	0x36
#define	ASI_ITSB_CONFIG_CTX0	0x37
#define	ASI_DTSBBASE_CTXN_PS0	0x39
#define	ASI_DTSBBASE_CTXN_PS1	0x3a
#define	ASI_DTSB_CONFIG_CTXN	0x3b
#define	ASI_ITSBBASE_CTXN_PS0	0x3d
#define	ASI_ITSBBASE_CTXN_PS1	0x3e
#define	ASI_ITSB_CONFIG_CTXN	0x3f

#define	ASI_IMMU_TSB_PS0 0x51	/* IMMU TSB PS0 */
#define	ASI_IMMU_TSB_PS1 0x52	/* IMMU TSB PS1 */

#define	ASI_DMMU_TSB_PS0 0x59	/* DMMU TSB PS0 */
#define	ASI_DMMU_TSB_PS1 0x5a	/* DMMU TSB PS1 */
#define	ASI_DTLB_DIRECTPTR 0x5b	/* DMMU direct pointer */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_ASI_H */
