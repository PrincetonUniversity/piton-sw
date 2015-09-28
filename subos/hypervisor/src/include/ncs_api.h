/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: ncs_api.h
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

#ifndef	_NCS_API_H
#define	_NCS_API_H

#pragma ident	"@(#)ncs_api.h	1.4	07/05/03 SMI"

#ifdef	__cplusplus
extern "C" {
#endif

#include <mau_api.h>

/*
 * NCS API v1.0 definitions (PSARC/2005/125)
 */

/*
 * NCS Crypto Function Numbers
 */
#define	NCS_V10_QCONF		0x1
#define	NCS_V10_QTAIL_UPDATE	0x2

/*
 * The following are parameters to the NCS_QTAIL_UPDATE calls:
 *
 *      NCS_SYNC	Perform MA/SPU operations synchronously,
 *			i.e. wait for all enqueued operations
 *			to complete before progressing to
 *			next one.
 *      NCS_ASYNC	Perform MA/SPU operations asynchronously,
 *			i.e. kick off the next MA/SPU operation
 *			without waiting for its completion.
 */
#define	NCS_SYNC	0
#define	NCS_ASYNC	1

/*
 * Pointers passed to NCS must be on 8-byte boundary.
 */
#define	NCS_PTR_ALIGN	8

/*
 * CWQ pointers must be on 64-byte boundary.
 */
#define	NCS_CWQ_PTR_ALIGN	64

#ifndef	_ASM

typedef struct ncs_qconf_arg {
	uint64_t	nq_mid;
	uint64_t	nq_base;
	uint64_t	nq_end;
	uint64_t	nq_nentries;
} ncs_qconf_arg_t;

typedef struct ncs_qtail_update_arg {
	uint64_t	nu_mid;
	uint64_t	nu_tail;
	uint64_t	nu_syncflag;
} ncs_qtail_update_arg_t;

/*
 * The interface to the MAU is via the following data structures. The
 * structure consists of a copy of all relevant registers required to perform
 * the requested operation.
 */
typedef struct ma_regs {
	union ma_ctl	mr_ctl;
	union ma_mpa	mr_mpa;
	union ma_ma	mr_ma;
	uint64_t	mr_np;
} ma_regs_t;

typedef union cwq_cw_ret {
	uint64_t	cw_ret_dst_addr;
	uint64_t	cw_ret_csr;
} cwq_cw_ret_t;

typedef struct cwq_cw {
	uint64_t	cw_ctlbits;
	uint64_t	cw_src_addr;
	uint64_t	cw_auth_key_addr;
	uint64_t	cw_auth_iv_addr;
	uint64_t	cw_final_auth_state_addr;
	uint64_t	cw_enc_key_addr;
	uint64_t	cw_enc_iv_addr;
	cwq_cw_ret_t	cw_ret;
} cwq_cw_t;

#endif /* !_ASM */

/*
 * struct ncs_hvdesc.nhd_state
 */
#define	ND_STATE_FREE		0
#define	ND_STATE_PENDING	1
#define	ND_STATE_BUSY		2
#define	ND_STATE_DONE		3
#define	ND_STATE_ERROR		4
/*
 * struct ncs_hvdesc.nhd_type
 */
#define	ND_TYPE_UNASSIGNED	0x00
#define	ND_TYPE_MA		0x01

#ifndef _ASM
/*
 * NCS HV descriptor structure (ncs_hvdesc) MUST MATCH
 * corresponding one in kernel/driver.
 * Structure padded to the next power of 2.
 */
struct ncs_hvdesc {
	uint64_t	nhd_state;	/* set in OS/HV */
	uint64_t	nhd_type;	/* set in OS */
	ma_regs_t	nhd_regs;	/* used in HV */
	uint64_t	nhd_errstatus;	/* set in HV (v2.0) */
	uint64_t	_padding;
};

#endif /* !_ASM */

/*
 * NCS HV API v2.0 definitions (FWARC/2006/174)
 *
 * Some of the structures above (v1.0) are inherited for v2.0
 */
/*
 * In v2.0, the nhd_type field has the following values
 * when non-zero (unassigned).  The nhd_type field indicates
 * whether the descriptor is the beginning of a crypto job,
 * the continuation, or the end/last descriptor in a job.
 * A job may be comprised of multiple descriptors.
 */
#define	ND_TYPE_START	0x01
#define	ND_TYPE_CONT	0x02
#define	ND_TYPE_END	0x80

#define	ND_ERR_OK	0x00
#define	ND_ERR_INVOP	0x01
#define	ND_ERR_HWE	0x02

/*
 * Types of queues supported by NCS
 */
#define	NCS_QTYPE_MAU	0x1
#define	NCS_QTYPE_CWQ	0x2

#ifdef	__cplusplus
}
#endif

#endif	/* _NCS_API_H */
