/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errs_common.s
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

	.ident	"@(#)errs_common.s	1.8	07/05/03 SMI"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <hypervisor.h>
#include <sparcv9/asi.h>
#include <sun4v/asi.h>
#include <asi.h>

#include <offsets.h>
#include <strand.h>
#include <debug.h>
#include <util.h>
#include <errs_common.h>
#include <svc.h>
#include <abort.h>

/*
 * send_diag_erpt -   send the diag error report. The offset of the error
 * report buffwe is passed in as E_OFF
 *
 * %g1 - erpt 
 * %g2 - ptr to sent flag
 * %g3 - packet size
 * %g7 - return address
 * %g4 - %g6 used and garbbled
 *
 * For service delivery the flag is not cleared until the packet
 * has been received (ACK) by the SP, this ensures that we dont trample
 * on the current report in the sram while the notify packet is being delivered
 */
	ENTRY_NP(send_diag_erpt)
#if defined(CONFIG_FPGA) && defined(CONFIG_SVC)
	CPU_PUSH(%g7, %g4, %g5, %g6)		/* save return addr */
	CPU_PUSH(%g2, %g4, %g5, %g6)		/* save unsent flag ptr */
	ROOT_STRUCT(%g6)
	add	%g6, CONFIG_SRAM_ERPT_BUF_INUSE, %g5
	mov	ERR_BUF_BUSY, %g4
	casx	[%g5], %g0, %g4
	brnz,pn	%g4, 1f				/* buf busy, flag it  */
	nop
	ldx	[%g6 + CONFIG_ERPT_PA], %g2	/* erpt buffer (dest) */
	brz	%g2, 2f				/* no buffer */
	add	%g2, 7, %g2			/* align pa */
	andn	%g2, 7, %g2
	HVCALL(xcopy)				/* send erpt */
	ldx	[%g6 + CONFIG_ERROR_SVCH], %g1 /* error service */
	brz	%g1, 2f				/* skip if no svc */
	add	%g6, CONFIG_ERPT_PA, %g2	/* error present pkt */
	add	%g0, ERPT_SVC_PKT_SIZE, %g3	/* pkt len */
	HVCALL(svc_internal_send)		/* send erpt */
	brnz,a,pt	%g1, 1f
	  ldx	[%g2 + CPU_ROOT], %g6		/* config data */
	CPU_POP(%g4, %g1, %g2, %g3)		/* restore unsent flag ptr */
	st	%g0, [%g4]			/* flag as no need to send */
	CPU_POP(%g7, %g1, %g2, %g3)		/* restore callers return */
	HVRET
1:
	/*
	 * SRAM is busy, flag so it gets sent later
	 * %g6 still contains the ROOT
	 */
	CPU_POP(%g4, %g1, %g2, %g3)
	mov	1, %g3
	st	%g3, [%g4]			/* flag pkt */
	add	%g6, CONFIG_ERRS_TO_SEND, %g6
	ldx	[%g6], %g1
0:	add	%g1, 1, %g3
	casx	[%g6], %g1, %g3
	cmp	%g1, %g3
	bne,a,pn %xcc, 0b
	mov	%g3, %g1
	CPU_POP(%g7, %g1, %g2, %g3)	 /* restore callers return */
	HVRET
2:
	CPU_POP(%g4, %g1, %g2, %g3)	 /* pop unsent flag ptr */
	CPU_POP(%g7, %g1, %g2, %g3)	 /* restore callers return */
	HVRET
#else   /* !(CONFIG_FPGA && CONFIG_SVC) */
	HVRET
#endif  /* CONFIG_FPGA && CONFIG_SVC */
	SET_SIZE(send_diag_erpt)

/*
 * send_diag_erpt_nolock -   send the diag error report. The offset of the error
 * report buffwe is passed in as E_OFF
 *
 * %g1 - erpt 
 * %g2 - ptr to sent flag
 * %g3 - packet size
 * %g7 - return address
 * %g4 - %g6 used and garbbled
 *
 * For service delivery the flag is not cleared until the packet
 * has been received (ACK) by the SP, this ensures that we dont trample
 * on the current report in the sram while the notify packet is being delivered
 */
	ENTRY_NP(send_diag_erpt_nolock)
#ifdef NO_SVC_EREPORTS
	HVRET
#endif
#if defined(CONFIG_FPGA) && defined(CONFIG_SVC)
	CPU_PUSH(%g7, %g4, %g5, %g6)		/* save unsent flag ptr */
	CPU_PUSH(%g2, %g4, %g5, %g6)		/* save return addr */
	ROOT_STRUCT(%g6)
	add	%g6, CONFIG_SRAM_ERPT_BUF_INUSE, %g5
	mov	ERR_BUF_BUSY, %g4
	casx	[%g5], %g0, %g4
	brnz,pn	%g4, 1f				/* buf busy, flag it */
	nop
	ldx	[%g6 + CONFIG_ERPT_PA], %g2	/* erpt buffer (dest) */
	brz	%g2, 2f				/* no buffer */
	add	%g2, 7, %g2			/* align pa */
	andn	%g2, 7, %g2
	HVCALL(xcopy)				/* send erpt */
	ldx	[%g6 + CONFIG_ERROR_SVCH], %g1 /* error service */
	brz	%g1, 2f				/* skip if no svc */
	add	%g6, CONFIG_ERPT_PA, %g2	/* error present pkt */
	add	%g0, ERPT_SVC_PKT_SIZE, %g3	/* pkt len */
	HVCALL(svc_internal_send_nolock)	/* send erpt */
	ROOT_STRUCT(%g6)
	ldx	[%g6 + CONFIG_ERROR_SVCH], %g6	/* error service handle */
	ld	[%g6 + SVC_CTRL_STATE], %g5
	andn	%g5, SVC_FLAGS_RI, %g5
	st	%g5, [%g6 + SVC_CTRL_STATE]	! clear RECV pending
	UNLOCK(%g6, SVC_CTRL_LOCK)
	ROOT_STRUCT(%g6)
	ldx	[%g6 + CONFIG_SVCS], %g6		! svc root
	UNLOCK(%g6, HV_SVC_DATA_LOCK)
	CPU_POP(%g4, %g1, %g2, %g3)
	st	%g0, [%g4]			/* flag as no need to send */
	CPU_POP(%g7, %g1, %g2, %g3)		/* restore callers return */
	HVRET
1:
	/*
	 * SRAM is busy, flag so it gets sent later
	 * %g6 still contains the ROOT
	 */
	CPU_POP(%g4, %g1, %g2, %g3)
	mov	1, %g3
	st	%g3, [%g4]			/* flag pkt */
	add	%g6, CONFIG_ERRS_TO_SEND, %g6
	ldx	[%g6], %g1
0:	add	%g1, 1, %g3
	casx	[%g6], %g1, %g3
	cmp	%g1, %g3
	bne,a,pn %xcc, 0b
	mov	%g3, %g1
	CPU_POP(%g7, %g1, %g2, %g3)		/* restore callers return */

	HVRET
2:
	CPU_POP(%g4, %g1, %g2, %g3)		/* pop unsent flag ptr */
	CPU_POP(%g7, %g1, %g2, %g3)		/* restore callers return */
	HVRET
#else   /* !(CONFIG_FPGA && CONFIG_SVC) */
	HVRET
#endif  /* CONFIG_FPGA && CONFIG_SVC */
	SET_SIZE(send_diag_erpt_nolock)
