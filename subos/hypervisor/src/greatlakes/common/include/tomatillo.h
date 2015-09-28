/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: tomatillo.h
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
 * Copyright 2004 Sun Microsystems, Inc.  All rights reserved.
 * Use is subject to license terms.
 */

#pragma ident   "@(#)tomatillo.h 1.1     04/05/27 SMI"

/*
 * Tomatillo Definitions
 */

#define TOMATILLO_BASE  0x800f000000		/* JBUS ID = 1e */

#define TOM_CTL_STAT_REG   ( TOMATILLO_BASE + 0x410000 )
#define TOM_RESET_GEN_REG  ( TOMATILLO_BASE + 0x417010 )
#define TOM_JBUS_DTAG_REGS ( TOMATILLO_BASE + 0x412000 )
#define TOM_JBUS_CTAG_REGS ( TOMATILLO_BASE + 0x413000 )
#define TOM_PCIA_BASE 	   ( TOMATILLO_BASE + 0x600000 )
#define TOM_PCIB_BASE 	   ( TOMATILLO_BASE + 0x700000 )
#define TOM_PCIA_IO_CACHE_TAG ( TOM_PCIA_BASE + 0x2250 )
#define TOM_PCIB_IO_CACHE_TAG ( TOM_PCIB_BASE + 0x2250 )

