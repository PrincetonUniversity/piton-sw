/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: guest.h
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

#ifndef _PLATFORM_GUEST_H
#define	_PLATFORM_GUEST_H

#pragma ident	"@(#)guest.h	1.57	07/06/04 SMI"

#ifdef __cplusplus
extern "C" {
#endif


#include <cache.h>
#include <fire.h>
#include <ncs.h>
#include <cpu_errs.h>

/*
 * NUM_API_GROUPS - The size of the "api_versions" table in the
 *     guest structure.  One more than the number of entries in the
 *     table in hcall.s, to account for API_GROUP_SUN4V.
 */
#define	NUM_API_GROUPS		12	/* one more than table */

#ifndef _ASM

/*
 * Info built parsing the HV MD
 */
typedef struct {
	resource_t	res;
	uint64_t	rom_base;
	uint64_t	rom_size;
	uint64_t	real_base;
	uint64_t	md_pa;
#ifdef	CONFIG_CN_UART
	uint64_t	uartbase;
#endif
#ifdef	CONFIG_DISK
	uint64_t	diskpa;
#endif
#ifdef	T1_FPGA_SNET
	uint64_t	snet_pa;
	uint64_t	snet_ino;
#endif
	uint64_t	reset_reason;
	uint64_t	perfreg_accessible;
	uint64_t	diagpriv;
	uint64_t	tod_offset;
	uint64_t	vdev_cfghandle;
	uint64_t	cdev_cfghandle;
	/*
	 * Following are for N2 HWTW only. Not used
	 * on N1.
	 */
	uint64_t	real_limit;
	uint64_t	mem_offset;
} guest_parse_info_t;

struct machguest {
	/*
	 * The compiler hates zero length structs, for now this
	 * just stuff this placeholder in.
	 */
	int dummy;
};

#endif /* !_ASM */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_GUEST_H */
