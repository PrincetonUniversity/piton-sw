/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: hvctl.s
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

	.ident	"@(#)hvctl.s	1.5	07/05/03 SMI"

/*
 * Hypervisor control interface
 */

#include <config.h>
#include <offsets.h>
#include <hvctl.h>
#include <vdev_intr.h>
#include <guest.h>
#include <strand.h>
#include <vcpu.h>
#include <abort.h>
#include <util.h>
#include <ldc.h>
#include <debug.h>
#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <sparcv9/asi.h>
#include <asi.h>
#include <sun4v/queue.h>

/* FIXME: fix the files where these #defs to be visible */
#define	IVDR_THREAD 8		/* XXX */


/*
 * callback for hv control
 *
 * %g1 = callback arg (config struct)
 * %g2 = payload
 * %g3 = size
 * %g7 = return address
 */
	ENTRY_NP(hvctl_svc_callback)

#define HVLDC_RD_IDATA(pload, conf, idx, tmp)			 \
	ldx	[pload + (idx*8)], tmp				;\
	stx	tmp, [conf + (CONFIG_HVCTL_IBUF+(idx*8))]

	HVLDC_RD_IDATA(%g2, %g1, 0, %g3)		! load payload
	HVLDC_RD_IDATA(%g2, %g1, 1, %g3)
	HVLDC_RD_IDATA(%g2, %g1, 2, %g3)
	HVLDC_RD_IDATA(%g2, %g1, 3, %g3)
	HVLDC_RD_IDATA(%g2, %g1, 4, %g3)
	HVLDC_RD_IDATA(%g2, %g1, 5, %g3)
	HVLDC_RD_IDATA(%g2, %g1, 6, %g3)
	HVLDC_RD_IDATA(%g2, %g1, 7, %g3)

	STRAND_PUSH(%g7, %g2, %g3)

	HVCALL(vcpu_state_save)

	! TODO: verify checksum match, drop packet on mismatch

	!
	! zero reply buffer
	!
	ROOT_STRUCT(%g1)
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 0]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 8]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 16]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 24]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 32]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 40]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 48]
	stx	%g0, [%g1 + CONFIG_HVCTL_OBUF + 56]
 
	wrpr	%g0, 0, %tl
	wrpr	%g0, 0, %gl
	HVCALL(setup_c_environ)
	call	hv_control_pkt
	nop

.try_again:
	CONFIG_STRUCT(%g3)
	add	%g3, CONFIG_HVCTL_OBUF, %g2
	ldx	[%g3 + CONFIG_HVCTL_LDC], %g1

	add	%g3, CONFIG_HVCTL_LDC_LOCK, %g7
	SPINLOCK_ENTER(%g7, %g4, %g5)

	! call hv_ldc_send_pkt(hvldc_idx, bufptr)
	HVCALL(hv_ldc_send_pkt)

	CONFIG_STRUCT(%g3)
	add	%g3, CONFIG_HVCTL_LDC_LOCK, %g7
	SPINLOCK_EXIT(%g7)

	! Busy wait if can't deliver ...
	! FIXME: need a send queue instead.
	cmp	%g1, EWOULDBLOCK
	be,pn	%xcc, .try_again
	cmp	%g1, ETOOMANY
	be,pn	%xcc, .try_again
	 nop

	HVCALL(vcpu_state_restore)

	STRAND_POP(%g7, %g2)

	HVRET
	SET_SIZE(hvctl_svc_callback)
