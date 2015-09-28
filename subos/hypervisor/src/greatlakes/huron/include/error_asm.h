/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: error_asm.h
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

#ifndef _NIAGARA2_ERROR_ASM_H
#define	_NIAGARA2_ERROR_ASM_H

#pragma ident	"@(#)error_asm.h	1.6	07/09/18 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/htypes.h>
#include <util.h>
#include <debug.h>
#include <traps.h>
#include <error_defs.h>
#include <error_soc.h>

/* BEGIN CSTYLED */

/*
 * All the strand->strand_err_*[TL] data is stored as pointers, one per
 * trap level. To get to the appropriate pointer we multiply by
 * sizeof(uint64_t *), or use (sllx << 3).
 */
#define	STRAND_ERR_POINTER_SHIFT			3

#define	GET_STRAND_ERR_TL_ENTRY(tl_entry, offset, scr1)		\
	STRAND_STRUCT(tl_entry)					;\
	rdpr	%tl, scr1					;\
	dec	scr1						;\
	sllx	scr1, STRAND_ERR_POINTER_SHIFT, scr1		;\
	add	scr1, offset, scr1				;\
	ldx	[tl_entry + scr1], tl_entry

#define	SET_STRAND_ERR_TL_ENTRY(tl_entry, offset, scr1, scr2)	\
	STRAND_STRUCT(scr2)					;\
	rdpr	%tl, scr1					;\
	dec	scr1						;\
	sllx	scr1, STRAND_ERR_POINTER_SHIFT, scr1		;\
	add	scr1, offset, scr1				;\
	stx	tl_entry, [scr2 + scr1]


/*
 * returns strand->strand_err_table_entry[TL] in err_table_entry
 */
#define	GET_ERR_TABLE_ENTRY(err_table_entry, scr1)		\
	GET_STRAND_ERR_TL_ENTRY(err_table_entry, STRAND_ERR_TABLE_ENTRY, scr1)

/*
 * returns strand->strand_diag_buf[TL] in diag_buf
 */
#define	GET_ERR_DIAG_BUF(diag_buf, scr1)			\
	GET_STRAND_ERR_TL_ENTRY(diag_buf, STRAND_DIAG_BUF, scr1)

/*
 * returns strand->strand_diag_buf[TL].err_diag_data in diag_buf
 */
#define	GET_ERR_DIAG_DATA_BUF(diag_data_buf, scr1)		\
	.pushlocals						;\
	GET_ERR_DIAG_BUF(diag_data_buf, scr1)			;\
	brnz,a,pt	diag_data_buf, 1f			;\
	add	diag_data_buf, ERR_DIAG_RPRT_ERR_DIAG, diag_data_buf	;\
1:	.poplocals

/*
 * returns strand->strand_sun4v_rprt_buf[TL] in rprt_buf
 */
#define	GET_ERR_SUN4V_RPRT_BUF(rprt_buf, scr1)			\
	GET_STRAND_ERR_TL_ENTRY(rprt_buf, STRAND_SUN4V_RPRT_BUF, scr1)
/*
 * puts err_table_entry in strand->strand_err_table_entry[TL] 
 */
#define	SET_ERR_TABLE_ENTRY(err_table_entry, scr1, scr2)		\
	SET_STRAND_ERR_TL_ENTRY(err_table_entry, STRAND_ERR_TABLE_ENTRY, scr1, scr2)

/*
 * The strand->strand_err_*[TL] ESR registers are stored as uint64_t, one per
 * trap level. To get to the appropriate pointer we multiply by
 * sizeof(uint64_t *), or use (sllx << 3).
 */
#define	STRAND_ERR_REG_SHIFT			3

/*
 * stores esr in strand->strand_err_{isfsr|dsfsr|dsfar|desr|dfesr}[TL]
 */
#define	STORE_ERR_ESR(desr, esr, scr1, scr2)			\
	STRAND_STRUCT(scr2)					;\
	rdpr	%tl, scr1					;\
	dec	scr1						;\
	sllx	scr1, STRAND_ERR_REG_SHIFT, scr1	 	;\
	add	scr1, esr, scr1					;\
	stx	desr, [scr2 + scr1]

/*
 * stores isfsr in strand->strand_err_isfsr[TL]
 */
#define	STORE_ERR_ISFSR(isfsr, scr1, scr2)			\
	STORE_ERR_ESR(isfsr, STRAND_ERR_ISFSR, scr1, scr2)
/*
 * stores dsfsr in strand->strand_err_dsfsr[TL]
 */
#define	STORE_ERR_DSFSR(dsfsr, scr1, scr2)			\
	STORE_ERR_ESR(dsfsr, STRAND_ERR_DSFSR, scr1, scr2)
/*
 * stores dsfar in strand->strand_err_dsfar[TL]
 */
#define	STORE_ERR_DSFAR(dsfar, scr1, scr2)			\
	STORE_ERR_ESR(dsfar, STRAND_ERR_DSFAR, scr1, scr2)
/*
 * stores desr in strand->strand_err_desr[TL]
 */
#define	STORE_ERR_DESR(desr, scr1, scr2)			\
	STORE_ERR_ESR(desr, STRAND_ERR_DESR, scr1, scr2)
/*
 * stores dfesr in strand->strand_err_dfesr[TL]
 */
#define	STORE_ERR_DFESR(dfesr, scr1, scr2)			\
	STORE_ERR_ESR(dfesr, STRAND_ERR_DFESR, scr1, scr2)

/*
 * stores reg in strand->strand_err_return_addr[TL]
 */
#define	STORE_ERR_RETURN_ADDR(reg, scr1, scr2)			\
	STORE_ERR_ESR(reg, STRAND_ERR_RETURN_ADDR, scr1, scr2)
/*
 * loads esr from strand->strand_err_{isfsr|dsfsr|dsfar|desr|dfesr}[TL]
 */
#define	GET_ERR_ESR(esr_reg, esr, scr1)				\
	STRAND_STRUCT(esr_reg)					;\
	rdpr	%tl, scr1					;\
	dec	scr1						;\
	sllx	scr1, STRAND_ERR_POINTER_SHIFT, scr1		;\
	add	scr1, esr, scr1					;\
	ldx	[esr_reg + scr1], esr_reg

/*
 * returns strand->strand_err_isfsr[TL] in isfsr
 */
#define	GET_ERR_ISFSR(isfsr, scr1)				\
	GET_ERR_ESR(isfsr, STRAND_ERR_ISFSR, scr1)

/*
 * returns strand->strand_err_dsfsr[TL] in dsfsr
 */
#define	GET_ERR_DSFSR(dsfsr, scr1)				\
	GET_ERR_ESR(dsfsr, STRAND_ERR_DSFSR, scr1)

/*
 * returns strand->strand_err_dsfar[TL] in dsfar
 */
#define	GET_ERR_DSFAR(dsfar, scr1)				\
	GET_ERR_ESR(dsfar, STRAND_ERR_DSFAR, scr1)

/*
 * returns strand->strand_err_desr[TL] in desr
 */
#define	GET_ERR_DESR(desr, scr1)				\
	GET_ERR_ESR(desr, STRAND_ERR_DESR, scr1)

/*
 * returns strand->strand_err_dfesr[TL] in dfesr
 */
#define	GET_ERR_DFESR(dfesr, scr1)				\
	GET_ERR_ESR(dfesr, STRAND_ERR_DFESR, scr1)

/*
 * returns strand->strand_err_return_addr[TL] in reg
 */
#define	GET_ERR_RETURN_ADDR(reg, scr1)				\
	GET_ERR_ESR(reg, STRAND_ERR_RETURN_ADDR, scr1)

/*
 * Enable precise error traps
 */
#define	ENABLE_PSCCE(scr1, scr2, scr3)			\
	setx	ERR_PSCCE, scr2, scr1			;\
	mov	CORE_ERR_TRAP_EN, scr2			;\
	ldxa	[scr2]ASI_ERR_EN, scr3			;\
	or	scr3, scr1, scr3			;\
	stxa	scr3, [scr2]ASI_ERR_EN

/*
 * Disable precise error traps
 */
#define	DISABLE_PSCCE(scr1, scr2, scr3)			\
	setx	ERR_PSCCE, scr2, scr1			;\
	mov	CORE_ERR_TRAP_EN, scr2			;\
	ldxa	[scr2]ASI_ERR_EN, scr3			;\
	andn	scr3, scr1, scr3			;\
	stxa	scr3, [scr2]ASI_ERR_EN

/*
 * If TSTATE.GL == GL, we save GLOBALS[GL] -> cpu_globals[TL - 1]
 */

#ifdef IRF_ECC_ERRATA
/*
 * The IRF fix is to work around a problem with the way the N2
 * chip checks ECC on privileged/hyper-privileged and ASR
 * accesses. As well as checking the ECC on the target PR/ASR/HPR
 * of the instruction in question, it also checks the ECC of
 * an unrelated general purpose register. So, for example,
 * the instruction
 * 
 * rd    %asr25, %g5        (%asr25	STICK)
 * 
 * checks ECC on the STICK register, on %g5 (for the current
 * GL), but also checks the ECC for %i0. So if the original IRF
 * error trap happened on %i0, we get another nested trap.
 * 
 * The workaround is not to use  the ASR/PR/HPR registers that do
 * this as we can get nested IRF traps which eventually cause
 * RED_State.
 * 
 * Note that the ASR/PR/HPR accesses which also check a global
 * register check the global register at GL == current GL, which
 * if we got the IRF on a global register, will not be the
 * same as Trap GL, so we don't get the nested traps.
 * 
 * There is (of course) an exception, where if we get an IRF
 * trap at TL> MAXGL, we are out of options, as current GL == Trap
 * GL. We have to look at the trap stack array, and we have to
 * use global registers so if we get an IRF error on a global at
 * TL > MAXGL we are going to get nested traps and RED_State. 
 */
#define	GET_ERR_GL(gl_reg)					\
	.pushlocals						;\
	rdpr	%tt, gl_reg					;\
	cmp	gl_reg, TT_PROCERR				;\
	bne,a,pt	%xcc, 0f				;\
	  rdpr	%gl, gl_reg					;\
	mov	MMU_SFAR, gl_reg				;\
	ldxa	[gl_reg]ASI_DMMU, gl_reg /* D_SFAR */		;\
	srlx	gl_reg, DSFAR_IRF_GL_SHIFT, gl_reg		;\
	and	gl_reg, DSFAR_IRF_GL_MASK, gl_reg		;\
	/* gl_reg %gl when error trap taken */			;\
	inc	gl_reg						;\
	/* gl_reg saturated at MAXGL */				;\
	and	gl_reg, DSFAR_IRF_GL_MASK, gl_reg		;\
	/* gl_reg current %gl */				;\
0:								;\
	.poplocals	

#define	GET_ERR_CWP(cwp_reg)					\
	.pushlocals						;\
	rdpr	%tt, cwp_reg					;\
	cmp	cwp_reg, TT_PROCERR				;\
	bne,a,pt	%xcc, 0f				;\
	  rdpr	%cwp, cwp_reg					;\
	rdpr	%tstate, cwp_reg				;\
	srlx	cwp_reg, TSTATE_CWP_SHIFT, cwp_reg		;\
	and	cwp_reg, TSTATE_CWP_MASK, cwp_reg		;\
0:								;\
	.poplocals	

#define	GET_ERR_STICK(stick_reg)				\
	.pushlocals						;\
	rdpr	%tt, stick_reg					;\
	cmp	stick_reg, TT_PROCERR				;\
	bne,a,pt	%xcc, 0f				;\
	  rd	STICK, stick_reg				;\
	rd	%tick, stick_reg				;\
0:								;\
	.poplocals	
#else

#define	GET_ERR_GL(gl_reg)					\
	rdpr	%gl, gl_reg

#define	GET_ERR_CWP(cwp_reg)					\
	rdpr	%cwp, cwp_reg

#define	GET_ERR_STICK(stick_reg)				\
	rd	STICK, stick_reg

#endif

#define	SAVE_GLOBALS()						\
	.pushlocals						;\
	mov	ASI_HSCRATCHPAD, %asi				;\
	/*							;\
	 * We overwrite the VCPU scratchpad register 		;\
	 */							;\
	stxa	%g1, [%g0 + HSCRATCH_VCPU_STRUCT]%asi		;\
								;\
	/*							;\
	 * If we have an error on the STRAND scratchpad		;\
	 * register we can't just load from it, or we will	;\
	 * get another error.					;\
	 * %g1	scratch						;\
	 */							;\
	rdpr	%tt, %g1					;\
	cmp	%g1, TT_PROCERR					;\
	bne,pt	%xcc, 1f					;\
	mov	MMU_SFSR, %g1					;\
	ldxa	[%g1]ASI_DMMU, %g1				;\
	cmp	%g1, DSFSR_SCAC					;\
	bl,pt	%xcc, 1f					;\
	cmp	%g1, DSFSR_SCAU					;\
	bg,pn	%xcc, 1f					;\
	mov	MMU_SFAR, %g1					;\
	ldxa	[%g1]ASI_DMMU, %g1				;\
	srlx	%g1, DSFAR_SCRATCHPAD_INDEX_SHIFT, %g1		;\
	and	%g1, DSFAR_SCRATCHPAD_INDEX_MASK, %g1		;\
	sllx    %g1, 3, %g1  /* VA of scratchpad reg (index * 8) */     ;\
	cmp     %g1, HSCRATCH_STRAND_STRUCT			;\
	bne,pt	%xcc, 1f					;\
	nop							;\
								;\
	/*							;\
	 * reset the strand struct, no globals saved		;\
	 */							;\
	PHYS_STRAND_ID(%g3)					;\
	set     STRAND_SIZE, %g2				;\
	mulx    %g3, %g2, %g3					;\
	setx	strands, %g4, %g5				;\
	RELOC_OFFSET(%g4, %g6)					;\
	sub	%g5, %g6, %g4	/* &strands */			;\
	add	%g3, %g4, %g3 /* &strands[core_id] */		;\
	mov     HSCRATCH_STRAND_STRUCT, %g2			;\
	stxa    %g3, [%g2]ASI_HSCRATCHPAD			;\
	ba,pt	%xcc, 2f					;\
	nop							;\
								;\
1:								;\
	/*							;\
	 * If the STRAND scratchpad is NULL, the VCPU		;\
	 * scratchpad will be also, so reset it back		;\
	 * to NULL here, nothing we can do			;\
	 */							;\
	ldxa	[%g0 + HSCRATCH_STRAND_STRUCT]%asi, %g1		;\
	brz,a,pn	%g1, 3f					;\
	  stxa	%g0, [%g0 + HSCRATCH_VCPU_STRUCT]%asi		;\
								;\
	/*							;\
	 * valid strand struct in %g1, save the globals		;\
	 */							;\
	stx	%g2, [%g1 + STRAND_UE_TMP3]			;\
								;\
	/*							;\
	 * %g1/%g2 now available for use			;\
	 */							;\
	rdpr	%tstate, %g1					;\
	srlx	%g1, TSTATE_GL_SHIFT, %g1			;\
	and	%g1, TSTATE_GL_MASK, %g1			;\
	GET_ERR_GL(%g2)						;\
	cmp	%g1, %g2					;\
	bne,pt %xcc, 2f	/* nothing to do, not MAXGL */		;\
	nop							;\
								;\
	/*							;\
	 * get the strand struct back into %g1			;\
	 */							;\
	ldxa	[%g0 + HSCRATCH_STRAND_STRUCT]%asi, %g1		;\
								;\
	/*							;\
	 * get a couple of scratch registers			;\
	 */							;\
	stx	%o0, [%g1 + STRAND_UE_TMP1]			;\
	stx	%o1, [%g1 + STRAND_UE_TMP2]			;\
	mov	%g1, %o0	/* %o0 strandp */		;\
								;\
	/*							;\
	 * restore original %g2					;\
	 */							;\
	ldx	[%g1 + STRAND_UE_TMP3], %g2			;\
								;\
	/*							;\
	 * restore original %g1	from VCPU scratchpad		;\
	 */							;\
	ldxa	[%g0 + HSCRATCH_VCPU_STRUCT] %asi, %g1		;\
								;\
	rdpr	%tl, %o1					;\
	sub	%o1, 1, %o1					;\
	sllx	%o1, TRAPGLOBALS_SHIFT, %o1			;\
	add	%o0, %o1, %o1					;\
	stx	%g7, [%o1 + STRAND_UE_GLOBALS + (7*8)]		;\
	stx	%g6, [%o1 + STRAND_UE_GLOBALS + (6*8)]		;\
	stx	%g5, [%o1 + STRAND_UE_GLOBALS + (5*8)]		;\
	stx	%g4, [%o1 + STRAND_UE_GLOBALS + (4*8)]		;\
	stx	%g3, [%o1 + STRAND_UE_GLOBALS + (3*8)]		;\
	stx	%g2, [%o1 + STRAND_UE_GLOBALS + (2*8)]		;\
	stx	%g1, [%o1 + STRAND_UE_GLOBALS + (1*8)]		;\
	/*							;\
	 * Set globals-saved flag				;\
	 */							;\
	mov	1, %o1						;\
	stx	%o1, [%o0 + STRAND_ERR_GLOBALS_SAVED]		;\
	ldx	[%o0 + STRAND_UE_TMP2], %o1			;\
	ldx	[%o0 + STRAND_UE_TMP1], %o0			;\
2:								;\
	/*							;\
	 * Restore scratchpad VCPU pointer			;\
	 * all globals available				;\
	 */							;\
	STRAND_STRUCT(%g1)					;\
	ldub	[%g1 + STRAND_ID], %g1				;\
	PID2VCPUP(%g1, %g2, %g3, %g4)				;\
	SET_VCPU_STRUCT(%g2, %g3)				;\
3:								;\
	.poplocals

/*
 * If TSTATE.GL == GL, we restore GLOBALS[GL] from cpu_globals[TL - 1]
 * All registers are clobbered. Must issue a retry/done immediately
 * after this macro.
 */
#define	RESTORE_GLOBALS(instr)				\
	.pushlocals					;\
	/*						;\
	 * check if globals saved, clear flag in	;\
	 * delay slot					;\
	 */						;\
	STRAND_STRUCT(%g1)				;\
	ldx	[%g1 + STRAND_ERR_GLOBALS_SAVED], %g2	;\
	brz,pt	%g2, 1f					;\
	stx	%g0, [%g1 + STRAND_ERR_GLOBALS_SAVED]	;\
							;\
	/*						;\
	 * get a couple of scratch registers		;\
	 * %g1	strandp					;\
	 */						;\
	stx	%o0, [%g1 + STRAND_UE_TMP1]		;\
	stx	%o1, [%g1 + STRAND_UE_TMP2]		;\
	mov	%g1, %o0 /* %o0 strandp */		;\
	rdpr	%tl, %o1				;\
	sub	%o1, 1, %o1				;\
	sllx	%o1, TRAPGLOBALS_SHIFT, %o1		;\
	add	%o0, %o1, %o1				;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (1*8)], %g1	;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (2*8)], %g2	;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (3*8)], %g3	;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (4*8)], %g4	;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (5*8)], %g5	;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (6*8)], %g6	;\
	ldx	[%o1 + STRAND_UE_GLOBALS + (7*8)], %g7	;\
	ldx	[%o0 + STRAND_UE_TMP2], %o1		;\
	ldx	[%o0 + STRAND_UE_TMP1], %o0		;\
1:							;\
	instr	/* retry/done/nop */			;\
	.poplocals

/*
 * in:
 *
 * out:	EHDL	(CPUID | TL | SEQ No)
 * scr1 -> unique error sequence
 *
 */
#define	GENERATE_EHDL(scr1, scr2)					\
	STRAND_STRUCT(scr2);						;\
	ldx	[scr2 + STRAND_ERR_SEQ_NO], scr1 /* get current seq# */	;\
	add	scr1, 1, scr1			/* new seq#	    */	;\
	stx	scr1, [scr2 + STRAND_ERR_SEQ_NO] /* update seq#      */	;\
	sllx	scr1, EHDL_SEQ_MASK_SHIFT, scr1				;\
	srlx	scr1, EHDL_SEQ_MASK_SHIFT, scr1	/* scr1 = normalized seq# */;\
	ldub	[scr2 + STRAND_ID], scr2		/* scr2 has CPUID    */	;\
	sllx	scr2, EHDL_TL_BITS, scr2	/* scr2 << EHDL_TL_BITS */;\
	sllx	scr2, EHDL_CPUTL_SHIFT, scr2	/* scr2 now has cpuid in 63:56 */  ;\
	or	scr2, scr1, scr1		/* scr1 now has ehdl without tl */ ;\
	rdpr	%tl, scr2			/* scr2 = %tl        */	;\
	sllx	scr2, EHDL_CPUTL_SHIFT, scr2	/* scr2 tl in position  */;\
	or	scr2, scr1, scr1		/* scr1 -> ehdl   */

/*
 * relocate an address
 */
#define	RELOC_ADDR(addr, scr)				\
	ROOT_STRUCT(scr)				;\
	ldx	[scr + CONFIG_RELOC], scr		;\
	sub	addr, scr, addr

#ifdef DEBUG
/*
 * %g1	error table entry
 * the first 'ba puts' will print out the error name
 */
#define	PRINT_ERROR_TABLE_ENTRY()			\
	.pushlocals					;\
	rdpr	%tl, %g3				;\
	brz,pn	%g3, 1f					;\
	nop						;\
	rdpr	%tpc, %g4				;\
	STRAND_STRUCT(%g2)				;\
	stx	%g1, [%g2 + STRAND_UE_TMP1]		;\
	stx	%g4, [%g2 + STRAND_UE_TMP2]		;\
	PRINT_NOTRAP("CPU: 0x")				;\
	mov	CMP_CORE_ID, %g4			;\
	ldxa	[%g4]ASI_CMP_CORE, %g4			;\
	and	%g4, 0x3f, %g4 /* strand_id bits [5:0] */ ;\
	PRINTX_NOTRAP(%g4)				;\
	PRINT_NOTRAP("\r\nTPC: 0x")			;\
	STRAND_STRUCT(%g2)				;\
	ldx	[%g2 + STRAND_UE_TMP2], %g4		;\
	PRINTX_NOTRAP(%g4)				;\
	PRINT_NOTRAP("\r\nTT: 0x")			;\
	rdpr	%tt, %g2				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nTL: 0x")			;\
	rdpr	%tl, %g2				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nTSTATE: 0x")			;\
	rdpr	%tstate, %g2				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nD-SFSR: 0x")			;\
	GET_ERR_DSFSR(%g2, %g3)				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nI-SFSR: 0x")			;\
	GET_ERR_ISFSR(%g2, %g3)				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nD-SFAR: 0x")			;\
	GET_ERR_DSFAR(%g2, %g3)				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nDESR: 0x")			;\
	GET_ERR_DESR(%g2, %g3)				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\nDFESR: 0x")			;\
	GET_ERR_DFESR(%g2, %g3)				;\
	PRINTX_NOTRAP(%g2)				;\
	PRINT_NOTRAP("\r\n")				;\
	STRAND_STRUCT(%g2)				;\
	ldx	[%g2 + STRAND_UE_TMP1], %g1		;\
	ba	puts					;\
	rd	%pc, %g7				;\
	PRINT_NOTRAP("\r\n")				;\
	STRAND_STRUCT(%g2)				;\
	ldx	[%g2 + STRAND_UE_TMP1], %g1		;\
1:							;\
	.poplocals
#endif

#define	SET_STRAND_ERR_FLAG(strand, flag, scr)				\
	lduw	[strand + STRAND_ERR_FLAG], scr				;\
	or	scr, flag, scr						;\
	stw	scr, [strand + STRAND_ERR_FLAG]

#define	CLEAR_STRAND_ERR_FLAG(strand, flag, scr)			\
	lduw	[strand + STRAND_ERR_FLAG], scr				;\
	andn	scr, flag, scr						;\
	stw	scr, [strand + STRAND_ERR_FLAG]

#define	SET_CPU_IN_ERROR(scr1, scr2)					\
	VCPU_STRUCT(scr1)						;\
	mov	CPU_STATE_ERROR, scr2					;\
	stx	scr2, [scr1 + CPU_STATUS]

#define	HPRIV_ERROR()							\
	LEGION_EXIT(3)							;\
	ba,a,pt   %xcc, hvabort_exit

#define	FATAL_ERROR()							\
	LEGION_EXIT(3)							;\
	ba,a,pt   %xcc, hvabort_exit

/*
 * Translate I/O PA to RA
 *
 * Currently no offset is used for non-cacheable I/O addresses. This
 * may change in the future.
 */
#define	CPU_ERR_IO_PA_TO_RA(cpu, paddr, raddr)		\
	mov	paddr, raddr

/*
 * Translate PA to guest RA
 *
 * Note that this should only be used for DRAM PA translation.
 */
#define	CPU_ERR_INVALID_RA		(-1)

#define	CPU_ERR_PA_TO_RA(vcpu, paddr, raddr, scr1, scr2)		\
	.pushlocals							;\
	VCPU2GUEST_STRUCT(vcpu, vcpu)					;\
	PA2RA_CONV(vcpu, paddr, raddr, scr1, scr2)			;\
	brnz,a,pn       scr2, 1f        /* ret 0 is success */          ;\
	  mov	CPU_ERR_INVALID_RA, raddr				;\
1:									;\
	VCPU_STRUCT(vcpu) /* restore VCPU */				;\
	.poplocals


#define	TRAP_GUEST(pc, scr1, scr2)		\
	/* Read _current_ tstate */		;\
	rdpr	%tstate, scr2			;\
	/* Bump %tl */				;\
	rdpr	%tl, scr1			;\
	inc	scr1				;\
	wrpr	scr1, %tl			;\
	/* Arrange for done to go to 'pc' */	;\
	wrpr	pc, %tnpc			;\
	/* Set up target %tl's pstate */	;\
	andn	scr2, (PSTATE_AM | PSTATE_IE) << TSTATE_PSTATE_SHIFT, scr2 ;\
	or	scr2, (PSTATE_PRIV) << TSTATE_PSTATE_SHIFT, scr2 ;\
	sllx	scr2, 64 - TSTATE_GL_SHIFT, scr2 ;\
	srlx	scr2, 64 - TSTATE_GL_SHIFT, scr2 ;\
	GET_ERR_GL(pc)				;\
	sllx	pc, TSTATE_GL_SHIFT, pc		;\
	wrpr	scr2, pc, %tstate		;\
	mov	HTSTATE_GUEST, scr1		;\
	wrhpr	scr1, %htstate			;\
	done

/*
 * When correcting an FRFC error, we need to convert the correction
 * mask from an integer register to a FP register, so we store it 
 * in CPU_FP_TMP3. We then load it into freg_scr1, load the FP reg
 * in error into freg_scr2, XOR and put the corrected data back
 * into the FP reg in error.
 */
/* single-precision FP ops */
#define	CORRECT_FRFC_SP(strand, freg_in_error, freg_scr1, freg_scr2, label)	\
	st	freg_scr1, [strand + STRAND_FP_TMP1]			;\
	st	freg_scr2, [strand + STRAND_FP_TMP2]			;\
	ld	[strand + STRAND_FP_TMP3], freg_scr1			;\
	fmovs	freg_in_error, freg_scr2				;\
	fxors	freg_scr2, freg_scr1, freg_scr2				;\
	fmovs	freg_scr2, freg_in_error				;\
	ld	[strand + STRAND_FP_TMP1], freg_scr1			;\
	ba	label							;\
	ld	[strand + STRAND_FP_TMP2], freg_scr2			

/* double-precision FP ops */
#define	CORRECT_FRFC_DP(strand, freg_in_error, freg_scr1, freg_scr2, label)	\
	std	freg_scr1, [strand + STRAND_FP_TMP1]			;\
	std	freg_scr2, [strand + STRAND_FP_TMP2]			;\
	ldd	[strand + STRAND_FP_TMP3], freg_scr1			;\
	fmovd	freg_in_error, freg_scr2				;\
	fxor	freg_scr2, freg_scr1, freg_scr2				;\
	fmovd	freg_scr2, freg_in_error				;\
	ldd	[strand + STRAND_FP_TMP1], freg_scr1			;\
	ba	label							;\
	ldd	[strand + STRAND_FP_TMP2], freg_scr2			

#define	CORRECT_FRFC_SIZE	(9 * SZ_INSTR)

#define	CORRECT_IRFC(ireg, correction_mask, scr, label)			\
	mov	ireg, scr						;\
	xor	scr, correction_mask, scr				;\
	ba	label							;\
	mov	scr, ireg

#define	CORRECT_IRFC_SIZE	(4 * SZ_INSTR)

/*
 * macro to get a new error_table_entry. Must be within the same
 * error table.
 */
#define	CONVERT_CE_TO_UE(num_entries)					\
	.pushlocals							;\
	/*								;\
	 * Clear the error report in_use field				;\
	 */								;\
	GET_ERR_DIAG_BUF(%g4, %g5)					;\
	brnz,a,pt	%g4, 1f						;\
	  stub	%g0, [%g4 + ERR_DIAG_RPRT_IN_USE]			;\
1:									;\
	/*								;\
	 * Clear the sun4v report in_use field				;\
	 */								;\
	GET_ERR_SUN4V_RPRT_BUF(%g4, %g5)				;\
	brnz,a,pt	%g4, 1f						;\
	  stub	%g0, [%g4 + ERR_SUN4V_RPRT_IN_USE]			;\
1:									;\
									;\
	/*								;\
	 * get the current error table entry and calculate where the	;\
	 * new entry is from the num_entries to offset by		;\
	 */								;\
	GET_ERR_TABLE_ENTRY(%g1, %g2)					;\
	sub	%g1, num_entries * ERROR_TABLE_ENTRY_SIZE, %g1		;\
	/*								;\
	 * And now just start all over again ...			;\
	 */								;\
	ba	error_handler						;\
	nop								;\
	.poplocals

/*
 * Correct bad ECC in a trapstack array privileged register
 * index	trap level of error
 */
#define	CORRECT_TSA_PREG(priv_reg, index, bit_in_error, scr1, scr2, scr3, label) \
	rdpr	%tl, scr3						;\
	wrpr	index, %tl						;\
	rdpr	priv_reg, scr1						;\
	mov	1, scr2							;\
	sllx	scr2, bit_in_error, scr2				;\
	xor	scr1, scr2, scr1					;\
	wrpr	scr1, priv_reg						;\
	ba	label							;\
	wrpr	scr3, %tl			

/*
 * Correct bad ECC in a trapstack array hyper-privileged register
 * index	trap level of error
 */
#define	CORRECT_TSA_HREG(hpriv_reg, index, bit_in_error, scr1, scr2, scr3, label) \
	rdpr	%tl, scr3						;\
	wrpr	index, %tl						;\
	rdhpr	hpriv_reg, scr1						;\
	mov	1, scr2							;\
	sllx	scr2, bit_in_error, scr2				;\
	xor	scr1, scr2, scr1					;\
	wrhpr	scr1, hpriv_reg						;\
	ba	label							;\
	wrpr	scr3, %tl

/*
 * Correct bad ECC in a trapstack array queue ASI
 */
#define	CORRECT_TSA_QUEUE(va, bit_in_error, scr1, scr2, scr3, label)	\
	mov	va, scr3						;\
	ldxa	[scr3]ASI_QUEUE, scr1					;\
	mov	1, scr2							;\
	sllx	scr2, bit_in_error, scr2				;\
	xor	scr1, scr2, scr1					;\
	ba	label							;\
	stxa	scr2, [scr3]ASI_QUEUE

#define	CORRECT_TSA_ALL_REGS(trap_level, scr1, scr2, label) 		\
	rdpr	%tl, scr2						;\
	wrpr	trap_level, %tl						;\
	rdpr	%tpc, scr1						;\
	wrpr	scr1, %tpc						;\
	rdpr	%tnpc, scr1						;\
	wrpr	scr1, %tnpc						;\
	rdpr	%tt, scr1						;\
	wrpr	scr1, %tt						;\
	rdpr	%tstate, scr1						;\
	wrpr	scr1, %tstate						;\
	rdhpr	%htstate, scr1						;\
	wrhpr	scr1, %htstate						;\
	wrpr	scr2, %tl						;\
	mov	ERROR_NONRESUMABLE_QUEUE_TAIL, scr1			;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	ERROR_NONRESUMABLE_QUEUE_HEAD, scr1			;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	ERROR_RESUMABLE_QUEUE_TAIL, scr1			;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	ERROR_RESUMABLE_QUEUE_HEAD, scr1			;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	DEV_MONDO_QUEUE_TAIL, scr1				;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	DEV_MONDO_QUEUE_HEAD, scr1				;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	CPU_MONDO_QUEUE_TAIL, scr1				;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	stxa	scr2, [scr1]ASI_QUEUE					;\
	mov	CPU_MONDO_QUEUE_HEAD, scr1				;\
	ldxa	[scr1]ASI_QUEUE, scr2					;\
	ba	label							;\
	stxa	scr2, [scr1]ASI_QUEUE

/*
 * If we get an SCAC/SCAU error on HSCRATCH_VCPU_STRUCT, we can't use the CPU_STRUCT()
 * macro as this will cause further errors. We will reload the HSCRATCH0
 * register with the appropriate config.cpus[] address, clobbering the
 * globals in the process.
 *
 * The SCAU handler will check for this register
 * and if it is in error - and we have not clobbered MAXGL globals - it
 * will convert the error into an SCAC and continue.
 */
#define	SCRATCHPAD_ERROR()						\
	.pushlocals							;\
	mov	MMU_SFSR, %g1						;\
	ldxa	[%g1]ASI_DMMU, %g1					;\
	cmp	%g1, DSFSR_SCAU						;\
	be,pt	%xcc, 1f						;\
	cmp	%g1, DSFSR_SCAC						;\
	be,pt	%xcc, 1f						;\
	nop								;\
	ba,pt	%xcc, 3f						;\
	.empty								;\
1:									;\
	mov	MMU_SFAR, %g1						;\
	ldxa	[%g1]ASI_DMMU, %g1					;\
	srlx    %g1, DSFAR_SCRATCHPAD_INDEX_SHIFT, %g1			;\
	and     %g1, DSFAR_SCRATCHPAD_INDEX_MASK, %g1			;\
	sllx	%g1, 3, %g1  /* VA of scratchpad reg (index * 8) */	;\
	cmp	%g1, HSCRATCH_VCPU_STRUCT				;\
	be,pt	%xcc, 2f						;\
	cmp	%g1, HSCRATCH_STRAND_STRUCT				;\
	be,pt	%xcc, 2f						;\
	nop								;\
	ba,pt	%xcc, 3f						;\
	.empty								;\
2:									;\
	/*								;\
	 * First the strand struct					;\
	 */								;\
	PHYS_STRAND_ID(%g3)						;\
	set     STRAND_SIZE, %g2					;\
	mulx    %g3, %g2, %g3						;\
	setx	strands, %g4, %g5					;\
	RELOC_OFFSET(%g4, %g6)						;\
	sub	%g5, %g6, %g4	/* &strands */				;\
	add	%g3, %g4, %g3 /* &strands[core_id] */			;\
	mov     HSCRATCH_STRAND_STRUCT, %g2				;\
	stxa    %g3, [%g2]ASI_HSCRATCHPAD				;\
									;\
	/*								;\
	 * Restore scratchpad VCPU pointer for that strand		;\
	 */								;\
	STRAND_STRUCT(%g1)						;\
	ldub	[%g1 + STRAND_ID], %g1					;\
	PID2VCPUP(%g1, %g2, %g3, %g4)					;\
	SET_VCPU_STRUCT(%g2, %g3)					;\
3:									;\
	.poplocals

/*
 * IRF index in D-SFAR is not Sparc V9 index
 *
 * Where %cwp even
 * 	index 0  --> %g0
 *	index 8  --> %o0
 * 	index 16 --> %l0
 * 	index 24 --> %i0
 *
 * For an odd window, the IN and OUT registers change position :-
 *	index 0  --> %g0
 *	index 24 --> %o0
 *	index 16 --> %l0
 *	index 8  --> %i0
 *
 * returns converted idx, scr clobbered
 */
#define	CONVERT_IRF_INDEX(idx, scr)					;\
	.pushlocals							;\
	cmp	idx, 8		/* skip globals */			;\
	bl	%xcc, 2f						;\
	nop								;\
	sub	idx, 8, idx	/* idx - 8 , (lose globals) */		;\
	GET_ERR_CWP(scr)						;\
	btst	0x1, scr						;\
	bz,pt	%xcc, 1f	/* even window, no change */		;\
	/* odd cwp, idx is register index - 8 */			;\
	cmp	idx, 15							;\
	bg,a,pt	%xcc, 1f						;\
	/* %o register, index 24->31 back to 8->15 (- 8 remember) */	;\
	  sub	idx, 16, idx						;\
	cmp	idx, 8		/* (%o7 - 8 + 1) */			;\
	bl,a,pt	%xcc, 1f						;\
	/* %i register, index 8->15 up to 24->31 (- 8 of course) */	;\
	  add	idx, 16, idx						;\
1:									;\
	add	idx, 8, idx 	/* globals back in */			;\
2:									;\
	.poplocals

/*
 * Calculate parity over data
 */
#define	GEN_PARITY(data, parity)	\
	srlx	data, 32, parity	;\
	xor	parity, data, data	;\
	srlx	data, 16, parity	;\
	xor	parity, data, data	;\
	srlx	data, 8, parity		;\
	xor	parity, data, data	;\
	srlx	data, 4, parity		;\
	xor	parity, data, data	;\
	srlx	data, 2, parity		;\
	xor	parity, data, data	;\
	srlx	data, 1, parity		;\
	xor	parity, data, data	;\
	and	data, 1, parity
	

/*
 * Calculate check bits [6:0] for floating point data
 */
#define	GEN_FRF_CHECK(data, chk, scr1, scr2, scr3, scr4)	\
	.pushlocals						;\
	setx	frfc_ecc_mask_table, scr2, scr1			;\
	RELOC_OFFSET(scr2, scr3)				;\
	sub	 scr1, scr3, scr1				;\
								;\
	set	NO_FRF_ECC_MASKS, scr2				;\
	mov	0, chk						;\
	ba	2f						;\
	nop							;\
1:								;\
	add	scr1, ECC_MASK_TABLE_ENTRY_SIZE, scr1		;\
2:								;\
	lduw	[scr1], scr3  /* get appropriate mask */	;\
								;\
	and	scr3, data, scr3 /* mask off unwanted data */	;\
								;\
	GEN_PARITY(scr3, scr4)					;\
								;\
	sllx	chk, 1, chk					;\
								;\
	subcc	scr2, 1, scr2					;\
	bgt	%xcc, 1b					;\
	or	scr4, chk, chk					;\
	.poplocals

#if defined(DEBUG) && !defined(DEBUG_LEGION)
#define	CLEAR_SOC_INJECTOR_REG(scr1, scr2)				\
	setx	SOC_ERROR_INJECTION_REG, scr1, scr2			;\
	stx	%g0, [scr2]
#else
#define	CLEAR_SOC_INJECTOR_REG(scr1, scr2)
#endif

#define	CHECK_BLACKOUT_INTERVAL(scr)					\
	.pushlocals							;\
	STRAND_STRUCT(scr)						;\
	brz,pn	scr, 0f							;\
	nop								;\
	STRAND2CONFIG_STRUCT(scr, scr)					;\
	brz,pn	scr, 0f							;\
	nop								;\
	ldx	[scr + CONFIG_CE_BLACKOUT], scr				;\
	brnz,pn scr, 1f		/* zero: blackout disabled */		;\
	nop								;\
0:									;\
	HVRET								;\
1:									;\
	.poplocals

/* END CSTYLED */

#ifdef __cplusplus
}
#endif

#endif /* _NIAGARA2_ERROR_ASM_H */
