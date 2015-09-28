/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ncs.h
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

#ifndef	_NCS_H
#define	_NCS_H

#pragma ident	"@(#)ncs.h	1.3	07/05/03 SMI"

#ifdef	__cplusplus
extern "C" {
#endif

#include <ncs_api.h>

/*
 * MAU states
 */
#define	MAU_STATE_UNCONFIGURED	0x0
#define	MAU_STATE_RUNNING	0x1	/* mau configured & running */
#define	MAU_STATE_ERROR		0xF	/* mau is in the error state */
/*
 * CWQ states
 */
#define	CWQ_STATE_UNCONFIGURED	0x0
#define	CWQ_STATE_RUNNING	0x1	/* cwq configured & running */
#define	CWQ_STATE_ERROR		0xF	/* cwq is in the error state */

/*
 * MAU/CWQ Queue state.
 */
#define	NCS_QSTATE_UNCONFIGURED		0
#define	NCS_QSTATE_CONFIGURED		1

#define	NCS_MIN_MAU_NENTRIES	2
#define	NCS_MIN_CWQ_NENTRIES	2
#define	NCS_MAX_CWQ_NENTRIES	64

#ifndef	_ASM
/*
 * Queuing structure used by crypto hypervisor support
 * to represent queue of requests for MAU/CWQ.  Kernel
 * side inserts requests into the queue which are
 * subsequently picked up in the context of the
 * hypervisor.
 *
 * Struct is globally kept in a per-MAU/CWQ array.
 * NCS code indexes into appropriate queue
 * using the ID of the MAU/CWQ (Core) on which
 * it's running at the time.
 */
typedef struct mau_queue {
	uint64_t	mq_lock;
	uint32_t	mq_state;
	uint32_t	mq_busy;
	uint64_t	mq_base;
	uint64_t	mq_base_ra;
	uint64_t	mq_end;
	uint64_t	mq_head;
	uint64_t	mq_head_marker;
	uint64_t	mq_tail;
	uint64_t	mq_nentries;
	uint64_t	mq_cpu_pid;	/* HV intr target */
} mau_queue_t;


/*
 * The MA and CWQ interrupt cookies are obtained
 * via vdev_intr_register() and passed to
 * vdev_intr_generate() to initiate the interrupt.
 *
 * The active field gets set via the respective
 * mau/cwq_intr() routines.
 */
typedef struct crypto_intr {
	uint64_t	ci_cookie;
	uint64_t	ci_active;
	uint64_t	ci_data;
} crypto_intr_t;



#endif	/* !_ASM */

/*
 * Saves us from doing mulx's when using a
 * mau/cwq id as an index into guest.maus[]
 * or guest.cwqs[].
 */
#define	GUEST_MAUS_SHIFT	SHIFT_LONG
#define	GUEST_CWQS_SHIFT	SHIFT_LONG

#ifdef	__cplusplus
}
#endif

#endif	/* _NCS_H */
