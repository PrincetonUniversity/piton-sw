/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mau.h
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

#ifndef _MAU_H
#define	_MAU_H

#pragma ident	"@(#)mau.h	1.4	07/05/21 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <mau_api.h>
#include <platform/mau.h>


#ifndef _ASM

/*
 * Per-mau attributes in vcpu.
 */
typedef struct {
	resource_t	res;
	int		pid;
	int		ino;
	int		guestid;
	uint64_t	cpuset;		/* cpus ref MAU */
} mau_parse_info_t;

struct mau {
	uint64_t	pid;		/* physical MAU id */
	uint64_t	state;		/* error/running/unconfig */
	uint64_t	handle;		/* handle for MAU */
	uint64_t	ino;		/* ino property */
#ifdef ERRATA_192
	uint64_t	store_in_progr;	/* an MAU store op is in progress */
	uint64_t	enable_cwq;	/* should we reenable the CWQ */
#endif
	uint64_t	cpuset;		/* cpus ref MAU */
	uint8_t		cpu_active[NSTRANDS_PER_CORE];
	mau_queue_t	queue;		/* queue for MAU */
	crypto_intr_t	ihdlr;		/* intr_handler info */
	struct guest	*guest;

	/*
	 * Configuration and running status
	 */
	uint32_t	res_id;
	mau_parse_info_t	pip;
};

extern intr_getstate_f mau_intr_getstate;

#endif


#ifdef __cplusplus
}
#endif

#endif /* _MAU_H */
