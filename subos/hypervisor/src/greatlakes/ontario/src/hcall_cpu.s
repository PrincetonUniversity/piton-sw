/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_cpu.s
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

	.ident	"@(#)hcall_cpu.s	1.98	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <asi.h>
#include <hprivregs.h>
#include <offsets.h>
#include <guest.h>
#include <util.h>

/*
 * Halt the current strand
 *
 * %g1	 	clobbered
 * %g2 - %g6	preserved
 * %g7		return address
 */
	ENTRY_NP(plat_halt_strand)
#ifdef NIAGARA_ERRATUM_39
	rdhpr	%hver, %g1
	srlx	%g1, VER_MASK_MAJOR_SHIFT, %g1
	and	%g1, VER_MASK_MAJOR_MASK, %g1
	cmp	%g1, 1		! Check for Niagara 1.x
	bleu,pt	%xcc, 1f
	nop
#endif
	rd      STR_STATUS_REG, %g1
	! xor ACTIVE to clear it on current strand
	wr      %g1, STR_STATUS_STRAND_ACTIVE, STR_STATUS_REG
	! skid
	nop
	nop
	nop
	nop
1:
	HVRET

	SET_SIZE(plat_halt_strand)
