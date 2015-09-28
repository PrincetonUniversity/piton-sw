/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hcall_diag.s
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

	.ident	"@(#)hcall_diag.s	1.98	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <asi.h>
#include <guest.h>
#include <offsets.h>
#include <util.h>

/*
 * diag_ra2pa
 *
 * arg0 ra (%o0)
 * --
 * ret0 status (%o0)
 * ret1 pa (%o1)
 */
	ENTRY_NP(hcall_diag_ra2pa)
	GUEST_STRUCT(%g1)
	set	GUEST_DIAGPRIV, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	nop

	RA2PA_RANGE_CONV(%g1, %o0, 1, herr_noraddr, %g2, %o1)

	HCALL_RET(EOK)
	SET_SIZE(hcall_diag_ra2pa)


/*
 * diag_hexec
 *
 * arg0 physical address of routine to execute (%o0)
 * --
 * ret0 status if noaccess, other SEP (somebody else's problem) (%o0)
 */
	ENTRY_NP(hcall_diag_hexec)
	GUEST_STRUCT(%g1)
	set	GUEST_DIAGPRIV, %g2
	ldx	[%g1 + %g2], %g2
	brz,pn	%g2, herr_noaccess
	nop

	jmp	%o0
	nop
	/* caller executes "done" */
	SET_SIZE(hcall_diag_hexec)
