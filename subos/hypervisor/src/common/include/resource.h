/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: resource.h
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

#ifndef	_RESOURCE_H
#define	_RESOURCE_H

#pragma ident	"@(#)resource.h	1.3	07/02/12 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ASM

/*
 * Simple struct to bury in each resource structure
 * so we can re-use common functions in the
 * reconfigure framework.
 */

typedef struct {
	uint8_t	flags;
} resource_t;


/*
 * The bits below look like uniq values, but are in fact
 * bitwise flags. The parse-commit phase for an HV MD update
 * Will set bits according to how a resource is to be
 * (re)configured.
 *
 * All configured resources start being marked in the unconfig state
 *	so by default they will be unconfigured.
 * 	unconfigured resources are marked in the noop state.
 * The new HV MD state is parsed and as each MD node is found and
 *	read in, unconfigured resources get marked to the config state
 *	configured resources are either marked as noop, rebind or
 *	modified based on what (if anything) has changed.
 * At the end of the parse process we now know what action if
 *	any needs to happen to each resource, so in the commit
 *	phase we call the appropriate resource specific function
 *	to take the action we need to take for the reconfig.
 */


#define	RESF_Noop	0x0
#define	RESF_Unconfig	0x1
#define	RESF_Config	0x2
#define	RESF_Rebind	0x3
#define	RESF_Modify	0x4

/*
 * Simple macro to help with resource configuration prototypes
 */

#define	RES_PROTO(_name)						\
	void		res_##_name##_prep();				\
	hvctl_status_t	res_##_name##_parse(bin_md_t *,			\
			hvctl_res_error_t *fail_codep,			\
			md_element_t **failnodepp, int *fail_res_id);	\
	hvctl_status_t	res_##_name##_postparse(hvctl_res_error_t *,	\
			int *fail_res_id);				\
	void		res_##_name##_commit(int flags);


#endif

#ifdef __cplusplus
}
#endif

#endif	/* _RESOURCE_H */
