/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: instr.h
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

#ifndef _SUN4V_INSTR_H
#define	_SUN4V_INSTR_H

#pragma ident	"@(#)instr.h	1.1	07/07/17 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * LDBLOCKF
 *
 *   op               op3
 * +-----+--------+---------+------+-----+----------+------+
 * |  11 |   rd   |  110011 |  rs1 | I=0 |  imm_asi |  rs2 |
 * +-----+--------+---------+------+-----+----------+------+
 *						   5 4
 * +-----+--------+---------+------+-----+-----------------+
 * | 11  |   rd   |  110011 |  rs1 | I=1 |     simm_13     |
 * +-----+--------+---------+------+-----+-----------------+
 *  31 30 29    25 24     19 18  14  13   12              0
 */
#define	LDBLOCKF_OP		0x3
#define	LDBLOCKF_OP_SHIFT	30
#define	LDBLOCKF_OP3		0x33
#define	LDBLOCKF_OP3_SHIFT	19
#define	LDBLOCKF_OP3_MASK	(0x3f << LDBLOCKF_OP3_SHIFT)
#define	LDBLOCKF_I_SHIFT	13
#define	LDBLOCKF_ASI_SHIFT	5
#define	LDBLOCKF_ASI_MASK	(0xff << LDBLOCKF_ASI_SHIFT)
#define	LDBLOCKF_RD_SHIFT	25
#define	LDBLOCKF_RD_MASK	(0x1f << LDBLOCKF_RD_SHIFT)

#ifdef __cplusplus
}
#endif

#endif /* _SUN4V_INSTR_H */
