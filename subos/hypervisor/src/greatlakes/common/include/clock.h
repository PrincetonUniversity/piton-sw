/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: clock.h
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

#ifndef _CLOCK_H
#define	_CLOCK_H

#pragma ident	"@(#)clock.h	1.2	07/01/24 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Clock Unit Definitions
 */

#define	CLK_BASE  (0x96 << 32)

#define	CLK_DIV_REG			0x00
#define	CLK_CTL_REG			0x08
#define	CLK_DLL_CNTL_REG		0x18
#define	CLK_DLL_BYP_REG			0x38
#define	CLK_JSYNC_REG			0x28
#define	CLK_DSYNC_REG			0x30
#define	CLK_VERSION_REG			0x40

#define	CLK_CTL_MASK			0xffff000000000000
#define	CLK_DEBUG_INIT_REG		0x10		/* DEBUG ONLY */

/*
 * Clock Divider Register
 */
#define	CLK_DIV_MASK			0x1f
#define	CLK_DIV_JDIV_SHIFT		0x08
#define	CLK_DIV_SCALE_SHIFT		0x3

#ifdef __cplusplus
}
#endif

#endif /* _CLOCK_H */
