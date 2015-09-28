/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: mmu_common.s
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

	.ident	"@(#)mmu_common.s	1.2	07/05/03 SMI"

/*
 * Niagara-family MMU common routines
 */

#include <sys/asm_linkage.h>
#include <hprivregs.h>
#include <asi.h>
#include <traps.h>
#include <mmu.h>
#include <sun4v/traps.h>
#include <sun4v/mmu.h>

#include <guest.h>
#include <offsets.h>
#include <debug.h>
#include <util.h>

/*
 * revec_dax - revector the current trap to the guest's DAX handler
 *
 * %g1 - fault type
 * %g2 - fault addr
 * %g3 - fault ctx
 */
	ENTRY_NP(revec_dax)
	VCPU_STRUCT(%g4)
	ldx	[%g4 + CPU_MMU_AREA], %g4
	brz,pn	%g4, watchdog_guest
	nop
	stx	%g1, [%g4 + MMU_FAULT_AREA_DFT]
	stx	%g2, [%g4 + MMU_FAULT_AREA_DADDR]
	stx	%g3, [%g4 + MMU_FAULT_AREA_DCTX]
	REVECTOR(TT_DAX)
	SET_SIZE(revec_dax)

/*
 * revec_iax - revector the current trap to the guest's IAX handler
 *
 * %g1 - fault type
 * %g2 - fault addr
 * %g3 - fault ctx
 */
	ENTRY_NP(revec_iax)
	VCPU_STRUCT(%g4)
	ldx	[%g4 + CPU_MMU_AREA], %g4
	brz,pn	%g4, watchdog_guest
	nop
	stx	%g1, [%g4 + MMU_FAULT_AREA_IFT]
	stx	%g2, [%g4 + MMU_FAULT_AREA_IADDR]
	stx	%g3, [%g4 + MMU_FAULT_AREA_ICTX]
	REVECTOR(TT_IAX)
	SET_SIZE(revec_iax)
