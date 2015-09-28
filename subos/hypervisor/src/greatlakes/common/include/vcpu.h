/*
* ========== Copyright Header Begin ==========================================
*
* Hypervisor Software File: vcpu.h
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

#ifndef _VCPU_H
#define	_VCPU_H

#pragma ident	"@(#)vcpu.h	1.10	07/07/09 SMI"

#ifdef __cplusplus
extern "C" {
#endif

#include <mmu.h>
#include <traps.h>
#include <resource.h>
#include <sun4v/traps.h>	/* for MAXPTL */
#include <resource.h>
#include <config.h>
#include <mau.h>
#include <cwq.h>

/*
 * Size of svc code's per-cpu scratch area in 64-bit words
 */
#define	NSVCSCRATCHREGS	6


/*
 * Number of per-cpu scratch locations
 */
#define	NCPUSCRATCH	8


/*
 * hvctl register save size
 */
#define	REG_STORE_SZ		(28 * 8)


#ifndef _ASM

typedef struct vcpu	vcpu_t;
typedef	struct mau	mau_t;
typedef	struct cwq	cwq_t;
typedef	struct rng	rng_t;
typedef	struct vcpustate vcpustate_t;

/*
 * vcpu state information
 */
struct rwindow {
	uint64_t	ins[8];
	uint64_t	outs[8];
};


struct vcpu_trapstate {
	uint64_t	tpc;
	uint64_t	tnpc;
	uint64_t	tstate;
	uint64_t	tt;
		/*
		 * we preserve htstate for vcpu in case at some point
		 * we add new "hyperprivileged" features relevent
		 * to that vcpu - e.g. "trap on level zero" etc.
		 */
	uint64_t	htstate;
};

typedef struct vcpu_trapstate vcpu_trapstate_t;

struct vcpu_globals {
	uint64_t	g[7];	/* ignore g0 */
};

typedef struct vcpu_globals  vcpu_globals_t;

struct vcpustate {
	uint64_t	tl;
	vcpu_trapstate_t	trapstack[MAXTL];
	uint64_t	gl;
	vcpu_globals_t	globals[MAXGL];

	uint64_t	tba;

	uint64_t	y;
	uint64_t	asi;
	uint64_t	softint;
	uint64_t	pil;
	uint64_t	gsr;

	uint64_t	tick;
	uint64_t	stick;
	uint64_t	stickcompare;

	uint64_t	scratchpad[8];

	uint64_t	cwp;
	uint64_t	wstate;
	uint64_t	cansave;
	uint64_t	canrestore;
	uint64_t	otherwin;
	uint64_t	cleanwin;

	struct rwindow	wins[NWINDOWS];

	uint16_t	cpu_mondo_head;
	uint16_t	cpu_mondo_tail;
	uint16_t	dev_mondo_head;
	uint16_t	dev_mondo_tail;
	uint16_t	error_resumable_head;
	uint16_t	error_resumable_tail;
	uint16_t	error_nonresumable_head;
	uint16_t	error_nonresumable_tail;
};

/*
 * Temp staging for info gleaned from MD node.
 */
typedef struct {
	resource_t	res;
	int		strand_id;
	int		vid;
	int		guestid;
	int		parttag;
} vcpu_parse_info_t;

/*
 * VCPU utilisation statistics
 */
typedef struct vcpu_util {
	uint64_t	stick_last;		/* last time stats were read */
	volatile uint64_t yield_count;		/* total yielded cycles */
	uint64_t	yield_start;		/* start of yield in progress */
	uint64_t	last_yield_count_guest;	/* previous guest yield count */
	uint64_t	last_yield_count_vcpu;	/* previous vcpu yield count */
} vcpu_util_t;

/* BEGIN CSTYLED */
#if	NVCPUS > 256
error IDs for cpus in this HV use 8 bit values if you want more than
error 256 cpus you need to find all these and change to wider types
#endif
/* END CSTYLED */

/*
 * This is the virtual cpu struct. There's one per virtual cpu.
 */
struct vcpu {
	struct guest	*guest;		/* pointer to owning guest */
	struct config	*root;
	struct strand	*strand;
	uint32_t	res_id;
	uint8_t		strand_slot;
	uint8_t		vid;		/* virtual cpu number */
	uint8_t		parttag;	/* id to use for partition tag reg */
	uint64_t	scr[NCPUSCRATCH];	/* scratch space */

	/*
	 * Configuration and running status
	 */
	volatile uint64_t	status;
	vcpu_parse_info_t	pip;

	/*
	 * Low-level mailbox
	 */
	uint64_t	lastpoke;
	uint64_t	command;
	uint64_t	arg0;
	uint64_t	arg1;
	uint64_t	arg2;
	uint64_t	arg3;
	uint64_t	arg4;
	uint64_t	arg5;
	uint64_t	arg6;
	uint64_t	arg7;
	uint64_t	vintr;

	/*
	 * State
	 */
	uint64_t	start_pc;
	uint64_t	start_arg;
	uint64_t	rtba;
	uint64_t	mmu_area;
	uint64_t	mmu_area_ra;
	uint64_t	cpuq_base;
	uint64_t	cpuq_size;
	uint64_t	cpuq_mask;
	uint64_t	cpuq_base_ra;
	uint64_t	devq_base;
	uint64_t	devq_size;
	uint64_t	devq_mask;
	uint64_t	devq_base_ra;
	uint64_t	devq_lock;
	uint64_t	devq_shdw_tail;
	uint64_t	errqnr_base;
	uint64_t	errqnr_size;
	uint64_t	errqnr_mask;
	uint64_t	errqnr_base_ra;
	uint64_t	errqr_base;
	uint64_t	errqr_size;
	uint64_t	errqr_mask;
	uint64_t	errqr_base_ra;

	/*
	 * Traptrace support
	 */
	uint64_t	ttrace_offset;
	uint64_t	ttrace_buf_size;
	uint64_t	ttrace_buf_ra;
	uint64_t	ttrace_buf_pa;

	/*
	 * TSBs
	 */
	uint64_t	ntsbs_ctx0;
	uint64_t	ntsbs_ctxn;
	uint8_t		tsbds_ctx0[MAX_NTSB * TSBD_BYTES];
	uint8_t		tsbds_ctxn[MAX_NTSB * TSBD_BYTES];

	/*
	 * MMU statistic support
	 */
	uint64_t	mmustat_area;
	uint64_t	mmustat_area_ra;

#ifdef CONFIG_CRYPTO
	/*
	 * Crypto units
	 */
	mau_t		*maup;
	cwq_t		*cwqp;
#endif

	rng_t		*rng;

#ifdef CONFIG_SVC
	uint64_t	svcregs[NSVCSCRATCHREGS];
#endif

	/*
	 * LDC interrupt handling/delivery
	 */
	uint32_t	ldc_intr_pend;	/* pending flag for synchronization */
	uint64_t	ldc_endpoint;	/* target endpt structure */
	uint64_t	ldc_sp_endpt;	/* for save/restore around callbacks */
	uint64_t	ldc_sp_arg;	/* for save/restore around callbacks */
	uint64_t	ldc_sp_arg_pc;	/* for save/restore around callbacks */
	uint64_t	ldc_cb_scr1;	/* scratch reg used in callback */
	uint64_t	ldc_cb_scr2;	/* scratch reg used in callback */

	/*
	 * Virtual CPU state save area
	 */
	struct vcpustate	state_save_area;
	uint8_t		launch_with_retry;

	/*
	 * Utilisation statistics area
	 */
	uint64_t	start_stick;
	vcpu_util_t	util;
};

extern vcpu_t		vcpus[];

extern void init_vcpu(int id);
extern void reset_vcpu_state(vcpu_t *vp);
extern void c_desched_n_stop_vcpu(vcpu_t *vp);

#endif /* !_ASM */

/*
 * Per-vcpu low-level mailbox commands, see vcpu.command.
 *
 * Over time, the list of commands that use the vcpu mailbox
 * has dwindled. Everything other than the cpu_mondo_send hcall
 * has been converted to use the hvxcall mechanism. Once that
 * has been modified to use hvxcalls as well, the vcpu mailbox
 * can be removed in its entirety.
 */
#define	CPU_CMD_READY			0x0
#define	CPU_CMD_BUSY			0x2
#define	CPU_CMD_GUESTMONDO_READY	0x3

#ifdef __cplusplus
}
#endif

#endif /* _VCPU_H */
