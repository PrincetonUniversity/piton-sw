/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: jbi_regs.h
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

#ifndef _NIAGARA_JBI_REGS_H
#define	_NIAGARA_JBI_REGS_H

#pragma ident	"@(#)jbi_regs.h	1.11	07/01/24 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#define	JBI_BASE		0x8000000000

#define	JBI_CONFIG1		JBI_BASE
#define	JBI_CONFIG2		(JBI_BASE + 0x00008)

#define	JBI_DEBUG		(JBI_BASE + 0x04000)
#define	JBI_DEBUG_ARB		(JBI_BASE + 0x04100)
#define	JBI_ERR_INJECT		(JBI_BASE + 0x04800)

#define	JBI_ERR_CONFIG		(JBI_BASE + 0x10000)
#define	JBI_ERR_LOG		(JBI_BASE + 0x10020)
#define	JBI_ERR_OVF		(JBI_BASE + 0x10028)
#define	JBI_LOG_ENB		(JBI_BASE + 0x10030)
#define	JBI_SIG_ENB		(JBI_BASE + 0x10038)
#define	JBI_LOG_ADDR		(JBI_BASE + 0x10040)
#define	JBI_LOG_DATA0		(JBI_BASE + 0x10050)
#define	JBI_LOG_DATA1		(JBI_BASE + 0x10058)
#define	JBI_LOG_CTRL		(JBI_BASE + 0x10048)
#define	JBI_LOG_PAR		(JBI_BASE + 0x10060)
#define	JBI_LOG_NACK		(JBI_BASE + 0x10070)
#define	JBI_LOG_ARB		(JBI_BASE + 0x10078)
#define	JBI_L2_TIMEOUT		(JBI_BASE + 0x10080)
#define	JBI_ARB_TIMEOUT		(JBI_BASE + 0x10088)
#define	JBI_TRANS_TIMEOUT	(JBI_BASE + 0x10090)
#define	JBI_INTR_TIMEOUT	(JBI_BASE + 0x10098)
#define	JBI_MEMSIZE		(JBI_BASE + 0x100a0)

#define	JBI_PERF_CTL		(JBI_BASE + 0x20000)
#define	JBI_PERF_COUNT		(JBI_BASE + 0x20008)

/* JBI_ERR_LOG bits */
#define	JBI_APAR		(1 << 28)
#define	JBI_CPAR		(1 << 27)
#define	JBI_ADTYPE		(1 << 26)
#define	JBI_L2_TO		(1 << 25)
#define	JBI_ARB_TO		(1 << 24)
#define	JBI_FATAL_MASK		0x2
#define	JBI_FATAL		(1 << 16)
#define	JBI_DPAR_WR		(1 << 15)
#define	JBI_DPAR_RD		(1 << 14)
#define	JBI_DPAR_O		(1 << 13)
#define	JBI_REP_UE		(1 << 12)
#define	JBI_ILLEGAL		(1 << 11)
#define	JBI_UNSUPP		(1 << 10)
#define	JBI_NONEX_WR		(1 << 9)
#define	JBI_NONEX_RD		(1 << 8)
#define	JBI_READ_TO		(1 << 5)
#define	JBI_UNMAP_WR		(1 << 4)
#define	JBI_RSVD4		(1 << 3)
#define	JBI_ERR_CYCLE		(1 << 2)
#define	JBI_UNEXP_DR		(1 << 1)
#define	JBI_INTR_TO		(1 << 0)

/*
 * JBUS Performance Counter Select Encodings
 */
#define	JBI_PERF1_EVT_OFF	0x00
#define	JBI_PERF1_EVT_CYCLES	0x10

#define	JBI_PERF2_EVT_OFF	0x00
#define	JBI_PERF2_EVT_CYCLES	0x01


/* BEGIN CSTYLED */

/*
 * JBI_MEMSIZE register
 * +----------------------------------------------+
 * | RSVD [63:38] | MEMSIZE [37:30] | RSVD [29:0] |
 * +----------------------------------------------+
 *
 * MEMSIZE[37:30] is the memory size in GB.
 * Note: GB == (1 << 30) so just ensure the RSVD bits are clear
 * to get the memory size in bytes.
 */
#define	JBI_MEMSIZE_SHIFT	30
#define	JBI_MEMSIZE_MASK	0xFF
#define JBI_MEMSIZE_BYTES(reg)				\
	srlx	reg, JBI_MEMSIZE_SHIFT, reg		;\
	and	reg, JBI_MEMSIZE_MASK, reg		;\
	sllx	reg, JBI_MEMSIZE_SHIFT, reg

/*
 * These JBI errors have not been initialised before startup. The HV must
 * enable them.
 */
#define	JBI_INTR_ONLY_ERRS	(JBI_DPAR_WR | JBI_REP_UE | JBI_ILLEGAL | \
				JBI_UNSUPP | JBI_NONEX_WR | JBI_UNMAP_WR | \
				JBI_UNEXP_DR)

#define	JBI_ABORT_ERRS	\
	(JBI_UNEXP_DR | JBI_NONEX_WR | JBI_NONEX_RD |   \
	    JBI_ILLEGAL | JBI_UNSUPP | JBI_UNMAP_WR)


#define	ENABLE_JBI_INTR_ERRS(jbi_errors, reg2, reg3)			\
	setx	JBI_LOG_ENB, reg2, reg3					;\
	ldx	[reg3], reg2						;\
	or	jbi_errors, reg2, reg2					;\
	stx	reg2, [reg3]						;\
	setx	JBI_SIG_ENB, reg2, reg3					;\
	ldx	[reg3], reg2						;\
	or	jbi_errors, reg2, reg2					;\
	stx	reg2, [reg3]


/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA_JBI_REGS_H */
