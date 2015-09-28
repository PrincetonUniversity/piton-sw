/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hv.c
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

#pragma ident	"@(#)hv.c	1.7	07/06/07 SMI"

#include <hypervisor.h>
#include <sys/types.h>

extern int hv_core_trap(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, int);
extern int hv_fast_trap(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, int);
extern int hv_trap(uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, int);

int
hv_set_version(uint64_t group, uint64_t major, uint64_t minor)
{
	return (hv_core_trap(group, major, minor, 0, 0, API_SET_VERSION));
}

int
hv_core_exit(uint64_t code)
{
	return (hv_core_trap(code, 0, 0, 0, 0, API_EXIT));
}

int
hv_core_putchar(char c)
{
	return (hv_core_trap(c, 0, 0, 0, 0, API_PUTCHAR));
}

int
hv_cons_putchar(char c)
{
	return (hv_fast_trap(c, 0, 0, 0, 0, CONS_PUTCHAR));
}

int
hv_mmu_map_addr(uint64_t va, int ctx, uint64_t tte, int flags)
{
	return (hv_trap(va, ctx, tte, flags, 0, MMU_MAP_ADDR));
}

int
hv_mmu_demap_page(uint64_t va, int ctx, int flags)
{
	return (hv_trap(va, ctx, flags, 0, 0, MMU_UNMAP_ADDR));
}

void
api_version_init()
{
	hv_set_version(API_GROUP_CORE, 1, 0);
}
