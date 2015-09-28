/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hypervisor.h
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

#ifndef _PLATFORM_HYPERVISOR_H
#define	_PLATFORM_HYPERVISOR_H

#pragma ident	"@(#)hypervisor.h	1.1	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Niagara MMU statistics (Niagara Perf Regs API group)
 */
#define	NIAGARA_MMUSTAT_CONF	0x102
#define	NIAGARA_MMUSTAT_INFO	0x103

/*
 * Niagara Crypto Service Request (Niagara/Niagara2 Crypto API group v1.0)
 */
#define	NCS_REQUEST		0x110

#define	NIAGARA_GET_PERFREG	0x100	/* Get Niagara JBUS/DRAM perf reg */
#define	NIAGARA_SET_PERFREG	0x101	/* Set Niagara JBUS/DRAM perf reg */

/*
 * Niagara Crypto Service (Niagara/Niagara2 Crypto API group v2.0)
 */
#define	NCS_QCONF		0x111
#define	NCS_QINFO		0x112
#define	NCS_GETHEAD		0x113
#define	NCS_GETTAIL		0x114
#define	NCS_SETTAIL		0x115
#define	NCS_QHANDLE_TO_DEVINO	0x116
#define	NCS_SETHEAD_MARKER	0x117

/*
 * Fire-specific hcalls (Fire API group)
 */
#define	FIRE_GET_PERFREG	0x120
#define	FIRE_SET_PERFREG	0x121


/*
 * Niagara JBUS/DRAM performance register ID
 *
 * hcalls: NIAGARA_SET_PERFREG/NIAGARA_GET_PERFREG
 */
#define	NIAGARA_PERFREG_JBUS_CTL	0x00
#define	NIAGARA_PERFREG_JBUS_COUNT	0x01
#define	NIAGARA_PERFREG_DRAM_CTL0	0x02
#define	NIAGARA_PERFREG_DRAM_COUNT0	0x03
#define	NIAGARA_PERFREG_DRAM_CTL1	0x04
#define	NIAGARA_PERFREG_DRAM_COUNT1	0x05
#define	NIAGARA_PERFREG_DRAM_CTL2	0x06
#define	NIAGARA_PERFREG_DRAM_COUNT2	0x07
#define	NIAGARA_PERFREG_DRAM_CTL3	0x08
#define	NIAGARA_PERFREG_DRAM_COUNT3	0x09

#define	NIAGARA_PERFREG_MAX		10


#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_HYPERVISOR_H */
