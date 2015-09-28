/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: strand.h
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

#ifndef _PLATFORM_STRAND_H
#define	_PLATFORM_STRAND_H

#pragma ident	"@(#)strand.h	1.3	07/07/25 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <config.h>
#include <cyclic.h>

/*
 * Size of svc code's per-cpu scratch area in 64-bit words
 */
#define	NSVCSCRATCHREGS	6


/*
 * Number of per-cpu scratch locations
 */
#define	NCPUSCRATCH	8


/*
 * Stack depth for each cpu
 */
#define	STACKDEPTH	12

#ifndef _ASM

typedef	uint64_t	cpuset_t;

/*
 * Structures for saving watchdog failure state
 */
struct trapstate {
	uint64_t	htstate;
	uint64_t	tstate;
	uint64_t	tt;
	uint64_t	tpc;
	uint64_t	tnpc;
};

struct trapglobals {
	uint64_t	g[8];
};

/*
 * Stack support
 *
 * Each CPU has a very simple stack.  Only two operations are supported:
 * Push and Pop. In the event the stack gets full or under poped, hv will
 * abort.
 */
struct stack {
	uint64_t	top;			/* top of the stack */
	uint64_t	val[STACKDEPTH];	/* reg value */
};

#if NSTRANDS > 256
#error The strand id field is encoded in an 8bit value
#error for more than 256 strands this needs to have its type changed
#endif

struct strand {
	uint8_t		id;	/* physical strand number */
	struct config	*configp;

	/*
	 * This list is used to assign work to this strand.
	 * The current_slot points to the slot action in progress
	 * We only allow the local strand to manipulate its slots
	 * which means (along as interrupts are off) we've no need
	 * for locks around this structure.
	 */
	uint16_t	current_slot;
	struct sched_slot	slot[NUM_SCHED_SLOTS];

	/*
	* This is the HV strand X-Call mailbox.
	* This should evolve into an LDC channel with endpoints between
	* each of the strands, (an N*N matrix), and a mondo queue indicating
	* which incomming endpoints need servicing, but that happens when
	* we assign guest0 as the HV's context - later.
	*/
	struct xcall_mbox	xc_mb;
	uint64_t	hv_txmondo[8];
	uint64_t	hv_rxmondo[8];

	/*
	 * Initialisation support .. FIXME .. we could use scratch
	 * values instead as these are only used at the beginning of time
	 */
	uint64_t	scrub_basepa;
	uint64_t	scrub_size;

	/*
	 * The mini-stack used for the PUSH & POP macros.
	 */
	struct mini_stack	mini_stack;

	uint64_t	scr[NCPUSCRATCH];	/* scratch space */

	/*
	 * hstick interrupt support
	 */
	struct cyclic   cyclic;

	/*
	 * Error handling support
	 */

	/*
	 * support for when we get a UE with TSTATE.GL == GL
	 */
	uint64_t	ue_tmp1;
	uint64_t	ue_tmp2;
	uint64_t	ue_tmp3;
	struct	trapglobals ue_globals[MAXTL];
	uint64_t	err_seq_no;	/* unique sequence # */
	uint32_t	err_flag;		/* error handling flags */
	void		*strand_diag_buf[MAXTL];
	void		*strand_sun4v_rprt_buf[MAXTL];
	void		*strand_err_table_entry[MAXTL];
	uint64_t	strand_err_isfsr[MAXTL];
	uint64_t	strand_err_dsfsr[MAXTL];
	uint64_t	strand_err_dsfar[MAXTL];
	uint64_t	strand_err_desr[MAXTL];
	uint64_t	strand_err_dfesr[MAXTL];
	uint64_t	strand_err_return_addr[MAXTL];
	uint64_t	io_prot;	/* i/o error protection flag */
	uint64_t	io_error;	/* i/o error flag */
	uint64_t	nrpending;	/* pending non-resumable on this CPU */
	uint64_t	rerouted_cpu;	/* rerouting CPU -or- CPU in error */
	uint64_t	rerouted_ehdl;	/* EHDL rerouted to this CPU */
	uint64_t	rerouted_addr;	/* PA rerouted to this CPU */
	uint64_t	rerouted_stick;	/* %stick rerouted to this CPU */
	uint64_t	rerouted_attr;	/* ATTR rerouted to this CPU */
	uint64_t	abort_pc;	/* %pc of hvabort caller */
	uint64_t	err_globals_saved; /* globals saved OK on TL == MAXGL */

	/*
	 * Config
	 */
	uint64_t	dtnode;

	/*
	 * Saved failure state
	 */
	uint64_t	fail_tl;
	uint64_t	fail_gl;
	struct trapstate trapstate[MAXTL];
	struct trapglobals trapglobals[MAXGL];

	/*
	 * save a "clean" copy of the MRA data:
	 *
	 *   mra[0:3]:   z_tsb_cfg
	 *   mra[4:7]:   nz_tsb_cfg
	 */
	uint64_t	mra[MAX_NMRA];

	/*
	 * This is the real stack used for the C environment
	 */
	uint64_t	strand_stack[STRAND_STACK_SIZE / sizeof (uint64_t)];
};

#endif /* !_ASM */

/*
 *  struct cpu.wip: Work In Progress
 */
#define	CPU_WIP_CE		(1 << 0)	/* ce processing */
#define	CPU_WIP_UE		(1 << 1)	/* ue processing */
#define	CPU_WIP_CI		(1 << 2)	/* cmpr interrupt processing */
#define	CPU_WIP_ERRPOLL		(1 << 4)	/* polling for errors */

#ifdef __cplusplus
}
#endif

#endif /* _PLATFORM_STRAND_H */
