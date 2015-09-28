/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: rng.s
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

	.ident	"@(#)rng.s	1.2	07/07/19 SMI"

	.file	"rng.s"

#include <sys/asm_linkage.h>
#include <sys/htypes.h>
#include <asi.h>
#include <mmu.h>
#include <hypervisor.h>
#include <rng_api.h>
#include <rng.h>
#include <sun4v/asi.h>
#include <sparcv9/asi.h>

#include <debug.h>
#include <offsets.h>
#include <util.h>

/*
 * Delay necessary because of how CTL bits are serially
 * sent to RNG hardware.
 */
#define	CTL_REG_DELAY_CYCLES	64

#define	CTL_REG_DELAY(scr)			\
	.pushlocals				; \
	mov	CTL_REG_DELAY_CYCLES, scr	; \
0:						; \
	brnz,pt	scr, 0b				; \
	dec	scr				; \
	.poplocals

/*
 * Locking primitives for RNG_LOCK
 */
#define	RNG_TRYLOCK(rng, scr, lck)		\
	mov	-1, lck				; \
	add	rng, RNG_LOCK, scr		; \
	casa	[scr]ASI_P, %g0, lck

#define	RNG_UNLOCK(rng)				\
	st	%g0, [rng + RNG_LOCK]


/*
 *-----------------------------------------------------------
 * Function: rng_get_diag_control()
 * Arguments:
 *	Input:
 *	Output:
 *		%o0 - EOK (on success),
 *		      EWOULDBLOCK, ENOACCESS (on failure)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_rng_get_diag_control)

	/*
	 * Check that caller has CTL access.
	 */
	GUEST_STRUCT(%g3)
	setx	GUEST_RNG_CTL_ACCESSIBLE, %g5, %g2
	ldx	[%g3 + %g2], %g2
	brz,a,pn %g2, herr_noaccess
	nop

	ROOT_STRUCT(%g4)
	ldx	[%g4 + CONFIG_RNG], %g1

	RNG_TRYLOCK(%g1, %g5, %g2)
	brnz,pn	%g2, herr_wouldblock
	nop

	ldx	[%g3 + GUEST_GID], %g3
	stx	%g3, [%g1 + RNG_CTL + RNG_CTLDATA_GUESTID]

	RNG_UNLOCK(%g1)

	HCALL_RET(EOK)

	SET_SIZE(hcall_rng_get_diag_control)

/*
 *-----------------------------------------------------------
 * Function: rng_ctl_read(struct rng_ctlregs rctlptr)
 * Arguments:
 *	Input:
 *		%o0 - struct rng_ctlregs pointer
 *	Output:
 *		%o0 - EOK (on success),
 *		      EWOULDBLOCK, ENOACCESS, EBADALIGN, ENORADDR (on failure)
 *		%o1 - RNG state
 *		%o2 - Ready delta (system ticks)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_rng_ctl_read)

	btst	SZ_LONG - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	/*
	 * Check that caller has CTL access.
	 */
	GUEST_STRUCT(%g3)
	setx	GUEST_RNG_CTL_ACCESSIBLE, %g5, %g4
	ldx	[%g3 + %g4], %g4
	brz,pn	%g4, herr_noaccess
	nop

	ROOT_STRUCT(%g4)
	ldx	[%g4 + CONFIG_RNG], %g1

	brz,pn	%o0, rdc_noregs
	nop

	mov	RNG_CTLREGS_SIZE, %g2
	RA2PA_RANGE_CONV_UNK_SIZE(%g3, %o0, %g2, herr_noraddr, %g5, %g4)
	! %g4	PA

rdc_noregs:
	RNG_TRYLOCK(%g1, %g5, %g2)
	brnz,a,pn %g2, herr_wouldblock
	  mov	%g0, %o2

	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_STATE], %o1
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_READYTIME], %g3
	rd	STICK, %g5                      ! current time
	sub	%g3, %g5, %o2
	cmp	%g5, %g3
	movgeu	%xcc, %g0, %o2			! delta

	brz,pn	%o0, rdc_ret
	nop

	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG0], %g3
	stx	%g3, [%g4 + RNG_CTLREGS_REG0]
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG1], %g3
	stx	%g3, [%g4 + RNG_CTLREGS_REG1]
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG2], %g3
	stx	%g3, [%g4 + RNG_CTLREGS_REG2]
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG3], %g3
	stx	%g3, [%g4 + RNG_CTLREGS_REG3]

rdc_ret:
	RNG_UNLOCK(%g1)

	HCALL_RET(EOK)

	SET_SIZE(hcall_rng_ctl_read)

/*
 *-----------------------------------------------------------
 * Function: rng_ctl_write(struct rng_ctlregs rctlptr, uint64_t nstate,
 *				uint64_t wtimeout)
 * Arguments:
 *	Input:
 *		%o0 - struct rng_ctlregs pointer
 *		%o1 - New state
 *		%o2 - Watchdog timeout (system ticks)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EWOULDBLOCK, ENOACCESS, EBADALIGN, ENORADDR,
 *		      EIO, EINVAL (on failure)
 *		%o1 - Ready delta (system ticks)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_rng_ctl_write)

	btst	SZ_LONG - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	/*
	 * Check that caller has diagnostic access & control.
	 */
	GUEST_STRUCT(%g3)
	setx	GUEST_RNG_CTL_ACCESSIBLE, %g5, %g4
	ldx	[%g3 + %g4], %g4
	brz,pn	%g4, herr_noaccess
	nop

	mov	RNG_CTLREGS_SIZE, %g2
	RA2PA_RANGE_CONV_UNK_SIZE(%g3, %o0, %g2, herr_noraddr, %g5, %g7)
	mov	%g7, %o0
	! %o0	PA

	ROOT_STRUCT(%g4)
	ldx	[%g4 + CONFIG_RNG], %g1

	RNG_TRYLOCK(%g1, %g5, %g2)
	brnz,a,pn %g2, herr_wouldblock
	  mov	%g0, %o1

	ldx	[%g3 + GUEST_GID], %g5
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_GUESTID], %g4
	cmp	%g5, %g4
	bne,a,pn %xcc, wrc_ret
	  mov	EIO, %g6

	cmp	%o1, RNG_STATE_CONFIGURED
	be,pt	%xcc, wrc_config
	cmp	%o1, RNG_STATE_HEALTHCHECK
	be,pn	%xcc, wrc_config
	cmp	%o1, RNG_STATE_UNCONFIGURED
	be,pn	%xcc, wrc_unconfig
	cmp	%o1, RNG_STATE_ERROR
	bne,a,pn %xcc, wrc_ret
	  mov	EINVAL, %g6

wrc_unconfig:
	/*
	 * newstate = UNCONFIGURED or ERROR.
	 */
	stx	%o1, [%g1 + RNG_CTL + RNG_CTLDATA_STATE]
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_READYTIME], %g4
	rd	STICK, %g5			! current time
	sub	%g4, %g5, %o1
	cmp	%g5, %g4
	movgeu	%xcc, %g0, %o1
	ba	wrc_ret
	mov	EOK, %g6

wrc_config:
	/*
	 * newstate = CONFIGURED or HEALTHCHECK.
	 *
	 * Verify that CTL is ready to be changed.
	 */
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_READYTIME], %g4
	rd	STICK, %g5			! current time
	mov	EWOULDBLOCK, %g6
	cmp	%g5, %g4
	bl,a,pn	%xcc, wrc_ret
	  sub	%g4, %g5, %o1

	stx	%g5, [%g1 + RNG_CTL + RNG_CTLDATA_READYTIME]

	setx	RNG_CTL_MASK, %g6, %g2
	/*
	 * Check callers CTLREG values and make sure they are
	 * valid values first.
	 */
	ldx	[%o0 + RNG_CTLREGS_REG0], %g3
	andncc	%g3, %g2, %g0
	bnz,a,pn %xcc, wrc_ret
	  mov	EINVAL, %g6
	ldx	[%o0 + RNG_CTLREGS_REG1], %g4
	andncc	%g4, %g2, %g0
	bnz,a,pn %xcc, wrc_ret
	  mov	EINVAL, %g6
	ldx	[%o0 + RNG_CTLREGS_REG2], %g5
	andncc	%g5, %g2, %g0
	bnz,a,pn %xcc, wrc_ret
	  mov	EINVAL, %g6
	ldx	[%o0 + RNG_CTLREGS_REG3], %g6
	andncc	%g6, %g2, %g0
	bnz,a,pn %xcc, wrc_ret
	  mov	EINVAL, %g6
	/*
	 * Values are valid.  Save a copy off in our CTLDATA.
	 */
	stx	%g3, [%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG0]
	stx	%g4, [%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG1]
	stx	%g5, [%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG2]
	stx	%g6, [%g1 + RNG_CTL + RNG_CTLDATA_REGS + RNG_CTLREGS_REG3]
	/*
	 * Store values into RNG.CTL.
	 * The RNG hardware control register is funky.   You store
	 * to different control registers by specifying different
	 * bits in the value being stored, but all stores happen
	 * against the same RNG.CTL address.
	 */
	setx	RNG_CTL_ADDR, %o0, %g2
	stx	%g3, [%g2]
	CTL_REG_DELAY(%o0)
	stx	%g4, [%g2]
	CTL_REG_DELAY(%o0)
	stx	%g5, [%g2]
	CTL_REG_DELAY(%o0)
	stx	%g6, [%g2]
	CTL_REG_DELAY(%o0)
	/*
	 * If caller specified a watchdog timeout value of 0,
	 * then that means no watchdog necessary.  If caller
	 * specified negative value then overwrite to 0.
	 */
	cmp	%o2, %g0		
	movl	%xcc, %g0, %o2
	rd	STICK, %g5
	add	%g5, %o2, %g5
	stx	%g5, [%g1 + RNG_CTL + RNG_CTLDATA_READYTIME]
	stx	%o1, [%g1 + RNG_CTL + RNG_CTLDATA_STATE]
	mov	%o2, %o1
	mov	EOK, %g6

wrc_ret:
	RNG_UNLOCK(%g1)

	HCALL_RET(%g6)

	SET_SIZE(hcall_rng_ctl_write)

/*
 *-----------------------------------------------------------
 * Function: rng_data_read_diag(uint64_t addr, uint64_t sz)
 * Arguments:
 *	Input:
 *		%o0 - Address of data buffer
 *		%o1 - Size of data buffer (bytes)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EWOULDBLOCK, ENOACCESS, EBADALIGN, ENORADDR,
 *		      EIO, EINVAL (on failure)
 *		%o1 - Ready delta (system ticks)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_rng_data_read_diag)

	btst	SZ_LONG - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	/*
	 * Check that caller has diagnostic access & control.
	 */
	GUEST_STRUCT(%g3)
	setx	GUEST_RNG_CTL_ACCESSIBLE, %g5, %g4
	ldx	[%g3 + %g4], %g4
	brz,pn	%g4, herr_noaccess
	nop

	/*
	 * Verify size falls within desired range:
	 *	RNG_DATA_MINLEN...RNG_DATA_MAXLEN
	 */
	btst	SZ_LONG - 1, %o1
	bnz,pn	%xcc, herr_badalign
	nop
	setx	RNG_DATA_MAXLEN, %g5, %g4
	cmp	%o1, %g4
	bgu,pn	%xcc, herr_inval
	cmp	%o1, RNG_DATA_MINLEN
	blu,pn	%xcc, herr_inval
	nop

	RA2PA_RANGE_CONV_UNK_SIZE(%g3, %o0, %o1, herr_noraddr, %g2, %g7)
	mov	%g7, %o0

	ROOT_STRUCT(%g4)
	ldx	[%g4 + CONFIG_RNG], %g1

	RNG_TRYLOCK(%g1, %g5, %g2)
	brnz,a,pn %g2, herr_wouldblock
	  mov	%g0, %o1

	ldx	[%g3 + GUEST_GID], %g5
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_GUESTID], %g4
	cmp	%g5, %g4
	bne,a,pn %xcc, rdg_ret
	  mov	EIO, %g6

	/*
	 * Check that the RNG is ready,
	 * i.e. STICK >= ctldata.readytime.
	 */
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_READYTIME], %g4
	rd	STICK, %g5			! current time
	mov	EWOULDBLOCK, %g6
	cmp	%g5, %g4
	bl,a,pn	%xcc, rdg_ret
	  sub	%g4, %g5, %o1

	stx	%g5, [%g1 + RNG_CTL + RNG_CTLDATA_READYTIME]

	setx	RNG_DATA_ADDR, %g3, %g4

rdg_rdloop:
	ldx	[%g4], %g3			! read RNG.DATA
	stx	%g3, [%o0]
	sub	%o1, SZ_LONG, %o1
	brgz,pt	%o1, rdg_rdloop
	add	%o0, SZ_LONG, %o0

	mov	EOK, %g6
	!!
	!! %o1 == 0 after loop.
	!!

rdg_ret:
	RNG_UNLOCK(%g1)

	HCALL_RET(%g6)

	SET_SIZE(hcall_rng_data_read_diag)

/*
 *-----------------------------------------------------------
 * Function: rng_data_read(uint64_t addr)
 * Arguments:
 *	Input:
 *		%o0 - Address of data buffer (size = 8 bytes)
 *	Output:
 *		%o0 - EOK (on success),
 *		      EWOULDBLOCK, ENOACCESS, EBADALIGN, ENORADDR,
 *		      EIO (on failure)
 *		%o1 - Ready delta (system ticks)
 *-----------------------------------------------------------
 */
	ENTRY_NP(hcall_rng_data_read)

	btst	SZ_LONG - 1, %o0
	bnz,pn	%xcc, herr_badalign
	nop

	GUEST_STRUCT(%g3)

	mov	SZ_LONG, %g5
	RA2PA_RANGE_CONV_UNK_SIZE(%g3, %o0, %g5, herr_noraddr, %g2, %g7)
	mov	%g7, %o0
	!!
	!! %o0 = physical address of buffer
	!!

	ROOT_STRUCT(%g4)
	ldx	[%g4 + CONFIG_RNG], %g1

	RNG_TRYLOCK(%g1, %g5, %g2)
	brnz,pn	%g2, herr_wouldblock
	mov	%g0, %o1		! *tdelta = 0

	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_STATE], %g4
	cmp	%g4, RNG_STATE_CONFIGURED
	be,pt	%xcc, rdd_chkrdy
	ldx	[%g1 + RNG_CTL + RNG_CTLDATA_READYTIME], %g2

	mov	EIO, %g6
	cmp	%g4, RNG_STATE_ERROR
	ba	rdd_ret
	move	%xcc, ENOACCESS, %g6

rdd_chkrdy:
	rd	STICK, %g3			! current time
	sub	%g2, %g3, %o1
	cmp	%g3, %g2
	bl,pn	%xcc, rdd_ret
	mov	EWOULDBLOCK, %g6

	stx	%g3, [%g1 + RNG_CTL + RNG_CTLDATA_READYTIME]

	setx	RNG_DATA_ADDR, %g3, %g4
	ldx	[%g4], %g3			! read RNG.DATA
	stx	%g3, [%o0]
	mov	EOK, %g6

rdd_ret:
	RNG_UNLOCK(%g1)

	HCALL_RET(%g6)

	SET_SIZE(hcall_rng_data_read)
