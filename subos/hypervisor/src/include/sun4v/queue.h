/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: queue.h
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

#ifndef _SUN4V_QUEUE_H
#define _SUN4V_QUEUE_H

#pragma ident	"@(#)queue.h	1.3	04/08/19 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * sun4v Queue registers
 */

#define	CPU_MONDO_QUEUE		0x3c
#define	DEV_MONDO_QUEUE		0x3d
#define	ERROR_RESUMABLE_QUEUE	0x3e
#define	ERROR_NONRESUMABLE_QUEUE 0x3f

#define	CPU_MONDO_QUEUE_HEAD	0x3c0 /* rw */
#define	CPU_MONDO_QUEUE_TAIL	0x3c8 /* ro */
#define	DEV_MONDO_QUEUE_HEAD	0x3d0 /* rw */
#define	DEV_MONDO_QUEUE_TAIL	0x3d8 /* ro */

#define	ERROR_RESUMABLE_QUEUE_HEAD	0x3e0 /* rw */
#define	ERROR_RESUMABLE_QUEUE_TAIL	0x3e8 /* ro */
#define	ERROR_NONRESUMABLE_QUEUE_HEAD	0x3f0 /* rw */
#define	ERROR_NONRESUMABLE_QUEUE_TAIL	0x3f8 /* ro */

#define	Q_EL_SIZE		0x40
#define	Q_EL_SIZE_SHIFT		6	/* LOG2(Q_EL_SIZE) */

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_QUEUE_H */
