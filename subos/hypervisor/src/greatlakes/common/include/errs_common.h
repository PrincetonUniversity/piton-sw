/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: errs_common.h
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

#ifndef	_ERRS_COMMON_H
#define	_ERRS_COMMON_H

#pragma ident	"@(#)errs_common.h	1.6	07/05/03 SMI"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Guest error report: Error Handle (ehdl) encoding
 * The error handle is 64 bits long. It will be used to generate a
 * unique error handle.  Each strand has an incremental value.
 *
 * 63           56 55  52 51                                              0
 *  ----------------------------------------------------------------------
 * | PHYS CPU ID  | TL    |                incrmt num                     |
 *  ----------------------------------------------------------------------
 */
#define	EHDL_TL_BITS		4
#define	EHDL_SEQ_MASK		0x000FFFFFFFFFFFFF
#define	EHDL_SEQ_MASK_SHIFT	12	/* use this strip off upper bits */
#define	EHDL_CPUTL_SHIFT	52

#define	ERPT_TYPE_CPU		0x1
#define	ERPT_TYPE_VPCI		0x2

/*
 * in:
 *
 * out:
 * scr1 -> unique error sequence
 *
 */
/* BEGIN CSTYLED */
#define	GEN_SEQ_NUMBER(scr1, scr2)					\
	STRAND_STRUCT(scr2);						;\
	ldx	[scr2 + STRAND_ERR_SEQ_NO], scr1	/* get current seq# */	;\
	add	scr1, 1, scr1			/* new seq#	    */	;\
	stx	scr1, [scr2 + STRAND_ERR_SEQ_NO]	/* update seq#      */	;\
	sllx	scr1, EHDL_SEQ_MASK_SHIFT, scr1				;\
	srlx	scr1, EHDL_SEQ_MASK_SHIFT, scr1	/* scr1 = normalized seq# */;\
	ldub	[scr2 + STRAND_ID], scr2	/* scr2 has CPUID    */	;\
	sllx	scr2, EHDL_TL_BITS, scr2	/* scr2 << EHDL_TL_BITS */;\
	sllx	scr2, EHDL_CPUTL_SHIFT, scr2	/* scr2 now has cpuid in 63:56 */  ;\
	or	scr2, scr1, scr1		/* scr1 now has ehdl without tl */ ;\
	rdpr	%tl, scr2			/* scr2 = %tl        */	;\
	sllx	scr2, EHDL_CPUTL_SHIFT, scr2	/* scr2 tl in position  */;\
	or	scr2, scr1, scr1		/* scr1 -> ehdl   */
/* END CSTYLED */

/*
 * A error channel packet gets sent to the vbsc with the PA and size
 * pointing the location of the bulk data.
 * HV obtains the PA and the Size avail from the PDs. They correspond
 * to a location in sram.
 *
 * There is only 1 sram error buffer per system, so it needs to be shared
 * across cpus, fire leaves, and guests.
 * The err_buf_inuse flag on the config struct is used for this purpose.
 * The following flag defines the sram error buffer as busy.
 *
 */
#define	ERR_BUF_BUSY	1

/*
 * Software Initiated Reset type codes
 */
#define	SIR_TYPE_FATAL_DBU		1


#ifdef __cplusplus
}
#endif

#endif /* _ERRS_COMMON_H */
