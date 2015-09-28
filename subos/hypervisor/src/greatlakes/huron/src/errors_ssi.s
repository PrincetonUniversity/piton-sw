/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errors_ssi.s
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

#pragma ident	"@(#)errors_ssi.s	1.1	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sun4v/asi.h>
#include <sun4v/queue.h>
#include <hypervisor.h>
#include <asi.h>
#include <mmu.h>
#include <hprivregs.h>

#include <offsets.h>
#include <util.h>
#include <error_defs.h>
#include <error_regs.h>
#include <error_asm.h>
#include <error_ssi.h>
#include <ncu.h>

	/*
	 * Dump SSI diagnostic data
	 * %g7 return address
	 */
	ENTRY(dump_ssi)

	GET_ERR_DIAG_DATA_BUF(%g1, %g2)
	/*
	 * get diag_buf->err_ssi
	 */
	add	%g1, ERR_DIAG_BUF_DIAG_DATA, %g1
	add	%g1, ERR_DIAG_DATA_SSI_INFO, %g1

	setx	SSI_LOG, %g2, %g3
	ldx	[%g3], %g2
	setx	SSI_TIMEOUT, %g4, %g3
	ldx	[%g3], %g3
	stx	%g2, [%g1 + ERR_SSI_LOG]
	stx	%g3, [%g1 + ERR_SSI_TIMEOUT]

	HVRET

	SET_SIZE(dump_ssi)

	/*
	 * Clear ESRs after SSI error
	 * args
	 * %g7	return address
	 */
	ENTRY(clear_ssi)

	setx	SSI_LOG, %g2, %g3
	ldx	[%g3], %g2
	stx	%g2, [%g3]

	HVRET

	SET_SIZE(clear_ssi)

